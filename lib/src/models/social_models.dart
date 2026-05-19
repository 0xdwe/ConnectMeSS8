import 'package:flutter/material.dart';

import '../state/memory/memory_document.dart';
import '../widgets/bond_ring.dart';

enum InteractionType {
  interaction,
  personalDetail,
  preference,
  reminder,
  sharedActivity,
  relationshipNote,
}

enum InteractionSource {
  manual,
  aiSuggested,
}

enum ContactSort { name, lastContact, bondScore }

enum AvatarKind { emoji, image }

enum RecurrencePattern { daily, weekly, monthly, yearly }

extension RecurrencePatternLabel on RecurrencePattern {
  String get label => switch (this) {
    RecurrencePattern.daily => 'Daily',
    RecurrencePattern.weekly => 'Weekly',
    RecurrencePattern.monthly => 'Monthly',
    RecurrencePattern.yearly => 'Yearly',
  };
}

class AppUser {
  const AppUser({
    required this.name,
    required this.email,
    required this.avatar,
    required this.avatarKind,
  });

  final String name;
  final String email;
  final String avatar;
  final AvatarKind avatarKind;

  AppUser copyWith({
    String? name,
    String? email,
    String? avatar,
    AvatarKind? avatarKind,
  }) {
    return AppUser(
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      avatarKind: avatarKind ?? this.avatarKind,
    );
  }
}

extension ContactSortLabel on ContactSort {
  String get label => switch (this) {
    ContactSort.name => 'Name',
    ContactSort.lastContact => 'Last Contact',
    ContactSort.bondScore => 'Bond Score',
  };
}

extension InteractionTypeLabel on InteractionType {
  String get label => switch (this) {
    InteractionType.interaction => 'Interaction',
    InteractionType.personalDetail => 'Personal detail',
    InteractionType.preference => 'Preference',
    InteractionType.reminder => 'Reminder',
    InteractionType.sharedActivity => 'Shared activity',
    InteractionType.relationshipNote => 'Relationship note',
  };

  IconData get icon => switch (this) {
    InteractionType.interaction => Icons.chat_bubble_outline,
    InteractionType.personalDetail => Icons.badge_outlined,
    InteractionType.preference => Icons.favorite_border,
    InteractionType.reminder => Icons.notifications_none,
    InteractionType.sharedActivity => Icons.groups_2_outlined,
    InteractionType.relationshipNote => Icons.psychology_alt_outlined,
  };
}

class AttachmentRef {
  const AttachmentRef({required this.name, required this.path});
  final String name;
  final String? path;
}

class CrmInteraction {
  const CrmInteraction({
    required this.id,
    required this.contactId,
    required this.type,
    required this.title,
    required this.note,
    required this.date,
    this.attachments = const [],
    this.source = InteractionSource.manual,
  });

  final String id;
  final String contactId;
  final InteractionType type;
  final String title;
  final String note;
  final DateTime date;
  final List<AttachmentRef> attachments;
  final InteractionSource source;

  CrmInteraction copyWith({
    String? id,
    String? contactId,
    InteractionType? type,
    String? title,
    String? note,
    DateTime? date,
    List<AttachmentRef>? attachments,
    InteractionSource? source,
  }) {
    return CrmInteraction(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      type: type ?? this.type,
      title: title ?? this.title,
      note: note ?? this.note,
      date: date ?? this.date,
      attachments: attachments ?? this.attachments,
      source: source ?? this.source,
    );
  }
}

class Connection {
  const Connection({
    required this.id,
    required this.name,
    required this.email,
    required this.category,
    required this.avatar,
    required this.bondScore,
    required this.nextStep,
    required this.lastContact,
    required this.notes,
    required this.knownSince,
    required this.preferredChannels,
    this.isSample = false,
  });

  final String id;
  final String name;
  final String email;
  final String category;
  final String avatar;
  final int bondScore;
  final String nextStep;
  final DateTime lastContact;
  final String notes;
  final DateTime knownSince;
  final List<String> preferredChannels;
  final bool isSample;

  String get role => category;
  String get company => email;
  String get avatarSeed => avatar;
  int get closeness => bondScore;
  List<String> get tags => [category];

