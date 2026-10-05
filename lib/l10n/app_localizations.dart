import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
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
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

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
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Masrouf'**
  String get appTitle;

  /// No description provided for @seedSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get seedSalary;

  /// No description provided for @seedFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get seedFreelance;

  /// No description provided for @seedReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get seedReimbursement;

  /// No description provided for @seedGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get seedGift;

  /// No description provided for @seedOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get seedOther;

  /// No description provided for @seedGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get seedGroceries;

  /// No description provided for @seedEatingOut.
  ///
  /// In en, this message translates to:
  /// **'Eating Out'**
  String get seedEatingOut;

  /// No description provided for @seedTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get seedTransport;

  /// No description provided for @seedRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get seedRent;

  /// No description provided for @seedUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get seedUtilities;

  /// No description provided for @seedSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get seedSubscriptions;

  /// No description provided for @seedHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get seedHealth;

  /// No description provided for @seedFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get seedFamily;

  /// No description provided for @seedShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get seedShopping;

  /// No description provided for @seedGym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get seedGym;

  /// No description provided for @seedSavingsZakat.
  ///
  /// In en, this message translates to:
  /// **'Savings/Zakat'**
  String get seedSavingsZakat;

  /// No description provided for @seedCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get seedCash;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get actionToday;

  /// No description provided for @actionYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get actionYesterday;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get navAdd;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @authSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get authSignOutTitle;

  /// No description provided for @authSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on the server. This device will be cleared and re-downloaded next time you log in.'**
  String get authSignOutBody;

  /// No description provided for @authSignOutPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change has not reached the server yet and will be lost.} other{{count} changes have not reached the server yet and will be lost.}}'**
  String authSignOutPending(int count);

  /// No description provided for @authSignOutSyncFirst.
  ///
  /// In en, this message translates to:
  /// **'Sync first'**
  String get authSignOutSyncFirst;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetPassword;

  /// No description provided for @authSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendResetLink;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Sign up'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get authHaveAccount;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateAccount;

  /// No description provided for @authResetIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a reset link.'**
  String get authResetIntro;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent. Check your inbox.'**
  String get authResetSent;

  /// No description provided for @authCheckEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get authCheckEmailTitle;

  /// No description provided for @authCheckEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it to activate your account.'**
  String authCheckEmailBody(String email);

  /// No description provided for @authResendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get authResendEmail;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get authBackToSignIn;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get validationPasswordTooShort;

  /// No description provided for @validationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordMismatch;

  /// No description provided for @validationAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get validationAmountRequired;

  /// No description provided for @validationAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero'**
  String get validationAmountPositive;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get validationNameRequired;

  /// No description provided for @validationCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get validationCategoryRequired;

  /// No description provided for @validationAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick an account'**
  String get validationAccountRequired;

  /// No description provided for @validationRatePositive.
  ///
  /// In en, this message translates to:
  /// **'Rate must be greater than zero'**
  String get validationRatePositive;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered.'**
  String get errorEmailAlreadyRegistered;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is too weak. Use at least 8 characters.'**
  String get errorWeakPassword;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email before logging in.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get errorNetwork;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Log in again.'**
  String get errorSessionExpired;

  /// No description provided for @txnIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get txnIncome;

  /// No description provided for @txnExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get txnExpense;

  /// No description provided for @txnTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get txnTransfer;

  /// No description provided for @txnAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get txnAmount;

  /// No description provided for @txnNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get txnNote;

  /// No description provided for @txnNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get txnNoteHint;

  /// No description provided for @txnDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get txnDate;

  /// No description provided for @txnAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get txnAccount;

  /// No description provided for @txnRateMissing.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate set for {currency}'**
  String txnRateMissing(String currency);

  /// No description provided for @txnRateMissingHint.
  ///
  /// In en, this message translates to:
  /// **'Set one in Settings → Exchange rates, so this amount is counted correctly.'**
  String get txnRateMissingHint;

  /// No description provided for @txnCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get txnCategory;

  /// No description provided for @txnTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get txnTags;

  /// No description provided for @txnTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Add a tag (optional)'**
  String get txnTagsHint;

  /// No description provided for @txnSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get txnSaved;

  /// No description provided for @txnDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get txnDeleted;

  /// No description provided for @txnUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get txnUndo;

  /// No description provided for @txnRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get txnRecent;

  /// No description provided for @txnAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get txnAll;

  /// No description provided for @txnEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get txnEmpty;

  /// No description provided for @txnEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to log your first one.'**
  String get txnEmptyHint;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountsDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Delete this account? Its transactions stay in your history but will no longer count towards any balance.'**
  String get accountsDeleteWarning;

  /// No description provided for @accountsAdd.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountsAdd;

  /// No description provided for @accountsName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountsName;

  /// No description provided for @accountsOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get accountsOpeningBalance;

  /// No description provided for @accountsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get accountsArchive;

  /// No description provided for @accountsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get accountsArchived;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountTypeBank;

  /// No description provided for @accountTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountTypeSavings;

  /// No description provided for @accountTypeForeign.
  ///
  /// In en, this message translates to:
  /// **'Foreign'**
  String get accountTypeForeign;

  /// No description provided for @accountsTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get accountsTotalBalance;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoriesAdd;

  /// No description provided for @categoriesName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoriesName;

  /// No description provided for @categoriesIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get categoriesIcon;

  /// No description provided for @categoriesColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get categoriesColor;

  /// No description provided for @categoriesReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get categoriesReorderHint;

  /// No description provided for @categoriesKindIncome.
  ///
  /// In en, this message translates to:
  /// **'Income categories'**
  String get categoriesKindIncome;

  /// No description provided for @categoriesKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense categories'**
  String get categoriesKindExpense;

  /// No description provided for @categoriesDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Transactions in this category will keep their history but lose the label.'**
  String get categoriesDeleteWarning;

  /// No description provided for @dashboardThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashboardThisMonth;

  /// No description provided for @dashboardIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get dashboardIn;

  /// No description provided for @dashboardOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get dashboardOut;

  /// No description provided for @dashboardNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get dashboardNet;

  /// No description provided for @dashboardSafeToSpend.
  ///
  /// In en, this message translates to:
  /// **'Safe to spend'**
  String get dashboardSafeToSpend;

  /// No description provided for @dashboardSafeToSpendHint.
  ///
  /// In en, this message translates to:
  /// **'Balance minus known bills before {date}'**
  String dashboardSafeToSpendHint(String date);

  /// No description provided for @dashboardUpcomingBills.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bills'**
  String get dashboardUpcomingBills;

  /// No description provided for @dashboardNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled before next payday.'**
  String get dashboardNoUpcoming;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get analyticsByCategory;

  /// No description provided for @analyticsIncomeByCategory.
  ///
  /// In en, this message translates to:
  /// **'Income by category'**
  String get analyticsIncomeByCategory;

  /// No description provided for @analyticsBurnRate.
  ///
  /// In en, this message translates to:
  /// **'Spent {percent} of income'**
  String analyticsBurnRate(String percent);

  /// No description provided for @analyticsBurnRateNoIncome.
  ///
  /// In en, this message translates to:
  /// **'No income recorded this month'**
  String get analyticsBurnRateNoIncome;

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @budgetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get budgetsEmpty;

  /// No description provided for @budgetsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly cap on a category to see how you are tracking against it.'**
  String get budgetsEmptyHint;

  /// No description provided for @budgetCap.
  ///
  /// In en, this message translates to:
  /// **'Monthly cap'**
  String get budgetCap;

  /// No description provided for @budgetOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get budgetOptional;

  /// No description provided for @budgetNone.
  ///
  /// In en, this message translates to:
  /// **'No cap'**
  String get budgetNone;

  /// No description provided for @budgetRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String budgetRemaining(String amount);

  /// No description provided for @budgetOver.
  ///
  /// In en, this message translates to:
  /// **'{amount} over'**
  String budgetOver(String amount);

  /// No description provided for @budgetSpentOfCap.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {cap}'**
  String budgetSpentOfCap(String spent, String cap);

  /// No description provided for @budgetRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this budget? Nothing else changes.'**
  String get budgetRemoveConfirm;

  /// No description provided for @plannedTitle.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get plannedTitle;

  /// No description provided for @plannedAdd.
  ///
  /// In en, this message translates to:
  /// **'New planned expense'**
  String get plannedAdd;

  /// No description provided for @plannedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get plannedEmpty;

  /// No description provided for @plannedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Plan a future expense and it is set aside from Safe to spend, without leaving your balance.'**
  String get plannedEmptyHint;

  /// No description provided for @plannedReserved.
  ///
  /// In en, this message translates to:
  /// **'{amount} set aside'**
  String plannedReserved(String amount);

  /// No description provided for @plannedDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Did this happen?'**
  String get plannedDueTitle;

  /// No description provided for @plannedDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String plannedDueOn(String date);

  /// No description provided for @plannedLogIt.
  ///
  /// In en, this message translates to:
  /// **'Log it'**
  String get plannedLogIt;

  /// No description provided for @plannedSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get plannedSkip;

  /// No description provided for @plannedWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get plannedWhen;

  /// No description provided for @plannedNotCounted.
  ///
  /// In en, this message translates to:
  /// **'Not counted in your balance until you log it'**
  String get plannedNotCounted;

  /// No description provided for @plannedRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this plan? Nothing else changes.'**
  String get plannedRemoveConfirm;

  /// No description provided for @forecastTitle.
  ///
  /// In en, this message translates to:
  /// **'Next months'**
  String get forecastTitle;

  /// No description provided for @forecastSavings.
  ///
  /// In en, this message translates to:
  /// **'About {amount} saved'**
  String forecastSavings(String amount);

  /// No description provided for @forecastShortfall.
  ///
  /// In en, this message translates to:
  /// **'About {amount} short'**
  String forecastShortfall(String amount);

  /// No description provided for @forecastTypical.
  ///
  /// In en, this message translates to:
  /// **'Typical'**
  String get forecastTypical;

  /// No description provided for @forecastCommitted.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get forecastCommitted;

  /// No description provided for @forecastPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get forecastPlanned;

  /// No description provided for @forecastProvisional.
  ///
  /// In en, this message translates to:
  /// **'Based on less than 3 months of history — treat as a rough guide.'**
  String get forecastProvisional;

  /// No description provided for @forecastExplains.
  ///
  /// In en, this message translates to:
  /// **'Your usual spending, plus the bills you know about, plus what you planned.'**
  String get forecastExplains;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings goals'**
  String get goalsTitle;

  /// No description provided for @goalsAdd.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get goalsAdd;

  /// No description provided for @goalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get goalsEmpty;

  /// No description provided for @goalsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Set a target and the account that holds it, and progress tracks that account’s real balance.'**
  String get goalsEmptyHint;

  /// No description provided for @goalsTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalsTarget;

  /// No description provided for @goalsBy.
  ///
  /// In en, this message translates to:
  /// **'By {date}'**
  String goalsBy(String date);

  /// No description provided for @goalsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} a month needed'**
  String goalsPerMonth(String amount);

  /// No description provided for @goalsReached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get goalsReached;

  /// No description provided for @goalsOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get goalsOnTrack;

  /// No description provided for @goalsBehind.
  ///
  /// In en, this message translates to:
  /// **'Behind — your forecast saves less than this needs'**
  String get goalsBehind;

  /// No description provided for @goalsAccount.
  ///
  /// In en, this message translates to:
  /// **'Held in'**
  String get goalsAccount;

  /// No description provided for @goalsRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this goal? The account and its balance are untouched.'**
  String get goalsRemoveConfirm;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash-flow calendar'**
  String get calendarTitle;

  /// No description provided for @calendarEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing expected this month'**
  String get calendarEmpty;

  /// No description provided for @calendarDayTotal.
  ///
  /// In en, this message translates to:
  /// **'{amount} expected'**
  String calendarDayTotal(String amount);

  /// No description provided for @digestTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get digestTitle;

  /// No description provided for @digestEnable.
  ///
  /// In en, this message translates to:
  /// **'Weekly spending summary'**
  String get digestEnable;

  /// No description provided for @digestHint.
  ///
  /// In en, this message translates to:
  /// **'A notification each Sunday evening comparing this week to last.'**
  String get digestHint;

  /// No description provided for @digestBodyUp.
  ///
  /// In en, this message translates to:
  /// **'You spent {amount} this week, {percent} more than last week.'**
  String digestBodyUp(String amount, String percent);

  /// No description provided for @digestBodyDown.
  ///
  /// In en, this message translates to:
  /// **'You spent {amount} this week, {percent} less than last week.'**
  String digestBodyDown(String amount, String percent);

  /// No description provided for @digestBodyFlat.
  ///
  /// In en, this message translates to:
  /// **'You spent {amount} this week.'**
  String digestBodyFlat(String amount);

  /// No description provided for @digestPermission.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Masrouf. Enable them in system settings.'**
  String get digestPermission;

  /// No description provided for @analyticsCashflow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get analyticsCashflow;

  /// No description provided for @analyticsIncomeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Income breakdown'**
  String get analyticsIncomeBreakdown;

  /// No description provided for @analyticsPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get analyticsPreviousMonth;

  /// No description provided for @analyticsCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'Current month'**
  String get analyticsCurrentMonth;

  /// No description provided for @analyticsNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get analyticsNoData;

  /// No description provided for @analyticsDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get analyticsDaily;

  /// No description provided for @analyticsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get analyticsWeekly;

  /// No description provided for @analyticsVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'{percent} vs last month'**
  String analyticsVsPrevious(String percent);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes, tags, amounts'**
  String get historySearchHint;

  /// No description provided for @historyFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get historyFilter;

  /// No description provided for @historyFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get historyFilterAll;

  /// No description provided for @historyNoResults.
  ///
  /// In en, this message translates to:
  /// **'No transactions match your filters'**
  String get historyNoResults;

  /// No description provided for @historyClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get historyClearFilters;

  /// No description provided for @recurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringTitle;

  /// No description provided for @recurringAdd.
  ///
  /// In en, this message translates to:
  /// **'New recurring rule'**
  String get recurringAdd;

  /// No description provided for @recurringDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this rule? Transactions it already created are kept.'**
  String get recurringDeleteConfirm;

  /// No description provided for @recurringCadenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurringCadenceMonthly;

  /// No description provided for @recurringCadenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurringCadenceWeekly;

  /// No description provided for @recurringNextRun.
  ///
  /// In en, this message translates to:
  /// **'Next on {date}'**
  String recurringNextRun(String date);

  /// No description provided for @recurringActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recurringActive;

  /// No description provided for @recurringGenerated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions generated} =1{1 transaction generated} other{{count} transactions generated}}'**
  String recurringGenerated(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get settingsBaseCurrency;

  /// No description provided for @settingsExchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get settingsExchangeRates;

  /// No description provided for @settingsRateFor.
  ///
  /// In en, this message translates to:
  /// **'1 {currency} ='**
  String settingsRateFor(String currency);

  /// No description provided for @settingsPayday.
  ///
  /// In en, this message translates to:
  /// **'Payday'**
  String get settingsPayday;

  /// No description provided for @settingsPaydayDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of the month'**
  String settingsPaydayDay(int day);

  /// No description provided for @settingsExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get settingsExportCsv;

  /// No description provided for @settingsExportDone.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} transactions'**
  String settingsExportDone(int count);

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSyncStatus;

  /// No description provided for @syncIdle.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncIdle;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — changes are saved locally'**
  String get syncOffline;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting} other{{count} changes waiting}}'**
  String syncPending(int count);

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed — will retry'**
  String get syncFailed;

  /// No description provided for @historySelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String historySelectedCount(int count);

  /// No description provided for @historySelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get historySelectAll;

  /// No description provided for @historyDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Transaction duplicated'**
  String get historyDuplicated;

  /// No description provided for @bulkPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get bulkPickCategory;

  /// No description provided for @bulkTagHint.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get bulkTagHint;

  /// No description provided for @bulkRecategorize.
  ///
  /// In en, this message translates to:
  /// **'Recategorize'**
  String get bulkRecategorize;

  /// No description provided for @bulkAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get bulkAddTag;

  /// No description provided for @bulkDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bulkDelete;

  /// No description provided for @bulkUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matching transaction} =1{1 transaction updated} other{{count} transactions updated}}'**
  String bulkUpdated(int count);

  /// No description provided for @bulkDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction deleted} other{{count} transactions deleted}}'**
  String bulkDeleted(int count);

  /// No description provided for @channelDigestName.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get channelDigestName;

  /// No description provided for @channelDigestDescription.
  ///
  /// In en, this message translates to:
  /// **'A weekly recap of what you spent.'**
  String get channelDigestDescription;

  /// No description provided for @channelRemindersName.
  ///
  /// In en, this message translates to:
  /// **'Bill reminders'**
  String get channelRemindersName;

  /// No description provided for @channelRemindersDescription.
  ///
  /// In en, this message translates to:
  /// **'Planned expenses falling due.'**
  String get channelRemindersDescription;

  /// No description provided for @channelBudgetsName.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get channelBudgetsName;

  /// No description provided for @channelBudgetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Categories approaching or over their cap.'**
  String get channelBudgetsDescription;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @remindersEnable.
  ///
  /// In en, this message translates to:
  /// **'Bill reminders'**
  String get remindersEnable;

  /// No description provided for @remindersHint.
  ///
  /// In en, this message translates to:
  /// **'A notification on the morning a planned expense is due.'**
  String get remindersHint;

  /// No description provided for @budgetAlertsEnable.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get budgetAlertsEnable;

  /// No description provided for @budgetAlertsHint.
  ///
  /// In en, this message translates to:
  /// **'A notification when a category reaches 80% and 100% of its cap.'**
  String get budgetAlertsHint;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} is planned for today.'**
  String reminderBody(String amount);

  /// No description provided for @reminderBodyWithCategory.
  ///
  /// In en, this message translates to:
  /// **'{category}: {amount} is planned for today.'**
  String reminderBodyWithCategory(String category, String amount);

  /// No description provided for @budgetAlertNearTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} is nearly spent'**
  String budgetAlertNearTitle(String category);

  /// No description provided for @budgetAlertNearBody.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {cap} used — {remaining} left this month.'**
  String budgetAlertNearBody(String spent, String cap, String remaining);

  /// No description provided for @budgetAlertOverTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} is over budget'**
  String budgetAlertOverTitle(String category);

  /// No description provided for @budgetAlertOverBody.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {cap} used — {overspend} over.'**
  String budgetAlertOverBody(String spent, String cap, String overspend);

  /// No description provided for @settingsBackups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get settingsBackups;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @backupLastAt.
  ///
  /// In en, this message translates to:
  /// **'Last backup {date}'**
  String backupLastAt(String date);

  /// No description provided for @backupNever.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get backupNever;

  /// No description provided for @backupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupDone;

  /// No description provided for @backupEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to back up yet.'**
  String get backupEmpty;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not write the backup.'**
  String get backupFailed;

  /// No description provided for @backupShare.
  ///
  /// In en, this message translates to:
  /// **'Share latest backup'**
  String get backupShare;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get backupRestore;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Everything in the backup replaces what is on this device, then syncs to your account. Anything recorded since the backup was taken is lost.'**
  String get backupRestoreBody;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} records'**
  String backupRestoreDone(int count);

  /// No description provided for @backupRestoreInvalid.
  ///
  /// In en, this message translates to:
  /// **'That file is not a Masrouf backup.'**
  String get backupRestoreInvalid;

  /// No description provided for @backupAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic weekly backup'**
  String get backupAuto;

  /// No description provided for @backupAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps the last four backups on this device.'**
  String get backupAutoHint;

  /// No description provided for @budgetAlertSpentTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} is fully spent'**
  String budgetAlertSpentTitle(String category);

  /// No description provided for @budgetAlertSpentBody.
  ///
  /// In en, this message translates to:
  /// **'All {cap} is used. That is the whole budget for this month.'**
  String budgetAlertSpentBody(String cap);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return L10nAr();
    case 'en':
      return L10nEn();
    case 'fr':
      return L10nFr();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
