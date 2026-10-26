import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../helper/helper.dart';
import '../../../provider.dart';
import '../../groups/data/group_model.dart';
import '../data/editor_mode.dart';
import '../data/expense_conversion.dart';
import '../data/expense_deletion_impact.dart';
import '../data/expense_entry_model.dart';
import '../data/expense_model.dart';
import '../data/receipt_scan_result.dart';
import '../service/rate_source.dart';

part 'expense_editor_controller.g.dart';

/// The save CTA's three states: idle → busy → done.
///
/// The confirmation used to be a snackbar fired *after* `Navigator.pop`, so
/// it appeared on the screen behind; and nothing marked the write in flight,
/// so a second tap could start a second one. Both live on the button now.
enum EditorSaveStatus { idle, busy, done }

/// What [ExpenseEditorController.save] did, for the screen to show.
enum EditorSaveOutcome {
  saved,
  failed,
  refusedZeroTotal,
  refusedNoRate,
  ignoredInFlight,
}

/// What [ExpenseEditorController.delete] did, for the screen to show.
enum EditorDeleteOutcome { deleted, failed, ignoredInFlight }

/// One card in the editor, as it was seeded. Replaces the screen's mutable
/// `ExpenseEntryData`: the screen builds each card's `onRemove` from [index]
/// and passes the group's active members itself.
@immutable
class EditorEntry {
  const EditorEntry({
    required this.index,
    required this.expenseEntry,
    this.initialName,
    this.initialAmount,
    this.initialQuantity,
  });

  /// Names the card's `expense_entry[index]` form fields and keys its
  /// `ExpenseEntryWidget`. Never reused within one editor session.
  final int index;
  final ExpenseEntry expenseEntry;
  final String? initialName;
  final String? initialAmount;
  final String? initialQuantity;

  EditorEntry withInitialAmount(String? amount) => EditorEntry(
    index: index,
    expenseEntry: expenseEntry,
    initialName: initialName,
    initialAmount: amount,
    initialQuantity: initialQuantity,
  );
}

/// Where the rate currently in the editor's rate field came from.
///
/// The whole of "a user-entered rate always wins": a prefill may only ever
/// write into a field that is [none] or already [prefilled]. A [user] rate — one
/// typed this session, one a saved expense froze, or one remembered from a rate
/// the user typed before — is never overwritten and never even refetched for.
enum RateOrigin { none, user, prefilled }

/// What one opened expense editor is seeded from.
///
/// Equality is identity, deliberately: the screen creates one instance per
/// opened editor, in `initState`, and that instance is the controller's family
/// key. A key on the group would hand a reopened editor the last unsaved
/// session, and a key on fresh widget values would reset the session if a
/// rebuild ever produced new instances. Not `const`, for the same reason: a
/// canonicalised constant would let two editors share one key.
class ExpenseEditorArgs {
  ExpenseEditorArgs({
    required this.group,
    this.expense,
    this.receiptResult,
    this.lookupRate,
  });

  final Group group;
  final Expense? expense;
  final ReceiptScanResult? receiptResult;

  /// Test seam for the historical-rate prefill. Null in production →
  /// [fetchRate].
  final RateLookup? lookupRate;
}

const Object _unset = Object();

/// Everything the expense editor decides, as one immutable value.
///
/// The rate text is state here and the screen's rate `TextEditingController`
/// mirrors it.
@immutable
class ExpenseEditorState {
  const ExpenseEditorState({
    required this.groupCurrency,
    required this.entryCurrency,
    required this.rateText,
    required this.rateDate,
    required this.rateOrigin,
    required this.prefilledRateDate,
    required this.baseRate,
    required this.rateUnavailable,
    required this.entries,
    required this.itemizedOverride,
    required this.saveStatus,
    required this.deleteInFlight,
  });

  final Currency groupCurrency;

  /// The currency the amounts on the screen are TYPED in. Defaults to the
  /// group's; an existing converted expense opens on its frozen original.
  final Currency entryCurrency;

