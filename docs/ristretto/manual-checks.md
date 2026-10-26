# Manual checks

Deun's Supabase instance is **self-hosted** and is not reachable from the build. Migrations in
`supabase/migrations/` are therefore *authored* by feature work but **never applied** by it — they
are applied by hand, by Jakob, against the live instance.

This file is the queue. A feature that needs a schema or RPC change appends an entry here as part of
its own work, and does not treat the change as done until the entry is ticked off.

A check line reads `- [ ] **proves** · <criterion> · <what was out of reach> · <what to do>`. The
third slot is the reason the build could not reach it — on this project almost always the
self-hosted instance.

## The rule features follow

A feature that needs a database change **must still run through green**. It does that by:

1. Writing the migration into `supabase/migrations/` with a timestamped filename. Never editing an
   already-applied migration — always a new one.
2. Writing its Dart against the post-migration shape, with tests that use fakes, fixtures or models
   rather than a live connection. The gates (`dart format`, `flutter analyze`, `flutter test`) do not
   touch a database, so this passes.
3. Marking every acceptance criterion that cannot be observed without the applied migration as
   **`[human]`** in its plan, so the difference between "tested" and "assumed" stays visible.
4. Appending an entry below saying exactly what to run and how to confirm it worked.

A feature is **done** when its gates pass. An open entry here does **not** hold its roadmap row open,
and `code-complete` is no longer a status — it stalled every dependent feature behind hand-applied
work and cost a full brew run on 2026-08-15. Mark the row `done`, add a `⚠ migration pending` marker
to it, and leave the entry here open until the migration is actually applied.

This file, not the roadmap, is the authority on what has been applied and verified. A `done` row can
carry `[human]` criteria that nobody has ever observed. Check here before shipping.

## Open

- [x] **proves** · multi-currency-expense-rate: saving stores the converted amount as the ledger
  value; provenance survives a save/reload round trip; the stored rate and converted amount are
  frozen across non-amount edits · self-hosted instance, not reachable from the build · apply
  `20260816020000_expense_entry_currency_rate.sql` — three nullable provenance columns on `expense`,
  one on `expense_entry`, one on `expense_entry_share`, and `save_expense_all` re-stated to thread
  all five. No backfill. Then verify:
  1. `select original_currency_code, conversion_rate, rate_date from public.expense limit 1;` returns
     columns (all null).
  2. `select original_amount from public.expense_entry limit 1;` and
     `select original_fixed_amount from public.expense_entry_share limit 1;` each return a column.
  3. In a EUR group, add an expense of 3000 entered in JPY at rate 0.0058; confirm
     `select amount from public.expense_entry where expense_id = '<id>';` is `17.40` and
     `select original_amount ...` is `3000`.
  4. Confirm `select conversion_rate, rate_date, original_currency_code from public.expense where id = '<id>';`
     is `0.0058`, today, `JPY`.
  5. Edit that expense's name only, save, and confirm all four values are byte-identical.
  6. Confirm `group_shares_summary` for the group totals `17.40`, not `3000`.
  7. In a EUR group, add a 4.50 CHF expense at rate 0.9432 split **exact** 1.50/1.50/1.50; confirm
     `select fixed_amount, original_fixed_amount from public.expense_entry_share where expense_entry_id = '<entry id>';`
     is `1.42` / `1.50` for the payer's row and `1.41` / `1.50` for the other two — the three
     `fixed_amount` values summing to the entry `amount` of `4.24` — then edit only its name, save,
     and confirm all three and the entry `amount` are byte-identical.
     *(Expected values corrected 2026-09-11. They previously read `1.41` per row against an entry of
     `4.23`, which no code path produced: the entry converted as a line to 4.24 while the shares
     converted one by one to 4.23. The shares are now apportioned out of the converted line, so they
     sum to it — see the finding below.)*

  **Walked 2026-09-11, migration applied. All seven steps pass — closed.**
  Steps 1–6 were verified through the app rather than by SQL, so those assertions are the app
  reading the same columns rather than the query itself. Step 7 was run as SQL against the live
  instance after the defect it found was fixed.
  - Steps 1–2: provenance saves and reloads without error, so the five columns exist.
  - Steps 3–4: 3000 entered in JPY at 0.0058 in a EUR group stored €17.40 and the read view shows
    "¥3,000 as entered · Rate 0.0058 · 11.09.2026" — converted amount, original amount, original
    currency, rate and rate date all correct.
  - Step 5: renaming the expense left €17.40, ¥3,000, 0.0058, the date and all three €5.80 shares
    untouched. Nothing recomputed.
  - Step 6: the group balance moved by exactly the converted value — `−6.67 + (17.40 − 5.80)` =
    €4.93 — so the summary totals 17.40, not 3000.
  - **Step 7 failed, was fixed, and now passes — confirmed by SQL against the live instance
    (Jakob, 2026-09-11).** Two expenses, both 4.50 CHF at 0.9432 split exact 1.50/1.50/1.50 in a EUR
    group, one written before the fix and one after:

    | name | entry_amount | shares_sum | unallocated | verdict |
    |------|--------------|------------|-------------|---------|
    | CHF-Exact (pre-fix) | 4.24 | 4.23 | 0.01 | FAIL |
    | Exact-Fixed (post-fix) | 4.24 | 4.24 | 0 | PASS |

    The verdict is `sum(fixed_amount) = amount` on `numeric` — exact equality, not a tolerance. The
    pre-fix row still showing the gap is what makes this discriminating rather than merely green:
    the only difference between the two is which code wrote them.
  - Not run, and not required by the criterion: the per-row 1.42/1.41 distribution (implied by the
    exact sum, and observed on screen), the rename-fingerprint freeze for this particular row (the
    freeze itself is proven by step 5 on the JPY expense), and the sweep for pre-fix rows elsewhere
    in the database. The sweep is worth a glance if you ever want to know whether this reached real
    data — nothing recomputes a saved expense, so those rows do not heal themselves. They cost
    nobody money: balances derive from `percentage`, not `fixed_amount`.

