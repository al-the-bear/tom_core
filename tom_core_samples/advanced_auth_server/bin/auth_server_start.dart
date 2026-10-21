/// Live-boot entrypoint for the advanced auth server, and the reflection root
/// for the package (see `build.yaml`).
///
/// This is the smallest single-isolate `TomServer` boot that serves the auth +
/// admin surfaces against the bundled Docker MariaDB. It follows the
/// `core_server_sample` / `tom_uam_server` boot sequence:
///
///   platform → registry → reflection → runtime → config → JWT signing →
///   datasource → bean context → migrations → demo-password seed →
///   `TomServer.start()`
///
/// Unlike `core_server_sample` (whose endpoints are all public), this server
/// authenticates and role-gates, so it adds the two pieces that surface that:
/// the JWT signing configuration (so the minted token pair is properly signed +
/// encrypted, and verifies again here and — with the identical configuration —
/// in `advanced_app_server`), and the server-level error handler that maps
/// the pipeline's pre-invocation access-denied throw to HTTP 403. The
/// authentication middleware itself is the framework default
/// (`tomDefaultAuthenticationMiddleware`), which `TomServer.start()` installs
/// automatically when the configuration leaves `authenticationMiddleware` null —
/// it verifies the bearer token and places the resulting `TomPrincipal` in the
/// request zone, where handlers read it with `getFromCurrentZone<TomPrincipal>()`
/// — never through the client-side `TomBearerAuthentication` singleton, which is
/// a token store the server middleware never populates (and is not
/// request-scoped, so it is unsafe under concurrent requests). See the comment
/// on `AdvancedAuthApiService.me()` for the same warning at the point of use.
///
/// Run it from the package root (relative asset/migration paths resolve against
/// the CWD):
///
/// ```sh
/// cp .env.example .env
/// docker compose up -d auth-db
/// dart run bin/auth_server_start.dart
/// ```
///
/// Getting that directory wrong is a caught error rather than a puzzle: the
/// three assets the boot cannot work without are loaded through
/// [mergeRequiredYaml], which names the absolute path it tried and the
/// directory it resolved against. Only the per-environment overlay may be
/// missing — see [mergeOptionalYaml].
///
/// This file is also the reflection-generation root (`build.yaml`): the
/// generator follows its import graph to discover every `@tomReflector` /
/// `@tomComponent` type — this config class, the auth + admin API service
/// implementations, the auth_db records, and (transitively, through the
/// `tom_core_server` barrel) the MariaDB driver, migration adaptor, and
/// `TomResourceGrant`. Regenerate with `./reflection_generation.sh` after
/// changing any reflected shape.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

// Imported for its reflection side effects and its production wiring: the barrel
// re-exports the auth/admin service implementations, the auth_db records, the
// password helper, and the repository singletons, pulling them into this
// entrypoint's import graph so the generator captures them — and giving the boot
// the `userRepository` and `applyPassword` it references directly below.
import 'package:advanced_auth_server/advanced_auth_server.dart';

// Registers the auth/admin/app endpoint definitions with the global
// `tomRemoteApis` registry the endpoint router resolves URIs from.
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

// Registers the ProjectRole → TomAuthState resource-role vocabulary the
// framework's TomResourceRoleAdapter resolves grades through.
import 'package:advanced_todo_domain/advanced_todo_domain.dart';

import 'auth_server_start.reflection.dart';

/// HTTP port the auth server binds when nothing else supplies one.
///
/// Every override is the same configuration key, `port`, reached by whichever
/// of the merge's sources is convenient: a config asset, the OS environment,
/// the `.env`, or a `port=9081` command-line argument. The dashed
/// `--port=9081` is **not** among them — a key is the argument text before the
/// first `=`, dashes included, so it fills a key named `--port`, which names no
/// field and is dropped in silence (`TomBaseServerConfiguration.port`,
/// `tom_core_server/doc/cmdline.md`, and pinned in both directions by
/// `configuration_test.dart`).
///
/// Worth getting right here in particular: this server and the app server must
/// stay on *different* ports, so moving one is the case where the override is
/// actually reached for — and the dashed form fails as a port conflict on the
/// other server rather than as a rejected argument.
///
/// 8081 keeps it clear of the app server's 8080. This constant applies only
/// where that merge left the field at `0`, which is what makes it a default
/// rather than a fixed choice.
const int _defaultPort = 8081;

