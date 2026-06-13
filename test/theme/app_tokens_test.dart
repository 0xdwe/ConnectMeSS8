import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTokens.light', () {
    test('exposes documented values from DESIGN.md', () {
      final tokens = AppTokens.light();
      expect(tokens.surface, const Color(0xFFFAF9FC));
      expect(tokens.surfaceRaised, const Color(0xFFFFFFFF));
      expect(tokens.surfaceSunken, const Color(0xFFF2F1F4));
      expect(tokens.ink, const Color(0xFF1A1A1A));
      expect(tokens.inkMuted, const Color(0xFF5C5A66));
      expect(tokens.inkSubtle, const Color(0xFF8C8995));
      expect(tokens.border, const Color(0xFFE7E4EB));
      expect(tokens.primary, const Color(0xFF7C3AED));
      expect(tokens.primaryOn, const Color(0xFFFFFFFF));
      expect(tokens.primaryTint, const Color(0xFFF1ECFA));
      expect(tokens.secondary, const Color(0xFFFF8C00));
      expect(tokens.tertiary, const Color(0xFFFF71CF));
      expect(tokens.success, const Color(0xFF3B9D6E));
      expect(tokens.danger, const Color(0xFFC53030));
      expect(tokens.categoryWork, const Color(0xFF5283A8));
    });

    test('exposes Pass 2 AI surface tokens', () {
      final tokens = AppTokens.light();
      // aiGradient: two-color purple→indigo gradient
      expect(tokens.aiGradient.colors.length, 2);
      // Recommendation callout + topic accent are real, opaque colors
      // (full opacity at every channel-encoded representation).
      expect(tokens.recommendationSurface.a, 1.0);
      expect(tokens.recommendationBorder.a, 1.0);
      expect(tokens.topicAccent.a, 1.0);
    });
  });

  group('AppTokens.dark', () {
    test('exposes documented dark-mode values from DESIGN.md', () {
      final tokens = AppTokens.dark();
      expect(tokens.surface, const Color(0xFF191820));
      expect(tokens.surfaceRaised, const Color(0xFF23222B));
      expect(tokens.ink, const Color(0xFFF4F2F7));
      expect(tokens.primary, const Color(0xFF9B6BF0));
      expect(tokens.primaryOn, const Color(0xFFFFFFFF));
      expect(tokens.success, const Color(0xFF5BC094));
      expect(tokens.danger, const Color(0xFFE25555));
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
      expect(dark.topicAccent, isNot(equals(light.topicAccent)));
      expect(dark.aiGradient.colors.length, 2);
    });
  });

  group('AppTheme.data', () {
    test('registers AppTokens in ThemeData.extensions for light mode', () {
      final theme = AppTheme.data(false);
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.primary, const Color(0xFF7C3AED));
      expect(tokens.surface, const Color(0xFFFAF9FC));
    });

    test('registers AppTokens in ThemeData.extensions for dark mode', () {
      final theme = AppTheme.data(true);
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.primary, const Color(0xFF9B6BF0));
      expect(tokens.surface, const Color(0xFF191820));
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
