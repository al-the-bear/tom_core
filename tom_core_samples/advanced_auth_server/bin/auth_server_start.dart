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
    listenToAnyIP = true;
    errorHandler = authServerErrorHandler;
  }

  @override
  void setValues(Map<String, dynamic> values) {
    tomReflectionInfo.setValues<AuthServerConfiguration>(this, values);
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

/// Loads `assets/blobstores_default.yaml` — where the bytes behind this
/// server's `@TomFileReference` column (`auth_users.avatar_ref`) live.
///
/// Deliberately a separate file from `datasources_default.yaml` even though the
/// only configured store is backed by a data source: the two answer different
/// questions ("which databases do we talk to" vs "where do files go"), and a
/// deployment that moves its files to S3 edits this file alone.
Map<String, dynamic> blobStoreLoaderFunction() {
  final result = <String, dynamic>{};
  _mergeYamlIfPresent(result, 'assets/blobstores_default.yaml');
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

/// Installs the deployment's second-factor policy and enrolment store — the two
/// beans that turn 2FA from "whatever the user row happens to say" into a
/// server-wide rule with a first-login set-up path (C-10).
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
/// `mechanisms` is pinned to TOTP because that is the one adaptor this
/// deployment registers; leaving it null would say "every registered mechanism",
/// which is the same list today and a silently widening one tomorrow.
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
  TomBean.withType(
    Tom2FAPolicy,
    TomRole2FAPolicy(
      requirementByRole: const {
        'two_factor_required': Tom2FARequirement.required,
        'two_factor_optional': Tom2FARequirement.optional,
      },
      mechanisms: const [TomTotp2FAService.mechanismType],
    ),
  );
  TomBean.withType(
    Tom2FAEnrolmentStore,
    LegacyBridging2FAEnrolmentStore(
      TomPersistent2FAEnrolmentStore(TomUserTwoFactorEnrolmentRepository()),
    ),
  );
  tomLog.info(
    'Two-factor policy installed: required for role "two_factor_required", '
    'offered for "two_factor_optional", disabled otherwise; TOTP only, '
    'enrolments persisted to tom_user_two_factor_enrolment.',
  );
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

  // Must follow the datasource init: the `type: database` backend resolves its
  // named data source eagerly, so a store pointing at an unregistered name is a
  // start-up failure rather than a failed upload hours later.
  await TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction());

  initializeJwtSigning();
  warnIfDevelopmentSigningKey();

  initializeBeanContext();
  installTwoFactorPolicy();

  tomLog.setLogLevelByName(configuration.logLevel);

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

  startServer(configuration);

  tomLog.info('Advanced auth server started on port ${configuration.port}.');
}
