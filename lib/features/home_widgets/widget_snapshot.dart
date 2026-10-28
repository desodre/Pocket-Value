import '../markets/market_models.dart';

/// Versioned local payload for the future native widget bridge. No credentials.
class WidgetSnapshot {
  const WidgetSnapshot(this.quote);
  final Quote quote;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'symbol': quote.instrument.symbol,
    'exchange': quote.instrument.exchange,
    'name': quote.instrument.name,
    'currency': quote.instrument.isIndex ? null : quote.instrument.currency,
    'isIndex': quote.instrument.isIndex,
    'price': quote.price,
    'changePercent': quote.changePercent,
    'observedAt': quote.observedAt?.toUtc().toIso8601String(),
    'receivedAt': quote.receivedAt.toUtc().toIso8601String(),
    'source': quote.source,
  };
}
