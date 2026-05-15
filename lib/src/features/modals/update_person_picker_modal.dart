import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/app_typography.dart';

Future<void> showUpdatePersonPickerModal(BuildContext context) => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const UpdatePersonPickerModal());

class UpdatePersonPickerModal extends ConsumerWidget {
  const UpdatePersonPickerModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(appControllerProvider).connections;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text('Choose person to update', style: AppTypography.h1()),
            const SizedBox(height: 12),
            for (final person in people) ListTile(leading: CircleAvatar(child: Text(person.avatar)), title: Text(person.name), subtitle: Text(person.email), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(context); context.push('/ai-update/${person.id}'); }),
          ],
        ),
      ),
    );
  }
}