/// Demo passwords seeded onto the seed users' password-less rows so the README
/// `curl`s can log in on first boot — `admin` from the untagged [002] admin seed
/// (present in every environment), `alice`/`bob`/`carol` from the `@dev,test`
/// [003] demo seed, and `dave`/`erin` from the `@dev,test` [005] two-factor
/// seed (dev/test only). [seedDemoPasswords] fills only the rows that exist,
/// so a production apply (no demo seed) sets just the admin password.
/// Hashing is the auth server's job (never raw SQL), so the migrations leave
/// `password_hash` NULL and the boot fills it through the [applyPassword]
/// helper. Sample credentials only — never ship these.
const Map<String, String> _demoPasswords = {
  'admin': 'admin-pass',
  'alice': 'alice-pass',
  'bob': 'bob-pass',
  'carol': 'carol-pass',
  // Dave (from the `@dev,test` [005] seed) is enrolled in TOTP, so this password
  // only gets him through pass 1: his login answers with a challenge that must
  // be completed at `POST /auth/second-factor` with a code derived from the
  // seeded secret. He exists so the two-pass path is exercised out of the box.
  'dave': 'dave-pass',
  // Erin is dave's mirror image: the same [005] seed, no factor of her own, and
  // the `two_factor_optional` role — so this password gets her to the *enrolment
  // offer* rather than to a challenge or to a session. She exists so the set-up
  // path, and the decline that must remain possible under an optional policy,
  // are exercised out of the box too.
  'erin': 'erin-pass',
};

/// The auth-server configuration.
///
/// `@tomReflector` so `tomReflectionInfo.setValues<AuthServerConfiguration>` can
/// populate it from the merged config/env/args. The constructor runs after the
/// base has applied the loaded values, so the fields set here are the sample's
/// fixed choices: a single plain-HTTP isolate bound on all interfaces, plus the
/// server-level error handler that yields the admin gate's 403. `appId` and
/// `port` are guarded on being unset, which is what makes them *defaults*
/// rather than fixed choices — an unguarded assignment here would overwrite the
/// value the merge just resolved.
@tomReflector
class AuthServerConfiguration extends TomBaseServerConfiguration {
  /// Builds the configuration from the process [args].
  AuthServerConfiguration(super.args) {
    if (appId.isEmpty) appId = 'auth';
    if (port == 0) port = _defaultPort;
    noSsl = true;
    isolateLogging = false;
    listenToAnyIp = true;
    errorHandler = authServerErrorHandler;
  }

  /// Binds the merged configuration onto this instance.
  ///
  /// The shared [tomReflectionInfo], deliberately: the merged map carries the
  /// whole process environment, so a `strictUnknownFields` converter would
  /// refuse to start. See [TomBaseServerConfiguration.setValues].
  @override
  void setValues(Map<String, dynamic> values) {
    tomReflectionInfo.setValues<AuthServerConfiguration>(this, values);
  }
}

