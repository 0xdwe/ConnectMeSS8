import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_widgets.dart';
import 'modals/add_connection_modal.dart';
import 'modals/update_person_picker_modal.dart';
import 'tabs/home_tab.dart';
import 'tabs/people_tab.dart';
import 'tabs/planner_tab.dart';
import 'tabs/settings_tab.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  bool actionsOpen = false;
  static const _tabs = [HomeTab(), PeopleTab(), PlannerTab(), SettingsTab()];

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(
      appControllerProvider.select((state) => state.selectedTab),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      body: Stack(
        children: [
          AppSurface(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppHeader(
                    userName: ref.watch(
                      appControllerProvider.select((state) => state.user.name),
                    ),
                    userAvatar: ref.watch(
                      appControllerProvider.select(
                        (state) => state.user.avatar,
                      ),
                    ),
                    onProfileTap: () => context.push('/me'),
                  ),
                  Expanded(child: _tabs[selectedTab]),
                ],
              ),
            ),
          ),
          if (actionsOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => actionsOpen = false),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: .05),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 114),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionPill(
                            label: 'Update Connection',
                            onTap: () {
                              setState(() => actionsOpen = false);
                              showUpdatePersonPickerModal(context);
                            },
                          ),
                          const SizedBox(height: 16),
                          _ActionPill(
                            label: 'Add Connection',
                            onTap: () {
                              setState(() => actionsOpen = false);
                              showAddConnectionModal(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selectedTab: selectedTab,
        actionsOpen: actionsOpen,
        onTab: ref.read(appControllerProvider.notifier).setTab,
        onPlus: () => setState(() => actionsOpen = !actionsOpen),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 10,
    borderRadius: BorderRadius.circular(44),
    child: InkWell(
      borderRadius: BorderRadius.circular(44),
      onTap: onTap,
      child: SizedBox(
        width: 430,
        height: 72,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.moss,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedTab,
    required this.actionsOpen,
    required this.onTab,
    required this.onPlus,
  });
  final int selectedTab;
  final bool actionsOpen;
  final ValueChanged<int> onTab;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 92,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 6)],
            ),
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
                const SizedBox(width: 86),
                _NavItem(
                  index: 2,
                  selectedTab: selectedTab,
                  icon: Icons.calendar_today_outlined,
                  label: 'Planner',
                  onTap: onTab,
                ),
                _NavItem(
                  index: 3,
                  selectedTab: selectedTab,
                  icon: Icons.settings_outlined,
                  label: 'Setting',
                  onTap: onTab,
                ),
              ],
            ),
          ),
          Positioned(
            top: -35,
            child: InkWell(
              key: const Key('plus-action-button'),
              onTap: onPlus,
              customBorder: const CircleBorder(),
              child: Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: AppTheme.moss,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 18),
                  ],
                ),
                child: Icon(
                  actionsOpen ? Icons.close : Icons.add,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
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
    final selected = selectedTab == index;
    return InkWell(
      onTap: () => onTap(index),
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.moss : Colors.black54,
              size: 32,
            ),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.moss : Colors.black54,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
