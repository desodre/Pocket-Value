import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../watchlist/dashboard_controller.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.controller});
  final DashboardController controller;
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final brapi = TextEditingController(), twelve = TextEditingController();
  bool ready = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.controller.store.key('brapi'),
        widget.controller.store.key('twelve'),
      ]);
      if (!mounted) return;
      brapi.text = values[0];
      twelve.text = values[1];
      setState(() => ready = true);
    } on Object {
      if (mounted) {
        setState(
          () => error = 'Não foi possível acessar o armazenamento seguro.',
        );
      }
    }
  }

  @override
  void dispose() {
    brapi.dispose();
    twelve.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.controller.store.setKey('brapi', brapi.text);
      await widget.controller.store.setKey('twelve', twelve.text);
      if (!mounted) return;
      Navigator.pop(context);
      await widget.controller.refresh(force: true);
    } on Object {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Não foi possível salvar as chaves. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Suas fontes de dados',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Fechar configurações',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Uso pessoal. As chaves ficam no armazenamento seguro deste dispositivo.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (!ready && error == null) const LinearProgressIndicator(),
          TextField(
            controller: brapi,
            enabled: ready && !saving,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Chave brapi',
              helperText: 'Brasil e Ibovespa · brapi.dev/dashboard',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: twelve,
            enabled: ready && !saving,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Chave Twelve Data',
              helperText: 'Internacional · twelvedata.com/account',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Deixe um campo vazio para remover a chave. O app usa cache de 30 minutos; puxar para atualizar ou “Atualizar agora” força uma consulta dentro dos limites disponíveis.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.negative),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ready && !saving ? save : null,
              child: Text(saving ? 'Salvando…' : 'Salvar e atualizar'),
            ),
          ),
        ],
      ),
    ),
  );
}
