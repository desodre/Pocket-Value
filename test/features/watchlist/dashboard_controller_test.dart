import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_value/core/local_store.dart';
import 'package:pocket_value/features/markets/market_api.dart';
import 'package:pocket_value/features/markets/market_models.dart';
import 'package:pocket_value/features/watchlist/dashboard_controller.dart';

const apple = Instrument(
  symbol: 'AAPL',
  name: 'Apple',
  exchange: 'NASDAQ',
  currency: 'USD',
  market: Market.international,
);
const petro = Instrument(
  symbol: 'PETR4',
  name: 'Petrobras',
  exchange: 'B3',
  currency: 'BRL',
  market: Market.brazil,
);

class FakeApi implements MarketApi {
  int calls = 0;
  Market? failure;
  @override
  Future<Quote> quote(Instrument i) async {
    calls++;
    if (i.market == failure) throw const MarketFailure('Falha desta fonte');
    return Quote(
      instrument: i,
      price: 10,
      change: 1,
      changePercent: 2,
      observedAt: DateTime.now(),
      receivedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Instrument>> search(String query, Market market) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore store;
  late FakeApi api;
  late DashboardController c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
    api = FakeApi();
    c = DashboardController(api, store);
  });
  tearDown(() => c.dispose());
  test(
    'empty first launch, deduplication and persistence after restart',
    () async {
      expect(c.watchlist, isEmpty);
      await c.add(apple);
      await c.add(apple);
      await c.selectWidget(apple);
      final restored = DashboardController(api, store);
      expect(restored.watchlist.single.id, apple.id);
      expect(restored.quotes[apple.id]!.price, 10);
      expect(restored.widgetId, apple.id);
      final snapshot = store.read()['widgetSnapshot'] as Map;
      expect(snapshot['symbol'], 'AAPL');
      expect(snapshot['version'], 1);
      expect(snapshot.containsKey('apiKey'), false);
      restored.dispose();
    },
  );
  test(
    'one failed source preserves cache and successful source updates',
    () async {
      await c.add(apple);
      await c.add(petro);
      final previous = c.quotes[apple.id];
      api.failure = Market.international;
      await c.refresh(force: true);
      expect(c.quotes[apple.id], same(previous));
      expect(c.errors[apple.id], 'Falha desta fonte');
      expect(c.errors[petro.id], isNull);
      expect(c.quotes[Instrument.ibovespa.id], isNotNull);
      expect(c.refreshing, false);
    },
  );
  test('fresh cache avoids requests while force refresh fetches', () async {
    await c.refresh();
    final calls = api.calls;
    await c.refresh();
    expect(api.calls, calls);
    await c.refresh(force: true);
    expect(api.calls, calls + 1);
  });
  test('adjusted reorder index and removal update selected widget', () async {
    await c.add(apple);
    await c.add(petro);
    await c.reorder(0, 1);
    expect(c.watchlist.first.id, petro.id);
    await c.selectWidget(apple);
    await c.remove(apple);
    expect(c.widgetId, isNull);
    expect(c.quotes.containsKey(apple.id), false);
  });
}
