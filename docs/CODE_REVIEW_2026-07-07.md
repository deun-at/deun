# Deun Code Review — 2026-07-07

Full-codebase review before/around the v2.0.0+13 production release.
Six review passes: money correctness, security, state/realtime, duplication, test coverage, architecture — plus `flutter analyze` (clean, 0 issues).

**Verdict:** Core money math is solid. 2 release-blocking bugs, 3 fix-soon issues, ~1000 lines of dead code, ~350 lines of duplication (4 consolidations worth doing). Architecture is sound and will hold for a year of feature growth.

---

## 1. Fix before next release (critical)

### 1.1 Guest merge corrupts data across groups — `lib/pages/groups/presentation/group_join_page.dart:110-119` ✅ verified by direct read

When a joining user claims a guest member:

```dart
await supabase.from('expense').update({'paid_by': email}).eq('paid_by', guestEmail);            // no group scoping!
await supabase.from('expense_entry_share').update({'email': email}).eq('email', guestEmail);   // no group scoping!
await supabase.from('group_member').delete().eq('group_id', widget.groupId).eq('email', guestEmail);
await supabase.from('user').delete().eq('email', guestEmail);                                   // hard-deletes guest everywhere
```

- The `expense` / `expense_entry_share` updates filter **only by guest email** — if that guest exists in any other group, joining ONE group silently rewrites their expense history in ALL groups.
- The `user` row is hard-deleted even if the guest still belongs to other groups.
- Four separate awaits, no transaction — failure midway leaves half-merged data.
- Bonus: this is also the **only layering violation in the app** (raw Supabase writes in a presentation file; 8 `.from()` calls + 1 `.rpc()`).

**Fix:** move the whole merge into one server-side RPC scoped to the group; only delete the `user` row if it has no remaining memberships; call it through `GroupRepository`. One fix resolves both the corruption bug and the layering violation.

### 1.2 Receipt scan drops quantity, treats line-total as unit-price — `lib/pages/expenses/presentation/expense_detail.dart:135-145` and `~:723-733` ✅ verified by direct read

Scanned line items pass `item.amount` (the line **total**) as `initialAmount` (which `ExpenseEntryWidget` treats as **unit price**) and never pass `initialQuantity`:

```dart
initialAmount: item.amount.toStringAsFixed(2),   // line TOTAL fed into unit-price field, no initialQuantity
```

The existing-entry path 10 lines above does it correctly (`expenseEntry.unitPrice` + `expenseEntry.quantity`).

**Failure:** receipt line "3 × Coffee €5.97" → editor shows qty 1, €5.97. User "corrects" qty to 3 → expense saved as €17.91 (3× overcharge), propagating into balances and settle-up. Even untouched, quantity is silently lost, defeating per-unit claims for scanned items. On the live production scan path (both local parser and Gemini edge function build `ReceiptLineItem` the same way). No test covers the receipt→editor population.

**Fix (2 lines × 2 places):** `initialAmount: item.unitPrice.toStringAsFixed(2), initialQuantity: item.quantity.toString()` at both the initial-load branch (~:135) and the `_scanReceipt` rescan (~:723).

---

## 2. Fix soon (high)

### 2.1 Tap-to-claim is a last-write-wins race — `lib/pages/expenses/provider/claim_notifier.dart:123-139`

`claimUnit`/`unclaimUnit`/`splitUnit` read the locally cached claimer list, mutate client-side, then send the **entire replacement list** to `claim_set_unit_shares` (migration `20260618000000_per_unit_claim_entries.sql:120-139`), which does delete-all + insert with no compare-and-swap.

**Failure:** Alice and Bob tap "claim" on the same item within one realtime round-trip → both read `current = []` → last commit wins, the other's claim is silently deleted. One person charged 100% instead of 50%, no error shown.

**Fix:** change the RPC to add/remove a single email (`INSERT … ON CONFLICT DO NOTHING` / targeted delete) instead of full-list replace. No concurrency test exists.

### 2.2 Realtime retry timers survive dispose — `lib/helper/realtime_mixin.dart:140-146`

On `channelError`/`timedOut` the mixin schedules `Future.delayed(...) => _createChannel(...)`. Neither `disposeChannels()` (:197-203) nor `resubscribeChannels()` (:165-180) cancels pending timers.

