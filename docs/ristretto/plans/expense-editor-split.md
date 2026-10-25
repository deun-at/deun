# expense-editor-split

## Spec
- Source: idea — code review 2026-10-22 (research/code-review-2026-10.md), Architecture item: `lib/pages/expenses/presentation/expense_detail.dart` is 1898 lines (1098 at the 2026-07-07 review), with 1 lib importer and 8 test importers; the CODE_REVIEW_2026-07-07 §6 "leave alone" advice listed under Open
- Goal: The editor's entries, Quick/Itemized mode, rate state and save status move into a Riverpod controller that unit tests can reach without a widget. The screen is assembled from section widgets in their own files, and nothing changes for the user.
- Why: Jakob as sole maintainer · noticed by: the backend rebuilds from supabase/migrations/, the fallback code paths are gone, the 1500–1900-line files open in pieces

## Contract
- Acceptance:
  - [auto] Saving, failing, retrying and deleting work as they do once the dependencies land. A failed save or delete keeps the editor and what was typed, each tap sends one write, the check shows before the pop, a sticky-rate failure after a good write still counts as saved, and a confirmed delete calls the deleter once with the expense's own ids. Already enforced by test/widgets/expense_save_status_test.dart and test/widgets/expense_editor_delete_guard_test.dart, as they stand when this feature starts (after editor-failure-keeps-form and typed-expense-draft). Both must stay green, with no setup or expected value changed.
  - [auto] The entry currency and the rate work as before. Already enforced by test/widgets/expense_editor_currency_rate_test.dart (including "saving that exact split back reproduces its ledger values byte-identically" and the two CHF -> EUR -> CHF round-trip dating cases) and test/widgets/expense_editor_rate_prefill_test.dart (including "a rate arriving LATE never overwrites one the user has typed" and "an accepted prefill is saved but never remembered"). The second file pumps the editor through the first file's helpers. Both are taken as they stand when this feature starts and must stay green, with no setup or expected value changed.
  - [auto] Layout, mode switching, labels, the removed-member roster and scanning work as before. Already enforced by:
    - test/widgets/expense_itemized_editor_test.dart, including "a name typed in Quick is still there after switching to Itemized" and "collapsing a multi-item itemized expense to Quick seeds the summed total"
    - test/widgets/expense_detail_tiles_test.dart, including "the paid-by sheet omits a removed member" and "the split member list omits a removed member"
    - test/widgets/expense_editor_amount_locale_test.dart
    - test/widgets/expense_editor_edit_labels_test.dart
    - test/pages/groups/v3_header_migration_test.dart
    - test/widgets/expense_editor_rescan_test.dart, added by scan-total-applies
    - the draft hand-over widget test that typed-expense-draft adds

    All of them are taken as they stand when this feature starts and must stay green, with no setup or expected value changed. With the save-status, delete-guard and currency-rate suites above, these include all eight test files that import expense_detail.dart at HEAD.
  - [auto] A prefill never replaces a rate the user owns. Unit tests on the controller, with no widget pumped, prove two things:
    - After the user types a rate, a prefill answer requested earlier that arrives later leaves the typed text, its origin and its pick-time rate date untouched.
    - A date change requests no lookup at all for an expense opened on its saved (frozen) rate, or for a currency that was picked onto a remembered rate.
  - [auto] Only the answer to the latest prefill request lands. Unit tests on the controller prove this case: CHF is picked on 2026-07-01, and the expense date then moves to 2026-07-04 before the first answer arrives. The 2026-07-01 answer, arriving last, is dropped. The field holds the 2026-07-04 answer, dated with the effective date that answer carries. Two variants with an empty 2026-07-04 answer: if the 2026-07-01 answer had already landed, the field, its prefilled date and its origin are cleared rather than left standing under the new date; if the 2026-07-01 answer arrives after the empty one, it is still dropped. Either way the rate is reported unavailable.
  - [auto] The save gets the conversion the screen shows. Unit tests on the controller prove three things:
    - In the group currency the write receives the identity conversion.
    - In a foreign currency the write receives the entry currency, the parsed rate and a rate date. That date is the prefill's effective date for a prefilled rate, or the pick-time date for a typed rate.
    - Switching back to the group currency converts the typed amounts at the rate in effect (3000 JPY at 0.0058 becomes 17.40, and a qty-3 10.00 CHF line at 0.9432 keeps its 28.30 total), and clears the rate, its date and its origin.
  - [auto] The save refuses bad writes and remembers the right rates. Unit tests on the controller prove five things:
    - A non-positive total, or a foreign currency with no rate, writes nothing and reports which refusal it was.
    - A save started while a save or a delete is still running writes nothing.
    - After a successful write, a typed foreign rate is remembered for that group and currency. A prefilled rate never is.
    - If remembering the rate throws, the save is still reported as succeeded, and the write ran exactly once.
    - A failed write remembers nothing and returns the status to idle.
  - [auto] Closing the editor while a rate lookup or a write is still pending does no harm. When the pending lookup or write resolves after the close, nothing throws uncaught, no editor state is written, no rate is remembered, and the write that had already been sent is not sent again.
  - [auto] Each editor starts fresh. The user opens the editor, picks CHF, types a rate, switches to Itemized and adds an item, then closes it without saving. A new editor opened on the same group shows the group currency, no rate field and one empty entry.
  - [auto] What the user entered survives a change in the remembered rates. When the stored remembered rates finish loading after the editor opened, the entries, the entry currency and the rate field stay as they were. Resetting a remembered rate clears only the rate and fetches a fresh one. It never touches the entries or the entry currency. The fetch half is already enforced by "clearing a saved rate fetches a fresh one" in test/widgets/expense_editor_rate_prefill_test.dart (must stay green); the untouched entries and entry currency are new.
  - [auto] `dart format`, `flutter analyze` and `flutter test` pass.
