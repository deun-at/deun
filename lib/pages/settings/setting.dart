import 'package:async_preferences/async_preferences.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/initialization_helper.dart';
import 'package:deun/widgets/shimmer_card_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import 'package:deun/l10n/app_localizations.dart';

class Setting extends ConsumerStatefulWidget {
  const Setting({super.key});

  @override
  ConsumerState<Setting> createState() => _SettingState();
}

class _SettingState extends ConsumerState<Setting> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _initializationHelper = InitializationHelper();

// We will use a Future to read the setting that
  // tells us if the user is under the GDPR
  late final Future<bool> _future;

  @override
  void initState() {
    super.initState();

    _future = _isUnderGdpr();
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;
    const double heightSpacing = 12;

    return Scaffold(
      body: NotificationListener<ScrollUpdateNotification>(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.medium(
              title: Text(AppLocalizations.of(context)!.settings),
              actions: [
                IconButton(
                  onPressed: () async {
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
                            ));
                  },
                  icon: const Icon(Icons.logout),
                )
              ],
            ),
          ],
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    AppLocalizations.of(context)!.settingsUserHeading,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final User? user = ref.watch(userDetailNotifierProvider).value;

                      if (user == null) {
                        return const ShimmerCardList(
                          height: 54,
                          listEntryLength: 5,
                        );
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
                                const Icon(
                                  Icons.person_outline,
                                ),
                                const SizedBox(width: spacing),
                                Flexible(
                                  child: Column(
                                    children: [
                                      FormBuilderField(
                                        name: "first_name",
                                        builder: (FormFieldState<dynamic> field) => TextFormField(
                                          initialValue: field.value,
                                          validator: FormBuilderValidators.required(
                                              errorText:
                                                  AppLocalizations.of(context)!.settingsFirstNameValidationEmpty),
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context)!.settingsFirstName,
                                            border: const OutlineInputBorder(),
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
                                              errorText: AppLocalizations.of(context)!.settingsLastNameValidationEmpty),
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context)!.settingsLastName,
                                            border: const OutlineInputBorder(),
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
                                              errorText:
                                                  AppLocalizations.of(context)!.settingsDisplayNameValidationEmpty),
                                          decoration: InputDecoration(
                                            labelText: AppLocalizations.of(context)!.settingsDisplayName,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (value) => field.didChange(value),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: heightSpacing),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.payment,
                                ),
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
                                            border: const OutlineInputBorder(),
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
                                            border: const OutlineInputBorder(),
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () async {
                                  if (_formKey.currentState!.saveAndValidate()) {
                                    try {
                                      await User.saveAll(_formKey.currentState!.value);
                                      if (context.mounted) {
                                        showSnackBar(context, rootScaffoldMessengerKey,
                                            AppLocalizations.of(context)!.settingsUserUpdateSuccess);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        showSnackBar(context, rootScaffoldMessengerKey,
                                            AppLocalizations.of(context)!.settingsUserUpdateError);
                                      }
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
                    },
                  ),
                ),
                Divider(),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.settingsPrivacyPolicy),
                  onTap: () {
                    GoRouter.of(context).push('/setting/privacy-policy');
                  },
                ),
                FutureBuilder(
                  future: _future,
                  builder: (context, snapshot) {
                    // Show it only if the user is under the GDPR
                    if (snapshot.hasData && snapshot.data == true) {
                      return ListTile(
                          title: Text(AppLocalizations.of(context)!.settingsPrivacyPreferences),
                          onTap: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(context);

                            // Show the consent message again
                            final didChangePreferences = await _initializationHelper.changePrivacyPreferences();

                            // Give feedback to the user that their
                            // preferences have been correctly modified
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  didChangePreferences
                                      ? AppLocalizations.of(context)!.settingsPrivacyPreferencesSuccess
                                      : AppLocalizations.of(context)!.settingsPrivacyPreferencesError,
                                ),
                              ),
                            );
                          });
                    } else {
                      return SizedBox();
                    }
                  },
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.contact),
                  onTap: () {
                    GoRouter.of(context).push('/setting/contact');
                  },
                ),
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

  Future<bool> _isUnderGdpr() async {
    // Initialize AsyncPreferences and checks if the IABTCF_gdprApplies
    // parameter is 1, if it is the user is under the GDPR,
    // any other value could be interpreted as not under the GDPR
    final preferences = AsyncPreferences();
    return await preferences.getInt('IABTCF_gdprApplies') == 1;
  }
}
