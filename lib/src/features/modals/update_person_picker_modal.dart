import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

ImageProvider<Object>? _pickerAvatarImage(String avatar) {
  final trimmed = avatar.trim();
  if (!trimmed.startsWith('data:image/')) return null;
  final parts = trimmed.split(',');
  if (parts.length != 2) return null;
  try {
    return MemoryImage(base64Decode(parts[1]));
  } catch (_) {
    return null;
  }
}

String _pickerAvatarGlyph(String avatar) {
  final trimmed = avatar.trim();
  return (trimmed.isNotEmpty && !trimmed.startsWith('data:image/')) ? trimmed : '?';
}

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
          padding: EdgeInsets.all(AppSpacing.space5),
          children: [
            Text('Choose person to update', style: AppTypography.h1()),
            SizedBox(height: AppSpacing.space3),
            for (final person in people)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEDE9FE),
                  backgroundImage: _pickerAvatarImage(person.avatar),
                  child: _pickerAvatarImage(person.avatar) == null
                      ? Text(
                          _pickerAvatarGlyph(person.avatar),
                          style: const TextStyle(fontSize: 18),
                        )
                      : null,
                ),
                title: Text(person.name),
                subtitle: Text(person.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/ai-update/${person.id}');
                },
              ),
          ],
        ),
      ),
    );
  }
}
