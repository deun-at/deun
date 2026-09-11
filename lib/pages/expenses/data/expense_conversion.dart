import 'package:deun/helper/helper.dart';

import 'itemized_totals.dart';

/// Keys of the provenance columns on the `expense` row. Exported so the legacy
/// (non-RPC) write path can strip them before a PostgREST upsert.
const Set<String> kExpenseProvenanceKeys = {
  'original_currency_code',
  'conversion_rate',
  'rate_date',
};

/// Key of the provenance column on the `expense_entry` row.
const Set<String> kEntryProvenanceKeys = {'original_amount'};

/// Key of the provenance column on the `expense_entry_share` row.
///
/// `fixed_amount` is a LEDGER-currency column, so an exact-split share needs an
/// entry-currency twin for the editor to reload — the same rule
/// [kEntryProvenanceKeys] encodes for `expense_entry.amount`.
const Set<String> kShareProvenanceKeys = {'original_fixed_amount'};

/// How one expense's ENTERED amounts map onto its group's ledger.
///
/// The whole design rests on one property: the converted amount is computed
/// here, in the client, and written as an ordinary group-currency amount. The
/// provenance rides along unread by every balance path.
class ExpenseConversion {
  const ExpenseConversion({
    required this.groupCurrency,
    required this.entryCurrency,
    required this.rate,
    required this.rateDate,
  });

  /// The no-conversion case: amounts were entered in the group's own currency.
  factory ExpenseConversion.identity(Currency groupCurrency) =>
      ExpenseConversion(
        groupCurrency: groupCurrency,
        entryCurrency: groupCurrency,
        rate: null,
        rateDate: null,
      );

  /// The group's settlement currency. Every stored ledger amount is in this.
  final Currency groupCurrency;

  /// The currency the user typed the amounts in.
  final Currency entryCurrency;

  /// The frozen rate: 1 [entryCurrency] = [rate] [groupCurrency]. Null on
  /// [isIdentity], and null on a foreign currency means "no rate supplied yet",
  /// which [toLedger] refuses rather than defaulting.
  final double? rate;

  /// `yyyy-MM-dd` the rate is attributed to. Stamped when the entry currency is
  /// chosen (see [rateDateForPickedCurrency]) and never re-stamped by an edit to
  /// anything else.
  final String? rateDate;

  bool get isIdentity => entryCurrency == groupCurrency;

  /// The ledger value of [enteredAmount], which is expressed in
  /// [entryCurrency].
  ///
  /// Throws [MissingConversionRateException] when the expense is in a foreign
  /// currency and no positive rate was supplied.
  double toLedger(double enteredAmount) {
    if (isIdentity) return roundCurrency(enteredAmount, groupCurrency);
    final r = rate;
    if (r == null || r <= 0) {
      throw MissingConversionRateException(entryCurrency, groupCurrency);
    }
    return convertToGroupCurrency(enteredAmount, r, groupCurrency);
  }

  /// The provenance columns for the `expense` row.
  ///
  /// Always all three keys, explicitly null on [isIdentity], so switching an
  /// expense back to its group's currency CLEARS the stored provenance instead
  /// of leaving a stale rate on the row.
  Map<String, dynamic> get expenseProvenance => {
    'original_currency_code': isIdentity ? null : entryCurrency.code,
    'conversion_rate': isIdentity ? null : rate,
    'rate_date': isIdentity ? null : rateDate,
  };
}

/// The units a line of [quantity] actually has: a 0 or negative quantity is one
/// unit, the normalisation every per-unit path applies.
int effectiveQuantity(int quantity) => quantity > 0 ? quantity : 1;

/// The LEDGER total of one entered [line] — THE definition of "the line
/// converts once".
///
/// The editor preview, [ExpenseRepository.saveAll] and the switch-back all read
/// this one function, so none of the three can drift a cent from the others.
double ledgerLineTotal(ItemLine line, ExpenseConversion conversion) =>
    conversion.toLedger(line.lineTotal);

