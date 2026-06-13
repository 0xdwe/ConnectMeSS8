class AboutFeature {
  final String title;
  final String description;

  const AboutFeature({
    required this.title,
    required this.description,
  });
}

const List<AboutFeature> kAboutFeatures = [
  AboutFeature(
    title: 'AI Memory Updates',
    description: 'Generates deep Markdown memories summarizing contact histories, preferences, and key topics.',
  ),
  AboutFeature(
    title: 'Bond Score & Drift',
    description: 'Tracks relationship health (0–100) with Bond Rings and automatic cadence-based Bond Drift.',
  ),
  AboutFeature(
    title: 'Firebase Cloud Sync',
    description: 'Full real-time sync of connections, interactions, events, and memories via Firebase Auth.',
  ),
  AboutFeature(
    title: 'Smart Notifications',
    description: 'Durable notification settings for check-in suggestions, quiet hours, and planner lead times.',
  ),
  AboutFeature(
    title: 'Auth-Backed Profiles',
    description: 'Upload profile pictures to Firebase Storage and update your Auth display name.',
  ),
];
