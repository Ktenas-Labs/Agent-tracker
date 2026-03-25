import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── UserProfile ────────────────────────────────────────────────────────────────

class UserProfile {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final bool isAdmin;

  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.isAdmin = false,
  });

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  String get displayName => '$firstName $lastName'.trim();
}

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier() : super(null);

  void setUser(UserProfile user) => state = user;
  void clearUser() => state = null;
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile?>(
  (ref) => UserProfileNotifier(),
);

// ── UserPreferences ────────────────────────────────────────────────────────────

class UserPreferences {
  final bool compactMode;
  final bool sidebarCollapsedByDefault;
  final bool showRoleBadge;

  const UserPreferences({
    this.compactMode = false,
    this.sidebarCollapsedByDefault = false,
    this.showRoleBadge = true,
  });

  UserPreferences copyWith({
    bool? compactMode,
    bool? sidebarCollapsedByDefault,
    bool? showRoleBadge,
  }) =>
      UserPreferences(
        compactMode: compactMode ?? this.compactMode,
        sidebarCollapsedByDefault: sidebarCollapsedByDefault ?? this.sidebarCollapsedByDefault,
        showRoleBadge: showRoleBadge ?? this.showRoleBadge,
      );
}

class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  UserPreferencesNotifier() : super(const UserPreferences());

  void toggleCompactMode() =>
      state = state.copyWith(compactMode: !state.compactMode);

  void toggleSidebarCollapsedByDefault() =>
      state = state.copyWith(sidebarCollapsedByDefault: !state.sidebarCollapsedByDefault);

  void toggleShowRoleBadge() =>
      state = state.copyWith(showRoleBadge: !state.showRoleBadge);
}

final userPreferencesProvider =
    StateNotifierProvider<UserPreferencesNotifier, UserPreferences>(
  (ref) => UserPreferencesNotifier(),
);

// ── BasesTablePrefs ────────────────────────────────────────────────────────────

class BasesTablePrefs {
  final Map<String, bool> visible;
  final Map<String, double> widths;

  static const _defaultVisible = {
    'name': true,
    'state': true,
    'address': true,
    'region_id': true,
    'latitude': false,
    'longitude': false,
    'notes': false,
  };

  static const _defaultWidths = {
    'name': 200.0,
    'state': 140.0,
    'address': 220.0,
    'region_id': 160.0,
    'latitude': 110.0,
    'longitude': 110.0,
    'notes': 240.0,
  };

  const BasesTablePrefs({required this.visible, required this.widths});

  factory BasesTablePrefs.defaults() => BasesTablePrefs(
        visible: Map.from(_defaultVisible),
        widths: Map.from(_defaultWidths),
      );

  BasesTablePrefs setVisible(String col, bool v) =>
      BasesTablePrefs(visible: {...visible, col: v}, widths: widths);

  BasesTablePrefs setWidth(String col, double w) =>
      BasesTablePrefs(visible: visible, widths: {...widths, col: w});
}

class BasesTablePrefsNotifier extends StateNotifier<BasesTablePrefs> {
  BasesTablePrefsNotifier() : super(BasesTablePrefs.defaults());

  void setVisible(String col, bool v) => state = state.setVisible(col, v);
  void setWidth(String col, double w) => state = state.setWidth(col, w);
  void reset() => state = BasesTablePrefs.defaults();
}

final basesTablePrefsProvider =
    StateNotifierProvider<BasesTablePrefsNotifier, BasesTablePrefs>(
  (ref) => BasesTablePrefsNotifier(),
);

// ── BriefsTablePrefs ───────────────────────────────────────────────────────────

class BriefsTablePrefs {
  final Map<String, bool> visible;
  final Map<String, double> widths;

  static const _defaultVisible = {
    'brief_title': true,
    'brief_date': true,
    'status': true,
    'alt_address_state': true,
    'alt_address_city': true,
    'expected_pax': true,
    'notes': false,
  };

  static const _defaultWidths = {
    'brief_title': 220.0,
    'brief_date': 120.0,
    'status': 120.0,
    'alt_address_state': 120.0,
    'alt_address_city': 160.0,
    'expected_pax': 80.0,
    'notes': 240.0,
  };

  const BriefsTablePrefs({required this.visible, required this.widths});

  factory BriefsTablePrefs.defaults() => BriefsTablePrefs(
        visible: Map.from(_defaultVisible),
        widths: Map.from(_defaultWidths),
      );

  BriefsTablePrefs setVisible(String col, bool v) =>
      BriefsTablePrefs(visible: {...visible, col: v}, widths: widths);

  BriefsTablePrefs setWidth(String col, double w) =>
      BriefsTablePrefs(visible: visible, widths: {...widths, col: w});
}

class BriefsTablePrefsNotifier extends StateNotifier<BriefsTablePrefs> {
  BriefsTablePrefsNotifier() : super(BriefsTablePrefs.defaults());

  void setVisible(String col, bool v) => state = state.setVisible(col, v);
  void setWidth(String col, double w) => state = state.setWidth(col, w);
  void reset() => state = BriefsTablePrefs.defaults();
}

final briefsTablePrefsProvider =
    StateNotifierProvider<BriefsTablePrefsNotifier, BriefsTablePrefs>(
  (ref) => BriefsTablePrefsNotifier(),
);

// ── DashboardPrefs ─────────────────────────────────────────────────────────────

enum DashboardWidgetId { statistics, upcomingBriefs, calendar, inbox }

class DashboardPrefs {
  final List<DashboardWidgetId> order;
  final Set<DashboardWidgetId> hidden;

  const DashboardPrefs({required this.order, this.hidden = const {}});

  factory DashboardPrefs.defaults() => DashboardPrefs(
        order: DashboardWidgetId.values.toList(),
      );

  bool isVisible(DashboardWidgetId id) => !hidden.contains(id);

  DashboardPrefs withToggled(DashboardWidgetId id) {
    final newHidden = Set<DashboardWidgetId>.from(hidden);
    if (newHidden.contains(id)) {
      newHidden.remove(id);
    } else {
      newHidden.add(id);
    }
    return DashboardPrefs(order: order, hidden: newHidden);
  }

  DashboardPrefs withReordered(int oldIndex, int newIndex) {
    final newOrder = [...order];
    if (newIndex > oldIndex) newIndex--;
    newOrder.insert(newIndex, newOrder.removeAt(oldIndex));
    return DashboardPrefs(order: newOrder, hidden: hidden);
  }
}

class DashboardPrefsNotifier extends StateNotifier<DashboardPrefs> {
  DashboardPrefsNotifier() : super(DashboardPrefs.defaults());

  void toggle(DashboardWidgetId id) => state = state.withToggled(id);
  void reorder(int oldIndex, int newIndex) =>
      state = state.withReordered(oldIndex, newIndex);
  void reset() => state = DashboardPrefs.defaults();
}

final dashboardPrefsProvider =
    StateNotifierProvider<DashboardPrefsNotifier, DashboardPrefs>(
  (ref) => DashboardPrefsNotifier(),
);
