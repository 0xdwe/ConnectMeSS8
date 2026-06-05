import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_providers.dart';

class AccountProfile {
  const AccountProfile({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
  });

  factory AccountProfile.fromAuthValues({
    required String uid,
    required String? email,
    required String? displayName,
    required String? photoUrl,
  }) {
    final trimmedName = displayName?.trim();
    final trimmedEmail = email?.trim() ?? '';
    final fallbackName = trimmedEmail.contains('@')
        ? trimmedEmail.split('@').first
        : 'Your profile';
    return AccountProfile(
      uid: uid,
      email: trimmedEmail,
      name: trimmedName == null || trimmedName.isEmpty
          ? fallbackName
          : trimmedName,
      photoUrl: photoUrl?.trim().isEmpty == true ? null : photoUrl?.trim(),
    );
  }

  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
}

abstract class UserProfileService {
  AccountProfile? currentProfile();
  Future<void> updateDisplayName(String displayName);
  Future<void> uploadAvatarAndUpdatePhotoUrl(File imageFile);
  Future<void> removeAvatar();
}

abstract class AccountProfileBackend {
  String get uid;
  String? get email;
  String? get displayName;
  String? get photoUrl;
  Future<void> updateDisplayName(String displayName);
  Future<void> updatePhotoUrl(String? photoUrl);
  Future<void> reload();
}

abstract class UserAvatarStorage {
  Future<void> uploadFile({
    required String path,
    required File file,
    required String contentType,
  });
  Future<String> downloadUrl(String path);
  Future<void> delete(String path);
}

class BackendUserProfileService implements UserProfileService {
  BackendUserProfileService({
    required AccountProfileBackend account,
    required UserAvatarStorage storage,
  }) : _account = account,
       _storage = storage;

  final AccountProfileBackend _account;
  final UserAvatarStorage _storage;

  @override
  AccountProfile? currentProfile() {
    return AccountProfile.fromAuthValues(
      uid: _account.uid,
      email: _account.email,
      displayName: _account.displayName,
      photoUrl: _account.photoUrl,
    );
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) throw ArgumentError('displayName is required');
    await _account.updateDisplayName(trimmed);
    await _account.reload();
  }

  @override
  Future<void> uploadAvatarAndUpdatePhotoUrl(File imageFile) async {
    final path = avatarPathForUid(_account.uid);
    await _storage.uploadFile(
      path: path,
      file: imageFile,
      contentType: contentTypeForAvatarPath(imageFile.path),
    );
    final url = await _storage.downloadUrl(path);
    await _account.updatePhotoUrl(url);
    await _account.reload();
  }

  @override
  Future<void> removeAvatar() async {
    final path = avatarPathForUid(_account.uid);
    try {
      await _storage.delete(path);
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
    await _account.updatePhotoUrl(null);
    await _account.reload();
  }
}

String avatarPathForUid(String uid) => 'users/$uid/profile/avatar.jpg';

String contentTypeForAvatarPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

class FirebaseUserProfileService implements UserProfileService {
  FirebaseUserProfileService({
    required FirebaseAuth auth,
    required FirebaseStorage storage,
  }) : _auth = auth,
       _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    return user;
  }

  @override
  AccountProfile? currentProfile() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _delegateFor(user).currentProfile();
  }

  @override
  Future<void> updateDisplayName(String displayName) {
    return _delegateFor(_user).updateDisplayName(displayName);
  }

  @override
  Future<void> uploadAvatarAndUpdatePhotoUrl(File imageFile) {
    return _delegateFor(_user).uploadAvatarAndUpdatePhotoUrl(imageFile);
  }

  @override
  Future<void> removeAvatar() {
    return _delegateFor(_user).removeAvatar();
  }

  BackendUserProfileService _delegateFor(User user) {
    return BackendUserProfileService(
      account: FirebaseAccountProfileBackend(user),
      storage: FirebaseUserAvatarStorage(_storage),
    );
  }
}

class FirebaseAccountProfileBackend implements AccountProfileBackend {
  FirebaseAccountProfileBackend(this._user);

  final User _user;

  @override
  String get uid => _user.uid;

  @override
  String? get email => _user.email;

  @override
  String? get displayName => _user.displayName;

  @override
  String? get photoUrl => _user.photoURL;

  @override
  Future<void> updateDisplayName(String displayName) {
    return _user.updateDisplayName(displayName);
  }

  @override
  Future<void> updatePhotoUrl(String? photoUrl) {
    return _user.updatePhotoURL(photoUrl);
  }

  @override
  Future<void> reload() => _user.reload();
}

class FirebaseUserAvatarStorage implements UserAvatarStorage {
  FirebaseUserAvatarStorage(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<void> uploadFile({
    required String path,
    required File file,
    required String contentType,
  }) {
    return _storage
        .ref()
        .child(path)
        .putFile(file, SettableMetadata(contentType: contentType));
  }

  @override
  Future<String> downloadUrl(String path) {
    return _storage.ref().child(path).getDownloadURL();
  }

  @override
  Future<void> delete(String path) {
    return _storage.ref().child(path).delete();
  }
}

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return FirebaseUserProfileService(
    auth: ref.watch(firebaseAuthProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

final accountProfileProvider = Provider<AccountProfile?>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(userProfileServiceProvider).currentProfile();
});
