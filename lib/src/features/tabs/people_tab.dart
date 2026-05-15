import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/crm_widgets.dart';

class PeopleTab extends ConsumerStatefulWidget {
  const PeopleTab({super.key});

  @override
  ConsumerState<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<PeopleTab> {
  String query = '';
  String category = 'All';
  ContactSort sort = ContactSort.name;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(appControllerProvider);
    final categories = ['All', ...state.categories];
    final people = state.connections.where((c) {
      final matchesQuery = '${c.name} ${c.email} ${c.category}'.toLowerCase().contains(query.toLowerCase());
      final matchesCategory = category == 'All' || c.category == category;
      return matchesQuery && matchesCategory;
    }).toList()
      ..sort((a, b) => switch (sort) {
            ContactSort.name => a.name.compareTo(b.name),
            ContactSort.lastContact => b.lastContact.compareTo(a.lastContact),
            ContactSort.bondScore => b.bondScore.compareTo(a.bondScore),
          });
    return ListView(
      key: const Key('people-tab'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.pageBottomPadding,
      ),
      children: [
        TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 34), hintText: 'Search contacts...', hintStyle: AppTypography.h1(color: tokens.inkSubtle)), style: AppTypography.bodyLg(), onChanged: (value) => setState(() => query = value)),
        SizedBox(height: AppSpacing.space5),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [Icon(Icons.filter_alt_outlined, color: tokens.inkMuted, size: 32), SizedBox(width: AppSpacing.space3), ...categories.map((item) => _FilterChip(label: item, selected: item == category, onTap: () => setState(() => category = item)))])),
        SizedBox(height: AppSpacing.space5),
        Text('Sort by:', style: AppTypography.h2(color: tokens.inkMuted)),
        SizedBox(height: AppSpacing.space3),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ContactSort.values.map((item) => _FilterChip(label: item.label, selected: item == sort, onTap: () => setState(() => sort = item))).toList())),
        SizedBox(height: AppSpacing.space5),
        for (final person in people) ContactListCard(connection: person, onTap: () => context.push('/contact/${person.id}')),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
        padding: EdgeInsets.only(right: AppSpacing.space3),
        child: ChoiceChip(
          label: Text(label, style: AppTypography.body(color: selected ? tokens.primaryOn : tokens.inkMuted)),
          selected: selected,
          showCheckmark: false,
          selectedColor: tokens.primary,
          backgroundColor: tokens.surfaceSunken,
          side: BorderSide.none,
          onSelected: (_) => onTap(),
        ),
      );
  }
}
