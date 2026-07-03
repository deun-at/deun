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
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isPlaceholder = labelMode == AppTextFieldLabelMode.placeholder;
    final radius = BorderRadius.circular(14);

    final field = DecoratedBox(
      // Spec input shadow (0 2px 4px rgba(20,18,12,.04)); omitted in dark where
      // the lighter card surface carries elevation instead — mirrors SoftCard.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: isDark ? null : kSoftCardShadow,
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
          filled: true,
          // White card surface (DESIGN_SPEC "Card surface" = inputs).
          fillColor: colorScheme.surfaceContainerLowest,
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
