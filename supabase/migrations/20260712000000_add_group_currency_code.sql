-- Multi-currency foundation: every group carries an ISO 4217 currency code.
-- Amounts are always stored/entered in the group's currency (the ledger never
-- converts — per-expense conversion was cut, the user's bank already converts).
-- Existing rows backfill to EUR, the app-wide default.

alter table "group"
  add column if not exists currency_code text not null default 'EUR';

-- Backfill any pre-existing NULLs defensively (the default covers new rows).
update "group" set currency_code = 'EUR' where currency_code is null;
