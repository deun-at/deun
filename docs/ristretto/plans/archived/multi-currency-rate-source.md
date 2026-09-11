# multi-currency-rate-source — Historical rate prefill via a Supabase Edge Function

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08; replanned 2026-08-11)
- Flight: multi-currency
- Goal: Stop making the user type a rate they do not have. The expense form prefills the historical
  rate for the expense's own date, fetched server-side and cached — as a suggestion the user can
  always overrule.

## Contract
- Acceptance:
  - [auto] Creating an expense in a currency other than the group's prefills the rate for the **expense's
    date**, not today's, and the form states which date the rate is attributed to.
  - [auto] The prefilled value is editable. A user-entered rate always wins and is what gets frozen on the
    row; nothing in this feature can overwrite a rate the user typed.
  - [auto] Changing the expense's date re-fetches the prefill for the new date. Editing any other field
    never triggers a fetch and never changes a displayed or stored rate.
  - [auto] A saved expense's stored rate and converted amount are never altered by this feature, including
    when rates later move or the expense is reopened for editing.
  - [auto] When the rate service is unreachable, returns no rate for the requested pair, or the date has no
    published rate (weekends, holidays, future dates), the form falls back to manual entry with a
    visible explanation. It never substitutes 1:1, never silently uses today's rate in place of the
    requested date, and never blocks saving with a manually entered rate.
  - [human] Rates are fetched through a Supabase Edge Function rather than directly from the client, so the
    web build is unaffected by CORS or by the provider changing hostnames.
  - [auto] Repeated requests for the same currency pair and date are served from cache rather than refetched.
  - [auto] Every code in `kSupportedCurrencies` returns a rate for a recent weekday, verified by a test
    against the live function or a recorded fixture.
  - [auto] `flutter analyze` and `flutter test` pass, including tests for the unavailable-service fallback
    and for date-change-triggers-refetch / other-edits-do-not.
- Provides: *(corrected at close against the built code — all in
  `lib/pages/expenses/service/rate_source.dart` unless stated)*
  - `fetchRate({required Currency base, required Currency quote, required DateTime date}) -> Future<RateQuote?>`
  - `RateQuote` — `.rate -> double`, `.effectiveDate -> DateTime`
  - Supabase Edge Function `exchange-rate` (`supabase/functions/exchange-rate/index.ts`)
  - **Beyond the contract**, all forced by making the failure paths testable without a deployment:
    - `RateSource({RateTransport? transport})` — the class behind `fetchRate`, holding the
      in-session cache. `transport` is the injection point every failure test uses.
    - `rateSource` — the shared instance, so the cache spans editors rather than one screen.
    - `typedef RateTransport = Future<Map<String, dynamic>?> Function(Map<String, dynamic>)`
    - `typedef RateLookup` — the lookup as the editor consumes it; `ExpenseDetail.lookupRate`
      is the test seam typed by it.
- Consumes: `Currency`, `kSupportedCurrencies` (from [multi-currency-core](multi-currency-core.md));
  the editor's rate field and `setStickyRate` (from
  [multi-currency-expense-rate](multi-currency-expense-rate.md))
