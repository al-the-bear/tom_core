/// Live-boot entrypoint for the advanced ops server, and the reflection root
/// for the package (see `build.yaml`).
///
/// ## What is different from the other two servers
///
/// The auth and app servers end their `main` with `TomServer(...).start()` and
/// stay alive because a socket is bound. This one ends with
/// [OpsRuntime.start] and stays alive because timers are pending. Everything
/// before that last line is the *same* sequence, and deliberately so — a
/// back-office process that skipped reflection, or config, or migrations, would
/// be operating on a different set of assumptions from the servers whose data it
/// edits:
///
///   platform → reflection → runtime → config → datasources → blob stores →
///   scopes/grades → bean context → migrations → `OpsRuntime.start()`
///
/// ## Why it needs the app server's registrations at all
///
/// It deletes and reads `app_items` through the *app server's* repository, so it
/// must present the same picture of that entity the app server does. Registering
/// the data scopes and column grades here is not decoration: they are resolved
/// off the entity's annotations at repository construction, and a process that
/// left them unregistered would be a second, subtly different view of one table.
/// The ops server then *bypasses* the scopes explicitly
/// ([TomDataScope.runUnscoped]) rather than by never having installed them —
/// which is the difference between a documented exemption and an accident.
///
/// ## Running it
///
/// From the package root, with both databases up (the app server's compose
/// stack publishes `app_db` on 3308, the auth server's `auth_db` on 3307):
///
/// ```sh
/// dart run bin/ops_server_start.dart
/// ```
///
/// Getting that directory wrong is a caught error rather than a puzzle: the
/// three assets the boot cannot work without are loaded through
/// [mergeRequiredYaml], which names the absolute path it tried and the
/// directory it resolved against. Only the per-environment overlay may be
/// missing — see [mergeOptionalYaml]. This matters more here than in the two
/// HTTP servers: nothing binds a port, so a misconfigured process has no
/// failing request to make the problem visible.
///
/// Nothing is delivered to a real mail server by default: `OPS_SMTP_HOST` is
/// unset, so digests are written as `.eml` files under `OPS_MAIL_DIR`
/// (`./ztmp/ops_mail`) where they can be opened and read. That is the honest
/// sample default — a discarding transport would make a green run and an
/// undelivered digest look identical.
///
/// ## `--migrate-only`
///
/// ```sh
/// dart run bin/ops_server_start.dart --migrate-only
/// ```
///
/// Runs the sequence above as far as the migrations and exits, without starting
/// a scheduler. This exists because of the arrangement `[100]` is part of: the
/// app server's `[000]`–`[099]` band is mounted into its container's initdb
/// hook and so applies itself on a fresh volume, while this package's
/// contribution to the same chain lives in a folder that container never sees. Something has to
/// apply it, and the alternatives are worse — a deployment that had to *start*
/// the back-office server to migrate would also be starting its timers, and
/// applying the file by hand would leave the chain's version table not knowing
/// `[100]` had run. `tool/run_ops_integration.sh` uses this before the live
/// suite for exactly that reason.
library;

import 'dart:io';

import 'package:advanced_app_server/advanced_app_server.dart';
// The auth server's `UserRecord` is reached transitively through this barrel
// (the digest resolves recipients through its repository), so the reflection
// root sees it without naming it here.
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'ops_server_start.reflection.dart';

/// The ops server's configuration.
///
/// Extends the same base the other two servers use even though nothing here
/// listens: the base is what merges `assets/config-resources_*.yaml`, the
/// environment, `.env` and the command line into one picture, and re-deriving
/// that for a process without a port would be a second configuration mechanism
/// in a suite that already has one.
///
/// `appId` is guarded on being unset, which is what makes it a *default* rather
/// than a fixed choice — an unguarded assignment here would overwrite the value
/// the merge just resolved.
@tomReflector
class OpsServerConfiguration extends TomBaseServerConfiguration {
  /// Builds the configuration from the process [args].
  OpsServerConfiguration(super.args) {
    if (appId.isEmpty) appId = 'ops';
    isolateLogging = false;
  }

