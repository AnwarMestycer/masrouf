// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Masrouf';

  @override
  String get seedSalary => 'Salaire';

  @override
  String get seedFreelance => 'Freelance';

  @override
  String get seedReimbursement => 'Remboursement';

  @override
  String get seedGift => 'Cadeau';

  @override
  String get seedOther => 'Autre';

  @override
  String get seedGroceries => 'Courses';

  @override
  String get seedEatingOut => 'Restaurant';

  @override
  String get seedTransport => 'Transport';

  @override
  String get seedRent => 'Loyer';

  @override
  String get seedUtilities => 'Factures';

  @override
  String get seedSubscriptions => 'Abonnements';

  @override
  String get seedHealth => 'Santé';

  @override
  String get seedFamily => 'Famille';

  @override
  String get seedShopping => 'Achats';

  @override
  String get seedGym => 'Sport';

  @override
  String get seedSavingsZakat => 'Épargne/Zakat';

  @override
  String get seedCash => 'Espèces';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionDone => 'Terminé';

  @override
  String get actionAdd => 'Ajouter';

  @override
  String get actionClose => 'Fermer';

  @override
  String get actionToday => 'Aujourd\'hui';

  @override
  String get actionYesterday => 'Hier';

  @override
  String get navHome => 'Accueil';

  @override
  String get navHistory => 'Historique';

  @override
  String get navAdd => 'Ajouter';

  @override
  String get navAnalytics => 'Analyses';

  @override
  String get navSettings => 'Réglages';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authSignUp => 'S\'inscrire';

  @override
  String get authSignOut => 'Se déconnecter';

  @override
  String get authSignOutTitle => 'Se déconnecter ?';

  @override
  String get authSignOutBody =>
      'Vos données restent sur le serveur. Cet appareil sera vidé puis retélééchargé à la prochaine connexion.';

  @override
  String authSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modifications n\'ont pas encore atteint le serveur et seront perdues.',
      one: '1 modification n\'a pas encore atteint le serveur et sera perdue.',
    );
    return '$_temp0';
  }

  @override
  String get authSignOutSyncFirst => 'Synchroniser d\'abord';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authResetPassword => 'Réinitialiser le mot de passe';

  @override
  String get authSendResetLink => 'Envoyer le lien';

  @override
  String get authNoAccount => 'Pas encore de compte ? S\'inscrire';

  @override
  String get authHaveAccount => 'Vous avez déjà un compte ? Se connecter';

  @override
  String get authWelcomeBack => 'Content de vous revoir';

  @override
  String get authCreateAccount => 'Créez votre compte';

  @override
  String get authResetIntro =>
      'Saisissez votre e-mail et nous vous enverrons un lien de réinitialisation.';

  @override
  String get authResetSent =>
      'Lien envoyé. Consultez votre boîte de réception.';

  @override
  String get authCheckEmailTitle => 'Confirmez votre e-mail';

  @override
  String authCheckEmailBody(String email) {
    return 'Nous avons envoyé un lien de confirmation à $email. Ouvrez-le pour activer votre compte.';
  }

  @override
  String get authResendEmail => 'Renvoyer l\'e-mail';

  @override
  String get authBackToSignIn => 'Retour à la connexion';

  @override
  String get validationEmailRequired => 'L\'e-mail est obligatoire';

  @override
  String get validationEmailInvalid => 'Saisissez une adresse e-mail valide';

  @override
  String get validationPasswordRequired => 'Le mot de passe est obligatoire';

  @override
  String get validationPasswordTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères';

  @override
  String get validationPasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get validationAmountRequired => 'Saisissez un montant';

  @override
  String get validationAmountPositive =>
      'Le montant doit être supérieur à zéro';

  @override
  String get validationNameRequired => 'Le nom est obligatoire';

  @override
  String get validationCategoryRequired => 'Choisissez une catégorie';

  @override
  String get validationAccountRequired => 'Choisissez un compte';

  @override
  String get validationRatePositive => 'Le taux doit être supérieur à zéro';

  @override
  String get errorInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get errorEmailAlreadyRegistered => 'Cet e-mail est déjà enregistré.';

  @override
  String get errorWeakPassword =>
      'Mot de passe trop faible. Utilisez au moins 8 caractères.';

  @override
  String get errorEmailNotConfirmed =>
      'Confirmez votre e-mail avant de vous connecter.';

  @override
  String get errorNetwork =>
      'Pas de connexion. Vérifiez votre réseau et réessayez.';

  @override
  String get errorRateLimited => 'Trop de tentatives. Patientez un instant.';

  @override
  String get errorUnknown => 'Une erreur est survenue. Réessayez.';

  @override
  String get errorSessionExpired => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get txnIncome => 'Revenu';

  @override
  String get txnExpense => 'Dépense';

  @override
  String get txnTransfer => 'Virement';

  @override
  String get txnAmount => 'Montant';

  @override
  String get txnNote => 'Note';

  @override
  String get txnNoteHint => 'Ajouter une note (facultatif)';

  @override
  String get txnDate => 'Date';

  @override
  String get txnAccount => 'Compte';

  @override
  String txnRateMissing(String currency) {
    return 'Aucun taux de change défini pour $currency';
  }

  @override
  String get txnRateMissingHint =>
      'Définissez-le dans Réglages → Taux de change, pour que ce montant soit compté correctement.';

  @override
  String get txnCategory => 'Catégorie';

  @override
  String get txnTags => 'Étiquettes';

  @override
  String get txnTagsHint => 'Ajouter une étiquette (facultatif)';

  @override
  String get txnSaved => 'Enregistré';

  @override
  String get txnDeleted => 'Supprimé';

  @override
  String get txnUndo => 'Annuler';

  @override
  String get txnRecent => 'Récent';

  @override
  String get txnAll => 'Tout';

  @override
  String get txnEmpty => 'Aucune transaction';

  @override
  String get txnEmptyHint => 'Touchez + pour enregistrer la première.';

  @override
  String get accountsTitle => 'Comptes';

  @override
  String get accountsDeleteWarning =>
      'Supprimer ce compte ? Ses transactions restent dans l\'historique mais ne compteront plus dans aucun solde.';

  @override
  String get accountsAdd => 'Nouveau compte';

  @override
  String get accountsName => 'Nom du compte';

  @override
  String get accountsOpeningBalance => 'Solde initial';

  @override
  String get accountsArchive => 'Archiver';

  @override
  String get accountsArchived => 'Archivé';

  @override
  String get accountTypeCash => 'Espèces';

  @override
  String get accountTypeBank => 'Banque';

  @override
  String get accountTypeSavings => 'Épargne';

  @override
  String get accountTypeForeign => 'Devise';

  @override
  String get accountsTotalBalance => 'Solde total';

  @override
  String get categoriesTitle => 'Catégories';

  @override
  String get categoriesAdd => 'Nouvelle catégorie';

  @override
  String get categoriesName => 'Nom de la catégorie';

  @override
  String get categoriesIcon => 'Icône';

  @override
  String get categoriesColor => 'Couleur';

  @override
  String get categoriesReorderHint => 'Glissez pour réordonner';

  @override
  String get categoriesKindIncome => 'Catégories de revenus';

  @override
  String get categoriesKindExpense => 'Catégories de dépenses';

  @override
  String get categoriesDeleteWarning =>
      'Les transactions de cette catégorie gardent leur historique mais perdent son libellé.';

  @override
  String get dashboardThisMonth => 'Ce mois-ci';

  @override
  String get dashboardIn => 'Entrées';

  @override
  String get dashboardOut => 'Sorties';

  @override
  String get dashboardNet => 'Net';

  @override
  String get dashboardSafeToSpend => 'Disponible';

  @override
  String dashboardSafeToSpendHint(String date) {
    return 'Solde moins les factures connues avant le $date';
  }

  @override
  String get dashboardUpcomingBills => 'Factures à venir';

  @override
  String get dashboardNoUpcoming => 'Rien de prévu avant la prochaine paie.';

  @override
  String get analyticsTitle => 'Analyses';

  @override
  String get analyticsByCategory => 'Dépenses par catégorie';

  @override
  String get analyticsIncomeByCategory => 'Revenus par catégorie';

  @override
  String analyticsBurnRate(String percent) {
    return '$percent des revenus dépensés';
  }

  @override
  String get analyticsBurnRateNoIncome => 'Aucun revenu enregistré ce mois-ci';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetsEmpty => 'Aucun budget';

  @override
  String get budgetsEmptyHint =>
      'Définissez un plafond mensuel sur une catégorie pour suivre vos dépenses.';

  @override
  String get budgetCap => 'Plafond mensuel';

  @override
  String get budgetOptional => 'Facultatif';

  @override
  String get budgetNone => 'Sans plafond';

  @override
  String budgetRemaining(String amount) {
    return '$amount restants';
  }

  @override
  String budgetOver(String amount) {
    return '$amount de dépassement';
  }

  @override
  String budgetSpentOfCap(String spent, String cap) {
    return '$spent sur $cap';
  }

  @override
  String get budgetRemoveConfirm =>
      'Supprimer ce budget ? Rien d\'autre ne change.';

  @override
  String get plannedTitle => 'Prévu';

  @override
  String get plannedAdd => 'Nouvelle dépense prévue';

  @override
  String get plannedEmpty => 'Rien de prévu';

  @override
  String get plannedEmptyHint =>
      'Planifiez une dépense future : elle est mise de côté du « reste à dépenser », sans quitter votre solde.';

  @override
  String plannedReserved(String amount) {
    return '$amount mis de côté';
  }

  @override
  String get plannedDueTitle => 'Cela a-t-il eu lieu ?';

  @override
  String plannedDueOn(String date) {
    return 'Prévu le $date';
  }

  @override
  String get plannedLogIt => 'Enregistrer';

  @override
  String get plannedSkip => 'Ignorer';

  @override
  String get plannedWhen => 'Quand';

  @override
  String get plannedNotCounted =>
      'Non compté dans votre solde tant que vous ne l’enregistrez pas';

  @override
  String get plannedRemoveConfirm =>
      'Supprimer ce plan ? Rien d’autre ne change.';

  @override
  String get forecastTitle => 'Mois à venir';

  @override
  String forecastSavings(String amount) {
    return 'Environ $amount économisés';
  }

  @override
  String forecastShortfall(String amount) {
    return 'Environ $amount manquants';
  }

  @override
  String get forecastTypical => 'Habituel';

  @override
  String get forecastCommitted => 'Factures';

  @override
  String get forecastPlanned => 'Prévu';

  @override
  String get forecastProvisional =>
      'Basé sur moins de 3 mois d’historique — à prendre comme indication.';

  @override
  String get forecastExplains =>
      'Vos dépenses habituelles, plus les factures connues, plus ce que vous avez prévu.';

  @override
  String get goalsTitle => 'Objectifs d’épargne';

  @override
  String get goalsAdd => 'Nouvel objectif';

  @override
  String get goalsEmpty => 'Aucun objectif';

  @override
  String get goalsEmptyHint =>
      'Définissez un objectif et le compte qui le porte : la progression suit le solde réel de ce compte.';

  @override
  String get goalsTarget => 'Objectif';

  @override
  String goalsBy(String date) {
    return 'Pour le $date';
  }

  @override
  String goalsPerMonth(String amount) {
    return '$amount par mois nécessaires';
  }

  @override
  String get goalsReached => 'Atteint';

  @override
  String get goalsOnTrack => 'En bonne voie';

  @override
  String get goalsBehind =>
      'En retard — vos prévisions épargnent moins que nécessaire';

  @override
  String get goalsAccount => 'Détenu sur';

  @override
  String get goalsRemoveConfirm =>
      'Supprimer cet objectif ? Le compte et son solde ne changent pas.';

  @override
  String get calendarTitle => 'Calendrier de trésorerie';

  @override
  String get calendarEmpty => 'Rien de prévu ce mois-ci';

  @override
  String calendarDayTotal(String amount) {
    return '$amount attendus';
  }

  @override
  String get digestTitle => 'Résumé hebdomadaire';

  @override
  String get digestEnable => 'Résumé hebdomadaire des dépenses';

  @override
  String get digestHint =>
      'Une notification chaque dimanche soir comparant cette semaine à la précédente.';

  @override
  String digestBodyUp(String amount, String percent) {
    return 'Vous avez dépensé $amount cette semaine, $percent de plus que la semaine dernière.';
  }

  @override
  String digestBodyDown(String amount, String percent) {
    return 'Vous avez dépensé $amount cette semaine, $percent de moins que la semaine dernière.';
  }

  @override
  String digestBodyFlat(String amount) {
    return 'Vous avez dépensé $amount cette semaine.';
  }

  @override
  String get digestPermission =>
      'Les notifications sont désactivées pour Masrouf. Activez-les dans les réglages système.';

  @override
  String get analyticsCashflow => 'Flux de trésorerie';

  @override
  String get analyticsIncomeBreakdown => 'Répartition des revenus';

  @override
  String get analyticsPreviousMonth => 'Mois précédent';

  @override
  String get analyticsCurrentMonth => 'Mois en cours';

  @override
  String get analyticsNoData => 'Pas encore assez de données';

  @override
  String get analyticsDaily => 'Par jour';

  @override
  String get analyticsWeekly => 'Par semaine';

  @override
  String analyticsVsPrevious(String percent) {
    return '$percent vs le mois dernier';
  }

  @override
  String get historyTitle => 'Historique';

  @override
  String get historySearchHint => 'Rechercher notes, étiquettes, montants';

  @override
  String get historyFilter => 'Filtrer';

  @override
  String get historyFilterAll => 'Tout';

  @override
  String get historyNoResults => 'Aucune transaction ne correspond aux filtres';

  @override
  String get historyClearFilters => 'Effacer les filtres';

  @override
  String get recurringTitle => 'Récurrent';

  @override
  String get recurringAdd => 'Nouvelle règle récurrente';

  @override
  String get recurringDeleteConfirm =>
      'Supprimer cette règle ? Les transactions déjà créées sont conservées.';

  @override
  String get recurringCadenceMonthly => 'Mensuel';

  @override
  String get recurringCadenceWeekly => 'Hebdomadaire';

  @override
  String recurringNextRun(String date) {
    return 'Prochaine le $date';
  }

  @override
  String get recurringActive => 'Active';

  @override
  String recurringGenerated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions générées',
      one: '1 transaction générée',
      zero: 'Aucune transaction générée',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsBaseCurrency => 'Devise de base';

  @override
  String get settingsExchangeRates => 'Taux de change';

  @override
  String settingsRateFor(String currency) {
    return '1 $currency =';
  }

  @override
  String get settingsPayday => 'Jour de paie';

  @override
  String settingsPaydayDay(int day) {
    return 'Le $day du mois';
  }

  @override
  String get settingsExportCsv => 'Exporter en CSV';

  @override
  String settingsExportDone(int count) {
    return '$count transactions exportées';
  }

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsSyncStatus => 'Synchronisation';

  @override
  String get syncIdle => 'À jour';

  @override
  String get syncSyncing => 'Synchronisation…';

  @override
  String get syncOffline =>
      'Hors ligne — modifications enregistrées localement';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: '1 modification en attente',
    );
    return '$_temp0';
  }

  @override
  String get syncFailed => 'Échec de la synchronisation — nouvelle tentative';

  @override
  String historySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnées',
      one: '1 sélectionnée',
    );
    return '$_temp0';
  }

  @override
  String get historySelectAll => 'Tout sélectionner';

  @override
  String get historyDuplicated => 'Transaction dupliquée';

  @override
  String get bulkPickCategory => 'Choisir une catégorie';

  @override
  String get bulkTagHint => 'Nom du tag';

  @override
  String get bulkRecategorize => 'Reclasser';

  @override
  String get bulkAddTag => 'Ajouter un tag';

  @override
  String get bulkDelete => 'Supprimer';

  @override
  String bulkUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions mises à jour',
      one: '1 transaction mise à jour',
      zero: 'Aucune transaction correspondante',
    );
    return '$_temp0';
  }

  @override
  String bulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions supprimées',
      one: '1 transaction supprimée',
    );
    return '$_temp0';
  }

  @override
  String get channelDigestName => 'Résumé hebdomadaire';

  @override
  String get channelDigestDescription =>
      'Un récapitulatif hebdomadaire de vos dépenses.';

  @override
  String get channelRemindersName => 'Rappels de factures';

  @override
  String get channelRemindersDescription =>
      'Dépenses prévues arrivant à échéance.';

  @override
  String get channelBudgetsName => 'Alertes de budget';

  @override
  String get channelBudgetsDescription =>
      'Catégories proches de leur plafond ou au-delà.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get remindersEnable => 'Rappels de factures';

  @override
  String get remindersHint =>
      'Une notification le matin de l’échéance d’une dépense prévue.';

  @override
  String get budgetAlertsEnable => 'Alertes de budget';

  @override
  String get budgetAlertsHint =>
      'Une notification quand une catégorie atteint 80 % puis 100 % de son plafond.';

  @override
  String get reminderTitle => 'À payer aujourd’hui';

  @override
  String reminderBody(String amount) {
    return '$amount est prévu pour aujourd’hui.';
  }

  @override
  String reminderBodyWithCategory(String category, String amount) {
    return '$category : $amount est prévu pour aujourd’hui.';
  }

  @override
  String budgetAlertNearTitle(String category) {
    return '$category est presque épuisé';
  }

  @override
  String budgetAlertNearBody(String spent, String cap, String remaining) {
    return '$spent sur $cap utilisés — il reste $remaining ce mois-ci.';
  }

  @override
  String budgetAlertOverTitle(String category) {
    return '$category dépasse le budget';
  }

  @override
  String budgetAlertOverBody(String spent, String cap, String overspend) {
    return '$spent sur $cap utilisés — $overspend de dépassement.';
  }

  @override
  String get settingsBackups => 'Sauvegardes';

  @override
  String get backupNow => 'Sauvegarder maintenant';

  @override
  String backupLastAt(String date) {
    return 'Dernière sauvegarde $date';
  }

  @override
  String get backupNever => 'Aucune sauvegarde';

  @override
  String get backupDone => 'Sauvegarde enregistrée';

  @override
  String get backupEmpty => 'Rien à sauvegarder pour le moment.';

  @override
  String get backupFailed => 'Impossible d’écrire la sauvegarde.';

  @override
  String get backupShare => 'Partager la dernière sauvegarde';

  @override
  String get backupRestore => 'Restaurer une sauvegarde';

  @override
  String get backupRestoreTitle => 'Restaurer cette sauvegarde ?';

  @override
  String get backupRestoreBody =>
      'Le contenu de la sauvegarde remplace ce qui est sur cet appareil, puis est synchronisé avec votre compte. Tout ce qui a été saisi depuis la sauvegarde sera perdu.';

  @override
  String get backupRestoreConfirm => 'Restaurer';

  @override
  String backupRestoreDone(int count) {
    return '$count enregistrements restaurés';
  }

  @override
  String get backupRestoreInvalid =>
      'Ce fichier n’est pas une sauvegarde Masrouf.';

  @override
  String get backupAuto => 'Sauvegarde hebdomadaire automatique';

  @override
  String get backupAutoHint =>
      'Conserve les quatre dernières sauvegardes sur cet appareil.';

  @override
  String budgetAlertSpentTitle(String category) {
    return '$category est entièrement dépensé';
  }

  @override
  String budgetAlertSpentBody(String cap) {
    return 'Les $cap sont utilisés. C’est tout le budget du mois.';
  }

  @override
  String get analyticsShowLess => 'Afficher moins';

  @override
  String get rangeThisMonth => 'Ce mois-ci';

  @override
  String get rangeLastMonth => 'Le mois dernier';

  @override
  String get rangeLast30Days => '30 derniers jours';

  @override
  String get rangeLast3Months => '3 derniers mois';

  @override
  String get rangeLast6Months => '6 derniers mois';

  @override
  String get rangeYearToDate => 'Depuis janvier';

  @override
  String get rangePayPeriod => 'Période de paie';

  @override
  String get rangeCustom => 'Personnalisé';

  @override
  String get rangePickDates => 'Choisir les dates';

  @override
  String get analyticsEveryday => 'Courant';

  @override
  String analyticsPerDay(String amount) {
    return '$amount/jour';
  }

  @override
  String analyticsSetAside(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gros paiements mis à part',
      one: '1 gros paiement mis à part',
    );
    return '$_temp0';
  }

  @override
  String analyticsTypicalPurchase(String amount) {
    return 'Achat typique $amount';
  }

  @override
  String get analyticsTopMovers => 'Plus fortes variations';

  @override
  String analyticsRangeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String analyticsComparedTo(String days) {
    return 'vs $days précédents';
  }

  @override
  String get analyticsBurnRateNoIncomeRange => 'Aucun revenu sur cette période';
}
