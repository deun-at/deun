# Deun Redesign — Theme Audit & "De-Materialize" Spec

**Status of the build:** the redesign largely landed. The palette, warm-neutral surfaces, Bricolage/Hanken
type, semantic colors, the whole `lib/widgets/restyle/` set, and the per-screen layouts (Groups list, Group
detail, Settings, Claim, etc.) are faithful to the prototype. **This is not a "the theme didn't apply"
problem.**

**Why it still reads as Material Design:** the theme overrides `ColorScheme`, `textTheme`, and a few
component themes (buttons, FAB, chip shape, dialog shape, bottom sheet). It does **not** override the handful
of stock Material components that carry M3's strongest visual signature. Those components fall back to the
default M3 look — tonal "pill" indicators, tonal switches, default snackbars/dialogs, elevation tint — and a
few of them (the bottom nav bar especially) appear on **every** screen, so the whole app reads Material even
though the screens themselves are restyled.

This doc is the missing **E0-T5**: a component-theme pass in `lib/widgets/theme_builder.dart`. It's almost
entirely additive — new `*ThemeData` blocks on the existing `ThemeData(...)` return. No screen changes needed
for most of it.

---

## What landed vs. what's missing

| Themed today (good) | **Not themed → still Material** |
|---|---|
| `ColorScheme` surfaces (warm neutrals, light+dark) | **`NavigationBarThemeData`** — bottom tab bar (every screen) |
| `textTheme` (Bricolage/Hanken, tabular figures) | **`SwitchThemeData`** — notifications toggle, etc. |
| `filledButtonTheme`, `textButtonTheme`, `floatingActionButtonTheme` | **`inputDecorationTheme`** — any field not using `_InsetFormField` |
| `chipTheme` (shape + padding only) | **`snackBarTheme`** — every snackbar |
| `dialogTheme` (shape only) | **`cardTheme`** sets *margin only* → raw `Card` keeps M3 elevation + tonal tint |
| `bottomSheetTheme` (radius + drag handle) | **`checkboxTheme` / `radioTheme`** — split editor, tracking-mode radio |
| `appBarTheme` (bg + transparent tint) | **`dividerTheme`**, **`progressIndicatorTheme`**, **`switchTheme`** |
| `SemanticColors` extension (success/danger/warning) | `dialogTheme` has shape but no surface/button color |

The custom widgets (`AppSegmentedControl`, `MemberAvatar`, `MoneyText`, `SoftCard`, inset form fields…) are
done right and don't need touching. The gap is purely the **un-themed stock components**.

---

## The #1 offender: the bottom navigation bar

`ScaffoldWithNestedNavigation` in `navigation.dart` uses a bare `NavigationBar` with no theme. M3 draws it
with a **tonal pill indicator** behind the active icon and seed-derived colors — the single most recognizable
"this is a Material app" element, and it's on every screen. The prototype's tab bar has **no pill**: active =
accent-colored icon + label, inactive = muted, 78px tall, flat warm surface.

Add to `getThemeData(...)`:

```dart
navigationBarTheme: NavigationBarThemeData(
  height: 78,
  backgroundColor: surfaceBright,            // #FBFAF7 light / #1A1B19 dark
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  indicatorColor: Colors.transparent,        // kill the M3 pill
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        size: 24,
        color: states.contains(WidgetState.selected)
            ? seedColor                       // accent #5750E6
            : const Color(0xFFADA99F),        // inactive (DESIGN_SPEC app-shell)
      )),
  labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontFamily: GoogleFonts.hankenGrotesk().fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: states.contains(WidgetState.selected) ? seedColor : const Color(0xFFADA99F),
      )),
),
```

> Inactive color: use a single constant for both brightnesses (`#ADA99F` reads correctly on the dark bar too),
> or branch it in the `if (dark)` block like the other tokens.

---

## The rest of the component pass (all additive in `theme_builder.dart`)

