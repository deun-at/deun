import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The three Settings bottom sheets (E7-T3, Screen 6): Language, Appearance and
/// the type-DELETE account-deletion sheet. All use [SheetScaffold] +
/// [showModalBottomSheet] and drive existing providers / Supabase calls.

/// Opens the Language picker sheet. Tapping an option drives the existing
/// [localeProvider] (System → `resetLocale`, otherwise `setLocale`) and reports
/// the chosen language tag (or `null` for System) via [onSelected] so the caller
/// can keep the profile-form save in sync. Closes itself on selection.
void showLanguageSheet(
  BuildContext context, {
  required String? currentTag,
  required void Function(String? tag) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    builder: (_) => _LanguageSheet(currentTag: currentTag, onSelected: onSelected),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet({required this.currentTag, required this.onSelected});

  final String? currentTag;
  final void Function(String? tag) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final options = AppLocalizations.supportedLocales.map((l) => l.toLanguageTag()).toList();

    void choose(String? tag) {
      if (tag == null) {
        ref.read(localeProvider.notifier).resetLocale();
      } else {
        ref.read(localeProvider.notifier).setLocale(Locale(tag));
      }
      onSelected(tag);
      Navigator.pop(context);
    }

    return SheetScaffold(
      title: l10n.settingsLanguageSheetTitle,
      body: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _OptionRow(
              label: l10n.localeSelectorSystem,
              selected: currentTag == null,
              onTap: () => choose(null),
            ),
            for (final tag in options)
              _OptionRow(
                label: l10n.localeSelector(tag),
                selected: currentTag == tag,
                onTap: () => choose(tag),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the Appearance picker sheet. Tapping an option sets the persisted
/// [themeModeProvider] and closes the sheet. Below the options sits an
/// accent-tinted info callout.
void showAppearanceSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    builder: (_) => const _AppearanceSheet(),
  );
}

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final current = ref.watch(themeModeProvider);

    void choose(ThemeMode mode) {
      ref.read(themeModeProvider.notifier).setThemeMode(mode);
      Navigator.pop(context);
    }

    return SheetScaffold(
      title: l10n.settingsAppearance,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _OptionRow(
                  label: l10n.settingsAppearanceSystem,
                  leading: Icons.brightness_auto,
                  selected: current == ThemeMode.system,
                  onTap: () => choose(ThemeMode.system),
                ),
                _OptionRow(
                  label: l10n.settingsAppearanceLight,
                  leading: Icons.light_mode,
                  selected: current == ThemeMode.light,
                  onTap: () => choose(ThemeMode.light),
                ),
                _OptionRow(
                  label: l10n.settingsAppearanceDark,
                  leading: Icons.dark_mode,
                  selected: current == ThemeMode.dark,
                  onTap: () => choose(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, size: 20, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsAppearanceInfo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable option row (used by the Language and Appearance sheets). Shows
/// an accent [Icons.check_circle] when [selected].
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, size: 22, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colorScheme.primary)
            else
              Icon(Icons.circle_outlined, color: colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

/// Opens the type-DELETE account-deletion sheet. Ports the existing dialog's
/// logic: the destructive button enables only when the input matches
/// [AppLocalizations.deleteAccountConfirmKeyword], then invokes the
/// `delete-user-account` edge function and signs out. Cancel closes.
void showDeleteAccountSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnimationStyle,
    barrierColor: kSheetBarrierColor,
    builder: (_) => const _DeleteAccountSheet(),
  );
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final keyword = l10n.deleteAccountConfirmKeyword;
    final isConfirmed = _controller.text.trim().toUpperCase() == keyword.toUpperCase();
    final radius = BorderRadius.circular(16);

    return SheetScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning, color: colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(l10n.settingsDeleteAccountTitle, style: textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsDeleteAccountBody,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: keyword,
              helperText: l10n.deleteAccountConfirmHint(keyword),
              filled: true,
              fillColor: colorScheme.surfaceContainer,
              border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: colorScheme.error, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: l10n.cancel,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: l10n.settingsDeleteAccountConfirmButton,
              background: colorScheme.error,
              foreground: colorScheme.onError,
              onPressed: !isConfirmed ? null : () => _deleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await supabase.functions.invoke('delete-user-account');
      await supabase.auth.signOut();
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, l10n.deleteAccountError);
      }
    }
  }
}
