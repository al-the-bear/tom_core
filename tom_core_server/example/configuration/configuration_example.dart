/// Executable example for the configuration module of `tom_core_server`.
///
/// Demonstrates the reflection-free surface: installing a
/// [TomServerConfigResourceProvider], resolving typed properties with
/// [TomConfig] (dotted paths, defaults, the `~` operator, obligatory-missing),
/// loading a YAML file with `${VAR:default}` substitution via [TomYaml], and
/// the boundary between the merged value map and the provider — steps 7 and 8
/// show that the environment reaches a configuration object's *fields* but not
/// [TomConfig], and the one line that changes that.
///
/// Constructing a [TomBaseServerConfiguration] subclass is not shown: it needs
/// a generated `setValues` and so is described in `doc/configuration.md`
/// instead. Its static `getDefaultValues` needs no subclass and is used here.
///
/// Run with `dart run example/configuration/configuration_example.dart`.
/// The same behaviour is covered by `test/configuration_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

/// Throws when [ok] does not hold, naming the [expectation] that failed.
///
/// Deliberately not `assert`: `dart run` leaves assertions **disabled** — that
/// is what its `--enable-asserts` flag is for — so an `assert` here compiles
/// out under the very command this file's header gives. An example whose
/// checks vanish under its own documented invocation is worse than one with no
/// checks at all, because it still prints a plausible transcript and still
/// exits 0 while every expectation in it is violated. A plain `if`/`throw`
/// holds however the file is run.
void check(bool ok, String expectation) {
  if (!ok) throw StateError('configuration example failed: $expectation');
}

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
  check(provider.exists('server.port'), 'a present key exists');
  check(!provider.exists('server.missing'), 'an absent key does not exist');

  // 2. Typed access via a dotted path, with the value captured at construction.
  final port = TomIntConfig('server.port').get();
  print('2. server.port (int)         : $port');
  check(port == 8080, 'a dotted path resolves to the int 8080');

  // 3. A default is used when the key is absent.
  final timeout = TomIntConfig.withDefault('server.timeoutSeconds', 30).get();
  print('3. timeout default           : $timeout');
  check(timeout == 30, 'an absent key falls back to the default');

  // 4. The ~ operator is shorthand for .get().
  final beta = ~TomBoolConfig('featureFlags.beta');
  print('4. featureFlags.beta (~)     : $beta');
  check(beta == true, '~ is shorthand for .get()');

  // 5. An obligatory missing property throws on construction.
  var threw = false;
  try {
    TomStringConfig('server.obligatoryMissing');
  } catch (_) {
    threw = true;
  }
  print('5. obligatory missing threw  : $threw');
  check(threw, 'an obligatory missing property throws on construction');

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
  // DB_HOST is unset, so the `:default` half of the placeholder is used.
  check(db['host'] == 'localhost', r'${VAR:default} falls back to the default');
  await dir.delete(recursive: true);

  // 7. The environment is NOT visible to TomConfig. getDefaultValues merges
  //    Platform.environment, the .env file and the command line into a *copy*
  //    of the provider's tree, and that copy goes to a configuration object's
  //    setValues -- the process-wide provider is deliberately left untouched.
  //    So PATH, which every platform sets, resolves through neither.
  var pathVisible = true;
  try {
    TomStringConfig('PATH');
  } catch (_) {
    pathVisible = false;
  }
  print('7. PATH before install       : ${pathVisible ? 'visible' : 'absent'}');
  check(!pathVisible, 'the environment is not visible to TomConfig');

  // 8. Installing the merged map as the provider is what joins the two stores.
  //    It is the caller's line to write; the module never writes it. Afterwards
  //    the environment and the arguments resolve -- already converted to their
  //    natural Dart types on the way into the map, which is what lets
  //    TomConfig's strict cast succeed.
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(
      TomBaseServerConfiguration.getDefaultValues([
        'DB_PORT=3307',
        'accountNumber="00420"',
      ]).cast<String, dynamic>(),
    ),
  );
  final dbPort = TomIntConfig('DB_PORT').get();
  final account = ~TomStringConfig('accountNumber');
  print('8. DB_PORT / accountNumber   : $dbPort / $account');
  check(dbPort == 3307, 'DB_PORT arrives as an int, not the string "3307"');
  check(account == '00420', 'a quoted value keeps its leading zeros');
  check(
    TomStringConfig('PATH').get()!.isNotEmpty,
    'the environment resolves once the merged map is the provider',
  );
}

Future<void> main() async {
  await run();
}