/// The server-level error handler: the framework's default JSON error.
///
/// This level sees only what no other level claimed. A pre-invocation access
/// denial does not reach it — `tom_core_server` answers that itself, with a
/// bare `404` that carries no key — and an error raised *inside* a method is
/// offered to the endpoint's own handler first. What is left is a fault with no
/// owner, and it gets the framework's standard JSON error rather than an opaque
/// shelf 500.
///
/// It is a function rather than nothing because the seam is what the
/// configuration installs, and a deployment that grows a server-wide mapping
/// adds it here.
Response? authServerErrorHandler(
  Request request,
  Object error,
  StackTrace stack,
) => const TomDefaultErrorHandler().handleErrorDefault(
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

/// Registers the environment hierarchy and resolves the current environment
/// from the `env` variable (defaults to `prod`).
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
/// unconditionally, so without it the avatar column has nowhere to put bytes.
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
/// `@TomFileReference` column (`auth_users.avatar_ref`) live.
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

/// Installs the config-resource provider so the configuration can read the
/// loaded `config-resources_*.yaml` keys.
void initializeServerResources() {
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(configLoaderFunction()),
  );
}

/// Fills a demo password onto every seed user that still has none, so the
/// README `curl`s can authenticate on first boot.
///
/// Idempotent: a user that already carries a hash (a re-boot, or a password set
/// through the admin API) is left untouched, so this never clobbers a real
/// credential.
Future<void> seedDemoPasswords() async {
  for (final entry in _demoPasswords.entries) {
    final matches = await userRepository.findByQuerySentence(
      'FIND BY username = :username',
      {'username': entry.key},
    );
    if (matches.isEmpty) continue;
    final user = matches.first;
    if ((user.passwordHash ?? '').isNotEmpty) continue;
    await userRepository.save(applyPassword(user, entry.value));
    tomLog.info('Seeded demo password for "${entry.key}".');
  }
}

/// Installs the deployment's second-factor policy and enrolment store — the two
/// beans that turn 2FA from "whatever the user row happens to say" into a
/// server-wide rule with a first-login set-up path.
///
/// **The rule is carried by two roles, not by a server-wide default.** The
/// `two_factor_optional` role makes a login *offer* a factor the holder may
/// decline; `two_factor_required` makes it insist. The `@dev,test` [005] seed
/// puts `erin` in the first and `dave` in the second, so one boot demonstrates
/// all three branches the framework offers — enrol, skip, and challenge — while
/// every other account signs in exactly as it did before 2FA existed.
///
/// The obvious alternative, `defaultRequirement: optional` with no rules, is a
/// perfectly truthful configuration and a worse sample: it makes *every* login
/// an enrolment dialogue, so the suites about grant matrices, shares and file
/// uploads would each open with a 2FA step about something else. Two roles cost
/// two seed rows and keep "which accounts owe a factor" answerable by reading
/// one table.
///
/// Declining costs nothing under `optional` (it spends no grace login), which is
/// what makes the skip path repeatable rather than a one-shot the next run
/// cannot reproduce.
///
/// Roles rather than the principal flag: [TomRole2FAPolicy] reads the roles the
/// principal already carries in its access-control information, so the axis that
/// grants a privilege and the axis that demands a factor cannot drift apart.
/// `mechanisms` is pinned to [advancedTwoFactorMechanisms] — TOTP and passkeys —
/// rather than left null, which would say "every registered mechanism": the
/// same list today and a silently widening one tomorrow. Passkeys are offered
/// once [installPasskeyRelyingParty] has bound them to `localhost`.
///
/// **The store is the persistent one, bridged.** Installing any store makes it
/// the authority on whether a user has a factor, which would send the seeded
/// `dave` — whose secret lives in the legacy `auth_users.two_factor_secret`
/// column — to enrolment rather than to the challenge he can already answer.
/// [LegacyBridging2FAEnrolmentStore] reports that column as one synthetic
/// enrolment when the table has no row, so seeded accounts keep their challenge
/// while everyone else enrols into the table. See its own docs for why the
/// bridge belongs here and not in the framework.
void installTwoFactorPolicy() {
  TomBean.withType<Tom2FAPolicy>(
    TomRole2FAPolicy(
      requirementByRole: const {
        'two_factor_required': Tom2FARequirement.required,
        'two_factor_optional': Tom2FARequirement.optional,
      },
      mechanisms: advancedTwoFactorMechanisms,
    ),
  );
  TomBean.withType<Tom2FAEnrolmentStore>(
    LegacyBridging2FAEnrolmentStore(
      TomPersistent2FAEnrolmentStore(TomUserTwoFactorEnrolmentRepository()),
    ),
  );
  tomLog.info(
    'Two-factor policy installed: required for role "two_factor_required", '
    'offered for "two_factor_optional", disabled otherwise; TOTP and '
    'passkeys, '
    'enrolments persisted to tom_user_two_factor_enrolment.',
  );
}

