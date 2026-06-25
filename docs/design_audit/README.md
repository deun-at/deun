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

_None yet — start empty. The loop's next iteration is an **AUDIT** against the v3 prototype, which
populates this section. Then it FIXes top-down by severity._
