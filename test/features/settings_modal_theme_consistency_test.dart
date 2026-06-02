import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'settings customization modals use theme tokens instead of hard-coded accent colors',
    () {
      final modalFiles = [
        File('lib/src/features/modals/manage_categories_modal.dart'),
        File('lib/src/features/modals/manage_event_types_modal.dart'),
        File('lib/src/features/modals/theme_modal.dart'),
      ];

      for (final file in modalFiles) {
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('Color(0xFF9B59B6)')),
          reason:
              '${file.path} should not hard-code the old purple category accent.',
        );
        expect(
          source,
          isNot(contains('Color(0xFF4F40C7)')),
          reason: '${file.path} should not hard-code purple chip text.',
        );
        expect(
          source,
          isNot(contains('Color(0xFFEBE8FF)')),
          reason: '${file.path} should not hard-code purple chip backgrounds.',
        );
        expect(
          source,
          isNot(contains('Color(0xFFF6F5FB)')),
          reason:
              '${file.path} should not hard-code near-white field backgrounds.',
        );
        expect(
          source,
          isNot(contains('Color(0xFF153452)')),
          reason: '${file.path} should not hard-code a dark blue icon swatch.',
        );
      }
    },
  );

  test('requested modal header actions use explicit theme tokens', () {
    final eventTypesSource = File(
      'lib/src/features/modals/manage_event_types_modal.dart',
    ).readAsStringSync();
    final themeSource = File(
      'lib/src/features/modals/theme_modal.dart',
    ).readAsStringSync();

    expect(
      eventTypesSource,
      contains("AppTypography.h2(color: tokens.ink)"),
      reason: 'Manage Event Types title should render with black/ink text.',
    );
    expect(
      themeSource,
      contains("tooltip: 'Close'"),
      reason: 'Theme modal should provide an explicit close button.',
    );
    expect(
      themeSource,
      contains('onPressed: Navigator.of(context).pop'),
      reason: 'Theme modal close button should return to Settings.',
    );
  });
}
