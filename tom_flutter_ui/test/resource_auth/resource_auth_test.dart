import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/resource_auth/resource_auth_example.dart' as example;

void main() {
  // These globals are process-wide singletons; reset around every test so
  // ordering can never leak state between cases. reset() covers registrations
  // as well as the adapter, so these three calls are the whole teardown.
  setUp(() {
    TomUIColors.reset();
    TomUIIcons.reset();
    TomConfigProvider.reset();
  });

  tearDown(() {
    TomUIColors.reset();
    TomUIIcons.reset();
    TomConfigProvider.reset();
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

    test('resolves named, hex (3/4/6/8) and rgb colours', () {
      TomUIColors.adapter = AllColorsAdapter();
      expect(TomUIColors.resolveColor('mRed'), Colors.red);
      expect(TomUIColors.resolveColor('#FF5733'), const Color(0xFFFF5733));
      expect(TomUIColors.resolveColor('#F53'), const Color(0xFFFF5533));
      expect(TomUIColors.resolveColor('#80FF5733'), const Color(0x80FF5733));
      expect(TomUIColors.resolveColor('#8F53'), const Color(0x88FF5533));
      expect(
        TomUIColors.resolveColor('rgb(0, 128, 255)'),
        const Color(0xFF0080FF),
      );
      expect(
        TomUIColors.resolveColor('rgba(255, 0, 0, 0.5)'),
        const Color(0x80FF0000),
      );
    });

    // Both alpha-carrying hex forms put alpha FIRST, matching Dart's
    // Color(0x...) literal. CSS, Figma and Sketch put it last, and the two
    // orderings are indistinguishable at runtime: a designer pasting
    // #FF5733AA (orange at two-thirds alpha) gets an opaque blue-violet, with
    // colorExists reporting true so no validation pass catches it. Nothing can
    // fix that at parse time — which is why the position is pinned here and
    // spelled out in the dartdoc, the readme and doc/resource_auth.md.
    group('hex alpha is the leading pair, not the trailing one', () {
      test('the 8-digit form reads AARRGGBB', () {
        final adapter = AllColorsAdapter();
        final c = adapter.resolveColor('#80FF5733')!;
        expect(c, const Color(0x80FF5733));
        // Spelled out channel by channel, so a reordering cannot pass by
        // matching some other literal that happens to be equal.
        expect(
          c.a,
          closeTo(0x80 / 0xFF, 0.001),
          reason: 'alpha is the first pair',
        );
        expect(c.r, closeTo(1.0, 0.001), reason: 'red is the second pair');
        expect(c.g, closeTo(0x57 / 0xFF, 0.001));
        expect(c.b, closeTo(0x33 / 0xFF, 0.001));
      });

      test('the 4-digit form reads ARGB, each digit doubled', () {
        final adapter = AllColorsAdapter();
        final c = adapter.resolveColor('#8F53')!;
        expect(c, const Color(0x88FF5533));
        expect(
          c.a,
          closeTo(0x88 / 0xFF, 0.001),
          reason: 'alpha is the first digit',
        );
        expect(c.r, closeTo(1.0, 0.001));
        expect(c.g, closeTo(0x55 / 0xFF, 0.001));
        expect(c.b, closeTo(0x33 / 0xFF, 0.001));
        // The shorthand agrees with the long form it abbreviates.
        expect(c, adapter.resolveColor('#88FF5533'));
      });

      test('the alpha-less forms are fully opaque', () {
        final adapter = AllColorsAdapter();
        expect(adapter.resolveColor('#FF5733')!.a, 1.0);
        expect(adapter.resolveColor('#F53')!.a, 1.0);
      });

      test('colorExists agrees with resolveColor on every hex width', () {
        final adapter = AllColorsAdapter();
        for (final name in ['#F53', '#8F53', '#FF5733', '#80FF5733']) {
          expect(
            adapter.colorExists(name),
            isTrue,
            reason: '$name should exist',
          );
          expect(adapter.resolveColor(name), isNotNull, reason: name);
        }
        // Widths between and beyond the four remain unknown rather than
        // being coerced into the nearest one.
        for (final name in ['#F', '#FF', '#FF573', '#FF57333', '#FF5733AAB']) {
          expect(adapter.colorExists(name), isFalse, reason: name);
          expect(adapter.resolveColor(name), isNull, reason: name);
        }
      });
    });

    test('rgb values are clamped to valid ranges', () {
      final adapter = AllColorsAdapter();
      expect(adapter.resolveColor('rgb(999, 128, 0)'), const Color(0xFFFF8000));
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

  // The single-family colour adapters mirror the icon ones, and for the same
  // two reasons: an app targeting one platform stops carrying the other
  // family's table, and — the reason that shows up in a bug report rather than
  // a bundle report — a `cSystemBlue` left in a Material-only resource file
  // resolves to null and gets caught, instead of quietly working.
  group('single-family colour adapters', () {
    test('MaterialOnlyColorAdapter resolves only Material colours', () {
      final adapter = MaterialOnlyColorAdapter();
      expect(adapter.resolveColor('mRed'), Colors.red);
      expect(adapter.resolveColor('mBlueGrey500'), const Color(0xFF607D8B));
      expect(adapter.resolveColor('cSystemBlue'), isNull);
      expect(adapter.colorExists('mRed'), isTrue);
      expect(adapter.colorExists('cSystemBlue'), isFalse);
    });

    test('CupertinoOnlyColorAdapter resolves only Cupertino colours', () {
      final adapter = CupertinoOnlyColorAdapter();
      expect(adapter.resolveColor('cTransparent'), const Color(0x00000000));
      expect(adapter.resolveColor('mRed'), isNull);
      expect(adapter.colorExists('cTransparent'), isTrue);
      expect(adapter.colorExists('mRed'), isFalse);
    });

    // Hex and rgb are syntax, not a palette: nothing about them belongs to
    // either family, and dropping them would make the single-family adapters
    // a different contract rather than a smaller one.
    test('hex and rgb parse through every colour adapter', () {
      for (final adapter in <TomUIColorAdapter>[
        AllColorsAdapter(),
        MaterialOnlyColorAdapter(),
        CupertinoOnlyColorAdapter(),
      ]) {
        final what = adapter.runtimeType;
        expect(
          adapter.resolveColor('#80FF5733'),
          const Color(0x80FF5733),
          reason: '$what cannot parse hex',
        );
        expect(
          adapter.resolveColor('rgba(255, 0, 0, 0.5)'),
          const Color(0x80FF0000),
          reason: '$what cannot parse rgba',
        );
        expect(adapter.colorExists('#F53'), isTrue, reason: '$what');
      }
    });

    // Same module-wide registry as the icon side, and the same silent failure
    // if it were not: registered brand colours would resolve to null after a
    // switch to a single-family adapter, with colorExists denying they exist.
    test('registrations reach the single-family colour adapters too', () {
      AllColorsAdapter.registerColors({'zBrand': const Color(0xFF112233)});
      for (final adapter in <TomUIColorAdapter>[
        AllColorsAdapter(),
        MaterialOnlyColorAdapter(),
        CupertinoOnlyColorAdapter(),
      ]) {
        expect(
          adapter.resolveColor('zBrand'),
          const Color(0xFF112233),
          reason: '${adapter.runtimeType} lost the registration',
        );
        expect(
          adapter.colorExists('zBrand'),
          isTrue,
          reason: '${adapter.runtimeType} denies the registration exists',
        );
      }
    });

    test('a colour registration overrides a built-in for every adapter', () {
      AllColorsAdapter.registerColors({'mRed': const Color(0xFF112233)});
      expect(
        MaterialOnlyColorAdapter().resolveColor('mRed'),
        const Color(0xFF112233),
      );
      expect(AllColorsAdapter().resolveColor('mRed'), const Color(0xFF112233));
    });

    test('clearing drops colour registrations for every adapter', () {
      AllColorsAdapter.registerColors({'zBrand': const Color(0xFF112233)});
      AllColorsAdapter.clearCustomColors();
      for (final adapter in <TomUIColorAdapter>[
        AllColorsAdapter(),
        MaterialOnlyColorAdapter(),
        CupertinoOnlyColorAdapter(),
      ]) {
        expect(adapter.resolveColor('zBrand'), isNull);
        expect(adapter.colorExists('zBrand'), isFalse);
      }
      // The built-in table is untouched by the round trip.
      expect(MaterialOnlyColorAdapter().resolveColor('mRed'), Colors.red);
    });

    test('colour registrations do not open the other family to a '
        'single-family adapter', () {
      AllColorsAdapter.registerColors({'zBrand': const Color(0xFF112233)});
      expect(MaterialOnlyColorAdapter().resolveColor('cSystemBlue'), isNull);
      expect(CupertinoOnlyColorAdapter().resolveColor('mRed'), isNull);
    });

    test('TomUIColors.reset() drops registrations for these adapters too', () {
      AllColorsAdapter.registerColors({'zBrand': const Color(0xFF112233)});
      TomUIColors.reset();
      expect(MaterialOnlyColorAdapter().resolveColor('zBrand'), isNull);
      expect(CupertinoOnlyColorAdapter().resolveColor('zBrand'), isNull);
    });
  });

  generatedTableHeaderTests(
    fileName: 'tom_colors_generated.dart',
    valueType: 'Color',
    maps: {
      'Material colors': 'materialColors',
      'Cupertino colors': 'cupertinoColors',
    },
  );

  generatedTableHeaderTests(
    fileName: 'tom_icons_generated.dart',
    valueType: 'IconData',
    maps: {
      'Material icons': 'materialIcons',
      'Cupertino icons': 'cupertinoIcons',
    },
  );

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

    test('MaterialOnlyIconAdapter resolves only Material icons', () {
      final adapter = MaterialOnlyIconAdapter();
      expect(adapter.resolveIcon('mSave'), Icons.save);
      expect(adapter.resolveIcon('cShare'), isNull);
      expect(adapter.iconExists('mSave'), isTrue);
      expect(adapter.iconExists('cShare'), isFalse);
    });

    test('CupertinoOnlyIconAdapter resolves only Cupertino icons', () {
      final adapter = CupertinoOnlyIconAdapter();
      expect(adapter.resolveIcon('cShare'), CupertinoIcons.share);
      expect(adapter.resolveIcon('mSave'), isNull);
      expect(adapter.iconExists('cShare'), isTrue);
      expect(adapter.iconExists('mSave'), isFalse);
    });

    // Registration is module-wide, not a property of AllIconsAdapter. The
    // failure this pins was silent and total: an app registers its brand
    // icons, switches to MaterialOnlyIconAdapter for bundle size — the one
    // documented reason to switch — and every registered icon resolves to
    // null with iconExists reporting false. Nothing throws; icons just stop
    // rendering. The two tests above could not see it because they only ever
    // ask for built-in names.
    test('registrations reach the single-family adapters too', () {
      AllIconsAdapter.registerIcons({'zBrandLogo': Icons.abc});
      for (final adapter in <TomUIIconAdapter>[
        AllIconsAdapter(),
        MaterialOnlyIconAdapter(),
        CupertinoOnlyIconAdapter(),
      ]) {
        expect(
          adapter.resolveIcon('zBrandLogo'),
          Icons.abc,
          reason: '${adapter.runtimeType} lost the registration',
        );
        expect(
          adapter.iconExists('zBrandLogo'),
          isTrue,
          reason: '${adapter.runtimeType} denies the registration exists',
        );
      }
    });

    test('a registration overrides a built-in for every adapter', () {
      AllIconsAdapter.registerIcons({'mSave': Icons.delete});
      expect(MaterialOnlyIconAdapter().resolveIcon('mSave'), Icons.delete);
      expect(AllIconsAdapter().resolveIcon('mSave'), Icons.delete);
    });

    test('clearing drops registrations for every adapter', () {
      AllIconsAdapter.registerIcons({'zBrandLogo': Icons.abc});
      AllIconsAdapter.clearCustomIcons();
      for (final adapter in <TomUIIconAdapter>[
        AllIconsAdapter(),
        MaterialOnlyIconAdapter(),
        CupertinoOnlyIconAdapter(),
      ]) {
        expect(adapter.resolveIcon('zBrandLogo'), isNull);
        expect(adapter.iconExists('zBrandLogo'), isFalse);
      }
      // The built-in table is untouched by the round trip.
      expect(MaterialOnlyIconAdapter().resolveIcon('mSave'), Icons.save);
    });

    test('registrations do not open the other family to a single-family '
        'adapter', () {
      // The point of these adapters is that they carry one family. A shared
      // registry must not become a back door to the other one.
      AllIconsAdapter.registerIcons({'zBrandLogo': Icons.abc});
      expect(MaterialOnlyIconAdapter().resolveIcon('cShare'), isNull);
      expect(CupertinoOnlyIconAdapter().resolveIcon('mSave'), isNull);
    });
  });

  // reset() is dartdoc'd as the test-hygiene hook, and it is the only hook a
  // reader is told about. It used to clear the adapter and nothing else, so a
  // suite that followed the dartdoc leaked every registration into every later
  // test in the same process — where an override silently changed a colour
  // instead of failing. This suite hid that from itself by calling
  // clearCustomColors/clearCustomIcons in setUp and tearDown as well; those
  // calls are gone now, so these tests are load-bearing for the whole file.
  group('reset() is the whole test-hygiene hook', () {
    test('TomUIColors.reset() drops custom colour registrations', () {
      AllColorsAdapter.registerColors({'zBrand': const Color(0xFF112233)});
      // The registry is process-global, so an adapter constructed before the
      // reset must see the clear too — that instance is what a leak rides on.
      final earlier = AllColorsAdapter();
      TomUIColors.reset();
      TomUIColors.adapter = AllColorsAdapter();

      expect(TomUIColors.resolveColor('zBrand'), isNull);
      expect(TomUIColors.colorExists('zBrand'), isFalse);
      expect(earlier.resolveColor('zBrand'), isNull);
    });

    test('TomUIIcons.reset() drops custom icon registrations', () {
      AllIconsAdapter.registerIcons({'zBrand': Icons.abc});
      final earlier = AllIconsAdapter();
      TomUIIcons.reset();
      TomUIIcons.adapter = AllIconsAdapter();

      expect(TomUIIcons.resolveIcon('zBrand'), isNull);
      expect(TomUIIcons.iconExists('zBrand'), isFalse);
      expect(earlier.resolveIcon('zBrand'), isNull);
      // The registry is module-wide, so the single-family adapters lose it too.
      expect(MaterialOnlyIconAdapter().resolveIcon('zBrand'), isNull);
      expect(CupertinoOnlyIconAdapter().resolveIcon('zBrand'), isNull);
    });

    test('reset() drops an override without disturbing the built-in', () {
      AllColorsAdapter.registerColors({'mRed': const Color(0xFF112233)});
      AllIconsAdapter.registerIcons({'mSave': Icons.delete});
      TomUIColors.reset();
      TomUIIcons.reset();
      TomUIColors.adapter = AllColorsAdapter();
      TomUIIcons.adapter = AllIconsAdapter();

      // Back to the generated tables, not to null and not to the override.
      expect(TomUIColors.resolveColor('mRed'), Colors.red);
      expect(TomUIIcons.resolveIcon('mSave'), Icons.save);
    });
  });

  // `adapter` reads as well as writes, and is nullable in both directions.
  // Both halves are pinned below: the read is what lets anything ask what is
  // installed, and writing `null` is what lets a caller put back "nothing was
  // installed" without going through `reset()`, which would drop every
  // registration along with the adapter.
  group('the installed adapter reads back', () {
    test('TomUIColors.adapter is null until one is installed', () {
      expect(TomUIColors.adapter, isNull);

      final adapter = AllColorsAdapter();
      TomUIColors.adapter = adapter;
      expect(TomUIColors.adapter, same(adapter));

      TomUIColors.reset();
      expect(TomUIColors.adapter, isNull);
    });

    test('TomUIIcons.adapter is null until one is installed', () {
      expect(TomUIIcons.adapter, isNull);

      final adapter = AllIconsAdapter();
      TomUIIcons.adapter = adapter;
      expect(TomUIIcons.adapter, same(adapter));

      TomUIIcons.reset();
      expect(TomUIIcons.adapter, isNull);
    });

    test('a narrow adapter can be installed and the wide one put back', () {
      final wide = AllColorsAdapter();
      TomUIColors.adapter = wide;
      final saved = TomUIColors.adapter;

      TomUIColors.adapter = MaterialOnlyColorAdapter();
      // Observable through resolution, not only through identity: the narrow
      // adapter really is the one answering.
      expect(TomUIColors.resolveColor('cSystemBlue'), isNull);

      TomUIColors.adapter = saved;
      expect(TomUIColors.adapter, same(wide));
      expect(TomUIColors.resolveColor('cSystemBlue'), isNotNull);
    });

    test(
      'a narrow icon adapter can be installed and the wide one put back',
      () {
        final wide = AllIconsAdapter();
        TomUIIcons.adapter = wide;
        final saved = TomUIIcons.adapter;

        TomUIIcons.adapter = CupertinoOnlyIconAdapter();
        expect(TomUIIcons.resolveIcon('mSave'), isNull);

        TomUIIcons.adapter = saved;
        expect(TomUIIcons.adapter, same(wide));
        expect(TomUIIcons.resolveIcon('mSave'), Icons.save);
      },
    );

    // The reason the setter accepts null. Restoring "nothing was installed"
    // through reset() would take the caller's registrations with it — so the
    // one branch a save/restore helper would otherwise need is also the one
    // that silently loses application state.
    test('restoring "nothing installed" keeps the registrations', () {
      AllColorsAdapter.registerColors({'zBrand': const Color(0xFF112233)});
      final saved = TomUIColors.adapter; // nothing installed yet

      TomUIColors.adapter = MaterialOnlyColorAdapter();
      TomUIColors.adapter = saved;

      expect(TomUIColors.adapter, isNull);
      TomUIColors.adapter = AllColorsAdapter();
      expect(TomUIColors.resolveColor('zBrand'), const Color(0xFF112233));
    });

    test('restoring "nothing installed" keeps icon registrations', () {
      AllIconsAdapter.registerIcons({'zBrand': Icons.abc});
      final saved = TomUIIcons.adapter;

      TomUIIcons.adapter = MaterialOnlyIconAdapter();
      TomUIIcons.adapter = saved;

      expect(TomUIIcons.adapter, isNull);
      TomUIIcons.adapter = AllIconsAdapter();
      expect(TomUIIcons.resolveIcon('zBrand'), Icons.abc);
    });
  });

  group('TomConfigProvider', () {
    test('throws before initialisation', () {
      expect(() => TomConfigProvider.current, throwsStateError);
    });

    test('exposes environment, platform and flags', () {
      TomConfigProvider.initialize(
        TomConfigProvider.create(
          environment: TomEnvironment.staging,
          platform: TomPlatform.desktop,
          flags: {'beta': true, 'limit': 10, 'name': 'x'},
        ),
      );
      final cfg = TomConfigProvider.current;
      expect(cfg.environment, TomEnvironment.staging);
      expect(cfg.platform, TomPlatform.desktop);
      expect(cfg.isEnabled('beta'), isTrue);
      expect(cfg.feature<int>('limit'), 10);
      expect(cfg.feature<String>('name'), 'x');
    });

    test('feature returns null on type mismatch or missing', () {
      TomConfigProvider.initialize(
        TomConfigProvider.create(
          environment: TomEnvironment.development,
          platform: TomPlatform.mobile,
          flags: {'limit': 10},
        ),
      );
      final cfg = TomConfigProvider.current;
      expect(cfg.feature<String>('limit'), isNull);
      expect(cfg.feature<int>('missing'), isNull);
    });

    // `isEnabled` has one rule spanning three axes, and the axes are pinned
    // together because the hazard is them disagreeing. The same flag reaches
    // an application as a `bool` from Dart, as `1` from YAML or JSON, and as
    // `'true'` or `'1'` from --dart-define or an environment variable, which
    // can carry neither of the other two. Which source it came through must
    // not change what it means.
    test('isEnabled: every spelling of on agrees', () {
      const on = <String, Object>{
        'boolean': true,
        'number': 1,
        'double': 1.0,
        'word': 'true',
        'shouty': 'TRUE',
        'mixed': 'True',
        'padded': '  true  ',
        'digit': '1',
        'paddedDigit': ' 1 ',
      };
      final cfg = _withFlags(on);
      for (final name in on.keys) {
        expect(cfg.isEnabled(name), isTrue, reason: 'flag "$name"');
      }
    });

    test('isEnabled: every spelling of off agrees, and so does absence', () {
      const off = <String, Object>{
        'boolean': false,
        'zero': 0,
        'zeroDouble': 0.0,
        'word': 'false',
        'shouty': 'FALSE',
        'empty': '',
      };
      final cfg = _withFlags(off);
      for (final name in off.keys) {
        expect(cfg.isEnabled(name), isFalse, reason: 'flag "$name"');
      }
      expect(cfg.isEnabled('neverSet'), isFalse);
    });

    // The tolerance is bounded on purpose. Case and surrounding space are
    // noise from the authoring source; a synonym is a different word, and
    // admitting one commits the module to a list of them that nobody agreed
    // on. It is the line AllColorsAdapter already draws — it folds case in
    // `#FFF` and `rgb(...)` syntax and still does not know `crimson`.
    test('isEnabled: the tolerance stops at spelling, not synonyms', () {
      const outside = <String, Object>{
        'yes': 'yes',
        'on': 'on',
        'y': 'y',
        'enabled': 'enabled',
        'typo': 'ture',
        'two': 2,
        'minusOne': -1,
        'list': <String>['true'],
      };
      final cfg = _withFlags(outside);
      for (final name in outside.keys) {
        expect(cfg.isEnabled(name), isFalse, reason: 'flag "$name"');
      }

      // Falsy is not the same as lost: a value outside the on/off vocabulary
      // is still readable, which is where anything richer than a flag lives.
      expect(cfg.feature<String>('yes'), 'yes');
      expect(cfg.feature<int>('two'), 2);
    });
  });

  group('authorization types', () {
    test('TomAuthState ordering and predicates', () {
      expect(TomAuthState.values, [
        TomAuthState.none,
        TomAuthState.disabled,
        TomAuthState.read,
        TomAuthState.full,
      ]);
      expect(TomAuthState.none.isVisible, isFalse);
      expect(TomAuthState.read.isVisible, isTrue);
      expect(TomAuthState.read.isInteractive, isFalse);
      expect(TomAuthState.full.isInteractive, isTrue);
      expect(TomAuthState.read.showsContent, isTrue);
    });
  });
}

/// Asserts the header of a generated resource table against its own contents.
///
/// Both tables are emitted by a script in `tool/` and must stay reproducible:
/// regenerating an unchanged SDK has to produce no diff, because that is the
/// only way to check a checked-in table is current — you regenerate and look
/// for one. So the header may state nothing the entries do not determine.
///
/// Both checks earn their place. The colour table's predecessor was
/// hand-authored and claimed "60+" Cupertino colours against 46; the icon
/// table's generator stamped a wall clock into every run, which made a
/// no-op regeneration a 10k-line diff and the table uncheckable.
///
/// [maps] pairs each header count label with the map that has to justify it;
/// the count named `Total` is checked against their sum.
void generatedTableHeaderTests({
  required String fileName,
  required String valueType,
  required Map<String, String> maps,
}) {
  group('$fileName header', () {
    final source = File('lib/src/resource_auth/$fileName').readAsStringSync();

    int declaredCount(String label) {
      final match = RegExp(
        '^// $label: (\\d+)\$',
        multiLine: true,
      ).firstMatch(source);
      expect(match, isNotNull, reason: 'no "$label:" line in the header');
      return int.parse(match!.group(1)!);
    }

    int entryCount(String mapName) {
      final start = source.indexOf(
        'static const Map<String, $valueType> $mapName',
      );
      expect(start, greaterThan(-1), reason: 'no $mapName map');
      final body = source.substring(start, source.indexOf('\n  };', start));
      return RegExp("^    '\\w+':", multiLine: true).allMatches(body).length;
    }

    test('states the counts the two maps actually hold', () {
      var total = 0;
      maps.forEach((label, mapName) {
        final count = entryCount(mapName);
        expect(declaredCount(label), count, reason: '$label count is stale');
        total += count;
      });
      expect(declaredCount('Total'), total);
    });

    test('records no generation timestamp', () {
      expect(source, isNot(contains('Generated on:')));
    });
  });
}

/// A provider carrying [flags], built but deliberately **not** installed.
///
/// `isEnabled` is a rule about a value, so the flag-vocabulary cases have no
/// use for the global singleton; going through it would only add teardown
/// that could fail for reasons the case is not about.
TomConfigProvider _withFlags(Map<String, Object> flags) =>
    TomConfigProvider.create(
      environment: TomEnvironment.development,
      platform: TomPlatform.mobile,
      flags: flags,
    );
