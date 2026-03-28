# QUESTIONS.md

## Project Understanding Summary

**Deun** ("Simply Split Fairly") is a Flutter cross-platform expense splitting app (v1.0.1+11). Users create groups, add expenses with multiple entries and percentage-based shares, and the app calculates who owes whom. Features friendship tracking, real-time updates via Supabase channels, push notifications via Firebase, social login (Google/GitHub/Apple), ad monetization via Google AdMob, and statistics with bar/pie charts.

**Stack:** Flutter 3.x (Dart >=3.8.0) + Supabase (PostgreSQL, Auth, Realtime, Edge Functions) + Firebase (Cloud Messaging) + Riverpod 3.x with code generation + GoRouter 16.x (routing) + Freezed (immutable models).

**High-risk areas identified:**
- Zero test coverage for a financial app
- Floating-point arithmetic for currency calculations
- Multi-step database operations without transaction wrapping
- Hardcoded credentials in source code (OAuth IDs, VAPID key, Firebase keys)
- CI/CD prints secrets to GitHub Actions logs
- No input validation/sanitization in several critical paths
- Real-time subscription over-fetching
- No ProGuard/R8 obfuscation for Android release builds
- No crash/error reporting in production

---

## How to Answer

For each question, mark your answer with one of these tags:

- `verified` -- intended behavior, no change needed
- `partial` -- partially correct, needs refinement
- `blocked` -- can't answer yet, depends on something else
- `deferred` -- known issue, will address later
- `out-of-scope` -- not relevant or not worth addressing
- `caveat` -- answer with caveats or conditions
- `bug` -- confirmed bug, needs fixing
- `approved improvement` -- agree this should be improved

---

## Questions

---

### 1. Product & Intended Behavior

#### Q1. Is equal-only expense splitting intentional?
- **Where:** `lib/pages/expenses/data/expense_model.dart` ~line 204
- **Why this matters:** Shares are calculated as `100 / expenseEntryShares.length`, meaning every member always pays equally per entry. Users cannot do 60/40 or custom percentage splits.
- **Question:** Is equal-only splitting the intended product behavior, or should unequal sharing be supported?

#### Q2. What should happen when a user deletes their account while having shared expenses?
- **Where:** `lib/pages/settings/setting.dart`
- **Why this matters:** Account deletion calls a Supabase function but there's no cascade delete confirmation or handling of shared financial data. Other users' balances could become orphaned.
- **Question:** Should account deletion be blocked if the user has unsettled balances? Should other group members be notified?

#### Q3. Is the "paid back" expense type clearly distinguished from regular expenses?
- **Where:** `lib/pages/expenses/data/expense_model.dart` (`isPaidBackRow`)
- **Why this matters:** The field marks an expense as a payment record, but from the data model alone it's unclear how this interacts with balance calculations and display.
- **Question:** Is the distinction between payments and regular expenses clear enough for users? Are there edge cases where a payment could be confused with an expense?

#### Q4. Should expenses with zero entries be allowed?
- **Where:** `lib/pages/expenses/presentation/expense_detail.dart`
- **Why this matters:** Form validation checks individual fields but doesn't enforce a minimum number of expense entries. A user could submit an expense with 0 entries and amount 0.
- **Question:** Should the app prevent submitting expenses with no entries?

#### Q5. Should the category detector be user-customizable?
- **Where:** `lib/pages/expenses/data/expense_category.dart` (CategoryDetector, 380+ hardcoded keywords)
- **Why this matters:** Auto-detection uses a fixed keyword list with exact substring matching (no fuzzy matching, no scoring). Users can't teach it new keywords or correct misclassifications. First match wins with no confidence level.
- **Question:** Is the hardcoded keyword approach sufficient, or should users be able to add custom keywords? Should the detector support fuzzy matching or a scoring system?

---

### 2. Architecture

