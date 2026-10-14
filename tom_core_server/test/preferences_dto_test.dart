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
/// round trip in `preferences_db_test.dart`. A value that came back from
/// the column is UTC-flagged before `toDto` is reached, so asserting `isUtc`
/// there passes whether the normalisation happens or not — it is the one path
/// that cannot see it. Only an in-memory local-flagged value can, and that needs
/// nothing to build.
///
/// The file also carries what the timestamp is *for*, because that is a claim
/// about the whole module and the only place it can be pinned is beside the
/// conversion that produces it. No read path compares two of these: the
/// shipped client holds no cache, so there is no staleness to detect, and a
/// conditional read would be a mechanism with no consumer. What the field
/// answers is "when did the server last write this" — an answer only the
/// server can give, which is why the write request carries no timestamp — and
/// that answer has to keep being true, which is what the group at the end
/// asserts.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A row with [updatedAt], and every other field distinct so a transposition is
/// visible.
TomUserPreference _row(DateTime? updatedAt) => TomUserPreference(
  id: 4,
  principalId: '7',
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

  group('nothing compares two of these, and the guide says why', () {
    /// Every shipped library source, as (path, contents) pairs.
    final library = [
      for (final entry in Directory('lib').listSync(recursive: true))
        if (entry is File && entry.path.endsWith('.dart'))
          (entry.path, entry.readAsStringSync()),
    ];

    test('no shipped source compares an updatedAt against anything', () {
      // A comparison is what a conditional read, a list-since or a staleness
      // check would all need first, so its absence is the whole of "no read
      // path uses it" in one testable form. If one appears, the decision
      // recorded in the guide has changed and has to be rewritten rather than
      // quietly outgrown.
      final comparisons = <String>[];
      final operators = RegExp(
        r'updatedAt[!?.\w]*\s*(isAfter|isBefore|compareTo|==|!=|<|>)|'
        r'(isAfter|isBefore|compareTo)\([^)]*updatedAt',
      );
      for (final (path, source) in library) {
        final lines = source.split('\n');
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          if (line.trimLeft().startsWith('///')) continue;
          if (line.trimLeft().startsWith('//')) continue;
          if (operators.hasMatch(line)) comparisons.add('$path:${index + 1}');
        }
      }
      expect(
        comparisons,
        isEmpty,
        reason:
            'a timestamp comparison has appeared; doc/preferences.md records '
            'that none exists and why, so that section is now wrong',
      );
    });

    test('the pattern the guard uses finds a comparison when there is one', () {
      // Without this the guard above passes by never matching anything, which
      // is the one way an assertion about an absence is worthless.
      final operators = RegExp(
        r'updatedAt[!?.\w]*\s*(isAfter|isBefore|compareTo|==|!=|<|>)|'
        r'(isAfter|isBefore|compareTo)\([^)]*updatedAt',
      );
      expect(operators.hasMatch('if (a.updatedAt!.isAfter(b))'), isTrue);
      expect(operators.hasMatch('if (since.isBefore(dto.updatedAt!))'), isTrue);
      expect(operators.hasMatch('    updatedAt: updatedAt?.toUtc(),'), isFalse);
    });

    test('the guide states what the timestamp is for, and what it is not', () {
      final guide = File('doc/preferences.md').readAsStringSync();
      final start = guide.indexOf('## When a Preference Was Written');
      expect(start, isNot(-1), reason: 'the guide section was renamed');
      final end = guide.indexOf('\n## ', start + 1);
      final section = guide.substring(start, end == -1 ? guide.length : end);

      expect(
        section,
        allOf(
          // No cache, therefore no staleness, therefore no conditional read.
          contains('no cache'),
          // The answer is the server's, which is why the request has none.
          contains('write request'),
          // And the one place a second store also fills the field, so a
          // reader does not mistake it for a cache of this one.
          contains('device store'),
        ),
      );
    });
  });
}
