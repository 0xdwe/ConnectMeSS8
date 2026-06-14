import 'package:connect_me/src/features/recommendations_screen.dart';
import 'package:connect_me/src/features/tabs/home_tab.dart';
import 'package:connect_me/src/models/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('topic-aware recommendation routes (#099)', () {
    test('Home route includes topic query for topic-aware cards', () {
      final route = contactRouteForRecommendation(
        const Recommendation(
          contactId: 'sarah',
          reason: 'Sarah has Paris on her mind.',
          insight: 'A recent update mentioned Paris.',
          priority: 'Medium',
          topic: 'Paris trip',
          action: 'Ask how the Paris plans are coming together.',
        ),
      );

      expect(route, '/contact/sarah?topic=Paris+trip&reason=Sarah+has+Paris+on+her+mind.&insight=A+recent+update+mentioned+Paris.&action=Ask+how+the+Paris+plans+are+coming+together.');
    });

    test(
      'recommendations screen route includes topic query for topic-aware cards',
      () {
        final route = recommendationContactRoute(
          const Recommendation(
            contactId: 'sarah',
            reason: 'Sarah has Paris on her mind.',
            insight: 'A recent update mentioned Paris.',
            priority: 'Medium',
            topic: 'Paris trip',
            action: 'Ask how the Paris plans are coming together.',
          ),
        );

        expect(route, '/contact/sarah?topic=Paris+trip&reason=Sarah+has+Paris+on+her+mind.&insight=A+recent+update+mentioned+Paris.&action=Ask+how+the+Paris+plans+are+coming+together.');
      },
    );

    test('routes include reason and insight for regular cards', () {
      const recommendation = Recommendation(
        contactId: 'mike',
        reason: 'Mike could use a check-in.',
        insight: 'A quick hello keeps things warm.',
        priority: 'Low',
      );

      expect(contactRouteForRecommendation(recommendation),
          '/contact/mike?reason=Mike+could+use+a+check-in.&insight=A+quick+hello+keeps+things+warm.');
      expect(recommendationContactRoute(recommendation),
          '/contact/mike?reason=Mike+could+use+a+check-in.&insight=A+quick+hello+keeps+things+warm.');
    });
  });
}
