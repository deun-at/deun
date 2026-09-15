# empty-states — One shared empty state across the app

## Spec
- Source: idea (Jakob, 2026-09-13 — "empty states are not fully implemented. this is the first
  thing people see when downloading")
- Flight: empty-states
- Goal: Every blank screen uses one component that explains what goes there and, where the screen
  offers no prominent action of its own, how to fill it. A failed load stops impersonating an
  empty account.

## Contract
- Acceptance:
  - [auto] `EmptyState` renders the icon inside a filled rounded container using
    `colorScheme.primaryContainer`, and the icon in `colorScheme.onPrimaryContainer` — **not**
    `colorScheme.outline`, which is the disabled/hairline token the four current empty states draw
    their icon in and the reason they read as unfinished.
  - [auto] `EmptyState` renders headline, optional body, and an optional action, in that order.
    With `body: null` no empty `Text` is laid out; with `onAction: null` no button is laid out.
  - [auto] `EmptyState` itself builds no scrollable and no `RefreshIndicator` — it is a
    `Column(mainAxisSize: MainAxisSize.min)`. `EmptyState.refreshable` wraps that same column in
    `RefreshIndicator` + a single `ListView` with `AlwaysScrollableScrollPhysics`, so the pull
    gesture still works on an empty list.
  - [auto] Placing a bare `EmptyState` inside an existing `ListView` produces no unbounded-viewport
    exception — this is the defect that stopped `group_list.dart` using `EmptyListWidget` and left
    it with a hand-rolled copy (see the comment at `group_list.dart:85`).
  - [auto] `tone: EmptyStateTone.error` renders the error copy and a Retry action wired to the
    caller's refresh; `tone: EmptyStateTone.empty` never renders Retry.
  - [auto] The friends `AsyncError` branch (`friend_list.dart:210`) renders the error headline, and
    **not** `friendsNoEntries`. A failed fetch and an empty account must not produce the same
    screen — today they produce the identical widget.
  - [auto] The groups and friends empty states each render an action button; the group-expenses
    empty state renders none (its screen already carries an extended, labelled "Add expense" FAB).
  - [auto] Every new ARB key is present in **both** `app_en.arb` and `app_de.arb`, and every
    retired key (`expenseNoEntries`, `groupNoEntries`, `groupExpenseNoEntries`, `friendsNoEntries`)
    is absent from both. Needs a **new** test: `test/l10n_editor_labels_test.dart` reads both ARBs
    directly and is the pattern to copy, but it asserts one hard-coded list belonging to a past
    feature — there is no repo-wide parity guard to lean on.
  - [auto] On mount the icon chip scales from 0 to 1 over `Motion.successPopDuration` with the
    `Motion.successPop` overshoot curve, while the headline, body and action are laid out at rest
    from the first frame — they never fade or move.
  - [auto] With `MediaQuery.disableAnimations` true, the chip is rendered statically at full scale
    and no `ScaleTransition` carrying `kEmptyStateChipPopKey` is in the tree.
  - [auto] `EmptyListWidget` is deleted and has no remaining references.
  - [auto] `dart format`, `flutter analyze` and `flutter test` pass.
- Provides:
  - `EmptyState({required IconData icon, required String headline, String? body, String? actionLabel, VoidCallback? onAction, EmptyStateTone tone})`
  - `EmptyState.refreshable({required Future<void> Function() onRefresh, required IconData icon, required String headline, String? body, String? actionLabel, VoidCallback? onAction, EmptyStateTone tone})`
  - `enum EmptyStateTone { empty, error }`
  - `const Key kEmptyStateChipPopKey` — names the chip's own `ScaleTransition`, so a test can ask
    "did the chip pop?" without matching the `ScaleTransition` that `PrimaryButton`'s press
    feedback renders. Same device as `kPrimaryButtonCheckPopKey`, and for the same reason: a
    `findsNothing` on the bare type is not a valid reduced-motion assertion.
- Consumes: `kScreenGutter` (`lib/widgets/restyle/screen_gutter.dart`), `PrimaryButton`
  (`lib/widgets/restyle/primary_button.dart`), `Motion.successPop`,
  `Motion.successPopDuration` (`lib/widgets/motion.dart`)
- Decisions:
  - **Tinted icon chip, not an illustration.** Jakob preferred illustration on sight; this feature
    ships the chip first because it needs no assets and no drawing pass. The component's visual
    slot is a single widget, so an illustration upgrade later replaces that slot without touching
    a call site — see the anticipated sibling in `## Approach`.
  - **The component owns no scrollable.** `EmptyListWidget` wraps itself in
    `RefreshIndicator` + `ListView`, which is precisely why `group_list.dart` could not use it —
    nesting that inside the screen's own list is an unbounded viewport, so the best empty state in
    the app was hand-rolled instead and the other three never got a CTA. Two entry points instead:
    the default constructor is a bare column for placing inside a caller's scroll view,
    `.refreshable` is the self-wrapping one. The call site says which it is.
  - **A CTA only where the screen has no prominent action of its own.** Groups: the FAB was
    removed as redundant (F91), so the empty state is the only affordance → CTA. Friends: the only
    affordance is a small `HeaderIconButton` (`friend_list.dart:272`) → CTA. Group expenses: a
    `FloatingActionButton.extended` labelled "Add expense" is always on screen
    (`group_detail.dart:252`) → **no CTA**, or the screen carries three ways to do one thing. The
    body copy names the FAB instead, which also teaches the affordance the user will keep using.
  - **The error tone ships with this feature, not after it.** The friends `AsyncError` branch
    currently renders the empty widget with `friendsNoEntries`, so a network failure tells the
    user they have no friends. Designing the component without the variant would leave that bug
    standing and force a second pass over the same call sites.
  - **The chip pops; the words do not.** An empty screen is a message, and fading the message in
    delays the only thing on screen — but a wholly static screen after a moving transition reads as
    dead. So the motion is confined to the one element carrying no information. Reuses
    `Motion.successPop`, the overshoot `SuccessBadge` already uses, rather than inventing a curve.
    Mounting is the trigger, so it plays once per appearance and not on every rebuild.
  - **Statistics is out of scope.** `statisticsNoExpenses` is used in **8** files across
    statistics sections and sheets, where "empty" is a sub-section of a populated screen rather
    than a screen's empty state. Folding those in triples the surface area and is a different
    design question (an empty chart, not an empty list).
  - **Friend search is out of scope.** `search_result_list.dart:58` uses `_MessageCard` — an
    inline answer to a query the user just typed, not a screen at rest. Different pattern,
    already has copy.
  - **`expenseNoEntries` ("So empty here :(") is deleted, not rewritten.** It has no reference
    anywhere in `lib/` — it is already dead.
  - Reuses the existing `retry`, `addNewGroup`, `expenseAddButton` and `addFriends` keys, all four
    of which already exist in both locales. Only headline/body keys are new.
- Units:
  - `EmptyState` + `EmptyStateTone` in `lib/widgets/restyle/empty_state.dart`, with both
    constructors and the `primaryContainer` chip.
  - The chip's mount pop, keyed `kEmptyStateChipPopKey`, with its reduced-motion branch. Build its
    `AnimationController` eagerly in `initState`, not as a lazy `late final` — under reduced motion
    nothing else touches it, so a lazy one is first constructed inside `dispose()`, where the
    ancestor lookup a `Ticker` needs is no longer safe. This exact bug was hit and fixed in
    `PrimaryButton._CheckPopState` (commit `33c7d2a`); do not rediscover it.
  - New ARB keys in both locales, `flutter gen-l10n`, and the deletion of `expenseNoEntries`.
  - Migrate the three empty call sites — `group_list.dart:82` (replacing the hand-rolled block),
    `group_detail_list.dart:81`, `friend_list.dart:201` — and delete `EmptyListWidget`.
  - Give `friend_list.dart:210`'s `AsyncError` branch the error tone with a working Retry.
- Manual-Checks: —
- Blockers: —

## Approach
Tier: easy — the component's file, both constructor signatures, every call site with its line
number, the CTA rule and the full copy for both locales are all fixed here; a planner would add
nothing.

**New ARB keys** (English, then German):

| key | en | de |
|---|---|---|
| `emptyGroupsHeadline` | No groups yet | Noch keine Gruppen |
| `emptyGroupsBody` | Start one for a trip, a flat, or a night out. | Erstelle eine für eine Reise, eine WG oder einen Abend. |
| `emptyExpensesHeadline` | No expenses yet | Noch keine Ausgaben |
| `emptyExpensesBody` | Add the first one and Deun works out who owes what. | Füge die erste hinzu — Deun rechnet aus, wer wem was schuldet. |
| `emptyFriendsHeadline` | No friends yet | Noch keine Freunde |
| `emptyFriendsBody` | Add people you split with often to settle up across groups. | Füge Personen hinzu, mit denen du oft teilst, um gruppenübergreifend abzurechnen. |
| `emptyErrorHeadline` | Couldn't load this | Konnte nicht geladen werden |
| `emptyErrorBody` | Check your connection and try again. | Prüfe deine Verbindung und versuche es erneut. |

Retired: `expenseNoEntries` (both locales, already unreferenced). `groupNoEntries`,
`groupExpenseNoEntries` and `friendsNoEntries` are each used at exactly one site and are replaced
by the headline/body pair above; delete them in the same pass so no key survives with no reader.

**Layout.** The chip is a 96×96 `Container` with `BorderRadius.circular(28)` filled
`primaryContainer`, icon at 40 in `onPrimaryContainer`. Headline `textTheme.titleMedium` at
`w600`; body `textTheme.bodyMedium` in `onSurfaceVariant`, `textAlign: center`, capped near 30
characters per line by a `ConstrainedBox`. The action is the existing `PrimaryButton`
(`fullWidth: false`). The column is centred with `MainAxisAlignment.center` and applies
`kScreenGutter` horizontally itself, per the rule in `screen_gutter.dart` — an empty branch is a
bare `Column` outside the screen's scroll view, so it owns its own gutter.

**Anticipated sibling, not planned here:** `empty-states-illustrations` would swap the chip for a
`CustomPainter` drawing per surface. Worth recording that painting them from `ColorScheme` rather
than shipping SVG assets means one drawing per subject instead of a light and a dark file, no
`flutter_svg` dependency and nothing added to the bundle — which is most of what made the
illustration route look expensive. Prep it when the chip has shipped.

- Likely touchpoints: `lib/widgets/restyle/empty_state.dart` (new),
  `lib/widgets/empty_list_widget.dart` (deleted),
  `lib/pages/groups/presentation/group_list.dart`,
  `lib/pages/groups/presentation/group_detail_list.dart`,
  `lib/pages/friends/presentation/friend_list.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`,
  `test/widgets/empty_state_test.dart` (new)
- Depends: —
- Parallel-with: save-status-rollout — no shared file; this one touches the three list screens and
  a new widget, that one touches the payback sheet and the group editor.

## Evidence

Gate green: `dart format` clean on every touched Dart file (ARBs are not Dart and are not
format-checked), `flutter analyze` — no issues found, `flutter test` — 1578 tests pass, none
failing.

review: notes-only · rounds: 1 · open: 0 block, 2 note, 5 lean
tier: easy

Twelve `[auto]` criteria, proven by named tests in `test/widgets/empty_state_test.dart` (component,
12 cases), `test/l10n_empty_state_keys_test.dart` (l10n parity, 4 cases, new), and the updated
call-site suites:

- **Filled `primaryContainer` chip, not `outline`** — "the icon sits in a filled primaryContainer
  chip", asserting the icon color `isNot(scheme.outline)`.
- **Headline/body/action in order, either optional omitted** — "renders headline, body and action
  in order" (vertical `dy` ordering) and "omits the body and the action when they are null" /
  "the empty tone renders no action without one being passed".
- **No scrollable of its own; `.refreshable` wraps one `ListView` with
  `AlwaysScrollableScrollPhysics`** — "the default constructor builds a bare min-size column"
  (`RefreshIndicator` and `Scrollable` both `findsNothing`) and ".refreshable wraps the column in a
  pullable single ListView" (fling triggers `onRefresh`).
- **A bare `EmptyState` nests inside a caller `ListView` with no unbounded-viewport exception** —
  "a bare EmptyState nests inside a caller ListView" (`tester.takeException()` is null) — the
  defect that stopped `group_list.dart` using `EmptyListWidget`.
- **`tone: error` renders Retry; `tone: empty` never does** — "the error tone repaints the chip in
  the error container" plus, at the friends call site, "a failed load shows the error tone, not the
  no-friends copy" and "the error Retry re-runs the fetch" (`reloads.value == 1` after a tap).
- **Friends `AsyncError` renders the error headline, not `friendsNoEntries`** — same two friends
  tests above; `friendsNoEntries` no longer exists in either ARB (see the l10n test below), so the
  old bug cannot recur silently.
- **Groups and friends carry a CTA; group-expenses carries none** — groups: pre-existing
  `group_list_screen_test.dart`, "empty state offers a create-first-group CTA that navigates"
  (`l10n.addNewGroup`, unchanged key, reused per the reuse-before-writing rule); friends: "empty
  state shows the shared empty state with an add CTA"; group-expenses: "shows the shared empty
  state, without a CTA, when there are no expenses" (`PrimaryButton` `findsNothing` inside
  `EmptyState`).
