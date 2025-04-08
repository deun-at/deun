// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get addNewGroup => 'Neue Gruppe';

  @override
  String get addNewExpense => 'Neue Ausgabe';

  @override
  String get groups => 'Gruppen';

  @override
  String groupListFilter(String filter) {
    String _temp0 = intl.Intl.selectLogic(
      filter,
      {
        'all': 'alle',
        'active': 'offen',
        'done': 'abgeschlossen',
        'other': '',
      },
    );
    return '$_temp0';
  }

  @override
  String get createGroup => 'Gruppe erstellen';

  @override
  String get editGroup => 'Gruppe bearbeiten';

  @override
  String get groupName => 'Name';

  @override
  String get addGroupTitle => 'Titel hinzufügen';

  @override
  String get groupNameValidationEmpty => 'Bitte gib einen Namen ein!';

  @override
  String get groupSimplifiedExpensesTitle => 'Vereinfachte Ausgaben aktivieren';

  @override
  String get expenseDateValidationEmpty => 'Bitte gib ein Datum ein!';

  @override
  String get groupDeleteItemTitle => 'Diese Gruppe löschen?';

  @override
  String get groupNoEntries => 'Füge eine Gruppe hinzu, um zu starten.';

  @override
  String get groupEntriesError => 'Es trat ein Problem beim Laden der Gruppen auf.';

  @override
  String get groupMemberSelectionEmpty => 'Freunde suchen';

  @override
  String get groupMemberAddFriends => 'Freunde hinzufügen';

  @override
  String get groupMemberSelectionTitle => 'Hinzugefügte Freunde';

  @override
  String get groupMemberResultEmpty => 'Keine Freunde gefunden!';

  @override
  String get groupExpenseNoEntries => 'Füge eine Ausgabe hinzu, um zu starten.';

  @override
  String get groupDeleteError => 'Fehler beim Löschen der Gruppe!';

  @override
  String get groupDeleteSuccess => 'Gruppe gelöscht!';

  @override
  String get groupCreateError => 'Fehler beim Erstellen der Gruppe!';

  @override
  String get groupCreateSuccess => 'Gruppe erstellt!';

  @override
  String get expenses => 'Ausgaben';

  @override
  String get expensesSearchTitle => 'Suche';

  @override
  String get expensesSearchDescription => 'Nach Ausgaben suchen';

  @override
  String get expensesSearchEmpty => 'Keine Ergebnisse gefunden!';

  @override
  String get createExpense => 'Ausgabe erstellen';

  @override
  String get editExpense => 'Ausgabe bearbeiten';

  @override
  String get addExpenseTitle => 'Titel hinzufügen';

  @override
  String get expenseName => 'Beschreibung';

  @override
  String get expenseNameValidationEmpty => 'Bitte gib einen Titel ein!';

  @override
  String get expenseAmount => 'Betrag';

  @override
  String get expenseAmountValidationEmpty => 'Bitte gib einen Betrag ein!';

  @override
  String get expenseDate => 'Wann wurde gezahlt?';

  @override
  String get expensePaidBy => 'Wer hat gezahlt?';

  @override
  String get expenseEntryTitle => 'Eintrag Titel hinzufügen';

  @override
  String get addNewExpenseEntry => 'Eintrag hinzufügen';

  @override
  String get expenseEntryName => 'Name';

  @override
  String get expenseEntryNameValidationEmpty => 'Bitte gib einen Eintrag Titel ein!';

  @override
  String get expenseEntryAmount => 'Betrag';

  @override
  String get expenseEntryAmountValidationEmpty => 'Bitte gib einen Betrag ein!';

  @override
  String get expenseEntrySharesLable => 'Wer war dabei?';

  @override
  String get expenseEntrySharesValidationEmpty => 'Bitte wähle mindestens eine Person aus!';

  @override
  String get expenseDeleteItemTitle => 'Diese Ausgabe löschen?';

  @override
  String get expenseDeleteError => 'Fehler beim Löschen der Ausgabe!';

  @override
  String get expenseDeleteSuccess => 'Ausgabe gelöscht!';

  @override
  String get expenseCreateError => 'Fehler beim Erstellen der Ausgabe!';

  @override
  String get expenseCreateSuccess => 'Ausgabe erstellt!';

  @override
  String get expenseNoEntries => 'So leer hier :(';

  @override
  String expenseDisplayAmount(String displayNameYourself, String displayName, String expenseType, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(
      displayNameYourself,
      {
        'yes': 'hast',
        'other': 'hat',
      },
    );
    String _temp1 = intl.Intl.selectLogic(
      expenseType,
      {
        'paid': 'gezahlt',
        'lent': 'geliehen',
        'borrowed': 'geborgt',
        'other': '',
      },
    );
    return '$displayName $_temp0 $amountString $_temp1';
  }

  @override
  String get expenseNoShares => 'Du bist nicht beteiligt';

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
        'yes': '$displayName schuldet dir',
        'other': 'Du schuldest $displayName',
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
        'yes': 'Du hast $amountString gut',
        'other': 'Du hast $amountString Schulden',
      },
    );
    return '$_temp0';
  }

  @override
  String totalExpensesAmount(double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'Gesamtausgaben $amountString';
  }

  @override
  String get allDone => 'Alles erledigt';

  @override
  String get payBack => 'Zurückzahlen';

  @override
  String get payBackNoEntries => 'Es gibt nichts zurückzuzahlen!';

  @override
  String get payBackDialogTitle => 'Zurückzahlen!';

  @override
  String payBackDialog(String displayName, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'Du schuldest $displayName $amountString';
  }

  @override
  String get payBackDialogPaypal => 'Paypal-Link öffnen';

  @override
  String get payBackDialogIban => 'IBAN kopieren';

  @override
  String get payBackDialogDone => 'Als bezahlt markieren';

  @override
  String get payBackError => 'Es gab einen Fehler beim Zurückzahlen des Betrags. Bitte versuche es später noch einmal!';

  @override
  String payBackSuccess(String displayName, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    return 'Du hast $displayName $amountString zurückgezahlt';
  }

  @override
  String groupDisplayPaidBack(String paidByYourself, String paidBy, String paidForYourself, String paidFor, double amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.currency(
      locale: localeName,
      decimalDigits: 2,
      name: '€'
    );
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(
      paidByYourself,
      {
        'yes': 'hast',
        'other': 'hat',
      },
    );
    String _temp1 = intl.Intl.selectLogic(
      paidForYourself,
      {
        'yes': 'dir',
        'other': '$paidFor',
      },
    );
    return '$paidBy $_temp0 $_temp1 $amountString zurückgezahlt';
  }

  @override
  String get signInTitle => 'Anmelden';

  @override
  String get signInSubtitle => 'Bitte melde dich mit deinem Konto an.';

  @override
  String get signInDescription => 'Gib deine E-Mail und dein Passwort ein, um fortzufahren.';

  @override
  String get signInEmailTitle => 'E-Mail';

  @override
  String get updatePasswordTitle => 'Passwort aktualisieren';

  @override
  String get updatePasswordToSignIn => 'Verwende dein neues Passwort, um dich anzumelden.';

  @override
  String get updatePasswordEnterPassword => 'Gib dein neues Passwort ein';

  @override
  String get updatePasswordPasswordLengthError => 'Das Passwort muss mindestens 8 Zeichen lang sein.';

  @override
  String get updatePasswordPasswordResetSent => 'Ein Link zum Zurücksetzen des Passworts wurde gesendet.';

  @override
  String get updatePasswordunexpectedError => 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es später noch einmal.';

  @override
  String get updatePasswordUpdatePassword => 'Passwort aktualisieren';

  @override
  String get friends => 'Freunde';

  @override
  String get friendsNoEntries => 'Keine Freunde gefunden.';

  @override
  String get addFriendshipSelectionEmpty => 'Bitte wähle einen Freund aus.';

  @override
  String get addFriendshipNoResult => 'Es wurden keine Freunde gefunden.';

  @override
  String get requestFriendship => 'Freund hinzufügen';

  @override
  String get friendsPending => 'Ausstehende Freundschaften';

  @override
  String friendshipRequestSent(String displayName) {
    return 'Freundschaftsanfrage gesendet.';
  }

  @override
  String removeFriend(String displayName) {
    return 'Freund entfernen';
  }

  @override
  String friendRemoved(String displayName) {
    return 'Freund entfernt.';
  }

  @override
  String friendshipAccept(String displayName) {
    return 'Anfrage annehmen';
  }

  @override
  String friendshipRequestCancel(String displayName) {
    return 'Freundschaftsanfrage abbrechen';
  }

  @override
  String friendshipDialogTitle(String displayName) {
    return 'Freundschaftsanfrage';
  }

  @override
  String get friendshipDialogEmail => 'E-Mail:';

  @override
  String get friendshipDialogFullName => 'Vollständiger Name:';

  @override
  String get friendshipDialogRemoveAsFriend => 'Als Freund entfernen';

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
  String get settings => 'Einstellungen';

  @override
  String get settingsUserHeading => 'Benutzereinstellungen';

  @override
  String get settingsFirstName => 'Vorname';

  @override
  String get settingsFirstNameValidationEmpty => 'Bitte gib einen Vornamen ein!';

  @override
  String get settingsLastName => 'Nachname';

  @override
  String get settingsLastNameValidationEmpty => 'Bitte gib einen Nachnamen ein!';

  @override
  String get settingsDisplayName => 'Anzeigename';

  @override
  String get settingsDisplayNameValidationEmpty => 'Bitte gib einen Anzeigenamen ein!';

  @override
  String get settingsPaypalMe => 'PayPal.me';

  @override
  String get settingsIban => 'IBAN';

  @override
  String get settingsLocale => 'Sprache';

  @override
  String get settingsUserUpdateSuccess => 'Benutzerdaten erfolgreich aktualisiert.';

  @override
  String get settingsUserUpdateError => 'Fehler beim Aktualisieren der Benutzerdaten.';

  @override
  String get settingsSignOutDialogTitle => 'Wirklich abmelden?';

  @override
  String get settingsSignOut => 'Abmelden';

  @override
  String get settingsPrivacyPolicy => 'Datenschutzrichtlinien';

  @override
  String get settingsPrivacyPreferences => 'Datenschutzeinstellungen';

  @override
  String get settingsPrivacyPreferencesSuccess => 'Datenschutzeinstellungen erfolgreich gespeichert.';

  @override
  String get settingsPrivacyPreferencesError => 'Fehler beim Speichern der Datenschutzeinstellungen.';

  @override
  String get contact => 'Support';

  @override
  String get contactSubtitle => 'Egal, ob du Unterstützung suchst, Feedback hast oder an einer Zusammenarbeit interessiert bist - fülle einfach das untenstehende Formular aus oder schreibe uns eine E-Mail an app.deun@gmail.com!';

  @override
  String get contactName => 'Name';

  @override
  String get contactNameValidationEmpty => 'Bitte gib einen Namen ein!';

  @override
  String get contactCompany => 'Unternehmen';

  @override
  String get contactEmail => 'E-Mail';

  @override
  String get contactEmailValidationEmpty => 'Bitte gib eine E-Mail ein!';

  @override
  String get contactDescription => 'Beschreibung';

  @override
  String get contactDescriptionValidationEmpty => 'Bitte gib eine Beschreibung ein!';

  @override
  String get contactUs => 'Kontaktiere uns';

  @override
  String get contactSendSuccess => 'Nachricht erfolgreich gesendet.';

  @override
  String get contactSendError => 'Fehler beim Senden der Nachricht.';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountError => 'Fehler beim Löschen des Kontos.';

  @override
  String get create => 'Erstellen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get update => 'Aktualisieren';

  @override
  String get save => 'Speichern';

  @override
  String get accept => 'Akzeptieren';

  @override
  String get remove => 'Entfernen';

  @override
  String get open => 'Öffnen';

  @override
  String get close => 'Schließen';

  @override
  String get send => 'Senden';

  @override
  String get generalError => 'Ein Fehler ist aufgetreten.';

  @override
  String get loading => 'Lädt...';

  @override
  String get you => 'Du';

  @override
  String get all => 'Alle';

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
  String get localeSelectorSystem => 'Systemsprache';
}
