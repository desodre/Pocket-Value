import 'package:dio/dio.dart';

import '../../core/local_store.dart';
import 'market_models.dart';

abstract interface class MarketApi {
  Future<Quote> quote(Instrument instrument);
  Future<List<Instrument>> search(String query, Market market);
}

class HttpMarketApi implements MarketApi {
  HttpMarketApi(this.store, {Dio? client})
    : client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 12),
            ),
          );
  final LocalStore store;
  final Dio client;
  final Map<Market, DateTime> _blockedUntil = {};
  Future<Map<String, dynamic>> _get(
    Market market,
    String path,
    Map<String, dynamic> query, {
    bool public = false,
  }) async {
    final blocked = _blockedUntil[market];
    if (blocked != null && DateTime.now().isBefore(blocked)) {
      throw const MarketFailure(
        'Limite temporário da API. Aguarde antes de atualizar.',
      );
    }
    final key = await store.key(market == Market.brazil ? 'brapi' : 'twelve');
    if (key.isEmpty && !public) {
      throw MarketFailure(
        'Configure sua chave ${market == Market.brazil ? 'brapi' : 'Twelve Data'} para consultar este ativo.',
      );
    }
    if (market == Market.international) {
      try {
        await store.reserveCredit(DateTime.now());
      } on StateError catch (e) {
        throw MarketFailure(e.message.toString());
      }
    }
    try {
      final response = await client.get<Object>(
        '${market == Market.brazil ? 'https://brapi.dev' : 'https://api.twelvedata.com'}$path',
        queryParameters: query,
        options: Options(
          headers: {
            if (key.isNotEmpty)
              'Authorization': market == Market.brazil
                  ? 'Bearer $key'
                  : 'apikey $key',
          },
        ),
      );
      final raw = response.data;
      if (raw is! Map) {
        throw const MarketFailure(
          'A API retornou dados em formato inesperado.',
        );
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['status'] == 'error' || data['error'] == true) {
        final code = number(data['code'])?.toInt() ?? 400;
        if (code == 429) {
          _blockedUntil[market] = DateTime.now().add(
            const Duration(minutes: 1),
          );
        }
        throw MarketFailure(_message(code));
      }
      return data;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 429) {
        final seconds =
            int.tryParse(e.response?.headers.value('retry-after') ?? '') ?? 60;
        _blockedUntil[market] = DateTime.now().add(
          Duration(seconds: seconds.clamp(1, 86400)),
        );
      }
      throw MarketFailure(
        code == null
            ? 'Sem conexão com a API. Seus dados salvos foram mantidos.'
            : _message(code),
      );
    }
  }

  static String _message(int code) => switch (code) {
    401 => 'Chave inválida ou ausente. Confira as configurações.',
    403 => 'Seu plano não inclui este ativo ou recurso.',
    404 => 'Cotação indisponível para este ativo.',
    429 => 'Limite da API atingido. Aguarde antes de tentar novamente.',
    _ => 'A API está indisponível. Tente novamente mais tarde.',
  };
  @override
  Future<Quote> quote(Instrument instrument) async {
    final data = await _get(
      instrument.market,
      instrument.market == Market.brazil ? '/api/v2/stocks/quote' : '/quote',
      instrument.market == Market.brazil
          ? {'symbols': instrument.symbol}
          : {'symbol': instrument.symbol, 'exchange': instrument.exchange},
      public:
          instrument.market == Market.brazil &&
          const [
            'PETR4',
            'VALE3',
            'MGLU3',
            'ITUB4',
          ].contains(instrument.symbol),
    );
    return instrument.market == Market.brazil
        ? parseBrapi(data, instrument, DateTime.now())
        : parseTwelve(data, instrument, DateTime.now());
  }

  static Quote parseBrapi(
    Map<String, dynamic> json,
    Instrument requested,
    DateTime received,
  ) {
    final results = json['results'];
    if (results is! List || results.isEmpty) {
      throw const MarketFailure('Cotação indisponível para este ativo.');
    }
    final row = Map<String, dynamic>.from(results.first as Map);
    final d = Map<String, dynamic>.from(row['data'] as Map);
    final instrument = Instrument(
      symbol: row['symbol'] as String? ?? requested.symbol,
      name: d['shortName'] as String? ?? requested.name,
      exchange: requested.exchange,
      currency: d['currency'] as String? ?? requested.currency,
      market: Market.brazil,
    );
    return Quote(
      instrument: instrument,
      price: number(d['regularMarketPrice']),
      change: number(d['regularMarketChange']),
      changePercent: number(d['regularMarketChangePercent']),
      observedAt: DateTime.tryParse(d['regularMarketTime']?.toString() ?? ''),
      receivedAt: received,
    );
  }

  static Quote parseTwelve(
    Map<String, dynamic> d,
    Instrument requested,
    DateTime received,
  ) {
    final stamp = number(d['last_quote_at']);
    return Quote(
      instrument: Instrument(
        symbol: d['symbol'] as String? ?? requested.symbol,
        name: d['name'] as String? ?? requested.name,
        exchange: d['exchange'] as String? ?? requested.exchange,
        currency: d['currency'] as String? ?? requested.currency,
        market: Market.international,
      ),
      price: number(d['close']),
      change: number(d['change']),
      changePercent: number(d['percent_change']),
      observedAt: stamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              stamp.toInt() * 1000,
              isUtc: true,
            ),
      receivedAt: received,
      marketOpen: d['is_market_open'] as bool?,
    );
  }

  @override
  Future<List<Instrument>> search(String query, Market market) async {
    final d = await _get(
      market,
      market == Market.brazil ? '/api/v2/tickers' : '/symbol_search',
      market == Market.brazil
          ? {'search': query, 'limit': 20}
          : {'symbol': query, 'outputsize': 20, 'show_plan': true},
      public: market == Market.brazil,
    );
    final rows = d[market == Market.brazil ? 'results' : 'data'];
    if (rows is! List) {
      return [];
    }
    return rows
        .whereType<Map>()
        .map(
          (r) => Instrument(
            symbol: r['symbol'] as String,
            name:
                (r[market == Market.brazil ? 'name' : 'instrument_name']
                    as String?) ??
                r['symbol'] as String,
            exchange: r['exchange'] as String? ?? '',
            currency: r['currency'] as String? ?? '',
            market: market,
          ),
        )
        .toList();
  }
}
