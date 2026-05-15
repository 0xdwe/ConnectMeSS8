import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

Future<void> showEditUserProfileModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const EditUserProfileModal(),
  );
}

class EditUserProfileModal extends ConsumerStatefulWidget {
  const EditUserProfileModal({super.key});

  @override
  ConsumerState<EditUserProfileModal> createState() =>
      _EditUserProfileModalState();
}

class _EditUserProfileModalState extends ConsumerState<EditUserProfileModal> {
  late final name = TextEditingController(
    text: ref.read(appControllerProvider).user.name,
  );
  late final email = TextEditingController(
    text: ref.read(appControllerProvider).user.email,
  );
  late final avatar = TextEditingController(
    text: ref.read(appControllerProvider).user.avatar,
  );
  late AvatarKind avatarKind = ref.read(appControllerProvider).user.avatarKind;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    avatar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space4,
        AppSpacing.space5,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.space5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit Profile',
                    style: AppTypography.h1(),
                  ),
                ),
                IconButton(
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.space3),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: tokens.primaryTint,
                child: Text(
                  avatar.text.isEmpty ? '👤' : avatar.text,
                  style: AppTypography.glyph(42),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.space3),
            SegmentedButton<AvatarKind>(
              segments: const [
                ButtonSegment(
                  value: AvatarKind.emoji,
                  icon: Icon(Icons.emoji_emotions_outlined),
                  label: Text('Emoji'),
                ),
                ButtonSegment(
                  value: AvatarKind.image,
                  icon: Icon(Icons.image_outlined),
                  label: Text('Image'),
                ),
              ],
              selected: {avatarKind},
              onSelectionChanged: (value) {
                setState(() => avatarKind = value.first);
              },
            ),
            SizedBox(height: AppSpacing.space3),
            TextField(
              controller: avatar,
              decoration: InputDecoration(
                labelText: avatarKind == AvatarKind.emoji
                    ? 'Avatar emoji'
                    : 'Image URL or path',
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: AppSpacing.space4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Navigator.of(context).pop,
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.primary,
                    ),
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .updateUser(
                            name: name.text,
                            email: email.text,
                            avatar: avatar.text,
                            avatarKind: avatarKind,
                          );
                      Navigator.pop(context);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
