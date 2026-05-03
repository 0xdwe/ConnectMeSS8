import 'package:flutter/material.dart';

enum InteractionType {
  interaction,
  personalDetail,
  preference,
  reminder,
  sharedActivity,
  relationshipNote,
}

enum ContactSort { name, lastContact, bondScore }

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
  });

  final String id;
  final String contactId;
  final InteractionType type;
  final String title;
  final String note;
  final DateTime date;
  final List<AttachmentRef> attachments;
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

  String get role => category;
  String get company => email;
  String get avatarSeed => avatar;
  int get closeness => bondScore;
  List<String> get tags => [category];

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
    );
  }
}

class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    required this.contactId,
    required this.category,
    required this.date,
    required this.note,
  });

  final String id;
  final String title;
  final String contactId;
  final String category;
  final DateTime date;
  final String note;
}

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
  });
  final String summary;
  final String contactId;
  final List<CrmInteraction> interactions;
  final String? nextStep;
}