  /// Bond trend stub: score ≥70 → up, else flat.
  /// Wave 4 will replace with real history-based logic.
  BondTrend get bondTrend => bondScore >= 70 ? BondTrend.up : BondTrend.flat;

  Connection copyWith({
    String? name,
    String? email,
    String? category,
    String? avatar,
    int? bondScore,
    String? nextStep,
    DateTime? lastContact,
    String? notes,
    DateTime? knownSince,
    List<String>? preferredChannels,
    bool? isSample,
  }) {
    return Connection(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      category: category ?? this.category,
      avatar: avatar ?? this.avatar,
      bondScore: bondScore ?? this.bondScore,
      nextStep: nextStep ?? this.nextStep,
      lastContact: lastContact ?? this.lastContact,
      notes: notes ?? this.notes,
      knownSince: knownSince ?? this.knownSince,
      preferredChannels: preferredChannels ?? this.preferredChannels,
      isSample: isSample ?? this.isSample,
    );
  }
}

class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    this.contactId,
    required this.category,
    required this.date,
    required this.note,
    this.eventType = 'Plan',
    this.isAllDay = true,
    this.startTimeMinutes,
    this.endTimeMinutes,
    this.isRecurring = false,
    this.recurrencePattern,
  });

  final String id;
  final String title;
  final String? contactId;
  final String category;
  final DateTime date;
  final String note;
  final String eventType;
  final bool isAllDay;
  final int? startTimeMinutes;
  final int? endTimeMinutes;
  final bool isRecurring;
  final RecurrencePattern? recurrencePattern;

  PlannerEvent copyWith({
    String? title,
    Object? contactId = _sentinel,
    String? category,
    DateTime? date,
    String? note,
    String? eventType,
    bool? isAllDay,
    Object? startTimeMinutes = _sentinel,
    Object? endTimeMinutes = _sentinel,
    bool? isRecurring,
    Object? recurrencePattern = _sentinel,
  }) {
    return PlannerEvent(
      id: id,
      title: title ?? this.title,
      contactId: identical(contactId, _sentinel)
          ? this.contactId
          : contactId as String?,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      eventType: eventType ?? this.eventType,
      isAllDay: isAllDay ?? this.isAllDay,
      startTimeMinutes: identical(startTimeMinutes, _sentinel)
          ? this.startTimeMinutes
          : startTimeMinutes as int?,
      endTimeMinutes: identical(endTimeMinutes, _sentinel)
          ? this.endTimeMinutes
          : endTimeMinutes as int?,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: identical(recurrencePattern, _sentinel)
          ? this.recurrencePattern
          : recurrencePattern as RecurrencePattern?,
    );
  }
}

const Object _sentinel = Object();

class Recommendation {
  const Recommendation({
    required this.contactId,
    required this.reason,
    required this.insight,
    required this.priority,
  });

  final String contactId;
  final String reason;
  final String insight;
  final String priority;
}

class ContactInsight {
  const ContactInsight({
    required this.contactId,
    required this.summary,
    required this.why,
    required this.recommendedAction,
    required this.potentialScoreGain,
    required this.relationshipLabel,
    required this.knownSinceYears,
    required this.preferredChannels,
    required this.frequencyByMonth,
    this.aiConfidence,
  });

  final String contactId;
  final String summary;
  final String why;
  final String recommendedAction;
  final int potentialScoreGain;
  final String relationshipLabel;
  final int knownSinceYears;
  final List<String> preferredChannels;
  final List<int> frequencyByMonth;
  final double? aiConfidence;
}

class AiUpdateResult {
  const AiUpdateResult({
    required this.summary,
    required this.contactId,
    required this.interactions,
    this.nextStep,
    this.memoryDocument,
  });
  final String summary;
  final String contactId;
  final List<CrmInteraction> interactions;
  final String? nextStep;

  /// The new memory document produced by this run, ready to be persisted
  /// in the commit step. Nullable so legacy in-memory construction (no
  /// memory delta) still works; #042 unified `AiUpdate.run` always
  /// populates it.
  final MemoryDocument? memoryDocument;
}
