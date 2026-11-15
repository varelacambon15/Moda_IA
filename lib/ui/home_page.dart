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

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
        child: Text(t, style: Theme.of(context).textTheme.labelSmall),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('LOOKS IA')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: aiCtrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => askAi(),
              style: t.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Cuéntale a la IA qué buscas: boda en junio, 150 €',
                hintStyle: t.bodySmall?.copyWith(color: Colors.black45),
                prefixIcon: const Icon(Icons.auto_awesome, size: 18),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward, size: 18), onPressed: askAi),
              ),
            ),
          ),
          _label('OCASIÓN'),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final o in Occasion.values)
                  GestureDetector(
                    onTap: () => setState(() => occasion = o),
                    child: Container(
                      margin: const EdgeInsets.only(right: 22),
                      padding: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: occasion == o ? Colors.black : Colors.transparent, width: 1.5),
                        ),
                      ),
                      child: Text(
                        o.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: occasion == o ? FontWeight.w600 : FontWeight.w300,
                          color: occasion == o ? Colors.black : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _label('TEMPORADA'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<Season>(
              showSelectedIcon: false,
              segments: [
                for (final s in Season.values)
                  ButtonSegment(value: s, label: Text(s.label.toUpperCase())),
              ],
              selected: {season},
              onSelectionChanged: (s) => setState(() => season = s.first),
            ),
          ),
          _label('PRESUPUESTO MÁXIMO · ${budget.round()} EUR'),
          Slider(
            value: budget,
            min: 40,
            max: 600,
            divisions: 56,
            onChanged: (v) => setState(() => budget = v),
          ),
          if (allStores.isNotEmpty) ...[
            _label('TIENDAS · NINGUNA = TODAS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in allStores)
                    FilterChip(
                      showCheckmark: false,
                      label: Text(s.toUpperCase()),
                      labelStyle: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: stores.contains(s) ? Colors.white : Colors.black),
                      selected: stores.contains(s),
                      onSelected: (v) => setState(() => v ? stores.add(s) : stores.remove(s)),
                    ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: FilledButton(
              onPressed: loading ? null : () => generate(),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                  : const Text('GENERAR LOOKS'),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(message!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          for (final o in outfits) OutfitCard(app: app, outfit: o, request: request),
        ],
      ),
    );
  }
}
