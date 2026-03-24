import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/firebase_state.dart';
import 'google_cloud_sign_in.dart' as gcp;

final api = ApiService();

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
  String? _token;

  Future<void> signInWithGoogleCloud() async {
    final user = await gcp.signInWithGoogleCloud();
    if (user == null) {
      throw StateError('Sign-in cancelled');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('No Firebase ID token');
    }
    final resp = await _dio.post('/auth/firebase', data: {'id_token': idToken});
    _token = resp.data['access_token'] as String?;
    if (_token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  Future<void> mockLogin() async {
    final resp = await _dio.post('/auth/mock-login', data: {
      'email': 'agent@example.com',
      'first_name': 'Field',
      'last_name': 'Agent',
      'role': 'admin',
    });
    _token = resp.data['access_token'] as String?;
    if (_token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  Future<List<dynamic>> getList(String path) async {
    final resp = await _dio.get(path);
    return (resp.data as List<dynamic>);
  }

  Future<void> post(String path, Map<String, dynamic> payload) async {
    await _dio.post(path, data: payload);
  }

  Future<Map<String, dynamic>> getReport(String path) async {
    final resp = await _dio.get(path);
    return Map<String, dynamic>.from(resp.data as Map);
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Agent Tracker v2.0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Field Sales Operations and CRM'),
                  const SizedBox(height: 20),
                  if (firebaseAppReady) ...[
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await api.signInWithGoogleCloud();
                          if (context.mounted) context.go('/dashboard');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Google Cloud sign-in failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Sign in with Google (Cloud)'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: () async {
                      await api.mockLogin();
                      if (context.mounted) context.go('/dashboard');
                    },
                    child: const Text('Sign in (Mock / dev)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Regions', '/regions'),
      ('Bases', '/bases'),
      ('Reserve Units', '/units'),
      ('Conversations', '/conversations'),
      ('Briefs', '/briefs'),
      ('Calendar', '/calendar'),
      ('Map/Nearby', '/maps'),
      ('Performance', '/performance'),
      ('Reports', '/reports'),
      ('Admin', '/admin'),
      ('Settings', '/settings'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        childAspectRatio: 3,
        children: [
          for (final item in items)
            Card(
              child: InkWell(
                onTap: () => context.go(item.$2),
                child: Center(child: Text(item.$1)),
              ),
            ),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title screen')),
    );
  }
}

class RegionsScreen extends StatefulWidget {
  const RegionsScreen({super.key});
  @override
  State<RegionsScreen> createState() => _RegionsScreenState();
}

class _RegionsScreenState extends State<RegionsScreen> {
  late Future<List<dynamic>> future = api.getList('/regions');
  final nameCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CrudScaffold(
      title: 'Regions',
      onAdd: () async {
        await api.post('/regions', {'name': nameCtrl.text, 'notes': ''});
        nameCtrl.clear();
        setState(() => future = api.getList('/regions'));
      },
      inputHint: 'Region name',
      inputController: nameCtrl,
      future: future,
      itemBuilder: (item) => ListTile(title: Text(item['name'] ?? ''), subtitle: Text(item['id'] ?? '')),
    );
  }
}

class BasesScreen extends StatefulWidget {
  const BasesScreen({super.key});
  @override
  State<BasesScreen> createState() => _BasesScreenState();
}

class _BasesScreenState extends State<BasesScreen> {
  late Future<List<dynamic>> future = api.getList('/bases');
  final nameCtrl = TextEditingController();
  final regionIdCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CrudScaffold(
      title: 'Bases',
      onAdd: () async {
        await api.post('/bases', {'name': nameCtrl.text, 'region_id': regionIdCtrl.text, 'address': ''});
        setState(() => future = api.getList('/bases'));
      },
      inputHint: 'Base name',
      inputController: nameCtrl,
      extra: TextField(controller: regionIdCtrl, decoration: const InputDecoration(labelText: 'Region ID')),
      future: future,
      itemBuilder: (item) => ListTile(
        title: Text(item['name'] ?? ''),
        subtitle: Text('region: ${item['region_id'] ?? ''}'),
      ),
    );
  }
}

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});
  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  late Future<List<dynamic>> future = api.getList('/units');
  final nameCtrl = TextEditingController();
  final baseIdCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CrudScaffold(
      title: 'Reserve Units',
      onAdd: () async {
        await api.post('/units', {'name': nameCtrl.text, 'base_id': baseIdCtrl.text, 'status': 'uncontacted'});
        setState(() => future = api.getList('/units'));
      },
      inputHint: 'Unit name',
      inputController: nameCtrl,
      extra: TextField(controller: baseIdCtrl, decoration: const InputDecoration(labelText: 'Base ID')),
      future: future,
      itemBuilder: (item) => ListTile(
        title: Text(item['name'] ?? ''),
        subtitle: Text('status: ${item['status'] ?? ''}'),
      ),
    );
  }
}

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});
  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<dynamic>> future = api.getList('/conversations');
  final unitIdCtrl = TextEditingController();
  final agentIdCtrl = TextEditingController();
  final summaryCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CrudScaffold(
      title: 'Conversation Log',
      onAdd: () async {
        await api.post('/conversations', {
          'reserve_unit_id': unitIdCtrl.text,
          'agent_id': agentIdCtrl.text,
          'contact_person': 'POC',
          'channel': 'phone',
          'summary': summaryCtrl.text,
        });
        setState(() => future = api.getList('/conversations'));
      },
      inputHint: 'Summary',
      inputController: summaryCtrl,
      extra: Column(
        children: [
          TextField(controller: unitIdCtrl, decoration: const InputDecoration(labelText: 'Reserve Unit ID')),
          const SizedBox(height: 8),
          TextField(controller: agentIdCtrl, decoration: const InputDecoration(labelText: 'Agent ID')),
        ],
      ),
      future: future,
      itemBuilder: (item) => ListTile(title: Text(item['summary'] ?? ''), subtitle: Text(item['channel'] ?? '')),
    );
  }
}

