import 'package:yaml/yaml.dart';

/// An entry on the `## Upcoming` section of a memory document.
///
/// `endDate` is optional. When present, the entry represents a span
/// (e.g., a trip); when absent, a single dated note (e.g., a deadline).
class UpcomingEntry {
  const UpcomingEntry({
    required this.startDate,
    this.endDate,
    required this.description,
  });

  final DateTime startDate;
  final DateTime? endDate;
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpcomingEntry &&
          runtimeType == other.runtimeType &&
          _sameDay(startDate, other.startDate) &&
          _sameDayNullable(endDate, other.endDate) &&
          description == other.description;

  @override
  int get hashCode => Object.hash(
    _dayKey(startDate),
    endDate == null ? null : _dayKey(endDate!),
    description,
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _sameDayNullable(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return _sameDay(a, b);
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

enum TopicSuggestionKind { ask, share, plan, remember }

class TopicSuggestion {
  const TopicSuggestion({required this.kind, required this.text});

  final TopicSuggestionKind kind;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicSuggestion && kind == other.kind && text == other.text;

  @override
  int get hashCode => Object.hash(kind, text);
}

class TopicSuggestionGroup {
  const TopicSuggestionGroup({
    required this.topic,
    this.lastMentionedAt,
    this.mentionCount = 0,
    this.expiresAt,
    this.suggestions = const [],
  });

  final String topic;
  final DateTime? lastMentionedAt;
  final int mentionCount;
  final DateTime? expiresAt;
  final List<TopicSuggestion> suggestions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicSuggestionGroup &&
          topic == other.topic &&
          MemoryDocument._sameDayNullable(
            lastMentionedAt,
            other.lastMentionedAt,
          ) &&
          mentionCount == other.mentionCount &&
          MemoryDocument._sameDayNullable(expiresAt, other.expiresAt) &&
          MemoryDocument._listEquals(suggestions, other.suggestions);

  @override
  int get hashCode => Object.hash(
    topic,
    lastMentionedAt == null ? null : MemoryDocument._dayKey(lastMentionedAt!),
    mentionCount,
    expiresAt == null ? null : MemoryDocument._dayKey(expiresAt!),
    Object.hashAll(suggestions),
  );
}

/// Immutable per-contact memory document. Markdown body + YAML frontmatter.
///
/// Parse is **total**: `MemoryDocument.parse(raw)` never throws on any
/// input, including bytes/garbage. Malformed regions are reported via
/// `parseErrors`; the rest of the document parses.
class MemoryDocument {
  const MemoryDocument({
    required this.contactId,
    required this.displayName,
    required this.lastUpdated,
    this.version = 1,
    this.summary = '',
    this.history = '',
    this.preferences = '',
    this.topics = const [],
    this.topicSuggestions = const [],
    this.upcoming = const [],
    this.parseErrors = const [],
  });

  final String contactId;
  final String displayName;
  final DateTime lastUpdated;
  final int version;
  final String summary;
  final String history;
  final String preferences;
  final List<String> topics;
  final List<TopicSuggestionGroup> topicSuggestions;
  final List<UpcomingEntry> upcoming;
  final List<String> parseErrors;

  /// Empty memory document for a brand-new contact. `now` defaults to
  /// `DateTime.now()`; tests that need a deterministic timestamp pass it
  /// explicitly.
  factory MemoryDocument.empty({
    required String contactId,
    required String displayName,
    DateTime? now,
  }) {
    return MemoryDocument(
      contactId: contactId,
      displayName: displayName,
      lastUpdated: now ?? DateTime.now(),
      version: 1,
    );
  }

  /// Maximum number of topics retained on parse and on render.
  static const int topicCap = 8;

  static final RegExp _frontmatterRegExp = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?',
    multiLine: false,
  );

  /// Total parser. Never throws.
  static MemoryDocument parse(String raw) {
    final errors = <String>[];

    String body = raw;
    Map<String, dynamic> frontmatter = const {};

    final match = _frontmatterRegExp.firstMatch(raw);
    if (match != null) {
      final yamlText = match.group(1) ?? '';
      try {
        final parsed = loadYaml(yamlText);
        if (parsed is YamlMap) {
          frontmatter = {
            for (final entry in parsed.entries)
              entry.key.toString(): entry.value,
          };
        } else if (parsed != null) {
          errors.add('frontmatter: expected map, got ${parsed.runtimeType}');
        }
        body = raw.substring(match.end);
      } catch (e) {
        errors.add('frontmatter: $e');
        // Treat the whole input as body so the rest still parses.
        body = raw;
      }
    }

    String contactId = '';
    String displayName = '';
    DateTime lastUpdated = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    int version = 1;

    final rawContactId = frontmatter['contactId'];
    if (rawContactId is String && rawContactId.isNotEmpty) {
      contactId = rawContactId;
    } else {
      errors.add('missing contactId');
    }

    final rawDisplayName = frontmatter['displayName'];
    if (rawDisplayName is String) {
      displayName = rawDisplayName;
    }

    final rawLastUpdated = frontmatter['lastUpdated'];
    if (rawLastUpdated is String && rawLastUpdated.isNotEmpty) {
      try {
        lastUpdated = DateTime.parse(rawLastUpdated);
      } catch (_) {
        errors.add('lastUpdated: cannot parse "$rawLastUpdated"');
      }
    } else if (rawLastUpdated is DateTime) {
      lastUpdated = rawLastUpdated;
    }

    final rawVersion = frontmatter['version'];
    if (rawVersion is int) {
      version = rawVersion;
    } else if (rawVersion is String) {
      version = int.tryParse(rawVersion) ?? 1;
    }

    // Section split on lines starting with "## ". Preserve the rest as
    // each section's body.
    final sections = _splitSections(body);

    String summary = '';
    String history = '';
    String preferences = '';
    final topicsRaw = <String>[];
    final topicSuggestions = <TopicSuggestionGroup>[];
    final upcoming = <UpcomingEntry>[];

    sections.forEach((header, sectionBody) {
      final trimmed = sectionBody.trim();
      switch (header) {
        case 'Summary':
          summary = trimmed;
          break;
        case 'History':
          history = trimmed;
          break;
        case 'Preferences':
          preferences = trimmed;
          break;
        case 'Topics':
          topicsRaw.addAll(_parseBullets(trimmed));
          break;
        case 'Topic Suggestions':
          topicSuggestions.addAll(_parseTopicSuggestions(trimmed));
          break;
        case 'Upcoming':
          for (final bullet in _parseBullets(trimmed)) {
            final entry = _parseUpcomingBullet(bullet, errors);
            if (entry != null) upcoming.add(entry);
          }
          break;
        default:
          errors.add('unknown section: $header');
      }
    });

    final dedupedTopics = _dedupeTopics(topicsRaw);
    final cappedTopics = dedupedTopics.length > topicCap
        ? dedupedTopics.sublist(0, topicCap)
        : dedupedTopics;

    return MemoryDocument(
      contactId: contactId,
      displayName: displayName,
      lastUpdated: lastUpdated,
      version: version,
      summary: summary,
      history: history,
      preferences: preferences,
      topics: List.unmodifiable(cappedTopics),
      topicSuggestions: List.unmodifiable(topicSuggestions),
      upcoming: List.unmodifiable(upcoming),
      parseErrors: List.unmodifiable(errors),
    );
  }

  /// Lossless round-trip render.
  String render() {
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln("contactId: '${_yamlEscape(contactId)}'");
    buf.writeln("displayName: '${_yamlEscape(displayName)}'");
    buf.writeln("lastUpdated: '${_yamlEscape(lastUpdated.toIso8601String())}'");
    buf.writeln('version: $version');
    buf.writeln('---');

    buf.writeln();
    buf.writeln('## Summary');
    buf.writeln(summary);

    buf.writeln();
    buf.writeln('## History');
    buf.writeln(history);

    buf.writeln();
    buf.writeln('## Preferences');
    buf.writeln(preferences);

    buf.writeln();
    buf.writeln('## Topics');
    for (final topic in topics.take(topicCap)) {
      buf.writeln('- $topic');
    }

    buf.writeln();
    buf.writeln('## Topic Suggestions');
    for (final group in topicSuggestions) {
      buf.writeln();
      buf.writeln('### ${group.topic}');
      buf.writeln(
        'lastMentionedAt: ${_formatNullableDate(group.lastMentionedAt)}',
      );
      buf.writeln('mentionCount: ${group.mentionCount}');
      buf.writeln('expiresAt: ${_formatNullableDate(group.expiresAt)}');
      for (final suggestion in group.suggestions.take(3)) {
        buf.writeln(
          '- ${_renderTopicSuggestionKind(suggestion.kind)}: ${suggestion.text}',
        );
      }
    }

    buf.writeln();
    buf.writeln('## Upcoming');
    for (final entry in upcoming) {
      buf.writeln('- ${_renderUpcoming(entry)}');
    }

    return buf.toString();
  }

  MemoryDocument copyWith({
    String? contactId,
    String? displayName,
    DateTime? lastUpdated,
    int? version,
    String? summary,
    String? history,
    String? preferences,
    List<String>? topics,
    List<TopicSuggestionGroup>? topicSuggestions,
    List<UpcomingEntry>? upcoming,
    List<String>? parseErrors,
  }) {
    return MemoryDocument(
      contactId: contactId ?? this.contactId,
      displayName: displayName ?? this.displayName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      version: version ?? this.version,
      summary: summary ?? this.summary,
      history: history ?? this.history,
      preferences: preferences ?? this.preferences,
      topics: topics ?? this.topics,
      topicSuggestions: topicSuggestions ?? this.topicSuggestions,
      upcoming: upcoming ?? this.upcoming,
      parseErrors: parseErrors ?? this.parseErrors,
    );
  }

  // -- helpers ---------------------------------------------------------

  /// Splits `body` on lines beginning with `## `. Returns a map from
  /// header → body. Headers preserve their original case. Content
  /// before the first `## ` line is dropped.
  static Map<String, String> _splitSections(String body) {
    final result = <String, String>{};
    final lines = body.split('\n');
    String? currentHeader;
    final currentBody = StringBuffer();

    void flush() {
      final header = currentHeader;
      if (header != null) {
        result[header] = currentBody.toString();
        currentBody.clear();
      }
    }

    for (final line in lines) {
      if (line.startsWith('## ')) {
        flush();
        currentHeader = line.substring(3).trim();
      } else if (currentHeader != null) {
        currentBody.writeln(line);
      }
    }
    flush();
    return result;
  }

  /// Returns trimmed bullet bodies for lines starting with `- ` or `* `.
  /// Drops empties.
  static List<String> _parseBullets(String body) {
    final out = <String>[];
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('- ')) {
        final value = line.substring(2).trim();
        if (value.isNotEmpty) out.add(value);
      } else if (line.startsWith('* ')) {
        final value = line.substring(2).trim();
        if (value.isNotEmpty) out.add(value);
      }
    }
    return out;
  }

