# Audit-fix loop overhaul — design (v1)

**Date:** 2026-06-26 · **Status:** approved, pending implementation
**Touches:** `docs/superpowers/AUDIT_LOOP.md`, `docs/design_audit/tools/capture.md`, a new gitignored
`docs/design_audit/tools/.web-creds`. **No app code. No parallelism. No new visualization.**

## Why
Running the loop end-to-end exposed three real costs the current design pays:
1. **Wasted FIX iterations** — false positives (F13, audit inverted above/below) and out-of-scope
   items (F31 display-name data, F34 friend-handle, F36 net-new reset screen) entered the FIX queue
   and burned a whole iteration each before being blocked.
2. **Re-triaging a known flake** — a `+722 -5` (`claim_chips`, `expense_detail_tiles`,
   `expense_picker_sheets`, `group_detail_payment`) is a stale-build artifact, not a regression;
   it cost three separate clean-verify subagent runs to re-confirm 727 green.
3. **No unattended reach** — web capture needs a session; without one the loop stalls on 11 screens.

## Goals (chosen)
Throughput (by *culling wasted work*, not parallelism), Autonomy, Coverage/rigor.
Explicitly **not** chosen: Visibility — so no dashboard/graph. `graphify` evaluated and rejected
(no Dart grammar → empty graph on a ~100% Dart app; file-finding was never the bottleneck).

## Decisions
- **Sequential FIX stays.** No git-worktree parallelism, no auto-merge. Throughput comes from the
  triage gate removing doomed/false iterations, not from concurrency.
- **Auth creds on disk.** The throwaway test account (`tester@deun.app`) lives in a **gitignored**
  `tools/.web-creds` so the loop can re-login unattended. Never committed; `storageState` cache in
  `tools/.web-auth.json` (already gitignored).

## Part 1 — Audit triage gate  *(coverage + autonomy + throughput-by-culling)*
A new step between AUDIT and "append to README". The AUDIT subagent still returns a raw findings
list; before any of it becomes an open `- [ ]` item, **one triage subagent** verifies the whole batch
and returns a structured verdict per finding:
- **Real?** Re-check the delta against the rendered v3 prototype + `DESIGN_SPEC`/`COMPONENTS`.
  False → dropped with a one-line note (never enters the queue). *(would have killed F13)*
- **In scope?** Classify against the loop's out-of-scope list (new screen / route / data / Supabase
  query / nav re-arch / feature). Out-of-scope → appended **pre-marked `⛔ blocked — out of scope:
  <reason>`**, not as open work. *(F31, F34, F36)*
- **Severity** confirmed (🔥/⚠️/💅).

Orchestrator then appends: verified-in-scope → open `- [ ]`; out-of-scope → blocked line; false →
omitted (logged in the commit body). One extra dispatch per AUDIT round; saves ≥1 FIX iteration per
bogus finding.

## Part 2 — Auth + self-heal  *(autonomy; unblocks the 11 pending screens now)*
`capture.md` section 2 gains a login step:
- If `tools/.web-auth.json` storageState exists and is still valid, reuse it.
- Else read creds from `tools/.web-creds`, drive the login via Playwright, save fresh storageState.
- **Self-heal:** if any capture navigation bounces to the login screen mid-run (session expired),
  re-login once from creds and resume; only after a failed re-login is a screen `⏳ capture-pending`.

## Part 3 — Flake hardening  *(autonomy)*
Promote the `-5` rule from a note to a hard gate in the loop's Verify row and the FIX brief: a
`flutter test` showing the named `-5` set is **not** trusted until re-run as
`flutter clean && flutter pub get && flutter test`. Subagents must clean-then-retry before reporting
BLOCKED on those tests; the orchestrator no longer spawns separate triage runs for it.

## Out of scope (YAGNI)
Parallel FIX / worktrees · graphify / any code-index MCP · visualization/dashboard · incremental
(diff-only) audits · dependency-aware scheduling.

## Acceptance
- A planted false-positive finding is dropped by the triage gate, never reaching the FIX queue.
- A planted out-of-scope finding is appended already-`⛔ blocked`, no FIX dispatch.
- A fresh session (no storageState) logs in from `.web-creds` and captures an authed screen.
- `.web-creds` is gitignored and absent from `git status`.
- The documented `-5` set, when it appears, is resolved by clean-retry inside the same FIX iteration.
