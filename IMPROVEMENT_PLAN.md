# Deun — Repository Improvement Plan

Full-repo audit covering correctness, security, performance, code quality, usability, testing, and infrastructure. Findings reference `file:line` in the current state of the repo (~16k lines of hand-written Dart across 104 files).

---

## Phase 0 — Critical Correctness & Data Integrity (fix first)

These can produce **wrong balances or corrupted data** in a money-splitting app.

### 0.1 Floating-point currency math
- **Where:** `lib/pages/groups/data/group_model.dart:70-196`, `lib/pages/expenses/data/expense_model.dart:40-60`, `lib/pages/expenses/data/expense_repository.dart:113-217`
- **Problem:** All monetary values are `double`. Accumulation happens without consistent rounding (e.g. `group_model.dart:78` adds totals unrounded), and the "settled" check compares against a `0.01` threshold that floating-point drift can break. The simplified-settlement algorithm (`group_model.dart:111-196`) is a greedy while-loop whose termination depends on values reaching ~zero — rounding drift can cause wrong settlement suggestions.
- **Plan:**
  1. ✅ DONE — `roundCurrency()` applied at arithmetic boundaries in `group_model.dart` (balances rounded on load, totals accumulate rounded).
  2. Medium term (open): migrate to integer cents (or the `decimal` package) in models + `NUMERIC` columns in Postgres.
  3. ✅ DONE — defensive iteration guard added to the settlement while-loop (analysis showed each iteration removes ≥1 entry, so it already terminated; guard protects against future regressions). Closes QUESTIONS.md Q69.
  4. ✅ DONE — 17 unit tests in `test/model/group_settlement_test.dart` covering both calculation modes: equal/unequal splits, creditor/debtor perspectives, unrounded DB thirds, one-cent differences, drift-free accumulation. The methods were refactored to take `currentUserEmail` as a parameter so the real code is testable (previously they read the supabase global directly).

### 0.2 Multi-step DB writes are not atomic
- **Where:** `lib/pages/expenses/data/expense_repository.dart:74-222` (`saveAll` = upsert expense → delete entries → insert entries → delete shares → insert shares → RPC → notify), `lib/pages/groups/data/group_repository.dart:72-142` (upsert group → create guests → delete members → insert members → RPC)
- **Problem:** A failure mid-sequence leaves orphaned expenses/shares or a group without members. Guest users created in the loop (`group_repository.dart:89-127`) are never rolled back or cleaned up on group deletion.
- **Plan:** Move each `saveAll` into a single Postgres RPC (`plpgsql` function runs in one transaction). Add cascade cleanup for guest users. Add integration tests simulating partial failure.

### 0.3 Split validation tolerance is too loose
- **Where:** `lib/pages/expenses/presentation/expense_entry_widget.dart:470-486`
- **Problem:** `(sum - _entryTotal).abs() < 0.01 * _enabledMembers.length.clamp(1, 10)` lets a 10-member split be off by up to €0.10 and still pass. Zero-amount entries are also accepted (`expense_repository.dart:122-124`), creating meaningless shares.
- **Plan:** ✅ DONE — amount mode now requires cent-exact equality (`< 0.005`), percentage mode epsilon tightened to 0.01. Auto-distribution keeps full precision so this only flags genuinely inconsistent user-typed splits. `amount > 0` validators added to both amount fields with a new localized message (`expenseEntryAmountValidationZero` in en + de).

### 0.4 PayBack correctness
- ~~"paid back notification sent regardless of RPC outcome"~~ — **finding was wrong**: a failed retry throws out of `payBack()` before the notification line, and callers already show `payBackError`. The remaining gap is server-side atomicity (`pay_back` succeeding but `update_group_member_shares` failing leaves stale balances) — that's QUESTIONS.md Q70 and belongs to the Phase 0.2 RPC work.
- ✅ FIXED (new bug found during this work) — `payBackAll()` passed the **cross-group total** to every group's `pay_back` RPC instead of the per-group amount (the computed `groupAmount` was only used in a threshold check), and also recorded pay-backs in groups where the *friend* owed the *user*. Now settles only groups where the user owes, with the exact per-group amount.
- ✅ FIXED — unhandled PayPal `launchUrl` throw in `group_detail_payment.dart` (same pattern as the friend-list one).

