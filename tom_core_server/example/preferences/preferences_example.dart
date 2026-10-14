/// Executable example for the preferences module of `tom_core_server`.
///
/// A user preference is the smallest thing in this framework with the most
/// wiring behind it. Five pieces have to be in place before the store answers —
/// reflection, a datasource under the name the entity declares, the bean, a
/// request zone carrying a principal, and the table — and four of them fail at
/// the *bootstrap* line rather than at the call you were trying to make. This
/// program puts them together in the order a deployment does, so the sequence
/// is something to run rather than something to reconstruct from prose.
///
/// **The table is a map here, and that is the one substitution.** The service
/// reaches storage through a `TomSqlDatasourceRepository<TomUserPreference,
/// int>`, so [_InMemoryPreferenceTable] stands in for it — everything else is
/// the shipped code: the real [TomUserPreferences], the real key rule, the real
/// [TomUserPreferenceCodec], the real zone lookup. What the substitution cannot
/// show is named where it matters (step 9) rather than quietly implied: the
/// entity's `@TomDbScope(field: 'principal_id', scope: 'owner')` is enforced by
/// the *repository*, and only a real one can demonstrate it. That, the upsert's
/// unique key and the migration applied to a live schema are the subjects of
/// `test/preferences_db_test.dart` and `test/preferences_roundtrip_db_test.dart`
/// (`@Tags(['db'])`, started with `tool/run_db_tests.sh`).
///
/// Run with `dart run example/preferences/preferences_example.dart`. Every step
/// checks its own result and the run fails when one does not hold, so a green
/// run is a verification and not just a transcript.
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';
import 'preferences_entities.dart';

// ignore_for_file: avoid_print

