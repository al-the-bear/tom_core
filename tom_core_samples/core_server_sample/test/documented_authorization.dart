/// Shared test helper: reading the sample's authorization claims out of the
/// artifacts that state them.
///
/// The four-state grade matrix is asserted in three places — the seeded
/// migration, the package README, and the live endpoint — and the whole point of
/// the design is that no Dart source restates it. A test that hardcoded the
/// matrix would put the twelve cells back into the source and be free to drift
/// from both the migration and the document, which is the drift these suites
/// exist to catch. So the expectation is *read*: [seededGrants] parses the rows
/// the database is seeded with, [documentedFieldStates] parses the response the
/// README prints, and the tests assert the authorizer maps one onto the other.
///
/// Used by `todo_authorization_test.dart` (database-free: seeds → matrix through
/// the authorizer) and `todo_endpoints_integration_test.dart` (live: the wire
/// response equals the document). One loader for both, because two copies would
/// be free to disagree about what the artifacts say.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The migration that creates `tom_resource_grant` and seeds the demo grants.
const grantsMigration =
    'database_migrations/todo_db/todo_schema/[001]-todo_authz_grants.sql';

/// The number of `(role, key, grade)` rows [grantsMigration] seeds — three demo
/// roles across the four gradable item fields.
///
/// Stated so that a parse which silently matched fewer rows fails naming the
/// count rather than passing on a subset. Without it, a reformatted `INSERT`
/// that the regex no longer recognised would yield an empty grant list, and an
/// empty list resolves every key to `none` — a green suite asserting nothing.
const seededGrantCount = 12;

/// The `(role_name, resource_key, access_level)` rows seeded by
/// [grantsMigration], as the [TomResourceGrant]s the repository would load.
///
/// Parsing the SQL rather than restating it is what makes the database-free
/// suite a real proof about the shipped seed data: re-grading a field in the
/// migration changes what these tests assert, so the migration and the README
/// cannot part company without a failure.
List<TomResourceGrant> seededGrants() {
  final sql = _read(grantsMigration);

  // Anchored on the value-tuple shape rather than on line numbers, so adding a
  // comment or a role does not break the parse. `access_level` is converted
  // through the same codec the persistence layer uses on a real column read.
  final rows = RegExp(
    r"\(\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*\)",
  ).allMatches(sql);

  final grants = <TomResourceGrant>[];
  for (final row in rows) {
    final grade = row.group(3)!;
    // `fromStored` is deliberately lenient — an unrecognised token degrades to
    // `none` — which is right for a stray database value and wrong for a typo
    // in the file this test reads as its expectation. Guarded, so a bad token
    // fails naming itself instead of quietly grading a field hidden.
    expect(
      TomAuthState.values.map((s) => s.name),
      contains(grade),
      reason: '$grantsMigration grants an unknown access level "$grade"',
    );
    grants.add(
      TomResourceGrant(
        roleName: row.group(1)!,
        resourceKey: row.group(2)!,
        accessLevel: TomAuthStateCodec.fromStored(grade),
      ),
    );
  }

  expect(
    grants,
    hasLength(seededGrantCount),
    reason: 'parsed ${grants.length} grant rows from $grantsMigration',
  );
  return grants;
}

/// [seededGrants] grouped by role, the way `TodoApiServer.fieldStates()` groups
/// the rows it loads before folding each role's own grants.
///
/// The grouping is the *caller's* responsibility:
/// `TomGradedAccessControlInformation.fromGrants` ignores `roleName` entirely
/// and unions everything it is handed. Reproducing the endpoint's grouping here
/// is what makes the database-free assertion an assertion about the request-time
/// path rather than about an arrangement only the test performs.
Map<String, List<TomResourceGrant>> seededGrantsByRole() {
  final byRole = <String, List<TomResourceGrant>>{};
  for (final grant in seededGrants()) {
    byRole.putIfAbsent(grant.roleName, () => []).add(grant);
  }
  return byRole;
}

/// The `/todos/field-states` response as printed in `README.md`, decoded.
///
/// Anchored on the fenced block and required to be the only one, so a second
/// JSON sample makes the anchor ambiguous and fails loudly instead of silently
/// matching the wrong block. Cited by section *title* rather than number
/// wherever it is referenced in prose: a number renumbers silently when a
/// section is inserted above it, which is the same drift this exists to catch.
Object? documentedFieldStates() {
  final blocks = RegExp(
    r'^```json\n(.*?)^```',
    multiLine: true,
    dotAll: true,
  ).allMatches(_read('README.md')).map((m) => m.group(1)!).toList();
  expect(
    blocks,
    hasLength(1),
    reason:
        'README.md must contain exactly one ```json block — the '
        '/todos/field-states sample response the suites assert against',
  );
  return jsonDecode(blocks.single);
}

/// The `states` map of [documentedFieldStates], as `role -> field -> grade`.
Map<String, Map<String, String>> documentedMatrix() {
  final states = (documentedFieldStates()! as Map<String, Object?>)['states'];
  expect(
    states,
    isA<Map<String, Object?>>(),
    reason: "the documented response must carry a `states` map",
  );
  return {
    for (final role in (states! as Map<String, Object?>).entries)
      role.key: (role.value! as Map<String, Object?>).map(
        (field, grade) => MapEntry(field, grade! as String),
      ),
  };
}

/// Reads [path], failing with the cause rather than the symptom.
///
/// A relative path that does not resolve almost always means the suite was run
/// from somewhere other than the package root, which `PathNotFoundException`
/// does not say.
String _read(String path) {
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'tests must run from the package root ($path not found)',
  );
  return file.readAsStringSync();
}
