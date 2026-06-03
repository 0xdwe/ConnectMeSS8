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

    return Container(
      color: const Color(0xFFF5F0FF),
      child: ListView(
        key: const Key('people-tab'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Search contacts...',
              hintStyle: AppTypography.body(color: tokens.inkSubtle),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
            style: AppTypography.body(),
            onChanged: (value) => setState(() => query = value),
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(Icons.filter_alt_outlined, color: tokens.primary, size: 18),
                const SizedBox(width: 8),
                ...categories.map(
                  (item) => _SmallChip(
                    label: item,
                    selected: item == category,
                    onTap: () => setState(() => category = item),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Sort by:',
            style: AppTypography.caption(color: tokens.inkMuted),
          ),

          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ContactSort.values
                  .map(
                    (item) => _SmallChip(
                      label: item.label,
                      selected: item == sort,
                      onTap: () => setState(() => sort = item),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          if (people.isEmpty && !hasAnyConnections)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No connections yet. Tap + to add someone.',
                style: AppTypography.bodyLg(color: tokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            )
          else if (people.isEmpty && query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Nothing matches "$query". Try a different word.',
                style: AppTypography.bodyLg(color: tokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ContactListCard(
                  connection: person,
                  onTap: () => context.push('/contact/${person.id}'),
                ),
              ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: AppTypography.caption(
            color: selected ? Colors.white : tokens.inkMuted,
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: tokens.primary,
        backgroundColor: tokens.surfaceSunken,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }
}