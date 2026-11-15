import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'secrets.dart';

/// Línea "tienda|url" de los ajustes.
class SourceLine {
  final String store;
  final String url;
  const SourceLine(this.store, this.url);
}

List<SourceLine> parseSourceLines(String text) {
  final out = <SourceLine>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final i = line.indexOf('|');
    if (i > 0) {
      out.add(SourceLine(line.substring(0, i).trim(), line.substring(i + 1).trim()));
    }
  }
  return out;
}

/// Proveedores de IA con capa gratuita y API compatible con OpenAI.
class AiPreset {
  final String id;
  final String name;
  final String baseUrl;
  final String defaultModel;
  final String keyUrl;
  final String? visionModel; // modelo gratuito con visión (null = no soporta)
  const AiPreset(this.id, this.name, this.baseUrl, this.defaultModel, this.keyUrl,
      [this.visionModel]);
}

const aiPresets = <AiPreset>[
  AiPreset('groq', 'Groq', 'https://api.groq.com/openai/v1',
      'llama-3.3-70b-versatile', 'https://console.groq.com/keys',
      'meta-llama/llama-4-scout-17b-16e-instruct'),
  AiPreset('gemini', 'Google Gemini',
      'https://generativelanguage.googleapis.com/v1beta/openai',
      'gemini-2.5-flash', 'https://aistudio.google.com/apikey', 'gemini-2.5-flash'),
  AiPreset('openrouter', 'OpenRouter', 'https://openrouter.ai/api/v1',
      'meta-llama/llama-3.3-70b-instruct:free', 'https://openrouter.ai/keys',
      'google/gemma-3-27b-it:free'),
  AiPreset('cerebras', 'Cerebras', 'https://api.cerebras.ai/v1',
      'llama-3.3-70b', 'https://cloud.cerebras.ai'),
  AiPreset('mistral', 'Mistral', 'https://api.mistral.ai/v1',
      'mistral-small-latest', 'https://console.mistral.ai/api-keys', 'pixtral-12b-2409'),
];

const defaultScraperPages = '''# tienda|url de categoría (JSON-LD público; respeta robots.txt)
Zara|https://www.zara.com/es/es/mujer-camisetas-l1362.html
Mango|https://shop.mango.com/es/mujer/camisetas-y-tops_c18813536
Bershka|https://www.bershka.com/es/mujer/ropa/camisetas-c1010193132.html
Pull&Bear|https://www.pullandbear.com/es/mujer/ropa/camisetas-n6417
Stradivarius|https://www.stradivarius.com/es/mujer/ropa/camisetas-n1930
H&M|https://www2.hm.com/es_es/mujer/compra-por-producto/camisetas-y-tops.html
Massimo Dutti|https://www.massimodutti.com/es/mujer/camisetas-n1719''';

class AppSettings extends ChangeNotifier {
  bool useSample = true;
  bool useAffiliate = false;
  bool useScraper = false;
  String affiliateFeeds = '';
  String scraperPages = '';

  bool aiEnabled = true;
  final Map<String, String> aiKeys = {};
  final Map<String, String> aiModels = {};

  String keyOf(AiPreset p) => aiKeys[p.id] ?? '';
  String modelOf(AiPreset p) => aiModels[p.id] ?? p.defaultModel;

  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    useSample = _p.getBool('useSample') ?? true;
    useAffiliate = _p.getBool('useAffiliate') ?? false;
    useScraper = _p.getBool('useScraper') ?? false;
    affiliateFeeds = _p.getString('affiliateFeeds') ?? '';
    scraperPages = _p.getString('scraperPages') ?? defaultScraperPages;
    aiEnabled = _p.getBool('aiEnabled') ?? true;
    for (final pr in aiPresets) {
      aiKeys[pr.id] = _p.getString('aiKey_${pr.id}') ?? defaultAiKeys[pr.id] ?? '';
      aiModels[pr.id] = _p.getString('aiModel_${pr.id}') ?? pr.defaultModel;
    }
  }

  Future<void> update(void Function() change) async {
    change();
    await _p.setBool('useSample', useSample);
    await _p.setBool('useAffiliate', useAffiliate);
    await _p.setBool('useScraper', useScraper);
    await _p.setString('affiliateFeeds', affiliateFeeds);
    await _p.setString('scraperPages', scraperPages);
    await _p.setBool('aiEnabled', aiEnabled);
    for (final pr in aiPresets) {
      await _p.setString('aiKey_${pr.id}', aiKeys[pr.id] ?? '');
      await _p.setString('aiModel_${pr.id}', aiModels[pr.id] ?? pr.defaultModel);
    }
    notifyListeners();
  }
}

class FavoritesStore extends ChangeNotifier {
  late SharedPreferences _p;
  List<Outfit> outfits = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('favorites');
    if (raw != null) {
      try {
        outfits = (jsonDecode(raw) as List)
            .map((e) => Outfit.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        outfits = [];
      }
    }
  }

  bool isFavorite(Outfit o) => outfits.any((f) => f.key == o.key);

  Future<void> toggle(Outfit o) async {
    if (isFavorite(o)) {
      outfits.removeWhere((f) => f.key == o.key);
    } else {
      outfits.insert(0, o);
    }
    await _p.setString('favorites', jsonEncode(outfits.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}