#### Q6. Why does the friendship list reload on every group change?
- **Where:** `lib/pages/friends/provider/friendship_list.dart`
- **Why this matters:** `FriendshipListNotifier` subscribes to `group_update_checker` and reloads ALL friendships on any group change. This causes unnecessary database queries and UI re-renders.
- **Question:** Is this intentional because friendship balances depend on group data? Could this be optimized to only reload when relevant groups change?

#### Q7. Is the broad provider invalidation on app resume intentional?
- **Where:** `lib/navigation.dart` (~lines 66-70)
- **Why this matters:** When the app resumes from background, ALL providers (groups, expenses, friendships) are invalidated. This could cause UI flicker and unnecessary network requests.
- **Question:** Should this be selective (only invalidate if data is stale), or is the full refresh needed for correctness?

#### Q8. Should pagination state live inside or outside the AsyncValue?
- **Where:** `lib/pages/expenses/provider/expense_list.dart` (`_offset`, `_hasMore` as mutable fields)
- **Why this matters:** Mutable fields outside Riverpod's state model break the reactivity pattern. The UI cannot observe `_hasMore` to show/hide a "load more" indicator. Additionally, `_hasMore` is not reset on `reload()`, potentially preventing loading after a refresh.
- **Question:** Should pagination state be part of the notifier's state so the UI can react to it?

#### Q9. Should real-time update patterns be consistent across all providers?
- **Where:** `lib/pages/groups/provider/group_detail.dart` vs `lib/pages/expenses/provider/expense_list.dart`
- **Why this matters:** `GroupDetailNotifier` does a full refetch on any change (simple but inefficient), while `ExpenseListNotifier` does optimistic insert/update/delete (complex but efficient). `GroupListNotifier` uses a hybrid approach. This inconsistency makes the codebase harder to maintain and reason about.
- **Question:** Should all providers follow one consistent update pattern? Which approach is preferred?

---

### 3. Code Structure & Boundaries

#### Q10. Should notification sending logic be extracted from helper.dart?
- **Where:** `lib/helper/helper.dart` (~lines 91-216)
- **Why this matters:** `helper.dart` mixes utility functions (date formatting, currency) with complex business logic (notification construction, Cloud Function invocation). This makes it hard to test and reason about.
- **Question:** Should notification logic live in its own service/module?

#### Q11. Are the global ScaffoldMessenger keys necessary?
- **Where:** `lib/main.dart` (multiple global keys)
- **Why this matters:** Multiple global keys for per-screen snackbar control is unusual. It works but couples screens to global state.
- **Question:** Is this pattern intentional for controlling snackbar display per screen, or is there a cleaner approach?

#### Q12. Should data access logic be extracted from model classes?
- **Where:** `lib/pages/groups/data/group_model.dart`, `lib/pages/expenses/data/expense_model.dart`, `lib/pages/friends/data/friendship_model.dart`
- **Why this matters:** Static methods like `fetchData()`, `saveAll()`, `delete()` on model classes mix data access with domain logic (violates SRP). `UserRepository` already follows the repository pattern but other models don't.
- **Question:** Should all data access be moved to repository classes, consistent with the `UserRepository` pattern?

---

### 4. API Design & Data Access

#### Q13. Should the app validate that fetched data belongs to the requesting user?
- **Where:** Multiple model files (group_model, expense_model, friendship_model)
- **Why this matters:** The app relies entirely on Supabase Row Level Security (RLS) for authorization. Client-side code doesn't verify ownership before delete/edit operations.
- **Question:** Is RLS sufficient, or should the client also validate ownership as a defense-in-depth measure?

#### Q14. Is email the right identifier for user lookups?
- **Where:** Multiple files using `supabase.auth.currentUser!.email ?? ''`
- **Why this matters:** If email is null, this queries with an empty string. Also, `.single()` will throw if multiple users share an email. Using `!` on `currentUser` will crash if the user is not authenticated.
- **Question:** Should user lookups use the Supabase user ID instead of email? Is email uniqueness enforced at the database level?