- Notifier disposed before retry fires → zombie channel recreated on a dead mixin, never cleaned up (leak).
- Pause→resume: old in-flight retry fires after `resubscribeChannels()` already rebuilt channels → duplicate channel for same name/table → doubled `onEvent`, doubled fetches.
- Retry callback calls `_ref?.read(realtimeConnectionStatusProvider.notifier)` (:149, :152) on a Ref captured from a disposed notifier → throws.

**Fix:** `bool _disposed` flag (or generation counter) set in `disposeChannels()`, checked at top of retry closure and before every `_ref?.read`.

**Related — unguarded async gaps in realtime handlers:**
- `lib/pages/expenses/provider/expense_list.dart:38-59` — `onEvent` awaits `fetchDetail` then sets state with no `ref.mounted` check (its own `reload()` at :70-76 guards correctly).
- `lib/pages/groups/provider/group_list.dart:22-52` — same pattern (fetch at :36, no guard; `reload()` at :60-63 guards).
- **Fix:** route `onEvent` through `reload()` — `GroupDetailNotifier` (:22-24) already does this and is the good example.

### 2.3 QR friend-add writes mutual "accepted" unilaterally — `lib/pages/friends/data/friendship_repository.dart:145-160` (invoked from `friend_accept_page.dart:88`)

```dart
await supabase.from("friendship").upsert([
  {"requester": me, "addressee": email, "status": "accepted"},
  {"requester": email, "addressee": me, "status": "accepted"},   // target never consented
]);
```

The normal search-based `request()` path creates a `pending` row requiring separate acceptance; the QR/deep-link path skips consent entirely. If a QR/link leaks (screenshot, forwarded), anyone opening it becomes a mutual friend.

**Fix:** server-side (RLS/RPC) enforce that `status` can only flip to `accepted` by the addressee of a pre-existing pending request. May be intended UX for in-person scans — but the server must still enforce it.

---

## 3. Verify server-side (cannot be proven from client repo)

- **RLS policies**: the client relies entirely on `.eq(...)` filters for reads/writes on `friendship` (all methods), `expense` / `expense_entry` / `expense_entry_share` (legacy fallback paths in `expense_repository.dart`), `group_member` (legacy fallback in `group_repository.dart`), `device_tokens`. Confirm RLS restricts writes to self/group-members on all of these — a modified client could omit every filter. Run Supabase advisors.
- **OAuth redirect** — `android/app/src/main/AndroidManifest.xml:47-54`: `app.deun.www://login-callback` is a bare custom scheme (not a verified App Link). Mitigated if PKCE is active (supabase_flutter default) — confirm `authFlowType` is PKCE explicitly.

**Security all-clear elsewhere:** no service_role keys / keystores / .env files tracked in git; `google-services.json` + `firebase_options.dart` contain only standard public Firebase client keys; no client-side isAdmin/isOwner authorization; parse-receipt edge function receives only OCR text lines (no user-controlled URLs); no PII in release-path logging (one debug-only email log at `group_detail_payment.dart:339`, low severity).

---

## 4. Realtime / performance

- **`GroupListNotifier` subscription is global and undebounced** — `lib/pages/groups/provider/group_list.dart:18-53` subscribes to `group_update_checker` with **no filter** (contrast `group_detail.dart:21` which correctly filters by `group_id`) and no debounce (contrast `friendship_list.dart:39-51` which has a 2s debounce). Every group change by any user platform-wide triggers a `fetchDetail` on every client. **Fix:** copy the friendship debounce at minimum; filter server-side (user-scoped channel / Realtime Authorization) ideally.
- **`realtimeConnectionStatusProvider` is dead** — `realtime_mixin.dart:21-29` is written (`markConnected`/`markDisconnected`) but has zero `ref.watch`/`ref.read` consumers anywhere. Disconnects are invisible to users. Wire the promised "live updates paused" banner or delete the provider.
- **Pagination visibility gap (medium)** — `expense_list.dart:80-100`: a realtime insert landing mid-scroll shifts the server-side offset window; dedup prevents duplicates but can't backfill an item pushed past the fetched range → expense silently missing until full reload. Not a money bug (balances come from `group_shares_summary`). Fix opportunistically (cursor-based pagination or reload-on-insert-while-paging).
- **Fragile offset read** — `group_detail_list.dart:77` reads `.notifier.offset` via `ref.read` inside build; works only because a sibling `ref.watch` forces rebuilds. No action needed unless the sibling watch is removed.

---

## 5. Duplication (the "copied to ship faster" debt)

~350 duplicated lines across 12 sites. **Worth consolidating (4):**

