# Deun Redesign — Custom Component Specs (buttons · app headers · bottom sheets)

The "make it not look like Material" conversation, written down. `THEME_AUDIT.md` covers the **stock M3
components that were never themed** (nav bar, switches, snackbars, cards, inputs, checkboxes, dividers,
progress, dialogs). **This doc covers the three families that carry the strongest Material signature in
day-to-day use and should be built as custom widgets, not styled Material ones:** buttons, app headers, and
bottom sheets. All values are pulled from `Deun Redesign v3.dc.html`.

> **Guiding rule:** Material's defaults (ripples, tonal elevation overlays, 48dp ripple squares, centered M3
> AppBar metrics, the M3 sheet drag handle + surface) are exactly what makes the app read as "a Flutter app."
> For these three, prefer a **custom widget** (`InkWell`/`GestureDetector` + `Container`) over fighting the
> Material defaults — it's less code than overriding every `*ThemeData` knob and matches the prototype 1:1.

---

## 1. Buttons

### Primary CTA (submit, "Add expense", "Get started", "Pay €X", "Confirm")
- Background **`#5750E6`** (accent), text `#fff` **Hanken 16 / w700**.
- Radius **15**, full-width, vertical padding **15** (≈48–50px tall).
- **Colored soft shadow** `0 12px 22px -10px rgba(87,80,230,0.5)` — *not* M3 elevation/tonal overlay.
- **No ripple-heavy splash, no surfaceTint.** A subtle press scale/opacity is fine.
- Disabled: reduce to ~40% accent or `#C2BEB4`; keep shape.
- **Flutter:** a `FilledButton` *can* work only if you kill the tint and set the shadow:
  `FilledButton.styleFrom(backgroundColor: seed, foregroundColor: Colors.white, elevation: 0,
  shadowColor: …, shape: RoundedRectangleBorder(borderRadius: 15))` **plus** wrap for the soft colored shadow
  (Material elevation won't reproduce `0 12 22 -10`). Cleaner: a custom `InkWell + Container(decoration:
  BoxShadow(...))`. The FAB (`StadiumBorder`) already matches — keep it.

### Secondary / social buttons (Google, GitHub)
- Background `#fff`, **1.5px border `#E4E1D8`**, radius 15, text `#16181A` w700, leading mark/icon, gap 9.
- **Apple** variant: background `#16181A`, white text/icon (dark solid, no border).
- **Flutter:** `OutlinedButton`-shaped custom container; do **not** use M3 tonal/`elevated` styles.

### Icon buttons (header back/close, row actions)
- **38×38 circle**, background **`rgba(20,18,12,0.04)`** (faint warm tint), icon **22px** `#16181A`.
- This replaces M3 `IconButton` (which is a 48dp transparent ripple square). Action icons with no bg (e.g.
  delete on detail) are bare 38×38 hit targets.
- **Keep the real hit target ≥ 44–48dp** even though the visible circle is 38 (pad the `InkWell`).
- **Flutter:** custom `InkWell(customBorder: CircleBorder())` + `Container(38, color: 0x0A120C0F)`.

### Pills / chips / segmented
- Stadium (`999`) pills; segmented control track `#F1EFE9` with a white selected thumb. Already covered by the
  `AppSegmentedControl` custom widget (`E0-T4`) — use it, not M3 `SegmentedButton`.

---

## 2. App headers (top bars) — **do not use `AppBar`**

Every sub-screen uses the **same custom header row**, not a Material `AppBar`:

- A **single 38px-tall flex row**, padding ≈ `4px 14px 6–10px`, on the **screen background** (transparent) —
  **no elevation, no shadow, no bottom divider, no scroll-tint**.
- Layout: **`[leading 38×38 icon button] · [flex:1 centered title] · [trailing 38×38 action or empty spacer]`**.
  The empty 38×38 spacer on the right keeps the title optically centered when there's no action.
- **Title:** Hanken **16 / w700**, centered, single line (the Claim header stacks a 16/700 merchant + an
  11.5px presence subline).
