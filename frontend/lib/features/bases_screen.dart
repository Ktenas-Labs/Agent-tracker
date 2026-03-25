import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/user_state.dart';
import 'screens.dart' show api;

// ── Column definitions ─────────────────────────────────────────────────────────

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

const _kColumns = [
  _ColDef(id: 'name', label: 'Name', minWidth: 80),
  _ColDef(id: 'address', label: 'Address', minWidth: 80),
  _ColDef(id: 'region_id', label: 'Region', minWidth: 60),
  _ColDef(id: 'latitude', label: 'Lat', numeric: true, minWidth: 60),
  _ColDef(id: 'longitude', label: 'Lng', numeric: true, minWidth: 60),
  _ColDef(id: 'notes', label: 'Notes', minWidth: 80),
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class BasesScreen extends ConsumerStatefulWidget {
  const BasesScreen({super.key});

  @override
  ConsumerState<BasesScreen> createState() => _BasesScreenState();
}

class _BasesScreenState extends ConsumerState<BasesScreen> {
  late Future<List<dynamic>> _future = api.getList('/bases');

  String _sortCol = 'name';
  bool _sortAscending = true;

  final Map<String, TextEditingController> _filterCtrls = {
    for (final c in _kColumns) c.id: TextEditingController(),
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
    if (_hScrollBody.hasClients && _hScrollBody.offset != _hScrollHeader.offset) {
      _hScrollBody.jumpTo(_hScrollHeader.offset);
    }
    _syncing = false;
  }

  void _syncB2H() {
    if (_syncing) return;
    _syncing = true;
    if (_hScrollHeader.hasClients && _hScrollHeader.offset != _hScrollBody.offset) {
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
      for (final col in _kColumns) {
        final q = _filterCtrls[col.id]!.text.trim().toLowerCase();
        if (q.isEmpty) continue;
        final v = (b[col.id] ?? '').toString().toLowerCase();
        if (!v.contains(q)) return false;
      }
      return true;
    }).toList();

    rows.sort((a, b) {
      final av = (a[_sortCol] ?? '').toString();
      final bv = (b[_sortCol] ?? '').toString();
      return _sortAscending ? av.compareTo(bv) : bv.compareTo(av);
    });

    return rows;
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
    final prefs = ref.watch(basesTablePrefsProvider);
    final prefsNotifier = ref.read(basesTablePrefsProvider.notifier);

    final visibleCols =
        _kColumns.where((c) => prefs.visible[c.id] ?? true).toList();
    final totalWidth =
        visibleCols.fold<double>(0, (s, c) => s + (prefs.widths[c.id] ?? 180.0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bases'),
        actions: [
          if (_anyFilter())
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Clear filters'),
              onPressed: _clearFilters,
            ),
          _ColumnsButton(
            columns: _kColumns,
            prefs: prefs,
            onToggle: prefsNotifier.setVisible,
            onReset: prefsNotifier.reset,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
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
              // ── Sticky header + filter rows ──────────────────────────────
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
                          final minW = _kColumns
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
              // ── Body ─────────────────────────────────────────────────────
              Expanded(
                child: !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off,
                                    size: 32,
                                    color: AppColors.textDisabled),
                                const SizedBox(height: 8),
                                Text(
                                  allRows.isEmpty
                                      ? 'No bases found.'
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
      ),
    );
  }
}

// ── Header Row ─────────────────────────────────────────────────────────────────

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
                // Resize handle
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (d) => onResize(col.id, d.delta.dx),
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

// ── Filter Row ─────────────────────────────────────────────────────────────────

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
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: visibleCols.map((col) {
          final width = prefs.widths[col.id] ?? 180.0;
          return SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TextField(
                controller: filterCtrls[col.id],
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Filter…',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: AppColors.border.withAlpha(100)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
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

// ── Data Row ───────────────────────────────────────────────────────────────────

class _DataRow extends StatefulWidget {
  const _DataRow({
    required this.row,
    required this.visibleCols,
    required this.prefs,
    required this.isEven,
  });

  final dynamic row;
  final List<_ColDef> visibleCols;
  final BasesTablePrefs prefs;
  final bool isEven;

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
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surfaceHigh
              : widget.isEven
                  ? Colors.transparent
                  : const Color(0x08FFFFFF),
          border: Border(
            bottom: BorderSide(color: AppColors.border.withAlpha(50), width: 1),
          ),
        ),
        child: Row(
          children: widget.visibleCols.map((col) {
            final width = widget.prefs.widths[col.id] ?? 180.0;
            return SizedBox(
              width: width,
              child: Padding(
                padding: EdgeInsets.only(
                  left: col.numeric ? 0 : 12,
                  right: col.numeric ? 12 : 4,
                ),
                child: Text(
                  _cell(col),
                  style: TextStyle(
                    fontSize: 13,
                    color: col.id == 'name'
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: col.id == 'name'
                        ? FontWeight.w500
                        : FontWeight.normal,
                    fontFamily: col.id == 'region_id' ? 'monospace' : null,
                  ),
                  textAlign: col.numeric ? TextAlign.end : TextAlign.start,
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

// ── Columns selector button ────────────────────────────────────────────────────

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
              title: Text(col.label, style: const TextStyle(fontSize: 13)),
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
