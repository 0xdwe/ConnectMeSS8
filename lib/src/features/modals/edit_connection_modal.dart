import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/social_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum _AvatarMode { emoji, image }

Future<void> showEditConnectionModal(
  BuildContext context,
  Connection connection,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => EditConnectionModal(connection: connection),
);

class EditConnectionModal extends ConsumerStatefulWidget {
  const EditConnectionModal({super.key, required this.connection});
  final Connection connection;

  @override
  ConsumerState<EditConnectionModal> createState() =>
      _EditConnectionModalState();
}

class _EditConnectionModalState extends ConsumerState<EditConnectionModal> {
  late final name = TextEditingController(text: widget.connection.name);
  late final email = TextEditingController(text: widget.connection.email);
  late final phone = TextEditingController(text: widget.connection.phone);
  late final address = TextEditingController(text: widget.connection.address);
  late final instagram = TextEditingController(
    text: widget.connection.instagram,
  );
  late final linkedin = TextEditingController(text: widget.connection.linkedin);
  late final whatsapp = TextEditingController(text: widget.connection.whatsapp);
  late final line = TextEditingController(text: widget.connection.line);
  late final notes = TextEditingController(text: widget.connection.notes);
  late final avatar = TextEditingController(text: widget.connection.avatar);
  late String category = widget.connection.category;
  late _AvatarMode avatarMode =
      widget.connection.avatar.trim().startsWith('data:image/')
      ? _AvatarMode.image
      : _AvatarMode.emoji;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    instagram.dispose();
    linkedin.dispose();
    whatsapp.dispose();
    line.dispose();
    notes.dispose();
    avatar.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      setState(() {
        avatar.text = 'data:image/png;base64,${base64Encode(bytes)}';
        avatarMode = _AvatarMode.image;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick image: $error')));
    }
  }

  ImageProvider<Object>? get _avatarImage {
    final value = avatar.text.trim();
    if (!value.startsWith('data:image/')) return null;
    final parts = value.split(',');
    if (parts.length != 2) return null;
    try {
      return MemoryImage(base64Decode(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String get _avatarText {
    final value = avatar.text.trim();
    if (value.isEmpty || value.startsWith('data:image/')) return '👤';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(appControllerProvider).categories;
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.space5,
          right: AppSpacing.space5,
          top: AppSpacing.space5,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Connection', style: AppTypography.h1()),
            SizedBox(height: AppSpacing.space3),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.primaryContainer,
                    backgroundImage: _avatarImage,
                    child: _avatarImage == null
                        ? Text(_avatarText, style: AppTypography.glyph(26))
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Material(
                      color: colors.surface,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatarImage,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: colors.surface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  avatar.text = '👤';
                  avatarMode = _AvatarMode.emoji;
                }),
                icon: const Icon(Icons.emoji_emotions_outlined),
                label: const Text('Use default avatar'),
              ),
            ),
            if (avatarMode == _AvatarMode.emoji) ...[
              TextField(
                controller: avatar,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Emoji avatar'),
              ),
              SizedBox(height: AppSpacing.space2),
            ] else ...[
              Text(
                'Tap the pencil to change the photo.',
                style: AppTypography.caption(),
              ),
              SizedBox(height: AppSpacing.space2),
            ],
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: AppSpacing.space2),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),
            SizedBox(height: AppSpacing.space2),
            Text(
              'Contact Information (Optional)',
              style: AppTypography.caption(),
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: instagram,
              decoration: const InputDecoration(labelText: 'Instagram'),
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: linkedin,
              decoration: const InputDecoration(labelText: 'LinkedIn'),
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: whatsapp,
              decoration: const InputDecoration(labelText: 'WhatsApp'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: line,
              decoration: const InputDecoration(labelText: 'LINE'),
            ),
            SizedBox(height: AppSpacing.space2),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Starter detail'),
            ),
            SizedBox(height: AppSpacing.space4),
            FilledButton(
              onPressed: () {
                ref
                    .read(appControllerProvider.notifier)
                    .updateConnection(
                      widget.connection.copyWith(
                        avatar: avatar.text.trim().isEmpty
                            ? '👤'
                            : avatar.text.trim(),
                        name: name.text,
                        email: email.text,
                        category: category,
                        phone: phone.text,
                        address: address.text,
                        instagram: instagram.text,
                        linkedin: linkedin.text,
                        whatsapp: whatsapp.text,
                        line: line.text,
                        notes: notes.text,
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
            SizedBox(height: AppSpacing.space2),
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Connection'),
                    content: Text(
                      'Remove ${widget.connection.name} and related events?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  try {
                    await ref
                        .read(appControllerProvider.notifier)
                        .deleteConnection(widget.connection.id);
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not delete contact. Try again.'),
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
