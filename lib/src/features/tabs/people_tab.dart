import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../state/query_providers.dart';
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
    final categories = ref.watch(
      appControllerProvider.select((state) => ['All', ...state.categories]),
    );
    final filter = ContactFilter(
      query: query,
      category: category,
      sort: sort,
    );
    final people = ref.watch(filteredContactsProvider(filter));
    final hasAnyConnections = ref.watch(
      appControllerProvider.select((state) => state.connections.isNotEmpty),
    );
    
    return ListView(
      key: const Key('people-tab'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.space6,
        AppSpacing.pageBottomPadding,
      ),
      children: [
        TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 24), hintText: 'Search contacts...', hintStyle: AppTypography.bodyLg(color: tokens.inkSubtle)), style: AppTypography.bodyLg(), onChanged: (value) => setState(() => query = value)),
        SizedBox(height: AppSpacing.space5),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [Icon(Icons.filter_alt_outlined, color: tokens.inkMuted, size: 22), SizedBox(width: AppSpacing.space3), ...categories.map((item) => _FilterChip(label: item, selected: item == category, onTap: () => setState(() => category = item)))])),
        SizedBox(height: AppSpacing.space5),
        Text('Sort by:', style: AppTypography.caption(color: tokens.inkMuted)),
        SizedBox(height: AppSpacing.space3),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ContactSort.values.map((item) => _FilterChip(label: item.label, selected: item == sort, onTap: () => setState(() => sort = item))).toList())),
        SizedBox(height: AppSpacing.space5),
        if (people.isEmpty && !hasAnyConnections)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.space8),
              child: Text(
                'No connections yet. Tap + to add someone.',
                style: AppTypography.bodyLg(color: tokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (people.isEmpty && query.isNotEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.space8),
              child: Text(
                'Nothing matches "$query". Try a different word.',
                style: AppTypography.bodyLg(color: tokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
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
