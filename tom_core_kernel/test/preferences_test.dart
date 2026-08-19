import 'dart:convert';

import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

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

// =============================================================================
// Tests
// =============================================================================

void main() {
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
}