#### Q15. Should multi-step database operations use transactions?
- **Where:** `lib/pages/expenses/data/expense_model.dart` saveAll() (~lines 134-217)
- **Why this matters:** Expense creation involves: upsert expense -> delete old entries -> insert new entries -> insert shares -> call RPC `update_group_member_shares` -> send notification. If any step fails mid-way, the database is left in an inconsistent state (e.g., expense exists but entries are deleted).
- **Question:** Should these operations be wrapped in a Supabase transaction or RPC to ensure atomicity?

---

### 5. Data & Persistence

#### Q16. Are floating-point precision errors acceptable for currency calculations?
- **Where:** All monetary values use `double` throughout the codebase
- **Why this matters:** `double` cannot represent values like 0.10 exactly. Over many transactions, rounding errors can accumulate and cause incorrect balances. The 0.01 threshold for "settled" status could misclassify edge cases.
- **Question:** Should the app use integer cents (e.g., 1050 for 10.50) or a `Decimal` package to avoid floating-point errors?

#### Q17. Is IBAN and PayPal data stored securely?
- **Where:** User table (via `user_model.dart` - `paypalMe`, `iban` fields)
- **Why this matters:** IBAN and PayPal handles appear to be stored as plaintext in the database. A database breach would expose financial identifiers.
- **Question:** Should these be encrypted at rest, or is Supabase's built-in encryption sufficient?

#### Q18. What threshold determines if a group balance is "settled"?
- **Where:** `lib/pages/groups/data/group_model.dart` and provider filter logic
- **Why this matters:** The filter uses 0.01/-0.01 thresholds. Values between -0.01 and 0.01 are treated as zero. But floating-point errors could produce values like 0.005 that are misclassified. The threshold is also not currency-aware (0.01 EUR vs 1 JPY).
- **Question:** Is 0.01 the right threshold? Should it be configurable or derived from the currency's smallest unit?

---

### 6. Security

#### Q19. Should OAuth client IDs be moved to environment variables?
- **Where:** `lib/pages/auth/sign_in.dart` lines 53-56 (Google web/iOS client IDs hardcoded)
- **Why this matters:** Hardcoded OAuth credentials in source code are visible in the repository. While client IDs are semi-public, best practice is to keep them in environment config for rotation flexibility.
- **Question:** Should these be moved to `.env_flutter/` like the Supabase keys?

#### Q20. Should the VAPID key be moved out of source code?
- **Where:** `lib/navigation.dart` (~line 339)
- **Why this matters:** The Firebase VAPID key is hardcoded in plain text. If the key needs rotation, it requires a code change and redeployment.
- **Question:** Should this be an environment variable?

#### Q21. Is the deep link fragment validated before routing?
- **Where:** `lib/navigation.dart` (~lines 398-402)
- **Why this matters:** `GoRouter.of(context).go(uri.fragment)` passes the URI fragment directly to the router without validation. A crafted deep link could navigate to arbitrary routes.
- **Question:** Should deep link fragments be validated against a whitelist of allowed routes?

#### Q22. Is the contact email HTML injection risk acceptable?
- **Where:** `lib/helper/helper.dart` `sendContactMail()` function
- **Why this matters:** The function constructs HTML via string concatenation from `contactInfo` values. If a user enters `<script>` tags in the contact form, they'd be included in the email HTML.
- **Question:** Should contact form values be HTML-escaped before constructing the email body?

#### Q23. Should email comparisons be case-insensitive?
- **Where:** `lib/pages/friends/data/friendship_model.dart` and multiple other files
- **Why this matters:** Email comparisons use `==` without `.toLowerCase()`. If a user registers with "User@Email.com" and a friend request targets "user@email.com", the comparison fails.
- **Question:** Should all email comparisons normalize to lowercase?

#### Q24. Does the CI/CD pipeline leak secrets?
- **Where:** `.github/workflows/deploy_deun_web_page.yml` line 46
- **Why this matters:** The workflow contains `echo "$(<.env_flutter/development.env )"` which prints Supabase URL and anon key to the GitHub Actions console log. These logs are visible to anyone with repo access.
- **Question:** Should this echo line be removed? Are the exposed keys still valid and in need of rotation?

