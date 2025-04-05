// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get addNewGroup => 'New group';

  @override
  String get addNewExpense => 'New expense';

  @override
  String get groups => 'Groups';

  @override
  String groupListFilter(String filter) {
    String _temp0 = intl.Intl.selectLogic(
      filter,
      {
        'all': 'all',
        'active': 'open',
        'done': 'done',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get createGroup => 'Create group';

  @override
  String get editGroup => 'Edit group';

  @override
  String get groupName => 'Name';

  @override
  String get addGroupTitle => 'Add title';

  @override
  String get groupNameValidationEmpty => 'Please enter a name!';

  @override
  String get groupSimplifiedExpensesTitle => 'Activate simplified expenses';

  @override
  String get expenseDateValidationEmpty => 'Please enter a date!';

  @override
  String get groupDeleteItemTitle => 'Delete this group?';

  @override
  String get groupNoEntries => 'Add a group to get started.';

  @override
  String get groupEntriesError => 'Something went wrong with loading Groups.';

  @override
  String get groupMemberSelectionEmpty => 'Search friends';

  @override
  String get groupMemberAddFriends => 'Add friends';

  @override
  String get groupMemberSelectionTitle => 'Added friends';

  @override
  String get groupMemberResultEmpty => 'No friends found!';

  @override
  String get groupExpenseNoEntries => 'Add an expense to get started';

  @override
  String get groupDeleteError => 'Error while deleting group!';

  @override
  String get groupDeleteSuccess => 'Group deleted!';

  @override
  String get groupCreateError => 'Error while creating group!';

  @override
  String get groupCreateSuccess => 'Group created!';

  @override
  String get expenses => 'Expenses';

  @override
  String get expensesSearchTitle => 'Search';

  @override
  String get expensesSearchDescription => 'Search for expenses';

  @override
  String get expensesSearchEmpty => 'No results found';

  @override
  String get createExpense => 'Create expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get addExpenseTitle => 'Add title';

  @override
  String get expenseName => 'Description';

  @override
  String get expenseNameValidationEmpty => 'Please enter a title!';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get expenseAmountValidationEmpty => 'Please enter an amount!';

  @override
  String get expenseDate => 'When did it happen?';

  @override
  String get expensePaidBy => 'Who paid?';

  @override
  String get expenseEntryTitle => 'Add item title';

  @override
  String get addNewExpenseEntry => 'Add item';

  @override
  String get expenseEntryName => 'Name';

  @override
  String get expenseEntryNameValidationEmpty => 'Please enter an item title!';

  @override
  String get expenseEntryAmount => 'Amount';

  @override
  String get expenseEntryAmountValidationEmpty => 'Please enter an amount!';

  @override
  String get expenseEntrySharesLable => 'Who used it?';

  @override
  String get expenseEntrySharesValidationEmpty => 'Please select at least one person!';

  @override
  String get expenseDeleteItemTitle => 'Delete this expense?';

  @override
  String get expenseDeleteError => 'Error while deleting expense!';

  @override
  String get expenseDeleteSuccess => 'Expense deleted!';

  @override
  String get expenseCreateError => 'Error while creating expense!';

  @override
  String get expenseCreateSuccess => 'Expense created!';

  @override
  String get expenseNoEntries => 'So empty here :(';

  @override
  String expenseDisplayAmount(String displayNameYourself, String displayName, String expenseType, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(
      expenseType,
      {
        'paid': 'paid',
        'lent': 'lent',
        'borrowed': 'borrowed',
        'other': '',
      },
    );
    return '$displayName $_temp0 $amountString';
  }

  @override
  String get expenseNoShares => 'You are not involved';

  @override
  String groupDisplayAmount(String displayName, String paidByYourself, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(
      paidByYourself,
      {
        'yes': '$displayName owes you',
        'other': 'You owe $displayName',
      },
    );
    return '$_temp0 $amountString';
  }

  @override
  String groupDisplaySumAmount(String paidByYourself, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(
      paidByYourself,
      {
        'yes': 'You are owed',
        'other': 'You owe',
      },
    );
    return '$_temp0 $amountString';
  }

  @override
  String totalExpensesAmount(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'Total expenses $amountString';
  }

  @override
  String get allDone => 'all done';

  @override
  String get payBack => 'Pay back';

  @override
  String get payBackNoEntries => 'There is nothing to pay back!';

  @override
  String get payBackDialogTitle => 'Pay back!';

  @override
  String payBackDialog(String displayName, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'You owe $displayName $amountString';
  }

  @override
  String get payBackDialogPaypal => 'Open Paypal link';

  @override
  String get payBackDialogIban => 'Copy IBAN';

  @override
  String get payBackDialogDone => 'Mark as paid';

  @override
  String get payBackError => 'There was an error with paying back the amount. Please try again later!';

  @override
  String payBackSuccess(String displayName, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'You paid back $amountString to $displayName';
  }

  @override
  String groupDisplayPaidBack(String paidByYourself, String paidBy, String paidForYourself, String paidFor, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return '$paidBy paid back $amountString to $paidFor';
  }

  @override
  String get signInTitle => 'deun.app';

  @override
  String get signInSubtitle => 'Simply Split Fairly.';

  @override
  String get signInDescription => 'Sign in to make the best\nout of your group trips.';

  @override
  String get signInEmailTitle => 'Can\'t use social login?\nUse email instead!';

  @override
  String get updatePasswordTitle => 'Update Password';

  @override
  String get updatePasswordToSignIn => 'Take me back to Sign Up';

  @override
  String get updatePasswordEnterPassword => 'Enter your password';

  @override
  String get updatePasswordPasswordLengthError => 'Please enter a password that is at least 6 characters long';

  @override
  String get updatePasswordPasswordResetSent => 'Password successfully updated';

  @override
  String get updatePasswordunexpectedError => 'An unexpected error occurred';

  @override
  String get updatePasswordUpdatePassword => 'Update Password';

  @override
  String get friends => 'Friends';

  @override
  String get friendsNoEntries => 'No friends yet';

  @override
  String get addFriendshipSelectionEmpty => 'Search E-Mail';

  @override
  String get addFriendshipNoResult => 'No User found with this E-Mail!';

  @override
  String get requestFriendship => 'Add friend';

  @override
  String get friendsPending => 'Pending';

  @override
  String friendshipRequestSent(String displayName) {
    return 'Request sent to $displayName';
  }

  @override
  String removeFriend(String displayName) {
    return 'Remove $displayName as a friend';
  }

  @override
  String friendRemoved(String displayName) {
    return '$displayName was removed as a friend';
  }

  @override
  String friendshipAccept(String displayName) {
    return '$displayName was accepted as a friend';
  }

  @override
  String friendshipRequestCancel(String displayName) {
    return 'Request to $displayName was canceled';
  }

  @override
  String friendshipDialogTitle(String displayName) {
    return '$displayName';
  }

  @override
  String get friendshipDialogEmail => 'E-Mail:';

  @override
  String get friendshipDialogFullName => 'Full Name:';

  @override
  String get friendshipDialogRemoveAsFriend => 'Remove as friend';

  @override
  String toCurrency(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString';
  }

  @override
  String toCurrencyNoPrefix(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2
    );
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString';
  }

  @override
  String groupNotificationTitle(String userDisplayName) {
    return '$userDisplayName added you to a new group!';
  }

  @override
  String groupNotificationBody(String groupName) {
    return 'You now have access to \"$groupName\".';
  }

  @override
  String groupPayBackNotificationTitle(String userDisplayName, String groupName) {
    return '$userDisplayName paid their debts in \"$groupName\" back!';
  }

  @override
  String groupPayBackNotificationBody(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'You should receive $amountString in the next days.';
  }

  @override
  String expenseNotificationTitle(String userDisplayName) {
    return '$userDisplayName added a new expense!';
  }

  @override
  String expenseNotificationBody(String expenseName, String groupName, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return '\"$expenseName\" has been added to \"$groupName\" with a total of $amountString.';
  }

  @override
  String get friendRequestNotificationTitle => 'You have a new friend request';

  @override
  String friendRequestNotificationBody(String userDisplayName) {
    return '$userDisplayName wants to connect with you.';
  }

  @override
  String get friendAcceptNotificationTitle => 'Your friend request got accepted';

  @override
  String friendAcceptNotificationBody(String userDisplayName) {
    return '$userDisplayName accepted your friend request.';
  }

  @override
  String get settings => 'Settings';

  @override
  String get settingsUserHeading => 'User Data';

  @override
  String get settingsFirstName => 'First name';

  @override
  String get settingsFirstNameValidationEmpty => 'Please enter a First name!';

  @override
  String get settingsLastName => 'Last name';

  @override
  String get settingsLastNameValidationEmpty => 'Please enter a Last name!';

  @override
  String get settingsDisplayName => 'Display name';

  @override
  String get settingsDisplayNameValidationEmpty => 'Please enter a Display name!';

  @override
  String get settingsPaypalMe => 'Paypal.me link';

  @override
  String get settingsIban => 'IBAN';

  @override
  String get settingsLocale => 'Language';

  @override
  String get settingsUserUpdateSuccess => 'User data updated!';

  @override
  String get settingsUserUpdateError => 'Error while updating user data!';

  @override
  String get settingsSignOutDialogTitle => 'Are you sure you want to sign out?';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsPrivacyPreferences => 'Change privacy preferences';

  @override
  String get settingsPrivacyPreferencesSuccess => 'Your privacy choices have been updated';

  @override
  String get settingsPrivacyPreferencesError => 'An error occurred while trying to change your privacy choices';

  @override
  String get contact => 'Contact';

  @override
  String get contactName => 'Full Name';

  @override
  String get contactNameValidationEmpty => 'Please enter a full name!';

  @override
  String get contactCompany => 'Company (optional)';

  @override
  String get contactEmail => 'E-Mail';

  @override
  String get contactEmailValidationEmpty => 'Please enter an email!';

  @override
  String get contactDescription => 'Description';

  @override
  String get contactDescriptionValidationEmpty => 'Please enter a description!';

  @override
  String get contactSendSuccess => 'Support request sent!';

  @override
  String get contactSendError => 'Error while requesting the support!';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountError => 'Error while trying to delete the user account. Please contact app.deun@gmail.com for support.';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get update => 'Update';

  @override
  String get save => 'Save';

  @override
  String get accept => 'Accept';

  @override
  String get remove => 'Remove';

  @override
  String get open => 'Open';

  @override
  String get close => 'Close';

  @override
  String get send => 'Send';

  @override
  String get generalError => 'Something went wrong';

  @override
  String get loading => 'Loading';

  @override
  String get you => 'You';

  @override
  String get all => 'All';

  @override
  String localeSelector(String locale) {
    String _temp0 = intl.Intl.selectLogic(
      locale,
      {
        'de': 'Deutsch',
        'en': 'English',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get localeSelectorSystem => 'System default';
}
