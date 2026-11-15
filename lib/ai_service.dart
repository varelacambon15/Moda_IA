import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'settings.dart';

/// Cliente de IA con varias APIs gratuitas (todas compatibles con OpenAI).
/// Prueba cada proveedor que tenga clave, en orden, hasta que uno responda.
class AiService {
  final AppSettings settings;
  AiService(this.settings);

  List<AiPreset> get _active =>
      aiPresets.where((p) => settings.keyOf(p).trim().isNotEmpty).toList();

  bool get available => settings.aiEnabled && _active.isNotEmpty;

  Future<String> _chat(List<Map<String, String>> messages, {double temp = 0.7}) async {
    String? lastError;
    for (final p in _active) {
      try {
        final res = await http
            .post(
              Uri.parse('${p.baseUrl}/chat/completions'),
              headers: {
                'Authorization': 'Bearer ${settings.keyOf(p).trim()}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': settings.modelOf(p),
                'messages': messages,
                'temperature': temp,
              }),
            )
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final text = data['choices'][0]['message']['content'] as String?;
          if (text != null && text.trim().isNotEmpty) return text.trim();
        }
        lastError = '${p.name}: HTTP ${res.statusCode}';
      } catch (e) {
        lastError = '${p.name}: $e';
      }
    }
    throw Exception(lastError ?? 'No hay ninguna API de IA configurada');
  }

  /// Explica el look y da consejos de estilismo.
  Future<String> describeOutfit(Outfit o, StyleRequest r) {
    final prendas = o.items
        .map((p) => '- ${p.name} (${p.store}, ${p.color}, ${p.price.toStringAsFixed(2)} €)')
        .join('\n');
    return _chat([
      {
        'role': 'system',
        'content': 'Eres un estilista de moda español. Responde en español de España, '
            'con tuteo, en un máximo de 90 palabras, sin listas largas.',
      },
      {
        'role': 'user',
        'content': 'Ocasión: ${r.occasion.label}. Temporada: ${r.season.label}.\n'
            'Look:\n$prendas\n\nDale un nombre corto al look, explica por qué combina '
            'y da un consejo para llevarlo.',
      },
    ]);
  }

  /// Convierte una petición libre ("algo para una boda en junio, 150 €")
  /// en parámetros del motor de estilo.
  Future<StyleRequest?> parseRequest(
      String text, StyleRequest base, List<String> stores) async {
    final out = await _chat([
      {
        'role': 'system',
        'content': 'Devuelves SOLO un JSON válido, sin texto adicional.',
      },
      {
        'role': 'user',
        'content': 'Petición: "$text"\n'
            'Devuelve {"occasion": uno de ${Occasion.values.map((e) => e.name).toList()}, '
            '"season": uno de ${Season.values.map((e) => e.name).toList()}, '
            '"budget": número en euros (${base.budget.round()} si no se indica), '
            '"stores": lista con tiendas de ${stores.toList()} citadas (vacía si no se citan)}',
      },
    ], temp: 0.1);
    final start = out.indexOf('{');
    final end = out.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final j = jsonDecode(out.substring(start, end + 1)) as Map<String, dynamic>;
      final occ = Occasion.values.asNameMap()[j['occasion']] ?? base.occasion;
      final sea = Season.values.asNameMap()[j['season']] ?? base.season;
      final bud = (j['budget'] as num?)?.toDouble() ?? base.budget;
      final st = ((j['stores'] as List?) ?? const [])
          .cast<String>()
          .where(stores.contains)
          .toSet();
      return StyleRequest(occasion: occ, season: sea, budget: bud.clamp(30, 1500).toDouble(), stores: st);
    } catch (_) {
      return null;
    }
  }

  bool get visionAvailable =>
      settings.aiEnabled && _active.any((p) => p.visionModel != null);

  /// Lee una foto (prenda, escaparate o etiqueta) y devuelve los datos de la prenda.
  /// [modo]: 'imagen' | 'prenda' | 'etiqueta'.
  Future<Map<String, dynamic>?> readGarment(Uint8List bytes, String modo) async {
    final b64 = base64Encode(bytes);
    final hint = modo == 'etiqueta'
        ? 'La foto es de la etiqueta de una prenda: lee marca, nombre/referencia, precio y composición.'
        : 'La foto es de una prenda (en tienda o una imagen suelta): identifica qué es, su color y estilo.';
    final prompt = '$hint\nDevuelve SOLO un JSON con: '
        '{"name": nombre corto en español, "store": marca o tienda si se ve o ""'
        ', "price": número en euros o null, '
        '"category": uno de ${Category.values.map((e) => e.name).toList()}, '
        '"color": color principal en español (negro, blanco, gris, beige, marino, azul, vaquero, rojo, verde, caqui, marrón, rosa, burdeos, amarillo, camel), '
        '"style": uno de [casual, elegante, urbano, fiesta, deportivo], '
        '"season": uno de ${Season.values.map((e) => e.name).toList()}}';
    for (final p in _active.where((p) => p.visionModel != null)) {
      try {
        final res = await http
            .post(
              Uri.parse('${p.baseUrl}/chat/completions'),
              headers: {
                'Authorization': 'Bearer ${settings.keyOf(p).trim()}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': p.visionModel,
                'temperature': 0.1,
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': prompt},
                      {
                        'type': 'image_url',
                        'image_url': {'url': 'data:image/jpeg;base64,$b64'},
                      },
                    ],
                  }
                ],
              }),
            )
            .timeout(const Duration(seconds: 40));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final out = data['choices'][0]['message']['content'] as String? ?? '';
        final a = out.indexOf('{'), z = out.lastIndexOf('}');
        if (a < 0 || z <= a) continue;
        return jsonDecode(out.substring(a, z + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }
}
