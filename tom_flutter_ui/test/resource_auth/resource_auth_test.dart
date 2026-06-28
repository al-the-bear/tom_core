import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/resource_auth/resource_auth_example.dart' as example;

void main() {
  // These globals are process-wide singletons; reset around every test so
  // ordering can never leak state between cases.
  setUp(() {
    TomUIColors.reset();
    TomUIIcons.reset();
    TomConfigProvider.reset();
    AllColorsAdapter.clearCustomColors();
    AllIconsAdapter.clearCustomIcons();
  });

  tearDown(() {
    TomUIColors.reset();
    TomUIIcons.reset();
    TomConfigProvider.reset();
    AllColorsAdapter.clearCustomColors();
    AllIconsAdapter.clearCustomIcons();
  });

  group('resource_auth example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('TomUIColors / AllColorsAdapter', () {
    test('returns null and false when no adapter installed', () {
      expect(TomUIColors.resolveColor('mRed'), isNull);
      expect(TomUIColors.colorExists('mRed'), isFalse);
    });

    test('resolves named, hex (3/6/8) and rgb colours', () {
      TomUIColors.adapter = AllColorsAdapter();
      expect(TomUIColors.resolveColor('mRed'), Colors.red);
      expect(TomUIColors.resolveColor('#FF5733'), const Color(0xFFFF5733));
      expect(TomUIColors.resolveColor('#F53'), const Color(0xFFFF5533));
      expect(TomUIColors.resolveColor('#80FF5733'), const Color(0x80FF5733));
      expect(TomUIColors.resolveColor('rgb(0, 128, 255)'),
          const Color(0xFF0080FF));
      expect(TomUIColors.resolveColor('rgba(255, 0, 0, 0.5)'),
          const Color(0x80FF0000));
    });

    test('rgb values are clamped to valid ranges', () {
      final adapter = AllColorsAdapter();
      expect(adapter.resolveColor('rgb(999, 128, 0)'),
          const Color(0xFFFF8000));
    });

    test('colorExists recognises hex, rgb and named', () {
      final adapter = AllColorsAdapter();
      expect(adapter.colorExists('#FFFFFF'), isTrue);
      expect(adapter.colorExists('rgb(1,2,3)'), isTrue);
      expect(adapter.colorExists('mBlue'), isTrue);
      expect(adapter.colorExists('definitelyNotAColor'), isFalse);
    });

    test('custom colours take precedence and can be cleared', () {
      TomUIColors.adapter = AllColorsAdapter();
      AllColorsAdapter.registerColors({'mRed': const Color(0xFF000000)});
      expect(TomUIColors.resolveColor('mRed'), const Color(0xFF000000));
      AllColorsAdapter.clearCustomColors();
      expect(TomUIColors.resolveColor('mRed'), Colors.red);
    });

    test('unknown name resolves to null', () {
      TomUIColors.adapter = AllColorsAdapter();
      expect(TomUIColors.resolveColor('notARealColor'), isNull);
    });
  });

  group('TomUIIcons / icon adapters', () {
    test('returns null and false when no adapter installed', () {
      expect(TomUIIcons.resolveIcon('mSave'), isNull);
      expect(TomUIIcons.iconExists('mSave'), isFalse);
    });

    test('AllIconsAdapter resolves Material and Cupertino', () {
      TomUIIcons.adapter = AllIconsAdapter();
      expect(TomUIIcons.resolveIcon('mSave'), Icons.save);
      expect(TomUIIcons.resolveIcon('cShare'), CupertinoIcons.share);
      expect(TomUIIcons.iconExists('mSettings'), isTrue);
      expect(TomUIIcons.resolveIcon('notAnIcon'), isNull);
    });

    test('custom icons take precedence and can be cleared', () {
      TomUIIcons.adapter = AllIconsAdapter();
      AllIconsAdapter.registerIcons({'mSave': Icons.delete});
      expect(TomUIIcons.resolveIcon('mSave'), Icons.delete);
      AllIconsAdapter.clearCustomIcons();
      expect(TomUIIcons.resolveIcon('mSave'), Icons.save);
    });

    test('MaterialOnlyAdapter resolves only Material icons', () {
      final adapter = MaterialOnlyAdapter();
      expect(adapter.resolveIcon('mSave'), Icons.save);
      expect(adapter.resolveIcon('cShare'), isNull);
      expect(adapter.iconExists('mSave'), isTrue);
      expect(adapter.iconExists('cShare'), isFalse);
    });

    test('CupertinoOnlyAdapter resolves only Cupertino icons', () {
      final adapter = CupertinoOnlyAdapter();
      expect(adapter.resolveIcon('cShare'), CupertinoIcons.share);
      expect(adapter.resolveIcon('mSave'), isNull);
      expect(adapter.iconExists('cShare'), isTrue);
      expect(adapter.iconExists('mSave'), isFalse);
    });
  });

  group('TomConfigProvider', () {
    test('throws before initialisation', () {
      expect(() => TomConfigProvider.current, throwsStateError);
    });

    test('exposes environment, platform and flags', () {
      TomConfigProvider.initialize(TomConfigProvider.create(
        environment: TomEnvironment.staging,
        platform: TomPlatform.desktop,
        flags: {'beta': true, 'limit': 10, 'name': 'x'},
      ));
      final cfg = TomConfigProvider.current;
      expect(cfg.environment, TomEnvironment.staging);
      expect(cfg.platform, TomPlatform.desktop);
      expect(cfg.isEnabled('beta'), isTrue);
      expect(cfg.feature<int>('limit'), 10);
      expect(cfg.feature<String>('name'), 'x');
    });

    test('feature returns null on type mismatch or missing', () {
      TomConfigProvider.initialize(TomConfigProvider.create(
        environment: TomEnvironment.development,
        platform: TomPlatform.mobile,
        flags: {'limit': 10},
      ));
      final cfg = TomConfigProvider.current;
      expect(cfg.feature<String>('limit'), isNull);
      expect(cfg.feature<int>('missing'), isNull);
    });

    test('isEnabled treats true, "true" and 1 as truthy', () {
      TomConfigProvider.initialize(TomConfigProvider.create(
        environment: TomEnvironment.development,
        platform: TomPlatform.mobile,
        flags: {'a': true, 'b': 'true', 'c': 1, 'd': false, 'e': 'no'},
      ));
      final cfg = TomConfigProvider.current;
      expect(cfg.isEnabled('a'), isTrue);
      expect(cfg.isEnabled('b'), isTrue);
      expect(cfg.isEnabled('c'), isTrue);
      expect(cfg.isEnabled('d'), isFalse);
      expect(cfg.isEnabled('e'), isFalse);
      expect(cfg.isEnabled('missing'), isFalse);
    });
  });

  group('authorization re-exports', () {
    test('TomAuthState ordering and predicates', () {
      expect(TomAuthState.values,
          [TomAuthState.none, TomAuthState.disabled, TomAuthState.read,
            TomAuthState.full]);
      expect(TomAuthState.none.isVisible, isFalse);
      expect(TomAuthState.read.isVisible, isTrue);
      expect(TomAuthState.read.isInteractive, isFalse);
      expect(TomAuthState.full.isInteractive, isTrue);
      expect(TomAuthState.read.showsContent, isTrue);
    });
  });
}
