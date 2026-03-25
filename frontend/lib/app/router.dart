import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'navigation_shell.dart';
import '../features/bases_screen.dart';
import '../features/briefs_screen.dart';
import '../features/dashboard_screen.dart';
import '../features/resources_screen.dart';
import '../features/screens.dart';
import '../core/user_state.dart';

// ── Auth redirect notifier ─────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<UserProfile?>(userProfileProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final user = _ref.read(userProfileProvider);
    final isLoggedIn = user != null;
    final isOnLogin = state.matchedLocation == '/login';

    if (!isLoggedIn && !isOnLogin) return '/login';
    if (isLoggedIn && isOnLogin) return '/dashboard';
    return null;
  }
}

// ── Router provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            NavigationShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/briefs', builder: (_, __) => const BriefsScreen()),
          GoRoute(path: '/bases', builder: (_, __) => const BasesScreen()),
          GoRoute(path: '/resources', builder: (_, __) => const ResourcesScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