### 0.5 Email comparisons are case-sensitive (deprioritized)
- **Where:** `lib/pages/friends/data/friendship_model.dart`, `lib/pages/groups/data/group_model.dart`
- **Assessment:** Supabase Auth normalizes emails to lowercase and all user rows are created from `session.user.email`, so in practice all stored emails are already lowercase. A client-side normalization sweep would touch every email-keyed map with little real-world payoff. Better fix: enforce `lower(email)` via a DB constraint/trigger when doing the Phase 0.2 migration work.

---

## Phase 1 — Security & Privacy

### 1.1 QR/share fallback exposes raw email addresses
- ✅ DONE — email fallback removed entirely. The "My Code" tab now shows a loading/retry state until the username+code link resolves; the scanner's copy-link button guards against a missing link. Accept-side still honors old email links for backward compatibility.

### 1.2 HTML injection in contact form
- ✅ DONE — all contact-form fields HTML-escaped before being embedded in the email body. `sendContactMail` also now rethrows failures so the contact form's error snackbar actually fires (previously errors were swallowed and success was always shown).

### 1.3 Secrets & config hygiene
- ✅ DONE — VAPID key and Google OAuth client IDs moved to `constants.dart` as `String.fromEnvironment` with defaults (rotatable via `FCM_VAPID_KEY`, `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID` defines).
- ✅ DONE — CI now writes the env file from masked env vars instead of inline `echo` interpolation.
- OPEN — access token passed into UI in `lib/pages/auth/update_password.dart:18` → let the SDK manage the session internally.

### 1.4 Web & Android hardening
- ~~CSP/X-Frame-Options meta tags~~ — **not feasible as described**: browsers ignore `frame-ancestors` and `X-Frame-Options` in `<meta>` tags, and GitHub Pages cannot send custom response headers. Real fix requires fronting the site with a CDN (e.g. Cloudflare) that injects headers.
- OPEN — No Android obfuscation → add `--obfuscate --split-debug-info` to release builds.
- ✅ DONE — stale `com.example.deun` client entry removed from `android/app/google-services.json`.
- OPEN — deep-link fragment validation (`lib/navigation.dart`) could be extended to more parameter types (groups/friends/static routes are already allowlisted).

### 1.5 RLS policies not version-controlled
- `supabase/` contains only `config.toml`. Export schema, RLS policies, RPCs, and indexes into `supabase/migrations/` so they can be code-reviewed. Check FK cascades for account deletion, and verify the `delete-user-account` edge function.

---

## Phase 2 — Stability & Error Handling

### 2.1 Auth flows swallow errors
- ✅ DONE — `lib/auth_gate.dart:78-81`: `.catchError((_) => [null, null])` hid *any* network/server error. Now logged; full retry UI still open.
- ~~`lib/pages/auth/sign_in.dart`: SupaSocialsAuth/SupaEmailAuth no error callbacks~~ — **finding was wrong**: the supabase_auth_ui widgets show a default error snackbar when `onError` is null. No action needed.
- ✅ DONE — `lib/pages/auth/onboarding_screen.dart:55-66`: every exception mapped to "username taken". Now differentiates `PostgrestException` from other errors.
- `lib/pages/auth/onboarding_screen.dart:70`: nested `MaterialApp` — **cannot simply be removed**: AuthGate is the app root and every top-level screen (login, splash, onboarding, navigation) builds its own `MaterialApp`. Proper fix is hoisting a single shared `MaterialApp` above AuthGate (structural refactor).

