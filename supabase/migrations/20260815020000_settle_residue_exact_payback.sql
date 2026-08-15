-- settle-residue (server half): settle the EXACT outstanding balance instead of
-- the cent-rounded figure the client is able to see.
--
-- Why this is still needed after the client half:
--   `update_group_member_shares` computes every share as
--   `ee.amount * (ees.percentage / 100)` with no rounding at any step, so a
--   10.00 expense split three ways leaves each share at 3.3333...  A client can
--   only settle a 2-decimal number, and `pay_back` inserts that number verbatim,
--   so `exact - round(exact)` stays behind. One counterparty's leftover is under
--   half a cent and reads settled, but a member's net is the SUM over all their
--   counterparties: with three of them the leftovers reach a visible 0.01 that
--   no further settling can clear. That is the bug reported on 2026-08-11.
--
-- `pay_back_exact` recomputes the outstanding value server-side and snaps to it
-- when the client's figure is the rounded version of it. A genuine partial
-- payment (further than half a cent from either exact value) is inserted exactly
-- as the user typed it.
--
-- `pay_back` itself is deliberately untouched, and this function delegates to it,
-- so the payback insert still exists in exactly one place -- payback-on-behalf
-- adds its validation there and gets it for both entry points.
--
-- NOT APPLIED. See docs/ristretto/MANUAL_OPS.md.

create or replace function public.pay_back_exact(
  _group_id uuid,
  _paid_by text,
  _paid_for text,
  _amount numeric
)
returns uuid
language plpgsql
as $function$
declare
  _pairwise numeric;  -- exact amount _paid_by owes _paid_for in this group
  _net numeric;       -- exact amount _paid_by owes the group as a whole
  _settled numeric;
begin
  -- A group_shares_summary row (paid_by = X, paid_for = Y).share_amount is what X
  -- paid for Y, i.e. what Y owes X. So what _paid_by owes _paid_for is the
  -- _paid_for-side row minus the _paid_by-side one: the same difference
  -- group_model.dart accumulates client-side, but unrounded.
  select coalesce(sum(
           case
             when gss.paid_by = _paid_for and gss.paid_for = _paid_by
               then gss.share_amount
             when gss.paid_by = _paid_by and gss.paid_for = _paid_for
               then -gss.share_amount
             else 0
           end
         ), 0)
    into _pairwise
  from public.group_shares_summary as gss
  where gss.group_id = _group_id
    and (
      (gss.paid_by = _paid_for and gss.paid_for = _paid_by) or
      (gss.paid_by = _paid_by and gss.paid_for = _paid_for)
    );

  -- total_share_amount is the member's net and is identical across all of their
  -- rows, so max() just picks it. Positive = they are owed, so what they owe is
  -- its negation. This is the value a SIMPLIFIED group settles against: there the
  -- pairwise figure is an assignment made by the client's greedy algorithm, not a
  -- ledger fact.
  select coalesce(-max(gss.total_share_amount), 0)
    into _net
  from public.group_shares_summary as gss
  where gss.group_id = _group_id
    and gss.paid_for = _paid_by;

  -- Snap only when the client is settling one of these in full: within half a
  -- cent means "this is the rounded version of that exact number". The pairwise
  -- candidate wins when both match, which is the default-mode case.
  if _pairwise > 0 and abs(_amount - _pairwise) <= 0.005 then
    _settled := _pairwise;
  elsif _net > 0 and abs(_amount - _net) <= 0.005 then
    _settled := _net;
  else
    _settled := _amount;
  end if;

  return public.pay_back(_group_id, _paid_by, _paid_for, _settled);
end;
$function$;
