# settle-residue — Settling a balance leaves no rounding remainder

## Spec
- Source: idea (user bug report, 2026-08-11: "I was paying something back and then it showed that the
  person I paid back owes me 0.01 euro. I had to remove 1 cent from an expense to show the settled")
- Flight: —
- Goal: Paying someone back settles the balance exactly. No sub-cent remainder survives the
  settlement, and no screen ever asks the user to hand-edit an expense to make a balance disappear.

## Contract
- Acceptance:
  - After settling a balance with a member, that pair's balance is exactly zero and no further
    "owes you" entry appears — without editing any expense.
  - This holds for an amount that does not divide evenly into cents: an expense of 10.00 split three
    ways, then settled, leaves every pairwise balance at zero rather than at 0.01.
  - This holds in both group modes — default and simplified — and for `payBackAll`, which settles
    several groups for one friend in a single action.
  - The group detail, the payment screen, the group-list balance hero and the friend list all agree
    on whether a given balance is settled. Today they cannot: the payment screen treats anything
    under 0.005 as settled while the group list and the friendship repository use 0.01, so a 0.007
    balance is simultaneously settled on one screen and outstanding on another.
  - All settled/outstanding decisions route through one shared predicate rather than three separately
    declared epsilon constants.
  - A regression test reproduces the remainder against the pre-fix behaviour and fails without the
    fix.
  - `flutter analyze` and `flutter test` pass, with existing money-math tests unchanged in their
    expected values except where they encoded the bug.
- Provides:
  - a single settled predicate over an amount, replacing `_kSettledEpsilon` (`payment_view_model.dart`),
    `_kSettledThreshold` (`group_list_view_model.dart`) and the inline `< 0.01`
    (`friendship_repository.dart`)
  - a settlement amount derived from the exact outstanding balance rather than a display-rounded one
- Consumes: —
- Decisions:
  - Fix the remainder at its source rather than widening a threshold to swallow it -> a wider epsilon
    hides a one-cent error today and a larger one as soon as a group has many uneven splits; it also
    silently changes what "settled" means on three screens.
  - Reconcile the three thresholds now, at 2-decimal EUR, and let
    [multi-currency-core](multi-currency-core.md) later give that same predicate a `Currency`
    parameter -> the two changes compose instead of colliding, and this bug should not wait on the
    currency flight to ship.
  - The active/done group tabs also filter on a hardcoded ±0.01, but server-side in a PostgREST
    query, so it cannot share the client predicate directly. It must still agree with it; making
    them agree is in scope here even though the mechanism differs.
- Units:
  - Failing test: settle an unevenly divisible split and assert the resulting balance is exactly zero.
  - Determine which side introduces the remainder — the client rounding the balance before it calls
    `pay_back`, or `update_group_member_shares` redistributing the generated payback expense.
  - Fix it at that source so the settled amount is the exact outstanding value.
  - Collapse the three epsilon constants into one predicate and align the server-side active/done
    filter with it.
  - Verify across default mode, simplified mode and `payBackAll`.
- Blockers:
  - If the remainder originates server-side, `pay_back`, `update_group_member_shares` and the
    `group_shares_summary` rebuild are the code that has to change — and none of them is in this
    repo. They exist only on the self-hosted instance at api.deun.app, which the Supabase MCP cannot
    reach. **The user must supply those function definitions, or run a diagnostic query against a
    reproducing group, before that half can be fixed.** The client-side half can proceed regardless.

## Approach
Start by reproducing, not by patching. The client already rounds to cents at every accumulation step
in `calculateGroupSharesSummaryDefault` and its simplified counterpart, and `payBackAll` rounds again
before deciding what to settle — so the value the app *pays back* is a clean cent figure. The
question is whether the value it is settling *against* is also a clean cent figure, and there is good
reason to think it is not: an expense split three ways stores a per-member share the database
computed at full numeric precision, and paying back the rounded version of that necessarily leaves
the fraction behind. The recomputation that follows then surfaces the leftover as 0.01.

That is a hypothesis, and the plan treats it as one. Unit two exists to confirm it before anything is
changed, because the alternative cause — `update_group_member_shares` generating a fresh remainder
when it redistributes the payback expense itself — lives in different code and needs a different fix.
The user's own workaround (removing a cent from an expense to make the balance vanish) is consistent
with both, so it does not discriminate between them.

The threshold reconciliation is worth doing in the same pass even though it is not the cause. Three
constants that disagree about the same question will keep producing "settled here, outstanding there"
reports, and once [multi-currency-core](multi-currency-core.md) makes the predicate currency-aware
there needs to be exactly one place to change.

- Likely touchpoints: `lib/pages/groups/data/group_model.dart` (share accumulation),
  `lib/pages/groups/data/group_repository.dart` (`payBack`, `payBackAll`, the active/done filter),
  `lib/pages/groups/presentation/payment_view_model.dart`,
  `lib/pages/groups/presentation/group_list_view_model.dart`,
  `lib/pages/friends/data/friendship_repository.dart`, `lib/helper/helper.dart` (`roundCurrency`),
  possibly a new Supabase migration
- Depends: —
- Parallel-with: expense-notification-route, expense-editor-edit-labels

Note (2026-08-15): `multi-currency-core` now carries `Depends: settle-residue`, so these two are
sequenced rather than parallel — this bug ships first and owns the single predicate, and the currency
flight widens it afterwards. `payback-on-behalf` likewise depends on this feature: both change
`pay_back`, and it should be corrected once before it is extended.

status: planned
