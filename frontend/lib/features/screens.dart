import 'package:dio/dio.dart';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/firebase_state.dart';
import '../core/user_state.dart';
import 'google_cloud_sign_in.dart' as gcp;

final api = ApiService();

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: _apiBaseUrl));
  String? _token;

  Future<Map<String, dynamic>> signInWithGoogleCloud() async {
    final user = await gcp.signInWithGoogleCloud();
    if (user == null) throw StateError('Sign-in cancelled');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) throw StateError('No Firebase ID token');
    return signInWithFirebaseToken(idToken);
  }

  Future<Map<String, dynamic>> signInWithFirebaseToken(String idToken) async {
    final resp = await _dio.post('/auth/firebase', data: {'id_token': idToken});
    _token = resp.data['access_token'] as String?;
    if (_token != null) _dio.options.headers['Authorization'] = 'Bearer $_token';
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> mockLogin() async {
    final resp = await _dio.post('/auth/mock-login', data: {
      'email': 'admin@example.com',
      'first_name': 'Admin',
      'last_name': 'User',
      'role': 'director',
      'is_admin': true,
    });
    _token = resp.data['access_token'] as String?;
    if (_token != null) _dio.options.headers['Authorization'] = 'Bearer $_token';
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

  Future<Map<String, dynamic>> postItem(String path, Map<String, dynamic> payload) async {
    final resp = await _dio.post(path, data: payload);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> post(String path, Map<String, dynamic> payload) async {
    await _dio.post(path, data: payload);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> payload) async {
    final resp = await _dio.put(path, data: payload);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getReport(String path) async {
    final resp = await _dio.get(path);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  // -- Google Workspace integrations ----------------------------------------

  Future<Map<String, dynamic>> getGoogleConnectUrl() async {
    final resp = await _dio.get('/integrations/google/connect');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> getGoogleStatus() async {
    final resp = await _dio.get('/integrations/google/status');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<void> disconnectGoogle() async {
    await _dio.post('/integrations/google/disconnect');
  }

  Future<List<dynamic>> getCalendarEvents({int daysAhead = 14}) async {
    final resp = await _dio.get('/google/calendar/events', queryParameters: {'days_ahead': daysAhead});
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getGoogleTasks({bool showCompleted = false}) async {
    final resp = await _dio.get('/google/tasks/list', queryParameters: {'show_completed': showCompleted});
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getDriveFiles({int maxResults = 25}) async {
    final resp = await _dio.get('/google/drive/files', queryParameters: {'max_results': maxResults});
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCalendarEvent(Map<String, dynamic> payload) async {
    final resp = await _dio.post('/google/calendar/create-event', data: payload);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> createGoogleTask(Map<String, dynamic> payload) async {
    final resp = await _dio.post('/google/tasks/create-follow-up', data: payload);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> sendGmail(Map<String, dynamic> payload) async {
    final resp = await _dio.post('/google/gmail/send-follow-up', data: payload);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> syncBriefToCalendar(String briefId) async {
    final resp = await _dio.post('/google/calendar/sync-brief', queryParameters: {'brief_id': briefId});
    return Map<String, dynamic>.from(resp.data as Map);
  }
}

// ── Login ──────────────────────────────────────────────────────────────────────

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
          isAdmin: u['is_admin'] as bool? ?? false,
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
                  const Text('Agent Tracker v2.0',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                              SnackBar(content: Text('Google sign-in failed: $e')),
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

// ── Admin Settings ─────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppColors.textDisabled),
              const SizedBox(height: 16),
              const Text('Admin access required',
                  style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Only administrators can access settings.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.tune_outlined), text: 'System Settings'),
              Tab(icon: Icon(Icons.people_outlined), text: 'Users'),
              Tab(icon: Icon(Icons.security_outlined), text: 'Security'),
              Tab(icon: Icon(Icons.extension_outlined), text: 'Integrations'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SystemSettingsTab(),
            _UsersTab(),
            _SecurityTab(),
            _IntegrationsTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SYSTEM SETTINGS TAB  –  Regions + Bases combined
// ─────────────────────────────────────────────────────────────────────────────

enum _ConfigSection { regions, bases }

class _SystemSettingsTab extends StatefulWidget {
  const _SystemSettingsTab();
  @override
  State<_SystemSettingsTab> createState() => _SystemSettingsTabState();
}

class _SystemSettingsTabState extends State<_SystemSettingsTab> {
  _ConfigSection _section = _ConfigSection.regions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.tune_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text('CONFIGURATION',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 20),
              SegmentedButton<_ConfigSection>(
                segments: const [
                  ButtonSegment(
                    value: _ConfigSection.regions,
                    icon: Icon(Icons.map_outlined, size: 15),
                    label: Text('Regions'),
                  ),
                  ButtonSegment(
                    value: _ConfigSection.bases,
                    icon: Icon(Icons.location_city_outlined, size: 15),
                    label: Text('Bases'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (v) => setState(() => _section = v.first),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _section == _ConfigSection.regions
              ? const _RegionsTab()
              : const _BasesTab(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTEGRATIONS TAB  –  Google Workspace connect / status
// ─────────────────────────────────────────────────────────────────────────────

class _IntegrationsTab extends StatefulWidget {
  const _IntegrationsTab();

  @override
  State<_IntegrationsTab> createState() => _IntegrationsTabState();
}

class _IntegrationsTabState extends State<_IntegrationsTab> {
  bool _loading = true;
  bool _connected = false;
  List<String> _scopes = [];
  String? _connectedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() { _loading = true; _error = null; });
    try {
      final status = await api.getGoogleStatus();
      setState(() {
        _connected = status['connected'] as bool? ?? false;
        _scopes = (status['scopes'] as List<dynamic>?)?.cast<String>() ?? [];
        _connectedAt = status['connected_at'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _connect() async {
    try {
      final data = await api.getGoogleConnectUrl();
      final url = data['url'] as String?;
      if (url == null) throw StateError('No URL returned');
      html.window.location.href = url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start Google connect: $e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google Workspace?'),
        content: const Text(
          'This will remove your Google connection. '
          'Gmail, Calendar, Drive, and Tasks features will stop working until you reconnect.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.disconnectGoogle();
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Workspace disconnected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    }
  }

  String _scopeLabel(String scope) {
    if (scope.contains('gmail')) return 'Gmail';
    if (scope.contains('calendar')) return 'Calendar';
    if (scope.contains('drive')) return 'Drive';
    if (scope.contains('tasks')) return 'Tasks';
    return scope.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Google Workspace',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Connect your Google account to enable Gmail, Calendar, Drive, and Tasks integration.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Connection status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(
                color: _connected ? AppColors.success.withAlpha(120) : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _connected ? AppColors.success : AppColors.textDisabled,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _connected ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _connected ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (_connected)
                      OutlinedButton.icon(
                        onPressed: _disconnect,
                        icon: const Icon(Icons.link_off, size: 16),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _connect,
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Connect Google Account'),
                      ),
                  ],
                ),
                if (_connected && _connectedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Connected since ${_connectedAt!.substring(0, 10)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Service cards
          const Text('Services',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ServiceCard(
                icon: Icons.email_outlined,
                label: 'Gmail',
                description: 'Send follow-up emails to unit contacts',
                active: _connected && _scopes.any((s) => s.contains('gmail')),
              ),
              _ServiceCard(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
                description: 'Sync briefs and trips to Google Calendar',
                active: _connected && _scopes.any((s) => s.contains('calendar')),
              ),
              _ServiceCard(
                icon: Icons.folder_outlined,
                label: 'Drive',
                description: 'Upload brief materials and export reports',
                active: _connected && _scopes.any((s) => s.contains('drive')),
              ),
              _ServiceCard(
                icon: Icons.task_alt_outlined,
                label: 'Tasks',
                description: 'Create follow-up tasks from conversations',
                active: _connected && _scopes.any((s) => s.contains('tasks')),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_connected && _scopes.isNotEmpty) ...[
            const Text('Granted Scopes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _scopes
                  .where((s) => s.startsWith('https://'))
                  .map((s) => Chip(
                        label: Text(_scopeLabel(s), style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 32),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadStatus,
                tooltip: 'Refresh status',
              ),
              const SizedBox(width: 8),
              const Text(
                'After connecting, return here and press refresh to update status.',
                style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.active,
  });
  final IconData icon;
  final String label;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: active ? AppColors.primary.withAlpha(100) : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: active ? AppColors.primary : AppColors.textDisabled),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? AppColors.success.withAlpha(30) : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.success : AppColors.textDisabled,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY TAB  –  Roles & Permissions
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityTab extends StatefulWidget {
  const _SecurityTab();
  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final List<Map<String, dynamic>> _roles = [
    {
      'name': 'Agent',
      'key': 'agent',
      'level': 1,
      'description': 'Field sales agent with access to assigned units and states',
      'builtin': true,
      'permissions': [
        'View assigned units and bases',
        'Create and manage own briefs',
        'Log conversations and contacts',
        'View own reports and dashboard',
        'Manage own trips',
      ],
    },
    {
      'name': 'Manager',
      'key': 'manager',
      'level': 2,
      'description': 'Regional manager with oversight of agents and state assignments',
      'builtin': true,
      'permissions': [
        'All Agent permissions',
        'View all regions, bases, and units',
        'Manage user accounts and assignments',
        'Manage unit-agent assignments',
        'Access management reports and exports',
        'Create and edit regions and bases',
      ],
    },
    {
      'name': 'Director',
      'key': 'director',
      'level': 3,
      'description': 'Executive director with full operational access across all regions',
      'builtin': true,
      'permissions': [
        'All Manager permissions',
        'Full access to all data and operations',
        'Access executive reports',
        'Manage organization-wide settings',
      ],
    },
  ];

  void _addRole() {
    showDialog(
      context: context,
      builder: (ctx) => _EditRoleDialog(
        onSaved: (role) {
          setState(() => _roles.add(role));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role "${role['name']}" created')),
          );
        },
      ),
    );
  }

  void _editRole(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _EditRoleDialog(
        role: _roles[index],
        onSaved: (role) {
          setState(() => _roles[index] = role);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role "${role['name']}" updated')),
          );
        },
      ),
    );
  }

  void _deleteRole(int index) async {
    final role = _roles[index];
    final isBuiltin = role['builtin'] as bool? ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text(
          isBuiltin
              ? 'Delete built-in role "${role['name']}"? '
                'This will remove it from the permission hierarchy and cannot be undone.'
              : 'Delete "${role['name']}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _roles.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role "${role['name']}" deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.security_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text('ROLES & PERMISSIONS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_roles.length} roles',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _addRole,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Role'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textDisabled),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All roles are fully customizable. Edit descriptions and permissions to '
                  'match your organization. Admin access is a separate flag that grants '
                  'full system access regardless of role.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SecuritySectionLabel(label: 'ALL ROLES'),
                const SizedBox(height: 8),
                _RolesTable(
                  roles: _roles,
                  onEdit: _editRole,
                  onDelete: _deleteRole,
                ),
                const SizedBox(height: 24),
                _SecuritySectionLabel(label: 'ADMIN ACCESS'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Administrator Flag',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'The admin flag is independent of role hierarchy. '
                              'When enabled on a user, it grants full system access including '
                              'all settings, user management, and data manipulation '
                              'regardless of their assigned role.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _PermissionChip(label: 'Bypass all role checks'),
                                _PermissionChip(label: 'Manage all settings'),
                                _PermissionChip(label: 'Full data access'),
                                _PermissionChip(label: 'User administration'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SecuritySectionLabel extends StatelessWidget {
  const _SecuritySectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _RolesTable extends StatelessWidget {
  const _RolesTable({
    required this.roles,
    required this.onEdit,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> roles;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          children: [
            Container(
              color: AppColors.surfaceHigh,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  SizedBox(width: 80, child: Text('Role', style: _tableHeaderStyle)),
                  SizedBox(width: 8),
                  SizedBox(
                      width: 50, child: Text('Level', style: _tableHeaderStyle)),
                  SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: Text('Description', style: _tableHeaderStyle)),
                  SizedBox(width: 8),
                  Expanded(
                      flex: 3,
                      child: Text('Permissions', style: _tableHeaderStyle)),
                  SizedBox(
                      width: 80,
                      child: Text('Actions',
                          style: _tableHeaderStyle,
                          textAlign: TextAlign.center)),
                ],
              ),
            ),
            for (int i = 0; i < roles.length; i++) ...[
              const Divider(height: 1),
              _RoleRow(
                role: roles[i],
                onEdit: () => onEdit(i),
                onDelete: () => onDelete(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _tableHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.5,
  color: AppColors.textSecondary,
);

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> role;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _roleColor => switch (role['key'] as String?) {
        'director' => AppColors.warning,
        'manager' => AppColors.primaryLight,
        'agent' => AppColors.textSecondary,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final perms = (role['permissions'] as List<dynamic>?) ?? [];
    final isBuiltin = role['builtin'] as bool? ?? false;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _roleColor.withAlpha(80)),
                  ),
                  child: Text(role['name'] as String? ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _roleColor)),
                ),
                if (isBuiltin) ...[
                  const SizedBox(height: 4),
                  Text('Built-in',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.textDisabled)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${role['level'] ?? '—'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(role['description'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final p in perms)
                  _PermissionChip(label: p as String),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.error),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    );
  }
}

class _EditRoleDialog extends StatefulWidget {
  const _EditRoleDialog({this.role, required this.onSaved});
  final Map<String, dynamic>? role;
  final void Function(Map<String, dynamic> role) onSaved;
  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _permCtrl;
  late int _level;
  late List<String> _permissions;
  bool get _isEditing => widget.role != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.role?['name'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: widget.role?['description'] as String? ?? '');
    _permCtrl = TextEditingController();
    _level = widget.role?['level'] as int? ?? 1;
    _permissions = List<String>.from(
        (widget.role?['permissions'] as List<dynamic>?) ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _permCtrl.dispose();
    super.dispose();
  }

  void _addPermission() {
    final p = _permCtrl.text.trim();
    if (p.isEmpty) return;
    setState(() {
      _permissions.add(p);
      _permCtrl.clear();
    });
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role name is required')));
      return;
    }
    widget.onSaved({
      'name': _nameCtrl.text.trim(),
      'key': widget.role?['key'] as String? ??
          _nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
      'level': _level,
      'description': _descCtrl.text.trim(),
      'builtin': widget.role?['builtin'] as bool? ?? false,
      'permissions': _permissions,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'Edit Role' : 'Add New Role',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Role name *',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _level,
                        decoration: const InputDecoration(
                            labelText: 'Permission Level',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 – Basic')),
                          DropdownMenuItem(
                              value: 2, child: Text('2 – Elevated')),
                          DropdownMenuItem(
                              value: 3, child: Text('3 – Full')),
                        ],
                        onChanged: (v) =>
                            setState(() => _level = v ?? 1),
                      ),
                      const SizedBox(height: 16),
                      const Text('Permissions',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _permCtrl,
                              decoration: const InputDecoration(
                                  hintText: 'Add a permission…',
                                  border: OutlineInputBorder(),
                                  isDense: true),
                              onSubmitted: (_) => _addPermission(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addPermission,
                            icon: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_permissions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No permissions added yet.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textDisabled)),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (int i = 0; i < _permissions.length; i++)
                              Chip(
                                label: Text(_permissions[i],
                                    style: const TextStyle(fontSize: 11)),
                                deleteIcon:
                                    const Icon(Icons.close, size: 14),
                                onDeleted: () => setState(
                                    () => _permissions.removeAt(i)),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(_isEditing ? 'Save Changes' : 'Create Role'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGIONS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _RegionsTab extends StatefulWidget {
  const _RegionsTab();
  @override
  State<_RegionsTab> createState() => _RegionsTabState();
}

class _RegionsTabState extends State<_RegionsTab> {
  late Future<List<dynamic>> _regions = api.getList('/regions');
  late Future<List<dynamic>> _allStates = api.getList('/states');
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _regions = api.getList('/regions'));

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await api.post('/regions', {'name': name, 'notes': ''});
      _nameCtrl.clear();
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to add region: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Region'),
        content: Text('Delete "${region['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await api.delete('/regions/${region['id']}');
      _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _edit(Map<String, dynamic> region, List<dynamic> allStates) async {
    await showDialog(
      context: context,
      builder: (ctx) =>
          _EditRegionDialog(region: region, allStates: allStates, onSaved: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _allStates,
      builder: (context, statesSnap) {
        final allStates = statesSnap.data ?? [];
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
                          labelText: 'New region name', border: OutlineInputBorder(), isDense: true),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _add,
                    icon: _saving
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                    return Center(
                        child: Text('Error: ${snap.error}',
                            style: const TextStyle(color: AppColors.error)));
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(
                        child: Text('No regions',
                            style: TextStyle(color: AppColors.textSecondary)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final r = Map<String, dynamic>.from(list[i] as Map);
                      final states = (r['states'] as List<dynamic>? ?? []).cast<String>();
                      return ListTile(
                        leading: const Icon(Icons.map_outlined, color: AppColors.primary),
                        title:
                            Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: states.isNotEmpty
                            ? Text(states.join(' · '),
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)
                            : const Text('No states assigned',
                                style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (r['notes'] != null && (r['notes'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                    label: Text(r['notes'] as String,
                                        style: const TextStyle(fontSize: 11))),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit',
                              onPressed: () => _edit(r, allStates),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.error),
                              tooltip: 'Delete',
                              onPressed: () => _delete(r),
                            ),
                          ],
                        ),
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

class _EditRegionDialog extends StatefulWidget {
  const _EditRegionDialog(
      {required this.region, required this.allStates, required this.onSaved});
  final Map<String, dynamic> region;
  final List<dynamic> allStates;
  final VoidCallback onSaved;

  @override
  State<_EditRegionDialog> createState() => _EditRegionDialogState();
}

class _EditRegionDialogState extends State<_EditRegionDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late Set<String> _selectedStates;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.region['name'] as String? ?? '');
    _notesCtrl = TextEditingController(text: widget.region['notes'] as String? ?? '');
    _selectedStates = Set<String>.from(
        (widget.region['states'] as List<dynamic>? ?? []).cast<String>());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await api.put('/regions/${widget.region['id']}', {
        'name': name,
        'notes': _notesCtrl.text.trim(),
        'states': _selectedStates.toList()..sort(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final states = widget.allStates.cast<Map<String, dynamic>>();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit Region', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Region name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Assigned States',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('(${_selectedStates.length} selected)',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final s in states)
                          FilterChip(
                            label: Text('${s['code']} – ${s['name']}',
                                style: const TextStyle(fontSize: 11)),
                            selected: _selectedStates.contains(s['code'] as String),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selectedStates.add(s['code'] as String);
                              } else {
                                _selectedStates.remove(s['code'] as String);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BASES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _BasesTab extends StatefulWidget {
  const _BasesTab();
  @override
  State<_BasesTab> createState() => _BasesTabState();
}

class _BasesTabState extends State<_BasesTab> {
  late Future<List<dynamic>> _bases = api.getList('/bases');
  late Future<List<dynamic>> _regions = api.getList('/regions');

  void _refresh() => setState(() => _bases = api.getList('/bases'));

  Future<void> _delete(Map<String, dynamic> base) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Base'),
        content: Text('Delete "${base['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await api.delete('/bases/${base['id']}');
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _showBaseDialog(Map<String, dynamic>? base, List<dynamic> regions) async {
    await showDialog(
      context: context,
      builder: (ctx) =>
          _EditBaseDialog(base: base, regions: regions, onSaved: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _regions,
      builder: (context, regionsSnap) {
        final regions = regionsSnap.data ?? [];
        final regionNames = {
          for (final r in regions)
            r['id'] as String: r['name'] as String? ?? r['id'] as String
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.surfaceLow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_city_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text('BASES',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showBaseDialog(null, regions),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Base'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
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
                        child: Text('Error: ${snap.error}',
                            style: const TextStyle(color: AppColors.error)));
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_city_outlined,
                              size: 48, color: AppColors.textDisabled),
                          const SizedBox(height: 12),
                          const Text('No bases',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _showBaseDialog(null, regions),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Base'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final b = Map<String, dynamic>.from(list[i] as Map);
                      final regionName = regionNames[b['region_id']] ?? '—';
                      final state = b['state'] as String?;
                      final street = b['address_street'] as String?;
                      final city = b['address_city'] as String?;
                      final zip = b['address_zip'] as String?;
                      final addrParts = [street, city, zip].whereType<String>().toList();
                      final addr = addrParts.isNotEmpty ? addrParts.join(', ') : null;
                      return ListTile(
                        leading: const Icon(Icons.location_city_outlined,
                            color: AppColors.primary),
                        title: Text(b['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            [if (state != null) state, regionName].join(' · '),
                            style: const TextStyle(color: AppColors.textSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (addr != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(addr,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary)),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit',
                              onPressed: () => _showBaseDialog(b, regions),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.error),
                              tooltip: 'Delete',
                              onPressed: () => _delete(b),
                            ),
                          ],
                        ),
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

class _EditBaseDialog extends StatefulWidget {
  const _EditBaseDialog(
      {this.base, required this.regions, required this.onSaved});
  final Map<String, dynamic>? base;
  final List<dynamic> regions;
  final VoidCallback onSaved;

  @override
  State<_EditBaseDialog> createState() => _EditBaseDialogState();
}

class _EditBaseDialogState extends State<_EditBaseDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _notesCtrl;
  String? _selectedRegionId;
  String? _selectedState;
  List<String> _regionStates = [];
  bool _saving = false;

  bool get _isEditing => widget.base != null;

  @override
  void initState() {
    super.initState();
    final b = widget.base;
    _nameCtrl = TextEditingController(text: b?['name'] as String? ?? '');
    _streetCtrl =
        TextEditingController(text: b?['address_street'] as String? ?? '');
    _cityCtrl =
        TextEditingController(text: b?['address_city'] as String? ?? '');
    _zipCtrl = TextEditingController(text: b?['address_zip'] as String? ?? '');
    _latCtrl = TextEditingController(
        text: b?['latitude'] != null ? b!['latitude'].toString() : '');
    _lngCtrl = TextEditingController(
        text: b?['longitude'] != null ? b!['longitude'].toString() : '');
    _notesCtrl = TextEditingController(text: b?['notes'] as String? ?? '');
    _selectedRegionId = b?['region_id'] as String?;
    _selectedState = b?['state'] as String?;
    _loadRegionStates();
  }

  void _loadRegionStates() {
    if (_selectedRegionId == null) return;
    final region = widget.regions.firstWhere((r) => r['id'] == _selectedRegionId,
        orElse: () => <String, dynamic>{});
    _regionStates = (region['states'] as List<dynamic>? ?? []).cast<String>();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _streetCtrl, _cityCtrl, _zipCtrl, _latCtrl, _lngCtrl, _notesCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _selectedRegionId == null) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'region_id': _selectedRegionId,
        'state': _selectedState,
        'address_street':
            _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim(),
        'address_city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'address_zip': _zipCtrl.text.trim().isEmpty ? null : _zipCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };
      if (_latCtrl.text.trim().isNotEmpty) {
        payload['latitude'] = double.tryParse(_latCtrl.text.trim());
      }
      if (_lngCtrl.text.trim().isNotEmpty) {
        payload['longitude'] = double.tryParse(_lngCtrl.text.trim());
      }
      if (_isEditing) {
        await api.put('/bases/${widget.base!['id']}', payload);
      } else {
        await api.post('/bases', payload);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'Edit Base' : 'Add New Base',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Base name *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedRegionId,
                              decoration: const InputDecoration(
                                  labelText: 'Region *', border: OutlineInputBorder()),
                              items: [
                                for (final r in widget.regions)
                                  DropdownMenuItem<String>(
                                      value: r['id'] as String,
                                      child: Text(
                                          r['name'] as String? ?? r['id'] as String)),
                              ],
                              onChanged: (v) {
                                final region = widget.regions.firstWhere(
                                    (r) => r['id'] == v,
                                    orElse: () => <String, dynamic>{});
                                setState(() {
                                  _selectedRegionId = v;
                                  _regionStates = (region['states'] as List<dynamic>? ?? [])
                                      .cast<String>();
                                  _selectedState = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _regionStates.contains(_selectedState)
                                  ? _selectedState
                                  : null,
                              decoration: const InputDecoration(
                                  labelText: 'State', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem<String>(
                                    value: null, child: Text('— none —')),
                                for (final s in _regionStates)
                                  DropdownMenuItem<String>(value: s, child: Text(s)),
                              ],
                              onChanged: (v) => setState(() => _selectedState = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _streetCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Street address', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _cityCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'City', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _zipCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'ZIP', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                              decoration: const InputDecoration(
                                  labelText: 'Latitude', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _lngCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                              decoration: const InputDecoration(
                                  labelText: 'Longitude', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Notes', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Save Changes' : 'Create Base'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USERS TAB  –  By Users / By Regions+States
// ─────────────────────────────────────────────────────────────────────────────

enum _UsersView { byUsers, byRegions }

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  _UsersView _view = _UsersView.byUsers;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _allStates = [];

  // state_code -> {state_code, state_name, agents:[...]}
  Map<String, Map<String, dynamic>> _coverageByState = {};
  // user_id -> [state_codes]
  Map<String, List<String>> _userStateMap = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.getList('/admin/users'),
        api.getList('/regions'),
        api.getList('/states'),
        api.getList('/admin/state-coverage'),
      ]);
      if (!mounted) return;
      setState(() {
        _users = _toMaps(results[0]);
        _regions = _toMaps(results[1]);
        _allStates = _toMaps(results[2]);
        _rebuildCoverage(results[3]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _toMaps(List<dynamic> raw) =>
      raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  void _rebuildCoverage(List<dynamic> raw) {
    _coverageByState = {};
    for (final c in raw) {
      final m = Map<String, dynamic>.from(c as Map);
      final code = m['state_code'] as String;
      _coverageByState[code] = {
        'state_code': code,
        'state_name': m['state_name'] as String? ?? code,
        'agents': (m['agents'] as List<dynamic>)
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList(),
      };
    }
    _userStateMap = {};
    for (final entry in _coverageByState.values) {
      for (final agent in (entry['agents'] as List<Map<String, dynamic>>)) {
        _userStateMap.putIfAbsent(agent['id'] as String, () => [])
            .add(entry['state_code'] as String);
      }
    }
  }

  Future<void> _reloadCoverage() async {
    try {
      final coverage = await api.getList('/admin/state-coverage');
      if (!mounted) return;
      setState(() => _rebuildCoverage(coverage));
    } catch (_) {}
  }

  Future<void> _reloadUsers() async {
    try {
      final users = await api.getList('/admin/users');
      if (!mounted) return;
      setState(() => _users = _toMaps(users));
    } catch (_) {}
  }

  Set<String> get _allRegionStateCodes {
    final result = <String>{};
    for (final r in _regions) {
      result.addAll((r['states'] as List?)?.cast<String>() ?? []);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 8),
            TextButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ],
        ),
      );
    }

    final allRegionStates = _allRegionStateCodes;
    final coveredCount = _coverageByState.keys
        .where((k) => allRegionStates.contains(k))
        .length;
    final uncoveredCount = allRegionStates.difference(_coverageByState.keys.toSet()).length;
    final totalAssignments =
        _userStateMap.values.fold(0, (s, v) => s + v.length);
    final avgStates = _users.isEmpty ? 0.0 : totalAssignments / _users.length;
    return Column(
      children: [
        // ── Stats bar ────────────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              _StatTile(label: 'Total Users', value: '${_users.length}', color: AppColors.primary),
              _kStatDivider,
              _StatTile(
                label: 'States Covered',
                value: '$coveredCount',
                sub: '/ ${allRegionStates.length}',
                color: AppColors.success,
              ),
              _kStatDivider,
              _StatTile(
                label: 'Need Coverage',
                value: '$uncoveredCount',
                color: uncoveredCount > 0 ? AppColors.warning : AppColors.success,
                icon: uncoveredCount > 0
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
              ),
              _kStatDivider,
              _StatTile(
                label: 'Avg States / User',
                value: avgStates.toStringAsFixed(1),
                color: AppColors.textSecondary,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_outlined, size: 18),
                tooltip: 'Refresh',
                onPressed: _loadAll,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── View toggle ──────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SegmentedButton<_UsersView>(
                segments: const [
                  ButtonSegment(
                    value: _UsersView.byUsers,
                    icon: Icon(Icons.people_outlined, size: 15),
                    label: Text('By Users'),
                  ),
                  ButtonSegment(
                    value: _UsersView.byRegions,
                    icon: Icon(Icons.map_outlined, size: 15),
                    label: Text('By Region / State'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (v) => setState(() => _view = v.first),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Content ──────────────────────────────────────────────────────────
        Expanded(
          child: _view == _UsersView.byUsers
              ? _UsersByUsersView(
                  key: const ValueKey('byUsers'),
                  users: _users,
                  allStates: _allStates,
                  userStateMap: _userStateMap,
                  onUserChanged: () async {
                    await _reloadUsers();
                    await _reloadCoverage();
                  },
                  onStatesChanged: _reloadCoverage,
                )
              : _UsersByRegionsView(
                  key: const ValueKey('byRegions'),
                  regions: _regions,
                  coverageByState: _coverageByState,
                ),
        ),
      ],
    );
  }
}

const _kStatDivider = Padding(
  padding: EdgeInsets.symmetric(horizontal: 20),
  child: SizedBox(height: 36, child: VerticalDivider()),
);

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.sub,
    this.icon,
  });
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
            ],
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: color, height: 1.1)),
            if (sub != null) ...[
              const SizedBox(width: 3),
              Text(sub!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary, letterSpacing: 0.3)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BY USERS VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _UsersByUsersView extends StatefulWidget {
  const _UsersByUsersView({
    super.key,
    required this.users,
    required this.allStates,
    required this.userStateMap,
    required this.onUserChanged,
    required this.onStatesChanged,
  });
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> allStates;
  final Map<String, List<String>> userStateMap;
  final Future<void> Function() onUserChanged;
  final Future<void> Function() onStatesChanged;

  @override
  State<_UsersByUsersView> createState() => _UsersByUsersViewState();
}

class _UsersByUsersViewState extends State<_UsersByUsersView> {
  Map<String, dynamic>? _selectedUser;
  String _search = '';
  String? _filterState;

  List<Map<String, dynamic>> get _filtered {
    return widget.users.where((u) {
      final uid = u['id'] as String;
      // State filter
      if (_filterState != null) {
        final assigned = widget.userStateMap[uid] ?? [];
        if (!assigned.contains(_filterState)) return false;
      }
      // Text search
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        final role = (u['role'] as String? ?? '').toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !role.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Delete "${user['first_name']} ${user['last_name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await api.delete('/admin/users/${user['id']}');
      if (_selectedUser?['id'] == user['id']) setState(() => _selectedUser = null);
      await widget.onUserChanged();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic>? user) async {
    await showDialog(
      context: context,
      builder: (ctx) => _EditUserDialog(
        user: user,
        onSaved: (updated) async {
          await widget.onUserChanged();
          if (!mounted) return;
          if (updated != null) {
            if (_selectedUser?['id'] == (updated['id'] as String?)) {
              setState(() => _selectedUser = updated);
            } else if (user == null) {
              setState(() => _selectedUser = updated);
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: user list ───────────────────────────────────────────────
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                color: AppColors.surfaceLow,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('USERS',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondary)),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showEditDialog(null),
                      icon: const Icon(Icons.person_add_outlined, size: 15),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search users…',
                    prefixIcon: Icon(Icons.search_outlined, size: 17),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: DropdownButtonFormField<String?>(
                  value: _filterState,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    prefixIcon: const Icon(Icons.filter_list_outlined, size: 16),
                    suffixIcon: _filterState != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            tooltip: 'Clear filter',
                            onPressed: () => setState(() => _filterState = null),
                          )
                        : null,
                  ),
                  hint: const Text('All states', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All states', style: TextStyle(fontSize: 13)),
                    ),
                    for (final s in widget.allStates)
                      DropdownMenuItem<String?>(
                        value: s['code'] as String,
                        child: Text('${s['code']} – ${s['name']}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _filterState = v),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_search_outlined,
                                size: 36, color: AppColors.textDisabled),
                            const SizedBox(height: 8),
                            Text(
                              _filterState != null
                                  ? 'No users assigned to $_filterState'
                                  : _search.isNotEmpty
                                      ? 'No users match "$_search"'
                                      : 'No users',
                              style:
                                  const TextStyle(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final u = filtered[i];
                          final uid = u['id'] as String;
                          final name =
                              '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                          final role = u['role'] as String? ?? '';
                          final isAdmin = u['is_admin'] as bool? ?? false;
                          final stateCount =
                              (widget.userStateMap[uid] ?? []).length;
                          final isSelected = _selectedUser?['id'] == uid;

                          return InkWell(
                            onTap: () => setState(() => _selectedUser = u),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              color: isSelected
                                  ? AppColors.primary.withAlpha(22)
                                  : Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isSelected
                                          ? AppColors.primary
                                          : AppColors.surfaceHigh,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              _RoleBadge(role: role),
                                              if (isAdmin) ...[
                                                const SizedBox(width: 4),
                                                const _AdminBadge(),
                                              ],
                                              const Spacer(),
                                              _StateCountBadge(count: stateCount),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _MiniIconButton(
                                          icon: Icons.edit_outlined,
                                          tooltip: 'Edit',
                                          onPressed: () => _showEditDialog(u),
                                        ),
                                        _MiniIconButton(
                                          icon: Icons.delete_outline,
                                          tooltip: 'Delete',
                                          color: AppColors.error,
                                          onPressed: () => _deleteUser(u),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // ── Right: user detail ────────────────────────────────────────────
        Expanded(
          child: _selectedUser == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outlined, size: 48, color: AppColors.textDisabled),
                      SizedBox(height: 12),
                      Text(
                        'Select a user to view details\nand manage state assignments',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : _UserDetailPanel(
                  key: ValueKey(_selectedUser!['id']),
                  user: _selectedUser!,
                  assignedStateCodes:
                      List<String>.from(widget.userStateMap[_selectedUser!['id']] ?? []),
                  allStates: widget.allStates,
                  onEditProfile: () => _showEditDialog(_selectedUser),
                  onStatesChanged: widget.onStatesChanged,
                ),
        ),
      ],
    );
  }
}

// ── User Detail Panel ──────────────────────────────────────────────────────────

class _UserDetailPanel extends StatefulWidget {
  const _UserDetailPanel({
    super.key,
    required this.user,
    required this.assignedStateCodes,
    required this.allStates,
    required this.onEditProfile,
    required this.onStatesChanged,
  });
  final Map<String, dynamic> user;
  final List<String> assignedStateCodes;
  final List<Map<String, dynamic>> allStates;
  final VoidCallback onEditProfile;
  final Future<void> Function() onStatesChanged;

  @override
  State<_UserDetailPanel> createState() => _UserDetailPanelState();
}

class _UserDetailPanelState extends State<_UserDetailPanel> {
  String? _stateToAdd;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    final role = u['role'] as String? ?? '';
    final isAdmin = u['is_admin'] as bool? ?? false;
    final email = u['email'] as String? ?? '';
    final mobile = u['mobile_phone'] as String?;
    final office = u['office_phone'] as String?;
    final street = u['address_street'] as String?;
    final city = u['address_city'] as String?;
    final addrState = u['address_state'] as String?;
    final zip = u['address_zip'] as String?;
    final ssli = u['ssli_agent_number'] as String?;
    final rgli = u['rgli_agent_number'] as String?;

    // Build a lookup map: code → name for display
    final stateNameMap = {
      for (final s in widget.allStates) s['code'] as String: s['name'] as String
    };

    final assigned = (List<String>.from(widget.assignedStateCodes))..sort();
    final assignedSet = assigned.toSet();
    final unassigned = widget.allStates
        .where((s) => !assignedSet.contains(s['code'] as String))
        .toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Profile header bar ────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withAlpha(50),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _RoleBadge(role: role, large: true),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        const _AdminBadge(large: true),
                      ],
                    ]),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onEditProfile,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit Profile'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Compact profile info ──────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              if (email.isNotEmpty)
                _InfoRow(icon: Icons.email_outlined, value: email),
              if (mobile != null && mobile.isNotEmpty)
                _InfoRow(icon: Icons.phone_android_outlined, value: mobile, sub: 'Mobile'),
              if (office != null && office.isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, value: office, sub: 'Office'),
              if (street != null || city != null || addrState != null)
                _InfoRow(
                  icon: Icons.home_outlined,
                  value: [street, city, addrState, zip].whereType<String>().join(', '),
                ),
              if (ssli != null && ssli.isNotEmpty)
                _InfoRow(icon: Icons.badge_outlined, value: 'SSLI: $ssli'),
              if (rgli != null && rgli.isNotEmpty)
                _InfoRow(icon: Icons.badge_outlined, value: 'RGLI: $rgli'),
              if (email.isEmpty &&
                  (mobile == null || mobile.isEmpty) &&
                  (office == null || office.isEmpty))
                const Text('No contact info on file',
                    style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── State Assignments section header ──────────────────────────────────
        Container(
          color: AppColors.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Text('STATE ASSIGNMENTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary)),
              const Spacer(),
              _StateCountBadge(count: assigned.length, large: true),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Add state row ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _stateToAdd,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select a state to assign',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    for (final s in unassigned)
                      DropdownMenuItem<String>(
                        value: s['code'] as String,
                        child: Text('${s['code']} – ${s['name']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _stateToAdd = v),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _stateToAdd == null
                    ? null
                    : () async {
                        final s = _stateToAdd!;
                        setState(() => _stateToAdd = null);
                        try {
                          await api.post('/admin/user-state-licenses', {
                            'user_id': u['id'] as String,
                            'state_code': s,
                          });
                          await widget.onStatesChanged();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to assign state: $e')));
                          }
                        }
                      },
                icon: const Icon(Icons.add),
                label: const Text('Assign'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Assigned states list ──────────────────────────────────────────────
        Expanded(
          child: assigned.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 36, color: AppColors.textDisabled),
                      SizedBox(height: 8),
                      Text('No states assigned yet',
                          style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('Use the dropdown above to assign states.',
                          style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: assigned.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
                  itemBuilder: (context, i) {
                    final code = assigned[i];
                    final stateName = stateNameMap[code] ?? code;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.flag_outlined,
                          color: AppColors.primary, size: 18),
                      title: Text(stateName),
                      subtitle: Text(code,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.error, size: 18),
                        tooltip: 'Remove $code',
                        onPressed: () async {
                          try {
                            await api.delete(
                                '/admin/user-state-licenses/${u['id']}/$code');
                            await widget.onStatesChanged();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to remove state: $e')));
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BY REGIONS / STATES VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _UsersByRegionsView extends StatefulWidget {
  const _UsersByRegionsView({
    super.key,
    required this.regions,
    required this.coverageByState,
  });
  final List<Map<String, dynamic>> regions;
  final Map<String, Map<String, dynamic>> coverageByState;

  @override
  State<_UsersByRegionsView> createState() => _UsersByRegionsViewState();
}

class _UsersByRegionsViewState extends State<_UsersByRegionsView> {
  Map<String, dynamic>? _selectedRegion;

  int _coveredCount(Map<String, dynamic> region) {
    final states = (region['states'] as List?)?.cast<String>() ?? [];
    return states.where((s) => widget.coverageByState.containsKey(s)).length;
  }

  Color _regionColor(Map<String, dynamic> region) {
    final states = (region['states'] as List?)?.cast<String>() ?? [];
    if (states.isEmpty) return AppColors.textDisabled;
    final covered = _coveredCount(region);
    if (covered == states.length) return AppColors.success;
    if (covered > 0) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: regions list ────────────────────────────────────────────
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.surfaceLow,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('REGIONS',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondary)),
                    ),
                    Text('${widget.regions.length} total',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: widget.regions.isEmpty
                    ? const Center(
                        child: Text('No regions',
                            style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: widget.regions.length,
                        itemBuilder: (context, i) {
                          final r = widget.regions[i];
                          final states = (r['states'] as List?)?.cast<String>() ?? [];
                          final covered = _coveredCount(r);
                          final color = _regionColor(r);
                          final isSelected = _selectedRegion?['id'] == r['id'];

                          return InkWell(
                            onTap: () => setState(() => _selectedRegion = r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              color: isSelected
                                  ? AppColors.primary.withAlpha(22)
                                  : Colors.transparent,
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle, color: color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r['name'] as String? ?? '',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          states.isEmpty
                                              ? 'No states in region'
                                              : '$covered of ${states.length} states have agents',
                                          style: TextStyle(
                                              fontSize: 11, color: color.withAlpha(200)),
                                        ),
                                        if (states.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: states.isEmpty
                                                  ? 0
                                                  : covered / states.length,
                                              backgroundColor: AppColors.surfaceHigh,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(color),
                                              minHeight: 3,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // ── Right: state coverage detail ──────────────────────────────────
        Expanded(
          child: _selectedRegion == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 48, color: AppColors.textDisabled),
                      SizedBox(height: 12),
                      Text(
                        'Select a region to view\ncoverage by state',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : _RegionCoveragePanel(
                  key: ValueKey(_selectedRegion!['id']),
                  region: _selectedRegion!,
                  coverageByState: widget.coverageByState,
                ),
        ),
      ],
    );
  }
}

class _RegionCoveragePanel extends StatelessWidget {
  const _RegionCoveragePanel({
    super.key,
    required this.region,
    required this.coverageByState,
  });
  final Map<String, dynamic> region;
  final Map<String, Map<String, dynamic>> coverageByState;

  @override
  Widget build(BuildContext context) {
    final states = (region['states'] as List?)?.cast<String>() ?? [];
    final covered = states.where((s) => coverageByState.containsKey(s)).length;
    final uncovered = states.length - covered;

    // Sort: uncovered first, then alphabetical
    final sorted = [...states]..sort((a, b) {
        final ac = coverageByState.containsKey(a);
        final bc = coverageByState.containsKey(b);
        if (!ac && bc) return -1;
        if (ac && !bc) return 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          color: AppColors.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(region['name'] as String? ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              _CoveragePill(
                label: '$covered / ${states.length} covered',
                color: covered == states.length
                    ? AppColors.success
                    : covered > 0
                        ? AppColors.warning
                        : AppColors.error,
              ),
              if (uncovered > 0) ...[
                const SizedBox(width: 8),
                _CoveragePill(
                  label: '$uncovered need help',
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.error,
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // State cards
        Expanded(
          child: states.isEmpty
              ? const Center(
                  child: Text('No states assigned to this region',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final code = sorted[i];
                    final cov = coverageByState[code];
                    final agents = (cov?['agents'] as List<Map<String, dynamic>>? ?? []);
                    final stateName = cov?['state_name'] as String? ?? code;
                    final hasCoverage = agents.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(
                            color: hasCoverage
                                ? AppColors.success.withAlpha(70)
                                : AppColors.error.withAlpha(70),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _StateCodeBadge(code: code, covered: hasCoverage),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(stateName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 14)),
                                ),
                                if (!hasCoverage)
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_outlined,
                                          size: 13, color: AppColors.error),
                                      const SizedBox(width: 4),
                                      Text('Needs coverage',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  )
                                else
                                  Text(
                                    '${agents.length} agent${agents.length != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                            if (hasCoverage) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final a in agents) _AgentChip(agent: a),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT USER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

const _kRoles = ['agent', 'manager', 'director'];

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user, required this.onSaved});
  final Map<String, dynamic>? user;
  final void Function(Map<String, dynamic>? updatedUser) onSaved;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _officeCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _ssliCtrl;
  late final TextEditingController _rgliCtrl;
  late String _role;
  late bool _isAdmin;
  String? _addrState;
  late Future<List<dynamic>> _states;
  bool _saving = false;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _firstCtrl = TextEditingController(text: u?['first_name'] as String? ?? '');
    _lastCtrl = TextEditingController(text: u?['last_name'] as String? ?? '');
    _emailCtrl = TextEditingController(text: u?['email'] as String? ?? '');
    _mobileCtrl = TextEditingController(text: u?['mobile_phone'] as String? ?? '');
    _officeCtrl = TextEditingController(text: u?['office_phone'] as String? ?? '');
    _streetCtrl = TextEditingController(text: u?['address_street'] as String? ?? '');
    _cityCtrl = TextEditingController(text: u?['address_city'] as String? ?? '');
    _zipCtrl = TextEditingController(text: u?['address_zip'] as String? ?? '');
    _ssliCtrl = TextEditingController(text: u?['ssli_agent_number'] as String? ?? '');
    _rgliCtrl = TextEditingController(text: u?['rgli_agent_number'] as String? ?? '');
    _role = u?['role'] as String? ?? 'agent';
    _isAdmin = u?['is_admin'] as bool? ?? false;
    _addrState = u?['address_state'] as String?;
    _states = api.getList('/states');
  }

  @override
  void dispose() {
    for (final c in [
      _firstCtrl, _lastCtrl, _emailCtrl, _mobileCtrl, _officeCtrl,
      _streetCtrl, _cityCtrl, _zipCtrl, _ssliCtrl, _rgliCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty ||
        _lastCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First name, last name, and email are required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _role,
        'is_admin': _isAdmin,
        'mobile_phone': _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
        'office_phone': _officeCtrl.text.trim().isEmpty ? null : _officeCtrl.text.trim(),
        'address_street': _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim(),
        'address_city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'address_state': _addrState,
        'address_zip': _zipCtrl.text.trim().isEmpty ? null : _zipCtrl.text.trim(),
        'ssli_agent_number': _ssliCtrl.text.trim().isEmpty ? null : _ssliCtrl.text.trim(),
        'rgli_agent_number': _rgliCtrl.text.trim().isEmpty ? null : _rgliCtrl.text.trim(),
      };
      final result = _isEditing
          ? await api.put('/admin/users/${widget.user!['id']}', payload)
          : await api.postItem('/admin/users', payload);
      widget.onSaved(result);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEditing ? 'Edit User' : 'Add New User',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _states,
                  builder: (context, snap) {
                    final states =
                        (snap.data ?? []).cast<Map<String, dynamic>>();
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _firstCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'First name *',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _lastCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Last name *',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                labelText: 'Email address *',
                                border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _role,
                                  decoration: const InputDecoration(
                                      labelText: 'Role / Position',
                                      border: OutlineInputBorder()),
                                  items: [
                                    for (final r in _kRoles)
                                      DropdownMenuItem<String>(
                                        value: r,
                                        child: Text(r[0].toUpperCase() + r.substring(1)),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _role = v ?? 'agent'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Admin access'),
                                  subtitle: const Text('Can manage all settings',
                                      style: TextStyle(fontSize: 11)),
                                  value: _isAdmin,
                                  onChanged: (v) =>
                                      setState(() => _isAdmin = v ?? false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(label: 'CONTACT'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _mobileCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      labelText: 'Mobile phone',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _officeCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      labelText: 'Office phone',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(label: 'HOME ADDRESS'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _streetCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Street', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _cityCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'City', border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: states.any((s) => s['code'] == _addrState)
                                      ? _addrState
                                      : null,
                                  decoration: const InputDecoration(
                                      labelText: 'State', border: OutlineInputBorder()),
                                  items: [
                                    const DropdownMenuItem<String>(
                                        value: null, child: Text('—')),
                                    for (final s in states)
                                      DropdownMenuItem<String>(
                                        value: s['code'] as String,
                                        child: Text(s['code'] as String),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _addrState = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _zipCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'ZIP', border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(label: 'AGENT NUMBERS'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ssliCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'SSLI Agent Number',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _rgliCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'RGLI Agent Number',
                                      border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Save Changes' : 'Create User'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value, this.sub});
  final IconData icon;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 13)),
                if (sub != null)
                  Text(sub!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, this.large = false});
  final String role;
  final bool large;

  Color get _color => switch (role) {
        'director' => AppColors.warning,
        'manager' => AppColors.primaryLight,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 8 : 5, vertical: large ? 3 : 1),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withAlpha(80)),
      ),
      child: Text(role,
          style: TextStyle(
              fontSize: large ? 12 : 10,
              fontWeight: FontWeight.w600,
              color: _color)),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge({this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 8 : 5, vertical: large ? 3 : 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined,
              size: large ? 12 : 9, color: AppColors.primary),
          SizedBox(width: large ? 4 : 2),
          Text('admin',
              style: TextStyle(
                  fontSize: large ? 12 : 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _StateCountBadge extends StatelessWidget {
  const _StateCountBadge({required this.count, this.large = false});
  final int count;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 6, vertical: large ? 3 : 2),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.primary.withAlpha(40) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count state${count != 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: large ? 12 : 10,
          fontWeight: FontWeight.w600,
          color: count > 0 ? AppColors.primary : AppColors.textDisabled,
        ),
      ),
    );
  }
}

class _StateCodeBadge extends StatelessWidget {
  const _StateCodeBadge({required this.code, required this.covered});
  final String code;
  final bool covered;

  @override
  Widget build(BuildContext context) {
    final color = covered ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(code,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5)),
    );
  }
}

class _CoveragePill extends StatelessWidget {
  const _CoveragePill({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _AgentChip extends StatelessWidget {
  const _AgentChip({required this.agent});
  final Map<String, dynamic> agent;

  @override
  Widget build(BuildContext context) {
    final name =
        '${agent['first_name'] ?? ''} ${agent['last_name'] ?? ''}'.trim();
    final role = agent['role'] as String? ?? '';
    final isAdmin = agent['is_admin'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: AppColors.primary.withAlpha(60),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Text('($role)',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (isAdmin) ...[
            const SizedBox(width: 4),
            const Icon(Icons.shield_outlined, size: 11, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton(
      {required this.icon,
      required this.onPressed,
      required this.tooltip,
      this.color});
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 15, color: color),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: tooltip,
      onPressed: onPressed,
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
                TextField(
                    controller: inputController,
                    decoration: InputDecoration(labelText: inputHint)),
                if (extra != null) ...[const SizedBox(height: 8), extra!],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                      onPressed: onAdd, child: const Text('Quick Add')),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty)
                  return const Center(child: Text('No records'));
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
