# multi-currency-group — Per-currency cross-group totals, replacing home-currency conversion

## Spec
- Source: idea ("multiple currencies with conversion rates", 2026-07-08; replanned 2026-08-11 on
  competitor + user-sentiment research; **rebased 2026-08-15** onto the multi-currency work that had
  already shipped on `feature/brew-2026-07-12`)
- Flight: multi-currency
- Goal: Cross-group totals stop converting into a personal home currency and start breaking down per
  currency, and per-group currency handling becomes correct for 0-decimal currencies.

## Flight note — the model this flight commits to
Research across Splitwise, Tricount, Settle Up, Splid, Spliit and Kittysplit (2026-08-11), plus the
public Splitwise feedback forum, App Store and Play reviews, and GitHub issues on the open-source
clones. Five of six converge on the same model, and it is the one this flight builds:

**One settlement currency per group -> expenses may be entered in another currency -> the rate is
prefilled but user-overridable -> the converted amount and the rate are frozen on the row -> all
balances merge into the group currency.**

The two behaviours users complain about most are (a) a mid-market rate that does not match what their
bank actually charged, and (b) conversion that retroactively rewrites past expenses. Splitwise's
manual-rate request has sat unshipped for a decade at 203 votes; its group-currency request at 309
votes since 2012. Per-*user* currency drew 4 votes — this flight does not build it, and the
already-shipped cross-group "home currency" conversion is **retired here** for the same reason.

## Rebase note — what already shipped, and what this feature now owns
`multi-currency-foundation` (`47c5a6d`) and `multi-currency-home-aggregates` (`9349e38`) shipped on
2026-07-12. This plan was originally written against `origin/main`, which does not contain them.
**Do not rebuild what already exists**, and do not assume anything below is greenfield:

- **Already done, leave alone:** the `group.currency_code` column and its migration
  (`20260712000000_add_group_currency_code.sql`), `Group.currencyCode`, the currency picker on group
  create and edit (`_CurrencyField` in `group_detail_edit.dart`), the relabel warning, and
  currency-aware rendering inside a group via `MoneyText` / `toCurrency`.
- **Shipped but superseded — this feature removes it:** `lib/helper/currency_conversion.dart`,
  `lib/helper/exchange_rate_service.dart`, `homeCurrencyProvider`, the home-currency setting and its
  `settingsHomeCurrency*` strings, and every cross-group conversion built on them.
- **Still to build:** everything in the acceptance list below.

