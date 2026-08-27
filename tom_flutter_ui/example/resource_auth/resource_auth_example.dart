/// Executable example for the `resource_auth/` module of `tom_flutter_ui`.
///
/// Demonstrates name → object resolution (the heart of the module): colours and
/// icons stored as *names* in resources are turned into real `Color` /
/// `IconData` through pluggable adapters, plus the `TomConfigProvider`
/// environment/flag store and the re-exported `TomAuthState`.
///
/// Because it imports `flutter/material` (→ `dart:ui`), run it under the Flutter
/// toolchain, e.g. `flutter test example/resource_auth/resource_auth_example.dart`,
/// not bare `dart run`. The same scenarios are covered by
/// `test/resource_auth/resource_auth_test.dart`.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void run() {
  // Clear any globals so the example is self-contained (these are process-wide
  // singletons). reset() drops custom registrations along with the adapter, so
  // it is the whole hook.
  TomUIColors.reset();
  TomUIIcons.reset();
  TomConfigProvider.reset();

  // Example 1: colour resolution — named, hex, and rgb, via one adapter.
  TomUIColors.adapter = AllColorsAdapter();
  final named = TomUIColors.resolveColor('mRed');
  final hex = TomUIColors.resolveColor('#FF5733');
  final rgb = TomUIColors.resolveColor('rgb(0, 128, 255)');
  print('mRed=$named  #FF5733=$hex  rgb=$rgb');

  // Example 2: custom colour registration overrides/extends the palette.
  AllColorsAdapter.registerColors({'brandPrimary': const Color(0xFF123456)});
  final brand = TomUIColors.resolveColor('brandPrimary');
  print('brandPrimary=$brand  exists=${TomUIColors.colorExists('brandPrimary')}');

  // Example 3: icon resolution across families and the single-family adapters.
  TomUIIcons.adapter = AllIconsAdapter();
  final save = TomUIIcons.resolveIcon('mSave');
  final share = TomUIIcons.resolveIcon('cShare');
  print('mSave=$save  cShare=$share');

  final materialOnly = MaterialOnlyAdapter();
  final cupertinoOnly = CupertinoOnlyAdapter();
  print('materialOnly cShare -> ${materialOnly.resolveIcon('cShare')}');
  print('cupertinoOnly mSave -> ${cupertinoOnly.resolveIcon('mSave')}');

  // Example 4: configuration — environment, platform, and feature flags.
  TomConfigProvider.initialize(TomConfigProvider.create(
    environment: TomEnvironment.production,
    platform: TomPlatform.web,
    flags: {'newCheckout': true, 'maxItems': 50},
  ));
  final cfg = TomConfigProvider.current;
  print('env=${cfg.environment} platform=${cfg.platform} '
      'newCheckout=${cfg.isEnabled('newCheckout')} '
      'maxItems=${cfg.feature<int>('maxItems')}');

  // Example 5: the re-exported authorization state ordering.
  print('auth states (restrictive→full): ${TomAuthState.values}');

  // -------------------------------------------------------------------------
  // Assertions
  // -------------------------------------------------------------------------
  assert(named == Colors.red);
  assert(hex == const Color(0xFFFF5733));
  assert(rgb == const Color(0xFF0080FF));
  assert(brand == const Color(0xFF123456));
  assert(TomUIColors.colorExists('#FFFFFF'));

  assert(save == Icons.save);
  assert(share == CupertinoIcons.share);
  // Single-family adapters resolve only their own family.
  assert(materialOnly.resolveIcon('cShare') == null);
  assert(materialOnly.resolveIcon('mSave') == Icons.save);
  assert(cupertinoOnly.resolveIcon('mSave') == null);
  assert(cupertinoOnly.resolveIcon('cShare') == CupertinoIcons.share);

  assert(cfg.environment == TomEnvironment.production);
  assert(cfg.isEnabled('newCheckout'));
  assert(cfg.feature<int>('maxItems') == 50);
  assert(cfg.feature<String>('maxItems') == null); // wrong type -> null
  assert(!cfg.isEnabled('missingFlag'));

  // none < disabled < read < full
  assert(TomAuthState.none.index < TomAuthState.full.index);
  assert(!TomAuthState.none.isVisible);
  assert(TomAuthState.full.isInteractive);

  // Restore clean global state — including the brandPrimary registration
  // above, which reset() drops with the adapter.
  TomUIColors.reset();
  TomUIIcons.reset();
  TomConfigProvider.reset();
}

void main() => run();
