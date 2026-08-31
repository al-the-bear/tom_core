/// Live server boot for the sample backend.
///
/// This is the smallest single-isolate `TomServer` boot that serves the API
/// against the bundled Docker MariaDB. It follows the `tom_uam_server` boot
/// sequence, trimmed to what public (unauthenticated) JSON endpoints need:
///
///   platform → reflection → runtime → config → datasource → bean context →
///   migrations → `TomServer.start()`
///
/// The JWT/auth-server/cache/worker-pool machinery `tom_uam_server` also wires
/// is intentionally omitted — the endpoints are `@TomPublicAccess`, so none of
/// it is exercised. Run it from the package root (relative asset/migration
/// paths resolve against the CWD):
///
/// ```sh
/// cp .env.example .env
/// docker compose up -d db
/// dart run bin/server_start.dart
/// ```
///
/// The `.env` is read by this boot as well as by Docker Compose — see
/// [_environment] — so the two halves of that workflow cannot drift apart.
///
/// This file is also the reflection-generation root (`build.yaml`): the
/// generator follows its import graph to discover every `@tomReflector`
/// type — the endpoint service, the persistence records, this config class, and
/// (transitively, through the `tom_core_server` barrel) the MariaDB driver,
/// migration adaptor, and `TomResourceGrant`. Regenerate with
/// `./reflection_generation.sh` after changing any reflected shape.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

// Imported for its reflection side effects: the barrel re-exports the endpoint
// service and the persistence records, pulling them into this entrypoint's
// import graph so the generator captures them (and, transitively through the
// tom_core_server barrel, the driver/migrator/grant types). The generated
// reflection file imports the concrete types directly, so at compile time this
// import contributes no referenced symbol — but it is what the generator
// follows to discover them, so it must stay.
// ignore: unused_import
import 'package:core_server_sample/core_server_sample.dart';

import 'server_start.reflection.dart';

/// HTTP port the sample binds (overridable via the `port` config key / env /
/// `--port=`).
const int _defaultPort = 8080;

/// The variables this boot expands `${VAR:default}` placeholders from and reads
/// the `env` overlay selector out of: the process environment with the
/// package-root `.env` layered on top.
///
/// Resolving it explicitly is what makes the documented workflow — `cp
/// .env.example .env`, edit, `docker compose up -d db`, run — actually work.
/// `TomBaseServerConfiguration` merges `.env` into the *configuration* keys on
/// its own, but `TomYaml` expands placeholders from `Platform.environment`
/// unless it is given something else, and `TomRuntime` is told which
/// environment to select by this file. So without this the `.env` moved the
/// database (Docker Compose reads it directly) while the server kept dialling
/// the `${TODO_DB_PORT:3306}` default, and `env=dev` selected the prod overlay.
///
/// Read once at first use rather than per call, so every consumer below sees
/// one consistent snapshot even if the file changes under a running server.
final Map<String, String> _environment = TomEnvFile.resolveEnvironment();

/// The sample server configuration.
///
/// `@tomReflector` so `tomReflectionInfo.setValues<ServerConfiguration>` can
/// populate it from the merged config/env/args. The constructor runs after the
/// base has applied the loaded values, so the fields set here are the sample's
/// fixed choices: plain HTTP (no TLS cert to manage), a single isolate with no
/// separate logging isolate, and binding on all interfaces so the host and the
/// compose network can both reach it. `appId` and `port` are guarded on being
/// unset, which is what makes them *defaults* rather than fixed choices — an
/// unguarded assignment here would overwrite the value the merge just resolved.
@tomReflector
class ServerConfiguration extends TomBaseServerConfiguration {
  /// Builds the configuration from the process [args].
  ServerConfiguration(super.args) {
    if (appId.isEmpty) appId = 'todo';
    if (port == 0) port = _defaultPort;
    noSsl = true;
    isolateLogging = false;
    listenToAnyIP = true;
  }

  @override
  void setValues(Map<String, dynamic> values) {
    tomReflectionInfo.setValues<ServerConfiguration>(this, values);
  }
}

/// Production environment — the root of the (small) environment hierarchy.
const TomEnvironment environmentProd = TomEnvironment('prod');

/// Development overlay selected by `env=dev`.
const TomEnvironment environmentDev = TomEnvironment(
  'dev',
  parent: environmentProd,
  isDevelopment: true,
  isTest: true,
);

/// Registers the environment hierarchy and resolves the current environment
/// from the `env` variable in [_environment] (defaults to `prod`).
void initializeRuntime() {
  TomRuntime.addEnvironment(environmentProd);
  TomRuntime.addEnvironment(environmentDev);
  TomRuntime.setRootEnvironment(environmentProd);
  TomRuntime.setCurrentEnvironment(_environment['env'], 'prod');
  TomRuntime.getCurrentEnvironment().initialize();
  TomRuntime.initializePlatform();
}

/// Loads `assets/config-resources_default.yaml` plus the active environment
/// overlay (`_<env>.yaml`); OS env, `.env` and args win on top of the result
/// inside the base config (`TomBaseServerConfiguration.getDefaultValues`).
Map<String, dynamic> configLoaderFunction() {
  final result = <String, dynamic>{};
  _mergeYamlIfPresent(result, 'assets/config-resources_default.yaml');
  for (final env in TomRuntime.getEnvironmentHierarchy()) {
    _mergeYamlIfPresent(result, 'assets/config-resources_${env.env}.yaml');
  }
  return result;
}

/// Loads `assets/datasources_default.yaml` (with `${VAR:default}` substitution
/// against [_environment], so the connection follows `.env`).
Map<String, dynamic> datasourceLoaderFunction() {
  final result = <String, dynamic>{};
  _mergeYamlIfPresent(result, 'assets/datasources_default.yaml');
  return result;
}

void _mergeYamlIfPresent(Map<String, dynamic> into, String path) {
  if (!File(path).existsSync()) return;
  mergeMapsOneSided(
    into,
    TomYaml.loadYamlFile(path, environment: _environment),
  );
}

/// Installs the config-resource provider so the configuration can read the
/// loaded `config-resources_*.yaml` keys.
void initializeServerResources() {
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(configLoaderFunction()),
  );
}

/// Boots the HTTP server (fire-and-forget; the bound socket + open DB
/// connection keep the isolate alive).
void startServer(ServerConfiguration configuration) {
  TomServer(configuration).start();
}

Future<void> main(List<String> args) async {
  TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);

  initializeReflection();
  initializeRuntime();
  initializeServerResources();

  final configuration = ServerConfiguration(args);

  await TomDataSourceInfo.initializeDatasourceInfo(datasourceLoaderFunction());

  initializeBeanContext();

  tomLog.setLogLevelByName(configuration.logLevel);

  await TomDbMigrations.migrateDatabases(
    configuration.databaseMigrationsDirectory,
  );

  startServer(configuration);

  // Names the resolved environment as well as the port: which overlay won is
  // the first thing anyone asks when a server behaves like the wrong one, and
  // it is decided by a `.env` the operator cannot see from the process list.
  tomLog.info(
    'Todo API server started on port ${configuration.port} '
    '(environment: ${TomRuntime.getCurrentEnvironment().env}).',
  );
}
