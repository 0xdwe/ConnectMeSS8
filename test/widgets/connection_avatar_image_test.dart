import 'package:connect_me/src/widgets/crm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('connectionAvatarImage', () {
    test('decodes data image avatars', () {
      final image = connectionAvatarImage(
        'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
      );

      expect(image, isA<MemoryImage>());
    });

    test('uses network images for uploaded avatar URLs', () {
      final image = connectionAvatarImage('https://example.com/avatar.jpg');

      expect(image, isA<NetworkImage>());
      expect((image! as NetworkImage).url, 'https://example.com/avatar.jpg');
    });

    test('falls back for text and malformed data avatars', () {
      expect(connectionAvatarImage('AB'), isNull);
      expect(connectionAvatarImage('data:image/png;base64,not-base64'), isNull);
    });
  });
}
