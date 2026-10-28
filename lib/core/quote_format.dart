import 'package:intl/intl.dart';

import '../features/markets/market_models.dart';

String priceLabel(Quote? quote, Instrument instrument) {
  if (quote?.price == null) return '—';
  if (instrument.isIndex) {
    return '${NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 0).format(quote!.price)} pts';
  }
  final currency = quote!.instrument.currency;
  return '${currency.isEmpty ? 'Moeda indisponível' : currency} ${NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 2).format(quote.price)}';
}

String changeLabel(Quote? quote) {
  final value = quote?.changePercent;
  if (value == null) return 'Variação indisponível';
  return '${value >= 0 ? '+' : ''}${NumberFormat('0.00', 'pt_BR').format(value)}%';
}

String timeLabel(Quote? quote) => quote?.observedAt == null
    ? 'Horário da cotação indisponível'
    : 'Cotação ${DateFormat('dd/MM HH:mm').format(quote!.observedAt!.toLocal())} • horário local';
