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
  - Cross-group totals never sum or convert unlike currencies. When a user's groups span more than one
    currency, the overall balance hero, the friend balances and the personal statistics figures each
    show a per-currency breakdown; when all groups share one currency the display is unchanged from
    today.
  - The home-currency surface is gone: `currency_conversion.dart`, `exchange_rate_service.dart`,
    `homeCurrencyProvider`, the settings home-currency row and the `settingsHomeCurrency` /
    `settingsHomeCurrencyInfo` strings in both ARB files no longer exist, and no code path fetches an
    exchange rate. Grepping `lib/` for `homeCurrency` returns no matches.
  - No "≈ approximate" marker survives anywhere, because no displayed number is an estimate any more.
    Every figure the app shows is an exact ledger value in a named currency.
  - A user who had set a non-EUR home currency sees no error, no empty state and no lost data after
    the removal — the stored preference is ignored or dropped cleanly on read.
  - A group list containing a EUR group and a JPY group shows each row in its own currency with
    correct decimal digits per row (¥3,000 next to €25.50).
  - The settled/active classification uses the group's own currency: a JPY group with a net balance of
    0.4 is settled, one with 0.6 is active. This holds for the server-side active/done group filter as
    well as the client-side lists, so the group tabs and the group rows agree.
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
  - `balancesByCurrency(List<Group>) -> Map<Currency, OverallBalance>`
- Consumes: `Currency`, `kSupportedCurrencies`, `roundCurrency`, `isSettled`, `CurrencyScope`,
  `MoneyText` (from [multi-currency-core](multi-currency-core.md))
- Decisions:
  - Cross-group totals get a per-currency breakdown rather than conversion to a personal home
    currency -> home currency has essentially no evidenced demand (4 votes); the breakdown is honest,
    free, and needs no rate source.
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
- Units:
  - Retire the home-currency surface: delete the conversion helper, the rate service, the provider,
    the settings row, both ARB key pairs and the two test files; drop the pubspec dependency added
    for it if nothing else uses it.
  - Per-currency breakdown for the overall balance hero, the friend balances and the personal
    statistics figures, replacing the converted totals at the same three call sites.
  - Currency-correct settled classification, including the server-side active/done group filter.
  - Group-currency lock (`canChangeGroupCurrency`) wired into the existing picker's disabled state.
  - Correct decimal digits per group row for 0-decimal currencies.
  - PayPal.me link currency.
- Blockers: —

## Approach
The removal is the first move and should be its own commit inside the feature — deleting the
conversion layer before building the breakdown keeps the two models from coexisting even briefly in
the diff, and makes the "did we miss a call site" question answerable by the compiler.

Three aggregation points span groups and currently **convert**: the overall balance hero (a view-model
fold, the easy one), the friendship balances (folded inside the repository, so either the currency is
injected there or the fold moves out to a view model), and the personal statistics notifier. Each
becomes a per-currency fold. The monthly trend series has no group dimension at all and so cannot be
broken down without changing the RPC — expect that to need an explicit answer at pull time; it is the
one place where "just don't convert" is not a local change.

The active/done group tabs filter server-side on `total_share_amount` against a hardcoded ±0.01 in a
PostgREST query. With per-group currencies that threshold is no longer uniform, so the classification
has to either travel with the group's currency or move behind an RPC. Whichever way it goes, the tabs
and the rows must agree.

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
- Depends: multi-currency-core
- Parallel-with: —

status: planned