  /// What the rate field holds.
  final String rateText;

  /// `yyyy-MM-dd` the rate is attributed to. Stamped when a foreign currency is
  /// chosen and carried unchanged through every later edit of a non-amount
  /// field — nothing in this feature ever re-stamps a saved expense on its own.
  /// Changing the entry currency does re-stamp it: the rate then belongs to a
  /// different currency pair and is quoted today. See
  /// [rateDateForPickedCurrency].
  final String? rateDate;

  final RateOrigin rateOrigin;

  /// `yyyy-MM-dd` the PREFILLED rate is effective for — the day the source
  /// actually quoted it, which for a weekend or holiday expense is earlier than
  /// the expense's own date. Non-null exactly while [rateOrigin] is
  /// [RateOrigin.prefilled].
  final String? prefilledRateDate;

  /// The rate exactly as the source quoted it, BEFORE the card fee. Non-null
  /// exactly while [rateOrigin] is [RateOrigin.prefilled].
  ///
  /// Kept so a fee change recomputes rather than refetches: the rate for a pair
  /// and a date is immutable, so a refetch would return the same number, and
  /// the flight's only refetch trigger is a date change.
  final double? baseRate;

  /// True when the last prefill attempt for the current pair and date came back
  /// with nothing. Drives the visible explanation; never blocks a save.
  final bool rateUnavailable;

  /// The cards, in on-screen order.
  final List<EditorEntry> entries;

  /// Drives the Quick/Itemized top toggle. The app still distinguishes the two
  /// layouts by entry count (a single entry = Quick); this override lets the
  /// toggle force the Itemized layout while only one entry exists, without
  /// inventing a parallel data model. See [resolveEditorMode].
  final bool itemizedOverride;

  /// Where the save CTA is in its idle → busy → done cycle.
  final EditorSaveStatus saveStatus;

  /// True while a delete is out: the payback probe before the confirmation,
  /// and the delete write after it. A slow probe must not leave the header
  /// delete tappable (a repeat tap would stack a second dialog), and the write
  /// runs with the editor uncovered, so the header shows progress and ignores
  /// taps, and a save tap is refused, for both windows. Within a delete it is
  /// false only while the confirmation dialog is up, and that dialog is modal.
  final bool deleteInFlight;

  EditorMode get editorMode => resolveEditorMode(
    entryCount: entries.length,
    itemizedOverride: itemizedOverride,
  );

  /// Quick layout is shown only for a single entry with no itemized override.
  bool get isSingleEntry => isSingleEntryQuick(
    entryCount: entries.length,
    itemizedOverride: itemizedOverride,
  );

  bool get isForeignCurrency => entryCurrency != groupCurrency;

  double? get rate => parseConversionRate(rateText);

  /// The conversion a save will apply. Identity while the amounts are in the
  /// group's own currency.
  ExpenseConversion get conversion => isForeignCurrency
      ? ExpenseConversion(
          groupCurrency: groupCurrency,
          entryCurrency: entryCurrency,
          rate: rate,
          // A prefilled rate is attributed to the day it was actually quoted,
          // not the day the currency was picked.
          rateDate: prefilledRateDate ?? rateDate,
        )
      : ExpenseConversion.identity(groupCurrency);