- Provides:
  - Unchanged, and still declared in lib/pages/expenses/presentation/expense_detail.dart:
    - `ExpenseDetail({Key? key, required Group group, Expense? expense, ReceiptScanResult? receiptResult, GroupPaybackLoader? loadGroupPaybacks, ExpenseSaver? saveExpense, RateLookup? lookupRate, ExpenseDeleter? deleteExpense, ReceiptScanner? scanReceipt})`
    - `typedef ExpenseSaver`, in the shape typed-expense-draft leaves it
    - `typedef ReceiptScanner = Future<ReceiptScanResult?> Function(BuildContext context)`
  - New in lib/pages/expenses/provider/expense_editor_controller.dart, with the generated part committed:
    - `@riverpod class ExpenseEditorController extends _$ExpenseEditorController`, with `ExpenseEditorState build(ExpenseEditorArgs args)`. This generates the auto-dispose family `expenseEditorControllerProvider(ExpenseEditorArgs args)`.
    - `ExpenseEditorArgs({required Group group, Expense? expense, ReceiptScanResult? receiptResult, RateLookup? lookupRate})`. Equality is identity. One instance is created per opened editor.
    - `ExpenseEditorState`, an immutable value:
      - fields: `List<EditorEntry> entries`, `bool itemizedOverride`, `Currency groupCurrency`, `Currency entryCurrency`, `String rateText`, `String? rateDate`, `RateOrigin rateOrigin`, `String? prefilledRateDate`, `bool rateUnavailable`, `EditorSaveStatus saveStatus`, `bool deleteInFlight`
      - getters: `EditorMode editorMode`, `bool isSingleEntry`, `bool isForeignCurrency`, `double? rate`, `ExpenseConversion conversion`
    - `EditorEntry({required int index, required ExpenseEntry expenseEntry, String? initialName, String? initialAmount, String? initialQuantity})`, an immutable value that replaces `ExpenseEntryData`
    - `enum RateOrigin { none, user, prefilled }`, `enum EditorSaveStatus { idle, busy, done }`, `enum EditorSaveOutcome { saved, failed, refusedZeroTotal, refusedNoRate, ignoredInFlight }` and `enum EditorDeleteOutcome { deleted, failed, ignoredInFlight }`
    - Rate methods:
      - `void rateTyped(String text)`
      - `Future<void> pickEntryCurrency(Currency picked, {required DateTime expenseDate})`. Called only for a currency other than the group's.
      - `Future<void> prefillRate({required DateTime expenseDate})`
      - `Future<void> resetStickyRate({required DateTime expenseDate})`
      - `List<String> switchBackToGroupCurrency({required List<String> enteredTexts, required List<int> quantities})`. Returns the converted amount texts for the screen to write into the form.
    - Write methods:
      - `Future<EditorSaveOutcome> save({required double total, required Future<void> Function(ExpenseConversion conversion) write})`
      - `Future<ExpenseDeletionImpact?> probeDeletion(Future<ExpenseDeletionImpact> Function() probe)`. Returns null when a write is in flight.
      - `Future<EditorDeleteOutcome> delete(Future<void> Function() write)`
    - Entry and mode methods: `void addEntry(…)`, `void removeEntry(int index)`, `setMode(EditorMode mode, …)`, plus replacing the entries with scanned lines and the first-entry seeding scan-total-applies needs. Each takes the live form readings it needs as arguments. Their exact parameter lists are the planner's to decide.
