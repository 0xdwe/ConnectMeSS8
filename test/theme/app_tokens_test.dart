import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTokens.light', () {
    test('exposes documented values from DESIGN.md', () {
      final tokens = AppTokens.light();
      expect(tokens.surface, const Color(0xFFF7F6FF));
      expect(tokens.surfaceRaised, const Color(0xFFFFFFFF));
      expect(tokens.surfaceSunken, const Color(0xFFF0EEFA));
      expect(tokens.ink, const Color(0xFF232033));
      expect(tokens.inkMuted, const Color(0xFF69647A));
      expect(tokens.inkSubtle, const Color(0xFF9892AA));
      expect(tokens.border, const Color(0xFFE5E1F2));
      expect(tokens.primary, const Color(0xFF7367F0));
      expect(tokens.primaryOn, const Color(0xFFFFFFFF));
      expect(tokens.primaryTint, const Color(0xFFEDEBFF));
      expect(tokens.secondary, const Color(0xFFF59E0B));
      expect(tokens.tertiary, const Color(0xFFE76BAE));
      expect(tokens.success, const Color(0xFF2F9E78));
      expect(tokens.danger, const Color(0xFFD64545));
      expect(tokens.categoryWork, const Color(0xFF4F8DBD));
    });

    test('exposes Pass 2 AI surface tokens', () {
      final tokens = AppTokens.light();
      // aiGradient: two-color purple→indigo gradient
      expect(tokens.aiGradient.colors.length, 2);
      // Recommendation callout + topic accent are real, opaque colors
      // (full opacity at every channel-encoded representation).
      expect(tokens.recommendationSurface.a, 1.0);
      expect(tokens.recommendationBorder.a, 1.0);
      expect(tokens.recommendationInk.a, 1.0);
      expect(tokens.recommendationInkMuted.a, 1.0);
      expect(tokens.topicAccent.a, 1.0);
    });
  });

  group('AppTokens.dark', () {
    test('exposes documented dark-mode values from DESIGN.md', () {
      final tokens = AppTokens.dark();
      expect(tokens.surface, const Color(0xFF171722));
      expect(tokens.surfaceRaised, const Color(0xFF222334));
      expect(tokens.ink, const Color(0xFFF5F3FF));
      expect(tokens.primary, const Color(0xFF9B8CFF));
      expect(tokens.primaryOn, const Color(0xFFFFFFFF));
      expect(tokens.success, const Color(0xFF61D0A9));
      expect(tokens.danger, const Color(0xFFFF6B6B));
    });

    test('Pass 2 AI surface tokens differ from light values', () {
      final light = AppTokens.light();
      final dark = AppTokens.dark();
      // Different at minimum on the two endpoints we care about visually.
      expect(dark.aiGradient.colors, isNot(equals(light.aiGradient.colors)));
      expect(
        dark.recommendationSurface,
        isNot(equals(light.recommendationSurface)),
      );
      expect(
        dark.recommendationBorder,
        isNot(equals(light.recommendationBorder)),
      );
      expect(dark.recommendationInk, isNot(equals(light.recommendationInk)));
      expect(
        dark.recommendationInkMuted,
        isNot(equals(light.recommendationInkMuted)),
      );
      expect(dark.topicAccent, isNot(equals(light.topicAccent)));
      expect(dark.aiGradient.colors.length, 2);
    });
  });

  group('AppTheme.data', () {
    test('registers AppTokens in ThemeData.extensions for light mode', () {
      final theme = AppTheme.data(false);
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.primary, const Color(0xFF7367F0));
      expect(tokens.surface, const Color(0xFFF7F6FF));
    });

    test('registers AppTokens in ThemeData.extensions for dark mode', () {
      final theme = AppTheme.data(true);
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.primary, const Color(0xFF9B8CFF));
      expect(tokens.surface, const Color(0xFF171722));
    });
  });

  group('AppTokens.lerp', () {
    test('interpolates each color between two token sets', () {
      final light = AppTokens.light();
      final dark = AppTokens.dark();
      final mid = light.lerp(dark, 0.5);
      // Halfway between two distinct primaries should equal Flutter's
      // built-in Color.lerp result, sanity-checked here.
      expect(mid.primary, Color.lerp(light.primary, dark.primary, 0.5));
      expect(mid.surface, Color.lerp(light.surface, dark.surface, 0.5));
    });

    test('returns self when other is not AppTokens', () {
      final light = AppTokens.light();
      // ignore: invalid_use_of_visible_for_overriding_member
      final result = light.lerp(null, 0.5);
      expect(result.primary, light.primary);
    });
  });
}
