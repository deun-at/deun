# Ristretto Roadmap
<!-- ristretto-format: 0.22 -->

> **Database changes are authored, never applied.** The Supabase instance is self-hosted and
> unreachable from the build, so features write their migrations and defer application to
> [manual-checks.md](manual-checks.md). Gates (`dart format`, `flutter analyze`, `flutter test`) touch no
> database, so a DB-coupled feature still runs through green — but a criterion marked `[human]`
> in its plan is **assumed, not tested**.
>
> **A row goes `done` when its gates pass.** A pending migration does **not** hold it open, and
> `code-complete` is no longer a status — it stalled every dependent feature behind work that only
> Jakob can do by hand, which cost a whole brew run on 2026-08-15. The unapplied-migration fact is
> still recorded, in the two places where it does its job: an open entry in
> [manual-checks.md](manual-checks.md), and a `⚠ migration pending` marker on the row here. What changed is
> that it no longer gates automation.
>
> The trade this makes, explicitly: `done` now means "built and green", not "verified end to end". A
> row can be `done` while its `[human]` criteria have never been observed. manual-checks is the only
> authority on what has actually been applied and checked — read it before shipping, not the roadmap.

| Flight | Feature | Title | Tier | Status |
|--------|---------|-------|------|--------|
| review-bugs | editor-failure-keeps-form | A failed save or delete keeps the expense editor and its input | normal | done |
| review-bugs | realtime-channel-lifecycle | Realtime retries never outlive or duplicate a channel | normal | done |
| review-bugs | realtime-event-scope | Group and friend lists hear only the user's own groups and friendships ⚠ migration pending | normal | done |
| review-bugs | push-session-lifecycle | Push registration lives and dies with the signed-in session | normal | done |
| review-bugs | notification-context-free | Pushes survive the screen that sent them | normal | done |
| review-bugs | group-model-parse-safety | One malformed summary row no longer breaks a group | easy | planned |
| review-bugs | scan-total-applies | A rescanned receipt total lands in the amount and is saved | normal | planned |
| review-bugs | expense-search-escape | Expense search matches what was typed, character for character | easy | planned |
| atomic-writes | guest-merge-rpc | Joining a group and claiming a guest is one group-scoped transaction | normal | planned |
| atomic-writes | payback-atomic-recalc | A recorded payback and its balance update commit together | normal | planned |
| atomic-writes | group-write-rpcs | Member add/remove, group delete and expense delete each commit as one transaction | normal | planned |
| backend-in-repo | schema-baseline | The live base schema committed as a reference baseline | normal | planned |
| backend-in-repo | legacy-fallback-removal | Writes commit through their RPC or fail, with no client-side fallback | normal | planned |
| backend-in-repo | push-server-compose | The push function writes each push for its receiver and checks who may get it | normal | planned |
| backend-in-repo | rls-hardening | The anon key reaches nothing, and only the people a row concerns can change it | normal | planned |
| structure | typed-expense-draft | The expense editor hands the repository a typed draft, not a string-keyed map | normal | planned |
| structure | expense-editor-split | The expense editor's state lives in a controller, and the screen opens in pieces | normal | planned |
| structure | injectable-repositories | One current-user source, repositories as injectable instances | normal | planned |
| structure | helper-split | helper.dart opens in pieces | easy | planned |
| structure | typed-routes | Group and expense pages open from their URL, by id | normal | planned |
| structure | presentation-file-split | The claim page and the split editor open in pieces | normal | planned |
| structure | housekeeping | Review cleanup: dead widgets, a debug-only dev route, a no-op push handler, untracked build output | easy | planned |
| — | group-form-field-structure | Group edit form: fields in a Column, not a lazy ListView | normal | done |
| — | group-member-removal | Removing a group member: defined semantics instead of a silent wipe | normal | done |
| — | expense-delete-settled-guard | Warn before deleting an expense that a payback already touched | normal | done |
| — | payback-on-behalf | Record a payback that someone else made | normal | done |
| group-membership | group-create-simplify | Group creation asks for name, mode and currency only | normal | done |
| group-membership | group-member-add-flow | Adding members as its own flow, not a form field | normal | done |
| — | settle-residue | Settling a balance leaves no rounding remainder | normal | done |
| — | expense-notification-route | Expense notifications open the read view, not the editor | normal | done |
| — | expense-editor-edit-labels | Editing an expense never says "Add expense" | normal | done |
| multi-currency | group-currency-persist | `save_group_all` actually stores the group's currency (bugfix) | normal | done |
| multi-currency | multi-currency-core | Currency value object + currency-aware money pipeline | normal | done |
| multi-currency | multi-currency-group | Per-currency cross-group totals, replacing home-currency conversion | normal | done |
| multi-currency | multi-currency-expense-rate | Per-expense entry currency with a manual, frozen rate | normal | done |
| multi-currency | multi-currency-rate-source | Historical rate prefill via a Supabase Edge Function | normal | done |
| empty-states | empty-states | One shared empty state across the app | easy | done |
| save-status | save-status-rollout | The save confirmation moves onto the button everywhere | easy | done |
| — | payback-row-delete | Undoing a recorded payment | normal | done |
| — | auth-switch-stale-providers | Invalidate user-scoped providers on user switch (bugfix) | normal | done |
| multi-currency | multi-currency-foundation | Group currency + currency-aware formatting | normal | done |
| multi-currency | multi-currency-home-aggregates | Home currency for cross-group balances & statistics (display-only) | normal | done — **retired** |
| — | itemized-expense-categories | Expense-level category for itemized expenses | normal | done |
| — | scan-split-even | Split a scanned receipt evenly | normal | done |
| — | cosmetic-round-2026-07 | Post-release alignment & polish round (7 fixes) | normal | done |
| — | tab-switch-transition | Animate home tab switches per motion spec | normal | done |
| — | keypad-calculator | Calculator in the amount keypad sheet | normal | done |
| multi-currency | expense-card-fee | A card's foreign-transaction fee, on the rates Deun looks up | normal | done |
