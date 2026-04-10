import 'package:deun/helper/helper.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:deun/l10n/app_localizations.dart';

class SettingsProfileForm extends ConsumerStatefulWidget {
  const SettingsProfileForm({super.key});

  @override
  ConsumerState<SettingsProfileForm> createState() => _SettingsProfileFormState();
}

class _SettingsProfileFormState extends ConsumerState<SettingsProfileForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  List<String> localeOptions = AppLocalizations.supportedLocales
      .map((l) => l.toLanguageTag())
      .toList();

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;
    const double heightSpacing = 12;

    final SupaUser? user = ref.watch(userDetailProvider).value;
    final locale = ref.watch(localeProvider);

    if (user == null) {
      return const SizedBox.shrink();
    }

    return FormBuilder(
      key: _formKey,
      clearValueOnUnregister: true,
      initialValue: user.toJson(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: spacing),
              Flexible(
                child: Column(
                  children: [
                    FormBuilderField(
                      name: "first_name",
                      builder: (FormFieldState<dynamic> field) => TextFormField(
                        initialValue: field.value,
                        validator: FormBuilderValidators.required(
                          errorText: AppLocalizations.of(context)!.settingsFirstNameValidationEmpty,
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.settingsFirstName,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onChanged: (value) => field.didChange(value),
                      ),
                    ),
                    const SizedBox(height: heightSpacing),
                    FormBuilderField(
                      name: "last_name",
                      builder: (FormFieldState<dynamic> field) => TextFormField(
                        initialValue: field.value,
                        validator: FormBuilderValidators.required(
                          errorText: AppLocalizations.of(context)!.settingsLastNameValidationEmpty,
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.settingsLastName,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onChanged: (value) => field.didChange(value),
                      ),
                    ),
                    const SizedBox(height: heightSpacing),
                    FormBuilderField(
                      name: "display_name",
                      builder: (FormFieldState<dynamic> field) => TextFormField(
                        initialValue: field.value,
                        validator: FormBuilderValidators.required(
                          errorText: AppLocalizations.of(context)!.settingsDisplayNameValidationEmpty,
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.settingsDisplayName,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onChanged: (value) => field.didChange(value),
                      ),
                    ),
                    const SizedBox(height: heightSpacing),
                    FormBuilderField(
                      name: "username",
                      builder: (FormFieldState<dynamic> field) => TextFormField(
                        initialValue: field.value,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.settingsUsername,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          suffixText: user.usernameCode != null ? '#${user.usernameCode}' : null,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: user.fullUsername));
                              showSnackBar(context, '${user.fullUsername} copied');
                            },
                          ),
                        ),
                        onChanged: (value) => field.didChange(value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: heightSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.payment),
              const SizedBox(width: spacing),
              Flexible(
                child: Column(
                  children: [
                    FormBuilderField(
                      name: "paypal_me",
                      builder: (FormFieldState<dynamic> field) => TextFormField(
                        initialValue: field.value,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.settingsPaypalMe,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixText: 'paypal.me/',
                        ),
                        onChanged: (value) => field.didChange(value),
                      ),
                    ),
                    const SizedBox(height: heightSpacing),
                    FormBuilderField(
                      name: "iban",
                      builder: (FormFieldState<dynamic> field) => TextFormField(
                        initialValue: field.value,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.settingsIban,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onChanged: (value) => field.didChange(value),
                      ),
                    ),
                    const SizedBox(height: heightSpacing),
                    FormBuilderDropdown(
                      name: 'locale',
                      initialValue: locale?.toLanguageTag(),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.settingsLocale,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(AppLocalizations.of(context)!.localeSelectorSystem),
                        ),
                        ...localeOptions.map(
                          (locale) => DropdownMenuItem(
                            value: locale,
                            child: Text(AppLocalizations.of(context)!.localeSelector(locale)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: heightSpacing),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                if (_formKey.currentState!.saveAndValidate()) {
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
                    if (context.mounted) {
                      showSnackBar(
                        context,
                        AppLocalizations.of(context)!.settingsUserUpdateSuccess,
                      );

                      if (_formKey.currentState!.value['locale'] == null) {
                        ref.read(localeProvider.notifier).resetLocale();
                      } else {
                        ref.read(localeProvider.notifier).setLocale(
                              Locale(_formKey.currentState!.value['locale']),
                            );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showSnackBar(
                        context,
                        AppLocalizations.of(context)!.settingsUserUpdateError,
                      );
                    }
                    debugPrint(e.toString());
                  } finally {
                    if (mounted) {
                      if (context.mounted) {
                        FocusScope.of(context).unfocus();
                      }
                    }
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.update),
            ),
          ),
        ],
      ),
    );
  }
}
