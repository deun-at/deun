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
- Provides:
  - `fetchRate({required Currency base, required Currency quote, required DateTime date}) -> Future<RateQuote?>`
  - `RateQuote` — `.rate -> double`, `.effectiveDate -> DateTime`
  - Supabase Edge Function `exchange-rate`
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
- Manual-Checks: [manual-checks.md](../manual-checks.md) — deploy the `exchange-rate` Edge Function to the self-hosted instance
- Blockers: —
- Deferred DB work: needs an Edge Function deployed to the self-hosted instance, which updates by
  force-recreate rather than in place. Write the function source into the repo and the client against
  its contract, test the client against a faked response including the failure and offline paths,
  mark anything requiring the deployed function `[deferred]`, and append to
  [manual-checks.md](../manual-checks.md). A prefill that silently fails must degrade to manual entry —
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

status: planned
