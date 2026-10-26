/// Default preferences, the bulk write and the single-statement write, against
/// a live database.
///
/// * **Precedence.** A principal reads its own value, then a default of a role
///   it holds (highest precedence, then role name), then the deployment's.
/// * **The bulk write** stores a batch all or none, and counts the batch whole
///   against the per-principal ceiling.
/// * **The single-statement write.** Concurrent writes of one key never meet a
///   duplicate key and leave one row; an entity whose write needs the stored
///   row falls back to the read-then-save path.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomException>().having((e) => e.key, 'key', key));

TomPrincipal _principal(int userId, List<String> roles) => TomPrincipal(
  authenticated: true,
  context: {},
  clientId: 0,
  organization: 'acme',
  organizationId: 0,
  application: 'console',
  applicationId: 0,
  process: 'login',
  processId: 0,
  language: 'en',
  country: 'US',
  clientCountry: 'US',
  clientLanguage: 'en',
  clientTimezone: 'UTC',
  user: TomUser(
    id: '$userId',
    username: 'user$userId',
    firstname: 'Test',
    lastname: 'User',
    attributes: {},
    timezone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: roles),
);

/// Records nothing; registering it makes a write of [TomUserPreference]
/// observed, so the repository cannot write it in one statement.
class _Observer extends TomEntityListener<TomUserPreference> {
  const _Observer();
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomDataSourceInfo dsi;
  late TomPreferenceDefaults defaults;

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    dsi = await TestDatabase.register();
    await TestDatabase.registerMainAlias();
    await TestDatabase.ensureUserPreferenceTable(dsi);
    await TestDatabase.ensurePreferenceDefaultTable(dsi);
    addTearDown(TestDatabase.reset);
  });

  setUp(() async {
    if (!reachable) return;
    await TestDatabase.truncateUserPreference(dsi);
    await TestDatabase.truncatePreferenceDefault(dsi);
    defaults = TomPreferenceDefaults(TomPreferenceDefaultRepository());
  });

  /// Runs [body] as user [userId] holding [roles], over fresh services.
  Future<T> as<T>(
    int userId,
    List<String> roles,
    Future<T> Function(TomUserPreferences preferences) body,
  ) => runZoned(
    () => body(
      TomUserPreferences(TomUserPreferenceRepository(), defaults: defaults),
    ),
    zoneValues: <Object, Object?>{TomPrincipal: _principal(userId, roles)},
  );

  Future<int> rowCount(String table) async =>
      (await dsi.datasource.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM $table',
      )).single.count;

  group('precedence', () {
    test(
      'own value, then a held role\'s default, then the deployment\'s',
      () async {
        await defaults.setForDeployment('theme', 'light');
        expect(
          (await as(1, ['user'], (p) => p.read('theme')))!.origin,
          tomUserPreferenceOriginDeployment,
        );

        await defaults.setForRole('admin', 'theme', 'dark');
        expect(await as(1, ['user'], (p) => p.get<String>('theme')), 'light');
        final admin = (await as(2, ['admin'], (p) => p.read('theme')))!;
        expect(admin.value, '"dark"');
        expect(admin.origin, tomUserPreferenceOriginRole);
        expect(admin.isDefault, isTrue);

        await as(2, ['admin'], (p) => p.set('theme', 'contrast'));
        final own = (await as(2, ['admin'], (p) => p.read('theme')))!;
        expect(own.value, '"contrast"');
        expect(own.origin, tomUserPreferenceOriginUser);

        // Deleting the own value brings the default back; a default is never
        // copied into the principal's rows.
        expect(await as(2, ['admin'], (p) => p.remove('theme')), isTrue);
        expect(await as(2, ['admin'], (p) => p.get<String>('theme')), 'dark');
        expect(await as(2, ['admin'], (p) => p.remove('theme')), isFalse);

        expect(await defaults.removeForRole('admin', 'theme'), isTrue);
        expect(await defaults.removeForDeployment('theme'), isTrue);
        expect(await as(2, ['admin'], (p) => p.read('theme')), isNull);
      },
      skip: skip,
    );

    test(
      'of several roles: the highest precedence, then the role name',
      () async {
        await defaults.setForRole('editor', 'page.size', 50, precedence: 1);
        await defaults.setForRole('auditor', 'page.size', 10, precedence: 5);
        await defaults.setForRole('author', 'page.size', 20, precedence: 5);

        expect(
          await as(1, [
            'editor',
            'author',
            'auditor',
          ], (p) => p.get<int>('page.size')),
          10,
          reason: 'precedence 5 twice; auditor sorts before author',
        );
        expect(
          await as(1, ['editor', 'author'], (p) => p.get<int>('page.size')),
          20,
        );
        expect(await as(1, ['editor'], (p) => p.get<int>('page.size')), 50);
        expect(await as(1, ['guest'], (p) => p.read('page.size')), isNull);
      },
      skip: skip,
    );

    test(
      'the list merges own values and defaults by key, with origins',
      () async {
        await defaults.setForDeployment('a.deployment', 1);
        await defaults.setForDeployment('c.both', 1);
        await defaults.setForRole('admin', 'b.role', 2);
        await as(1, ['admin'], (p) => p.set('c.both', 3));
        await as(1, ['admin'], (p) => p.set('d.own', 4));

        final all = await as(1, ['admin'], (p) => p.all());
        expect(
          [for (final dto in all) '${dto.key}=${dto.value}:${dto.origin}'],
          [
            'a.deployment=1:deployment',
            'b.role=2:role',
            'c.both=3:user',
            'd.own=4:user',
          ],
        );
        final window = await as(1, [
          'admin',
        ], (p) => p.all(TomPageRequest(offset: 1, limit: 2)));
        expect(window.map((d) => d.key), ['b.role', 'c.both']);
      },
      skip: skip,
    );

    test('writing a default twice replaces it in one row', () async {
      await defaults.setForRole('admin', 'theme', 'dark');
      await defaults.setForRole('admin', 'theme', 'light', precedence: 3);
      expect(await rowCount('tom_preference_default'), 1);
      final stored = (await defaults.all()).single;
      expect(stored.valueJson, '"light"');
      expect(stored.precedence, 3);
    }, skip: skip);

    test('a role name must be given', () async {
      await expectLater(
        defaults.setForRole('', 'theme', 'dark'),
        _throwsKey('preferences.default.invalid_role'),
      );
    }, skip: skip);
  });

  group('the bulk write', () {
    TomUserPreferenceWriteRequest write(
      String key,
      String type,
      String value,
    ) => TomUserPreferenceWriteRequest(key: key, valueType: type, value: value);

    test('writes every entry and answers them ordered by key', () async {
      await as(1, ['user'], (p) => p.set('b', 'old'));
      final written = await as(
        1,
        ['user'],
        (p) => p.setAllEncoded([
          write('c', 'int', '3'),
          write('b', 'String', '"new"'),
          write('a', 'bool', 'true'),
        ]),
      );
      expect(written.map((d) => '${d.key}=${d.value}'), [
        'a=true',
        'b="new"',
        'c=3',
      ]);
      expect(await rowCount('tom_user_preference'), 3);
      expect(await as(1, ['user'], (p) => p.setAllEncoded(const [])), isEmpty);
    }, skip: skip);

    test('one refused entry writes nothing', () async {
      await expectLater(
        as(
          1,
          ['user'],
          (p) => p.setAllEncoded([
            write('a', 'int', '1'),
            write('b', 'int', '"not an int"'),
          ]),
        ),
        throwsA(isA<TomUserPreferenceCodecException>()),
      );
      expect(await rowCount('tom_user_preference'), 0);
    }, skip: skip);

    test('the ceiling counts the batch whole', () async {
      final full = [
        for (var i = 0; i < tomUserPreferencesMaxPerPrincipal - 1; i++)
          write('k$i', 'int', '$i'),
      ];
      await as(1, ['user'], (p) => p.setAllEncoded(full));

      await expectLater(
        as(
          1,
          ['user'],
          (p) => p.setAllEncoded([
            write('new.one', 'int', '1'),
            write('new.two', 'int', '2'),
          ]),
        ),
        _throwsKey(tomUserPreferencesLimitExceededErrorKey),
      );
      expect(
        await rowCount('tom_user_preference'),
        tomUserPreferencesMaxPerPrincipal - 1,
        reason: 'nothing of the refused batch was written',
      );

      // Replacing held keys and adding the one that still fits succeeds.
      await as(
        1,
        ['user'],
        (p) => p.setAllEncoded([
          write('k0', 'int', '100'),
          write('new.one', 'int', '1'),
        ]),
      );
      expect(
        await rowCount('tom_user_preference'),
        tomUserPreferencesMaxPerPrincipal,
      );
      expect(await as(1, ['user'], (p) => p.get<int>('k0')), 100);
    }, skip: skip);
  });

  group('the single-statement write', () {
    test('concurrent writes of one key leave one row and no failure', () async {
      final writes = [
        for (var i = 0; i < 20; i++)
          as(1, ['user'], (p) => p.set('theme', 'v$i')),
      ];
      await Future.wait(writes);
      expect(await rowCount('tom_user_preference'), 1);
      expect(
        await as(1, ['user'], (p) => p.get<String>('theme')),
        matches(RegExp(r'^v\d+$')),
      );
    }, skip: skip);

    test(
      'concurrent bulk writes of overlapping keys leave one row per key',
      () async {
        await Future.wait([
          for (var i = 0; i < 8; i++)
            as(
              1,
              ['user'],
              (p) => p.setAllEncoded([
                TomUserPreferenceWriteRequest(
                  key: 'a',
                  valueType: 'int',
                  value: '$i',
                ),
                TomUserPreferenceWriteRequest(
                  key: 'b',
                  valueType: 'int',
                  value: '$i',
                ),
              ]),
            ),
        ]);
        expect(await rowCount('tom_user_preference'), 2);
      },
      skip: skip,
    );

    test('the conflict key must hold the owner', () async {
      await expectLater(
        runZoned(
          () => TomUserPreferenceRepository().upsert(
            TomUserPreference(
              principalId: '1',
              preferenceKey: 'theme',
              valueType: 'String',
              valueJson: '"dark"',
            ),
            conflictFields: const ['preferenceKey'],
          ),
          zoneValues: <Object, Object?>{
            TomPrincipal: _principal(1, ['user']),
          },
        ),
        _throwsKey('crud_repository.upsert.unscoped_conflict_key'),
      );
    }, skip: skip);

    test('an observed entity is not upserted, and the store falls back to '
        'read then save', () async {
      final unregister = TomEntityLifecycle.register<TomUserPreference>(
        const _Observer(),
      );
      addTearDown(unregister);
      final repository = TomUserPreferenceRepository();
      expect(repository.upsertBlocker, isNotNull);
      await expectLater(
        repository.upsert(TomUserPreference(), conflictFields: const ['id']),
        _throwsKey('crud_repository.upsert.unsupported'),
      );

      await as(1, ['user'], (p) => p.set('theme', 'dark'));
      await as(1, ['user'], (p) => p.set('theme', 'light'));
      expect(await rowCount('tom_user_preference'), 1);
      expect(await as(1, ['user'], (p) => p.get<String>('theme')), 'light');
    }, skip: skip);
  });
}
