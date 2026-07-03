import 'package:deun/helper/helper.dart';
import 'package:deun/pages/settings/settings_sheets.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/app_text_field.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';

/// Restyled profile form (E7-T3, Screen 6). The whole form is grouped inside
/// the single grouping [SoftCard] provided by the parent settings screen (v3
/// white card surface, radius 18, soft shadow); the inset fields and the
/// Language row that opens the [showLanguageSheet] picker sit as tight,
/// borderless inset rows (radius 12, 11px gap) inside that one card. The save
/// path is unchanged: the locale still flows through a (now hidden) FormBuilder
/// `locale` field so the Update button's existing DB persistence keeps working.
class SettingsProfileForm extends ConsumerStatefulWidget {
  const SettingsProfileForm({super.key});

  @override
  ConsumerState<SettingsProfileForm> createState() => _SettingsProfileFormState();
}

class _SettingsProfileFormState extends ConsumerState<SettingsProfileForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    // v3 profile card stacks fields with an 11px inter-row gap inside the card.
    const double heightSpacing = 11;
    final l10n = AppLocalizations.of(context)!;

    final SupaUser? user = ref.watch(userDetailProvider).value;
    final locale = ref.watch(localeProvider);

    if (user == null) {
      return const SizedBox.shrink();
    }

    final String? localeTag = locale?.toLanguageTag();
    final String languageLabel =
        localeTag == null ? l10n.localeSelectorSystem : l10n.localeSelector(localeTag);

    return FormBuilder(
      key: _formKey,
      clearValueOnUnregister: true,
      initialValue: user.toJson(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // First + Last name share a single two-column row (v3 profile form).
          // crossAxisAlignment.start keeps the pair top-aligned if one field
          // shows a validation error and grows taller than the other.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InsetFormField(
                  name: 'first_name',
                  label: l10n.settingsFirstName,
                  initialValue: user.firstName,
                  validator: FormBuilderValidators.required(
                    errorText: l10n.settingsFirstNameValidationEmpty,
                  ),
                ),
              ),
              const SizedBox(width: heightSpacing),
              Expanded(
                child: _InsetFormField(
                  name: 'last_name',
                  label: l10n.settingsLastName,
                  initialValue: user.lastName,
                  validator: FormBuilderValidators.required(
                    errorText: l10n.settingsLastNameValidationEmpty,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'display_name',
            label: l10n.settingsDisplayName,
            initialValue: user.displayName,
            validator: FormBuilderValidators.required(
              errorText: l10n.settingsDisplayNameValidationEmpty,
            ),
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'username',
            label: l10n.settingsUsername,
            initialValue: user.username,
            // #code discriminator + copy action ride together in the suffix so
            // the label-above field keeps both affordances (AppTextField exposes
            // a single suffix slot; no floating suffixText).
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.usernameCode != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '#${user.usernameCode}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user.fullUsername));
                    showSnackBar(context,
                        AppLocalizations.of(context)!.settingsUsernameCopied(user.fullUsername));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: heightSpacing),
          // paypal.me/ was an in-field prefix on the old floating-label input;
          // AppTextField has no prefix slot and must not be modified, so the
          // "PayPal.me" label above now carries that meaning. ponytail: drop the
          // inline prefix rather than fork AppTextField for one field.
          _InsetFormField(
            name: 'paypal_me',
            label: l10n.settingsPaypalMe,
            initialValue: user.paypalMe,
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'iban',
            label: l10n.settingsIban,
            initialValue: user.iban,
          ),
          const SizedBox(height: heightSpacing),
          // Language row → opens the picker sheet. The value is kept in a hidden
          // FormBuilder field so the existing save path persists it.
          FormBuilderField<String>(
            name: 'locale',
            initialValue: localeTag,
            builder: (field) => _LanguageRow(
              value: languageLabel,
              onTap: () => showLanguageSheet(
                context,
                currentTag: field.value,
                onSelected: (tag) => field.didChange(tag),
              ),
            ),
          ),
          const SizedBox(height: heightSpacing),
          PrimaryButton(
            label: l10n.update,
            onPressed: _onSave,
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    final user = ref.read(userDetailProvider).value;
    if (user == null) return;
    if (!_formKey.currentState!.saveAndValidate()) return;

    try {
      final formValue = _formKey.currentState!.value;
      final newUsername = formValue['username'] as String?;
      final usernameChanged =
          newUsername != null && newUsername.isNotEmpty && newUsername != user.username;

      if (usernameChanged) {
        await UserRepository.saveUsername(
          newUsername,
          formValue['display_name'] ?? user.displayName,
        );
      }

      await UserRepository.saveProfileData(formValue);
      ref.invalidate(userDetailProvider);
      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.settingsUserUpdateSuccess);

        final localeValue = _formKey.currentState!.value['locale'];
        if (localeValue == null) {
          ref.read(localeProvider.notifier).resetLocale();
        } else {
          ref.read(localeProvider.notifier).setLocale(Locale(localeValue));
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.settingsUserUpdateError);
      }
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    }
  }
}

/// A profile text field: the shared [AppTextField] in
/// [AppTextFieldLabelMode.above] (static label ABOVE the field, no floating
/// Material label — design F146/F82), bridged into the surrounding [FormBuilder]
/// so the existing keyed save path (`_formKey.currentState!.value`) is unchanged.
///
/// The field owns a [TextEditingController] seeded from the FormBuilder field's
/// initial value and pushes edits back via `field.didChange`, so validation,
/// submit and DB persistence behave exactly as before — only the label
/// presentation changed from floating to label-above.
class _InsetFormField extends StatefulWidget {
  const _InsetFormField({
    required this.name,
    required this.label,
    this.initialValue,
    this.validator,
    this.suffix,
  });

  final String name;
  final String label;
  final String? initialValue;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  State<_InsetFormField> createState() => _InsetFormFieldState();
}

class _InsetFormFieldState extends State<_InsetFormField> {
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
        );
      },
    );
  }
}

/// The tappable Language row. Per v3 (and consistent with the iconless
/// [_InsetFormField] styling that F09/F11 established), this carries no leading
/// translate icon: it is a floating label + current value with a trailing
/// dropdown chevron ([Icons.expand_more], v3 `chevron_down`) so it reads as a
/// dropdown selector rather than a navigate-forward row. Tapping still opens
/// the language sheet — only the icon/chevron presentation changed.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.settingsLocale,
            filled: true,
            fillColor: colorScheme.surfaceContainer,
            border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
            suffixIcon: Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
          ),
          child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}
