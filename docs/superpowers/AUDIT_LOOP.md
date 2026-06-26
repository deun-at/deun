# Audit-fix loop (superpowers)

Autonomous loop that drives the **Deun app** to match the **v3 design handoff**. The problem
list and status live in [`docs/design_audit/README.md`](../design_audit/README.md) — the loop
reads it each iteration and never relies on chat for memory. This is a **restyle/polish phase**:
the redesign build is done; the job is closing the gap to the prototype.

> Sibling to [`LOOP.md`](LOOP.md) (the build loop). That one builds from `ROADMAP.md`; this one
> fixes design-fidelity deltas and re-audits against the prototype.

## Subagent-driven (keep the orchestrator thin)
The loop runner is an **orchestrator**: each iteration it reads only `README.md` + git, decides the
mode, and **dispatches exactly ONE subagent** to do the heavy work. Screenshots (AUDIT) and code reads
(FIX) happen in the subagent's context and are discarded on return — only a short **text** result comes
back. The orchestrator never loads an image or a source file. Iterations run **sequentially** (one phone,
one browser, one git worktree — no parallel subagents). State lives in files, so the loop resumes losslessly
in a fresh chat.

## How to run
Paste the block below into a `/loop` invocation (omit an interval to let the model self-pace).
Each iteration runs exactly one of FIX / AUDIT / STOP and the loop stops itself when the app is
similar enough (no 🔥/⚠️ deltas left). Best run in its own clean session.

## Resolved parameters
| Loop slot | Value |
|---|---|
| Source of truth | [`docs/design_audit/README.md`](../design_audit/README.md) — severity-tagged Findings. Open = `- [ ]`; done = `- [x] … ✅ <SHA>`; blocked = `⛔ blocked — <reason>`. |
| Severity | 🔥 high · ⚠️ medium · 💅 low. |
| Design ref | prototype [`docs/design_handoff_updated/Deun Redesign v3.dc.html`](../design_handoff_updated/Deun%20Redesign%20v3.dc.html), open in a browser. |
| Locked spec | [`DESIGN_SPEC.md`](../design_handoff_updated/DESIGN_SPEC.md) + [`COMPONENTS.md`](../design_handoff_updated/COMPONENTS.md) (tokens/layouts/copy). |
| Orchestration | thin orchestrator dispatches **one subagent per iteration**; sequential; images/source never enter the orchestrator context. |
| FIX subagent | reproduces against v3, implements (theme-level where possible), uses `superpowers:systematic-debugging` + `superpowers:verification-before-completion`, commits, returns `SHA + one line + PASS/BLOCKED`. |
| AUDIT subagent | captures app (**Flutter web in Chrome via Playwright**, mobile 390×844) + prototype via [`docs/design_audit/tools/capture.md`](../design_audit/tools/capture.md), regenerates composites, returns a **text** findings list (no images). Web is authoritative for layout/structure/color/type/copy; final light+dark pixel sign-off stays on the phone. |
| Test group | **hans** — safe to navigate/write. Never touch other groups. |
| Verify | `flutter analyze` clean; `flutter test` green; looks right in **light AND dark**; new copy via `AppLocalizations` (en+de); if a provider/notifier changed, `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart`. |
| Push policy | never push; commit on the current local `feat/…` / `fix/…` branch only. |
| Out of scope | rebuilding existing functionality (balances/settlement, OCR, itemized data, favorites, statistics, invite, QR, friend requests, multi-mode split, routing, badges); changing Supabase queries or `*SelectString` for a restyle; re-architecting nav; brand/identity changes; editing the prototype/spec. |
| Close | tick the box `- [x] … ✅ <SHA>` in README.md and commit on the local branch (incl. any regenerated `.g.dart`). |

