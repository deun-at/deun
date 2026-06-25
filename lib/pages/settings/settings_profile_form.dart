import 'package:deun/helper/helper.dart';
import 'package:deun/pages/settings/settings_sheets.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';

/// Restyled profile form (E7-T3, Screen 6). Soft inset fields + a Language row
/// that opens the [showLanguageSheet] picker. The save path is unchanged: the
/// locale still flows through a (now hidden) FormBuilder `locale` field so the
/// Update button's existing DB persistence keeps working.
class SettingsProfileForm extends ConsumerStatefulWidget {
  const SettingsProfileForm({super.key});

  @override
  ConsumerState<SettingsProfileForm> createState() => _SettingsProfileFormState();
}

class _SettingsProfileFormState extends ConsumerState<SettingsProfileForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    const double heightSpacing = 12;
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
          _InsetFormField(
            name: 'first_name',
            label: l10n.settingsFirstName,
            validator: FormBuilderValidators.required(
              errorText: l10n.settingsFirstNameValidationEmpty,
            ),
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'last_name',
            label: l10n.settingsLastName,
            validator: FormBuilderValidators.required(
              errorText: l10n.settingsLastNameValidationEmpty,
            ),
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'display_name',
            label: l10n.settingsDisplayName,
            validator: FormBuilderValidators.required(
              errorText: l10n.settingsDisplayNameValidationEmpty,
            ),
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'username',
            label: l10n.settingsUsername,
            suffixText: user.usernameCode != null ? '#${user.usernameCode}' : null,
            suffix: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: user.fullUsername));
                showSnackBar(context, AppLocalizations.of(context)!.settingsUsernameCopied(user.fullUsername));
              },
            ),
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'paypal_me',
            label: l10n.settingsPaypalMe,
            prefixText: 'paypal.me/',
          ),
          const SizedBox(height: heightSpacing),
          _InsetFormField(
            name: 'iban',
            label: l10n.settingsIban,
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
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _onSave,
              child: Text(l10n.update),
            ),
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

/// A soft inset [FormBuilderField] text input matching the redesign field look
/// (filled `surfaceContainer`, radius 16, no hard border). Per the v3 profile
/// form, fields carry no leading icon — they are label + value only.
class _InsetFormField extends StatelessWidget {
  const _InsetFormField({
    required this.name,
    required this.label,
    this.validator,
    this.suffixText,
    this.suffix,
    this.prefixText,
  });

  final String name;
  final String label;
  final String? Function(String?)? validator;
  final String? suffixText;
  final Widget? suffix;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    return FormBuilderField<String>(
      name: name,
      validator: validator,
      builder: (field) => TextFormField(
        initialValue: field.value,
        onChanged: field.didChange,
        decoration: InputDecoration(
          labelText: label,
          errorText: field.errorText,
          prefixText: prefixText,
          suffixText: suffixText,
          suffixIcon: suffix,
          filled: true,
          fillColor: colorScheme.surfaceContainer,
          border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// The tappable Language row (mirrors the inset field surface) showing the
/// current language and a chevron; tapping opens the language sheet.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.translate, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.settingsLocale,
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(value, style: textTheme.bodyLarge),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