class BriefsScreen extends StatefulWidget {
  const BriefsScreen({super.key});
  @override
  State<BriefsScreen> createState() => _BriefsScreenState();
}

class _BriefsScreenState extends State<BriefsScreen> {
  late Future<List<dynamic>> future = api.getList('/briefs');
  final unitIdCtrl = TextEditingController();
  final baseIdCtrl = TextEditingController();
  final regionIdCtrl = TextEditingController();
  final agentIdCtrl = TextEditingController();
  final locationCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CrudScaffold(
      title: 'Brief Scheduling',
      onAdd: () async {
        await api.post('/briefs', {
          'reserve_unit_id': unitIdCtrl.text,
          'base_id': baseIdCtrl.text,
          'region_id': regionIdCtrl.text,
          'assigned_agent_id': agentIdCtrl.text,
          'scheduled_at': DateTime.now().toUtc().toIso8601String(),
          'location': locationCtrl.text,
        });
        setState(() => future = api.getList('/briefs'));
      },
      inputHint: 'Location',
      inputController: locationCtrl,
      extra: Column(
        children: [
          TextField(controller: unitIdCtrl, decoration: const InputDecoration(labelText: 'Unit ID')),
          const SizedBox(height: 8),
          TextField(controller: baseIdCtrl, decoration: const InputDecoration(labelText: 'Base ID')),
          const SizedBox(height: 8),
          TextField(controller: regionIdCtrl, decoration: const InputDecoration(labelText: 'Region ID')),
          const SizedBox(height: 8),
          TextField(controller: agentIdCtrl, decoration: const InputDecoration(labelText: 'Agent ID')),
        ],
      ),
      future: future,
      itemBuilder: (item) => ListTile(
        title: Text(item['location'] ?? ''),
        subtitle: Text('status: ${item['status'] ?? ''}'),
      ),
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: 'Calendar (events + training weekends)');
}

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});
  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  late Future<Map<String, dynamic>> report = api.getReport('/maps/weekend-opportunities');
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map / Nearby Bases')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: report,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final ops = (snapshot.data!['opportunities'] as List<dynamic>? ?? []);
          return ListView(
            children: [
              for (final op in ops)
                ListTile(
                  title: Text('${op['base_a']} ↔ ${op['base_b']}'),
                  subtitle: Text('${op['miles']} miles'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: 'Agent Performance');
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<dynamic>> units = api.getList('/units');
  late Future<List<dynamic>> briefs = api.getList('/briefs');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: units,
                builder: (context, snap) => SummaryCard(
                  title: 'Units',
                  value: '${snap.data?.length ?? 0}',
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: briefs,
                builder: (context, snap) => SummaryCard(
                  title: 'Briefs',
                  value: '${snap.data?.length ?? 0}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text(title), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 24))],
        ),
      ),
    );
  }
}

class CrudScaffold extends StatelessWidget {
  const CrudScaffold({
    super.key,
    required this.title,
    required this.onAdd,
    required this.inputHint,
    required this.inputController,
    required this.future,
    required this.itemBuilder,
    this.extra,
  });
  final String title;
  final Future<void> Function() onAdd;
  final String inputHint;
  final TextEditingController inputController;
  final Future<List<dynamic>> future;
  final Widget Function(dynamic item) itemBuilder;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(controller: inputController, decoration: InputDecoration(labelText: inputHint)),
                if (extra != null) ...[const SizedBox(height: 8), extra!],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(onPressed: onAdd, child: const Text('Quick Add')),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text('No records'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) => itemBuilder(list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
