// Global test configuration. Auto-discovered by `flutter test`.
//
// Two responsibilities:
//
// 1. Disable `google_fonts` runtime HTTP fetching during tests.
//    Without this, every theme construction triggers font asset
//    downloads to fonts.gstatic.com, which fails in offline test
//    environments and floods stderr.
//
//    The fallback (Roboto on iOS/Android, system on macOS) is fine
//    for tests — we don't render Inter glyphs in widget tests, we
//    only verify structural behavior. Tests that *want* to assert
//    Inter is wired up must do so by inspecting the TextStyle the
//    widget receives, not by expecting the actual font to be
//    rendered.
//
// 2. Register a `PathProviderPlatform` test fake so #041's
//    `FileMemoryStore` (the production `memoryStoreProvider`) can
//    resolve `getApplicationDocumentsDirectory()` without a real
//    platform channel. Each test process gets its own temp directory
//    via `Directory.systemTemp.createTempSync`, isolated from other
//    runs and cleaned up by the OS.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _TestPathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TestPathProvider(this._root);
  final Directory _root;

  @override
  Future<String?> getTemporaryPath() async => _ensure('tmp');
  @override
  Future<String?> getApplicationSupportPath() async => _ensure('support');
  @override
  Future<String?> getLibraryPath() async => _ensure('library');
  @override
  Future<String?> getApplicationDocumentsPath() async => _ensure('documents');
  @override
  Future<String?> getExternalStoragePath() async => _ensure('external');
  @override
  Future<List<String>?> getExternalCachePaths() async => [_ensure('external_cache')];
  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async =>
      [_ensure('external_storage')];
  @override
  Future<String?> getDownloadsPath() async => _ensure('downloads');

  String _ensure(String name) {
    final d = Directory('${_root.path}/$name');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final tempRoot = Directory.systemTemp.createTempSync('connectme_test_');
  PathProviderPlatform.instance = _TestPathProvider(tempRoot);

  await testMain();
}
