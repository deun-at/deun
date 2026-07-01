# Deun Redesign — Open Backlog (single source for "what's still missing")

Everything **not yet done** lives here, in one place. The *done* history is intentionally **not**
duplicated — it stays in its logs:
- Build tasks E0–E8 + the V3 motion epic: all `✅ done` in [`ROADMAP.md`](ROADMAP.md).
- Design-fidelity findings F01–F78: all resolved in [`../design_audit/README.md`](../design_audit/README.md)
  (audit loop STOPPED 2026-06-26, no 🔥/⚠️ deltas remain).

This file holds three things: (1) post-release bugs found on-device, (2) audit findings deferred as
out-of-scope, (3) screens still needing a device/fresh-account capture.

**Severity:** 🔥 high (wrong money / crash / unusable) · ⚠️ medium (visible, recoverable) · 💅 low (cosmetic).
**Status:** 🔴 open · ✅ done · ⛔ blocked (needs greenlight / separate task) · ⏳ capture-pending.
**QA harness:** physical device via `adb`; use the **hans** test group for any write; never touch real groups.

---

## 1 · Post-release on-device issues
Found while using the app after the redesign landed. One issue = one fix-loop iteration (reproduce → TDD fix →
verify `flutter analyze` clean + `flutter test` green + on-device light **and** dark → commit).

### I-1 · Group-detail hero action row overflows horizontally 🔥 · 🔴 open
- **Screen:** Group detail (`lib/pages/groups/presentation/group_detail.dart`, color hero, ~line 458).
- **Symptom:** With many members the hero action row (member `AvatarStack` + "+N" + **Settle**) overflows
  right — yellow/black overflow stripe; **Settle** is clipped/partly unusable.
- **Repro:** group with ~6 members (e.g. "Steiermark"); the 4-member "hans" hero fits fine — member-count
  dependent.
- **Expected:** row fits at any member count (cap visible avatars / `Flexible` / wrap); Settle stays tappable.
  Verify light + dark.
- **Note:** not confirmed fixed by a static read — needs device repro.

### I-2 · Floating FABs cover the right-edge amount of ledger rows 💅 · 🔴 open (confirm intended)
- **Screen:** Group detail ledger (`group_detail_list.dart`), Scan / New-expense FABs.
- **Symptom:** bottom-right Scan FAB / "New expense" pill float over the ledger; a row's right-edge amount
  sits behind the FAB and is partly hidden.
- **Expected:** enough trailing/bottom inset (or FAB placement) that amounts are never occluded.

### I-3 · Components still feel Material, not the handoff 🔥 · ✅ RESOLVED by the audit + de-Materialize work
The original "M3-recolored, not bespoke" complaint and all its sub-items (I-3a buttons → 15px rounded-rect,
I-3b flat-white cards + soft shadow, I-3c filled inputs, I-3d uppercase tracked section labels, I-3e rounded
icon set, I-3f circular icon buttons / tabular nums) were closed by the audit loop and the V3 de-Materialize
epic. Evidence: the custom widget library `lib/widgets/restyle/` (`primary_button.dart`, `secondary` variant,
`soft_card.dart`, `app_segmented_control.dart`, `section_label.dart`, `deun_header.dart`, `sheet_scaffold.dart`)
plus findings F30/F14/F37/F39/F40/F51/F77 and tasks E0-T5 (THEME_AUDIT) + V3-T1…T10. The `StadiumBorder`
entries remaining in `theme_builder.dart` are FABs + balance pills, which I-3a explicitly says to keep stadium.

### I-4 · "Claim items" doesn't toggle the split view in the expense editor 🔥 · ✅ RESOLVED by F118
- **Screen:** expense editor (`expense_entry_widget.dart`), Quick/Itemized (split↔items) mode toggle bound to
  the entry-count-derived mode (`AppSegmentedControl` / editor mode).
- **Symptom:** "claim items" does not switch the view as it should.
- **Resolution (2026-07-02):** F118 removed the per-item split UI entirely — the Itemized tab *is* the
  claim-items view now (item cards only; Quick keeps the split section). Toggle verified on web (hans),
  light + dark. See `../design_audit/plans/f118_itemized_claim_model.md`.

