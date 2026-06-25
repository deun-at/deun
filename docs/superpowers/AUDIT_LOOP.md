# Audit-fix loop (superpowers)

Autonomous loop that drives the **Deun app** to match the **v3 design handoff**. The problem
list and status live in [`docs/design_audit/README.md`](../design_audit/README.md) — the loop
reads it each iteration and never relies on chat for memory. This is a **restyle/polish phase**:
the redesign build is done; the job is closing the gap to the prototype.

> Sibling to [`LOOP.md`](LOOP.md) (the build loop). That one builds from `ROADMAP.md`; this one
> fixes design-fidelity deltas and re-audits against the prototype.

## How to run
Paste the block below into a `/loop` invocation (omit an interval to let the model self-pace).
Each iteration runs exactly one of FIX / AUDIT / STOP and the loop stops itself when the app is
similar enough (no 🔥/⚠️ deltas left).

## Resolved parameters
| Loop slot | Value |
|---|---|
| Source of truth | [`docs/design_audit/README.md`](../design_audit/README.md) — severity-tagged checklist. Open = `- [ ]`; done = `- [x] … ✅ <SHA>`. |
| Severity | 🔥 high · ⚠️ medium · 💅 low. |
| Design ref | prototype [`docs/design_handoff_updated/Deun Redesign v3.dc.html`](../design_handoff_updated/Deun%20Redesign%20v3.dc.html), open in a browser. |
| Locked spec | [`DESIGN_SPEC.md`](../design_handoff_updated/DESIGN_SPEC.md) + [`COMPONENTS.md`](../design_handoff_updated/COMPONENTS.md) (tokens/layouts/copy). |
| Workflow | superpowers (lightweight) |
| FIX | `superpowers:systematic-debugging` to locate, implement directly, verified by `superpowers:verification-before-completion`. `superpowers:writing-plans` only to decompose an item too big for one iteration (plan under `docs/design_audit/plans/`). |
| AUDIT | re-capture app + prototype via [`docs/design_audit/tools/capture.md`](../design_audit/tools/capture.md); compare; append new severity-tagged items + regenerate composites. |
| Test group | **hans** — safe to navigate/write. Never touch other groups. |
| Verify | `flutter analyze` clean; `flutter test` green; looks right in **light AND dark**; new copy via `AppLocalizations` (en+de); if a provider/notifier changed, `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart`. |
| Push policy | never push; commit on the current local `feat/…` / `fix/…` branch only. |
| Out of scope | rebuilding existing functionality (balances/settlement, OCR, itemized data, favorites, statistics, invite, QR, friend requests, multi-mode split, routing, badges); changing Supabase queries or `*SelectString` for a restyle; re-architecting nav; brand/identity changes; editing the prototype/spec. |
| Close | tick the box `- [x] … ✅ <SHA>` in README.md and commit on the local branch (incl. any regenerated `.g.dart`). |

## The loop
```
/loop Drive the Deun app to match the v3 design handoff, using the superpowers workflow.
Keep context lean. Each iteration, read docs/design_audit/README.md and do exactly one of:

1. FIX — if there's an open `- [ ]` item: take the highest-severity one (🔥 → ⚠️ → 💅; ties
   top-to-bottom). Reproduce against the v3 prototype
   (docs/design_handoff_updated/Deun Redesign v3.dc.html) and pull exact tokens from
   DESIGN_SPEC.md / COMPONENTS.md. Use superpowers:systematic-debugging to find the locus, then
   implement the fix THEME-LEVEL where possible (so it propagates), per-widget only where the
   prototype diverges from a themeable default. Rules: colors via SemanticColors / theme
   extensions (never hard-code prototype hex); all visible copy via AppLocalizations (add en+de);
   reuse existing providers and go_router routes; do NOT change Supabase queries or *SelectString
   for a restyle; never weaken or delete tests. If the item is too big for one iteration,
   decompose it first with superpowers:writing-plans (plan under docs/design_audit/plans/) and fix
   the first slice. Before closing, run superpowers:verification-before-completion: flutter analyze
   clean, flutter test green, screen looks right in BOTH light and dark (capture from the phone);
   if a provider/notifier changed, run dart run build_runner build --delete-conflicting-outputs and
   commit the .g.dart. Then close: commit on the current local feat/… or fix/… branch — NEVER push,
   set upstream, force, amend, reset, or open a PR. Tick the box in README.md (- [x] … ✅ <SHA>).

2. AUDIT — if no open items remain: re-capture the live app from the connected phone
   (R5CY22DR0FK) and the v3 prototype following docs/design_audit/tools/capture.md. Use the hans
   test group for any navigation that needs a group, and attempt EVERY screen including the deep
   expense / settle up / claim / stats flows (retry flaky in-group taps; let live lists settle).
   The first AUDIT re-baselines docs/design_audit/design/* from v2 to v3. Compare each screen
   against DESIGN_SPEC.md / COMPONENTS.md and the rendered prototype, regenerate the composites in
   docs/design_audit/compare/, and APPEND every new delta to docs/design_audit/README.md as a
   severity-tagged `- [ ]` item under the right screen (id · screen · delta 🔥|⚠️|💅 — file:loc —
   target: value — ev: compare/<x>.png). Don't duplicate items already listed or already done. A
   screen you genuinely can't reach this pass → log it `⏳ capture-pending`, don't skip silently.

3. STOP — if a fresh full AUDIT adds no 🔥/⚠️ items (only 💅 nitpicks remain or nothing): end the
   loop with a final report — items fixed (with SHAs), new items found per audit round, blocked
   items, and the per-screen light/dark fidelity checklist that needs my eyes on the phone.

If an item fails verification after 3 distinct superpowers:systematic-debugging attempts, mark it
`⛔ blocked` in README.md with a one-line reason and move to the next item — never thrash, never
weaken tests to get green, never touch the prototype or DESIGN_SPEC.md. If everything remaining is
blocked, STOP and report instead of looping idle.
```
