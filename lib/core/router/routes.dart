/// Route paths and names, in one place.
///
/// Constants rather than string literals at call sites: a typo in a navigation
/// string is a runtime failure that no test necessarily catches, whereas a typo
/// here does not compile.
abstract final class Routes {
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String checkEmail = '/check-email';
  static const String forgotPassword = '/forgot-password';

  static const String dashboard = '/';
  static const String history = '/history';
  static const String analytics = '/analytics';
  static const String settings = '/settings';

  static const String add = '/add';
  static const String editTransaction = '/edit';
  static const String accounts = '/accounts';
  static const String categories = '/categories';
  static const String recurring = '/recurring';
  static const String budgets = '/budgets';
  static const String planned = '/planned';
  static const String forecast = '/forecast';
  static const String goals = '/goals';
  static const String calendar = '/calendar';
  static const String exchangeRates = '/settings/rates';

  /// Screens reachable while signed out. Anything else redirects to sign-in.
  static const Set<String> unauthenticated = <String>{
    signIn,
    signUp,
    checkEmail,
    forgotPassword,
  };

  static bool isUnauthenticated(String location) =>
      unauthenticated.any((route) => location.startsWith(route));
}
