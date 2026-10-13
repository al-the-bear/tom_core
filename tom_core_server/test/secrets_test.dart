/// Secret references in configuration: parsing, resolving through a provider,
/// taking the precedence of the source they were written in, and refreshing
/// rotated values.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show FixtureRequiredConfig;
import 'fixtures/reflection_fixture.reflection.dart';

Matcher _refused(String key) =>
    throwsA(isA<TomSecretsException>().having((e) => e.key, 'key', key));

void _resources(Map<String, dynamic> resources) =>
    TomServerConfigResourceProvider.setServerConfigProvider(
      TomServerConfigResourceProvider.from(resources),
    );

void main() {
  setUpAll(initializeReflection);
  tearDown(TomSecrets.reset);

  group('TomSecretReference', () {
    test('reads provider, path and field', () {
      final r = TomSecretReference.parse('secret:vault:secret/data/app#jwt');
      expect(r.provider, 'vault');
      expect(r.path, 'secret/data/app');
      expect(r.field, 'jwt');
      expect('$r', 'secret:vault:secret/data/app#jwt');
    });

    test('a path may hold colons; the field is after the last #', () {
      final r = TomSecretReference.parse(
        'secret:aws:arn:aws:secretsmanager:eu-west-1:1:secret:db#password',
      );
      expect(r.provider, 'aws');
      expect(r.path, 'arn:aws:secretsmanager:eu-west-1:1:secret:db');
      expect(r.field, 'password');
    });

    test('a malformed reference is refused by name', () {
      for (final bad in [
        'secret:',
        'secret:vault',
        'secret:vault:',
        'secret::x',
        'secret:vault:#f',
        'secret:vault:p#',
      ]) {
        expect(
          () => TomSecretReference.parse(bad),
          _refused('secrets.reference.malformed'),
          reason: bad,
        );
      }
    });
  });

  group('TomSecretPayload', () {
    const plain = TomSecretReference('p', 'x');
    const field = TomSecretReference('p', 'x', 'user');

    test('a single value is the whole secret', () {
      expect(const TomSecretPayload('s3cr3t').valueOf(plain), 's3cr3t');
    });

    test('a field is read from a map, or from a JSON object string', () {
      expect(
        const TomSecretPayload({'user': 'app', 'port': 5432}).valueOf(field),
        'app',
      );
      expect(const TomSecretPayload('{"user":"app"}').valueOf(field), 'app');
    });

    test('a multi-valued secret needs a field; a missing field is named', () {
      expect(
        () => const TomSecretPayload({'user': 'app'}).valueOf(plain),
        _refused('secrets.field.required'),
      );
      expect(
        () => const TomSecretPayload({'other': 'x'}).valueOf(field),
        _refused('secrets.field.missing'),
      );
    });
  });

  group('resolving configuration', () {
    late TomMapSecretsProvider vault;

    setUp(() {
      vault = TomMapSecretsProvider('vault', {
        'secret/data/billing': {'jwt': 'jwt-from-vault', 'db': 'db-pass'},
        'secret/data/other': 'plain-secret',
      });
      TomSecrets.register(vault);
    });

    test('a reference in a resource becomes the secret', () async {
      _resources({
        'dbUrl': 'secret:vault:secret/data/billing#db',
        'label': 'plain',
      });
      await TomSecrets.load(TomBaseServerConfiguration.collectSources([]));
      final config = FixtureRequiredConfig([]);
      expect(config.dbUrl, 'db-pass');
      expect(config.label, 'plain');
    });

    test(
      'a secret keeps the precedence of the source it was written in',
      () async {
        // The resource names a secret; the command line, which outranks
        // resources, names a plain value — and wins.
        _resources({'dbUrl': 'secret:vault:secret/data/billing#db'});
        final args = ['dbUrl=from-the-command-line'];
        await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
        expect(FixtureRequiredConfig(args).dbUrl, 'from-the-command-line');
        // And the reverse: a reference on the command line outranks a plain
        // resource value.
        _resources({'dbUrl': 'from-the-resource'});
        final secretArgs = ['dbUrl=secret:vault:secret/data/other'];
        await TomSecrets.load(
          TomBaseServerConfiguration.collectSources(secretArgs),
        );
        expect(FixtureRequiredConfig(secretArgs).dbUrl, 'plain-secret');
      },
    );

    test('a reference that was never loaded is refused, never passed on', () {
      _resources({'dbUrl': 'secret:vault:secret/data/billing#db'});
      expect(
        () => FixtureRequiredConfig([]),
        _refused('secrets.reference.unresolved'),
      );
    });

    test('an unknown provider or path fails the load by name', () async {
      expect(
        TomSecrets.load({'x': 'secret:nowhere:a'}),
        _refused('secrets.provider.unknown'),
      );
      expect(
        TomSecrets.load({'x': 'secret:vault:secret/data/missing'}),
        _refused('secrets.fetch.not_found'),
      );
    });

    test('a provider failing with its own exception fails the load as '
        'fetch.failed, keeping the cause', () async {
      TomSecrets.register(_ThrowingProvider());
      await expectLater(
        TomSecrets.load({'x': 'secret:throwing:p'}),
        throwsA(
          isA<TomSecretsException>()
              .having((e) => e.key, 'key', 'secrets.fetch.failed')
              .having((e) => e.rootException, 'cause', isA<StateError>()),
        ),
      );
    });

    test(
      'a path is fetched once however many of its fields are named',
      () async {
        var fetches = 0;
        TomSecrets.register(_CountingProvider(() => fetches++));
        await TomSecrets.load({
          'a': 'secret:counting:p#one',
          'b': 'secret:counting:p#two',
          'c': ['secret:counting:p#one'],
        });
        expect(fetches, 1);
        expect(TomSecrets.current('secret:counting:p#two'), '2');
      },
    );
  });

  group('rotation', () {
    test(
      'refresh fetches again and calls the watchers of what changed',
      () async {
        final vault = TomMapSecretsProvider('vault', {'db': 'v1', 'api': 'a1'});
        TomSecrets.register(vault);
        await TomSecrets.load({
          'x': 'secret:vault:db',
          'y': 'secret:vault:api',
        });
        final seen = <String>[];
        final subscription = TomSecrets.watch('secret:vault:db', seen.add);
        vault.secrets['db'] = 'v2';
        final outcome = await TomSecrets.refresh();
        expect(outcome.changed, ['secret:vault:db']);
        expect(seen, ['v2']);
        expect(TomSecrets.current('secret:vault:db'), 'v2');
        subscription.cancel();
        vault.secrets['db'] = 'v3';
        await TomSecrets.refresh();
        expect(seen, ['v2']);
      },
    );

    test('a refresh that cannot fetch keeps the last value', () async {
      final vault = TomMapSecretsProvider('vault', {'db': 'v1'});
      TomSecrets.register(vault);
      await TomSecrets.load({'x': 'secret:vault:db'});
      vault.secrets.remove('db');
      final outcome = await TomSecrets.refresh();
      expect(outcome.failed, ['secret:vault:db']);
      expect(TomSecrets.current('secret:vault:db'), 'v1');
    });

    test('startRefresh refreshes on its own until stopped', () async {
      final vault = TomMapSecretsProvider('vault', {'db': 'v1'});
      TomSecrets.register(vault);
      await TomSecrets.load({'x': 'secret:vault:db'});
      vault.secrets['db'] = 'v2';
      TomSecrets.startRefresh(const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      TomSecrets.stopRefresh();
      expect(TomSecrets.current('secret:vault:db'), 'v2');
    });
  });
}

class _CountingProvider implements TomSecretsProvider {
  _CountingProvider(this.onFetch);

  final void Function() onFetch;

  @override
  String get name => 'counting';

  @override
  Future<TomSecretPayload> fetch(String path) async {
    onFetch();
    return const TomSecretPayload({'one': '1', 'two': '2'});
  }

  @override
  Future<void> close() async {}
}

class _ThrowingProvider implements TomSecretsProvider {
  @override
  String get name => 'throwing';

  @override
  Future<TomSecretPayload> fetch(String path) async =>
      throw StateError('connection reset');

  @override
  Future<void> close() async {}
}