#### Q25. Should Android release builds use code obfuscation?
- **Where:** `android/app/` -- no `proguard-rules.pro` file exists
- **Why this matters:** Without ProGuard/R8 rules, the release APK ships with readable code. This makes it easier to reverse-engineer business logic, extract API keys, and find vulnerabilities.
- **Question:** Should ProGuard/R8 obfuscation rules be added? Should `--obfuscate --split-debug-info` flags be used in release builds?

#### Q26. Should web builds include security headers?
- **Where:** `web/index.html`
- **Why this matters:** No Content-Security-Policy, X-Frame-Options, or other security headers are set. The web app could be embedded in iframes (clickjacking) or load unauthorized scripts.
- **Question:** Should CSP and other security headers be configured for the web deployment?

---

### 7. Performance

#### Q27. Is the simplified expense algorithm correct for all edge cases?
- **Where:** `lib/pages/groups/data/group_model.dart` (~lines 104-189)
- **Why this matters:** The greedy algorithm matches smallest debtor with largest creditor. Complex nested conditionals with floating-point comparisons could produce incorrect results in edge cases (e.g., values very close to each other).
- **Question:** Has this algorithm been validated with test cases? Are there known scenarios where it produces incorrect results?

#### Q28. Is friendship share amount calculation performant at scale?
- **Where:** `lib/pages/friends/data/friendship_model.dart`
- **Why this matters:** `shareAmount` is recalculated by iterating ALL groups on every fetch. With many groups and expenses, this could be slow. Every group update triggers a full recalculation.
- **Question:** Should share amounts be cached or computed server-side?

#### Q29. Is the 220 skipped frames at startup acceptable?
- **Where:** Observed during app launch on physical device (Nothing Phone A065)
- **Why this matters:** The app skips ~220 frames (~1.8s delay) during startup, likely from synchronous initialization of Firebase, Supabase, Google Mobile Ads, and real-time subscriptions all happening before the first frame.
- **Question:** Should heavy initialization be deferred or moved to isolates to improve startup performance?

#### Q30. Should statistics providers avoid unnecessary recalculation?
- **Where:** `lib/provider.dart` (GroupMonthlyTotalsNotifier, GroupMonthMemberTotalsNotifier, GroupMonthCategoryTotalsNotifier)
- **Why this matters:** Statistics recalculate from scratch when any expense changes, even if the change is in an unrelated month. No memoization or change filtering is applied.
- **Question:** Should statistics only recalculate for affected months?

---

### 8. Error Handling & Resilience

#### Q31. Should the auth upsert handle errors instead of swallowing them?
- **Where:** `lib/auth_gate.dart` (~lines 54-60)
- **Why this matters:** `.whenComplete(() {})` swallows all exceptions from the database upsert. If the insert fails, the user signs in but their profile data may be missing or outdated. No user feedback is shown.
- **Question:** Should upsert failures be surfaced to the user or retried?

#### Q32. Should Cloud Function invocations have timeouts?
- **Where:** `lib/helper/helper.dart` notification functions
- **Why this matters:** `supabase.functions.invoke('push', ...)` has no timeout. If the function hangs, the caller blocks indefinitely. Notification failures are only `debugPrint`ed (invisible in production).
- **Question:** Should a timeout be added? What's an acceptable timeout for push notifications?

#### Q33. Should unsafe type casts be replaced with safe alternatives?
- **Where:** `lib/navigation.dart` (route `extra` casting throughout)
- **Why this matters:** `state.extra as Map<String, dynamic>` will throw a runtime exception if `extra` is null or the wrong type. This could crash the app on malformed navigation or deep links.
- **Question:** Should these be wrapped in try-catch or use safe casting (`as?`) with fallbacks?

