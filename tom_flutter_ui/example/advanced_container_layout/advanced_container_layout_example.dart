/// Executable example for the `advanced_container_layout/` module of
/// `tom_flutter_ui`.
///
/// `advanced_container_layout/` (ACL) is the fluent, row-based layout engine
/// behind the Tom UI. A layout is declared with [AclBuilder] — append widgets,
/// break rows, tune sizes/alignments/groups — and `build()` produces an [Acl]
/// widget. The engine layers on responsive *variants*, *row breakpoints*,
/// per-group *visibility controllers*, and *device-context* variant detection.
///
/// This example demonstrates the pure-logic surfaces (no `BuildContext`):
///
/// 1. [AclFlags] bit composition (the AWT-style attribute constants),
/// 2. the static [AclDeviceContext] resolvers (`resolveFormFactor`,
///    `resolveDensity`, `resolveInputMode`) and `buildConvenienceDetector`,
/// 3. the group-visibility controllers ([AclBinaryVisibilityController] and
///    [AclCallbackVisibilityController]) driven by `ValueNotifier`s,
/// 4. an [AclBuilder] fluent chain producing an [Acl] widget (pure
///    construction — no rendering).
///
/// Because it imports `flutter/material` (→ `dart:ui`) through the package
/// barrel, bare `dart run` cannot execute it. Run `flutter test
/// test/advanced_container_layout/advanced_container_layout_example_test.dart`,
/// which calls this example and reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void run() {
  // ---------------------------------------------------------------------------
  // 1. AclFlags — AWT-style attribute bits compose with bitwise OR.
  // ---------------------------------------------------------------------------
  print('AclFlags.expandX | expandY = ${AclFlags.expandX | AclFlags.expandY}');
  print('AclFlags.expand            = ${AclFlags.expand}');
  print('AclFlags.otherDim          = ${AclFlags.otherDim}');

  // ---------------------------------------------------------------------------
  // 2. AclDeviceContext static resolvers (pure functions, no BuildContext).
  // ---------------------------------------------------------------------------
  final phone = AclDeviceContext.resolveFormFactor(420);
  final tablet = AclDeviceContext.resolveFormFactor(800);
  final desktop = AclDeviceContext.resolveFormFactor(1440);
  print('formFactor 420/800/1440 = $phone / $tablet / $desktop');

  final compact = AclDeviceContext.resolveDensity(
    const VisualDensity(horizontal: -2, vertical: -2),
  );
  final comfortable = AclDeviceContext.resolveDensity(
    const VisualDensity(horizontal: -1, vertical: -1),
  );
  final standard = AclDeviceContext.resolveDensity(VisualDensity.standard);
  print(
    'density compact/comfortable/standard = '
    '$compact / $comfortable / $standard',
  );

  final touch = AclDeviceContext.resolveInputMode(TargetPlatform.iOS);
  final pointer = AclDeviceContext.resolveInputMode(TargetPlatform.macOS);
  print('inputMode iOS/macOS = $touch / $pointer');

  // buildConvenienceDetector returns null for an empty spec (the default
  // variant) and a non-null AND-combined predicate when any field is set.
  final defaultDetector = AclDeviceContext.buildConvenienceDetector();
  final phoneDetector = AclDeviceContext.buildConvenienceDetector(
    formFactor: AclFormFactor.phone,
  );
  print('default detector is null: ${defaultDetector == null}');
  print('phone detector is non-null: ${phoneDetector != null}');

  // ---------------------------------------------------------------------------
  // 3. Group-visibility controllers — ValueNotifier-backed, no widget tree.
  // ---------------------------------------------------------------------------
  final binary = AclBinaryVisibilityController(
    initialMode: AclGroupVisibilityMode.hidden,
  );
  print('binary initial: ${binary.mode}');
  binary.mode = AclGroupVisibilityMode.visible;
  print('binary toggled: ${binary.mode}');

  final country = ValueNotifier<String>('DE');
  final callback = AclCallbackVisibilityController<String>(
    valueListenable: country,
    modeBuilder: (c) => c == 'US'
        ? AclGroupVisibilityMode.visible
        : AclGroupVisibilityMode.hidden,
  );
  print('callback for DE: ${callback.mode}');
  country.value = 'US';
  print('callback for US: ${callback.mode}');

  // ---------------------------------------------------------------------------
  // 4. AclBuilder fluent chain → Acl widget (pure construction).
  // ---------------------------------------------------------------------------
  final Widget acl = AclBuilder(title: 'Address')
      .append(const Text('Street'))
      .gap()
      .append(const Text('No.'))
      .expandX()
      .newRow()
      .append(const Text('City'))
      .build();
  print('built layout is Acl: ${acl is Acl}');

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
  assert(AclFlags.expand == (AclFlags.expandX | AclFlags.expandY));
  assert(AclFlags.otherDim == (AclFlags.otherDimX | AclFlags.otherDimY));

  assert(phone == AclFormFactor.phone);
  assert(tablet == AclFormFactor.tablet);
  assert(desktop == AclFormFactor.desktop);

  assert(compact == AclDensity.compact);
  assert(comfortable == AclDensity.comfortable);
  assert(standard == AclDensity.standard);

  assert(touch == AclInputMode.touch);
  assert(pointer == AclInputMode.pointer);

  assert(defaultDetector == null);
  assert(phoneDetector != null);

  assert(binary.mode == AclGroupVisibilityMode.visible);
  assert(callback.mode == AclGroupVisibilityMode.visible);

  assert(acl is Acl);

  // Controllers own a ValueNotifier — release it.
  binary.dispose();
  callback.dispose();
  country.dispose();
}

void main() => run();