- **Every new key in both ARBs, every retired key in neither, reused keys survive** —
  `test/l10n_empty_state_keys_test.dart`: "every new empty-state key exists in both locales", "the
  German empty-state copy is translated, not copied", "every retired empty-state key is gone from
  both locales", "the reused action keys survive in both locales".
- **Chip pops 0→1 over `Motion.successPopDuration` with the `Motion.successPop` overshoot; words
  laid out at rest** — "the chip pops from 0 while the words never move" (scale 0.0 at first pump,
  1.0 after the duration, headline/body `topLeft` unchanged, no `FadeTransition` in the subtree) and
  "the chip pop overshoots with Motion.successPop" (`scale.value > 1.0` observed mid-animation).
- **Reduced motion: chip static at full scale, no `ScaleTransition` keyed `kEmptyStateChipPopKey`**
  — "reduced motion renders the chip statically at full scale" and "disposing under reduced motion
  throws nothing" (guards the `_CheckPopState` lazy-controller bug from commit `33c7d2a`, fixed
  eagerly here per the plan's `Units:` note).
- **`EmptyListWidget` deleted, no remaining references** — `lib/widgets/empty_list_widget.dart` is
  gone; `grep` across `lib/` and `test/` turns up only doc-comment mentions of the retired name, no
  imports or usages.