  /// Binds the merged configuration onto this instance.
  ///
  /// The shared [tomReflectionInfo], deliberately: the merged map carries the
  /// whole process environment, so a `strictUnknownFields` converter would
  /// refuse to start. See [TomBaseServerConfiguration.setValues].
  @override
  void setValues(Map<String, dynamic> values) {
    tomReflectionInfo.setValues<OpsServerConfiguration>(this, values);
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

/// Registers the environment hierarchy and resolves the current environment.
///
/// The lookup is [selectedRuntimeEnvironmentName], which reads the command
/// line, the `.env` file and the OS environment in that order — so the
/// `env=dev` line at the bottom of `.env.example` selects `dev` for the
/// *runtime* as well as for the configuration. Reading only
/// `Platform.environment` would leave the two disagreeing: this server would
/// load the `dev` configuration overlay while running as a production
/// deployment.
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
/// unconditionally, so without it the weekly export has nowhere to write.
const String blobStoresAsset = 'assets/blobstores_default.yaml';

/// Loads [configResourcesAsset] plus the active overlay.
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

/// Loads [blobStoresAsset] — where the scheduled export's bytes land, and where
/// the app server's attachments already are.
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
/// instead would start a back-office process with no configuration, no
/// datasource and no blob store, whose first symptom appears several layers
/// later as a connection or missing-key error that says nothing about the real
/// cause — and this process has no HTTP surface to report it on, so its jobs
/// would simply run against nothing.
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

/// The node identity this process claims in `tom_scheduler_node` and
/// `tom_lease.owner`.
///
/// Derived from `OPS_NODE_ID` when set, else the host name plus the pid. Two ops
/// processes sharing an id would each treat the other's lease as its own, so a
/// default that is merely *probably* distinct is not good enough for a real
/// deployment — which is why the environment variable exists and why a real one
/// sets it.
String resolveNodeId() =>
    Platform.environment['OPS_NODE_ID'] ?? 'ops-${Platform.localHostname}-$pid';

/// Where digests go.
///
/// SMTP when `OPS_SMTP_HOST` is set; otherwise `.eml` files under
/// `OPS_MAIL_DIR`. See the library comment for why the fallback writes files
/// rather than discarding.
TomMessageTransport resolveTransport() {
  final host = Platform.environment['OPS_SMTP_HOST'];
  if (host == null || host.isEmpty) {
    final directory = Directory(
      Platform.environment['OPS_MAIL_DIR'] ?? 'ztmp/ops_mail',
    );
    tomLog.warn(
      'No OPS_SMTP_HOST configured — digests will be written as .eml files to '
      '${directory.path} instead of being sent.',
    );
    return TomFileMessageTransport(directory: directory);
  }
  return TomSmtpTransport(
    TomSmtpSettings(
      host: host,
      port: int.tryParse(Platform.environment['OPS_SMTP_PORT'] ?? '') ?? 587,
      username: Platform.environment['OPS_SMTP_USER'],
      password: Platform.environment['OPS_SMTP_PASSWORD'],
      defaultFrom: _digestSender(),
    ),
  );
}

/// The `From` address digests carry, or `null` to let the transport decide.
TomRecipient? _digestSender() {
  final address = Platform.environment['OPS_MAIL_FROM'];
  if (address == null || address.isEmpty) return null;
  return TomRecipient(address, displayName: 'Advanced Todo');
}

/// The flag that stops the boot after the migrations.
const String migrateOnlyFlag = '--migrate-only';

Future<void> main(List<String> args) async {
  TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);

  initializeReflection();
  registerProjectRoleVocabulary();
  initializeRuntime(args);
  initializeServerResources();

  // Removed before the configuration parses what is left: the flag decides how
  // much of *this* function runs and is not a configuration value.
  final migrateOnly = args.contains(migrateOnlyFlag);
  final configuration = OpsServerConfiguration(
    args.where((a) => a != migrateOnlyFlag).toList(),
  );
  tomLog.setLogLevelByName(configuration.logLevel);

  await TomDataSourceInfo.initializeDatasourceInfo(datasourceLoaderFunction());
  await TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction());

  // The app server's own registrations — see the library comment for why a
  // process that reads its tables must share them.
  registerAppDataScopes();
  registerAppColumnGrades();

  initializeBeanContext();

  // The ops server owns `[100]` and up of the `app_db/app_schema` chain (the
  // framework tables the scheduler, the leases and the trail need). Running the migration
  // from here means the deployment can add the back-office server without
  // editing the app server's package — and the engine's per-(datasource, schema)
  // version table is what lets two packages contribute to one chain.
  await TomDbMigrations.migrateDatabases(
    configuration.databaseMigrationsDirectory,
  );

  if (migrateOnly) {
    tomLog.info('Advanced ops server: migrations applied, exiting.');
    exit(0);
  }

  final appDatasource = TomDataSourceInfo.getDataSourceInfo(
    'app_db',
  )!.datasource;
  final runtime = OpsRuntime.production(
    datasource: appDatasource,
    nodeId: resolveNodeId(),
    transport: resolveTransport(),
    anchorDirectory: Directory(
      Platform.environment['OPS_ANCHOR_DIR'] ?? 'ztmp/ops_anchors',
    ),
    digestSender: _digestSender(),
    // Left false unless the deployment says otherwise, because the default path
    // is inside this process's own writable tree — see `ops_anchoring.dart`.
    anchorStoreIsIndependent:
        Platform.environment['OPS_ANCHOR_INDEPENDENT'] == 'true',
  );

  final jobs = await runtime.start();

  tomLog.info(
    'Advanced ops server started as ${resolveNodeId()}: '
    '${jobs.map((j) => j.name).join(', ')}.',
  );
  tomLog.info(runtime.anchoring.describe());

  // A back-office process has no request to end on, so the only clean stop is a
  // signal. Closing through the runtime is what guarantees the trail outlives
  // the last in-flight run rather than the other way round — and the `await` is
  // load-bearing: `exit(0)` does not wait for pending work, so calling this
  // without it would take the process down with the last audit records still
  // queued, which is the shutdown the trail most needs to survive.
  ProcessSignal.sigint.watch().listen((_) async {
    tomLog.info('Advanced ops server stopping.');
    await runtime.close();
    exit(0);
  });
}
