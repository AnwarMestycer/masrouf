// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مصروف';

  @override
  String get seedSalary => 'راتب';

  @override
  String get seedFreelance => 'عمل حر';

  @override
  String get seedReimbursement => 'استرجاع';

  @override
  String get seedGift => 'هدية';

  @override
  String get seedOther => 'أخرى';

  @override
  String get seedGroceries => 'مشتريات';

  @override
  String get seedEatingOut => 'مطاعم';

  @override
  String get seedTransport => 'نقل';

  @override
  String get seedRent => 'كراء';

  @override
  String get seedUtilities => 'فواتير';

  @override
  String get seedSubscriptions => 'اشتراكات';

  @override
  String get seedHealth => 'صحة';

  @override
  String get seedFamily => 'عائلة';

  @override
  String get seedShopping => 'تسوق';

  @override
  String get seedGym => 'رياضة';

  @override
  String get seedSavingsZakat => 'ادخار/زكاة';

  @override
  String get seedCash => 'نقدًا';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionDone => 'تم';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionToday => 'اليوم';

  @override
  String get actionYesterday => 'أمس';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navHistory => 'السجل';

  @override
  String get navAdd => 'إضافة';

  @override
  String get navAnalytics => 'التحليلات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authSignUp => 'إنشاء حساب';

  @override
  String get authSignOut => 'تسجيل الخروج';

  @override
  String get authSignOutTitle => 'تسجيل الخروج؟';

  @override
  String get authSignOutBody =>
      'تبقى بياناتك على الخادم. سيُمسح هذا الجهاز ويُعاد تنزيلها عند الدخول مجدّدًا.';

  @override
  String authSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير لم يصل إلى الخادم وسيُفقد.',
      many: '$count تغييرًا لم تصل إلى الخادم وستُفقد.',
      few: '$count تغييرات لم تصل إلى الخادم وستُفقد.',
      two: 'تغييران لم يصلا إلى الخادم وسيُفقدان.',
      one: 'تغيير واحد لم يصل إلى الخادم وسيُفقد.',
    );
    return '$_temp0';
  }

  @override
  String get authSignOutSyncFirst => 'مزامنة أولاً';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authResetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get authSendResetLink => 'إرسال الرابط';

  @override
  String get authNoAccount => 'ليس لديك حساب؟ أنشئ واحدًا';

  @override
  String get authHaveAccount => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get authWelcomeBack => 'أهلًا بعودتك';

  @override
  String get authCreateAccount => 'أنشئ حسابك';

  @override
  String get authResetIntro =>
      'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين.';

  @override
  String get authResetSent => 'تم إرسال الرابط. تحقق من بريدك.';

  @override
  String get authCheckEmailTitle => 'أكّد بريدك الإلكتروني';

  @override
  String authCheckEmailBody(String email) {
    return 'أرسلنا رابط تأكيد إلى $email. افتحه لتفعيل حسابك.';
  }

  @override
  String get authResendEmail => 'إعادة إرسال البريد';

  @override
  String get authBackToSignIn => 'العودة لتسجيل الدخول';

  @override
  String get validationEmailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get validationEmailInvalid => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get validationPasswordRequired => 'كلمة المرور مطلوبة';

  @override
  String get validationPasswordTooShort => 'يجب ألا تقل كلمة المرور عن 8 أحرف';

  @override
  String get validationPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get validationAmountRequired => 'أدخل المبلغ';

  @override
  String get validationAmountPositive => 'يجب أن يكون المبلغ أكبر من صفر';

  @override
  String get validationNameRequired => 'الاسم مطلوب';

  @override
  String get validationCategoryRequired => 'اختر فئة';

  @override
  String get validationAccountRequired => 'اختر حسابًا';

  @override
  String get validationRatePositive => 'يجب أن يكون سعر الصرف أكبر من صفر';

  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errorEmailAlreadyRegistered => 'هذا البريد مسجّل بالفعل.';

  @override
  String get errorWeakPassword => 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل.';

  @override
  String get errorEmailNotConfirmed =>
      'أكّد بريدك الإلكتروني قبل تسجيل الدخول.';

  @override
  String get errorNetwork => 'لا يوجد اتصال. تحقق من الشبكة وحاول مجددًا.';

  @override
  String get errorRateLimited => 'محاولات كثيرة. انتظر قليلًا ثم أعد المحاولة.';

  @override
  String get errorUnknown => 'حدث خطأ ما. حاول مجددًا.';

  @override
  String get errorSessionExpired => 'انتهت جلستك. سجّل الدخول من جديد.';

  @override
  String get txnIncome => 'دخل';

  @override
  String get txnExpense => 'مصروف';

  @override
  String get txnTransfer => 'تحويل';

  @override
  String get txnAmount => 'المبلغ';

  @override
  String get txnNote => 'ملاحظة';

  @override
  String get txnNoteHint => 'أضف ملاحظة (اختياري)';

  @override
  String get txnDate => 'التاريخ';

  @override
  String get txnAccount => 'الحساب';

  @override
  String txnRateMissing(String currency) {
    return 'لا يوجد سعر صرف مُعيّن لـ $currency';
  }

  @override
  String get txnRateMissingHint =>
      'حدّده من الإعدادات ← أسعار الصرف حتّى يُحتسب هذا المبلغ بشكل صحيح.';

  @override
  String get txnCategory => 'الفئة';

  @override
  String get txnTags => 'الوسوم';

  @override
  String get txnTagsHint => 'أضف وسمًا (اختياري)';

  @override
  String get txnSaved => 'تم الحفظ';

  @override
  String get txnDeleted => 'تم الحذف';

  @override
  String get txnUndo => 'تراجع';

  @override
  String get txnRecent => 'الأخيرة';

  @override
  String get txnAll => 'الكل';

  @override
  String get txnEmpty => 'لا توجد معاملات بعد';

  @override
  String get txnEmptyHint => 'اضغط + لتسجيل أول معاملة.';

  @override
  String get accountsTitle => 'الحسابات';

  @override
  String get accountsDeleteWarning =>
      'حذف هذا الحساب؟ ستبقى معاملاته في السجل، لكنها لن تُحتسب ضمن أي رصيد.';

  @override
  String get accountsAdd => 'حساب جديد';

  @override
  String get accountsName => 'اسم الحساب';

  @override
  String get accountsOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get accountsArchive => 'أرشفة';

  @override
  String get accountsArchived => 'مؤرشف';

  @override
  String get accountTypeCash => 'نقدًا';

  @override
  String get accountTypeBank => 'بنك';

  @override
  String get accountTypeSavings => 'ادخار';

  @override
  String get accountTypeForeign => 'عملة أجنبية';

  @override
  String get accountsTotalBalance => 'الرصيد الإجمالي';

  @override
  String get categoriesTitle => 'الفئات';

  @override
  String get categoriesAdd => 'فئة جديدة';

  @override
  String get categoriesName => 'اسم الفئة';

  @override
  String get categoriesIcon => 'الأيقونة';

  @override
  String get categoriesColor => 'اللون';

  @override
  String get categoriesReorderHint => 'اسحب لإعادة الترتيب';

  @override
  String get categoriesKindIncome => 'فئات الدخل';

  @override
  String get categoriesKindExpense => 'فئات المصروفات';

  @override
  String get categoriesDeleteWarning =>
      'ستحتفظ معاملات هذه الفئة بسجلها لكنها ستفقد التسمية.';

  @override
  String get dashboardThisMonth => 'هذا الشهر';

  @override
  String get dashboardIn => 'الداخل';

  @override
  String get dashboardOut => 'الخارج';

  @override
  String get dashboardNet => 'الصافي';

  @override
  String get dashboardSafeToSpend => 'المتاح للصرف';

  @override
  String dashboardSafeToSpendHint(String date) {
    return 'الرصيد ناقص الفواتير المعروفة قبل $date';
  }

  @override
  String get dashboardUpcomingBills => 'فواتير قادمة';

  @override
  String get dashboardNoUpcoming => 'لا شيء مجدول قبل الراتب القادم.';

  @override
  String get analyticsTitle => 'التحليلات';

  @override
  String get analyticsByCategory => 'المصروفات حسب الفئة';

  @override
  String get analyticsIncomeByCategory => 'الدخل حسب الفئة';

  @override
  String analyticsBurnRate(String percent) {
    return 'أُنفق $percent من الدخل';
  }

  @override
  String get analyticsBurnRateNoIncome => 'لا يوجد دخل مُسجّل هذا الشهر';

  @override
  String get budgetsTitle => 'الميزانيات';

  @override
  String get budgetsEmpty => 'لا توجد ميزانيات';

  @override
  String get budgetsEmptyHint => 'حدّد سقفًا شهريًا لفئة لمتابعة إنفاقك.';

  @override
  String get budgetCap => 'السقف الشهري';

  @override
  String get budgetOptional => 'اختياري';

  @override
  String get budgetNone => 'بلا سقف';

  @override
  String budgetRemaining(String amount) {
    return 'متبقٍّ $amount';
  }

  @override
  String budgetOver(String amount) {
    return 'تجاوز $amount';
  }

  @override
  String budgetSpentOfCap(String spent, String cap) {
    return '$spent من $cap';
  }

  @override
  String get budgetRemoveConfirm => 'إزالة هذه الميزانية؟ لن يتغير شيء آخر.';

  @override
  String get plannedTitle => 'مخطَّط';

  @override
  String get plannedAdd => 'مصروف مخطَّط جديد';

  @override
  String get plannedEmpty => 'لا شيء مخطَّط';

  @override
  String get plannedEmptyHint =>
      'خطِّط لمصروف مستقبلي فيُحجز من «المتاح للإنفاق» دون أن يغادر رصيدك.';

  @override
  String plannedReserved(String amount) {
    return 'محجوز $amount';
  }

  @override
  String get plannedDueTitle => 'هل تمَّ هذا؟';

  @override
  String plannedDueOn(String date) {
    return 'مستحق $date';
  }

  @override
  String get plannedLogIt => 'سجِّله';

  @override
  String get plannedSkip => 'تخطَّ';

  @override
  String get plannedWhen => 'متى';

  @override
  String get plannedNotCounted => 'لا يُحتسب في رصيدك حتى تُسجِّله';

  @override
  String get plannedRemoveConfirm => 'إزالة هذا المخطَّط؟ لن يتغيَّر شيء آخر.';

  @override
  String get forecastTitle => 'الأشهر القادمة';

  @override
  String forecastSavings(String amount) {
    return 'نحو $amount مدَّخرة';
  }

  @override
  String forecastShortfall(String amount) {
    return 'نحو $amount نقص';
  }

  @override
  String get forecastTypical => 'المعتاد';

  @override
  String get forecastCommitted => 'فواتير';

  @override
  String get forecastPlanned => 'مخطَّط';

  @override
  String get forecastProvisional =>
      'يستند إلى أقل من 3 أشهر من السجل — اعتبره تقديرًا تقريبيًا.';

  @override
  String get forecastExplains =>
      'إنفاقك المعتاد، زائد الفواتير المعروفة، زائد ما خطَّطت له.';

  @override
  String get goalsTitle => 'أهداف الادخار';

  @override
  String get goalsAdd => 'هدف جديد';

  @override
  String get goalsEmpty => 'لا توجد أهداف';

  @override
  String get goalsEmptyHint =>
      'حدِّد هدفًا والحساب الذي يحمله، فيتابع التقدُّم رصيد ذلك الحساب الفعلي.';

  @override
  String get goalsTarget => 'الهدف';

  @override
  String goalsBy(String date) {
    return 'بحلول $date';
  }

  @override
  String goalsPerMonth(String amount) {
    return '$amount شهريًا مطلوبة';
  }

  @override
  String get goalsReached => 'تحقَّق';

  @override
  String get goalsOnTrack => 'على المسار';

  @override
  String get goalsBehind => 'متأخر — تدَّخر توقُّعاتك أقل مما يتطلَّبه';

  @override
  String get goalsAccount => 'محفوظ في';

  @override
  String get goalsRemoveConfirm =>
      'إزالة هذا الهدف؟ لن يتأثَّر الحساب ولا رصيده.';

  @override
  String get calendarTitle => 'تقويم التدفُّق';

  @override
  String get calendarEmpty => 'لا شيء متوقَّع هذا الشهر';

  @override
  String calendarDayTotal(String amount) {
    return '$amount متوقَّعة';
  }

  @override
  String get digestTitle => 'الملخَّص الأسبوعي';

  @override
  String get digestEnable => 'ملخَّص الإنفاق الأسبوعي';

  @override
  String get digestHint => 'إشعار كل مساء أحد يقارن هذا الأسبوع بالسابق.';

  @override
  String digestBodyUp(String amount, String percent) {
    return 'أنفقت $amount هذا الأسبوع، أي $percent أكثر من الأسبوع الماضي.';
  }

  @override
  String digestBodyDown(String amount, String percent) {
    return 'أنفقت $amount هذا الأسبوع، أي $percent أقل من الأسبوع الماضي.';
  }

  @override
  String digestBodyFlat(String amount) {
    return 'أنفقت $amount هذا الأسبوع.';
  }

  @override
  String get digestPermission =>
      'الإشعارات معطَّلة لمصروف. فعِّلها من إعدادات النظام.';

  @override
  String get analyticsCashflow => 'التدفق النقدي';

  @override
  String get analyticsIncomeBreakdown => 'توزيع الدخل';

  @override
  String get analyticsPreviousMonth => 'الشهر الماضي';

  @override
  String get analyticsCurrentMonth => 'الشهر الحالي';

  @override
  String get analyticsNoData => 'لا توجد بيانات كافية بعد';

  @override
  String get analyticsDaily => 'يومي';

  @override
  String get analyticsWeekly => 'أسبوعي';

  @override
  String analyticsVsPrevious(String percent) {
    return '$percent مقارنة بالشهر الماضي';
  }

  @override
  String get historyTitle => 'السجل';

  @override
  String get historySearchHint => 'ابحث في الملاحظات والوسوم والمبالغ';

  @override
  String get historyFilter => 'تصفية';

  @override
  String get historyFilterAll => 'الكل';

  @override
  String get historyNoResults => 'لا توجد معاملات مطابقة للتصفية';

  @override
  String get historyClearFilters => 'مسح التصفية';

  @override
  String get recurringTitle => 'المتكررة';

  @override
  String get recurringAdd => 'قاعدة متكررة جديدة';

  @override
  String get recurringDeleteConfirm =>
      'حذف هذه القاعدة؟ تُحفظ المعاملات التي أنشأتها مسبقًا.';

  @override
  String get recurringCadenceMonthly => 'شهري';

  @override
  String get recurringCadenceWeekly => 'أسبوعي';

  @override
  String recurringNextRun(String date) {
    return 'التالية في $date';
  }

  @override
  String get recurringActive => 'مفعّلة';

  @override
  String recurringGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُنشئت $count معاملة',
      many: 'أُنشئت $count معاملة',
      few: 'أُنشئت $count معاملات',
      two: 'أُنشئت معاملتان',
      one: 'أُنشئت معاملة واحدة',
      zero: 'لم تُنشأ معاملات',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get settingsThemeSystem => 'النظام';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsBaseCurrency => 'العملة الأساسية';

  @override
  String get settingsExchangeRates => 'أسعار الصرف';

  @override
  String settingsRateFor(String currency) {
    return '1 $currency =';
  }

  @override
  String get settingsPayday => 'يوم الراتب';

  @override
  String settingsPaydayDay(int day) {
    return 'اليوم $day من الشهر';
  }

  @override
  String get settingsExportCsv => 'تصدير CSV';

  @override
  String settingsExportDone(int count) {
    return 'تم تصدير $count معاملة';
  }

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsSyncStatus => 'المزامنة';

  @override
  String get syncIdle => 'محدَّث';

  @override
  String get syncSyncing => 'جارٍ المزامنة…';

  @override
  String get syncOffline => 'غير متصل — التغييرات محفوظة محليًا';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير بالانتظار',
      many: '$count تغييرًا بالانتظار',
      few: '$count تغييرات بالانتظار',
      two: 'تغييران بالانتظار',
      one: 'تغيير واحد بالانتظار',
    );
    return '$_temp0';
  }

  @override
  String get syncFailed => 'فشلت المزامنة — ستُعاد المحاولة';
}
