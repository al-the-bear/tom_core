import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// A concrete configuration that captures the merged values instead of relying
/// on the generated reflection, so [TomBaseServerConfiguration.getDefaultValues]
/// and the source-merge order can be tested without codegen.
class _CapturingConfig extends TomBaseServerConfiguration {
  Map<String, Object?> captured = {};
  _CapturingConfig(super.args);
  @override
  void setValues(Map<String, Object?> values) => captured = values;
}

/// Installs a fresh provider built from [resources] as the active source.
void _install(Map<String, dynamic> resources) {
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(resources),
  );
}

void main() {
  group('TomServerConfigResourceProvider', () {
    test('exists/get resolve a top-level key', () {
      final p = TomServerConfigResourceProvider.from({'name': 'svc'});
      expect(p.exists('name'), isTrue);
      expect(p.get('name'), 'svc');
    });

    test('exists/get resolve a dotted path into the tree', () {
      final p = TomServerConfigResourceProvider.from({
        'server': {'port': 8080},
      });
      expect(p.exists('server.port'), isTrue);
      expect(p.get('server.port'), 8080);
    });

    test('exists is false for an unknown key', () {
      final p = TomServerConfigResourceProvider.from({'a': 1});
      expect(p.exists('b'), isFalse);
    });

    test('get falls back to the key string for an unknown key', () {
      final p = TomServerConfigResourceProvider.from({'a': 1});
      expect(p.get('unknown'), 'unknown');
    });

    test('setServerConfigProvider installs the active provider', () {
      final p = TomServerConfigResourceProvider.from({'x': 1});
      TomServerConfigResourceProvider.setServerConfigProvider(p);
      expect(TomServerConfigResourceProvider.getServerConfig(), same(p));
    });

    test('.load builds resources by invoking the supplied loader', () {
      var invocations = 0;
      final p = TomServerConfigResourceProvider.load(() {
        invocations++;
        return {'from': 'loader'};
      });
      expect(invocations, 1); // the loader runs eagerly in the constructor
      expect(p.get('from'), 'loader');
    });

    test(
      'the default constructor populates resources from the static loader',
      () {
        // The static loader feeds any provider created with the default
        // constructor (including the lazy one made by getServerConfig). Null it
        // again so it cannot leak into other tests' providers.
        addTearDown(() => TomServerConfigResourceProvider.loader = null);
        TomServerConfigResourceProvider.loader = () => {'seeded': 'yes'};
        final p = TomServerConfigResourceProvider();
        expect(p.get('seeded'), 'yes');
      },
    );

    test(
      'the default constructor yields empty resources when no loader is set',
      () {
        TomServerConfigResourceProvider.loader = null;
        final p = TomServerConfigResourceProvider();
        expect(p.resources, isEmpty);
      },
    );

    test('get returns the whole subtree map for a branch key', () {
      final p = TomServerConfigResourceProvider.from({
        'server': {'port': 8080, 'host': 'localhost'},
      });
      final subtree = p.get('server') as Map;
      expect(subtree['port'], 8080);
      expect(subtree['host'], 'localhost');
    });

    group('explicitly null properties (§79)', () {
      test('a null dotted property exists and reads as null', () {
        final p = TomServerConfigResourceProvider.from({
          'server': {'replica': null},
        });
        expect(p.exists('server.replica'), isTrue);
        expect(p.get('server.replica'), isNull);
      });

      test('a null top-level property exists and reads as null', () {
        final p = TomServerConfigResourceProvider.from({'cleared': null});
        expect(p.exists('cleared'), isTrue);
        expect(p.get('cleared'), isNull);
      });

      test('a null property is not confused with an unknown one', () {
        // The unknown key keeps the documented key-string fallback; the null
        // one does not, because it resolved.
        final p = TomServerConfigResourceProvider.from({'cleared': null});
        expect(p.exists('unknown'), isFalse);
        expect(p.get('unknown'), 'unknown');
        expect(p.get('cleared'), isNull);
      });
    });
  });

  group('TomConfig resolution', () {
    test('reads an existing value and casts it to T', () {
      _install({
        'server': {'port': 8080},
      });
      expect(TomIntConfig('server.port').get(), 8080);
    });

    test('uses the default when the key is absent', () {
      _install({});
      expect(TomIntConfig.withDefault('missing', 42).get(), 42);
    });

    test('prefers the configured value over the default', () {
      _install({'n': 7});
      expect(TomIntConfig.withDefault('n', 42).get(), 7);
    });

    test('the ~ operator returns the resolved value', () {
      _install({'flag': true});
      expect(~TomBoolConfig('flag'), isTrue);
    });

    test('throws for an obligatory key with no default', () {
      _install({});
      expect(() => TomStringConfig('obligatory'), throwsA(anything));
    });

    test('throws an Exception on a type mismatch', () {
      _install({'port': 'not-an-int'});
      expect(() => TomIntConfig('port'), throwsException);
    });

    test('the typed subclasses resolve their type', () {
      _install({'s': 'hi', 'i': 3, 'd': 1.5, 'b': false});
      expect(TomStringConfig('s').get(), 'hi');
      expect(TomIntConfig('i').get(), 3);
      expect(TomDoubleConfig('d').get(), 1.5);
      expect(TomBoolConfig('b').get(), isFalse);
    });

    test('the value is captured at construction, not on read', () {
      _install({'v': 1});
      final config = TomIntConfig('v');
      _install({'v': 2}); // swap the provider after construction
      expect(config.get(), 1); // still the originally-resolved value
    });

    test('a nullable null default resolves to null, not a throw (bug §64)', () {
      _install({});
      // withDefault(key, null) over a nullable T must honour the supplied null
      // default rather than treating it as "no default" and throwing.
      expect(TomConfig<String?>.withDefault('absent', null).get(), isNull);
    });

    test('a non-null default still wins over an absent key', () {
      _install({});
      expect(
        TomConfig<String?>.withDefault('absent', 'fallback').get(),
        'fallback',
      );
    });

    test('an explicitly null value reaches a nullable T (§79)', () {
      _install({
        'server': {'replica': null},
      });
      expect(TomConfig<String?>('server.replica').get(), isNull);
    });

    test('an explicitly null value does not fall back to the default (§79)', () {
      // Defaults cover an *absent* key. A key the operator deliberately set to
      // null is present, so substituting the default would discard exactly the
      // setting they wrote -- it throws instead, naming the key.
      _install({'port': null});
      expect(() => TomIntConfig.withDefault('port', 8080), throwsException);
    });
  });

  group('TomBaseServerConfiguration.getDefaultValues', () {
    test('command-line args override configuration resources', () {
      _install({'override.me': 'fromResource', 'kept': 'resource'});
      final config = _CapturingConfig(['override.me=fromArgs']);
      expect(config.captured['override.me'], 'fromArgs');
      expect(config.captured['kept'], 'resource');
    });

    test('the OS environment is merged in', () {
      _install({});
      final config = _CapturingConfig([]);
      // PATH is present on every supported platform's environment.
      expect(config.captured.containsKey('PATH'), isTrue);
    });

    test('constructing a configuration leaves the provider resources unchanged'
        ' (bug §62)', () {
      _install({'kept': 'resource'});
      final provider = TomServerConfigResourceProvider.getServerConfig();
      final before = provider.resources.keys.toSet();
      _CapturingConfig(
        [],
      ); // merges env/.env/args into a copy, not the provider
      // The OS environment (PATH et al.) must not have leaked into the provider.
      expect(provider.resources.keys.toSet(), before);
      expect(provider.resources.containsKey('PATH'), isFalse);
    });

    test(
      'a nested provider subtree is not mutated by construction (bug §62)',
      () {
        _install({
          'server': {'port': 8080},
        });
        final provider = TomServerConfigResourceProvider.getServerConfig();
        _CapturingConfig(['server.host=example']);
        // The deep copy means the provider's nested map keeps only its own keys,
        // regardless of how overrides are shaped.
        expect((provider.resources['server'] as Map).keys.toSet(), {'port'});
      },
    );

    test('the captured values are a copy, mutating them leaves the provider'
        ' untouched (bug §62)', () {
      _install({
        'server': {'port': 8080},
      });
      final provider = TomServerConfigResourceProvider.getServerConfig();
      final config = _CapturingConfig([]);
      (config.captured['server'] as Map)['port'] = 9999;
      expect((provider.resources['server'] as Map)['port'], 8080);
    });

    test(
      '.env overlays between env and args (resources < env < .env < args)',
      () async {
        final prevCwd = Directory.current;
        final dir = await Directory.systemTemp.createTemp('tom_cfg_env');
        try {
          await File('${dir.path}/.env').writeAsString(
            'r_key=fromEnvFile\nPATH=SENTINEL_PATH\na_key=fromEnvFile\n',
          );
          Directory.current = dir;
          _install({'r_key': 'fromResource'});
          final config = _CapturingConfig(['a_key=fromArgs']);
          expect(
            config.captured['r_key'],
            'fromEnvFile',
          ); // .env beats resources
          expect(config.captured['PATH'], 'SENTINEL_PATH'); // .env beats env
          expect(config.captured['a_key'], 'fromArgs'); // args beat .env
        } finally {
          Directory.current = prevCwd;
          if (await dir.exists()) await dir.delete(recursive: true);
        }
      },
    );

    test('the default bind host is empty (anyIPv4-eligible) (bug §63)', () {
      _install({});
      // An empty host routes TomServer.start to InternetAddress.anyIPv4; the
      // previous "t"/"0" defaults were invalid addresses.
      expect(_CapturingConfig([]).host, '');
    });
  });

  group('TomYaml', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tom_config_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('loads a YAML file into a nested map', () async {
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('database:\n  host: localhost\n  port: 3306\n');
      final map = TomYaml.loadYamlFile(f.path);
      final db = map['database'] as Map;
      expect(db['host'], 'localhost');
      expect(db['port'], 3306);
    });

    test('substitutes a missing variable with its :default', () async {
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('host: \${TOM_CFG_TEST_HOST:fallback}\n');
      final map = TomYaml.loadYamlFile(f.path);
      expect(map['host'], 'fallback');
    });

    test('substitutes a real environment variable', () async {
      // PATH is set in every supported platform's environment; the substitution
      // must resolve ${PATH} to its actual value, not the literal placeholder.
      final path = Platform.environment['PATH'];
      expect(path, isNotNull, reason: 'PATH must be set for this test');
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('p: \${PATH}\n');
      final map = TomYaml.loadYamlFile(f.path);
      expect(map['p'], path);
    });

    test('mergeInYamlFile overlays a file onto an existing map', () async {
      final f = File('${dir.path}/c.yaml');
      await f.writeAsString('added: yes\n');
      final existing = <String, Object?>{'existing': 1};
      TomYaml.mergeInYamlFile(existing, f.path);
      expect(existing['existing'], 1);
      expect(existing['added'], 'yes');
    });
  });
}