- **Leading glyph:** `arrow_back` for drill-down pages (group, stats, settle, detail, claim, add-friend, QR);
  **`close`** for modal-style full-screen forms (new/edit group, expense editor).
- **Trailing:** optional single action (edit, QR, delete) as a 38×38 icon button, else a 38×38 spacer.

> **⚠ Updates `THEME_AUDIT.md` point 3.** The audit suggested `centerTitle:false` (left-aligned) for a Material
> `AppBar`. The v3 design **centers** titles between two equal 38×38 side slots. Since you're building a
> **custom header widget** (not an `AppBar`), this is moot — just center the title with symmetric leading/trailing
> slots as above. The latest design (v3) wins: **centered title.**

- **Flutter:** a small `DeunHeader` widget (a `SizedBox(height: ~50)` + `Row`), reused on every sub-screen,
  rather than `Scaffold.appBar`. If you must keep `Scaffold.appBar` for scroll behavior, set
  `backgroundColor: transparent, elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: transparent` and
  build the same 3-slot row as `title`/`leading`/`actions` — but the standalone widget is closer to the prototype.
- The **home tabs have no header** — Groups/Friends/Settings each open with their own in-content greeting/title,
  not a top app bar.

---

## 3. Bottom sheets — **override the M3 sheet, don't accept defaults**

Every picker/confirm (keypad, scan, category, paid-by, date, friend, invite, language, appearance, delete,
stat-month, stat-category, discard, settle) uses the same shell:

- **Surface `#FBFAF7`** (warm off-white) — not the default M3 `surfaceContainerLow`.
- **Top radius 30** (prototype draws `30px 30px 44px 44px`; the 44 bottom corners only matter because the
  prototype sits inside a 44px device frame — in a real full-bleed sheet the **bottom is flush to the screen
  edge**, so implement **top-radius 30, square bottom**). *(This refines `DESIGN_SPEC.md`'s "28" → use 30.)*
- **Drag handle:** **38×4**, radius 2, color **`#D6D2C7`**, centered, ~6px top margin — a custom handle, not
  the M3 default. (Theme `bottomSheetTheme.dragHandleColor`/`dragHandleSize`, or draw it and set
  `showDragHandle:false`.)
- Content padding ≈ `8px 20px 26px`. Sheet titles: **Bricolage 22–24 / w700**, `-0.01em`.
- **Scrim:** `rgba(16,16,14,0.4)`, **fade 0.2s** (M3 default barrier is `black54`-ish — set
  `barrierColor` to match).
- **Motion:** rise `translateY(101%) → 0`, **0.28s** `Cubic(0.22,1,0.36,1)` — see `ANIMATIONS.md §7`.
  Provide a custom `transitionAnimationController` to `showModalBottomSheet` to hit this curve/duration;
  the default differs.
- Confirm/destructive sheets add a centered status badge (e.g. delete = 54×54 `#FBEAE5` circle + danger icon;
  success = the pop+ring from `ANIMATIONS.md §4`).
- **Flutter:** `showModalBottomSheet(isScrollControlled: true, backgroundColor: #FBFAF7,
  shape: RoundedRectangleBorder(top 30), barrierColor: rgba(16,16,14,.4), …)` wrapped by your `SheetScaffold`
  (`E0-T4`) so every sheet shares handle + surface + padding. Round only the **top** corners.

---

## Quick verification (light + dark)
- [ ] Primary CTA has the soft **colored** shadow, flat accent fill, no tonal overlay or heavy ripple.
- [ ] Header icon buttons are 38px warm-tint circles (not M3 ripple squares); titles **centered** Hanken 16/700;
      no app-bar shadow/divider/tint.
- [ ] Sheets are warm `#FBFAF7`, **top-radius 30 / square bottom**, custom 38×4 `#D6D2C7` handle, scrim
      `rgba(16,16,14,.4)`, rise in 0.28s with the spec curve.
- [ ] No screen still shows a stock Material `AppBar`, `IconButton` square ripple, or default M3 sheet handle/surface.