| # | What | Where | Est. lines | Consolidation |
|---|------|-------|-----------|---------------|
| 1 | Realtime list-event handling (delete-from-list / fetch-and-upsert-by-id) | `groups/provider/group_list.dart:22-62` + `expenses/provider/expense_list.dart:22-62` | ~50 | Shared handler in `RealtimeNotifierMixin`. **Do together with fix 2.2** — otherwise the mounted-guard fix must land in both copies. |
| 2 | Friendship action handlers (accept/decline/cancel + a 2nd accept copy) | `friends/presentation/friend_list.dart:39-71` + `friend_accept_page.dart:66-75` | ~48 | One `handleFriendshipAction(...)` helper (try/catch/mounted/snackbar/notify). |
| 3 | Sheet-opener boilerplate (`showModalBottomSheet` w/ identical 4 params) | 8+ call sites across statistics/friends/groups/settings | ~70 | `showDeunSheet(context, child, {isScrollControlled})` in `widgets/restyle/sheet_scaffold.dart`. |
| 4 | JSON→model list loop (`List.empty(growable:true)` + for + `loadDataFromJson`) | 6× across the 3 repositories | ~24 | Extension/helper in `lib/helper/helper.dart`. |

**Can wait (leave or do opportunistically):** `_Empty` widget duplicated in 2 statistics sheets; friend list-section structures (`contact_suggestion` vs `search_result`); RPC-else-legacy fallback pattern (2×); optimistic-update pattern (2×); ad-block init (2×); settings sheet openers (3×). Two flagged duplication targets (`pending_request_list` / `requested_friendship_list`) are actually **dead code — delete instead of consolidating** (see §7).

---

## 6. Architecture

**Verdict: sound; holds for a year of growth. No rewrite needed.**

- **Layering:** exactly ONE violation in the whole app — `group_join_page.dart` (see §1.1). Every other presentation file goes through repositories; providers only use supabase_flutter for the realtime mixin.
- **Repositories:** 5 static-method classes, no shared base, unmockable — but the test suite sensibly tests pure math/models instead, so it costs nothing today. Leave alone unless integration tests become a goal. Error-handling convention is mostly consistent (`PostgrestException` + `isMissingFunctionError` + rethrow) except `friendship_repository.dart` (zero try/catch, propagates raw) and `reminder_repository.dart` (StateError/null mix). Note the convention, don't rewrite.
- **God files:**
  - `claim_page.dart` (1581) — one screen + ~25 private widgets, cohesive. Leave alone.
  - `expense_detail.dart` (1098) — cohesive page controller. Leave alone.
  - `expense_entry_widget.dart` (1288) — genuine mix: contains its own rebalancing algorithm (`_recalculateAmounts`/`_recalculatePercentages`/`_scaleLockedMembers`, ~:199-257) parallel to `split_allocation.dart`. **Move the math to `split_allocation.dart`** (mirror the `claim_math.dart` pattern) before a third copy appears.
  - `navigation.dart` (692) — four responsibilities: route tree, Firebase Messaging init/token handling (:419-484), deep-link URI parsing (:529-582), lifecycle/scaffold. **Split into `navigation.dart` + `push_notifications.dart` + `deep_links.dart`** next time push/deep-links are touched.
- **Model layer:** `group_model.dart` runs the greedy debt-settlement algorithm inside the model (:71-202) and `isFavorite` (:33-37) reaches into `supabase.auth` from a model. `test/model/group_settlement_test.dart` already tests this standalone — **finish the half-done extraction into `group_settlement.dart`** (precedent: `claim_math.dart`).
- **Navigation state:** group/expense objects passed as live Dart objects via `extra:` (13 occurrences, 6 files + 10 route builders) — breaks browser refresh / shareable URLs on web. Broad refactor (IDs + refetch); only do it if web deep-linking becomes a real complaint.
- **Cross-feature coupling:** Group↔Expense bidirectional imports = same aggregate, fine. Statistics importing groups/expenses models = inherently cross-cutting, fine. Two minor reaches (`friends` ↔ `groups` data layers in 2 presentation files) — fix opportunistically.
- **Restyle migration ~90% done:** restyle widgets dominate (soft_card 27, primary_button 24, section_label 22, money_text 21 usages). Old `user_avatar.dart` survives in 4 friend screens (`group_member_search`, `pending_request_list`, `requested_friendship_list`, `friend_accept_page`) — swap for `member_avatar.dart` when in those files.

---

## 7. Dead code — delete now (~1000 lines, zero imports, zero risk)

