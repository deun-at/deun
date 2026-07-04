import 'package:deun/widgets/restyle/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

/// A form text field: the shared [AppTextField] in
/// [AppTextFieldLabelMode.above] (static label ABOVE the field, no floating
/// Material label — design F82/F146), bridged into the surrounding [FormBuilder]
/// so the existing keyed save path (`_formKey.currentState!.value`) is unchanged.
///
/// The field owns a [TextEditingController] seeded from its initial value and
/// pushes edits back via `field.didChange`, so validation, submit and DB
/// persistence behave exactly as before — only the label presentation changed
/// from floating to label-above. Shared by the Settings/Profile form and the
/// Contact form.
class InsetFormField extends StatefulWidget {
  const InsetFormField({
    super.key,
    required this.name,
    required this.label,
    this.initialValue,
    this.validator,
    this.suffix,
    this.prefixText,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
  });

  final String name;
  final String label;
  final String? initialValue;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final String? prefixText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;

  @override
  State<InsetFormField> createState() => _InsetFormFieldState();
}

class _InsetFormFieldState extends State<InsetFormField> {
  late final TextEditingController _controller;
  FormFieldState<String>? _field;

  @override
  void initState() {
    super.initState();
    // Seed from the same initial value the parent hands FormBuilder, so the
    // displayed text and the FormBuilder field agree from frame one without
    // touching the field during its build (which would re-enter didChange).
    _controller = TextEditingController(text: widget.initialValue ?? '');
    // Push every keystroke back into the bound FormBuilder field so the keyed
    // save path (`_formKey.currentState!.value`) sees live text — the same
    // contract the old TextFormField(onChanged: field.didChange) provided. The
    // listener only fires on real edits (after build), so no re-entrancy.
    _controller.addListener(() => _field?.didChange(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<String>(
      name: widget.name,
      initialValue: widget.initialValue,
      validator: widget.validator,
      builder: (field) {
        _field = field;
        return AppTextField(
          controller: _controller,
          label: widget.label,
          labelMode: AppTextFieldLabelMode.above,
          validator: widget.validator,
          suffix: widget.suffix,
          prefixText: widget.prefixText,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
        );
      },
    );
  }
}
