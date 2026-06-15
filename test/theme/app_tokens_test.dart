import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTokens.light', () {
    test('exposes documented values from DESIGN.md', () {
      final tokens = AppTokens.light();
      expect(tokens.surface, const Color(0xFFFBFAFF));
      expect(tokens.surfaceRaised, const Color(0xFFFFFFFF));
      expect(tokens.surfaceSunken, const Color(0xFFF0F4FF));
      expect(tokens.ink, const Color(0xFF211F3D));
      expect(tokens.inkMuted, const Color(0xFF676184));
      expect(tokens.inkSubtle, const Color(0xFF9D96B8));
      expect(tokens.border, const Color(0xFFE4DFFA));
      expect(tokens.primary, const Color(0xFF6F63E8));
      expect(tokens.primaryOn, const Color(0xFFFFFFFF));
      expect(tokens.primaryTint, const Color(0xFFEEF0FF));
      expect(tokens.secondary, const Color(0xFFE46FC4));
      expect(tokens.tertiary, const Color(0xFF5EADEB));
      expect(tokens.success, const Color(0xFF2F9E78));
      expect(tokens.danger, const Color(0xFFD64545));
      expect(tokens.categoryWork, const Color(0xFF5EADEB));
    });

    test('exposes Pass 2 AI surface tokens', () {
      final tokens = AppTokens.light();
      // aiGradient: saturated mascot blue/lavender/pink gradient.
      expect(tokens.aiGradient.colors.length, 3);
      expect(tokens.pageGradient.colors.length, 4);
      expect(tokens.cardGradient.colors.length, 3);
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
      expect(tokens.surface, const Color(0xFF151525));
      expect(tokens.surfaceRaised, const Color(0xFF23243A));
      expect(tokens.ink, const Color(0xFFF7F5FF));
      expect(tokens.primary, const Color(0xFFA8A0FF));
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
      expect(dark.aiGradient.colors.length, 3);
      expect(dark.pageGradient.colors.length, 4);
      expect(dark.cardGradient.colors.length, 3);
    });
  });

  group('AppTheme.data', () {
    test('registers AppTokens in ThemeData.extensions for light mode', () {
      final theme = AppTheme.data(false);
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.primary, const Color(0xFF6F63E8));
      expect(tokens.surface, const Color(0xFFFBFAFF));
    });

    test('registers AppTokens in ThemeData.extensions for dark mode', () {
      final theme = AppTheme.data(true);
      final tokens = theme.extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.primary, const Color(0xFFA8A0FF));
      expect(tokens.surface, const Color(0xFF151525));
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
