import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/catalog_page.dart';
import 'ui/favorites_page.dart';
import 'ui/home_page.dart';
import 'ui/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  await app.init();
  runApp(LooksApp(app: app));
}

class LooksApp extends StatelessWidget {
  final AppState app;
  const LooksApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Looks IA',
      debugShowCheckedModeBanner: false,
      theme: zaraTheme(),
      home: Shell(app: app),
    );
  }
}

/// Estilo minimalista de tienda de moda: blanco, negro, tipografía fina y sin bordes redondeados.
ThemeData zaraTheme() {
  const black = Color(0xFF111111);
  const line = Color(0xFFE0E0E0);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: black,
      onPrimary: Colors.white,
      secondary: black,
      surface: Colors.white,
      onSurface: black,
      error: Color(0xFFB00020),
    ),
    scaffoldBackgroundColor: Colors.white,
    dividerColor: line,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: black, displayColor: black).copyWith(
          bodySmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w300, letterSpacing: 0.3),
          bodyMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, letterSpacing: 0.3),
          labelSmall: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1),
          labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          titleMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: black,
      titleTextStyle: TextStyle(
          color: black, fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 62,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(
          size: 22, color: st.contains(WidgetState.selected) ? black : Colors.black45)),
      labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: st.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w300,
          color: st.contains(WidgetState.selected) ? black : Colors.black54)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: black,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: black,
        side: const BorderSide(color: black),
        shape: const RoundedRectangleBorder(),
        textStyle: const TextStyle(fontSize: 12, letterSpacing: 1.5),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: black,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(),
      elevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: UnderlineInputBorder(borderSide: BorderSide(color: black)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: black)),
      labelStyle: TextStyle(fontSize: 12, letterSpacing: 1, color: Colors.black54),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(),
      side: const BorderSide(color: line),
      backgroundColor: Colors.white,
      selectedColor: black,
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 11, letterSpacing: 0.8),
      secondaryLabelStyle: const TextStyle(fontSize: 11, color: Colors.white),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: black,
      inactiveTrackColor: line,
      thumbColor: black,
      trackHeight: 1.5,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(const RoundedRectangleBorder()),
        side: WidgetStateProperty.all(const BorderSide(color: line)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? black : Colors.white),
        foregroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? Colors.white : black),
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, letterSpacing: 1)),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(),
    ),
    listTileTheme: const ListTileThemeData(iconColor: black),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? black : Colors.black26),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
  );
}

class Shell extends StatefulWidget {
  final AppState app;
  const Shell({super.key, required this.app});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(app: widget.app),
      FavoritesPage(app: widget.app),
      CatalogPage(app: widget.app),
      SettingsPage(app: widget.app),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom), label: 'LOOKS'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'FAVORITOS'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'CATÁLOGO'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'AJUSTES'),
        ],
      ),
    );
  }
}
