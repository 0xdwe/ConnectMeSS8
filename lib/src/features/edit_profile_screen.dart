import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../state/user_profile/user_profile_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/crm_widgets.dart';
import '../widgets/account_avatar.dart';

/// A premium, full-page route that handles editing user profile details
/// including name, email, and advanced avatar configuration (Emoji/Photo).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  /// Robust navigation method that uses [GoRouter] if available,
  /// otherwise falls back to a standard [Navigator] push.
  static Future<void> navigateTo(BuildContext context) async {
    try {
      GoRouter.of(context).push('/edit-profile');
    } catch (_) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
      );
    }
  }

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final AccountProfile? _initialProfile = ref.read(accountProfileProvider);
  late final name = TextEditingController(text: _initialProfile?.name ?? '');
  late final email = TextEditingController(text: _initialProfile?.email ?? '');
  File? _pickedAvatar;
  bool _removePhoto = false;
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _pickedAvatar = File(image.path);
          _removePhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  void _showAvatarOptionSheet() {
    final tokens = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Profile Picture',
                  style: AppTypography.h2(color: tokens.ink),
                ),
              ),
              Divider(color: tokens.border, height: 1),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: tokens.primary,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: AppTypography.body(color: tokens.ink),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: tokens.danger),
                title: Text(
                  'Remove Photo',
                  style: AppTypography.body(color: tokens.danger),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pickedAvatar = null;
                    _removePhoto = true;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    final trimmedName = name.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _nameError = 'Enter your name');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    try {
      final service = ref.read(userProfileServiceProvider);
      if (_pickedAvatar != null) {
        await service.uploadAvatarAndUpdatePhotoUrl(_pickedAvatar!);
      } else if (_removePhoto) {
        await service.removeAvatar();
      }
      await service.updateDisplayName(trimmedName);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update profile. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final previewProfile = AccountProfile(
      uid: _initialProfile?.uid ?? '',
      email: email.text,
      name: name.text.trim().isEmpty
          ? (_initialProfile?.name ?? '')
          : name.text.trim(),
      photoUrl: _removePhoto ? null : _initialProfile?.photoUrl,
    );

    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTypography.h2(color: tokens.ink)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
        leadingWidth: 70,
        leading: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tokens.border),
            ),
            child: IconButton(
              icon: Icon(Icons.close, color: tokens.inkSubtle, size: 18),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        actions: [
          Center(
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.save_outlined,
                  color: tokens.primary,
                  size: 18,
                ),
                onPressed: _saving ? null : _saveChanges,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space5,
            AppSpacing.space4,
            AppSpacing.space5,
            AppSpacing.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Center CircleAvatar with floating Camera Icon Overlay ───
              const SizedBox(height: 12),
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.primary.withValues(alpha: 0.15),
                          width: 4,
                        ),
                      ),
                      child: AccountAvatar(
                        profile: previewProfile,
                        radius: 64,
                        glyphSize: 48,
                        backgroundColor: tokens.primaryTint,
                        localImage: _pickedAvatar == null
                            ? null
                            : FileImage(_pickedAvatar!),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: tokens.primary,
                        elevation: 4,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _showAvatarOptionSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            key: Key('edit-avatar-camera-button'),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // PROFILE PHOTO Label
              Center(
                child: Text(
                  'PROFILE PHOTO',
                  style: AppTypography.caption(color: tokens.primary).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Outlined Remove Photo pilled button
              Center(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _pickedAvatar = null;
                      _removePhoto = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(
                      color: tokens.danger.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Remove Photo',
                    style: AppTypography.body(
                      color: tokens.danger,
                    ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ─── Input Fields Card (Name and Email) ───
              CardBox(
                padding: const EdgeInsets.all(16),
                border: Border.all(color: tokens.border, width: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'NAME',
                      style: AppTypography.caption(color: tokens.primary)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                    ),
                    TextField(
                      key: const Key('profile-name-field'),
                      controller: name,
                      onChanged: (_) => setState(() => _nameError = null),
                      style: AppTypography.body(
                        color: tokens.ink,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        errorText: _nameError,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Divider(color: tokens.border, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'EMAIL ADDRESS',
                      style: AppTypography.caption(color: tokens.primary)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                    ),
                    TextField(
                      key: const Key('profile-email-field'),
                      controller: email,
                      readOnly: true,
                      style: AppTypography.body(
                        color: tokens.inkMuted,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Save & Cancel Outlined/Shadowed Pill Buttons ───
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: tokens.inkSubtle,
                        side: BorderSide(color: tokens.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: AppTypography.body().copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        key: const Key('profile-save-button'),
                        onPressed: _saving ? null : _saveChanges,
                        child: Text(
                          _saving ? 'Saving…' : 'Save Changes',
                          style: AppTypography.body(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
