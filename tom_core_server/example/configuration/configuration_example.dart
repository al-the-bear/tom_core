/// Executable example for the configuration module of `tom_core_server`.
///
/// Demonstrates the reflection-free surface: installing a
/// [TomServerConfigResourceProvider], resolving typed properties with
/// [TomConfig] (dotted paths, defaults, the `~` operator, obligatory-missing),
/// and loading a YAML file with `${VAR:default}` substitution via [TomYaml].
/// The reflected [TomBaseServerConfiguration] base is described in
/// `doc/configuration.md`; it needs a generated subclass and so is not shown
/// here.
///
/// Run with `dart run example/configuration/configuration_example.dart`.
/// The same behaviour is covered by `test/configuration_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

Future<void> run() async {
  // 1. Install a configuration tree as the process-wide provider.
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from({
      'server': {'port': 8080, 'host': '0.0.0.0'},
      'featureFlags': {'beta': true},
    }),
  );
  final provider = TomServerConfigResourceProvider.getServerConfig();
  print('1. exists(server.port)       : ${provider.exists('server.port')}');
  assert(provider.exists('server.port'));
  assert(!provider.exists('server.missing'));

  // 2. Typed access via a dotted path, with the value captured at construction.
  final port = TomIntConfig('server.port').get();
  print('2. server.port (int)         : $port');
  assert(port == 8080);

  // 3. A default is used when the key is absent.
  final timeout = TomIntConfig.withDefault('server.timeoutSeconds', 30).get();
  print('3. timeout default           : $timeout');
  assert(timeout == 30);

  // 4. The ~ operator is shorthand for .get().
  final beta = ~TomBoolConfig('featureFlags.beta');
  print('4. featureFlags.beta (~)     : $beta');
  assert(beta == true);

  // 5. An obligatory missing property throws on construction.
  var threw = false;
  try {
    TomStringConfig('server.obligatoryMissing');
  } catch (_) {
    threw = true;
  }
  print('5. obligatory missing threw  : $threw');
  assert(threw);

  // 6. Load a YAML file with ${VAR:default} substitution.
  final dir = await Directory.systemTemp.createTemp('tom_config_example');
  final yaml = File('${dir.path}/config.yaml');
  await yaml.writeAsString('''
database:
  host: \${DB_HOST:localhost}
  port: \${DB_PORT:3306}
''');
  final loaded = TomYaml.loadYamlFile(yaml.path);
  final db = loaded['database'] as Map;
  print('6. yaml db.host/db.port      : ${db['host']}:${db['port']}');
  assert(db['host'] == 'localhost'); // DB_HOST unset -> default
  await dir.delete(recursive: true);
}

Future<void> main() async {
  await run();
}
