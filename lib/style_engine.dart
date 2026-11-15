import 'dart:math';

import 'models.dart';

const _neutrals = {'negro', 'blanco', 'gris', 'beige', 'marino', 'vaquero', 'camel', 'marrón', 'caqui', 'otro'};
const _goodPairs = {
  'azul|marrón', 'marrón|verde', 'burdeos|rosa', 'azul|rojo',
  'amarillo|azul', 'burdeos|verde', 'rosa|verde',
};

/// Motor de reglas: combina prendas por categoría, estilo, temporada,
/// armonía de color, variedad de tiendas y presupuesto.
class StyleEngine {
  static List<Outfit> generate(List<Product> all, StyleRequest req,
      {int count = 6, int? seed}) {
    final rnd = Random(seed);
    final catalog = req.stores.isEmpty
        ? all
        : all.where((p) => req.stores.contains(p.store)).toList();

    List<Product> pool(Category c) {
      final inCat = catalog
          .where((p) =>
              p.category == c &&
              (p.season == Season.all || req.season == Season.all || p.season == req.season))
          .toList();
      final strict =
          inCat.where((p) => p.styles.any(req.occasion.styles.contains)).toList();
      return strict.isNotEmpty ? strict : inCat;
    }

    final tops = pool(Category.top);
    final bottoms = pool(Category.bottom);
    final dresses = pool(Category.dress);
    final outer = pool(Category.outerwear);
    final shoes = pool(Category.shoes);
    final acc = pool(Category.accessory);

    T pick<T>(List<T> l) => l[rnd.nextInt(l.length)];

    final found = <String, Outfit>{};
    for (var i = 0; i < 500; i++) {
      final items = <Product>[];
      final canSeparates = tops.isNotEmpty && bottoms.isNotEmpty;
      final useDress = dresses.isNotEmpty && (!canSeparates || rnd.nextDouble() < 0.3);
      if (useDress) {
        items.add(pick(dresses));
      } else if (canSeparates) {
        items..add(pick(tops))..add(pick(bottoms));
      } else {
        continue;
      }
      if (shoes.isNotEmpty) items.add(pick(shoes));
      final wantOuter = req.season == Season.cold ||
          (req.season == Season.all && rnd.nextDouble() < 0.4);
      if (wantOuter && outer.isNotEmpty) items.add(pick(outer));
      if (acc.isNotEmpty && rnd.nextDouble() < 0.5) items.add(pick(acc));

      if (items.length < 3) continue;
      final total = items.fold(0.0, (s, p) => s + p.price);
      if (total > req.budget) continue;

      final o = Outfit(items, _score(items, total, req, rnd));
      found.putIfAbsent(o.key, () => o);
    }

    final sorted = found.values.toList()..sort((a, b) => b.score.compareTo(a.score));

    // Variedad: ninguna prenda en más de 2 looks.
    final used = <String, int>{};
    final result = <Outfit>[];
    for (final o in sorted) {
      if (o.items.any((p) => (used[p.id] ?? 0) >= 2)) continue;
      for (final p in o.items) {
        used[p.id] = (used[p.id] ?? 0) + 1;
      }
      result.add(o);
      if (result.length >= count) break;
    }
    return result;
  }

  static double _score(List<Product> items, double total, StyleRequest r, Random rnd) {
    var s = 0.0;

    // Estilo (0-4)
    final styleHits =
        items.where((p) => p.styles.any(r.occasion.styles.contains)).length;
    s += 4 * styleHits / items.length;

    // Color (-5..3)
    final colors = items.map((p) => p.color).toSet().where((c) => !_neutrals.contains(c)).toList()
      ..sort();
    if (colors.isEmpty) {
      s += 2;
    } else if (colors.length == 1) {
      s += 3;
    } else if (colors.length == 2) {
      s += _goodPairs.contains(colors.join('|')) ? 1 : -3;
    } else {
      s -= 5;
    }

    // Variedad de tiendas (0-1.5)
    final stores = items.map((p) => p.store).toSet().length;
    s += stores >= 3 ? 1.5 : (stores == 2 ? 1 : 0);

    // Presupuesto bien aprovechado (0-1.5)
    final ratio = total / r.budget;
    if (ratio >= 0.5 && ratio <= 1) s += 1.5;

    // Un toque de azar para no repetir siempre lo mismo.
    s += rnd.nextDouble();

    return ((s + 5) / 11 * 100).clamp(40, 99).toDouble();
  }
}
