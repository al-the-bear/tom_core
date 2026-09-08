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
/// cd tom_core_samples/core_server_sample
/// cp .env.example .env
/// docker compose up -d db
/// dart run bin/server_start.dart
/// ```
///
/// Getting that `cd` wrong is a caught error rather than a puzzle: the two
/// assets the boot cannot work without are loaded through [mergeRequiredYaml],
/// which names the absolute path it tried and the directory it resolved
/// against. Only the per-environment overlay may be missing — see
/// [mergeOptionalYaml].
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

/// HTTP port the sample binds when nothing else supplies one.
///
/// Every override is the same configuration key, `port`, reached by whichever
/// of the merge's sources is convenient: a config asset, the OS environment,
/// the `.env`, or a `port=9000` command-line argument. The dashed
/// `--port=9000` is **not** among them — a key is the argument text before the
/// first `=`, dashes included, so it fills a key named `--port`, which names no
/// field and is dropped in silence (`TomBaseServerConfiguration.port`,
/// `tom_core_server/doc/cmdline.md`, and pinned in both directions by
/// `configuration_test.dart`).
///
/// This constant applies only where that merge left the field at `0`, which is
/// what makes it a default rather than a fixed choice.
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

  /// Binds the merged configuration onto this instance.
  ///
  /// The shared [tomReflectionInfo], deliberately: the merged map carries the
  /// whole process environment, so a `strictUnknownFields` converter would
  /// refuse to start. See [TomBaseServerConfiguration.setValues].
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

/// The base configuration asset — required; the boot has no configuration
/// without it.
const String configResourcesAsset = 'assets/config-resources_default.yaml';

/// The datasource asset — required; the boot has no database without it.
const String datasourcesAsset = 'assets/datasources_default.yaml';

/// Loads [configResourcesAsset] plus the active environment overlay
/// (`_<env>.yaml`); OS env, `.env` and args win on top of the result inside the
/// base config (`TomBaseServerConfiguration.getDefaultValues`).
///
/// The base is required and the overlay is not, which is the whole of the
/// difference between [mergeRequiredYaml] and [mergeOptionalYaml]: every
/// environment in the hierarchy is asked for an overlay, and the root one
/// (`prod`) ships none.
Map<String, dynamic> configLoaderFunction() {
  final result = <String, dynamic>{};
  mergeRequiredYaml(result, configResourcesAsset);
  for (final env in TomRuntime.getEnvironmentHierarchy()) {
    mergeOptionalYaml(result, 'assets/config-resources_${env.env}.yaml');
  }
  return result;
}

/// Loads [datasourcesAsset] (with `${VAR:default}` substitution against
/// [_environment], so the connection follows `.env`).
Map<String, dynamic> datasourceLoaderFunction() {
  final result = <String, dynamic>{};
  mergeRequiredYaml(result, datasourcesAsset);
  return result;
}

/// Merges [path] into [into], throwing a [StateError] if it is not there.
///
/// The message names the *absolute* path that was tried and the directory it
/// was resolved against, because the cause is almost never a missing file — the
/// assets ship with the package — but a wrong working directory, and the
/// relative path alone only repeats what the reader already wrote. Skipping
/// instead would start a server with no configuration and no datasource, whose
/// first symptom appears several layers later as a connection or missing-key
/// error that says nothing about the real cause.
void mergeRequiredYaml(Map<String, dynamic> into, String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Required boot asset not found: ${file.absolute.path}\n'
      'Resolved against the working directory ${Directory.current.path}.\n'
      'Run the server from the package root, where assets/ and '
      'database_migrations/ live.',
    );
  }
  _mergeYaml(into, path);
}

/// Merges [path] into [into] if it exists, and reports whether it did.
///
/// Only the per-environment overlay may be absent: [configLoaderFunction] asks
/// every environment in the hierarchy for one, and the root (`prod`) ships
/// none. A wrong working directory does not reach this function undiagnosed —
/// the required base asset is loaded first and throws.
///
/// The framework answers this, rather than a local `existsSync` guard, so that
/// the tolerance stays narrow: `mergeInYamlFileIfPresent` forgives an absent
/// file and nothing else, so an overlay that is *there* and does not parse
/// still stops the boot instead of being skipped as though it were missing.
bool mergeOptionalYaml(Map<String, dynamic> into, String path) =>
    TomYaml.mergeInYamlFileIfPresent(into, path, environment: _environment);

void _mergeYaml(Map<String, dynamic> into, String path) {
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
