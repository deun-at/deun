# Deun Redesign — Motion & Animation Spec (NEW in v3)

This doc covers the **animation layer added in the v3 prototype** (`Deun Redesign v3.dc.html`). The v2
prototype already had three motions (sheet rise, scrim fade, scan-line sweep, presence pulse); **v3 adds six
more** and a count-up number element. Everything here is part of the redesign — implement it in Flutter as a
new task set (`E8-T3 Motion` in `ROADMAP.md` expands to the list below).

> **All exact values are pulled from the prototype's `<style>` block + `renderVals()` nav logic.** Match the
> durations, distances, and curves; they are tuned, not arbitrary. Honor `MediaQuery.disableAnimations` /
> reduced-motion — fall back to instant or fade-only.

## Curves (name them once, reuse)
| Prototype cubic-bezier | Use | Flutter equivalent |
|---|---|---|
| `cubic-bezier(0.2,0.8,0.2,1)` | screen push, list rise | `Curves.easeOutCubic` (close) or a custom `Cubic(0.2,0.8,0.2,1)` |
| `cubic-bezier(0.2,0.85,0.2,1)` | bar/fill grow | `Cubic(0.2,0.85,0.2,1)` |
| `cubic-bezier(0.22,1,0.36,1)` | sheet rise | `Curves.easeOutExpo`-ish; use `Cubic(0.22,1,0.36,1)` |
| `cubic-bezier(0.2,0.9,0.3,1.2)` | success pop (overshoot) | `Curves.easeOutBack` (close) or custom |
| `cubic-bezier(0.34,1.4,0.5,1)` | tab pill slide (springy overshoot) | `Curves.elasticOut` is too much — use `Cubic(0.34,1.4,0.5,1)` |
| `ease` / `ease-out` | fades, scrim | `Curves.ease` / `Curves.easeOut` |

---

## 1. Screen transitions — Material shared-axis (NEW)
Each routed screen (`.deun-pane`) animates in based on **navigation direction**, computed from a route-depth map:

```
depth 0: login, recover, onboarding, home
depth 1: group, groupstats, personalstats, friendadd, friendqr, newgroup
depth 2: expense, settle, detail, claim
```
- **Forward** (deeper): `translateX(28px) scale(.985)` + fade → rest, **0.36s** `Cubic(0.2,0.8,0.2,1)`.
- **Back** (shallower): `translateX(-24px) scale(.985)` + fade → rest, 0.36s.
- **Tab switch** (same depth, home tabs): `translateY(8px)` + fade, **0.26s** `ease` (a gentler fade-up, no X slide).

**Flutter:** this is exactly the `animations` package **`SharedAxisTransition`** — use `SharedAxisTransitionType.horizontal`
for go_router push/pop (forward/back), and `.vertical` (or a fade-through) for switching the 3 home tabs in the
`StatefulShellRoute`. Wire it via a `CustomTransitionPage` per route (forward/back is handled automatically by
push vs pop). Depth map above tells you which transition a given navigation is.

## 2. Staggered list entrance (NEW)
Containers tagged `.deun-stag` animate their **direct children** in one-by-one: each child `translateY(12px)`
+ fade → rest, **0.44s** `Cubic(0.2,0.8,0.2,1)`, **stagger 50ms** per item, capped (8th item onward all share
0.38s delay). Used on: the Groups list cards, the Friends list, and other primary lists.

**Flutter:** `flutter_staggered_animations` (`AnimationLimiter` + `AnimationConfiguration.staggeredList`,
`SlideAnimation(verticalOffset: 12) + FadeInAnimation`), or hand-roll with an interval-staggered controller.
Run it on first build / when the list's data changes — not on every rebuild.

## 3. Count-up numbers (NEW — `<deun-num>` custom element)
Big amounts animate from 0 to their value on mount: **750ms**, ease-out-cubic (`1-(1-p)^3`), respecting a
decimal count (`data-dec`, default 2) and optional thousands grouping (`data-group`) and prefix (`data-prefix="€"`).
Applied to: overall-owed hero, group balance hero, settle total, claim "your share", stats totals (`data-group`
for the big spend figures). All render with **tabular figures**.

