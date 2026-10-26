import 'package:deun/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

/// The expense's name, an inset field below the amount/category block (the name
/// stays persisted). [onNameTyped] hears every non-empty edit, for category
/// detection.
class EditorNameField extends StatelessWidget {
  const EditorNameField({
    super.key,
    required this.screenContext,
    required this.controller,
    required this.onNameTyped,
  });

  /// The screen's own context, above the group's `ThemeBuilder`: the field's
  /// colours come from the app's brand theme, not the group's.
  final BuildContext screenContext;
  final TextEditingController controller;
  final ValueChanged<String> onNameTyped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(screenContext).colorScheme;
    final radius = BorderRadius.circular(12);
    return FormBuilderField(
      name: "name",
      // Seeded from the controller, which is the value actually on screen.
      //
      // Without this the field's only source of truth was the onChanged
      // callback below, and its element lifetime is not stable: the Quick
      // branch above contributes 6 children to this Column and the Itemized
      // branch 4, so switching modes shifts this field two positions up an
      // unkeyed children list. Flutter reconciles unkeyed children by
      // position, so the field is deactivated and re-inflated, and
      // `clearValueOnUnregister: true` wipes whatever the user had typed —
      // while the name controller keeps the text visibly on screen. The expense
      // then saved with a null name and broke the expense list.
      //
      // expense_date next to it never had this problem precisely because it
      // carries an initialValue to re-register with.
      initialValue: controller.text,
      builder: (FormFieldState<dynamic> field) => TextFormField(
        key: const ValueKey('expense_name_field'),
        controller: controller,
        validator: FormBuilderValidators.required(
          errorText: l10n.expenseNameValidationEmpty,
        ),
        decoration: InputDecoration(
          hintText: l10n.expenseDescriptionHint,
          filled: true,
          // v3: description sits on a white card surface (not the grey field).
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
        onChanged: (value) {
          field.didChange(value);
          if (value.isNotEmpty) {
            onNameTyped(value);
          }
        },
      ),
    );
  }
}
