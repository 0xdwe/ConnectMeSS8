import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../state/user_profile/user_profile_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/account_avatar.dart';
import '../widgets/chain_logo.dart';
import '../widgets/crm_widgets.dart';
import 'modals/plus_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/people_tab.dart';
import 'tabs/planner_tab.dart';
import 'tabs/you_tab.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  static const _tabs = [HomeTab(), PeopleTab(), PlannerTab(), YouTab()];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selectedTab = ref.watch(
      appControllerProvider.select((state) => state.selectedTab),
    );
    final profile = ref.watch(accountProfileProvider);
    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: selectedTab == 3
          ? null
          : AppBar(
              toolbarHeight: 58,
              titleSpacing: 20,
              backgroundColor: tokens.surfaceRaised,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(color: tokens.border, height: 1),
              ),
              title: LinkedChainLogo(size: 42, color: tokens.primary),
              actions: [
                IconButton(
                  key: const Key('profile-button'),
                  tooltip: 'Open profile',
                  icon: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.primary, width: 2),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: AccountAvatar(
                      profile: profile,
                      radius: 18,
                      glyphSize: 14,
                      backgroundColor: tokens.primaryTint,
                      foregroundColor: tokens.primary,
                    ),
                  ),
                  onPressed: () =>
                      ref.read(appControllerProvider.notifier).setTab(3),
                ),
                SizedBox(width: AppSpacing.space2),
              ],
            ),
      body: AppSurface(
        child: SafeArea(top: false, bottom: false, child: _tabs[selectedTab]),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 15),
        child: SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            key: const Key('plus-action-button'),
            shape: CircleBorder(
              side: BorderSide(color: tokens.surfaceRaised, width: 5),
            ),
            backgroundColor: tokens.primary,
            elevation: 6,
            onPressed: () => showPlusSheet(context),
            child: Icon(Icons.add, color: tokens.primaryOn, size: 42),
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
  const _BottomNav({required this.selectedTab, required this.onTab});
  final int selectedTab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .22 : .06),
              offset: const Offset(0, -3),
              blurRadius: 14,
            ),
          ],
        ),
        child: BottomAppBar(
          height: 74,
          padding: EdgeInsets.zero,
          color: tokens.surfaceRaised,
          elevation: 0,
          shape: null,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  index: 0,
                  selectedTab: selectedTab,
                  icon: Icons.home_outlined,
                  label: 'Home',
                  onTap: onTab,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _NavItem(
                  index: 1,
                  selectedTab: selectedTab,
                  icon: Icons.people_outline,
                  label: 'People',
                  onTap: onTab,
                ),
              ),

              const SizedBox(width: 80),

              Expanded(
                child: _NavItem(
                  index: 2,
                  selectedTab: selectedTab,
                  icon: Icons.calendar_month_outlined,
                  label: 'Plan',
                  onTap: onTab,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _NavItem(
                  index: 3,
                  selectedTab: selectedTab,
                  icon: Icons.person_outline,
                  label: 'You',
                  onTap: onTab,
                ),
              ),
            ],
          ),
        ),
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
        width: double.infinity,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 28 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: tokens.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: selected ? tokens.primary : tokens.inkSubtle,
                    size: 26,
                  ),
                  Text(
                    label,
                    style: AppTypography.caption(
                      color: selected ? tokens.primary : tokens.inkSubtle,
                    ).copyWith(fontWeight: FontWeight.w700),
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
