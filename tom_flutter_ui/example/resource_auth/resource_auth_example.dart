/// Executable example for the `resource_auth/` module of `tom_flutter_ui`.
///
/// Demonstrates name → object resolution (the heart of the module): colours and
/// icons stored as *names* in resources are turned into real `Color` /
/// `IconData` through pluggable adapters, plus the `TomConfigProvider`
/// environment/flag store and the re-exported `TomAuthState`.
///
/// Because it imports `flutter/material` (→ `dart:ui`), bare `dart run` cannot
/// execute it. Run `flutter test test/resource_auth/resource_auth_test.dart`,
/// which calls this example and reports its result in the exit code.
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
  TomUIColors.adapter = TomAllColorsAdapter();
  final named = TomUIColors.resolveColor('mRed');
  final hex = TomUIColors.resolveColor('#FF5733');
  final rgb = TomUIColors.resolveColor('rgb(0, 128, 255)');
  print('mRed=$named  #FF5733=$hex  rgb=$rgb');

  // Example 2: custom colour registration overrides/extends the palette.
  TomUIColors.registerColors({'brandPrimary': const Color(0xFF123456)});
  final brand = TomUIColors.resolveColor('brandPrimary');
  print(
    'brandPrimary=$brand  exists=${TomUIColors.colorExists('brandPrimary')}',
  );

  // Example 3: single-family colour adapters — one palette instead of both.
  // Registrations and hex/rgb literals still resolve through them; only the
  // other family's table is gone.
  final materialColors = TomMaterialOnlyColorAdapter();
  final cupertinoColors = TomCupertinoOnlyColorAdapter();
  print(
    'materialColors cSystemBlue -> '
    '${materialColors.resolveColor('cSystemBlue')}',
  );
  print('cupertinoColors mRed -> ${cupertinoColors.resolveColor('mRed')}');
  print(
    'materialColors brandPrimary -> '
    '${materialColors.resolveColor('brandPrimary')}',
  );

  // Example 4: icon resolution across families and the single-family adapters.
  TomUIIcons.adapter = TomAllIconsAdapter();
  final save = TomUIIcons.resolveIcon('mSave');
  final share = TomUIIcons.resolveIcon('cShare');
  print('mSave=$save  cShare=$share');

  final materialOnly = TomMaterialOnlyIconAdapter();
  final cupertinoOnly = TomCupertinoOnlyIconAdapter();
  print('materialOnly cShare -> ${materialOnly.resolveIcon('cShare')}');
  print('cupertinoOnly mSave -> ${cupertinoOnly.resolveIcon('mSave')}');

  // Example 5: configuration — environment, platform, and feature flags.
  // The three enabled flags below are spelled the three ways the sources
  // flags come from can spell them: Dart hands over a bool, YAML a number,
  // and --dart-define nothing but text. All three mean the same thing.
  TomConfigProvider.initialize(
    TomConfigProvider.create(
      environment: TomConfigEnvironment.production,
      platform: TomConfigPlatform.web,
      flags: {
        'newCheckout': true,
        'compactRows': 1,
        'betaBanner': 'TRUE',
        'legacyGrid': 'yes', // not the vocabulary — disabled, not enabled
        'maxItems': 50,
      },
    ),
  );
  final cfg = TomConfigProvider.current;
  print(
    'env=${cfg.environment} platform=${cfg.platform} '
    'newCheckout=${cfg.isEnabled('newCheckout')} '
    'maxItems=${cfg.feature<int>('maxItems')}',
  );

  // Example 6: the re-exported authorization state ordering.
  print('auth states (restrictive→full): ${TomAuthState.values}');

  // -------------------------------------------------------------------------
  // Assertions
  // -------------------------------------------------------------------------
  assert(named == Colors.red);
  assert(hex == const Color(0xFFFF5733));
  assert(rgb == const Color(0xFF0080FF));
  assert(brand == const Color(0xFF123456));
  assert(TomUIColors.colorExists('#FFFFFF'));

  // Single-family colour adapters resolve only their own palette, but keep
  // the module-wide registrations and the hex/rgb syntax.
  assert(materialColors.resolveColor('cSystemBlue') == null);
  assert(materialColors.resolveColor('mRed') == Colors.red);
  assert(
    materialColors.resolveColor('brandPrimary') == const Color(0xFF123456),
  );
  assert(materialColors.resolveColor('#FF5733') == const Color(0xFFFF5733));
  assert(cupertinoColors.resolveColor('mRed') == null);
  assert(
    cupertinoColors.resolveColor('cTransparent') == const Color(0x00000000),
  );

  assert(save == Icons.save);
  assert(share == CupertinoIcons.share);
  // Single-family adapters resolve only their own family.
  assert(materialOnly.resolveIcon('cShare') == null);
  assert(materialOnly.resolveIcon('mSave') == Icons.save);
  assert(cupertinoOnly.resolveIcon('mSave') == null);
  assert(cupertinoOnly.resolveIcon('cShare') == CupertinoIcons.share);

  assert(cfg.environment == TomConfigEnvironment.production);
  assert(cfg.feature<int>('maxItems') == 50);
  assert(cfg.feature<String>('maxItems') == null); // wrong type -> null

  // true, 1 and a case-folded 'true' are one rule, not three special cases.
  assert(cfg.isEnabled('newCheckout'));
  assert(cfg.isEnabled('compactRows'));
  assert(cfg.isEnabled('betaBanner'));
  // The tolerance stops at spelling: 'yes' is a synonym, not a spelling, and
  // an unset flag is off. Neither is lost — feature<T> still reports them.
  assert(!cfg.isEnabled('legacyGrid'));
  assert(cfg.feature<String>('legacyGrid') == 'yes');
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
