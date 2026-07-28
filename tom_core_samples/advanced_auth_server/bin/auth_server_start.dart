/// Live-boot entrypoint for the advanced auth server, and the reflection root
/// for the package (see `build.yaml`).
///
/// This is the smallest single-isolate `TomServer` boot that serves the auth +
/// admin surfaces against the bundled Docker MariaDB. It follows the
/// `core_server_sample` / `tom_uam_server` boot sequence:
///
///   platform → registry → reflection → runtime → config → datasource →
///   JWT signing → bean context → migrations → demo-password seed →
///   `TomServer.start()`
///
/// Unlike `core_server_sample` (whose endpoints are all public), this server
/// authenticates and role-gates, so it adds the two pieces that surface that:
/// the JWT signing configuration (so the minted token pair is properly signed +
/// encrypted, and verifies again here and — with the identical configuration —
/// in the app server at step 21), and the server-level error handler that maps
/// the pipeline's pre-invocation access-denied throw to HTTP 403. The
/// authentication middleware itself is the framework default
/// (`tomDefaultAuthenticationMiddleware`), which `TomServer.start()` installs
/// automatically when the configuration leaves `authenticationMiddleware` null —
/// it is what reads the bearer token into the request zone for
/// `TomBearerAuthentication.getPrincipal()`.
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
// the `forbiddenOnAccessDenied` handler, `userRepository`, and `applyPassword`
// it references directly below.
import 'package:advanced_auth_server/advanced_auth_server.dart';

// Registers the auth/admin/app endpoint definitions with the global
// `tomRemoteApis` registry the endpoint router resolves URIs from.
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

// Registers the ProjectRole → TomAuthState resource-role vocabulary the
// framework's TomResourceRoleAdapter resolves grades through (C-5).
import 'package:advanced_todo_domain/advanced_todo_domain.dart';

import 'auth_server_start.reflection.dart';

/// HTTP port the auth server binds (overridable via the `port` config key / env
/// / `--port=`). 8081 keeps it clear of the app server's 8080.
const int _defaultPort = 8081;

/// Demo passwords seeded onto the seed users' password-less rows so the README
/// `curl`s can log in on first boot — `admin` from the untagged [002] admin seed
/// (present in every environment), `alice`/`bob`/`carol` from the `@dev,test`
/// [003] demo seed, and `dave` from the `@dev,test` [005] two-factor seed
/// (dev/test only). [seedDemoPasswords] fills only the rows that
/// exist, so a production apply (no demo seed) sets just the admin password.
/// Hashing is the auth server's job (never raw SQL), so the migrations leave
/// `password_hash` NULL and the boot fills it through the step-9 [applyPassword]
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
};

/// The auth-server configuration.
///
/// `@tomReflector` so `tomReflectionInfo.setValues<AuthServerConfiguration>` can
/// populate it from the merged config/env/args. The constructor runs after the
/// base has applied the loaded values, so the fields set here are the sample's
/// fixed choices: a single plain-HTTP isolate bound on all interfaces, plus the
/// server-level error handler that yields the admin gate's 403.
@tomReflector
class AuthServerConfiguration extends TomBaseServerConfiguration {
  /// Builds the configuration from the process [args].
  AuthServerConfiguration(super.args) {
    appId = 'auth';
    if (port == 0) port = _defaultPort;
    noSsl = true;
    isolateLogging = false;
    listenToAnyIP = true;
    errorHandler = authServerErrorHandler;
  }

  @override
  void setValues(Map<String, dynamic> values) {
    tomReflectionInfo.setValues<AuthServerConfiguration>(this, values);
    tomAppId = appId;
  }
}

/// The server-level error handler: pipeline access-denied → 403, else the
/// framework default JSON error.
///
/// The endpoint pipeline enforces the contract-declared `TomRoleAccess`
/// (`TomApiEndpoint.access`) *before* the method runs and,
/// on denial, throws the access-denied [TomEndpointHandlerException] *outside*
/// the per-endpoint try/catch — so only a server-level handler can see it.
/// [forbiddenOnAccessDenied] maps exactly that one key to `403 Forbidden` and
/// returns null for everything else; the null is composed here onto
/// [TomDefaultErrorHandler] so genuine faults still get the framework's standard
/// JSON error response rather than an opaque shelf 500.
Response? authServerErrorHandler(
  Request request,
  Object error,
  StackTrace stack,
) =>
    forbiddenOnAccessDenied(request, error, stack) ??
    const TomDefaultErrorHandler()
        .handleErrorDefault(error, stack, request, null);

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
void initializeRuntime() {
  TomRuntime.addEnvironment(environmentProd);
  TomRuntime.addEnvironment(environmentDev);
  TomRuntime.setRootEnvironment(environmentProd);
  TomRuntime.setCurrentEnvironment(Platform.environment['env'], 'prod');
  TomRuntime.getCurrentEnvironment().initialize();
  TomRuntime.initializePlatform();
}

