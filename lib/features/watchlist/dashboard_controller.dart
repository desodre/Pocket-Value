import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_store.dart';
import '../markets/market_api.dart';
import '../home_widgets/widget_snapshot.dart';
import '../markets/market_models.dart';

final dashboardProvider = Provider<DashboardController>(
  (ref) => throw StateError('Dashboard não inicializado.'),
);

class DashboardController extends ChangeNotifier {
  DashboardController(this.api, this.store) {
    final saved = store.read();
    try {
      watchlist = (saved['watchlist'] as List? ?? [])
          .map((j) => Instrument.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      quotes.addAll(
        (saved['quotes'] as Map? ?? {}).map(
          (k, v) => MapEntry(
            k as String,
            Quote.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        ),
      );
      widgetId = saved['widgetId'] as String?;
    } on Object {
      watchlist = [];
      quotes.clear();
      widgetId = null;
    }
  }
  final MarketApi api;
  final LocalStore store;
  List<Instrument> watchlist = [];
  final Map<String, Quote> quotes = {};
  final Map<String, String> errors = {};
  final Set<String> loading = {};
  String? widgetId;
  String? storageError;
  bool refreshing = false;
  bool _disposed = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> persist() async {
    try {
      await store.save({
        'watchlist': watchlist.map((i) => i.toJson()).toList(),
        'quotes': quotes.map((k, v) => MapEntry(k, v.toJson())),
        'widgetId': widgetId,
        'widgetSnapshot': quotes[widgetId] == null
            ? null
            : WidgetSnapshot(quotes[widgetId]!).toJson(),
      });
      storageError = null;
    } on Object {
      storageError =
          'Não foi possível salvar suas alterações neste dispositivo.';
    }
    _emit();
  }

  Future<void> refresh({bool force = false}) async {
    if (refreshing) return;
    refreshing = true;
    _emit();
    final all = [Instrument.ibovespa, ...watchlist];
    // Parallel markets; sequential symbols respect each provider's quota.
    await Future.wait(
      Market.values.map((market) async {
        for (final i in all.where((i) => i.market == market)) {
          await refreshOne(i, force: force);
        }
      }),
    );
    refreshing = false;
    await persist();
    _emit();
  }

  Future<void> refreshOne(Instrument i, {bool force = false}) async {
    if (loading.contains(i.id)) return;
    final cached = quotes[i.id];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.receivedAt) <
            const Duration(minutes: 30)) {
      return;
    }
    loading.add(i.id);
    errors.remove(i.id);
    _emit();
    try {
      quotes[i.id] = await api.quote(i);
    } on MarketFailure catch (e) {
      errors[i.id] = e.message;
    } on Object {
      errors[i.id] = 'Não foi possível ler a cotação recebida.';
    } finally {
      loading.remove(i.id);
      _emit();
    }
  }

  Future<void> add(Instrument i) async {
    if (i.isIndex || watchlist.any((w) => w.id == i.id)) return;
    watchlist.add(i);
    _emit();
    await persist();
    await refreshOne(i);
    await persist();
  }

  Future<void> remove(Instrument i) async {
    watchlist.removeWhere((w) => w.id == i.id);
    quotes.remove(i.id);
    errors.remove(i.id);
    if (widgetId == i.id) widgetId = null;
    await persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    watchlist.insert(newIndex, watchlist.removeAt(oldIndex));
    await persist();
  }

  Future<void> selectWidget(Instrument i) async {
    widgetId = i.id;
    await persist();
  }
}
