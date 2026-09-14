# group-membership — Design brief (by surface)

Handoff doc for the design session on group membership. Engineering contracts live in three plans
([member-removal](archived/group-member-removal.md) · [create-simplify](archived/group-create-simplify.md) →
[add-flow](archived/group-member-add-flow.md)); this file pivots them by **surface** so each screen is
designed once. Apply changes to the existing screens — don't rebuild.

**Product model (the rules everything follows):**
1. A member's ledger history is permanent. Removing someone never rewrites a past expense.
2. You cannot remove someone who still owes or is owed money — settle first.
3. Membership changes save immediately. They are not part of "saving the group".

---

## 1. Add-member flow — the main deliverable  *(no design exists yet)*
Today this is a `SearchAnchor` embedded as a form field inside group edit. It becomes its own surface.

- **Entry point:** from group detail, and from the empty state of a freshly created group.
- **Four add paths that must all survive:** existing user by username (`name#1234`), by email,
  contact suggestion from the device address book, and "create a guest" for someone who doesn't
  use the app.
- **States:** empty (no members yet, post-create) · searching · results · no results ·
  guest-name entry · add succeeded · add failed · already-a-member.
- **Decided** (design session, Jakob, 2026-09-11):
  - **A full page, not a sheet — and it is a Members page, not an add page.** Roster first, search
    at the top, remove on the row. Three things forced the page over the sheet: it is where a
    freshly created group lands, the guest sub-flow needs a second step, and the page stays open
    across several adds. A sheet holding a keyboard, a results list and a guest sub-form at once
    is the shape that goes wrong.
  - **Add and remove share the surface.** Blocked removal has to name an amount and offer a way
    out, which needs row-level room; and the roster is the only place re-adding someone is
    discoverable. This also settles surface 4: group edit links here instead of holding a field.
  - **"Create a guest" is an inline result row, not a separate button.** A search matching no user
    ends in an actionable `Create guest «Max»` row. It appears exactly when it is relevant — the
    moment search came up empty — and costs no extra navigation. A standing button would compete
    with search even when search was going to work.
  - **The page stays open across adds.** Forced by the no-batch-save rule: each add lands in the
    roster above the search field and the field clears for the next one.
- **Constraints:** each add persists on its own — no batch save, no "done" button that commits.
  Guest-creation failure must be visible, not swallowed.
- **Not settled here, deliberately:** the roster's own visual design (row density, avatar
  treatment, where the balance sits) follows the existing list idiom — `SoftCard`, `MemberAvatar`,
  `BalancePill`, `kScreenGutter`. Apply the screens that exist; don't invent a second list style.

## 2. Member removal — states, not a screen  *[owned by member-removal]*
- **What changes:** removal gains three outcomes the UI must distinguish.
- **States:**
  - **Blocked** — they still owe or are owed. Must name the outstanding amount in the group
    currency, and should offer the settle-up path rather than dead-ending.
  - **Soft-removed** — settled, but has history. They vanish from pickers, stay in the ledger.
  - **Hard-removed** — no history, gone without trace. Probably needs no confirmation at all.
- **Decided** (design session, Jakob, 2026-09-11):
  - **A soft-removed member is invisible outside past expenses.** No "former members" section, no
    greyed roster row. They are gone from the Members page, gone from every picker, and present
    only where the ledger already carries them. This is the narrower reading of soft removal, and
    it is the one `group-member-removal` already shipped — `removed_at` filters them from rosters
    and pickers today, so the design adds no new state rather than inventing a third member class.
  - **Re-adding a former member is silent.** It follows from the above: the roster cannot hint at
    someone it does not show. Already built — `GroupMemberWrite.reAddEmails` and
    `GroupJoinPlan.clearRemovedAt` clear `removed_at` instead of inserting, so the historical
    shares are neither touched nor duplicated. The add path needs no branch for this case.
  - **Blocked removal is shown before the tap, not after.** An unsettled row carries no remove
    affordance at all; it carries its outstanding balance, and tapping the row offers the
    settle-up path. The removal action appears only once the row is settled. A dialog explaining
    a failure after the user committed to it is the shape this constraint exists to forbid.
  - **Confirmation follows the outcome, not the gesture.** Hard removal — no history, nothing
    lost, re-addable in seconds — commits with no confirmation. Soft removal confirms once,
    naming that their past expenses stay. This is a real difference the user can feel, and it is
    the reason the flow has to resolve the outcome *before* it writes (see the add-flow plan's
    `Units:` — it is the one genuine engineering consequence this session produced).
- **Constraints:** never offer a removal action that will fail — prefer showing why it's unavailable.
  The outstanding amount renders code-first (`USD 12.50`, never `$12.50`) like every other amount
  in the app — see the multi-currency brief.

## 3. Group create  *[owned by create-simplify]*
- **What changes:** the member section leaves. Create becomes name + colour, tracking mode, currency.
- **States:** create (three fields) · post-create landing on the new group.
- **Decided** (design session, Jakob, 2026-09-11): a freshly created group has exactly one thing
  worth doing, so its empty state is a single call to action that opens the Members page — not a
  dashboard of zeroes with a button somewhere in it. It stops dominating the moment a second
  member exists; a solo group is not an error state and does not nag.
- **Constraints:** currency **stays** on create — changing it later relabels amounts without
  converting them, so it is a creation-time decision. See the multi-currency brief, surface 2.

## 4. Group edit  *[owned by add-flow]*
- **What changes:** the member section leaves here too, once the add-flow exists. Edit becomes
  purely group attributes plus the edit-only actions block.
- **Decided** (design session, Jakob, 2026-09-11): the field goes, but a **read-only row stays** —
  member count, tap opens the Members page. Edit is where people look for members today; removing
  every trace would relocate the feature and hide it in the same move. A row that only navigates
  cannot write membership, so it satisfies the constraint below while preserving the path people
  already know.
- **Constraints:** no group-attribute save may write membership, in either direction.

---

## Cross-cutting design decisions — settled 2026-09-11 (Jakob)
1. **Former-member treatment** — *no visual language, because there is nothing to show.* A
   soft-removed person is absent from the Members page and every picker, and appears only inside
   the expenses that already carry them, rendered as an ordinary participant. The alternative — a
   "former members" section — was rejected as a third member class the data model does not have.
   The other three surfaces hang off this, and what they inherit is the absence of a case.
2. **Guest vs real user** — distinguished by one small `Guest` label on the roster row, and
   nowhere else. It exists for a single reason: a guest receives no notification, so someone
   recording a payback on their behalf (see [payback-on-behalf](archived/payback-on-behalf.md))
   needs to know nobody is being told. Avatars stay identical — guests have no photo anyway, so a
   separate avatar treatment would encode nothing the initials don't.
3. **Immediate-save feedback** — **the roster is the receipt.** The member appearing in the list
   is the confirmation; no success snackbar, which would report the same fact twice. Nothing can
   read as "unsaved" because the page has no Save button to be missing. Failure is the only case
   that speaks: a snackbar naming what failed, with the search text left in place to retry.
4. **Blocked-action pattern** — settled by surface 2: show the balance where the action would be,
   and route to the existing settle-up affordance. No new component, no second style, and no
   dialog that explains a refusal after the fact.