## Contract
- Acceptance:
  - Cross-group totals never sum or convert unlike currencies. No displayed figure is ever the sum of
    amounts in two different currencies.
  - When all of a user's groups share one currency, all three surfaces (overall balance hero, friend
    balances, personal statistics) render exactly as they do today — same layout, same line count, no
    expand affordance shown. This is the only case that exists in production right now and it must not
    regress.
  - When groups span more than one currency, each of the three surfaces shows the **primary currency
    inline** and collapses the remainder behind a disclosure labelled with the count of hidden
    currencies. The primary currency is the one with the largest absolute balance on that surface;
    ties break by ISO code ascending so the choice is deterministic and testable.
  - Expanding the disclosure reveals one row per remaining currency, each an exact ledger value in its
    own currency with that currency's decimal digits. Collapsing restores the inline state. The
    expanded/collapsed state is local to the surface and is not persisted across app launches.
  - A user with exactly two currencies sees the primary inline and a disclosure naming one hidden
    currency — the disclosure is never shown with a count of zero.
  - The personal statistics trend chart plots exactly one currency at a time, never a mixed series.
    It defaults to the primary currency, its axis is labelled with that currency, and selecting a
    different currency from the disclosure re-plots the chart in that currency. A single-currency user
    sees no selector.
  - Each month bucket in the trend chart is the sum of that month's expenses **in the plotted currency
    only**; groups in other currencies contribute nothing to it rather than being converted or
    silently folded in.
  - `approximate` and `excludedCount` are gone from the personal statistics state, along with the "≈"
    marker and the "N groups excluded, no rate available" copy — with no conversion there is no
    estimate and nothing is ever excluded for want of a rate.
  - A friend list row shows the primary-currency balance plus a non-interactive marker of how many
    other currencies that friendship spans. The row has no expand target of its own — its whole area
    still opens the detail sheet, and the sheet carries the expandable breakdown. A single-currency
    friendship shows no marker.
  - A friendship's owes-you/you-owe direction and its semantic colour follow the **primary currency**.
    When a friend owes the user in one currency while the user owes them in another, each currency's
    row in the sheet carries its own direction and colour independently, and no direction is inferred
    from a sum across currencies.
  - Settling a friend across groups in different currencies settles each group in that group's own
    currency, and the confirmation names the per-currency amounts rather than one merged figure.
  - The home-currency surface is gone: `currency_conversion.dart`, `exchange_rate_service.dart`,
    `homeCurrencyProvider`, the settings home-currency row and the `settingsHomeCurrency` /
    `settingsHomeCurrencyInfo` strings in both ARB files no longer exist, and no code path fetches an
    exchange rate. Grepping `lib/` for `homeCurrency` returns no matches.
  - The `http: ^1.2.0` dependency is removed from `pubspec.yaml`. `exchange_rate_service.dart` is its
    only importer in `lib/`, verified at prep time, so nothing else breaks — and after this the app
    genuinely has no HTTP client, which is the premise
    [multi-currency-rate-source](multi-currency-rate-source.md) rests its Edge Function decision on.
  - A user who had set a home currency, or who has a cached rates blob under
    `kExchangeRatesCachePrefKey`, sees no error and no empty state. Both stored preferences are ignored
    on read and never written again; leftover values are inert rather than migrated.
  - No "≈ approximate" marker survives anywhere, because no displayed number is an estimate any more.
    Every figure the app shows is an exact ledger value in a named currency.
  - A group list containing a EUR group and a JPY group shows each row in its own currency with
    correct decimal digits per row (¥3,000 next to €25.50).
  - The settled/active classification uses the group's own currency: a JPY group with a net balance of
    0.4 is settled, one with 0.6 is active, and a EUR group at 0.004 is settled where one at 0.006 is
    active. The PostgREST tab predicate returns a superset in both directions — `active` filtered on
    the smallest supported epsilon, `done` on the largest — and `isSettled(amount, currency)` makes the
    final call, so a group's tab placement and its row rendering can never disagree.
  - A group's currency may be changed only while every expense in it shares that currency; once any
    expense carries a different original currency the picker is disabled and states why. (Vacuously
    true until [multi-currency-expense-rate](multi-currency-expense-rate.md) lands — build the guard
    now so that feature does not have to retrofit it.)
  - PayPal.me settlement links carry the group's currency code, so settling a USD balance does not
    open a request in the payee's default currency.
  - `flutter analyze` and `flutter test` pass, including a test that a mixed-currency set of groups
    produces a per-currency breakdown rather than one merged number, and with the deleted features'
    tests (`test/helper/currency_conversion_test.dart`, `test/provider/home_currency_test.dart`)
    removed rather than skipped.
- Provides:
  - `Group.currency -> Currency`
  - `canChangeGroupCurrency(Group) -> bool`
  - `showCurrencyPicker(BuildContext, {Currency? initial}) -> Future<Currency?>` — the group-edit
    currency field extracted from its current private `_CurrencyField` form binding so
    [multi-currency-expense-rate](multi-currency-expense-rate.md) can reuse it for entry currency.
    **Added at prep 2026-08-16:** that feature already listed this in its `Consumes:` while this plan
    did not provide it — a mismatch that would have surfaced as a missing signature at pull time.
  - `CurrencyAmount` — `.currency -> Currency`, `.amount -> double`
  - `CurrencyBreakdown` — `.primary -> CurrencyAmount`, `.others -> List<CurrencyAmount>`,
    `.hiddenCount -> int`, `.isSingleCurrency -> bool`. The one shape all three surfaces render, so
    "primary inline, remainder collapsed" is decided once rather than three times.
  - `balancesByCurrency(List<Group>) -> CurrencyBreakdown`
  - `friendBalancesByCurrency(List<Friendship>) -> CurrencyBreakdown`
