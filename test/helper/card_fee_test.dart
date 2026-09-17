import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AC: a fetched base of 0.0027405 at 1.4% is what turns 5 170 HUF into 14.37.
  test('a fetched base rate carries the fee, at full precision', () {
    expect(applyCardFee(0.0027405, 1.4), closeTo(0.002778867, 1e-12));
    // The number that actually reaches the field, and the amount it settles.
    expect(formatRate(applyCardFee(0.0027405, 1.4)), '0.00277887');
    expect(convertToGroupCurrency(5170, 0.00277887, Currency.eur), 14.37);
    expect(convertToGroupCurrency(5170, 0.0027405, Currency.eur), 14.17);
  });

  test('a null, zero or non-finite fee returns the base rate untouched', () {
    expect(applyCardFee(0.0027405, null), 0.0027405);
    expect(applyCardFee(0.0027405, 0), 0.0027405);
    expect(applyCardFee(0.0027405, double.nan), 0.0027405);
    expect(applyCardFee(0.0027405, double.infinity), 0.0027405);
  });

  // AC: the fee reads and writes per locale, and both forms parse back to the
  // same stored number.
  test(
    'the fee renders per locale and both forms parse back the same',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final de = await AppLocalizations.delegate.load(const Locale('de'));

      expect(
        en.cardFeePercentValue(formatPercentValue(1.4, const Locale('en'))),
        '1.4 %',
      );
      expect(
        de.cardFeePercentValue(formatPercentValue(1.4, const Locale('de'))),
        '1,4 %',
      );
      expect(parseCardFeePercent('1.4'), 1.4);
      expect(parseCardFeePercent('1,4'), 1.4);
      expect(parseCardFeePercent('0'), 0);
      expect(parseCardFeePercent(''), isNull);
      expect(parseCardFeePercent('-1'), isNull);
    },
  );

  test(
    'the fee copy is real German, not the English string copied over',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final de = await AppLocalizations.delegate.load(const Locale('de'));
      expect(de.settingsCardFee, isNot(en.settingsCardFee));
      expect(de.settingsCardFeeSubtitle, isNot(en.settingsCardFeeSubtitle));
      expect(de.cardFeeSheetHelper, isNot(en.cardFeeSheetHelper));
      expect(
        de.expenseConversionRateNeeded,
        isNot(en.expenseConversionRateNeeded),
      );
    },
  );
}
