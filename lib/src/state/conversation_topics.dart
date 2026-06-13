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
/// blank prepared strings dropped and the result capped to two. When
/// prepared suggestions are missing, expired, or blank after trimming,
/// this falls back to [suggestionsForTopic].
List<TopicSuggestion> preferredSuggestionsForTopic({
  required Connection connection,
  required MemoryDocument? memory,
  required String topic,
  DateTime? now,
}) {
  final prepared = _preparedSuggestionsForTopic(
    memory,
    topic,
    now ?? DateTime.now(),
  );
  final fallback = _fallbackContext(
    connection: connection,
    memory: memory,
    topic: topic,
  );
  if (prepared.isNotEmpty) {
    return prepared.map((s) {
      if (s.context == null || s.context!.trim().isEmpty) {
        return TopicSuggestion(
          kind: s.kind,
          text: s.text,
          context: fallback,
        );
      }
      return s;
    }).toList(growable: false);
  }
  return suggestionsForTopic(connection.category, topic, connection.name)
      .take(2)
      .map((str) => TopicSuggestion(
            kind: TopicSuggestionKind.ask,
            text: str,
            context: fallback,
          ))
      .toList(growable: false);
}

/// Returns 2-3 deterministic conversation-starter suggestions for a
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
        .take(2)
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

const _stopWords = {
  'a', 'an', 'the', 'in', 'on', 'at', 'to', 'for', 'of', 'and', 'or', 'with', 
  'about', 'is', 'was', 'were', 'trip', 'plans', 'updates', 'recent', 'shared', 
  'life', 'future', 'old', 'times', 'news', 'team', 'some', 'any', 'how', 
  'what', 'who', 'where', 'why', 'my', 'your', 'his', 'her', 'their', 'our', 
  'its', 'he', 'she', 'they', 'we', 'it', 'me', 'you', 'him', 'them', 'us',
  'like', 'associated', 'person'
};

class _MatchCandidate {
  final String text;
  final int score;
  final DateTime? date;
  final int sourcePriority;

  _MatchCandidate({
    required this.text,
    required this.score,
    this.date,
    required this.sourcePriority,
  });
}

String? _fallbackContext({
  required Connection connection,
  required MemoryDocument? memory,
  required String topic,
}) {
  final cleanTopic = topic.trim();
  if (cleanTopic.isEmpty) return null;

  final keywords = cleanTopic
      .toLowerCase()
      .split(RegExp(r'\W+'))
      .where((k) => k.isNotEmpty && !_stopWords.contains(k))
      .toSet();

  if (keywords.isEmpty) return null;

  final candidates = <_MatchCandidate>[];

  if (memory != null && memory.history.trim().isNotEmpty) {
    final historyLineRegex = RegExp(r'^\s*[-*]\s*(\d{4}-\d{2}-\d{2})\s*(?:—|–|-|:)\s*(.*)$');
    final lines = memory.history.split('\n');
    for (final line in lines) {
      final match = historyLineRegex.firstMatch(line);
      if (match != null) {
        final dateStr = match.group(1)!;
        final bodyText = match.group(2)!.trim();
        if (bodyText.isEmpty) continue;

        final parsedDate = DateTime.tryParse('${dateStr}T00:00:00Z');
        final score = _calculateScore(bodyText, keywords);
        if (score > 0) {
          candidates.add(_MatchCandidate(
            text: bodyText,
            score: score,
            date: parsedDate,
            sourcePriority: 0,
          ));
        }
      }
    }
  }

  if (memory != null && memory.summary.trim().isNotEmpty) {
    final sentences = memory.summary.split(RegExp(r'(?<=[.!?])\s+'));
    for (final sentence in sentences) {
      final cleanSentence = sentence.trim();
      if (cleanSentence.isEmpty) continue;
      final score = _calculateScore(cleanSentence, keywords);
      if (score > 0) {
        candidates.add(_MatchCandidate(
          text: cleanSentence,
          score: score,
          sourcePriority: 1,
        ));
      }
    }
  }

  if (connection.notes.trim().isNotEmpty) {
    final lines = connection.notes.split('\n');
    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;
      final score = _calculateScore(cleanLine, keywords);
      if (score > 0) {
        candidates.add(_MatchCandidate(
          text: cleanLine,
          score: score,
          sourcePriority: 2,
        ));
      }
    }
  }

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    if (a.score != b.score) {
      return b.score.compareTo(a.score);
    }
    if (a.sourcePriority != b.sourcePriority) {
      return a.sourcePriority.compareTo(b.sourcePriority);
    }
    if (a.date != null && b.date != null) {
      return b.date!.compareTo(a.date!);
    }
    return 0;
  });

  final best = candidates.first;

  if (best.sourcePriority == 0 && best.date != null) {
    final formattedDate = _formatDateFriendly(best.date!);
    var text = best.text;
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return '$text (from check-in on $formattedDate)';
  }

  return best.text;
}

int _calculateScore(String text, Set<String> keywords) {
  final textLower = text.toLowerCase();
  int score = 0;
  for (final kw in keywords) {
    if (textLower.contains(kw)) {
      score++;
    }
  }
  return score;
}

String _formatDateFriendly(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final monthStr = months[date.month - 1];
  return '$monthStr ${date.day}, ${date.year}';
}
