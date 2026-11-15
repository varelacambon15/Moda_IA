import 'dart:io';

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
  final double size; // ancho
  final double aspect; // alto / ancho
  const ProductImage({super.key, required this.product, this.size = 90, this.aspect = 1});

  @override
  Widget build(BuildContext context) {
    final w = size, h = size * aspect;
    // Sin foto: fondo gris claro con un toque del color de la prenda, como una ficha de tienda.
    final tint = Color.lerp(const Color(0xFFF1F1F1), colorOf(product.color), 0.22)!;
    final placeholder = Container(
      width: w,
      height: h,
      color: tint,
      alignment: Alignment.center,
      child: Icon(iconOf(product.category), color: Colors.black38, size: w * 0.3),
    );
    final url = product.imageUrl;
    if (url == null) return placeholder;
    return url.startsWith('/')
        ? Image.file(File(url),
            width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder)
        : Image.network(url,
            width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
  }
}

class ProductTile extends StatelessWidget {
  final Product product;
  final double width;
  const ProductTile({super.key, required this.product, this.width = 132});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => openUrl(context, product.url),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(product: product, size: width, aspect: 4 / 3),
            const SizedBox(height: 6),
            Text(product.name.toUpperCase(),
                style: t.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${product.price.toStringAsFixed(2)} EUR', style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}
