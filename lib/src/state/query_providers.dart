import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_models.dart';
import 'app_state.dart';

/// Immutable filter parameters for contact queries.
/// Used as the family key for filteredContactsProvider.
class ContactFilter {
  const ContactFilter({
    required this.query,
    required this.category,
    required this.sort,
  });

  final String query;
  final String category;
  final ContactSort sort;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactFilter &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          category == other.category &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(query, category, sort);
}

/// Returns a connection by ID using O(1) Map lookup.
/// Returns null if the connection doesn't exist (null-safe, won't throw).
final contactByIdProvider = Provider.family<Connection?, String>(
  (ref, id) {
    final connections = ref.watch(
      appControllerProvider.select((state) => state.connections),
    );
    final connectionMap = {for (var c in connections) c.id: c};
    return connectionMap[id];
  },
);

/// Returns an event by ID using O(1) Map lookup.
/// Returns null if the event doesn't exist (null-safe, won't throw).
final eventByIdProvider = Provider.family<PlannerEvent?, String>(
  (ref, id) {
    final events = ref.watch(
      appControllerProvider.select((state) => state.events),
    );
    final eventMap = {for (var e in events) e.id: e};
    return eventMap[id];
  },
);

/// Returns all interactions for a specific contact.
/// Returns empty list if contact has no interactions or doesn't exist.
final interactionsByContactProvider = Provider.family<List<CrmInteraction>, String>(
  (ref, contactId) {
    final interactions = ref.watch(
      appControllerProvider.select((state) => state.interactions),
    );
    return interactions.where((i) => i.contactId == contactId).toList();
  },
);

/// Returns all events for a specific date.
/// Uses DateUtils.isSameDay to match regardless of time component.
final selectedDayEventsProvider = Provider.family<List<PlannerEvent>, DateTime>(
  (ref, date) {
    final events = ref.watch(
      appControllerProvider.select((state) => state.events),
    );
    return events.where((e) => DateUtils.isSameDay(e.date, date)).toList();
  },
);

/// Returns filtered and sorted connections based on query, category, and sort mode.
/// Filters by query string (case-insensitive, matches name/email/category).
/// Filters by category ('All' means no category filter).
/// Sorts by the specified ContactSort mode.
final filteredContactsProvider = Provider.family<List<Connection>, ContactFilter>(
  (ref, filter) {
    final connections = ref.watch(
      appControllerProvider.select((state) => state.connections),
    );

    // Filter by query and category
    final filtered = connections.where((c) {
      final matchesQuery = filter.query.isEmpty ||
          '${c.name} ${c.email} ${c.category}'
              .toLowerCase()
              .contains(filter.query.toLowerCase());
      final matchesCategory =
          filter.category == 'All' || c.category == filter.category;
      return matchesQuery && matchesCategory;
    }).toList();

    // Sort
    filtered.sort((a, b) => switch (filter.sort) {
          ContactSort.name => a.name.compareTo(b.name),
          ContactSort.lastContact => b.lastContact.compareTo(a.lastContact),
          ContactSort.bondScore => b.bondScore.compareTo(a.bondScore),
        });

    return filtered;
  },
);
