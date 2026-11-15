import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../my_catalog.dart';
import 'widgets.dart';

enum AddMode { imagen, enlace, prenda, etiqueta }

class CatalogPage extends StatelessWidget {
  final AppState app;
  const CatalogPage({super.key, required this.app});

  void _add(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget opt(IconData i, String t, String s, AddMode m) => ListTile(
              leading: Icon(i),
              title: Text(t),
              subtitle: Text(s),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddItemPage(app: app, mode: m)));
              },
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            opt(Icons.image_outlined, 'Desde una imagen', 'Elige una foto de la galería', AddMode.imagen),
            opt(Icons.link, 'Desde un enlace', 'Pega la página del producto', AddMode.enlace),
            opt(Icons.photo_camera_outlined, 'Foto a la prenda', 'Hazla en la tienda', AddMode.prenda),
            opt(Icons.sell_outlined, 'Foto a la etiqueta', 'Lee marca, precio y referencia', AddMode.etiqueta),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.mine,
      builder: (context, _) {
        final items = app.mine.items;
        return Scaffold(
          appBar: AppBar(title: const Text('CATÁLOGO')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('AÑADIR', style: TextStyle(letterSpacing: 2, fontSize: 12)),
          ),
          body: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aún no has guardado prendas.\nAñade las que te gusten y se usarán al generar looks.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 88),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 2,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final t = Theme.of(context).textTheme;
                    return InkWell(
                      onTap: p.url.isEmpty ? null : () => openUrl(context, p.url),
                      onLongPress: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: const RoundedRectangleBorder(),
                            title: const Text('Quitar del catálogo'),
                            content: Text(p.name),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('QUITAR')),
                            ],
                          ),
                        );
                        if (ok == true) app.mine.remove(p);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (_, c) =>
                                  ProductImage(product: p, size: c.maxWidth, aspect: c.maxHeight / c.maxWidth),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: Text(p.name.toUpperCase(),
                                style: t.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                            child: Text('${p.store} · ${p.price.toStringAsFixed(2)} EUR', style: t.bodySmall),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class AddItemPage extends StatefulWidget {
  final AppState app;
  final AddMode mode;
  const AddItemPage({super.key, required this.app, required this.mode});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final name = TextEditingController();
  final store = TextEditingController();
  final price = TextEditingController();
  final link = TextEditingController();
  Category category = Category.top;
  String color = 'negro';
  Season season = Season.all;
  String style = 'casual';
  String? imagePath; // fichero local
  String? imageUrl; // imagen remota (enlace)
  bool busy = false;
  String? note;

  static const colors = [
    'negro', 'blanco', 'gris', 'beige', 'marino', 'azul', 'vaquero', 'rojo',
    'verde', 'caqui', 'marrón', 'rosa', 'burdeos', 'amarillo', 'camel'
  ];
  static const styles = ['casual', 'elegante', 'urbano', 'fiesta', 'deportivo'];

  AddMode get mode => widget.mode;

  @override
  void initState() {
    super.initState();
    if (mode == AddMode.imagen || mode == AddMode.prenda || mode == AddMode.etiqueta) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
    }
  }

  Future<void> _pick() async {
    final src = mode == AddMode.imagen ? ImageSource.gallery : ImageSource.camera;
    try {
      final f = await ImagePicker().pickImage(source: src, maxWidth: 1280, imageQuality: 80);
      if (f == null) return;
      setState(() {
        imagePath = f.path;
        busy = true;
        note = null;
      });
      final ai = widget.app.ai;
      if (!ai.visionAvailable) {
        setState(() {
          busy = false;
          note = 'Para rellenar los datos solos, añade una clave de Groq, Gemini, OpenRouter o Mistral en Ajustes. Rellénalos a mano.';
        });
        return;
      }
      final d = await ai.readGarment(await File(f.path).readAsBytes(),
          mode == AddMode.etiqueta ? 'etiqueta' : 'prenda');
      if (!mounted) return;
      setState(() {
        busy = false;
        if (d == null) {
          note = 'La IA no pudo leer la foto. Rellena los datos a mano.';
        } else {
          _fill(d);
          note = 'Datos rellenados por IA: revísalos antes de guardar.';
        }
      });
    } catch (e) {
      if (mounted) setState(() { busy = false; note = 'No se pudo usar la cámara/galería: $e'; });
    }
  }

  void _fill(Map<String, dynamic> d) {
    final n = d['name']?.toString() ?? '';
    if (n.isNotEmpty) name.text = n;
    final s = d['store']?.toString() ?? '';
    if (s.isNotEmpty) store.text = s;
    final pr = d['price'];
    if (pr is num) price.text = pr.toString();
    category = Category.values.asNameMap()[d['category']] ?? category;
    final c = d['color']?.toString();
    if (c != null && colors.contains(c)) color = c;
    final st = d['style']?.toString();
    if (st != null && styles.contains(st)) style = st;
    season = Season.values.asNameMap()[d['season']] ?? season;
  }

  Future<void> _readLink() async {
    if (link.text.trim().isEmpty) return;
    setState(() { busy = true; note = null; });
    try {
      final d = await readProductLink(link.text);
      if (!mounted) return;
      setState(() {
        if (d.name != null) name.text = d.name!;
        if (d.store != null) store.text = d.store!;
        if (d.price != null) price.text = d.price!.toString();
        if (d.color != null && colors.contains(d.color)) color = d.color!;
        category = Category.values.asNameMap()[d.category] ?? category;
        imageUrl = d.image;
        note = 'Datos leídos de la página: revísalos antes de guardar.';
      });
    } catch (e) {
      if (mounted) setState(() => note = '$e. Rellena los datos a mano.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    final p = double.tryParse(price.text.replaceAll(',', '.'));
    if (name.text.trim().isEmpty || p == null) {
      setState(() => note = 'Indica al menos el nombre y el precio.');
      return;
    }
    String? img = imageUrl;
    if (imagePath != null) img = await widget.app.mine.keepImage(imagePath!);
    final id = 'mio:${DateTime.now().microsecondsSinceEpoch}';
    await widget.app.mine.add(Product(
      id: id,
      store: store.text.trim().isEmpty ? 'Otra' : store.text.trim(),
      name: name.text.trim(),
      category: category,
      color: color,
      price: p,
      url: link.text.trim(),
      imageUrl: img,
      styles: {style},
      season: season,
      source: 'mío',
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      AddMode.imagen => 'Desde una imagen',
      AddMode.enlace => 'Desde un enlace',
      AddMode.prenda => 'Foto a la prenda',
      AddMode.etiqueta => 'Foto a la etiqueta',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mode == AddMode.enlace) ...[
            TextField(
              controller: link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Enlace de la prenda',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.download), onPressed: _readLink),
              ),
              onSubmitted: (_) => _readLink(),
            ),
            const SizedBox(height: 12),
          ] else
            Row(children: [
              if (imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(imagePath!), width: 120, height: 120, fit: BoxFit.cover),
                ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : _pick,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(imagePath == null ? 'Elegir foto' : 'Cambiar foto'),
              ),
            ]),
          if (imageUrl != null && mode == AddMode.enlace)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl!, width: 120, height: 120, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            ),
          if (busy) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
          if (note != null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(note!)),
          const SizedBox(height: 8),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: store, decoration: const InputDecoration(labelText: 'Tienda / marca', border: OutlineInputBorder()))),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio €', border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<Category>(
            value: category,
            decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
            items: [for (final c in Category.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: (v) => setState(() => category = v!),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: color,
                decoration: const InputDecoration(labelText: 'Color', border: OutlineInputBorder()),
                items: [for (final c in colors) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => color = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: style,
                decoration: const InputDecoration(labelText: 'Estilo', border: OutlineInputBorder()),
                items: [for (final s in styles) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setState(() => style = v!),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<Season>(
            value: season,
            decoration: const InputDecoration(labelText: 'Temporada', border: OutlineInputBorder()),
            items: [for (final s in Season.values) DropdownMenuItem(value: s, child: Text(s.label))],
            onChanged: (v) => setState(() => season = v!),
          ),
          if (mode != AddMode.enlace) ...[
            const SizedBox(height: 12),
            TextField(controller: link, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Enlace (opcional)', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save), label: const Text('Guardar en mi catálogo')),
        ],
      ),
    );
  }
}
