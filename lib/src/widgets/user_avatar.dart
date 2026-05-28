import 'dart:io';
import 'package:flutter/material.dart';

import '../models/social_models.dart';
import '../theme/app_typography.dart';

/// A premium, highly robust avatar widget for [AppUser] that gracefully handles
/// emoji text, network URLs, and local image file paths with safety checks.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    required this.radius,
    required this.glyphSize,
    this.backgroundColor,
  });

  final AppUser user;
  final double radius;
  final double glyphSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (user.avatarKind == AvatarKind.image && user.avatar.trim().isNotEmpty) {
      final avatarPath = user.avatar.trim();
      if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: NetworkImage(avatarPath),
        );
      }

      try {
        final file = File(avatarPath);
        if (file.existsSync()) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor,
            backgroundImage: FileImage(file),
          );
        }
      } catch (_) {
        // Graceful fallback if platform file system operations fail or throw
      }
    }

    // Emoji or fallback rendering
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        user.avatar.isEmpty ? '👤' : user.avatar,
        style: AppTypography.glyph(glyphSize),
      ),
    );
  }
}
