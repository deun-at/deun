import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/decimal_text_input_formatter.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';

/// Opens the card-fee entry sheet and WRITES the preference itself — Settings
/// and the conversion sheet are two surfaces over one number, so there is one
/// write site.
///
/// Lives under `pages/settings`, not `widgets/restyle`, because it writes a
/// preference and so must import `provider.dart`. The conversion sheet reaches
/// it through `ExpenseDetail`'s `onEditCardFee` callback rather than importing
/// it, which keeps `expense_picker_sheets.dart` provider-free.
///
/// Resolves to the fee now stored (null when none is, whether it was cleared or
/// the sheet was dismissed). Callers watching [cardFeeProvider] can ignore it.
Future<double?> showCardFeeSheet(BuildContext context, {double? initial}) =>
    showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: kSheetAnimationStyle,
      barrierColor: kSheetBarrierColor,
      builder: (_) => CardFeeSheet(initial: initial),
    );

/// The percent entry sheet behind both the Settings row and the conversion
/// sheet's fee row.
class CardFeeSheet extends ConsumerStatefulWidget {
  const CardFeeSheet({super.key, this.initial});

  /// The fee as currently stored, or null when none is.
  final double? initial;

  @override
  ConsumerState<CardFeeSheet> createState() => _CardFeeSheetState();
}

class _CardFeeSheetState extends ConsumerState<CardFeeSheet> {
  late final TextEditingController _controller;

  /// Set when Save was pressed on text that will not parse. Cleared on the
  /// next keystroke.
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    // Seeded blank rather than "0" so an unset fee reads as empty, not as a
    // value the user has to clear — 0 and unset are one state.
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.text.isEmpty && widget.initial != null) {
      _controller.text = formatPercentValue(
        widget.initial!,
        Localizations.localeOf(context),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    final parsed = parseCardFeePercent(text);
    // BLANK is the only thing that means "no fee". Anything else that will
    // not parse is a typo, and collapsing it to 0 would silently delete a
    // saved fee — reachable in `de`, where the field is seeded "1,4" and the
    // input formatter accepts a trailing separator ("1,4.") that
    // double.tryParse then rejects.
    if (text.isNotEmpty && parsed == null) {
      setState(() => _invalid = true);
      return;
    }
    final notifier = ref.read(cardFeeProvider.notifier);
    // setCardFeePercent collapses 0 into clearCardFee, so "0" and an empty
    // field are one path.
    await notifier.setCardFeePercent(parsed ?? 0);
    if (!mounted) return;
    Navigator.of(context).pop(notifier.cardFeePercent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SheetScaffold(
      title: l10n.cardFeeSheetTitle,
      footer: PrimaryButton(
        key: const ValueKey('card_fee_save'),
        label: l10n.save,
        onPressed: _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('card_fee_field'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Two decimals: card markups are quoted to a hundredth of a percent
            // at most (1.4, 1.75, 2.99), and more would invite precision the
            // number does not have.
            inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            decoration: InputDecoration(
              labelText: l10n.cardFeeSheetFieldLabel,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixText: ' %',
              errorText: _invalid ? l10n.cardFeeSheetInvalid : null,
            ),
          ),
          const SizedBox(height: 12),
          // Load-bearing: card networks convert at their own wholesale rate and
          // then add the fee, so this must not imply it reconciles a statement.
          Text(
            l10n.cardFeeSheetHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
