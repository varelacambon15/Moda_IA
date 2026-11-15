import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

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
  const AiPreset(this.id, this.name, this.baseUrl, this.defaultModel, this.keyUrl);
}

const aiPresets = <AiPreset>[
  AiPreset('groq', 'Groq', 'https://api.groq.com/openai/v1',
      'llama-3.3-70b-versatile', 'https://console.groq.com/keys'),
  AiPreset('gemini', 'Google Gemini',
      'https://generativelanguage.googleapis.com/v1beta/openai',
      'gemini-2.5-flash', 'https://aistudio.google.com/apikey'),
  AiPreset('openrouter', 'OpenRouter', 'https://openrouter.ai/api/v1',
      'meta-llama/llama-3.3-70b-instruct:free', 'https://openrouter.ai/keys'),
  AiPreset('cerebras', 'Cerebras', 'https://api.cerebras.ai/v1',
      'llama-3.3-70b', 'https://cloud.cerebras.ai'),
  AiPreset('mistral', 'Mistral', 'https://api.mistral.ai/v1',
      'mistral-small-latest', 'https://console.mistral.ai/api-keys'),
];

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
    scraperPages = _p.getString('scraperPages') ?? '';
    aiEnabled = _p.getBool('aiEnabled') ?? true;
    for (final pr in aiPresets) {
      aiKeys[pr.id] = _p.getString('aiKey_${pr.id}') ?? '';
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