- **Gates pass** — see gate-green summary above.

## Open findings

Left open by review round 1 (`notes-only`), recorded verbatim, none fixed:

note · `lib/widgets/restyle/empty_state.dart:200` · `_ChipPop` forwards the controller only when
`reduceMotion` is false **at mount**, with no `didUpdateWidget`; if the OS reduce-motion setting is
switched off while an empty screen is mounted, `build` swaps to the `ScaleTransition` whose
animation is still parked at `0.0` and the chip vanishes permanently. Not blocking: only the
decorative chip is lost — headline, body and CTA stay laid out and tappable, and the plan itself
puts no information in the chip. Fix: `_controller.value = 1` (or `forward()` unconditionally) and
gate only the wrapper. Same one-line gap exists in `PrimaryButton._CheckPopState:287`, which this
was copied from verbatim.

note · `lib/pages/groups/presentation/group_list.dart:114-138` · the groups `AsyncError` branch is
still the hand-rolled `Icon(size: 48, color: colorScheme.outline)` + `headlineMedium` block with no
Retry — the exact treatment AC1 names as "the reason they read as unfinished", now one `switch` arm
away from the migrated empty state, and the new `emptyError*` keys + error tone exist. Not
blocking: it is outside the plan's enumerated Units, and its copy is already error-specific
(`groupEntriesError`), so no user is told their data is gone. Fix: follow-up, or
`EmptyState(tone: EmptyStateTone.error, …)` here too.

