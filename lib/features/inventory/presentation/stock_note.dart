import '../../../l10n/generated/app_localizations.dart';
import '../domain/stock_draw.dart';

/// The sentence to add after a change, when stock has something to say.
///
/// Only ever for someone who is actually counting. Telling a user who never
/// set inventory up that they have run out would be an invention, and
/// [StockDraw.isWorthMentioning] is what keeps that impossible.
///
/// Returns null when there is nothing worth saying, which is the common case
/// and the one the caller should treat as normal.
String? stockNote(AppLocalizations l10n, StockDraw stock, String name) {
  if (!stock.isWorthMentioning) {
    return null;
  }
  // A shortfall reads first, because it is the more surprising of the two and
  // because it says explicitly that the count was not pushed negative to
  // accommodate the change. The change is recorded either way: the log is the
  // product and the count is a convenience on top of it.
  return stock.shortfall > 0
      ? l10n.stockShortSnack(name)
      : l10n.stockRanOutSnack(name);
}