```dart
// Switches — flat accent track, white thumb; no M3 tonal container.
switchTheme: SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? Colors.white : surfaceContainerLowest),
  trackColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? seedColor : surfaceContainerHigh),
  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
),

// Snackbars — ink surface, accent action, soft radius (matches dark hero cards).
snackBarTheme: SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  backgroundColor: onSurface,                          // ink
  contentTextStyle: TextStyle(color: surface, fontWeight: FontWeight.w500),
  actionTextColor: brightness == Brightness.dark ? const Color(0xFF7A74F0) : seedColor,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 0,
),

// Cards — kill default elevation + tonal tint so raw Card == SoftCard.
cardTheme: Theme.of(context).cardTheme.copyWith(
  margin: const EdgeInsets.fromLTRB(10, 1, 10, 1),
  elevation: 0,
  color: surfaceContainerLowest,                       // #FFFFFF / #1F211E
  surfaceTintColor: Colors.transparent,
  shadowColor: kSoftShadowColor,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
),

// Global input look (mirrors _InsetFormField so EVERY field matches).
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: surfaceContainer,
  prefixIconColor: onSurfaceVariant,
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: seedColor, width: 1.5)),
),

// Checkbox / radio — accent fill, hairline outline (split editor, tracking radio).
checkboxTheme: CheckboxThemeData(
  fillColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? seedColor : Colors.transparent),
  side: BorderSide(color: onSurfaceVariant.withValues(alpha: 0.5), width: 1.5),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
),
radioTheme: RadioThemeData(
  fillColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? seedColor : onSurfaceVariant.withValues(alpha: 0.6)),
),

// Hairlines + progress — match spec instead of M3 outlineVariant defaults.
dividerTheme: DividerThemeData(
  color: brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0x14120C0F),                       // ~rgba(20,18,12,.06)
  thickness: 1,
  space: 1,
),
progressIndicatorTheme: ProgressIndicatorThemeData(
  color: seedColor,
  linearTrackColor: surfaceContainerHigh,
  circularTrackColor: surfaceContainerHigh,
),

// Dialogs — give the existing shape a warm surface so AlertDialog isn't a gray M3 box.
dialogTheme: DialogThemeData(
  backgroundColor: surfaceBright,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
),
```

---

## Likely "layout problems" (verify against a running build)

Without a running app these are inferred from the code — **send screenshots of the screens that look off and
they can be pinpointed.** Usual suspects given what's in the repo:

1. **Nav bar height/labels.** Default `NavigationBar` is ~80px with M3 label metrics; once `height: 78` +
   the 10px label style above are set, labels stop clipping and the bar matches the prototype.
2. **`cardTheme` margin `(10,1,10,1)` on raw `Card`s.** Any screen that wraps a `Card` inside an
   already-padded `ListView` gets *double* horizontal inset → cards look narrower/misaligned vs. the
   `SoftCard`/`Container` screens. Prefer `SoftCard` everywhere, or drop the card margin and pad at the list.
3. **AppBar title.** `centerTitle` defaults differ iOS vs Android; the prototype left-aligns titles. Set
   `centerTitle: false` (and check `titleSpacing`) in `appBarTheme` for consistency.
4. **`surfaceTint` set to gray.** `colorScheme.surfaceTint` is a gray, so *any* elevated Material surface
   (Card, Menu, etc.) still gets a tonal overlay. The per-component `surfaceTintColor: Colors.transparent`
   above removes it where it shows.
5. **Dialog/menu/snackbar** insets and corner radii default to M3 until themed (covered above).

---

## Verification checklist (the real definition of done for the look)

Run light **and** dark for each:

- [ ] Bottom tab bar: **no pill** behind the active item; active = accent, inactive = `#ADA99F`, 78px, flat.
- [ ] Notifications toggle (Settings) is a flat accent switch, not an M3 tonal one.
- [ ] A snackbar (e.g. "Profile updated") is the ink floating pill, not the default gray bar.
- [ ] Sign-out dialog uses the warm surface + Bricolage title, accent/danger buttons.
- [ ] Split editor checkboxes/radios fill with accent, not M3 default purple-tint.
- [ ] No raw `Card` shows an elevation shadow + tonal tint different from `SoftCard`.
- [ ] Every text field matches the inset look (filled `surfaceContainer`, radius 16, no hard border).
- [ ] Screenshot each of the 15 screens in both brightnesses against the prototype — note any remaining
      stock-Material component and add its `*ThemeData` here.

---

## Suggested sequence

1. **E0-T5 (this doc) — component theme pass.** One file (`theme_builder.dart`), mostly additive. Biggest
   visual payoff; do it first. The nav-bar block alone removes the dominant "Material" read.
2. **Layout sweep.** Fix the `cardTheme` margin / `centerTitle` items, then screenshot all 15 screens
   light+dark and diff against the prototype.
3. **Per-screen polish.** Anything the screenshots surface that a component theme can't reach → fix in the
   widget, pulling from `Theme.of(context).colorScheme` / `SemanticColors` (never hard-code light hex).

This slots in **after E0-T4 and before the remaining per-screen polish** in `ROADMAP.md`.
