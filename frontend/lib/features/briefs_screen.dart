import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/user_state.dart';
import 'screens.dart';

// ── BriefsScreen ─────────────────────────────────────────────────────────────

class BriefsScreen extends ConsumerWidget {
  const BriefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Briefs'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: FilledButton.icon(
              onPressed: user == null
                  ? null
                  : () => _openScheduleDialog(context, user.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Schedule Brief'),
            ),
          ),
        ],
      ),
      body: const _BriefsTable(),
    );
  }

  void _openScheduleDialog(BuildContext context, String agentId) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScheduleBriefDialog(agentId: agentId),
    );
  }
}

// ── Column definitions ───────────────────────────────────────────────────────

class _ColDef {
  final String id;
  final String label;
  final bool numeric;
  final double minWidth;

  const _ColDef({
    required this.id,
    required this.label,
    this.numeric = false,
    this.minWidth = 60,
  });
}

const _kBriefColumns = [
  _ColDef(id: 'brief_title', label: 'Title', minWidth: 120),
  _ColDef(id: 'brief_date', label: 'Date', minWidth: 90),
  _ColDef(id: 'start_time', label: 'Time', minWidth: 80),
  _ColDef(id: 'status', label: 'Status', minWidth: 80),
  _ColDef(id: 'alt_address_state', label: 'State', minWidth: 80),
  _ColDef(id: 'alt_address_city', label: 'City', minWidth: 80),
  _ColDef(id: 'expected_pax', label: 'Exp. Attendees', numeric: true, minWidth: 60),
  _ColDef(id: 'last_briefed_date', label: 'Last Briefed', minWidth: 100),
  _ColDef(id: 'notes', label: 'Notes', minWidth: 100),
];

// ── Briefs Table ─────────────────────────────────────────────────────────────

class _BriefsTable extends ConsumerStatefulWidget {
  const _BriefsTable();

  @override
  ConsumerState<_BriefsTable> createState() => _BriefsTableState();
}

class _BriefsTableState extends ConsumerState<_BriefsTable> {
  late Future<List<dynamic>> _future = api.getList('/briefs');

  String _sortCol = 'brief_date';
  bool _sortAscending = true;

  final Map<String, TextEditingController> _filterCtrls = {
    for (final c in _kBriefColumns) c.id: TextEditingController(),
  };

