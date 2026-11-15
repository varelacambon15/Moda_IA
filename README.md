# Looks IA

App Android (Flutter) que genera looks combinando ropa de tiendas españolas
(Zara, Mango, Bershka, Pull&Bear, Stradivarius, H&M, Massimo Dutti…).

## Puesta en marcha

Requisitos: Flutter SDK 3.22 o superior, Android SDK y Python 3.

```bash
cd looks_ia
flutter create --platforms=android --org com.alejandro --project-name looks_ia .
python tools/patch_manifest.py
flutter pub get
flutter run            # o: flutter build apk --release
```

`flutter create .` no sobrescribe `lib/` ni `pubspec.yaml`. El script parchea el
`AndroidManifest.xml` (permiso INTERNET y enlaces https).

## Fuentes de catálogo (Ajustes)

1. **Ejemplo**: ~50 prendas integradas, sin conexión. Los precios son orientativos
   y los enlaces abren la búsqueda de la tienda.
2. **Feeds de afiliación**: CSV de Awin/Tradedoubler. Una línea por feed: `Zara|https://...csv`.
3. **Lectura de webs**: JSON-LD (schema.org) de páginas públicas, respetando robots.txt.
   Una línea por página: `Mango|https://...`.

## IA gratuita (Ajustes)

Groq, Google Gemini, OpenRouter, Cerebras y Mistral (todas con API compatible OpenAI).
Pega la clave de las que quieras; la app las prueba por orden hasta que una responde.
La IA interpreta peticiones libres ("look para una boda en junio, 150 €") y explica cada look.

## Estructura

- `lib/style_engine.dart`: reglas de estilo (ocasión, temporada, color, tiendas, presupuesto)
- `lib/catalog.dart`: los tres proveedores de catálogo
- `lib/ai_service.dart`: cliente de IA con respaldo entre proveedores
- `lib/ui/`: pantallas
