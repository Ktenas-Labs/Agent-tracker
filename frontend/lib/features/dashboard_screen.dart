import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/user_state.dart';
import 'briefs_screen.dart';
import 'screens.dart';

// ── Dashboard Screen ──────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<dynamic>> _briefsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = api.getReport('/reports/dashboard');
    _briefsFuture = api.getList('/briefs');
  }

  void _refreshStats() =>
      setState(() => _statsFuture = api.getReport('/reports/dashboard'));

  void _refreshBriefs() =>
      setState(() => _briefsFuture = api.getList('/briefs'));

  void _refreshAll() {
    _refreshStats();
    _refreshBriefs();
  }

  Future<void> _openScheduleDialog() async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScheduleBriefDialog(agentId: user.id),
    );
    if (result == true) _refreshBriefs();
  }

  void _openCustomize() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppColors.border),
      ),
      builder: (_) => const _CustomizeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(dashboardPrefsProvider);
    final visible = prefs.order.where((id) => prefs.isVisible(id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _openCustomize,
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Customize',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (visible.isEmpty) {
            return _EmptyDashboard(onCustomize: _openCustomize);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildLayout(
              visible,
              wide: constraints.maxWidth >= 900,
              medium: constraints.maxWidth >= 600,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLayout(
    List<DashboardWidgetId> ids, {
    required bool wide,
    required bool medium,
  }) {
    final tiles = _buildTiles(ids);

    if (!medium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final id in ids) ...[tiles[id]!, const SizedBox(height: 12)],
        ],
      );
    }

    // On wide screens, statistics spans full width; others pair up.
    if (wide) {
      final rows = <Widget>[];
      final statsPresent = ids.contains(DashboardWidgetId.statistics);
      final others =
          ids.where((id) => id != DashboardWidgetId.statistics).toList();

      if (statsPresent) {
        rows.add(tiles[DashboardWidgetId.statistics]!);
        rows.add(const SizedBox(height: 12));
      }
      for (int i = 0; i < others.length; i += 2) {
        final a = others[i];
        final b = i + 1 < others.length ? others[i + 1] : null;
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[a]!),
                const SizedBox(width: 12),
                Expanded(child: b != null ? tiles[b]! : const SizedBox()),
              ],
            ),
          ),
        );
        rows.add(const SizedBox(height: 12));
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    }

    // Medium: 2 columns, all widgets paired
    final rows = <Widget>[];
    for (int i = 0; i < ids.length; i += 2) {
      final a = ids[i];
      final b = i + 1 < ids.length ? ids[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[a]!),
              const SizedBox(width: 12),
              Expanded(child: b != null ? tiles[b]! : const SizedBox()),
            ],
          ),
        ),
      );
      rows.add(const SizedBox(height: 12));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Map<DashboardWidgetId, Widget> _buildTiles(List<DashboardWidgetId> ids) => {
        DashboardWidgetId.statistics: _StatisticsWidget(
          statsFuture: _statsFuture,
          briefsFuture: _briefsFuture,
          onRefresh: _refreshStats,
        ),
        DashboardWidgetId.upcomingBriefs: _UpcomingBriefsWidget(
          future: _briefsFuture,
          onSchedule: _openScheduleDialog,
          onRefresh: _refreshBriefs,
        ),
        DashboardWidgetId.calendar: _CalendarWidget(
          briefsFuture: _briefsFuture,
        ),
        DashboardWidgetId.inbox: const _InboxWidget(),
      };
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onCustomize});
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.widgets_outlined,
              size: 52, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          const Text('No widgets visible',
              style: TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onCustomize,
            icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
            label: const Text('Customize Dashboard'),
          ),
        ],
      ),
    );
  }
}

// ── Widget card frame ─────────────────────────────────────────────────────────

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32, color: AppColors.error),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Statistics widget ─────────────────────────────────────────────────────────

enum _StatPeriod { month, quarter, year }

extension _StatPeriodLabel on _StatPeriod {
  String get label => switch (this) {
        _StatPeriod.month => 'This Month',
        _StatPeriod.quarter => 'This Quarter',
        _StatPeriod.year => 'This Year',
      };

  String get short => switch (this) {
        _StatPeriod.month => 'MTD',
        _StatPeriod.quarter => 'QTD',
        _StatPeriod.year => 'YTD',
      };

