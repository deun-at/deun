import 'package:deun/helper/helper.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    const double spacing = 8;

    return Scaffold(
      // appBar: AppBar(
      //   centerTitle: true,
      //   title: Text(AppLocalizations.of(context)!.settings),
      //   actions: [
      //     IconButton.filledTonal(
      //       onPressed: () async {
      //         showDialog(
      //             context: context,
      //             builder: (context) => AlertDialog(
      //                   content: Text(AppLocalizations.of(context)!.settingsSignOutDialogTitle),
      //                   actions: <Widget>[
      //                     TextButton(
      //                       child: Text(AppLocalizations.of(context)!.cancel),
      //                       onPressed: () => Navigator.pop(context),
      //                     ),
      //                     FilledButton(
      //                       style: FilledButton.styleFrom(
      //                         backgroundColor: Theme.of(context).colorScheme.error,
      //                         foregroundColor: Theme.of(context).colorScheme.onError,
      //                       ),
      //                       child: Text(AppLocalizations.of(context)!.settingsSignOut),
      //                       onPressed: () async {
      //                         await supabase.auth.signOut();
      //                       },
      //                     ),
      //                   ],
      //                 ));
      //       },
      //       icon: const Icon(Icons.logout),
      //     )
      //   ],
      // ),
      body: NestedScrollView(
        // controller: _scrollController,
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
                        listEntryLength: 4,
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
                                            errorText: AppLocalizations.of(context)!.settingsFirstNameValidationEmpty),
                                        decoration: InputDecoration(
                                          labelText: AppLocalizations.of(context)!.settingsFirstName,
                                          border: const OutlineInputBorder(),
                                        ),
                                        onChanged: (value) => field.didChange(value),
                                      ),
                                    ),
                                    const SizedBox(height: spacing),
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
                                    const SizedBox(height: spacing),
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
                          const SizedBox(height: spacing),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.payment,
                              ),
                              const SizedBox(width: spacing),
                              FormBuilderField(
                                name: "paypal_me",
                                builder: (FormFieldState<dynamic> field) => Flexible(
                                  child: TextFormField(
                                    initialValue: field.value,
                                    decoration: InputDecoration(
                                      labelText: AppLocalizations.of(context)!.settingsPaypalMe,
                                      border: const OutlineInputBorder(),
                                      prefixText: 'paypal.me/',
                                    ),
                                    onChanged: (value) => field.didChange(value),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: spacing),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () async {
                                if (_formKey.currentState!.saveAndValidate()) {
                                  // ref.read(_isLoading.notifier).state = true; // Set loading to true
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
                                      // ref.read(_isLoading.notifier).state = false; // Stop loading
                                      if (context.mounted) {
                                        FocusScope.of(context).unfocus();
                                        // Navigator.pop(context);
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
            ],
          ),
        ),
      ),
    );
  }
}
