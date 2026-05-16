import 'package:connect_me/src/models/social_models.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/theme/app_tokens.dart';
import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactListCard', () {
    Connection makeConnection({String category = 'Family'}) => Connection(
          id: 'test-1',
          name: 'Test User',
          email: 'test@example.com',
          category: category,
          avatar: '🌟',
          bondScore: 70,
          nextStep: 'Say hi',
          lastContact: DateTime(2026, 5, 1),
          notes: '',
          knownSince: DateTime(2020, 1, 1),
          preferredChannels: const ['Text'],
        );

    Widget pump(Connection connection) => MaterialApp(
          theme: AppTheme.data(false),
          home: Scaffold(
            body: ContactListCard(connection: connection, onTap: () {}),
          ),
        );

    testWidgets('renders category dot tinted to category color', (tester) async {
      final connection = makeConnection(category: 'Family');

      await tester.pumpWidget(pump(connection));

      // Find a CircleAvatar with the categoryFamily color and small radius (<= 6).
      final tokens = AppTokens.light();
      final dotFinder = find.byWidgetPredicate(
        (w) =>
            w is CircleAvatar &&
            w.backgroundColor == tokens.categoryFamily &&
            (w.radius ?? 0) <= 6,
      );
      expect(dotFinder, findsOneWidget);
    });
  });
}