  /// Case-insensitive dedup, preserving first-occurrence original case.
  static List<String> _dedupeTopics(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final topic in raw) {
      final key = topic.toLowerCase();
      if (seen.add(key)) out.add(topic);
    }
    return out;
  }

  static List<TopicSuggestionGroup> _parseTopicSuggestions(String body) {
    final out = <TopicSuggestionGroup>[];
    String? topic;
    DateTime? lastMentionedAt;
    int mentionCount = 0;
    DateTime? expiresAt;
    final suggestions = <TopicSuggestion>[];

    void flush() {
      final currentTopic = topic?.trim();
      if (currentTopic == null || currentTopic.isEmpty) return;
      out.add(
        TopicSuggestionGroup(
          topic: currentTopic,
          lastMentionedAt: lastMentionedAt,
          mentionCount: mentionCount,
          expiresAt: expiresAt,
          suggestions: List.unmodifiable(suggestions.take(3).toList()),
        ),
      );
    }

    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('### ')) {
        flush();
        topic = line.substring(4).trim();
        lastMentionedAt = null;
        mentionCount = 0;
        expiresAt = null;
        suggestions.clear();
        continue;
      }
      if (topic == null) continue;
      if (line.startsWith('lastMentionedAt:')) {
        lastMentionedAt = _tryParseDateOnly(line.substring(16).trim());
      } else if (line.startsWith('mentionCount:')) {
        mentionCount = int.tryParse(line.substring(13).trim()) ?? 0;
      } else if (line.startsWith('expiresAt:')) {
        expiresAt = _tryParseDateOnly(line.substring(10).trim());
      } else if (line.startsWith('- ')) {
        final suggestion = _parseTopicSuggestion(line.substring(2).trim());
        if (suggestion != null && suggestions.length < 3) {
          suggestions.add(suggestion);
        }
      }
    }
    flush();
    return out;
  }

  static TopicSuggestion? _parseTopicSuggestion(String raw) {
    final separator = raw.indexOf(':');
    if (separator <= 0) return null;
    final kind = _parseTopicSuggestionKind(raw.substring(0, separator).trim());
    final text = raw.substring(separator + 1).trim();
    if (kind == null || text.isEmpty) return null;
    return TopicSuggestion(kind: kind, text: text);
  }

  static TopicSuggestionKind? _parseTopicSuggestionKind(String raw) {
    switch (raw) {
      case 'ask':
        return TopicSuggestionKind.ask;
      case 'share':
        return TopicSuggestionKind.share;
      case 'plan':
        return TopicSuggestionKind.plan;
      case 'remember':
        return TopicSuggestionKind.remember;
    }
    return null;
  }

  static String _renderTopicSuggestionKind(TopicSuggestionKind kind) {
    switch (kind) {
      case TopicSuggestionKind.ask:
        return 'ask';
      case TopicSuggestionKind.share:
        return 'share';
      case TopicSuggestionKind.plan:
        return 'plan';
      case TopicSuggestionKind.remember:
        return 'remember';
    }
  }

  static DateTime? _tryParseDateOnly(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Parses a single `## Upcoming` bullet body.
  ///
  /// Format: `YYYY-MM-DD[/YYYY-MM-DD] description`. The description is
  /// everything after the first space following the date(s).
  static UpcomingEntry? _parseUpcomingBullet(
    String bullet,
    List<String> errors,
  ) {
    final spaceIdx = bullet.indexOf(' ');
    if (spaceIdx <= 0) {
      errors.add('upcoming: missing description in "$bullet"');
      return null;
    }
    final datePart = bullet.substring(0, spaceIdx);
    final description = bullet.substring(spaceIdx + 1).trim();
    if (description.isEmpty) {
      errors.add('upcoming: empty description in "$bullet"');
      return null;
    }
    try {
      if (datePart.contains('/')) {
        final parts = datePart.split('/');
        if (parts.length != 2) {
          errors.add('upcoming: malformed date range "$datePart"');
          return null;
        }
        final start = DateTime.parse(parts[0]);
        final end = DateTime.parse(parts[1]);
        return UpcomingEntry(
          startDate: start,
          endDate: end,
          description: description,
        );
      } else {
        final start = DateTime.parse(datePart);
        return UpcomingEntry(startDate: start, description: description);
      }
    } catch (_) {
      errors.add('upcoming: cannot parse date "$datePart"');
      return null;
    }
  }

  static String _renderUpcoming(UpcomingEntry entry) {
    final start = _formatDate(entry.startDate);
    if (entry.endDate != null) {
      return '$start/${_formatDate(entry.endDate!)} ${entry.description}';
    }
    return '$start ${entry.description}';
  }

  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _formatNullableDate(DateTime? d) =>
      d == null ? '' : _formatDate(d);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameDayNullable(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dayKey(DateTime d) => _formatDate(d);

  static String _yamlEscape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", "''");
}
