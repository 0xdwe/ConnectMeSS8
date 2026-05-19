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
  final defaults = _topicDefaultsByCategory[connection.category] ??
      _genericTopicDefaults;
  return defaults.take(4).toList(growable: false);
}

/// Returns 3-5 conversation-starter suggestions for a
/// `(category, topic, contactName)` tuple.
///
/// Pass 3 (#043): looks up the curated static map only and falls back
/// to a generic three-line list when the (category, topic) is unknown.
/// The templated `{firstName}`-based fallback for memory-extracted
/// topics lands in #044; `contactName` is accepted now to stabilize
/// the signature ahead of that change.
List<String> suggestionsForTopic(
    String category, String topic, String contactName) {
  return _topicSuggestions[category]?[topic] ?? _genericSuggestions;
}

const Map<String, List<String>> _topicDefaultsByCategory = {
  'Family':      ['Family updates', 'Shared memories', 'Daily life', 'Future plans'],
  'Friends':     ['Recent meetups', 'Inside jokes', 'Plans together', 'Life updates'],
  'College':     ['Old classes', 'Mutual friends', 'Career', 'Reunions'],
  'High School': ['Old times', 'Mutual friends', 'Where they are now', 'Reunions'],
  'Work':        ['Projects', 'Career', 'Industry news', 'Team updates'],
};

const List<String> _genericTopicDefaults = [
  'Recent updates',
  'Shared interests',
  'Life events',
  'Future plans',
];

const Map<String, Map<String, List<String>>> _topicSuggestions = {
  'Family': {
    'Family updates':  ['Ask how the family is doing', 'Share a recent family photo', 'Mention an upcoming family event'],
    'Shared memories': ['Recall a favorite holiday', 'Bring up a childhood story', 'Reference a shared inside joke'],
    'Daily life':      ['Ask about their week', 'Share something from your routine', 'Plan a regular check-in'],
    'Future plans':    ['Discuss travel ideas', 'Talk about upcoming milestones', 'Mention something you want to do together'],
  },
  'Friends': {
    'Recent meetups':  ['Reference the last hangout', 'Plan the next one', 'Share a photo from the last meet-up'],
    'Inside jokes':    ['Bring up a running joke', 'Send a meme that fits your vibe', 'Reminisce about a funny moment'],
    'Plans together':  ['Suggest a coffee or meal', 'Pitch a small adventure', 'Pick a date that works for both'],
    'Life updates':    ['Ask what\'s been new lately', 'Share something from your week', 'Catch up on the bigger picture'],
  },
  'College': {
    'Old classes':       ['Bring up a favorite class', 'Reference a tough exam you survived', 'Mention a professor you both had'],
    'Mutual friends':    ['Ask if they\'re still in touch with someone', 'Share an update about a mutual friend', 'Suggest a small reunion'],
    'Career':            ['Ask how work is going', 'Share a career update of your own', 'Talk about industry shifts'],
    'Reunions':          ['Float a meet-up idea', 'Mention an upcoming alumni event', 'Suggest a video call to catch up'],
  },
  'High School': {
    'Old times':              ['Reference a memorable moment', 'Share an old photo', 'Bring up a teacher you both remember'],
    'Mutual friends':         ['Ask about a shared friend', 'Suggest a group chat', 'Share what you\'ve heard from someone'],
    'Where they are now':     ['Ask what they\'re up to these days', 'Share what you\'re focused on', 'Compare notes on life stage'],
    'Reunions':               ['Mention an upcoming reunion', 'Pitch a small get-together', 'Suggest a quick video call'],
  },
  'Work': {
    'Projects':       ['Ask what they\'re working on', 'Share a recent project win', 'Trade notes on a tough problem'],
    'Career':         ['Ask about career goals', 'Share an opportunity you saw', 'Compare notes on growth'],
    'Industry news':  ['Reference a recent headline', 'Share an article you found useful', 'Ask their take on a trend'],
    'Team updates':   ['Ask how the team is doing', 'Share a team change of your own', 'Talk about working styles'],
  },
};

const List<String> _genericSuggestions = [
  'Ask an open question about how they\'ve been',
  'Share a recent update from your own life',
  'Suggest meeting up',
];