- [x] **proves** · group-member-removal: editing a group without touching its members leaves the
  roster and favourites intact (the one non-deferred write-path criterion, which has no unit
  coverage) · self-hosted instance, not reachable from the build · edit a group without touching its
  members (e.g. rename it), save, then confirm no `group_member` row disappeared and every
  `is_favorite` survived. Also confirm a settled member with history soft-removes with an identical
  `groupSharesSummary`, and one with no history is deleted outright.
  - Walked 2026-09-11 on the emulator against the live instance, all three parts pass. Renaming
    `USD-Check` left all three members and the group's filled star intact and the balance at $7.00.
    A guest with no history (`Ghost`) vanished outright — no "Removed" section. A settled member
    with history (`Trio`) soft-removed into "Removed" with "Add back", and the balance stayed
    $4.00 either side of the save.
  - Also observed, not in the criterion: removal has a **third** outcome. Removing a member who
    still owes is refused — "Trio still has $12.00 outstanding in this group. Settle up first, then
    remove them." Worth knowing the blocked path is real and reachable, not just soft/hard.

- [x] **proves** · settle-residue: settling leaves no rounding remainder, and a partial payment
  inserts exactly the amount paid · self-hosted instance, not reachable from the build · settle a
  10.00 expense split three ways and confirm every member's `total_share_amount` is exactly `0`, in
  both default and simplified groups; then confirm a partial payment (5.00 against a 12.00 debt)
  still inserts exactly 5.00.
  - Walked 2026-09-11 on the emulator, both halves pass. A $10.00 expense split three ways settled
    to "Settled up · $0.00 · You're all settled up" after both members paid the $3.33 the app
    itself displayed — the indivisible cent does not strand the group. A 5.00 payment against a
    12.00 debt left exactly $7.00, hero and row agreeing.
  - Checked in a **simplified** group only; the default-mode half of the criterion is still
    unobserved.

- [x] **proves** · group-currency-persist: a group's chosen currency is stored, and existing groups
  are untouched (every criterion in that plan needs the database — the feature is a migration with no
  Dart) · self-hosted instance, not reachable from the build · create a group picking USD and check
  `select currency_code from public."group" where id = '<id>';` returns `USD`; then confirm
  `select currency_code, count(*) from public."group" group by 1;` still shows the 110 pre-existing
  groups as EUR.
  - Walked 2026-09-11: a group created picking USD reads back in USD, and still does after a cold
    app restart, so it is coming from the row and not from local state.
  - **The second query was not run.** The three pre-existing groups visible on this account kept
    their own currencies (CHF, CHF, EUR) across the new group's creation, which is evidence but not
    the census. Run the `group by` once if the 110-row claim matters.

