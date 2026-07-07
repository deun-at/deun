import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/auth/onboarding_username.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/deun_app.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen 3 — Onboarding username + display name (redesign).
///
/// A presentation-only restyle: the form, validation and the
/// `UserRepository.saveUsername` wiring (plus the `onComplete` /
/// `initialDisplayName` contract used by `auth_gate.dart`) are unchanged.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.initialDisplayName,
    required this.onComplete,
  });

  final String? initialDisplayName;
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _displayNameController;
  bool _isLoading = false;
  String? _errorMessage;

  /// The real discriminator is generated server-side by
  /// `UserRepository.saveUsername` and is only known after save, so the live
  /// preview shows a muted placeholder until then.
  static const _codePlaceholder = '0000';

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    final name = widget.initialDisplayName;
    _displayNameController = TextEditingController(
      text: (name != null && name != '-') ? name : '',
    );
    // Rebuild the live handle preview as the username field changes.
    _usernameController.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() => setState(() {});

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await UserRepository.saveUsername(
        _usernameController.text,
        _displayNameController.text.trim(),
      );
      widget.onComplete();
    } on PostgrestException catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(ctx)!.onboardingUsernameTaken;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(ctx)!.generalError;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeunApp(
      home: Builder(
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          final sanitized = sanitizeUsername(_usernameController.text);
          final handle = previewHandle(
            username: sanitized,
            codePlaceholder: _codePlaceholder,
          );

          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                            children: [
                              // Accent tile header.
                              Container(
                                height: 72,
                                width: 72,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.alternate_email,
                                  size: 34,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                l10n.onboardingUsernameHeading,
                                style: theme.textTheme.headlineMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.onboardingUsernameSubtitle,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              SectionLabel(l10n.onboardingUsernameLabel),
                              const SizedBox(height: 8),
                              _UsernameField(
                                controller: _usernameController,
                                codePlaceholder: _codePlaceholder,
                                hint: l10n.onboardingUsernameHint,
                                validator: (value) {
                                  if (value == null ||
                                      !isValidUsername(value)) {
                                    return l10n.onboardingUsernameInvalid;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              _HandlePreview(
                                prefix: l10n.onboardingHandlePreviewPrefix,
                                handle: handle,
                              ),
                              const SizedBox(height: 24),

                              SectionLabel(l10n.onboardingDisplayNameLabel),
                              const SizedBox(height: 8),
                              _InsetField(
                                controller: _displayNameController,
                                icon: Icons.person_outline,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(ctx),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return l10n
                                        .onboardingDisplayNameRequired;
                                  }
                                  return null;
                                },
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: colorScheme.error),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: PrimaryButton(
                            onPressed: _isLoading ? null : () => _submit(ctx),
                            label: l10n.onboardingButton,
                            loading: _isLoading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The username row: a leading `@` glyph, the editable username, and a trailing
/// fixed `#code` discriminator hint — all on the soft inset surface.
class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.controller,
    required this.codePlaceholder,
    required this.hint,
    required this.validator,
  });

  final TextEditingController controller;
  final String codePlaceholder;
  final String hint;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    return TextFormField(
      controller: controller,
      validator: validator,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Text(
            '@',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(
            '#$codePlaceholder',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: colorScheme.surfaceContainer,
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
    );
  }
}

/// The live "Friends will see @username#code" preview, with the handle in the
/// accent color, bold.
class _HandlePreview extends StatelessWidget {
  const _HandlePreview({required this.prefix, required this.handle});

  /// The localized lead-in copy (e.g. "Friends will see ").
  final String prefix;
  final String handle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.bodyMedium
        ?.copyWith(color: colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: prefix),
            TextSpan(
              text: handle,
              style: baseStyle?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A restyled inset text field on the field-fill surface, matching the
/// redesign's soft inputs (radius 16, no hard border, leading icon) — the same
/// treatment as `sign_in.dart`'s `_InsetField`.
class _InsetField extends StatelessWidget {
  const _InsetField({
    required this.controller,
    required this.icon,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    return TextFormField(
      controller: controller,
      validator: validator,
      textInputAction: textInputAction,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        // No in-field label: the SectionLabel above already names this field.
        // Material's floating labelText is banned app-wide (F82, see
        // AppTextField) — it duplicated the section label as a doubled
        // "Display Name" here.
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surfaceContainer,
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
    );
  }
}
