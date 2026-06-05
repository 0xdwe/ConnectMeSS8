import 'package:flutter/material.dart';

import '../state/user_profile/user_profile_service.dart';
import '../theme/app_typography.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.profile,
    required this.radius,
    required this.glyphSize,
    this.backgroundColor,
    this.localImage,
  });

  final AccountProfile? profile;
  final double radius;
  final double glyphSize;
  final Color? backgroundColor;
  final ImageProvider<Object>? localImage;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile?.photoUrl?.trim();
    final image =
        localImage ??
        (photoUrl == null || photoUrl.isEmpty ? null : NetworkImage(photoUrl));
    if (image != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage: image,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        _initials(profile?.name),
        style: AppTypography.glyph(glyphSize),
      ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '👤';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}