| File | Lines | Note |
|------|-------|------|
| `lib/pages/expenses/service/receipt_parser.dart` | 463 | Superseded by Gemini edge-function parser. Only its own tests import it (✅ verified by grep) — also delete `test/service/receipt_parser_amount_test.dart` + `receipt_parser_total_test.dart`. |
| `lib/pages/friends/presentation/pending_request_list.dart` | 170 | Zero imports. |
| `lib/pages/friends/presentation/requested_friendship_list.dart` | 78 | Zero imports. |
| `lib/pages/friends/presentation/friend_add_button_state.dart` | 18 | Zero imports. |
| `lib/pages/groups/presentation/group_share_view_model.dart` | 20 | Zero imports. |
| `lib/widgets/form_loading_widget.dart` | — | Zero imports. |
| `lib/widgets/rounded_container.dart` | — | Zero imports. |
| `lib/widgets/sliver_grab_widget.dart` | — | Zero imports. |

---

## 8. Test coverage

86 test files; widgets well covered (30+), money paths thin exactly where it hurts.

**Coverage by module:** widgets ✅ · expenses/groups/friends/settings/auth/statistics/helper ◐ partial · root/core (main, auth_gate, navigation, provider) ✗ none.

**Most dangerous untested paths:**
1. `expense_model.dart:54-57` — `groupMemberShareStatistic` (amount × percentage/100 accumulation, rounding).
2. `claim_notifier.dart` — state transitions untested (widget tests mock the notifier entirely); no concurrency test (see §2.1).
3. `statistics_notifiers.dart:65-81` — `_bucketByMonth` date bucketing.
4. `expense_entry_model.dart:12` — `unitPrice` getter (`quantity > 0 ? amount/quantity : amount`).
5. `friendship_repository.dart` — sync/fetch and balance aggregation.
6. Receipt→editor population path in `expense_detail.dart` (would have caught §1.2).

**Quality smells:** claim_page widget test mocks the logic under test; group_detail_payment tests only presence/absence (no `PaymentPartition.fromSummary` edge cases); statistics tests cover chart math but not the aggregation feeding it; settlement test missing 1-member/0-balance edge case; expense_repository test covers only the static `explodeItemizedEntry`.

**Highest-value additions:** tests for §1.1 (guest merge scoping), §1.2 (receipt qty/unit-price), §2.1 (claim concurrency), and `_bucketByMonth`.

---

## 9. Verified solid — do not touch

- Greedy debt-simplification algorithm (`group_model.dart:111-202`) — `== 0` double comparisons proven safe (bit-identical values from repeated `roundCurrency`).
- Settle-up sign conventions (`group_model.dart:71-109`, `payment_view_model.dart:42-59`) — consistent, no asymmetry.
- Split validation (`expense_entry_widget.dart:605-626`, `split_allocation.dart:32-100`) — cent tolerance enforced at save; empty-member-list guarded before division.
- German comma-decimal parsing (`parseAmount`) — correct thousands/decimal disambiguation, `tryParse` (no silent NaN).
- `loadMoreEntries` pagination — offset advanced only after successful fetch, dedupes realtime inserts.
- App-resume lifecycle (`navigation.dart:583-596`) — single observer, `_wasPaused` guard against transient inactive→resumed double-fires.
- `AuthGate` + router — `_routerConfig` built once, `const NavigationScreen` reused across auth-stream ticks (no router churn).
- `listenForResume` microtask re-entrancy guard in the mixin.
- Claim writes all route through the server RPC (no client-side bypass) — the §2.1 issue is in *what* is sent, not a bypass.
- `flutter analyze`: **0 issues**.

## 10. Housekeeping

- ~95 packages outdated within constraints (supabase_flutter 2.12.2→2.16.0, realtime_client 2.7→2.11, sign_in_with_apple 6→8, …). Not urgent; batch an upgrade before drift gets painful.

---

## Suggested order

1. §1.2 receipt qty fix (2 lines × 2 places) + test
2. §1.1 guest-merge RPC (also kills the only layering violation) + test
3. §7 dead-code deletion (free win, any time)
4. §2.2 retry-timer/mounted guards **together with** duplication item #1 (shared realtime handler)
5. §2.1 claim RPC add/remove semantics + concurrency test
6. §3 RLS verification pass (Supabase advisors)
7. §2.3 QR friendship server-side enforcement
8. Remaining dedups (§5) + `GroupListNotifier` debounce (§4) opportunistically
