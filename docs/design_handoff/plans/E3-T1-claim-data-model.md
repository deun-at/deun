# E3-T1: Claim Data Model — Per-Unit Entries — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every claimable unit of an itemized expense its own `ExpenseEntry` (`quantity: 1`) so that a unit's `expense_entry_share` rows hold exactly that unit's claimers, with split = `unit_cost / number_of_claimers`, while keeping `Expense.groupMemberShareStatistic`-style derivation working.

**Architecture:** The unit-level representation is **persisted** (not derived at read time): when an itemized expense is saved, an item with `quantity: N` is exploded into N rows in `expense_entry` each with `quantity: 1, amount: unit_cost`, grouped by a shared `item_group_id` so the editor can re-collapse them. Claiming = mutating a single unit's `expense_entry_share` rows; each share gets `percentage = 100 / claimers` (consistent with the existing `percentage`-driven `groupMemberShareStatistic` and `get_user_spending_summary`). A new Riverpod `ClaimNotifier` exposes claim/unclaim/split-one operations and realtime refresh via the existing `RealtimeNotifierMixin`. A new `.sql` migration (applied later by the user, not via MCP) adds the `item_group_id` column plus an idempotent backfill RPC and a claim-mutation RPC.

**Tech Stack:** Flutter, Riverpod (`riverpod_annotation` + codegen), Supabase (PostgREST + plpgsql RPCs), `flutter_test`.

---

## Background — what exists today (read before starting)

These are the load-bearing facts this plan is built on. Cite/verify them, do not assume.

- **`lib/pages/expenses/data/expense_entry_model.dart`** — `ExpenseEntry` has `id, expenseId, name, amount, quantity, splitMode, createdAt`, getter `unitPrice => quantity > 0 ? amount / quantity : amount`, and `List<ExpenseEntryShare> expenseEntryShares`. `ExpenseEntryShare` has `expenseEntryId, email, displayName, percentage, fixedAmount, parts, isLocked, createdAt`. There is **no `itemGroupId` field yet**.
- **`lib/pages/expenses/data/expense_model.dart`** —
  - `Expense.expenseSelectString` (line 22) is the PostgREST select; `expense_entry(*, ...)` already returns all `expense_entry` columns, so a new column is auto-included.
  - `loadDataFromJson` (lines 24-61) builds `expenseEntries` keyed by entry id, sums `amount`, and computes `groupMemberShareStatistic[email] += entry.amount * (share.percentage / 100)` (lines 53-58). **This derivation is percentage-based and must keep working unchanged for per-unit entries.**
  - `toJson` (lines 63-77) is the legacy form-encoder (not the save path used today; `saveAll` reads the raw form map directly).
- **`lib/pages/expenses/data/expense_repository.dart`** —
  - `saveAll` (lines 75-217) parses the FormBuilder map (`expense_entry[index][field]`), builds an `entries` list of `{entry: {...}, shares: [...]}`, and calls RPC `save_expense_all`, falling back to `_saveAllLegacy` on missing-function error (`isMissingFunctionError`, helper line 14). **Key current behavior (lines 113-196):** one form entry → ONE `expense_entry` row with `amount = unitPrice * qty` and `quantity = qty`. This is exactly what E3-T1 changes for itemized expenses.
  - `_saveAllLegacy` (lines 221-246) deletes children then re-inserts entry+shares per item, then calls `update_group_member_shares`.
  - `fetchDetail` (lines 57-69) orders `expense_entry` by `sort_id`.
- **`supabase/migrations/20260610120000_atomic_save_rpcs.sql`** — defines `save_expense_all(_group_id uuid, _expense jsonb, _entries jsonb)`. The entries loop (lines 61-70) inserts `expense_entry (expense_id, name, amount, quantity, split_mode, sort_id)` and `expense_entry_share (expense_entry_id, email, percentage, fixed_amount, parts, is_locked)`. **This file is the template for migration style** (header comment block, `create or replace function`, `language plpgsql`, SECURITY INVOKER default).
- **`supabase/migrations/20260417_user_spending_summary.sql`** — confirms the read-side aggregation is also `sum(entry_amount * percentage / 100)` (lines 38-39). **Any v0 choice must keep `percentage` meaningful**, or this RPC breaks.
- **`lib/pages/expenses/service/receipt_parser.dart`** + **`lib/pages/expenses/data/receipt_scan_result.dart`** — parser emits `ReceiptLineItem(name, amount, quantity)` where `amount` is the **line total** and `unitPrice => amount / quantity`. `ReceiptParser` itself does NOT write to the DB.
- **`lib/pages/expenses/presentation/expense_detail.dart`** (lines 100-168) — the editor maps scan results / existing entries to form fields; itemized save flows through `ExpenseRepository.saveAll` (line 646). Scan line items today are added as one form entry each (lines 119-129).
- **`lib/pages/expenses/provider/expense_list.dart`** — canonical `RealtimeNotifierMixin` usage: `subscribeToChannel(ref, channelName, table: 'expense_update_checker', filter: PostgresChangeFilter(eq, 'group_id', groupId), onEvent: ...)` then `listenForResume(ref, onResume)`. Realtime is driven by the **`expense_update_checker`** table, not `expense_entry` directly.
- **`lib/helper/helper.dart`** — `roundCurrency(double) => (value*100).roundToDouble()/100` (line 30); `isMissingFunctionError(PostgrestException)` (line 14).
- **`lib/pages/expenses/data/itemized_totals.dart`** — `ItemLine(unitPrice, quantity)`, `lineTotal => unitPrice*quantity`, `itemizedTotal(items)`. Pure helper; good model for where claim-math helpers should live.
- Test conventions: model tests in `test/model/`, pure Dart, `group()`/`test()`/`expect()` (see `test/model/expense_entry_model_test.dart`).

---

## V0 Decisions (locked here — record, do not re-litigate during execution)

These resolve every place the spec/README leaves a number or mechanic open. Each is chosen to be consistent with the existing percentage-based model and the prototype.

