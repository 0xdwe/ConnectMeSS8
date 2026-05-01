import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

Future<void> showThemeModal(BuildContext context) {
  return showModalBottomSheet<void>(context: context, builder: (_) => const ThemeModal());
}

class ThemeModal extends ConsumerWidget {
  const ThemeModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(appControllerProvider.select((state) => state.darkMode));
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Theme', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: const [
          CircleAvatar(backgroundColor: AppTheme.moss),
          SizedBox(width: 8),
          CircleAvatar(backgroundColor: AppTheme.sage),
          SizedBox(width: 8),
          CircleAvatar(backgroundColor: AppTheme.clay),
          SizedBox(width: 8),
          CircleAvatar(backgroundColor: AppTheme.sand),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dark mode'),
          value: dark,
          onChanged: ref.read(appControllerProvider.notifier).setDarkMode,
        ),
      ]),
    );
  }
}