#### Q34. Should notification sending failures be visible to the user?
- **Where:** `lib/helper/helper.dart` (all `send*Notification` functions)
- **Why this matters:** All notification functions catch errors and only `debugPrint` them. In production, if push notifications fail (e.g., Edge Function down), users have no idea their group members weren't notified.
- **Question:** Should notification failures show a non-blocking warning, or is silent failure acceptable?

---

### 9. Testing & QA

#### Q35. Why are there zero tests?
- **Where:** No `test/` directory exists
- **Why this matters:** This is a financial app handling real money calculations. Without tests, there's no safety net against regressions in balance calculations, expense splitting, or friendship tracking.
- **Question:** Is test coverage planned? What areas should be prioritized first (balance calculations, expense splitting algorithm, data models)?

#### Q36. Should the CI/CD pipeline include test gates?
- **Where:** `.github/workflows/deploy_deun_web_page.yml`
- **Why this matters:** The pipeline deploys directly to production (GitHub Pages) on push to main with no `flutter analyze` or `flutter test` steps.
- **Question:** Should `flutter analyze` and `flutter test` be required before deployment?

---

### 10. Observability

#### Q37. Should errors be reported to a crash reporting service?
- **Where:** Entire codebase -- errors are caught and logged via `debugPrint` only
- **Why this matters:** In production, `debugPrint` output is invisible. Errors in Cloud Functions, database queries, and real-time subscriptions are silently lost. There's no way to know about production issues.
- **Question:** Should Firebase Crashlytics or Sentry be integrated for production error reporting?

---

### 11. Documentation

#### Q38. Should the database schema be documented?
- **Where:** Database schema not in repository
- **Why this matters:** The database schema is the source of truth for data models, RLS policies, and constraints. Without it in the repo, developers must inspect the live database to understand the data layer. RLS policies can't be code-reviewed.
- **Question:** Should a sanitized version of the schema (without secrets) be committed to the repository?

---

### 12. Technical Debt / Suspicious Areas

#### Q39. Is the expense insert ordering a known issue?
- **Where:** `lib/pages/expenses/provider/expense_list.dart`
- **Why this matters:** New expenses from real-time events may break chronological order if inserted at the wrong position in the list.
- **Question:** Is this on the backlog to fix? Should new expenses be inserted in sorted order or trigger a full re-fetch?

#### Q40. Is the navigation delay for expense sheets fragile?
- **Where:** `lib/helper/helper.dart` (~lines 224-232)
- **Why this matters:** `Future.delayed(Durations.medium1, ...)` (228ms) is used to wait for navigation animation before opening a bottom sheet. This is timing-dependent and may break on slower devices.
- **Question:** Is there a callback-based approach that would be more reliable?

#### Q41. Is the zero-width space hack for search refresh acceptable?
- **Where:** `lib/helper/helper.dart` `refreshSuggestions()` function
- **Why this matters:** Inserts and removes a zero-width space character to force the SearchController to refresh. This is a workaround for a Flutter limitation.
- **Question:** Is there a cleaner API available, or should this be kept until Flutter provides a proper refresh method?

#### Q42. Should the duplicate Firebase client config in google-services.json be removed?
- **Where:** `android/app/google-services.json` (two client entries: `app.deun.www` and `com.example.deun`)
- **Why this matters:** The `com.example.deun` entry appears to be a leftover from initial project setup. It uses the same Firebase API key as the real app. Having a stale config could cause confusion or unexpected behavior.
- **Question:** Should the `com.example.deun` entry be removed?

#### Q43. Is the `isRequester` naming in the friendship model confusing?
- **Where:** `lib/pages/friends/data/friendship_model.dart` (~lines 13-24)
- **Why this matters:** `isRequester` is set to `true` when the current user is the *addressee* (not the requester). The naming is semantically inverted from its meaning, making the code harder to reason about.
- **Question:** Should this be renamed to something clearer like `isIncomingRequest` or `isAddressedToMe`?

---

### 13. Possible Bugs

#### Q44. ~~Does the group notification handler use the wrong key?~~ `verified`
- **Where:** `lib/navigation.dart`
- **Answer:** Intentional -- uses `expense_id` on purpose. No change needed.

