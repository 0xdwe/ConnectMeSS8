class AboutFeature {
  final String emoji;
  final String title;
  final String description;

  const AboutFeature({
    required this.emoji,
    required this.title,
    required this.description,
  });
}

const List<AboutFeature> kAboutFeatures = [
  AboutFeature(
    emoji: '🤖',
    title: 'AI Memory Updates',
    description: 'Generates deep Markdown memories summarizing contact histories, preferences, and key topics.',
  ),
  AboutFeature(
    emoji: '📈',
    title: 'Bond Score & Drift',
    description: 'Tracks relationship health (0–100) with Bond Rings and automatic cadence-based Bond Drift.',
  ),
  AboutFeature(
    emoji: '☁️',
    title: 'Firebase Cloud Sync',
    description: 'Full real-time sync of connections, interactions, events, and memories via Firebase Auth.',
  ),
  AboutFeature(
    emoji: '🔔',
    title: 'Smart Notifications',
    description: 'Durable notification settings for check-in suggestions, quiet hours, and planner lead times.',
  ),
  AboutFeature(
    emoji: '👤',
    title: 'Auth-Backed Profiles',
    description: 'Upload profile pictures to Firebase Storage and update your Auth display name.',
  ),
];
