# Looks IA — contexto para Claude Code

App Android en Flutter que genera looks con ropa de tiendas españolas (Zara, Mango, Bershka…).
El usuario es Alejandro; escribe siempre en español de España (tuteo, nunca voseo).

## Estado
- Código escrito pero NUNCA compilado ni analizado (el entorno donde se creó no tenía Flutter).
  Primera tarea: generar el proyecto Android, `flutter analyze` y `flutter build apk`, y corregir errores.
- Pasos: ver README.md (`flutter create --platforms=android --org com.alejandro --project-name looks_ia .`,
  `python tools/patch_manifest.py`, `flutter pub get`).

## Decisiones tomadas por el usuario
- Flutter. Catálogo con 3 fuentes a la vez: ejemplo integrado, feeds de afiliación (CSV Awin/Tradedoubler)
  y lectura de webs (JSON-LD, respeta robots.txt, apagada por defecto).
- Looks por reglas de estilo + IA. APIs gratuitas con respaldo entre proveedores
  (Groq, Gemini, OpenRouter, Cerebras, Mistral; compatibles OpenAI). Las claves las pone él en Ajustes.

## Arquitectura (lib/)
- models.dart: Product, Outfit, StyleRequest, enums
- catalog.dart: SampleProvider, AffiliateFeedProvider, ScraperProvider, CatalogRepository
- style_engine.dart: generación y puntuación de looks
- ai_service.dart: cliente IA con fallback; describeOutfit y parseRequest
- settings.dart: ajustes y favoritos (shared_preferences)
- ui/: home, favoritos, ajustes, tarjetas de look

## Pendiente / ideas
- Compilar y probar en móvil; imágenes reales de producto con feeds
- Enlaces de ejemplo son búsquedas aproximadas de cada tienda (verificar patrones de URL)
- Tests del StyleEngine y del parser CSV; icono y nombre del paquete definitivos
