import 'dart:io';

import 'package:connect_me/src/state/user_profile/user_profile_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAccountProfileBackend implements AccountProfileBackend {
  @override
  String? displayName = 'Old';
  @override
  String? photoUrl = 'https://old.example/avatar.jpg';
  var reloadCount = 0;
  var updateDisplayNameCalls = <String>[];
  var updatePhotoUrlCalls = <String?>[];
  Object? updateDisplayNameError;
  Object? updatePhotoUrlError;

  @override
  String get uid => 'uid-1';

  @override
  String? get email => 'james@example.com';

  @override
  Future<void> reload() async {
    reloadCount++;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    updateDisplayNameCalls.add(displayName);
    if (updateDisplayNameError != null) throw updateDisplayNameError!;
    this.displayName = displayName;
  }

  @override
  Future<void> updatePhotoUrl(String? photoUrl) async {
    updatePhotoUrlCalls.add(photoUrl);
    if (updatePhotoUrlError != null) throw updatePhotoUrlError!;
    this.photoUrl = photoUrl;
  }
}

class _FakeAvatarStorage implements UserAvatarStorage {
  String? uploadedPath;
  String? uploadedContentType;
  File? uploadedFile;
  var deleteCalls = <String>[];
  var nextDownloadUrl = 'https://download.example/avatar.jpg';
  Object? uploadError;
  Object? deleteError;
  Object? downloadUrlError;

  @override
  Future<void> uploadFile({
    required String path,
    required File file,
    required String contentType,
  }) async {
    uploadedPath = path;
    uploadedFile = file;
    uploadedContentType = contentType;
    if (uploadError != null) throw uploadError!;
  }

  @override
  Future<String> downloadUrl(String path) async {
    if (downloadUrlError != null) throw downloadUrlError!;
    return nextDownloadUrl;
  }

  @override
  Future<void> delete(String path) async {
    deleteCalls.add(path);
    if (deleteError != null) throw deleteError!;
  }
}

void main() {
  group('AccountProfile', () {
    test('uses Firebase Auth displayName when present', () {
      final profile = AccountProfile.fromAuthValues(
        uid: 'uid-1',
        email: 'james@example.com',
        displayName: 'James Li',
        photoUrl: 'https://example.com/avatar.jpg',
      );

      expect(profile.name, 'James Li');
      expect(profile.email, 'james@example.com');
      expect(profile.photoUrl, 'https://example.com/avatar.jpg');
    });

    test('falls back to email prefix when displayName is blank', () {
      final profile = AccountProfile.fromAuthValues(
        uid: 'uid-1',
        email: 'james@example.com',
        displayName: '   ',
        photoUrl: null,
      );

      expect(profile.name, 'james');
    });

    test(
      'falls back to Your profile when displayName and email are missing',
      () {
        final profile = AccountProfile.fromAuthValues(
          uid: 'uid-1',
          email: null,
          displayName: null,
          photoUrl: null,
        );

        expect(profile.name, 'Your profile');
        expect(profile.email, '');
      },
    );
  });

  group('UserProfileService mutation behavior', () {
    late _FakeAccountProfileBackend account;
    late _FakeAvatarStorage storage;
    late UserProfileService service;
    late File image;

    setUp(() {
      account = _FakeAccountProfileBackend();
      storage = _FakeAvatarStorage();
      service = BackendUserProfileService(account: account, storage: storage);
      image = File('/tmp/avatar.png');
    });

    test('updateDisplayName trims and reloads account', () async {
      await service.updateDisplayName('  New Name  ');

      expect(account.updateDisplayNameCalls, ['New Name']);
      expect(account.displayName, 'New Name');
      expect(account.reloadCount, 1);
    });

    test('updateDisplayName rejects blank names', () async {
      await expectLater(
        service.updateDisplayName('   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(account.updateDisplayNameCalls, isEmpty);
      expect(account.reloadCount, 0);
    });

    test(
      'avatar upload uses exact path, metadata, download URL, and reloads',
      () async {
        await service.uploadAvatarAndUpdatePhotoUrl(image);

        expect(storage.uploadedPath, 'users/uid-1/profile/avatar.jpg');
        expect(storage.uploadedFile, image);
        expect(storage.uploadedContentType, 'image/png');
        expect(account.updatePhotoUrlCalls, [
          'https://download.example/avatar.jpg',
        ]);
        expect(account.photoUrl, 'https://download.example/avatar.jpg');
        expect(account.reloadCount, 1);
      },
    );

    test('avatar upload propagates failure before photoURL update', () async {
      storage.uploadError = Exception('upload failed');

      await expectLater(
        service.uploadAvatarAndUpdatePhotoUrl(image),
        throwsA(isA<Exception>()),
      );
      expect(account.updatePhotoUrlCalls, isEmpty);
      expect(account.reloadCount, 0);
    });

    test('removeAvatar ignores missing object and clears photoURL', () async {
      storage.deleteError = FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
      );

      await service.removeAvatar();

      expect(storage.deleteCalls, ['users/uid-1/profile/avatar.jpg']);
      expect(account.updatePhotoUrlCalls, [null]);
      expect(account.photoUrl, isNull);
      expect(account.reloadCount, 1);
    });

    test('removeAvatar propagates non-missing delete failures', () async {
      storage.deleteError = FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
      );

      await expectLater(
        service.removeAvatar(),
        throwsA(isA<FirebaseException>()),
      );
      expect(account.updatePhotoUrlCalls, isEmpty);
      expect(account.reloadCount, 0);
    });
  });
}
