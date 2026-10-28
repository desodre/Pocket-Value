import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../watchlist/dashboard_controller.dart';
import 'market_models.dart';

class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key, required this.controller});
  final DashboardController controller;
  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final input = TextEditingController();
  Timer? debounce;
  int request = 0;
  Market market = Market.brazil;
  bool busy = false;
  String? error;
  List<Instrument> results = [];
  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    super.dispose();
  }

  void changed() {
    debounce?.cancel();
    request++;
    setState(() {
      results = [];
      error = null;
      busy = false;
    });
    if (input.text.trim().length < 2) return;
    debounce = Timer(const Duration(milliseconds: 600), search);
  }

  Future<void> search() async {
    final current = ++request;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final found = await widget.controller.api.search(
        input.text.trim(),
        market,
      );
      if (mounted && current == request) setState(() => results = found);
    } on MarketFailure catch (e) {
      if (mounted && current == request) setState(() => error = e.message);
    } on Object {
      if (mounted && current == request) {
        setState(() => error = 'Não foi possível buscar os ativos.');
      }
    } finally {
      if (mounted && current == request) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: ListView(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Adicionar ativo',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar busca',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              autofocus: true,
              onChanged: (_) => changed(),
              decoration: const InputDecoration(
                labelText: 'Nome ou símbolo',
                hintText: 'Ex.: Petrobras ou AAPL',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in Market.values)
                  ChoiceChip(
                    label: Text(
                      m == Market.brazil ? 'Brasil' : 'Internacional',
                    ),
                    selected: market == m,
                    onSelected: (_) {
                      setState(() => market = m);
                      changed();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (busy)
              const LinearProgressIndicator(semanticsLabel: 'Buscando ativos'),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: AppColors.negative),
                ),
              ),
            if (!busy && results.isEmpty && error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  input.text.trim().length < 2
                      ? 'Digite pelo menos dois caracteres para buscar.'
                      : 'Nenhum ativo encontrado neste mercado.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ...results.map((i) {
              final added = widget.controller.watchlist.any(
                (w) => w.id == i.id,
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i.symbol),
                subtitle: Text('${i.name}\n${i.exchange} · ${i.currency}'),
                isThreeLine: true,
                trailing: Icon(added ? Icons.check : Icons.add),
                onTap: added
                    ? null
                    : () {
                        widget.controller.add(i);
                        Navigator.pop(context);
                      },
              );
            }),
          ],
        ),
      ),
    ),
  );
}