- Consumes:
  - typed-expense-draft: `ExpenseDraft`, `ExpenseEntryDraft`, `ExpenseDraft.markEntriesClaimable({Set<String>? notifyEmails}): ExpenseDraft`, and `typedef ExpenseSaver` in its draft-taking shape
  - editor-failure-keeps-form: `ExpenseDetail.deleteExpense` (`ExpenseDeleter?`), and `typedef ExpenseDeleter = Future<void> Function(String expenseId, String groupId)` in lib/pages/expenses/data/expense_deletion_impact.dart
  - scan-total-applies: `typedef ReceiptScanner = Future<ReceiptScanResult?> Function(BuildContext context)` and `ExpenseDetail.scanReceipt`
- Decisions:
  - CODE_REVIEW_2026-07-07 §6 said to leave expense_detail.dart alone. That advice is superseded, and the file is split. Source: Jakob in prep code-review-2026-10 (2026-10-24), answering the Open item in research/code-review-2026-10.md.
  - Unchanged surface -> expense_detail.dart keeps its path and keeps declaring `ExpenseDetail`, `ExpenseSaver` and `ReceiptScanner`. The constructor and its five test seams stay exactly as the dependencies leave them, so the route that builds the editor (lib/navigation.dart, or lib/app_router.dart once typed-routes has landed) and the 8 importing test files need no edit. Behaviour is unchanged (Jakob in prep code-review-2026-10 (2026-10-24)).
  - The controller is a code-generated Riverpod notifier, the house standard. CLAUDE.md puts feature notifiers under lib/pages/*/provider/, and claim_notifier.dart is the expenses precedent. The controller owns the entries, the Quick/Itemized mode, the rate state (origin, prefill request token, sticky-rate reads and writes) and the save status (Jakob in prep code-review-2026-10 (2026-10-24)). As a technical ruling it also owns the delete in-flight flag, covering both the probe and the write. editor-failure-keeps-form's single-flight rule spans both writes, and with a single owner that rule is testable without a widget.
  - One controller per opened editor -> an auto-dispose family keyed on an `ExpenseEditorArgs` that the screen creates once in `initState` and compares by identity. Two other keys were rejected:
    - Keying on the group, or on its id, would let a reopened editor inherit the last unsaved session.
    - Keying on fresh widget values would reset the session if a rebuild ever produced new instances.

    The editor's group is a snapshot handed to the constructor, from the route's `extra` (lib/navigation.dart) or, once typed-routes has landed, from its route loader, which keeps page constructors unchanged. Seeding the controller once is exactly what `initState` does today. Source: follows from "behaviour unchanged" (Jakob in prep code-review-2026-10 (2026-10-24)).
  - The controller never uses `ref.watch` in `build`. Watching `stickyRateProvider` would re-run `build` and wipe the session in two cases: when the stored rates hydrate, and when the user resets a rate. It reads `stickyRateProvider.notifier` with `ref.read` and awaits `hydrated` before reading a prefill, as `_pickEntryCurrency` does today. The screen keeps watching `stickyRateProvider` for the Reset button's visibility. Sources: "behaviour unchanged" (Jakob in prep code-review-2026-10 (2026-10-24)); the hydrate-then-read ordering documented on `StickyRateNotifier` in lib/provider.dart (multi-currency-expense-rate).
  - After every await, the controller checks `ref.mounted` before writing state or remembering a rate. This takes over from today's `mounted` checks. Riverpod 3 refuses a disposed Ref, and the precedent is ExpenseListNotifier's `reload`/`loadMoreEntries` (research/code-review-2026-10.md). It keeps today's behaviour for a write that resolves after the editor closed: no rate is remembered then either, because the State's `ref.read` throws once the widget is unmounted (flutter_riverpod 3.3.2) and `_saveExpense`'s catch swallows it.
  - Boundary -> the controller holds no BuildContext. It reads no `supabase` global, `Navigator`, `ScaffoldMessenger`, `MediaQuery` or `AppLocalizations`, so its unit tests need no `Supabase.initialize` and no widget. The screen keeps:
    - the FormBuilder key and fields
    - the name, quick-amount and rate `TextEditingController`s
    - the dirty flag and the discard guard (`_isDirty`, `_bypassDiscardGuard`, `PopScope`)
    - category detection
    - the keypad and scan sheets
    - the draft builder
    - the confirmation hold, the SnackBars and the pops

    The screen marks the form dirty around the user intents that do so today: typing a rate, picking a currency, switching back, scanning. The `supabase.auth` reads (paid-by default, member sort, "you") stay in the screen and the sections. Removing them is injectable-repositories' job (research/code-review-2026-10.md). Source for the boundary: the controller's rules must be reachable without a widget (Jakob in prep code-review-2026-10 (2026-10-24)).
  - The rate text is controller state, and the screen's rate `TextEditingController` mirrors it. The screen writes the text into the field only when the controller changed it and it differs (prefill, pick, reset, switch-back). Typing reports through `rateTyped`, so the cursor never jumps. Source: the controller owns the rate state, and behaviour is unchanged (Jakob in prep code-review-2026-10 (2026-10-24)).
  - Save flow -> the controller handles everything up to the write and the remembered rate:
    - the two gates: a non-positive total, then a missing rate
    - the single-flight check, which comes after the gates, as today
    - the busy flip, then the write
    - the sticky-rate step, run only after a successful write and only for a user-origin foreign rate; it is wrapped and only `debugPrint`ed on failure (editor-failure-keeps-form)
    - the status flip, then the outcome

    The form's `saveAndValidate` stays in the screen and runs first, as today. The screen maps each outcome to today's SnackBar (`expenseEntryAmountValidationZero`, `expenseRateRequired`, `expenseCreateError`) or to the hold-then-pop. The `total` is `itemizedTotal` over the live form lines, as `_itemizedTotalFromForm` computes it today. Sources: the controller owns the save status (Jakob in prep code-review-2026-10 (2026-10-24)); editor-failure-keeps-form and save-status-rollout for the outcomes.
  - The write closure receives the controller's conversion. The screen binds the rest: the saver (`saveExpense ?? ExpenseRepository.saveAll`), its sender-side parameter as it stands at implementation time, the group and expense ids, and the draft. If notification-context-free has landed, that is its trailing `notifications:` named `NotificationSender`, built in the screen before the controller's first await (notification-context-free plan, Decisions). Otherwise it is today's leading context, which never enters the controller. The draft is built inside the closure, so a parse failure lands in the controller's failure branch and gives the save-error path. That is typed-expense-draft's ruling. The claimable path's `markEntriesClaimable(notifyEmails: active member emails)` and each card's existing claims stay in the screen's draft builder.
  - editor-failure-keeps-form's "write, then pop only on success" helper is private to `_ExpenseDetailState` and not in that plan's Provides (editor-failure-keeps-form plan, Decisions). The brief's "consumes the shared save-flow helper" (Jakob in prep code-review-2026-10 (2026-10-24)) is therefore honoured by consuming its behaviour, as pinned by its tests, rather than a surface. It stays one flow, not two. One controller write runner sits behind both save and delete. One screen-side handler shows the outcome's SnackBar and, on success only, sets `_bypassDiscardGuard` immediately before the pop.
  - Delete -> the header action and the confirmation dialog move to their own file. The dialog only asks and resolves to a confirmation, which is editor-failure-keeps-form's shape. It stays the existing `AlertDialog` with today's title, message and actions, because the delete-guard tests find it by type and text (expense-delete-settled-guard). The probe runs through `probeDeletion` with `probeDeletionImpact(expense, loader: widget.loadGroupPaybacks)`, and the write runs through `delete`. Both are bound by the screen.
  - Rate rules move verbatim:
    - `_prefillRate`'s guard runs both before and after the await.
    - Typing takes ownership: origin becomes user, and the prefilled date and the unavailable flag clear.
    - A pick prefills from the remembered rate, dates the rate with `rateDateForPickedCurrency`, then fetches.
    - Reset clears the remembered rate, sets origin to none and refetches.
    - Switch-back runs `switchBackAmountTexts` and clears the provenance.
    - The conversion's date is the prefilled date when there is one, otherwise the pick date.

    The pure helpers in lib/pages/expenses/data/expense_conversion.dart (`rateDateForPickedCurrency`, `switchBackAmountTexts`, `unitPriceFieldTextForTotal`, `ledgerTotalOfLines`), lib/pages/expenses/service/rate_source.dart (`RateLookup`, `fetchRate`) and lib/helper/helper.dart (`parseConversionRate`, `formatRate`, `ymd`, `amountToFieldText`) are reused unchanged (multi-currency-expense-rate, multi-currency-rate-source). If helper-split has moved the helper.dart ones by then, they are imported from wherever it put them. The explanatory comments move with the code they explain, because several of them record rulings (rate precision 12, "a user-entered rate always wins").
  - Entries -> `ExpenseEntryData` is replaced by the immutable `EditorEntry`, and the screen builds each card's `onRemove` from its index. The monotonic entry index (today `_newTextFieldId`) moves to the controller and is never reused within a session. It names the `expense_entry[i]` form fields and keys each `ExpenseEntryWidget`. `build(args)` seeds the entries the way `initState` does today:
    - a loaded expense: its `editorEntries`, with `unitPriceFieldTextForTotal` seeds, and `itemizedOverride` set for a claim expense
    - a receipt with lines
    - a receipt with only a total
    - otherwise, one empty entry

    The mode still comes from `resolveEditorMode` and `isSingleEntryQuick` (lib/pages/expenses/data/editor_mode.dart). Source: the controller owns the entries and the Quick/Itemized mode (Jakob in prep code-review-2026-10 (2026-10-24)).
  - Sections go under lib/pages/expenses/presentation/editor/, one per file (Jakob in prep code-review-2026-10 (2026-10-24), "in their own files"):
    - currency & rate: the entry-currency card, the rate field, the prefilled-on or unavailable line, the preview, Reset
    - quick amount: the expense-level amount field and the per-head line
    - itemized header: the total and Scan, plus the info callout
    - name field
    - paid-by & date card, with its row widget kept private
    - delete action and its confirmation
    - the entry list: the Quick column, or Itemized's single SoftCard with dividers
    - the save footer

    Public section widgets take an `Editor` prefix (for example `EditorCurrencyRateSection`) and reuse no existing name (`EditorMode`, `ExpenseEntryWidget`, `ExpenseDetail`). They are public only because each file is its own library, so they are not in Provides. There are no hand-written `part` files.
  - Section widgets are plain widgets that take values and callbacks through their constructors. Only the screen watches providers. This is the presentation-file-split precedent.
  - The form and key contract stays byte-identical, because the suites named in Acceptance locate these and behaviour is unchanged (Jakob in prep code-review-2026-10 (2026-10-24)):
    - field names `name`, `expense_date`, `paid_by`, `category` and `expense_entry[i][amount]`
    - the ValueKeys `expense_entry_currency`, `expense_rate_field`, `expense_rate_prefill_date`, `expense_rate_unavailable`, `expense_rate_preview`, `expense_rate_reset`, `expense_name_field` and `expense_level_amount_<i>`
    - the `ExpenseEntryWidget` key `ValueKey(index)`
    - the widget types and ancestry the suites locate: `SoftCard`, `Padding`, `Divider`, `DashedGhostButton`, `CategorySelector`, `ListView`, `PrimaryButton`, `AppSegmentedControl<EditorMode>`

    The name field keeps its `initialValue` seed from the name controller, as today. That seed is the fix for the field being re-registered on a mode switch (the comment on `_buildNameField` records it).
  - No identifier or string containing `ExchangeRate` or `homeCurrency` appears in any new lib file. test/pages/groups/multi_currency_group_test.dart sweeps all of lib/ for both (multi-currency-group).
  - Size target (a build instruction, not a criterion; Jakob in prep code-review-2026-10 (2026-10-24), file sizes are Decisions): afterwards expense_detail.dart is at most about 500 lines, and no new file is over about 500.
  - Tests -> the controller's unit tests go in the new test/provider/expense_editor_controller_test.dart (Jakob in prep code-review-2026-10 (2026-10-24): the rate and save rules get direct unit tests). They use a `ProviderContainer`, a `RateLookup` stub modelled on `_StubLookup` in test/widgets/expense_editor_rate_prefill_test.dart but holding each date's answer back separately (today's `_StubLookup` has one shared gate), gated write closures, and the fake `async_preferences` channel (`installFakePrefs` in test/widgets/expense_editor_currency_rate_test.dart) or a `stickyRateProvider` override. The close-mid-work criterion closes the test's only subscription to the auto-dispose provider while a gated lookup or write is pending, then releases the gate. The fresh-start criterion is a widget test in that file or an existing editor suite. Existing suites are taken as they stand when this feature starts, and no expected value in them is edited.
  - presentation-file-split owns expense_entry_widget.dart and the §6 rebalancing math, so this feature does not touch that file (presentation-file-split plan, Decisions).
  - (a) Per-group currency -> the entry currency, rate, rate date, origin and prefilled date move into controller state. The conversion is still an `ExpenseConversion` built on the client before the write, and provenance and the RPC arithmetic are untouched (multi-currency-expense-rate). `isSettled`/`kSettledEpsilon` are not involved.
  - (b) Email identity -> unchanged. The payer, shares and claimers stay member emails inside the draft builder (typed-expense-draft).
  - (c) Soft-removed members -> unchanged. Cards and the paid-by sheet take `group.activeMembers`, and the payer's name still resolves from the full `groupMembers` (group-member-removal). Already enforced by the two removed-member cases in test/widgets/expense_detail_tiles_test.dart.
  - (d) Guests -> does not apply. The editor has no guest logic.
  - (e) Locale -> no new strings. Existing keys are reused verbatim. If a string turns out to be unavoidable, it goes into both lib/l10n/app_en.arb and lib/l10n/app_de.arb.
  - (f) Realtime -> does not apply. The controller subscribes to no channel and does not use `RealtimeNotifierMixin`. The write path is unchanged, so `save_expense_all` still bumps the checkers as today.
  - (g) Test seams -> `loadGroupPaybacks`, `saveExpense`, `lookupRate`, `deleteExpense` and `scanReceipt` stay function-typed constructor overrides on `ExpenseDetail`, and stay null where lib/navigation.dart builds the editor (Jakob in prep code-review-2026-10 (2026-10-24): the constructor and its test seams stay as they are). `lookupRate` reaches the controller through its args. The others are bound into the screen's closures. `ExpenseDetail` gains no new seam. The controller's own seams are its args and the write and probe closures its methods take.
  - (h) Migrations -> none. There is no schema, RPC or Edge Function change, so there is no manual-checks entry and no client fallback question.
- Units:
  - Controller and rate state: add the controller, args and state with today's rate seeding (entry currency, frozen rate and its date, origin), and move every rate field and rule into it. The screen reads the state and mirrors the rate text. Unit tests prove the ownership, latest-answer and switch-back criteria, the conversion the state reports, the rate half of the remembered-rate-change criterion, and the close-mid-lookup half of the close criterion.
  - Writes: move the save status, the delete in-flight flag and the write runner into the controller, with the screen mapping outcomes to SnackBars and the pop. Unit tests prove the refusal, single-flight and remember-rules criteria, that the write receives the state's conversion, and the close-mid-write half of the close criterion. The save-status and delete-guard suites are the regression net.
  - Entries and mode: move the entries, the index counter and the itemized override, plus the add, remove, mode and scan-entry intents, and replace `ExpenseEntryData`. The fresh-start test and the entries half of the remembered-rate-change criterion go here.
  - Sections: cut the build methods into the editor/ files and have the screen compose them. Every suite named in Acceptance stays green, and the size target is checked.
- Blockers: —

## Approach
- Move the state first, then the widgets. The rate state goes first: it holds the most rules and has the richest regression net (the currency-rate and rate-prefill suites). The screen keeps its widgets and only changes where it reads from. The writes come next, behind the save-status and delete-guard suites, then the entries and the mode. Only then are the `_build*` methods cut into section widgets under editor/. That step is close to cut-and-paste once they read values and callbacks instead of State fields. Each step leaves `flutter test` fully green, so a regression points at one step.
- The controller's I/O reaches it in only two ways: the rate lookup, through its args, and the remembered rates, through `ref.read`. Anything that needs a BuildContext, the saver's sender-side parameter (context or `notifications:`) or the FormBuilder is a closure or an argument the screen supplies. That is what makes every rule in Acceptance reachable from a `ProviderContainer`.
- Traps, each ruled on in Decisions:
  - `ref.watch` in `build` wipes the session.
  - Writing state after an await on a disposed Ref throws.
  - A family keyed on the group hands a reopened editor a stale session.
  - Section extraction must keep the `Padding`/`SoftCard` ancestry the layout tests check, and the name field's `initialValue` seed.
  - The lib-wide `ExchangeRate` sweep turns red on a careless name.
- Regenerate the Riverpod part after adding the controller (the build_runner step in CLAUDE.md), and commit it like the other `*.g.dart` files.
- Tier: normal — the controller's method parameter lists, the screen-side mirroring of the rate text, the single write runner behind save and delete, and the section cut against several layout suites leave real choices for a planner.
- Likely touchpoints: lib/pages/expenses/presentation/expense_detail.dart, lib/pages/expenses/presentation/editor/ (new), lib/pages/expenses/provider/expense_editor_controller.dart and its .g.dart (new), test/provider/expense_editor_controller_test.dart (new)
- Depends: typed-expense-draft, editor-failure-keeps-form, scan-total-applies
- Parallel-with: realtime-channel-lifecycle, realtime-event-scope, push-session-lifecycle, group-model-parse-safety, expense-search-escape, guest-merge-rpc, payback-atomic-recalc, group-write-rpcs, schema-baseline, legacy-fallback-removal, typed-routes, housekeeping, presentation-file-split. These features do not run in parallel with it, because they edit the same file or seams: notification-context-free (the `ExpenseSaver` sender-side parameter and the save path), push-server-compose (how expense_detail.dart builds the sender), injectable-repositories (the `supabase.auth` reads and static repository calls in the editor) and helper-split (the helpers the editor and its new section files import).
