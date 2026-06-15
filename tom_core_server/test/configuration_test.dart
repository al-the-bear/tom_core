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
