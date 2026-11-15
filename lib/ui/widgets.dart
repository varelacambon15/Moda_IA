import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

Future<void> openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }
}

Color colorOf(String name) => switch (name) {
      'negro' => const Color(0xFF212121),
      'blanco' => const Color(0xFFF5F5F5),
      'gris' => const Color(0xFF9E9E9E),
      'beige' => const Color(0xFFD7C4A3),
      'marino' => const Color(0xFF1A2A4F),
      'azul' => const Color(0xFF3F6FB5),
      'vaquero' => const Color(0xFF5C7FA3),
      'rojo' => const Color(0xFFC62828),
      'verde' => const Color(0xFF2E7D32),
      'caqui' => const Color(0xFF8A8458),
      'marrón' => const Color(0xFF6D4C41),
      'rosa' => const Color(0xFFE79AB5),
      'burdeos' => const Color(0xFF6D1A2B),
      'amarillo' => const Color(0xFFF2C94C),
      'camel' => const Color(0xFFB98B5A),
      _ => const Color(0xFFBDBDBD),
    };

IconData iconOf(Category c) => switch (c) {
      Category.top => Icons.checkroom,
      Category.bottom => Icons.straighten,
      Category.dress => Icons.woman,
      Category.outerwear => Icons.dry_cleaning,
      Category.shoes => Icons.directions_walk,
      Category.accessory => Icons.shopping_bag_outlined,
    };

class ProductImage extends StatelessWidget {
  final Product product;
  final double size;
  const ProductImage({super.key, required this.product, this.size = 90});

  @override
  Widget build(BuildContext context) {
    final bg = colorOf(product.color);
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white70
        : Colors.black54;
    final placeholder = Container(
      width: size,
      height: size,
      color: bg,
      child: Icon(iconOf(product.category), color: fg, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: product.imageUrl == null
          ? placeholder
          : Image.network(
              product.imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}

class ProductTile extends StatelessWidget {
  final Product product;
  const ProductTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openUrl(context, product.url),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(product: product, size: 96),
            const SizedBox(height: 4),
            Text(product.store, style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(product.name, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('${product.price.toStringAsFixed(2)} €',
                style: t.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
