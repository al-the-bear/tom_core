import 'dart:convert';

import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'preferences_test.reflection.dart';

// =============================================================================
// Helpers
// =============================================================================

/// Wraps [text] the way it is stored: a preference value is JSON, and a
/// timestamp is JSON *text*, so the stored bytes carry the quotes.
String storedText(String text) => jsonEncode(text);

Matcher throwsCodecKey(String key) => throwsA(
      isA<TomUserPreferenceCodecException>()
          .having((error) => error.key, 'key', key),
    );

/// Timestamps that name the instant they mean — the reader cannot be wrong
/// about them, whatever zone it runs in.
const zonedTimestamps = <String>[
  '2026-03-04T05:06:07Z',
  '2026-03-04T05:06:07z',
  '2026-03-04T05:06:07.123456Z',
  '2026-03-04T05:06:07+00:00',
  '2026-03-04T05:06:07+01:00',
  '2026-03-04T05:06:07-05:00',
  '2026-03-04T05:06:07+0100',
  '2026-03-04T05:06:07+01',
];

/// Timestamps `DateTime.parse` accepts but reads as *local* time, so each one
/// denotes a different instant on every device that reads it. The date-only
/// form belongs here too: it means local midnight.
const zonelessTimestamps = <String>[
  '2026-03-04T05:06:07',
  '2026-03-04 05:06:07',
  '2026-03-04T05:06:07.123',
  '2026-03-04',
];

/// The only scalar values `jsonEncode` refuses. A non-finite double is not
/// exotic for a preference: it is what a computed UI scale produces when the
/// number it divided by turned out to be zero.
const nonFiniteDoubles = <String, double>{
  'double.nan': double.nan,
  'double.infinity': double.infinity,
  'double.negativeInfinity': double.negativeInfinity,
};

/// A value the reflection path cannot serialize, so the reflected branch's own
/// failure stays distinguishable from the scalar one.
class UnreflectedPreference {
  int size = 3;
}

/// A reflected preference value, with a default for every member.
@tomReflector
class DisplayPreference {
  String theme = 'light';
  int fontSize = 14;
  bool compact = false;
}

/// A second reflected preference value that shares **no** member name with
/// [DisplayPreference], so a payload of one carries nothing the other
/// recognises.
@tomReflector
class NotificationPreference {
  bool enabled = true;
  int quietHour = 22;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // The object-decode group below reconstructs @tomReflector classes, which
  // needs their mirrors registered.
  setUpAll(initializeReflection);

  // tcinc160: a zoneless ISO timestamp passed `validateEncoded` and then
  // decoded to a different instant on every device — the exact failure the
  // module's dartdoc promises cannot happen.
  group('TomUserPreferenceCodec — a stored DateTime names one instant', () {
    group('validateEncoded', () {
      for (final text in zonedTimestamps) {
        test('accepts "$text", which carries a zone', () {
          expect(
            () => TomUserPreferenceCodec.validateEncoded(
              TomUserPreferenceCodec.dateTimeType,
              storedText(text),
              key: 'ui.lastSeen',
            ),
            returnsNormally,
          );
        });
      }

      for (final text in zonelessTimestamps) {
        test('rejects "$text", which names no zone', () {
          expect(
            () => TomUserPreferenceCodec.validateEncoded(
              TomUserPreferenceCodec.dateTimeType,
              storedText(text),
              key: 'ui.lastSeen',
            ),
            throwsCodecKey('preferences.encoded.not_an_instant'),
          );
        });
      }

      test('names the offending key and type in the rejection', () {
        try {
          TomUserPreferenceCodec.validateEncoded(
            TomUserPreferenceCodec.dateTimeType,
            storedText('2026-03-04T05:06:07'),
            key: 'ui.lastSeen',
          );
          fail('A zoneless timestamp must not be accepted');
        } on TomUserPreferenceCodecException catch (error) {
          expect(error.parameters?['key'], 'ui.lastSeen');
          expect(
            error.parameters?['valueType'],
            TomUserPreferenceCodec.dateTimeType,
          );
        }
      });

      test('still rejects text that is no timestamp at all', () {
        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            TomUserPreferenceCodec.dateTimeType,
            storedText('yesterday'),
          ),
          throwsCodecKey('preferences.encoded.type_mismatch'),
        );
      });

      test('still rejects a non-text value declared as a DateTime', () {
        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            TomUserPreferenceCodec.dateTimeType,
            '1772596000',
          ),
          throwsCodecKey('preferences.encoded.type_mismatch'),
        );
      });

