/// Executable example for the resources module of `tom_core_flutter`.
///
/// Demonstrates resolving typed config values via `TomProperty` subclasses and
/// the `.withDefault` fallback. A deterministic in-memory config provider is
/// installed so the example is self-contained.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so run
/// this under the Flutter toolchain, e.g.
/// `flutter test example/resources/resources_example.dart`, not bare
/// `dart run`. The same behaviour is covered by `test/resources_test.dart`.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

void run() {
  // Install an in-memory config so the example resolves deterministically.
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from({
      'app.title': 'Tom Demo',
      'app.retries': 3,
      'app.ratio': 1.5,
      'app.flag': true,
    }),
  );

  // Example 1: all four typed properties resolve their value at construction.
  final title = TomStringProperty('app.title');
  final retries = TomIntProperty('app.retries');
  final ratio = TomDoubleProperty('app.ratio');
  final flag = TomBoolProperty('app.flag');
  print('title=${~title} retries=${retries.get()} '
      'ratio=${~ratio} flag=${~flag}');

  // Example 2: a default fills in when the key is absent.
  final timeout = TomIntProperty.withDefault('app.timeout', 30);
  print('timeout (defaulted)=${~timeout}');

  // Example 3: withDefault prefers a present config value over the default.
  final ratioOrDefault = TomDoubleProperty.withDefault('app.ratio', 9.9);
  print('ratio (present wins over default)=${~ratioOrDefault}');

  // Assertions
  assert(~title == 'Tom Demo');
  assert(retries.get() == 3);
  assert(~ratio == 1.5);
  assert(~flag == true);
  assert(~timeout == 30);
  assert(~ratioOrDefault == 1.5);
}

void main() => run();
