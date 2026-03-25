import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import 'navigation_shell.dart';
import '../features/bases_screen.dart';
import '../features/briefs_screen.dart';
import '../features/screens.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            NavigationShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/bases', builder: (_, __) => const BasesScreen()),
          GoRoute(path: '/units', builder: (_, __) => const UnitsScreen()),
          GoRoute(path: '/conversations', builder: (_, __) => const ConversationsScreen()),
          GoRoute(path: '/briefs', builder: (_, __) => const BriefsScreen()),
          GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
          GoRoute(path: '/performance', builder: (_, __) => const PerformanceScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/admin', builder: (_, __) => const PlaceholderScreen(title: 'Admin')),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
}
