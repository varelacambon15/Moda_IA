import 'package:flutter/material.dart';

import '../app_state.dart';
import '../settings.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Fuentes de catálogo', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              title: const Text('Catálogo de ejemplo'),
              subtitle: const Text('Prendas de muestra de Zara, Mango, Bershka, H&M… Funciona sin conexión.'),
              value: s.useSample,
              onChanged: (v) => s.update(() => s.useSample = v),
            ),
            SwitchListTile(
              title: const Text('Feeds de afiliación (Awin, Tradedoubler…)'),
              subtitle: const Text('Catálogos oficiales en CSV, con enlaces de compra.'),
              value: s.useAffiliate,
              onChanged: (v) => s.update(() => s.useAffiliate = v),
            ),
            if (s.useAffiliate)
              _Field(
                label: 'Feeds (una línea por feed: tienda|url)',
                value: s.affiliateFeeds,
                lines: 4,
                onChanged: (v) => s.update(() => s.affiliateFeeds = v),
              ),
            SwitchListTile(
              title: const Text('Lectura de webs (scraping)'),
              subtitle: const Text('Lee datos estructurados de páginas públicas y respeta robots.txt. '
                  'Muchas tiendas lo prohíben en sus términos de uso: úsalo bajo tu responsabilidad.'),
              value: s.useScraper,
              onChanged: (v) => s.update(() => s.useScraper = v),
            ),
            if (s.useScraper)
              _Field(
                label: 'Páginas (una línea por página: tienda|url)',
                value: s.scraperPages,
                lines: 4,
                onChanged: (v) => s.update(() => s.scraperPages = v),
              ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.refresh),
              label: const Text('Probar catálogo'),
              onPressed: () async {
                final r = await app.repo.load();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${r.products.length} prendas cargadas'
                      '${r.warnings.isEmpty ? '' : '\n${r.warnings.join('\n')}'}'),
                ));
              },
            ),
            const Divider(height: 32),
            Text('IA (APIs gratuitas)', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              title: const Text('Usar IA'),
              subtitle: const Text('Pega la clave de uno o varios proveedores. Si uno falla o se queda '
                  'sin cuota, la app prueba el siguiente por orden.'),
              value: s.aiEnabled,
              onChanged: (v) => s.update(() => s.aiEnabled = v),
            ),
            for (final p in aiPresets)
              ExpansionTile(
                title: Text(p.name),
                subtitle: Text(s.keyOf(p).isEmpty ? 'Sin clave' : 'Clave guardada'),
                leading: Icon(s.keyOf(p).isEmpty ? Icons.key_off : Icons.key),
                children: [
                  _Field(
                    label: 'Clave de API',
                    value: s.keyOf(p),
                    obscure: true,
                    onChanged: (v) => s.update(() => s.aiKeys[p.id] = v.trim()),
                  ),
                  _Field(
                    label: 'Modelo',
                    value: s.modelOf(p),
                    onChanged: (v) => s.update(() => s.aiModels[p.id] = v.trim()),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Conseguir clave gratis'),
                      onPressed: () => openUrl(context, p.keyUrl),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final int lines;
  final bool obscure;
  final ValueChanged<String> onChanged;
  const _Field({
    required this.label,
    required this.value,
    required this.onChanged,
    this.lines = 1,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: value,
        minLines: lines,
        maxLines: obscure ? 1 : lines,
        obscureText: obscure,
        autocorrect: false,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }
}