  /// The nullable fields take [_unset] as "keep", so passing `null` clears them.
  ExpenseEditorState copyWith({
    Currency? entryCurrency,
    String? rateText,
    Object? rateDate = _unset,
    RateOrigin? rateOrigin,
    Object? prefilledRateDate = _unset,
    Object? baseRate = _unset,
    bool? rateUnavailable,
    List<EditorEntry>? entries,
    bool? itemizedOverride,
    EditorSaveStatus? saveStatus,
    bool? deleteInFlight,
  }) => ExpenseEditorState(
    groupCurrency: groupCurrency,
    entryCurrency: entryCurrency ?? this.entryCurrency,
    rateText: rateText ?? this.rateText,
    rateDate: identical(rateDate, _unset) ? this.rateDate : rateDate as String?,
    rateOrigin: rateOrigin ?? this.rateOrigin,
    prefilledRateDate: identical(prefilledRateDate, _unset)
        ? this.prefilledRateDate
        : prefilledRateDate as String?,
    baseRate: identical(baseRate, _unset) ? this.baseRate : baseRate as double?,
    rateUnavailable: rateUnavailable ?? this.rateUnavailable,
    entries: entries ?? this.entries,
    itemizedOverride: itemizedOverride ?? this.itemizedOverride,
    saveStatus: saveStatus ?? this.saveStatus,
    deleteInFlight: deleteInFlight ?? this.deleteInFlight,
  );
}

/// The expense editor's rules, owned apart from its widgets so they can be
/// proven without one.
///
/// One controller per opened editor: an auto-dispose family keyed on
/// [ExpenseEditorArgs]. It never `watch`es — watching [stickyRateProvider]
/// would re-run [build] and wipe the session when the stored rates hydrate and
/// when the user resets a rate. It reads the notifier and awaits `hydrated`
/// before reading a rate, and after every `await` it checks `ref.mounted`
/// before touching state.
@riverpod
class ExpenseEditorController extends _$ExpenseEditorController {
  /// Monotonic request token. The fetch is asynchronous, so a response for a
  /// date or currency the user has already moved off must be discarded rather
  /// than dropped into the field.
  int _rateRequestId = 0;

  @override
  ExpenseEditorState build(ExpenseEditorArgs args) {
    // A fee change re-applies to the base rate already fetched and issues NO
    // new request: the rate for a pair and a date is immutable, so a refetch
    // would return the same number.
    ref.listen<double?>(cardFeeProvider, (_, next) => _reapplyCardFee(next));

    final expense = args.expense;
    final entryCurrency = expense?.originalCurrencyCode != null
        ? Currency.fromCode(expense!.originalCurrencyCode)
        : args.group.currency;
    final loadedRate = expense?.conversionRate;

    _nextIndex = 0;
    final receipt = args.receiptResult;
    final entries = <EditorEntry>[];
    var itemizedOverride = false;
    if (expense != null && expense.expenseEntries.isNotEmpty) {
      // Claim units are regrouped into one qty-N item card per item_group_id
      // (F146). Their claims ride along on the synthetic entry so a re-save
      // can preserve them.
      final editorEntries = expense.editorEntries;
      _nextIndex = editorEntries.length;
      // A shared claim expense is itemized by definition — keep the itemized
      // layout even when its units regroup into a single card.
      itemizedOverride = editorEntries.any((e) => e.splitMode == 'claim');
      for (final expenseEntry in editorEntries) {
        entries.add(
          EditorEntry(
            index: expenseEntry.index,
            expenseEntry: expenseEntry,
            initialName: expenseEntry.name,
            // Seed the item card and the itemized total header directly from
            // the loaded entry — claim units have no shares, so the widget's
            // shares-gated seeding showed €0.00 line totals before.
            //
            // The seed is the exact inverse of the save: a line whose total did
            // not divide evenly over its units keeps the digits that multiply
            // back to it. Rounding here instead would reopen a 28.30 qty-3 line
            // as "9.43" and the next name-only save would store 28.29 — the
            // same one-sided rounding the switch-back already avoids.
            initialAmount: unitPriceFieldTextForTotal(
              expenseEntry.enteredLineTotal,
              expenseEntry.quantity,
              entryCurrency,
            ),
            initialQuantity: expenseEntry.quantity.toString(),
          ),
        );
      }
    } else if (receipt != null && receipt.lineItems.isNotEmpty) {
      // A scanned receipt with itemized lines opens in the Itemized layout.
      itemizedOverride = true;
      for (final item in receipt.lineItems) {
        entries.add(_entryFromReceiptLine(item, entryCurrency));
      }
    } else if (receipt != null && receipt.total != null) {
      entries.add(
        _freshEntry(
          initialAmount: amountToFieldText(receipt.total!, entryCurrency),
        ),
      );
    } else {
      entries.add(_freshEntry());
    }

    return ExpenseEditorState(
      groupCurrency: args.group.currency,
      entryCurrency: entryCurrency,
      rateText: loadedRate != null ? formatRate(loadedRate) : '',
      rateDate: expense?.rateDate,
      // A saved expense opens on its FROZEN rate. Nothing in the prefill may
      // touch it — not on open, not on a later date change.
      rateOrigin: loadedRate != null ? RateOrigin.user : RateOrigin.none,
      prefilledRateDate: null,
      baseRate: null,
      rateUnavailable: false,
      entries: entries,
      itemizedOverride: itemizedOverride,
      saveStatus: EditorSaveStatus.idle,
      deleteInFlight: false,
    );
  }

