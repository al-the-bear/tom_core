import 'dart:io';

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

    test('carries the swatch shades the SDK declares beyond 50..900', () {
      // Grey is the one Material swatch with off-scale shades. A table
      // transcribed by hand drops them, because they are not in the pattern
      // every other family follows; one walked out of the SDK cannot.
      final adapter = AllColorsAdapter();
      expect(adapter.resolveColor('mGrey350'), const Color(0xFFD6D6D6));
      expect(adapter.resolveColor('mGrey850'), const Color(0xFF303030));
    });

    test('carries every CupertinoColors constant, transparent included', () {
      final adapter = AllColorsAdapter();
      expect(adapter.resolveColor('cTransparent'), const Color(0x00000000));
    });
  });

  // The colour table is emitted by `tool/generate_colors.dart` and must stay
  // reproducible: regenerating an unchanged palette has to produce no diff, so
  // the header may state nothing the entries do not determine. Both checks
  // below failed on the hand-authored table this generator replaced — it
  // claimed "60+" Cupertino colours against 46, and carried a wall-clock
  // stamp for a file no tool had ever written.
  group('tom_colors_generated.dart header', () {
    final source =
        File('lib/src/resource_auth/tom_colors_generated.dart').readAsStringSync();

    int declaredCount(String label) {
      final match = RegExp('^// $label: (\\d+)\$', multiLine: true)
          .firstMatch(source);
      expect(match, isNotNull, reason: 'no "$label:" line in the header');
      return int.parse(match!.group(1)!);
    }

    int entryCount(String mapName) {
      final start = source.indexOf('static const Map<String, Color> $mapName');
      expect(start, greaterThan(-1), reason: 'no $mapName map');
      final body = source.substring(start, source.indexOf('\n  };', start));
      return RegExp("^    '\\w+':", multiLine: true).allMatches(body).length;
    }

    test('states the counts the two maps actually hold', () {
      final material = entryCount('materialColors');
      final cupertino = entryCount('cupertinoColors');
      expect(declaredCount('Material colors'), material);
      expect(declaredCount('Cupertino colors'), cupertino);
      expect(declaredCount('Total'), material + cupertino);
    });

    test('records no generation timestamp', () {
      expect(source, isNot(contains('Generated on:')));
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

  // `tom_auth_state.dart` re-exports a fixed list of kernel names, and
  // `doc/resource_auth.md` enumerates that list in prose. Nothing kept the two
  // in step, and they drifted: the doc named eight of the nine, omitting
  // `AuthGroupMode` — the enum deciding whether a group narrows, replaces or
  // lifts its members' states. An enumeration that silently loses an entry is
  // worse than no enumeration, because it still reads as complete.
  group('doc/resource_auth.md enumerates the re-export', () {
    test('names every symbol the show list carries', () {
      final source =
          File('lib/src/resource_auth/tom_auth_state.dart').readAsStringSync();
      final shown = RegExp(r'show\s+([^;]+);').firstMatch(source);
      expect(shown, isNotNull, reason: 'no show list in tom_auth_state.dart');
      final names = shown!
          .group(1)!
          .split(',')
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .toList();
      expect(names, hasLength(9));

      final doc = File('doc/resource_auth.md').readAsStringSync();
      final start = doc.indexOf('## Authorization re-exports');
      expect(start, greaterThan(-1), reason: 'no re-exports section');
      final end = doc.indexOf('\n## ', start + 1);
      final section = doc.substring(start, end == -1 ? doc.length : end);

      final missing = names.where((n) => !section.contains('`$n`')).toList();
      expect(missing, isEmpty,
          reason: 'the re-export shows these names, but the '
              '"Authorization re-exports" section of doc/resource_auth.md '
              'never mentions them: $missing');
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
