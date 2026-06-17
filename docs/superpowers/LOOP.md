# Build loop (superpowers)

Reusable autonomous build loop for the **Deun redesign**, expressed in the
**superpowers** workflow. The plan and status live in the design-handoff bundle —
[`docs/design_handoff/ROADMAP.md`](../design_handoff/ROADMAP.md) is the task list and
the loop reads it each iteration; it never relies on the chat for memory.

The redesign is a **restyle of the existing Deun Flutter app** to the prototype's look
(indigo `#5750E6` + warm neutrals + Bricolage/Hanken, light **and** dark). Almost
everything already exists in code — only **Epic 3 (Tap to Claim)** is net-new. See
[`README.md`](../design_handoff/README.md) for the codebase map and the "already built —
restyle only" list; don't rebuild balances/OCR/itemized/favorites/stats/invite/QR.

## How to run

Paste the block below into a `/loop` invocation (omit an interval to let the model
self-pace). The loop runs one of PULL / PREP / STOP per iteration and stops on its own
when nothing in-scope remains.

## Resolved parameters

| Loop slot      | Value |
|----------------|-------|
| Project        | Deun (redesign of `deun-at/deun`) |
| Roadmap        | [`docs/design_handoff/ROADMAP.md`](../design_handoff/ROADMAP.md) |
| Order          | **E0 first, in order**, then by the dependency cheat-sheet (E1→E2→E3; E4; E5→E4-T2; E6; E7). E8 polish trails the screen it covers. |
| Workflow       | superpowers |
| PULL           | `superpowers:subagent-driven-development` + `superpowers:test-driven-development`, verified by `superpowers:verification-before-completion` |
| PREP           | rarely needed — ROADMAP tasks already carry ID/file/scope/deps/acceptance. Use `superpowers:writing-plans` only to decompose a task that's too big for one iteration (e.g. E3-T1). All design decisions are resolved, so `superpowers:brainstorming` should not be needed. |
| Fix loop       | `superpowers:systematic-debugging` |
| Verify         | `flutter analyze` clean; `flutter test` green; looks right in **light AND dark**; new copy via `AppLocalizations` (en+de keys); if a provider/notifier changed, `dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart`. (Device/visual QA batched, not a gate.) |
| Push policy    | never push; local `fix/…` / `feat/…` branches only |
| Design ref     | prototype [`docs/design_handoff/Deun Redesign v2.dc.html`](../design_handoff/Deun%20Redesign%20v2.dc.html) (open in a browser) |
| Locked spec    | [`DESIGN_SPEC.md`](../design_handoff/DESIGN_SPEC.md) (tokens/layouts/copy) + the resolved decisions in [`README.md`](../design_handoff/README.md) |
| Out of scope   | rebuilding existing functionality (balances/settlement, receipt OCR, itemized data, favorites, statistics, invite, QR, friend requests, multi-mode split, routing, badges); changing Supabase queries or `*SelectString` for a restyle; re-architecting nav; brand/identity changes. **Only E3-T1 (Tap-to-Claim) touches the backend — schema changes are approved.** |
| Close          | mark the task done in ROADMAP.md (`✅ done · <SHA>`) and commit on the local branch (incl. any regenerated `.g.dart`). |

## The loop

```
/loop Build the Deun redesign from docs/design_handoff/ROADMAP.md, using the superpowers
workflow. Keep context lean by doing implementation work in subagents.

Each iteration, read docs/design_handoff/ROADMAP.md and do exactly one of:

1. PULL — if there's a ready task (deps satisfied, not blocked): implement the next one
   in locked order (E0 in order first, then the dependency cheat-sheet). Dispatch the
   implementation to a subagent using superpowers:subagent-driven-development; the
   subagent uses superpowers:test-driven-development (RED → GREEN → REFACTOR). Pull exact
   values from docs/design_handoff/DESIGN_SPEC.md and follow the rules in README.md:
   restyle via Theme.of(context).colorScheme / theme extensions (never hard-code the
   prototype's light hex), all visible copy via AppLocalizations (add en+de keys for new
   strings), reuse existing Riverpod providers and go_router routes. Do NOT rebuild
   anything in the "already built — restyle only" list, and do NOT change Supabase queries
   or *SelectString for a restyle. Before closing, run
   superpowers:verification-before-completion: flutter analyze must be clean and
   flutter test green; the screen must look right in BOTH light and dark; if a
   provider/notifier changed, run dart run build_runner build --delete-conflicting-outputs
   and commit the .g.dart. Device/visual QA is batched, not a gate (collect an eyeball
   checklist for the final report instead of blocking). Then close: commit on a local
   fix/… or feat/… branch — NEVER push, set upstream, force, amend, reset, or open a PR.
   Mark the task done in ROADMAP.md (✅ done · <SHA>).

2. PREP — only if a ready task is too big for one iteration (e.g. E3-T1, the per-unit
   claim data model + Supabase migration): plan ONLY that one with
   superpowers:writing-plans → a plan under docs/design_handoff/plans/, written against
   DESIGN_SPEC.md and the code as it exists right now. DESIGN_SPEC.md and the resolved
   decisions in README.md are locked law (full prototype look, dark mode required,
   Tap-to-Claim built as designed with per-unit unit-level ExpenseEntry rows, schema
   changes approved). Where the spec leaves a number or mechanic open, make a v0 choice
   consistent with the prototype and record it in the plan — don't block, don't invent
   scope. All design decisions are already resolved, so brainstorming should not be needed.

3. STOP — if nothing in-scope remains: end the loop with a final report — tasks done
   (with SHAs), v0 decisions taken, blocked tasks with reasons, and the device-QA
   checklist (per-screen light/dark fidelity) that needs my eyes on the phone.

If a task fails verification after 3 distinct superpowers:systematic-debugging attempts,
mark it blocked in ROADMAP.md with a one-line reason and move to the next ready task —
never thrash, never weaken or delete failing tests to get green, never touch DESIGN_SPEC.md
or the prototype. If everything remaining is blocked, STOP and report instead of looping idle.
```
