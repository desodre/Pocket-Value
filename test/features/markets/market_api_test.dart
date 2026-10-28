import 'dart:typed_data';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_value/core/local_store.dart';
import 'package:pocket_value/core/quote_format.dart';
import 'package:pocket_value/features/markets/market_api.dart';
import 'package:pocket_value/features/markets/market_models.dart';

const apple = Instrument(
  symbol: 'AAPL',
  name: 'Apple',
  exchange: 'NASDAQ',
  currency: 'USD',
  market: Market.international,
);

class Adapter implements HttpClientAdapter {
  Adapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  final List<RequestOptions> calls = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 28);
  test('brapi v2 envelope, numeric fields, nulls and renamed symbols', () {
    final quote = HttpMarketApi.parseBrapi(
      {
        'results': [
          {
            'requestedSymbol': 'OLD',
            'symbol': 'NEW',
            'data': {
              'shortName': 'Novo nome',
              'currency': 'BRL',
              'regularMarketPrice': 41.18,
              'regularMarketChange': null,
              'regularMarketChangePercent': -1.39,
              'regularMarketTime': '2026-10-27T17:08:02.000Z',
            },
          },
        ],
      },
      Instrument.ibovespa,
      now,
    );
    expect(quote.instrument.symbol, 'NEW');
    expect(quote.price, 41.18);
    expect(quote.change, isNull);
    expect(quote.observedAt, DateTime.utc(2026, 10, 27, 17, 8, 2));
    expect(quote.receivedAt, now);
  });
  test('Twelve uses last_quote_at instead of opening candle timestamp', () {
    final quote = HttpMarketApi.parseTwelve(
      {
        'close': '148.85',
        'change': '-0.24',
        'percent_change': '-0.16',
        'timestamp': 1,
        'last_quote_at': 1793120882,
        'is_market_open': false,
      },
      apple,
      now,
    );
    expect(quote.price, 148.85);
    expect(quote.observedAt!.millisecondsSinceEpoch, 1793120882000);
    expect(quote.marketOpen, false);
    expect(quote.instrument.currency, 'USD');
  });
  test('missing or invalid price and quote time stay unavailable', () {
    final quote = HttpMarketApi.parseTwelve(
      {'close': 'NaN', 'timestamp': 1},
      apple,
      now,
    );
    expect(quote.price, isNull);
    expect(quote.observedAt, isNull);
    expect(priceLabel(quote, apple), '—');
    expect(changeLabel(quote), 'Variação indisponível');
    expect(
      () => HttpMarketApi.parseBrapi({'results': []}, apple, now),
      throwsA(isA<MarketFailure>()),
    );
  });
  test('formatting distinguishes points, currency, sign and stale time', () {
    final q = Quote(
      instrument: apple,
      price: 1200.25,
      change: 1,
      changePercent: 0.25,
      observedAt: now,
      receivedAt: now,
    );
    expect(priceLabel(q, apple), 'USD 1.200,25');
    expect(priceLabel(q, Instrument.ibovespa), '1.200 pts');
    expect(changeLabel(q), '+0,25%');
    expect(q.isOld(now.add(const Duration(minutes: 31))), true);
    expect(Quote.fromJson(q.toJson()).observedAt, now);
  });
  late LocalStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'brapi': 'secret-b',
      'twelve': 'secret-t',
    });
    store = LocalStore(await SharedPreferences.getInstance());
  });
  test(
    'requests use documented URLs, params and authorization headers',
    () async {
      final adapter = Adapter(
        (o) => ResponseBody.fromString(
          jsonEncode(
            o.uri.host == 'brapi.dev'
                ? {
                    'results': [
                      {'symbol': '^BVSP', 'data': {}},
                    ],
                  }
                : {'close': '10'},
          ),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      final api = HttpMarketApi(
        store,
        client: Dio()..httpClientAdapter = adapter,
      );
      await api.quote(Instrument.ibovespa);
      await api.quote(apple);
      expect(adapter.calls[0].uri.path, '/api/v2/stocks/quote');
      expect(adapter.calls[0].queryParameters['symbols'], '^BVSP');
      expect(adapter.calls[0].headers['Authorization'], 'Bearer secret-b');
      expect(adapter.calls[1].uri.path, '/quote');
      expect(adapter.calls[1].queryParameters['exchange'], 'NASDAQ');
      expect(adapter.calls[1].headers['Authorization'], 'apikey secret-t');
      expect(adapter.calls[1].uri.query, isNot(contains('secret')));
    },
  );
  test(
    '429 blocks immediate retries and preserves provider isolation',
    () async {
      final adapter = Adapter(
        (o) => ResponseBody.fromString(
          '{}',
          429,
          headers: {
            'retry-after': ['120'],
            'content-type': ['application/json'],
          },
        ),
      );
      final api = HttpMarketApi(
        store,
        client: Dio()..httpClientAdapter = adapter,
      );
      await expectLater(api.quote(apple), throwsA(isA<MarketFailure>()));
      await expectLater(api.quote(apple), throwsA(isA<MarketFailure>()));
      expect(adapter.calls.length, 1);
      await expectLater(
        api.quote(Instrument.ibovespa),
        throwsA(isA<MarketFailure>()),
      );
      expect(adapter.calls.length, 2);
    },
  );
  test('missing key is actionable and does not send a request', () async {
    await store.setKey('twelve', '');
    final adapter = Adapter((o) => throw StateError('Unexpected request'));
    await expectLater(
      HttpMarketApi(
        store,
        client: Dio()..httpClientAdapter = adapter,
      ).quote(apple),
      throwsA(isA<MarketFailure>()),
    );
    expect(adapter.calls, isEmpty);
  });
  test('local minute budget persists and permits a new minute', () async {
    for (var i = 0; i < 8; i++) {
      await store.reserveCredit(now);
    }
    await expectLater(store.reserveCredit(now), throwsStateError);
    await LocalStore(await SharedPreferences.getInstance())
        .reserveCredit(now.add(const Duration(minutes: 1)));
  });
  test(
    'search distinguishes providers and parses documented envelopes',
    () async {
      final adapter = Adapter(
        (o) => ResponseBody.fromString(
          jsonEncode(
            o.uri.host == 'brapi.dev'
                ? {
                    'results': [
                      {
                        'symbol': 'PETR4',
                        'name': 'Petrobras',
                        'exchange': 'B3',
                        'currency': 'BRL',
                      },
                    ],
                  }
                : {
                    'data': [
                      {
                        'symbol': 'AAPL',
                        'instrument_name': 'Apple',
                        'exchange': 'NASDAQ',
                        'currency': 'USD',
                      },
                    ],
                  },
          ),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      final api = HttpMarketApi(
        store,
        client: Dio()..httpClientAdapter = adapter,
      );
      expect((await api.search('petro', Market.brazil)).single.symbol, 'PETR4');
      expect(
        (await api.search('apple', Market.international)).single.exchange,
        'NASDAQ',
      );
      expect(adapter.calls.first.uri.path, '/api/v2/tickers');
      expect(adapter.calls.last.queryParameters['show_plan'], true);
    },
  );
}
