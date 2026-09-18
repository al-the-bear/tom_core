import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

// The neutral platform store is selected by conditional *export*, so on this
// target the barrel name resolves to the io variant. Importing the neutral
// source directly is what makes its documented failure testable here at all;
// the prefix keeps the two same-named classes apart.
import 'package:tom_core_flutter/src/tomclient/preferences/platform_device_preference_store_neutral.dart'
    as neutral_store;

import '../example/preferences/preferences_example.dart' as example;
import 'preferences_test.reflection.dart';
import 'support/conditional_export_variants.dart';
import 'support/exception_constructor_mirror.dart';

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

/// A backend that conforms to [TomDevicePreferenceStore] as documented, and
/// offers nothing beyond it.
///
/// All three shipped backends happen to hand out a list nobody else holds —
/// [TomMemoryDevicePreferenceStore] copies on every `read()`, and the file and
/// web stores decode a fresh one. That tolerance is not part of the contract,
/// and the natural way to write a cache-backed store — wrapping
/// `shared_preferences`, a keychain, an encrypted blob kept in memory — does
/// not offer it. This store is the strictest conforming implementation: `read()`
/// returns the store's own list, unmodifiable and the same instance every time,
/// and `write` keeps a copy rather than the caller's list.
///
/// Running the shared suite against it is what turns "the caller must not
/// modify what `read()` returns" from a sentence in a dartdoc into something
/// the package cannot quietly break.
class UnmodifiableDevicePreferenceStore extends TomDevicePreferenceStore {
  List<TomUserPreferenceDto> _values = List.unmodifiable(
    const <TomUserPreferenceDto>[],
  );

