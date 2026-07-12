# tab-switch-transition — Animate home tab switches per motion spec

## Spec
- Source: idea (2026-07-12 planning session; spec exists in docs/design_handoff/ANIMATIONS.md §1)
- Flight: —
- Goal: Switching between the three home tabs (Groups / Friends / Settings) plays the spec'd fade-up instead of an instant cut.
- Acceptance:
  - Switching home tabs animates the incoming view with the handoff spec's tab-switch motion: translateY(8px) + fade, 0.26s, ease — no horizontal slide.
  - Push/pop screen transitions (already implemented via the shared-axis page helper) are unchanged.
  - Branch state is preserved across switches exactly as today (scroll positions, nested navigation) — the animation wraps the existing indexed-stack shell, it does not replace it.
  - Reduced motion (`MediaQuery.disableAnimations`) falls back to instant or fade-only, per the spec header.
  - `flutter analyze` and `flutter test` pass.
## Approach
- Verified 2026-07-12: `sharedAxisPage` covers all routed pushes; the gap is only the `StatefulShellRoute.indexedStack` body, which swaps branches with no transition.
- Wrap the shell's branch display in an animated container keyed on the current branch index (fade+slide on index change), or use the `animations` package fade-through variant — whichever preserves the indexed stack's state-keeping. The `animations` package is already a dependency.
- Likely touchpoints: lib/navigation.dart (ScaffoldWithNestedNavigation), possibly lib/widgets/page_transitions.dart for a shared curve/duration constant.
- Decisions / tradeoffs: follow the spec values exactly (0.26s, 8px, ease) — they're tuned in the prototype; don't improvise a different motion.
- Depends: —
- Parallel-with: cosmetic-round-2026-07
- Blockers: —

status: done

## Evidence

Commit `f28b0b1` on `feature/brew-2026-07-12`.

Implementation: `TabSwitchTransition` (lib/widgets/page_transitions.dart) wraps
`widget.navigationShell` in `ScaffoldWithNestedNavigation` (lib/navigation.dart).
It keys a `SingleTickerProvider` controller (`Motion.tabSwitch` = 260 ms,
`Curves.ease`) on the branch index; on index change it runs `forward(from: 0)`
driving `Opacity` (0→1) + `Transform.translate` (dy `kTabSwitchOffset`=8→0).
The shell/indexed-stack is wrapped, never rebuilt or replaced, so branch state
is preserved. Reduced motion returns the child directly.

Each acceptance criterion is restated as a test in
`test/widgets/page_transitions_test.dart` (group "TabSwitchTransition — home-tab
switch motion"):

- "translateY(8px) + fade, 0.26s, ease — no horizontal slide" →
  `switching index runs a fade-up: partway through, opacity<1 and view is
  offset downward (translateY), never slid horizontally` (asserts 0 < dy ≤ 8,
  dx == 0, 0 < opacity < 1) and `animation settles to rest (opacity 1, offset 0)
  within 0.26s`.
- "Push/pop screen transitions unchanged" → the pre-existing `sharedAxisPage`
  tests in the same file still pass untouched (Motion.screenForward = 360 ms,
  SharedAxisTransition horizontal).
- "Branch state preserved — wraps, does not replace" → verified structurally:
  the shell is passed as `child` and never re-keyed; `first build is settled —
  no animation, child fully visible` and `unrelated rebuild with same index does
  not restart the animation` confirm the wrapper does not disturb the child on
  rebuild.
- "Reduced motion falls back to instant/fade-only" → `reduced motion:
  disableAnimations → no Opacity/Transform wrapper, child returned directly`.

Gates (`.ristretto.json`), all green:
- format: `dart format` — 0 files changed.
- lint: `flutter analyze` — No issues found.
- test: `flutter test` — All 927 tests passed (12 in page_transitions_test.dart,
  5 of them new for this feature).
