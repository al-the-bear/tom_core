/// DB-backed tests for repository paging and sorting (tfca4).
///
/// `paging_test.dart` asserts the request objects and the SQL each sentence
/// renders. This file asserts the thing the rendering is *for*: that a caller
/// asking for page N of size M gets that window, in that order, out of a real
/// table — and that a window composes with the security layers rather than
/// escaping them.
///
/// Three claims only a live table can settle:
///
///  * **the pages partition the result.** Consecutive windows over the same
///    query must neither repeat nor drop a row, which is a property of the
///    ordering the repository appends, not of the SQL text;
///  * **a window past the end is empty, not an error.** The boundary a caller
///    reaches by paging one step too far, every time;
///  * **paging composes with the row scope.** The window is cut out of the rows
///    the principal may see, and the total reported beside it is the *scoped*
///    total — otherwise the page metadata leaks the size of a row set the
///    principal is not allowed to read.
///
/// The group is `@Tags(['db'])` and skips itself when no MariaDB is reachable,
/// so the default `testkit :test` run stays green everywhere. Bring a server up
/// with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// Builds a fixture task; the surrogate key stays `null` so `save` inserts.
FixtureTaskRecord _task(String title, int priority) => FixtureTaskRecord()
  ..title = title
  ..priority = priority
  ..done = false;