#### Q45. Does the date comparison miss same-day entries? `bug`
- **Where:** `lib/helper/helper.dart` `formatDate()` function
- **Answer:** Bug confirmed. Fix to compare date-only (year/month/day), ignoring time component.

#### Q46. ~~Can the `ignoreDuplicates: true` upsert prevent profile updates?~~ `verified`
- **Where:** `lib/auth_gate.dart`
- **Answer:** Intentional. Users edit profiles manually in settings; OAuth data only used on first signup.

#### Q47. ~~Does the friendship fetch miss half of all friendships?~~ `verified`
- **Where:** `lib/pages/friends/data/friendship_model.dart`
- **Answer:** Handled server-side. Supabase view/RLS returns both directions.

#### Q48. Does the friendship list provider have a duplicate reload call?
- **Where:** `lib/pages/friends/provider/friendship_list.dart` (~lines 61-63)
- **Why this matters:** `reload()` appears to be called twice when the subscription is established, causing a redundant database fetch on every subscription connect.
- **Question:** Is one of these reload calls unnecessary and should be removed?

#### Q49. Does the friendship `accepted()` method risk creating duplicate records?
- **Where:** `lib/pages/friends/data/friendship_model.dart` `accepted()` method
- **Why this matters:** The method inserts two bidirectional records with status="accepted" but doesn't check if a friendship already exists. Calling accept twice could create duplicates.
- **Question:** Should this use upsert or check for existing records first?

#### Q50. Is the currency formatting locale incorrect for German users?
- **Where:** `lib/helper/helper.dart` `toCurrency()` and `toNumber()` functions
- **Why this matters:** Currency formatting is hardcoded to `en_US` locale (using `.` as decimal separator). German users expect `,` as decimal separator and `.` as thousands separator. The app supports German locale but currency display ignores it.
- **Question:** Should currency formatting respect the user's selected locale?

---

### 14. Missing Decisions / Open Design Gaps

#### Q51. Should the app support multiple currencies?
- **Where:** `lib/helper/helper.dart` currency functions
- **Why this matters:** Currency is hardcoded to EUR with US-locale number formatting. International users may need USD, GBP, or other currencies.
- **Question:** Is EUR-only intentional for the current scope? Is multi-currency planned?

#### Q52. Should AdMob test IDs be replaced before production?
- **Where:** `lib/constants.dart` (MobileAdMobs enum)
- **Why this matters:** If the enum contains Google's test unit IDs (`ca-app-pub-3940256099942544/...`), shipping with test ads means no ad revenue.
- **Question:** Are production ad unit IDs configured elsewhere, or do these need to be replaced?

#### Q53. Should there be a staging/development environment?
- **Where:** `.github/workflows/deploy_deun_web_page.yml`
- **Why this matters:** The only CI/CD pipeline deploys directly to production on push to main. There's no staging environment for testing changes before they reach users.
- **Question:** Is a staging environment planned?

#### Q54. How should name parsing handle non-Western name formats?
- **Where:** `lib/auth_gate.dart` (~lines 31-42)
- **Why this matters:** Name parsing splits `full_name` on space and assumes Western order (first last). Names with multiple parts, mononyms, or non-Latin scripts would be incorrectly split.
- **Question:** Is the current name parsing acceptable for the target audience, or should it be more flexible?

#### Q55. Should the 26 untranslated German strings be addressed?
- **Where:** `lib/l10n/app_de.arb` vs `lib/l10n/app_en.arb`
- **Why this matters:** 26 English strings have no German translation. German-speaking users will see English fallbacks for these strings, creating an inconsistent language experience.
- **Question:** Should all strings be translated before the next release? Are some intentionally left in English?

#### Q56. Should the app handle offline scenarios?
- **Where:** Entire codebase -- no offline detection or queuing
- **Why this matters:** The app assumes always-online connectivity. If the network drops while creating an expense, the operation fails silently or with an error. There's no offline queue or local cache.
- **Question:** Is offline support planned? Should the app at least detect offline status and show a clear message?