- [x] **proves** · multi-currency-rate-source: rates are fetched through a Supabase Edge Function
  rather than directly from the client, so the web build is unaffected by CORS or by the provider
  changing hostnames · Edge Function must be deployed to the self-hosted instance, which updates by
  force-recreate rather than in place · deploy `supabase/functions/exchange-rate/` (force-recreate,
  not an in-place update). It needs outbound network access to `api.frankfurter.dev` and no secrets
  — the source has no API key. Then verify:
  1. A weekday: in a EUR group, add an expense dated a recent **Tuesday** and pick CHF. The rate
     field fills on its own and the line under it reads "Rate for" that same Tuesday.
  2. A weekend: change that expense's date to the following **Saturday**. The field refills and the
     line names the **Friday** — the day the rate was actually published, not the Saturday. This is
     the whole point of returning the effective date; a Saturday shown here means the function is
     echoing the request.
  3. A future date: change the date to next month. The field empties and "No rate available for this
     date. Enter it manually." appears. It must **not** silently fill with today's rate.
  4. Typing a rate over any of the above and saving stores the typed rate, and the read view shows
     it with the date it was attributed to.
  5. Cache: repeat step 1 twice for the same pair and date. The second is served from the function's
     in-memory cache — confirm in the function logs (the cached response carries `"cached": true`),
     not by timing.
  6. **Web build specifically** (this is the criterion): run the web build, repeat step 1 in a
     browser, and confirm the browser console shows no CORS error and the rate arrives. A
     client-side fetch is what this design exists to avoid, so the web path is the one that proves
     it.
  7. Offline: put the device in airplane mode, pick a foreign currency, and confirm the same visible
     explanation as step 3 and that a manually typed rate still saves.
  8. Every supported currency: the in-repo sweep runs against a hand-authored table, so it proves
     the client resolves all 31 codes, not that the provider quotes them. Call the deployed
     function once per code — `for c in USD JPY BGN CZK DKK GBP HUF PLN RON SEK CHF ISK NOK TRY AUD
     BRL CAD CNY HKD IDR ILS INR KRW MXN MYR NZD PHP SGD THB ZAR; do` … `{"base":"$c","quote":"EUR",
     "date":"<a recent Tuesday>"}` — and confirm each returns a `rate`. Any code that returns
     `no_rate` is a currency the app offers and the prefill silently cannot serve: record which.
  9. **Timezone** (the bug the review caught): the client sends the DEVICE's local date and the
     function's clock is UTC, so the future-date refusal carries one day of slack. Set the device to
     Asia/Tokyo, set the clock to 08:00, and add a same-day expense in a foreign currency. The rate
     must fill. Before the slack existed this returned "No rate available for this date" for every
     user east of UTC during their morning — if you see that, the deployed function is the old one.

  **Walked 2026-09-11, steps 1/2/3/5/8/9, against the live function.** Not assumed — the instance
  answers HTTPS from the build machine, so these were executed with `curl` and these are the
  responses. The box stays unticked: steps 4, 6 and 7 need the app, a browser and a device, and
  ticking is Jakob's signature, not mine.
  - 1 · Tuesday 2026-09-08, CHF→EUR → `{"rate":1.061,"date":"2026-09-08"}`.
  - 2 · **The discriminating one.** Saturday 2026-09-05 → `{"rate":1.0633,"date":"2026-09-04"}` —
    Friday's date, not an echo of the request. A deployment echoing the request back fails here.
  - 3 · 2026-10-15 → `{"error":"no_rate"}`. No silent substitution of today's rate.
  - 5 · NOK→EUR 2026-09-08 twice → identical rate, second carries `"cached":true`.
  - 8 · **30 of 31 codes resolve. `BGN` does not** — see the open finding below.
  - 9 · UTC+1 day → `{"rate":1.0581,"date":"2026-09-11"}` (allowed, and labelled with the real
    publication day, so the slack is visible rather than silent). UTC+2 days → `{"error":"no_rate"}`.
  - Also: `XYZ` → `unsupported_currency`, `"not-a-date"` → `bad_date`.

  **Steps 1, 2 and 4 re-walked in the app** (emulator-5554, debug build of this branch, live
  function), 2026-09-11:
  - Group `EUR-Test`, new expense GBP 100.00. Picking GBP filled the rate on its own with
    `1 GBP = 1.1653` under a `Rate for Today` line and a live `= EUR 116.53` preview. No
    `Clear saved rate` button appeared — a prefill is correctly never remembered.
  - Changing the date to **Saturday 5 Sep** refetched: the rate moved to `1.1642` and the line
    read **`Rate for 4 Sep`** — the Friday. Step 2 through the UI, not just the wire.
  - Saved. The ledger row reads `EUR 116.42` over `GBP 100.00`; the read view's provenance block
    reads `Entered as GBP 100.00` and `Rate 1 GBP = 1.1642 EUR · 04.09.2026` — the **effective**
    date frozen on the row, not the expense's own 5 Sep. Splits 38.81 / 38.81 / 38.80 = 116.42.
  - Left behind: one expense named `RateSource-Check` in `EUR-Test`, which moved that group's
    balance from EUR 10.59 to 88.20. Delete when the test data is next cleared.
  - CHF still had a saved rate of 0.9432 from August, and it correctly shadowed the prefill — no
    fetch, no `Rate for …` line. The precedence is by design: a remembered rate is one the user
    typed, so it wins.
  - **A defect that walk missed, and Jakob found: `Clear saved rate` did not then fetch.** The
    field just emptied. Re-walked after the fix on the same emulator: with a saved 0.95 showing,
    tapping `Clear saved rate` now fills `1 CHF = 1.0581` under `Rate for Today` with a
    `= EUR 105.81` preview, and the button disappears. Fixed in `2d6caf7`; the editor test suite
    covers it as "clearing a saved rate fetches a fresh one".

  **Closed 2026-09-14 — Jakob: the function is deployed to the self-hosted instance and working.**
  That is the tick: the criterion is that rates arrive through the Edge Function rather than a
  client-side fetch, and they do, in the running app against the live deployment.
  - What that confirms, beyond the 2026-09-11 walk: the deploy itself went through by
    force-recreate and the deployed code is the current one (step 2 and step 9 above both
    discriminate old deployments, and both passed against it).
  - **Steps 6 and 7 were not separately reported and stay unobserved.** Step 6 is the web build in
    a browser with the console open — the CORS half of the criterion is argued from the design
    (the client no longer fetches the provider directly) rather than watched. Step 7 is airplane
    mode. Neither blocks anything; both are worth ten minutes before the next web deploy.
  - The `BGN` finding below is untouched by this and stays open.

