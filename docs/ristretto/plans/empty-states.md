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

status: planned
