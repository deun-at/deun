import 'package:flutter/material.dart';

import 'package:deun/constants.dart';

/// The app's two input-field patterns (design F82).
///
/// Material's floating/animating `InputDecoration` label is banned app-wide:
/// no label may animate from inside the border up to the top border. Instead
/// there are exactly two patterns, both provided by [AppTextField]:
///
/// * [AppTextFieldLabelMode.placeholder] — the label sits INSIDE the field as a
///   hint/placeholder that disappears on input and NEVER floats up. Used by the
///   login / auth fields (v3 prototype: white fill, radius 14, no leading icon,
///   `w600` value text, soft card shadow).
/// * [AppTextFieldLabelMode.above] — a static label rendered ABOVE the field.
///   Used everywhere else (Settings/Profile forms, etc.).
///
/// Both modes share the same white ([ColorScheme.surfaceContainerLowest]) field
/// on the spec input shadow, so the two patterns read as one family.
enum AppTextFieldLabelMode {
  /// Label lives inside the field as a placeholder (login/auth).
  placeholder,

  /// Static label rendered above the field (everywhere else).
  above,
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.labelMode = AppTextFieldLabelMode.above,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.prefixText,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;

  /// The field's label text. In [AppTextFieldLabelMode.placeholder] it is the
  /// in-field placeholder; in [AppTextFieldLabelMode.above] it is the static
  /// label above the field. Either way it is NEVER a floating Material label.
  final String label;

  final AppTextFieldLabelMode labelMode;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;

  /// Optional muted inline prefix (e.g. `paypal.me/`). Only meaningful in
  /// [AppTextFieldLabelMode.above]; rendered via [InputDecoration.prefixText]
  /// in the muted [ColorScheme.onSurfaceVariant] token (spec placeholder tone).
  final String? prefixText;

  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isPlaceholder = labelMode == AppTextFieldLabelMode.placeholder;
    // Placeholder (login) inputs are white cards: radius 14, soft shadow
    // (mockup L830). Label-above (profile) inputs are flat beige inset boxes:
    // fill surfaceContainer (#F4F3EF), radius 12, NO shadow (mockup L353/369/377).
    final radius = BorderRadius.circular(isPlaceholder ? 14 : 12);
    final fillColor =
        isPlaceholder ? colorScheme.surfaceContainerLowest : colorScheme.surfaceContainer;

    final field = DecoratedBox(
      // Spec input shadow (0 2px 4px rgba(20,18,12,.04)); placeholder-mode only,
      // and omitted in dark where the lighter card surface carries elevation
      // instead — mirrors SoftCard. Above-mode is flat (no shadow).
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: isPlaceholder && !isDark ? kSoftCardShadow : null,
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        obscureText: obscureText,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onFieldSubmitted: onFieldSubmitted,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          // Placeholder mode: the label is a hintText — it shows when empty,
          // disappears on input, and never animates to the border. Above mode:
          // the label is rendered separately below, so no in-field text here.
          // Neither mode ever sets labelText (the floating Material label).
          hintText: isPlaceholder ? label : null,
          suffixIcon: suffix,
          // Muted inline prefix (above-mode only), spec placeholder tone.
          prefixText: isPlaceholder ? null : prefixText,
          prefixStyle: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
          // Above-mode uses the spec inset padding (11×13); placeholder-mode
          // keeps Material's default so the login cards stay their taller size.
          contentPadding: isPlaceholder
              ? null
              : const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          filled: true,
          // Placeholder: white card surface. Above: flat beige inset surface.
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );

    if (isPlaceholder) return field;

    // Label-above mode: static label above the field (never floats).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        field,
      ],
    );
  }
}
