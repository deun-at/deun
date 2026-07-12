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

status: planned
