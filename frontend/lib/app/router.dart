import 'package:go_router/go_router.dart';

import '../features/screens.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/regions', builder: (_, __) => const RegionsScreen()),
      GoRoute(path: '/bases', builder: (_, __) => const BasesScreen()),
      GoRoute(path: '/units', builder: (_, __) => const UnitsScreen()),
      GoRoute(path: '/conversations', builder: (_, __) => const ConversationsScreen()),
      GoRoute(path: '/briefs', builder: (_, __) => const BriefsScreen()),
      GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
      GoRoute(path: '/maps', builder: (_, __) => const MapsScreen()),
      GoRoute(path: '/performance', builder: (_, __) => const PerformanceScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const PlaceholderScreen(title: 'Admin')),
      GoRoute(path: '/settings', builder: (_, __) => const PlaceholderScreen(title: 'Settings')),
    ],
  );
}