/// Boots the HTTP server (fire-and-forget; the bound socket + open DB connection
/// keep the isolate alive).
Future<void> startServer(AuthServerConfiguration configuration) async {
  // Awaited, so a bind failure — the port already in use is the everyday one —
  // arrives here rather than as an unhandled asynchronous error from a future
  // nobody held. The call still returns as soon as the socket is listening;
  // it is that socket, not this function, that keeps the isolate alive.
  await TomServer(configuration).start();
}

Future<void> main(List<String> args) async {
  TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);

  registerAdvancedTodoApis();

  initializeReflection();
  // Establishes the shared ProjectRole → TomAuthState grade vocabulary the
  // framework's TomResourceRoleAdapter resolves resource keys through.
  // Every advanced_* runtime registers the identical mapping at boot.
  registerProjectRoleVocabulary();
  initializeRuntime(args);
  initializeServerResources();

  final configuration = AuthServerConfiguration(args);

  // Signs (RS256) with the private key `jwtSigningKeyFile` names, under the
  // configured `jwtIssuer`/`jwtAudience`, and publishes the public half at
  // `GET /.well-known/jwks.json`; `advanced_app_server` verifies with that
  // public half (`jwtVerificationKeyFiles`). The access-control payload is
  // encrypted with the `jwtRsaPrivKey`/`jwtRsaPubKey` pair, which both servers
  // hold. Leave them unset, as this sample does, and both servers fall back to
  // the framework's bundled sample keys with a warning — which it permits only
  // because `env=dev` selected a development environment.
  //
  // It runs here, immediately after the configuration and before any datasource
  // is opened, because outside a development environment it *refuses* the
  // bundled keys. A refusal is only useful if it arrives before the boot has
  // connected to two databases and run their migrations — the server cannot
  // serve either way, so it should say so while it has done nothing yet.
  installJwtSigning(configuration);

  await TomDataSourceInfo.initializeDatasourceInfo(datasourceLoaderFunction());

  // Must follow the datasource init: the `type: database` backend resolves its
  // named data source eagerly, so a store pointing at an unregistered name is a
  // start-up failure rather than a failed upload hours later.
  await TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction());

  initializeBeanContext();
  installPasskeyRelyingParty();
  installTwoFactorPolicy();

  tomLog.setLogLevelByName(configuration.logLevel);

  // An operator's repair of a failed migration
  // (`--repair-migration=<datasource>/<schema>/<version>
  // --repair-action=remove|resolve`) runs instead of the start, and exits.
  if (await TomDbMigrations.repairFromArgs(args)) {
    tomLog.info('Migration repaired, exiting.');
    exit(0);
  }

  await TomDbMigrations.migrateDatabases(
    configuration.databaseMigrationsDirectory,
  );

  await seedDemoPasswords();

  // Publishes `POST|GET|HEAD|DELETE /files/auth_users/{id}/avatar_ref`. One
  // line, naming the repository and nothing else: the table name, the column
  // name and the store all come off the entity's own annotations, so there is no
  // second copy of them to drift.
  //
  // `TomFileService` needs no bean: it is a `@tomService` like any other, and
  // the router constructs its `@tomComponent` implementation (`TomFileServer`)
  // when it mounts the reflected endpoint pipeline.
  TomFileSlots.register(userRepository);

  await startServer(configuration);

  tomLog.info('Advanced auth server started on port ${configuration.port}.');
}