- [ ] **fix** · multi-currency-rate-source: **`BGN` has no rate from 2026 onward.** Found by step 8.
  `{"base":"BGN","quote":"EUR"}` returns `upstream_error` for 2026-06-01 and 2026-09-08, but
  succeeds for 2025-11-14 and 2024-06-14 — both at exactly `0.5113`, the fixed lev peg. The provider
  answers `{"message":"not found"}`, consistent with Bulgaria having adopted the euro and the ECB
  having stopped publishing the reference rate; the cutoff is somewhere between those dates and was
  not narrowed further. Two decisions, neither urgent — a user picking BGN today gets the visible
  manual-entry fallback, never a wrong rate:
  1. Whether `BGN` stays in `kSupportedCurrencies`. Historical BGN expenses still resolve, so
     removing it would break dates that currently work.
  2. The function returns `upstream_error` (502) where it should return `no_rate` (404): a 404 from
     the provider means "no rate for this pair", not "the provider is broken". User-invisible — the
     client maps both to null — but it misreports the cause in the function logs, which is where
     anyone would look next.

- [ ] **proves** · group-member-add-flow: a member added by one client appears on another client's
  open group detail through the existing realtime path · needs two live clients against the
  self-hosted instance, which the build cannot reach · open the same group's detail page on two
  signed-in clients (emulator + web build is enough). On client A open Members and add someone.
  Without touching client B, confirm its roster and its hero avatar stack gain the new member
  within a few seconds. Then remove them on A and confirm B drops them again — same channel, and
  the removal half was already walked on 2026-09-11, so a working removal with a stuck add points
  at `addMember`'s `update_group_member_shares` call, not at the subscription.

- [ ] **proves** · payback-row-delete: deleting a payback row leaves `group_shares_summary` agreeing
  with the ledger — the settlement is reopened, not merely hidden · the row is written by the
  `pay_back` RPC and removed by a plain row delete; only the live self-hosted instance can show what
  the derived summary does afterwards, and the build cannot reach it · **no migration to apply** —
  this is a verification walk only. In a throwaway test group (never real data): note the balance
  and each member's share, record a payment, confirm the balance moves, then tap the green PAYMENT
  row in the ledger and delete it from the sheet. Confirm (1) the row disappears from the ledger,
  (2) the group balance and every member's share return to *exactly* the values noted before the
  payment, and (3) `select paid_by, paid_for, total_share_amount from public.group_shares_summary
  where group_id = '<id>';` carries no leftover row from the deleted payback. Repeat once for a
  payback recorded **on someone else's behalf** (payer ≠ you) — it must behave identically, with no
  special case. If any share is stale, the delete needs its own RPC and this feature is not small.

- [ ] **proves** · realtime-channel-lifecycle: live updates and claim presence still arrive through
  the refactored channel code, before and after a background/resume · out of reach: the live
  self-hosted realtime server (api.deun.app) and a real OS pause/resume (`supabase.removeAllChannels`
  on pause); no test runs `SupabaseRealtimeChannelFactory`, the adapter behind the seam · what to
  do: in a throwaway test group (never real data), sign a phone (A) and a second client (B; a web
  build is enough) into the group. Open the group ledger on A, add an expense on B, and check it
  appears on A without a refresh. Background A for about a minute, resume it, add another expense on
  B, and check it appears. Open the same itemized expense's claim screen on A alone: it says 1
  person claiming. Join on B (2), then leave on B (1). Background and resume A on the claim screen
  and check it still says 1 while B is away.

