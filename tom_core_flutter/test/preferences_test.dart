import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'preferences_test.reflection.dart';

/// A reflected preference value, so the object round-trip is exercised through
/// the same reflection path an application's own preference class would take.
@tomReflector
class LayoutPreference {
  String density = 'comfortable';
  int columns = 2;
  bool showSidebar = true;
}

/// The device store an application would register on a desktop target.
///
/// Concrete `@TomComponent` classes are how an application binds an
/// implementation to [TomDevicePreferences]; the framework ships none, because
/// only the app knows where its machine-local state belongs. These two stand in
/// for that, so the four-tier bean selection is exercised against this
/// interface exactly as a real app exercises it.
@tomReflector
@TomComponent(TomDevicePreferences)
@platformMacos
class MacosDevicePreferences extends TomStoredDevicePreferences {
  MacosDevicePreferences() : super(TomMemoryDevicePreferenceStore());
}

/// The device store an application would register on the web.
@tomReflector
@TomComponent(TomDevicePreferences)
@platformWeb
class WebDevicePreferences extends TomStoredDevicePreferences {
  WebDevicePreferences() : super(TomMemoryDevicePreferenceStore());
}

/// The behaviour every backend must show, run against whichever one [build]
/// returns.
///
/// The whole promise of this module is that the call site does not change with
/// the backend, and a promise checked against one implementation is not
/// checked. So the suite is written once and instantiated per backend: if a
/// backend ever needed a different call, it would fail to compile here rather
/// than surprise an application on one platform.
void runSharedStoreTests(
  String backend,
  TomDevicePreferences Function() build,
) {
  group('$backend backend', () {
    test('answers null for a preference that has never been written', () async {
      final preferences = build();
      expect(await preferences.get<String>('device.unset'), isNull);
      expect(await preferences.read('device.unset'), isNull);
      expect(await preferences.all(), isEmpty);
    });

    test('round-trips every scalar type', () async {
      final preferences = build();
      await preferences.set('device.account', 'alex@example.com');
      await preferences.set('device.launches', 7);
      await preferences.set('device.scale', 1.25);
      await preferences.set('device.biometric', true);

      expect(
        await preferences.get<String>('device.account'),
        'alex@example.com',
      );
      expect(await preferences.get<int>('device.launches'), 7);
      expect(await preferences.get<double>('device.scale'), 1.25);
      expect(await preferences.get<bool>('device.biometric'), isTrue);
    });

    test('round-trips a DateTime as UTC', () async {
      final preferences = build();
      final local = DateTime(2026, 3, 14, 9, 26, 53);
      await preferences.set('device.lastSync', local);

      final restored = await preferences.get<DateTime>('device.lastSync');
      expect(restored, isNotNull);
      expect(
        restored!.isUtc,
        isTrue,
        reason: 'a preference instant must not carry a device offset',
      );
      expect(restored.isAtSameMomentAs(local), isTrue);
    });

    test('round-trips a reflected object', () async {
      final preferences = build();
      final original = LayoutPreference()
        ..density = 'compact'
        ..columns = 4
        ..showSidebar = false;
      final stored = await preferences.set('device.layout', original);
      expect(stored.valueType, 'LayoutPreference');

      final restored = await preferences.get<LayoutPreference>('device.layout');
      expect(restored, isNotNull);
      expect(
        identical(restored, original),
        isFalse,
        reason: 'the value must come back from storage, not from memory',
      );
      expect(restored!.density, 'compact');
      expect(restored.columns, 4);
      expect(restored.showSidebar, isFalse);
    });

    test('replaces rather than duplicates a key written twice', () async {
      final preferences = build();
      await preferences.set('device.theme', 'light');
      await preferences.set('device.theme', 'dark');

      expect(await preferences.get<String>('device.theme'), 'dark');
      expect(await preferences.all(), hasLength(1));
    });

    test('refuses a read of the wrong type instead of coercing', () async {
      final preferences = build();
      await preferences.set('device.launches', 7);

      await expectLater(
        preferences.get<String>('device.launches'),
        throwsA(
          isA<TomUserPreferenceCodecException>().having(
            (error) => error.key,
            'key',
            'preferences.decode.type_mismatch',
          ),
        ),
      );
    });

    test(
      'getOr answers the fallback only for an unwritten preference',
      () async {
        final preferences = build();
        expect(await preferences.getOr('device.theme', 'system'), 'system');

        await preferences.set('device.theme', 'dark');
        expect(await preferences.getOr('device.theme', 'system'), 'dark');
      },
    );

    test('getOr still throws on a type mismatch', () async {
      final preferences = build();
      await preferences.set('device.launches', 7);

      await expectLater(
        preferences.getOr('device.launches', 'never'),
        throwsA(isA<TomUserPreferenceCodecException>()),
      );
    });

    test('remove reports whether a preference was there', () async {
      final preferences = build();
      await preferences.set('device.theme', 'dark');

      expect(await preferences.remove('device.theme'), isTrue);
      expect(await preferences.remove('device.theme'), isFalse);
      expect(await preferences.get<String>('device.theme'), isNull);
    });

    test('clear empties the store', () async {
      final preferences = build();
      await preferences.set('device.theme', 'dark');
      await preferences.set('device.launches', 7);

      await preferences.clear();
      expect(await preferences.all(), isEmpty);
    });

    test(
      'getPreferred prefers the device value over the server value',
      () async {
        final preferences = build();
        await preferences.set(TomUserPreferenceKeys.theme, 'dark');

        var serverConsulted = false;
        final resolved = await preferences.getPreferred<String>(
          TomUserPreferenceKeys.theme,
          () async {
            serverConsulted = true;
            return 'light';
          },
        );

        expect(resolved, 'dark');
        expect(
          serverConsulted,
          isFalse,
          reason: 'a device that has the answer must not pay for a round trip',
        );
      },
    );

    test(
      'getPreferred falls back to the server value for an unwritten key',
      () async {
        final preferences = build();
        final resolved = await preferences.getPreferred<String>(
          TomUserPreferenceKeys.theme,
          () async => 'light',
        );
        expect(resolved, 'light');
      },
    );
  });
}