  /// The next card's index: monotonic, so a form field name is never reused
  /// within one editor session. It names the `expense_entry[i]` form fields
  /// and keys each card's widget.
  int _nextIndex = 0;

  /// A new item holding nothing yet, or just what is given.
  EditorEntry _freshEntry({
    String? initialName,
    String? initialAmount,
    String? initialQuantity,
  }) {
    final expenseEntry = ExpenseEntry(index: _nextIndex++);
    return EditorEntry(
      index: expenseEntry.index,
      expenseEntry: expenseEntry,
      initialName: initialName,
      initialAmount: initialAmount,
      initialQuantity: initialQuantity,
    );
  }

  /// An item row seeded from a scanned receipt line. The scan's `amount` is
  /// the LINE total ("5x Pita 12,50"), while the editor's amount field holds
  /// the unit price, so the quantity has to travel with it — dropping it
  /// turned every multi-unit line into a single unit priced at the line total.
  EditorEntry _entryFromReceiptLine(ReceiptLineItem item, Currency currency) =>
      _freshEntry(
        initialName: item.name,
        initialAmount: unitPriceFieldTextForTotal(
          item.amount,
          item.quantity,
          currency,
        ),
        initialQuantity: item.quantity.toString(),
      );

  /// The user has taken ownership of the rate.
  void rateTyped(String text) {
    // Nothing refetches for this field again, and the rate date reverts to
    // the pick-time stamp — the effective date belonged to the suggestion,
    // not to the number they just typed.
    state = state.copyWith(
      rateText: text,
      rateOrigin: RateOrigin.user,
      baseRate: null,
      prefilledRateDate: null,
      rateUnavailable: false,
    );
  }

