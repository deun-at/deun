# Capture procedure (design-audit harness)

Produces the screenshots + composites the loop reasons over. **No app-code edits here.**
App: **Flutter web in Chrome via Playwright** (real pointer events — unlike `adb input tap`, which
this build's gesture arena ignores on device, so the group flow was unreachable). Mobile viewport
**390×844**. Prototype: `../../design_handoff_updated/Deun Redesign v3.dc.html`.
Test group for any group navigation / writes: **hans** (never touch real groups).

## 1. Prototype (design side → `../design/`)
```bash
node tools/serve.js ../../design_handoff_updated 8731   # from docs/design_audit/
```
- Playwright: open `http://localhost:8731/Deun%20Redesign%20v3.dc.html`, resize ~820×1000.
- The phone frame renders one screen at a time (React/DC runtime). Navigate with the bottom
  nav and on-screen buttons (snapshot to get refs; click `target=<ref>`).
- Screen set (`data-screen-label`): Login · Reset password · Onboarding · Groups · Friends ·
  Settings · Group detail · Group stats · Personal stats · Add friend · QR code · Group form ·
  Expense · Settle up · Expense detail · Tap to claim.
- Screenshot each into `design/design_NN_<screen>.png`.

## 2. App (app side → `../app/`)
Serve the app headless (no auto-launched Chrome — Playwright drives its own), from repo root:
```bash
flutter run -d web-server --web-port 8740 --dart-define-from-file .env_flutter/development.env
```
- Playwright: open `http://localhost:8740`, resize **390×844** (mobile). Flutter web renders to canvas
  but responds to real pointer events — click by coordinate/`target=<ref>` from a snapshot.
- **Auth (with self-heal):** the app needs a signed-in session.
  1. If `tools/.web-auth.json` storageState exists, load it and open the app.
  2. If no session (or any nav below bounces to the login screen mid-run = expired), read
     `tools/.web-creds` (gitignored; `email=` / `password=` lines), drive the login form via
     Playwright, then **save fresh storageState to `tools/.web-auth.json`** and resume.
  3. Only after a *failed* re-login is a screen `⏳ capture-pending — web auth blocked`.
- Use **hans** for group flows; now reachable — drive into group detail, expense detail/editor (quick +
  itemized), settle up, claim, stats, invite; sign out to reach login / reset / onboarding.
- Let live lists settle (`browser_wait_for`) before each screenshot; verify each nav by snapshot.
- Screenshot each into `app/app_NN_<screen>.png`. A screen that genuinely can't be reached → log it
  `⏳ capture-pending` in README, don't skip silently.

### Web ≠ device — read findings accordingly
Web pixels differ from the phone (font hinting, default metrics). **AdMob doesn't run on web** (the F33
banner won't appear here — fine, already fixed + device-verified). Treat web as authoritative for
layout / structure / color / typography / component shape / copy; leave final light-AND-dark pixel
sign-off for the phone. OAuth redirect / push / native share / QR-scan camera may not fully work on web.

## 3. Composites (`../compare/`)
```bash
node tools/serve.js .. 8732        # serves design_audit/ ; _build.html lives at its root
```
- Add each new pair to `_build.html`'s `pairs` map (`key:[design/…, app/…]`).
- Playwright: screenshot `http://localhost:8732/_build.html?p=<key>` at 1180×820 → `compare/compare_<key>.png`.

## Cleanup
Kill the node servers (ports 8731/8732) and the `flutter run -d web-server` (port 8740); remove
`app/_dev*.png` scratch files. Keep `tools/.web-auth.json` (gitignored) for next run's auth reuse.