## The loop
```
/loop Drive the Deun app to match the v3 design handoff. You are the ORCHESTRATOR — stay thin: each
iteration read ONLY docs/design_audit/README.md (the Findings) and git, decide the mode, and dispatch
exactly ONE subagent (Agent tool) to do the heavy work. NEVER read screenshots or source files in your
own context — that belongs to the subagent, whose context is thrown away on return; you keep only its
short text result. Run iterations SEQUENTIALLY (one phone, one browser, one git worktree — no parallel
subagents). Do exactly one of:

1. FIX — if there's an open `- [ ]` item: take the highest-severity one (🔥 → ⚠️ → 💅; ties top-to-bottom).
   Dispatch ONE subagent with this brief: "Fix <the finding, verbatim>. Reproduce against the v3 prototype
   docs/design_handoff_updated/Deun Redesign v3.dc.html; pull exact tokens from DESIGN_SPEC.md /
   COMPONENTS.md. Implement THEME-LEVEL where possible (so it propagates), per-widget only where the
   prototype diverges from a themeable default. Rules: colors via SemanticColors / theme extensions (never
   hard-code prototype hex); all visible copy via AppLocalizations (add en+de); reuse existing providers and
   go_router routes; do NOT change Supabase queries or *SelectString for a restyle; never weaken or delete
   tests. Use superpowers:systematic-debugging to locate the issue. If it's too big for one iteration,
   decompose with superpowers:writing-plans (plan under docs/design_audit/plans/) and fix the first slice.
   Before finishing run superpowers:verification-before-completion: flutter analyze clean, flutter test
   green, screen looks right in BOTH light and dark (capture from the phone via the hans group); if a
   provider/notifier changed, dart run build_runner build --delete-conflicting-outputs and commit the .g.dart.
   Commit on the current feat/… or fix/… branch — NEVER push, set upstream, force, amend, reset, or open a PR.
   Return ONLY: commit SHA, a one-line summary, and PASS or BLOCKED(<reason>)." When the subagent returns
   PASS, tick the box in README.md (- [x] … ✅ <SHA>) and commit the README. If it returns BLOCKED (or fails
   3 distinct attempts), mark the item `⛔ blocked — <reason>` in README.md and move to the next item.

2. AUDIT — if no open `- [ ]` items remain: dispatch ONE subagent with this brief: "Audit the live Deun app
   against the v3 prototype following docs/design_audit/tools/capture.md. Capture EVERY screen — app as
   Flutter web in Chrome via Playwright (flutter run -d web-server --web-port 8740 ...; viewport 390×844;
   real pointer events reach the group flow that adb taps could not; use the hans test group for any group
   navigation; drive the deep group-detail / expense / settle up / claim / stats / login / onboarding flows;
   let live lists settle) and the v3 prototype via Playwright. Web is authoritative for layout/structure/
   color/type/copy — flag anything web can't show (native share, OAuth, camera) for the phone, and note
   AdMob doesn't render on web. (First run re-baselines docs/design_audit/design/* to v3.) Compare each screen to
   DESIGN_SPEC.md / COMPONENTS.md and the rendered prototype, regenerate the composites in
   docs/design_audit/compare/, and RETURN ONLY a plain-text findings list — one per line, severity-tagged:
   `<id> · <screen> · <delta> 🔥|⚠️|💅 — <file:loc> — target: <value> — ev: compare/<x>.png`. Do NOT return
   images. Flag any screen you cannot reach as `⏳ capture-pending`." When it returns, APPEND the findings
   under the right screens in README.md (skip duplicates of existing or done items) and commit README +
   composites.

3. STOP — if the most recent AUDIT returned no 🔥/⚠️ findings (only 💅, or nothing): end the loop with a
   final report — items fixed (with SHAs), findings added per audit round, blocked items, and the per-screen
   light/dark fidelity checklist that needs my eyes on the phone. Do not loop idle.

Keep your orchestrator context minimal — only the README Findings, the subagent's short return value, and
git. If everything remaining is blocked, STOP and report instead of looping idle.
```