  /// Fetches the historical rate for [expenseDate] and drops it into the rate
  /// as a suggestion.
  ///
  /// Refuses to run at all unless the field is free: a rate the user typed, a
  /// rate a saved expense froze and a rate remembered from one they typed
  /// before are all [RateOrigin.user], and this feature can neither overwrite
  /// nor refetch for any of them. The check runs twice — before the request and
  /// again after it resolves — because the user can type while it is in flight.
  Future<void> prefillRate({required DateTime expenseDate}) async {
    if (!state.isForeignCurrency || state.rateOrigin == RateOrigin.user) return;

    // The fee rides on the rate that is about to land, so it has to be loaded
    // before the answer arrives. Awaited HERE, before the request token, so the
    // existing staleness guard still covers the whole in-flight window.
    await ref.read(cardFeeProvider.notifier).hydrated;
    if (!ref.mounted ||
        !state.isForeignCurrency ||
        state.rateOrigin == RateOrigin.user) {
      return;
    }

    final base = state.entryCurrency;
    final quote = state.groupCurrency;
    final id = ++_rateRequestId;

    final result = await (args.lookupRate ?? fetchRate)(
      base: base,
      quote: quote,
      date: expenseDate,
    );

    // Superseded by a later pick or date change, the user has since made the
    // rate their own, or they switched back to the group currency and there is
    // no rate field left to write into. Either way this answer is stale.
    if (!ref.mounted ||
        id != _rateRequestId ||
        !state.isForeignCurrency ||
        state.rateOrigin == RateOrigin.user) {
      return;
    }

    if (result == null) {
      // A prefill for the PREVIOUS date must not stand under the new one —
      // that is the silent wrong-date substitution, arrived at by omission.
      state = state.copyWith(
        rateUnavailable: true,
        rateText: '',
        baseRate: null,
        prefilledRateDate: null,
        rateOrigin: RateOrigin.none,
      );
    } else {
      // The fee applies to a SUGGESTION and to nothing else: this is the one
      // place RateOrigin.prefilled is written, so it is the one place the
      // fee can enter a rate.
      state = state.copyWith(
        rateUnavailable: false,
        baseRate: result.rate,
        rateText: formatRate(
          applyCardFee(result.rate, ref.read(cardFeeProvider)),
        ),
        prefilledRateDate: ymd(result.effectiveDate),
        rateOrigin: RateOrigin.prefilled,
      );
    }
  }

  /// Picks [picked] as the entry currency. Called only for a currency other
  /// than the group's; going back to the group's goes through
  /// [switchBackToGroupCurrency].
  Future<void> pickEntryCurrency(
    Currency picked, {
    required DateTime expenseDate,
  }) async {
    // Await hydration before reading: this is a keepAlive provider and the
    // editor may be the first thing to touch it after app start.
    final sticky = ref.read(stickyRateProvider.notifier);
    await sticky.hydrated;
    if (!ref.mounted) return;
    final prefill = sticky.stickyRate(args.group.id, picked);

    state = state.copyWith(
      entryCurrency: picked,
      // A rate is per source currency — a CHF rate is meaningless for JPY, so
      // the field always follows the newly picked currency's remembered rate,
      // and the date follows it too: a rate typed after switching JPY -> CHF is
      // a CHF rate quoted today, never the old JPY rate's date. Only re-picking
      // the currency the expense was loaded with keeps its frozen date.
      rateText: prefill != null ? formatRate(prefill) : '',
      // A remembered rate is a rate the user typed, so it owns the field and
      // no prefill is fetched for it. Nothing remembered leaves the field free.
      rateOrigin: prefill != null ? RateOrigin.user : RateOrigin.none,
      baseRate: null,
      prefilledRateDate: null,
      rateUnavailable: false,
      // The date is a fact about the RATE, so the frozen one survives only
      // while the frozen rate is what the field will hold. Gating on the
      // currency alone misdates a round trip: CHF -> EUR -> CHF clears the
      // field and refills it from the sticky rate, which may never have been
      // quoted on the loaded date.
      rateDate: rateDateForPickedCurrency(
        picked: picked,
        loadedOriginalCurrencyCode: args.expense?.originalCurrencyCode,
        loadedRateDate: args.expense?.rateDate,
        loadedRate: args.expense?.conversionRate,
        pickedRate: prefill,
        today: DateTime.now(),
      ),
    );

    unawaited(prefillRate(expenseDate: expenseDate));
  }

  /// Forgets the remembered rate for the current currency and fetches a fresh
  /// one.
  Future<void> resetStickyRate({required DateTime expenseDate}) async {
    await ref
        .read(stickyRateProvider.notifier)
        .clearStickyRate(args.group.id, state.entryCurrency);
    if (!ref.mounted) return;
    // Ownership goes back to free, and a rate is fetched straight away.
    //
    // This state — foreign currency, empty field, nothing remembered — is
    // exactly the one a fresh currency pick produces, and that one fetches.
    // Not fetching here made the same state behave two ways depending on how
    // it was reached, and left the user on an empty field having just asked to
    // be rid of a stale number: the reason to clear a saved rate is almost
    // always that it is wrong, not that typing is preferred.
    state = state.copyWith(
      rateText: '',
      rateOrigin: RateOrigin.none,
      baseRate: null,
      prefilledRateDate: null,
      rateUnavailable: false,
    );
    unawaited(prefillRate(expenseDate: expenseDate));
  }

