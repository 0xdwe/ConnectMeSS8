import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';
import 'modals/plus_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/people_tab.dart';
import 'tabs/planner_tab.dart';
import 'settings_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  static const _tabs = [HomeTab(), PeopleTab(), PlannerTab(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selectedTab = ref.watch(
      appControllerProvider.select((state) => state.selectedTab),
    );
    final userAvatar = ref.watch(
      appControllerProvider.select((state) => state.user.avatar),
    );
    return Scaffold(
      backgroundColor: tokens.surface,

      appBar: AppBar(
        toolbarHeight: 55,
        titleSpacing: 20,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D4CFF), Color(0xFF9F7BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Connect Me',
          style: AppTypography.h2(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                userAvatar,
                style: AppTypography.body(color: const Color(0xFF6D4CFF)),
              ),
            ),
            onPressed: () => ref.read(appControllerProvider.notifier).setTab(3),
          ),
          SizedBox(width: AppSpacing.space2),
        ],
      ),

      body: AppSurface(
        child: SafeArea(
          top: false,
          bottom: false,
          child: _tabs[selectedTab],
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 18),
        child: SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            key: const Key('plus-action-button'),
            shape: const CircleBorder(),
            backgroundColor: tokens.primary,
            elevation: 10,
            onPressed: () => showPlusSheet(context),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
      ),

      bottomNavigationBar: _BottomNav(
        selectedTab: selectedTab,
        onTab: ref.read(appControllerProvider.notifier).setTab,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedTab,
    required this.onTab,
  });

  final int selectedTab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return BottomAppBar(
      height: 88,
      color: tokens.surfaceRaised,
      elevation: 8,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            index: 0,
            selectedTab: selectedTab,
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: onTab,
          ),
          _NavItem(
            index: 1,
            selectedTab: selectedTab,
            icon: Icons.people_outline,
            label: 'People',
            onTap: onTab,
          ),

          const SizedBox(width: 80),

          _NavItem(
            index: 2,
            selectedTab: selectedTab,
            icon: Icons.calendar_month_outlined,
            label: 'Planner',
            onTap: onTab,
          ),
          _NavItem(
            index: 3,
            selectedTab: selectedTab,
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onTab,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selectedTab,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final int index;
  final int selectedTab;
  final IconData icon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selected = selectedTab == index;
    return InkWell(
      onTap: () => onTap(index),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? tokens.primary : tokens.inkMuted,
              size: 28,
            ),
            SizedBox(height: AppSpacing.space1),
            Text(
              label,
              style: AppTypography.caption(
                color: selected ? tokens.primary : tokens.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