1. **Per-unit representation is PERSISTED, not derived.** An itemized item with `quantity: N` is stored as **N `expense_entry` rows**, each `quantity: 1`, `amount: unit_cost`. Rationale: the README/DESIGN_SPEC say "represent each claimable unit as its own `ExpenseEntry` (`quantity: 1`) so its `expense_entry_share` rows hold that unit's claimers" — claiming mutates *per-unit* share rows, which only works if units are distinct rows. A derived approach can't store different claimers per unit.
2. **Split is expressed via `percentage = 100 / claimers`** on each unit's share rows (NOT `parts`, NOT `fixedAmount`). Rationale: `groupMemberShareStatistic` (expense_model.dart:55-56) and `get_user_spending_summary` (migration:38-39) both derive member cost from `entry.amount * percentage/100`. Using `percentage` keeps both working with zero changes. `parts`/`fixedAmount` stay `null` for claim units; `split_mode` is set to `'claim'` (new sentinel) so the editor/UI can distinguish claim units from manual splits. `is_locked` stays `false`.
   - **Unit cost to a claimer** = `unit_amount * (1/claimers) = unit_amount / claimers`. Identical to the README's `unit / claim.members.length`.
3. **Units of the same item are grouped by `item_group_id` (new uuid column on `expense_entry`).** All N rows from one item share one `item_group_id`; the editor re-collapses them into a single editable line (name, unit price, qty stepper) by grouping on it. Rationale: without grouping, editing an itemized expense would show N identical lines. A nullable column is fully backward compatible (existing rows = `null` = treated as a standalone single-unit item).
4. **Unclaimed units have ZERO share rows.** A unit with no claimers contributes `0` to `groupMemberShareStatistic`; the **payer covers unclaimed** (matches DESIGN_SPEC line 161 "unclaimed = total−claimed (payer covers unclaimed)"). No phantom share row is written for the payer.
5. **Rounding:** unit cost is left UN-rounded at the share-row level (percentage is exact, e.g. `33.333...`); display rounding uses existing `roundCurrency`. Rationale: matches today's percentage storage (saveAll writes `100/n` without rounding). Penny-reconciliation is a presentation concern for E3-T2/T3, not the data model.
6. **`split_mode = 'claim'`** is the sentinel string for claim units. Existing modes are `'equal' | 'shares' | 'percentage' | 'exact'` (saveAll lines 119-163). `'claim'` is additive and ignored by the existing split-math switch (falls into no branch on save because claim units are written directly, not via the form split path).
7. **Backfill of existing itemized expenses is OPT-IN and idempotent, exposed as an RPC** (`explode_itemized_entries`), not run automatically inside the schema migration. Rationale: exploding rows is data-mutating and the user applies migrations manually; a separate callable RPC lets them backfill per-group when ready without forcing a global rewrite. Existing un-exploded `quantity:N` itemized rows keep rendering correctly (they just aren't per-unit-claimable until backfilled or re-saved).
8. **Atomic claim mutation via RPC `claim_set_unit_shares`**, with a client-side multi-statement fallback mirroring the `save_expense_all` / `_saveAllLegacy` pattern (delete this unit's shares → insert new share set → bump `expense_update_checker`). Rationale: keeps the "atomic RPC with backwards-compatible fallback" convention from git history (commit `861cdc6`).

### Open architectural fork (resolved, but recorded for the executor)

There were two viable representations for "N units":
- **(A) N physical `expense_entry` rows + `item_group_id`** ← **CHOSEN** (decision 1/3). Pro: per-unit share rows fall out naturally; `groupMemberShareStatistic` and the spending-summary RPC need zero change. Con: row-count inflation (an item of qty 10 = 10 rows) and a backfill for legacy data.
- **(B) One `expense_entry` row + a new `expense_entry_unit_share` child table keyed by unit index.** Pro: no row inflation. Con: a brand-new table, all read aggregations (`expense_model.dart`, `get_user_spending_summary`) must be rewritten to understand unit indices, and `Expense.loadDataFromJson` would need a parallel parse path. Much larger blast radius; rejected for v0.

If row inflation ever becomes a real problem, (B) is the documented escape hatch — but v0 ships (A).

---

## File Structure

| File | Change | Responsibility |
|------|--------|----------------|
| `supabase/migrations/20260618000000_per_unit_claim_entries.sql` | **Create** | Add `item_group_id` column; `claim_set_unit_shares` RPC; `explode_itemized_entries` backfill RPC; update `save_expense_all` to accept per-unit entries + `item_group_id`. |
| `lib/pages/expenses/data/expense_entry_model.dart` | **Modify** | Add `itemGroupId` field + parse it; add `isClaimUnit` getter. |
| `lib/pages/expenses/data/claim_math.dart` | **Create** | Pure cost-math helpers (per-member totals, claimed/unclaimed) over a unit list. |
| `lib/pages/expenses/data/expense_repository.dart` | **Modify** | Explode itemized items into per-unit entries on save; add `claimSetUnitShares` (RPC + fallback) + `claimUnits` grouping helper. |
| `lib/pages/expenses/provider/claim_notifier.dart` | **Create** | Riverpod notifier: load expense detail, expose claim/unclaim/split-one, realtime refresh. |
| `lib/pages/expenses/provider/claim_notifier.g.dart` | **Generated** | `dart run build_runner build`. |
| `test/model/claim_math_test.dart` | **Create** | Cost-math unit tests. |
| `test/model/expense_entry_claim_test.dart` | **Create** | `itemGroupId` / `isClaimUnit` parse tests. |
| `test/model/expense_repository_explode_test.dart` | **Create** | Per-unit explosion logic tests (pure, no Supabase). |

> **Note on the migration filename:** `20260618000000_per_unit_claim_entries.sql`. The timestamp must sort AFTER `20260610120000_atomic_save_rpcs.sql`. If the execution date differs, use that day's `YYYYMMDD000000` prefix — keep it lexically last.

---

## Sequencing & what must land before E3-T2/E3-T3

Execute tasks in order. Tasks 1-3 are pure-Dart/SQL and independently testable. Task 4 (repository) depends on Task 1 (model). Task 5 (notifier) depends on Tasks 1, 4. Task 6 (migration) is independent SQL but **must be authored before the notifier/repo RPC calls are meaningful at runtime** (the fallback keeps the app working until it's applied).

- **Before E3-T2** (claim screen layout/summary): Tasks 1, 2, 3, 5 must land — the screen binds to `ClaimNotifier` and `claim_math` for the dark summary card (your share / progress / unclaimed / per-member totals).
- **Before E3-T3** (chips & actions): Task 4 (`claimSetUnitShares`) and the notifier's claim/unclaim/split-one methods must land — chips call them.
- **The migration (Task 6) must be applied by the user before per-unit claiming works against real data**; until then the write path still produces correct (collapsed) itemized expenses via the fallback, and existing data renders unchanged.

---

## Task 1: Add `itemGroupId` + `isClaimUnit` to the entry model

**Files:**
- Modify: `lib/pages/expenses/data/expense_entry_model.dart`
- Test: `test/model/expense_entry_claim_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/model/expense_entry_claim_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';

void main() {
  group('ExpenseEntry.itemGroupId', () {
    test('loads item_group_id when present', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'u1',
        'expense_id': 'exp1',
        'name': 'Beer',
        'amount': 5.0,
        'quantity': 1,
        'split_mode': 'claim',
        'item_group_id': 'grp-1',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.itemGroupId, 'grp-1');
    });

    test('item_group_id is null when absent', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'u1',
        'expense_id': 'exp1',
        'name': 'Beer',
        'amount': 5.0,
        'quantity': 1,
        'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });

      expect(entry.itemGroupId, isNull);
    });
  });

  group('ExpenseEntry.isClaimUnit', () {
    test('true when split_mode is claim and quantity is 1', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'u1', 'expense_id': 'exp1', 'name': 'Beer',
        'amount': 5.0, 'quantity': 1, 'split_mode': 'claim',
        'item_group_id': 'grp-1', 'created_at': '2024-03-15T10:00:00',
      });
      expect(entry.isClaimUnit, isTrue);
    });

    test('false for a regular equal-split entry', () {
      final entry = ExpenseEntry(index: 0);
      entry.loadDataFromJson({
        'id': 'e1', 'expense_id': 'exp1', 'name': 'Dinner',
        'amount': 40.0, 'quantity': 1, 'split_mode': 'equal',
        'created_at': '2024-03-15T10:00:00',
      });
      expect(entry.isClaimUnit, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/model/expense_entry_claim_test.dart`
Expected: FAIL — `itemGroupId`/`isClaimUnit` not defined.

- [ ] **Step 3: Implement the model changes**

In `lib/pages/expenses/data/expense_entry_model.dart`, add the field and getters to `ExpenseEntry`. After `late String createdAt;` (line 9) add:

```dart
  late String? itemGroupId;
```

Add to the getters block (after the `unitPrice` getter, line 11):

```dart
  /// True when this entry is a single claimable unit produced by the
  /// per-unit claim model (split_mode 'claim', quantity 1).
  bool get isClaimUnit => splitMode == 'claim' && quantity == 1;
```

In `loadDataFromJson`, after `splitMode = json["split_mode"] ?? 'equal';` (line 24) add:

```dart
    itemGroupId = json["item_group_id"];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/model/expense_entry_claim_test.dart`
Expected: PASS (both groups).

- [ ] **Step 5: Run the existing model test to confirm no regression**

Run: `flutter test test/model/expense_entry_model_test.dart`
Expected: PASS (the existing suite still green; `item_group_id` is optional).

- [ ] **Step 6: Commit**

```bash
git add lib/pages/expenses/data/expense_entry_model.dart test/model/expense_entry_claim_test.dart
git commit -m "E3-T1: add itemGroupId + isClaimUnit to ExpenseEntry"
```

---

## Task 2: Pure claim cost-math helpers

**Files:**
- Create: `lib/pages/expenses/data/claim_math.dart`
- Test: `test/model/claim_math_test.dart`

This is the read-side math the E3-T2 summary card binds to. It mirrors `groupMemberShareStatistic` but is expressed over a list of claim units for direct unit testing and reuse by the notifier.

- [ ] **Step 1: Write the failing test**

Create `test/model/claim_math_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';

void main() {
  // Helper to build a unit: cost + list of claimer emails.
  ClaimUnit u(double cost, List<String> claimers) =>
      ClaimUnit(unitCost: cost, claimers: claimers);

  group('memberShareTotals', () {
    test('single claimer pays full unit cost', () {
      final totals = memberShareTotals([u(5.0, ['sam@x'])]);
      expect(totals['sam@x'], 5.0);
    });

    test('split one unit between two claimers', () {
      final totals = memberShareTotals([u(6.0, ['sam@x', 'priya@x'])]);
      expect(totals['sam@x'], 3.0);
      expect(totals['priya@x'], 3.0);
    });

    test('sums a member across multiple units', () {
      final totals = memberShareTotals([
        u(5.0, ['sam@x']),
        u(6.0, ['sam@x', 'priya@x']),
      ]);
      expect(totals['sam@x'], 8.0); // 5 + 3
      expect(totals['priya@x'], 3.0);
    });

    test('unclaimed unit contributes to nobody', () {
      final totals = memberShareTotals([u(5.0, [])]);
      expect(totals.isEmpty, isTrue);
    });
  });

  group('claimedTotal / unclaimedTotal', () {
    test('claimed sums only units with >=1 claimer', () {
      final units = [u(5.0, ['sam@x']), u(4.0, []), u(6.0, ['priya@x'])];
      expect(claimedTotal(units), 11.0);
    });

    test('unclaimed = grand total - claimed', () {
      final units = [u(5.0, ['sam@x']), u(4.0, []), u(6.0, ['priya@x'])];
      expect(unclaimedTotal(units), 4.0);
    });

    test('all claimed -> unclaimed is zero', () {
      final units = [u(5.0, ['sam@x']), u(6.0, ['priya@x'])];
      expect(unclaimedTotal(units), 0.0);
    });

    test('none claimed -> claimed is zero, unclaimed is total', () {
      final units = [u(5.0, []), u(6.0, [])];
      expect(claimedTotal(units), 0.0);
      expect(unclaimedTotal(units), 11.0);
    });

    test('claimers can exceed an integer share without error (3-way)', () {
      final totals = memberShareTotals([u(10.0, ['a', 'b', 'c'])]);
      expect(totals['a']!, closeTo(3.3333, 0.0001));
      expect(totals['b']!, closeTo(3.3333, 0.0001));
      expect(totals['c']!, closeTo(3.3333, 0.0001));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/model/claim_math_test.dart`
Expected: FAIL — `claim_math.dart` missing.

- [ ] **Step 3: Implement `claim_math.dart`**

Create `lib/pages/expenses/data/claim_math.dart`:

```dart
/// A single claimable unit for cost-math purposes: its cost and the emails
/// of the members who have claimed it. Mirrors one `expense_entry`
/// (quantity 1, split_mode 'claim') with its `expense_entry_share` rows.
class ClaimUnit {
  const ClaimUnit({required this.unitCost, required this.claimers});

  final double unitCost;
  final List<String> claimers;

  bool get isClaimed => claimers.isNotEmpty;

  /// Cost to each claimer of this unit = unitCost / number of claimers.
  /// Returns 0 when nobody has claimed it (the payer covers unclaimed units).
  double get perClaimerCost => claimers.isEmpty ? 0 : unitCost / claimers.length;
}

/// Per-member share totals across all units. A member's total is the sum,
/// over every unit they claimed, of `unitCost / claimers`. Equivalent to
/// `Expense.groupMemberShareStatistic` for claim units (percentage = 100/n).
Map<String, double> memberShareTotals(List<ClaimUnit> units) {
  final totals = <String, double>{};
  for (final unit in units) {
    if (!unit.isClaimed) continue;
    final per = unit.perClaimerCost;
    for (final email in unit.claimers) {
      totals[email] = (totals[email] ?? 0) + per;
    }
  }
  return totals;
}

/// Sum of all unit costs that have at least one claimer.
double claimedTotal(List<ClaimUnit> units) {
  double sum = 0;
  for (final unit in units) {
    if (unit.isClaimed) sum += unit.unitCost;
  }
  return sum;
}

/// Sum of all unit costs (claimed or not).
double grandTotal(List<ClaimUnit> units) {
  double sum = 0;
  for (final unit in units) {
    sum += unit.unitCost;
  }
  return sum;
}

/// Total cost not yet claimed by anyone — the payer covers this.
double unclaimedTotal(List<ClaimUnit> units) => grandTotal(units) - claimedTotal(units);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/model/claim_math_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/expenses/data/claim_math.dart test/model/claim_math_test.dart
git commit -m "E3-T1: add pure claim cost-math helpers"
```

---

## Task 3: Per-unit explosion logic (pure, repository-static)

**Files:**
- Modify: `lib/pages/expenses/data/expense_repository.dart`
- Test: `test/model/expense_repository_explode_test.dart`

Factor the "explode one itemized item into N unit entries" decision into a **pure static method** so it is testable without Supabase, then wire it into `saveAll` in Task 4.

- [ ] **Step 1: Write the failing test**

Create `test/model/expense_repository_explode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';

void main() {
  group('ExpenseRepository.explodeItemizedEntry', () {
    test('qty 3 item becomes 3 unit entries each amount = unit price', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer',
        unitPrice: 5.0,
        quantity: 3,
        itemGroupId: 'grp-1',
        sortIdStart: 10,
      );

      expect(units.length, 3);
      for (final unit in units) {
        final entry = unit['entry'] as Map<String, dynamic>;
        expect(entry['amount'], 5.0);
        expect(entry['quantity'], 1);
        expect(entry['split_mode'], 'claim');
        expect(entry['item_group_id'], 'grp-1');
        expect(entry['name'], 'Beer');
        expect((unit['shares'] as List).isEmpty, isTrue); // new units start unclaimed
      }
    });

    test('sort_id increments per unit so order is stable', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Beer', unitPrice: 5.0, quantity: 2,
        itemGroupId: 'grp-1', sortIdStart: 20,
      );
      expect((units[0]['entry'] as Map)['sort_id'], 20);
      expect((units[1]['entry'] as Map)['sort_id'], 21);
    });

    test('qty 1 produces exactly one unit', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Wine', unitPrice: 8.5, quantity: 1,
        itemGroupId: 'grp-2', sortIdStart: 10,
      );
      expect(units.length, 1);
      expect((units[0]['entry'] as Map)['amount'], 8.5);
    });

    test('qty 0 is treated as 1 (guard)', () {
      final units = ExpenseRepository.explodeItemizedEntry(
        name: 'Odd', unitPrice: 2.0, quantity: 0,
        itemGroupId: 'grp-3', sortIdStart: 10,
      );
      expect(units.length, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/model/expense_repository_explode_test.dart`
Expected: FAIL — `explodeItemizedEntry` undefined.

- [ ] **Step 3: Implement the pure static method**

In `lib/pages/expenses/data/expense_repository.dart`, add inside the `ExpenseRepository` class (e.g. just above `saveAll`):

```dart
  /// Explodes one itemized line (unit price + quantity) into per-unit
  /// claim entries. Each unit is its own expense_entry (quantity 1,
  /// split_mode 'claim', amount = unit price), grouped by [itemGroupId] so
  /// the editor can re-collapse them. New units start with no claimers
  /// (empty shares) — the payer covers them until someone claims.
  static List<Map<String, dynamic>> explodeItemizedEntry({
    required String? name,
    required double unitPrice,
    required int quantity,
    required String itemGroupId,
    required int sortIdStart,
  }) {
    final qty = quantity > 0 ? quantity : 1;
    final units = <Map<String, dynamic>>[];
    for (int i = 0; i < qty; i++) {
      units.add({
        'entry': {
          'name': name,
          'amount': roundCurrency(unitPrice),
          'quantity': 1,
          'split_mode': 'claim',
          'item_group_id': itemGroupId,
          'sort_id': sortIdStart + i,
        },
        'shares': <Map<String, dynamic>>[],
      });
    }
    return units;
  }
```

`roundCurrency` is already imported via `package:deun/helper/helper.dart` (top of the file).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/model/expense_repository_explode_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/expenses/data/expense_repository.dart test/model/expense_repository_explode_test.dart
git commit -m "E3-T1: add pure per-unit explosion helper to ExpenseRepository"
```

---

## Task 4: Wire explosion into the save path + add claim-mutation repository methods

**Files:**
- Modify: `lib/pages/expenses/data/expense_repository.dart`

No new unit test here for the network calls (they require a live Supabase); the pure logic is covered by Task 3. Verification is `flutter analyze` + the full suite staying green.

- [ ] **Step 1: Make `saveAll` emit per-unit claim entries for itemized expenses**

In `saveAll` (lines 113-196), the loop currently builds one entry per item with `amount = unitPrice*qty, quantity = qty`. Change it so that when an item is **itemized with quantity > 1 OR explicitly flagged claimable**, it is exploded.

Detection rule (v0): an item is claimable when its form data carries `'claimable': true` **or** when `qty > 1` and the item has no manual `share_data` (i.e. it's a plain itemized line, not a custom split). Replace the body that builds `entries.add({...})` (lines 184-195) with:

```dart
        final bool isClaimable = (expenseEntry['claimable'] == true) ||
            (qty > 1 && (shareData.isEmpty));

        if (isClaimable) {
          final itemGroupId = (expenseEntry['item_group_id'] as String?) ??
              _uuid();
          entries.addAll(ExpenseRepository.explodeItemizedEntry(
            name: expenseEntry['name'] as String?,
            unitPrice: unitPrice,
            quantity: qty,
            itemGroupId: itemGroupId,
            sortIdStart: sortId,
          ));
          sortId += qty * 10; // leave room between groups
        } else {
          entries.add({
            'entry': {
              'name': expenseEntry['name'],
              'amount': entryTotal,
              'quantity': qty,
              'split_mode': splitMode,
              'item_group_id': expenseEntry['item_group_id'],
              'sort_id': sortId,
            },
            'shares': shareRows,
          });
          sortId += 10;
        }
```

Add a small uuid helper at the bottom of the class (Supabase `gen_random_uuid` is server-side; the client needs one for grouping). Use the existing `uuid` package if present, else `Random`-based. Check `pubspec.yaml` first; if `uuid` is a dependency, use it:

```dart
  static String _uuid() => const Uuid().v4(); // import 'package:uuid/uuid.dart';
```

If `uuid` is NOT a dependency, instead let the **server** assign the group id: pass `'item_group_id': null` for the first unit and have the migration's `save_expense_all` `coalesce` a fresh `gen_random_uuid()` per item group (see Task 6, where the RPC generates the group id when null). **Pick one and record it in the commit message.** Recommended: server-side generation to avoid a new client dependency — pass a per-item sentinel key (`'item_group_seq': <int>`) so the RPC groups consecutive units, and drop the client `_uuid()` entirely.

> **Executor note:** the server-side option keeps the client dependency-free and is the recommended v0. The RPC in Task 6 is written for it (`item_group_seq`). If you choose client-side uuids, adjust the RPC to read `item_group_id` directly instead.

- [ ] **Step 2: Add `claimUnits` read helper**

Add a method that fetches an expense and returns its claim units grouped by `item_group_id`, for the notifier:

```dart
  /// Fetches an expense's claim units (split_mode 'claim') as ClaimUnit
  /// objects for cost math, preserving DB sort order.
  static Future<Expense> fetchClaimExpense(String expenseId) =>
      ExpenseRepository.fetchDetail(expenseId);
```

(`fetchDetail` already returns the full `Expense` with entries+shares ordered by `sort_id`; the notifier maps entries where `isClaimUnit` to `ClaimUnit`. No new query needed — this method exists for naming clarity and can be omitted if the notifier calls `fetchDetail` directly.)

- [ ] **Step 3: Add `claimSetUnitShares` (atomic RPC + fallback)**

Add the claim-mutation method, mirroring the `save_expense_all`/`_saveAllLegacy` fallback pattern:

```dart
  /// Sets the exact claimer set for a single claim unit (one expense_entry).
  /// [claimerEmails] empty => the unit becomes unclaimed. Each claimer gets
  /// percentage = 100 / claimers so existing percentage-based aggregations
  /// (groupMemberShareStatistic, get_user_spending_summary) stay correct.
  /// Atomic via claim_set_unit_shares RPC; falls back to a multi-step write
  /// against servers that don't have the RPC yet.
  static Future<void> claimSetUnitShares({
    required String groupId,
    required String expenseId,
    required String unitEntryId,
    required List<String> claimerEmails,
  }) async {
    final double pct = claimerEmails.isEmpty ? 0 : 100 / claimerEmails.length;
    final shareRows = claimerEmails
        .map((email) => {'email': email, 'percentage': pct})
        .toList();
    try {
      await supabase.rpc('claim_set_unit_shares', params: {
        '_group_id': groupId,
        '_expense_id': expenseId,
        '_entry_id': unitEntryId,
        '_shares': shareRows,
      });
    } on PostgrestException catch (e) {
      if (!isMissingFunctionError(e)) rethrow;
      await _claimSetUnitSharesLegacy(groupId, expenseId, unitEntryId, shareRows);
    }
  }

  static Future<void> _claimSetUnitSharesLegacy(
      String groupId, String expenseId, String unitEntryId,
      List<Map<String, dynamic>> shareRows) async {
    await supabase.from('expense_entry_share').delete().eq('expense_entry_id', unitEntryId);
    if (shareRows.isNotEmpty) {
      await supabase.from('expense_entry_share').insert(
            shareRows.map((s) => {...s, 'expense_entry_id': unitEntryId}).toList(),
          );
    }
    // Trigger realtime + recompute, same as the save path.
    await supabase.rpc('update_group_member_shares', params: {"_group_id": groupId, "_expense_id": expenseId});
  }
```

> The legacy path relies on `update_group_member_shares` also bumping `expense_update_checker` (it does today — that's how `expense_list` realtime fires). If it doesn't, the RPC in Task 6 handles the checker bump; the fallback is best-effort.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: No errors (warnings about unused `fetchClaimExpense` are acceptable; remove it if you went with the direct-`fetchDetail` option). Then `flutter test` — full suite green (no behavior change for non-itemized expenses; explosion only affects itemized claimable items).

- [ ] **Step 5: Commit**

```bash
git add lib/pages/expenses/data/expense_repository.dart
git commit -m "E3-T1: emit per-unit claim entries on save; add claimSetUnitShares with fallback"
```

---

## Task 5: Riverpod `ClaimNotifier`

**Files:**
- Create: `lib/pages/expenses/provider/claim_notifier.dart`
- Generated: `lib/pages/expenses/provider/claim_notifier.g.dart` (via build_runner)

The notifier owns claim state for one expense and exposes the operations E3-T2/T3 call. It loads the expense via `fetchDetail`, exposes `ClaimUnit` lists + cost math, and refreshes on realtime.

- [ ] **Step 1: Write the notifier**

Create `lib/pages/expenses/provider/claim_notifier.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/claim_math.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

part 'claim_notifier.g.dart';

/// Owns the claim state for a single itemized expense. Loads the expense,
/// exposes its claim units + cost math, and mutates claimer sets per unit.
@riverpod
class ClaimNotifier extends _$ClaimNotifier with RealtimeNotifierMixin {
  late String _groupId;

  @override
  FutureOr<Expense> build(String groupId, String expenseId) async {
    _groupId = groupId;
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    subscribeToChannel(
      ref: ref,
      channelName: 'claim:$expenseId',
      table: 'expense_update_checker',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'expense_id',
        value: expenseId,
      ),
      onEvent: (_) async {
        final fresh = await ExpenseRepository.fetchDetail(expenseId);
        state = AsyncData(fresh);
      },
    );

    listenForResume(
      ref: ref,
      onResume: () async {
        state = await AsyncValue.guard(() => ExpenseRepository.fetchDetail(expenseId));
      },
    );

    return await ExpenseRepository.fetchDetail(expenseId);
  }

  /// Claim units (split_mode 'claim') in stable DB order.
  List<ClaimUnit> get units {
    final expense = state.value;
    if (expense == null) return const [];
    return expense.expenseEntries.values
        .where((e) => e.isClaimUnit)
        .map((e) => ClaimUnit(
              unitCost: e.amount,
              claimers: e.expenseEntryShares.map((s) => s.email).toList(),
            ))
        .toList();
  }

  Map<String, double> get memberTotals => memberShareTotals(units);
  double get claimed => claimedTotal(units);
  double get unclaimed => unclaimedTotal(units);

  /// Adds [email] as a claimer of the unit [unitEntryId] (alongside any
  /// existing claimers). Split becomes unitCost / claimers.
  Future<void> claimUnit(String unitEntryId, String email) async {
    final current = _claimersOf(unitEntryId);
    if (current.contains(email)) return;
    await _setClaimers(unitEntryId, [...current, email]);
  }

  /// Removes [email] from the unit's claimers (unclaim / leave a split).
  Future<void> unclaimUnit(String unitEntryId, String email) async {
    final current = _claimersOf(unitEntryId);
    if (!current.contains(email)) return;
    await _setClaimers(unitEntryId, current.where((e) => e != email).toList());
  }

  /// "Split one": sets the exact claimer set chosen in the inline picker.
  Future<void> splitUnit(String unitEntryId, List<String> claimerEmails) async {
    await _setClaimers(unitEntryId, claimerEmails);
  }

  List<String> _claimersOf(String unitEntryId) {
    final entry = state.value?.expenseEntries[unitEntryId];
    return entry?.expenseEntryShares.map((s) => s.email).toList() ?? const [];
  }

  Future<void> _setClaimers(String unitEntryId, List<String> emails) async {
    final expenseId = state.value?.id;
    if (expenseId == null) return;
    await ExpenseRepository.claimSetUnitShares(
      groupId: _groupId,
      expenseId: expenseId,
      unitEntryId: unitEntryId,
      claimerEmails: emails,
    );
    // Realtime will refresh; optimistic refetch keeps UI snappy.
    state = await AsyncValue.guard(() => ExpenseRepository.fetchDetail(expenseId));
  }
}
```

- [ ] **Step 2: Generate Riverpod code**

Run:
```bash
$env:Path = "C:\Users\ASUS\flutter\bin;" + $env:Path
dart run build_runner build --delete-conflicting-outputs
```
Expected: `lib/pages/expenses/provider/claim_notifier.g.dart` is generated, no errors.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/expenses/provider/claim_notifier.dart lib/pages/expenses/provider/claim_notifier.g.dart
git commit -m "E3-T1: add ClaimNotifier for per-unit claim state + realtime"
```

---

## Task 6: Supabase migration (`.sql` file — applied later by the user, NOT via MCP)

**Files:**
- Create: `supabase/migrations/20260618000000_per_unit_claim_entries.sql`

> **This migration is delivered as a `.sql` file under `supabase/migrations/` and is NOT auto-applied.** The user applies it manually. The app keeps working before it lands via the fallback paths (Task 4): itemized expenses still save as collapsed `quantity:N` entries until `save_expense_all` understands per-unit entries, and `claimSetUnitShares` falls back to direct table writes. Existing data renders unchanged (the new column is nullable).

- [ ] **Step 1: Write the migration**

Create `supabase/migrations/20260618000000_per_unit_claim_entries.sql`:

```sql
-- Per-unit claim entries (E3-T1).
--
-- Motivation: the Tap-to-Claim feature models claims PER UNIT. An itemized
-- item with quantity N is now stored as N expense_entry rows (quantity 1,
-- split_mode 'claim', amount = unit price), grouped by item_group_id so the
-- editor can re-collapse them. Each unit's expense_entry_share rows hold that
-- unit's claimers; split = unit_cost / claimers, expressed as
-- percentage = 100 / claimers (keeps groupMemberShareStatistic and
-- get_user_spending_summary correct with no read-side changes).
--
-- Backwards compatible:
--   * item_group_id is nullable; existing rows stay null and render as before.
--   * save_expense_all is replaced to accept per-unit entries + item_group_id,
--     generating a group id per consecutive run of item_group_seq.
--   * claim_set_unit_shares is new; old clients ignore it.
--   * explode_itemized_entries backfill is OPT-IN (call per group), never run
--     automatically by this migration.
--
-- SECURITY INVOKER (default): RLS applies as for the current client calls.

-- 1. Schema: group units that belong to the same itemized line.
alter table public.expense_entry
  add column if not exists item_group_id uuid;

create index if not exists expense_entry_item_group_id_idx
  on public.expense_entry (item_group_id);

-- 2. Replace save_expense_all to persist item_group_id and assign a fresh
--    group id per run of units sharing the same _item->>'item_group_seq'.
create or replace function public.save_expense_all(
  _group_id uuid,
  _expense jsonb,
  _entries jsonb
) returns uuid
language plpgsql
as $$
declare
  _expense_id uuid;
  _item jsonb;
  _entry_id uuid;
  _seq text;
  _prev_seq text;
  _group uuid;
begin
  if _expense ? 'id' then
    _expense_id := (_expense->>'id')::uuid;
    update public.expense e set
      name = r.name,
      expense_date = r.expense_date,
      paid_by = r.paid_by,
      group_id = r.group_id,
      user_id = r.user_id,
      category = r.category
    from jsonb_populate_record(null::public.expense, _expense) r
    where e.id = _expense_id;
    if not found then
      insert into public.expense (id, name, expense_date, paid_by, group_id, user_id, category)
      select r.id, r.name, r.expense_date, r.paid_by, r.group_id, r.user_id, r.category
      from jsonb_populate_record(null::public.expense, _expense) r;
    end if;
  else
    insert into public.expense (name, expense_date, paid_by, group_id, user_id, category)
    select r.name, r.expense_date, r.paid_by, r.group_id, r.user_id, r.category
    from jsonb_populate_record(null::public.expense, _expense) r
    returning id into _expense_id;
  end if;

  delete from public.expense_entry where expense_id = _expense_id;

  _prev_seq := null;
  _group := null;
  for _item in select * from jsonb_array_elements(coalesce(_entries, '[]'::jsonb)) loop
    -- Resolve item_group_id: explicit value wins; otherwise generate one new
    -- uuid per run of equal item_group_seq values; null seq => standalone.
    if (_item->'entry') ? 'item_group_id'
       and coalesce(_item->'entry'->>'item_group_id', '') <> '' then
      _group := (_item->'entry'->>'item_group_id')::uuid;
    else
      _seq := _item->'entry'->>'item_group_seq';
      if _seq is null then
        _group := null;
      elsif _seq is distinct from _prev_seq then
        _group := gen_random_uuid();
      end if;
      _prev_seq := _seq;
    end if;

    insert into public.expense_entry (expense_id, name, amount, quantity, split_mode, sort_id, item_group_id)
    select _expense_id, r.name, r.amount, r.quantity, r.split_mode, r.sort_id, _group
    from jsonb_populate_record(null::public.expense_entry, _item->'entry') r
    returning id into _entry_id;

    insert into public.expense_entry_share (expense_entry_id, email, percentage, fixed_amount, parts, is_locked)
    select _entry_id, s.email, s.percentage, s.fixed_amount, s.parts, coalesce(s.is_locked, false)
    from jsonb_populate_recordset(null::public.expense_entry_share, _item->'shares') s;
  end loop;

  perform public.update_group_member_shares(_group_id, _expense_id);

  return _expense_id;
end;
$$;

-- 3. Atomic claim mutation: set the exact claimer set for one unit.
create or replace function public.claim_set_unit_shares(
  _group_id uuid,
  _expense_id uuid,
  _entry_id uuid,
  _shares jsonb
) returns void
language plpgsql
as $$
begin
  delete from public.expense_entry_share where expense_entry_id = _entry_id;

  insert into public.expense_entry_share (expense_entry_id, email, percentage)
  select _entry_id, s.email, s.percentage
  from jsonb_populate_recordset(null::public.expense_entry_share, _shares) s;

  -- Recompute member shares (also bumps expense_update_checker so the
  -- claim screen's realtime subscription fires).
  perform public.update_group_member_shares(_group_id, _expense_id);
end;
$$;

-- 4. OPT-IN backfill: explode existing quantity>1 itemized entries of one
--    expense into per-unit claim entries. Idempotent: skips entries that are
--    already single units (quantity 1) or already claim units. Existing
--    shares on a multi-unit entry are dropped (a quantity>1 itemized line had
--    no per-unit claimers yet). Call per expense when ready; never automatic.
create or replace function public.explode_itemized_entries(_expense_id uuid)
returns int
language plpgsql
as $$
declare
  _e record;
  _unit_price numeric;
  _i int;
  _group uuid;
  _new_entry uuid;
  _count int := 0;
  _sort int;
begin
  for _e in
    select id, name, amount, quantity, sort_id
    from public.expense_entry
    where expense_id = _expense_id
      and quantity > 1
      and split_mode <> 'claim'
  loop
    _unit_price := round((_e.amount / _e.quantity)::numeric, 2);
    _group := gen_random_uuid();
    _sort := coalesce(_e.sort_id, 0);

    for _i in 1.._e.quantity loop
      insert into public.expense_entry
        (expense_id, name, amount, quantity, split_mode, sort_id, item_group_id)
      values
        (_expense_id, _e.name, _unit_price, 1, 'claim', _sort + _i, _group)
      returning id into _new_entry;
      _count := _count + 1;
    end loop;

    delete from public.expense_entry where id = _e.id; -- cascades shares
  end loop;

  return _count;
end;
$$;
```

- [ ] **Step 2: Sanity-check SQL (optional, planning only)**

The migration is NOT applied here. If the executor wants a syntax sanity-check, eyeball it against `20260610120000_atomic_save_rpcs.sql` for consistent style. Do not run `apply_migration` / `execute_sql` via MCP — the user applies it.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260618000000_per_unit_claim_entries.sql
git commit -m "E3-T1: migration — item_group_id, per-unit save_expense_all, claim + backfill RPCs"
```

---

## Task 7: Adapt the receipt-parser write path to per-unit entries

**Files:**
- Modify: `lib/pages/expenses/presentation/expense_detail.dart`

The parser (`receipt_parser.dart`) already produces `ReceiptLineItem(name, amount=lineTotal, quantity)`. No parser change is needed — the **editor's** mapping of scan items into form fields must carry the unit price + quantity + a claimable flag so `saveAll` explodes them.

- [ ] **Step 1: Pass unit price + quantity + claimable flag from scan items**

In `expense_detail.dart` initState (lines 116-129), scan line items are added with `initialAmount: item.amount` (the line total). Change to use the **unit price** and carry quantity so the saved entry can be exploded:

```dart
    } else if (widget.receiptResult != null && widget.receiptResult!.lineItems.isNotEmpty) {
      _itemizedOverride = true;
      for (final item in widget.receiptResult!.lineItems) {
        final expenseEntry = ExpenseEntry(index: _newTextFieldId++);
        _entries.add(ExpenseEntryData(
          index: expenseEntry.index,
          expenseEntry: expenseEntry,
          onRemove: () => _removeEntry(expenseEntry),
          groupMembers: groupMembers,
          initialName: item.name,
          initialAmount: item.unitPrice.toStringAsFixed(2),
          initialQuantity: item.quantity.toString(),
        ));
      }
    }
```

(`ExpenseEntryData` already supports `initialQuantity` — see `expense_detail.dart:588-598` which reads `data.initialQuantity`. Verify the field exists; if `initialAmount` was previously the line total, switching to `unitPrice` + `initialQuantity` keeps the displayed line total identical because the editor computes `unitPrice * qty`.)

- [ ] **Step 2: Mark itemized lines claimable when saving an itemized expense**

The itemized editor's CTA is "Add & share for claiming" (DESIGN_SPEC line 133) — i.e. an itemized save is inherently claimable. Ensure the form map for itemized entries includes `'claimable': true` so `saveAll` (Task 4 detection rule) explodes them even at quantity 1. Locate where the itemized form is assembled before `ExpenseRepository.saveAll(...)` (line 646) and add `expense_entry[<index>][claimable] = true` (or set it in the entry-data → form serialization). If serialization happens inside `ExpenseEntryData`/`expense_entry_widget.dart`, add the flag there for itemized mode.

> **Executor note:** confirm exactly where `expense_entry[i][shares]` / `[quantity]` form keys are written (grep `expense_entry[` in `expense_detail.dart` and `expense_entry_widget.dart`). Add the `claimable` key alongside them only in itemized mode. Quick-split expenses must NOT be exploded (they use `share_data` and the existing split path).

- [ ] **Step 3: Verify**

Run: `flutter analyze` then `flutter test test/widgets/expense_itemized_editor_test.dart test/widgets/receipt_scanner_sheet_test.dart`
Expected: PASS. If an existing test asserts scan items use line-total as `initialAmount`, update it to expect unit price (the displayed line total is unchanged via qty).

- [ ] **Step 4: Commit**

```bash
git add lib/pages/expenses/presentation/expense_detail.dart
git commit -m "E3-T1: adapt receipt-scan + itemized editor to emit claimable per-unit entries"
```

---

## Task 8: Full-suite verification

- [ ] **Step 1: Run the entire test suite**

Run:
```bash
$env:Path = "C:\Users\ASUS\flutter\bin;" + $env:Path
flutter test
```
Expected: All tests PASS. New suites: `claim_math_test`, `expense_entry_claim_test`, `expense_repository_explode_test`.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Commit any test fixups**

```bash
git add -A
git commit -m "E3-T1: fix up tests for per-unit claim model"
```

---

## Risks & Mitigations

1. **Row inflation.** An itemized expense with large quantities (e.g. qty 50) creates 50 rows. *Mitigation:* acceptable for v0 (receipts rarely have huge per-line quantities); escape hatch is fork (B) above. Index on `item_group_id` keeps grouping cheap.
2. **Backfill is manual and lossy for pre-existing per-unit claimers.** `explode_itemized_entries` drops shares on multi-unit entries (there were none, by construction, since today's itemized save can attach shares to a `quantity:N` row via custom split). *Mitigation:* the backfill only targets `split_mode <> 'claim'` AND `quantity > 1`; a quantity>1 entry that already had a manual `share_data` split would lose it. **Flag to user:** only backfill expenses that are pure itemized (no custom split), or skip backfill entirely and rely on re-save. Recommended: do NOT mass-backfill; let users re-open + save itemized expenses to migrate them lazily.
3. **`update_group_member_shares` must bump `expense_update_checker`.** The claim RPC + fallback assume this is how realtime fires (proven by `expense_list.dart`). *Mitigation:* if it does not, add an explicit `expense_update_checker` upsert inside `claim_set_unit_shares`. Verify against the live function before relying on realtime.
4. **`item_group_seq` server-grouping vs client uuid.** The save path (Task 4) and migration (Task 6) must agree on how group ids are assigned. *Mitigation:* recommended path is server-side via `item_group_seq`; the RPC is written for it. If client uuids are chosen, the RPC's explicit-`item_group_id` branch already handles it — but pick ONE and keep them consistent.
5. **Percentage precision.** `100 / 3 = 33.333...` stored as a float; summing three units can drift by sub-cent. *Mitigation:* matches today's behavior exactly (saveAll already writes `100/n`); display uses `roundCurrency`. No new risk.
6. **Migration timestamp ordering.** Must sort after `20260610120000`. *Mitigation:* use a `YYYYMMDD000000` prefix ≥ that day; CI/Supabase apply migrations in lexical order.

---

## Self-Review

- **Spec coverage:** data-model mapping (Tasks 1, 3), persisted-vs-derived choice (V0 #1), share representation `percentage=100/n` (V0 #2, Task 4/6), `groupMemberShareStatistic`-style derivation preserved (Task 2 mirrors it; no read-side change), migration `.sql` under `supabase/migrations/` not auto-applied (Task 6), backfill approach (Task 6 #4 + Risk 2), write-path explosion + receipt-parser adaptation (Tasks 4, 7), claim/unclaim/split-one math (Tasks 2, 4, 5), Riverpod notifier (Task 5), unit tests incl. 0-claimers / all-claimed / over-under / split-one (Task 2), sequencing + E3-T2/T3 gating (Sequencing section), v0 decisions + risks (dedicated sections). All spec bullets map to a task.
- **Placeholders:** none — every code step shows the code; the one genuine implementation-judgment point (form-key location for `claimable`, Task 7 Step 2) is bounded with an exact grep target because the precise serialization site must be confirmed against current code, not invented.
- **Type consistency:** `ClaimUnit(unitCost, claimers)`, `memberShareTotals/claimedTotal/unclaimedTotal/grandTotal`, `explodeItemizedEntry(name, unitPrice, quantity, itemGroupId, sortIdStart)`, `claimSetUnitShares(groupId, expenseId, unitEntryId, claimerEmails)`, `ClaimNotifier.build(groupId, expenseId)` with `claimUnit/unclaimUnit/splitUnit` — names used consistently across notifier, repo, tests, and migration (`claim_set_unit_shares`, `explode_itemized_entries`, `item_group_id`, `item_group_seq`, `split_mode='claim'`).