  /// Switches the editor back to the group's own currency.
  ///
  /// The amount fields hold amounts in the ENTRY currency, so leaving them as
  /// typed would save a 3000 JPY expense as 3000 EUR, and clearing them would
  /// silently discard the user's numbers. Each field is re-converted at the
  /// FROZEN rate the expense is already carrying, which preserves the value the
  /// ledger holds today: a converted 17.40 EUR expense switched back to EUR
  /// stays 17.40, not 3000. The provenance clears in the same step.
  ///
  /// With no rate in effect nothing was ever converted, so the typed numbers
  /// pass through untouched.
  ///
  /// Returns the converted amount texts, parallel to [enteredTexts], for the
  /// screen to write into the form.
  List<String> switchBackToGroupCurrency({
    required List<String> enteredTexts,
    required List<int> quantities,
  }) {
    // Amount fields hold UNIT prices, so the quantities ride along: each line
    // converts once and its remainder distributes across its units, exactly as
    // the save does. Re-converting the unit price alone would drop the
    // remainder — a qty-3 10.00 CHF line at 0.9432 is 28.30 in the ledger and
    // 9.43 x3 = 28.29 without it.
    final converted = switchBackAmountTexts(
      enteredTexts: enteredTexts,
      rate: state.rate,
      groupCurrency: state.groupCurrency,
      quantities: quantities,
    );
    state = state.copyWith(
      entryCurrency: state.groupCurrency,
      rateText: '',
      rateDate: null,
      rateOrigin: RateOrigin.none,
      baseRate: null,
      prefilledRateDate: null,
      rateUnavailable: false,
      // In the same step as the currency: the cards must see both in one frame.
      entries: [
        for (var i = 0; i < state.entries.length; i++)
          state.entries[i].withInitialAmount(converted[i]),
      ],
    );
    return converted;
  }

  /// Saves the expense: everything up to the write, and the rate remembered
  /// after it. The form's validation stays in the screen and runs first.
  ///
  /// [total] is the sum of the live item lines. [write] sends the expense with
  /// the conversion handed to it; the screen binds the saver, the ids and the
  /// draft, so nothing here needs a context.
  Future<EditorSaveOutcome> save({
    required double total,
    required Future<void> Function(ExpenseConversion conversion) write,
  }) async {
    // Individual lines may be negative (discounts), but the expense total
    // must stay positive — a non-positive total collapses every member's
    // percentage share to 0% in ExpenseRepository.saveAll.
    if (total <= 0) return EditorSaveOutcome.refusedZeroTotal;
    // No implicit rate: an expense in a currency other than the group's
    // cannot be saved without one. No 1:1 fallback, no silent substitution.
    final conversion = state.conversion;
    if (!conversion.isIdentity && conversion.rate == null) {
      return EditorSaveOutcome.refusedNoRate;
    }
    // Past every validation gate — from here a write is actually going out.
    // Single flight across both writes: no save while a delete is out.
    if (state.saveStatus != EditorSaveStatus.idle || state.deleteInFlight) {
      return EditorSaveOutcome.ignoredInFlight;
    }
    // Captured with the conversion the write is sent with, so a rate typed
    // while the write is out cannot turn a prefill into a remembered rate.
    final remember =
        !conversion.isIdentity && state.rateOrigin == RateOrigin.user;
    state = state.copyWith(saveStatus: EditorSaveStatus.busy);

    final written = await _runWrite(
      // Failures still need words — a check would be a lie, and "something
      // went wrong" can't be mimed.
      () => write(conversion),
      onFailure: (s) => s.copyWith(saveStatus: EditorSaveStatus.idle),
    );
    if (!written) return EditorSaveOutcome.failed;
    // The write committed. A closed editor remembers nothing.
    if (!ref.mounted) return EditorSaveOutcome.saved;

    if (remember) {
      // Remember the rate for the next expense in this currency in this
      // group — a trip holds one agreed rate with no separate concept.
      //
      // Only a rate the USER supplied. Remembering a prefill would make
      // the suggestion its own successor: the fetch would fire once per
      // group and currency and then be shadowed forever by its first
      // answer, which is the opposite of a rate for each expense's own
      // date.
      //
      // The write has already committed, so failing to remember the
      // rate is not a failed save: reporting it as one would invite a
      // duplicate. Logged only.
      try {
        await ref
            .read(stickyRateProvider.notifier)
            .setStickyRate(
              args.group.id,
              conversion.entryCurrency,
              conversion.rate!,
            );
      } catch (e) {
        debugPrint('Could not remember the typed rate: $e');
      }
    }
    if (!ref.mounted) return EditorSaveOutcome.saved;
    // The confirmation is the check on the CTA; the screen holds it long
    // enough to read before the route goes.
    state = state.copyWith(saveStatus: EditorSaveStatus.done);
    return EditorSaveOutcome.saved;
  }

