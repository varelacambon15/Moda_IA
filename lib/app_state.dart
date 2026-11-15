import 'ai_service.dart';
import 'catalog.dart';
import 'my_catalog.dart';
import 'settings.dart';

class AppState {
  final settings = AppSettings();
  final favorites = FavoritesStore();
  final mine = MyCatalogStore();
  late final CatalogRepository repo = CatalogRepository(settings, mine);
  late final AiService ai = AiService(settings);

  Future<void> init() async {
    await settings.load();
    await favorites.load();
    await mine.load();
  }
}
