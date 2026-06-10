# Deun — Repository Improvement Plan

Full-repo audit covering correctness, security, performance, code quality, usability, testing, and infrastructure. Findings reference `file:line` in the current state of the repo (~16k lines of hand-written Dart across 104 files).

---

## Phase 0 — Critical Correctness & Data Integrity (fix first)

These can produce **wrong balances or corrupted data** in a money-splitting app.

### 0.1 Floating-point currency math
- **Where:** `lib/pages/groups/data/group_model.dart:70-196`, `lib/pages/expenses/data/expense_model.dart:40-60`, `lib/pages/expenses/data/expense_repository.dart:113-217`
- **Problem:** All monetary values are `double`. Accumulation happens without consistent rounding (e.g. `group_model.dart:78` adds totals unrounded), and the "settled" check compares against a `0.01` threshold that floating-point drift can break. The simplified-settlement algorithm (`group_model.dart:111-196`) is a greedy while-loop whose termination depends on values reaching ~zero — rounding drift can cause wrong settlement suggestions.
- **Plan:**
  1. Short term: apply `roundCurrency()` at *every* arithmetic boundary, and compare with an explicit epsilon.
  2. Medium term: migrate to integer cents (or the `decimal` package) in models + `NUMERIC` columns in Postgres.
  3. Add an iteration guard to the settlement while-loop.
  4. Add exhaustive unit tests: 3-way split of €0.01, 7-way of €1.00, 40/30/30 splits, circular debt, amounts differing by €0.01.

### 0.2 Multi-step DB writes are not atomic
- **Where:** `lib/pages/expenses/data/expense_repository.dart:74-222` (`saveAll` = upsert expense → delete entries → insert entries → delete shares → insert shares → RPC → notify), `lib/pages/groups/data/group_repository.dart:72-142` (upsert group → create guests → delete members → insert members → RPC)
- **Problem:** A failure mid-sequence leaves orphaned expenses/shares or a group without members. Guest users created in the loop (`group_repository.dart:89-127`) are never rolled back or cleaned up on group deletion.
- **Plan:** Move each `saveAll` into a single Postgres RPC (`plpgsql` function runs in one transaction). Add cascade cleanup for guest users. Add integration tests simulating partial failure.

### 0.3 Split validation tolerance is too loose
- **Where:** `lib/pages/expenses/presentation/expense_entry_widget.dart:470-486`
- **Problem:** `(sum - _entryTotal).abs() < 0.01 * _enabledMembers.length.clamp(1, 10)` lets a 10-member split be off by up to €0.10 and still pass. Zero-amount entries are also accepted (`expense_repository.dart:122-124`), creating meaningless shares.
- **Plan:** Exact validation per split mode (amount mode: rounded sum must equal total; percentage mode: sum == 100.0 within tiny epsilon), plus an `amount > 0` validator.

### 0.4 PayBack RPC failure is invisible to the user
- **Where:** `lib/pages/groups/data/group_repository.dart:146-163`
- **Problem:** `update_group_member_shares` RPC retries once, but the "paid back" notification is sent regardless of outcome — balances can silently stay wrong while the user is told it succeeded.
- **Plan:** Surface RPC failure to the UI (snackbar + retain dialog), only notify after success.

### 0.5 Email comparisons are case-sensitive
- **Where:** `lib/pages/friends/data/friendship_model.dart`, `lib/pages/groups/data/group_model.dart`
- **Problem:** `User@Email.com` won't match `user@email.com` in friendship/membership checks.
- **Plan:** Normalize to lowercase at model boundaries (and add a DB constraint/normalization).

---

## Phase 1 — Security & Privacy

### 1.1 QR/share fallback exposes raw email addresses
- **Where:** `lib/pages/friends/presentation/friend_qr_page.dart:49`
- The username+code link (lines 60-63) is good, but the fallback encodes the user's email into the QR/shared URL. Remove the email fallback; require username completion before QR is available.

### 1.2 HTML injection in contact form
- **Where:** `lib/helper/helper.dart:246-250`
- User input is interpolated directly into an HTML email body. HTML-escape all fields.

### 1.3 Secrets & config hygiene
- VAPID key hardcoded in `lib/navigation.dart:351-352`; OAuth client IDs in `lib/pages/auth/sign_in.dart:54-55` → move to `--dart-define` env config.
- CI echoes `SUPABASE_URL`/`SUPABASE_ANON_KEY` via shell `echo` in `.github/workflows/deploy_deun_web_page.yml:45-46` → write via masked mechanism.
- Access token passed into UI in `lib/pages/auth/update_password.dart:18` → let the SDK manage the session internally.

### 1.4 Web & Android hardening
- No CSP / `X-Frame-Options` in `web/index.html` → add security headers.
- No Android obfuscation → add `--obfuscate --split-debug-info` to release builds.
- Stale `com.example.deun` client entry in `android/app/google-services.json` → remove.
- Deep-link fragment validation (`lib/navigation.dart:420-462`) validates groups/friends but not other IDs and doesn't sanitize query params → whitelist routes.

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
- `lib/pages/expenses/provider/expense_list.dart:26-61`: each realtime event refetches the expense via `fetchDetail` — N+1 under bulk updates. Build the model from `payload.newRecord` where possible.
- `lib/pages/groups/provider/group_detail.dart:22-23`: reloads the whole group detail on *any* change without checking `payload.newRecord['group_id'] == groupId`.
- `lib/pages/friends/provider/friendship_list.dart`: reloads all friendships and recalculates shared amounts across all groups on any group change.
- **Plan:** filter events by ID, prefer payload-based patches, debounce bursts. Also: unify the three different realtime-update strategies (refetch vs. optimistic vs. hybrid) into one documented pattern.

### 3.2 Pagination state bugs
- `lib/pages/expenses/provider/expense_list.dart:70-76`: `_offset`/`_hasMore` are mutable fields outside Riverpod state; `reload()` doesn't reset them → after refresh, pagination can be stuck. Move pagination into the notifier state and reset on reload.

### 3.3 Statistics queries duplicated
- `lib/pages/statistics/provider/statistics_notifiers.dart:64,113,150`: three notifiers each call `ExpenseRepository.fetchRange` for the same month → 3 identical queries when opening details. Introduce one shared month-expenses provider the others derive from.
- `lib/pages/statistics/group_statistics_page.dart:146-163`: bar groups rebuilt in `build()`; memoize or wrap chart in `RepaintBoundary`.

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
- Raw exceptions shown to users: `group_statistics_page.dart:57-58` (`Text(e.toString())`), `friend_accept_page.dart:74-80` (raw PG errors). Map to localized, actionable messages with a retry button.
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
- **Currency format hardcoded to `en_US`** (`lib/helper/helper.dart:33-41`): German users see `€1,234.56` instead of `1.234,56 €`. Use the active locale. This is the single most visible i18n bug.
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
| 2 | Phase 0 money math + validation + settlement tests | 2–4 days |
| 3 | Phase 1 security items (QR email, HTML escape, env config, headers) | 1–2 days |
| 4 | Phase 0.2 transactional RPCs + migrations in repo | 2–3 days |
| 5 | Phase 3 performance (realtime filtering, pagination state, stats dedup) | 2–3 days |
| 6 | Phase 4 UX polish + de translations + locale-aware currency | 2–3 days |
| 7 | Phase 5 test buildout to ~60% on critical paths | ongoing |
