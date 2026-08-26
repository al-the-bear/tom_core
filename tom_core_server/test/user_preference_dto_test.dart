/// `TomUserPreference.toDto()` — the entity's edge, which needs no database.
///
/// The conversion carries four fields across unchanged and does one thing to the
/// fifth: it normalises `updatedAt` to UTC. That single `toUtc()` carries the
/// longest reason-comment in the entity, and the reason is specifically *not*
/// about rows the repository loaded — those arrive UTC-flagged already, because
/// the datasource applies the instant convention to every `TomDbDateTime`
/// column, so on that path the call is a no-op. It is there for the DTO built
/// from a value set in memory, and what it buys is a flag: the DTO is rendered
/// as ISO-8601 for a client that may be in another zone, and a local-flagged
/// instant renders with no offset, so the client reads the server's wall clock
/// as its own.
///
/// That is why this file exists rather than the assertion living beside the
/// round trip in `user_preferences_db_test.dart`. A value that came back from
/// the column is UTC-flagged before `toDto` is reached, so asserting `isUtc`
/// there passes whether the normalisation happens or not — it is the one path
/// that cannot see it. Only an in-memory local-flagged value can, and that needs
/// nothing to build.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A row with [updatedAt], and every other field distinct so a transposition is
/// visible.
TomUserPreference _row(DateTime? updatedAt) => TomUserPreference(
  id: 4,
  principalId: 7,
  preferenceKey: 'tom.theme',
  valueType: 'String',
  valueJson: '"dark"',
  updatedAt: updatedAt,
);

void main() {
  group('toDto normalises updatedAt to UTC', () {
    // `DateTime` carries the flag but the wire format is what acts on it, so
    // both halves are asserted separately below: that the flag changed, and
    // that the instant did not. Either one alone is satisfied by a wrong
    // implementation — re-labelling the wall clock as UTC sets the flag while
    // moving the moment, and leaving the value alone keeps the moment while
    // leaving the flag wrong.

    test('a local-flagged value comes out UTC-flagged', () {
      final local = DateTime(2026, 3, 14, 15, 9, 26);
      expect(local.isUtc, isFalse, reason: 'the premise of the test');

      expect(_row(local).toDto().updatedAt!.isUtc, isTrue);
    });

    test('and comes out as the same moment', () {
      // The conversion is a re-labelling of the *representation*, not of the
      // instant. An implementation that built `DateTime.utc(...)` from the
      // local components would set the flag and shift the moment by the
      // server's offset — silently, and only for deployments outside UTC, which
      // is the failure least likely to be noticed where it is introduced.
      final local = DateTime(2026, 3, 14, 15, 9, 26);

      expect(_row(local).toDto().updatedAt!.isAtSameMomentAs(local), isTrue);
    });

    test('a value that is already UTC is unchanged', () {
      // The repository path. Asserted so that the no-op the entity's comment
      // claims is actually a no-op: a conversion that did anything at all here
      // would move every timestamp read from the column.
      final utc = DateTime.utc(2026, 3, 14, 15, 9, 26);

      final normalised = _row(utc).toDto().updatedAt;

      expect(normalised!.isUtc, isTrue);
      expect(normalised, utc);
    });

    test('a row that was never written keeps a null updatedAt', () {
      // The column is nullable and a blank entity leaves it null, so the
      // conversion has to be null-aware. It is the one input for which a
      // normalisation written as `updatedAt!.toUtc()` would throw instead of
      // answering.
      expect(_row(null).toDto().updatedAt, isNull);
    });
  });

  group('toDto carries the rest across', () {
    // The three string fields are the reason this group exists: `valueType` and
    // `value` are both `String`, and the DTO renames `valueJson` to `value`, so
    // a transposition of the two compiles, round-trips through the database
    // intact, and only surfaces as a decode failure in a client. The distinct
    // fixture values above are what make it visible here.

    test('the key, the declared type and the JSON text', () {
      final dto = _row(null).toDto();

      expect(dto.key, 'tom.theme');
      expect(dto.valueType, 'String');
      expect(dto.value, '"dark"');
    });
  });
}
