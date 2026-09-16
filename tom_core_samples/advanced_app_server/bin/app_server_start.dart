/// Live-boot entrypoint for the advanced app server, and the reflection root for
/// the package (see `build.yaml`).
///
/// The smallest single-isolate `TomServer` boot that serves the secured todo
/// board against the bundled Docker MariaDB. It follows the same sequence as the
/// auth server (`core_server_sample` / `tom_uam_server` lineage):
///
///   platform → registry → reflection → runtime → config → JWT signing →
///   datasource → bean context → migrations → `TomServer.start()`
///
/// Every endpoint but `GET /status` is contract-declared
/// `TomAuthenticatedAccess` (`TomApiEndpoint.access`, extracted by the
/// pipeline) — `/status` is `appHealth`, the contract's one `TomPublicAccess`
/// entry, and it avoids `/health` because that path is not a contract
/// endpoint at all but the plain-text liveness probe `TomHealthService`
/// auto-mounts in every server. Because the rest are authenticated, the boot
/// trusts the **same JWT signing key as the auth server**: `installJwtSigning`
/// builds the signing configuration from the three `jwt*` configuration fields,
/// which both servers leave unset, so both fall back to the identical framework
/// sample keypair — which is what lets a token minted by `advanced_auth_server`
/// verify here, the standard "resource server trusts the authorization server"
/// split. Configure `jwtSharedSecretKey` in both and that shared trust becomes
/// a deliberate one; configure it in one only and this server rejects the auth
/// server's tokens. The fallback warns at boot and is refused outright outside a
/// development or test environment.
/// The authentication middleware itself is left null so `TomServer.start()`
/// installs the framework default (`tomDefaultAuthenticationMiddleware`),
/// which verifies the bearer token and places the resulting `TomPrincipal` in
/// the request zone, where handlers read it with
/// `getFromCurrentZone<TomPrincipal>()` — never through the client-side
/// `TomBearerAuthentication` singleton, which is a token store the server
/// middleware never populates (and is not request-scoped, so it is unsafe
/// under concurrent requests). The server-level [appServerErrorHandler] maps
/// the service layer's closed/safe denial keys to HTTP 403/404 — the mapping
/// the services deliberately leave to the boot.
///
/// Two datasources are wired (`assets/datasources_default.yaml`): `app_db` holds
/// the app's own tables, and `main` points at the auth server's `auth_db` — home
/// of the framework authorization tables. The field-grade resolver *reads* the
/// `tom_resource_grant` matrix the auth server seeds; the app server also
/// *writes* to `main`: ownership is stamped as `tom_principal_resource_grant`
/// rows, and cross-user shares as `share`-mode
/// `tom_principal_delegation` rows — both resolved back through the framework
/// delegation resolver as the sole resource-access enforcement path.
///
/// Run it from the package root (relative asset/migration paths resolve against
/// the CWD), with the auth server (and its DB) already up so tokens verify and
/// the grant matrix is reachable:
///
/// ```sh
/// cp .env.example .env
/// docker compose up -d app-db        # MariaDB on host port 3308
/// dart run bin/app_server_start.dart # HTTP on port 8080
/// ```
///
/// Getting that directory wrong is a caught error rather than a puzzle: the
/// three assets the boot cannot work without are loaded through
/// [mergeRequiredYaml], which names the absolute path it tried and the
/// directory it resolved against. Only the per-environment overlay may be
/// missing — see [mergeOptionalYaml].
///
/// This file is also the reflection-generation root (`build.yaml`): the generator
/// follows its import graph to discover every `@tomReflector` / `@tomComponent`
/// type — this config class, the `AppApiService` implementation, the `app_db`
/// records, and (transitively, through the `tom_core_server` barrel) the MariaDB
/// driver, migration adaptor, and `TomResourceGrant`. Regenerate with
/// `./reflection_generation.sh` after changing any reflected shape.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

// Imported for its reflection side effects and its production wiring: the barrel
// re-exports the app API service implementation, the app_db records, the
// repository singletons, and the `appForbiddenOrNotFound` handler this boot
// installs below.
import 'package:advanced_app_server/advanced_app_server.dart';

// Registers the auth/admin/app endpoint definitions with the global
// `tomRemoteApis` registry the endpoint router resolves URIs from.
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

// Registers the ProjectRole → TomAuthState resource-role vocabulary the
// framework's TomResourceRoleAdapter resolves grades through (C-5).
import 'package:advanced_todo_domain/advanced_todo_domain.dart';

import 'app_server_start.reflection.dart';

/// HTTP port the app server binds when nothing else supplies one.
///
/// Every override is the same configuration key, `port`, reached by whichever
/// of the merge's sources is convenient: a config asset, the OS environment,
/// the `.env`, or a `port=9080` command-line argument. The dashed
/// `--port=9080` is **not** among them — a key is the argument text before the
/// first `=`, dashes included, so it fills a key named `--port`, which names no
/// field and is dropped in silence (`TomBaseServerConfiguration.port`,
/// `tom_core_server/doc/cmdline.md`, and pinned in both directions by
/// `configuration_test.dart`).
///
/// Worth getting right here in particular: this server and the auth server must
/// stay on *different* ports, so moving one is the case where the override is
/// actually reached for — and the dashed form fails as a port conflict on the
/// other server rather than as a rejected argument.
///
/// 8080 keeps it clear of the auth server's 8081. This constant applies only
/// where that merge left the field at `0`, which is what makes it a default
/// rather than a fixed choice.
const int _defaultPort = 8080;

