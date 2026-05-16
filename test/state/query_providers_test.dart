import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/state/query_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contactByIdProvider', () {
    test('returns connection when ID exists', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seeded state has 'david', 'emily', 'jessica', 'mike', 'sarah'
      final contact = container.read(contactByIdProvider('david'));

      expect(contact, isNotNull);
      expect(contact!.id, 'david');
      expect(contact.name, 'David Kim');
    });

    test('returns null when ID does not exist', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final contact = container.read(contactByIdProvider('nonexistent-id'));

      expect(contact, isNull);
    });
  });

  group('eventByIdProvider', () {
    test('returns event when ID exists', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seeded state has events 'e1', 'e2', 'e3', 'e4', 'e5'
      final event = container.read(eventByIdProvider('e1'));

      expect(event, isNotNull);
      expect(event!.id, 'e1');
      expect(event.title, 'Coffee with Sarah');
    });

    test('returns null when ID does not exist', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final event = container.read(eventByIdProvider('nonexistent-event'));

      expect(event, isNull);
    });
  });

  group('interactionsByContactProvider', () {
    test('returns interactions for a specific contact', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seeded state has interactions for 'sarah', 'mike', 'emily'
      final interactions = container.read(interactionsByContactProvider('sarah'));

      expect(interactions, isNotEmpty);
      expect(interactions.every((i) => i.contactId == 'sarah'), isTrue);
      expect(interactions.first.id, 'i1');
    });

    test('returns empty list when contact has no interactions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final interactions = container.read(interactionsByContactProvider('david'));

      expect(interactions, isEmpty);
    });

    test('returns empty list for nonexistent contact', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final interactions = container.read(interactionsByContactProvider('nonexistent'));

      expect(interactions, isEmpty);
    });
  });

  group('selectedDayEventsProvider', () {
    test('returns events for a specific date', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seeded state has event 'e1' on 2026-04-28
      final date = DateTime(2026, 4, 28);
      final events = container.read(selectedDayEventsProvider(date));

      expect(events, isNotEmpty);
      expect(events.length, 1);
      expect(events.first.id, 'e1');
      expect(events.first.title, 'Coffee with Sarah');
    });

    test('returns empty list when no events on date', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final date = DateTime(2026, 6, 1);
      final events = container.read(selectedDayEventsProvider(date));

      expect(events, isEmpty);
    });

    test('matches events regardless of time component', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Event is on 2026-04-28, query with different time
      final date = DateTime(2026, 4, 28, 15, 30);
      final events = container.read(selectedDayEventsProvider(date));

      expect(events, isNotEmpty);
      expect(events.first.id, 'e1');
    });
  });

  group('filteredContactsProvider', () {
    test('returns all connections when no filters applied', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = ContactFilter(
        query: '',
        category: 'All',
        sort: ContactSort.name,
      );
      final contacts = container.read(filteredContactsProvider(filter));

      // Seeded state has 5 connections
      expect(contacts.length, 5);
    });

    test('filters by query string (case-insensitive)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = ContactFilter(
        query: 'emily',
        category: 'All',
        sort: ContactSort.name,
      );
      final contacts = container.read(filteredContactsProvider(filter));

      expect(contacts.length, 1);
      expect(contacts.first.name, 'Emily Rodriguez');
    });

    test('filters by category', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = ContactFilter(
        query: '',
        category: 'Work',
        sort: ContactSort.name,
      );
      final contacts = container.read(filteredContactsProvider(filter));

      expect(contacts.every((c) => c.category == 'Work'), isTrue);
      expect(contacts.first.name, 'Emily Rodriguez');
    });

    test('sorts by name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = ContactFilter(
        query: '',
        category: 'All',
        sort: ContactSort.name,
      );
      final contacts = container.read(filteredContactsProvider(filter));

      expect(contacts.first.name, 'David Kim');
      expect(contacts.last.name, 'Sarah Johnson');
    });

    test('sorts by lastContact (most recent first)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = ContactFilter(
        query: '',
        category: 'All',
        sort: ContactSort.lastContact,
      );
      final contacts = container.read(filteredContactsProvider(filter));

      // David has most recent contact (4 days ago)
      expect(contacts.first.name, 'David Kim');
    });

    test('sorts by bondScore (highest first)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = ContactFilter(
        query: '',
        category: 'All',
        sort: ContactSort.bondScore,
      );
      final contacts = container.read(filteredContactsProvider(filter));

      // David has highest bond score (95)
      expect(contacts.first.name, 'David Kim');
      expect(contacts.first.bondScore, 95);
    });

    test('combines query and category filters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filter = ContactFilter(
        query: 'e',
        category: 'Work',
        sort: ContactSort.name,
      );
      final contacts = container.read(filteredContactsProvider(filter));

      expect(contacts.length, 1);
      expect(contacts.first.name, 'Emily Rodriguez');
    });
  });
}
