import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'models.dart';

/// Catálogo personal: prendas que el usuario guarda a mano, por enlace o por foto.
class MyCatalogStore extends ChangeNotifier {
  late SharedPreferences _p;
  List<Product> items = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('myCatalog');
    if (raw != null) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        items = [];
      }
    }
  }

  Future<void> _save() async {
    await _p.setString('myCatalog', jsonEncode(items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> add(Product p) async {
    items.removeWhere((e) => e.id == p.id);
    items.insert(0, p);
    await _save();
  }

  Future<void> remove(Product p) async {
    items.removeWhere((e) => e.id == p.id);
    if (p.imageUrl != null && p.imageUrl!.startsWith('/')) {
      try {
        await File(p.imageUrl!).delete();
      } catch (_) {}
    }
    await _save();
  }

  /// Copia la foto a la carpeta de la app para que no se pierda.
  Future<String> keepImage(String path) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/prenda_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).copy(dest);
    return dest;
  }
}

/// Datos leídos de una página de producto.
class LinkData {
  final String? name, image, store;
  final double? price;
  final String? color, category;
  const LinkData({this.name, this.image, this.store, this.price, this.color, this.category});
}

String storeFromHost(String host) {
  final h = host.replaceFirst(RegExp(r'^(www2?|shop|m)\.'), '');
  const known = {
    'zara': 'Zara', 'mango': 'Mango', 'bershka': 'Bershka', 'pullandbear': 'Pull&Bear',
    'stradivarius': 'Stradivarius', 'hm': 'H&M', 'massimodutti': 'Massimo Dutti',
    'oysho': 'Oysho', 'asos': 'ASOS', 'zalando': 'Zalando', 'shein': 'Shein',
  };
  final base = h.split('.').first;
  return known[base] ?? (base.isEmpty ? '' : base[0].toUpperCase() + base.substring(1));
}

String? _meta(String html, String prop) {
  final a = RegExp('<meta[^>]+(?:property|name)=["\']$prop["\'][^>]*content=["\']([^"\']*)["\']',
          caseSensitive: false)
      .firstMatch(html);
  if (a != null) return a.group(1);
  final b = RegExp('<meta[^>]+content=["\']([^"\']*)["\'][^>]*(?:property|name)=["\']$prop["\']',
          caseSensitive: false)
      .firstMatch(html);
  return b?.group(1);
}

String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'");

/// Lee nombre, precio e imagen de una página de producto (JSON-LD y etiquetas Open Graph).
Future<LinkData> readProductLink(String link) async {
  final uri = Uri.parse(link.trim());
  final res = await http.get(uri, headers: {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
    'Accept-Language': 'es-ES,es;q=0.9',
  }).timeout(const Duration(seconds: 25));
  if (res.statusCode != 200) throw Exception('La página respondió HTTP ${res.statusCode}');
  final html = utf8.decode(res.bodyBytes, allowMalformed: true);

  String? name, image, color, cat;
  double? price;
  final re = RegExp(r'<script[^>]*type=["\x27]application/ld\+json["\x27][^>]*>(.*?)</script>',
      dotAll: true, caseSensitive: false);
  void walk(dynamic j) {
    if (j is List) {
      for (final e in j) {
        walk(e);
      }
    } else if (j is Map) {
      final t = j['@type'];
      if (t == 'Product' || (t is List && t.contains('Product'))) {
        name ??= j['name']?.toString();
        color ??= j['color']?.toString();
        cat ??= j['category']?.toString();
        dynamic img = j['image'];
        if (img is List && img.isNotEmpty) img = img.first;
        if (img is Map) img = img['url'];
        if (img is String) image ??= img;
        dynamic o = j['offers'];
        if (o is List && o.isNotEmpty) o = o.first;
        if (o is Map) price ??= parsePrice((o['price'] ?? o['lowPrice'])?.toString());
      }
      for (final k in ['@graph', 'mainEntity']) {
        if (j[k] != null) walk(j[k]);
      }
    }
  }

  for (final m in re.allMatches(html)) {
    try {
      walk(jsonDecode(m.group(1)!.trim()));
    } catch (_) {}
  }
  name ??= _meta(html, 'og:title') ??
      RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true).firstMatch(html)?.group(1)?.trim();
  image ??= _meta(html, 'og:image');
  price ??= parsePrice(_meta(html, 'product:price:amount') ?? _meta(html, 'og:price:amount'));
  if (name == null && image == null && price == null) {
    throw Exception('No encontré datos de producto en esa página');
  }
  final n = name == null ? null : _unescape(name!);
  return LinkData(
    name: n,
    image: image == null ? null : uri.resolve(_unescape(image!)).toString(),
    store: storeFromHost(uri.host),
    price: price,
    color: color == null ? (n == null ? null : normalizeColor(n)) : normalizeColor(color!),
    category: (inferCategory('${n ?? ''} ${cat ?? ''}'))?.name,
  );
}
