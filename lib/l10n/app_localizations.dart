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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Button to add a new group.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get addNewGroup;

  /// No description provided for @addNewExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addNewExpense;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @groupSectionFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get groupSectionFavorites;

  /// No description provided for @groupSectionSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get groupSectionSettled;

  /// Greeting in the groups home header.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// Time-of-day greeting line on the groups home header (05:00-11:59).
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// Time-of-day greeting line on the groups home header (12:00-16:59).
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// Time-of-day greeting line on the groups home header (17:00-21:59).
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// Time-of-day greeting line on the groups home header (22:00-04:59).
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get homeGreetingNight;

  /// Lead label on the overall-balance hero when the user has a net positive balance.
  ///
  /// In en, this message translates to:
  /// **'Overall, you\'re owed'**
  String get homeOverallOwed;

  /// Lead label on the overall-balance hero when the user has a net negative balance.
  ///
  /// In en, this message translates to:
  /// **'Overall, you owe'**
  String get homeOverallOwe;

  /// Lead label on the overall-balance hero when nothing is owed in either direction.
  ///
  /// In en, this message translates to:
  /// **'You\'re all settled up'**
  String get homeOverallSettled;

  /// Stat-chip label on the hero for the total the user is owed.
  ///
  /// In en, this message translates to:
  /// **'You\'re owed'**
  String get homeStatOwed;

  /// Stat-chip label on the hero for the total the user owes.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get homeStatOwe;

  /// Section header above the group cards.
  ///
  /// In en, this message translates to:
  /// **'Your groups'**
  String get homeYourGroups;

  /// Short action label, e.g. create a new group.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// Balance lead label on a group card when the user is owed money.
  ///
  /// In en, this message translates to:
  /// **'You\'re owed'**
  String get balanceOwed;

  /// Balance lead label on a group card when the user owes money.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get balanceOwe;

  /// Balance lead label on a group card when the group is settled.
  ///
  /// In en, this message translates to:
  /// **'Settled up'**
  String get balanceSettled;

  /// Lead label on the settle-up hero when the user is owed money overall.
  ///
  /// In en, this message translates to:
  /// **'You\'re owed overall'**
  String get paymentBalanceOwed;

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

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameHint;

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

  /// No description provided for @groupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get groupCreateTitle;

  /// No description provided for @groupEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get groupEditTitle;

  /// No description provided for @groupColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get groupColorLabel;

  /// No description provided for @groupMemberSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMemberSectionTitle;

  /// No description provided for @groupTrackingModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense tracking'**
  String get groupTrackingModeTitle;

  /// No description provided for @groupTrackingModeSimplifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Simplified'**
  String get groupTrackingModeSimplifiedTitle;

  /// No description provided for @groupTrackingModeSimplifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fewer payments to settle the group balance.'**
  String get groupTrackingModeSimplifiedSubtitle;

  /// No description provided for @groupTrackingModeDetailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get groupTrackingModeDetailedTitle;

  /// No description provided for @groupTrackingModeDetailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track exactly who owes whom for each expense.'**
  String get groupTrackingModeDetailedSubtitle;

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

  /// Option in member search to add the typed name as a guest.
  ///
  /// In en, this message translates to:
  /// **'Add {name} as guest'**
  String groupMemberAddGuestOption(String name);

  /// No description provided for @groupMemberIsGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get groupMemberIsGuest;

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

  /// No description provided for @groupInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get groupInviteTitle;

  /// No description provided for @groupInviteTitleNamed.
  ///
  /// In en, this message translates to:
  /// **'Invite to {group}'**
  String groupInviteTitleNamed(String group);

  /// No description provided for @groupInviteLetFriendScan.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code to join the group.'**
  String get groupInviteLetFriendScan;

  /// No description provided for @groupInviteLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Group link'**
  String get groupInviteLinkLabel;

  /// No description provided for @groupInviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get groupInviteLinkCopied;

  /// No description provided for @groupInviteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this link can join the group.'**
  String get groupInviteSubtitle;

  /// No description provided for @groupInviteShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get groupInviteShowQr;

  /// No description provided for @groupInviteHideQr.
  ///
  /// In en, this message translates to:
  /// **'Hide QR code'**
  String get groupInviteHideQr;

  /// No description provided for @inviteQrButton.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get inviteQrButton;

  /// No description provided for @inviteShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get inviteShareLink;

  /// No description provided for @groupInviteJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get groupInviteJoinTitle;

  /// No description provided for @groupInviteJoinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join this group to view and add expenses.'**
  String get groupInviteJoinSubtitle;

  /// No description provided for @groupInviteJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Enter Group'**
  String get groupInviteJoinButton;

  /// Title for selecting an existing guest profile when joining a group.
  ///
  /// In en, this message translates to:
  /// **'Who are you in this group?'**
  String get groupInviteGuestSelectTitle;

  /// No description provided for @groupInviteGuestSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If you were added as a guest before (no account), pick your name to take over all expenses. If you don\'t find yourself, just join as a new member.'**
  String get groupInviteGuestSelectSubtitle;

  /// No description provided for @groupInviteJoinAsNew.
  ///
  /// In en, this message translates to:
  /// **'Join as new member'**
  String get groupInviteJoinAsNew;

  /// No description provided for @groupInviteNoGuestsFound.
  ///
  /// In en, this message translates to:
  /// **'No guest profiles found in this group.'**
  String get groupInviteNoGuestsFound;

  /// No description provided for @groupInviteTransferButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get groupInviteTransferButton;

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
  /// **'Date'**
  String get expenseDate;

  /// Label for the date row in the expense editor's Paid by / When list.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get expenseWhen;

  /// No description provided for @expensePaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get expensePaidBy;

  /// Per-person preview under the quick-split amount (total divided equally among group members).
  ///
  /// In en, this message translates to:
  /// **'Split {amount} each'**
  String expenseSplitEach(String amount);

  /// No description provided for @expenseEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add item title'**
  String get expenseEntryTitle;

  /// Placeholder in the inset description field of the expense editor item card.
  ///
  /// In en, this message translates to:
  /// **'Add a description'**
  String get expenseDescriptionHint;

  /// No description provided for @addNewExpenseEntry.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addNewExpenseEntry;

  /// No description provided for @editorModeQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick split'**
  String get editorModeQuick;

  /// No description provided for @editorModeItemized.
  ///
  /// In en, this message translates to:
  /// **'Itemized'**
  String get editorModeItemized;

  /// No description provided for @itemizedItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemizedItemsLabel;

  /// No description provided for @itemizedTotalFromItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items yet} =1{Total · from 1 item} other{Total · from {count} items}}'**
  String itemizedTotalFromItems(int count);

  /// No description provided for @addItemByHand.
  ///
  /// In en, this message translates to:
  /// **'Add item by hand'**
  String get addItemByHand;

  /// No description provided for @itemizedInfoCallout.
  ///
  /// In en, this message translates to:
  /// **'After you share, members claim their own items — solo or split, per unit.'**
  String get itemizedInfoCallout;

  /// No description provided for @expenseSaveAndShareForClaiming.
  ///
  /// In en, this message translates to:
  /// **'Add & share for claiming'**
  String get expenseSaveAndShareForClaiming;

  /// App-bar title for the expense detail (read) screen.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseDetailTitle;

  /// Header title for the expense editor when creating a new expense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get expenseDetailTitleNew;

  /// Header title for the expense editor when editing an existing expense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get expenseDetailTitleEdit;

  /// Label above the current user's net amount on the expense detail summary card.
  ///
  /// In en, this message translates to:
  /// **'Your net'**
  String get expenseYourNetLabel;

  /// Combined payer line on the expense detail summary card when the current user paid.
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get expensePaidByYou;

  /// Combined payer line on the expense detail summary card when someone else paid.
  ///
  /// In en, this message translates to:
  /// **'{name} paid'**
  String expensePaidByOther(String name);

  /// Net phrase on the expense detail summary card when the user is owed for this expense.
  ///
  /// In en, this message translates to:
  /// **'You lent {amount}'**
  String expenseYouLentAmount(String amount);

  /// Net phrase on the expense detail summary card when the user owes for this expense.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount}'**
  String expenseYouOweAmount(String amount);

  /// Pill label on the expense detail summary card when the user is owed for this expense.
  ///
  /// In en, this message translates to:
  /// **'You lent'**
  String get expenseYouLent;

  /// Pill label on the expense detail summary card when the user owes for this expense.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get expenseYouOwe;

  /// Pill label on the expense detail summary card when the user's net for this expense is zero.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get expenseNetSettled;

  /// Section label above the per-member breakdown on the expense detail screen.
  ///
  /// In en, this message translates to:
  /// **'Who owes what'**
  String get expenseBreakdownLabel;

  /// Section label above the category tags on the expense detail screen.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get expenseTagsLabel;

  /// Title of the Review & claim banner on the expense detail screen.
  ///
  /// In en, this message translates to:
  /// **'Itemized expense'**
  String get expenseReviewClaimTitle;

  /// Subtitle of the Review & claim banner on the expense detail screen.
  ///
  /// In en, this message translates to:
  /// **'Review the items and claim what you had.'**
  String get expenseReviewClaimSubtitle;

  /// Call-to-action on the Review & claim banner on the expense detail screen.
  ///
  /// In en, this message translates to:
  /// **'Review & claim'**
  String get expenseReviewClaimAction;

  /// App-bar / header title for the itemized claim screen (Screen 9).
  ///
  /// In en, this message translates to:
  /// **'Tap to claim'**
  String get claimTitle;

  /// Label next to the live-presence pulse dot in the claim screen header.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get claimPresenceLive;

  /// Tooltip / label for the edit-items action that opens the itemized editor from the claim screen.
  ///
  /// In en, this message translates to:
  /// **'Edit items'**
  String get claimEditItems;

  /// Label above the persona switcher that previews the claim view as a chosen member.
  ///
  /// In en, this message translates to:
  /// **'Preview as'**
  String get claimPreviewAs;

  /// Label above the selected persona's claimed total on the dark summary card.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get claimYourShare;

  /// Progress caption under the claimed/total progress bar on the summary card.
  ///
  /// In en, this message translates to:
  /// **'{claimed} of {total} claimed'**
  String claimProgressLabel(String claimed, String total);

  /// Label for the amount on the receipt nobody has claimed yet.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed'**
  String get claimUnclaimedLabel;

  /// Status shown on the summary card when nothing is left unclaimed.
  ///
  /// In en, this message translates to:
  /// **'All claimed'**
  String get claimAllClaimed;

  /// Section label above the per-member totals on the summary card.
  ///
  /// In en, this message translates to:
  /// **'Per person'**
  String get claimPerMemberLabel;

  /// Uppercase caption above the list of claimable items on the Tap to Claim screen. Rendered in screaming caps via styling.
  ///
  /// In en, this message translates to:
  /// **'Tap to take what you had'**
  String get claimItemsCaption;

  /// Chip text on an item that nobody has claimed yet.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed'**
  String get claimItemUnclaimed;

  /// Empty state shown when an expense has no per-unit claim items.
  ///
  /// In en, this message translates to:
  /// **'This expense has no claimable items.'**
  String get claimNoItems;

  /// Error state shown when the claim screen fails to load the expense.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this expense.'**
  String get claimLoadError;

  /// Dashed open chip on an unclaimed unit; tap to claim it.
  ///
  /// In en, this message translates to:
  /// **'Take one'**
  String get claimTakeOne;

  /// Subline on a multi-unit item card: per-unit price and number of ordered units.
  ///
  /// In en, this message translates to:
  /// **'{price} each · {count} ordered'**
  String claimEachOrdered(String price, int count);

  /// Hint on an item card while free unit slots remain and the persona holds none.
  ///
  /// In en, this message translates to:
  /// **'Tap a slot to take one'**
  String get claimTapSlotHint;

  /// Chip label on a unit split between several people, showing the per-person cost.
  ///
  /// In en, this message translates to:
  /// **'split · {amount}'**
  String claimSplitLabel(String amount);

  /// Action on a claim chip that opens the member picker to split a single unit.
  ///
  /// In en, this message translates to:
  /// **'Split one'**
  String get claimSplitOne;

  /// Title of the inline member picker sheet for splitting one unit.
  ///
  /// In en, this message translates to:
  /// **'Split this item'**
  String get claimSplitSheetTitle;

  /// Live per-person cost shown in the split picker as members are selected.
  ///
  /// In en, this message translates to:
  /// **'{amount} each'**
  String claimSplitPerPerson(String amount);

  /// Confirm button in the split-one member picker.
  ///
  /// In en, this message translates to:
  /// **'Apply split'**
  String get claimSplitApply;

  /// Warning callout above the items when some units have no claimer.
  ///
  /// In en, this message translates to:
  /// **'{amount} still unclaimed'**
  String claimUnclaimedCallout(String amount);

  /// Action in the unclaimed callout that reminds members to claim their items.
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get claimNudge;

  /// Snackbar confirmation shown after tapping Nudge.
  ///
  /// In en, this message translates to:
  /// **'Nudge sent to remind everyone to claim.'**
  String get claimNudgeSent;

  /// Sticky CTA that confirms the persona's claimed total.
  ///
  /// In en, this message translates to:
  /// **'Confirm — I had {amount}'**
  String claimConfirm(String amount);

  /// Title of the success sheet shown after confirming a claim.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set'**
  String get claimConfirmedTitle;

  /// Body of the claim success sheet, showing the confirmed share.
  ///
  /// In en, this message translates to:
  /// **'Your share of {amount} is saved. We\'ll keep the totals up to date as others claim.'**
  String claimConfirmedBody(String amount);

  /// Dismiss button on the claim success sheet.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get claimConfirmedDone;

  /// Trailing label for a member who is owed in the per-member breakdown.
  ///
  /// In en, this message translates to:
  /// **'lent'**
  String get expenseMemberLent;

  /// Trailing label for a member who owes in the per-member breakdown.
  ///
  /// In en, this message translates to:
  /// **'owes'**
  String get expenseMemberOwes;

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

  /// No description provided for @expenseEntryAmountValidationZero.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero!'**
  String get expenseEntryAmountValidationZero;

  /// No description provided for @expenseEntrySharesLable.
  ///
  /// In en, this message translates to:
  /// **'Split between'**
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

  /// No description provided for @expenseDeleteItemMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes the expense and updates everyone\'s balances. This can\'t be undone.'**
  String get expenseDeleteItemMessage;

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
  String expenseDisplayAmount(
    String displayNameYourself,
    String displayName,
    String expenseType,
    double amount,
  );

  /// No description provided for @expenseNoShares.
  ///
  /// In en, this message translates to:
  /// **'You are not involved'**
  String get expenseNoShares;

  /// Lable in the group list/group detail of what you are owed/what you owe per user.
  ///
  /// In en, this message translates to:
  /// **'{paidByYourself, select, yes{{displayName} owes you} other{You owe {displayName}}} {amount}'**
  String groupDisplayAmount(
    String displayName,
    String paidByYourself,
    double amount,
  );

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

  /// Subtitle for the 'Mark as paid' option in the friend detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Settle the balance manually'**
  String get friendPayBackMarkPaidSubtitle;

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
  String groupDisplayPaidBack(
    String paidByYourself,
    String paidBy,
    String paidForYourself,
    String paidFor,
    double amount,
  );

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

  /// Screen 1 title in login mode.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginTitle;

  /// Screen 1 title in sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authSignupTitle;

  /// Subtitle shown under the title on the login / sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Simply split fairly with your group.'**
  String get authSubtitle;

  /// Apple social sign-in button label.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// Google social sign-in button label.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// GitHub social sign-in button label.
  ///
  /// In en, this message translates to:
  /// **'Continue with GitHub'**
  String get authContinueWithGithub;

  /// Label centered on the divider between social and email sign-in.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authDividerOr;

  /// Label for the email field on the login / sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Label for the password field on the login / sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Label for the display-name field shown on sign-up.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get authNameLabel;

  /// Validation error for an invalid email on the login / sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get authEmailInvalid;

  /// Validation error when the password is shorter than 6 characters.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password that is at least 6 characters long.'**
  String get authPasswordTooShort;

  /// Validation error when the display name is empty on sign-up.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get authNameRequired;

  /// Forgot-password link shown in login mode.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Primary submit button label in login mode.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLoginCta;

  /// Primary submit button label in sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignupCta;

  /// Prompt before the link to switch to sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authSwitchToSignupPrompt;

  /// Action link to switch to sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSwitchToSignupAction;

  /// Prompt before the link to switch to login mode.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authSwitchToLoginPrompt;

  /// Action link to switch to login mode.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authSwitchToLoginAction;

  /// Muted legal microcopy footer under the login / sign-up CTA.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our Terms & Privacy Policy.'**
  String get authLegalDisclaimer;

  /// Snackbar confirmation after a password reset email is sent.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox for a reset link.'**
  String get authPasswordResetSent;

  /// Fallback error for non-auth failures on the login / sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get authUnexpectedError;

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

  /// No description provided for @updatePasswordUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get updatePasswordUnexpectedError;

  /// No description provided for @updatePasswordUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordUpdatePassword;

  /// No description provided for @updatePasswordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get updatePasswordInstructions;

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

  /// Tooltip/label for declining an incoming friend request.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get friendDecline;

  /// No description provided for @friendRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend Requests ({count})'**
  String friendRequests(int count);

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Requests ({count})'**
  String pendingRequests(int count);

  /// No description provided for @addFriendshipSelectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter exact username or e-mail'**
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
  /// **'Find Friends from Contacts'**
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

  /// No description provided for @addFriendshipAmbiguousUsername.
  ///
  /// In en, this message translates to:
  /// **'Multiple users share this username. Try searching with the full username#code.'**
  String get addFriendshipAmbiguousUsername;

  /// No description provided for @addFriendshipContactOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get addFriendshipContactOpenSettings;

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

  /// No description provided for @addFriendshipSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by username#code'**
  String get addFriendshipSearchHint;

  /// No description provided for @addFriendshipFromContacts.
  ///
  /// In en, this message translates to:
  /// **'From your contacts'**
  String get addFriendshipFromContacts;

  /// No description provided for @addFriendshipRequestedButton.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get addFriendshipRequestedButton;

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
  String groupPayBackNotificationTitle(
    String userDisplayName,
    String groupName,
  );

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
  String expenseNotificationBody(
    String expenseName,
    String groupName,
    double amount,
  );

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

  /// No description provided for @deleteAccountConfirmKeyword.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAccountConfirmKeyword;

  /// No description provided for @deleteAccountConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Type {keyword} to confirm'**
  String deleteAccountConfirmHint(String keyword);

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

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

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

  /// No description provided for @expenseCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseCategory;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransport;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// No description provided for @categoryBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get categoryBills;

  /// No description provided for @categoryGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoryGroceries;

  /// No description provided for @categoryRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get categoryRestaurants;

  /// No description provided for @categoryCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get categoryCoffee;

  /// No description provided for @categoryGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get categoryGas;

  /// No description provided for @categoryParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get categoryParking;

  /// No description provided for @categoryAccommodation.
  ///
  /// In en, this message translates to:
  /// **'Accommodation'**
  String get categoryAccommodation;

  /// No description provided for @categoryGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryGifts;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categorySports;

  /// No description provided for @categoryBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryBeauty;

  /// No description provided for @categoryTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get categoryTechnology;

  /// No description provided for @categoryClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoryClothing;

  /// No description provided for @categoryHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get categoryHome;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @qr.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get qr;

  /// No description provided for @friendQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Friend via QR'**
  String get friendQrTitle;

  /// No description provided for @friendQrTabScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get friendQrTabScan;

  /// No description provided for @friendQrTabMyCode.
  ///
  /// In en, this message translates to:
  /// **'My Code'**
  String get friendQrTabMyCode;

  /// No description provided for @friendQrNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'QR not recognized'**
  String get friendQrNotRecognized;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @friendQrLetFriendScan.
  ///
  /// In en, this message translates to:
  /// **'Let your friend scan this code to add you.'**
  String get friendQrLetFriendScan;

  /// No description provided for @friendQrScanPrompt.
  ///
  /// In en, this message translates to:
  /// **'Point at a friend\'s code'**
  String get friendQrScanPrompt;

  /// No description provided for @friendQrTorchToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle flashlight'**
  String get friendQrTorchToggle;

  /// No description provided for @friendQrSwitchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get friendQrSwitchCamera;

  /// No description provided for @stepperDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get stepperDecrease;

  /// No description provided for @stepperIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get stepperIncrease;

  /// No description provided for @friendQrLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get friendQrLinkCopied;

  /// No description provided for @friendQrLinkCopiedInstruction.
  ///
  /// In en, this message translates to:
  /// **'Link copied. If your system camera supports QR app links, show this code on the other device and scan.'**
  String get friendQrLinkCopiedInstruction;

  /// No description provided for @friendQrShareLink.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get connected on DEUN! 🤝\n{url}'**
  String friendQrShareLink(String url);

  /// No description provided for @friendAcceptConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add as Friend?'**
  String get friendAcceptConfirmTitle;

  /// No description provided for @friendAcceptConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to add {displayName} as a friend?'**
  String friendAcceptConfirmBody(String displayName);

  /// No description provided for @friendAcceptSelfError.
  ///
  /// In en, this message translates to:
  /// **'You cannot add yourself as a friend.'**
  String get friendAcceptSelfError;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @statisticsGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'{groupName} · Stats'**
  String statisticsGroupTitle(String groupName);

  /// No description provided for @statisticsRangeThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get statisticsRangeThreeMonths;

  /// No description provided for @statisticsRangeSixMonths.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get statisticsRangeSixMonths;

  /// No description provided for @statisticsRangeTwelveMonths.
  ///
  /// In en, this message translates to:
  /// **'12M'**
  String get statisticsRangeTwelveMonths;

  /// No description provided for @statisticsRangeAllTime.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statisticsRangeAllTime;

  /// No description provided for @statisticsTotalSpend.
  ///
  /// In en, this message translates to:
  /// **'Total spend'**
  String get statisticsTotalSpend;

  /// No description provided for @statisticsAvgPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Avg / month'**
  String get statisticsAvgPerMonth;

  /// No description provided for @statisticsExpenseCount.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get statisticsExpenseCount;

  /// No description provided for @statisticsBiggestExpense.
  ///
  /// In en, this message translates to:
  /// **'Biggest'**
  String get statisticsBiggestExpense;

  /// No description provided for @statisticsVsPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'vs previous period'**
  String get statisticsVsPreviousPeriod;

  /// No description provided for @statisticsTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get statisticsTrend;

  /// No description provided for @statisticsMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get statisticsMembers;

  /// No description provided for @statisticsMemberPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statisticsMemberPaid;

  /// No description provided for @statisticsMemberFairShare.
  ///
  /// In en, this message translates to:
  /// **'Fair share'**
  String get statisticsMemberFairShare;

  /// No description provided for @statisticsMemberDelta.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get statisticsMemberDelta;

  /// No description provided for @statisticsCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get statisticsCategoryBreakdown;

  /// No description provided for @statisticsPersonalOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Your statistics'**
  String get statisticsPersonalOverviewTitle;

  /// No description provided for @statisticsPersonalOverviewEntry.
  ///
  /// In en, this message translates to:
  /// **'Personal overview'**
  String get statisticsPersonalOverviewEntry;

  /// No description provided for @statisticsTopGroup.
  ///
  /// In en, this message translates to:
  /// **'Top group'**
  String get statisticsTopGroup;

  /// No description provided for @statisticsTopCategory.
  ///
  /// In en, this message translates to:
  /// **'Top category'**
  String get statisticsTopCategory;

  /// No description provided for @statisticsGroupsRanked.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get statisticsGroupsRanked;

  /// No description provided for @statisticsNoExpenses.
  ///
  /// In en, this message translates to:
  /// **'No expenses'**
  String get statisticsNoExpenses;

  /// No description provided for @statisticsNoExpensesFound.
  ///
  /// In en, this message translates to:
  /// **'No expenses found'**
  String get statisticsNoExpensesFound;

  /// No description provided for @statisticsDetails.
  ///
  /// In en, this message translates to:
  /// **'Details {month}/{year}'**
  String statisticsDetails(String month, String year);

  /// No description provided for @paidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by {displayName}'**
  String paidBy(String displayName);

  /// No description provided for @statisticsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories {monthYear}'**
  String statisticsCategories(String monthYear);

  /// No description provided for @receiptScanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get receiptScanButton;

  /// No description provided for @expenseScanShort.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get expenseScanShort;

  /// No description provided for @receiptScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt'**
  String get receiptScanTitle;

  /// No description provided for @receiptScanTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get receiptScanTakePhoto;

  /// No description provided for @receiptScanChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get receiptScanChooseGallery;

  /// No description provided for @receiptScanProcessing.
  ///
  /// In en, this message translates to:
  /// **'Scanning receipt...'**
  String get receiptScanProcessing;

  /// No description provided for @receiptScanSuccess.
  ///
  /// In en, this message translates to:
  /// **'Receipt scanned! Review the details below.'**
  String get receiptScanSuccess;

  /// No description provided for @receiptScanNoData.
  ///
  /// In en, this message translates to:
  /// **'Could not read the receipt. Try again with a clearer photo.'**
  String get receiptScanNoData;

  /// No description provided for @receiptScanError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while scanning.'**
  String get receiptScanError;

  /// No description provided for @receiptScanInstructions.
  ///
  /// In en, this message translates to:
  /// **'Line up the receipt inside the frame'**
  String get receiptScanInstructions;

  /// No description provided for @receiptScanReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Detected items'**
  String get receiptScanReviewTitle;

  /// No description provided for @receiptScanItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String receiptScanItemCount(int count);

  /// No description provided for @receiptScanTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get receiptScanTotalLabel;

  /// No description provided for @receiptScanUseItems.
  ///
  /// In en, this message translates to:
  /// **'Use these items'**
  String get receiptScanUseItems;

  /// No description provided for @receiptScanRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get receiptScanRetake;

  /// No description provided for @splitModeAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get splitModeAmount;

  /// No description provided for @splitModeEqual.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get splitModeEqual;

  /// No description provided for @splitModeExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get splitModeExact;

  /// No description provided for @splitModePercentage.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get splitModePercentage;

  /// No description provided for @splitModeShares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get splitModeShares;

  /// No description provided for @splitNotInLabel.
  ///
  /// In en, this message translates to:
  /// **'Not in'**
  String get splitNotInLabel;

  /// No description provided for @splitEqualSummary.
  ///
  /// In en, this message translates to:
  /// **'{amount} each'**
  String splitEqualSummary(String amount);

  /// No description provided for @splitEquallyLabel.
  ///
  /// In en, this message translates to:
  /// **'Split equally'**
  String get splitEquallyLabel;

  /// No description provided for @splitByAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Split by exact amounts'**
  String get splitByAmountLabel;

  /// No description provided for @splitByPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Split by percentage'**
  String get splitByPercentLabel;

  /// No description provided for @splitBySharesLabel.
  ///
  /// In en, this message translates to:
  /// **'Split by shares'**
  String get splitBySharesLabel;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @splitPercentageError.
  ///
  /// In en, this message translates to:
  /// **'Must add up to 100%'**
  String get splitPercentageError;

  /// No description provided for @splitAmountError.
  ///
  /// In en, this message translates to:
  /// **'Must add up to the total'**
  String get splitAmountError;

  /// No description provided for @splitSharesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{part} other{parts}}'**
  String splitSharesSummary(int count);

  /// No description provided for @expenseDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get expenseDetailsLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @splitSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get splitSectionLabel;

  /// No description provided for @splitPeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} people'**
  String splitPeopleCount(int count, int total);

  /// No description provided for @splitAllocatedLabel.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get splitAllocatedLabel;

  /// No description provided for @splitRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String splitRemainingLabel(String amount);

  /// No description provided for @splitOverLabel.
  ///
  /// In en, this message translates to:
  /// **'{amount} over'**
  String splitOverLabel(String amount);

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. If you leave now, they will be lost.'**
  String get discardChangesMessage;

  /// No description provided for @discardChangesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChangesConfirm;

  /// No description provided for @discardChangesKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get discardChangesKeepEditing;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Deun!'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a username to get started'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get onboardingUsernameLabel;

  /// No description provided for @onboardingDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get onboardingDisplayNameLabel;

  /// No description provided for @onboardingButton.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingButton;

  /// No description provided for @onboardingUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, underscores (3–20 chars)'**
  String get onboardingUsernameHint;

  /// No description provided for @onboardingUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username not available, please try another'**
  String get onboardingUsernameTaken;

  /// No description provided for @onboardingUsernameInvalid.
  ///
  /// In en, this message translates to:
  /// **'3–20 characters: letters, numbers, underscores only'**
  String get onboardingUsernameInvalid;

  /// No description provided for @onboardingDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get onboardingDisplayNameRequired;

  /// No description provided for @onboardingUsernameHeading.
  ///
  /// In en, this message translates to:
  /// **'Choose your username'**
  String get onboardingUsernameHeading;

  /// No description provided for @onboardingUsernameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s how friends find and add you. You can change it later.'**
  String get onboardingUsernameSubtitle;

  /// No description provided for @onboardingHandlePreviewPrefix.
  ///
  /// In en, this message translates to:
  /// **'Friends will see '**
  String get onboardingHandlePreviewPrefix;

  /// No description provided for @settingsUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsUsername;

  /// No description provided for @settingsUsernameCode.
  ///
  /// In en, this message translates to:
  /// **'Your username'**
  String get settingsUsernameCode;

  /// No description provided for @groupMemberSectionFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get groupMemberSectionFriends;

  /// No description provided for @groupMemberSectionOtherUsers.
  ///
  /// In en, this message translates to:
  /// **'Other users'**
  String get groupMemberSectionOtherUsers;

  /// No description provided for @groupMemberAddGuestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add someone without an account'**
  String get groupMemberAddGuestSubtitle;

  /// No description provided for @reminderSend.
  ///
  /// In en, this message translates to:
  /// **'Send reminder'**
  String get reminderSend;

  /// No description provided for @reminderSent.
  ///
  /// In en, this message translates to:
  /// **'Reminder sent to {displayName}'**
  String reminderSent(String displayName);

  /// No description provided for @reminderCooldown.
  ///
  /// In en, this message translates to:
  /// **'Already reminded recently'**
  String get reminderCooldown;

  /// No description provided for @reminderNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'{displayName} reminds you'**
  String reminderNotificationTitle(String displayName);

  /// No description provided for @reminderNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount} in {groupName}'**
  String reminderNotificationBody(double amount, String groupName);

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// Button in the group-detail hero that opens the settle-up / payment screen.
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get groupDetailSettleUp;

  /// Pill on an itemized ledger row prompting the user to claim their items.
  ///
  /// In en, this message translates to:
  /// **'Tap to claim'**
  String get groupDetailTapToClaim;

  /// Shown on an itemized ledger row after the current user has claimed.
  ///
  /// In en, this message translates to:
  /// **'You claimed {amount}'**
  String groupDetailYouClaimed(double amount);

  /// Meta line on an itemized ledger row showing the still-unclaimed amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} unclaimed'**
  String groupDetailUnclaimed(double amount);

  /// Meta line on an itemized ledger row when nothing is left unclaimed.
  ///
  /// In en, this message translates to:
  /// **'all claimed'**
  String get groupDetailAllClaimed;

  /// Indicator in the payer subline of an itemized ledger row (e.g. 'Sam paid · itemized').
  ///
  /// In en, this message translates to:
  /// **'itemized'**
  String get groupDetailItemizedTag;

  /// Trailing tag on a payback / settlement ledger row.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT'**
  String get groupDetailPaymentTag;

  /// Title of the category picker bottom sheet (icon grid).
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categorySheetTitle;

  /// Title of the paid-by picker bottom sheet (member list).
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get paidBySheetTitle;

  /// Title of the date picker bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateSheetTitle;

  /// Option in the date sheet that opens the platform calendar.
  ///
  /// In en, this message translates to:
  /// **'Pick a date…'**
  String get datePickCustom;

  /// Title of the amount keypad bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountSheetTitle;

  /// Title of the settle-up / payment sheet (Screen 10).
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get paymentTitle;

  /// Section label over the members the current user owes.
  ///
  /// In en, this message translates to:
  /// **'You pay'**
  String get paymentYouPay;

  /// Section label over the members who owe the current user.
  ///
  /// In en, this message translates to:
  /// **'Owes you'**
  String get paymentOwesYou;

  /// Action on a you-pay row that opens the payment-method detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get paymentPay;

  /// Action on an owes-you row that sends a payment reminder.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get paymentRemind;

  /// Empty state on the settle-up sheet when nothing is owed either way.
  ///
  /// In en, this message translates to:
  /// **'You\'re all settled up'**
  String get paymentAllSettled;

  /// Title of the PayPal payment-method card.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get paymentMethodPaypal;

  /// Subtitle of the PayPal payment-method card.
  ///
  /// In en, this message translates to:
  /// **'Open PayPal.me link'**
  String get paymentMethodPaypalSubtitle;

  /// Title of the IBAN / bank-transfer payment-method card.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentMethodIban;

  /// Subtitle of the IBAN payment-method card.
  ///
  /// In en, this message translates to:
  /// **'Copy IBAN'**
  String get paymentMethodIbanSubtitle;

  /// Title of the cash payment-method card.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// Subtitle of the cash payment-method card.
  ///
  /// In en, this message translates to:
  /// **'Settle in person'**
  String get paymentMethodCashSubtitle;

  /// Snackbar shown after copying a payee's IBAN.
  ///
  /// In en, this message translates to:
  /// **'IBAN copied to clipboard'**
  String get paymentIbanCopied;

  /// Sticky CTA on the method-detail sheet that records the payment.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String paymentPayAmount(double amount);

  /// Sticky CTA on the cash method-detail sheet that marks the balance settled.
  ///
  /// In en, this message translates to:
  /// **'Mark settled'**
  String get paymentMarkSettled;

  /// Section label above the profile form on the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfileSection;

  /// Section label above the settings list (notifications, appearance, privacy, contact).
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesSection;

  /// Label for the notifications toggle row on the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Label for the appearance row and the appearance picker sheet title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Appearance option that follows the device theme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsAppearanceSystem;

  /// Light appearance option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// Dark appearance option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// Info callout under the appearance options explaining the System option.
  ///
  /// In en, this message translates to:
  /// **'System follows your device. Dark mode ships with the redesign.'**
  String get settingsAppearanceInfo;

  /// Title of the language picker bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSheetTitle;

  /// Title of the delete-account confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteAccountTitle;

  /// Explanatory body in the delete-account sheet.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and all your data. This cannot be undone.'**
  String get settingsDeleteAccountBody;

  /// Destructive confirm button in the delete-account sheet.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteAccountConfirmButton;

  /// Centered muted tagline footer at the bottom of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Deun · Simply Split Fairly'**
  String get settingsTagline;

  /// Snackbar shown after copying the user's full username to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'{handle} copied'**
  String settingsUsernameCopied(String handle);

  /// Fallback message shown for unknown/invalid routes.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