  final _hScrollHeader = ScrollController();
  final _hScrollBody = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _hScrollHeader.addListener(_syncH2B);
    _hScrollBody.addListener(_syncB2H);
  }

  void _syncH2B() {
    if (_syncing) return;
    _syncing = true;
    if (_hScrollBody.hasClients &&
        _hScrollBody.offset != _hScrollHeader.offset) {
      _hScrollBody.jumpTo(_hScrollHeader.offset);
    }
    _syncing = false;
  }

  void _syncB2H() {
    if (_syncing) return;
    _syncing = true;
    if (_hScrollHeader.hasClients &&
        _hScrollHeader.offset != _hScrollBody.offset) {
      _hScrollHeader.jumpTo(_hScrollBody.offset);
    }
    _syncing = false;
  }

  @override
  void dispose() {
    _hScrollHeader.dispose();
    _hScrollBody.dispose();
    for (final c in _filterCtrls.values) c.dispose();
    super.dispose();
  }

  List<dynamic> _process(List<dynamic> data) {
    var rows = data.where((b) {
      for (final col in _kBriefColumns) {
        final q = _filterCtrls[col.id]!.text.trim().toLowerCase();
        if (q.isEmpty) continue;
        final v = _cellText(b, col).toLowerCase();
        if (!v.contains(q)) return false;
      }
      return true;
    }).toList();

    rows.sort((a, b) {
      final av = _cellText(a, _colById(_sortCol)).toLowerCase();
      final bv = _cellText(b, _colById(_sortCol)).toLowerCase();
      return _sortAscending ? av.compareTo(bv) : bv.compareTo(av);
    });

    return rows;
  }

  _ColDef _colById(String id) =>
      _kBriefColumns.firstWhere((c) => c.id == id);

  static String _cellText(dynamic row, _ColDef col) {
    final v = row[col.id];
    if (v == null) return '—';
    if (col.numeric && v is num) return v.toString();
    if (col.id == 'start_time' && v is String) return _formatTimeStr(v);
    return v.toString();
  }

  static String _formatTimeStr(String iso) {
    final parts = iso.split(':');
    if (parts.length < 2) return iso;
    var h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    return '$h:$m $period';
  }

  void _onSort(String colId) {
    setState(() {
      if (_sortCol == colId) {
        _sortAscending = !_sortAscending;
      } else {
        _sortCol = colId;
        _sortAscending = true;
      }
    });
  }

  bool _anyFilter() =>
      _filterCtrls.values.any((c) => c.text.trim().isNotEmpty);

  void _clearFilters() {
    for (final c in _filterCtrls.values) c.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(briefsTablePrefsProvider);
    final prefsNotifier = ref.read(briefsTablePrefsProvider.notifier);

    final visibleCols =
        _kBriefColumns.where((c) => prefs.visible[c.id] ?? true).toList();
    final totalWidth = visibleCols.fold<double>(
        0, (s, c) => s + (prefs.widths[c.id] ?? 180.0));

    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading briefs: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        final allRows = snapshot.data ?? [];
        final rows = _process(allRows);

        return Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  if (_anyFilter())
                    TextButton.icon(
                      icon: const Icon(Icons.filter_alt_off_outlined,
                          size: 16),
                      label: const Text('Clear filters'),
                      onPressed: _clearFilters,
                    ),
                  _ColumnsButton(
                    columns: _kBriefColumns,
                    prefs: prefs,
                    onToggle: prefsNotifier.setVisible,
                    onReset: prefsNotifier.reset,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _hScrollHeader,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderRow(
                      visibleCols: visibleCols,
                      prefs: prefs,
                      sortCol: _sortCol,
                      sortAscending: _sortAscending,
                      onSort: _onSort,
                      onResize: (id, dx) {
                        final minW = _kBriefColumns
                            .firstWhere((c) => c.id == id)
                            .minWidth;
                        prefsNotifier.setWidth(
                          id,
                          ((prefs.widths[id] ?? 180.0) + dx)
                              .clamp(minW, 600.0),
                        );
                      },
                    ),
                    _FilterRow(
                      visibleCols: visibleCols,
                      prefs: prefs,
                      filterCtrls: _filterCtrls,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: !snapshot.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                allRows.isEmpty
                                    ? Icons.event_note_outlined
                                    : Icons.search_off,
                                size: 32,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allRows.isEmpty
                                    ? 'No briefs scheduled'
                                    : 'No results match the active filters.',
                                style: const TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _hScrollBody,
                          child: SizedBox(
                            width: totalWidth,
                            child: ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (ctx, i) => _DataRow(
                                row: rows[i],
                                visibleCols: visibleCols,
                                prefs: prefs,
                                isEven: i.isEven,
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Header Row ───────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.visibleCols,
    required this.prefs,
    required this.sortCol,
    required this.sortAscending,
    required this.onSort,
    required this.onResize,
  });

  final List<_ColDef> visibleCols;
  final BriefsTablePrefs prefs;
  final String sortCol;
  final bool sortAscending;
  final void Function(String colId) onSort;
  final void Function(String colId, double dx) onResize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppColors.surfaceLow,
      child: Row(
        children: visibleCols.map((col) {
          final width = prefs.widths[col.id] ?? 180.0;
          return SizedBox(
            width: width,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InkWell(
                    onTap: () => onSort(col.id),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 16),
                      child: Row(
                        mainAxisAlignment: col.numeric
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              col.label.toUpperCase(),
                              style: TextStyle(
                                color: sortCol == col.id
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sortCol == col.id) ...[
                            const SizedBox(width: 4),
                            Icon(
                              sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 11,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (d) =>
                        onResize(col.id, d.delta.dx),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: Center(
                        child: Container(
                          width: 1,
                          height: 16,
                          color: AppColors.border,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Filter Row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.visibleCols,
    required this.prefs,
    required this.filterCtrls,
    required this.onChanged,
  });

  final List<_ColDef> visibleCols;
  final BriefsTablePrefs prefs;
  final Map<String, TextEditingController> filterCtrls;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border:
            Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: visibleCols.map((col) {
          final width = prefs.widths[col.id] ?? 180.0;
          return SizedBox(
            width: width,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TextField(
                controller: filterCtrls[col.id],
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Filter…',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 0),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                        color: AppColors.border.withAlpha(100)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  hintStyle: const TextStyle(
                      fontSize: 12, color: AppColors.textDisabled),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Data Row ─────────────────────────────────────────────────────────────────

class _DataRow extends StatefulWidget {
  const _DataRow({
    required this.row,
    required this.visibleCols,
    required this.prefs,
    required this.isEven,
  });

  final dynamic row;
  final List<_ColDef> visibleCols;
  final BriefsTablePrefs prefs;
  final bool isEven;

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hovered = false;

  static const _statusColors = {
    'draft': AppColors.textDisabled,
    'outreach': Color(0xFF8B5CF6),
    'scheduled': AppColors.primary,
    'completed': AppColors.success,
    'cancelled': AppColors.error,
    'rescheduled': AppColors.warning,
  };

  String _cell(_ColDef col) {
    final v = widget.row[col.id];
    if (v == null) return '—';
    if (col.numeric && v is num) return v.toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surfaceHigh
              : widget.isEven
                  ? Colors.transparent
                  : const Color(0x08FFFFFF),
          border: Border(
            bottom: BorderSide(
                color: AppColors.border.withAlpha(50), width: 1),
          ),
        ),
        child: Row(
          children: widget.visibleCols.map((col) {
            final width = widget.prefs.widths[col.id] ?? 180.0;
            final text = _cell(col);

            if (col.id == 'status') {
              final color =
                  _statusColors[text.toLowerCase()] ?? AppColors.textSecondary;
              return SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }

            return SizedBox(
              width: width,
              child: Padding(
                padding: EdgeInsets.only(
                  left: col.numeric ? 0 : 12,
                  right: col.numeric ? 12 : 4,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: col.id == 'brief_title'
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: col.id == 'brief_title'
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                  textAlign:
                      col.numeric ? TextAlign.end : TextAlign.start,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Columns selector button ──────────────────────────────────────────────────

class _ColumnsButton extends StatelessWidget {
  const _ColumnsButton({
    required this.columns,
    required this.prefs,
    required this.onToggle,
    required this.onReset,
  });

  final List<_ColDef> columns;
  final BriefsTablePrefs prefs;
  final void Function(String id, bool visible) onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Columns',
      offset: const Offset(0, 42),
      icon: const Icon(Icons.view_column_outlined),
      itemBuilder: (_) => [
        for (final col in columns)
          PopupMenuItem<String>(
            value: col.id,
            padding: EdgeInsets.zero,
            onTap: () => onToggle(col.id, !(prefs.visible[col.id] ?? true)),
            child: CheckboxListTile(
              value: prefs.visible[col.id] ?? true,
              onChanged: (v) {
                if (v != null) onToggle(col.id, v);
              },
              title:
                  Text(col.label, style: const TextStyle(fontSize: 13)),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__reset__',
          onTap: onReset,
          child: const Row(
            children: [
              Icon(Icons.refresh, size: 14),
              SizedBox(width: 8),
              Text('Reset columns', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Schedule Brief Dialog ────────────────────────────────────────────────────

class ScheduleBriefDialog extends StatefulWidget {
  const ScheduleBriefDialog({super.key, required this.agentId});
  final String agentId;

  @override
  State<ScheduleBriefDialog> createState() => _ScheduleBriefDialogState();
}

class _ScheduleBriefDialogState extends State<ScheduleBriefDialog> {
  List<String> _assignedStates = [];
  List<Map<String, dynamic>> _allBases = [];
  List<Map<String, dynamic>> _allUnits = [];
  bool _loading = true;
  String? _loadError;

  String? _selectedState;
  String? _selectedBaseId;
  String? _selectedUnitId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _titleCtrl = TextEditingController();

  bool _saving = false;
  String? _saveError;

  List<Map<String, dynamic>> get _filteredBases {
    if (_selectedState == null) return [];
    return _allBases.where((b) => b['state'] == _selectedState).toList();
  }

  List<Map<String, dynamic>> get _filteredUnits {
    if (_selectedBaseId == null) return [];
    return _allUnits.where((u) => u['base_id'] == _selectedBaseId).toList();
  }

  bool get _canSubmit => _selectedUnitId != null && !_saving;

  bool get _hasDate => _selectedDate != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        api.getList('/me/state-assignments'),
        api.getList('/bases'),
        api.getList('/units'),
      ]);
      if (!mounted) return;
      setState(() {
        _assignedStates = results[0].cast<String>();
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

  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final body = <String, dynamic>{
        'assigned_agent_id': widget.agentId,
        'unit_ids': [_selectedUnitId!],
        'contact_ids': [],
        'status': _hasDate ? 'scheduled' : 'draft',
        if (_titleCtrl.text.trim().isNotEmpty)
          'brief_title': _titleCtrl.text.trim(),
      };
      if (_selectedDate != null) {
        final d = _selectedDate!;
        body['brief_date'] =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
      if (_selectedTime != null) {
        body['start_time'] =
            '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      }
      await api.post('/briefs', body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Failed to save brief: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                                style: const TextStyle(
                                    color: AppColors.error)),
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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Create a Brief',
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
            'Select a unit to brief. Date and time are optional\u2009—\u2009'
            'you can save as a draft and fill them in later.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration:
                const InputDecoration(labelText: 'State', isDense: true),
            items: [
              for (final s in _assignedStates)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: _assignedStates.isEmpty ? null : _onStateChanged,
            hint: const Text('Select state'),
            disabledHint: const Text(
              'No states assigned to your account',
              style: TextStyle(color: AppColors.textDisabled),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedBaseId,
            decoration:
                const InputDecoration(labelText: 'Base', isDense: true),
            items: [
              for (final b in _filteredBases)
                DropdownMenuItem<String>(
                  value: b['id'] as String,
                  child:
                      Text(b['name'] as String? ?? b['id'] as String),
                ),
            ],
            onChanged: _selectedState == null ? null : _onBaseChanged,
            hint: const Text('Select base'),
            disabledHint: const Text(
              'Select a state first',
              style: TextStyle(color: AppColors.textDisabled),
            ),
          ),
          const SizedBox(height: 14),
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
                  child:
                      Text(u['name'] as String? ?? u['id'] as String),
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
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date (optional)',
                      isDense: true,
                      suffixIcon: _selectedDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () =>
                                  setState(() => _selectedDate = null),
                              tooltip: 'Clear date',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            )
                          : const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                  Icons.calendar_today_outlined, size: 18),
                            ),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'No date yet'
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Time (optional)',
                      isDense: true,
                      suffixIcon: _selectedTime != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () =>
                                  setState(() => _selectedTime = null),
                              tooltip: 'Clear time',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            )
                          : const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                  Icons.access_time_outlined, size: 18),
                            ),
                    ),
                    child: Text(
                      _selectedTime == null
                          ? 'No time yet'
                          : _formatTime(_selectedTime!),
                      style: TextStyle(
                        color: _selectedTime == null
                            ? AppColors.textDisabled
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!_hasDate) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 13, color: AppColors.primary.withAlpha(180)),
                const SizedBox(width: 6),
                Text(
                  'Without a date this will be saved as a draft.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withAlpha(180),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Brief title (optional)',
              isDense: true,
              hintText: 'e.g. SSLI Retirement Benefits Presentation',
            ),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Color(0xFFEF4444).withAlpha(60)),
              ),
              child: Text(
                _saveError!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed:
                    _saving ? null : () => Navigator.of(context).pop(false),
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
                    : Icon(
                        _hasDate
                            ? Icons.event_available_outlined
                            : Icons.drafts_outlined,
                        size: 18,
                      ),
                label: Text(_hasDate ? 'Schedule' : 'Save Draft'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
