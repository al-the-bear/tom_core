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

/// Reads [json] as a [T] the only way the codec allows: through a DTO that
/// declares the value is a [T].
///
/// The codec has no public entry point taking the text alone (tcinc163), so a
/// test that wants to exercise the narrowing has to say what the stored value
/// claims to be — which is exactly what a caller has to say too.
T decodeStored<T extends Object>(String json, [String key = 'ui.value']) =>
    TomUserPreferenceCodec.decode<T>(
      TomUserPreferenceDto(
        key: key,
        valueType: TomUserPreferenceCodec.typeNameForType(T),
        value: json,
      ),
    );

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

/// A reflected *generic* preference value.
///
/// The instantiation is what `runtimeType.toString()` used to leak into the
/// stored name: `BoxPreference<int>` from a value, `BoxPreference<dynamic>`
/// from the bare class literal, so the write and the read could never meet.
@tomReflector
class BoxPreference<T> {
  int count = 0;
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

    group('decode', () {
      for (final text in zonedTimestamps) {
        test('reads "$text" as the instant it names', () {
          final decoded = decodeStored<DateTime>(
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
            () => decodeStored<DateTime>(storedText(text), 'ui.lastSeen'),
            throwsCodecKey('preferences.decode.not_an_instant'),
          );
        });
      }

      test('reports text that is no timestamp at all as a mismatch', () {
        // Previously this escaped as a bare FormatException from
        // `DateTime.parse`, naming neither the preference nor the codec.
        expect(
          () => decodeStored<DateTime>(storedText('yesterday'), 'ui.lastSeen'),
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
          decodeStored<DateTime>(encoded),
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
        expect(decodeStored<DateTime>(encoded), instant);
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
  // an error. The `valueType` guard in `decode` is what keeps that from being
  // reachable by asking for the wrong class — what is left is a row whose
  // declared type and text disagree. Intended, but documented nowhere until
  // now, and these tests are what stops it drifting.
  group('TomUserPreferenceCodec — a reflected value is rebuilt by member', () {
    // Each of these stores a row whose `valueType` says DisplayPreference, so
    // the guard passes and the payload is all that is left to go on. That is
    // the only shape the defaulting is still reachable in: a mislabelled row,
    // not a caller asking for the wrong class.
    group('a mislabelled row takes the payload as it finds it', () {
      test('a payload sharing no member name yields the defaults', () {
        final decoded = decodeStored<DisplayPreference>(
          '{"enabled":false,"quietHour":6}',
          'ui.display',
        );

        expect(decoded.theme, 'light');
        expect(decoded.fontSize, 14);
        expect(decoded.compact, isFalse);
      });

      test('an empty object yields the defaults', () {
        final decoded = decodeStored<DisplayPreference>('{}', 'ui.display');

        expect(decoded.theme, 'light');
        expect(decoded.fontSize, 14);
      });

      test('unrecognised members are ignored, recognised ones applied', () {
        final decoded = decodeStored<DisplayPreference>(
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
        final restored = decodeStored<DisplayPreference>(encoded, 'ui.display');

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
      // Refused for want of a stored identity now (tcinc164) rather than at
      // the instantiation: a class the registry does not know has no name a
      // row could have been written under, so the read is answered before the
      // payload is even looked at.
      expect(
        () => decodeStored<UnreflectedPreference>('{"size":9}', 'ui.size'),
        throwsCodecKey('preferences.type.not_reflected'),
      );
    });
  });

  // tcinc163: the module's headline promise is that a mismatched read fails
  // rather than coerces, but `decodeValue` was public and took the text alone,
  // so the promise held only for callers who reached for `decode`. It is
  // private now; these tests pin the cases that used to slip past it.
  //
  // That the whole file compiles without naming `decodeValue` is the other
  // half of the assertion: there is no longer an entry point to reach for.
  group('TomUserPreferenceCodec — the type guard has no way around it', () {
    test('a stored DateTime cannot be read as the String it looks like', () {
      // The exact probe that motivated this: JSON stores an instant as text,
      // so a String read is well-typed at every level below the valueType.
      final stored = TomUserPreferenceCodec.encode(
        'ui.lastSeen',
        DateTime.utc(2026, 3, 4, 5, 6, 7),
      );

      expect(stored.value, storedText('2026-03-04T05:06:07.000Z'));
      expect(
        () => TomUserPreferenceCodec.decode<String>(stored),
        throwsCodecKey('preferences.decode.type_mismatch'),
      );
    });

    test('a stored int cannot be read as the double it widens to', () {
      // `decode` refuses before the widening branch is reached, so the
      // convenience does not become a second way past the declared type.
      final stored = TomUserPreferenceCodec.encode('ui.scale', 3);

      expect(
        () => TomUserPreferenceCodec.decode<double>(stored),
        throwsCodecKey('preferences.decode.type_mismatch'),
      );
      expect(TomUserPreferenceCodec.decode<int>(stored), 3);
    });

    test('the refusal names both types, so the caller knows which is wrong',
        () {
      final stored = TomUserPreferenceCodec.encode('ui.lastSeen', 3);

      try {
        TomUserPreferenceCodec.decode<String>(stored);
        fail('A mismatched read must not succeed');
      } on TomUserPreferenceCodecException catch (error) {
        expect(error.parameters?['key'], 'ui.lastSeen');
        expect(error.parameters?['stored'], TomUserPreferenceCodec.intType);
        expect(
          error.parameters?['requested'],
          TomUserPreferenceCodec.stringType,
        );
      }
    });
  });

  // tcinc164: a non-scalar was stored under `value.runtimeType.toString()` — a
  // string the compiler owns rather than the program. It leaked private SDK
  // names, carried the generic instantiation, and is explicitly not preserved
  // by web minification, so a preference could be written under a name no
  // reader could ever ask for. The identity now comes from the reflection
  // registry.
  //
  // The obfuscation hazard itself cannot be observed from the VM. What these
  // tests pin instead is the thing that implies it: the name is the
  // generator's literal, not the compiler's rendering — and the three cases
  // where the two visibly disagree.
  group('TomUserPreferenceCodec — a non-scalar is named by the registry', () {
    test('the stored name is the registry\'s own name for the class', () {
      final mirror = tomReflector.reflectType(DisplayPreference) as ClassMirror;

      expect(
        TomUserPreferenceCodec.typeNameOf(DisplayPreference()),
        mirror.simpleName,
      );
      expect(
        TomUserPreferenceCodec.typeNameForType(DisplayPreference),
        mirror.simpleName,
      );
    });

    test('a private SDK class can no longer be stored under its name', () {
      // `typeNameOf(<String,int>{})` answered `_Map<String, int>`. `_Map` is
      // not a type any caller can write, so such a row was unreadable by
      // construction the moment it was written — a silent write and a
      // permanent read failure. Refusing the write is the whole point.
      expect(
        () => TomUserPreferenceCodec.typeNameOf(<String, int>{'a': 1}),
        throwsCodecKey('preferences.type.not_reflected'),
      );
    });

    test('a generic value and its bare class literal reach the same name', () {
      // `runtimeType.toString()` gave `BoxPreference<int>` on the way out and
      // `BoxPreference<dynamic>` on the way back, so a generic preference
      // written by one half could never be read by the other. The registry
      // knows the class, not the instantiation.
      expect(TomUserPreferenceCodec.typeNameOf(BoxPreference<int>()),
          'BoxPreference');
      expect(
        TomUserPreferenceCodec.typeNameOf(BoxPreference<int>()),
        TomUserPreferenceCodec.typeNameForType(BoxPreference),
      );
    });

    test('a type the registry does not know has no stored identity', () {
      expect(
        () => TomUserPreferenceCodec.typeNameOf(UnreflectedPreference()),
        throwsCodecKey('preferences.type.not_reflected'),
      );
      expect(
        () => TomUserPreferenceCodec.typeNameForType(UnreflectedPreference),
        throwsCodecKey('preferences.type.not_reflected'),
      );
    });

    test('encode refuses such a value rather than inventing a name', () {
      // The failure now arrives at the write, not at the first read — which
      // would otherwise be on another device, in another release.
      expect(
        () => TomUserPreferenceCodec.encode('ui.size', UnreflectedPreference()),
        throwsCodecKey('preferences.type.not_reflected'),
      );
    });

    test('the refusal names the type it could not name', () {
      try {
        TomUserPreferenceCodec.typeNameOf(UnreflectedPreference());
        fail('A type with no stored identity must not be given one');
      } on TomUserPreferenceCodecException catch (error) {
        expect(error.parameters?['valueType'], 'UnreflectedPreference');
      }
    });

    test('a scalar is named without the registry being asked', () {
      // None of these are reflected, so answering at all is the assertion:
      // the scalar branches are tested before anything reaches reflection.
      expect(TomUserPreferenceCodec.typeNameForType(String),
          TomUserPreferenceCodec.stringType);
      expect(TomUserPreferenceCodec.typeNameForType(int),
          TomUserPreferenceCodec.intType);
      expect(TomUserPreferenceCodec.typeNameForType(double),
          TomUserPreferenceCodec.doubleType);
      expect(TomUserPreferenceCodec.typeNameForType(bool),
          TomUserPreferenceCodec.boolType);
      expect(TomUserPreferenceCodec.typeNameForType(DateTime),
          TomUserPreferenceCodec.dateTimeType);
    });

    test('a reflected value still round-trips under its registry name', () {
      final stored = TomUserPreferenceCodec.encode(
        'ui.display',
        DisplayPreference()..fontSize = 18,
      );

      expect(stored.valueType, 'DisplayPreference');
      expect(TomUserPreferenceCodec.decode<DisplayPreference>(stored).fontSize,
          18);
    });

    test('a row labelled as a scalar but holding an object says so', () {
      // Resolving the class once, in `decode`, and handing the mirror to the
      // read means the read no longer asks reflection anything — so a stored
      // row whose declared scalar type does not match its object payload is
      // now reported as what it is, rather than as `String is not reflected`,
      // which blamed the wrong thing.
      expect(
        () => decodeStored<String>('{"size":9}', 'ui.size'),
        throwsCodecKey('preferences.decode.failed'),
      );
    });
  });
}
