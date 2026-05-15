import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFE0F0F0),
                child: Text(
                  avatar.text.isEmpty ? '👤' : avatar.text,
                  style: const TextStyle(fontSize: 42),
                ),
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 12),
            TextField(
              controller: avatar,
              decoration: InputDecoration(
                labelText: avatarKind == AvatarKind.emoji
                    ? 'Avatar emoji'
                    : 'Image URL or path',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Navigator.of(context).pop,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.moss,
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
