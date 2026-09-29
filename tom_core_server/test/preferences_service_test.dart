/// The `TomUserPreferences` behaviour that needs no database — how the service
/// is found, and what it does when the caller cannot be.
///
/// The service takes no principal parameter: it reads the caller from the
/// request zone, which is what keeps the value a handler stores and the row
/// `@TomDbScope(field: 'principal_id', scope: 'owner')` permits it to store from
/// ever disagreeing. The consequence is this file's larger subject — outside a
/// zone carrying one, there is nothing to read and nothing to own, so every
/// operation has to refuse, and refuse before it reaches the table.
///
/// *Which* method performs the lookup is an implementation detail and moves; the
/// suite is written against the public surface so that it can.
///
/// [TomUserPreferences.resolve] is here for the same reason: it is a static bean
/// lookup that touches no repository, and its answer for an unwired deployment
/// is a deliberate `null` rather than a throw — a choice the module is designed
/// around and which would otherwise be pinned nowhere.
///
/// The round trip, the scope, and one principal's inability to read another's
/// are only answerable against a real server — see `preferences_db_test.dart`.
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// A repository resolves its entity through reflection at construction, so the
// bootstrap is needed even though no statement is ever issued here.
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/unreachable_repository.dart';

void main() {
  setUpAll(initializeReflection);

  group('the table\'s key columns are case-sensitive', () {
    // A preference is identified by (principal_id, preference_key), and the
    // unique key is what enforces that. Under a server's default collation -
    // commonly a case-insensitive one - `device.Theme` and `device.theme`
    // would be one row, and the server would order keys differently from the
    // kernel's code-unit rule. The DDL therefore names a binary collation
    // itself rather than inheriting whatever the deployment chose.
    String columnOf(String name) => TomUserPreference.createTableSql
        .split('\n')
        .singleWhere((line) => line.trimLeft().startsWith('$name '));

    test('preference_key is utf8mb4_bin', () {
      expect(columnOf('preference_key'), contains('COLLATE utf8mb4_bin'));
    });

    test('value_type is utf8mb4_bin', () {
      // A Dart type name, compared on read: `String` and `string` differ.
      expect(columnOf('value_type'), contains('COLLATE utf8mb4_bin'));
    });
  });

  group('resolve answers the installed store, or nothing', () {
    // The bean context is process-global, so each test leaves it as it found it
    // rather than letting the next one inherit a registration. Without this the
    // "no bean" case would pass or fail on test order, which is the one way a
    // test of an absence can be worthless.
    tearDown(TomBean.resetBeanContext);

    test('null when no bean is installed', () {
      // The behaviour the module is designed around: a preference is optional by
      // nature, so a deployment that never created `tom_user_preference` falls
      // back to whatever its callers used before rather than failing. A throw
      // here would make installing the table mandatory for every deployment.
      expect(TomUserPreferences.resolve(), isNull);
    });

    test('the installed instance when one is', () {
      // The complement. Without it an implementation that answered `null`
      // unconditionally would satisfy the test above, and every consumer would
      // quietly take its fallback path against a store that was wired
      // correctly.
      final store = preferenceStore();
      TomBean.withType(TomUserPreferences, store);

      expect(TomUserPreferences.resolve(), same(store));
    });

    test('null when the type is bound to something that is not a store', () {
      // `resolve` type-tests what it finds instead of casting it. A deployment
      // that bound the key to the wrong object is mis-wired either way, but the
      // type test keeps the failure shaped like the absence it is — the caller
      // takes its fallback — rather than a cast error raised at whichever
      // consumer happened to ask first.
      TomBean.overrideWithType(TomUserPreferences, 'not a store');

      expect(TomUserPreferences.resolve(), isNull);
    });
  });

  group('every operation identifies the caller before it queries', () {
    // These run outside any zone, over a repository that fails the test if it is
    // reached, so each asserts both halves at once: the refusal is
    // `preferences.no_principal`, and nothing was asked of the database first.
    //
    // All seven entry points are here rather than a representative few. The
    // lookup is shared through private helpers, so any one of them can stop
    // performing it as a side effect of a change to a helper it delegates to —
    // and that is a failure no test of a *sibling* method would notice.

    test('all refuses when no principal is in the zone', () {
      expect(preferenceStore().all, throwsNoPrincipal);
    });

    test('read refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().read(TomUserPreferenceKeys.theme),
        throwsNoPrincipal,
      );
    });

    test('get refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().get<String>(TomUserPreferenceKeys.theme),
        throwsNoPrincipal,
      );
    });

    test('getOr refuses when no principal is in the zone', () {
      // Notably *not* answered with the fallback: the fallback stands in for a
      // preference that was never written, which is a state this call never got
      // close enough to the table to establish.
      expect(
        () => preferenceStore().getOr<String>(
          TomUserPreferenceKeys.theme,
          'light',
        ),
        throwsNoPrincipal,
      );
    });

    test('set refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().set(TomUserPreferenceKeys.theme, 'dark'),
        throwsNoPrincipal,
      );
    });

    test('setEncoded refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().setEncoded(
          TomUserPreferenceKeys.theme,
          valueType: 'String',
          valueJson: '"dark"',
        ),
        throwsNoPrincipal,
      );
    });

    test('remove refuses when no principal is in the zone', () {
      expect(
        () => preferenceStore().remove(TomUserPreferenceKeys.theme),
        throwsNoPrincipal,
      );
    });
  });

  group('all() takes a window, and the wire does not', () {
    // `all()` answers every preference the caller holds, and the list endpoint
    // returns it whole. That is safe rather than lucky — the store is bounded
    // at `tomUserPreferencesMaxPerPrincipal` entries of at most
    // `TomUserPreferenceCodec.maxValueBytes` each — and it is the wire
    // contract's stated shape (`TomUserPreferencesApiService.listPreferences`:
    // "Unpaged, and bounded").
    //
    // The optional window is for a caller on *this* side of the wire — a
    // migration walking one principal's settings, a job reading in batches —
    // and is asserted here as forwarding, because whether it narrows is the
    // repository's answer and needs a table: `preferences_db_test.dart` takes
    // that half.

    test('no window is forwarded when none is given', () async {
      final repository = _RecordingRepository();
      await _asPrincipal(() => TomUserPreferences(repository).all());

      expect(repository.pages, [null]);
    });

    test('the window is forwarded to the repository', () async {
      final repository = _RecordingRepository();
      final page = TomPageRequest(limit: 10, offset: 20);
      await _asPrincipal(() => TomUserPreferences(repository).all(page));

      expect(repository.pages, [same(page)]);
    });

    test('the ordered sentence is the one the window is applied to', () async {
      // A window over an undefined order is a different set of rows each time
      // it is asked for. The clause is part of the sentence rather than added
      // beside the page, so the two cannot be separated by a later edit.
      final repository = _RecordingRepository();
      await _asPrincipal(
        () => TomUserPreferences(repository).all(TomPageRequest(limit: 5)),
      );

      expect(repository.sentences.single, contains('ORDER BY preference_key'));
    });
  });

  group('the guide states the bound the unpaged read rests on', () {
    // The document's numbers are the argument for returning the list whole, so
    // a ceiling raised in the kernel without the document following turns that
    // argument into a wrong one — and it reads exactly as convincingly.
    late String bounded;

    setUpAll(() {
      final guide = File('doc/preferences.md').readAsStringSync();
      final start = guide.indexOf('## The Store Is Bounded');
      expect(start, isNot(-1), reason: 'the guide section was renamed');
      final end = guide.indexOf('\n## ', start + 1);
      bounded = guide.substring(start, end == -1 ? guide.length : end);
    });

    /// The guide's ceiling table row that names [constant].
    ///
    /// The *row*, not the section: the numbers appear in the prose around the
    /// table too, so a containment test over the whole section passes on a
    /// sentence while the table it is meant to check has gone stale.
    String rowNaming(String constant) {
      final rows = bounded
          .split('\n')
          .where((line) => line.startsWith('| ') && line.contains(constant))
          .toList();
      expect(
        rows,
        hasLength(1),
        reason: 'the guide must carry exactly one ceiling row for $constant',
      );
      return rows.single;
    }

    test('it names the count ceiling the kernel enforces', () {
      expect(
        rowNaming('tomUserPreferencesMaxPerPrincipal'),
        contains('$tomUserPreferencesMaxPerPrincipal'),
      );
    });

    test('it names the value ceiling in the unit the guide uses', () {
      expect(
        rowNaming('TomUserPreferenceCodec.maxValueBytes'),
        contains('${TomUserPreferenceCodec.maxValueBytes ~/ 1024} KiB'),
      );
    });

    test('it states what the two together cap the list at', () {
      // Rounded to the nearest megabyte, which is the figure the guide gives —
      // the point is the order of magnitude, and a reader who needs the exact
      // number has the two ceilings above it.
      final megabytes =
          (tomUserPreferencesMaxPerPrincipal *
              (TomUserPreferenceCodec.maxValueBytes +
                  TomUserPreferenceKeys.maxLength)) /
          (1024 * 1024);
      expect(megabytes.round(), 4);
      expect(bounded, contains('four megabytes'));
    });

    test('it says the wire is unpaged on purpose', () {
      expect(
        bounded,
        allOf(contains('no page'), contains('TomPageRequest')),
        reason:
            'the section is where the decision lives: the list endpoint is '
            'unpaged because the store is bounded, and `all()` takes a window '
            'for the server-internal caller that wants one',
      );
    });
  });
}