/// A principal whose [TomPrincipal.id] is [userId] — the value the grant rows
/// are keyed by.
TomPrincipal _principalWithId(int userId) => TomPrincipal(
  authenticated: true,
  user: TomUser(id: userId, username: 'user$userId'),
  aci: TomAccessControlInformation(roles: const ['user']),
);

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('row windows (DB-backed)', () {
    late TomDataSourceInfo dsi;
    late FixtureTaskRepository repo;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureTaskTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureTask(dsi);
      // A fresh repository per test: a paged read must not reuse the prepared
      // statement an unpaged one cached.
      repo = FixtureTaskRepository();
    });

    tearDownAll(TestDatabase.reset);

    /// Saves five tasks whose priorities ascend with their titles.
    Future<void> seedFive() async {
      for (final (index, title) in ['a', 'b', 'c', 'd', 'e'].indexed) {
        await repo.save(_task(title, index + 1));
      }
    }

    List<String?> titles(Iterable<FixtureTaskRecord> rows) => [
      for (final row in rows) row.title,
    ];

    test('findAll returns the requested page in the requested order', () async {
      await seedFive();
      final sort = const [TomSortField.asc('priority')];
      expect(
        titles(await repo.findAll(TomPageRequest.page(0, 2, sort: sort))),
        ['a', 'b'],
      );
      expect(
        titles(await repo.findAll(TomPageRequest.page(1, 2, sort: sort))),
        ['c', 'd'],
      );
      // The last page is short rather than padded.
      expect(
        titles(await repo.findAll(TomPageRequest.page(2, 2, sort: sort))),
        ['e'],
      );
    });

    test('a page past the end is empty, not an error', () async {
      await seedFive();
      expect(
        await repo.findAll(
          TomPageRequest.page(
            10,
            2,
            sort: const [TomSortField.asc('priority')],
          ),
        ),
        isEmpty,
      );
    });

    test('a sort-only request orders the whole result set', () async {
      await seedFive();
      expect(
        titles(
          await repo.findAll(
            TomPageRequest.sorted(const [TomSortField.desc('priority')]),
          ),
        ),
        ['e', 'd', 'c', 'b', 'a'],
      );
    });

    test('a multi-column sort mixes directions', () async {
      // Three priority bands, two rows each, so the second term is the only
      // thing that can order within a band — a single shared direction could
      // not produce this result.
      await repo.save(_task('beta', 2));
      await repo.save(_task('alpha', 2));
      await repo.save(_task('delta', 1));
      await repo.save(_task('charlie', 1));

      expect(
        titles(
          await repo.findAll(
            TomPageRequest.sorted(const [
              TomSortField.desc('priority'),
              TomSortField.asc('title'),
            ]),
          ),
        ),
        ['alpha', 'beta', 'charlie', 'delta'],
      );
    });

    test('an unsorted window still partitions the result set', () async {
      // No caller sort at all: the repository appends the primary key so the
      // pages remain complementary. Without it "page 2" is not the complement
      // of "page 1" — the database may repeat or skip rows between the calls.
      await seedFive();
      final first = await repo.findAll(TomPageRequest.page(0, 3));
      final second = await repo.findAll(TomPageRequest.page(1, 3));
      expect(first, hasLength(3));
      expect(second, hasLength(2));
      expect({...titles(first), ...titles(second)}, {'a', 'b', 'c', 'd', 'e'});
    });

    test(
      'a caller sort that already settles the order is left alone',
      () async {
        // `priority` is unique here, so the appended key changes nothing — the
        // point is that the caller's ordering still governs.
        await seedFive();
        expect(
          titles(
            await repo.findAll(
              TomPageRequest(
                limit: 2,
                sort: const [TomSortField.desc('priority')],
              ),
            ),
          ),
          ['e', 'd'],
        );
      },
    );

    test('findAllById windows the rows it was given', () async {
      await seedFive();
      final ids = [for (final row in await repo.findAll()) row.id!]..sort();
      final page = await repo.findAllById(
        ids,
        TomPageRequest.page(1, 2, sort: const [TomSortField.asc('priority')]),
      );
      expect(titles(page), ['c', 'd']);
    });

    test('findByQuerySentence takes a page request', () async {
      await seedFive();
      final page = await repo.findByQuerySentence(
        'find by priority >= :floor',
        {'floor': 2},
        null,
        TomPageRequest.page(1, 2, sort: const [TomSortField.asc('priority')]),
      );
      expect(titles(page), ['d', 'e']);
    });

    test('findByQuery takes a page request', () async {
      await seedFive();
      final select =
          TomQuerySentenceCompiler([
                FixtureTaskRecord,
              ]).compileQuerySentence('find by priority >= :floor')
              as TomSelect;
      final page = await repo.findByQuery(
        select,
        {'floor': 1},
        TomPageRequest.page(0, 2, sort: const [TomSortField.desc('priority')]),
      );
      expect(titles(page), ['e', 'd']);
    });

    test('count is unaffected by a window', () async {
      // The result of a paged finder is the page; the *total* comes from
      // count(), which reads the whole filtered set.
      await seedFive();
      await repo.findAll(TomPageRequest.page(0, 2));
      expect((await repo.count()).get(), 5);
    });
  }, skip: skipReason);

  group('paging under a row scope (DB-backed)', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureResourceTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureResource(dsi);
      TomResourceRoleRegistry.reset();
      TomResourceRoleRegistry.registerAll({
        'owner': TomAuthState.full,
        'viewer': TomAuthState.read,
      });
      TomResourceDataScope.install(
        TomDelegationResolver(
          InMemoryPrincipalDelegationStore(const []),
          TomPrincipalResourceRoleResolver(
            InMemoryPrincipalResourceGrantStore([
              TomPrincipalResourceGrant(
                principalId: '1',
                resourceKey: 'project:alpha',
                role: 'owner',
              ),
            ]),
          ),
        ),
      );
    });

    tearDown(() {
      TomResourceDataScope.uninstall();
      TomResourceRoleRegistry.reset();
    });

    tearDownAll(TestDatabase.reset);

    /// Runs [body] in a request zone carrying principal [userId], over a
    /// freshly constructed repository (the scope must come from the zone).
    Future<R> asPrincipal<R>(
      int userId,
      Future<R> Function(FixtureResourceRepository repo) body,
    ) => runZoned(
      () => body(FixtureResourceRepository()),
      zoneValues: <Object, Object?>{TomPrincipal: _principalWithId(userId)},
    );

    /// Inserts a row bypassing the scope, so a test can prove a principal
    /// cannot page into a row that demonstrably exists.
    Future<void> seed(String resourceKey, String title) =>
        dsi.datasource.executeCommand(
          'INSERT INTO fixture_resource_document (resource_key, title) '
          "VALUES ('$resourceKey', '$title')",
        );

    /// Every row in the table, read as raw SQL rather than through a
    /// repository — unscoped by construction, so a test can count rows no
    /// principal is allowed to see.
    Future<List<FixtureResourceRecord>> rawRows() =>
        dsi.datasource.executeQuery<FixtureResourceRecord>(
          'SELECT id, resource_key, title FROM fixture_resource_document '
          'ORDER BY id',
        );

    /// Seeds three visible rows and two the principal may not see.
    Future<void> seedMixed() async {
      for (final title in ['alpha 1', 'alpha 2', 'alpha 3']) {
        await seed('project:alpha', title);
      }
      for (final title in ['beta 1', 'beta 2']) {
        await seed('project:beta', title);
      }
    }

    test('a window is cut out of the scoped rows, not the table', () async {
      await seedMixed();
      final page = await asPrincipal(
        1,
        (repo) => repo.findAll(
          TomPageRequest.page(0, 2, sort: const [TomSortField.asc('title')]),
        ),
      );
      expect([for (final row in page) row.title], ['alpha 1', 'alpha 2']);
    });

    test('the pages of a scoped query end where the scope does', () async {
      // Five rows in the table, three visible: page 1 of size 2 holds the one
      // remaining *visible* row, and page 2 is empty. An unscoped window would
      // have found a beta row in both.
      await seedMixed();
      final second = await asPrincipal(
        1,
        (repo) => repo.findAll(
          TomPageRequest.page(1, 2, sort: const [TomSortField.asc('title')]),
        ),
      );
      expect([for (final row in second) row.title], ['alpha 3']);

      final third = await asPrincipal(
        1,
        (repo) => repo.findAll(
          TomPageRequest.page(2, 2, sort: const [TomSortField.asc('title')]),
        ),
      );
      expect(third, isEmpty);
    });

    test('the total beside a page is the scoped total', () async {
      // The assertion that keeps page metadata from leaking: five rows exist,
      // the principal may see three, and the count it can obtain says three.
      await seedMixed();
      final total = await asPrincipal(1, (repo) => repo.count());
      expect(total.get(), 3);

      // The rows really are all there — the difference is the scope's.
      expect(await rawRows(), hasLength(5));
    });

    test('a principal with no grant pages into nothing', () async {
      await seedMixed();
      expect(
        await asPrincipal(2, (repo) => repo.findAll(TomPageRequest.page(0, 2))),
        isEmpty,
      );
      expect((await asPrincipal(2, (repo) => repo.count())).get(), 0);
    });
  }, skip: skipReason);
}
