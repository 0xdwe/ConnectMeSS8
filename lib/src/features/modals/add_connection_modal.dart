import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../state/app_state.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

Future<void> showAddConnectionModal(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      isScrollControlled: true,
      builder: (_) => const AddConnectionModal(),
    );

class AddConnectionModal extends ConsumerStatefulWidget {
  const AddConnectionModal({super.key});

  @override
  ConsumerState<AddConnectionModal> createState() => _AddConnectionModalState();
}

enum _ProfilePictureMode { emoji, image }

class _AddConnectionModalState extends ConsumerState<AddConnectionModal> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final avatar = TextEditingController(text: '👤');
  final phone = TextEditingController();
  final address = TextEditingController();
  final instagram = TextEditingController();
  final linkedin = TextEditingController();
  final whatsapp = TextEditingController();
  final line = TextEditingController();
  final notes = TextEditingController();

  String? category;
  _ProfilePictureMode pictureMode = _ProfilePictureMode.emoji;
  Uint8List? avatarBytes;

  Future<void> _pickAvatarImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          avatarBytes = bytes;
          avatar.text = 'data:image/png;base64,${base64Encode(bytes)}';
          pictureMode = _ProfilePictureMode.image;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick image. $error')));
    }
  }

  bool get _hasUploadedImage => avatarBytes != null;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    avatar.dispose();
    phone.dispose();
    address.dispose();
    instagram.dispose();
    linkedin.dispose();
    whatsapp.dispose();
    line.dispose();
    notes.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    category ??= state.categories.first;
    final tokens = context.tokens;
    final colors = Theme.of(context).colorScheme;
    final selectedButtonStyle = FilledButton.styleFrom(
      backgroundColor: tokens.primary,
      foregroundColor: tokens.primaryOn,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
    final unselectedButtonStyle = OutlinedButton.styleFrom(
      backgroundColor: colors.surface,
      foregroundColor: tokens.primary,
      side: BorderSide(color: tokens.primary.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
    final selectedLabelStyle = AppTypography.body(
      color: tokens.primaryOn,
    ).copyWith(fontWeight: FontWeight.w700);
    final unselectedLabelStyle = AppTypography.body(
      color: tokens.primary,
    ).copyWith(fontWeight: FontWeight.w700);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.space5,
          right: AppSpacing.space5,
          top: AppSpacing.space4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Add Connection', style: AppTypography.h1()),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.space4),

                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.18,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Profile Picture', style: AppTypography.caption()),
                      SizedBox(height: AppSpacing.space3),
                      Align(
                        alignment: Alignment.center,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.12,
                          ),
                          backgroundImage: _hasUploadedImage
                              ? MemoryImage(avatarBytes!)
                              : null,
                          child: !_hasUploadedImage
                              ? Text(
                                  avatar.text.isEmpty ? '👤' : avatar.text,
                                  style: AppTypography.display().copyWith(
                                    fontSize: 36,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      SizedBox(height: AppSpacing.space3),
                      Row(
                        children: [
                          Expanded(
                            child: pictureMode == _ProfilePictureMode.emoji
                                ? FilledButton.icon(
                                    onPressed: () => setState(() {
                                      pictureMode = _ProfilePictureMode.emoji;
                                      if (avatar.text.startsWith(
                                        'data:image/',
                                      )) {
                                        avatar.text = '👤';
                                        avatarBytes = null;
                                      }
                                    }),
                                    icon: const Icon(
                                      Icons.emoji_emotions_outlined,
                                    ),
                                    style: selectedButtonStyle,
                                    label: Text(
                                      'Emoji',
                                      style: selectedLabelStyle,
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      pictureMode = _ProfilePictureMode.emoji;
                                      if (avatar.text.startsWith(
                                        'data:image/',
                                      )) {
                                        avatar.text = '👤';
                                        avatarBytes = null;
                                      }
                                    }),
                                    icon: const Icon(
                                      Icons.emoji_emotions_outlined,
                                    ),
                                    style: unselectedButtonStyle,
                                    label: Text(
                                      'Emoji',
                                      style: unselectedLabelStyle,
                                    ),
                                  ),
                          ),
                          SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: pictureMode == _ProfilePictureMode.image
                                ? FilledButton.icon(
                                    onPressed: () => setState(
                                      () => pictureMode =
                                          _ProfilePictureMode.image,
                                    ),
                                    icon: const Icon(Icons.image_outlined),
                                    style: selectedButtonStyle,
                                    label: Text(
                                      'Image',
                                      style: selectedLabelStyle,
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => setState(
                                      () => pictureMode =
                                          _ProfilePictureMode.image,
                                    ),
                                    icon: const Icon(Icons.image_outlined),
                                    style: unselectedButtonStyle,
                                    label: Text(
                                      'Image',
                                      style: unselectedLabelStyle,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.space3),
                      if (pictureMode == _ProfilePictureMode.emoji)
                        TextField(
                          controller: avatar,
                          textAlign: TextAlign.center,
                          decoration: _inputDecoration('Enter an emoji'),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _hasUploadedImage
                                  ? 'Selected photo'
                                  : 'Select an image from your gallery',
                              style: AppTypography.bodyLg(
                                color: colors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: AppSpacing.space3),
                            FilledButton.icon(
                              onPressed: _pickAvatarImage,
                              icon: const Icon(Icons.upload_file),
                              style: selectedButtonStyle,
                              label: Text(
                                _hasUploadedImage
                                    ? 'Change photo'
                                    : 'Upload photo',
                                style: selectedLabelStyle,
                              ),
                            ),
                            if (_hasUploadedImage)
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: tokens.primary,
                                  shadowColor: Colors.transparent,
                                  surfaceTintColor: Colors.transparent,
                                ),
                                onPressed: () => setState(() {
                                  avatar.text = '👤';
                                  avatarBytes = null;
                                  pictureMode = _ProfilePictureMode.emoji;
                                }),
                                child: Text(
                                  'Remove photo',
                                  style: unselectedLabelStyle,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),

                SizedBox(height: AppSpacing.space4),

                Text('Basic Info', style: AppTypography.caption()),
                SizedBox(height: AppSpacing.space2),

                TextFormField(
                  key: const Key('add-name-field'),
                  controller: name,
                  decoration: _inputDecoration(
                    'Name',
                    icon: Icons.person_outline,
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Name is required' : null,
                ),
                SizedBox(height: AppSpacing.space3),

                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    'Category',
                    icon: Icons.category_outlined,
                  ),
                  items: state.categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => category = value),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Category is required'
                      : null,
                ),

                SizedBox(height: AppSpacing.space4),

                Text('Contact Information', style: AppTypography.caption()),
                SizedBox(height: AppSpacing.space2),

                TextField(
                  key: const Key('add-email-field'),
                  controller: email,
                  decoration: _inputDecoration(
                    'Email',
                    icon: Icons.email_outlined,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: AppSpacing.space3),

                TextField(
                  controller: phone,
                  decoration: _inputDecoration(
                    'Phone',
                    icon: Icons.phone_outlined,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: AppSpacing.space3),

                TextField(
                  controller: address,
                  decoration: _inputDecoration(
                    'Address',
                    icon: Icons.location_on_outlined,
                  ),
                ),

                SizedBox(height: AppSpacing.space4),

                Text('Social Media', style: AppTypography.caption()),
                SizedBox(height: AppSpacing.space2),

                TextField(
                  controller: instagram,
                  decoration: _inputDecoration(
                    'Instagram',
                    icon: Icons.camera_alt_outlined,
                  ),
                ),
                SizedBox(height: AppSpacing.space3),

                TextField(
                  controller: linkedin,
                  decoration: _inputDecoration(
                    'LinkedIn',
                    icon: Icons.work_outline,
                  ),
                ),
                SizedBox(height: AppSpacing.space3),

                TextField(
                  controller: whatsapp,
                  decoration: _inputDecoration(
                    'WhatsApp',
                    icon: Icons.chat_outlined,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: AppSpacing.space3),

                TextField(
                  controller: line,
                  decoration: _inputDecoration(
                    'LINE',
                    icon: Icons.forum_outlined,
                  ),
                ),

                SizedBox(height: AppSpacing.space4),

                TextField(
                  controller: notes,
                  decoration: _inputDecoration(
                    'First connection starter',
                    icon: Icons.notes_outlined,
                  ),
                  minLines: 3,
                  maxLines: 4,
                ),

                SizedBox(height: AppSpacing.space5),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: unselectedButtonStyle,
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: unselectedLabelStyle),
                      ),
                    ),
                    SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: FilledButton(
                        key: const Key('save-connection-button'),
                        style: selectedButtonStyle,
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          try {
                            await ref
                                .read(appControllerProvider.notifier)
                                .addConnection(
                                  name: name.text.trim(),
                                  email: email.text.trim().isEmpty
                                      ? 'new@email.com'
                                      : email.text.trim(),
                                  category: category!,
                                  notes: notes.text.trim(),
                                  avatar:
                                      pictureMode == _ProfilePictureMode.emoji
                                      ? (avatar.text.trim().isEmpty
                                            ? '👤'
                                            : avatar.text.trim())
                                      : (avatar.text.trim().isEmpty
                                            ? '👤'
                                            : avatar.text.trim()),
                                  phone: phone.text.trim(),
                                  address: address.text.trim(),
                                  instagram: instagram.text.trim(),
                                  linkedin: linkedin.text.trim(),
                                  whatsapp: whatsapp.text.trim(),
                                  line: line.text.trim(),
                                );

                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not add connection. Try again.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Save', style: selectedLabelStyle),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
