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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OutfitDetailPage(app: app, outfit: outfit, request: request),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${outfit.total.toStringAsFixed(2)} €',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${outfit.score.round()}% afinidad'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: app.favorites,
                    builder: (_, __) => IconButton(
                      icon: Icon(app.favorites.isFavorite(outfit)
                          ? Icons.favorite
                          : Icons.favorite_border),
                      onPressed: () => app.favorites.toggle(outfit),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: outfit.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => ProductTile(product: outfit.items[i]),
                ),
              ),
            ],
          ),
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
        title: Text('Look · ${o.total.toStringAsFixed(2)} €'),
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
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _advice == null
                  ? const Text('Añade una clave de API gratuita en Ajustes para recibir consejos de estilista con IA.')
                  : FutureBuilder<String>(
                      future: _advice,
                      builder: (_, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Row(children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
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
          ),
          const SizedBox(height: 8),
          for (final p in o.items)
            Card(
              child: ListTile(
                leading: ProductImage(product: p, size: 56),
                title: Text(p.name),
                subtitle: Text('${p.store} · ${p.category.label}\n${p.price.toStringAsFixed(2)} €'),
                isThreeLine: true,
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openUrl(context, p.url),
              ),
            ),
        ],
      ),
    );
  }
}
