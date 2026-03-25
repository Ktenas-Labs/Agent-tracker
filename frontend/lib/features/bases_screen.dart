import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/user_state.dart';
import 'screens.dart';

// ── BasesScreen ──────────────────────────────────────────────────────────────

class BasesScreen extends ConsumerWidget {
  const BasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bases')),
      body: const _BasesTable(),
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

const _kBaseColumns = [
  _ColDef(id: 'name', label: 'Name', minWidth: 140),
  _ColDef(id: 'state', label: 'State', minWidth: 80),
  _ColDef(id: 'address', label: 'Address', minWidth: 140),
  _ColDef(id: 'region_id', label: 'Region', minWidth: 100),
  _ColDef(id: 'latitude', label: 'Latitude', numeric: true, minWidth: 80),
  _ColDef(id: 'longitude', label: 'Longitude', numeric: true, minWidth: 80),
  _ColDef(id: 'notes', label: 'Notes', minWidth: 100),
];

// ── Bases Table ──────────────────────────────────────────────────────────────

class _BasesTable extends ConsumerStatefulWidget {
  const _BasesTable();

  @override
  ConsumerState<_BasesTable> createState() => _BasesTableState();
}

class _BasesTableState extends ConsumerState<_BasesTable> {
  late Future<List<dynamic>> _future = api.getList('/bases');

  String _sortCol = 'name';
  bool _sortAscending = true;

  final Map<String, TextEditingController> _filterCtrls = {
    for (final c in _kBaseColumns) c.id: TextEditingController(),
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
      for (final col in _kBaseColumns) {
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
      _kBaseColumns.firstWhere((c) => c.id == id);

  static String _cellText(dynamic row, _ColDef col) {
    final v = row[col.id];
    if (v == null) return '—';
    if (col.numeric && v is num) return v.toStringAsFixed(4);
    return v.toString();
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

  void _onRowTap(dynamic base) {
    final name = base['name'] as String? ?? 'Unknown Base';
    final id = base['id'] as String? ?? '';
    showDialog(
      context: context,
      builder: (_) => _BaseDetailDialog(base: base, name: name, id: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(basesTablePrefsProvider);
    final prefsNotifier = ref.read(basesTablePrefsProvider.notifier);

    final visibleCols =
        _kBaseColumns.where((c) => prefs.visible[c.id] ?? true).toList();
    final totalWidth = visibleCols.fold<double>(
        0, (s, c) => s + (prefs.widths[c.id] ?? 180.0));

    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading bases: ${snapshot.error}',
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
                    columns: _kBaseColumns,
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
                        final minW = _kBaseColumns
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
                                    ? Icons.location_city_outlined
                                    : Icons.search_off,
                                size: 32,
                                color: AppColors.textDisabled,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allRows.isEmpty
                                    ? 'No bases assigned to your account'
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
                                onTap: () => _onRowTap(rows[i]),
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
  final BasesTablePrefs prefs;
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
  final BasesTablePrefs prefs;
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
                  hintText: 'Filter\u2026',
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
    required this.onTap,
  });

  final dynamic row;
  final List<_ColDef> visibleCols;
  final BasesTablePrefs prefs;
  final bool isEven;
  final VoidCallback onTap;

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hovered = false;

  String _cell(_ColDef col) {
    final v = widget.row[col.id];
    if (v == null) return '—';
    if (col.numeric && v is num) return v.toStringAsFixed(4);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
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
                      color: col.id == 'name'
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: col.id == 'name'
                          ? FontWeight.w600
                          : FontWeight.normal,
                      decoration: col.id == 'name'
                          ? TextDecoration.underline
                          : null,
                      decorationColor:
                          col.id == 'name' ? AppColors.primary : null,
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
  final BasesTablePrefs prefs;
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

// ── Base Detail Dialog ───────────────────────────────────────────────────────

class _BaseDetailDialog extends StatelessWidget {
  const _BaseDetailDialog({
    required this.base,
    required this.name,
    required this.id,
  });

  final dynamic base;
  final String name;
  final String id;

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String)>[
      ('Name', base['name']?.toString() ?? '—'),
      ('State', base['state']?.toString() ?? '—'),
      ('Address', base['address']?.toString() ?? '—'),
      ('Region', base['region_id']?.toString() ?? '—'),
      ('Latitude', base['latitude']?.toString() ?? '—'),
      ('Longitude', base['longitude']?.toString() ?? '—'),
      ('Notes', base['notes']?.toString() ?? '—'),
    ];

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_city_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              for (final (label, value) in fields) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