- Decisions:
  - Frankfurter (frankfurter.dev, ECB reference data, free, no API key) is the source -> it is what
    both open-source competitors use, it covers historical rates back decades, and
    [multi-currency-core](multi-currency-core.md)'s curated list is already pinned to its coverage.
  - Fetch server-side through an Edge Function -> the app has no HTTP client and no declared `http`
    dependency today, every external call already goes through Supabase, and a client-side fetch
    broke conversion outright for the one competitor that tried it when the provider issued a
    redirect without CORS headers. The function is also the natural place to cache.
  - Historical rate at the expense date, not the current rate -> using the current rate at conversion
    time is the mechanism behind the largest single quantified harm found in the research (a member
    overpaying by ~$100 on a months-old trip).
  - Prefill only; the manual rate always wins -> this feature is convenience layered on
    [multi-currency-expense-rate](multi-currency-expense-rate.md), which must remain fully usable
    without it.
  - Only a date change re-fetches (Kittysplit's rule) -> any broader trigger reintroduces surprise
    rate movement on expenses the user thought were settled.
  - Failure is visible and falls back to manual entry -> a silent 1:1 or wrong-date substitution is
    worse than no prefill, and both are confirmed shipped bugs elsewhere.
- Units:
  - Supabase Edge Function `exchange-rate`: validate the pair and date, call Frankfurter, cache, and
    return a rate plus the date it is actually effective for.
  - Client rate service with the typed result, in-session cache, and explicit unavailable state.
  - Wire prefill into the expense editor, including the effective-date label and the
    date-change-only refetch.
  - Fallback UX for unavailable rates, plus a check that every supported currency resolves.
- Manual-Checks: [manual-checks.md](../../manual-checks.md) — deploy the `exchange-rate` Edge Function to the self-hosted instance
- Blockers: —
- Deferred DB work: needs an Edge Function deployed to the self-hosted instance, which updates by
  force-recreate rather than in place. Write the function source into the repo and the client against
  its contract, test the client against a faked response including the failure and offline paths,
  mark anything requiring the deployed function `[deferred]`, and append to
  [manual-checks.md](../../manual-checks.md). A prefill that silently fails must degrade to manual entry —
  that behaviour is testable without deploying anything, and is the one that matters most.

## Approach
Small and self-contained compared to the rest of the flight, because everything it feeds already
exists: [multi-currency-expense-rate](multi-currency-expense-rate.md) ships a working manual rate
field, and this only changes what that field starts out containing.

The Edge Function follows the pattern already used for `push`, `send-contact-email` and the Gemini
receipt parser. Note that the requested date and the effective date often differ — ECB publishes on
business days, so a Saturday expense resolves to Friday's rate. Return the effective date rather than
echoing the request, and show it, so the user can see what they are accepting before it is frozen.

The one thing to be careful about is not letting the prefill fight the user: the fetch is
asynchronous, so a rate arriving after the user has already typed one must not overwrite it.

- Likely touchpoints: new `supabase/functions/exchange-rate/`, a new rate service under
  `lib/helper/` or `lib/pages/expenses/service/`,
  `lib/pages/expenses/presentation/expense_detail.dart`, both ARB files
- Depends: multi-currency-expense-rate
- Parallel-with: —

## Evidence

Built in one pull on 2026-09-11, 28 new tests across 4 units, whole-repo gate green
(`gate.js verify` exit 0 — `flutter analyze` clean, 1510 tests pass, up from 1482).

review: notes-only · rounds: 2 · open: 0 block, 3 note, 4 lean
tier: normal

**The one defect review caught, and it would have shipped.** The Edge Function refused a future
date with `date > today()`, where `today()` is UTC (`new Date().toISOString()`) but the client sends
the **device's local** date (`ymd`, `lib/helper/helper.dart:56`). Every user east of UTC therefore
had same-day expenses refused as "future" for the first hours of their morning — Tokyo at 08:00 on
the 11th sends `2026-09-11` while the function's `today()` is still `2026-09-10`. That is precisely
the travelling cohort the whole flight exists for, and JPY, AUD, NZD, SGD, HKD, KRW and THB are all
in `kSupportedCurrencies`. Fixed with one day of slack — `daysBetween(today(), date) > 1` — which
round 2 confirmed is exactly enough (the largest civil offset is UTC+14, so a local date is at most
one day ahead, never two) and cannot reintroduce the substitution it guards: whatever comes back
carries the provider's own effective date, bounded by the `> 7` walk-back guard, displayed under the
field and frozen on the row. The guard test was verified to go red when the fix is reverted.

- **Prefills for the expense's date, and names the date it is attributed to** —
  `expense_editor_rate_prefill_test.dart` "choosing a foreign currency prefills the rate for the
  expense date" (asserts the request carried `2026-07-01`, the expense's own date, not today's),
  "the form names the date the prefilled rate is attributed to"; `rate_source_test.dart` "a quote
  carries the rate and the EFFECTIVE date, not the requested one".
- **Editable; a user rate always wins** — "a rate typed over the prefill is what gets frozen, with
  its own date"; "a rate arriving LATE never overwrites one the user has typed" (staged with a
  `Completer` so the answer lands *after* the user types); "a remembered rate wins — no prefill is
  even requested". Enforced by `_RateOrigin` plus a monotonic `_rateRequestId`, checked both before
  the request and after it resolves.
- **Date change refetches; nothing else does** — "changing the expense date refetches the prefill
  for the new date" (drives the real `DateOptionsSheet`, not a direct `didChange`, so the wiring is
  what is proven); "editing another field neither refetches nor moves the rate".
- **A saved expense is never altered** — "a saved converted expense is never refetched for, even on
  a date change": opens on its frozen 0.0058, survives a date change, and saves back byte-identical
  with its original `2026-08-16` rate date.
- **Unavailable → visible manual fallback, never 1:1, never the wrong day** — "an unavailable rate
  falls back to manual entry, visibly"; "an unavailable rate never blocks saving a manually entered
  one"; "a failed refetch clears the stale prefill rather than misdating it" (the wrong-date
  substitution arrived at by *omission* — leaving the old date's rate standing under a new date);
  `rate_source_test.dart` "an unreachable service yields null, never a 1:1 rate, and is retried",
  "a no_rate answer for the date yields null", "a malformed body yields null rather than throwing"
  (seven malformed bodies).
