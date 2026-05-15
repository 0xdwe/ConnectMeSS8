import 'package:connect_me/src/state/app_state.dart';
import 'package:connect_me/src/theme/app_theme.dart';
import 'package:connect_me/src/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal app that resolves the theme from [AppState.themeMode]
/// and reports the resolved brightness. Mirrors the wiring in
/// `connect_me_app.dart` without going through GoRouter.
class _ThemeProbe extends ConsumerWidget {
  const _ThemeProbe({required this.platformBrightness});

  final Brightness platformBrightness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    return MediaQuery(
      data: MediaQueryData(platformBrightness: platformBrightness),
      child: MaterialApp(
        theme: AppTheme.data(false),
        darkTheme: AppTheme.data(true),
        themeMode: switch (appState.themeMode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        home: const _ThemeReader(),
      ),
    );
  }
}

class _ThemeReader extends StatelessWidget {
  const _ThemeReader();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final hasTokens = Theme.of(context).extension<AppTokens>() != null;
    return Scaffold(
      body: Column(
        children: [
          Text('brightness:${brightness.name}'),
          Text('hasTokens:$hasTokens'),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('themeMode defaults to system', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appControllerProvider).themeMode,
        AppThemeMode.system);
  });

  testWidgets(
      'system mode follows MediaQuery.platformBrightness (dark)',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: _ThemeProbe(platformBrightness: Brightness.dark),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('brightness:dark'), findsOneWidget);
    expect(find.text('hasTokens:true'), findsOneWidget);
  });

  testWidgets(
      'system mode follows MediaQuery.platformBrightness (light)',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: _ThemeProbe(platformBrightness: Brightness.light),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('brightness:light'), findsOneWidget);
    expect(find.text('hasTokens:true'), findsOneWidget);
  });

  testWidgets(
      'setThemeMode(dark) overrides system platformBrightness',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _ThemeProbe(platformBrightness: Brightness.light),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('brightness:light'), findsOneWidget);

    container
        .read(appControllerProvider.notifier)
        .setThemeMode(AppThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.text('brightness:dark'), findsOneWidget);
  });

  testWidgets(
      'deprecated setDarkMode shim still routes to setThemeMode',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // ignore: deprecated_member_use_from_same_package
    container.read(appControllerProvider.notifier).setDarkMode(true);
    expect(container.read(appControllerProvider).themeMode,
        AppThemeMode.dark);

    // ignore: deprecated_member_use_from_same_package
    container.read(appControllerProvider.notifier).setDarkMode(false);
    expect(container.read(appControllerProvider).themeMode,
        AppThemeMode.light);
  });
}
