import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavItem {
  final String id;
  final String label;
  final String route;
  final IconData icon;
  final bool visible;
  final bool adminOnly;

  const NavItem({
    required this.id,
    required this.label,
    required this.route,
    required this.icon,
    this.visible = true,
    this.adminOnly = false,
  });

  NavItem copyWith({bool? visible}) => NavItem(
        id: id,
        label: label,
        route: route,
        icon: icon,
        visible: visible ?? this.visible,
        adminOnly: adminOnly,
      );
}

const _defaultItems = [
  NavItem(id: 'dashboard', label: 'Dashboard', route: '/dashboard', icon: Icons.dashboard_outlined),
  NavItem(id: 'bases', label: 'Bases', route: '/bases', icon: Icons.location_city_outlined),
  NavItem(id: 'units', label: 'Reserve Units', route: '/units', icon: Icons.groups_outlined),
  NavItem(id: 'briefs', label: 'Briefs', route: '/briefs', icon: Icons.event_note_outlined),
  NavItem(id: 'performance', label: 'Performance', route: '/performance', icon: Icons.bar_chart),
  NavItem(id: 'reports', label: 'Reports', route: '/reports', icon: Icons.assessment_outlined),
  NavItem(id: 'admin', label: 'Admin', route: '/admin', icon: Icons.admin_panel_settings_outlined),
  NavItem(id: 'settings', label: 'Settings', route: '/settings', icon: Icons.settings_outlined, adminOnly: true),
];

class SidebarState {
  final List<NavItem> items;
  final bool editMode;

  const SidebarState({
    required this.items,
    this.editMode = false,
  });

  SidebarState copyWith({List<NavItem>? items, bool? editMode}) =>
      SidebarState(
        items: items ?? this.items,
        editMode: editMode ?? this.editMode,
      );
}

class SidebarNotifier extends StateNotifier<SidebarState> {
  SidebarNotifier() : super(const SidebarState(items: _defaultItems));

  void toggleEditMode() => state = state.copyWith(editMode: !state.editMode);

  void toggleVisibility(String id) {
    final updated = state.items.map((item) {
      return item.id == id ? item.copyWith(visible: !item.visible) : item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void reorder(int oldIndex, int newIndex) {
    final items = [...state.items];
    if (newIndex > oldIndex) newIndex--;
    items.insert(newIndex, items.removeAt(oldIndex));
    state = state.copyWith(items: items);
  }
}

final sidebarProvider = StateNotifierProvider<SidebarNotifier, SidebarState>(
  (ref) => SidebarNotifier(),
);
