import 'dart:convert';
import 'dart:io' show GZipCodec;

import 'package:http/http.dart' as http;

import 'models.dart';
import 'my_catalog.dart';
import 'settings.dart';

// ───────────────────────── utilidades ─────────────────────────

Category? inferCategory(String text) {
  final t = text.toLowerCase();
  bool has(List<String> k) => k.any(t.contains);
  if (has(['abrigo', 'chaqueta', 'cazadora', 'blazer', 'americana', 'gabardina', 'trench', 'plumífero', 'plumifero', 'parka', 'chaleco', 'cortavientos'])) return Category.outerwear;
  if (has(['vestido', 'mono largo'])) return Category.dress;
  if (has(['zapato', 'zapatilla', 'bota', 'botín', 'botin', 'sandalia', 'mocasín', 'mocasin', 'bailarina', 'deportiva'])) return Category.shoes;
  if (has(['bolso', 'cinturón', 'cinturon', 'gorra', 'bufanda', 'gafas', 'collar', 'pañuelo', 'mochila', 'cartera', 'riñonera'])) return Category.accessory;
  if (has(['pantal', 'vaquero', 'jeans', 'falda', 'short', 'bermuda', 'malla', 'legging', 'jogger'])) return Category.bottom;
  if (has(['camiseta', 'camisa', 'jersey', 'sudadera', 'blusa', ' top', 'polo', 'body', 'suéter', 'sueter', 'cárdigan', 'cardigan'])) return Category.top;
  return null;
}

String normalizeColor(String text) {
  final t = text.toLowerCase();
  const map = <String, List<String>>{
    'marino': ['marino', 'navy'],
    'negro': ['negro', 'black'],
    'blanco': ['blanco', 'white', 'crudo', 'ecru', 'ecrú'],
    'gris': ['gris', 'grey', 'gray', 'antracita'],
    'beige': ['beige', 'arena', 'crema', 'piedra'],
    'vaquero': ['vaquero', 'denim', 'índigo', 'indigo'],
    'azul': ['azul', 'blue', 'celeste'],
    'rojo': ['rojo', 'red'],
    'verde': ['verde', 'green'],
    'caqui': ['caqui', 'khaki'],
    'marrón': ['marrón', 'marron', 'brown', 'chocolate'],
    'rosa': ['rosa', 'pink', 'fucsia'],
    'burdeos': ['burdeos', 'granate', 'vino'],
    'amarillo': ['amarillo', 'yellow', 'mostaza'],
    'camel': ['camel', 'tostado', 'cuero'],
  };
  for (final e in map.entries) {
    if (e.value.any(t.contains)) return e.key;
  }
  return 'otro';
}

Set<String> inferStyles(String text) {
  final t = text.toLowerCase();
  final s = <String>{};
  if (RegExp(r'deportiv|running|sport|entrena|mallas|legging').hasMatch(t)) s.add('deportivo');
  if (RegExp(r'fiesta|satin|satén|lentejuela|brillo|lencero|body').hasMatch(t)) s.add('fiesta');
  if (RegExp(r'sastre|vestir|blazer|americana|camisa|popel|midi|mocas|tacón|tacon|lana|trench').hasMatch(t)) s.add('elegante');
  if (RegExp(r'oversize|cargo|sudadera|plataforma|bomber|ancho|estampad').hasMatch(t)) s.add('urbano');
  if (s.isEmpty || RegExp(r'básic|basic|casual|vaquero|jeans|camiseta').hasMatch(t)) s.add('casual');
  return s;
}

Season inferSeason(String text) {
  final t = text.toLowerCase();
  if (RegExp(r'abrigo|plumíf|plumif|lana|forrad|parka|bufanda|invierno').hasMatch(t)) return Season.cold;
  if (RegExp(r'lino|bermuda|sandalia|tirantes|manga corta|short|verano').hasMatch(t)) return Season.warm;
  return Season.all;
}

List<List<String>> parseCsv(String text, {String delimiter = ','}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        sb.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delimiter) {
      row.add(sb.toString());
      sb.clear();
    } else if (c == '\n') {
      row.add(sb.toString());
      sb.clear();
      rows.add(row);
      row = <String>[];
    } else if (c != '\r') {
      sb.write(c);
    }
  }
  if (sb.isNotEmpty || row.isNotEmpty) {
    row.add(sb.toString());
    rows.add(row);
  }
  return rows;
}