  /// Runs the payback probe before a delete's confirmation. Null when a save
  /// or a delete is already out, or when the editor closed meanwhile.
  ///
  /// A failed probe is [probe]'s to degrade (see `probeDeletionImpact`).
  Future<ExpenseDeletionImpact?> probeDeletion(
    Future<ExpenseDeletionImpact> Function() probe,
  ) async {
    // Single flight across both writes: no delete while a probe or a delete is
    // already out, nor while a save is in flight or showing its check.
    // Checked before any state flips.
    if (state.deleteInFlight || state.saveStatus != EditorSaveStatus.idle) {
      return null;
    }
    state = state.copyWith(deleteInFlight: true);
    final impact = await probe();
    if (!ref.mounted) return null;
    state = state.copyWith(deleteInFlight: false);
    return impact;
  }

  /// Runs the delete [write], after the screen's confirmation. After a success
  /// the in-flight flag stays set until the route pops.
  Future<EditorDeleteOutcome> delete(Future<void> Function() write) async {
    if (state.deleteInFlight || state.saveStatus != EditorSaveStatus.idle) {
      return EditorDeleteOutcome.ignoredInFlight;
    }
    state = state.copyWith(deleteInFlight: true);
    final deleted = await _runWrite(
      write,
      onFailure: (s) => s.copyWith(deleteInFlight: false),
    );
    return deleted ? EditorDeleteOutcome.deleted : EditorDeleteOutcome.failed;
  }

  /// Runs [write]. A throw is logged, [onFailure] puts the in-flight state
  /// back (only while this editor is still open) and the result is false.
  /// There is deliberately no `finally`: a failure has no route to success.
  Future<bool> _runWrite(
    Future<void> Function() write, {
    required ExpenseEditorState Function(ExpenseEditorState) onFailure,
  }) async {
    try {
      await write();
      return true;
    } catch (e) {
      debugPrint('Expense write failed: $e');
      if (ref.mounted) state = onFailure(state);
      return false;
    }
  }

  /// Adds an empty item. When the single Quick entry becomes the first of
  /// several, the Quick amount ([quickAmountText]) transfers to it.
  void addEntry({required String quickAmountText}) {
    final entries = [...state.entries];
    if (state.isSingleEntry &&
        quickAmountText.isNotEmpty &&
        quickAmountText != '0') {
      entries[0] = entries[0].withInitialAmount(quickAmountText);
    }
    entries.add(_freshEntry());
    state = state.copyWith(entries: entries);
  }

  void removeEntry(int index) {
    state = state.copyWith(
      entries: state.entries.where((e) => e.index != index).toList(),
    );
  }