      test('leaves the other scalar types alone', () {
        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            TomUserPreferenceCodec.stringType,
            storedText('2026-03-04T05:06:07'),
          ),
          returnsNormally,
        );
      });
    });

    group('decodeValue', () {
      for (final text in zonedTimestamps) {
        test('reads "$text" as the instant it names', () {
          final decoded = TomUserPreferenceCodec.decodeValue<DateTime>(
            storedText(text),
            'ui.lastSeen',
          );

          expect(decoded.isUtc, isTrue);
          expect(decoded, DateTime.parse(text).toUtc());
        });
      }

      for (final text in zonelessTimestamps) {
        test('refuses "$text" rather than reading it as local time', () {
          // The old behaviour returned a UTC-flagged value here, so the flag
          // proved only that a conversion happened — not that it converted
          // from the zone the writer meant.
          expect(
            () => TomUserPreferenceCodec.decodeValue<DateTime>(
              storedText(text),
              'ui.lastSeen',
            ),
            throwsCodecKey('preferences.decode.not_an_instant'),
          );
        });
      }

      test('reports text that is no timestamp at all as a mismatch', () {
        // Previously this escaped as a bare FormatException from
        // `DateTime.parse`, naming neither the preference nor the codec.
        expect(
          () => TomUserPreferenceCodec.decodeValue<DateTime>(
            storedText('yesterday'),
            'ui.lastSeen',
          ),
          throwsCodecKey('preferences.decode.type_mismatch'),
        );
      });
    });

    group('the write path keeps producing readable values', () {
      test('encodeValue writes a zoned timestamp for a local DateTime', () {
        final local = DateTime.utc(2026, 3, 4, 5, 6, 7).toLocal();

        final encoded = TomUserPreferenceCodec.encodeValue(local);

        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            TomUserPreferenceCodec.dateTimeType,
            encoded,
          ),
          returnsNormally,
        );
        expect(
          TomUserPreferenceCodec.decodeValue<DateTime>(encoded),
          DateTime.utc(2026, 3, 4, 5, 6, 7),
        );
      });

      test('encode/decode round-trips a local DateTime through the DTO', () {
        final local = DateTime.utc(2026, 3, 4, 5, 6, 7).toLocal();

        final stored = TomUserPreferenceCodec.encode('ui.lastSeen', local);
        final restored = TomUserPreferenceCodec.decode<DateTime>(stored);

        expect(stored.valueType, TomUserPreferenceCodec.dateTimeType);
        expect(restored.isUtc, isTrue);
        expect(restored.isAtSameMomentAs(local), isTrue);
      });

      test('a UTC DateTime round-trips byte-identically', () {
        final instant = DateTime.utc(2026, 3, 4, 5, 6, 7, 123, 456);

        final encoded = TomUserPreferenceCodec.encodeValue(instant);

        expect(encoded, storedText('2026-03-04T05:06:07.123456Z'));
        expect(TomUserPreferenceCodec.decodeValue<DateTime>(encoded), instant);
      });
    });
  });

  // tcinc161: the scalar branch called `jsonEncode` outside the guard, so a
  // non-finite double threw `JsonUnsupportedObjectError` straight through a
  // codec whose whole documented contract is that it throws
  // `TomUserPreferenceCodecException`.
  group('TomUserPreferenceCodec — encodeValue reports its own failures', () {
    for (final entry in nonFiniteDoubles.entries) {
      test('refuses ${entry.key} as a codec exception', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(entry.value),
          throwsCodecKey('preferences.encode.not_json'),
        );
      });
    }

    test('names the value type in parameters', () {
      expect(
        () => TomUserPreferenceCodec.encodeValue(double.nan),
        throwsA(
          isA<TomUserPreferenceCodecException>().having(
            (error) => error.parameters?['valueType'],
            'valueType',
            'double',
          ),
        ),
      );
    });

    test('names the preference key when encode() supplies one', () {
      expect(
        () => TomUserPreferenceCodec.encode('ui.scale', double.nan),
        throwsA(
          isA<TomUserPreferenceCodecException>().having(
            (error) => error.parameters?['key'],
            'key',
            'ui.scale',
          ),
        ),
      );
    });

    test('the reflected path keeps its own key', () {
      expect(
        () => TomUserPreferenceCodec.encodeValue(UnreflectedPreference()),
        throwsCodecKey('preferences.encode.failed'),
      );
    });

    group('the scalars that JSON can represent are untouched', () {
      test('a finite double', () {
        expect(TomUserPreferenceCodec.encodeValue(1.25), '1.25');
      });

      test('an int', () {
        expect(TomUserPreferenceCodec.encodeValue(14), '14');
      });

      test('a bool', () {
        expect(TomUserPreferenceCodec.encodeValue(true), 'true');
      });

      test('a String', () {
        expect(TomUserPreferenceCodec.encodeValue('hi'), '"hi"');
      });
    });
  });

  // tcinc162: a reflected value is rebuilt member by member, so a payload
  // belonging to a different class produces a defaulted instance rather than
  // an error. That is intended (the type name is what identifies a stored
  // object, and `decode` checks it) but it was documented nowhere, and these
  // tests are what stops it drifting.
  group('TomUserPreferenceCodec — a reflected value is rebuilt by member', () {
    group('decodeValue takes the payload as it finds it', () {
      test('a payload sharing no member name yields the defaults', () {
        final decoded = TomUserPreferenceCodec.decodeValue<DisplayPreference>(
          '{"enabled":false,"quietHour":6}',
          'ui.display',
        );

        expect(decoded.theme, 'light');
        expect(decoded.fontSize, 14);
        expect(decoded.compact, isFalse);
      });

      test('an empty object yields the defaults', () {
        final decoded = TomUserPreferenceCodec.decodeValue<DisplayPreference>(
          '{}',
          'ui.display',
        );

        expect(decoded.theme, 'light');
        expect(decoded.fontSize, 14);
      });

      test('unrecognised members are ignored, recognised ones applied', () {
        final decoded = TomUserPreferenceCodec.decodeValue<DisplayPreference>(
          '{"theme":"dark","quietHour":6}',
          'ui.display',
        );

        expect(decoded.theme, 'dark');
        // Absent from the payload, so still the declared default.
        expect(decoded.fontSize, 14);
      });

      test('a reflected value round-trips through its own text', () {
        final original = DisplayPreference()
          ..theme = 'dark'
          ..fontSize = 18
          ..compact = true;

        final encoded = TomUserPreferenceCodec.encodeValue(
          original,
          'ui.display',
        );
        final restored =
            TomUserPreferenceCodec.decodeValue<DisplayPreference>(encoded);

        expect(restored.theme, 'dark');
        expect(restored.fontSize, 18);
        expect(restored.compact, isTrue);
      });
    });

    group('the stored type name is what identifies an object', () {
      test('decode refuses a DTO stored as a different class', () {
        final stored = TomUserPreferenceCodec.encode(
          'ui.display',
          NotificationPreference(),
        );

        expect(stored.valueType, 'NotificationPreference');
        expect(
          () => TomUserPreferenceCodec.decode<DisplayPreference>(stored),
          throwsCodecKey('preferences.decode.type_mismatch'),
        );
      });

      test('decode accepts the class the DTO names', () {
        final stored = TomUserPreferenceCodec.encode(
          'ui.display',
          DisplayPreference()..theme = 'dark',
        );

        expect(
          TomUserPreferenceCodec.decode<DisplayPreference>(stored).theme,
          'dark',
        );
      });

      test('validateEncoded checks only that the value is a JSON object', () {
        // The boundary cannot ask more: a server may be storing a preference
        // type only the client knows, and reflecting it to check would mean
        // refusing values it is not meant to interpret.
        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            'DisplayPreference',
            '{"totally":"unrelated"}',
            key: 'ui.display',
          ),
          returnsNormally,
        );
        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            'DisplayPreference',
            '"not an object"',
            key: 'ui.display',
          ),
          throwsCodecKey('preferences.encoded.type_mismatch'),
        );
      });
    });

    test('an unreflected class is refused rather than defaulted', () {
      expect(
        () => TomUserPreferenceCodec.decodeValue<UnreflectedPreference>(
          '{"size":9}',
          'ui.size',
        ),
        throwsCodecKey('preferences.decode.not_reflected'),
      );
    });
  });
}
