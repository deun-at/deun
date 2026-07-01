# Ship Notes — v3 Walkthrough

Raw notes captured during a live walkthrough of the app (localhost:54089).
Phase 1 = capture only. Phase 2 = grill/plan. Date: 2026-07-01.

---

## Login / Welcome
_Screen: "Willkommen zurück" — Google/GitHub social login, email+password, register link._
_App now running at http://localhost:55572/ (had a startup hiccup, resolved)._

- **Wrong logo** — currently a generic fork/split glyph. Should be the existing app logo that was already used elsewhere.
- **Google / GitHub buttons: content good, styling wrong** — the buttons themselves are styled wrong vs design.
- **Two input styles are being conflated (main issue).** Design intends:
  - *Login fields only:* label sits INSIDE the input, behaves like a placeholder (disappears on input) — no floating.
  - *Everywhere else:* label sits ABOVE the field.
  - Current behavior is Material's floating label (label animates from inside the border up to the top border). This Material floating-label pattern must be removed entirely.
- **Inputs are not white** — should have a white fill (currently grey/tinted).
- **Divider text says "oder"** — should be "oder mit E-Mail".
- **"Passwort vergessen?" alignment** — should be aligned to the input (edge), currently isn't.
- **Slogan** — keep "Simply Split Fairly" (English) even in the German build; do not translate the slogan. (Currently shows "Teile fair mit deiner Gruppe.")
- Everything else on login looks really polished. ✅

---

## Group List (home)
_Screen: greeting header + list of groups + "you're owed" summary._

- **Greeting is wrong.** Currently "Hi, Tester." and single-line. Should be time-aware ("Good evening, ...") and multi-line. Need a **set of greetings for different times of day**.
- **Wordings generally wrong** — owed vs owe confusion. "you're owed", "your groups" copy is off / too small. Audit all owe/owed wording here.
- **Per-group icon is wrong** — using an expense icon, not a group icon.
- **"you're owed" summary color** — design_handoff shows it white (white on black). Unsure it makes sense, but looks better white on black. (flag as open question)
- **Remove "New Group" button** — redundant now that there's a global "+ New" button.

---

## Friends
_Screen: Friend Requests / Pending Requests / Friends list. Test users pre-seeded._

- **Wordings wrong** for "Friend Requests" and "Pending Requests" sections.
- **Friend request card layout wrong:**
  - "Accept" should be **bigger, spanning the whole card** (dominant action).
  - "X" (decline) button: border-radius wrong on both corners + wrong color.
- **Pending "Cancel" button** — currently white/filled, should be a **ghost button**.
- **Friends list layout:** each row has spacing incl. username; "owes you / You're owed" amount should be **on the right, not beneath** the name.
- **QR code button not white** (top-right icon button).
- **Buttons still look Material** across the board.
- **Remove bottom spacing** at the end of the friends list — it was reserved for a floating button that no longer exists.

### GLOBAL — Bottom nav bar
- **Active item highlight is wrong** — currently a pill roughly in the middle behind icon+label. Should **highlight only the icon**, not the whole item.

### GLOBAL — Button system
- Need **button types / presets**. There aren't many distinct types, but they all currently look different / inconsistent. Define a small set of button presets and apply everywhere.

## Add Expense — Quick Split (BIGGEST DIFFERENCE vs handoff)
_Screen: New expense, tabs Quick split / Itemized. Icon + amount + description + Details (Paid by / Date) + Split between._

**Entry behavior**
- Add expense should **open the number sheet by default** to type in the amount immediately.

