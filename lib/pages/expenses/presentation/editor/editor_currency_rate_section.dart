import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../widgets/restyle/soft_card.dart';
import '../../../../widgets/theme_builder.dart';
import '../../provider/expense_editor_controller.dart';

/// Entry currency plus, when it differs from the group's, the conversion
/// stated as a RESULT: the ledger amount and its provenance, with the rate
/// itself one tap away in the conversion sheet.
///
/// Two rows, two tap targets. The rate was a form field here and the fee
/// could not become a second one — a per-user constant with an input on the
/// expense screen implies it is per-expense, which is the wrong model.
class EditorCurrencyRateSection extends StatelessWidget {
  const EditorCurrencyRateSection({
    super.key,
    required this.screenContext,
    required this.entryCurrency,
    required this.groupCurrency,
    required this.convertedTotal,
    required this.rateOrigin,
    required this.rateUnavailable,
    required this.prefilledRateDate,
    required this.expenseDate,
    required this.cardFeePercent,
    required this.onPickCurrency,
    required this.onOpenConversion,
  });

  /// The screen's own context, above the group's `ThemeBuilder`: the card's
  /// own text and icon colours come from the app's brand theme, not the
  /// group's. The provenance chips build their own, as they always did.
  final BuildContext screenContext;
  final Currency entryCurrency;
  final Currency groupCurrency;

  /// The ledger total in the group currency, or null exactly when there is no
  /// usable rate, which renders the "rate needed" line.
  final double? convertedTotal;

  final RateOrigin rateOrigin;
  final bool rateUnavailable;
  final String? prefilledRateDate;
  final DateTime expenseDate;
  final double? cardFeePercent;
  final VoidCallback onPickCurrency;
  final VoidCallback onOpenConversion;

  bool get _isForeignCurrency => entryCurrency != groupCurrency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(screenContext);
    final locale = Localizations.localeOf(context);
    final converted = convertedTotal;

    return SoftCard(
      padding: EdgeInsets.zero,
      borderRadius: 16,
      child: Column(
        children: [
          InkWell(
            key: const ValueKey('expense_entry_currency'),
            onTap: onPickCurrency,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.expenseEntryCurrencyLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(entryCurrency.code, style: theme.textTheme.titleSmall),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isForeignCurrency) ...[
            const Divider(height: 1),
            InkWell(
              key: const ValueKey('expense_conversion_row'),
              onTap: onOpenConversion,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (converted == null)
                            Text(
                              key: const ValueKey(
                                'expense_conversion_rate_needed',
                              ),
                              l10n.expenseConversionRateNeeded,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          else
                            Text(
                              key: const ValueKey('expense_conversion_amount'),
                              formatMoney(converted, groupCurrency, locale),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ?_sourceChip(context, l10n),
                              ?_feeChip(l10n, locale),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Where the rate in the field came from, as one chip. Mutually exclusive
  /// states, so one key carries all of them and the tests read one thing.
  Widget? _sourceChip(BuildContext context, AppLocalizations l10n) {
    if (rateUnavailable) {
      return _ProvenanceChip(
        key: const ValueKey('expense_conversion_source_chip'),
        label: l10n.expenseNoRateChip(formatDate(ymd(expenseDate), context)),
        tone: _ChipTone.warning,
      );
    }
    switch (rateOrigin) {
      case RateOrigin.prefilled:
        return _ProvenanceChip(
          key: const ValueKey('expense_conversion_source_chip'),
          label: l10n.expenseSourceChip(formatDate(prefilledRateDate, context)),
          tone: _ChipTone.neutral,
        );
      case RateOrigin.user:
        return _ProvenanceChip(
          key: const ValueKey('expense_conversion_source_chip'),
          label: l10n.expenseTypedRateChip,
          tone: _ChipTone.neutral,
        );
      case RateOrigin.none:
        return null; // a fetch in flight: nothing true to say yet
    }
  }

  /// The fee chip, and the whole of its condition: a NON-ZERO fee that was
  /// actually applied, which is only ever to a fetched rate.
  Widget? _feeChip(AppLocalizations l10n, Locale locale) {
    // The fee is null-or-positive: CardFeeNotifier collapses every non-positive
    // value to null, in both its hydrate and its setter, so "a fee of 0" and
    // "no fee saved" reach here as the same state.
    final fee = cardFeePercent;
    if (fee == null || rateOrigin != RateOrigin.prefilled) {
      return null;
    }
    return _ProvenanceChip(
      key: const ValueKey('expense_conversion_fee_chip'),
      label: l10n.expenseFeeChip(
        l10n.cardFeePercentValue(formatPercentValue(fee, locale)),
      ),
      tone: _ChipTone.accent,
    );
  }
}

/// Tone of a provenance chip on the conversion row.
enum _ChipTone { neutral, accent, warning }

/// A stadium chip stating one fact about the rate in the field.
///
/// Colours come from the theme (and [SemanticColors], the repo's token
/// channel), never from fixed hexes, so the card reads correctly in dark mode
/// like every other surface in the app.
class _ProvenanceChip extends StatelessWidget {
  const _ProvenanceChip({super.key, required this.label, required this.tone});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    final (Color background, Color foreground) = switch (tone) {
      _ChipTone.neutral => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      ),
      _ChipTone.accent => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      _ChipTone.warning => (
        semantic.warning.withValues(alpha: 0.16),
        semantic.warning,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
