import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'widgets.dart';

class OutfitCard extends StatelessWidget {
  final AppState app;
  final Outfit outfit;
  final StyleRequest request;
  const OutfitCard({super.key, required this.app, required this.outfit, required this.request});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OutfitDetailPage(app: app, outfit: outfit, request: request),
      )),
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE0E0E0)))),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${outfit.total.toStringAsFixed(2)} EUR', style: t.titleMedium),
                const SizedBox(width: 12),
                Text('${outfit.score.round()}% AFINIDAD', style: t.labelSmall),
                const Spacer(),
                ListenableBuilder(
                  listenable: app.favorites,
                  builder: (_, __) => IconButton(
                    icon: Icon(
                        app.favorites.isFavorite(outfit) ? Icons.favorite : Icons.favorite_border,
                        size: 20),
                    onPressed: () => app.favorites.toggle(outfit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ProductTile(product: outfit.items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OutfitDetailPage extends StatefulWidget {
  final AppState app;
  final Outfit outfit;
  final StyleRequest request;
  const OutfitDetailPage({super.key, required this.app, required this.outfit, required this.request});

  @override
  State<OutfitDetailPage> createState() => _OutfitDetailPageState();
}

class _OutfitDetailPageState extends State<OutfitDetailPage> {
  Future<String>? _advice;

  @override
  void initState() {
    super.initState();
    if (widget.app.ai.available) {
      _advice = widget.app.ai.describeOutfit(widget.outfit, widget.request);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outfit;
    return Scaffold(
      appBar: AppBar(
        title: Text('${o.total.toStringAsFixed(2)} EUR'),
        actions: [
          ListenableBuilder(
            listenable: widget.app.favorites,
            builder: (_, __) => IconButton(
              icon: Icon(widget.app.favorites.isFavorite(o) ? Icons.favorite : Icons.favorite_border),
              onPressed: () => widget.app.favorites.toggle(o),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: const Color(0xFFF6F6F6),
            padding: const EdgeInsets.all(16),
            child: _advice == null
                ? const Text('Añade una clave de API gratuita en Ajustes para recibir consejos de estilista con IA.')
                : FutureBuilder<String>(
                    future: _advice,
                    builder: (_, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
                          SizedBox(width: 12),
                          Text('La IA está pensando…'),
                        ]);
                      }
                      if (snap.hasError) {
                        return Text('No se pudo obtener el consejo de la IA.\n${snap.error}');
                      }
                      return Text(snap.data ?? '');
                    },
                  ),
          ),
          const SizedBox(height: 12),
          for (final p in o.items) ...[
            GestureDetector(
              onTap: () => openUrl(context, p.url),
              child: LayoutBuilder(
                builder: (_, c) => ProductImage(product: p, size: c.maxWidth, aspect: 1.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 3),
                        Text('${p.store} · ${p.category.label}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('${p.price.toStringAsFixed(2)} EUR',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
