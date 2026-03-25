import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── UserProfile ────────────────────────────────────────────────────────────────

class UserProfile {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;

  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

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
