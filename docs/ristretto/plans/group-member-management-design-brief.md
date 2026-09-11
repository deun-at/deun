# group-membership — Design brief (by surface)

Handoff doc for the design session on group membership. Engineering contracts live in three plans
([member-removal](archived/group-member-removal.md) · [create-simplify](archived/group-create-simplify.md) →
[add-flow](group-member-add-flow.md)); this file pivots them by **surface** so each screen is
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
- **Open questions:**
  - Full page, bottom sheet, or the existing search-anchor overlay promoted to a page?
  - Are add and remove the same surface, or is removal a swipe/long-press on the member row?
  - How prominent is "create a guest" relative to searching for a real user? It's the path that
    matters most for the people who never install the app.
  - Does the flow stay open for adding several people in a row, or close after each add?
- **Constraints:** each add persists on its own — no batch save, no "done" button that commits.
  Guest-creation failure must be visible, not swallowed.

## 2. Member removal — states, not a screen  *[owned by member-removal]*
- **What changes:** removal gains three outcomes the UI must distinguish.
- **States:**
  - **Blocked** — they still owe or are owed. Must name the outstanding amount in the group
    currency, and should offer the settle-up path rather than dead-ending.
  - **Soft-removed** — settled, but has history. They vanish from pickers, stay in the ledger.
  - **Hard-removed** — no history, gone without trace. Probably needs no confirmation at all.
- **Open questions:**
  - Does a soft-removed member appear anywhere in the roster (greyed, "former member" section),
    or only inside past expenses?
  - Is the blocked case a dialog, an inline error on the row, or a disabled affordance with a reason?
  - Is re-adding a former member surfaced as such ("was in this group before"), or silent?
- **Constraints:** never offer a removal action that will fail — prefer showing why it's unavailable.

## 3. Group create  *[owned by create-simplify]*
- **What changes:** the member section leaves. Create becomes name + colour, tracking mode, currency.
- **States:** create (three fields) · post-create landing on the new group.
- **Open questions:** what the freshly created, member-less group detail looks like — how loud is
  the "add members" call to action, and does it dominate the screen until someone is added?
- **Constraints:** currency **stays** on create — changing it later relabels amounts without
  converting them, so it is a creation-time decision. See the multi-currency brief, surface 2.

## 4. Group edit  *[owned by add-flow]*
- **What changes:** the member section leaves here too, once the add-flow exists. Edit becomes
  purely group attributes plus the edit-only actions block.
- **Open questions:** does group edit keep a read-only member summary that links to the add flow,
  or drop members from this screen entirely?
- **Constraints:** no group-attribute save may write membership, in either direction.

---

## Cross-cutting design decisions (settle these first — they propagate)
1. **Former-member treatment** — one visual language for a soft-removed person, used in the ledger,
   past expenses, and the balance list. This is the decision the other three surfaces hang off.
2. **Guest vs real user** — how visibly the two are distinguished, now that guests get a first-class
   creation path and can have paybacks recorded on their behalf (see
   [payback-on-behalf](archived/payback-on-behalf.md)).
3. **Immediate-save feedback** — membership writes commit instantly; what confirms that, given the
   rest of the app uses form-save semantics? Must not read as "unsaved".
4. **Blocked-action pattern** — the "you can't do this yet, here's why, here's the way out" shape
   introduced by blocked removal is reusable; align it with the existing settle-up affordances
   rather than inventing a second style.
