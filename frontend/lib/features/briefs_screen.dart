import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/user_state.dart';
import 'screens.dart';

// ── BriefsScreen ──────────────────────────────────────────────────────────────

class BriefsScreen extends ConsumerStatefulWidget {
  const BriefsScreen({super.key});

  @override
  ConsumerState<BriefsScreen> createState() => _BriefsScreenState();
}

class _BriefsScreenState extends ConsumerState<BriefsScreen> {
  late Future<_BriefsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BriefsData> _load() async {
    final results = await Future.wait([
      api.getList('/briefs'),
      api.getList('/regions'),
      api.getList('/bases'),
      api.getList('/units'),
    ]);
    return _BriefsData(
      briefs: results[0],
      regions: results[1],
      bases: results[2],
      units: results[3],
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _openScheduleDialog(String agentId) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScheduleBriefDialog(agentId: agentId),
    );
    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Briefs'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: FilledButton.icon(
              onPressed: user == null ? null : () => _openScheduleDialog(user.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Schedule Brief'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_BriefsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('${snap.error}', style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final data = snap.data!;
          if (data.briefs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_note_outlined, size: 64, color: AppColors.textDisabled),
                  const SizedBox(height: 16),
                  const Text(
                    'No briefs scheduled',
                    style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use "Schedule Brief" to add one.',
                    style: TextStyle(color: AppColors.textDisabled),
                  ),
                ],
              ),
            );
          }
          final regionNames = {
            for (final r in data.regions) r['id'] as String: r['name'] as String? ?? '',
          };
          final baseNames = {
            for (final b in data.bases) b['id'] as String: b['name'] as String? ?? '',
          };
          final unitNames = {
            for (final u in data.units) u['id'] as String: u['name'] as String? ?? '',
          };
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.briefs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final b = data.briefs[i];
              return _BriefCard(
                brief: b,
                regionName: regionNames[b['region_id']] ?? b['region_id'] as String? ?? '—',
                baseName: baseNames[b['base_id']] ?? b['base_id'] as String? ?? '—',
                unitName: unitNames[b['reserve_unit_id']] ?? b['reserve_unit_id'] as String? ?? '—',
              );
            },
          );
        },
      ),
    );
  }
}

class _BriefsData {
  final List<dynamic> briefs;
  final List<dynamic> regions;
  final List<dynamic> bases;
  final List<dynamic> units;

  const _BriefsData({
    required this.briefs,
    required this.regions,
    required this.bases,
    required this.units,
  });
}

// ── BriefCard ─────────────────────────────────────────────────────────────────

class _BriefCard extends StatelessWidget {
  const _BriefCard({
    required this.brief,
    required this.regionName,
    required this.baseName,
    required this.unitName,
  });

  final dynamic brief;
  final String regionName;
  final String baseName;
  final String unitName;

