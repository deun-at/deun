# Capture procedure (design-audit harness)

Produces the screenshots + composites the loop reasons over. **No app-code edits here.**
Device: `R5CY22DR0FK` (1080×2340). Prototype: `../../design_handoff_updated/Deun Redesign v3.dc.html`.
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
```bash
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
"$ADB" exec-out screencap -p > app/app_NN_<screen>.png
"$ADB" shell input tap <x> <y>     # navigate; bottom nav y≈2270; let live lists settle ~2s
```
- Use **hans** for group flows; drive into expense detail/editor, settle up, claim, stats, invite.
- In-group taps race with realtime rebuilds → retry; verify each nav by re-screenshotting.
- A screen that genuinely can't be reached this pass → log it `⏳ capture-pending` in README, don't skip silently.

## 3. Reading >2000px shots (downscale first)
Device shots are 2340px tall (> the 2000px read limit). Downscale before reading:
```powershell
Add-Type -AssemblyName System.Drawing
$img=[System.Drawing.Image]::FromFile("app\_dev.png"); $s=1400/$img.Height; $w=[int]($img.Width*$s)
$bmp=New-Object System.Drawing.Bitmap $w,1400; $g=[System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode='HighQualityBicubic'; $g.DrawImage($img,0,0,$w,1400)
$bmp.Save("app\_dev_small.png",[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose();$bmp.Dispose();$img.Dispose()
```

## 4. Composites (`../compare/`)
```bash
node tools/serve.js .. 8732        # serves design_audit/ ; _build.html lives at its root
```
- Add each new pair to `_build.html`'s `pairs` map (`key:[design/…, app/…]`).
- Playwright: screenshot `http://localhost:8732/_build.html?p=<key>` at 1180×820 → `compare/compare_<key>.png`.

## Cleanup
Kill the node servers (ports 8731/8732) and remove `app/_dev*.png` scratch files when done.
