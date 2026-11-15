import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../style_engine.dart';
import 'outfit_widgets.dart';

class HomePage extends StatefulWidget {
  final AppState app;
  const HomePage({super.key, required this.app});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Occasion occasion = Occasion.casual;
  Season season = SeasonX.fromMonth(DateTime.now().month);
  double budget = 200;
  Set<String> stores = {};
  List<String> allStores = [];
  List<Outfit> outfits = [];
  bool loading = false;
  String? message;
  final aiCtrl = TextEditingController();

  AppState get app => widget.app;

  StyleRequest get request =>
      StyleRequest(occasion: occasion, season: season, budget: budget, stores: stores);

  @override
  void initState() {
    super.initState();
    app.settings.addListener(_onSettings);
    _refreshStores();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    app.settings.removeListener(_onSettings);
    aiCtrl.dispose();
    super.dispose();
  }

  Timer? _debounce;

  void _onSettings() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _refreshStores);
  }

  Future<void> _refreshStores() async {
    final r = await app.repo.load();
    if (!mounted) return;
    setState(() {
      allStores = (r.products.map((p) => p.store).toSet().toList()..sort());
      stores = stores.where(allStores.contains).toSet();
    });
  }

  Future<void> generate([StyleRequest? req]) async {
    setState(() {
      loading = true;
      message = null;
    });
    final r = await app.repo.load();
    final rq = req ?? request;
    final result = StyleEngine.generate(
      r.products,
      rq,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      outfits = result;
      allStores = (r.products.map((p) => p.store).toSet().toList()..sort());
      message = r.products.isEmpty
          ? 'No hay prendas. Activa alguna fuente en Ajustes.\n${r.warnings.join('\n')}'
          : result.isEmpty
              ? 'No he encontrado looks con ese presupuesto o esas tiendas. Prueba a subir el presupuesto.'
              : (r.warnings.isEmpty ? null : r.warnings.join('\n'));
    });
  }

  Future<void> askAi() async {
    final text = aiCtrl.text.trim();
    if (text.isEmpty) return;
    if (!app.ai.available) {
      setState(() => message = 'Añade una clave de API gratuita en Ajustes para usar la IA.');
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final req = await app.ai.parseRequest(text, request, allStores);
      if (req == null) {
        setState(() {
          loading = false;
          message = 'No he entendido la petición. Prueba con otras palabras.';
        });
        return;
      }
      setState(() {
        occasion = req.occasion;
        season = req.season;
        budget = req.budget.clamp(40, 600).toDouble();
        stores = {...req.stores};
      });
      await generate(req);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        message = 'Error con la IA: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Looks IA')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: aiCtrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => askAi(),
              decoration: InputDecoration(
                hintText: 'Pídeselo a la IA: "look para una boda en junio, 150 €"',
                prefixIcon: const Icon(Icons.auto_awesome),
                suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: askAi),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Ocasión'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final o in Occasion.values)
                  ChoiceChip(
                    label: Text(o.label),
                    selected: occasion == o,
                    onSelected: (_) => setState(() => occasion = o),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<Season>(
              segments: [
                for (final s in Season.values) ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {season},
              onSelectionChanged: (s) => setState(() => season = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Presupuesto máximo: ${budget.round()} €'),
          ),
          Slider(
            value: budget,
            min: 40,
            max: 600,
            divisions: 56,
            label: '${budget.round()} €',
            onChanged: (v) => setState(() => budget = v),
          ),
          if (allStores.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text('Tiendas (ninguna = todas)'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final s in allStores)
                    FilterChip(
                      label: Text(s),
                      selected: stores.contains(s),
                      onSelected: (v) => setState(() => v ? stores.add(s) : stores.remove(s)),
                    ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: loading ? null : () => generate(),
              icon: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_fix_high),
              label: const Text('Generar looks'),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          for (final o in outfits) OutfitCard(app: app, outfit: o, request: request),
        ],
      ),
    );
  }
}