double? parsePrice(String? s) {
  if (s == null) return null;
  var t = s.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (t.contains(',') && t.contains('.')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else {
    t = t.replaceAll(',', '.');
  }
  return double.tryParse(t);
}

// ───────────────────────── proveedores ─────────────────────────

abstract class CatalogProvider {
  String get name;
  Future<List<Product>> load();
}

/// 1) Catálogo de ejemplo integrado (funciona sin conexión).
///    Los precios son orientativos y los enlaces abren la búsqueda de la tienda.
class SampleProvider implements CatalogProvider {
  @override
  String get name => 'Catálogo de ejemplo';

  static const _search = {
    'Zara': 'https://www.zara.com/es/es/search?searchTerm=',
    'Mango': 'https://shop.mango.com/es/search?kw=',
    'Bershka': 'https://www.bershka.com/es/search?q=',
    'Pull&Bear': 'https://www.pullandbear.com/es/search?q=',
    'Stradivarius': 'https://www.stradivarius.com/es/search?q=',
    'H&M': 'https://www2.hm.com/es_es/search-results.html?q=',
    'Massimo Dutti': 'https://www.massimodutti.com/es/search?searchTerm=',
  };

  @override
  Future<List<Product>> load() async {
    final out = <Product>[];
    void p(String store, String name, Category c, String color, double price,
        String styles, [Season s = Season.all]) {
      out.add(Product(
        id: 'ej-${out.length}',
        store: store,
        name: name,
        category: c,
        color: color,
        price: price,
        url: '${_search[store]}${Uri.encodeQueryComponent(name)}',
        styles: styles.split(' ').toSet(),
        season: s,
        source: 'ejemplo',
      ));
    }

    const T = Category.top, B = Category.bottom, D = Category.dress;
    const O = Category.outerwear, S = Category.shoes, A = Category.accessory;
    const W = Season.warm, C = Season.cold;

    // Partes de arriba
    p('Zara', 'Camisa popelín', T, 'blanco', 29.95, 'elegante casual');
    p('Zara', 'Camiseta básica', T, 'negro', 12.95, 'casual urbano');
    p('Mango', 'Jersey punto cuello alto', T, 'beige', 25.99, 'elegante casual', C);
    p('Bershka', 'Camiseta oversize estampada', T, 'blanco', 15.99, 'urbano casual', W);
    p('Pull&Bear', 'Sudadera con capucha', T, 'gris', 25.99, 'urbano casual deportivo', C);
    p('H&M', 'Camiseta deportiva transpirable', T, 'negro', 9.99, 'deportivo');
    p('Stradivarius', 'Top satinado', T, 'burdeos', 17.99, 'fiesta elegante');
    p('Massimo Dutti', 'Polo de punto', T, 'marino', 59.95, 'elegante casual', W);
    p('Mango', 'Blusa fluida', T, 'rosa', 29.99, 'elegante fiesta', W);
    p('Zara', 'Body ajustado', T, 'negro', 15.95, 'fiesta');
    p('Bershka', 'Camisa de lino', T, 'beige', 22.99, 'casual', W);
    p('H&M', 'Jersey de lana fina', T, 'gris', 24.99, 'elegante casual', C);

    // Partes de abajo
    p('Zara', 'Pantalón de sastre', B, 'negro', 35.95, 'elegante');
    p('Mango', 'Vaquero recto', B, 'vaquero', 35.99, 'casual urbano');
    p('Bershka', 'Vaquero wide leg', B, 'vaquero', 29.99, 'urbano');
    p('Pull&Bear', 'Pantalón cargo', B, 'caqui', 29.99, 'urbano casual');
    p('H&M', 'Pantalón chino', B, 'beige', 24.99, 'casual elegante');
    p('Stradivarius', 'Falda midi satinada', B, 'verde', 25.99, 'fiesta elegante');
    p('Zara', 'Bermuda de lino', B, 'beige', 25.95, 'casual', W);
    p('H&M', 'Mallas deportivas', B, 'negro', 14.99, 'deportivo');
    p('Massimo Dutti', 'Pantalón de lana', B, 'gris', 79.95, 'elegante', C);
    p('Mango', 'Minifalda', B, 'negro', 22.99, 'fiesta');
    p('Zara', 'Pantalón corto deportivo', B, 'gris', 12.95, 'deportivo', W);

    // Vestidos
    p('Zara', 'Vestido midi', D, 'negro', 39.95, 'elegante fiesta');
    p('Mango', 'Vestido lencero', D, 'burdeos', 45.99, 'fiesta elegante');
    p('Stradivarius', 'Vestido camisero', D, 'azul', 29.99, 'casual', W);
    p('H&M', 'Vestido de punto', D, 'camel', 29.99, 'casual elegante', C);
    p('Bershka', 'Vestido corto', D, 'negro', 19.99, 'fiesta');

    // Abrigos y chaquetas
    p('Zara', 'Abrigo largo', O, 'camel', 89.95, 'elegante', C);
    p('Mango', 'Blazer estructurado', O, 'negro', 59.99, 'elegante');
    p('Bershka', 'Cazadora vaquera', O, 'vaquero', 39.99, 'urbano casual');
    p('Pull&Bear', 'Plumífero', O, 'negro', 49.99, 'urbano casual deportivo', C);
    p('Massimo Dutti', 'Trench', O, 'beige', 149.00, 'elegante');
    p('H&M', 'Chaqueta cortavientos', O, 'marino', 29.99, 'deportivo casual');

    // Calzado
    p('Zara', 'Botines de tacón', S, 'negro', 49.95, 'elegante fiesta');
    p('Mango', 'Zapatillas blancas', S, 'blanco', 49.99, 'casual urbano');
    p('Bershka', 'Zapatillas plataforma', S, 'blanco', 39.99, 'urbano');
    p('Pull&Bear', 'Botas militares', S, 'negro', 45.99, 'urbano', C);
    p('H&M', 'Zapatillas running', S, 'gris', 34.99, 'deportivo');
    p('Massimo Dutti', 'Mocasines de piel', S, 'marrón', 99.00, 'elegante casual');
    p('Stradivarius', 'Sandalias de tacón', S, 'negro', 29.99, 'fiesta elegante', W);
    p('Zara', 'Sandalias planas', S, 'camel', 29.95, 'casual', W);

    // Complementos
    p('Zara', 'Bolso bandolera', A, 'negro', 25.95, 'elegante fiesta casual');
    p('Mango', 'Cinturón de piel', A, 'marrón', 19.99, 'elegante casual');
    p('Bershka', 'Gorra', A, 'negro', 12.99, 'urbano deportivo');
    p('Stradivarius', 'Bolso mini', A, 'burdeos', 17.99, 'fiesta');
    p('H&M', 'Bufanda', A, 'gris', 12.99, 'casual elegante', C);
    p('Pull&Bear', 'Riñonera', A, 'negro', 14.99, 'urbano deportivo');

    return out;
  }
}

/// 2) Feeds de afiliación (Awin, Tradedoubler...) en CSV.
///    Ajustes: una línea por feed con formato  tienda|https://url-del-feed.csv
class AffiliateFeedProvider implements CatalogProvider {
  final List<SourceLine> feeds;
  AffiliateFeedProvider(this.feeds);

  @override
  String get name => 'Feeds de afiliación';

  @override
  Future<List<Product>> load() async {
    final out = <Product>[];
    for (final f in feeds) {
      final res = await http.get(Uri.parse(f.url)).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw Exception('Feed ${f.store}: HTTP ${res.statusCode}');
      }
      List<int> bytes = res.bodyBytes;
      if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        bytes = GZipCodec().decode(bytes);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final firstLine = text.split('\n').first;
      final delim = ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length ? ';' : ',';
      final rows = parseCsv(text, delimiter: delim);
      if (rows.length < 2) continue;

      final header = <String, int>{};
      for (var i = 0; i < rows[0].length; i++) {
        header[rows[0][i].trim().toLowerCase()] = i;
      }
      String? col(List<String> row, List<String> names) {
        for (final n in names) {
          final i = header[n];
          if (i != null && i < row.length && row[i].trim().isNotEmpty) return row[i].trim();
        }
        return null;
      }

      var n = 0;
      for (final row in rows.skip(1)) {
        if (n >= 3000) break;
        final pname = col(row, ['product_name', 'name', 'title']);
        final url = col(row, ['aw_deep_link', 'merchant_deep_link', 'deep_link', 'url', 'link']);
        final price = parsePrice(col(row, ['search_price', 'store_price', 'price']));
        if (pname == null || url == null || price == null) continue;
        final cat = col(row, ['merchant_category', 'category_name', 'product_type', 'category']) ?? '';
        final text2 = '$pname $cat';
        final category = inferCategory(text2);
        if (category == null) continue;
        final colour = col(row, ['colour', 'color', 'colors']) ?? pname;
        out.add(Product(
          id: 'af:${f.store}:${url.hashCode}',
          store: f.store,
          name: pname,
          category: category,
          color: normalizeColor(colour),
          price: price,
          imageUrl: col(row, ['aw_image_url', 'merchant_image_url', 'image_url', 'image']),
          url: url,
          styles: inferStyles(text2),
          season: inferSeason(text2),
          source: 'afiliado',
        ));
        n++;
      }
    }
    return out;
  }
}