#### Q57. Should minimum OS versions be updated?
- **Where:** `macos/Podfile` (macOS 10.14), `ios/Podfile` (iOS 15.6)
- **Why this matters:** macOS 10.14 is very old (2018). Supporting it limits use of modern APIs and increases maintenance burden. iOS 15.6 is reasonable but aging.
- **Question:** Should minimum OS versions be bumped to reduce maintenance scope?

---

### 15. Fresh Review Findings (2026-03-28)

#### Q58. Are guest users cleaned up when group save fails or a group is deleted?
- **Where:** `lib/pages/groups/data/group_repository.dart` saveAll() and `lib/pages/groups/presentation/group_detail_edit.dart`
- **Why this matters:** Guest users are created inline during group save. If the save fails partway through, the guest user record is orphaned in the database. Similarly, when a group is deleted, associated guest users are not cleaned up.
- **Question:** Should guest user creation be wrapped in a transaction with the group save? Should group deletion cascade-delete associated guest accounts?

#### Q59. Is FriendshipRepository.remove() intentionally fire-and-forget?
- **Where:** `lib/pages/friends/presentation/friend_list.dart` line 287
- **Why this matters:** `FriendshipRepository.remove(user.email)` is called without `await`. If the delete fails, the error is silently ignored and the UI proceeds as if the friendship was removed.
- **Question:** Should this be awaited with error handling? Should the user see feedback if removal fails?

#### Q60. Should the contact cache be invalidated when permission changes mid-session?
- **Where:** `lib/pages/friends/presentation/friend_add.dart` lines 59, 176-187
- **Why this matters:** Device contacts are cached in `_cachedContacts` on first load. If the user denies permission initially, then grants it via system settings and returns, the cache still holds null/empty and no contacts appear until the app restarts.
- **Question:** Should the cache be invalidated on widget re-mount or permission change?

#### Q61. Should real-time change events be debounced before triggering rebuilds?
- **Where:** `lib/helper/realtime_mixin.dart`
- **Why this matters:** Multiple rapid database changes (e.g., bulk expense import or multiple members editing simultaneously) each trigger a separate state rebuild. This can cause UI flicker and unnecessary network requests.
- **Question:** Should a short debounce window (e.g., 300ms) be applied to batch rapid change events?

#### Q62. Should the group list support pagination?
- **Where:** `lib/pages/groups/provider/group_list.dart`
- **Why this matters:** Unlike expenses (which have pageSize=20), the group list fetches all groups in a single query. For power users with many groups, this could become slow and memory-intensive.
- **Question:** At what group count does this become a problem? Should cursor-based pagination be added?

#### Q63. Does the receipt parser misinterpret "1,00" as 100.0?
- **Where:** `lib/pages/expenses/service/receipt_parser.dart` amount parsing logic
- **Why this matters:** The parser's decimal separator detection uses heuristics (last comma vs last period position). For amounts like "1,00" (common in German receipts meaning 1.00 EUR), the parser may interpret the comma as a thousands separator and return 100.0 instead of 1.00.
- **Question:** Should the parser use the user's locale to disambiguate, or require a manual confirmation step for ambiguous amounts?

#### Q64. Is the receipt merchant name detection robust enough?
- **Where:** `lib/pages/expenses/service/receipt_parser.dart` merchant name extraction
- **Why this matters:** The parser assumes the first non-excluded line of OCR text is the merchant name. Many receipts have logo text, store numbers, or address lines before the actual merchant name.
- **Question:** Should a scoring heuristic or keyword-based approach be used to identify the merchant name more reliably?

#### Q65. Can a guest user be linked to multiple groups without uniqueness constraints?
- **Where:** `lib/pages/groups/data/group_repository.dart` guest creation and group join logic
- **Why this matters:** When a real user joins a group that had a guest placeholder for them, the system transfers guest data (expenses, shares) to the real user. If the same person was added as a guest to multiple groups, there's no constraint ensuring correct linking across groups.
- **Question:** Should there be a database-level uniqueness constraint on guest-to-user linking? How should multi-group guest consolidation work?