/// Loads `assets/config-resources_default.yaml` plus the active environment
/// overlay (`_<env>.yaml`); env/`.env`/args win on top inside the base config.
Map<String, dynamic> configLoaderFunction() {
  final result = <String, dynamic>{};
  _mergeYamlIfPresent(result, 'assets/config-resources_default.yaml');
  for (final env in TomRuntime.getEnvironmentHierarchy()) {
    _mergeYamlIfPresent(result, 'assets/config-resources_${env.env}.yaml');
  }
  return result;
}

/// Loads `assets/datasources_default.yaml` (with `${VAR:default}` substitution).
Map<String, dynamic> datasourceLoaderFunction() {
  final result = <String, dynamic>{};
  _mergeYamlIfPresent(result, 'assets/datasources_default.yaml');
  return result;
}

void _mergeYamlIfPresent(Map<String, dynamic> into, String path) {
  if (!File(path).existsSync()) return;
  mergeMapsOneSided(into, TomYaml.loadYamlFile(path));
}

/// Installs the config-resource provider so the configuration can read the
/// loaded `config-resources_*.yaml` keys.
void initializeServerResources() {
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from(configLoaderFunction()),
  );
}

/// Configures JWT signing/encryption with the framework's bundled sample keypair.
///
/// The token pair the auth server mints is signed (HS256) and carries an
/// RSA-encrypted access-control payload. Reusing the framework's standard sample
/// keys — rather than minting per-server keys — is what lets the app server
/// (step 21) verify a token issued here by applying the identical configuration.
///
/// The configuration is left marked as a development ("dummy") certificate — the
/// bundled keypair is a non-fresh, non-production convenience shared across every
/// sample. Because it is a dummy cert, the framework emits a development-key
/// warning whenever it signs or verifies a token; that warning is intentionally
/// **not** suppressed (guideline G-AUTH-2). To run against a real certificate,
/// build a [TomJwtConfiguration] from your own keys and pass `isDummy: false`
/// (the last positional argument) so the warning stops.
void initializeJwtSigning() {
  final base = TomJwtConfiguration.defaultSignConfiguration;
  TomJwtConfiguration.defaultSignConfiguration = TomJwtConfiguration(
    TomJwtConfiguration.hmacKey,
    base.algorithm,
    TomJwtConfiguration.rsaPrivKey,
    TomJwtConfiguration.rsaPubKey,
  );
}

/// Emits a boot-time warning when the active signing configuration is still the
/// bundled development ("dummy") certificate.
///
/// Kept separate from [initializeJwtSigning] so the check reads explicitly at the
/// call site: a production deployment installs a real cert (`isDummy: false`) and
/// this stays silent.
void warnIfDevelopmentSigningKey() {
  if (TomJwtConfiguration.defaultSignConfiguration.isDummy) {
    tomLog.warn(
      'JWT signing uses the bundled development certificate (non-fresh, '
      'non-production). Install a real certificate before any real deployment; '
      'see README_advanced_06_authentication.md.',
    );
  }
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

/// Boots the HTTP server (fire-and-forget; the bound socket + open DB connection
/// keep the isolate alive).
void startServer(AuthServerConfiguration configuration) {
  TomServer(configuration).start();
}

Future<void> main(List<String> args) async {
  TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);

  registerAdvancedTodoApis();
  // The issuer the token service signs with; the app server must match it.
  TomAuthenticationServer.globalSettingJwtOrganization = 'tom';

  initializeReflection();
  // Establishes the shared ProjectRole → TomAuthState grade vocabulary the
  // framework's TomResourceRoleAdapter resolves resource keys through (C-5).
  // Every advanced_* runtime registers the identical mapping at boot.
  registerProjectRoleVocabulary();
  initializeRuntime();
  initializeServerResources();

  final configuration = AuthServerConfiguration(args);

  await TomDataSourceInfo.initializeDatasourceInfo(datasourceLoaderFunction());

  initializeJwtSigning();
  warnIfDevelopmentSigningKey();

  initializeBeanContext();

  tomLog.setLogLevelByName(configuration.logLevel);

  await TomDbMigrations.migrateDatabases(
    configuration.databaseMigrationsDirectory,
  );

  await seedDemoPasswords();

  startServer(configuration);

  tomLog.info('Advanced auth server started on port ${configuration.port}.');
}
