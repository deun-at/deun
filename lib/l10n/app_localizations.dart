import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// Button to add a new group.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get addNewGroup;

  /// No description provided for @addNewExpense.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get addNewExpense;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Group'**
  String get editGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get groupName;

  /// No description provided for @addGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Title'**
  String get addGroupTitle;

  /// No description provided for @groupNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get groupNameValidationEmpty;

  /// No description provided for @expenseDateValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a date'**
  String get expenseDateValidationEmpty;

  /// No description provided for @groupDeleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this group?'**
  String get groupDeleteItemTitle;

  /// No description provided for @groupNoEntries.
  ///
  /// In en, this message translates to:
  /// **'Add a group to get started'**
  String get groupNoEntries;

  /// No description provided for @groupEntriesError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with loading Groups.'**
  String get groupEntriesError;

  /// No description provided for @groupMemberSelectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add People'**
  String get groupMemberSelectionEmpty;

  /// No description provided for @groupMemberSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Added People'**
  String get groupMemberSelectionTitle;

  /// No description provided for @groupExpenseNoEntries.
  ///
  /// In en, this message translates to:
  /// **'Add an expense to get started'**
  String get groupExpenseNoEntries;

  /// No description provided for @groupDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error while deleting group!'**
  String get groupDeleteError;

  /// No description provided for @groupDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group deleted!'**
  String get groupDeleteSuccess;

  /// No description provided for @groupCreateError.
  ///
  /// In en, this message translates to:
  /// **'Error while creating group!'**
  String get groupCreateError;

  /// No description provided for @groupCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group created!'**
  String get groupCreateSuccess;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @createExpense.
  ///
  /// In en, this message translates to:
  /// **'Create Expense'**
  String get createExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit Expense'**
  String get editExpense;

  /// No description provided for @addExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Title'**
  String get addExpenseTitle;

  /// No description provided for @expenseName.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get expenseName;

  /// No description provided for @expenseNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a Title'**
  String get expenseNameValidationEmpty;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseAmount;

  /// No description provided for @expenseAmountValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get expenseAmountValidationEmpty;

  /// No description provided for @expenseDate.
  ///
  /// In en, this message translates to:
  /// **'When did it happen?'**
  String get expenseDate;

  /// No description provided for @expensePaidBy.
  ///
  /// In en, this message translates to:
  /// **'Who paid?'**
  String get expensePaidBy;

  /// No description provided for @expenseEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Item Title'**
  String get expenseEntryTitle;

  /// No description provided for @addNewExpenseEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addNewExpenseEntry;

  /// No description provided for @expenseEntryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get expenseEntryName;

  /// No description provided for @expenseEntryNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an Item Title'**
  String get expenseEntryNameValidationEmpty;

  /// No description provided for @expenseEntryAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseEntryAmount;

  /// No description provided for @expenseEntryAmountValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get expenseEntryAmountValidationEmpty;

  /// No description provided for @expenseEntrySharesLable.
  ///
  /// In en, this message translates to:
  /// **'Who used it?'**
  String get expenseEntrySharesLable;

  /// No description provided for @expenseEntrySharesValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one person'**
  String get expenseEntrySharesValidationEmpty;

  /// No description provided for @expenseDeleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get expenseDeleteItemTitle;

  /// No description provided for @expenseDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error while deleting expense!'**
  String get expenseDeleteError;

  /// No description provided for @expenseDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted!'**
  String get expenseDeleteSuccess;

  /// No description provided for @expenseCreateError.
  ///
  /// In en, this message translates to:
  /// **'Error while creating expense!'**
  String get expenseCreateError;

  /// No description provided for @expenseCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Expense created!'**
  String get expenseCreateSuccess;

  /// No description provided for @expenseNoEntries.
  ///
  /// In en, this message translates to:
  /// **'So empty here :('**
  String get expenseNoEntries;

  /// Lable in the expense list of what you are owed/what you owe per user.
  ///
  /// In en, this message translates to:
  /// **'{displayName} {expenseType, select, paid{paid} lent{lent} borrowed{borrowed} other{}} {amount}'**
  String expenseDisplayAmount(String displayName, String expenseType, double amount);

  /// No description provided for @expenseNoShares.
  ///
  /// In en, this message translates to:
  /// **'You are not involved'**
  String get expenseNoShares;

  /// Lable in the group list/group detail of what you are owed/what you owe per user.
  ///
  /// In en, this message translates to:
  /// **'{paidByYourself, select, yes{{displayName} owes you} other{You owe {displayName}}} {amount}'**
  String groupDisplayAmount(String displayName, String paidByYourself, double amount);

  /// Lable in the group list/group detail of what you are owed/what you owe as a sum.
  ///
  /// In en, this message translates to:
  /// **'{paidByYourself, select, yes{You are owed} other{You owe}} {amount}'**
  String groupDisplaySumAmount(String paidByYourself, double amount);

  /// Lable in the group list/group detail of what you spent
  ///
  /// In en, this message translates to:
  /// **'Total expenses {amount}'**
  String totalExpensesAmount(double amount);

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'all done'**
  String get allDone;

  /// No description provided for @payBack.
  ///
  /// In en, this message translates to:
  /// **'Pay back'**
  String get payBack;

  /// No description provided for @payBackNoEntries.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to pay back!'**
  String get payBackNoEntries;

  /// Dialog to confirm that you want to pay back money.
  ///
  /// In en, this message translates to:
  /// **'Pay back {amount} to {displayName}'**
  String payBackDialog(String displayName, double amount);

  /// No description provided for @payBackError.
  ///
  /// In en, this message translates to:
  /// **'There was an error with paying back the amount. Please try again later!'**
  String get payBackError;

  /// Snackbar message when you paid back money.
  ///
  /// In en, this message translates to:
  /// **'You paid back {amount} to {displayName}'**
  String payBackSuccess(String displayName, double amount);

  /// ListTile in the group detail of who paid back money.
  ///
  /// In en, this message translates to:
  /// **'{paidBy} paid back {amount} to {paidFor}'**
  String groupDisplayPaidBack(String paidBy, String paidFor, double amount);

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'deun.app'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simply Split Fairly.'**
  String get signInSubtitle;

  /// No description provided for @signInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to make the best\nout of your group trips.'**
  String get signInDescription;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @friendsNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsNoEntries;

  /// No description provided for @addFriendshipSelectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Search E-Mail'**
  String get addFriendshipSelectionEmpty;

  /// No description provided for @addFriendshipNoResult.
  ///
  /// In en, this message translates to:
  /// **'No User found with this E-Mail!'**
  String get addFriendshipNoResult;

  /// No description provided for @requestFriendship.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get requestFriendship;

  /// No description provided for @friendsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get friendsPending;

  /// Snackbar message when a friendship request was sent.
  ///
  /// In en, this message translates to:
  /// **'Request sent to {displayName}'**
  String friendshipRequestSent(String displayName);

  /// Dialog to confirm that you want to remove a friend.
  ///
  /// In en, this message translates to:
  /// **'Remove {displayName} as a friend'**
  String removeFriend(String displayName);

  /// Snackbar message when a friend was removed.
  ///
  /// In en, this message translates to:
  /// **'{displayName} was removed as a friend'**
  String friendRemoved(String displayName);

  /// Snackbar message when a friend was accepted.
  ///
  /// In en, this message translates to:
  /// **'{displayName} was accepted as a friend'**
  String friendshipAccept(String displayName);

  /// Snackbar message when a friendship request was canceled.
  ///
  /// In en, this message translates to:
  /// **'Request to {displayName} was canceled'**
  String friendshipRequestCancel(String displayName);

  /// Title for Friendship Edit Dialog
  ///
  /// In en, this message translates to:
  /// **'{displayName}'**
  String friendshipDialogTitle(String displayName);

  /// No description provided for @friendshipDialogEmail.
  ///
  /// In en, this message translates to:
  /// **'E-Mail:'**
  String get friendshipDialogEmail;

  /// No description provided for @friendshipDialogFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name:'**
  String get friendshipDialogFullName;

  /// No description provided for @friendshipDialogRemoveAsFriend.
  ///
  /// In en, this message translates to:
  /// **'Remove as friend'**
  String get friendshipDialogRemoveAsFriend;

  ///
  ///
  /// In en, this message translates to:
  /// **'{amount}'**
  String toCurrency(double amount);

  ///
  ///
  /// In en, this message translates to:
  /// **'{amount}'**
  String toCurrencyNoPrefix(double amount);

  /// Notification title when a new expense was added.
  ///
  /// In en, this message translates to:
  /// **'{userDisplayName} added an expense'**
  String expenseNotificationTitle(String userDisplayName);

  /// Notification body when a new expense was added.
  ///
  /// In en, this message translates to:
  /// **'\"{expenseName}\" has been added to \"{groupName}\" with a total of {amount}'**
  String expenseNotificationBody(String expenseName, String groupName, double amount);

  /// No description provided for @friendRequestNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'You have a new friend request'**
  String get friendRequestNotificationTitle;

  /// Notification title when a new friend request was sent.
  ///
  /// In en, this message translates to:
  /// **'{userDisplayName} wants to connect with you.'**
  String friendRequestNotificationBody(String userDisplayName);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsUserHeading.
  ///
  /// In en, this message translates to:
  /// **'User Data'**
  String get settingsUserHeading;

  /// No description provided for @settingsFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get settingsFirstName;

  /// No description provided for @settingsFirstNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a First name'**
  String get settingsFirstNameValidationEmpty;

  /// No description provided for @settingsLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get settingsLastName;

  /// No description provided for @settingsLastNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a Last name'**
  String get settingsLastNameValidationEmpty;

  /// No description provided for @settingsDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayName;

  /// No description provided for @settingsDisplayNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a Display name'**
  String get settingsDisplayNameValidationEmpty;

  /// No description provided for @settingsPaypalMe.
  ///
  /// In en, this message translates to:
  /// **'Paypal.me link'**
  String get settingsPaypalMe;

  /// No description provided for @settingsUserUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'User data updated!'**
  String get settingsUserUpdateSuccess;

  /// No description provided for @settingsUserUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Error while updating user data!'**
  String get settingsUserUpdateError;

  /// No description provided for @settingsSignOutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settingsSignOutDialogTitle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @generalError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get generalError;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