/// The app-server configuration.
///
/// `@tomReflector` so `tomReflectionInfo.setValues<AppServerConfiguration>` can
/// populate it from the merged config/env/args. The constructor runs after the
/// base has applied the loaded values, so the fields set here are the sample's
/// fixed choices: a single plain-HTTP isolate bound on all interfaces, plus the
/// server-level error handler that yields the service layer's 403/404. `appId`
/// and `port` are guarded on being unset, which is what makes them *defaults*
/// rather than fixed choices — an unguarded assignment here would overwrite the
/// value the merge just resolved.
@tomReflector
class AppServerConfiguration extends TomBaseServerConfiguration {
  /// Builds the configuration from the process [args].
  AppServerConfiguration(super.args) {
    if (appId.isEmpty) appId = 'app';
    if (port == 0) port = _defaultPort;
    noSsl = true;
    isolateLogging = false;
    listenToAnyIP = true;
    errorHandler = appServerErrorHandler;
  }

  /// Binds the merged configuration onto this instance.
  ///
  /// The shared [tomReflectionInfo], deliberately: the merged map carries the
  /// whole process environment, so a `strictUnknownFields` converter would
  /// refuse to start. See [TomBaseServerConfiguration.setValues].
  @override
  void setValues(Map<String, dynamic> values) {
    tomReflectionInfo.setValues<AppServerConfiguration>(this, values);
  }
}

/// The server-level error handler: the service layer's denial keys → 403/404,
/// else the framework default JSON error.
///
/// The read/write/share services throw stable [TomEndpointHandlerException] keys
/// (`app.access.forbidden`, `app.item.not_found`, …) rather than HTTP responses,
/// and the endpoint pipeline's pre-invocation auth check throws its access-denied
/// exception *outside* the per-endpoint try/catch — so only a server-level
/// handler can map them. [appForbiddenOrNotFound] turns those keys into 403/404
/// and returns null for everything else; the null is composed here onto
/// [TomDefaultErrorHandler] so genuine faults still get the framework's standard
/// JSON error response rather than an opaque shelf 500.
Response? appServerErrorHandler(
  Request request,
  Object error,
  StackTrace stack,
) =>
    appForbiddenOrNotFound(request, error, stack) ??
    const TomDefaultErrorHandler().handleErrorDefault(
      error,
      stack,
      request,
      null,
    );

/// Production environment — the root of the (small) environment hierarchy.
const TomEnvironment environmentProd = TomEnvironment('prod');

/// Development overlay selected by `env=dev`.
const TomEnvironment environmentDev = TomEnvironment(
  'dev',
  parent: environmentProd,
  isDevelopment: true,
  isTest: true,
);

/// Registers the environment hierarchy and resolves the current environment from
/// the `env` variable (defaults to `prod`).
///
/// The lookup is [selectedRuntimeEnvironmentName], which reads the command
/// line, the `.env` file and the OS environment in that order — so the
/// `env=dev` line at the bottom of `.env.example` selects `dev` for the
/// *runtime* as well as for the configuration. Reading only
/// `Platform.environment` would leave the two disagreeing: this server would
/// load `config-resources_dev.yaml` while running as a production deployment.
void initializeRuntime(List<String> args) {
  TomRuntime.addEnvironment(environmentProd);
  TomRuntime.addEnvironment(environmentDev);
  TomRuntime.setRootEnvironment(environmentProd);
  TomRuntime.setCurrentEnvironment(
    selectedRuntimeEnvironmentName(args),
    'prod',
  );
  TomRuntime.getCurrentEnvironment().initialize();
  TomRuntime.initializePlatform();
}

/// The base configuration asset — required; the boot has no configuration
/// without it.
const String configResourcesAsset = 'assets/config-resources_default.yaml';

/// The datasource asset — required; the boot has no database without it.
const String datasourcesAsset = 'assets/datasources_default.yaml';

/// The blob-store asset — required; `initializeBlobStores` is called
/// unconditionally, so without it the file columns have nowhere to put bytes.
const String blobStoresAsset = 'assets/blobstores_default.yaml';

/// Loads [configResourcesAsset] plus the active environment overlay
/// (`_<env>.yaml`); env/`.env`/args win on top inside the base config.
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

/// Loads [datasourcesAsset] (with `${VAR:default}` substitution).
Map<String, dynamic> datasourceLoaderFunction() {
  final result = <String, dynamic>{};
  mergeRequiredYaml(result, datasourcesAsset);
  return result;
}

