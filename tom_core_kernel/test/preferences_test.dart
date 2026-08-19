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

    // tcinc168: there are five ways to reach a write failure and they have
    // five different remedies, but every one of them used to be told to add
    // an annotation — advice a Set, a Map keyed by int and a NaN cannot act
    // on. These tests hold each refusal to its own diagnosis.
    group('the refusal names the cause it can actually detect', () {
      test('a non-finite element is the JSON problem it is, not a shape one',
          () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(<double>[1.0, double.nan]),
          throwsCodecCause('preferences.encode.not_json', 'element_not_json'),
        );
      });

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
          throwsCodecCause(
            'preferences.encode.failed',
            'map_key_not_string',
          ),
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
          () => TomUserPreferenceCodec.encodeValue(
            <UnreflectedPreference>[UnreflectedPreference()],
          ),
          throwsCodecCause('preferences.encode.failed', 'element_not_scalar'),
        );
      });

      test('and says outright that annotating the element does not help', () {
        expect(
          () => TomUserPreferenceCodec.encodeValue(
            <UnreflectedPreference>[UnreflectedPreference()],
          ),
          throwsCodecMessage(
            'preferences.encode.failed',
            allOf(
              contains('UnreflectedPreference'),
              contains('does not help'),
            ),
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

  // tcinc165: the dartdoc claimed the two naming methods "agree for every type
  // either of them can see". They do not, and cannot: `typeNameOf` asks a
  // *value* what it is, `typeNameForType` asks a *type*. Those are different
  // questions wherever the value's runtime class is not the type the caller
  // wrote down.
  //
  // tcinc164 removed the accidental half of the divergence — the generic
  // instantiation leaking into the stored name. What is left is inherent, so
  // these tests assert it rather than assert against it.
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

    test('a subclass value is named by its runtime class, not its supertype',
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
    });

    test('so a value stored as a subclass is not readable as its supertype',
        () {
      // The consequence, and the reason it is worth documenting rather than
      // repairing: reading a `SubPreference` row as a `BasePreference` would
      // silently drop the members only the subclass declares, so refusing is
      // the intended strictness. Store a preference under the class it is
      // declared as.
      final stored = TomUserPreferenceCodec.encode('ui.pref', SubPreference());

      expect(stored.valueType, 'SubPreference');
      expect(
        () => TomUserPreferenceCodec.decode<BasePreference>(stored),
        throwsCodecKey('preferences.decode.type_mismatch'),
      );
      expect(TomUserPreferenceCodec.decode<SubPreference>(stored).label, 'sub');
    });

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

  // tcinc166: the library dartdoc names "an enum written as its index" as one
  // of the two conventions the codec exists to settle, and the codec settled
  // only the other one. What an annotated enum actually did was worse than
  // being unsupported: `encode` wrote `{}` — the chosen constant simply gone —
  // `validateEncoded` passed that row, and the read then threw a raw
  // `ReflectionNoSuchMethodError`, which is not the exception type the module
  // tells callers to catch.
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

    test('an unannotated enum is refused, with advice that can be followed',
        () {
      // The rule is the one every non-scalar already follows, so there is no
      // separate thing to learn: annotate it. Before tcinc164 this failed one
      // call later, from `encodeValue`, with a message telling the caller to
      // annotate a class — advice an enum could not act on. It now fails while
      // naming the value, which is the call that cannot answer.
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
    });

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

    test('a read that reflection cannot complete still fails as a codec error',
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
    });
  });

  // tcinc167: a list of strings — pinned items, recent files, enabled feature
  // names — is one of the most ordinary preferences there is, and it had no
  // path through the codec: `List` and `Map` are not scalars, so they fell
  // into the reflected branch and `convertToJsonString` could not serialize
  // them. The failure also arrived one call late, `typeNameOf` having already
  // answered `List<int>`, which reads as support.
  group('TomUserPreferenceCodec — a collection of scalars is a value', () {
    test('a List<String> round-trips', () {
      final stored = TomUserPreferenceCodec.encode(
        'ui.pinned',
        <String>['alpha', 'beta'],
      );

      expect(stored.valueType, 'List<String>');
      expect(
        TomUserPreferenceCodec.decode<List<String>>(stored),
        ['alpha', 'beta'],
      );
    });

    test('a Map<String, String> round-trips', () {
      final stored = TomUserPreferenceCodec.encode(
        'ui.labels',
        <String, String>{'home': 'Start', 'away': 'Guest'},
      );

      expect(stored.valueType, 'Map<String, String>');
      expect(
        TomUserPreferenceCodec.decode<Map<String, String>>(stored),
        {'home': 'Start', 'away': 'Guest'},
      );
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
      final stored = TomUserPreferenceCodec.encode(
        'ui.recent',
        <DateTime>[local],
      );

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
      expect(
        decodeStored<List<double>>('[1, 2]', 'ui.scales'),
        [1.0, 2.0],
      );
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
        <String, Object>{'a': <String>['nested']},
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

    test('a list of reflected objects is refused rather than half-supported',
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
    });
  });
}
