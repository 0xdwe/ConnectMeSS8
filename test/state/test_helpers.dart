import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../test_overrides.dart';

/// Pass 4.5 #070 test container with full store / auth / batched
/// writes overrides. Thin wrapper over [signedInDemoOverrides] so
/// tests that don't need to peek at the individual stores can get
/// a working container in one line.
ProviderContainer passFourFiveTestContainer({
  List<dynamic> extraOverrides = const <dynamic>[],
}) {
  return ProviderContainer(
    overrides: [...signedInDemoOverrides(), ...extraOverrides],
  );
}