### 2.2 BuildContext / ref used across async gaps
- `lib/navigation.dart:393-408` (`_handleMessage`): context used after `await` with no mounted check.
- `lib/navigation.dart:302-313` (`_initUserLocale`): `ref.read` after await without mounted check.
- `lib/navigation.dart:349` (`_handlePush`): `void async` — exceptions vanish; also `currentUser!.id` at lines 357/383 can throw on expired session.
- `lib/pages/friends/presentation/friend_add_page.dart:82-94`, `friend_accept_page.dart:83-100`: inconsistent mounted checks.
- **Plan:** sweep all async methods; enforce via lints (`use_build_context_synchronously` is in flutter_lints — verify it isn't being ignored, and add `unawaited_futures`, `discarded_futures`).

### 2.3 Memory leaks
- `lib/widgets/search_view.dart:18`: `TextEditingController` never disposed (also adds a listener). Add `dispose()`.
- Audit other StatefulWidgets for the same pattern.

### 2.4 Fire-and-forget Supabase calls
- `lib/helper/helper.dart:103-149`: notification sends use `.then(onError: debugPrint)` — failures are dropped silently. Centralize notification sending in a service with retry + consistent error reporting.

### 2.5 Realtime mixin edge cases
- `lib/helper/realtime_mixin.dart:80` (duplicate-channel race on rapid resubscribe), `:119-122` (`_ref?.read` in callbacks may hit a disposed provider). Add atomic check+add and `ref.mounted` guards.

### 2.6 Crash reporting
- No Crashlytics/Sentry anywhere. Add one — most issues above currently fail silently in production.

---

## Phase 3 — Performance

### 3.1 Realtime events trigger full refetches
- OPEN — `lib/pages/expenses/provider/expense_list.dart`: each realtime event refetches the expense via `fetchDetail` (the `expense_update_checker` payload doesn't carry full expense data, so a payload-based patch needs schema work).
- ~~group_detail reloads on any change without group filtering~~ — **finding was wrong**: the channel already uses `PostgresChangeFilter(eq, 'group_id', groupId)`.
- ~~friendship_list over-fetches on every group change~~ — **mostly mitigated already**: reloads are debounced (2s) and the three fetches run in parallel with `keepAlive`. Remaining improvement is server-side aggregation of shared amounts.
- OPEN — unify the realtime-update strategies (refetch vs. optimistic) into one documented pattern.

### 3.2 Pagination state bugs
- ✅ DONE (corrected scope) — `reload()` already derived `_hasMore` correctly; the real bugs were `loadMoreEntries` advancing `_offset` even when the fetch failed (skipping a page on retry) and appending without dedup when realtime inserts shift pages. Both fixed.

### 3.3 Statistics queries duplicated
- ✅ DONE — new shared `monthExpensesProvider(groupId, monthStart, monthEnd)`; member-totals, category-totals and category-details all derive from it, so opening a month detail fires one query instead of three.
- OPEN — `group_statistics_page.dart`: bar groups rebuilt in `build()`; memoize or wrap chart in `RepaintBoundary`.

### 3.4 Client-side computation that belongs server-side
- `lib/pages/groups/data/group_model.dart:59-68`: shares summary recomputed on every fetch; `lib/pages/expenses/data/expense_model.dart:43-60`: per-member share statistic recomputed for every expense in the list (O(entries×members)). Compute in SQL views/RPCs or cache.

### 3.5 Widget-level wins
- `lib/widgets/card_list_view_builder.dart:93-122`: no item keys → all cards rebuild on any change; add `ValueKey(id)`.
- `ref.read(...).offset` inside `build()` at `lib/pages/groups/presentation/group_detail_list.dart:47` — rebuild-unsafe; use `watch` or restructure.
- Missing `const` constructors throughout (e.g. `group_share_widget.dart:20`); enable `prefer_const_constructors` lint and fix.
- Expense search `ilike('%filter%')` per keystroke (`expense_repository.dart:18`) — add debounce + a trigram/FTS index.

---

## Phase 4 — Usability / UX

### 4.1 Error & empty states
- ✅ DONE (statistics) — raw `e.toString()` displays in `group_statistics_page.dart` and `month_detail_bottom_sheet.dart` replaced with localized message + retry button on the main page.
- OPEN — `friend_accept_page.dart:74-80` still surfaces raw PG errors.
- Receipt scanner (`receipt_scanner_sheet.dart:47-66`): on parse failure the photo and OCR result are discarded with a generic error — add retry and a "continue manually with OCR text pre-filled" fallback, plus a timeout on the parser call.

### 4.2 Destructive-action confirmations
- Group deletion has no confirmation (and no "this deletes N expenses" impact warning).
- Account deletion (`lib/pages/settings/setting.dart:191-199`) is one tap → require typed confirmation.

### 4.3 Modal & navigation traps
- `lib/widgets/modal_bottom_sheet_page.dart:10-17`: `isDismissible: false, enableDrag: false` traps users in modals — allow standard dismissal (with an "unsaved changes?" guard where needed).
- Password-reset deep links: `auth_gate.dart:48-50` handles the auth event but there's no route for opening reset links cold — add one.

### 4.4 Feedback & affordances
- Friend request button (`friend_add_page.dart:82-94`) doesn't disable while in flight; success snackbar fires before refresh completes.
- Contacts permission flow (`friend_add_notifier.dart:130-136`, `contact_suggestion_list.dart:53-58`): on Android a re-request silently fails — detect permanent denial and open app settings directly.
- Ambiguous-username search result (`friend_add_notifier.dart:183-192`) should hint the `username#code` format.

### 4.5 Localization & formatting
- ✅ DONE — the en_US-hardcoded `toCurrency`/`toNumber` helpers are removed. All currency display now goes through the locale-aware l10n `toCurrency`; the zero-checks that abused string formatting (`toNumber(x) == '0.00'`) are numeric comparisons now.
- `app_de.arb` (255 keys) covers only ~half of `app_en.arb` (529 keys) → complete German translations.
- Hardcoded strings: "Page not found" (`navigation.dart:295-297`), literal `€`/`%` symbols in expense widgets.

### 4.6 Accessibility
- Icon buttons lack semantic labels throughout (friends pages, QR page). Add `Semantics`/tooltips; audit contrast.

---

## Phase 5 — Testing (current coverage ≈ 8%)

Existing tests cover receipt parsing, model JSON loading, and helpers — **zero tests for money math, repositories, or any of the 7+ notifiers**.

Priority order:
1. **Settlement algorithm** (`calculateGroupSharesSummarySimplified`) — table-driven tests incl. rounding edge cases.
2. **Share/percentage math** in `Expense`/`ExpenseEntry`.
3. **Repositories** (mock Supabase client): saveAll happy path + partial failures.
4. **Notifiers**: pagination reset, realtime event handling, optimistic updates (Riverpod `ProviderContainer` tests).
5. **Widget tests** for the expense form's split validation.
6. One integration test: create group → add expense → split → settle.

---

## Phase 6 — CI/CD & Tooling

- **CI runs no tests** (`deploy_deun_web_page.yml` only does `flutter analyze` then deploys to prod). Add `flutter test` as a gate.
- Add a **PR workflow** (analyze + test on pull_request) — currently nothing runs before merge.
- Cache `~/.pub-cache` and the Flutter SDK between runs.
- Strengthen `analysis_options.yaml` (currently flutter_lints + only 4 extra rules). Add at minimum: `prefer_const_constructors`, `prefer_const_constructors_in_immutables`, `unawaited_futures`, `discarded_futures`, `close_sinks`, `always_declare_return_types`, `cancel_subscriptions`.
- Remove dead code: commented-out blocks in `navigation.dart:545-558`.

---

## Phase 7 — Dependencies & Housekeeping

| Dependency | Finding | Action |
|---|---|---|
| `grouped_list` | No usage found in `lib/` | Remove |
| `webview_flutter` (+web) | Only `privacy_policy.dart` | Consider `url_launcher` instead; drop two deps |
| `universal_html` | One call in `main.dart` (history.replaceState) | Replace with conditional import / smaller shim |
| `equatable` | Only `statistics_models.dart` | Fold into freezed (already a dep) |
| `google_mobile_ads` | Verify production ad-unit IDs in `constants.dart` are not the test IDs | Verify before release |

Also: expand `README.md` (currently 3 lines) with setup/architecture; keep `QUESTIONS.md` (excellent issue log) in sync as items here get fixed.

---

## Suggested execution order (rough effort)

| Order | Work | Effort |
|---|---|---|
| 1 | ✅ DONE — Quick wins: SearchView dispose, mounted checks + async-gap guards in navigation.dart, lint rules (`unawaited_futures`, `use_build_context_synchronously`, const lints + 104 auto-fixes), PayPal launch try/catch, onboarding error differentiation, VAPID key to constants (env-overridable), CI test gate + PR workflow + pinned Flutter 3.41.9 | ~1 day |
| 2 | ✅ DONE — Phase 0 money math: rounding at boundaries, settlement iteration guard + 17 tests, cent-exact split validation, amount>0 validators, payBackAll per-group amount bug fix | 2–4 days |
| 3 | ✅ DONE — Phase 1 security: QR email fallback removed, contact-form HTML escaping + error propagation, OAuth IDs/VAPID env-overridable, stale Firebase client removed (headers infeasible on GitHub Pages — needs CDN) | 1–2 days |
| 4 | Phase 0.2 transactional RPCs + migrations in repo | 2–3 days |
| 5 | ✅ MOSTLY DONE — Phase 3 performance: stats query dedup via shared provider, pagination offset/dedup fixes, statistics error states localized with retry (group_detail filtering + friendship debounce were already in place) | 2–3 days |
| 6 | Phase 4 UX polish + de translations + locale-aware currency | 2–3 days |
| 7 | Phase 5 test buildout to ~60% on critical paths | ongoing |
