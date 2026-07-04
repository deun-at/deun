import 'package:deun/helper/helper.dart';
import 'package:deun/pages/settings/settings_sheets.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/inset_form_field.dart';
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
                child: InsetFormField(
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
                child: InsetFormField(
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
          InsetFormField(
            name: 'display_name',
            label: l10n.settingsDisplayName,
            initialValue: user.displayName,
            validator: FormBuilderValidators.required(
              errorText: l10n.settingsDisplayNameValidationEmpty,
            ),
          ),
          const SizedBox(height: heightSpacing),
          InsetFormField(
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
          // Muted `paypal.me/` inline prefix + username inside the field
          // (mockup L369, prefix ≈ #B6B2A8 → onSurfaceVariant). Fixed brand
          // literal, not localized.
          InsetFormField(
            name: 'paypal_me',
            label: l10n.settingsPaypalMe,
            initialValue: user.paypalMe,
            prefixText: 'paypal.me/',
          ),
          const SizedBox(height: heightSpacing),
          InsetFormField(
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

/// The tappable Language row. Per v3 (and consistent with the iconless
/// [InsetFormField] styling that F09/F11 established), this carries no leading
/// translate icon: it is a label-above + current value with a trailing dropdown
/// chevron ([Icons.expand_more], v3 `chevron_down`) so it reads as a dropdown
/// selector rather than a navigate-forward row. F171 moved the label above the
/// box (matching the text fields) so the value box is a pixel-identical sibling
/// of the [InsetFormField] inputs. Tapping still opens the language sheet.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(12);

    // Label-above, matching the text fields (F171): static titleSmall w600
    // onSurfaceVariant label + 6px gap over a surfaceContainer r12 value box.
    // After F169 the box is a pixel-identical sibling of the text-field inputs.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            AppLocalizations.of(context)!.settingsLocale,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Material(
          color: colorScheme.surfaceContainer,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              // Match AppTextField above-mode inset padding (13×11).
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
