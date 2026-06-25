# Design Audit — Handoff v3 vs. current app

Single source of truth for the design-fidelity loop ([`../superpowers/AUDIT_LOOP.md`](../superpowers/AUDIT_LOOP.md)).
The loop reads the **Findings** below each iteration: it FIXes the highest-severity open item, or — when
none are open — runs an AUDIT to compare the live app against the v3 prototype and append new findings.

- **Design** = `design_handoff_updated/Deun Redesign v3.dc.html`, rendered in a browser (light mode).
- **Current app** = live build on physical device `R5CY22DR0FK` (`app.deun.www`), branch `feat/v3-motion-foundation`.
- **Capture harness:** [`tools/`](tools/capture.md) (`serve.js` + `capture.md`). Test group for nav/writes: **hans**.

## Severity & format
🔥 high (wrong / unusable) · ⚠️ medium (clearly off) · 💅 low (cosmetic).
Open = `- [ ]`; done = `- [x] … ✅ <SHA>`; blocked = `⛔ blocked — <reason>`. AUDIT writes each finding as:
`- [ ] <id> · <screen> · <delta> 🔥|⚠️|💅 — <file:loc> — target: <value> — ev: compare/<x>.png`

## Screens to audit
Groups home · Friends · Settings/Profile · Group detail · New/Edit group · Add friend · QR code ·
Personal statistics · Group statistics · Expense detail · Expense editor (quick) · Expense editor (itemized) ·
Settle up · Invite · **Tap to Claim** · Login · Reset password · Onboarding.

---

## Findings

