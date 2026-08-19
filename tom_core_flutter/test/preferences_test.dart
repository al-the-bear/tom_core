import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
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

    // tcinc160: the document is meant to move between devices, so an
    // updatedAt with no zone would be read as the *importing* device's local
    // time — silently, and differently on each one.
    test('rejects an updatedAt that names no time zone', () {
      const content = '[{"key":"device.theme","valueType":"String",'
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
      const content = '[{"key":"device.theme","valueType":"String",'
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
          'https://api.example.com/preferences/tom.theme',
        );
        // The body carries the codec's encoding, not the raw value: the type
        // name is what lets the server reject a mismatched write and what lets
        // a later read come back typed.
        final sent = jsonDecode(transport.lastBody!) as Map<String, Object?>;
        expect(sent['key'], 'tom.theme');
        expect(sent['valueType'], 'String');
        expect(sent['value'], '"dark"');
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
        // All three key-taking calls, not just the delete: the key is in the
        // path of each, so a rule enforced on one is a rule with two ways past.
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
          // The server distinguishes a miss from a fault with a 404
          // (`TomUserPreferencesErrorHandler`); reading that as `null` is what
          // makes an unset preference an ordinary state rather than an error.
          transport.answer(
            statusCode: 404,
            body: '{"errorKey":"preferences.not_found"}',
          );
          expect(await build().get<String>('tom.theme'), isNull);

          transport.answer(
            statusCode: 404,
            body: '{"errorKey":"preferences.not_found"}',
          );
          expect(await build().read('tom.theme'), isNull);
        },
      );

      test(
        'getOr answers the fallback for a preference that is not there',
        () async {
          transport.answer(statusCode: 404, body: '');
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
          transport.answer(statusCode: 404, body: '');

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

      test('neither store holding the key answers null', () async {
        final device = TomStoredDevicePreferences(
          TomMemoryDevicePreferenceStore(),
        );
        transport.answer(statusCode: 404, body: '');
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
String _dtoBody(String key, Object value) => tomReflectionInfo
    .convertToJsonString(TomUserPreferenceCodec.encode(key, value));

/// An [TomHttpClientFactory] that answers every call from a script and records
/// what was asked.
///
/// A fake rather than a live server: what these tests are about is the *shape*
/// of the request the contract produces and the decoding of the answer, and
/// neither needs a socket to be wrong in an interesting way.
class _ScriptedTransport extends TomHttpClientFactory {
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

  /// Scripts the answer the next call receives.
  void answer({int statusCode = 200, String body = ''}) {
    _statusCode = statusCode;
    _body = body;
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
    return Response(_body, _statusCode);
  });
}
