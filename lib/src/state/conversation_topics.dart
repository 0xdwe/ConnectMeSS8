/// Pure conversation-topics module (#043).
///
/// Two top-level functions plus file-private static maps. Extracted
/// from `lib/src/widgets/crm_widgets.dart` so the data source can swap
/// between `MemoryDocument.topics` and the static category-default
/// fallback without dragging widget imports along for the ride.
///
/// Pass 3 (#043): static map only for `suggestionsForTopic`. The
/// templated fallback for memory-extracted topics lands in #044 — the
/// `contactName` parameter is accepted now to stabilize the signature.
library;

import '../models/social_models.dart';
import 'memory/memory_document.dart';

/// Returns up to 4 topic strings for a contact, preferring memory
/// topics when present and falling back to category defaults when
/// `memory.topics` is empty (or `memory` is null).
///
/// The 4 cap matches the Pass 2 pill-row presentation. Memory may
/// already be capped at 8 (PRD Q6); this caps the visible row at 4.
List<String> topicsForContact(Connection connection, MemoryDocument? memory) {
  final memoryTopics = memory?.topics ?? const <String>[];
  if (memoryTopics.isNotEmpty) {
    return memoryTopics.take(4).toList(growable: false);
  }
  final defaults =
      _topicDefaultsByCategory[connection.category] ?? _genericTopicDefaults;
  return defaults.take(4).toList(growable: false);
}

/// Returns conversation-starter suggestions for a topic tap.
///
/// Prepared non-expired Topic Suggestions from [memory] win first, with
/// blank prepared strings dropped and the result capped to three. When
/// prepared suggestions are missing, expired, or blank after trimming,
/// this falls back to [suggestionsForTopic].
List<TopicSuggestion> preferredSuggestionsForTopic({
  required String category,
  required String topic,
  required String contactName,
  required MemoryDocument? memory,
  DateTime? now,
}) {
  final prepared = _preparedSuggestionsForTopic(
    memory,
    topic,
    now ?? DateTime.now(),
  );
  if (prepared.isNotEmpty) {
    return prepared.map((s) {
      if (s.context == null || s.context!.trim().isEmpty) {
        return TopicSuggestion(
          kind: s.kind,
          text: s.text,
          context: _fallbackContext(category, topic, contactName),
        );
      }
      return s;
    }).toList(growable: false);
  }
  return suggestionsForTopic(category, topic, contactName)
      .map((str) => TopicSuggestion(
            kind: TopicSuggestionKind.ask,
            text: str,
            context: _fallbackContext(category, topic, contactName),
          ))
      .toList(growable: false);
}

/// Returns 3-5 deterministic conversation-starter suggestions for a
/// `(category, topic, contactName)` tuple.
///
/// Pass 3 (#044): the static `_topicSuggestions` map is consulted
/// first; on a miss, three rotating templates with `{topic}` and
/// `{firstName}` slots filled in are returned so memory-extracted
/// topics like `violin lessons` or `kindergarten` get useful prompts
/// rather than the generic three-line fallback. The generic list
/// remains the safety net for degenerate inputs (empty `topic` or
/// empty `contactName`), where rendering a template would produce
/// awkward strings.
///
/// First name is the leading whitespace-split token of `contactName`
/// (e.g., `'Mike Chen'` → `'Mike'`, `'Mike'` → `'Mike'`).
List<String> suggestionsForTopic(
  String category,
  String topic,
  String contactName,
) {
  final curated = _topicSuggestions[category]?[topic];
  if (curated != null) return curated;

  // Degenerate input: blank topic or blank contact name would render
  // an empty slot like "How's the  going?" or "Curious how 's …".
  // The generic three-line list is a friendlier fallback than that.
  final trimmedTopic = topic.trim();
  final trimmedContact = contactName.trim();
  if (trimmedTopic.isEmpty || trimmedContact.isEmpty) {
    return _genericSuggestions;
  }

  final firstName = _firstNameOf(trimmedContact);
  return <String>[
    "How's the $trimmedTopic going?",
    'Last time you mentioned $trimmedTopic \u2014 anything new?',
    "Curious how $firstName's $trimmedTopic is going.",
  ];
}