  /// Maps the Quick/Itemized toggle onto the existing entry-count mode.
  ///
  /// Quick → Itemized: flip the override so the (possibly single) entry renders
  /// as an item card, seeding the first item's amount from the quick amount —
  /// the same hand-off [addEntry] already performs.
  ///
  /// Itemized → Quick: collapses the item list into one expense-level amount.
  /// The Quick amount is seeded with the *summed* total of every item line
  /// ([itemizedTotal], scan-split-even), not just the first item's — so the
  /// receipt total is preserved and can be split evenly.
  /// [firstAmountFieldText] is the first item's live amount field, used when
  /// that total is not positive.
  ///
  /// Returns the text the Quick amount field now holds, or null when it is
  /// unchanged.
  String? setMode(
    EditorMode mode, {
    required String quickAmountText,
    required double itemizedTotal,
    required String? firstAmountFieldText,
  }) {
    if (mode == state.editorMode || state.entries.isEmpty) return null;
    if (mode == EditorMode.itemized) {
      var entries = state.entries;
      if (entries.length == 1 &&
          quickAmountText.isNotEmpty &&
          quickAmountText != '0') {
        entries = [entries.first.withInitialAmount(quickAmountText)];
      }
      state = state.copyWith(entries: entries, itemizedOverride: true);
      return null;
    }
    // Back to Quick. BUG B: with 2+ entries the toggle used to no-op
    // silently — the tab snapped back to Itemized and read as a dead,
    // unpressable control. Quick has a single expense-level amount, so
    // collapse the itemized items into one entry. scan-split-even: seed
    // the Quick amount from the SUM of every item line total (read live
    // before dropping the extras) so the full receipt value survives —
    // the old code kept only the first item's amount and silently lost
    // the rest. Now the toggle is always honored and value-preserving.
    var first = state.entries.first;
    final amount = itemizedTotal > 0
        ? amountToFieldText(itemizedTotal, state.entryCurrency)
        : firstAmountFieldText;
    final seeded = amount != null && amount.isNotEmpty;
    if (seeded) first = first.withInitialAmount(amount);
    state = state.copyWith(entries: [first], itemizedOverride: false);
    return seeded ? amount : null;
  }

  /// Replaces the items with a scan's lines. Scanned lines open Itemized, and
  /// claiming stays the default after a scan.
  void replaceEntriesWithScannedLines(List<ReceiptLineItem> lines) {
    state = state.copyWith(
      itemizedOverride: true,
      entries: [
        for (final line in lines)
          _entryFromReceiptLine(line, state.entryCurrency),
      ],
    );
  }

  /// Applies a total-only scan: through the same channels as the keypad, the
  /// first item's seed, so the row, the itemized total and the save all hold
  /// the scanned total. Written at the ENTRY currency's precision: CHF 12.34 in
  /// a JPY group stays 12.34. The receipt total is what the item costs, so the
  /// first item goes back to one unit: its old quantity would multiply the
  /// total (the screen resets the quantity field). Returns the field text.
  String applyScannedTotal(double total) {
    final text = amountToFieldText(total, state.entryCurrency);
    state = state.copyWith(
      entries: state.entries.isEmpty
          // Every item was removed: the total gets a fresh item instead of
          // being dropped.
          ? [_freshEntry(initialAmount: text)]
          // Only the first item: replacing items is the line-item branch's job.
          : [
              state.entries.first.withInitialAmount(text),
              ...state.entries.skip(1),
            ],
    );
    return text;
  }

  /// Re-applies a changed fee to the base rate already fetched. No
  /// `_rateRequestId` bump and no [prefillRate] call — recompute only.
  void _reapplyCardFee(double? feePercent) {
    final base = state.baseRate;
    if (base == null || state.rateOrigin != RateOrigin.prefilled) return;
    state = state.copyWith(
      rateText: formatRate(applyCardFee(base, feePercent)),
    );
  }
}