void main() {
  setUpAll(initializeReflection);

  late Directory temporaryDirectory;
  var storeIndex = 0;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'tom_device_preferences_',
    );
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
    TomBean.resetBeanContext();
    TomRuntime.reset();
  });

  // The same suite, twice: once against the store that persists nothing and
  // once against the store that writes a file. Neither the assertions nor the
  // calls differ, which is the module's contract.
  runSharedStoreTests(
    'memory',
    () => TomStoredDevicePreferences(TomMemoryDevicePreferenceStore()),
  );
  runSharedStoreTests(
    'file',
    // A fresh file per construction, inside the directory `tearDown` removes —
    // so a test never reads what a previous one wrote and nothing is left on
    // the machine afterwards.
    () => TomStoredDevicePreferences(
      TomPlatformDevicePreferenceStore(
        '${temporaryDirectory.path}/preferences_${++storeIndex}.json',
      ),
    ),
  );

  group('persistence across a restart', () {
    test('the file backend answers what a previous process wrote', () async {
      final path = '${temporaryDirectory.path}/preferences.json';

      // First "run": write, then drop every object that held the values.
      final first = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path),
      );
      await first.set('device.account', 'alex@example.com');
      await first.set('device.launches', 7);
      await first.set(
        'device.layout',
        LayoutPreference()
          ..density = 'compact'
          ..columns = 4,
      );

      // Second "run": nothing is shared but the path on disk.
      final second = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path),
      );
      expect(await second.get<String>('device.account'), 'alex@example.com');
      expect(await second.get<int>('device.launches'), 7);
      final layout = await second.get<LayoutPreference>('device.layout');
      expect(layout?.density, 'compact');
      expect(layout?.columns, 4);
    });

    test('the memory backend deliberately does not', () async {
      final store = TomMemoryDevicePreferenceStore();
      await TomStoredDevicePreferences(store).set('device.theme', 'dark');

      // A second store is a second process's worth of state — nothing carries
      // over, which is exactly why the memory backend is not a fallback for a
      // platform without a real one.
      final fresh = TomStoredDevicePreferences(
        TomMemoryDevicePreferenceStore(),
      );
      expect(await fresh.get<String>('device.theme'), isNull);
    });

    test('clearing the last preference leaves no file behind', () async {
      final path = '${temporaryDirectory.path}/preferences.json';
      final preferences = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path),
      );

      await preferences.set('device.theme', 'dark');
      expect(File(path).existsSync(), isTrue);

      await preferences.remove('device.theme');
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '"no file" and "empty document" must be one state',
      );
      expect(await preferences.all(), isEmpty);
    });
  });

  group('TomDevicePreferenceJson', () {
    test('round-trips a document', () {
      final written = DateTime.utc(2026, 3, 14, 9, 26, 53);
      final encoded = TomDevicePreferenceJson.encode([
        TomUserPreferenceDto(
          key: 'device.theme',
          valueType: 'String',
          value: '"dark"',
          updatedAt: written,
        ),
        TomUserPreferenceDto(
          key: 'device.launches',
          valueType: 'int',
          value: '7',
        ),
      ]);

      final decoded = TomDevicePreferenceJson.decode(encoded);
      expect(decoded, hasLength(2));
      expect(decoded.first.key, 'device.theme');
      expect(decoded.first.value, '"dark"');
      expect(decoded.first.updatedAt, written);
      expect(decoded.last.updatedAt, isNull);
    });

    test('treats blank content as an empty document', () {
      expect(TomDevicePreferenceJson.decode(''), isEmpty);
      expect(TomDevicePreferenceJson.decode('   \n'), isEmpty);
    });

    test('rejects content that is not a JSON array of objects', () {
      for (final content in ['{', '{"a": 1}', '[1, 2]']) {
        expect(
          () => TomDevicePreferenceJson.decode(content, source: 'store'),
          throwsA(
            isA<TomDevicePreferenceException>().having(
              (error) => error.key,
              'key',
              'device_preferences.store.invalid_content',
            ),
          ),
          reason: 'content: $content',
        );
      }
    });

    test('a corrupt file fails loudly rather than reading as empty', () async {
      final path = '${temporaryDirectory.path}/preferences.json';
      File(path).writeAsStringSync('not json at all');

      final preferences = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path),
      );
      await expectLater(
        preferences.all(),
        throwsA(isA<TomDevicePreferenceException>()),
        reason: 'a corrupt store that read as empty would be overwritten',
      );
    });
  });

  group('backend selection', () {
    /// Registers the platforms the two components are annotated for and
    /// activates [platform].
    void activate(TomPlatform platform) {
      // Bean selection resolves on both axes, so an environment has to be live
      // even for components that discriminate on platform alone.
      TomRuntime.addEnvironment(defaultTomEnvironment);
      TomRuntime.setCurrentEnvironment(defaultTomEnvironment.env);
      TomRuntime.addPlatform(platformMacos);
      TomRuntime.addPlatform(platformWeb);
      TomRuntime.setCurrentPlatform(platform);
      initializeBeanContext();
    }

    test('the macOS implementation is chosen on macOS', () {
      activate(platformMacos);
      expect(TomDevicePreferences.resolve(), isA<MacosDevicePreferences>());
    });

    test('the web implementation is chosen on the web', () {
      activate(platformWeb);
      expect(TomDevicePreferences.resolve(), isA<WebDevicePreferences>());
    });

    test('resolve answers null when nothing is registered', () {
      expect(TomDevicePreferences.resolve(), isNull);
    });

    test('an explicitly installed bean is used as-is', () {
      final installed = TomStoredDevicePreferences(
        TomMemoryDevicePreferenceStore(),
      );
      TomBean.withType(TomDevicePreferences, installed);
      expect(identical(TomDevicePreferences.resolve(), installed), isTrue);
    });
  });
}