Future<void> run() async {
  // 1. Reflection first. `TomUserPreferenceRepository` reads the entity's
  //    annotations through its class mirror *in its constructor*, and the codec
  //    resolves an object preference's stored type name through the same
  //    registry — so without this the wiring fails before any preference is
  //    read, and an object preference could not be named at all.
  initializeReflection();
  print('1. reflection initialised');
  check(
    TomUserPreferenceCodec.typeNameOf(ExampleDashboardPreference()) ==
        'ExampleDashboardPreference',
    'the registry names the reflected preference type, which is what makes an '
    'object preference readable by another release on another platform',
  );

  // 2. Nothing is installed yet, and `resolve` says so with a `null` rather
  //    than a throw. That is the module's design, not an oversight: a
  //    preference is optional by nature, so a deployment that never created
  //    `tom_user_preference` falls back to whatever its callers used before.
  TomBean.resetBeanContext();
  print('2. resolve before install   : ${TomUserPreferences.resolve()}');
  check(
    TomUserPreferences.resolve() == null,
    'an unwired deployment reads no store rather than failing',
  );

  // 3. The bean. A deployment installs the shipped service over the shipped
  //    repository; substituting a caching or read-only implementation is the
  //    same line with a different object, and no consumer changes.
  final table = _InMemoryPreferenceTable();
  final store = TomUserPreferences(table);
  TomBean.withType<TomUserPreferences>(store);
  print(
    '3. resolve after install    : ${TomUserPreferences.resolve() != null}',
  );
  check(
    identical(TomUserPreferences.resolve(), store),
    'resolve answers the installed store',
  );

  // 4. Outside a request zone there is no caller, so every operation refuses —
  //    and refuses *before* it reaches the table. A row written without an
  //    owner is one the scope would reject on the next read anyway, having
  //    already been stored.
  final refusal = await _keyOfRefusal(
    () => store.set<String>(TomUserPreferenceKeys.theme, 'dark'),
  );
  print('4. write with no principal  : $refusal');
  check(
    refusal == 'preferences.no_principal' && table.statements == 0,
    'an unidentified caller is refused, and nothing was asked of the table',
  );

  // 5. An illegal key is refused first — before the caller is resolved. The key
  //    arrives off a request URL, so on this side it is untrusted input, and it
  //    is the one fault a caller can see from the call site.
  final badKey = await _keyOfRefusal(() => store.read('Not A Key'));
  print('5. illegal key, no zone too : $badKey');
  check(
    badKey == 'preferences.key.invalid',
    'the key is checked ahead of the caller, because the caller cannot fix it '
    'and the key is what the caller wrote',
  );

  // 6. Inside a zone carrying a principal, a scalar round-trips.
  await _asPrincipal(7, () async {
    final written = await store.set<String>(
      TomUserPreferenceKeys.theme,
      'dark',
    );
    final read = await store.get<String>(TomUserPreferenceKeys.theme);
    print('6. scalar round trip        : ${written.valueType} -> $read');
    check(
      read == 'dark' && written.valueType == 'String',
      'a scalar preference is stored under its own type name and reads back',
    );
  });

  // 7. So does a reflected object, through the same two calls. The value is
  //    rebuilt field by field from JSON — it is not the instance that was
  //    written, which is the point: it survives a process restart and a
  //    different client.
  await _asPrincipal(7, () async {
    final layout = ExampleDashboardPreference()
      ..landingPanel = 'reports'
      ..rowsPerPage = 50
      ..navigationCollapsed = true;
    await store.set<ExampleDashboardPreference>('acme.dashboard', layout);
    final read = await store.get<ExampleDashboardPreference>('acme.dashboard');
    print(
      '7. object round trip        : ${read?.landingPanel} / '
      '${read?.rowsPerPage} / ${read?.navigationCollapsed}',
    );
    check(
      read != null &&
          !identical(read, layout) &&
          read.landingPanel == 'reports' &&
          read.rowsPerPage == 50 &&
          read.navigationCollapsed,
      'an object preference is rebuilt from its stored JSON rather than '
      'handed back',
    );
  });

  // 8. Reading a preference as the wrong type throws rather than answering a
  //    default. An unwritten preference is an ordinary state that `getOr`
  //    answers; a preference stored as another type is a bug, and a silent
  //    fallback would hide it on every device at once.
  await _asPrincipal(7, () async {
    final mismatch = await _keyOfRefusal(
      () => store.get<int>(TomUserPreferenceKeys.theme),
    );
    final unwritten = await store.getOr<String>('acme.never.written', 'en-GB');
    print('8. mismatch / unwritten     : $mismatch / $unwritten');
    check(
      mismatch == 'preferences.decode.type_mismatch' && unwritten == 'en-GB',
      'a type mismatch throws while an unwritten preference takes the fallback',
    );
  });

  // 9. One principal does not read another's. The service names the caller in
  //    every statement it issues rather than relying on the row scope, which is
  //    what keeps the answer right even under `TomDataScope.runUnscoped`.
  //
  //    This is the half the in-memory table can show. The other half — the
  //    repository ANDing `principal_id IN (:__tomscope_0)` into every read and
  //    refusing an insert scoped to somebody else — belongs to a real
  //    repository, and is asserted in `test/preferences_db_test.dart`.
  await _asPrincipal(8, () async {
    final theirs = await store.get<String>(TomUserPreferenceKeys.theme);
    final mine = await store.all();
    print('9. other principal reads    : $theirs, holding ${mine.length}');
    check(
      theirs == null && mine.isEmpty,
      'a second principal sees none of the first principal\'s preferences',
    );
  });

  // 10. `remove` answers whether a row was there, so a caller can tell
  //     "deleted" from "was never there" without a second read.
  await _asPrincipal(7, () async {
    final removed = await store.remove('acme.dashboard');
    final again = await store.remove('acme.dashboard');
    print('10. remove twice            : $removed then $again');
    check(
      removed && !again,
      'the first remove reports the row it deleted and the second reports none',
    );
  });

  // 11. `all` answers every preference of the caller and none of anyone
  //     else's. It also answers them *ordered by key* — the contract's order,
  //     so `tom_core_flutter`'s device store answers the same sequence and an
  //     application holding either reads one list — but that ordering is an
  //     `ORDER BY` clause, which is the database's work and not this map's.
  //     Asserting it here would assert the stand-in; it is asserted against a
  //     real table in `test/preferences_db_test.dart`.
  await _asPrincipal(7, () async {
    await store.set<String>(TomUserPreferenceKeys.language, 'en');
    await store.set<String>(TomUserPreferenceKeys.country, 'US');
    final keys = (await store.all()).map((dto) => dto.key).toSet();
    print('11. all() for the caller    : ${keys.length} keys');
    check(
      keys.length == 3 &&
          keys.containsAll([
            TomUserPreferenceKeys.theme,
            TomUserPreferenceKeys.language,
            TomUserPreferenceKeys.country,
          ]),
      'every preference the caller wrote comes back, and nothing else',
    );
  });

  // 12. The endpoint's write path takes the value already encoded, because a
  //     request carries text and there is no Dart value to take the type from.
  //     The pair is validated before it is stored: a mismatch written here is
  //     one every later read of that key, on every device, would fail on.
  await _asPrincipal(7, () async {
    final bad = await _keyOfRefusal(
      () => store.setEncoded(
        'acme.rows',
        valueType: 'int',
        valueJson: '"twenty"',
      ),
    );
    final good = await store.setEncoded(
      'acme.rows',
      valueType: 'int',
      valueJson: '20',
    );
    print('12. setEncoded             : refused $bad, stored ${good.value}');
    check(
      bad.startsWith('preferences.') && await store.get<int>('acme.rows') == 20,
      'an encoded pair that does not agree is refused at the door rather than '
      'on every later read',
    );
  });

  // 13. The fifth piece: the table itself. The entity declares the DDL it
  //     expects, and the shipped migration reproduces it verbatim so the two
  //     cannot drift — which is what lets a deployment apply the migration and
  //     know the entity will map onto what it created.
  final migration = File(
    'example/preferences/migrations/main/tomcore/'
    '[1]-create_tom_user_preference.sql',
  );
  final onDisk = migration.readAsStringSync();
  print('13. migration on disk       : ${migration.path.split('/').last}');
  check(
    onDisk.contains('CREATE TABLE IF NOT EXISTS tom_user_preference') &&
        onDisk.contains(
          'uq_tom_user_preference (principal_id, preference_key)',
        ),
    'the migration creates the table the entity maps to, with the unique key '
    'that makes (principal, key) the preference\'s identity',
  );

  print('\nPreferences example completed.');
}

