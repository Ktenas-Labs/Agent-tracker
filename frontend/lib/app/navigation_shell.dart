import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/nav_state.dart';
import '../core/user_state.dart';
import '../app/theme.dart';

const _sidebarWidth = 220.0;

// ── Shell ──────────────────────────────────────────────────────────────────────

class NavigationShell extends ConsumerWidget {
  const NavigationShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarState = ref.watch(sidebarProvider);
    final sidebarNotifier = ref.read(sidebarProvider.notifier);
    final currentPath = GoRouterState.of(context).uri.path;
    final isAdmin = ref.watch(userProfileProvider)?.isAdmin ?? false;

    return Column(
      children: [
        _TopBar(),
        Expanded(
          child: Row(
            children: [
              _Sidebar(
                state: sidebarState,
                notifier: sidebarNotifier,
                currentPath: currentPath,
                isAdmin: isAdmin,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final prefs = ref.watch(userPreferencesProvider);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Spacer(),
          if (user != null)
            _ProfileButton(user: user, prefs: prefs, ref: ref)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ── Profile button + dropdown ──────────────────────────────────────────────────

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.user,
    required this.prefs,
    required this.ref,
  });

  final UserProfile user;
  final UserPreferences prefs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showProfileMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(initials: user.initials, size: 30),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: GoogleFonts.assistant(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (prefs.showRoleBadge)
                  Text(
                    user.role.toUpperCase(),
                    style: GoogleFonts.assistant(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) async {
    final button = context.findRenderObject() as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_MenuAction>(
      context: context,
      position: position,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 8,
      items: [
        // Profile header (non-interactive)
        PopupMenuItem<_MenuAction>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _ProfileHeader(user: user),
        ),
        const PopupMenuDivider(height: 1),
        // Preferences
        _menuItem(
          value: _MenuAction.preferences,
          icon: Icons.tune_outlined,
          label: 'Preferences',
        ),
        const PopupMenuDivider(height: 1),
        // Sign out
        _menuItem(
          value: _MenuAction.signOut,
          icon: Icons.logout_outlined,
          label: 'Sign out',
          danger: true,
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    switch (selected) {
      case _MenuAction.preferences:
        _showPreferencesDialog(context);
      case _MenuAction.signOut:
        _signOut(context);
    }
  }

  void _signOut(BuildContext context) {
    ref.read(userProfileProvider.notifier).clearUser();
    context.go('/login');
  }

  void _showPreferencesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _PreferencesDialog(),
    );
  }

  PopupMenuItem<_MenuAction> _menuItem({
    required _MenuAction value,
    required IconData icon,
    required String label,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFEF4444) : AppColors.textPrimary;
    return PopupMenuItem<_MenuAction>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: danger ? const Color(0xFFEF4444) : AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.assistant(fontSize: 14, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { preferences, signOut }

// ── Profile header inside menu ────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _Avatar(initials: user.initials, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: GoogleFonts.assistant(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  user.email,
                  style: GoogleFonts.assistant(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF3B82F6).withAlpha(80)),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: GoogleFonts.assistant(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF60A5FA),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppColors.glowSm,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.assistant(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Preferences dialog ────────────────────────────────────────────────────────

class _PreferencesDialog extends ConsumerWidget {
  const _PreferencesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    final notifier = ref.read(userPreferencesProvider.notifier);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.tune_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Preferences',
                    style: GoogleFonts.assistant(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Options
            _PrefSection(title: 'Display'),
            _PrefTile(
              icon: Icons.density_small_outlined,
              title: 'Compact mode',
              subtitle: 'Denser list tiles and reduced spacing',
              value: prefs.compactMode,
              onChanged: (_) => notifier.toggleCompactMode(),
            ),
            _PrefTile(
              icon: Icons.badge_outlined,
              title: 'Show role badge',
              subtitle: 'Display your role label under your name',
              value: prefs.showRoleBadge,
              onChanged: (_) => notifier.toggleShowRoleBadge(),
            ),

            const Divider(height: 16),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Text(
                    'Preferences are saved for this session.',
                    style: GoogleFonts.assistant(fontSize: 11, color: AppColors.textDisabled),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefSection extends StatelessWidget {
  const _PrefSection({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.assistant(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.assistant(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.assistant(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.state,
    required this.notifier,
    required this.currentPath,
    required this.isAdmin,
  });

  final SidebarState state;
  final SidebarNotifier notifier;
  final String currentPath;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const Divider(height: 1, indent: 0, endIndent: 0),
          Expanded(
            child: state.editMode
                ? _EditList(state: state, notifier: notifier)
                : _NavList(state: state, currentPath: currentPath, isAdmin: isAdmin),
          ),
          const Divider(height: 1),
          _Footer(editMode: state.editMode, onToggle: notifier.toggleEditMode),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.shield, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Agent Tracker',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.state, required this.currentPath, required this.isAdmin});

  final SidebarState state;
  final String currentPath;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final visible = state.items.where((i) => i.visible && (!i.adminOnly || isAdmin)).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final item = visible[i];
        final isActive = currentPath == item.route ||
            (item.route != '/dashboard' && currentPath.startsWith(item.route));
        return _NavTile(item: item, isActive: isActive);
      },
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.isActive});

  final NavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(item.route),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(item.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditList extends StatelessWidget {
  const _EditList({required this.state, required this.notifier});

  final SidebarState state;
  final SidebarNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: state.items.length,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
      onReorder: notifier.reorder,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _EditTile(
          key: ValueKey(item.id),
          item: item,
          onToggle: () => notifier.toggleVisibility(item.id),
          index: index,
          theme: theme,
        );
      },
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.index,
    required this.theme,
  });

  final NavItem item;
  final VoidCallback onToggle;
  final int index;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: item.visible
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(item.icon, size: 18, color: item.visible ? null : theme.disabledColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: item.visible ? null : theme.disabledColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: item.visible,
                onChanged: (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, size: 18, color: theme.hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.editMode, required this.onToggle});

  final bool editMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: TextButton.icon(
        onPressed: onToggle,
        icon: Icon(editMode ? Icons.check_circle_outline : Icons.tune, size: 16),
        label: Text(editMode ? 'Done' : 'Customize'),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          minimumSize: const Size.fromHeight(36),
        ),
      ),
    );
  }
}