/// Runs [body] as a principal, so a read gets past the zone check.
Future<T> _asPrincipal<T>(Future<T> Function() body) =>
    runZoned(body, zoneValues: <Object, Object?>{TomPrincipal: _principal()});

/// The smallest principal the service will accept.
TomPrincipal _principal() => TomPrincipal(
  authenticated: true,
  context: {},
  clientId: 0,
  organization: 'acme',
  organizationId: 0,
  application: 'console',
  applicationId: 0,
  process: 'test',
  processId: 0,
  language: 'en',
  country: 'US',
  clientCountry: 'US',
  clientLanguage: 'en',
  clientTimezone: 'UTC',
  user: TomUser(
    id: 7,
    username: 'user7',
    firstname: 'Test',
    lastname: 'User',
    attributes: {},
    timezone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: const ['user']),
);

/// A repository that answers nothing and records what it was asked.
///
/// Whether a window *narrows* is the repository's answer and needs a table —
/// `preferences_db_test.dart` asserts that. What this file can assert is that
/// the service hands the window on rather than accepting it and dropping it,
/// which is the failure an in-memory stand-in that applied the page itself
/// would hide.
class _RecordingRepository
    implements TomSqlDatasourceRepository<TomUserPreference, int> {
  /// The window of every `findByQuerySentence`, in order.
  final List<TomPageRequest?> pages = [];

  /// The sentence of every `findByQuerySentence`, in order.
  final List<String> sentences = [];

  @override
  Future<Iterable<TomUserPreference>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> parameters, [
    Type? resultType,
    TomPageRequest? page,
  ]) async {
    sentences.add(querySentence);
    pages.add(page);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => fail(
    'the repository was reached via ${invocation.memberName}, which this '
    'group does not exercise',
  );
}