/// The LEDGER total of a whole expense: every line converts on its own and the
/// converted values accumulate at the group currency's precision.
///
/// This is exactly the accumulation [ExpenseRepository.saveAll] performs, which
/// is why the editor's preview is the figure the save stores. Converting the
/// SUMMED entry-currency total once instead disagrees by a cent: three lines of
/// 1.50 CHF at 0.9432 store 4.23 (3 x 1.41) but preview 4.24 from 4.50 x
/// 0.9432.
double ledgerTotalOfLines(List<ItemLine> lines, ExpenseConversion conversion) {
  double total = 0;
  for (final line in lines) {
    total = roundCurrency(
      total + ledgerLineTotal(line, conversion),
      conversion.groupCurrency,
    );
  }
  return total;
}

/// The per-unit LEDGER amounts for a claimable line of [quantity] units whose
/// line total is [enteredLineTotal] in the entry currency.
///
/// The line total converts ONCE and [distributeCurrency] spreads the
/// indivisible remainder, so the units sum to exactly the figure the editor
/// previewed and the notification quotes.
List<double> unitLedgerAmounts({
  required double enteredLineTotal,
  required int quantity,
  required ExpenseConversion conversion,
}) => distributeCurrency(
  conversion.toLedger(enteredLineTotal),
  effectiveQuantity(quantity),
  conversion.groupCurrency,
);

/// The matching per-unit ORIGINAL amounts, distributed in the ENTRY currency so
/// they sum to [enteredLineTotal] exactly. Null on an identity conversion —
/// there is no provenance to record.
List<double>? unitOriginalAmounts({
  required double enteredLineTotal,
  required int quantity,
  required ExpenseConversion conversion,
}) => conversion.isIdentity
    ? null
    : distributeCurrency(
        enteredLineTotal,
        effectiveQuantity(quantity),
        conversion.entryCurrency,
      );

/// The `yyyy-MM-dd` a newly picked entry currency's rate is attributed to.
///
/// A saved expense's rate date is frozen: re-opening the editor on it and
/// leaving its currency alone must never re-stamp it. But the rate a user types
/// after switching JPY -> CHF is a CHF rate quoted today, so attributing it to
/// the date the old JPY rate carried misdates it.
///
/// A date is only ever a fact about a *rate*, so the frozen [loadedRateDate]
/// survives exactly while both halves of the loaded pair are still in force:
/// [picked] is still [loadedOriginalCurrencyCode] AND the rate about to sit in
/// the field ([pickedRate], the sticky prefill) is still [loadedRate]. Gating
/// on the currency alone misdates a round trip — switching CHF -> EUR and back
/// to CHF clears the rate field and refills it from the sticky rate, so a rate
/// that was never quoted on that day would be stored under it. Anything else is
/// stamped [today].
String? rateDateForPickedCurrency({
  required Currency picked,
  required String? loadedOriginalCurrencyCode,
  required String? loadedRateDate,
  required double? loadedRate,
  required double? pickedRate,
  required DateTime today,
}) {
  if (loadedRateDate != null &&
      picked.code == loadedOriginalCurrencyCode &&
      loadedRate != null &&
      pickedRate == loadedRate) {
    return loadedRateDate;
  }
  return ymd(today);
}

