import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'outfit_widgets.dart';

class FavoritesPage extends StatelessWidget {
  final AppState app;
  const FavoritesPage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAVORITOS')),
      body: ListenableBuilder(
        listenable: app.favorites,
        builder: (_, __) {
          final list = app.favorites.outfits;
          if (list.isEmpty) {
            return const Center(child: Text('Aún no has guardado ningún look'));
          }
          return ListView(
            children: [
              for (final o in list)
                OutfitCard(
                  app: app,
                  outfit: o,
                  request: StyleRequest(
                    occasion: Occasion.casual,
                    season: Season.all,
                    budget: o.total,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
