import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/social_models.dart';
import 'event_store.dart';

/// Firestore-backed [EventStore] (Pass 4.5, #068).
///
/// Persists [PlannerEvent] records to
/// `users/{uid}/events/{eventId}`. Each document matches the closed
/// shape from `firestore/firestore.rules`:
///
///  * `id` (string, must equal the document key)
///  * `title`, `category`, `note`, `eventType` (string,
///    empty allowed)
///  * `date` (timestamp)
///  * `isAllDay`, `isRecurring` (bool)
///  * `schemaVersion` (int, literal `1`)
///  * `updatedAt` (server timestamp)
///  * `contactId`, `recurrencePattern` (string, optional)
///  * `startTimeMinutes`, `endTimeMinutes` (int, optional)
///
/// `eventType` is intentionally NOT validated server-side per
/// PRD §Q8 — the eventTypes list is per-user data (Pass 4.5 Q12)
/// and bad client data is recoverable client-side.
///
/// `recurrencePattern` is the [RecurrencePattern] enum's `.name`
/// (`daily`, `weekly`, `monthly`, `yearly`); decoder defensively
/// returns null for the document on unknown enum values.
///
/// **UID is bound at construction.** Mirrors
/// [FirebaseConnectionStore] from #065 and [FirebaseInteractionStore]
/// from #067. The auth-aware `eventStoreProvider` (#068) is
/// responsible for rebuilding a new adapter when the signed-in
/// user changes.
///
/// **Snapshot listener pattern (PRD §Q6).** At construction, the
/// adapter opens a `users/{uid}/events.snapshots()` subscription.
/// Incoming snapshots are decoded into an immutable
/// `Map<String, PlannerEvent>` and pushed onto a broadcast stream
/// that backs both [snapshot] and [snapshotSync]. Listener errors
/// are forwarded onto the broadcast stream's error channel; the
/// mirror is left unchanged so downstream readers do not see a torn
/// snapshot.
///
/// **Listener teardown contract.** [dispose] cancels the
/// subscription and closes the broadcast controller. Idempotent.
///
/// **`snapshotSync()` null-while-loading contract.** Returns null
/// until the first Firestore snapshot resolves, then returns the
/// current mirror map (empty or populated) for the lifetime of the
/// adapter.
class FirebaseEventStore implements EventStore {
  FirebaseEventStore({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid {
    _subscribe();
  }

  /// Schema version written into every event document.
  static const int schemaVersion = 1;

  final FirebaseFirestore _firestore;
  final String _uid;
  final StreamController<Map<String, PlannerEvent>> _controller =
      StreamController<Map<String, PlannerEvent>>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Map<String, PlannerEvent>? _mirror;
  bool _disposed = false;

  /// Path: `users/{uid}/events`. Single getter so call sites can't
  /// drift from the canonical structure.
  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('users').doc(_uid).collection('events');

  DocumentReference<Map<String, dynamic>> _docRef(String eventId) =>
      _eventsRef.doc(eventId);

  void _subscribe() {
    _subscription = _eventsRef.snapshots().listen(
      (query) {
        final next = <String, PlannerEvent>{};
        for (final doc in query.docs) {
          final parsed = _decode(doc);
          if (parsed != null) next[parsed.id] = parsed;
        }
        final immutable = Map<String, PlannerEvent>.unmodifiable(next);
        _mirror = immutable;
        if (!_controller.isClosed) _controller.add(immutable);
      },
      onError: (Object error, StackTrace stack) {
        if (!_controller.isClosed) _controller.addError(error, stack);
      },
    );
  }

  @override
  Future<PlannerEvent?> load(String eventId) async {
    final snapshot = await _docRef(eventId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    return _decodeData(data);
  }

  @override
  Future<void> save(PlannerEvent event) async {
    await _docRef(event.id).set(_encode(event));
  }

  @override
  Future<void> delete(String eventId) async {
    await _docRef(eventId).delete();
  }

  @override
  Future<Map<String, PlannerEvent>> listAll() async {
    final query = await _eventsRef.get();
    final out = <String, PlannerEvent>{};
    for (final doc in query.docs) {
      final parsed = _decode(doc);
      if (parsed != null) out[parsed.id] = parsed;
    }
    return Map.unmodifiable(out);
  }

  @override
  Stream<Map<String, PlannerEvent>> snapshot() {
    late StreamController<Map<String, PlannerEvent>> controller;
    StreamSubscription<Map<String, PlannerEvent>>? sub;
    controller = StreamController<Map<String, PlannerEvent>>(
      onListen: () {
        final current = _mirror;
        if (current != null) controller.add(current);
        sub = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await sub?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Map<String, PlannerEvent>? snapshotSync() => _mirror;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  // ---------------------------------------------------------------
  // Encode / decode
  // ---------------------------------------------------------------

  Map<String, dynamic> _encode(PlannerEvent e) => encode(e);

  /// Public encoder used by [save] and by [ConnectionSeeder] (#069).
  /// Pure — does not read `_firestore` or `_uid`.
  static Map<String, dynamic> encode(PlannerEvent e) {
    // Nullable fields are written only when present so the
    // present-and-typed-or-absent rule guards apply uniformly. The
    // FieldValue.delete() pattern would also work but adds
    // complexity for an absent-on-create case the rules already
    // accept.
    final out = <String, dynamic>{
      'id': e.id,
      'title': e.title,
      'category': e.category,
      'date': Timestamp.fromDate(e.date),
      'note': e.note,
      'eventType': e.eventType,
      'isAllDay': e.isAllDay,
      'isRecurring': e.isRecurring,
      'schemaVersion': schemaVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (e.contactId != null) out['contactId'] = e.contactId;
    if (e.startTimeMinutes != null) {
      out['startTimeMinutes'] = e.startTimeMinutes;
    }
    if (e.endTimeMinutes != null) {
      out['endTimeMinutes'] = e.endTimeMinutes;
    }
    if (e.recurrencePattern != null) {
      out['recurrencePattern'] = e.recurrencePattern!.name;
    }
    return out;
  }

  PlannerEvent? _decode(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return _decodeData(doc.data());
  }

  /// Defensive decode. Tolerate malformed documents by returning
  /// null rather than throwing — rules normally guarantee shape, but
  /// a transient inconsistency should not poison the snapshot.
  PlannerEvent? _decodeData(Map<String, dynamic> data) {
    try {
      final id = data['id'];
      final title = data['title'];
      final category = data['category'];
      final date = data['date'];
      final note = data['note'];
      final eventType = data['eventType'];
      final isAllDay = data['isAllDay'];
      final isRecurring = data['isRecurring'];
      final contactId = data['contactId'];
      final startTimeMinutes = data['startTimeMinutes'];
      final endTimeMinutes = data['endTimeMinutes'];
      final recurrencePattern = data['recurrencePattern'];

      if (id is! String ||
          title is! String ||
          category is! String ||
          date is! Timestamp ||
          note is! String ||
          eventType is! String ||
          isAllDay is! bool ||
          isRecurring is! bool) {
        return null;
      }

      // Optional-field type guards: present-and-typed-or-absent.
      // A wrong-typed optional field drops the whole document.
      if (contactId != null && contactId is! String) return null;
      if (startTimeMinutes != null && startTimeMinutes is! int) return null;
      if (endTimeMinutes != null && endTimeMinutes is! int) return null;

      RecurrencePattern? pattern;
      if (recurrencePattern != null) {
        if (recurrencePattern is! String) return null;
        final candidate = RecurrencePattern.values
            .where((p) => p.name == recurrencePattern)
            .firstOrNull;
        if (candidate == null) {
          // Unknown enum value — drop the document, consistent with
          // the InteractionStore decoder pattern from #067.
          return null;
        }
        pattern = candidate;
      }

      return PlannerEvent(
        id: id,
        title: title,
        contactId: contactId as String?,
        category: category,
        date: date.toDate(),
        note: note,
        eventType: eventType,
        isAllDay: isAllDay,
        startTimeMinutes: startTimeMinutes as int?,
        endTimeMinutes: endTimeMinutes as int?,
        isRecurring: isRecurring,
        recurrencePattern: pattern,
      );
    } catch (_) {
      return null;
    }
  }
}