**Flutter:** `TweenAnimationBuilder<double>(tween: Tween(begin:0, end: value), duration: 750ms,
curve: Curves.easeOutCubic, builder: (_, v, __) => Text(format(v)))` with `FontFeature.tabularFigures()`.
Trigger once when the value first becomes available (key the builder by the target value so it re-runs on change).

## 4. Success pop + ring (NEW)
On confirm/success sheets (e.g. claim "You're in for €X", settle "Settled"): the check badge **pops**
(`scale 0 → 1.14 → 1`, **0.5s**, overshoot `Cubic(0.2,0.9,0.3,1.2)`) while a ring behind it **expands & fades**
(`scale 0.55 → 2.4`, opacity `0.55 → 0`, **0.85s** ease-out, 0.1s delay).

**Flutter:** two `TweenAnimationBuilder`s (or one controller with two intervals) — `ScaleTransition` with
`Curves.easeOutBack` for the badge, plus an expanding bordered circle (`Transform.scale` + `Opacity`) for the ring.

## 5. Charts & progress grow (NEW)
- **Bars** (`.deun-bar`, monthly trend in stats): `scaleY 0 → 1`, origin **bottom**, **0.62s** `Cubic(0.2,0.85,0.2,1)`.
- **Fills** (`.deun-fill`, progress/allocation/claim bars): `scaleX 0 → 1`, origin **left**, **0.72s**,
  0.1s delay, same curve. Used on claim-progress, paid-vs-fair, category bars.

**Flutter:** animate the bar's `heightFactor` / the fill's `widthFactor` (or a `FractionallySizedBox` driven by a
`TweenAnimationBuilder`). Use `Alignment.bottomCenter` for bars, `Alignment.centerLeft` for fills as the transform
origin. Run on screen entrance.

## 6. Tab bar indicator — sliding pill (NEW — ⚠ updates THEME_AUDIT)
v3 adds a **custom sliding pill** behind the active home tab: a `52×34`, fully-rounded, **accent-tint `#ECEBFC`**
pill that **slides** between the 3 tabs via `transform: translateX(...)` transitioned **0.34s** with a springy
`Cubic(0.34,1.4,0.5,1)` (slight overshoot). Active icon+label = accent `#5750E6`; inactive = `#ADA99F`. Bar is
78px, flat `#FBFAF7`, 1px top hairline.

> **Reconciliation with `THEME_AUDIT.md`:** the audit said "kill the M3 pill." That still holds for the
> **stock M3 tonal pill** (`indicatorColor: Colors.transparent` on `NavigationBarThemeData`). v3's design then
> **re-introduces a *custom* pill** — warm accent-tint, different size, springy slide. So: **remove the Material
> indicator, then draw your own.** A themed `NavigationBar` can't produce this slide; build a **custom bottom bar**
> (Row of 3 tap targets + an `AnimatedPositioned`/`AnimatedSlide` pill behind them) to match. Dark mode: pill =
> accent-tint dark `#2A2950`.

## 7. Carried over from v2 (already speced, keep)
- **Sheet rise:** `translateY(101%) → 0`, **0.28s** `Cubic(0.22,1,0.36,1)`. Scrim **fade 0.2s**,
  `rgba(16,16,14,0.4)`. (Flutter: custom `transitionAnimationController` on `showModalBottomSheet`, or a
  `SlideTransition`; default M3 curve/scrim differ — override to match.)
- **Dark-mode flip:** `filter` transition 0.28s ease (prototype stand-in only; real app animates via
  `AnimatedTheme` / theme rebuild).
- **Scan-line sweep:** `top 8% → 88% → 8%`, **2.4s** ease-in-out loop (receipt + QR scanners).
- **Presence pulse:** dot `scale 1 → 1.5 → 1`, opacity `1 → 0.45 → 1`, **1.6s** loop (claim live-presence dot).

---

## Implementation notes
- **Don't animate on every rebuild.** Riverpod rebuilds are frequent; gate entrance animations to first build /
  data-arrival (keys, `AnimationLimiter`, or a `didChangeDependencies` guard) so lists don't re-stagger on a tap.
- **One curves/durations constants file** (`lib/widgets/motion.dart`) mirroring the table above — reuse, don't
  inline magic numbers.
- **Reduced motion:** check `MediaQuery.of(context).disableAnimations`; collapse to instant/fade.
- **Predictive back (Android):** shared-axis page transitions must not fight the system predictive-back gesture —
  test on Android 14+.