/// Runs [body] in a zone carrying a principal whose id is [userId] — the value
/// the `owner` scope resolver binds into `principal_id`, and the only thing the
/// service reads to decide whose preferences it is touching.
Future<void> _asPrincipal(int userId, Future<void> Function() body) => runZoned(
  body,
  zoneValues: <Object, Object?>{TomPrincipal: _principal(userId)},
);

/// The key of the [TomException] [body] raises, or `'<none>'` when it does not.
Future<String> _keyOfRefusal(Future<Object?> Function() body) async {
  try {
    await body();
    return '<none>';
  } on TomException catch (error) {
    return error.key;
  }
}

/// A principal whose [TomPrincipal.id] is [userId].
TomPrincipal _principal(int userId) => TomPrincipal(
  authenticated: true,
  context: {},
  clientId: 0,
  organization: 'acme',
  organizationId: 0,
  application: 'console',
  applicationId: 0,
  process: 'example',
  processId: 0,
  language: 'en',
  country: 'US',
  clientCountry: 'US',
  clientLanguage: 'en',
  clientTimezone: 'UTC',
  user: TomUser(
    id: '$userId',
    username: 'user$userId',
    firstname: 'Example',
    lastname: 'User',
    attributes: {},
    timezone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: const ['user']),
);

/// The rows the example's store reads and writes, in a map.
///
/// It implements `TomSqlDatasourceRepository` rather than extending it, so that
/// no datasource has to be registered to run the example — extending resolves
/// the entity's `@TomDbTable(datasource: 'main')` in the constructor. The four
/// methods below are every one `TomUserPreferences` calls; `noSuchMethod` turns
/// a fifth into a loud failure rather than a silent `null`, so this table can
/// never quietly answer for something it does not implement.
///
/// **It answers from the bound parameters, and interprets no SQL.** That is
/// deliberate: a stand-in that parsed the sentence would be making claims about
/// the query language, and a stand-in that ignored the parameters would make
/// the principal filter in step 9 pass for a reason the real store does not
/// have. Reading `principalId` and `key` off the bindings is exactly what the
/// service put there.
///
/// **And it does not sort.** [TomUserPreferences.all] orders by key through an
/// `ORDER BY` clause, which is the database's work; a map that sorted on its
/// way out would make the example's ordering step pass whether the clause was
/// there or not — an assertion about this class rather than about the service.
/// Rows therefore come back in insertion order, as a storage engine is free to
/// do, and the ordering is asserted where it can be: against a real table in
/// `test/preferences_db_test.dart`.
class _InMemoryPreferenceTable
    implements TomSqlDatasourceRepository<TomUserPreference, int> {
  final Map<int, TomUserPreference> _rows = {};
  int _nextId = 1;

  /// How many times the store has asked this table for anything, so step 4 can
  /// assert that a refused call never reached it.
  int statements = 0;

  @override
  Future<Iterable<TomUserPreference>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> parameters, [
    Type? resultType,
    TomPageRequest? page,
  ]) async {
    statements++;
    final principalId = parameters['principalId'] as String?;
    final key = parameters['key'] as String?;
    // Insertion order, deliberately — see this class's note on ordering.
    return _rows.values
        .where((row) => row.principalId == principalId)
        .where((row) => key == null || row.preferenceKey == key)
        .toList();
  }

  @override
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> parameters,
  ) async {
    statements++;
    final principalId = parameters['principalId'] as String?;
    return TomDbInt(
      _rows.values.where((row) => row.principalId == principalId).length,
    );
  }

  @override
  Future<TomUserPreference> save(TomUserPreference toSave) async {
    statements++;
    if (toSave.id < 0) toSave.id = _nextId++;
    _rows[toSave.id] = toSave;
    return toSave;
  }

  @override
  Future<int> deleteById(int id) async {
    statements++;
    return _rows.remove(id) == null ? 0 : 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'the example table was asked for ${invocation.memberName}, which the '
    'preferences service does not call. Implement it here if that changes.',
  );
}

Future<void> main() => run();