**Category icon**
- The "other" category icon is currently "..." — should be a **square / circle / triangle** icon.
- **Categories should match handoff:** no color, shorter, slimmer (use the design's version).

**Header / amount block (biggest layout diff)**
- **Icon and amount should have NO container** (currently boxed in white cards).
- **After the amount, show "split €3.00 each"** (per-person split line).
- **Then "Add a description" on a white background.**
- **Then the list** (no spacing) showing **Paid by** and **When (Date)** — and **this list's alignment looks wrong** and needs fixing.

**Split section (lots missing vs handoff)**
- **"4 of 4 people" count is missing.**
- **Split mode selector missing:** equal / shares / % / exact.
- The member list should be a **default (non-spaced) list**.
- **Checkbox is not round** — should be round.
- Each row is **missing "not in" state and the amount**.
- **Split bar colored per avatar is missing.**
- **"All set" makes no sense here** — remove.
- **"Add item" makes no sense here** — remove.
- (All the above = the whole Quick Split page.)

**Round 2 (screenshot comparison vs handoff prototype — see `screenshots/`)**
- All of the above confirmed side-by-side. Additional deltas:
- **CTA wording:** app "Save" → handoff **"Add expense"**.
- **"Details" section header doesn't exist in handoff** — the Paid by / When list starts directly under the description.
- **"Date" label → handoff says "When".**
- **Not-in state reference** (handoff): unchecked = empty round circle, avatar+name dimmed, grey "Not in" on the right, count updates ("3 of 4 people"), split bar drops that member's color, per-head amount recalculates.

## Add Expense — Itemized (vs handoff)
_Compared app Itemized tab vs handoff prototype. App structure is fundamentally different: app does per-item split assignment, handoff does share-then-claim._

- **Total block:** app puts it in a white card — handoff has **no container** ("Total · from 3 items" small grey + big amount, black **Scan** pill on the right). Scan button itself matches. ✅
- **Wording:** app "Total from 1 item" → handoff "Total · from N items" (dot separator).
- **No Category row in handoff** — app shows Category in Details; handoff items get **auto icons per item** (pizza/drink/restaurant) instead.
- **Item card layout completely different:**
  - Handoff: item icon + name + "€ [price] each" (inline editable) + line total right; bottom row = trash left, **qty stepper ("− 2 qty +") right**.
  - App: description textbox + big trash button, "€ 0 − 1x +" line, "= €0.00", then a **full per-item Split section (Amount / % / Parts + member checkboxes with amount fields)**.
- **Per-item split UI doesn't exist in handoff at all** — items are shared for claiming instead. Handoff shows an info note: "After you share, members claim their own items — solo or split, per unit."
- **"Add item by hand"** — dashed ghost button in handoff; app has none on this tab (its "+ Add item" lives on Quick split, already flagged for removal).
- **CTA wording:** app "Save" → handoff **"Add & share for claiming"**.
- ❓ **Grill topic:** is the per-item-split model being replaced by the claim model entirely, or do both survive? Handoff clearly says claim-only.

## Expense Detail (vs handoff)
_App: tapped "sei leise oda" (exact split). Handoff: "Lift passes ×4" (equal split)._

- **Header card is close.** Icon + title + "Category · Date" + big amount + payer row. ✅ (icon itself = known "other/..." icon issue)
- App has a **divider line** between amount and payer row — handoff has none.
- **Member list uses the wrong list type:** app = spaced cards per member; handoff = **one card, non-spaced rows**.
- **Row sub-label wording:** handoff "your share" / "paid €188.00" (green) / "owes Jonas" — app "Paid by" / "owes" / "lent".
- **Amounts:** handoff plain black, single line, right-aligned. App: two-line colored ("lent" grey + green €500.00 / "owes" grey + red €500.00).
- **Section label:** handoff "Split equally" — app "Split by exact amounts" (split-mode-dependent; verify wording set in grill).

## Claim Screen — Tap to claim (vs handoff)
_App: "na ned". Handoff: "Dinner · Trattoria Nova"._

- 🐞 **REAL BUG: "Preview as" chip row overflows** — Flutter renders "BOTTOM OVERFLOWED BY 78/14/45/184 PIXELS" stripes. Broken regardless of design.
  - ✅ **FIXED (F79):** root cause was `AppSegmentedControl` — segment labels had no overflow handling, so any label wider than its equal-width slot overflowed (claim page is the first caller with user-generated labels). Labels now ellipsize (`Flexible` + `TextOverflow.ellipsis`); regression test in `restyle_widgets_test.dart`. Needs hot restart (`R`) to see in the running app. The avatar-based redesign of this selector is still open above.
- **"Preview as" selector wrong:** handoff = **avatar circles with names underneath**, selected gets a black ring; app = text chips in a row (overflowing).
- **Header subtitle:** handoff "● 3 people claiming now" (live count); app "● Live". Wording.
- **Black share card:**
  - Handoff: "You, your share" + amount, right side "you claimed N items", **green** progress bar, "€62.50 of €84.50 claimed" left + **"€22.00 left"** (amber) right.
  - App: "Your share", **white** progress bar, "Unclaimed: €20.00". Wordings + colors off.
  - **Per-person chips:** handoff = avatar + amount only (compact, no name, no "Per person" label); app = "Per person" label + bigger chips with names.
- **Unclaimed banner:** handoff has explanation copy ("…Sam paid, so they cover the rest unless the group claims it.") + **black "Nudge" pill**; app has short text + plain "Nudge" text link.
- **Item cards missing structure:** handoff shows item name + ×N, "€2.00 each · N ordered", **per-unit claim chips** ("Sam", "P J split · €5.50", dashed "+ take one" per free unit), ghost **"Split one"** button, right-hint "Tap a slot to take one". App rows show only amount + avatar / one "+ Take one" — no name/qty line, no per-unit slots, no split-one ghost.
- **CTA:** handoff **"Tap the items you had"**; app "Confirm — I had €0.00". ❓ Grill: does the app's explicit confirm step survive, or is claiming instant per tap like the prototype?

## Group Creation
_Modal: icon + group name + color, members, expense tracking mode._

- **First card (icon + group name + color) should NOT be on a white background.** Only the **group name** should sit on a white background; icon + color pickers should not.
- **Colors: liked.** ✅
- **Icon is the expense icon** — should be the group icon (same issue as group list).
- **Members section — needs brainstorm (Phase 2).**
  - Likes the idea of a greyed friend list to add from.
  - But design_handoff has **no "add guest" function** — it's just a **randomized guest creator**. Revisit this in brainstorm.
- **Expense tracking options should be side by side** (next to each other), and **"simplified" should be the default**.

## Group Detail
_Screen: "You're owed" header card + Statistics/Invite + Search + dated expense list + Add expense FAB._

- **Search doesn't fit here anymore** — needs brainstorm on placement, but the function is worth keeping.
- **List: same spacing problem as friends** — items within the same date have spacing (should follow the list system; non-spaced within a date group).
- **Tap-to-claim expense row is wrong vs handoff:**
  - "Tap to claim" button on the **wrong side**; should be an **icon button**.
  - "€X unclaimed" label is on the **wrong side**. Compare directly with handoff.
  - **Wording** off — "You paid" / "sam paid" (?) — VERIFY exact intended wording in grill.
  - **"Itemized" indicator is missing** (should show when an expense is itemized).
  - **User avatars should overlap** each other (stacked/overlapping), not spaced.
- **"You're owed" header avatars** — in handoff they are **all the same color** (currently multi-colored).
- **FAB / scan:** "Add expense" + "scan" should be in the **same row**. Scan = **white** button, Add expense = **full color**.
- **Edit button is wrong** — currently a pencil icon; should be the correct edit icon per handoff.

### GLOBAL — List system (two list types)
- Standardize on **two list types**:
  1. **Spaced list** (cards separated by gaps) — used by: group list, friend requests, pending requests.
  2. **Non-spaced list** (joined rows, no gaps) — used by: all-friends list, preferences.
- **Remove the border from the preferences table** — it then becomes the non-spaced list type. Two list types should cover everything.

### GLOBAL — Shimmer / loading skeletons
- Shimmer loading effect **no longer matches the new design**. Update the skeleton shapes/style everywhere they appear: group list, group edit, friends fetch (and audit for others).

---

## Settings
_Screen: profile card + Profile form + Preferences. Looks great overall._

- Looks awesome overall. ✅
- **Same input problem as before** (label pattern — see Login note; applies to profile form fields).
- **Language popup / Appearance popup** — weird **border between items**. Mockup has **no border** between the options.
- **Preferences list border** — remove it entirely (becomes the non-spaced list type — see GLOBAL List system).
- **Notification row height** — should match all other rows; the switch is too big and bloats the item.
- **Sign out button not white** (→ global button system).
- **Update button** should be **full width**.

---
