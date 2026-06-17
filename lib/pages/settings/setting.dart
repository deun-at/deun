import 'package:async_preferences/async_preferences.dart';
import 'package:deun/constants.dart';
import 'package:deun/pages/settings/settings_sheets.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/initialization_helper.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import 'package:deun/l10n/app_localizations.dart';

import 'settings_profile_form.dart';

class Setting extends ConsumerStatefulWidget {
  const Setting({super.key});

  @override
  ConsumerState<Setting> createState() => _SettingState();
}

class _SettingState extends ConsumerState<Setting> {
  final _initializationHelper = InitializationHelper();

  late final Future<bool> _gdprFuture;

  @override
  void initState() {
    super.initState();
    _gdprFuture = _isUnderGdpr();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(userDetailProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Header row: title + sign-out icon button.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.settings, style: theme.textTheme.headlineMedium),
                  ),
                  IconButton(
                    tooltip: l10n.settingsSignOut,
                    onPressed: () => _showSignOutDialog(context),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.5),
                    ),
                    icon: Icon(Icons.logout, color: colorScheme.error),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (user != null) _ProfileHeroCard(user: user),
            const SizedBox(height: 24),
            SectionLabel(l10n.settingsProfileSection),
            const SizedBox(height: 8),
            const SoftCard(child: SettingsProfileForm()),
            const SizedBox(height: 24),
            SectionLabel(l10n.settingsPreferencesSection),
            const SizedBox(height: 8),
            _buildSettingsList(context),
            const SizedBox(height: 24),
            _buildDeleteCard(context),
            const SizedBox(height: 28),
            Center(
              child: Text(
                l10n.settingsTagline,
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);

    final String appearanceLabel = switch (themeMode) {
      ThemeMode.system => l10n.settingsAppearanceSystem,
      ThemeMode.light => l10n.settingsAppearanceLight,
      ThemeMode.dark => l10n.settingsAppearanceDark,
    };

    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.insights_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
            label: l10n.statisticsPersonalOverviewEntry,
            onTap: () => GoRouter.of(context).push('/setting/statistics'),
          ),
          const _RowDivider(),
          _SettingsRow(
            icon: Icons.notifications_outlined,
            label: l10n.settingsNotifications,
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (v) =>
                  ref.read(notificationsEnabledProvider.notifier).setEnabled(v),
            ),
          ),
          const _RowDivider(),
          _SettingsRow(
            icon: Icons.palette_outlined,
            label: l10n.settingsAppearance,
            valueLabel: appearanceLabel,
            onTap: () => showAppearanceSheet(context),
          ),
          const _RowDivider(),
          _SettingsRow(
            icon: Icons.shield_outlined,
            label: l10n.settingsPrivacyPolicy,
            onTap: () => GoRouter.of(context).push('/setting/privacy-policy'),
          ),
          // GDPR-only privacy preferences row (existing behavior preserved).
          FutureBuilder<bool>(
            future: _gdprFuture,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return Column(
                children: [
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.settingsPrivacyPreferences,
                    onTap: () => _changePrivacyPreferences(context),
                  ),
                ],
              );
            },
          ),
          const _RowDivider(),
          _SettingsRow(
            icon: Icons.mail_outline,
            label: l10n.contact,
            onTap: () => GoRouter.of(context).push('/setting/contact'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: _SettingsRow(
        icon: Icons.delete_outline,
        iconColor: colorScheme.error,
        labelColor: colorScheme.error,
        label: l10n.deleteAccount,
        onTap: () => showDeleteAccountSheet(context),
      ),
    );
  }

  Future<void> _changePrivacyPreferences(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final didChangePreferences = await _initializationHelper.changePrivacyPreferences();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          didChangePreferences
              ? l10n.settingsPrivacyPreferencesSuccess
              : l10n.settingsPrivacyPreferencesError,
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.settingsSignOutDialogTitle),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.settingsSignOut),
            onPressed: () async {
              await supabase.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _isUnderGdpr() async {
    final preferences = AsyncPreferences();
    return await preferences.getInt('IABTCF_gdprApplies') == 1;
  }
}

/// Dark hero profile card: avatar + display name + `@username#code · email`.
/// Mirrors the established dark-hero treatment ([_OverallBalanceHero] /
/// [PersonalSummarySection]).
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user});

  final SupaUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color heroSurface = isDark ? colorScheme.surfaceBright : colorScheme.onSurface;
    final Color onHero = isDark ? colorScheme.onSurface : colorScheme.surface;
    final Color onHeroMuted = onHero.withValues(alpha: 0.7);

    final displayName = user.displayName.isNotEmpty ? user.displayName : user.email;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: heroSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? null : kDarkHeroShadow,
      ),
      child: Row(
        children: [
          MemberAvatar(name: displayName, colorKey: user.email, isYou: true, radius: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleLarge?.copyWith(color: onHero),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _IdentityLine(user: user, onHero: onHero, onHeroMuted: onHeroMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The `@username#code · email` line, with the code dimmed.
class _IdentityLine extends StatelessWidget {
  const _IdentityLine({required this.user, required this.onHero, required this.onHeroMuted});

  final SupaUser user;
  final Color onHero;
  final Color onHeroMuted;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final mutedStyle = style?.copyWith(color: onHeroMuted);

    return Text.rich(
      TextSpan(
        style: style?.copyWith(color: onHero),
        children: [
          if (user.username != null) ...[
            TextSpan(text: '@${user.username}'),
            if (user.usernameCode != null)
              TextSpan(text: '#${user.usernameCode}', style: mutedStyle),
            TextSpan(text: '  ·  ', style: mutedStyle),
          ],
          TextSpan(text: user.email, style: mutedStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// One settings list row: leading icon, label, optional trailing value label /
/// chevron or a custom [trailing] widget.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.valueLabel,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? valueLabel;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget? trailingWidget = trailing;
    if (trailingWidget == null && onTap != null) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (valueLabel != null)
            Text(
              valueLabel!,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: textTheme.titleSmall?.copyWith(color: labelColor),
              ),
            ),
            ?trailingWidget,
          ],
        ),
      ),
    );
  }
}

/// Hairline divider between settings rows, inset to match the row padding.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}
