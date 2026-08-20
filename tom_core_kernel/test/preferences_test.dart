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
/// The codec has no public entry point taking the text alone, so a
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
  isA<TomUserPreferenceCodecException>().having(
    (error) => error.key,
    'key',
    key,
  ),
);

/// The `cause` a refusal reports, which is what a caller switches on when the
/// prose is for a human and the branch is for a program.
Matcher throwsCodecCause(String key, String cause) => throwsA(
  isA<TomUserPreferenceCodecException>()
      .having((error) => error.key, 'key', key)
      .having((error) => error.parameters?['cause'], 'cause', cause),
);

/// Asserts the sentence a caller is actually given, because the remedy is the
/// point of these refusals — a message naming the wrong fix costs more time
/// than no message at all.
Matcher throwsCodecMessage(String key, Matcher message) => throwsA(
  isA<TomUserPreferenceCodecException>()
      .having((error) => error.key, 'key', key)
      .having(
        (error) => error.defaultUserMessage,
        'defaultUserMessage',
        message,
      ),
);

/// The `cause` a key refusal reports — the clause of the rule that was
/// broken, which is what tells a caller what to change.
Matcher throwsKeyCause(String cause) => throwsA(
  isA<TomUserPreferenceKeyException>()
      .having((error) => error.key, 'key', 'preferences.key.invalid')
      .having((error) => error.parameters?['cause'], 'cause', cause),
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

/// A reflected preference value with a reflected subclass, which is what makes
/// the runtime/static difference between the two naming methods observable.
///
/// Every other fixture is named identically whether you start from a value or
/// from a type, so none of them can tell the two apart.
@tomReflector
class BasePreference {
  int size = 1;
}

/// A reflected subclass of [BasePreference]; see there.
@tomReflector
class SubPreference extends BasePreference {
  String label = 'sub';
}

/// A reflected class with no no-argument constructor, so rebuilding it from a
/// stored row is impossible. Writing one still works, which is what makes the
/// read the first place the problem can appear.
@tomReflector
class ConstructedPreference {
  int size;

  ConstructedPreference(this.size);
}

/// [DisplayPreference]'s members, defaulted through constructor parameters
/// instead of field initializers.
///
/// The two forms look like a style choice and are not obviously
/// interchangeable: rebuilding goes through `newInstance("", [])`, which passes
/// no arguments at all, so whether a defaulted *parameter* leaves the instance
/// as usable as a defaulted *field* is a question about the reflector, not
/// about taste. It is asserted rather than assumed because the documentation
/// shows both forms and a reader has to know that neither one is a trap.
@tomReflector
class ConstructorDefaultedPreference {
  String theme;
  int fontSize;
  bool compact;

  ConstructorDefaultedPreference({
    this.theme = 'light',
    this.fontSize = 14,
    this.compact = false,
  });
}

/// An enum preference value — a theme, the canonical one.
///
/// Annotated, because an enum is a non-scalar and so follows the same rule as
/// every other non-scalar: the registry is what makes its name durable, and on
/// the way back it is also what supplies the constants to match against.
@tomReflector
enum ThemePreference { light, dark, highContrast }

/// A second reflected enum, so a value of one is not readable as the other.
@tomReflector
enum DensityPreference { comfortable, compact }

/// An **unannotated** enum, which the registry therefore cannot name.
enum UnreflectedThemePreference { light, dark }

/// A reflected enum that overrides `toString`.
///
/// Worth pinning because the kernel's other enum-naming code
/// (`TomObservableEnum.enumTypeSegment`) reads the declared name back out of
/// `Enum.toString()` and is defeated by an override. The codec is not: it takes
/// the type name from the registry and the constant from [Enum.name], neither
/// of which an override touches.
@tomReflector
enum RenamedPreference {
  first,
  second;

  @override
  String toString() => 'custom($name)';
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // The object-decode group below reconstructs @tomReflector classes, which
  // needs their mirrors registered.
  setUpAll(initializeReflection);

  // A zoneless ISO timestamp would pass `validateEncoded` and then decode to
  // a different instant on every device — the exact failure the module's
  // dartdoc promises cannot happen.
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

  // Calling `jsonEncode` outside the guard in the scalar branch would let a
  // non-finite double throw `JsonUnsupportedObjectError` straight through a
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

    // There are five ways to reach a write failure and they have five
    // different remedies. Answering all of them with "add an annotation" is
    // advice a Set, a Map keyed by int and a NaN cannot act on. These tests
    // hold each refusal to its own diagnosis.
    group('the refusal names the cause it can actually detect', () {
      test(
        'a non-finite element is the JSON problem it is, not a shape one',
        () {
          expect(
            () => TomUserPreferenceCodec.encodeValue(<double>[1.0, double.nan]),
            throwsCodecCause('preferences.encode.not_json', 'element_not_json'),
          );
        },
      );

      test('and says which element and what to store instead', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<double>[double.nan]),
          throwsCodecMessage(
            'preferences.encode.not_json',
            allOf(contains('NaN'), contains('finite')),
          ),
        );
      });

      test('a top-level non-finite is told apart from an element one', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(double.nan),
          throwsCodecCause('preferences.encode.not_json', 'value_not_json'),
        );
      });

      test('a Map keyed by anything but String says so', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<int, String>{1: 'one'}),
          throwsCodecCause('preferences.encode.failed', 'map_key_not_string'),
        );
      });

      test('and names the key type rather than the private Map class', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<int, String>{1: 'one'}),
          throwsCodecMessage(
            'preferences.encode.failed',
            allOf(
              contains('keyed by int'),
              contains('String'),
              isNot(contains('_Map')),
            ),
          ),
        );
      });

      test('an element that is not a scalar is its own cause', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<UnreflectedPreference>[
            UnreflectedPreference(),
          ]),
          throwsCodecCause('preferences.encode.failed', 'element_not_scalar'),
        );
      });

      test('and says outright that annotating the element does not help', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<UnreflectedPreference>[
            UnreflectedPreference(),
          ]),
          throwsCodecMessage(
            'preferences.encode.failed',
            allOf(contains('UnreflectedPreference'), contains('does not help')),
          ),
        );
      });

      test('a Map value that is not a scalar takes the same cause', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(
            <String, UnreflectedPreference>{'a': UnreflectedPreference()},
          ),
          throwsCodecCause('preferences.encode.failed', 'element_not_scalar'),
        );
      });

      test('a Set is refused as a shape, not as a missing annotation', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<int>{1, 2}),
          throwsCodecCause('preferences.encode.failed', 'not_a_list_or_map'),
        );
      });

      test('and is told the conversion that would work', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<int>{1, 2}),
          throwsCodecMessage(
            'preferences.encode.failed',
            allOf(contains('Set'), contains('toList()')),
          ),
        );
      });

      test('a lazy Iterable is refused the same way a Set is', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<int>[1, 2].map((e) => e)),
          throwsCodecCause('preferences.encode.failed', 'not_a_list_or_map'),
        );
      });

      test('an unannotated class is the one case the annotation fixes', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(UnreflectedPreference()),
          throwsCodecCause('preferences.encode.failed', 'unreflected_class'),
        );
      });

      test('and is the case that keeps the @tomReflector advice', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(UnreflectedPreference()),
          throwsCodecMessage(
            'preferences.encode.failed',
            contains('@tomReflector'),
          ),
        );
      });

      test('the cause survives the DTO-building entry point too', () {
        expect(
          () => TomUserPreferenceCodec.encode('ui.scale', <double>[double.nan]),
          throwsCodecCause('preferences.encode.not_json', 'element_not_json'),
        );
      });
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

  // A reflected value is rebuilt member by member, so a payload
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

      test('a default reaches the rebuilt instance from either form', () {
        // Rebuilding calls the unnamed constructor with no arguments and then
        // assigns members, so a class whose defaults live on constructor
        // parameters gets them applied exactly as one whose defaults live on
        // the fields does — including for a member the payload omits, which is
        // the only case where the two forms could have differed.
        final original = ConstructorDefaultedPreference()..theme = 'dark';

        final encoded = TomUserPreferenceCodec.encodeValue(
          original,
          'ui.display',
        );
        final restored = decodeStored<ConstructorDefaultedPreference>(
          encoded,
          'ui.display',
        );

        expect(restored.theme, 'dark');
        expect(restored.fontSize, 14);
        expect(restored.compact, isFalse);

        final fromEmpty = decodeStored<ConstructorDefaultedPreference>(
          '{}',
          'ui.display',
        );
        expect(fromEmpty.theme, 'light');
        expect(fromEmpty.fontSize, 14);
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
      // Refused for want of a stored identity rather than at the
      // instantiation: a class the registry does not know has no name a
      // row could have been written under, so the read is answered before the
      // payload is even looked at.
      expect(
        () => decodeStored<UnreflectedPreference>('{"size":9}', 'ui.size'),
        throwsCodecKey('preferences.type.not_reflected'),
      );
    });
  });

  // The module's headline promise is that a mismatched read fails rather
  // than coerces. That holds only while no public entry point takes the text
  // alone: `decodeValue` is private, so every read states the type it
  // expects. These tests pin the cases a text-only entry point would let
  // slip past.
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

    test('a double preference whose stored text is integral still reads as a '
        'double', () {
      // The case the widening exists for, and — the refusal above being the
      // other one — the only case that reaches it. JSON writes `1.0` as `1`,
      // so a row a non-Dart client wrote for a `double` preference arrives
      // integral. The boundary lets it through on purpose: the read-side
      // predicate for `double` is `is num`, not `is double`. That makes the
      // widening the second half of one guarantee rather than a convenience,
      // and the halves are asserted together here because a boundary that
      // accepts a row the read then refuses stores successfully and fails on
      // another device.
      final stored = TomUserPreferenceDto(
        key: 'ui.scale',
        valueType: TomUserPreferenceCodec.doubleType,
        value: '14',
      );

      expect(
        () => TomUserPreferenceCodec.validateEncoded(
          stored.valueType,
          stored.value,
          key: stored.key,
        ),
        returnsNormally,
      );

      final value = TomUserPreferenceCodec.decode<double>(stored);
      expect(value, 14.0);
      // `14 == 14.0`, so the value alone would not tell the two apart.
      expect(value, isA<double>());
    });

    test(
      'the refusal names both types, so the caller knows which is wrong',
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
      },
    );
  });

  // Storing a non-scalar under `value.runtimeType.toString()` would use a
  // string the compiler owns rather than the program. It leaks private SDK
  // names, carries the generic instantiation, and is explicitly not
  // preserved by web minification, so a preference could be written under a
  // name no reader could ever ask for. The identity comes from the
  // reflection registry instead.
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
      // `typeNameOf` once answered `runtimeType.toString()`, and an SDK value's
      // runtime class is routinely private: a `Uri` is a `_SimpleUri`. `_Uri`
      // is not a type any caller can write, so such a row was unreadable by
      // construction the moment it was written — a silent write and a
      // permanent read failure. Refusing the write is the whole point.
      expect(
        () => TomUserPreferenceCodec.typeNameOf(Uri.parse('https://tom.dev/')),
        throwsCodecKey('preferences.type.not_reflected'),
      );
    });

    test('a generic value and its bare class literal reach the same name', () {
      // `runtimeType.toString()` gave `BoxPreference<int>` on the way out and
      // `BoxPreference<dynamic>` on the way back, so a generic preference
      // written by one half could never be read by the other. The registry
      // knows the class, not the instantiation.
      expect(
        TomUserPreferenceCodec.typeNameOf(BoxPreference<int>()),
        'BoxPreference',
      );
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
      // The by-type path consults the same table in the same order as the
      // by-value one, so the five names a `Type` resolves to are the five a
      // value resolves to. That is what lets a caller read a preference back
      // by type without knowing anything about how it was written.
      expect(
        TomUserPreferenceCodec.typeNameForType(String),
        TomUserPreferenceCodec.stringType,
      );
      expect(
        TomUserPreferenceCodec.typeNameForType(int),
        TomUserPreferenceCodec.intType,
      );
      expect(
        TomUserPreferenceCodec.typeNameForType(double),
        TomUserPreferenceCodec.doubleType,
      );
      expect(
        TomUserPreferenceCodec.typeNameForType(bool),
        TomUserPreferenceCodec.boolType,
      );
      expect(
        TomUserPreferenceCodec.typeNameForType(DateTime),
        TomUserPreferenceCodec.dateTimeType,
      );
    });

    test('the registry names a scalar exactly as its own row does', () {
      // The scalar table is consulted before the registry, and this is the
      // fact that makes that precedence invisible: a scalar falling through
      // to reflection would come back under the same string. So the ordering
      // cannot be caught by any behavioural test, and the agreement it rests
      // on is stated outright here instead — if the registry ever stopped
      // knowing a core scalar, or started naming one differently, the table
      // would stop being a fast path and become load-bearing, and this line
      // is what says so before a reader believes the ordering is free.
      for (final sample in <Object>[
        'dark',
        14,
        1.25,
        true,
        DateTime.utc(2026, 3, 4),
      ]) {
        expect(
          tomReflector.reflect(sample).type.simpleName,
          TomUserPreferenceCodec.typeNameOf(sample),
          reason:
              'the registry and the scalar table disagree about '
              '${sample.runtimeType}',
        );
      }
    });

    test('a reflected value still round-trips under its registry name', () {
      final stored = TomUserPreferenceCodec.encode(
        'ui.display',
        DisplayPreference()..fontSize = 18,
      );

      expect(stored.valueType, 'DisplayPreference');
      expect(
        TomUserPreferenceCodec.decode<DisplayPreference>(stored).fontSize,
        18,
      );
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

  // The two naming methods do not agree for every type either of them can
  // see, and cannot: `typeNameOf` asks a *value* what it is,
  // `typeNameForType` asks a *type*. Those are different questions wherever
  // the value's runtime class is not the type the caller wrote down.
  //
  // The divergence is inherent rather than accidental — it is not the
  // generic instantiation leaking into the stored name — so these tests
  // assert it rather than assert against it.
  group('TomUserPreferenceCodec — where the two naming methods diverge', () {
    test('they agree when the value is exactly the type asked about', () {
      // The ordinary case, and the reason the divergence below is easy to
      // miss: for a value stored under the class it is declared as, the
      // runtime answer and the static one are the same string.
      expect(
        TomUserPreferenceCodec.typeNameOf(BasePreference()),
        TomUserPreferenceCodec.typeNameForType(BasePreference),
      );
    });

    test(
      'a subclass value is named by its runtime class, not its supertype',
      () {
        // `typeNameOf` sees the instance, so it answers `SubPreference`.
        // `typeNameForType` can only see what it was handed. Both are correct
        // answers — to different questions.
        expect(
          TomUserPreferenceCodec.typeNameOf(SubPreference()),
          'SubPreference',
        );
        expect(
          TomUserPreferenceCodec.typeNameForType(BasePreference),
          'BasePreference',
        );
      },
    );

    test(
      'so a value stored as a subclass is not readable as its supertype',
      () {
        // The consequence, and the reason it is worth documenting rather than
        // repairing: reading a `SubPreference` row as a `BasePreference` would
        // silently drop the members only the subclass declares, so refusing is
        // the intended strictness. Store a preference under the class it is
        // declared as.
        final stored = TomUserPreferenceCodec.encode(
          'ui.pref',
          SubPreference(),
        );

        expect(stored.valueType, 'SubPreference');
        expect(
          () => TomUserPreferenceCodec.decode<BasePreference>(stored),
          throwsCodecKey('preferences.decode.type_mismatch'),
        );
        expect(
          TomUserPreferenceCodec.decode<SubPreference>(stored).label,
          'sub',
        );
      },
    );

    test('an instantiated generic type has no stored identity of its own', () {
      // The registry is keyed by *declaration*: it holds an entry for
      // `BoxPreference` and none for `BoxPreference<int>`. `typeNameOf` gets
      // past that because it resolves from the instance, which the registry
      // can match against its generic entries; a bare `Type` offers no route
      // back to the declaration, so this is the one shape where the value side
      // answers and the type side cannot.
      expect(
        () => TomUserPreferenceCodec.typeNameForType(BoxPreference<int>),
        throwsCodecKey('preferences.type.not_reflected'),
      );
    });

    test('a generic preference is read back under its bare class literal', () {
      // The practical consequence of the previous test. The instantiation is
      // deliberately not part of the stored name, so it is not part of what
      // comes back either: `decode<BoxPreference>` is the spelling that works,
      // and it returns a `BoxPreference<dynamic>`.
      final stored = TomUserPreferenceCodec.encode(
        'ui.box',
        BoxPreference<int>()..count = 7,
      );

      expect(stored.valueType, 'BoxPreference');
      expect(TomUserPreferenceCodec.decode<BoxPreference>(stored).count, 7);
    });
  });

  // The library dartdoc names "an enum written as its index" as one of the
  // two conventions the codec exists to settle, so it has to settle it. An
  // annotated enum falling into the reflected branch is worse than being
  // unsupported: `encode` writes `{}` — the chosen constant simply gone —
  // `validateEncoded` passes that row, and the read then throws a raw
  // `ReflectionNoSuchMethodError`, which is not the exception type the
  // module tells callers to catch.
  group('TomUserPreferenceCodec — an enum is stored by name', () {
    test('an enum round-trips', () {
      final stored = TomUserPreferenceCodec.encode(
        'ui.theme',
        ThemePreference.dark,
      );

      expect(stored.valueType, 'ThemePreference');
      expect(
        TomUserPreferenceCodec.decode<ThemePreference>(stored),
        ThemePreference.dark,
      );
    });

    test('the stored text carries the constant name, never its index', () {
      // The whole point of the convention. An index is positional, so
      // inserting a constant silently changes what every already-stored
      // preference means; the name does not move. `highContrast` is at index 2
      // today, and the assertion is that 2 appears nowhere.
      final stored = TomUserPreferenceCodec.encode(
        'ui.theme',
        ThemePreference.highContrast,
      );

      expect(jsonDecode(stored.value), {'name': 'highContrast'});
      expect(stored.value, isNot(contains('2')));
    });

    test('a stored enum passes the boundary check', () {
      // `validateEncoded` works from the two strings alone, without reflecting
      // the type — deliberately, so a server can store a preference type only
      // the client knows. That is why an enum is stored as a JSON object like
      // every other non-scalar: it needs no new branch here, and the rule "a
      // non-scalar value is a JSON object" stays universally true.
      final stored = TomUserPreferenceCodec.encode(
        'ui.theme',
        ThemePreference.dark,
      );

      expect(
        () => TomUserPreferenceCodec.validateEncoded(
          stored.valueType,
          stored.value,
          key: stored.key,
        ),
        returnsNormally,
      );
    });

    test('every constant of an enum survives the round trip', () {
      for (final value in ThemePreference.values) {
        expect(
          TomUserPreferenceCodec.decode<ThemePreference>(
            TomUserPreferenceCodec.encode('ui.theme', value),
          ),
          value,
          reason: 'ThemePreference.${value.name}',
        );
      }
    });

    test('an overridden toString does not affect the stored form', () {
      // `TomObservableEnum.enumTypeSegment` reads the declared type name back
      // out of `Enum.toString()` and rejects an enum that overrides it. The
      // codec takes the type name from the registry and the constant from
      // `Enum.name`, so an override is simply irrelevant here — worth pinning,
      // because the two mechanisms sit in the same package and only one of
      // them cares.
      expect(RenamedPreference.second.toString(), 'custom(second)');

      final stored = TomUserPreferenceCodec.encode(
        'ui.renamed',
        RenamedPreference.second,
      );

      expect(stored.valueType, 'RenamedPreference');
      expect(jsonDecode(stored.value), {'name': 'second'});
      expect(
        TomUserPreferenceCodec.decode<RenamedPreference>(stored),
        RenamedPreference.second,
      );
    });

    test('one enum is not readable as another', () {
      final stored = TomUserPreferenceCodec.encode(
        'ui.theme',
        ThemePreference.dark,
      );

      expect(
        () => TomUserPreferenceCodec.decode<DensityPreference>(stored),
        throwsCodecKey('preferences.decode.type_mismatch'),
      );
    });

    test(
      'an unannotated enum is refused, with advice that can be followed',
      () {
        // The rule is the one every non-scalar already follows, so there is no
        // separate thing to learn: annotate it. The refusal comes while naming
        // the value — the call that cannot answer — rather than one call later
        // from `encodeValue`, whose message would tell the caller to annotate a
        // class, advice an enum cannot act on.
        expect(
          () => TomUserPreferenceCodec.typeNameOf(
            UnreflectedThemePreference.dark,
            'ui.theme',
          ),
          throwsCodecKey('preferences.type.not_reflected'),
        );
        expect(
          () => TomUserPreferenceCodec.encode(
            'ui.theme',
            UnreflectedThemePreference.dark,
          ),
          throwsCodecKey('preferences.type.not_reflected'),
        );
      },
    );

    test('a constant that no longer exists is refused, not defaulted', () {
      // The failure a released application actually meets: the row was written
      // by a version whose enum had a constant this one has dropped. Answering
      // `values.first` would hand back a setting the user never chose, so it
      // is refused instead — and the message names the constant and the ones
      // that do exist, because that is what identifies which release wrote it.
      final stored = TomUserPreferenceDto(
        key: 'ui.theme',
        valueType: 'ThemePreference',
        value: jsonEncode({'name': 'solarized'}),
      );

      expect(
        () => TomUserPreferenceCodec.decode<ThemePreference>(stored),
        throwsCodecKey('preferences.decode.unknown_enum_constant'),
      );
    });

    test('an enum row that carries no constant name is refused', () {
      // Exactly the row the old encoder wrote: `{}`. It was stored happily and
      // only failed at the read, with an exception the module does not tell
      // callers to catch. It is still refused — it names no constant — but now
      // as a codec exception, and no writer produces it any more.
      final stored = TomUserPreferenceDto(
        key: 'ui.theme',
        valueType: 'ThemePreference',
        value: '{}',
      );

      expect(
        () => TomUserPreferenceCodec.decode<ThemePreference>(stored),
        throwsCodecKey('preferences.decode.unknown_enum_constant'),
      );
    });

    test(
      'a read that reflection cannot complete still fails as a codec error',
      () {
        // Found by the enum work rather than sought: the old enum read escaped
        // as a raw `ReflectionNoSuchMethodError`, because the reflected branch
        // did not wrap its instantiation. Removing the enum cause would have
        // left the same leak open for a class, which this pins shut — the module
        // promises a single exception type and this is the last path that broke
        // it.
        final stored = TomUserPreferenceCodec.encode(
          'ui.constructed',
          ConstructedPreference(3),
        );

        expect(
          () => TomUserPreferenceCodec.decode<ConstructedPreference>(stored),
          throwsCodecKey('preferences.decode.failed'),
        );
      },
    );
  });

  // A list of strings — pinned items, recent files, enabled feature
  // names — is one of the most ordinary preferences there is, and it had no
  // path through the codec: `List` and `Map` are not scalars, so they fell
  // into the reflected branch and `convertToJsonString` could not serialize
  // them. The failure also arrived one call late, `typeNameOf` having already
  // answered `List<int>`, which reads as support.
  group('TomUserPreferenceCodec — a collection of scalars is a value', () {
    test('a List<String> round-trips', () {
      final stored = TomUserPreferenceCodec.encode('ui.pinned', <String>[
        'alpha',
        'beta',
      ]);

      expect(stored.valueType, 'List<String>');
      expect(TomUserPreferenceCodec.decode<List<String>>(stored), [
        'alpha',
        'beta',
      ]);
    });

    test('a Map<String, String> round-trips', () {
      final stored = TomUserPreferenceCodec.encode(
        'ui.labels',
        <String, String>{'home': 'Start', 'away': 'Guest'},
      );

      expect(stored.valueType, 'Map<String, String>');
      expect(TomUserPreferenceCodec.decode<Map<String, String>>(stored), {
        'home': 'Start',
        'away': 'Guest',
      });
    });

    test('the stored text is a plain JSON array, with no wrapper', () {
      // Unlike an enum, a collection needs no envelope: an array and an object
      // are JSON's own shapes, and the element type is already in the stored
      // name. A wrapper would only be a second thing for a non-Dart client to
      // know about.
      final stored = TomUserPreferenceCodec.encode('ui.sizes', <int>[10, 20]);

      expect(stored.value, '[10,20]');
      expect(
        TomUserPreferenceCodec.encode('ui.labels', <String, int>{'a': 1}).value,
        '{"a":1}',
      );
    });

    test('every scalar element type round-trips, in a list and in a map', () {
      // The rule is "elements are scalars", with no sub-exception, so each of
      // the five is asserted rather than a representative one.
      expect(
        TomUserPreferenceCodec.decode<List<String>>(
          TomUserPreferenceCodec.encode('ui.v', <String>['a']),
        ),
        ['a'],
      );
      expect(
        TomUserPreferenceCodec.decode<List<int>>(
          TomUserPreferenceCodec.encode('ui.v', <int>[1]),
        ),
        [1],
      );
      expect(
        TomUserPreferenceCodec.decode<List<double>>(
          TomUserPreferenceCodec.encode('ui.v', <double>[1.5]),
        ),
        [1.5],
      );
      expect(
        TomUserPreferenceCodec.decode<List<bool>>(
          TomUserPreferenceCodec.encode('ui.v', <bool>[true, false]),
        ),
        [true, false],
      );
      expect(
        TomUserPreferenceCodec.decode<Map<String, bool>>(
          TomUserPreferenceCodec.encode('ui.v', <String, bool>{'a': true}),
        ),
        {'a': true},
      );
      expect(
        TomUserPreferenceCodec.decode<Map<String, double>>(
          TomUserPreferenceCodec.encode('ui.v', <String, double>{'a': 1.5}),
        ),
        {'a': 1.5},
      );
    });

    test('an empty list keeps the element type it was declared with', () {
      // The element type comes from the value's own type argument, so an empty
      // `<String>[]` still says what it is. A bare `[]` does not, and is
      // refused — see the untyped-collection test below.
      final stored = TomUserPreferenceCodec.encode('ui.pinned', <String>[]);

      expect(stored.valueType, 'List<String>');
      expect(stored.value, '[]');
      expect(TomUserPreferenceCodec.decode<List<String>>(stored), isEmpty);
    });

    test('the zone rule reaches inside a collection', () {
      // A DateTime element is a DateTime, so the promise [dateTimeType] makes
      // has to hold one level down too — otherwise the same value means a
      // different instant per device as soon as it is put in a list.
      final local = DateTime.utc(2026, 3, 4, 5, 6, 7).toLocal();
      final stored = TomUserPreferenceCodec.encode('ui.recent', <DateTime>[
        local,
      ]);

      expect(stored.valueType, 'List<DateTime>');
      expect(stored.value, contains('Z'));

      final decoded = TomUserPreferenceCodec.decode<List<DateTime>>(stored);
      expect(decoded.single.isAtSameMomentAs(local), isTrue);
      expect(decoded.single.isUtc, isTrue);
    });

    test('a stored collection passes the boundary check', () {
      // The check the server runs, and the reason collections are worth having
      // as a shape of their own: the element type is *in* the stored name, so
      // the boundary can verify the whole value without reflecting anything —
      // which it cannot do for a reflected class.
      for (final value in <Object>[
        <String>['a'],
        <int>[1],
        <String, bool>{'a': true},
        <String, DateTime>{'a': DateTime.utc(2026)},
      ]) {
        final stored = TomUserPreferenceCodec.encode('ui.v', value);
        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            stored.valueType,
            stored.value,
            key: stored.key,
          ),
          returnsNormally,
          reason: stored.valueType,
        );
      }
    });

    test('the boundary refuses an element of the wrong type', () {
      expect(
        () => TomUserPreferenceCodec.validateEncoded(
          'List<int>',
          '[1, "two"]',
          key: 'ui.sizes',
        ),
        throwsCodecKey('preferences.encoded.type_mismatch'),
      );
      expect(
        () => TomUserPreferenceCodec.validateEncoded(
          'Map<String, int>',
          '{"a": true}',
          key: 'ui.sizes',
        ),
        throwsCodecKey('preferences.encoded.type_mismatch'),
      );
    });

    test('the boundary refuses a zoneless timestamp inside a collection', () {
      // The one check that would have been easy to leave at the top level.
      // A row of instants is exactly as ambiguous as a single one.
      expect(
        () => TomUserPreferenceCodec.validateEncoded(
          'List<DateTime>',
          '["2026-03-04T05:06:07Z", "2026-03-04T05:06:07"]',
          key: 'ui.recent',
        ),
        throwsCodecKey('preferences.encoded.not_an_instant'),
      );
    });

    test('a declared List<double> reads an integral array back as doubles', () {
      // The widening the scalar path already allows, applied one level down:
      // JSON writes 1.0 as 1, so a row a non-Dart client wrote is integral
      // even though the preference is a list of doubles.
      expect(decodeStored<List<double>>('[1, 2]', 'ui.scales'), [1.0, 2.0]);
    });

    test('a collection is not readable as a collection of another type', () {
      final stored = TomUserPreferenceCodec.encode('ui.v', <String>['1']);

      expect(
        () => TomUserPreferenceCodec.decode<List<int>>(stored),
        throwsCodecKey('preferences.decode.type_mismatch'),
      );
      expect(
        () => TomUserPreferenceCodec.decode<Map<String, String>>(stored),
        throwsCodecKey('preferences.decode.type_mismatch'),
      );
    });

    test('the two naming methods agree about a collection', () {
      // The property that makes the halves symmetric: a value can be written
      // under a name exactly when it can be read back under it.
      expect(
        TomUserPreferenceCodec.typeNameOf(<String>['a']),
        TomUserPreferenceCodec.typeNameForType(List<String>),
      );
      expect(
        TomUserPreferenceCodec.typeNameOf(<String, DateTime>{}),
        TomUserPreferenceCodec.typeNameForType(Map<String, DateTime>),
      );
    });

    test('the composed name owes nothing to the compiler rendering', () {
      // The value that used to prove collections were unstorable: a map
      // literal's runtime class is `_Map`, a private name no caller can write,
      // so `runtimeType.toString()` could never have named this row. The name
      // is composed from the codec's own constants instead, which is what makes
      // a collection storable on the same terms a scalar is.
      final value = <String, int>{'a': 1};

      expect(value.runtimeType.toString(), isNot('Map<String, int>'));
      expect(TomUserPreferenceCodec.typeNameOf(value), 'Map<String, int>');
      expect(
        TomUserPreferenceCodec.decode<Map<String, int>>(
          TomUserPreferenceCodec.encode('ui.counts', value),
        ),
        value,
      );
    });

    test('an untyped or mixed collection is refused, and the message says '
        'what is allowed', () {
      // The restriction is real and has to be stated where it is met. Before
      // this the advice was "annotate it with @tomReflector", which a
      // `List<Object>` cannot act on.
      for (final value in <Object>[
        <Object>['a', 1],
        <dynamic>[],
        <int, String>{1: 'a'},
        <String, Object>{
          'a': <String>['nested'],
        },
        <String>{'a'},
      ]) {
        expect(
          () => TomUserPreferenceCodec.typeNameOf(value, 'ui.v'),
          throwsCodecKey('preferences.type.unsupported_collection'),
          reason: '${value.runtimeType}',
        );
      }

      Object? message;
      try {
        TomUserPreferenceCodec.typeNameOf(<Object>['a', 1], 'ui.v');
      } on TomUserPreferenceCodecException catch (error) {
        message = error.defaultUserMessage;
      }
      expect(message, contains('List'));
      expect(message, contains('Map<String'));
      expect(message, contains('DateTime'));
    });

    test(
      'a list of reflected objects is refused rather than half-supported',
      () {
        // Tempting to allow, and deliberately not: the read would have to build
        // each element from a class named nowhere in the stored type, and
        // `decode<List<DisplayPreference>>` has no route from its type argument
        // back to the registry entry. A reflected class whose *member* is a list
        // is the supported way to store this.
        expect(
          () => TomUserPreferenceCodec.encode(
            'ui.displays',
            <DisplayPreference>[DisplayPreference()],
          ),
          throwsCodecKey('preferences.type.unsupported_collection'),
        );
      },
    );
  });

  // The key is a URL path segment, so it is not free text. These tests hold
  // the rule that says what it may be, and the reasons for its two least
  // obvious clauses — the leading letter and the ASCII restriction.
  group('TomUserPreferenceKeys — a key has to survive being a path segment', () {
    test('the framework\'s own keys satisfy the rule', () {
      // A rule its author's own vocabulary fails is a rule that gets an
      // exception list, and then a second one.
      for (final key in <String>[
        TomUserPreferenceKeys.timezone,
        TomUserPreferenceKeys.language,
        TomUserPreferenceKeys.country,
        TomUserPreferenceKeys.theme,
      ]) {
        expect(TomUserPreferenceKeys.isValid(key), isTrue, reason: key);
      }
    });

    test('an ordinary application key is accepted', () {
      for (final key in <String>[
        'ui.theme',
        'device.lastAccount',
        'forge.layout.sidebarWidth',
        'count',
        'a',
        'a_b-c.d0',
        'A' * TomUserPreferenceKeys.maxLength,
      ]) {
        expect(TomUserPreferenceKeys.isValid(key), isTrue, reason: key);
      }
    });

    test('an empty key is refused, because it addresses the list endpoint', () {
      // Not a contrived input: it is what TomUserPreferenceKeyRequest()'s own
      // default produces, so any caller that forgets to set one sends it.
      expect(TomUserPreferenceKeys.isValid(''), isFalse);
      expect(() => TomUserPreferenceKeys.validate(''), throwsKeyCause('empty'));
    });

    test('a key containing a separator is refused', () {
      // `a/b` percent-encodes to `a%2Fb`, which a large share of HTTP
      // infrastructure rejects or silently normalises back to a `/` — at which
      // point the request addresses a path the API never declared.
      for (final key in <String>['a/b', 'a\\b', 'a?b', 'a#b', 'a%2Fb', 'a:b']) {
        expect(TomUserPreferenceKeys.isValid(key), isFalse, reason: key);
      }
      expect(
        () => TomUserPreferenceKeys.validate('a/b'),
        throwsKeyCause('illegal_character'),
      );
    });

    test('a key containing whitespace is refused', () {
      for (final key in <String>['has space', 'tab\tkey', 'line\nkey', 'a ']) {
        expect(TomUserPreferenceKeys.isValid(key), isFalse, reason: key);
      }
    });

    test('a dot-only key is refused, and that is why a key starts with a '
        'letter', () {
      // The strongest case for the leading-letter clause. Measured against the
      // contract's own endpoint: `..` is consumed by URI resolution itself, so
      // the request leaves the API's path entirely rather than merely
      // addressing an odd key, and `.` collapses to the list endpoint's URI
      // exactly as an empty key does.
      for (final key in <String>['.', '..', '...']) {
        expect(TomUserPreferenceKeys.isValid(key), isFalse, reason: key);
      }
      expect(
        () => TomUserPreferenceKeys.validate('..'),
        throwsKeyCause('leading_character'),
      );
    });

    test('a key starting with a digit, dot, dash or underscore is refused', () {
      for (final key in <String>['1key', '.key', '-key', '_key']) {
        expect(TomUserPreferenceKeys.isValid(key), isFalse, reason: key);
      }
    });

    test(
      'a non-ASCII key is refused, because two spellings can look the same',
      () {
        // The module's opening problem, one layer down: `ü` has a composed and a
        // decomposed Unicode form that render identically, so one visible key
        // can be two stored keys — the silent split the vocabulary exists to
        // prevent, and one no reader would ever see in a diff.
        final composed = 'grüsse'; // ü as one code point
        final decomposed = 'grüsse'; // u + combining diaeresis

        expect(composed == decomposed, isFalse);
        expect(TomUserPreferenceKeys.isValid(composed), isFalse);
        expect(TomUserPreferenceKeys.isValid(decomposed), isFalse);
        expect(TomUserPreferenceKeys.isValid('日本語'), isFalse);
      },
    );

    test('a key longer than the stored column is refused', () {
      // 191 is not arbitrary: it is `tom_user_preference.preference_key`'s
      // width. A longer key is one the server would silently truncate, and two
      // keys that differ past the cut would become one row.
      final tooLong = 'a' * (TomUserPreferenceKeys.maxLength + 1);

      expect(TomUserPreferenceKeys.isValid(tooLong), isFalse);
      expect(
        () => TomUserPreferenceKeys.validate(tooLong),
        throwsKeyCause('too_long'),
      );
    });

    test('the refusal names the key and the rule', () {
      // The message has to be actionable from the exception alone: the caller
      // is often a constant three files away from the call that failed.
      expect(
        () => TomUserPreferenceKeys.validate('a/b'),
        throwsA(
          isA<TomUserPreferenceKeyException>()
              .having((error) => error.key, 'key', 'preferences.key.invalid')
              .having(
                (error) => error.parameters?['key'],
                'parameters.key',
                'a/b',
              )
              .having(
                (error) => error.defaultUserMessage,
                'defaultUserMessage',
                allOf(contains("'a/b'"), contains('/')),
              ),
        ),
      );
    });

    test('encode refuses to build a DTO under an illegal key', () {
      // The write path's first gate. A DTO is the addressed artifact, so a key
      // that cannot be addressed must not reach one — the alternative is a
      // value encoded successfully and then unstorable.
      expect(
        () => TomUserPreferenceCodec.encode('a/b', 'dark'),
        throwsKeyCause('illegal_character'),
      );
      expect(
        () => TomUserPreferenceCodec.encode('', 'dark'),
        throwsKeyCause('empty'),
      );
    });

    test('the value-only entry points still take no key at all', () {
      // `typeNameOf` and `encodeValue` take an *optional* key that only names
      // the preference in an exception, and '' there means "not decided yet",
      // not "the empty key". Validating it would refuse the documented way to
      // encode a value before choosing where to put it.
      expect(TomUserPreferenceCodec.typeNameOf('dark'), 'String');
      expect(TomUserPreferenceCodec.encodeValue('dark'), '"dark"');
    });
  });

  group('TomUserPreferenceCodec — a scalar round-trips through the DTO', () {
    // `encodeValue` is asserted on its own above, but a round trip is a
    // different claim: that the name `encode` writes is the name `decode`
    // demands. Two methods that each work in isolation and disagree on one
    // type name store successfully and fail every read of that key.
    test('a String', () {
      final dto = TomUserPreferenceCodec.encode('ui.theme', 'dark');
      expect(dto.valueType, TomUserPreferenceCodec.stringType);
      expect(dto.value, '"dark"');
      expect(TomUserPreferenceCodec.decode<String>(dto), 'dark');
    });

    test('an int', () {
      final dto = TomUserPreferenceCodec.encode('ui.font_size', 14);
      expect(dto.valueType, TomUserPreferenceCodec.intType);
      expect(dto.value, '14');
      expect(TomUserPreferenceCodec.decode<int>(dto), 14);
    });

    test('a double', () {
      final dto = TomUserPreferenceCodec.encode('ui.scale', 1.25);
      expect(dto.valueType, TomUserPreferenceCodec.doubleType);
      expect(dto.value, '1.25');
      expect(TomUserPreferenceCodec.decode<double>(dto), 1.25);
    });

    test('a bool', () {
      final dto = TomUserPreferenceCodec.encode('ui.compact', true);
      expect(dto.valueType, TomUserPreferenceCodec.boolType);
      expect(dto.value, 'true');
      expect(TomUserPreferenceCodec.decode<bool>(dto), isTrue);
    });

    test('every scalar a write can produce is one a read accepts', () {
      // A scalar is described in one place by two predicates asked on
      // opposite sides of the column: one of a live Dart value on the way in,
      // one of decoded JSON on the way out. When they disagree the write
      // still succeeds — the failure surfaces only at the next read, which is
      // typically on another device — so the loop is closed here instead.
      final samples = <Object>[
        'dark',
        14,
        1.25,
        true,
        DateTime.utc(2026, 3, 4),
      ];

      // Keyed to `scalarTypes` and not to a literal, so that a scalar added
      // to the codec without a sample here fails this line rather than
      // quietly going untested. It pins the write side at the same time: the
      // names must come out in the published order, which they only do if
      // each sample is claimed by its own row and by no earlier one.
      expect(
        samples.map(TomUserPreferenceCodec.typeNameOf).toList(),
        TomUserPreferenceCodec.scalarTypes,
        reason: 'the samples must cover every scalar, in the published order',
      );

      for (final sample in samples) {
        final dto = TomUserPreferenceCodec.encode('ui.sample', sample);
        expect(
          () => TomUserPreferenceCodec.validateEncoded(
            dto.valueType,
            dto.value,
            key: dto.key,
          ),
          returnsNormally,
          reason: '${dto.valueType} can be written but not read back',
        );

        // A caller who reads a preference back by type never presents a
        // value, so that path names the scalar from the `Type` alone. It has
        // to arrive at the name the write side chose, or the read looks for a
        // `valueType` no write produces.
        expect(
          TomUserPreferenceCodec.typeNameForType(sample.runtimeType),
          dto.valueType,
          reason: 'naming ${sample.runtimeType} by type and by value disagree',
        );
      }
    });

    test('int is published before double, because the web needs it so', () {
      // On the web an integral `double` answers to `is int` — both are JS
      // numbers and the test is one of integrality — so the first matching
      // row decides the stored name, and swapping these two would change
      // what an entire platform writes. On the VM they are disjoint types
      // and the order is free, which is why no behavioural test in this
      // suite can catch a reorder and this one states the order outright.
      expect(
        TomUserPreferenceCodec.scalarTypes.indexOf(
          TomUserPreferenceCodec.intType,
        ),
        lessThan(
          TomUserPreferenceCodec.scalarTypes.indexOf(
            TomUserPreferenceCodec.doubleType,
          ),
        ),
      );
    });

    test('the DTO carries the key it was encoded under', () {
      expect(TomUserPreferenceCodec.encode('ui.theme', 'dark').key, 'ui.theme');
    });

    test('the timestamp is passed through, never invented', () {
      // *When* a preference was written is the store's answer. An `updatedAt`
      // defaulted to `now` here would be a claim about a row that has not been
      // written yet, and it would be indistinguishable from the real one.
      final writtenAt = DateTime.utc(2026, 3, 4, 5, 6, 7);
      expect(
        TomUserPreferenceCodec.encode(
          'ui.theme',
          'dark',
          updatedAt: writtenAt,
        ).updatedAt,
        writtenAt,
      );
      expect(
        TomUserPreferenceCodec.encode('ui.theme', 'dark').updatedAt,
        isNull,
      );
    });
  });

  group('TomUserPreferenceCodec — text that is not JSON is refused', () {
    test('a write whose value is not JSON never reaches the store', () {
      expect(
        () => TomUserPreferenceCodec.validateEncoded(
          TomUserPreferenceCodec.stringType,
          '{oops',
          key: 'ui.theme',
        ),
        throwsCodecKey('preferences.encoded.invalid_json'),
      );
    });

    test('the write-side refusal names the preference and the type', () {
      // Both, because neither alone is actionable: the key says which row to
      // look at and the declared type says what the text was supposed to be.
      expect(
        () => TomUserPreferenceCodec.validateEncoded(
          TomUserPreferenceCodec.intType,
          'oops',
          key: 'ui.font_size',
        ),
        throwsA(
          isA<TomUserPreferenceCodecException>()
              .having(
                (error) => error.key,
                'key',
                'preferences.encoded.invalid_json',
              )
              .having(
                (error) => error.parameters?['key'],
                'parameters.key',
                'ui.font_size',
              )
              .having(
                (error) => error.parameters?['valueType'],
                'parameters.valueType',
                'int',
              )
              .having(
                (error) => error.rootException,
                'rootException',
                isA<FormatException>(),
              ),
        ),
      );
    });

    test('a stored row that is not JSON is refused on the way out too', () {
      // The same text, a different moment and so a different key: a write can
      // still be rejected, whereas a row already in the store can only be
      // reported. Collapsing the two would hide which of the halves let it
      // through.
      expect(
        () => decodeStored<String>('{oops', 'ui.theme'),
        throwsCodecKey('preferences.decode.invalid_json'),
      );
    });

    test('the read-side refusal names the preference', () {
      expect(
        () => decodeStored<int>('12,', 'ui.font_size'),
        throwsA(
          isA<TomUserPreferenceCodecException>()
              .having(
                (error) => error.key,
                'key',
                'preferences.decode.invalid_json',
              )
              .having(
                (error) => error.parameters?['key'],
                'parameters.key',
                'ui.font_size',
              )
              .having(
                (error) => error.rootException,
                'rootException',
                isA<FormatException>(),
              ),
        ),
      );
    });

    test('a reflected row reports malformed text the same way', () {
      // The JSON check is ahead of the reflection branch, so a class row and a
      // scalar row agree on what "this is not JSON" is called. Reached through
      // the class path it would otherwise surface as a failed construction,
      // which blames the class for the store's text.
      expect(
        () => TomUserPreferenceCodec.decode<DisplayPreference>(
          TomUserPreferenceDto(
            key: 'ui.display',
            valueType: TomUserPreferenceCodec.typeNameForType(
              DisplayPreference,
            ),
            value: '{',
          ),
        ),
        throwsCodecKey('preferences.decode.invalid_json'),
      );
    });
  });

  group('the preference wire DTOs', () {
    test('a DTO carries key, declared type, value and timestamp', () {
      final dto = TomUserPreferenceDto(
        key: TomUserPreferenceKeys.timezone,
        valueType: TomUserPreferenceCodec.stringType,
        value: '"Europe/Berlin"',
        updatedAt: DateTime.utc(2026, 3, 4, 5, 6, 7),
      );

      expect(dto.key, 'tom.timezone');
      expect(dto.valueType, 'String');
      expect(dto.value, '"Europe/Berlin"');
      // Given a UTC input this says nothing about the zone — the normalising
      // is asserted below, on a local one. It is here to show the timestamp
      // arrives intact alongside the other three fields.
      expect(dto.updatedAt, DateTime.utc(2026, 3, 4, 5, 6, 7));
    });

    test('a local timestamp is stored as the UTC instant it names', () {
      // The field is documented as UTC, and a `DateTime` cannot carry that
      // promise by type — a server writing `DateTime.now()` instead of
      // `DateTime.now().toUtc()` satisfies every check. The normalisation is
      // therefore the DTO's job, not the writer's, and it happens for every
      // route into the field: the constructor here, the setter below, and the
      // reflection path that rebuilds a DTO off the wire.
      final local = DateTime(2026, 3, 4, 5, 6, 7);
      final dto = TomUserPreferenceDto(updatedAt: local);

      expect(dto.updatedAt!.isUtc, isTrue);
      expect(dto.updatedAt, local.toUtc());
      // Normalised, not reinterpreted: the moment is the same one.
      expect(
        dto.updatedAt!.millisecondsSinceEpoch,
        local.millisecondsSinceEpoch,
      );
    });

    test('a directly assigned timestamp is not intercepted', () {
      // The seam, stated so that nobody reads the constructor above and
      // concludes the field self-normalises. A wire DTO's fields are plain
      // and public (G-DTO) — reflection fills them by setter — so there is no
      // accessor to hook, and giving this one a private backing field would
      // change the shape every generated mirror of this class was built
      // against. The constructor is therefore the whole of the guarantee, and
      // it is enough because every DTO the framework produces comes from it.
      final dto = TomUserPreferenceDto()
        ..updatedAt = DateTime(2026, 3, 4, 5, 6, 7);

      expect(dto.updatedAt!.isUtc, isFalse);
    });

    test('a timestamp survives the wire as the instant it was', () {
      // The reason the promise has to be kept rather than documented away.
      // Reflection writes a `DateTime` with `toIso8601String()`, which emits
      // no zone marker for a local one, and reads it back with
      // `DateTime.parse`, which then reads a zoneless string as the *reading*
      // device's local time. So a local timestamp would not merely arrive
      // unconverted — its offset would be destroyed in transit and the
      // instant would silently shift by the difference between the two
      // machines, with nothing left for a receiving caller to convert from.
      // The constructor is what stops that: by the time anything is
      // serialized the field is UTC, so the text carries a zone marker.
      final dto = TomUserPreferenceDto(
        key: 'ui.theme',
        valueType: TomUserPreferenceCodec.stringType,
        value: storedText('dark'),
        updatedAt: DateTime(2026, 3, 4, 5, 6, 7),
      );

      final json = tomReflectionInfo.convertToJsonString(dto);
      final restored =
          tomReflectionInfo.createInstanceFromJson(
                tomReflector.reflectType(TomUserPreferenceDto) as ClassMirror,
                jsonDecode(json) as Map<String, dynamic>,
              )
              as TomUserPreferenceDto;

      expect(restored.updatedAt!.isUtc, isTrue);
      expect(
        restored.updatedAt!.millisecondsSinceEpoch,
        dto.updatedAt!.millisecondsSinceEpoch,
      );
    });

    test('every field defaults, because reflection fills a blank one', () {
      // The reflection path instantiates the DTO with no arguments and then
      // writes member by member, so a required field would make the wire type
      // unconstructible on the way in.
      final blank = TomUserPreferenceDto();
      expect(blank.key, isEmpty);
      expect(blank.valueType, isEmpty);
      expect(blank.value, isEmpty);
      expect(blank.updatedAt, isNull);
      expect(TomUserPreferenceWriteRequest().key, isEmpty);
      expect(TomUserPreferenceKeyRequest().key, isEmpty);
    });

    test('the write request is the result minus the timestamp', () {
      final request = TomUserPreferenceWriteRequest(
        key: TomUserPreferenceKeys.timezone,
        valueType: TomUserPreferenceCodec.stringType,
        value: '"Europe/Berlin"',
      );

      expect(request.key, 'tom.timezone');
      expect(request.valueType, 'String');
      expect(request.value, '"Europe/Berlin"');
    });

    test('each DTO names itself and its type in one line', () {
      // These end up in logs beside a failing write, where the useful pair is
      // which preference and what it claimed to be — not the value, which may
      // be long and is often the user's.
      expect(
        TomUserPreferenceDto(
          key: 'tom.theme',
          valueType: 'String',
          value: '"dark"',
        ).toString(),
        'TomUserPreferenceDto(tom.theme: String)',
      );
      expect(
        TomUserPreferenceWriteRequest(
          key: 'tom.theme',
          valueType: 'String',
        ).toString(),
        'TomUserPreferenceWriteRequest(tom.theme: String)',
      );
      expect(
        TomUserPreferenceKeyRequest(key: 'tom.theme').toString(),
        'TomUserPreferenceKeyRequest(tom.theme)',
      );
    });
  });

  group('tomUserPreferencesApi — the contract both halves bind to', () {
    test('the API is mounted at /preferences under its own id', () {
      expect(tomUserPreferencesApi.id, tomUserPreferencesApiId);
      expect(tomUserPreferencesApiId, 'tomUserPreferences');
      expect(tomUserPreferencesApi.uri, '/preferences');
    });

    test('it declares exactly the four endpoints its ids name', () {
      expect(
        tomUserPreferencesApi.endpoints.keys,
        unorderedEquals(<String>[
          tomUserPreferencesListEndpointId,
          tomUserPreferencesReadEndpointId,
          tomUserPreferencesWriteEndpointId,
          tomUserPreferencesDeleteEndpointId,
        ]),
      );
    });

    test('the endpoint ids are the literal text the server restates', () {
      // The server's `@TomApiEndpointImplementation(endpointId: …)` names these
      // as strings. Renaming a constant compiles on both sides and leaves the
      // handler bound to nothing, so the literals are pinned here.
      expect(tomUserPreferencesListEndpointId, 'listPreferences');
      expect(tomUserPreferencesReadEndpointId, 'readPreference');
      expect(tomUserPreferencesWriteEndpointId, 'writePreference');
      expect(tomUserPreferencesDeleteEndpointId, 'deletePreference');
    });

    test('each endpoint states its method and its address', () {
      final api = tomUserPreferencesApi;

      expect(api[tomUserPreferencesListEndpointId].method, TomHttpMethod.get);
      expect(api[tomUserPreferencesListEndpointId].uri, '');
      expect(api[tomUserPreferencesReadEndpointId].method, TomHttpMethod.get);
      expect(api[tomUserPreferencesReadEndpointId].uri, '/{key}');
      expect(api[tomUserPreferencesWriteEndpointId].method, TomHttpMethod.put);
      expect(
        api[tomUserPreferencesDeleteEndpointId].method,
        TomHttpMethod.delete,
      );
      expect(api[tomUserPreferencesDeleteEndpointId].uri, '/{key}');
    });

    test('each endpoint states the request type it reads', () {
      final api = tomUserPreferencesApi;

      expect(api[tomUserPreferencesListEndpointId].requestTypes, isEmpty);
      expect(api[tomUserPreferencesReadEndpointId].requestTypes, [
        TomUserPreferenceKeyRequest,
      ]);
      expect(api[tomUserPreferencesWriteEndpointId].requestTypes, [
        TomUserPreferenceWriteRequest,
      ]);
      expect(api[tomUserPreferencesDeleteEndpointId].requestTypes, [
        TomUserPreferenceKeyRequest,
      ]);
    });

    test('each endpoint states the result type it answers with', () {
      final api = tomUserPreferencesApi;

      expect(
        api[tomUserPreferencesListEndpointId].responseType,
        List<TomUserPreferenceDto>,
      );
      expect(
        api[tomUserPreferencesReadEndpointId].responseType,
        TomUserPreferenceDto,
      );
      // A write answers with the row as stored rather than with nothing: the
      // timestamp is the server's, so the caller has no other way to learn it.
      expect(
        api[tomUserPreferencesWriteEndpointId].responseType,
        TomUserPreferenceDto,
      );
      // A delete answers `200` with an empty body, and `void` is the only
      // spelling that says so. Nothing in the framework reads `responseType`,
      // so no behaviour would change if this said `Object?` instead — which is
      // why it is asserted here: the declaration is the sole statement of the
      // wire's shape, and the documentation mirrors are copied from it.
      expect(
        api[tomUserPreferencesDeleteEndpointId].responseType,
        _typeOf<void>(),
      );
    });

    test('the by-key endpoints bind the capture onto the request field', () {
      expect(
        tomUserPreferencesApi[tomUserPreferencesReadEndpointId]
            .urlParameterMapping,
        {'key': 'key'},
      );
      expect(
        tomUserPreferencesApi[tomUserPreferencesDeleteEndpointId]
            .urlParameterMapping,
        {'key': 'key'},
      );
    });

    test('the write states its key in the body and nowhere else', () {
      // Its request already carries a `key` field. A capture of the same name
      // would let one request name two preferences, and the pipeline folds the
      // body first — so the path would win silently. The URI is therefore the
      // bare collection and the body is the single statement.
      final write = tomUserPreferencesApi[tomUserPreferencesWriteEndpointId];

      expect(write.uri, '');
      expect(write.urlParameterMapping, isEmpty);
      expect(write.requestTypes, [TomUserPreferenceWriteRequest]);
    });

    test('every endpoint requires a principal', () {
      // There is no anonymous preference: a preference is per principal and an
      // anonymous caller is not one. That is the only policy the *contract* can
      // state — which rows a caller reaches is the server entity's row scope.
      expect(
        tomUserPreferencesApi.endpoints.values.map(
          (endpoint) => endpoint.access,
        ),
        everyElement(isA<TomAuthenticatedAccess>()),
      );
    });

    test('no endpoint takes a principal parameter', () {
      // The row scope means there is nothing to ask for but your own, so a
      // principal in a URI could only be a second and weaker statement of who
      // the caller is.
      for (final endpoint in tomUserPreferencesApi.endpoints.values) {
        expect(endpoint.uri ?? '', isNot(contains('principal')));
        expect(endpoint.urlParameterMapping, isNot(contains('principal')));
      }
    });

    test('a read addresses one preference by its key', () {
      // The client-side inverse of the route, built from the same declaration.
      // This is also what makes the key rule load-bearing: whatever the write
      // put in the body has to come back out as one path segment here.
      expect(
        tomUserPreferencesApi[tomUserPreferencesReadEndpointId]
            .resolveUri(
              Uri.parse('https://api.example.com'),
              parameters: {'key': TomUserPreferenceKeys.theme},
            )
            .toString(),
        'https://api.example.com/preferences/tom.theme',
      );
    });
  });

  group('registerTomUserPreferencesApi', () {
    test('it puts the contract itself into the registry', () {
      // The registry holds the declaration, not a copy of it, so a caller that
      // resolves an endpoint by id gets the same object the contract exports.
      registerTomUserPreferencesApi();

      expect(tomRemoteApis.apis.containsKey(tomUserPreferencesApiId), isTrue);
      expect(
        identical(
          tomRemoteApis[tomUserPreferencesApiId],
          tomUserPreferencesApi,
        ),
        isTrue,
      );
    });

    test('registering twice registers once', () {
      // Keyed by API id, which is what lets both halves call it without
      // coordinating: a server registers before mounting the endpoints and a
      // client before building a caller, and neither has to know about the
      // other.
      registerTomUserPreferencesApi();
      final registeredCount = tomRemoteApis.apis.length;
      registerTomUserPreferencesApi();

      expect(tomRemoteApis.apis.length, registeredCount);
    });
  });
}

/// The `Type` object for [T].
///
/// `void` cannot be written as an expression, so `expect(x, void)` does not
/// parse and the only way to name the type of an endpoint that answers with
/// nothing is to reify it through a type parameter.
Type _typeOf<T>() => T;
