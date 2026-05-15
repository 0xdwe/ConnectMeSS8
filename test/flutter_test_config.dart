// Global test configuration. Auto-discovered by `flutter test`.
//
// Disables `google_fonts` runtime HTTP fetching during tests. Without
// this, every theme construction triggers font asset downloads to
// fonts.gstatic.com, which fails in offline test environments and
// floods stderr.
//
// The fallback (Roboto on iOS/Android, system on macOS) is fine for
// tests — we don't render Inter glyphs in widget tests, we only verify
// structural behavior. Tests that *want* to assert Inter is wired up
// must do so by inspecting the TextStyle the widget receives, not by
// expecting the actual font to be rendered.

// Global test configuration. Auto-discovered by `flutter test`.
//
// Disables `google_fonts` runtime HTTP fetching during tests. Without
// this, every theme construction triggers font asset downloads to
// fonts.gstatic.com, which fails in offline test environments and
// floods stderr.
//
// The fallback (Roboto on iOS/Android, system on macOS) is fine for
// tests — we don't render Inter glyphs in widget tests, we only verify
// structural behavior. Tests that *want* to assert Inter is wired up
// must do so by inspecting the TextStyle the widget receives, not by
// expecting the actual font to be rendered.

import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
