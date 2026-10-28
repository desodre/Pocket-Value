import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/quote_format.dart';
import '../watchlist/dashboard_controller.dart';
import 'market_models.dart';
import 'search_sheet.dart';
import 'settings_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardProvider).refresh();
    }
  }

  Market? filter;
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(dashboardProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.watchlist
            .where((i) => filter == null || i.market == filter)
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'PocketValue',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Configurar APIs',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => SettingsSheet(controller: controller),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => SearchSheet(controller: controller),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar ativo'),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => controller.refresh(force: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Seu mercado,\nem perspectiva.',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        QuoteCard(
                          instrument: Instrument.ibovespa,
                          quote: controller.quotes[Instrument.ibovespa.id],
                          error: controller.errors[Instrument.ibovespa.id],
                          loading: controller.loading.contains(
                            Instrument.ibovespa.id,
                          ),
                          hero: true,
                          onRefresh: () => controller.refresh(force: true),
                          onWidget: () =>
                              controller.selectWidget(Instrument.ibovespa),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Cotações podem ter atraso. Puxe para atualizar.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Atualizar cotações agora',
                              onPressed: controller.refreshing
                                  ? null
                                  : () => controller.refresh(force: true),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        if (controller.refreshing)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Atualizando cotações',
                          ),
                        if (controller.storageError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              controller.storageError!,
                              style: const TextStyle(color: AppColors.negative),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Minha lista',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${controller.watchlist.length} ativos',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in <Market?, String>{
                              null: 'Todos',
                              Market.brazil: 'Brasil',
                              Market.international: 'Internacional',
                            }.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: filter == entry.key,
                                onSelected: (_) =>
                                    setState(() => filter = entry.key),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.padded,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (visible.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.bookmark_border_rounded,
                                  size: 36,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  controller.watchlist.isEmpty
                                      ? 'Comece pela sua lista'
                                      : 'Nenhum ativo neste mercado',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Adicione os ativos que você quer acompanhar. Suas escolhas ficam salvas neste dispositivo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverReorderableList(
                      itemCount: visible.length,
                      onReorderItem: (oldIndex, newIndex) {
                        if (filter != null) return;
                        controller.reorder(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final i = visible[index];
                        return Padding(
                          key: ValueKey(i.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: QuoteCard(
                            instrument: i,
                            quote: controller.quotes[i.id],
                            error: controller.errors[i.id],
                            loading: controller.loading.contains(i.id),
                            onRefresh: () async {
                              await controller.refreshOne(i, force: true);
                              await controller.persist();
                            },
                            onRemove: () => controller.remove(i),
                            onWidget: () => controller.selectWidget(i),
                            dragHandle: filter == null
                                ? ReorderableDragStartListener(
                                    index: index,
                                    child: const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.muted),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.widgets_outlined,
                              color: AppColors.accent,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Na sua tela inicial',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              controller.widgetId == null
                                  ? 'Escolha um ativo no menu ⋮ para preparar seu widget.'
                                  : 'Ativo escolhido: ${_widgetName(controller)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'A instalação dos widgets no Android e iOS será disponibilizada em uma próxima etapa.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _widgetName(DashboardController c) =>
      [
        Instrument.ibovespa,
        ...c.watchlist,
      ].where((i) => i.id == c.widgetId).map((i) => i.name).firstOrNull ??
      'Ibovespa';
}

class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.instrument,
    required this.quote,
    this.error,
    this.loading = false,
    this.hero = false,
    required this.onRefresh,
    required this.onWidget,
    this.onRemove,
    this.dragHandle,
  });
  final Instrument instrument;
  final Quote? quote;
  final String? error;
  final bool loading, hero;
  final VoidCallback onRefresh, onWidget;
  final VoidCallback? onRemove;
  final Widget? dragHandle;
  @override
  Widget build(BuildContext context) {
    final percent = quote?.changePercent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hero ? AppColors.panel : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hero ? const Color(0xFF385F91) : const Color(0xFF27384E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero ? 'IBOVESPA' : instrument.symbol,
                      style: TextStyle(
                        fontSize: hero ? 14 : 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: hero ? 2 : 0,
                        color: hero ? AppColors.accent : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hero ? 'O pulso da bolsa brasileira' : instrument.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (dragHandle != null)
                Semantics(
                  label: 'Arrastar para reordenar ${instrument.symbol}',
                  child: dragHandle!,
                ),
              PopupMenuButton<String>(
                tooltip: 'Opções de ${instrument.name}',
                onSelected: (value) {
                  switch (value) {
                    case 'refresh':
                      onRefresh();
                    case 'widget':
                      onWidget();
                    case 'remove':
                      onRemove?.call();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Text('Atualizar agora'),
                  ),
                  const PopupMenuItem(
                    value: 'widget',
                    child: Text('Escolher para widget'),
                  ),
                  if (onRemove != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remover da lista'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading && quote == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                semanticsLabel: 'Buscando cotação',
              ),
            )
          else
            Text(
              priceLabel(quote, instrument),
              style: TextStyle(
                fontSize: hero ? 36 : 26,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (percent != null)
                Icon(
                  percent >= 0 ? Icons.north_east : Icons.south_east,
                  size: 18,
                  color: percent >= 0 ? AppColors.positive : AppColors.negative,
                ),
              Text(
                changeLabel(quote),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: percent == null
                      ? AppColors.muted
                      : percent >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
              ),
              if (quote?.marketOpen != null)
                Text(
                  quote!.marketOpen! ? '• Mercado aberto' : '• Mercado fechado',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${instrument.exchange} · ${quote?.source ?? (instrument.market == Market.brazil ? 'brapi' : 'Twelve Data')}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel(quote),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (quote != null && quote!.isOld(DateTime.now()))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Última cotação disponível • pode estar desatualizada',
                style: TextStyle(fontSize: 12, color: AppColors.accent),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 14, color: AppColors.negative),
              ),
            ),
        ],
      ),
    );
  }
}
