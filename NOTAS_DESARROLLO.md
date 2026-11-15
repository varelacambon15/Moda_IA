# Notas de desarrollo (para continuar en otro chat)

## Hecho
- Proyecto Android generado con `flutter create` (carpeta `android/`), manifest parcheado, `flutter analyze` sin errores.
- Se eliminó `test/widget_test.dart` (plantilla que no compilaba con la app).
- Ajustes: la lectura de webs trae precargadas páginas de categoría de Zara, Mango, Bershka, Pull&Bear,
  Stradivarius, H&M y Massimo Dutti (`defaultScraperPages` en `lib/settings.dart`); sigue apagada por defecto.
  Los feeds de afiliación no se pueden precargar: requieren cuenta propia en Awin/Tradedoubler.
- Nueva pestaña **Catálogo** (`lib/ui/catalog_page.dart`, `lib/my_catalog.dart`): prendas guardadas por el usuario
  (shared_preferences + fotos copiadas a la carpeta de la app). Entran en la generación de looks (`CatalogRepository`).
  Cuatro formas de añadir: imagen de galería, enlace (JSON-LD/Open Graph), foto a la prenda y foto a la etiqueta.
  Las fotos se leen con IA con visión (`AiService.readGarment`; modelos en `AiPreset.visionModel`:
  Groq, Gemini, OpenRouter, Mistral; Cerebras no tiene visión). Sin clave, se rellena a mano.
- Claves de IA: `lib/secrets.dart` (en `.gitignore`, NO está en el repo). Plantilla en `lib/secrets.example.dart`.
  Hay que crearlo en cada clone; sin él no compila. Preconfiguradas: groq, gemini, openrouter.
  La clave de Gemini tiene formato `AQ.…` (no el habitual `AIza…`): sin verificar.

## Pendiente
- **Compilar la APK**: en el entorno de la nube, `flutter build apk --release` fallaba por red (Maven Central
  limita peticiones y el proxy corta conexiones). Probar en una máquina normal:
  `flutter pub get && flutter build apk --release`.
  Requiere Flutter 3.35.x (la 3.50 pide Kotlin 2.3.20 que no está publicado en Maven).
- Probar en móvil: cámara/galería, lectura por IA, importación por enlace.
- Verificar patrones de URL de las tiendas; tests del StyleEngine y del parser CSV; icono y nombre definitivos.
- Las claves han circulado por chat: conviene regenerarlas cuando acabe el desarrollo.

## APK compilada (entorno en la nube)
- `flutter build apk --release` funcionó con Flutter 3.35.7, Android SDK 35 y un espejo local de Maven con reintentos
  (Maven Central y el proxy de la nube devolvían 404/429 falsos). Tardó ~75 min la primera vez; con caché, mucho menos.
- La APK está firmada con la clave de depuración (no apta para Play Store). Instálala permitiendo orígenes desconocidos.

## Rediseño estilo tienda de moda (Zara)
- Tema en `zaraTheme()` (`lib/main.dart`): blanco/negro, tipografía fina, sin bordes redondeados, títulos en mayúsculas.
- Pantalla principal con ocasión en texto subrayado, botón negro; looks como tiras de fichas verticales;
  detalle de look con imagen a ancho completo; catálogo en rejilla de 2 columnas (pulsación larga = quitar).
- Sin foto de producto se muestra un fondo gris claro con icono: para el aspecto real hacen falta imágenes (feeds o catálogo propio).