  DateTime get startDate {
    final now = DateTime.now();
    return switch (this) {
      _StatPeriod.month => DateTime(now.year, now.month, 1),
      _StatPeriod.quarter =>
        DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1),
      _StatPeriod.year => DateTime(now.year, 1, 1),
    };
  }
}

class _StatisticsWidget extends StatefulWidget {
  const _StatisticsWidget({
    required this.statsFuture,
    required this.briefsFuture,
    required this.onRefresh,
  });

  final Future<Map<String, dynamic>> statsFuture;
  final Future<List<dynamic>> briefsFuture;
  final VoidCallback onRefresh;

  @override
  State<_StatisticsWidget> createState() => _StatisticsWidgetState();
}

class _StatisticsWidgetState extends State<_StatisticsWidget> {
  _StatPeriod _period = _StatPeriod.month;

  int _countBriefs(List<dynamic> briefs, {String? status}) {
    final start = _period.startDate;
    return briefs.where((b) {
      final dateStr = b['brief_date'] as String?;
      if (dateStr == null) return false;
      try {
        final date = DateTime.parse(dateStr);
        if (date.isBefore(start)) return false;
        if (status != null && b['status'] != status) return false;
        return true;
      } catch (_) {
        return false;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final periodSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in _StatPeriod.values)
          GestureDetector(
            onTap: () => setState(() => _period = p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: _period == p
                    ? AppColors.primary
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                p.short,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _period == p ? Colors.white : AppColors.textDisabled,
                ),
              ),
            ),
          ),
      ],
    );

    return _WidgetCard(
      title: 'Statistics',
      icon: Icons.bar_chart_outlined,
      action: periodSelector,
      child: FutureBuilder<List<dynamic>>(
        future: widget.briefsFuture,
        builder: (context, briefsSnap) {
          return FutureBuilder<Map<String, dynamic>>(
            future: widget.statsFuture,
            builder: (context, statsSnap) {
              if (briefsSnap.connectionState == ConnectionState.waiting ||
                  statsSnap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (statsSnap.hasError) {
                return _ErrorState(
                    error: '${statsSnap.error}',
                    onRetry: widget.onRefresh);
              }

              final stats = statsSnap.data ?? {};
              final briefs = briefsSnap.data ?? [];
              final briefsHeld =
                  _countBriefs(briefs, status: 'completed').toString();
              final briefsScheduled =
                  _countBriefs(briefs).toString();
              final callsTotal =
                  (stats['conversations_total'] ?? 0).toString();
              final unitsTotal = (stats['units_total'] ?? 0).toString();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount =
                      constraints.maxWidth >= 480 ? 4 : 2;
                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: crossCount == 4 ? 1.3 : 1.6,
                      children: [
                        _StatCard(
                          label: 'Briefs Held',
                          value: briefsHeld,
                          icon: Icons.event_available_outlined,
                          color: AppColors.primary,
                          period: _period.label,
                        ),
                        _StatCard(
                          label: 'Briefs Scheduled',
                          value: briefsScheduled,
                          icon: Icons.event_note_outlined,
                          color: const Color(0xFF8B5CF6),
                          period: _period.label,
                        ),
                        _StatCard(
                          label: 'Calls Made',
                          value: callsTotal,
                          icon: Icons.phone_outlined,
                          color: AppColors.success,
                          period: 'All time',
                        ),
                        _StatCard(
                          label: 'Units Covered',
                          value: unitsTotal,
                          icon: Icons.location_city_outlined,
                          color: AppColors.warning,
                          period: 'All time',
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.period,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String period;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            period,
            style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ── Upcoming Briefs widget ─────────────────────────────────────────────────────

class _UpcomingBriefsWidget extends StatelessWidget {
  const _UpcomingBriefsWidget({
    required this.future,
    required this.onSchedule,
    required this.onRefresh,
  });

  final Future<List<dynamic>> future;
  final VoidCallback onSchedule;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      title: 'Upcoming Briefs',
      icon: Icons.event_note_outlined,
      action: FilledButton.icon(
        onPressed: onSchedule,
        icon: const Icon(Icons.add, size: 14),
        label: const Text('Schedule'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(fontSize: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return _ErrorState(
                error: '${snap.error}', onRetry: onRefresh);
          }

          final now = DateTime.now().subtract(const Duration(days: 1));
          final upcoming = (snap.data ?? []).where((b) {
            final status = b['status'] as String? ?? '';
            if (status == 'completed' || status == 'cancelled') return false;
            final dateStr = b['brief_date'] as String?;
            if (dateStr == null) return true; // drafts without a date
            try {
              return !DateTime.parse(dateStr).isBefore(now);
            } catch (_) {
              return false;
            }
          }).toList()
            ..sort((a, b) {
              // Drafts (no date) sort to the end
              final aD = DateTime.tryParse(a['brief_date'] as String? ?? '') ??
                  DateTime(9999);
              final bD = DateTime.tryParse(b['brief_date'] as String? ?? '') ??
                  DateTime(9999);
              return aD.compareTo(bD);
            });

          if (upcoming.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_busy_outlined,
                      size: 36, color: AppColors.textDisabled),
                  const SizedBox(height: 10),
                  const Text('No upcoming briefs',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextButton(
                      onPressed: onSchedule,
                      child: const Text('Schedule one now')),
                ],
              ),
            );
          }

          final display = upcoming.take(6).toList();
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: display.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _BriefListTile(brief: display[i]),
          );
        },
      ),
    );
  }
}

class _BriefListTile extends StatelessWidget {
  const _BriefListTile({required this.brief});
  final dynamic brief;

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatTime(String iso) {
    final parts = iso.split(':');
    if (parts.length < 2) return iso;
    var h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = brief['brief_date'] as String?;
    final timeStr = brief['start_time'] as String?;
    DateTime? date;
    if (dateStr != null) {
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {}
    }
    final title = (brief['brief_title'] as String?)?.trim();
    final displayTitle =
        (title != null && title.isNotEmpty) ? title : 'Untitled Brief';
    final status = brief['status'] as String? ?? 'scheduled';

    final (statusColor, statusLabel) = switch (status) {
      'draft' => (AppColors.textDisabled, 'Draft'),
      'outreach' => (const Color(0xFF8B5CF6), 'Outreach'),
      'scheduled' => (AppColors.primary, 'Scheduled'),
      'completed' => (AppColors.success, 'Done'),
      'cancelled' => (AppColors.error, 'Cancelled'),
      'rescheduled' => (AppColors.warning, 'Rescheduled'),
      _ => (AppColors.textSecondary, status),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          if (date != null) ...[
            SizedBox(
              width: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _months[date.month],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            const SizedBox(
              width: 36,
              child: Icon(Icons.edit_note_outlined,
                  size: 22, color: AppColors.textDisabled),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (timeStr != null)
                  Text(
                    _formatTime(timeStr),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withAlpha(80)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar widget ───────────────────────────────────────────────────────────

class _CalendarWidget extends StatefulWidget {
  const _CalendarWidget({required this.briefsFuture});
  final Future<List<dynamic>> briefsFuture;

  @override
  State<_CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<_CalendarWidget> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _prev() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));

  void _next() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_monthNames[_month.month - 1]} ${_month.year}';

    return _WidgetCard(
      title: 'Calendar',
      icon: Icons.calendar_month_outlined,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: IconButton(
              onPressed: _prev,
              icon: const Icon(Icons.chevron_left, size: 16),
              padding: EdgeInsets.zero,
            ),
          ),
          Text(
            monthLabel,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          SizedBox(
            width: 26,
            height: 26,
            child: IconButton(
              onPressed: _next,
              icon: const Icon(Icons.chevron_right, size: 16),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      child: FutureBuilder<List<dynamic>>(
        future: widget.briefsFuture,
        builder: (context, snap) {
          final briefDates = <DateTime>[];
          for (final b in snap.data ?? []) {
            final dateStr = b['brief_date'] as String?;
            if (dateStr != null) {
              try {
                briefDates.add(DateTime.parse(dateStr));
              } catch (_) {}
            }
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: _CalendarGrid(month: _month, briefDates: briefDates),
          );
        },
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.month, required this.briefDates});
  final DateTime month;
  final List<DateTime> briefDates;

  static const _dayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dart weekday: Mon=1..Sun=7. We want Sun=0..Sat=6.
    final startOffset = firstDay.weekday % 7;
    final today = DateTime.now();
    final totalRows = ((startOffset + daysInMonth) / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Day-of-week headers
        Row(
          children: [
            for (final h in _dayHeaders)
              Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Weeks
        for (int row = 0; row < totalRows; row++) ...[
          Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 30));
              }
              final date = DateTime(month.year, month.month, day);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final hasBrief = briefDates.any((b) =>
                  b.year == date.year &&
                  b.month == date.month &&
                  b.day == date.day);
              return Expanded(
                child: _DayCell(
                    day: day, isToday: isToday, hasBrief: hasBrief),
              );
            }),
          ),
          if (row < totalRows - 1) const SizedBox(height: 2),
        ],
        // Legend
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Today',
                style: TextStyle(
                    fontSize: 10, color: AppColors.textDisabled)),
            const SizedBox(width: 14),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
                border:
                    Border.all(color: AppColors.primary.withAlpha(120)),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Brief',
                style: TextStyle(
                    fontSize: 10, color: AppColors.textDisabled)),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(
      {required this.day, required this.isToday, required this.hasBrief});
  final int day;
  final bool isToday;
  final bool hasBrief;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Color textColor = AppColors.textSecondary;

    if (isToday) {
      bg = AppColors.primary;
      textColor = Colors.white;
    } else if (hasBrief) {
      bg = AppColors.primary.withAlpha(50);
      textColor = AppColors.primaryLight;
    }

    return Container(
      height: 30,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: hasBrief && !isToday
            ? Border.all(color: AppColors.primary.withAlpha(120))
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            color: textColor,
            fontWeight:
                isToday || hasBrief ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Inbox widget ──────────────────────────────────────────────────────────────

class _InboxWidget extends StatelessWidget {
  const _InboxWidget();

  @override
  Widget build(BuildContext context) {
    return _WidgetCard(
      title: 'Inbox',
      icon: Icons.mail_outline,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.mail_lock_outlined,
                  size: 24, color: AppColors.textDisabled),
            ),
            const SizedBox(height: 12),
            const Text(
              'No connected email',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Connect your email account to view\nmessages and leads here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textDisabled, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.link, size: 15),
              label: const Text('Connect Email'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customize sheet ───────────────────────────────────────────────────────────

class _CustomizeSheet extends ConsumerWidget {
  const _CustomizeSheet();

  static IconData _iconFor(DashboardWidgetId id) => switch (id) {
        DashboardWidgetId.statistics => Icons.bar_chart_outlined,
        DashboardWidgetId.upcomingBriefs => Icons.event_note_outlined,
        DashboardWidgetId.calendar => Icons.calendar_month_outlined,
        DashboardWidgetId.inbox => Icons.mail_outline,
      };

  static String _labelFor(DashboardWidgetId id) => switch (id) {
        DashboardWidgetId.statistics => 'Statistics',
        DashboardWidgetId.upcomingBriefs => 'Upcoming Briefs',
        DashboardWidgetId.calendar => 'Calendar',
        DashboardWidgetId.inbox => 'Inbox',
      };

  static String _descFor(DashboardWidgetId id) => switch (id) {
        DashboardWidgetId.statistics =>
          'Briefs held, calls made, units covered',
        DashboardWidgetId.upcomingBriefs =>
          'Scheduled briefs + quick-schedule action',
        DashboardWidgetId.calendar =>
          'Monthly calendar with brief dates',
        DashboardWidgetId.inbox => 'Email inbox (connect account to use)',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dashboardPrefsProvider);
    final notifier = ref.read(dashboardPrefsProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Customize Dashboard',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: notifier.reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Toggle visibility or drag   to reorder widgets.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textDisabled),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollCtrl,
                onReorder: notifier.reorder,
                itemCount: prefs.order.length,
                itemBuilder: (context, i) {
                  final id = prefs.order[i];
                  final visible = prefs.isVisible(id);
                  return ListTile(
                    key: ValueKey(id),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: visible
                            ? AppColors.primary.withAlpha(30)
                            : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconFor(id),
                        size: 18,
                        color: visible
                            ? AppColors.primary
                            : AppColors.textDisabled,
                      ),
                    ),
                    title: Text(
                      _labelFor(id),
                      style: TextStyle(
                        color: visible
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                      ),
                    ),
                    subtitle: Text(_descFor(id),
                        style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: visible,
                          onChanged: (_) => notifier.toggle(id),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.drag_handle,
                            color: AppColors.textDisabled, size: 20),
                      ],
                    ),
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
