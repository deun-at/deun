import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../app_state.dart';
import '../../constants.dart';
import '../../main.dart';
import '../users/user_model.dart';
import 'group_model.dart';

class GroupBottomSheet extends StatefulWidget {
  const GroupBottomSheet({super.key, required this.appState, this.groupId});

  final AppState appState;
  final int? groupId;

  @override
  State<GroupBottomSheet> createState() => _GroupBottomSheetState();
}

class _GroupBottomSheetState extends State<GroupBottomSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  late Group? group;
  int groupColor = ColorSeed.baseColor.color.value;

  @override
  void initState() {
    super.initState();

    group = widget.appState.groupItems.value[widget.groupId];
  }

  List<Map<String, dynamic>> decodeGroupMembersString(String? jsonValue) {
    return List<Map<String, dynamic>>.from(jsonDecode(jsonValue ?? "[]"));
  }

  getUserSelection(SearchController controller, FormFieldState<dynamic> field) {
    debugPrint(field.value.toString());
    List<Map<String, dynamic>> groupMembers =
        decodeGroupMembersString(field.value);
    return groupMembers.mapIndexed((index, user) => ListTile(
          title: Text("${user["firstname"]} ${user["lastname"]}"),
          subtitle: Text(user["email"]),
          onTap: () {
            groupMembers.removeAt(index);
            field.didChange(jsonEncode(groupMembers));

            controller.text = '';
          },
        ));
  }

  Future<Iterable<Widget>> getUserSuggestions(
      SearchController controller, FormFieldState<dynamic> field) async {
    final String input = controller.value.text;

    List<User> result = await User.fetchData(input, 10);

    return result.map((user) => ListTile(
          // leading: CircleAvatar(backgroundColor: user.color),
          title: Text("${user.firstname} ${user.lastname}"),
          subtitle: Text(user.email),
          onTap: () {
            List<dynamic> nbs = decodeGroupMembersString(field.value);
            nbs.add(user.toJson());
            field.didChange(jsonEncode(nbs));
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10;

    return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: FormBuilder(
                  key: _formKey,
                  clearValueOnUnregister: true,
                  initialValue: group?.toJson() ?? {},
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                          widget.groupId == null
                              ? AppLocalizations.of(context)!.createGroup
                              : AppLocalizations.of(context)!.editGroup,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: spacing),
                      FormBuilderTextField(
                        name: "name",
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: FormBuilderValidators.required(
                            errorText: AppLocalizations.of(context)!
                                .groupNameValidationEmpty),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.groupName,
                        ),
                      ),
                      const SizedBox(height: spacing),
                      FormBuilderField(
                        name: "color_value",
                        builder: (FormFieldState<dynamic> field) {
                          return GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 5,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 4),
                              padding: const EdgeInsets.all(8),
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: ColorSeed.values.length,
                              itemBuilder: (context, i) {
                                return IconButton(
                                    icon: const Icon(
                                        Icons.radio_button_unchecked),
                                    selectedIcon:
                                        const Icon(Icons.radio_button_checked),
                                    color: ColorSeed.values[i].color,
                                    isSelected: field.value ==
                                        ColorSeed.values[i].color.value,
                                    onPressed: () {
                                      field.didChange(
                                          ColorSeed.values[i].color.value);
                                    });
                              });
                        },
                      ),
                      const Divider(),
                      FormBuilderField(
                        name: "group_members",
                        builder: (FormFieldState<dynamic> field) {
                          return SearchAnchor(
                            viewHintText: AppLocalizations.of(context)!
                                .groupMemberSelectionEmpty,
                            builder: (context, controller) {
                              if (field.value == null) {
                                return ListTile(
                                  leading: const Icon(Icons.people),
                                  title: Text(AppLocalizations.of(context)!
                                      .groupMemberSelectionEmpty),
                                );
                              }

                              List<Map<String, dynamic>> groupMembers =
                                  decodeGroupMembersString(field.value);

                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 5, 5, 10),
                                child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 5,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 4),
                                    padding: const EdgeInsets.all(8),
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: groupMembers.length,
                                    itemBuilder: (context, i) {
                                      return Text(groupMembers[i]["email"]);
                                    }),
                              );
                            },
                            suggestionsBuilder: (context, controller) {
                              if (controller.text.isEmpty) {
                                return getUserSelection(controller, field);
                              }
                              return getUserSuggestions(controller, field);
                            },
                          );
                        },
                      ),
                      const Divider(),
                      FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.saveAndValidate()) {
                              Map<String, dynamic> upsertVals =
                                  Map<String, dynamic>.from(
                                      _formKey.currentState!.value)
                                    ..addAll({
                                      'user_id': supabase.auth.currentUser?.id
                                    });

                              if (widget.groupId != null) {
                                upsertVals.addAll({'id': widget.groupId});
                              }
                              supabase
                                  .from('group')
                                  .upsert(upsertVals)
                                  .then((value) async {
                                await widget.appState.fetchGroupData();
                                await widget.appState.fetchExpenseData();
                                Navigator.pop(context);
                              });
                            }
                          },
                          child: Text(widget.groupId != null
                              ? AppLocalizations.of(context)!.update
                              : AppLocalizations.of(context)!.create))
                    ],
                  )))),
    );
  }
}