/// 3) Lectura de páginas públicas de categoría/producto mediante datos
///    estructurados JSON-LD (schema.org). Respeta robots.txt.
///    OJO: muchas tiendas prohíben el scraping en sus términos de uso.
///    Ajustes: una línea por página con formato  tienda|https://url-de-categoria
class ScraperProvider implements CatalogProvider {
  final List<SourceLine> pages;
  ScraperProvider(this.pages);

  @override
  String get name => 'Lectura de webs';

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) LooksIA/1.0',
    'Accept-Language': 'es-ES,es;q=0.9',
  };

  Future<bool> _allowed(Uri u) async {
    try {
      final r = await http
          .get(Uri(scheme: u.scheme, host: u.host, path: '/robots.txt'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return true;
      var applies = false;
      final disallows = <String>[];
      for (final raw in r.body.split('\n')) {
        final line = raw.split('#').first.trim();
        final i = line.indexOf(':');
        if (i < 0) continue;
        final k = line.substring(0, i).trim().toLowerCase();
        final v = line.substring(i + 1).trim();
        if (k == 'user-agent') {
          applies = v == '*';
        } else if (applies && k == 'disallow' && v.isNotEmpty) {
          disallows.add(v);
        }
      }
      final path = u.path + (u.hasQuery ? '?${u.query}' : '');
      return !disallows.any(path.startsWith);
    } catch (_) {
      return true;
    }
  }

  @override
  Future<List<Product>> load() async {
    final out = <Product>[];
    for (final page in pages) {
      final uri = Uri.parse(page.url);
      if (!await _allowed(uri)) {
        throw Exception('${page.store}: robots.txt no permite leer ${uri.path}');
      }
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('${page.store}: HTTP ${res.statusCode}');
      }
      final html = utf8.decode(res.bodyBytes, allowMalformed: true);
      final re = RegExp(
        r'<script[^>]*type=["\x27]application/ld\+json["\x27][^>]*>(.*?)</script>',
        dotAll: true,
        caseSensitive: false,
      );
      final nodes = <Map<String, dynamic>>[];
      for (final m in re.allMatches(html)) {
        try {
          _collect(jsonDecode(m.group(1)!.trim()), nodes);
        } catch (_) {}
      }
      for (final n in nodes) {
        final pr = _toProduct(n, page, uri);
        if (pr != null) out.add(pr);
      }
    }
    return out;
  }

  void _collect(dynamic j, List<Map<String, dynamic>> out) {
    if (j is List) {
      for (final e in j) {
        _collect(e, out);
      }
    } else if (j is Map<String, dynamic>) {
      final t = j['@type'];
      final isProduct = t == 'Product' || (t is List && t.contains('Product'));
      if (isProduct) out.add(j);
      for (final key in ['@graph', 'itemListElement', 'item', 'mainEntity']) {
        if (j[key] != null) _collect(j[key], out);
      }
    }
  }

  Product? _toProduct(Map<String, dynamic> n, SourceLine page, Uri base) {
    final name = n['name']?.toString();
    if (name == null || name.isEmpty) return null;
    final category = inferCategory('$name ${n['category'] ?? ''}');
    if (category == null) return null;

    dynamic offers = n['offers'];
    if (offers is List && offers.isNotEmpty) offers = offers.first;
    final price = offers is Map
        ? parsePrice((offers['price'] ?? offers['lowPrice'])?.toString())
        : null;
    if (price == null) return null;

    dynamic img = n['image'];
    if (img is List && img.isNotEmpty) img = img.first;
    if (img is Map) img = img['url'];

    final url = (n['url'] ?? (offers is Map ? offers['url'] : null))?.toString();
    final link = url == null ? base.toString() : base.resolve(url).toString();
    final txt = '$name ${n['category'] ?? ''} ${n['description'] ?? ''}';

    return Product(
      id: 'web:${page.store}:${link.hashCode}',
      store: page.store,
      name: name,
      category: category,
      color: normalizeColor('${n['color'] ?? name}'),
      price: price,
      imageUrl: img is String ? base.resolve(img).toString() : null,
      url: link,
      styles: inferStyles(txt),
      season: inferSeason(txt),
      source: 'web',
    );
  }
}

// ───────────────────────── repositorio ─────────────────────────

class CatalogResult {
  final List<Product> products;
  final List<String> warnings;
  CatalogResult(this.products, this.warnings);
}

class CatalogRepository {
  final AppSettings settings;
  final MyCatalogStore mine;
  CatalogRepository(this.settings, this.mine);

  Future<CatalogResult> load() async {
    final providers = <CatalogProvider>[
      if (settings.useSample) SampleProvider(),
      if (settings.useAffiliate) AffiliateFeedProvider(parseSourceLines(settings.affiliateFeeds)),
      if (settings.useScraper) ScraperProvider(parseSourceLines(settings.scraperPages)),
    ];
    final products = <Product>[...mine.items];
    final warnings = <String>[];
    for (final p in providers) {
      try {
        final l = await p.load();
        products.addAll(l);
        if (l.isEmpty) warnings.add('${p.name}: no devolvió prendas');
      } catch (e) {
        warnings.add('${p.name}: $e');
      }
    }
    return CatalogResult(products, warnings);
  }
}
