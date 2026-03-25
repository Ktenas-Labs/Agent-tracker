import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/firebase_state.dart';
import '../core/user_state.dart';
import 'google_cloud_sign_in.dart' as gcp;

final api = ApiService();

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
  String? _token;

  Future<Map<String, dynamic>> signInWithGoogleCloud() async {
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
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> mockLogin() async {
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
    return Map<String, dynamic>.from(resp.data as Map);
  }

  void clearToken() {
    _token = null;
    _dio.options.headers.remove('Authorization');
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

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  void _applyUser(WidgetRef ref, Map<String, dynamic> data) {
    final u = data['user'] as Map<String, dynamic>? ?? {};
    ref.read(userProfileProvider.notifier).setUser(UserProfile(
          id: u['id'] as String? ?? '',
          email: u['email'] as String? ?? '',
          firstName: u['first_name'] as String? ?? 'Field',
          lastName: u['last_name'] as String? ?? 'Agent',
          role: u['role'] as String? ?? 'agent',
        ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          final data = await api.signInWithGoogleCloud();
                          _applyUser(ref, data);
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
                      try {
                        final data = await api.mockLogin();
                        _applyUser(ref, data);
                        if (context.mounted) context.go('/dashboard');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Mock sign-in failed: $e')),
                          );
                        }
                      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(
        child: Text(
          'Customizable widgets coming soon.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
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


// BasesScreen lives in bases_screen.dart

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

// BriefsScreen lives in briefs_screen.dart

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(title: 'Calendar (events + training weekends)');
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

// ── Admin Settings ─────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppColors.textDisabled),
              const SizedBox(height: 16),
              const Text('Admin access required', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Only administrators can manage regions and bases.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Settings'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.map_outlined), text: 'Regions'),
              Tab(icon: Icon(Icons.location_city_outlined), text: 'Bases'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RegionsTab(),
            _BasesTab(),
          ],
        ),
      ),
    );
  }
}

class _RegionsTab extends StatefulWidget {
  const _RegionsTab();

  @override
  State<_RegionsTab> createState() => _RegionsTabState();
}

class _RegionsTabState extends State<_RegionsTab> {
  late Future<List<dynamic>> _regions = api.getList('/regions');
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await api.post('/regions', {'name': name, 'notes': ''});
      _nameCtrl.clear();
      setState(() => _regions = api.getList('/regions'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add region: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New region name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _add,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add),
                label: const Text('Add Region'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _regions,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.error)));
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('No regions', style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                itemBuilder: (context, i) {
                  final r = list[i];
                  final states = (r['states'] as List<dynamic>? ?? []).cast<String>();
                  return ListTile(
                    leading: const Icon(Icons.map_outlined, color: AppColors.primary),
                    title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: states.isNotEmpty
                        ? Text(states.join(' · '), style: const TextStyle(fontSize: 12),
                            maxLines: 2, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: r['notes'] != null && (r['notes'] as String).isNotEmpty
                        ? Chip(label: Text(r['notes'] as String, style: const TextStyle(fontSize: 11)))
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BasesTab extends StatefulWidget {
  const _BasesTab();

  @override
  State<_BasesTab> createState() => _BasesTabState();
}

class _BasesTabState extends State<_BasesTab> {
  late Future<List<dynamic>> _bases = api.getList('/bases');
  late Future<List<dynamic>> _regions = api.getList('/regions');
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _selectedRegionId;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedRegionId == null) return;
    setState(() => _saving = true);
    try {
      await api.post('/bases', {
        'name': name,
        'region_id': _selectedRegionId,
        'address': _addressCtrl.text.trim(),
      });
      _nameCtrl.clear();
      _addressCtrl.clear();
      setState(() {
        _selectedRegionId = null;
        _bases = api.getList('/bases');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add base: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _regions,
      builder: (context, regionsSnap) {
        final regions = regionsSnap.data ?? [];
        final regionNames = {for (final r in regions) r['id'] as String: r['name'] as String? ?? r['id'] as String};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Base name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Address (optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedRegionId,
                          decoration: const InputDecoration(
                            labelText: 'Region',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final r in regions)
                              DropdownMenuItem<String>(
                                value: r['id'] as String,
                                child: Text(r['name'] as String? ?? r['id'] as String),
                              ),
                          ],
                          onChanged: (v) => setState(() => _selectedRegionId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: (_saving || _selectedRegionId == null) ? null : _add,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: const Text('Add Base'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _bases,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                        child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.error)));
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(
                        child: Text('No bases', style: TextStyle(color: AppColors.textSecondary)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final b = list[i];
                      final regionName = regionNames[b['region_id']] ?? b['region_id'] ?? '—';
                      return ListTile(
                        leading: const Icon(Icons.location_city_outlined, color: AppColors.primary),
                        title: Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(regionName, style: const TextStyle(color: AppColors.textSecondary)),
                        trailing: b['address'] != null && (b['address'] as String).isNotEmpty
                            ? Text(b['address'] as String,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Shared scaffold ────────────────────────────────────────────────────────────

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