List<TopicSuggestion> _preparedSuggestionsForTopic(
  MemoryDocument? memory,
  String topic,
  DateTime now,
) {
  if (memory == null) return const [];
  final normalizedTopic = topic.trim().toLowerCase();
  if (normalizedTopic.isEmpty) return const [];

  for (final group in memory.topicSuggestions) {
    if (group.topic.trim().toLowerCase() != normalizedTopic) continue;
    final expiresAt = group.expiresAt;
    if (expiresAt != null && !_sameOrAfterDay(expiresAt, now)) {
      return const [];
    }
    return group.suggestions
        .where((suggestion) => suggestion.text.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
  }
  return const [];
}

bool _sameOrAfterDay(DateTime candidate, DateTime now) {
  final candidateDay = DateTime(candidate.year, candidate.month, candidate.day);
  final nowDay = DateTime(now.year, now.month, now.day);
  return !candidateDay.isBefore(nowDay);
}

/// Returns the leading whitespace-split token of [contactName]. Caller
/// is responsible for passing an already-trimmed string when it has a
/// fallback for empty inputs; this helper does not re-trim.
String _firstNameOf(String contactName) {
  final match = RegExp(r'\s+').firstMatch(contactName);
  if (match == null) return contactName;
  return contactName.substring(0, match.start);
}

const Map<String, List<String>> _topicDefaultsByCategory = {
  'Family': ['Family updates', 'Shared memories', 'Daily life', 'Future plans'],
  'Friends': [
    'Recent meetups',
    'Inside jokes',
    'Plans together',
    'Life updates',
  ],
  'College': ['Old classes', 'Mutual friends', 'Career', 'Reunions'],
  'High School': [
    'Old times',
    'Mutual friends',
    'Where they are now',
    'Reunions',
  ],
  'Work': ['Projects', 'Career', 'Industry news', 'Team updates'],
};

const List<String> _genericTopicDefaults = [
  'Recent updates',
  'Shared interests',
  'Life events',
  'Future plans',
];

const Map<String, Map<String, List<String>>> _topicSuggestions = {
  'Family': {
    'Family updates': [
      'Ask how the family is doing',
      'Share a recent family photo',
      'Mention an upcoming family event',
    ],
    'Shared memories': [
      'Recall a favorite holiday',
      'Bring up a childhood story',
      'Reference a shared inside joke',
    ],
    'Daily life': [
      'Ask about their week',
      'Share something from your routine',
      'Plan a regular check-in',
    ],
    'Future plans': [
      'Discuss travel ideas',
      'Talk about upcoming milestones',
      'Mention something you want to do together',
    ],
  },
  'Friends': {
    'Recent meetups': [
      'Reference the last hangout',
      'Plan the next one',
      'Share a photo from the last meet-up',
    ],
    'Inside jokes': [
      'Bring up a running joke',
      'Send a meme that fits your vibe',
      'Reminisce about a funny moment',
    ],
    'Plans together': [
      'Suggest a coffee or meal',
      'Pitch a small adventure',
      'Pick a date that works for both',
    ],
    'Life updates': [
      'Ask what\'s been new lately',
      'Share something from your week',
      'Catch up on the bigger picture',
    ],
  },
  'College': {
    'Old classes': [
      'Bring up a favorite class',
      'Reference a tough exam you survived',
      'Mention a professor you both had',
    ],
    'Mutual friends': [
      'Ask if they\'re still in touch with someone',
      'Share an update about a mutual friend',
      'Suggest a small reunion',
    ],
    'Career': [
      'Ask how work is going',
      'Share a career update of your own',
      'Talk about industry shifts',
    ],
    'Reunions': [
      'Float a meet-up idea',
      'Mention an upcoming alumni event',
      'Suggest a video call to catch up',
    ],
  },
  'High School': {
    'Old times': [
      'Reference a memorable moment',
      'Share an old photo',
      'Bring up a teacher you both remember',
    ],
    'Mutual friends': [
      'Ask about a shared friend',
      'Suggest a group chat',
      'Share what you\'ve heard from someone',
    ],
    'Where they are now': [
      'Ask what they\'re up to these days',
      'Share what you\'re focused on',
      'Compare notes on life stage',
    ],
    'Reunions': [
      'Mention an upcoming reunion',
      'Pitch a small get-together',
      'Suggest a quick video call',
    ],
  },
  'Work': {
    'Projects': [
      'Ask what they\'re working on',
      'Share a recent project win',
      'Trade notes on a tough problem',
    ],
    'Career': [
      'Ask about career goals',
      'Share an opportunity you saw',
      'Compare notes on growth',
    ],
    'Industry news': [
      'Reference a recent headline',
      'Share an article you found useful',
      'Ask their take on a trend',
    ],
    'Team updates': [
      'Ask how the team is doing',
      'Share a team change of your own',
      'Talk about working styles',
    ],
  },
};

const List<String> _genericSuggestions = [
  'Ask an open question about how they\'ve been',
  'Share a recent update from your own life',
  'Suggest meeting up',
];

String _fallbackContext(String category, String topic, String contactName) {
  final firstName = _firstNameOf(contactName.trim());
  final lowerTopic = topic.trim().toLowerCase();
  
  if (lowerTopic == 'family updates') {
    return 'Based on family relations with $firstName.';
  }
  if (lowerTopic == 'shared memories') {
    return 'Based on past shared experiences with $firstName.';
  }
  if (lowerTopic == 'daily life') {
    return 'Based on daily life updates from $firstName.';
  }
  if (lowerTopic == 'future plans') {
    return 'Based on future plans discussed with $firstName.';
  }
  if (lowerTopic == 'recent meetups') {
    return 'Based on recent hangouts and meetups with $firstName.';
  }
  if (lowerTopic == 'inside jokes') {
    return 'Based on inside jokes and funny moments shared with $firstName.';
  }
  if (lowerTopic == 'plans together') {
    return 'Based on plans you want to make together with $firstName.';
  }
  if (lowerTopic == 'life updates') {
    return 'Based on general life updates from $firstName.';
  }
  if (lowerTopic == 'old classes') {
    return 'Based on college classes taken with $firstName.';
  }
  if (lowerTopic == 'mutual friends') {
    return 'Based on mutual friends shared with $firstName.';
  }
  if (lowerTopic == 'career') {
    return 'Based on career and professional updates from $firstName.';
  }
  if (lowerTopic == 'reunions') {
    return 'Based on upcoming reunions or get-togethers with $firstName.';
  }
  if (lowerTopic == 'old times') {
    return 'Based on old memories and high school times shared with $firstName.';
  }
  if (lowerTopic == 'where they are now') {
    return 'Based on catching up with where $firstName is now.';
  }
  if (lowerTopic == 'projects') {
    return 'Based on professional projects worked on with $firstName.';
  }
  if (lowerTopic == 'industry news') {
    return 'Based on industry updates and news relevant to $firstName.';
  }
  if (lowerTopic == 'team updates') {
    return 'Based on team and workplace updates from $firstName.';
  }
  
  final trimmedTopic = topic.trim();
  if (trimmedTopic.isNotEmpty) {
    return "Based on the conversation topic '$trimmedTopic' associated with $firstName.";
  }
  return "General relationship check-in suggestion for $firstName.";
}