/// The amount-field texts after switching an expense back to its group's
/// currency.
///
/// The fields hold amounts in the ENTRY currency, so leaving them as typed
/// would save a 3000 JPY expense as 3000 EUR, and clearing them would silently
/// discard the user's numbers. Each entered amount is re-converted at the
/// FROZEN [rate], which preserves the value the ledger already holds: a
/// converted 17.40 EUR expense switched back to EUR stays 17.40, not 3000.
///
/// A null or non-positive [rate] means nothing was ever converted (the user
/// picked a foreign currency and typed no rate), so the texts pass through
/// untouched. An unparseable text also passes through untouched.
///
/// Each text is a UNIT price, so [quantities] (parallel to [enteredTexts],
/// defaulting to one unit per line) is what makes the line convert once:
/// re-converting the unit price of a qty-3 line would lose the distributed
/// remainder — 10.00 CHF x3 at 0.9432 is 28.30 in the ledger but 9.43 x3 is
/// 28.29, the exact drift the line-once rule exists to prevent.
List<String> switchBackAmountTexts({
  required List<String> enteredTexts,
  required double? rate,
  required Currency groupCurrency,
  List<int>? quantities,
}) {
  if (rate == null || rate <= 0) return List<String>.from(enteredTexts);
  final texts = <String>[];
  for (var i = 0; i < enteredTexts.length; i++) {
    final text = enteredTexts[i];
    final entered = double.tryParse(text);
    if (entered == null) {
      texts.add(text);
      continue;
    }
    final quantity = effectiveQuantity(
      quantities != null && i < quantities.length ? quantities[i] : 1,
    );
    // The LINE converts once and the indivisible remainder distributes across
    // its units, the same two steps the save performs — so the ledger value the
    // expense already holds survives the switch to the cent.
    final units = distributeCurrency(
      convertToGroupCurrency(entered * quantity, rate, groupCurrency),
      quantity,
      groupCurrency,
    );
    texts.add(unitPriceFieldText(units, groupCurrency));
  }
  return texts;
}

/// The amount-field text for a line whose per-unit ledger amounts are [units].
///
/// The field holds ONE unit price, so a line whose remainder had to be
/// distributed has no clean per-unit figure: the 9.44 / 9.43 / 9.43 of a 28.30
/// line would have to be written "9.43", and 9.43 x 3 saves 28.29. Such a line
/// therefore keeps enough fractional digits that unit price x quantity still
/// rounds back to the distributed total, so the save reproduces 28.30 and
/// re-distributes those very same units. An evenly divisible line keeps the
/// plain text at the currency's own precision.
String unitPriceFieldText(List<double> units, Currency currency) {
  final quantity = units.isEmpty ? 1 : units.length;
  final total = roundCurrency(
    units.fold<double>(0, (sum, unit) => sum + unit),
    currency,
  );
  final plain = amountToFieldText(total / quantity, currency);
  if (roundCurrency(double.parse(plain) * quantity, currency) == total) {
    return plain;
  }
  final precise = (total / quantity).toStringAsFixed(6);
  return precise
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// The amount-field text seeding a reloaded line of [quantity] units whose
/// ENTERED total is [enteredLineTotal] in [currency].
///
/// THE inverse of the save, and the reason it is not
/// `amountToFieldText(total / quantity, currency)`: the save multiplies the
/// field by the quantity and distributes the result, so the seed has to be a
/// text that multiplies back to exactly this total. Rounding 28.30 / 3 to
/// "9.43" loses the distributed remainder, and the next save of an otherwise
/// untouched expense stores 28.29 — the editor silently moving a cent of a
/// stranger's balance because it was reopened.
///
/// [distributeCurrency] reproduces the very units the save wrote (the explode
/// path distributes the same way), so this and [switchBackAmountTexts] hand the
/// field the same text for the same line.
String unitPriceFieldTextForTotal(
  double enteredLineTotal,
  int quantity,
  Currency currency,
) {
  final units = effectiveQuantity(quantity);
  return unitPriceFieldText(
    distributeCurrency(enteredLineTotal, units, currency),
    currency,
  );
}

/// A copy of [row] with [keys] removed. The legacy (non-RPC) write path goes
/// through PostgREST, which rejects an unknown column outright, so the
/// provenance keys must not reach it.
Map<String, dynamic> stripProvenance(
  Map<String, dynamic> row,
  Set<String> keys,
) => {
  for (final entry in row.entries)
    if (!keys.contains(entry.key)) entry.key: entry.value,
};
