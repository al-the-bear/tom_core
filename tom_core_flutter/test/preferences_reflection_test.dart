import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// What the preferences module does in an application that never called
/// `initializeReflection()`.
///
/// **A file of its own, and that is the whole reason it exists.** Reflection is
/// initialised once per isolate and cannot be put back; `preferences_test.dart`
/// calls `initializeReflection` in `setUpAll`, so no test there can ever reach
/// this state. `flutter test` gives each file its own isolate, which is the only
/// place the uninitialised case is observable at all.
///
/// Nothing here initialises reflection. A test added to this file that needs it
/// belongs in `preferences_test.dart` instead.
void main() {
  Matcher throwsReflectionFailure(String key) => throwsA(
    isA<TomException>()
        .having((error) => error.key, 'key', key)
        .having(
          (error) => error.defaultUserMessage,
          'message',
          contains('initializeReflection()'),
        ),
  );

  group('the device store says which side is misconfigured', () {
    test('encoding names the configuration fault', () {
      expect(
        () => TomDevicePreferenceJson.encode([
          TomUserPreferenceDto(key: 'k', valueType: 'String', value: '"v"'),
        ]),
        throwsReflectionFailure(
          'device_preferences.store.reflection_not_initialised',
        ),
      );
    });

    test('decoding a perfectly good document does too', () {
      // The document is valid. Reporting this as `invalid_content` would send
      // the reader to a file that is intact — the diagnosis this error exists
      // to avoid.
      expect(
        () => TomDevicePreferenceJson.decode(
          '[{"key":"k","valueType":"String","value":"\\"v\\""}]',
        ),
        throwsReflectionFailure(
          'device_preferences.store.reflection_not_initialised',
        ),
      );
    });

    test('and a genuinely corrupt document still reads as corrupt', () {
      // The other arm: the named error must not swallow the failure it was
      // carved out of.
      expect(
        () => TomDevicePreferenceJson.decode('not json at all'),
        throwsA(
          isA<TomDevicePreferenceException>().having(
            (error) => error.key,
            'key',
            'device_preferences.store.invalid_content',
          ),
        ),
      );
    });
  });

  group('a write reports the fault it met, not the one it was in', () {
    // The file backend translates a platform refusal into
    // `device_preferences.store.write_refused`. A failure this module already
    // named must pass through that translation unchanged — burying
    // `reflection_not_initialised` under a code about the filesystem would send
    // the reader to a disk that is fine.
    //
    // This is the only file that can stage it: encoding is what fails, and
    // encoding only fails where reflection was never initialised.
    test(
      'an unencodable document is not reported as a refused write',
      () async {
        final directory = Directory.systemTemp.createTempSync('tom_prefs_');
        addTearDown(() => directory.deleteSync(recursive: true));
        final store = TomPlatformDevicePreferenceStore(
          '${directory.path}/preferences.json',
        );

        await expectLater(
          store.write([
            TomUserPreferenceDto(
              key: 'device.a',
              valueType: 'String',
              value: '"1"',
            ),
          ]),
          throwsA(
            isA<TomDevicePreferenceException>().having(
              (error) => error.key,
              'key',
              'device_preferences.store.reflection_not_initialised',
            ),
          ),
        );
      },
    );
  });

  group('the account client does not blame the server', () {
    TomUserPreferencesClient build(_ScriptedTransport transport) =>
        TomUserPreferencesClient(
          baseUri: Uri.parse('https://api.example.com'),
          channel: TomServerChannel(
            'api.example.com',
            443,
            clientFactory: transport,
          ),
        );

    test('a correct answer is not reported as an invalid response', () async {
      // The measurement the todo was filed on: a valid 200 carrying a valid
      // preference document was reported as `preferences.client.invalid_response`
      // — "The server did not answer with a preference" — for a fault entirely
      // on this side.
      final transport = _ScriptedTransport(
        body: '{"key":"tom.theme","valueType":"String","value":"\\"dark\\""}',
      );
      final client = build(transport);
      addTearDown(client.close);

      await expectLater(
        client.read('tom.theme'),
        throwsReflectionFailure(
          'preferences.client.reflection_not_initialised',
        ),
      );
    });

    test('and fails before it sends a write', () async {
      // The outbound half. A write encodes its body through reflection, so it
      // cannot even reach the network — and saying so is what stops the caller
      // looking there.
      final transport = _ScriptedTransport(body: '{}');
      final client = build(transport);
      addTearDown(client.close);

      await expectLater(
        client.set<String>('tom.theme', 'dark'),
        throwsReflectionFailure(
          'preferences.client.reflection_not_initialised',
        ),
      );
      expect(
        transport.callCount,
        0,
        reason: 'the request was never made, so the server was never involved',
      );
    });
  });
}

/// A transport that answers every call with one scripted body and counts the
/// calls that reached it.
class _ScriptedTransport implements TomHttpClientAbstractFactory {
  _ScriptedTransport({required this.body});

  final String body;

  /// How many requests reached the transport.
  int callCount = 0;

  @override
  Client getClient() => MockClient((request) async {
    callCount++;
    return Response(body, 200);
  });
}
