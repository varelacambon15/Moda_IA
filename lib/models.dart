enum Category { top, bottom, dress, outerwear, shoes, accessory }

extension CategoryX on Category {
  String get label => switch (this) {
        Category.top => 'Parte de arriba',
        Category.bottom => 'Parte de abajo',
        Category.dress => 'Vestido',
        Category.outerwear => 'Abrigo / chaqueta',
        Category.shoes => 'Calzado',
        Category.accessory => 'Complemento',
      };
}

enum Season { all, warm, cold }

extension SeasonX on Season {
  String get label => switch (this) {
        Season.all => 'Todo el año',
        Season.warm => 'Calor',
        Season.cold => 'Frío',
      };

  static Season fromMonth(int month) {
    if (month >= 11 || month <= 3) return Season.cold;
    if (month >= 6 && month <= 9) return Season.warm;
    return Season.all;
  }
}

enum Occasion { casual, oficina, fiesta, cita, deporte, evento }

extension OccasionX on Occasion {
  String get label => switch (this) {
        Occasion.casual => 'Casual',
        Occasion.oficina => 'Oficina',
        Occasion.fiesta => 'Fiesta',
        Occasion.cita => 'Cita',
        Occasion.deporte => 'Deporte',
        Occasion.evento => 'Evento / boda',
      };

  /// Estilos de prenda que encajan con la ocasión.
  Set<String> get styles => switch (this) {
        Occasion.casual => {'casual', 'urbano'},
        Occasion.oficina => {'elegante', 'casual'},
        Occasion.fiesta => {'fiesta', 'urbano', 'elegante'},
        Occasion.cita => {'elegante', 'fiesta', 'casual'},
        Occasion.deporte => {'deportivo'},
        Occasion.evento => {'elegante', 'fiesta'},
      };
}

class Product {
  final String id;
  final String store;
  final String name;
  final Category category;
  final String color;
  final double price;
  final String? imageUrl;
  final String url;
  final Set<String> styles;
  final Season season;
  final String source; // ejemplo | afiliado | web

  const Product({
    required this.id,
    required this.store,
    required this.name,
    required this.category,
    required this.color,
    required this.price,
    required this.url,
    required this.styles,
    this.imageUrl,
    this.season = Season.all,
    this.source = 'ejemplo',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'store': store,
        'name': name,
        'category': category.name,
        'color': color,
        'price': price,
        'imageUrl': imageUrl,
        'url': url,
        'styles': styles.toList(),
        'season': season.name,
        'source': source,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        store: j['store'] as String,
        name: j['name'] as String,
        category: Category.values.byName(j['category'] as String),
        color: j['color'] as String,
        price: (j['price'] as num).toDouble(),
        imageUrl: j['imageUrl'] as String?,
        url: j['url'] as String,
        styles: ((j['styles'] as List).cast<String>()).toSet(),
        season: Season.values.byName(j['season'] as String),
        source: (j['source'] as String?) ?? 'ejemplo',
      );
}

class StyleRequest {
  final Occasion occasion;
  final Season season;
  final double budget;
  final Set<String> stores; // vacío = todas

  const StyleRequest({
    required this.occasion,
    required this.season,
    required this.budget,
    this.stores = const {},
  });
}

class Outfit {
  final List<Product> items;
  final double score; // 0-100

  const Outfit(this.items, this.score);

  double get total => items.fold(0.0, (s, p) => s + p.price);
  String get key => (items.map((p) => p.id).toList()..sort()).join('|');
  Set<String> get stores => items.map((p) => p.store).toSet();

  Map<String, dynamic> toJson() => {
        'items': items.map((p) => p.toJson()).toList(),
        'score': score,
      };

  factory Outfit.fromJson(Map<String, dynamic> j) => Outfit(
        (j['items'] as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(),
        (j['score'] as num).toDouble(),
      );
}