#### Q66. Should expense updates use optimistic locking to prevent stale overwrites?
- **Where:** `lib/pages/expenses/data/expense_model.dart` saveAll()
- **Why this matters:** If two users edit the same expense concurrently, the last save wins without warning. The first user's changes are silently overwritten.
- **Question:** Should a version column or updated_at check be used to detect and prevent concurrent edit conflicts?

#### Q67. Are time zones handled consistently in statistics and receipt parsing?
- **Where:** `lib/provider.dart` (statistics providers), `lib/pages/expenses/service/receipt_parser.dart`
- **Why this matters:** Statistics use `DateTime.parse()` which may return UTC timestamps, while receipt dates are parsed as local time without timezone info. Monthly grouping in statistics could assign expenses to the wrong month if UTC/local conversion isn't handled.
- **Question:** Should all dates be standardized to UTC for storage and converted to local only for display?

#### Q68. Do deleted user references show stale display names in expenses?
- **Where:** Expense display using `paid_by_display_name` field
- **Why this matters:** The `paid_by_display_name` field is set at expense creation time. If the paying user later deletes their account or changes their name, the expense still shows the old name. For deleted users, this creates a reference to a non-existent account.
- **Question:** Should display names be resolved dynamically from the user table, or is the snapshot approach acceptable? Should deleted users show a placeholder like "Deleted User"?

#### Q69. Does the simplified expense calculation loop have a termination guard?
- **Where:** `lib/pages/groups/data/group_model.dart` ~line 142 (calculateGroupSharesSummarySimplified)
- **Why this matters:** The while loop that matches debtors with creditors relies on floating-point comparisons to terminate. If rounding errors prevent the balance from reaching exactly zero, the loop could run indefinitely or produce incorrect settlement transactions.
- **Question:** Should a maximum iteration count be added as a safety guard? Should balances be rounded to 2 decimal places before comparison?

#### Q70. Should payBack() be a single atomic operation?
- **Where:** `lib/pages/groups/data/group_repository.dart` payBack() and `lib/pages/groups/presentation/group_detail_payment.dart`
- **Why this matters:** payBack() calls two separate RPCs sequentially: first `pay_back` (creates expense record), then `update_group_member_shares` (recalculates balances). If the first succeeds but the second fails, the database is left in an inconsistent state — a payment is recorded but balances don't reflect it.
- **Question:** Should this be combined into a single Supabase Edge Function or database transaction to ensure atomicity?

#### Q71. Should the app show real-time connection state to the user?
- **Where:** `lib/helper/realtime_mixin.dart`
- **Why this matters:** If the Supabase real-time connection drops (network issues, server restart), users see stale data with no indication that updates have stopped. They may believe their view is current when it isn't.
- **Question:** Should a connection state provider expose subscription health so the UI can show a "reconnecting" banner or indicator?

#### Q72. Can RealtimeNotifierMixin leak channels on initialization error?
- **Where:** `lib/helper/realtime_mixin.dart`
- **Why this matters:** If `subscribeToChannel()` succeeds but a subsequent operation during notifier initialization throws, the channel subscription remains active but `disposeChannels()` may not be called (since `ref.onDispose` triggers on normal dispose, not on build errors). This could create zombie subscriptions consuming server resources.
- **Question:** Should channel subscription be wrapped in try/finally to ensure cleanup on initialization failure?

---

## Suggested Answer Tags

Use these tags consistently when answering:

| Tag | Meaning |
|-----|---------|
| `verified` | Intended behavior, no change needed |
| `partial` | Partially correct, needs refinement |
| `blocked` | Can't answer yet, depends on something else |
| `deferred` | Known issue, will address later |
| `out-of-scope` | Not relevant or not worth addressing |
| `caveat` | Answer with conditions |
| `bug` | Confirmed bug, needs fixing |
| `approved improvement` | Agree this should be improved |