  @override
  Widget build(BuildContext context) {
    final status = brief['status'] as String? ?? 'scheduled';
    final scheduledAt = brief['scheduled_at'] as String?;
    DateTime? date;
    if (scheduledAt != null) {
      try {
        date = DateTime.parse(scheduledAt).toLocal();
      } catch (_) {}
    }
    final location = brief['location'] as String?;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _DateBadge(date: date),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unitName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_city_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          baseName,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.map_outlined, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          regionName,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            style:
                                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(status: status),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});
  final DateTime? date;

  static const _months = [
    '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: date == null
          ? const Center(
              child: Icon(Icons.calendar_today, size: 22, color: AppColors.textDisabled),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _months[date!.month],
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${date!.day}',
                  style: const TextStyle(
                    fontSize: 22,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  '${date!.year}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
                ),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status) {
      'scheduled' => (
          AppColors.primary,
          Color(0xFF3B82F6).withAlpha(30),
          'Scheduled'
        ),
      'completed' => (
          AppColors.success,
          Color(0xFF16A34A).withAlpha(30),
          'Completed'
        ),
      'canceled' => (
          AppColors.error,
          Color(0xFFEF4444).withAlpha(30),
          'Canceled'
        ),
      'rescheduled' => (
          AppColors.warning,
          Color(0xFFEA580C).withAlpha(30),
          'Rescheduled'
        ),
      _ => (AppColors.textSecondary, AppColors.surfaceHigh, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Schedule Brief Dialog ─────────────────────────────────────────────────────

class _ScheduleBriefDialog extends StatefulWidget {
  const _ScheduleBriefDialog({required this.agentId});
  final String agentId;

  @override
  State<_ScheduleBriefDialog> createState() => _ScheduleBriefDialogState();
}

class _ScheduleBriefDialogState extends State<_ScheduleBriefDialog> {
  List<Map<String, dynamic>> _allRegions = [];
  List<Map<String, dynamic>> _allBases = [];
  List<Map<String, dynamic>> _allUnits = [];
  bool _loading = true;
  String? _loadError;

  String? _selectedRegionId;
  String? _selectedState;
  String? _selectedBaseId;
  String? _selectedUnitId;
  DateTime? _selectedDate;
  final _locationCtrl = TextEditingController();

  bool _saving = false;
  String? _saveError;

  // ── Derived getters ────────────────────────────────────────────────────────

  Map<String, dynamic>? get _selectedRegion =>
      _allRegions.where((r) => r['id'] == _selectedRegionId).firstOrNull;

  List<String> get _filteredStates {
    final region = _selectedRegion;
    if (region == null) return [];
    return (region['states'] as List<dynamic>? ?? []).cast<String>();
  }

  List<Map<String, dynamic>> get _filteredBases {
    if (_selectedRegionId == null) return [];
    return _allBases.where((b) => b['region_id'] == _selectedRegionId).toList();
  }

  List<Map<String, dynamic>> get _filteredUnits {
    if (_selectedBaseId == null) return [];
    return _allUnits.where((u) => u['base_id'] == _selectedBaseId).toList();
  }

  bool get _canSubmit =>
      _selectedRegionId != null &&
      _selectedBaseId != null &&
      _selectedUnitId != null &&
      _selectedDate != null &&
      !_saving;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        api.getList('/regions'),
        api.getList('/bases'),
        api.getList('/units'),
      ]);
      if (!mounted) return;
      setState(() {
        _allRegions = results[0].cast<Map<String, dynamic>>();
        _allBases = results[1].cast<Map<String, dynamic>>();
        _allUnits = results[2].cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  void _onRegionChanged(String? id) {
    setState(() {
      _selectedRegionId = id;
      _selectedState = null;
      _selectedBaseId = null;
      _selectedUnitId = null;
    });
  }

  void _onBaseChanged(String? id) {
    setState(() {
      _selectedBaseId = id;
      _selectedUnitId = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await api.post('/briefs', {
        'region_id': _selectedRegionId!,
        'base_id': _selectedBaseId!,
        'reserve_unit_id': _selectedUnitId!,
        'assigned_agent_id': widget.agentId,
        'scheduled_at': DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          9,
        ).toUtc().toIso8601String(),
        if (_locationCtrl.text.trim().isNotEmpty) 'location': _locationCtrl.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Failed to schedule brief: $e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _loadError != null
                  ? SizedBox(
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 36, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(_loadError!,
                                style:
                                    const TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    )
                  : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final hasStates = _filteredStates.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Schedule a Brief',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
                tooltip: 'Cancel',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Use the dropdowns below — each one filters based on your selection above it.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // ── Region ──────────────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            value: _selectedRegionId,
            decoration: const InputDecoration(
              labelText: 'Region',
              isDense: true,
            ),
            items: [
              for (final r in _allRegions)
                DropdownMenuItem<String>(
                  value: r['id'] as String,
                  child: Text(r['name'] as String? ?? r['id'] as String),
                ),
            ],
            onChanged: _onRegionChanged,
            hint: const Text('Select region'),
          ),
          const SizedBox(height: 14),

          // ── State (filtered by region) ───────────────────────────────────
          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration: const InputDecoration(
              labelText: 'State',
              isDense: true,
            ),
            items: [
              for (final s in _filteredStates)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: (_selectedRegionId == null || !hasStates)
                ? null
                : (v) => setState(() => _selectedState = v),
            hint: const Text('Select state'),
            disabledHint: Text(
              _selectedRegionId == null
                  ? 'Select a region first'
                  : 'No states configured for this region',
              style: const TextStyle(color: AppColors.textDisabled),
            ),
          ),
          const SizedBox(height: 14),

          // ── Base (filtered by region) ──────────────────────────────────
          DropdownButtonFormField<String>(
            value: _selectedBaseId,
            decoration: const InputDecoration(
              labelText: 'Base',
              isDense: true,
            ),
            items: [
              for (final b in _filteredBases)
                DropdownMenuItem<String>(
                  value: b['id'] as String,
                  child: Text(b['name'] as String? ?? b['id'] as String),
                ),
            ],
            onChanged: _selectedRegionId == null ? null : _onBaseChanged,
            hint: const Text('Select base'),
            disabledHint: const Text(
              'Select a region first',
              style: TextStyle(color: AppColors.textDisabled),
            ),
          ),
          const SizedBox(height: 14),

          // ── Reserve Unit (filtered by base) ───────────────────────────
          DropdownButtonFormField<String>(
            value: _selectedUnitId,
            decoration: const InputDecoration(
              labelText: 'Reserve Unit',
              isDense: true,
            ),
            items: [
              for (final u in _filteredUnits)
                DropdownMenuItem<String>(
                  value: u['id'] as String,
                  child: Text(u['name'] as String? ?? u['id'] as String),
                ),
            ],
            onChanged: _selectedBaseId == null
                ? null
                : (v) => setState(() => _selectedUnitId = v),
            hint: const Text('Select reserve unit'),
            disabledHint: const Text(
              'Select a base first',
              style: TextStyle(color: AppColors.textDisabled),
            ),
          ),
          const SizedBox(height: 14),

          // ── Date ──────────────────────────────────────────────────────────
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                isDense: true,
                suffixIcon: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.calendar_today_outlined, size: 18),
                ),
              ),
              child: Text(
                _selectedDate == null
                    ? 'Select date'
                    : '${_selectedDate!.year}-'
                        '${_selectedDate!.month.toString().padLeft(2, '0')}-'
                        '${_selectedDate!.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: _selectedDate == null
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Location (optional) ────────────────────────────────────────
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              isDense: true,
              hintText: 'e.g. Building 3, Room 105',
            ),
          ),

          // ── Error ─────────────────────────────────────────────────────────
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFEF4444).withAlpha(60)),
              ),
              child: Text(
                _saveError!,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('Schedule'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