### Groups home
- [x] F01 · Groups home · Failed AdMob native ad overlays the group list and intercepts all taps — no group card is openable (vertical scroll passes through, taps do not); blocks the entire group flow 🔥 — lib/widgets/native_ad_block.dart:30 (placed group_list.dart:153) — target: ad must not capture touch / hit-test on sibling cards; on load-failure render nothing AND ensure the platform-view does not intercept — ev: compare/compare_groups.png ✅ ba289df
- [x] F02 · Groups home · Debug AdMob error banner "This ad may have not been loaded or has been disposed…" renders as a red full-width block in the list 🔥 — lib/widgets/native_ad_block.dart:30 — target: no visible ad container/banner on failure (currently SizedBox in widget, but SDK debug view still paints) — ev: compare/compare_groups.png ✅ 2de937d (resolved by ba289df; regression test added)
- [x] F03 · Groups home · Overall-balance hero amount uses textTheme.displaySmall (~36px) — far smaller/lighter than the v3 hero amount 🔥 — lib/pages/groups/presentation/group_list.dart:275 — target: hero amount 58px Bricolage Grotesque w700/-0.02em — ev: compare/compare_groups.png ✅ fe62601 (rendered v3 hero measures ~42px, not 58px — used shared displayMedium token 45px/w700/-0.02em)
- [x] F04 · Groups home · Group-card leading icon is a flat uniform light-teal/blue square for every group; not per-group palette-tinted ⚠️ — lib/pages/groups/presentation/group_list.dart (GroupListItem) — target: icon tinted from Group.colorValue palette (#5750E6/#2F73D9/#E0853D/#D45A8A/#B85C9E) with matching light tint — ev: compare/compare_groups.png ✅ 54d013a (centralized groupTint() resolver, light+dark)
- [x] F05 · Groups home · Group-card balance footer label/amount is small and lacks the v3 "lead label + colored amount" weight hierarchy 💅 — lib/pages/groups/presentation/group_list.dart (GroupListItem) — target: caption lead label + card-title-weight green owed / red owe / gray settled amount — ev: compare/compare_groups.png ✅ 168cdb1 (caption lead label + semantic-colored titleMedium amount)

### Friends
- [x] F06 · Friends · Accepted-friend row has no trailing chevron; v3 row ends in chevron_right to signal it opens the friend sheet ⚠️ — lib/pages/friends/presentation/friend_list.dart:375 — target: add trailing Icons.chevron_right (#C9C5BB) after the balance — ev: compare/compare_friends.png ✅ 1a27194 (chevron via colorScheme.outline)
- [x] F07 · Friends · Balance rendered as a filled BalancePill ("Du schuldest …" / "Ausgeglichen" chip); v3 uses plain colored text (green owed / red owe / gray settled), no pill ⚠️ — lib/pages/friends/presentation/friend_list.dart:375 (widgets/restyle/balance_pill.dart) — target: plain semantic-colored balance text, not a filled chip — ev: compare/compare_friends.png ✅ 9fc7d15 (plain SemanticColors balance text; BalancePill kept for gallery)
- [x] F08 · Friends · Header person-add and QR are plain M3 IconButtons; v3 makes the primary add-friend a filled indigo (#5750E6) accent circle, QR a 38×38 warm-tint circle ⚠️ — lib/pages/friends/presentation/friend_list.dart:207-216 — target: person_add = filled accent circle, qr = 38px rgba(20,18,12,.04) circle — ev: compare/compare_friends.png ✅ 50df242 (reusable HeaderIconButton: accent + warm-tint variants)

### Settings/Profile
- [x] F09 · Settings · Profile fields each carry a leading icon (badge/person/@/card/bank); v3 profile fields have NO leading icons (label + value only) ⚠️ — lib/pages/settings/settings_profile_form.dart:53,62,70 (_InsetFormField icon:) — target: remove field leading icons — ev: compare/compare_settings.png ✅ e02c851 (icon made optional; removed at profile call sites)
- [x] F10 · Settings · First name / Last name stacked as two full-width rows; v3 places them side-by-side in one two-column row ⚠️ — lib/pages/settings/settings_profile_form.dart:50-66 — target: First + Last in a single Row (two Expanded columns) — ev: compare/compare_settings.png ✅ e4e0b9c (two Expanded columns, 12px gap)
- [ ] F11 · Settings · Profile fields are separate inset fills with large gaps; v3 groups the whole profile form inside one white card 💅 — lib/pages/settings/settings_profile_form.dart:43-47 — target: wrap fields in a single SoftCard/white container; tighter row spacing — ev: compare/compare_settings.png
- [ ] F12 · Settings · Logout icon button has a red errorContainer-tinted circle; v3 logout is a plain white circle with a red (#D85A47) icon 💅 — lib/pages/settings/setting.dart:62 — target: white circle bg, red icon, no error tint — ev: compare/compare_settings.png

### QR code
- [ ] F13 · QR code · Profile row (avatar + name) renders BELOW the QR; v3 places it ABOVE the QR (between segmented control and code) ⚠️ — lib/pages/friends/presentation/friend_qr_page.dart:212 vs 292 — target: avatar/name block above QrImageView — ev: compare/compare_qr.png ⛔ blocked — false positive: v3 prototype + compare_qr.png both show the profile row BELOW the QR (audit inverted above/below); app already matches v3. Fixing would regress.
- [x] F14 · QR code · Copy/Share are full-stadium pills and "Link kopieren" wraps to two lines; v3 uses radius-15 buttons, Copy = white+1.5px border (secondary), Share = solid indigo, single-line ⚠️ — lib/pages/friends/presentation/friend_qr_page.dart:242,255 — target: radius-15; Copy white+#E4E1D8 border; one-line labels (more h-padding/width) — ev: compare/compare_qr.png ✅ 6419da9 (PrimaryButton + new SecondaryButton, radius-15, single-line)

### Add friend
- [ ] F15 · Add friend · Header has no trailing QR action; v3 "Add friends" header carries a trailing qr_code_2 button 💅 — lib/pages/friends/presentation/friend_add_page.dart (header) — target: add trailing qr_code_2 38×38 action — ev: compare/compare_add_friend.png
- [ ] F16 · Add friend · Custom header title not centered between symmetric 38×38 slots (sits left, near back arrow) 💅 — lib/pages/friends/presentation/friend_add_page.dart (header) — target: centered title, equal leading/trailing slots per COMPONENTS.md §2 — ev: compare/compare_add_friend.png

### Capture-pending (not yet auditable — re-audit after F01 unblocks the group flow)
These screens could not be reached this pass (most are gated behind the tap-blocked Groups home, F01). They are NOT fixable items yet; a later AUDIT re-captures them once F01 lands.
- F17 · Group detail — group cards untappable (F01), no adb deep-link possible (route needs in-process Group via state.extra, navigation.dart:114) — ev: compare/compare_group_detail.png ⏳ capture-pending
- F18 · New/Edit group — reachable only via "+ Neu"/FAB on the tap-blocked home (F01) — ev: compare/compare_group_form.png ⏳ capture-pending
- F19 · Group statistics — reached from group detail, blocked by F01 — ev: compare/compare_group_stats.png ⏳ capture-pending
- F20 · Personal statistics — reached via Settings → Your statistics; stats-row tap lands in the same Flutter content layer; not captured this pass — ev: compare/compare_personal_stats.png ⏳ capture-pending
- F21 · Expense detail — reached from group detail ledger, blocked by F01 — ev: compare/compare_expense_detail.png ⏳ capture-pending
- F22 · Expense editor (quick) — reached via Add-expense FAB in group detail, blocked by F01 — ev: compare/compare_expense_quick.png ⏳ capture-pending
- F23 · Expense editor (itemized) — reached via editor segmented control in group detail, blocked by F01 — ev: compare/compare_expense_itemized.png ⏳ capture-pending
- F24 · Settle up — reached from group-detail hero "Settle up", blocked by F01 — ev: compare/compare_settle_up.png ⏳ capture-pending
- F25 · Invite — reached from group-detail quick action, blocked by F01 — ev: compare/compare_invite.png ⏳ capture-pending
- F26 · Tap to Claim — reached from an itemized expense in group detail, blocked by F01 — ev: compare/compare_claim.png ⏳ capture-pending
- F27 · Login — requires sign-out from Settings, which routes back through the tap-blocked home shell; not captured this pass — ev: compare/compare_login.png ⏳ capture-pending
- F28 · Reset password — reached from Login (F27) — ev: compare/compare_reset.png ⏳ capture-pending
- F29 · Onboarding — reached via signup/social from Login (F27) — ev: compare/compare_onboarding.png ⏳ capture-pending
