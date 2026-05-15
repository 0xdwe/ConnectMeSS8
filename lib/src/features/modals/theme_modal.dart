import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

Future<void> showThemeModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const ThemeModal(),
  );
}

class ThemeModal extends ConsumerWidget {
  const ThemeModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final mode = ref.watch(
      appControllerProvider.select((state) => state.themeMode),
    );
    final controller = ref.read(appControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: AppTypography.h1(),
          ),
          const SizedBox(height: 4),
          Text(
            'Match system follows your device. Light and dark are explicit.',
            style: AppTypography.caption(color: tokens.inkMuted),
          ),
          const SizedBox(height: 16),
          RadioGroup<AppThemeMode>(
            groupValue: mode,
            onChanged: (value) {
              if (value != null) controller.setThemeMode(value);
            },
            child: const Column(
              children: [
                _ThemeOption(
                  key: Key('theme-mode-system'),
                  label: 'Match system',
                  value: AppThemeMode.system,
                ),
                _ThemeOption(
                  key: Key('theme-mode-light'),
                  label: 'Always light',
                  value: AppThemeMode.light,
                ),
                _ThemeOption(
                  key: Key('theme-mode-dark'),
                  label: 'Always dark',
                  value: AppThemeMode.dark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final AppThemeMode value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<AppThemeMode>(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
    );
  }
}
