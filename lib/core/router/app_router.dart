import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/presentation/accounts/accounts_page.dart';
import 'package:masrouf/presentation/add/fast_add_page.dart';
import 'package:masrouf/presentation/analytics/analytics_page.dart';
import 'package:masrouf/presentation/auth/pages/check_email_page.dart';
import 'package:masrouf/presentation/auth/pages/forgot_password_page.dart';
import 'package:masrouf/presentation/auth/pages/sign_in_page.dart';
import 'package:masrouf/presentation/auth/pages/sign_up_page.dart';
import 'package:masrouf/presentation/budgets/budgets_page.dart';
import 'package:masrouf/presentation/categories/categories_page.dart';
import 'package:masrouf/presentation/calendar/calendar_page.dart';
import 'package:masrouf/presentation/forecast/forecast_page.dart';
import 'package:masrouf/presentation/goals/goals_page.dart';
import 'package:masrouf/presentation/planned/planned_page.dart';
import 'package:masrouf/presentation/dashboard/dashboard_page.dart';
import 'package:masrouf/presentation/history/history_page.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/settings/exchange_rates_page.dart';
import 'package:masrouf/presentation/settings/recurring_page.dart';
import 'package:masrouf/presentation/settings/settings_page.dart';
import 'package:masrouf/presentation/shell/app_shell.dart';

/// Bridges Riverpod's auth stream to go_router's `refreshListenable`.
///
/// go_router re-evaluates redirects when a [Listenable] fires. Driving that from
/// a `ref.listen` rather than `ref.watch` matters: watching would rebuild the
/// router itself on every auth event, throwing away the navigation stack.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AppUser?>(
      currentUserProvider,
      (previous, next) {
        // Only a change in *whether* someone is signed in can affect routing.
        // A token refresh emits a new user object with the same id and must not
        // disturb the stack.
        if ((previous == null) != (next == null)) notifyListeners();
      },
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    // The full-screen routes below declare this as their parentNavigatorKey so
    // they cover the bottom bar instead of nesting inside a tab. go_router
    // asserts that such a key belongs to the router's own navigator, so it has
    // to be handed over here as well as referenced there.
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      // Read, not watch: the redirect runs inside routing, and watching here
      // would create a dependency cycle with the router provider itself.
      final signedIn = ref.read(currentUserProvider) != null;
      final atAuthScreen = Routes.isUnauthenticated(state.matchedLocation);

      if (!signedIn && !atAuthScreen) return Routes.signIn;
      if (signedIn && atAuthScreen) return Routes.dashboard;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: Routes.checkEmail,
        builder: (context, state) =>
            CheckEmailPage(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // The four tabs share one shell so the bottom bar and its state survive
      // tab switches instead of being rebuilt per route.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.dashboard,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.history,
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.analytics,
                builder: (context, state) => const AnalyticsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'rates',
                    builder: (context, state) => const ExchangeRatesPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // The add flow is a full-screen route rather than a sheet: it owns the
      // keyboard-sized numpad, and a route gives it a proper back gesture and
      // its own entry in the system back stack.
      GoRoute(
        path: Routes.add,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => const MaterialPage<void>(
          fullscreenDialog: true,
          child: FastAddPage(),
        ),
      ),
      GoRoute(
        path: '${Routes.editTransaction}/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage<void>(
          fullscreenDialog: true,
          child: FastAddPage(editingId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: Routes.accounts,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountsPage(),
      ),
      GoRoute(
        path: Routes.categories,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: Routes.recurring,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecurringPage(),
      ),
      GoRoute(
        path: Routes.budgets,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BudgetsPage(),
      ),
      GoRoute(
        path: Routes.planned,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlannedPage(),
      ),
      GoRoute(
        path: Routes.forecast,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForecastPage(),
      ),
      GoRoute(
        path: Routes.goals,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GoalsPage(),
      ),
      GoRoute(
        path: Routes.calendar,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CalendarPage(),
      ),
    ],
  );
});

final _rootNavigatorKey = GlobalKey<NavigatorState>();
