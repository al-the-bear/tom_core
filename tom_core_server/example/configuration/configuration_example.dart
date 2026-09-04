/// Executable example for the configuration module of `tom_core_server`.
///
/// Demonstrates the reflection-free surface: assembling the resource tree at
/// startup, resolving typed properties with [TomConfig] (dotted paths,
/// defaults, the `~` operator, obligatory-missing), loading and layering YAML
/// files with `${VAR:default}` substitution via [TomYaml], and the boundary
/// between the merged value map and the provider — steps 10 and 11 show that
/// the environment reaches a configuration object's *fields* but not
/// [TomConfig], and the one line that changes that. Step 12 shows the failure
/// shape: a bad cast raises [TomConfigurationException] chaining the
/// [TypeError], which step 6's obligatory miss — a bare `String` — does not.
///
/// The three ways to install a tree appear in the order a startup meets them:
/// step 1 defers the build to first access, step 2 hands over a tree already in
/// hand, step 9 wraps the build in the provider itself. The loader comes first
/// because it is *only* demonstrable there — it fires when
/// [TomServerConfigResourceProvider.getServerConfig] **creates** the process
/// provider, so once any provider exists the hook can no longer be reached.
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

import '../_support/check.dart';

Future<void> run() async {
  // 1. The `loader` hook builds the tree on FIRST ACCESS, not when it is set.
  //    That deferral is the whole point: a server that learns where its
  //    configuration file lives only after parsing its arguments can name the
  //    read here and let it happen later, without threading a half-built
  //    provider through startup. The flag is what shows the deferral -- a
  //    check that the value merely arrives would pass just as well if the
  //    loader ran eagerly.
  //
  //    This runs first because it is the only place it can: the hook fires
  //    when getServerConfig() *creates* the process provider, and every later
  //    step has one installed.
  var loaderRan = false;
  TomServerConfigResourceProvider.loader = () {
    loaderRan = true;
    return {'lazy': 'built on first access'};
  };
  check(!loaderRan, 'setting the loader does not build the tree');
  final lazy = TomServerConfigResourceProvider.getServerConfig();
  print('1. loader ran on first access: $loaderRan');
  check(loaderRan, 'the first getServerConfig() builds it');
  check(
    lazy.get('lazy') == 'built on first access',
    'the tree is the loaded one',
  );
  // Clear it: a static hook left set would silently populate any provider
  // default-constructed later in this process.
  TomServerConfigResourceProvider.loader = null;

  // 2. Install a configuration tree as the process-wide provider. This is the
  //    direct form -- the tree is in hand, so there is nothing to defer.
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from({
      'server': {'port': 8080, 'host': '0.0.0.0'},
      'featureFlags': {'beta': true},
    }),
  );
  final provider = TomServerConfigResourceProvider.getServerConfig();
  print('2. exists(server.port)       : ${provider.exists('server.port')}');
  check(provider.exists('server.port'), 'a present key exists');
  check(!provider.exists('server.missing'), 'an absent key does not exist');

  // 3. Typed access via a dotted path, with the value captured at construction.
  final port = TomIntConfig('server.port').get();
  print('3. server.port (int)         : $port');
  check(port == 8080, 'a dotted path resolves to the int 8080');

  // 4. A default is used when the key is absent.
  final timeout = TomIntConfig.withDefault('server.timeoutSeconds', 30).get();
  print('4. timeout default           : $timeout');
  check(timeout == 30, 'an absent key falls back to the default');

  // 5. The ~ operator is shorthand for .get().
  final beta = ~TomBoolConfig('featureFlags.beta');
  print('5. featureFlags.beta (~)     : $beta');
  check(beta == true, '~ is shorthand for .get()');

  // 6. An obligatory missing property throws on construction.
  var threw = false;
  try {
    TomStringConfig('server.obligatoryMissing');
  } catch (_) {
    threw = true;
  }
  print('6. obligatory missing threw  : $threw');
  check(threw, 'an obligatory missing property throws on construction');

  // 7. Load a YAML file with ${VAR:default} substitution.
  final dir = await Directory.systemTemp.createTemp('tom_config_example');
  final yaml = File('${dir.path}/config.yaml');
  await yaml.writeAsString('''
database:
  host: \${DB_HOST:localhost}
  port: \${DB_PORT:3306}
''');
  final loaded = TomYaml.loadYamlFile(yaml.path);
  final db = loaded['database'] as Map;
  print('7. yaml db.host/db.port      : ${db['host']}:${db['port']}');
  // DB_HOST is unset, so the `:default` half of the placeholder is used.
  check(db['host'] == 'localhost', r'${VAR:default} falls back to the default');

  // 8. mergeInYamlFile layers one file over a tree already built. The overwrite
  //    is per LEAF, not per branch: the overlay names server.host alone and
  //    server.port survives, which is what lets a per-environment file state
  //    only its differences instead of restating every sibling to avoid losing
  //    it. A branch the overlay never mentions is untouched entirely.
  final base = File('${dir.path}/base.yaml');
  await base.writeAsString('''
server:
  host: localhost
  port: 8080
featureFlags:
  beta: false
''');
  final production = File('${dir.path}/production.yaml');
  await production.writeAsString('''
server:
  host: prod.internal
''');
  final tree = <String, Object?>{};
  TomYaml.mergeInYamlFile(tree, base.path);
  TomYaml.mergeInYamlFile(tree, production.path);
  final server = tree['server'] as Map;
  print('8. layered server.host/port  : ${server['host']}:${server['port']}');
  check(server['host'] == 'prod.internal', 'the overlay wins the key it names');
  check(server['port'] == 8080, 'a sibling the overlay omits survives');
  check(
    (tree['featureFlags'] as Map)['beta'] == false,
    'a branch the overlay never mentions is untouched',
  );

  //    An overlay that is not there THROWS rather than being skipped, which
  //    matters because the usual reason to write this pattern is a set of
  //    per-environment files of which only one is ever present. Guard with an
  //    existsSync check, or catch PathNotFoundException specifically -- a bare
  //    `catch` reports a malformed overlay as a missing one and the setting
  //    silently stops applying. The throw happens before the merge, so the
  //    tree is left as it was either way.
  var absentThrew = false;
  try {
    TomYaml.mergeInYamlFile(tree, '${dir.path}/staging.yaml');
  } on PathNotFoundException catch (_) {
    absentThrew = true;
  }
  check(absentThrew, 'an absent overlay throws rather than being skipped');
  check(
    server['host'] == 'prod.internal',
    'the failed merge left the tree as it was',
  );

  // 9. The .load constructor is the explicit-provider counterpart of step 1's
  //    hook: same deferred build, but scoped to this provider instead of
  //    standing as a process-wide default. It is the form to reach for once a
  //    provider is already installed, since the hook can no longer fire.
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.load(() => tree.cast<String, dynamic>()),
  );
  final layeredHost = ~TomStringConfig('server.host');
  print('9. layered tree as provider  : $layeredHost');
  check(layeredHost == 'prod.internal', 'the layered tree answers TomConfig');
  await dir.delete(recursive: true);

  // 10. The environment is NOT visible to TomConfig. getDefaultValues merges
  //     Platform.environment, the .env file and the command line into a *copy*
  //     of the provider's tree, and that copy goes to a configuration object's
  //     setValues -- the process-wide provider is deliberately left untouched.
  //     So PATH, which every platform sets, resolves through neither.
  var pathVisible = true;
  try {
    TomStringConfig('PATH');
  } catch (_) {
    pathVisible = false;
  }
  print('10. PATH before install      : ${pathVisible ? 'visible' : 'absent'}');
  check(!pathVisible, 'the environment is not visible to TomConfig');

  // 11. Installing the merged map as the provider is what joins the two stores.
  //     It is the caller's line to write; the module never writes it.
  //     Afterwards the environment and the arguments resolve -- already
  //     converted to their natural Dart types on the way into the map, which is
  //     what lets TomConfig's strict cast succeed.
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(
      TomBaseServerConfiguration.getDefaultValues([
        'DB_PORT=3307',
        'accountNumber=00420',
      ]).cast<String, dynamic>(),
    ),
  );
  final dbPort = TomIntConfig('DB_PORT').get();
  final account = ~TomStringConfig('accountNumber');
  print('11. DB_PORT / accountNumber  : $dbPort / $account');
  check(dbPort == 3307, 'DB_PORT arrives as an int, not the string "3307"');
  // Unquoted, and still a String: a digit run with leading zeros is an
  // identifier, so the converter leaves it as the text it was written as. Only
  // an unpadded run becomes the int above.
  check(account == '00420', 'a padded account number keeps its leading zeros');
  check(
    TomStringConfig('PATH').get()!.isNotEmpty,
    'the environment resolves once the merged map is the provider',
  );

  // 12. A value of the wrong type throws TomConfigurationException, which
  //     chains the TypeError the cast raised. Note the contrast with step 6:
  //     that one needs a bare `catch` because an obligatory miss throws a bare
  //     String, while this one can be caught by type.
  //
  //     The chained cause is the point. A YAML `hosts: [a, b]` decodes as
  //     List<dynamic>, so asking for List<String> fails on the *element* type
  //     -- and the exception's own message reports "with value [a, b]", which
  //     is exactly what the operator wrote and looks perfectly valid. Only the
  //     TypeError names the subtype relation that actually failed.
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from({
      'hosts': <dynamic>['a', 'b'],
    }),
  );
  Object? cause;
  try {
    TomConfig<List<String>>('hosts');
  } on TomConfigurationException catch (e) {
    cause = e.rootException;
  }
  print('12. chained cause            : $cause');
  check(cause is TypeError, 'the failed cast is chained as rootException');
  check(
    '$cause'.contains('List<dynamic>') && '$cause'.contains('List<String>'),
    'the cause names the subtype relation the message cannot',
  );
}

Future<void> main() async {
  await run();
}