- Consumes: `Currency`, `kSupportedCurrencies`, `roundCurrency`, `isSettled`, `formatMoney`,
  `CurrencyScope`, `MoneyText` (from [multi-currency-core](multi-currency-core.md)) — checked at prep
  2026-08-16 against that plan's `Provides:`; every name is present.
- Decisions:
  - Cross-group totals get a per-currency breakdown rather than conversion to a personal home
    currency -> home currency has essentially no evidenced demand (4 votes); the breakdown is honest,
    free, and needs no rate source.
  - The breakdown is **primary-inline plus a collapsed remainder**, not a stack of all currencies and
    not a global currency filter (Jakob, prep 2026-08-16) -> keeps every surface one line tall in the
    common case, so the single-currency layout that 100% of production is on today is untouched, and
    no surface has to reflow for a case almost nobody is in. The cost — real money one tap away — is
    accepted because the disclosure states how many currencies are hidden.
  - Primary = largest absolute balance, ties by ISO code ascending -> "largest" is the figure the user
    most needs to see, and the tiebreak exists so the choice is deterministic rather than dependent on
    map iteration order, which is what makes it testable.
  - **The monthly trend series does not need an RPC change** (prep 2026-08-16, corrected against the
    live schema) -> the earlier plan text claimed the series "has no group dimension at all". That is
    wrong. `get_user_spending_summary` — the only RPC the personal statistics notifiers call — already
    returns `group_id` per row and groups by group and month. The per-currency fold is pure client-side
    work over rows that already carry the dimension. No migration, no RPC edit, and this feature does
    not touch the database at all.
  - **The active/done tab filter stays a PostgREST filter, widened to the permissive bound per tab,
    with the exact call made client-side** (prep 2026-08-16) -> `activeBalanceFilter` is already built
    from `kSettledEpsilon` rather than a hardcoded 0.01 (settle-residue unified that), and the group
    list is not paginated, so over-fetching is harmless. The `active` tab filters on the *smallest*
    supported epsilon and the `done` tab on the *largest*, each returning a superset; `isSettled(amount,
    currency)` then makes the real decision on the client. Tabs and rows agree by construction because
    one predicate decides both. Rejected: moving the filter behind a new RPC — it would put settled
    semantics in two places and add a migration to a feature that otherwise needs none.
  - The already-shipped home-currency aggregates are **removed, not left dormant** -> leaving a second,
    contradictory money model in the tree is how the app ends up with two answers for one balance.
    (Jakob, 2026-08-15: replan supersedes the shipped model.)
  - Removal happens in this feature, together with the replacement -> retiring conversion in a separate
    earlier step would leave a release where cross-group totals silently add unlike currencies.
  - Currency is a property of the group, not of the user -> 309 votes vs 4 in the only public dataset
    on this question, and it is the only model that works when two members of one group live in
    different countries.
  - Group currency locks once expenses diverge (Kittysplit's guardrail) -> the alternative produces
    the single angriest review class found in the research: a currency switch that silently moves
    other people's settled balances.
  - Changing the currency relabels, never converts -> conversion of an existing ledger is exactly the
    destructive rewrite that generates "it screwed up hundreds of my past transactions".
  - Multi-currency is never gated behind a paywall or ad tier -> it is free in every competitor except
    Splitwise, and the paywall is a named reason users leave.
  - The trend chart plots one currency at a time and the disclosure doubles as its currency switcher
    (Jakob, prep 2026-08-16) -> unlike currencies cannot share a y-axis, and small multiples would
    multiply chart work and vertical space for a case that currently affects zero users. Switching
    keeps every figure reachable, which the "primary only, others excluded" alternative would not.
  - The chart's currency selection is view state, not a preference -> it is derived from the same
    per-currency map the scalars use, so there is nothing to persist and no second source of truth
    about which currency a user cares about.
- Units:
  - Retire the home-currency surface: delete `currency_conversion.dart`, `exchange_rate_service.dart`,
    `homeCurrencyProvider`, the settings row, both ARB key pairs and the two test files; drop
    `http: ^1.2.0` from pubspec. Its own commit, first — deleting the old model before building the
    new one makes "did we miss a call site" a question the compiler answers.
  - `CurrencyAmount` / `CurrencyBreakdown` plus the three per-currency folds that replace the
    converting ones: the overall balance hero (view-model fold), the friend balances (folded inside
    `friendship_repository.dart` today, so either the currency is injected there or the fold moves out
    to a view model), and the personal statistics notifier.
  - Render the breakdown: primary inline with a collapsed disclosure on the overall balance hero and
    the friend detail sheet, and the non-interactive count marker on the friend list row.
  - Trend chart plots one currency at a time with the disclosure as its switcher; remove `approximate`,
    `excludedCount` and the "≈" marker from the statistics state and its widgets.
  - Currency-correct settled classification: widen `activeBalanceFilter` to the permissive bound per
    tab and let `isSettled(amount, currency)` make the real call client-side, so tabs and rows agree.
  - Group-currency lock (`canChangeGroupCurrency`) wired into the picker's disabled state, the picker
    extracted as `showCurrencyPicker`, correct decimal digits per group row, and the PayPal.me link
    currency.
- Blockers: —

## Approach
The removal is the first move and should be its own commit inside the feature — deleting the
conversion layer before building the breakdown keeps the two models from coexisting even briefly in
the diff, and makes the "did we miss a call site" question answerable by the compiler.

Three aggregation points span groups and currently **convert**: the overall balance hero (a view-model
fold, the easy one), the friendship balances (folded inside the repository, so either the currency is
injected there or the fold moves out to a view model), and the personal statistics notifier. Each
becomes a per-currency fold producing one `CurrencyBreakdown`.

The monthly trend series was previously believed to need an RPC change. It does not —
`get_user_spending_summary` already returns `group_id` per row and groups by group and month, so the
trend is foldable per currency on the client like everything else. This feature touches no database.

The active/done tabs filter through a PostgREST predicate built in Dart from `kSettledEpsilon`
(`activeBalanceFilter`). It stays there: `active` filters on the smallest supported epsilon, `done` on
the largest, each deliberately returning a superset, and `isSettled(amount, currency)` makes the real
decision client-side. The group list is not paginated, so the over-fetch costs nothing and the tabs
and rows cannot disagree because one predicate decides both.

Note the base schema — `group`, `save_group_all`, `update_group_member_shares` — is not in
`supabase/migrations`; the instance is self-hosted and changes are applied by hand. Only new
migrations land in the repo.

- Likely touchpoints: `lib/helper/currency_conversion.dart` and `exchange_rate_service.dart` (deleted),
  `lib/provider.dart` + `provider.g.dart` (home-currency provider removed),
  `lib/pages/settings/setting.dart` and `settings_sheets.dart`,
  `lib/pages/groups/presentation/group_list.dart` and `group_list_view_model.dart`,
  `lib/pages/friends/data/friendship_repository.dart` and `friend_detail_sheet.dart`,
  `lib/pages/statistics/provider/personal_statistics_notifiers.dart`,
  `lib/pages/groups/presentation/group_detail_payment.dart`, both ARB files
- Depends: multi-currency-core, group-currency-persist
- Parallel-with: —

`Depends: group-currency-persist` was added at prep 2026-08-16 and is already satisfied. It is
recorded rather than dropped because this feature builds per-currency balances, a currency lock and a
per-row currency on `Group.currency` — and until `20260816000000` was applied, `save_group_all`
discarded that value on every write, so every group in the instance was EUR regardless of the picker.
Building this on that field before the fix would have produced a feature that passed every test and
did nothing.

status: planned
