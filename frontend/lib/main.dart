import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/firebase_state.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseAppReady = true;
  } catch (e, st) {
    debugPrint('Firebase init failed (use flutterfire configure or valid firebase_options): $e\n$st');
  }
  runApp(const ProviderScope(child: AgentTrackerApp()));
}

class AgentTrackerApp extends StatelessWidget {
  const AgentTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      title: 'Agent Tracker',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