- [ ] **proves** · realtime-event-scope: the group list's filtered channels deliver insert, update
  and delete events, and a group the user is added to appears and goes live without a refresh ·
  out of reach: the self-hosted realtime server on api.deun.app (`supabase/realtime:v2.34.7`:
  whether it accepts in-filters with quoted values) and the unapplied migration; no test runs
  `SupabaseRealtimeChannelFactory` · ⚠ **do not apply yet** — open security finding in
  plans/realtime-event-scope.md (publishing `group_member` broadcasts every member removal's
  `(email, group_id)` to any subscriber); resolve it first. Then apply `20261025200000_realtime_event_scope.sql` as `supabase_admin`.
  Confirm by SQL that
  `select relname, relreplident from pg_class where relname in ('group_update_checker', 'friendship');`
  shows `f` for both and that
  `select tablename from pg_publication_tables where pubname = 'supabase_realtime';` lists
  `group_member`. Then, in throwaway test groups only (never real data), sign a phone (A) and a
  second client (B; a web build is enough) into two accounts that share group G, with A on the
  group list. Add an expense in G on B: A's row for G changes without a refresh. On B, create group
  H and add A: H appears in A's list without a refresh. Add an expense in H on B: A's row for H
  updates. Add an expense on B in a group A is not in: A's list does not change. Delete G on B: G
  leaves A's list without a refresh. Background A for about a minute, resume, and repeat one
  expense add.

- [ ] **proves** · realtime-event-scope: the friend list's two filtered friendship channels deliver
  insert, update and delete events · out of reach: the self-hosted realtime server on api.deun.app
  (eq filters on `friendship`; deletes that need replica identity full) and the unapplied migration
  · with the migration above applied and A on the friends tab, using two test accounts: have B send
  A a friend request — A's pending count rises without a refresh. B cancels — it falls back. B sends
  again and A accepts — B's friend list shows A without a refresh. B removes the friendship — A's
  list drops B. Add an expense on B in a throwaway group A and B share: A's balance with B updates
  after about 2 s.

- [ ] **proves** · push-session-lifecycle: after user A signs out in Settings, A's device_tokens row
  for this device's token is gone and pushes to A stop arriving there; after B signs in on that
  device, B's push arrives and one tap opens its target once · out of reach: real FCM delivery to a
  physical device and the self-hosted instance api.deun.app; no test runs `FirebasePushMessaging`
  or `SupabaseDeviceTokenStore`, the adapters behind the seams · on an Android or iOS device signed
  in as A (test accounts only), note A's user id and the device's token in device_tokens (read only).
  Sign out in Settings and confirm that row is gone. If it survives, record it under Findings: the
  stopgap's owner-only policy admits the owner's delete (supabase/tests/rls_stopgap
  'sign-out deletes own token'), so a surviving row means the unregister never ran. Have B add an
  expense in a group shared with A from another device and confirm nothing reaches the signed-out
  device. Sign in as B on it, have A add an expense in a shared group, and confirm B's notification
  arrives and one tap opens the expense once.

- [ ] **proves** · push-session-lifecycle: after an account is deleted on a physical device, no
  device_tokens row remains for that user and that token · out of reach: the live instance (the
  dump of 2026-10-24 shows the `auth.users → device_tokens` cascade; this confirms it on a real
  account) · create a throwaway account on a device, confirm its device_tokens row exists (read
  only), delete the account in Settings, then confirm no row remains for that user id or token.