- **Cache** — "the same pair and date is served from cache — one call, not two"; "the cache key
  includes the DATE — another day is a miss". A *failure* is deliberately not cached, proven by the
  retry assertion above: caching a null would freeze a transient outage for the session.
- **A prefill never becomes sticky** — "an accepted prefill is saved but never remembered" and "a
  rate typed over the prefill IS remembered". Without this the feature would fire once per group and
  currency and then be shadowed forever by its own first answer, which is the opposite of a rate for
  each expense's own date. Not in the contract; it falls out of the dependency's rule that the
  sticky rate is one the user *typed*.
- **No HTTP client crept in** — `rate_source_test.dart` "the only transport is the exchange-rate
  Edge Function", plus the pre-existing repo-wide sweep in
  `test/pages/groups/multi_currency_group_test.dart` (no `package:http/`, no direct provider call
  anywhere in `lib/`), and `pubspec.yaml` still declares no `http`.

**What is NOT proven here.** The `[human]` criterion — that rates are fetched through the Edge
Function so the web build is unaffected by CORS — is `pending human: deploy the exchange-rate Edge
Function` and is recorded as such, not as proven. What the tests do prove is the client half: there
is no other way out of `lib/`. The deployed half needs the function on the self-hosted instance.

The "every supported currency resolves" criterion is proven **only for the client**. Its fixture is
hand-authored, not captured from the provider, so it shows that no code is special-cased and that
the app's list cannot drift from the table — not that the provider quotes ISK, TRY or IDR. Step 8 of
the manual check closes that gap. A code the provider does not quote is not a correctness hazard: it
resolves to null and degrades to the visible manual-entry fallback, never to a substituted rate.

**Scope note.** The Approach warned against letting a late prefill fight the user; that turned out
to be the central design problem rather than a footnote, and `_RateOrigin` is the answer. A
*remembered* rate is treated as user-owned, which means the prefill is never even requested for one
— strictly stronger than "never overwritten", and the reason the request count is assertable.

## Open findings

Left open by review round 2 (`notes-only`), recorded verbatim, none fixed:

note · `test/widgets/expense_editor_rate_prefill_test.dart:174,403` · both trailing `findsNothing`
assertions run *after* `saveEditor`, and `expense_detail.dart:1177` pops the editor in a `finally`,
so they are vacuous — leaving `_rateUnavailable = false` on typing (`expense_detail.dart:1243`) with
no live coverage; can't harm a user because the code does clear it and each test's load-bearing
`conversion` assertion is real · assert the key is gone *before* tapping save, or drop the two lines.

note · `supabase/functions/exchange-rate/index.ts:91` · for a date exactly one day past UTC
`today()` the Contract's "the date has no published rate (weekends, holidays, **future dates**) →
the form falls back to manual entry" is literally unmet: it prefills instead; can't harm a user
because the effective date is displayed and frozen, which is the same walk-back the plan's Approach
already blesses for a Saturday, and refusing it is the round-1 block · reword the criterion's
parenthetical to "future dates beyond the timezone slack" when archiving.

note · `lib/pages/expenses/presentation/expense_detail.dart:253` · the `!_isForeignCurrency` arm
added this round has no test (no "switch back to the group currency with a fetch in flight" case);
can't harm a user because without it the stray write lands in a field that isn't rendered while
`_conversion` is identity, so nothing stored changes · add one case to the prefill suite, or say in
evidence that it's belt-and-braces.

lean · `test/pages/expenses/rate_source_test.dart:53` · `_recordedDate` (and `_RecordedTransport`'s
name at :57) still say "recorded" after the fixture became `_syntheticEcbRates`, contradicting the
new docstring's "hand-authored, not captured" · rename to `_fixtureDate`.

lean · `test/pages/expenses/exchange_rate_function_test.dart:88` · the currency sweep asserts
`source contains "'USD'"`, which any comment or unrelated string in `index.ts` satisfies · anchor it
to the `SUPPORTED` set literal.

lean · `supabase/functions/exchange-rate/index.ts:104` · expired `cache` entries are never deleted,
so a long-lived isolate grows one entry per pair-and-date forever · drop the key on a miss-by-expiry.

lean · `lib/helper/helper.dart:178` (untouched — reported, not a round) · `formatRate`'s fixed 6
decimals costs ~1% on an IDR→EUR prefill (0.0000579 → "0.000058"); pre-existing, but this feature is
the first to put a *computed* rate in that field, where it's likelier to be accepted unread.

status: needs-human
