import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../main.dart';
import 'package:deun/l10n/app_localizations.dart';

class Contact extends StatefulWidget {
  const Contact({super.key});

  @override
  State<StatefulWidget> createState() => _ContactState();
}

class _ContactState extends State<StatefulWidget> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const double heightSpacing = 12;

    return Scaffold(
      body: NotificationListener<ScrollUpdateNotification>(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.medium(
              title: Text(AppLocalizations.of(context)!.contact),
            ),
          ],
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: FormBuilder(
                    key: _formKey,
                    clearValueOnUnregister: true,
                    child: Column(
                      children: [
                        FormBuilderField(
                          name: "name",
                          builder: (FormFieldState<dynamic> field) => TextFormField(
                            initialValue: field.value,
                            validator: FormBuilderValidators.required(
                                errorText: AppLocalizations.of(context)!.contactNameValidationEmpty),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.contactName,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) => field.didChange(value),
                          ),
                        ),
                        const SizedBox(height: heightSpacing),
                        FormBuilderField(
                          name: "company",
                          builder: (FormFieldState<dynamic> field) => TextFormField(
                            initialValue: field.value,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.contactCompany,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) => field.didChange(value),
                          ),
                        ),
                        const SizedBox(height: heightSpacing),
                        FormBuilderField(
                          name: "email",
                          builder: (FormFieldState<dynamic> field) => TextFormField(
                            initialValue: field.value,
                            validator: FormBuilderValidators.required(
                                errorText: AppLocalizations.of(context)!.contactEmailValidationEmpty),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.contactEmail,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) => field.didChange(value),
                          ),
                        ),
                        const SizedBox(height: heightSpacing),
                        FormBuilderField(
                          name: "description",
                          builder: (FormFieldState<dynamic> field) => TextFormField(
                            initialValue: field.value,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            validator: FormBuilderValidators.required(
                                errorText: AppLocalizations.of(context)!.contactDescriptionValidationEmpty),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.contactDescription,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) => field.didChange(value),
                          ),
                        ),
                        const SizedBox(height: heightSpacing),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () async {
                              if (_formKey.currentState!.saveAndValidate()) {
                                try {
                                  sendContactMail(_formKey.currentState!.value);
                                  if (context.mounted) {
                                    showSnackBar(context, rootScaffoldMessengerKey,
                                        AppLocalizations.of(context)!.contactSendSuccess);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    showSnackBar(context, rootScaffoldMessengerKey,
                                        AppLocalizations.of(context)!.contactSendError);
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
                            child: Text(AppLocalizations.of(context)!.send),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
