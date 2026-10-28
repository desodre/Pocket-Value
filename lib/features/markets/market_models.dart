enum Market { brazil, international }

class Instrument {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.currency,
    required this.market,
  });
  final String symbol, name, exchange, currency;
  final Market market;
  String get id => '${market.name}:$exchange:$symbol';
  bool get isIndex => symbol == '^BVSP';
  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'exchange': exchange,
    'currency': currency,
    'market': market.name,
  };
  factory Instrument.fromJson(Map<String, dynamic> j) => Instrument(
    symbol: j['symbol'] as String,
    name: j['name'] as String,
    exchange: j['exchange'] as String,
    currency: j['currency'] as String,
    market: Market.values.byName(j['market'] as String),
  );
  static const ibovespa = Instrument(
    symbol: '^BVSP',
    name: 'Ibovespa',
    exchange: 'B3',
    currency: '',
    market: Market.brazil,
  );
}

class Quote {
  const Quote({
    required this.instrument,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.observedAt,
    required this.receivedAt,
    this.marketOpen,
  });
  final Instrument instrument;
  final double? price, change, changePercent;
  final DateTime? observedAt;
  final DateTime receivedAt;
  final bool? marketOpen;
  String get source =>
      instrument.market == Market.brazil ? 'brapi' : 'Twelve Data';
  bool isOld(DateTime now) =>
      observedAt == null ||
      now.difference(observedAt!) > const Duration(minutes: 30);
  Map<String, dynamic> toJson() => {
    'instrument': instrument.toJson(),
    'price': price,
    'change': change,
    'changePercent': changePercent,
    'observedAt': observedAt?.toIso8601String(),
    'receivedAt': receivedAt.toIso8601String(),
    'marketOpen': marketOpen,
  };
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    instrument: Instrument.fromJson(
      Map<String, dynamic>.from(j['instrument'] as Map),
    ),
    price: number(j['price']),
    change: number(j['change']),
    changePercent: number(j['changePercent']),
    observedAt: DateTime.tryParse(j['observedAt'] as String? ?? ''),
    receivedAt: DateTime.parse(j['receivedAt'] as String),
    marketOpen: j['marketOpen'] as bool?,
  );
}

double? number(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : null;
}

class MarketFailure implements Exception {
  const MarketFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