const allCountries = [
  'Afghanistan',
  'Albania',
  'Algeria',
  'American Samoa',
  'Andorra',
  'Angola',
  'Anguilla',
  'Antarctica',
  'Antigua and Barbuda',
  'Argentina',
  'Armenia',
  'Aruba',
  'Australia',
  'Austria',
  'Azerbaijan',
  'Bahamas',
  'Bahrain',
  'Bangladesh',
  'Barbados',
  'Belarus',
  'Belgium',
  'Belize',
  'Benin',
  'Bermuda',
  'Bhutan',
  'Bolivia',
  'Bosnia and Herzegowina',
  'Botswana',
  'Bouvet Island',
  'Brazil',
  'British Indian Ocean Territory',
  'Brunei Darussalam',
  'Bulgaria',
  'Burkina Faso',
  'Burundi',
  'Cambodia',
  'Cameroon',
  'Canada',
  'Cape Verde',
  'Cayman Islands',
  'Central African Republic',
  'Chad',
  'Chile',
  'China',
  'Christmas Island',
  'Cocos (Keeling) Islands',
  'Colombia',
  'Comoros',
  'Congo',
  'Congo, the Democratic Republic of the',
  'Cook Islands',
  'Costa Rica',
  'Cote d\'Ivoire',
  'Croatia (Hrvatska)',
  'Cuba',
  'Cyprus',
  'Czech Republic',
  'Denmark',
  'Djibouti',
  'Dominica',
  'Dominican Republic',
  'East Timor',
  'Ecuador',
  'Egypt',
  'El Salvador',
  'Equatorial Guinea',
  'Eritrea',
  'Estonia',
  'Ethiopia',
  'Falkland Islands (Malvinas)',
  'Faroe Islands',
  'Fiji',
  'Finland',
  'France',
  'France Metropolitan',
  'French Guiana',
  'French Polynesia',
  'French Southern Territories',
  'Gabon',
  'Gambia',
  'Georgia',
  'Germany',
  'Ghana',
  'Gibraltar',
  'Greece',
  'Greenland',
  'Grenada',
  'Guadeloupe',
  'Guam',
  'Guatemala',
  'Guinea',
  'Guinea-Bissau',
  'Guyana',
  'Haiti',
  'Heard and Mc Donald Islands',
  'Holy See (Vatican City State)',
  'Honduras',
  'Hong Kong',
  'Hungary',
  'Iceland',
  'India',
  'Indonesia',
  'Iran (Islamic Republic of)',
  'Iraq',
  'Ireland',
  'Israel',
  'Italy',
  'Jamaica',
  'Japan',
  'Jordan',
  'Kazakhstan',
  'Kenya',
  'Kiribati',
  'Korea, Democratic People\'s Republic of',
  'Korea, Republic of',
  'Kuwait',
  'Kyrgyzstan',
  'Lao, People\'s Democratic Republic',
  'Latvia',
  'Lebanon',
  'Lesotho',
  'Liberia',
  'Libyan Arab Jamahiriya',
  'Liechtenstein',
  'Lithuania',
  'Luxembourg',
  'Macau',
  'Macedonia, The Former Yugoslav Republic of',
  'Madagascar',
  'Malawi',
  'Malaysia',
  'Maldives',
  'Mali',
  'Malta',
  'Marshall Islands',
  'Martinique',
  'Mauritania',
  'Mauritius',
  'Mayotte',
  'Mexico',
  'Micronesia, Federated States of',
  'Moldova, Republic of',
  'Monaco',
  'Mongolia',
  'Montserrat',
  'Morocco',
  'Mozambique',
  'Myanmar',
  'Namibia',
  'Nauru',
  'Nepal',
  'Netherlands',
  'Netherlands Antilles',
  'New Caledonia',
  'New Zealand',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'Niue',
  'Norfolk Island',
  'Northern Mariana Islands',
  'Norway',
  'Oman',
  'Pakistan',
  'Palau',
  'Panama',
  'Papua New Guinea',
  'Paraguay',
  'Peru',
  'Philippines',
  'Pitcairn',
  'Poland',
  'Portugal',
  'Puerto Rico',
  'Qatar',
  'Reunion',
  'Romania',
  'Russian Federation',
  'Rwanda',
  'Saint Kitts and Nevis',
  'Saint Lucia',
  'Saint Vincent and the Grenadines',
  'Samoa',
  'San Marino',
  'Sao Tome and Principe',
  'Saudi Arabia',
  'Senegal',
  'Seychelles',
  'Sierra Leone',
  'Singapore',
  'Slovakia (Slovak Republic)',
  'Slovenia',
  'Solomon Islands',
  'Somalia',
  'South Africa',
  'South Georgia and the South Sandwich Islands',
  'Spain',
  'Sri Lanka',
  'St. Helena',
  'St. Pierre and Miquelon',
  'Sudan',
  'Suriname',
  'Svalbard and Jan Mayen Islands',
  'Swaziland',
  'Sweden',
  'Switzerland',
  'Syrian Arab Republic',
  'Taiwan, Province of China',
  'Tajikistan',
  'Tanzania, United Republic of',
  'Thailand',
  'Togo',
  'Tokelau',
  'Tonga',
  'Trinidad and Tobago',
  'Tunisia',
  'Turkey',
  'Turkmenistan',
  'Turks and Caicos Islands',
  'Tuvalu',
  'Uganda',
  'Ukraine',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'United States Minor Outlying Islands',
  'Uruguay',
  'Uzbekistan',
  'Vanuatu',
  'Venezuela',
  'Vietnam',
  'Virgin Islands (British)',
  'Virgin Islands (U.S.)',
  'Wallis and Futuna Islands',
  'Western Sahara',
  'Yemen',
  'Yugoslavia',
  'Zambia',
  'Zimbabwe'
];
