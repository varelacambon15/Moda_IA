import 'ai_service.dart';
import 'catalog.dart';
import 'settings.dart';

class AppState {
  final settings = AppSettings();
  final favorites = FavoritesStore();
  late final CatalogRepository repo = CatalogRepository(settings);
  late final AiService ai = AiService(settings);

  Future<void> init() async {
    await settings.load();
    await favorites.load();
  }
}