/// Loads [blobStoresAsset] — where the bytes behind this server's
/// `@TomFileReference` columns live.
///
/// Deliberately a separate file from [datasourcesAsset] even though the only
/// configured store is backed by a data source: the two answer different
/// questions ("which databases do we talk to" vs "where do files go"), and a
/// deployment that moves its files to S3 edits this file alone.
Map<String, dynamic> blobStoreLoaderFunction() {
  final result = <String, dynamic>{};
  mergeRequiredYaml(result, blobStoresAsset);
  return result;
}

/// Merges [path] into [into], throwing a [StateError] if it is not there.
///
/// The message names the *absolute* path that was tried and the directory it
/// was resolved against, because the cause is almost never a missing file — the
/// assets ship with the package — but a wrong working directory, and the
/// relative path alone only repeats what the reader already wrote. Skipping
/// instead would start a server with no configuration, no datasource and no
/// blob store, whose first symptom appears several layers later as a connection
/// or missing-key error that says nothing about the real cause.
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
    TomYaml.mergeInYamlFileIfPresent(into, path);

void _mergeYaml(Map<String, dynamic> into, String path) {
  mergeMapsOneSided(into, TomYaml.loadYamlFile(path));
}

/// Installs the config-resource provider so the configuration can read the loaded
/// `config-resources_*.yaml` keys.
void initializeServerResources() {
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(configLoaderFunction()),
  );
}

/// Boots the HTTP server (fire-and-forget; the bound socket + open DB connection
/// keep the isolate alive).
Future<void> startServer(AppServerConfiguration configuration) async {
  // Awaited, so a bind failure — the port already in use is the everyday one —
  // arrives here rather than as an unhandled asynchronous error from a future
  // nobody held. The call still returns as soon as the socket is listening;
  // it is that socket, not this function, that keeps the isolate alive.
  await TomServer(configuration).start();
}

Future<void> main(List<String> args) async {
  TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);

  registerAdvancedTodoApis();
  // The issuer the auth server signs with; the app server must match it to
  // verify a minted token.
  TomAuthenticationServer.globalSettingJwtOrganization = 'tom';

  initializeReflection();
  // Establishes the shared ProjectRole → TomAuthState grade vocabulary the
  // framework's TomResourceRoleAdapter resolves resource keys through (C-5).
  // Every advanced_* runtime registers the identical mapping at boot.
  registerProjectRoleVocabulary();
  initializeRuntime(args);
  initializeServerResources();

  final configuration = AppServerConfiguration(args);

  // Verifies with `jwtSharedSecretKey` and decrypts the access-control payload
  // with the configured RSA pair. This server is the *verifier* of the pair, so
  // the three values must match `advanced_auth_server`'s exactly; both leave
  // them unset here, so both fall back to the framework's bundled sample keys
  // with a warning — which the framework permits only because `env=dev`
  // selected a development environment.
  //
  // It runs here, immediately after the configuration and before any datasource
  // is opened, because outside a development environment it *refuses* the
  // bundled keys. A refusal is only useful if it arrives before the boot has
  // connected to a database and run its migrations — the server cannot serve
  // either way, so it should say so while it has done nothing yet.
  installJwtSigning(configuration);

  await TomDataSourceInfo.initializeDatasourceInfo(datasourceLoaderFunction());

  // Must follow the datasource init: the `type: database` backend resolves its
  // named data source eagerly, so a store pointing at an unregistered name is a
  // start-up failure rather than a failed upload hours later.
  await TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction());

  // Register the async `visible:project|list|item` data scopes so the CRUD
  // repository pushes each caller's owned ∪ shared id-set to `app_db` as an
  // OR-union predicate — the DB-side counterpart of the app read service's
  // in-memory visibility filter. Must run after *both* reflection init and
  // datasource init: it eagerly builds the production repositories, which
  // resolve their reflected persistence types and their datasource metadata at
  // construction time. Registered before serving.
  registerAppDataScopes();

  // C-4: register the per-row grade of the item's `attachment` column, so the
  // file endpoint's three operations resolve the caller's role on *this item's*
  // project and grade the column from the same seeded grant matrix that grades
  // the item's fields. Same ordering constraint as the data scopes above — it
  // eagerly builds the production resolvers.
  registerAppColumnGrades();

  initializeBeanContext();

  tomLog.setLogLevelByName(configuration.logLevel);

  await TomDbMigrations.migrateDatabases(
    configuration.databaseMigrationsDirectory,
  );

  // Publishes `POST|GET|HEAD|DELETE /files/app_items/{id}/attachment`. One line,
  // naming the repository and nothing else: the table name, the column name and
  // the store all come off the entity's own annotations, so there is no second
  // copy of them to drift. `internal_note` is a file column of the same entity
  // and is *not* published — it says nothing about `exposed`, and the default is
  // closed.
  //
  // `TomFileService` needs no bean: it is a `@tomService` like any other, and
  // the router constructs its `@tomComponent` implementation (`TomFileServer`)
  // when it mounts the reflected endpoint pipeline.
  TomFileSlots.register(itemRepository);

  await startServer(configuration);

  tomLog.info('Advanced app server started on port ${configuration.port}.');
}