  @override
  Future<List<TomUserPreferenceDto>> read() async => _values;

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    // Copies, so the store never depends on a list the caller may still hold —
    // the write half of the same ownership rule. `clear()` relies on this: it
    // passes `const []`, which no store could retain and later replace.
    _values = List.unmodifiable(values);
  }
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

    test('all() answers in key order, not in the order written', () async {
      // Written in an order that is neither the answer nor its reverse, so a
      // store that simply echoed insertion — which is what this used to do —
      // cannot pass by coincidence.
      final preferences = build();
      await preferences.set('device.launches', 7);
      await preferences.set('device.theme', 'dark');
      await preferences.set('device.account', 'alex@example.com');
      await preferences.set('device.biometric', true);

      expect((await preferences.all()).map((stored) => stored.key), [
        'device.account',
        'device.biometric',
        'device.launches',
        'device.theme',
      ]);
    });

    test('rewriting a value does not move it in the list', () async {
      // Why the key is the ordering field and not `updatedAt`: a preference a
      // user just changed must stay where the reader last saw it.
      final preferences = build();
      await preferences.set('device.account', 'alex@example.com');
      await preferences.set('device.theme', 'dark');
      await preferences.set('device.zoom', 1.25);

      await preferences.set('device.account', 'sam@example.com');

      expect((await preferences.all()).map((stored) => stored.key), [
        'device.account',
        'device.theme',
        'device.zoom',
      ]);
    });

    test('key order is by code unit, so Theme precedes theme', () async {
      // The clause that decides what "ascending" means. It matters because
      // `TomUserPreferenceKeys` admits both cases, and because it is exactly
      // where a store backed by a case-insensitive SQL collation would answer
      // something else — see TomUserPreferencesApiService.listPreferences.
      final preferences = build();
      await preferences.set('device.theme', 'dark');
      await preferences.set('device.Theme', 'light');

      expect((await preferences.all()).map((stored) => stored.key), [
        'device.Theme',
        'device.theme',
      ]);
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

    test(
      'getPreferred answers from the device when the server has none',
      () async {
        final preferences = build();
        await preferences.set(TomUserPreferenceKeys.theme, 'dark');

        final resolved = await preferences.getPreferred<String>(
          TomUserPreferenceKeys.theme,
          () async => null,
        );

        expect(resolved, 'dark');
      },
    );

    test(
      'getPreferred answers null when neither store holds the key',
      () async {
        final preferences = build();

        final resolved = await preferences.getPreferred<String>(
          TomUserPreferenceKeys.theme,
          () async => null,
        );

        expect(resolved, isNull);
      },
    );

    test('an illegal key is refused, and nothing is stored under it', () async {
      // A device store never builds a URL, so nothing *here* would break
      // under a looser rule — but the precedence above only means
      // anything if both stores answer to the same names, and a preference
      // that later moves to the server must already carry a key the server
      // would accept. One vocabulary, one rule, both stores.
      final preferences = build();

      for (final key in <String>['a/b', '', 'has space', '..', '1key']) {
        await expectLater(
          preferences.set(key, 'dark'),
          throwsA(isA<TomUserPreferenceKeyException>()),
          reason: key,
        );
        await expectLater(
          preferences.read(key),
          throwsA(isA<TomUserPreferenceKeyException>()),
          reason: key,
        );
        await expectLater(
          preferences.remove(key),
          throwsA(isA<TomUserPreferenceKeyException>()),
          reason: key,
        );
      }

      // The refusal happens before the read-modify-write cycle, so a rejected
      // write leaves no half-made entry behind.
      expect(await preferences.all(), isEmpty);
    });
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

  // The same suite, three times: against the store that persists nothing, the
  // store that writes a file, and the strictest implementation the contract
  // permits. Neither the assertions nor the calls differ, which is the module's
  // contract.
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
  runSharedStoreTests(
    // The two above both hand out a list nobody else holds, so between them
    // they cannot tell whether this package needs that. This one hands out its
    // own unmodifiable list, which is all the contract promises — so it fails
    // every operation that treats `read()`'s result as scratch space.
    'unmodifiable-read',
    () => TomStoredDevicePreferences(UnmodifiableDevicePreferenceStore()),
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

  group('scope', () {
    // The module's documented position is that a store belongs to its
    // `location`, not to a user, and that an application with two accounts on
    // one machine keeps them apart by giving each its own location. That makes
    // location isolation the property applications are told to rely on — so it
    // is asserted here rather than assumed from the backend's shape.

    test('two locations are two independent key spaces', () async {
      final alex = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(
          '${temporaryDirectory.path}/preferences/alex.json',
        ),
      );
      final robin = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(
          '${temporaryDirectory.path}/preferences/robin.json',
        ),
      );

      await alex.set('device.biometricUnlock', true);
      await alex.set('device.lastAccount', 'alex@example.com');

      // Robin's store must not answer what Alex wrote — not with Alex's value,
      // and not with a value at all.
      expect(await robin.get<bool>('device.biometricUnlock'), isNull);
      expect(await robin.all(), isEmpty);

      // And writing the same key on both keeps two values, rather than the
      // later write winning over the earlier one.
      await robin.set('device.biometricUnlock', false);
      expect(await alex.get<bool>('device.biometricUnlock'), isTrue);
      expect(await robin.get<bool>('device.biometricUnlock'), isFalse);
    });

    test('clearing one location leaves the other untouched', () async {
      // Sign-out on one account must not wipe the other's device settings —
      // `clear` is documented as the sign-out operation, so this is the case in
      // which a shared location would do visible damage.
      final alex = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(
          '${temporaryDirectory.path}/preferences/alex.json',
        ),
      );
      final robin = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(
          '${temporaryDirectory.path}/preferences/robin.json',
        ),
      );
      await alex.set('device.theme', 'dark');
      await robin.set('device.theme', 'light');

      await alex.clear();

      expect(await alex.all(), isEmpty);
      expect(await robin.get<String>('device.theme'), 'light');
    });

    test('one location is one key space, however often it is opened', () async {
      // The other half of the same rule, and the reason a shared install that
      // does *not* qualify its location shares its preferences: two stores over
      // one location are one store. A backend that isolated per instance would
      // make the documented failure mode impossible — and the persistence
      // guarantee with it.
      final location = '${temporaryDirectory.path}/shared.json';
      final first = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(location),
      );
      final second = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(location),
      );

      await first.set('device.lastAccount', 'alex@example.com');
      expect(
        await second.get<String>('device.lastAccount'),
        'alex@example.com',
        reason: 'the location, not the instance, is what scopes a store',
      );
    });
  });

  group('the scope rule reaches the documents a reader starts from', () {
    // The behaviour above is settled and correct; the exposure is in telling
    // anyone about it. Let the rule live only in the module `readme.md`, beside
    // the source, with no Scope section in `doc/preferences.md` and `location`
    // described in the API summary as a path and nothing more, and a reader who
    // follows the published documentation rather than the source tree builds a
    // multi-account application on a single store and hears about it from a
    // user.
    //
    // Documentation is prose and must stay free to be rewritten, so these
    // check for the two load-bearing *facts* rather than any sentence: that
    // the per-account pattern is shown, and that the constraint making it work
    // is stated. Anything that still says both has kept the rule; anything
    // that has dropped either has lost it.
    const documents = <String>[
      'lib/src/tomclient/preferences/readme.md',
      'doc/preferences.md',
      'doc/api_reference/api_summary_preferences.md',
    ];

    test('every document that explains location shows the per-account '
        'pattern', () {
      final silent = [
        for (final document in documents)
          if (!File(document).readAsStringSync().contains(r'$accountId'))
            document,
      ];
      expect(
        silent,
        isEmpty,
        reason:
            'These documents explain `location` without showing that it is '
            'what separates two accounts, which is the one thing an '
            'application can get wrong here without noticing: $silent',
      );
    });

    test('every document showing the pattern states what the account segment '
        'must be', () {
      // A per-account location built from a display name looks right and
      // breaks on the first profile edit, stranding every preference written
      // under the old spelling. Showing the pattern without this constraint is
      // worse than not showing it.
      final unqualified = [
        for (final document in documents)
          if (!File(document).readAsStringSync().contains('display name'))
            document,
      ];
      expect(
        unqualified,
        isEmpty,
        reason:
            'These documents show a per-account location without saying '
            'that the segment must be single and stable: $unqualified',
      );
    });

    test('doc/preferences.md carries the rule as a section of its own', () {
      // Not merely a sentence somewhere: a reader navigating by the table of
      // contents has to be able to find it. That the section is *listed* is
      // guarded generally, for every module document, in
      // `documentation_links_test.dart`.
      final headings = RegExp(r'^## (.+)$', multiLine: true)
          .allMatches(File('doc/preferences.md').readAsStringSync())
          .map((m) => m.group(1)!)
          .toList();
      expect(
        headings.where((h) => h.startsWith('Scope')),
        hasLength(1),
        reason:
            'doc/preferences.md must state the scope rule under a heading '
            'of its own; its headings are $headings',
      );
    });
  });

  group('the store contract states who owns each list', () {
    // The rule is only useful to the person writing a backend, and that person
    // may arrive at any of these four. The behaviour is pinned by the
    // 'unmodifiable-read' backend above; this pins that it is *stated*, because
    // an implementer who is not told may reasonably write a store that returns
    // its own list and then be surprised by a package that mutates it.
    const artefacts = <String>[
      'lib/src/tomclient/preferences/device_preference_store.dart',
      'lib/src/tomclient/preferences/readme.md',
      'doc/preferences.md',
      'doc/api_reference/api_summary_preferences.md',
    ];

    /// [file]'s text with emphasis and code markers removed, so a document is
    /// free to bold or quote any part of the rule without breaking the check.
    String plainTextOf(String file) =>
        File(file).readAsStringSync().replaceAll(RegExp(r'[*`\[\]]'), '');

    test('every artefact says the list read() returns belongs to the store', () {
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains('belongs to the store'),
          reason:
              '$artefact does not say who owns the list read() returns, '
              'which is what tells a backend author they need no defensive copy '
              'and tells a caller they may not modify it',
        );
      }
    });

    test(
      'every artefact says the list given to write() belongs to the caller',
      () {
        // The half that is easy to leave out, because every shipped backend
        // copies anyway. `clear()` is what makes it real: it passes `const []`,
        // so a store that modified or retained its argument would fail on the
        // module's own call.
        for (final artefact in artefacts) {
          expect(
            plainTextOf(artefact),
            contains('belongs to the caller'),
            reason:
                '$artefact states only half of the ownership rule; a half '
                'rule implies the other side behaves conventionally',
          );
        }
      },
    );
  });

  group('both faces of the store state one order', () {
    // The two `all()`s are the same surface with two backings, so a reader who
    // learns the order from whichever artefact they opened must learn the same
    // order. Behaviour is pinned above; this pins that it is *said*, in each
    // place a reader could start from.
    const artefacts = <String>[
      'lib/src/tomclient/preferences/device_preferences.dart',
      'lib/src/tomclient/preferences/user_preferences_client.dart',
      'lib/src/tomclient/preferences/readme.md',
      'doc/preferences.md',
      'doc/api_reference/api_summary_preferences.md',
    ];

    String plainTextOf(String file) =>
        File(file).readAsStringSync().replaceAll(RegExp(r'[*`\[\]]'), '');

    test('every artefact names the order all() answers in', () {
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          contains('ordered by key'),
          reason:
              '$artefact does not say what order all() answers in, so a reader '
              'starting there would take the sequence they happened to observe '
              'for the contract',
        );
      }
    });

    test('no artefact still describes the answer as storage order', () {
      // The tempting wrong phrase, guarded because it is not obviously wrong: a
      // JSON array does have an order, so "storage order" reads like a
      // guarantee while naming nothing more than whichever entry `set` appended
      // first — which no other backend owes and no caller can rely on.
      for (final artefact in artefacts) {
        expect(
          plainTextOf(artefact),
          isNot(contains('storage order')),
          reason:
              '$artefact still offers storage order as the contract, which the '
              'device store no longer answers in and the account store never '
              'could',
        );
      }
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

    // The document is meant to move between devices, so an updatedAt with no
    // zone would be read as the *importing* device's local time — silently, and
    // differently on each one.
    test('rejects an updatedAt that names no time zone', () {
      const content =
          '[{"key":"device.theme","valueType":"String",'
          '"value":"\\"dark\\"","updatedAt":"2026-03-14T09:26:53"}]';

      expect(
        () => TomDevicePreferenceJson.decode(content, source: 'store'),
        throwsA(
          isA<TomDevicePreferenceException>().having(
            (error) => error.key,
            'key',
            'device_preferences.store.invalid_content',
          ),
        ),
      );
    });

    test('accepts an updatedAt written with an explicit offset', () {
      const content =
          '[{"key":"device.theme","valueType":"String",'
          '"value":"\\"dark\\"","updatedAt":"2026-03-14T10:26:53+01:00"}]';

      expect(
        TomDevicePreferenceJson.decode(content).single.updatedAt,
        DateTime.utc(2026, 3, 14, 9, 26, 53),
      );
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

  group('a store that names its owner refuses another owner\'s document', () {
    // The separation between two accounts on one device is by construction: an
    // application gives each its own store `location`. Nothing could tell a
    // correct construction from a wrong one — the wrong install simply served
    // the previous user's last-used account and biometric flag to the current
    // one, on a screen that looked entirely normal.
    //
    // The owner marker does not replace the location; it makes getting the
    // location wrong loud.
    final dto = TomUserPreferenceDto(
      key: 'device.lastAccount',
      valueType: 'String',
      value: '"alex"',
    );

    test('a document written for one owner reads back for that owner', () {
      final written = TomDevicePreferenceJson.encode([dto], owner: 'alex');

      final read = TomDevicePreferenceJson.decode(written, owner: 'alex');

      expect(read, hasLength(1));
      expect(read.single.key, 'device.lastAccount');
    });

    test('and is refused for a different one', () {
      final written = TomDevicePreferenceJson.encode([dto], owner: 'alex');

      expect(
        () => TomDevicePreferenceJson.decode(written, owner: 'bo'),
        throwsA(
          isA<TomDevicePreferenceException>()
              .having(
                (error) => error.key,
                'key',
                'device_preferences.store.wrong_owner',
              )
              .having(
                (error) => error.parameters,
                'parameters',
                allOf(
                  containsPair('storedOwner', 'alex'),
                  containsPair('expectedOwner', 'bo'),
                ),
              ),
        ),
      );
    });

    test('absent is a value: an owned document is refused by a bare read', () {
      // The direction a lenient rule would wave through, and the one that is
      // the leak: a store with no owner reading a document that has one.
      final written = TomDevicePreferenceJson.encode([dto], owner: 'alex');

      expect(
        () => TomDevicePreferenceJson.decode(written),
        throwsA(
          isA<TomDevicePreferenceException>().having(
            (error) => error.key,
            'key',
            'device_preferences.store.wrong_owner',
          ),
        ),
      );
    });

    test('and so is the reverse: an unowned document under an owner', () {
      // An unowned document was written by a build that did not separate
      // accounts, so it could belong to anyone. One rule with no exemptions is
      // the only one a reader can hold.
      final written = TomDevicePreferenceJson.encode([dto]);

      expect(
        () => TomDevicePreferenceJson.decode(written, owner: 'alex'),
        throwsA(
          isA<TomDevicePreferenceException>().having(
            (error) => error.key,
            'key',
            'device_preferences.store.wrong_owner',
          ),
        ),
      );
    });

    test('an unowned document still reads bare, unchanged', () {
      // The interchange shape is untouched: an application that never names an
      // owner writes and reads exactly the array the server's list endpoint
      // answers.
      final written = TomDevicePreferenceJson.encode([dto]);

      expect(written.startsWith('['), isTrue);
      expect(TomDevicePreferenceJson.decode(written), hasLength(1));
    });

    test('the owned shape carries the array under `preferences`', () {
      final written = TomDevicePreferenceJson.encode([dto], owner: 'alex');
      final document = jsonDecode(written) as Map<String, Object?>;

      expect(document['owner'], 'alex');
      expect(document['preferences'], isA<List<Object?>>());
    });

    test('the file backend refuses the other account end to end', () async {
      // Through the store rather than the codec, because the codec is not what
      // an application holds. The file is written by one account's store and
      // read by another's — the mistake this exists to catch, with both halves
      // pointed at one location.
      final path = '${temporaryDirectory.path}/shared_preferences.json';
      final alex = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path, owner: 'alex'),
      );
      await alex.set<String>('device.lastAccount', 'alex');

      final bo = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path, owner: 'bo'),
      );

      await expectLater(
        bo.all(),
        throwsA(
          isA<TomDevicePreferenceException>().having(
            (error) => error.key,
            'key',
            'device_preferences.store.wrong_owner',
          ),
        ),
      );
    });

    test('and serves the right account its own document', () async {
      // The other arm, so the refusal cannot be read as "owners break reads".
      final path = '${temporaryDirectory.path}/owned_preferences.json';
      final alex = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path, owner: 'alex'),
      );
      await alex.set<String>('device.lastAccount', 'alex');

      final again = TomStoredDevicePreferences(
        TomPlatformDevicePreferenceStore(path, owner: 'alex'),
      );

      expect(await again.get<String>('device.lastAccount'), 'alex');
    });
  });

  group('both faces answer with the same kind of list', () {
    // The module's argument for its shape is that the two stores "carry the
    // same method set, which is what lets a preference *move* between them
    // without a call site changing". The call site that move produces is
    // exactly the one holding both results at once — so a difference between
    // them is met precisely where the symmetry was supposed to pay off, and it
    // is discoverable only by trying it.
    test('the device store answers an unmodifiable list', () async {
      final preferences = TomStoredDevicePreferences(
        TomMemoryDevicePreferenceStore(),
      );
      await preferences.set<String>('tom.theme', 'dark');

      final all = await preferences.all();

      expect(all, hasLength(1));
      expect(
        () => all.add(
          TomUserPreferenceDto(key: 'k', valueType: 'String', value: '"v"'),
        ),
        throwsUnsupportedError,
      );
    });

    test('and so does the account client', () async {
      final transport = _ScriptedTransport();
      transport.answer(body: '[${_dtoBody('tom.theme', 'dark')}]');
      final client = TomUserPreferencesClient(
        baseUri: Uri.parse('https://api.example.com'),
        channel: TomServerChannel(
          'api.example.com',
          443,
          clientFactory: transport,
        ),
      );
      addTearDown(client.close);

      final all = await client.all();

      expect(all, hasLength(1));
      expect(
        () => all.add(
          TomUserPreferenceDto(key: 'k', valueType: 'String', value: '"v"'),
        ),
        throwsUnsupportedError,
        reason:
            'a decoded response is a snapshot: adding to it would change '
            'nothing on the server',
      );
    });

    test('the contract face cannot differ from the store face', () async {
      // `all()` *is* `listPreferences()`, so a caller reaching the client
      // through `TomUserPreferencesApiService` gets the same promise. Asserted
      // rather than left to the one-line forward, because the forward is
      // exactly the kind of thing a later change replaces with a second body.
      final transport = _ScriptedTransport();
      transport.answer(body: '[${_dtoBody('tom.theme', 'dark')}]');
      final TomUserPreferencesApiService client = TomUserPreferencesClient(
        baseUri: Uri.parse('https://api.example.com'),
        channel: TomServerChannel(
          'api.example.com',
          443,
          clientFactory: transport,
        ),
      );
      addTearDown((client as TomUserPreferencesClient).close);

      final listed = await client.listPreferences();

      expect(
        () => listed.add(
          TomUserPreferenceDto(key: 'k', valueType: 'String', value: '"v"'),
        ),
        throwsUnsupportedError,
      );
    });

    test('an empty answer is unmodifiable too', () async {
      // The branch a `List.unmodifiable` around a literal is easy to get wrong
      // by short-circuiting the empty case to `const []` — which is right — or
      // to `[]`, which is not.
      final preferences = TomStoredDevicePreferences(
        TomMemoryDevicePreferenceStore(),
      );

      final all = await preferences.all();

      expect(all, isEmpty);
      expect(
        () => all.add(
          TomUserPreferenceDto(key: 'k', valueType: 'String', value: '"v"'),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('TomUserPreferencesClient', () {
    late _ScriptedTransport transport;

    /// A client whose every call is answered by [transport].
    TomUserPreferencesClient build({
      Map<String, String> headers = const {},
      Map<String, String> Function()? headerProvider,
    }) => TomUserPreferencesClient(
      baseUri: Uri.parse('https://api.example.com'),
      channel: TomServerChannel(
        'api.example.com',
        443,
        clientFactory: transport,
      ),
      headers: headers,
      headerProvider: headerProvider,
    );

    setUp(() => transport = _ScriptedTransport());

    group('addressing', () {
      // Each endpoint's method and URI come from the contract, so what is
      // asserted here is that the *declaration* is what reaches the socket — a
      // client that spelled the routes itself would agree with the server only
      // by inspection, which is the whole reason this class exists.
      test('all() issues the list endpoint', () async {
        transport.answer(body: '[]');
        await build().all();

        expect(transport.lastMethod, 'GET');
        expect(
          transport.lastUrl.toString(),
          'https://api.example.com/preferences',
        );
      });

      test(
        'read() issues the read endpoint with the key in the path',
        () async {
          transport.answer(body: _dtoBody('tom.theme', 'dark'));
          await build().read(TomUserPreferenceKeys.theme);

          expect(transport.lastMethod, 'GET');
          expect(
            transport.lastUrl.toString(),
            'https://api.example.com/preferences/tom.theme',
          );
        },
      );

      test('set() issues the write endpoint with the encoded value', () async {
        transport.answer(body: _dtoBody('tom.theme', 'dark'));
        await build().set(TomUserPreferenceKeys.theme, 'dark');

        expect(transport.lastMethod, 'PUT');
        expect(
          transport.lastUrl.toString(),
          'https://api.example.com/preferences',
        );
        // The body carries the codec's encoding, not the raw value: the type
        // name is what lets the server reject a mismatched write and what lets
        // a later read come back typed.
        final sent = jsonDecode(transport.lastBody!) as Map<String, Object?>;
        expect(sent['key'], 'tom.theme');
        expect(sent['valueType'], 'String');
        expect(sent['value'], '"dark"');
      });

      test('a write states its key once, in the body', () async {
        // The write URI carries no `{key}` capture, so there is no second
        // place for the key to be stated and nothing for the body to disagree
        // with. Whichever key the request names is the key that is written —
        // unlike read and delete, whose key is addressed by the path.
        transport.answer(body: _dtoBody('tom.language', 'de'));
        await build().writePreference(
          TomUserPreferenceWriteRequest(
            key: 'tom.language',
            valueType: 'String',
            value: '"de"',
          ),
        );

        expect(transport.lastMethod, 'PUT');
        expect(
          transport.lastUrl.toString(),
          'https://api.example.com/preferences',
        );
        expect(transport.lastUrl.pathSegments, ['preferences']);
        expect(transport.lastUrl.query, isEmpty);
        final sent = jsonDecode(transport.lastBody!) as Map<String, Object?>;
        expect(sent['key'], 'tom.language');
      });

      test('remove() issues the delete endpoint', () async {
        transport.answer(body: '');
        await build().remove(TomUserPreferenceKeys.theme);

        expect(transport.lastMethod, 'DELETE');
        expect(
          transport.lastUrl.toString(),
          'https://api.example.com/preferences/tom.theme',
        );
      });

      test('a key needing escaping never reaches the socket', () async {
        // A key that would have to be escaped to be sent is refused outright,
        // so there is no escaped request to reason about. Escaping it is not a
        // usable alternative: `%2F` is not a settled outcome — much HTTP
        // infrastructure rejects it and some normalises it back to `/`, at
        // which point the request addresses a two-segment path the API never
        // declared.
        final client = build();

        expect(
          () => client.remove('tom/theme'),
          throwsA(
            isA<TomUserPreferenceKeyException>().having(
              (error) => error.key,
              'key',
              'preferences.key.invalid',
            ),
          ),
        );
        expect(
          transport.callCount,
          0,
          reason: 'an illegal key is refused before a request is built',
        );
      });

      test('the empty key is refused rather than sent at the list URI', () {
        // The empty key resolves to `/preferences` — the *list* endpoint — so
        // an unset TomUserPreferenceKeyRequest would have sent a DELETE at the
        // whole collection. It is also the default that request produces, which
        // makes it the bad key most likely to actually happen.
        final client = build();

        expect(
          () => client.deletePreference(TomUserPreferenceKeyRequest()),
          throwsA(isA<TomUserPreferenceKeyException>()),
        );
        expect(transport.callCount, 0);
      });

      test('read and write refuse an illegal key too', () {
        // All three key-taking calls, not just the delete. Read and delete put
        // the key in the path, and write puts it in the body — but the key
        // rules are the store's, not the URI's, so a rule enforced on one call
        // is a rule with two ways past.
        final client = build();

        expect(
          () => client.read('a b'),
          throwsA(isA<TomUserPreferenceKeyException>()),
        );
        expect(
          () => client.set('1key', 'dark'),
          throwsA(isA<TomUserPreferenceKeyException>()),
        );
        expect(transport.callCount, 0);
      });
    });

    group('credentials', () {
      // A preferences call is always made *as* somebody — the endpoints answer
      // for the calling principal — so which credential reaches the socket is
      // part of this client's contract, not a transport detail. What these
      // pin is that exactly one arrives.
      final jwt = _bearerJwt({'username': 'dana', 'userId': 3});

      tearDown(TomBearerAuthentication.clearTokens);

      test('sends the signed-in bearer token by default', () async {
        TomBearerAuthentication.setTokens(jwt, jwt, false);
        transport.answer(body: '[]');
        await build().all();

        expect(transport.lastHeaders['authorization'], 'Bearer $jwt');
      });

      test('sends no Authorization at all when nobody has signed in', () async {
        // An absent credential is a clean 401; "Bearer null" is the same
        // rejection dressed as a parse failure, and a deployment debugging the
        // second one is chasing the wrong bug.
        TomBearerAuthentication.clearTokens();
        transport.answer(body: '[]');
        await build().all();

        expect(transport.lastHeaders.containsKey('authorization'), isFalse);
      });

      test('a caller-supplied Authorization suppresses the bearer', () async {
        // The channel writes the bearer *after* the spec headers, so without
        // suppression the constructor's documented promise would be silently
        // inverted — the caller's credential overwritten by the global one.
        TomBearerAuthentication.setTokens(jwt, jwt, false);
        transport.answer(body: '[]');
        await build(headers: {'Authorization': 'Basic abc'}).all();

        expect(transport.lastHeaders['authorization'], 'Basic abc');
      });

      test('a per-request provider header suppresses it too', () async {
        // The provider is the seam for a credential that rotates, so it must
        // win for the same reason a constructor header does.
        TomBearerAuthentication.setTokens(jwt, jwt, false);
        transport.answer(body: '[]');
        await build(headerProvider: () => {'Authorization': 'Basic xyz'}).all();

        expect(transport.lastHeaders['authorization'], 'Basic xyz');
      });

      test('suppression does not depend on how the header is cased', () async {
        // HTTP header names are case-insensitive, so a caller who wrote
        // `authorization` meant the same header. Matching only the capitalised
        // spelling would put two credentials on one request.
        TomBearerAuthentication.setTokens(jwt, jwt, false);
        transport.answer(body: '[]');
        await build(headers: {'authorization': 'Basic abc'}).all();

        expect(transport.lastHeaders['authorization'], 'Basic abc');
      });
    });

    group('reading', () {
      test('decodes every scalar type through the codec', () async {
        transport.answer(body: _dtoBody('tom.theme', 'dark'));
        expect(await build().get<String>('tom.theme'), 'dark');

        transport.answer(body: _dtoBody('app.launches', 7));
        expect(await build().get<int>('app.launches'), 7);

        transport.answer(body: _dtoBody('app.scale', 1.25));
        expect(await build().get<double>('app.scale'), 1.25);

        transport.answer(body: _dtoBody('app.beta', true));
        expect(await build().get<bool>('app.beta'), isTrue);
      });

      test('decodes a reflected object', () async {
        final stored = LayoutPreference()
          ..density = 'compact'
          ..columns = 4
          ..showSidebar = false;
        transport.answer(body: _dtoBody('app.layout', stored));

        final restored = await build().get<LayoutPreference>('app.layout');

        expect(restored, isNotNull);
        expect(restored!.density, 'compact');
        expect(restored.columns, 4);
        expect(restored.showSidebar, isFalse);
      });

      test(
        'answers null for a preference the server has never stored',
        () async {
          // The server distinguishes a miss from a fault with a 404 carrying
          // the error envelope (`TomUserPreferencesErrorHandler`); reading that
          // as `null` is what makes an unset preference an ordinary state
          // rather than an error. The body is spelled out literally here, once,
          // so the wire value is pinned and not only the constant naming it.
          transport.answer(
            statusCode: 404,
            body: '{"errorKey":"preferences.not_found"}',
          );
          expect(await build().get<String>('tom.theme'), isNull);

          transport.answer(statusCode: 404, body: _absentBody);
          expect(await build().read('tom.theme'), isNull);
        },
      );

      test(
        'getOr answers the fallback for a preference that is not there',
        () async {
          transport.answer(statusCode: 404, body: _absentBody);
          expect(await build().getOr<String>('tom.theme', 'light'), 'light');
        },
      );

      test('getOr still throws when the stored type disagrees', () async {
        // An unwritten preference is a state a default answers; a preference
        // stored as the wrong type is a bug, and answering the fallback would
        // hide it. Same rule as the device store.
        transport.answer(body: _dtoBody('app.launches', 7));

        expect(
          build().getOr<String>('app.launches', 'light'),
          throwsA(isA<TomUserPreferenceCodecException>()),
        );
      });

      test('a type mismatch surfaces the codec exception', () async {
        transport.answer(body: _dtoBody('app.launches', 7));

        expect(
          build().get<String>('app.launches'),
          throwsA(
            isA<TomUserPreferenceCodecException>().having(
              (error) => error.key,
              'key',
              'preferences.decode.type_mismatch',
            ),
          ),
        );
      });

      test('all() decodes the array the list endpoint answers', () async {
        transport.answer(
          body:
              '[${_dtoBody('tom.theme', 'dark')},'
              '${_dtoBody('app.launches', 7)}]',
        );

        final stored = await build().all();

        expect(stored, hasLength(2));
        expect(stored.first.key, 'tom.theme');
        expect(stored.first.value, '"dark"');
        expect(stored.last.valueType, 'int');
      });

      test('all() forwards the order the server answered in', () async {
        // The account store's half of the shared contract. The server orders by
        // key off an index that already covers it, so the sequence the socket
        // carries is the sequence the caller is owed — and this client's job is
        // not to alter it.
        transport.answer(
          body:
              '[${_dtoBody('app.launches', 7)},'
              '${_dtoBody('tom.language', 'de')},'
              '${_dtoBody('tom.theme', 'dark')}]',
        );

        expect((await build().all()).map((stored) => stored.key), [
          'app.launches',
          'tom.language',
          'tom.theme',
        ]);
      });

      test(
        'all() does not re-sort a server that answered out of order',
        () async {
          // Deliberate, and pinned because it is the kind of "harmless"
          // defensive sort a later reader adds without noticing what it costs:
          // it would hide the only symptom by which a store breaking the
          // ordering contract could be caught, and it would pay for a sort on
          // every call to do it.
          transport.answer(
            body:
                '[${_dtoBody('tom.theme', 'dark')},'
                '${_dtoBody('app.launches', 7)}]',
          );

          expect((await build().all()).map((stored) => stored.key), [
            'tom.theme',
            'app.launches',
          ]);
        },
      );
    });

    group('failures', () {
      test(
        'a rejected call fails loudly rather than reading as absent',
        () async {
          // A 500 is the server saying it is broken. Answering `null` here would
          // let an application paper a broken deployment over with a default and
          // never learn that its user's preferences are unreachable.
          transport.answer(statusCode: 500, body: 'Internal server error');

          expect(
            build().get<String>('tom.theme'),
            throwsA(
              isA<TomUserPreferencesClientException>().having(
                (error) => error.key,
                'key',
                'preferences.client.rejected',
              ),
            ),
          );
        },
      );

      test(
        'readPreference throws for a miss, because its result is not nullable',
        () async {
          // The contract face keeps the wire's shape — `TomUserPreferenceDto`,
          // not `TomUserPreferenceDto?` — so the miss has to be an error here.
          // The `null` lives on the store face (`read` / `get`) instead.
          transport.answer(statusCode: 404, body: _absentBody);

          expect(
            build().readPreference(
              TomUserPreferenceKeyRequest(key: 'tom.theme'),
            ),
            throwsA(
              isA<TomUserPreferencesClientException>().having(
                (error) => error.key,
                'key',
                'preferences.client.not_found',
              ),
            ),
          );
        },
      );

      test('a bare 404 is a refusal, not absence', () async {
        // The endpoint pipeline answers a denied or unauthenticated call with a
        // bare `404`, so that a refusal looks like a route that does not
        // exist. Reading that as "not set" would hand a signed-out user the
        // defaults and never tell anyone they were refused, so only the
        // envelope carrying the contract's absence key means absence.
        transport.answer(statusCode: 404, body: 'Not found');

        await expectLater(
          build().read('tom.theme'),
          throwsA(_rejectedWith(404)),
        );

        transport.answer(statusCode: 404, body: 'Not found');
        await expectLater(
          build().getOr<String>('tom.theme', 'light'),
          throwsA(_rejectedWith(404)),
          reason: 'a refusal must not be papered over with the fallback',
        );
      });

      test('a 404 whose envelope names another key is not absence', () async {
        // The key is what the client branches on, not the envelope's presence:
        // an error handler that translated some other failure to a 404 must
        // not be read as "not set" merely because it, too, sent an envelope.
        transport.answer(
          statusCode: 404,
          body: '{"errorKey":"preferences.not_configured"}',
        );

        await expectLater(
          build().read('tom.theme'),
          throwsA(_rejectedWith(404)),
        );
      });

      test('a refused delete fails rather than reporting success', () async {
        // The delete is idempotent on the server, which answers `200` for a
        // preference that is not there — so a `404` from it is never "already
        // gone". It is the pipeline's refusal, and a client that swallowed it
        // would tell its caller a preference was cleared that is still stored.
        transport.answer(statusCode: 404, body: 'Not found');

        await expectLater(
          build().remove(TomUserPreferenceKeys.theme),
          throwsA(_rejectedWith(404)),
        );
      });

      test('a rejection carries the server\'s error key', () async {
        // The client has one rejection code, so the server's own key is what a
        // caller branches on to tell "this account is full" from any other
        // refusal — and it is only reachable if the client passes it on.
        transport.answer(
          statusCode: 409,
          body: jsonEncode({
            'errorKey': tomUserPreferencesLimitExceededErrorKey,
          }),
        );

        await expectLater(
          build().set('ui.one_too_many', 'x'),
          throwsA(
            _rejectedWith(409).having(
              (error) => error.parameters?['errorKey'],
              'errorKey',
              tomUserPreferencesLimitExceededErrorKey,
            ),
          ),
        );
      });

      test('a rejection without an envelope carries no error key', () async {
        transport.answer(statusCode: 404, body: 'Not found');

        await expectLater(
          build().remove(TomUserPreferenceKeys.theme),
          throwsA(
            _rejectedWith(404).having(
              (error) => error.parameters?.containsKey('errorKey'),
              'has errorKey',
              isFalse,
            ),
          ),
        );
      });

      test('an oversized value is refused before a request is made', () {
        // The codec's ceiling applies on this side too, so the server is never
        // sent a write it would refuse, and the refusal names the value rather
        // than arriving as a status.
        expect(
          () => build().set(
            'ui.notes',
            'a' * TomUserPreferenceCodec.maxValueBytes,
          ),
          throwsA(
            isA<TomUserPreferenceCodecException>().having(
              (error) => error.key,
              'key',
              'preferences.encode.too_large',
            ),
          ),
        );
        expect(transport.callCount, 0);
      });

      test('an unreadable body fails loudly', () async {
        transport.answer(body: 'not json at all');

        expect(
          build().read('tom.theme'),
          throwsA(
            isA<TomUserPreferencesClientException>().having(
              (error) => error.key,
              'key',
              'preferences.client.invalid_response',
            ),
          ),
        );
      });
    });

    group('correlating a failure with the server', () {
      /// The answer a Tom server gives when an endpoint refuses: the error
      /// envelope, announced by the header a [TomServerCallError] reads.
      void answerEnvelope({
        int statusCode = 409,
        String errorKey = 'preferences.limit_exceeded',
        String uuid = 'SERVER-EXC-1',
        String requestUuid = 'SERVER-REQ-1',
      }) => transport.answer(
        statusCode: statusCode,
        body: jsonEncode({
          'errorKey': errorKey,
          'uuid': uuid,
          'requestUuid': requestUuid,
        }),
        headers: const {'x-tom-error': 'true'},
      );

      test('a rejection carries the whole answer as a call error', () async {
        transport.answer(statusCode: 502, body: 'Bad gateway');

        final error = await _rejectionFrom(build());
        final call = error.serverCallError;

        expect(call, isNotNull);
        expect(call!.statusCode, 502);
        expect(call.response, 'Bad gateway');
        expect(
          call.hasError,
          isTrue,
          reason: 'a gateway answering HTML is still an answer worth carrying',
        );
      });

      test("and names the request the server logged it under", () async {
        // The correlation this module exists for: one id on both sides of one
        // failed call, so the client's report and the server's log line can be
        // read together.
        answerEnvelope();

        final error = await _rejectionFrom(build());

        expect(error.requestUuid, 'SERVER-REQ-1');
        expect(error.serverCallError?.requestUuid, 'SERVER-REQ-1');
        expect(error.serverCallError?.errorKey, 'preferences.limit_exceeded');
        expect(error.serverCallError?.uuid, 'SERVER-EXC-1');
      });

      test('a body that is not an envelope leaves it uncorrelated', () async {
        // Reading an id out of an arbitrary body would invent a correlation,
        // and a wrong correlation is worse than none because it is believed.
        transport.answer(statusCode: 500, body: '{"requestUuid":"NOT-OURS"}');

        final error = await _rejectionFrom(build());

        expect(error.requestUuid, isNull);
        expect(error.serverCallError?.response, '{"requestUuid":"NOT-OURS"}');
      });

      test('the client keeps its own identity', () async {
        // `uuid` is forwardable, but this exception is raised *here* — it is
        // not the server's exception rebuilt, so it does not borrow its id.
        answerEnvelope();

        final error = await _rejectionFrom(build());

        expect(error.uuid, isNotEmpty);
        expect(error.uuid, isNot('SERVER-EXC-1'));
      });

      test('an unreadable answer reports a decoding failure', () async {
        // The status was very likely a 200; what failed is this client's
        // reading of the body, and the call error says so rather than
        // implying the server refused.
        transport.answer(body: 'not a preference');

        late final TomUserPreferencesClientException error;
        try {
          await build().read('tom.theme');
          fail('expected the undecodable answer to throw');
        } on TomUserPreferencesClientException catch (caught) {
          error = caught;
        }

        expect(error.key, 'preferences.client.invalid_response');
        expect(
          error.serverCallError?.internalError,
          TomServerCallError.jsonDecodingError,
        );
        expect(error.serverCallError?.response, 'not a preference');
        expect(error.serverCallError?.exception, isNotNull);
      });
    });

    group('precedence against the device store', () {
      test('the device value wins and the server is never asked', () async {
        final device = TomStoredDevicePreferences(
          TomMemoryDevicePreferenceStore(),
        );
        await device.set(TomUserPreferenceKeys.theme, 'dark');
        final client = build();

        final theme = await device.getPreferred<String>(
          TomUserPreferenceKeys.theme,
          () => client.get<String>(TomUserPreferenceKeys.theme),
        );

        expect(theme, 'dark');
        expect(
          transport.callCount,
          0,
          reason:
              'a device that has written the key must not pay for a round trip',
        );
      });

      test('the server answers a key this device has never written', () async {
        final device = TomStoredDevicePreferences(
          TomMemoryDevicePreferenceStore(),
        );
        transport.answer(body: _dtoBody('tom.theme', 'light'));
        final client = build();

        final theme = await device.getPreferred<String>(
          TomUserPreferenceKeys.theme,
          () => client.get<String>(TomUserPreferenceKeys.theme),
        );

        expect(theme, 'light');
        expect(transport.callCount, 1);
      });

      test('a key only this device holds is answered locally', () async {
        final device = TomStoredDevicePreferences(
          TomMemoryDevicePreferenceStore(),
        );
        await device.set(TomUserPreferenceKeys.theme, 'dark');
        // The server would answer "absent" if it were asked; it must not be.
        transport.answer(statusCode: 404, body: _absentBody);
        final client = build();

        final theme = await device.getPreferred<String>(
          TomUserPreferenceKeys.theme,
          () => client.get<String>(TomUserPreferenceKeys.theme),
        );

        expect(theme, 'dark');
        expect(transport.callCount, 0);
      });

      test('neither store holding the key answers null', () async {
        final device = TomStoredDevicePreferences(
          TomMemoryDevicePreferenceStore(),
        );
        transport.answer(statusCode: 404, body: _absentBody);
        final client = build();

        expect(
          await device.getPreferred<String>(
            TomUserPreferenceKeys.theme,
            () => client.get<String>(TomUserPreferenceKeys.theme),
          ),
          isNull,
        );
      });
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

  group('the three platform-store variants present one signature', () {
    // The point of a conditional export is that one name means one thing on
    // every target. When the variants' constructors differ, code that compiles
    // on the platform you are building for fails on the one you are not — and
    // the compiler only says so once someone builds for the second platform,
    // which is the worst moment to find out.
    //
    // Declaring `const` on io and web, which neutral cannot, would let
    // `const TomPlatformDevicePreferenceStore(location)` compile on device and
    // web and fail to compile on the one target whose entire purpose is to fail
    // *at run time*. That trades a deliberate, locatable run-time diagnostic
    // for a compile error at an unrelated call site.
    // `TomFileClientConfigurationStore` has the same shape and therefore the
    // same resolution: none of the variants is const.
    const io =
        'lib/src/tomclient/preferences/platform_device_preference_store_io.dart';
    const web =
        'lib/src/tomclient/preferences/platform_device_preference_store_web.dart';
    const neutral =
        'lib/src/tomclient/preferences/platform_device_preference_store_neutral.dart';
    const variants = [io, web, neutral];
    const className = 'TomPlatformDevicePreferenceStore';
    const summaryPath = 'doc/api_reference/api_summary_preferences.md';

    test('every variant agrees about const', () {
      expectVariantsAgreeOnConst(variantPaths: variants, className: className);
    });

    test('all three variants declare the same public members', () {
      expectVariantsDeclareSameMembers(variants);
    });

    test('the summary shows const exactly when the sources do', () {
      // Pinning this here means the decision cannot be made in the source and
      // forgotten in the mirror — which is how the summary came to advertise a
      // `const` that only two of the three implementations offered.
      //
      // Only the summary's code fences count. The page also *explains* why the
      // constructor is not const, and that explanation has to quote the
      // `const $className(location)` a reader might otherwise write — read
      // whole, the page would look like it was advertising the very thing it
      // warns against.
      expect(
        summaryDeclaresConstConstructor(summaryPath, className),
        declaresConstConstructor(io, className),
        reason: 'the summary must show `const` exactly when the sources do',
      );
    });
  });

  group('the neutral platform store fails loudly', () {
    // The neutral variant is only conditionally *exported*, not conditionally
    // compiled — so it can be imported by path and asserted on any target,
    // including this one. Without that, its documented behaviour would be a
    // promise no test ever checks, on the one code path whose whole purpose is
    // to fail rather than degrade quietly.
    //
    // It is also what makes the const invariant above unsatisfiable in the
    // wrong direction: "all three agree" could otherwise be reached by making
    // the neutral variant const, which means deleting this throw and silently
    // degrading to a store that forgets everything — the outcome the module
    // exists to prevent.
    test('construction throws unsupported_platform', () {
      expect(
        () => neutral_store.TomPlatformDevicePreferenceStore(
          '/wherever/device_preferences.json',
        ),
        throwsA(
          isA<TomDevicePreferenceException>().having(
            (e) => e.key,
            'key',
            'device_preferences.unsupported_platform',
          ),
        ),
      );
    });

    test('the failure names the location that was asked for', () {
      // A settings screen that fails at startup has to be able to say what it
      // was trying to open, or the report is unactionable.
      try {
        neutral_store.TomPlatformDevicePreferenceStore(
          '/wherever/device_preferences.json',
        );
        fail('expected the neutral store to throw');
      } on TomDevicePreferenceException catch (error) {
        expect(
          error.parameters?['location'],
          '/wherever/device_preferences.json',
        );
      }
    });
  });

  group('the API summary mirrors the preferences exception sources', () {
    // The parameter types in these two constructor blocks have to be read off
    // `TomException`'s constructor, because `super.x` resolves against *that*
    // rather than against the field it eventually lands in. The two can differ
    // — `uuid`'s field is a non-nullable `late String` while its parameter is
    // `String?` — so documenting either from the other is the plausible-looking
    // wrong answer, which is why the mistake keeps being made by eye.
    //
    // So this guard exists as much to reject the "correction" as to catch real
    // drift — and the real drift these blocks attract is the opposite kind:
    // `bool autoLog` written with the inherited `= false` default dropped.
    //
    // The checks live in `support/exception_constructor_mirror.dart`, shared
    // with `little_things` and `configuration`; the parser they use is pinned
    // by `little_things_test.dart`.
    const summaryPath = 'doc/api_reference/api_summary_preferences.md';
    const sourcePaths = [
      'lib/src/tomclient/preferences/device_preferences.dart',
      'lib/src/tomclient/preferences/user_preferences_client.dart',
    ];
    final classNames = exceptionClassesIn(sourcePaths);

    test('both module exceptions are among the classes checked below', () {
      // The class list is derived from the sources, so it cannot go stale — but
      // a regex that stopped matching would empty it and leave the two tests
      // below passing on nothing. These are the two the module declares.
      expect(
        classNames,
        containsAll(const [
          'TomDevicePreferenceException',
          'TomUserPreferencesClientException',
        ]),
      );
    });

    test('the summary shows the parameters the sources actually forward', () {
      expectSummaryListsForwardedParameters(
        summaryPath: summaryPath,
        sourcePaths: sourcePaths,
        classNames: classNames,
      );
    });

    test(
      'every parameter type matches the kernel constructor it comes from',
      () {
        expectSummaryTypesMatchKernel(
          summaryPath: summaryPath,
          classNames: classNames,
        );
      },
    );
  });

  group('the shipped example runs', () {
    test('preferences_example.run() completes its assertions', () async {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      //
      // run() binds a loopback server and a temporary directory, and closes
      // both in its own `finally`; the suite's tearDown resets the bean context
      // it leaves behind.
      await example.run();
    });
  });
}

/// A syntactically valid, unsigned JWT carrying [payload].
///
/// Signed tokens are the security suite's business; here the token only has to
/// be *parseable*, because what is under test is which header carries it.
String _bearerJwt(Map<String, dynamic> payload) {
  String segment(Map<String, dynamic> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment(payload)}.sig';
}

/// The wire body the server would answer for [key] holding [value].
///
/// Built through the real codec and the real reflection encoder, so a test
/// never asserts against a shape the server does not actually produce.
/// The body the server's read endpoint answers a never-written preference
/// with: the error envelope, keyed by the contract's absence key.
final String _absentBody = jsonEncode({
  'errorKey': tomUserPreferencesNotFoundErrorKey,
});

/// Matches the client's `preferences.client.rejected` failure for a response
/// with [statusCode].
TypeMatcher<TomUserPreferencesClientException> _rejectedWith(int statusCode) =>
    isA<TomUserPreferencesClientException>()
        .having((error) => error.key, 'key', 'preferences.client.rejected')
        .having(
          (error) => error.parameters?['statusCode'],
          'statusCode',
          statusCode,
        );

String _dtoBody(String key, Object value) => tomReflectionInfo
    .convertToJsonString(TomUserPreferenceCodec.encode(key, value));

/// The `preferences.client.rejected` failure [client] raises for a read.
///
/// The three correlation assertions all need the *exception object* rather
/// than a matcher, so the try/fail/catch is written once here.
Future<TomUserPreferencesClientException> _rejectionFrom(
  TomUserPreferencesClient client,
) async {
  try {
    await client.get<String>('tom.theme');
  } on TomUserPreferencesClientException catch (error) {
    return error;
  }
  fail('expected the rejected call to throw');
}

/// A [TomHttpClientAbstractFactory] that answers every call from a script and
/// records what was asked.
///
/// A fake rather than a live server: what these tests are about is the *shape*
/// of the request the contract produces and the decoding of the answer, and
/// neither needs a socket to be wrong in an interesting way.
class _ScriptedTransport implements TomHttpClientAbstractFactory {
  int _statusCode = 200;
  String _body = '';

  /// How many requests reached the transport.
  int callCount = 0;

  /// The method of the most recent request.
  String? lastMethod;

  /// The URL of the most recent request.
  late Uri lastUrl;

  /// The body of the most recent request, or `null` when it carried none.
  String? lastBody;

  /// The headers of the most recent request, keyed in **lower case**.
  ///
  /// Normalised on the way in because HTTP header names are case-insensitive
  /// and `http` keys its own map that way: copying it into a plain `Map` would
  /// otherwise make a lookup depend on which spelling the caller happened to
  /// use, and a test would fail over the casing rather than over the header.
  Map<String, String> lastHeaders = const {};

  /// The headers the next answer carries.
  ///
  /// `x-tom-error` is the one that matters: it is what tells a
  /// [TomServerCallError] the body is a framework error envelope worth reading
  /// the `errorKey`, `uuid` and `requestUuid` out of. Without a way to script
  /// it here, the client's correlation with the server's own log could only be
  /// asserted against a live server.
  Map<String, String> _headers = const {};

  /// Scripts the answer the next call receives.
  void answer({
    int statusCode = 200,
    String body = '',
    Map<String, String> headers = const {},
  }) {
    _statusCode = statusCode;
    _body = body;
    _headers = headers;
  }

  @override
  Client getClient() => MockClient((request) async {
    callCount++;
    lastMethod = request.method;
    lastUrl = request.url;
    lastBody = request.body.isEmpty ? null : request.body;
    lastHeaders = {
      for (final entry in request.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };
    return Response(_body, _statusCode, headers: _headers);
  });
}
