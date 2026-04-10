import 'package:async_preferences/async_preferences.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/widgets/initialization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../widgets/card_list_view_builder.dart';
import 'settings_profile_form.dart';

class Setting extends ConsumerStatefulWidget {
  const Setting({super.key});

  @override
  ConsumerState<Setting> createState() => _SettingState();
}

class _SettingState extends ConsumerState<Setting> {
  final _initializationHelper = InitializationHelper();

  late final Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _isUnderGdpr();
  }

  @override
  Widget build(BuildContext context) {
    const double heightSpacing = 12;

    return Scaffold(
      body: NotificationListener<ScrollUpdateNotification>(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.medium(
              title: Text(
                AppLocalizations.of(context)!.settings,
                style: GoogleFonts.robotoSerif(
                  textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () async {
                    _showSignOutDialog(context);
                  },
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ],
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SettingsProfileForm(),
                ),
                SizedBox(height: heightSpacing),
                _buildNavigationSection(context, heightSpacing),
              ],
            ),
          ),
        ),
        onNotification: (ScrollUpdateNotification notification) {
          final FocusScopeNode currentScope = FocusScope.of(context);
          if (notification.dragDetails != null && !currentScope.hasPrimaryFocus && currentScope.hasFocus) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
          return false;
        },
      ),
    );
  }

  Widget _buildNavigationSection(BuildContext context, double heightSpacing) {
    return Column(
      children: [
        CardListTile(
          isTop: true,
          child: ListTile(
            title: Text(AppLocalizations.of(context)!.settingsPrivacyPolicy),
            onTap: () {
              GoRouter.of(context).push('/setting/privacy-policy');
            },
          ),
        ),
        FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return CardListTile(
                child: ListTile(
                  title: Text(AppLocalizations.of(context)!.settingsPrivacyPreferences),
                  onTap: () async {
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
                  },
                ),
              );
            } else {
              return SizedBox();
            }
          },
        ),
        CardListTile(
          isBottom: true,
          child: ListTile(
            title: Text(AppLocalizations.of(context)!.contact),
            onTap: () {
              GoRouter.of(context).push('/setting/contact');
            },
          ),
        ),
        SizedBox(height: heightSpacing),
        CardListTile(
          isTop: true,
          isBottom: true,
          child: ListTile(
            title: Text(AppLocalizations.of(context)!.deleteAccount),
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            leading: Icon(Icons.delete),
            onTap: () async {
              _showDeleteUserDialog(context);
            },
          ),
        ),
      ],
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

  void _showDeleteUserDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.deleteAccount),
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
            child: Text(AppLocalizations.of(context)!.delete),
            onPressed: () async {
              try {
                await supabase.functions.invoke('delete-user-account');
                await supabase.auth.signOut();
              } catch (e) {
                if (context.mounted) {
                  showSnackBar(context, AppLocalizations.of(context)!.deleteAccountError);
                }
              }
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