### I-5 · Edit-expense Save vs "Add & share for claiming" behave inconsistently 🔥 · ✅ RESOLVED by F118
- **Screen:** editor save path + `claimable:true` wiring (`markEntriesClaimable`,
  `expense_repository.saveAll` auto-explode of itemized lines).
- **Symptom:** editing an expense's items, then **Save** vs the **"Add & share for claiming"** ("hand off")
  CTA do different / wrong things — the two paths diverge incorrectly.
- **Resolution (2026-07-02):** the itemized tab now has a single CTA — "Add & share for claiming"
  (`claimable:true`); the pinned footer Save renders in Quick mode only, so the diverging plain-save path
  no longer exists. End-to-end share flow verified in hans (create → tap-to-claim units → delete).

> **Splitting math (Equal/%/shares/exact, rounding, locked shares, per-unit claim):** a code-level review was
> in progress; append any confirmed bug here with repro + numbers before fixing.

---

## 2 · Deferred audit findings (⛔ out of scope — need a greenlight / separate task)
Surfaced by the design audit, intentionally **not** fixed because each needs a new screen/route, a Supabase
query/schema change, added/removed real data, or a nav re-architecture — beyond a restyle. Full context per id
is in [`../design_audit/README.md`](../design_audit/README.md).

- ~~**F67 · Personal statistics 🔥**~~ — ✅ **FIXED** (migration `20260628000000_fix_spending_summary_color_bigint.sql`).
  Root cause: `get_user_spending_summary` declared its return column `color_value int`, but `group.color_value`
  holds a 32-bit ARGB color (e.g. 4282339765) that overflows int4 → Postgres `22003 integer out of range` → the
  400 → infinite spinner. Fix widened the return column to `bigint` (drop+recreate; body unchanged; no Dart
  change — client reads `num`). Verified live: RPC now returns `HTTP 200` with rows.
- **F36 · Reset password ⚠️** — no dedicated reset screen; recovery is an inline link + snackbar on Login.
  v3 wants a full screen (back / title / subtitle / email / "Send reset link"). Net-new screen + route.
- **F58 · Settle up ⚠️** — implemented as a modal bottom sheet; v3 (DESIGN_SPEC §10) is a full drill-down
  page with back-arrow header. Sheet→page is nav/routing re-architecture.
- **F64 · Group statistics ⚠️** — trend is a line/area chart; v3 specifies a monthly **bar** chart with the
  selected month highlighted. Chart-type / data-shape swap.
- **F71 · New/Edit group ⚠️** — members shown as one "Add friends" SearchAnchor; v3 wants the full member
  roster as inline toggle rows + "Add guest". New selection behavior, not a restyle.
- **F75 · Tap to Claim ⚠️** — item cards are minimal; v3 adds category icon, ×N qty, "€X each · N ordered"
  subline, claimer-avatar chips. Pulls in itemized/quantity data the row doesn't surface.
- **F46 · Expense editor (quick) ⚠️** — split-mode segmented hidden on quick split (checkboxes only); exposing
  it enables multi-mode split behavior (out of scope).
- **F47 · Expense editor ⚠️** — split-mode has 3 options (Amount/%/Shares); v3 specifies 4
  (Equal/Shares/%/Exact). New `SplitMode` values + split math.
- **F34 · Friends 💅** — "All friends" rows show name + `username#code` subtitle; matching v3 (balance as
  subtitle) would contradict F07 and drop the real handle that uniquely identifies friends.
- **F31 · Settings/Profile 💅** — app has an extra "Display name" field v3's mock omits; `display_name` is a
  persisted Supabase column used app-wide — removing it would regress functionality.

---

## 3 · Capture-pending (⏳ needs phone / fresh account — fixes landed, visual sign-off owed)
- **F29 · Onboarding** — gated behind `user.needsOnboarding`; the tester account is already onboarded, so
  `OnboardingScreen` never renders on web. Capture from the phone with a brand-new signup.
- **Tap to Claim (F73/F74/F76 fixes)** — landed in code + claim_page tests pass, but the web itemized editor
  drops the 2nd line item on Save so the claim screen is unreachable on web. Needs a phone capture (real
  multi-item itemized expense) for light/dark sign-off.
