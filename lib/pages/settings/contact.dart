import 'package:deun/helper/helper.dart';
import 'package:deun/widgets/restyle/inset_form_field.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

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
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: Text(AppLocalizations.of(context)!.contactSubtitle),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: FormBuilder(
                    key: _formKey,
                    clearValueOnUnregister: true,
                    child: Column(
                      children: [
                        InsetFormField(
                          name: "name",
                          label: AppLocalizations.of(context)!.contactName,
                          validator: FormBuilderValidators.required(
                              errorText: AppLocalizations.of(context)!.contactNameValidationEmpty),
                        ),
                        const SizedBox(height: heightSpacing),
                        InsetFormField(
                          name: "company",
                          label: AppLocalizations.of(context)!.contactCompany,
                        ),
                        const SizedBox(height: heightSpacing),
                        InsetFormField(
                          name: "email",
                          label: AppLocalizations.of(context)!.contactEmail,
                          keyboardType: TextInputType.emailAddress,
                          validator: FormBuilderValidators.required(
                              errorText: AppLocalizations.of(context)!.contactEmailValidationEmpty),
                        ),
                        const SizedBox(height: heightSpacing),
                        InsetFormField(
                          name: "description",
                          label: AppLocalizations.of(context)!.contactDescription,
                          keyboardType: TextInputType.multiline,
                          minLines: 3,
                          maxLines: null,
                          validator: FormBuilderValidators.required(
                              errorText: AppLocalizations.of(context)!.contactDescriptionValidationEmpty),
                        ),
                        const SizedBox(height: heightSpacing),
                        Align(
                          alignment: Alignment.centerRight,
                          child: PrimaryButton(
                            fullWidth: false,
                            onPressed: () async {
                              if (_formKey.currentState!.saveAndValidate()) {
                                try {
                                  await sendContactMail(_formKey.currentState!.value);
                                  if (context.mounted) {
                                    showSnackBar(context,
                                        AppLocalizations.of(context)!.contactSendSuccess);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    showSnackBar(context,
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
                            label: AppLocalizations.of(context)!.contactUs,
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