- [ ] **proves** · expense-search-escape: searching a group for `50%`, `a_b`, `a*b`, `(1`, `[`,
  `\`, `TAXI` and `müller` returns exactly the expenses whose names contain that text (case
  ignored), with no error · out of reach: api.deun.app (its PostgREST version, Postgres regex engine
  and locale) is unreachable from the build · in a scratch group, add expenses named "50% off",
  "500 EUR", "a_b", "axb", "a*b", "a long b", "Taxi (1)", "Café Müller" and "C:\temp". Search for
  `50%`, `a_b`, `a*b`, `(1`, `[`, `\`, `TAXI` and `müller`. Confirm that each search returns exactly
  the names containing that text (case ignored) and that no error is shown.

- [ ] **proves** · guest-merge-rpc: invite-link joins (with or without claiming a guest) work on the
  live instance — the app has no fallback, so every join fails until this is applied · out of
  reach: the self-hosted instance (migration unapplied) · apply
  `20261026100000_join_group_guest_merge.sql` as `supabase_admin`, after `20261025190000`, BEFORE
  releasing any build containing guest-merge-rpc. Confirm by SQL that
  `select proname, prosecdef from pg_proc where proname in ('join_group', 'group_join_guests', 'lock_group_member_writes');`
  lists all three, with `prosecdef` true only for `group_join_guests`. Behaviour is already proven on
  the local harness (`supabase/tests/rls_stopgap/40_join_group_cases.sql`, 14/14): scoped merge,
  second group untouched, orphaned-guest delete only, outsider and soft-removed re-join under the
  live policies, refusals, colliding share rolls the join back.

- [ ] **proves** · payback-atomic-recalc: a payback recorded from the app settles the group's
  balance in the same transaction as the payback row. The app no longer recalculates on its own,
  so until this is applied every payback leaves the balance stale until the next write · out of
  reach: the self-hosted instance (migration unapplied) · apply
  `20261026120000_pay_back_atomic_recalc.sql` as `supabase_admin` BEFORE the client change reaches
  main (a push to main deploys the web build). Confirm by SQL that
  `select position('update_group_member_shares' in pg_get_functiondef('public.pay_back(uuid,text,text,numeric)'::regprocedure)) > 0;`
  returns true. The behaviour is already proven on the local harness
  (`supabase/tests/rls_stopgap/50_pay_back_cases.sql`, 4/4; 0/4 before the migration). The
  payback, its balances and both checkers commit together, through `pay_back` and
  `pay_back_exact`. A rolled-back payback leaves neither the row nor a balance change, and a
  failed recalculation leaves no payback.

- [ ] **proves** · group-write-rpcs: adding and removing a member, deleting a group and deleting an
  expense (payback rows included) each commit as one server transaction. The app has no fallback,
  so until this is applied every add, removal, group delete and expense delete fails with its error
  snackbar · out of reach: the self-hosted instance (migration unapplied) · ⚠ first read the open
  security finding in plans/group-write-rpcs.md (`remove_group_member` takes table-wide SHARE locks
  that stall expense writes in every group) and decide whether to fix it before applying · apply
  `20261026140000_group_write_rpcs.sql` as `supabase_admin`, after `20261026100000` (it calls
  `lock_group_member_writes`), BEFORE releasing any build containing group-write-rpcs (a push to
  main deploys the web build). Confirm by SQL that
  `select proname, prosecdef from pg_proc where proname in ('add_group_member', 'remove_group_member', 'delete_group', 'delete_expense');`
  lists all four, each with `prosecdef` false. Behaviour is already proven on the local harness
  (`supabase/tests/rls_stopgap/60_group_write_cases.sql`, 21/21; 2/21 before the migration): add
  inserts, re-adds on the same row and leaves an active member alone; removal blocks an unsettled
  member (owing or owed) with no change, soft-removes a settled member with a payment or a share
  while no balance moves, hard-removes one whose only history is in another group, and holds the
  member-write lock and the `share` locks on `expense` and `expense_entry_share`; expense and
  payback-row delete return every balance exactly with no leftover summary row; group delete takes
  the group and its checker row; a failed recalculation rolls each write back. If a removal fails
  with a permission error on `lock table`, `authenticated` lacks UPDATE/DELETE/TRUNCATE on
  `expense` or `expense_entry_share` (the 2026-10-24 dump grants ALL). Cross-client delivery is the
  existing realtime path: once applied, the open group-member-add-flow, payback-row-delete and
  realtime-event-scope walks make the same observations through these RPCs.

## Findings from verification

Defects turned up while walking the checks. These are not checks themselves — nobody ticks them —
they are recorded here because this file is what gets read before shipping. Each needs a roadmap row
of its own before it can be worked.

### The settle-up hero disagrees with the rows beneath it

Found 2026-09-11, reproduced in a clean group. A $10.00 expense split three ways shows
**"You're owed overall $6.67"** above rows reading **$3.33 + $3.33 = $6.66**. The same shape appears
at €75.01 over three €25.00 rows, and at CHF45.00 against seven CHF6.43 shares.

The cause is where the two numbers come from. The hero rounds the accumulated balance once; each row
is its own `groupSharesSummary` entry, rounded on its own. Sub-minor-unit residue therefore survives
in the total but not in the parts, and the two disagree by a minor unit.

**Not a dead end, and not data loss.** Paying the displayed per-person amounts settles the group to
exactly $0.00 — because the settle path carries a sub-minor-unit tolerance. The harm is a user
reconciling by hand and finding the column doesn't add up.

**Conservation was tested directly, because "does the cent vanish" is the question that matters.**
A group carrying four stacked uneven splits — 10.00, 20.00, 0.05 and 100.01, every one of them
divided three ways — accumulated to €86.71 owed against rows of €43.35 + €43.35. Both members paid
the €43.35 the app displayed and the group closed on **exactly €0.00**, confirmed independently on
two devices on 2026-09-11. Residue does not accumulate across expenses and no run of awkward splits
strands a balance.

`test/model/expense_detail_view_model_test.dart` pins the invariant that makes this true: across 48
combinations (eight awkward totals x six group sizes) every expense's shares sum to its total and
the members' nets cancel, with the running net over the whole run at zero. A change that started
leaking a fraction would fail there rather than in somebody's group.

Who carries the indivisible unit is decided, not incidental: **the payer does** (Jakob, 2026-09-11).
They are already fronting the money, and the first implementation broke the tie on the member's key,
which would have quietly taxed whoever's address sorted first in every group they were in. The rule
is a tie-break only — a member with a genuinely larger discarded fraction still has the better claim,
so the payer never distorts an uneven split. A payer who holds no share in the expense absorbs
nothing, since there is nothing of theirs to absorb it with.

**Client-side is already fixed; the server half is not.** `buildMemberBreakdown` now apportions with
`apportionCurrency`, so an expense's own breakdown sums to its total (commit `4e26d5f`). The
settle-up figures are a different path: they come from the server view `group_shares_summary`, which
`Group.amountToSettleWith` reads already-rounded. Fixing that means changing the view on the
self-hosted instance — a schema change, not a Dart change, which is why it is parked here rather
than done.

### A converted exact split left a cent unallocated — FIXED and CONFIRMED

Found 2026-09-11 by step 7 of the expense-rate check — the check did its job. Fixed the same day in
`ledgerFixedAmounts` (`expense_conversion.dart`): an exact split's ledger amounts are now
apportioned out of the already-converted line instead of each share converting on its own, so they
sum to the entry by construction, with the payer carrying the indivisible unit as everywhere else.
An identity conversion still returns the typed numbers untouched — only a conversion earns the right
to reshape someone's exact split.

**What is not yet proven:** `saveAll` writes to Supabase, so no test calls it and the ~15 lines
wiring the new function into the save path are covered by the analyzer and by the pure function's
own tests, not by an executed save. Running step 7 once against the live instance closes that gap —
it is the only thing between this and done.

The original diagnosis follows, kept because it explains why the two numbers ever differed.

A 4.50 CHF expense at 0.9432 in a EUR group, split **exact** 1.50/1.50/1.50, stores an entry
`amount` of **4.24** but three `fixed_amount` values of **1.41**, summing to **4.23**.

**No money is lost by this, and balances are not affected.** Every ledger figure — client and
server — is derived from `percentage`, never from `fixed_amount`: the server's
`group_shares_summary` and `update_group_member_shares` both sum
`ee.amount * (ees.percentage / 100)`, and the client's `groupMemberShareStatistic` does the same.
Percentages sum to 100, so the shares sum to the entry. `fixed_amount` is the entry-currency twin
kept so the editor can reload an exact split without inverting the conversion — provenance, not
money. The defect is that the two representations of the same split disagree by a minor unit, which
will bite whoever next treats `fixed_amount` as authoritative.

The two halves convert by different rules, both deliberate in isolation:
- `expense_repository.dart:314` converts each exact share on its own — `conv.toLedger(1.50)` = 1.41.
- `expense_repository.dart:241` converts the line once — `ledgerLineTotal(4.50)` = 4.24.

`4.50 × 0.9432` is 4.2444, which rounds up; `1.50 × 0.9432` is 1.4148 three times, which rounds down
three times. Nothing reconciles them.

The check's own expected value (entry `amount` 4.23) is what the code *should* produce if the entry
total were the sum of its converted shares, and disagrees with the 4.24 the code actually writes —
so either the entry total should be derived from the shares for an exact split, or the shares should
be apportioned across the converted total. That is a product decision, not a mechanical fix.

The read view does not show this, because it derives shares from `amount × percentage` and now
apportions them: it displays 1.42 / 1.41 / 1.41 summing to the 4.24 header. The stored
`fixed_amount` values are 1.41 / 1.41 / 1.41. **The screen and the rows disagree**, which is the
part most likely to bite later.

### Minor: the expense read view does not refresh after its own edit

Saving a rename from the expense editor returns to the read view still showing the old title; the
group ledger behind it is correct, and reopening the expense shows the new one. Cosmetic, one line
of state, noted so it is not rediscovered.

## Applied

| Feature | What was applied | Date |
|---------|------------------|------|
| — | `20260815000000_baseline_ledger_functions.sql` — baseline only, reproduces the functions already live, safe to skip | not required |
| group-member-removal | `20260815010000_group_member_removal.sql` — `group_member.removed_at`, the `update_group_member_shares` counterparty semi-join fix, and `save_group_all` no longer deleting absent members. Applied by Jakob against the live instance. | 2026-08-16 |
| settle-residue | `20260815020000_settle_residue_exact_payback.sql` — adds `pay_back_exact`; `pay_back` unchanged. Applied by Jakob against the live instance. | 2026-08-16 |
| group-currency-persist | `20260816000000_group_currency_code_persist.sql` — `currency_code` added to `save_group_all`'s UPDATE SET and INSERT column list; no backfill. Applied by Jakob against the live instance. | 2026-08-16 |
| payback-on-behalf | `20260816010000_payback_on_behalf.sql` — `pay_back` gains payer≠payee + both-current-member validation and records `auth.uid()` into `expense.user_id`. Applied by Jakob against the live instance. | 2026-08-16 |
| multi-currency-expense-rate | `20260816020000_expense_entry_currency_rate.sql` — the five provenance columns and `save_expense_all` re-stated to thread them. Applied by Jakob against the live instance. Steps 1–6 of its check then passed; step 7 failed, was fixed in `9bcd1bf`, and was re-verified by SQL the same day — all seven now pass (see Findings). | 2026-09-11 |
| multi-currency-rate-source | `supabase/functions/exchange-rate/` — not a migration: the Edge Function, deployed by force-recreate to the self-hosted instance by Jakob. Confirmed working from the app. Steps 6 and 7 of its check remain unobserved; the `BGN` finding remains open. | 2026-09-14 |
| rls-hardening (stopgap) | `20261025180000_rls_stopgap.sql` — anon revoked; RLS on device_tokens, expense_entry, expense_entry_share, group_shares_summary, birthday_signup; scoped user and group_member writes; `is_group_member()`. Applied by Jakob as supabase_admin. Verified from outside: anon gets 401 on every table. Rollback: `supabase/migrations/rollback/20261025180000_rls_stopgap_rollback.sql`. | 2026-10-25 |
| rls-hardening (push stopgap) | `push` Edge Function: caller from the bearer token (401 otherwise), receivers filtered to co-members and friends (403 if none). Deployed by force-recreate; backup at /root/push_index.ts.bak-20261025. Verified: 401 without a login and with the anon key. Source still not in the repo (push-server-compose). | 2026-10-25 |
| rls-hardening (stopgap follow-up) | `20261025190000_rls_stopgap_followup.sql` — group_member reads limited to own groups and own rows (no more listing every group id and joining any group); UPDATE granted per column (group_member: is_favorite, removed_at; user: profile fields); orphaned-guest delete via SECURITY DEFINER `has_any_membership()`. Found by a security review of the stopgap. Applied by Jakob as supabase_admin; verified read-only in pg_policies and column_privileges. Local tests 75/75. Known cost: non-members see no guests on the join page until guest-merge-rpc. | 2026-10-25 |

The migrations above are **applied**, which is what unblocked the dependent features. Their numbered
verification steps have **not** been reported as run — that is what the corresponding open `proves`
lines above are for.

## Known deferred work by feature

Recorded at prep time so the size of the manual tail is visible before anything is pulled.

- **settle-residue** — client half (unify the three settled thresholds, make the two client roundings
  consistent) needs no database work and is fully testable. The server half — making the settled
  amount the exact outstanding value rather than a client-rounded one — is
  `supabase/migrations/20260815020000_settle_residue_exact_payback.sql`, which adds `pay_back_exact`
  (delegating the insert to the untouched `pay_back`), and is deferred.
- **group-member-removal** — needs `group_member.removed_at timestamptz null`, and a fix to
  `update_group_member_shares` so its `total_share_amount` subquery joins `group_member` (today it
  does not, which is the ghost-share bug). Both deferred. All client logic and the pure
  `resolveMemberRemoval` decision function are testable without them.
- **payback-on-behalf** — the core capability needs **no** migration: `pay_back` already accepts
  `_paid_by` as a parameter and the restriction is one hardcoded line in the client. Only the
  validation (payer ≠ payee, both current members) is deferred.
- **multi-currency-expense-rate** — `supabase/migrations/20260816020000_expense_entry_currency_rate.sql`
  adds `expense.original_currency_code`, `expense.conversion_rate`, `expense.rate_date`,
  `expense_entry.original_amount` and `expense_entry_share.original_fixed_amount`, and re-states
  `save_expense_all` to thread them. The rule behind the two amount columns: every money column the
  editor reloads into a field needs an entry-currency twin, because the field holds entry-currency
  amounts and the column holds the converted ledger value. Deferred. All
  conversion arithmetic, freezing, switch-back and the no-implicit-rate guard are pure functions and
  are fully covered without a database. Read paths tolerate the pre-migration schema: the expense
  select is `*`, so the absent columns simply read null, and the currency-lock probe swallows the
  undefined-column error and reports "unlocked".
- **multi-currency-rate-source** — needs a Supabase Edge Function deployed to the self-hosted
  instance. Deferred; note that edge functions on this instance update via force-recreate.
- **multi-currency-core**, **multi-currency-group**, **group-form-field-structure**,
  **group-create-simplify**, **expense-delete-settled-guard**, **expense-notification-route**,
  **expense-editor-edit-labels** — no database work at all. The active/done group filter that
  `multi-currency-group` touches is built client-side in `GroupRepository.fetchData`, not in a view,
  so changing its threshold is a Dart change.

## Retired — not tracked by ristretto

Rollout steps from an older format. ristretto no longer reads this section;
keep or delete it as you like.

- [ ] **deploy** · — · live build · until the branch ships, the live app still removes members by
  omission through `save_group_all`, which the `group-member-removal` migration made a no-op. Member
  removal from the group edit form will silently do nothing on the currently deployed build.
