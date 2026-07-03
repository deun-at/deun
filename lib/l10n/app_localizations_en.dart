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
  String get addNewExpense => 'Add expense';

  @override
  String get groups => 'Groups';

  @override
  String get groupSectionFavorites => 'Favorites';

  @override
  String get groupSectionSettled => 'Settled';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeGreetingNight => 'Good night';

  @override
  String get homeOverallOwed => 'Overall, you\'re owed';

  @override
  String get homeOverallOwe => 'Overall, you owe';

  @override
  String get homeOverallSettled => 'You\'re all settled up';

  @override
  String get homeStatOwed => 'You\'re owed';

  @override
  String get homeStatOwe => 'You owe';

  @override
  String get homeYourGroups => 'Your groups';

  @override
  String get commonNew => 'New';

  @override
  String get balanceOwed => 'You\'re owed';

  @override
  String get balanceOwe => 'You owe';

  @override
  String get balanceSettled => 'Settled up';

  @override
  String get paymentBalanceOwed => 'You\'re owed overall';

  @override
  String get createGroup => 'Create group';

  @override
  String get editGroup => 'Edit group';

  @override
  String get groupName => 'Name';

  @override
  String get addGroupTitle => 'Add title';

  @override
  String get groupNameHint => 'Group name';

  @override
  String get groupNameValidationEmpty => 'Please enter a name!';

  @override
  String get groupSimplifiedExpensesTitle => 'Activate simplified expenses';

  @override
  String get groupCreateTitle => 'New group';

  @override
  String get groupEditTitle => 'Edit group';

  @override
  String get groupColorLabel => 'Color';

  @override
  String get groupMemberSectionTitle => 'Members';

  @override
  String get groupTrackingModeTitle => 'Expense tracking';

  @override
  String get groupTrackingModeSimplifiedTitle => 'Simplified';

  @override
  String get groupTrackingModeSimplifiedSubtitle =>
      'Fewer payments to settle the group balance.';

  @override
  String get groupTrackingModeDetailedTitle => 'Detailed';

  @override
  String get groupTrackingModeDetailedSubtitle =>
      'Track exactly who owes whom for each expense.';

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
  String groupMemberAddGuestOption(String name) {
    return 'Add $name as guest';
  }

  @override
  String get groupMemberIsGuest => 'Guest';

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
  String get groupInviteTitle => 'Invite Friends';

  @override
  String groupInviteTitleNamed(String group) {
    return 'Invite to $group';
  }

  @override
  String get groupInviteLetFriendScan => 'Scan this QR code to join the group.';

  @override
  String get groupInviteLinkLabel => 'Group link';

  @override
  String get groupInviteLinkCopied => 'Link copied';

  @override
  String get groupInviteSubtitle => 'Anyone with this link can join the group.';

  @override
  String get groupInviteShowQr => 'Show QR code';

  @override
  String get groupInviteHideQr => 'Hide QR code';

  @override
  String get inviteQrButton => 'QR';

  @override
  String get inviteShareLink => 'Share link';

  @override
  String get groupInviteJoinTitle => 'Join Group';

  @override
  String get groupInviteJoinSubtitle =>
      'Join this group to view and add expenses.';

  @override
  String get groupInviteJoinButton => 'Enter Group';

  @override
  String get groupInviteGuestSelectTitle => 'Who are you in this group?';

  @override
  String get groupInviteGuestSelectSubtitle =>
      'If you were added as a guest before (no account), pick your name to take over all expenses. If you don\'t find yourself, just join as a new member.';

  @override
  String get groupInviteJoinAsNew => 'Join as new member';

  @override
  String get groupInviteNoGuestsFound =>
      'No guest profiles found in this group.';

  @override
  String get groupInviteTransferButton => 'Continue';

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
  String get expenseDate => 'Date';

  @override
  String get expenseWhen => 'When';

  @override
  String get expensePaidBy => 'Paid by';

  @override
  String expenseSplitEach(String amount) {
    return 'Split $amount each';
  }

  @override
  String get expenseEntryTitle => 'Add item title';

  @override
  String get expenseDescriptionHint => 'Add a description';

  @override
  String get addNewExpenseEntry => 'Add item';

  @override
  String get editorModeQuick => 'Quick split';

  @override
  String get editorModeItemized => 'Itemized';

  @override
  String get itemizedItemsLabel => 'Items';

  @override
  String get itemNameHint => 'Item name';

  @override
  String get itemPriceEachSuffix => 'each';

  @override
  String itemQtyStepperValue(int qty) {
    return '$qty qty';
  }

  @override
  String itemizedTotalFromItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Total · from $count items',
      one: 'Total · from 1 item',
      zero: 'No items yet',
    );
    return '$_temp0';
  }

  @override
  String get addItemByHand => 'Add item by hand';

  @override
  String get itemizedInfoCallout =>
      'After you share, members claim their own items — solo or split, per unit.';

  @override
  String get expenseSaveAndShareForClaiming => 'Add & share for claiming';

  @override
  String get expenseDetailTitle => 'Expense';

  @override
  String get expenseDetailTitleNew => 'New expense';

  @override
  String get expenseDetailTitleEdit => 'Edit expense';

  @override
  String get expenseYourNetLabel => 'Your net';

  @override
  String get expensePaidByYou => 'You paid';

  @override
  String expensePaidByOther(String name) {
    return '$name paid';
  }

  @override
  String expenseYouLentAmount(String amount) {
    return 'You lent $amount';
  }

  @override
  String expenseYouOweAmount(String amount) {
    return 'You owe $amount';
  }

  @override
  String get expenseYouLent => 'You lent';

  @override
  String get expenseYouOwe => 'You owe';

  @override
  String get expenseNetSettled => 'Settled';

  @override
  String get expenseBreakdownLabel => 'Who owes what';

  @override
  String get expenseTagsLabel => 'Tags';

  @override
  String get expenseReviewClaimTitle => 'Itemized expense';

  @override
  String get expenseReviewClaimSubtitle =>
      'Review the items and claim what you had.';

  @override
  String get expenseReviewClaimAction => 'Review & claim';

  @override
  String get claimTitle => 'Tap to claim';

  @override
  String get claimPresenceLive => 'Live';

  @override
  String get claimEditItems => 'Edit items';

  @override
  String get claimPreviewAs => 'Preview as';

  @override
  String get claimYourShare => 'Your share';

  @override
  String claimProgressLabel(String claimed, String total) {
    return '$claimed of $total claimed';
  }

  @override
  String get claimUnclaimedLabel => 'Unclaimed';

  @override
  String get claimAllClaimed => 'All claimed';

  @override
  String get claimPerMemberLabel => 'Per person';

  @override
  String get claimItemsCaption => 'Tap to take what you had';

  @override
  String get claimItemUnclaimed => 'Unclaimed';

  @override
  String get claimNoItems => 'This expense has no claimable items.';

  @override
  String get claimLoadError => 'Couldn\'t load this expense.';

  @override
  String get claimTakeOne => 'Take one';

  @override
  String claimEachOrdered(String price, int count) {
    return '$price each · $count ordered';
  }

  @override
  String get claimTapSlotHint => 'Tap a slot to take one';

  @override
  String claimSplitLabel(String amount) {
    return 'split · $amount';
  }

  @override
  String get claimSplitOne => 'Split one';

  @override
  String get claimSplitSheetTitle => 'Split this item';

  @override
  String claimSplitPerPerson(String amount) {
    return '$amount each';
  }

  @override
  String get claimSplitApply => 'Apply split';

  @override
  String claimUnclaimedCallout(String amount) {
    return '$amount still unclaimed';
  }

  @override
  String get claimNudge => 'Nudge';

  @override
  String get claimNudgeSent => 'Nudge sent to remind everyone to claim.';

  @override
  String claimConfirm(String amount) {
    return 'Confirm — I had $amount';
  }

  @override
  String get claimConfirmedTitle => 'You\'re all set';

  @override
  String claimConfirmedBody(String amount) {
    return 'Your share of $amount is saved. We\'ll keep the totals up to date as others claim.';
  }

  @override
  String get claimConfirmedDone => 'Done';

  @override
  String get expenseMemberLent => 'lent';

  @override
  String get expenseMemberOwes => 'owes';

  @override
  String get expenseEntryName => 'Name';

  @override
  String get expenseEntryNameValidationEmpty => 'Please enter an item title!';

  @override
  String get expenseEntryAmount => 'Amount';

  @override
  String get expenseEntryAmountValidationEmpty => 'Please enter an amount!';

  @override
  String get expenseEntryAmountValidationZero =>
      'Amount must be greater than zero!';

  @override
  String get expenseEntrySharesLable => 'Split between';

  @override
  String get expenseEntrySharesValidationEmpty =>
      'Please select at least one person!';

  @override
  String get expenseDeleteItemTitle => 'Delete this expense?';

  @override
  String get expenseDeleteItemMessage =>
      'This permanently removes the expense and updates everyone\'s balances. This can\'t be undone.';

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
  String expenseDisplayAmount(
    String displayNameYourself,
    String displayName,
    String expenseType,
    double amount,
  ) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(expenseType, {
      'paid': 'paid',
      'lent': 'lent',
      'borrowed': 'borrowed',
      'other': '',
    });
    return '$displayName $_temp0 $amountString';
  }

  @override
  String get expenseNoShares => 'You are not involved';

  @override
  String groupDisplayAmount(
    String displayName,
    String paidByYourself,
    double amount,
  ) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(paidByYourself, {
      'yes': '$displayName owes you',
      'other': 'You owe $displayName',
    });
    return '$_temp0 $amountString';
  }

  @override
  String groupDisplaySumAmount(String paidByYourself, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(paidByYourself, {
      'yes': 'You are owed',
      'other': 'You owe',
    });
    return '$_temp0 $amountString';
  }

  @override
  String totalExpensesAmount(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
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
      name: '€',
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
  String get friendPayBackMarkPaidSubtitle => 'Settle the balance manually';

  @override
  String get payBackError =>
      'There was an error with paying back the amount. Please try again later!';

  @override
  String payBackSuccess(String displayName, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'You paid back $amountString to $displayName';
  }

  @override
  String groupDisplayPaidBack(
    String paidByYourself,
    String paidBy,
    String paidForYourself,
    String paidFor,
    double amount,
  ) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    return '$paidBy paid back $amountString to $paidFor';
  }

  @override
  String get signInTitle => 'deun.app';

  @override
  String get signInSubtitle => 'Simply Split Fairly.';

  @override
  String get signInDescription =>
      'Sign in to make the best\nout of your group trips.';

  @override
  String get signInEmailTitle => 'Can\'t use social login?\nUse email instead!';

  @override
  String get authLoginTitle => 'Welcome back';

  @override
  String get authSignupTitle => 'Create your account';

  @override
  String get authSubtitle => 'Simply split fairly with your group.';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authContinueWithGithub => 'Continue with GitHub';

  @override
  String get authDividerOr => 'or';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authNameLabel => 'Name';

  @override
  String get authEmailInvalid => 'Please enter a valid email address.';

  @override
  String get authPasswordTooShort =>
      'Please enter a password that is at least 6 characters long.';

  @override
  String get authNameRequired => 'Please enter your name.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authLoginCta => 'Log in';

  @override
  String get authSignupCta => 'Create account';

  @override
  String get authSwitchToSignupPrompt => 'Don\'t have an account?';

  @override
  String get authSwitchToSignupAction => 'Sign up';

  @override
  String get authSwitchToLoginPrompt => 'Already have an account?';

  @override
  String get authSwitchToLoginAction => 'Log in';

  @override
  String get authLegalDisclaimer =>
      'By continuing you agree to our Terms & Privacy Policy.';

  @override
  String get authPasswordResetSent => 'Check your inbox for a reset link.';

  @override
  String get authUnexpectedError =>
      'An unexpected error occurred. Please try again.';

  @override
  String get updatePasswordTitle => 'Update Password';

  @override
  String get updatePasswordToSignIn => 'Take me back to Sign Up';

  @override
  String get updatePasswordEnterPassword => 'Enter your password';

  @override
  String get updatePasswordPasswordLengthError =>
      'Please enter a password that is at least 6 characters long';

  @override
  String get updatePasswordPasswordResetSent => 'Password successfully updated';

  @override
  String get updatePasswordUnexpectedError => 'An unexpected error occurred';

  @override
  String get updatePasswordUpdatePassword => 'Update Password';

  @override
  String get updatePasswordInstructions =>
      'Choose a new password for your account.';

  @override
  String get friends => 'Friends';

  @override
  String get addFriends => 'Add friends';

  @override
  String get friendsNoEntries => 'No friends yet';

  @override
  String get friendDecline => 'Decline';

  @override
  String friendRequests(int count) {
    return 'Friend Requests ($count)';
  }

  @override
  String pendingRequests(int count) {
    return 'Pending Requests ($count)';
  }

  @override
  String get addFriendshipSelectionEmpty => 'Enter exact username or e-mail';

  @override
  String get addFriendshipSearchResult => 'Search Result';

  @override
  String get addFriendshipPendingRequests => 'Added Me';

  @override
  String get addFriendshipAllContacts => 'Find Friends from Contacts';

  @override
  String get addFriendshipContactPermission =>
      'Request access to your contacts.';

  @override
  String get addFriendshipContactPermissionSubtitle =>
      'Please make shure that you have given the app permission to access your contacts.';

  @override
  String get addFriendshipRequested => 'Pending Friendship Requests';

  @override
  String get addFriendshipRequestedNoResult => 'No pending requests found!';

  @override
  String get addFriendshipNoResult => 'No User found with this E-Mail!';

  @override
  String get addFriendshipAmbiguousUsername =>
      'Multiple users share this username. Try searching with the full username#code.';

  @override
  String get addFriendshipContactOpenSettings => 'Allow';

  @override
  String get addFriendshipRequestNoResult => 'No friend request found!';

  @override
  String get addFriendshipContactNoResult => 'No Contacts found!';

  @override
  String get addFriendshipSearchHint => 'Search by username#code';

  @override
  String get addFriendshipFromContacts => 'From your contacts';

  @override
  String get addFriendshipRequestedButton => 'Requested';

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
  String friendshipRequestDecline(String displayName) {
    return 'Request from $displayName was declined';
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
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString';
  }

  @override
  String toCurrencyNoPrefix(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
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
  String groupPayBackNotificationTitle(
    String userDisplayName,
    String groupName,
  ) {
    return '$userDisplayName paid their debts in \"$groupName\" back!';
  }

  @override
  String groupPayBackNotificationBody(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'You should receive $amountString in the next days.';
  }

  @override
  String expenseNotificationTitle(String userDisplayName) {
    return '$userDisplayName added a new expense!';
  }

  @override
  String expenseNotificationBody(
    String expenseName,
    String groupName,
    double amount,
  ) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
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
  String get friendAcceptNotificationTitle =>
      'Your friend request got accepted';

  @override
  String friendAcceptNotificationBody(String userDisplayName) {
    return '$userDisplayName accepted your friend request.';
  }

  @override
  String get friendDeclineNotificationTitle =>
      'Your friend request got declined';

  @override
  String friendDeclineNotificationBody(String userDisplayName) {
    return '$userDisplayName declined your friend request.';
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
  String get settingsDisplayNameValidationEmpty =>
      'Please enter a Display name!';

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
  String get settingsPrivacyPreferencesSuccess =>
      'Your privacy choices have been updated';

  @override
  String get settingsPrivacyPreferencesError =>
      'An error occurred while trying to change your privacy choices';

  @override
  String get contact => 'Support';

  @override
  String get contactSubtitle =>
      'Whether you\'re seeking support, have feedback, or are interested in collaborating with us, please fill out the form below or write us a mail to app.deun@gmail.com!';

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
  String get contactUs => 'Contact Us';

  @override
  String get contactSendSuccess => 'Support request sent!';

  @override
  String get contactSendError => 'Error while requesting the support!';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountError =>
      'Error while trying to delete the user account. Please contact app.deun@gmail.com for support.';

  @override
  String get deleteAccountConfirmKeyword => 'DELETE';

  @override
  String deleteAccountConfirmHint(String keyword) {
    return 'Type $keyword to confirm';
  }

  @override
  String get errorLoadingData => 'Error while loading data!';

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
  String get add => 'Add';

  @override
  String get invite => 'Invite';

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
  String get retry => 'Retry';

  @override
  String get loading => 'Loading';

  @override
  String get you => 'You';

  @override
  String get all => 'All';

  @override
  String localeSelector(String locale) {
    String _temp0 = intl.Intl.selectLogic(locale, {
      'de': 'Deutsch',
      'en': 'English',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get localeSelectorSystem => 'System default';

  @override
  String get expenseCategory => 'Category';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryBills => 'Bills';

  @override
  String get categoryGroceries => 'Groceries';

  @override
  String get categoryRestaurants => 'Restaurants';

  @override
  String get categoryCoffee => 'Coffee';

  @override
  String get categoryGas => 'Gas';

  @override
  String get categoryParking => 'Parking';

  @override
  String get categoryAccommodation => 'Accommodation';

  @override
  String get categoryGifts => 'Gifts';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryTechnology => 'Technology';

  @override
  String get categoryClothing => 'Clothing';

  @override
  String get categoryHome => 'Home';

  @override
  String get categoryOther => 'Other';

  @override
  String get qr => 'QR';

  @override
  String get friendQrTitle => 'Add Friend via QR';

  @override
  String get friendQrTabScan => 'Scan';

  @override
  String get friendQrTabMyCode => 'My Code';

  @override
  String get friendQrNotRecognized => 'QR not recognized';

  @override
  String get copyLink => 'Copy link';

  @override
  String get share => 'Share';

  @override
  String get friendQrLetFriendScan =>
      'Let your friend scan this code to add you.';

  @override
  String get friendQrScanPrompt => 'Point at a friend\'s code';

  @override
  String get friendQrTorchToggle => 'Toggle flashlight';

  @override
  String get friendQrSwitchCamera => 'Switch camera';

  @override
  String get stepperDecrease => 'Decrease';

  @override
  String get stepperIncrease => 'Increase';

  @override
  String get friendQrLinkCopied => 'Link copied';

  @override
  String get friendQrLinkCopiedInstruction =>
      'Link copied. If your system camera supports QR app links, show this code on the other device and scan.';

  @override
  String friendQrShareLink(String url) {
    return 'Let\'s get connected on DEUN! 🤝\n$url';
  }

  @override
  String get friendAcceptConfirmTitle => 'Add as Friend?';

  @override
  String friendAcceptConfirmBody(String displayName) {
    return 'Do you want to add $displayName as a friend?';
  }

  @override
  String get friendAcceptSelfError => 'You cannot add yourself as a friend.';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String statisticsGroupTitle(String groupName) {
    return '$groupName · Stats';
  }

  @override
  String get statisticsRangeThreeMonths => '3M';

  @override
  String get statisticsRangeSixMonths => '6M';

  @override
  String get statisticsRangeTwelveMonths => '12M';

  @override
  String get statisticsRangeAllTime => 'All';

  @override
  String get statisticsTotalSpend => 'Total spend';

  @override
  String get statisticsAvgPerMonth => 'Avg / month';

  @override
  String get statisticsExpenseCount => 'Expenses';

  @override
  String get statisticsBiggestExpense => 'Biggest';

  @override
  String get statisticsVsPreviousPeriod => 'vs previous period';

  @override
  String get statisticsTrend => 'Trend';

  @override
  String get statisticsMembers => 'Members';

  @override
  String get statisticsMemberPaid => 'Paid';

  @override
  String get statisticsMemberFairShare => 'Fair share';

  @override
  String get statisticsMemberDelta => 'Balance';

  @override
  String get statisticsCategoryBreakdown => 'Categories';

  @override
  String get statisticsPersonalOverviewTitle => 'Your statistics';

  @override
  String get statisticsPersonalOverviewEntry => 'Personal overview';

  @override
  String get statisticsTopGroup => 'Top group';

  @override
  String get statisticsTopCategory => 'Top category';

  @override
  String get statisticsGroupsRanked => 'Groups';

  @override
  String get statisticsNoExpenses => 'No expenses';

  @override
  String get statisticsNoExpensesFound => 'No expenses found';

  @override
  String statisticsDetails(String month, String year) {
    return 'Details $month/$year';
  }

  @override
  String paidBy(String displayName) {
    return 'Paid by $displayName';
  }

  @override
  String statisticsCategories(String monthYear) {
    return 'Categories $monthYear';
  }

  @override
  String get receiptScanButton => 'Scan receipt';

  @override
  String get expenseScanShort => 'Scan';

  @override
  String get receiptScanTitle => 'Scan a receipt';

  @override
  String get receiptScanTakePhoto => 'Take Photo';

  @override
  String get receiptScanChooseGallery => 'Choose from Gallery';

  @override
  String get receiptScanProcessing => 'Scanning receipt...';

  @override
  String get receiptScanSuccess => 'Receipt scanned! Review the details below.';

  @override
  String get receiptScanNoData =>
      'Could not read the receipt. Try again with a clearer photo.';

  @override
  String get receiptScanError => 'Something went wrong while scanning.';

  @override
  String get receiptScanInstructions => 'Line up the receipt inside the frame';

  @override
  String get receiptScanReviewTitle => 'Detected items';

  @override
  String receiptScanItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get receiptScanTotalLabel => 'Total';

  @override
  String get receiptScanUseItems => 'Use these items';

  @override
  String get receiptScanRetake => 'Retake';

  @override
  String get splitModeAmount => 'Amount';

  @override
  String get splitModeEqual => 'Equal';

  @override
  String get splitModeExact => 'Exact';

  @override
  String get splitModePercentage => '%';

  @override
  String get splitModeShares => 'Shares';

  @override
  String get splitNotInLabel => 'Not in';

  @override
  String splitEqualSummary(String amount) {
    return '$amount each';
  }

  @override
  String get splitEquallyLabel => 'Split equally';

  @override
  String get splitByAmountLabel => 'Split by exact amounts';

  @override
  String get splitByPercentLabel => 'Split by percentage';

  @override
  String get splitBySharesLabel => 'Split by shares';

  @override
  String get totalLabel => 'Total';

  @override
  String get splitPercentageError => 'Must add up to 100%';

  @override
  String get splitAmountError => 'Must add up to the total';

  @override
  String splitSharesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'parts',
      one: 'part',
    );
    return '$count $_temp0';
  }

  @override
  String get expenseDetailsLabel => 'Details';

  @override
  String get categoryLabel => 'Category';

  @override
  String get splitSectionLabel => 'Split';

  @override
  String splitPeopleCount(int count, int total) {
    return '$count of $total people';
  }

  @override
  String get splitAllocatedLabel => 'All set';

  @override
  String splitRemainingLabel(String amount) {
    return '$amount left';
  }

  @override
  String splitOverLabel(String amount) {
    return '$amount over';
  }

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'You have unsaved changes. If you leave now, they will be lost.';

  @override
  String get discardChangesConfirm => 'Discard';

  @override
  String get discardChangesKeepEditing => 'Keep editing';

  @override
  String get onboardingTitle => 'Welcome to Deun!';

  @override
  String get onboardingSubtitle => 'Choose a username to get started';

  @override
  String get onboardingUsernameLabel => 'Username';

  @override
  String get onboardingDisplayNameLabel => 'Display Name';

  @override
  String get onboardingButton => 'Get Started';

  @override
  String get onboardingUsernameHint =>
      'Letters, numbers, underscores (3–20 chars)';

  @override
  String get onboardingUsernameTaken =>
      'Username not available, please try another';

  @override
  String get onboardingUsernameInvalid =>
      '3–20 characters: letters, numbers, underscores only';

  @override
  String get onboardingDisplayNameRequired => 'Display name is required';

  @override
  String get onboardingUsernameHeading => 'Choose your username';

  @override
  String get onboardingUsernameSubtitle =>
      'It\'s how friends find and add you. You can change it later.';

  @override
  String get onboardingHandlePreviewPrefix => 'Friends will see ';

  @override
  String get settingsUsername => 'Username';

  @override
  String get settingsUsernameCode => 'Your username';

  @override
  String get groupMemberSectionFriends => 'Friends';

  @override
  String get groupMemberSectionOtherUsers => 'Other users';

  @override
  String get groupMemberAddGuestSubtitle => 'Add someone without an account';

  @override
  String get reminderSend => 'Send reminder';

  @override
  String reminderSent(String displayName) {
    return 'Reminder sent to $displayName';
  }

  @override
  String get reminderCooldown => 'Already reminded recently';

  @override
  String reminderNotificationTitle(String displayName) {
    return '$displayName reminds you';
  }

  @override
  String reminderNotificationBody(double amount, String groupName) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      symbol: '€',
      decimalDigits: 2,
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'You owe $amountString in $groupName';
  }

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get groupDetailSettleUp => 'Settle up';

  @override
  String get groupDetailTapToClaim => 'Tap to claim';

  @override
  String groupDetailYouClaimed(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'You claimed $amountString';
  }

  @override
  String groupDetailUnclaimed(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString unclaimed';
  }

  @override
  String get groupDetailAllClaimed => 'all claimed';

  @override
  String get groupDetailItemizedTag => 'itemized';

  @override
  String get groupDetailPaymentTag => 'PAYMENT';

  @override
  String get categorySheetTitle => 'Category';

  @override
  String get paidBySheetTitle => 'Paid by';

  @override
  String get dateSheetTitle => 'Date';

  @override
  String get datePickCustom => 'Pick a date…';

  @override
  String get amountSheetTitle => 'Amount';

  @override
  String get paymentTitle => 'Settle up';

  @override
  String get paymentYouPay => 'You pay';

  @override
  String get paymentOwesYou => 'Owes you';

  @override
  String get paymentPay => 'Pay';

  @override
  String get paymentRemind => 'Remind';

  @override
  String get paymentAllSettled => 'You\'re all settled up';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodPaypalSubtitle => 'Open PayPal.me link';

  @override
  String get paymentMethodIban => 'Bank transfer';

  @override
  String get paymentMethodIbanSubtitle => 'Copy IBAN';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodCashSubtitle => 'Settle in person';

  @override
  String get paymentIbanCopied => 'IBAN copied to clipboard';

  @override
  String paymentPayAmount(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€',
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'Pay $amountString';
  }

  @override
  String get paymentMarkSettled => 'Mark settled';

  @override
  String get settingsProfileSection => 'Profile';

  @override
  String get settingsPreferencesSection => 'Preferences';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSystem => 'System';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsAppearanceInfo =>
      'System follows your device. Dark mode ships with the redesign.';

  @override
  String get settingsLanguageSheetTitle => 'Language';

  @override
  String get settingsDeleteAccountTitle => 'Delete account?';

  @override
  String get settingsDeleteAccountBody =>
      'This permanently deletes your account and all your data. This cannot be undone.';

  @override
  String get settingsDeleteAccountConfirmButton => 'Delete my account';

  @override
  String get settingsTagline => 'Deun · Simply Split Fairly';

  @override
  String settingsUsernameCopied(String handle) {
    return '$handle copied';
  }

  @override
  String get pageNotFound => 'Page not found';
}
