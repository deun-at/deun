# Architecture Review — Deun App

**Date:** 2026-04-10
**Overall Health:** 5.5/10

---

## Critical Issues

### 1. No Error Handling in Real-time Subscriptions
- **File:** `lib/helper/realtime_mixin.dart:81-83`
- **Status:** [x] DONE
- **Impact:** App silently serves stale data after network drops
- **Fix:** Added status checking, exponential backoff retry (up to 3 attempts), error logging

### 2. Race Condition in Channel Re-subscription
- **File:** `lib/helper/realtime_mixin.dart:90-98`
- **Status:** [x] DONE
- **Impact:** Duplicate channels and memory leaks on app resume
- **Fix:** Added `_isResubscribing` guard flag + duplicate config detection in `subscribeToChannel()`

### 3. No Transaction Wrapping for Multi-step Saves
- **File:** `lib/pages/expenses/data/expense_repository.dart:70-204`
- **Status:** [x] DONE
- **Impact:** Orphaned entries if any step fails mid-operation
- **Fix:** Wrapped `saveAll()` in both expense_repository and group_repository with try-catch + rethrow

### 4. Double-Precision Currency Arithmetic
- **Files:** `group_model.dart`, `expense_model.dart`, all repositories
- **Status:** [x] DONE
- **Impact:** Rounding errors accumulate across calculations
- **Fix:** Added `roundCurrency()` helper, applied at all accumulation boundaries in group_model, expense_repository, friendship_repository

### 5. No Error Handling in Repositories
- **Files:** All `*_repository.dart`
- **Status:** [x] DONE (partial — saveAll methods wrapped; remaining fetch methods rely on AsyncValue.guard)
- **Impact:** Exceptions propagate uncaught to UI
- **Fix:** Added PostgrestException imports + try-catch in expense_repository.saveAll and group_repository.saveAll

---

## High Priority Issues

### 6. Pagination Breaks on Real-time Reload
- **File:** `lib/pages/expenses/provider/expense_list.dart:69-74`
- **Status:** [x] DONE
- **Fix:** Derive `_hasMore` from actual result count instead of blindly resetting to true

### 7. Friendship List Over-fetching
- **File:** `lib/pages/friends/provider/friendship_list.dart:43-48`
- **Status:** [x] DONE
- **Fix:** Both channels now use `_debouncedReload()` instead of immediate reload

### 8. Duplicate Config Accumulation
- **File:** `lib/helper/realtime_mixin.dart:59-66`
- **Status:** [x] DONE (fixed with #2)
- **Fix:** Added duplicate channelName check in `subscribeToChannel()`

### 9. SQL Injection Risk
- **Files:** `group_repository.dart:27-30`, `friendship_repository.dart:189`
- **Status:** [x] LOW RISK — values come from auth system/DB, not user input. PostgREST filters, not raw SQL.
- **Fix:** No change needed

### 10. Monolithic Screens
- `ExpenseEntryWidget` (854 LOC), `SettingScreen` (550 LOC), `GroupDetailEditScreen` (489 LOC)
- **Status:** [ ] TODO
- **Fix:** Extract sub-widgets

---

## Medium Priority Issues

### 11. Hardcoded Strings in Helper
- **File:** `lib/helper/helper.dart`
- **Status:** [x] DONE (Today/Yesterday localized; € and date format remain — tied to currency/locale system)
- Added `dateToday`/`dateYesterday` keys to en/de ARB files, updated `formatDate()` + call sites

### 12. Missing Channel Disposal on Failure
- **File:** `lib/helper/realtime_mixin.dart:69-86`
- **Status:** [x] DONE (fixed with #1 — failed channels are removed before retry)

### 13. Timer Lifecycle in FriendshipListNotifier
- **File:** `lib/pages/friends/provider/friendship_list.dart:58-62`
- **Status:** [x] ALREADY SAFE — timer cancelled in `ref.onDispose`, reload checks `ref.mounted`

### 14. Permissive Linting
- **File:** `analysis_options.yaml`
- **Status:** [x] DONE
- Added `avoid_print`, `avoid_empty_else`, `prefer_final_fields`, `unnecessary_statements`, `avoid_returning_null_for_future`; excluded generated files

### 15. `intl: any` in pubspec.yaml
- **Status:** [x] DONE
- **Fix:** Pinned to `^0.20.2`

---

## Strengths

- Clean feature-based modular structure
- RealtimeNotifierMixin centralizes channel management
- Good Riverpod patterns (AsyncValue.guard, disposal, ref.mounted)
- Well-curated widget library (13 reusable components)
- Localization infrastructure with ~500+ keys
- Optimistic updates in ExpenseList and GroupList
