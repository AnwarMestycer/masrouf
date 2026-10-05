// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Masrouf';

  @override
  String get seedSalary => 'Salary';

  @override
  String get seedFreelance => 'Freelance';

  @override
  String get seedReimbursement => 'Reimbursement';

  @override
  String get seedGift => 'Gift';

  @override
  String get seedOther => 'Other';

  @override
  String get seedGroceries => 'Groceries';

  @override
  String get seedEatingOut => 'Eating Out';

  @override
  String get seedTransport => 'Transport';

  @override
  String get seedRent => 'Rent';

  @override
  String get seedUtilities => 'Utilities';

  @override
  String get seedSubscriptions => 'Subscriptions';

  @override
  String get seedHealth => 'Health';

  @override
  String get seedFamily => 'Family';

  @override
  String get seedShopping => 'Shopping';

  @override
  String get seedGym => 'Gym';

  @override
  String get seedSavingsZakat => 'Savings/Zakat';

  @override
  String get seedCash => 'Cash';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionDone => 'Done';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionClose => 'Close';

  @override
  String get actionToday => 'Today';

  @override
  String get actionYesterday => 'Yesterday';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navAdd => 'Add';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navSettings => 'Settings';

  @override
  String get authSignIn => 'Log in';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignOutTitle => 'Sign out?';

  @override
  String get authSignOutBody =>
      'Your data stays on the server. This device will be cleared and re-downloaded next time you log in.';

  @override
  String authSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes have not reached the server yet and will be lost.',
      one: '1 change has not reached the server yet and will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get authSignOutSyncFirst => 'Sync first';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authResetPassword => 'Reset password';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get authNoAccount => 'No account yet? Sign up';

  @override
  String get authHaveAccount => 'Already have an account? Log in';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authCreateAccount => 'Create your account';

  @override
  String get authResetIntro =>
      'Enter your email and we\'ll send you a reset link.';

  @override
  String get authResetSent => 'Reset link sent. Check your inbox.';

  @override
  String get authCheckEmailTitle => 'Confirm your email';

  @override
  String authCheckEmailBody(String email) {
    return 'We sent a confirmation link to $email. Open it to activate your account.';
  }

  @override
  String get authResendEmail => 'Resend email';

  @override
  String get authBackToSignIn => 'Back to log in';

  @override
  String get validationEmailRequired => 'Email is required';

  @override
  String get validationEmailInvalid => 'Enter a valid email address';

  @override
  String get validationPasswordRequired => 'Password is required';

  @override
  String get validationPasswordTooShort =>
      'Password must be at least 8 characters';

  @override
  String get validationPasswordMismatch => 'Passwords do not match';

  @override
  String get validationAmountRequired => 'Enter an amount';

  @override
  String get validationAmountPositive => 'Amount must be greater than zero';

  @override
  String get validationNameRequired => 'Name is required';

  @override
  String get validationCategoryRequired => 'Pick a category';

  @override
  String get validationAccountRequired => 'Pick an account';

  @override
  String get validationRatePositive => 'Rate must be greater than zero';

  @override
  String get errorInvalidCredentials => 'Wrong email or password.';

  @override
  String get errorEmailAlreadyRegistered => 'That email is already registered.';

  @override
  String get errorWeakPassword =>
      'That password is too weak. Use at least 8 characters.';

  @override
  String get errorEmailNotConfirmed => 'Confirm your email before logging in.';

  @override
  String get errorNetwork => 'No connection. Check your network and try again.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get errorSessionExpired => 'Your session expired. Log in again.';

  @override
  String get txnIncome => 'Income';

  @override
  String get txnExpense => 'Expense';

  @override
  String get txnTransfer => 'Transfer';

  @override
  String get txnAmount => 'Amount';

  @override
  String get txnNote => 'Note';

  @override
  String get txnNoteHint => 'Add a note (optional)';

  @override
  String get txnDate => 'Date';

  @override
  String get txnAccount => 'Account';

  @override
  String txnRateMissing(String currency) {
    return 'No exchange rate set for $currency';
  }

  @override
  String get txnRateMissingHint =>
      'Set one in Settings → Exchange rates, so this amount is counted correctly.';

  @override
  String get txnCategory => 'Category';

  @override
  String get txnTags => 'Tags';

  @override
  String get txnTagsHint => 'Add a tag (optional)';

  @override
  String get txnSaved => 'Saved';

  @override
  String get txnDeleted => 'Deleted';

  @override
  String get txnUndo => 'Undo';

  @override
  String get txnRecent => 'Recent';

  @override
  String get txnAll => 'All';

  @override
  String get txnEmpty => 'No transactions yet';

  @override
  String get txnEmptyHint => 'Tap + to log your first one.';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsDeleteWarning =>
      'Delete this account? Its transactions stay in your history but will no longer count towards any balance.';

  @override
  String get accountsAdd => 'New account';

  @override
  String get accountsName => 'Account name';

  @override
  String get accountsOpeningBalance => 'Opening balance';

  @override
  String get accountsArchive => 'Archive';

  @override
  String get accountsArchived => 'Archived';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get accountTypeForeign => 'Foreign';

  @override
  String get accountsTotalBalance => 'Total balance';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesAdd => 'New category';

  @override
  String get categoriesName => 'Category name';

  @override
  String get categoriesIcon => 'Icon';

  @override
  String get categoriesColor => 'Colour';

  @override
  String get categoriesReorderHint => 'Drag to reorder';

  @override
  String get categoriesKindIncome => 'Income categories';

  @override
  String get categoriesKindExpense => 'Expense categories';

  @override
  String get categoriesDeleteWarning =>
      'Transactions in this category will keep their history but lose the label.';

  @override
  String get dashboardThisMonth => 'This month';

  @override
  String get dashboardIn => 'In';

  @override
  String get dashboardOut => 'Out';

  @override
  String get dashboardNet => 'Net';

  @override
  String get dashboardSafeToSpend => 'Safe to spend';

  @override
  String dashboardSafeToSpendHint(String date) {
    return 'Balance minus known bills before $date';
  }

  @override
  String get dashboardUpcomingBills => 'Upcoming bills';

  @override
  String get dashboardNoUpcoming => 'Nothing scheduled before next payday.';

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsByCategory => 'Spending by category';

  @override
  String get analyticsIncomeByCategory => 'Income by category';

  @override
  String analyticsBurnRate(String percent) {
    return 'Spent $percent of income';
  }

  @override
  String get analyticsBurnRateNoIncome => 'No income recorded this month';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetsEmpty => 'No budgets yet';

  @override
  String get budgetsEmptyHint =>
      'Set a monthly cap on a category to see how you are tracking against it.';

  @override
  String get budgetCap => 'Monthly cap';

  @override
  String get budgetOptional => 'Optional';

  @override
  String get budgetNone => 'No cap';

  @override
  String budgetRemaining(String amount) {
    return '$amount left';
  }

  @override
  String budgetOver(String amount) {
    return '$amount over';
  }

  @override
  String budgetSpentOfCap(String spent, String cap) {
    return '$spent of $cap';
  }

  @override
  String get budgetRemoveConfirm => 'Remove this budget? Nothing else changes.';

  @override
  String get plannedTitle => 'Planned';

  @override
  String get plannedAdd => 'New planned expense';

  @override
  String get plannedEmpty => 'Nothing planned';

  @override
  String get plannedEmptyHint =>
      'Plan a future expense and it is set aside from Safe to spend, without leaving your balance.';

  @override
  String plannedReserved(String amount) {
    return '$amount set aside';
  }

  @override
  String get plannedDueTitle => 'Did this happen?';

  @override
  String plannedDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get plannedLogIt => 'Log it';

  @override
  String get plannedSkip => 'Skip';

  @override
  String get plannedWhen => 'When';

  @override
  String get plannedNotCounted =>
      'Not counted in your balance until you log it';

  @override
  String get plannedRemoveConfirm => 'Remove this plan? Nothing else changes.';

  @override
  String get forecastTitle => 'Next months';

  @override
  String forecastSavings(String amount) {
    return 'About $amount saved';
  }

  @override
  String forecastShortfall(String amount) {
    return 'About $amount short';
  }

  @override
  String get forecastTypical => 'Typical';

  @override
  String get forecastCommitted => 'Bills';

  @override
  String get forecastPlanned => 'Planned';

  @override
  String get forecastProvisional =>
      'Based on less than 3 months of history — treat as a rough guide.';

  @override
  String get forecastExplains =>
      'Your usual spending, plus the bills you know about, plus what you planned.';

  @override
  String get goalsTitle => 'Savings goals';

  @override
  String get goalsAdd => 'New goal';

  @override
  String get goalsEmpty => 'No goals yet';

  @override
  String get goalsEmptyHint =>
      'Set a target and the account that holds it, and progress tracks that account’s real balance.';

  @override
  String get goalsTarget => 'Target';

  @override
  String goalsBy(String date) {
    return 'By $date';
  }

  @override
  String goalsPerMonth(String amount) {
    return '$amount a month needed';
  }

  @override
  String get goalsReached => 'Reached';

  @override
  String get goalsOnTrack => 'On track';

  @override
  String get goalsBehind => 'Behind — your forecast saves less than this needs';

  @override
  String get goalsAccount => 'Held in';

  @override
  String get goalsRemoveConfirm =>
      'Remove this goal? The account and its balance are untouched.';

  @override
  String get calendarTitle => 'Cash-flow calendar';

  @override
  String get calendarEmpty => 'Nothing expected this month';

  @override
  String calendarDayTotal(String amount) {
    return '$amount expected';
  }

  @override
  String get digestTitle => 'Weekly summary';

  @override
  String get digestEnable => 'Weekly spending summary';

  @override
  String get digestHint =>
      'A notification each Sunday evening comparing this week to last.';

  @override
  String digestBodyUp(String amount, String percent) {
    return 'You spent $amount this week, $percent more than last week.';
  }

  @override
  String digestBodyDown(String amount, String percent) {
    return 'You spent $amount this week, $percent less than last week.';
  }

  @override
  String digestBodyFlat(String amount) {
    return 'You spent $amount this week.';
  }

  @override
  String get digestPermission =>
      'Notifications are turned off for Masrouf. Enable them in system settings.';

  @override
  String get analyticsCashflow => 'Cash flow';

  @override
  String get analyticsIncomeBreakdown => 'Income breakdown';

  @override
  String get analyticsPreviousMonth => 'Previous month';

  @override
  String get analyticsCurrentMonth => 'Current month';

  @override
  String get analyticsNoData => 'Not enough data yet';

  @override
  String get analyticsDaily => 'Daily';

  @override
  String get analyticsWeekly => 'Weekly';

  @override
  String analyticsVsPrevious(String percent) {
    return '$percent vs last month';
  }

  @override
  String get historyTitle => 'History';

  @override
  String get historySearchHint => 'Search notes, tags, amounts';

  @override
  String get historyFilter => 'Filter';

  @override
  String get historyFilterAll => 'All';

  @override
  String get historyNoResults => 'No transactions match your filters';

  @override
  String get historyClearFilters => 'Clear filters';

  @override
  String get recurringTitle => 'Recurring';

  @override
  String get recurringAdd => 'New recurring rule';

  @override
  String get recurringDeleteConfirm =>
      'Delete this rule? Transactions it already created are kept.';

  @override
  String get recurringCadenceMonthly => 'Monthly';

  @override
  String get recurringCadenceWeekly => 'Weekly';

  @override
  String recurringNextRun(String date) {
    return 'Next on $date';
  }

  @override
  String get recurringActive => 'Active';

  @override
  String recurringGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions generated',
      one: '1 transaction generated',
      zero: 'No transactions generated',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsBaseCurrency => 'Base currency';

  @override
  String get settingsExchangeRates => 'Exchange rates';

  @override
  String settingsRateFor(String currency) {
    return '1 $currency =';
  }

  @override
  String get settingsPayday => 'Payday';

  @override
  String settingsPaydayDay(int day) {
    return 'Day $day of the month';
  }

  @override
  String get settingsExportCsv => 'Export CSV';

  @override
  String settingsExportDone(int count) {
    return 'Exported $count transactions';
  }

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSyncStatus => 'Sync';

  @override
  String get syncIdle => 'Up to date';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncOffline => 'Offline — changes are saved locally';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '1 change waiting',
    );
    return '$_temp0';
  }

  @override
  String get syncFailed => 'Sync failed — will retry';

  @override
  String historySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get historySelectAll => 'Select all';

  @override
  String get historyDuplicated => 'Transaction duplicated';

  @override
  String get bulkPickCategory => 'Choose a category';

  @override
  String get bulkTagHint => 'Tag name';

  @override
  String get bulkRecategorize => 'Recategorize';

  @override
  String get bulkAddTag => 'Add tag';

  @override
  String get bulkDelete => 'Delete';

  @override
  String bulkUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions updated',
      one: '1 transaction updated',
      zero: 'No matching transaction',
    );
    return '$_temp0';
  }

  @override
  String bulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions deleted',
      one: '1 transaction deleted',
    );
    return '$_temp0';
  }

  @override
  String get channelDigestName => 'Weekly summary';

  @override
  String get channelDigestDescription => 'A weekly recap of what you spent.';

  @override
  String get channelRemindersName => 'Bill reminders';

  @override
  String get channelRemindersDescription => 'Planned expenses falling due.';

  @override
  String get channelBudgetsName => 'Budget alerts';

  @override
  String get channelBudgetsDescription =>
      'Categories approaching or over their cap.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get remindersEnable => 'Bill reminders';

  @override
  String get remindersHint =>
      'A notification on the morning a planned expense is due.';

  @override
  String get budgetAlertsEnable => 'Budget alerts';

  @override
  String get budgetAlertsHint =>
      'A notification when a category reaches 80% and 100% of its cap.';

  @override
  String get reminderTitle => 'Due today';

  @override
  String reminderBody(String amount) {
    return '$amount is planned for today.';
  }

  @override
  String reminderBodyWithCategory(String category, String amount) {
    return '$category: $amount is planned for today.';
  }

  @override
  String budgetAlertNearTitle(String category) {
    return '$category is nearly spent';
  }

  @override
  String budgetAlertNearBody(String spent, String cap, String remaining) {
    return '$spent of $cap used — $remaining left this month.';
  }

  @override
  String budgetAlertOverTitle(String category) {
    return '$category is over budget';
  }

  @override
  String budgetAlertOverBody(String spent, String cap, String overspend) {
    return '$spent of $cap used — $overspend over.';
  }

  @override
  String get settingsBackups => 'Backups';

  @override
  String get backupNow => 'Back up now';

  @override
  String backupLastAt(String date) {
    return 'Last backup $date';
  }

  @override
  String get backupNever => 'No backup yet';

  @override
  String get backupDone => 'Backup saved';

  @override
  String get backupEmpty => 'Nothing to back up yet.';

  @override
  String get backupFailed => 'Could not write the backup.';

  @override
  String get backupShare => 'Share latest backup';

  @override
  String get backupRestore => 'Restore from a backup';

  @override
  String get backupRestoreTitle => 'Restore this backup?';

  @override
  String get backupRestoreBody =>
      'Everything in the backup replaces what is on this device, then syncs to your account. Anything recorded since the backup was taken is lost.';

  @override
  String get backupRestoreConfirm => 'Restore';

  @override
  String backupRestoreDone(int count) {
    return 'Restored $count records';
  }

  @override
  String get backupRestoreInvalid => 'That file is not a Masrouf backup.';

  @override
  String get backupAuto => 'Automatic weekly backup';

  @override
  String get backupAutoHint => 'Keeps the last four backups on this device.';

  @override
  String budgetAlertSpentTitle(String category) {
    return '$category is fully spent';
  }

  @override
  String budgetAlertSpentBody(String cap) {
    return 'All $cap is used. That is the whole budget for this month.';
  }

  @override
  String get analyticsShowLess => 'Show less';
}
