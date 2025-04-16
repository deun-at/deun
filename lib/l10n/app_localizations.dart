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
  /// **'New group'**
  String get addNewGroup;

  /// No description provided for @addNewExpense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get addNewExpense;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// Filter for the group list.
  ///
  /// In en, this message translates to:
  /// **'{filter, select, all{all} active{open} done{done} other{}}'**
  String groupListFilter(String filter);

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get groupName;

  /// No description provided for @addGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Add title'**
  String get addGroupTitle;

  /// No description provided for @groupNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name!'**
  String get groupNameValidationEmpty;

  /// No description provided for @groupSimplifiedExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate simplified expenses'**
  String get groupSimplifiedExpensesTitle;

  /// No description provided for @expenseDateValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a date!'**
  String get expenseDateValidationEmpty;

  /// No description provided for @groupDeleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this group?'**
  String get groupDeleteItemTitle;

  /// No description provided for @groupNoEntries.
  ///
  /// In en, this message translates to:
  /// **'Add a group to get started.'**
  String get groupNoEntries;

  /// No description provided for @groupEntriesError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with loading Groups.'**
  String get groupEntriesError;

  /// No description provided for @groupMemberSelectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Search friends'**
  String get groupMemberSelectionEmpty;

  /// No description provided for @groupMemberAddFriends.
  ///
  /// In en, this message translates to:
  /// **'Add friends'**
  String get groupMemberAddFriends;

  /// No description provided for @groupMemberSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Added friends'**
  String get groupMemberSelectionTitle;

  /// No description provided for @groupMemberResultEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friends found!'**
  String get groupMemberResultEmpty;

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

  /// No description provided for @expensesSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get expensesSearchTitle;

  /// No description provided for @expensesSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Search for expenses'**
  String get expensesSearchDescription;

  /// No description provided for @expensesSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get expensesSearchEmpty;

  /// No description provided for @createExpense.
  ///
  /// In en, this message translates to:
  /// **'Create expense'**
  String get createExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @addExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add title'**
  String get addExpenseTitle;

  /// No description provided for @expenseName.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get expenseName;

  /// No description provided for @expenseNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title!'**
  String get expenseNameValidationEmpty;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseAmount;

  /// No description provided for @expenseAmountValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount!'**
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
  /// **'Add item title'**
  String get expenseEntryTitle;

  /// No description provided for @addNewExpenseEntry.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addNewExpenseEntry;

  /// No description provided for @expenseEntryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get expenseEntryName;

  /// No description provided for @expenseEntryNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an item title!'**
  String get expenseEntryNameValidationEmpty;

  /// No description provided for @expenseEntryAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseEntryAmount;

  /// No description provided for @expenseEntryAmountValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount!'**
  String get expenseEntryAmountValidationEmpty;

  /// No description provided for @expenseEntrySharesLable.
  ///
  /// In en, this message translates to:
  /// **'Who used it?'**
  String get expenseEntrySharesLable;

  /// No description provided for @expenseEntrySharesValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one person!'**
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
  String expenseDisplayAmount(String displayNameYourself, String displayName, String expenseType, double amount);

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

  /// No description provided for @payBackDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay back!'**
  String get payBackDialogTitle;

  /// Dialog to confirm that you want to pay back money.
  ///
  /// In en, this message translates to:
  /// **'You owe {displayName} {amount}'**
  String payBackDialog(String displayName, double amount);

  /// No description provided for @payBackDialogPaypal.
  ///
  /// In en, this message translates to:
  /// **'Open Paypal link'**
  String get payBackDialogPaypal;

  /// No description provided for @payBackDialogIban.
  ///
  /// In en, this message translates to:
  /// **'Copy IBAN'**
  String get payBackDialogIban;

  /// No description provided for @payBackDialogDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get payBackDialogDone;

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
  String groupDisplayPaidBack(String paidByYourself, String paidBy, String paidForYourself, String paidFor, double amount);

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

  /// No description provided for @signInEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t use social login?\nUse email instead!'**
  String get signInEmailTitle;

  /// No description provided for @updatePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordTitle;

  /// No description provided for @updatePasswordToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Take me back to Sign Up'**
  String get updatePasswordToSignIn;

  /// No description provided for @updatePasswordEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get updatePasswordEnterPassword;

  /// No description provided for @updatePasswordPasswordLengthError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password that is at least 6 characters long'**
  String get updatePasswordPasswordLengthError;

  /// No description provided for @updatePasswordPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password successfully updated'**
  String get updatePasswordPasswordResetSent;

  /// No description provided for @updatePasswordunexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get updatePasswordunexpectedError;

  /// No description provided for @updatePasswordUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordUpdatePassword;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @addFriends.
  ///
  /// In en, this message translates to:
  /// **'Add friends'**
  String get addFriends;

  /// No description provided for @friendsNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsNoEntries;

  /// No description provided for @addFriendshipSelectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Search for Name or E-Mail'**
  String get addFriendshipSelectionEmpty;

  /// No description provided for @addFriendshipSearchResult.
  ///
  /// In en, this message translates to:
  /// **'Search Result'**
  String get addFriendshipSearchResult;

  /// No description provided for @addFriendshipPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Added Me'**
  String get addFriendshipPendingRequests;

  /// No description provided for @addFriendshipAllContacts.
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get addFriendshipAllContacts;

  /// No description provided for @addFriendshipContactPermission.
  ///
  /// In en, this message translates to:
  /// **'Request access to your contacts.'**
  String get addFriendshipContactPermission;

  /// No description provided for @addFriendshipContactPermissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please make shure that you have given the app permission to access your contacts.'**
  String get addFriendshipContactPermissionSubtitle;

  /// No description provided for @addFriendshipRequested.
  ///
  /// In en, this message translates to:
  /// **'Pending Friendship Requests'**
  String get addFriendshipRequested;

  /// No description provided for @addFriendshipRequestedNoResult.
  ///
  /// In en, this message translates to:
  /// **'No pending requests found!'**
  String get addFriendshipRequestedNoResult;

  /// No description provided for @addFriendshipNoResult.
  ///
  /// In en, this message translates to:
  /// **'No User found with this E-Mail!'**
  String get addFriendshipNoResult;

  /// No description provided for @addFriendshipRequestNoResult.
  ///
  /// In en, this message translates to:
  /// **'No friend request found!'**
  String get addFriendshipRequestNoResult;

  /// No description provided for @addFriendshipContactNoResult.
  ///
  /// In en, this message translates to:
  /// **'No Contacts found!'**
  String get addFriendshipContactNoResult;

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

  /// Snackbar message when a friendship request was declined.
  ///
  /// In en, this message translates to:
  /// **'Request from {displayName} was declined'**
  String friendshipRequestDecline(String displayName);

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

  /// Notification title when a new group was added.
  ///
  /// In en, this message translates to:
  /// **'{userDisplayName} added you to a new group!'**
  String groupNotificationTitle(String userDisplayName);

  /// Notification body when a new expense was added.
  ///
  /// In en, this message translates to:
  /// **'You now have access to \"{groupName}\".'**
  String groupNotificationBody(String groupName);

  /// Notification title when somebody paid their debts back.
  ///
  /// In en, this message translates to:
  /// **'{userDisplayName} paid their debts in \"{groupName}\" back!'**
  String groupPayBackNotificationTitle(String userDisplayName, String groupName);

  /// Notification body when a new expense was added.
  ///
  /// In en, this message translates to:
  /// **'You should receive {amount} in the next days.'**
  String groupPayBackNotificationBody(double amount);

  /// Notification title when a new expense was added.
  ///
  /// In en, this message translates to:
  /// **'{userDisplayName} added a new expense!'**
  String expenseNotificationTitle(String userDisplayName);

  /// Notification body when a new expense was added.
  ///
  /// In en, this message translates to:
  /// **'\"{expenseName}\" has been added to \"{groupName}\" with a total of {amount}.'**
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

  /// No description provided for @friendAcceptNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your friend request got accepted'**
  String get friendAcceptNotificationTitle;

  /// Notification title when a friend request was accepted.
  ///
  /// In en, this message translates to:
  /// **'{userDisplayName} accepted your friend request.'**
  String friendAcceptNotificationBody(String userDisplayName);

  /// No description provided for @friendDeclineNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your friend request got declined'**
  String get friendDeclineNotificationTitle;

  /// Notification title when a friend request was declined.
  ///
  /// In en, this message translates to:
  /// **'{userDisplayName} declined your friend request.'**
  String friendDeclineNotificationBody(String userDisplayName);

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
  /// **'Please enter a First name!'**
  String get settingsFirstNameValidationEmpty;

  /// No description provided for @settingsLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get settingsLastName;

  /// No description provided for @settingsLastNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a Last name!'**
  String get settingsLastNameValidationEmpty;

  /// No description provided for @settingsDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayName;

  /// No description provided for @settingsDisplayNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a Display name!'**
  String get settingsDisplayNameValidationEmpty;

  /// No description provided for @settingsPaypalMe.
  ///
  /// In en, this message translates to:
  /// **'Paypal.me link'**
  String get settingsPaypalMe;

  /// No description provided for @settingsIban.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get settingsIban;

  /// No description provided for @settingsLocale.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLocale;

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

  /// No description provided for @settingsPrivacyPreferences.
  ///
  /// In en, this message translates to:
  /// **'Change privacy preferences'**
  String get settingsPrivacyPreferences;

  /// No description provided for @settingsPrivacyPreferencesSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your privacy choices have been updated'**
  String get settingsPrivacyPreferencesSuccess;

  /// No description provided for @settingsPrivacyPreferencesError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while trying to change your privacy choices'**
  String get settingsPrivacyPreferencesError;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get contact;

  /// No description provided for @contactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Whether you\'re seeking support, have feedback, or are interested in collaborating with us, please fill out the form below or write us a mail to app.deun@gmail.com!'**
  String get contactSubtitle;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get contactName;

  /// No description provided for @contactNameValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a full name!'**
  String get contactNameValidationEmpty;

  /// No description provided for @contactCompany.
  ///
  /// In en, this message translates to:
  /// **'Company (optional)'**
  String get contactCompany;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'E-Mail'**
  String get contactEmail;

  /// No description provided for @contactEmailValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email!'**
  String get contactEmailValidationEmpty;

  /// No description provided for @contactDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get contactDescription;

  /// No description provided for @contactDescriptionValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description!'**
  String get contactDescriptionValidationEmpty;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @contactSendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Support request sent!'**
  String get contactSendSuccess;

  /// No description provided for @contactSendError.
  ///
  /// In en, this message translates to:
  /// **'Error while requesting the support!'**
  String get contactSendError;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Error while trying to delete the user account. Please contact app.deun@gmail.com for support.'**
  String get deleteAccountError;

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Error while loading data!'**
  String get errorLoadingData;

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

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

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

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

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

  /// No description provided for @localeSelector.
  ///
  /// In en, this message translates to:
  /// **'{locale, select, de{Deutsch} en{English} other{}}'**
  String localeSelector(String locale);

  /// No description provided for @localeSelectorSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get localeSelectorSystem;
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
