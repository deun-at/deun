# V3-T4 — Shared-axis route transitions (ANIMATIONS §1)

Give routed drill-down screens the v3 Material **shared-axis** push/pop transition via the `animations`
package (already a dependency, added in V3-T1). Currently the go_router child routes use plain `builder:`
(default MaterialPage transition) and the 3 home tabs use `NoTransitionPage`.

## Source of truth
`docs/design_handoff/ANIMATIONS.md` **§1 "Screen transitions — Material shared-axis"**:
- Forward (deeper): translateX(28) scale(.985) + fade → rest, **0.36s** `Cubic(0.2,0.8,0.2,1)`.
- Back (shallower): translateX(-24) scale(.985) + fade, 0.36s.
- Tab switch (home tabs, same depth): translateY(8) + fade, 0.26s ease.
- Flutter mapping: `animations` package **`SharedAxisTransition`** — `SharedAxisTransitionType.horizontal` for
  go_router push/pop (forward/back handled automatically by the secondary/primary animation), wired via a
  `CustomTransitionPage` per route.

## What to build
1. New helper `lib/widgets/page_transitions.dart` exposing:
   ```dart
   CustomTransitionPage<T> sharedAxisPage<T>({
     required LocalKey key,
     required Widget child,
     SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
   })
   ```
   - `transitionDuration` / `reverseTransitionDuration` = `Motion.screenForward` (360ms).
   - `transitionsBuilder` returns `SharedAxisTransition(animation: animation,
     secondaryAnimation: secondaryAnimation, transitionType: type, fillColor: Colors.transparent, child: child)`.
   - **Reduced motion:** if `MediaQuery.of(context).disableAnimations`, return the child directly (no slide) —
     i.e. instant. (Wrap with `reducedIfNeeded` semantics: zero-duration / plain child.)
   - Import curves/durations from `lib/widgets/motion.dart`. Do NOT inline magic numbers.
2. In `lib/navigation.dart`, convert every FULL-SCREEN drill-down `GoRoute` that currently uses `builder:`
   (the ones with `parentNavigatorKey: _rootNavigatorKey`) to `pageBuilder:` returning
   `sharedAxisPage(key: state.pageKey, child: <the existing screen widget>)`. These are, in the group branch:
   `details`, `expense`, `expense-detail`, `claim`, `statistics`, `edit`, `join`; friend branch: `add`, `qr`,
   `accept`; setting branch: `privacy-policy`, `statistics`, `contact`; and the top-level routes
   `/update-password`, `/privacy-policy`, `/contact`. Keep the EXACT same `state.extra`/arg extraction and the
   same destination widgets — only wrap them in a transition page.
3. **Do NOT touch** the 3 shell tops (`/group`, `/friend`, `/setting` → keep `NoTransitionPage`) and **do NOT
   touch** the `ModalBottomSheetPage` routes (`month`, `category`, `payment`, `share`) — sheets keep their
   sheet-rise. The error route stays as-is.

## v0 decision (record it)
The home-tab fade-through (translateY 8 + fade) is intentionally **deferred**: `StatefulShellRoute.indexedStack`
keeps all branches alive, and wrapping the shell in a transition switcher would rebuild branches and lose their
state. Keep tabs instant (`NoTransitionPage`) for v0; note the tab fade as a possible follow-up. The drill-down
shared-axis is the high-value 90%.

## TDD (RED → GREEN → REFACTOR)
- Unit-test `sharedAxisPage` in `test/widgets/page_transitions_test.dart` (write failing first):
  - It returns a `CustomTransitionPage` whose `transitionDuration == Motion.screenForward`.
  - Pumping it in a minimal MaterialApp/router renders the child.
  - With `MediaQuery(disableAnimations: true)`, the transition is instant (child present immediately / no
    SharedAxisTransition slide) — assert the reduced-motion branch.
- Keep any existing navigation/router test green; if finders break because routes became `pageBuilder`, update
  them without weakening assertions.

## Constraints (global, from README.md)
- Reuse the existing go_router structure/paths — do NOT re-architect navigation, only swap builder→pageBuilder.
- No Supabase/query/provider changes → no build_runner.
- Predictive-back (Android): the app sets `PredictiveBackPageTransitionsBuilder` in the theme; per-route
  `CustomTransitionPage` overrides it on these routes. That's acceptable for v0 — note in the report that
  Android 14+ predictive-back on drill-downs needs device QA (batched, not a gate).
- Both light and dark unaffected (transition uses transparent fillColor).

## Verification before reporting DONE
- `flutter analyze` clean.
- `flutter test test/widgets/page_transitions_test.dart` green; full `flutter test` shows no NEW failures beyond
  the known 6 pre-existing ones.
- Sanity: the app still routes (no `pageBuilder`/`builder` type errors); `grep -n "builder:" lib/navigation.dart`
  reflects the conversions (drill-downs now `pageBuilder`).
Report exact commands + output tails, files changed, the list of routes converted, and concerns (esp. predictive-back).

## Commit
One commit on `feat/v3-motion-foundation`: `V3-T4: shared-axis transitions on drill-down routes`.
End the body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
