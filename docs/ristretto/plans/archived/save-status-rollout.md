# save-status-rollout — The save confirmation moves onto the button everywhere

## Spec
- Source: idea (Jakob, 2026-09-14 — after `expense-save-status` shipped: "are the motions/animations
  also in… i liked it")
- Flight: save-status
- Goal: The two remaining writes that confirm themselves *after* closing their own surface confirm
  themselves on the button instead, the way the expense editor now does.

## Contract
- Acceptance:
  - [auto] Recording a payback shows the check on the sheet's own CTA before the sheet closes, and
    fires **no** success `SnackBar`. Today `record_payback_sheet.dart:174` calls `showSnackBar`
    and `:182` pops immediately after, so the confirmation is painted over the group detail behind.
  - [auto] Saving a group shows the check on the sticky-footer CTA before the route changes, and
    fires no success message. Today `group_detail_edit.dart:116` calls `showMessage` and the
    `finally` at `:119` navigates away, so the message lands on the new group's detail page.
  - [auto] A **failed** payback or group save still raises its `SnackBar`, still leaves the CTA in
    its idle state, and never shows a check. The payback sheet's three distinct failure paths
    (`PaybackRejectedException` at `:184`, generic at `:188`, and the plan rejection at `:146`)
    each keep their own wording.
  - [auto] A second tap on either CTA while the write is in flight issues no second write.
    `record_payback_sheet` already guards this with `_saving`; `group_detail_edit._save` already
    guards with `if (_isSaving) return` at `:95`. Both must still hold with the new state added.
  - [auto] Saving an **edit** of an existing group confirms with "Group saved!", not
    "Group created!". `_isEdit` already exists (`group_detail_edit.dart:64`) and the CTA label
    already branches on it at `:246`; the success copy does not, so editing a group has always
    reported that one was created.
  - [auto] `_StickyFooter` (`group_detail_edit.dart:708`) exposes `succeeded` and passes it through
    to its `PrimaryButton`, alongside the `isBusy` it already passes as `loading`.
  - [auto] The 700 ms confirmation hold is read from **one** place by all three call sites. It is
    `_kSaveConfirmationHold`, private to `expense_detail.dart`, today.
  - [auto] Under `MediaQuery.disableAnimations` the hold collapses to zero on both new surfaces, via
    `reducedIfNeeded` — matching what `expense_detail.dart` already does.
  - [auto] New ARB keys exist in **both** locales; no key is left with no reader.
  - [auto] `dart format`, `flutter analyze` and `flutter test` pass.
- Provides:
  - `Motion.saveConfirmationHold` — the promoted hold duration (700 ms).
  - `_StickyFooter({required String label, required bool isBusy, required bool succeeded, required String successLabel, required VoidCallback onPressed, required Color background})`
    — private to `group_detail_edit.dart`, listed because the added parameters are the contract. `successLabel` was
    added beyond the plan: the `_isEdit`-branched copy needs a route to the button and the widget is private, so no
    public surface was added.
- Consumes: `PrimaryButton.succeeded` / `PrimaryButton.successLabel`,
  `kPrimaryButtonCheckPopKey` (`lib/widgets/restyle/primary_button.dart`, commit `33c7d2a`);
  `reducedIfNeeded` (`lib/widgets/motion.dart`)
- Decisions:
  - **Only surfaces that close after writing are in scope.** The defect is a confirmation painted
    over a screen the user has already left. Checked against every `showSnackBar` site in `lib/`
    (61 of them): exactly two others have the pop-then-confirm shape.
  - **`friend_list`'s accept / decline / cancel stay snackbars.** They never pop — the user stays on
    the list and the row itself moves or disappears, which is already a better confirmation than a
    check would be, and there is no button left on screen to put one on.
  - **The payment screen's Remind action stays a snackbar.** It does not pop either, and it is
    repeatable with a cooldown. It is the most plausible *next* candidate — it does have a button —
    but a repeatable action needs a state that returns to idle, which is a different question from
    a terminal one. Not bundled.
  - **Deleting an expense is out of scope** (`expense_detail_read.dart:124`). Its trigger is a
    confirmation sheet that is already gone by the time the write runs, so there is no persistent
    CTA to decorate. Giving it a check needs a different mechanism, not this one.
  - **Sending a friend request is out of scope** (`friend_add_page.dart:107`). No pop, and the row
    already flips into a "requested" state — an inline confirmation that outlives a toast.
  - **The payback check does not carry the sentence.** `paybackRecordSuccess` is
    `"Recorded: {paidBy} paid {paidFor} {amount}"`, which will not fit a button. A new short
    `paybackRecordedShort` is used instead; the three facts it drops are all still on screen in the
    sheet the user is looking at. `paybackRecordSuccess` then has no reader and is deleted.
  - **`groupCreateSuccess` is short enough to be a button label as-is** ("Group created!" /
    "Gruppe erstellt!") and is reused rather than duplicated. Only the edit-path string is new.
  - **The hold moves to `Motion`, not to a new file.** `motion.dart` is already the one place the
    repo forbids inlining duration literals, and a confirmation hold is a duration. Promoting it
    also deletes a private constant that a second copy would otherwise have drifted from.
- Units:
  - Promote `_kSaveConfirmationHold` to `Motion.saveConfirmationHold` and repoint
    `expense_detail.dart` at it. No behaviour change — the guard is that the expense editor's six
    existing tests in `test/widgets/expense_save_status_test.dart` still pass untouched.
  - `record_payback_sheet.dart`: add the done state, hold, drop the success snackbar, add
    `paybackRecordedShort`, retire `paybackRecordSuccess`.
  - `group_detail_edit.dart`: `_StickyFooter.succeeded`, the done state and hold in `_save`, drop
    the success `showMessage`, and branch the success copy on `_isEdit`.
- Manual-Checks: —
- Blockers: —

## Approach
Tier: easy — both call sites, the private widget whose signature changes, the exact lines the
success messages fire from, the new keys with copy for both locales and the two existing test files
are all named here; a planner would add nothing.

**New ARB keys** (English, then German):

| key | en | de |
|---|---|---|
| `paybackRecordedShort` | Recorded | Erfasst |
| `groupSaveSuccess` | Group saved! | Gruppe gespeichert! |

Retired: `paybackRecordSuccess` (both locales) once the sheet stops reading it. `groupCreateSuccess`
is **kept** — it becomes the create-path button label.

**Shape, both surfaces.** Identical to what `expense_detail._saveExpense` now does: a private
`_SaveStatus { idle, busy, done }`, flipped to `busy` only after every validation gate has passed
(so a refused save never leaves a spinner behind), flipped to `done` on success, held for
`Motion.saveConfirmationHold` via `reducedIfNeeded`, and only then the pop or the navigation that
already exists. The `catch` blocks return the status to `idle` and keep their snackbars verbatim —
an error needs words, and none of these three failure messages can be mimed by an icon.

`record_payback_sheet` already passes `loading: _saving` to its footer `PrimaryButton` (`:250`), so
it needs only the `succeeded` argument and the hold. `group_detail_edit` reaches its
`PrimaryButton` through `_StickyFooter`, which passes `isBusy` as `loading` but has no third state
to pass — hence the signature change, which is the only reason that widget appears in `Provides:`.

**Existing test files to extend rather than replace:**
`test/widgets/record_payback_sheet_test.dart` and `test/widgets/group_edit_screen_test.dart` both
already pump these surfaces with injected write seams, which is what makes the in-flight state
observable — the pattern `test/widgets/expense_save_status_test.dart` uses is a gated `Completer`
the test holds open.

- Likely touchpoints: `lib/widgets/motion.dart`,
  `lib/pages/expenses/presentation/expense_detail.dart`,
  `lib/pages/groups/presentation/record_payback_sheet.dart`,
  `lib/pages/groups/presentation/group_detail_edit.dart`, `lib/l10n/app_en.arb`,
  `lib/l10n/app_de.arb`, `test/widgets/record_payback_sheet_test.dart`,
  `test/widgets/group_edit_screen_test.dart`, `test/widgets/expense_save_status_test.dart`
- Depends: —
- Parallel-with: empty-states

## Evidence
- Payback sheet check on CTA before close, no success snackbar: `test/widgets/record_payback_sheet_test.dart` —
  `the check lands on the CTA before the sheet closes`, `a recorded payback fires no success snackbar`.
- Group save check on sticky CTA before route change, no success message:
  `test/widgets/group_edit_screen_test.dart` — `the check lands on the sticky CTA before the route changes`,
  `saving a group fires no success message`.
- Failed payback/group save still raises its `SnackBar`, CTA returns to idle, no check, each failure path keeps its
  own wording: `test/widgets/record_payback_sheet_test.dart` — `a rejection from the write says why, not "could not
  pay back"`, `an unexpected write failure keeps the generic error`; `test/widgets/group_edit_screen_test.dart` —
  `a failed save keeps its error, stays put and shows no check`.
- No second write on a second tap in flight: `test/widgets/record_payback_sheet_test.dart` —
  `a second tap while the write is in flight writes once`; `test/widgets/group_edit_screen_test.dart` —
  `a second tap while saving does not fire a second write`.
- Editing a group confirms "Group saved!", not "Group created!":
  `test/widgets/group_edit_screen_test.dart:1031` (`succeeded`-state assertion on the create-copy test's
  edit counterpart) and `groupSaveSuccess is translated, not copied, in German` (line 1151).
- **Round 1 (`blocking (1)`)**: the deferred pop on the payback sheet could pop the group detail page underneath
  when the user dismissed the sheet mid-hold. Fixed by capturing `ModalRoute.of(context)` before the hold and
  popping only `if (sheetRoute?.isCurrent ?? false)`, proven red→green by
  `test/widgets/record_payback_sheet_test.dart:350` — `a user dismissal mid-hold never pops the screen underneath`.
  Round 1's two notes and two leans were applied in the same pass: succeeded-state assertion on the create-copy
  test, a German-translation test for `groupSaveSuccess`, navigation hoisted out of the `try` in
  `group_detail_edit._save`, and `_StickyFooter.onPressed` passed through unchanged. Round 2 re-review came back
  clean — nothing left open.
- `_StickyFooter` exposes `succeeded`, passed through to `PrimaryButton` alongside `isBusy` as `loading`; it also
  gained a private `successLabel` parameter beyond the plan — the `_isEdit`-branched copy has no other route to the
  button, the widget is private, so no public surface was added (reviewer-approved; see `Provides:` above).
- Hold read from one place: `Motion.saveConfirmationHold` (`lib/widgets/motion.dart`), consumed by all three call
  sites; `expense_detail.dart`'s private `_kSaveConfirmationHold` deleted. `test/widgets/motion_test.dart` —
  `saveConfirmationHold is 700 ms`; expense editor's six existing tests in
  `test/widgets/expense_save_status_test.dart` still pass untouched, proving the repoint is behaviour-neutral.
- Reduced motion collapses the hold to zero on both new surfaces via `reducedIfNeeded`, matching
  `expense_detail.dart`: exercised with `MediaQuery(disableAnimations: true)` in both
  `test/widgets/record_payback_sheet_test.dart` and `test/widgets/group_edit_screen_test.dart`.
- New ARB keys exist in both locales, no orphaned key: `paybackRecordedShort` / `groupSaveSuccess` added to
  `app_en.arb` and `app_de.arb`; `paybackRecordSuccess` retired from both once its last reader was removed —
  covered by each file's `copy exists in both languages` suite.
- Gates: `dart format --set-exit-if-changed` clean on all 7 touched feature files; `flutter analyze` — "No issues
  found!"; `flutter test` — 1590 tests, all passed, exit code 0. `dart format --set-exit-if-changed` on the full
  `lib`/`test` tree separately reports 112 pre-existing unformatted files repo-wide (confirmed by name), none of
  them touched by this feature.
- Not a finding, recorded for the record: the round-2 reviewer noted a pre-existing race it deliberately did not
  raise — if a picker sheet is open on top of the payback sheet when the hold expires, `isCurrent` is false and the
  payback sheet stays open on a dead, checked CTA until dismissed by hand; identical end state under the pre-fix
  code, so not introduced here.

review: resolved · rounds: 2 · open: 0 block, 0 note, 0 lean
tier: easy

status: done