lean · `lib/pages/groups/presentation/group_list.dart:93-107` · double gutter: the branch's
`ListView` applies `horizontal: kScreenGutter` **and** the bare `EmptyState` applies it again,
insetting the empty content 32px instead of 16 (and the "this branch's list has no padding of its
own" comment above it now contradicts the padding two lines below). Fix: drop the padding on this
branch's list, or the gutter inside `EmptyState` when nested.

lean · `test/widgets/empty_state_test.dart:126` · `'the empty tone renders no action without one
being passed'` duplicates `'omits the body and the action when they are null'` (:113) — both pump
an `EmptyState` with no `onAction` and assert `PrimaryButton findsNothing`. Fix: delete one.

lean · `lib/widgets/restyle/empty_state.dart:96` · `MainAxisAlignment.center` is a no-op on a
`MainAxisSize.min` Column. Fix: drop it.

lean · `test/l10n_empty_state_keys_test.dart:92` · the reused-keys guard asserts `expenseAddButton`
survives, a key this feature deliberately does **not** use (group expenses ships no CTA) — it pins
an unrelated key into this feature's suite. Fix: drop it from the list.

lean · `lib/widgets/restyle/empty_state.dart:155` · `.refreshable` carries `EmptyListWidget`'s
hardcoded `SizedBox(height: 100)` into the new component, so the column is pinned 100px from the
top of whatever viewport it lands in rather than centred in it. Fix: centre it against the
viewport, or make the offset a named constant so the number is deliberate rather than inherited.

Also recorded, from the implementer (not a review finding): a repo-wide `dart format` would rewrite
113 files untouched by this feature, so the tree is not format-clean under the pinned toolchain — a
one-off format commit would stop that landing in someone's feature diff.

status: done
