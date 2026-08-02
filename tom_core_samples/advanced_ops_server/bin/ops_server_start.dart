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
/// a scheduler. This exists because of the arrangement `[004]` is part of: the
/// app server's `[000]`–`[003]` are mounted into its container's initdb hook and
/// so apply themselves on a fresh volume, while this package's contribution to
/// the same chain lives in a folder that container never sees. Something has to
/// apply it, and the alternatives are worse — a deployment that had to *start*
/// the back-office server to migrate would also be starting its timers, and
/// applying the file by hand would leave the chain's version table not knowing
/// `[004]` had run. `tool/run_ops_integration.sh` uses this before the live
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
@tomReflector
class OpsServerConfiguration extends TomBaseServerConfiguration {
  /// Builds the configuration from the process [args].
  OpsServerConfiguration(super.args) {
    appId = 'ops';
    isolateLogging = false;
  }

  @override
  void setValues(Map<String, dynamic> values) {
    tomReflectionInfo.setValues<OpsServerConfiguration>(this, values);
    tomAppId = appId;
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
void initializeRuntime() {
  TomRuntime.addEnvironment(environmentProd);
  TomRuntime.addEnvironment(environmentDev);
  TomRuntime.setRootEnvironment(environmentProd);
  TomRuntime.setCurrentEnvironment(Platform.environment['env'], 'prod');
  TomRuntime.getCurrentEnvironment().initialize();
  TomRuntime.initializePlatform();
}

/// Loads `assets/config-resources_default.yaml` plus the active overlay.
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

/// Loads `assets/blobstores_default.yaml` — where the scheduled export's bytes
/// land, and where the app server's attachments already are.
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

/// The node identity this process claims in `tom_scheduler_node` and
/// `tom_lease.owner`.
///
/// Derived from `OPS_NODE_ID` when set, else the host name plus the pid. Two ops
/// processes sharing an id would each treat the other's lease as its own, so a
/// default that is merely *probably* distinct is not good enough for a real
/// deployment — which is why the environment variable exists and why a real one
/// sets it.
String resolveNodeId() =>
    Platform.environment['OPS_NODE_ID'] ??
    'ops-${Platform.localHostname}-$pid';

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
  initializeRuntime();
  initializeServerResources();

  // Removed before the configuration parses what is left: the flag decides how
  // much of *this* function runs and is not a configuration value.
  final migrateOnly = args.contains(migrateOnlyFlag);
  final configuration =
      OpsServerConfiguration(args.where((a) => a != migrateOnlyFlag).toList());
  tomLog.setLogLevelByName(configuration.logLevel);

  await TomDataSourceInfo.initializeDatasourceInfo(datasourceLoaderFunction());
  await TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction());

  // The app server's own registrations — see the library comment for why a
  // process that reads its tables must share them.
  registerAppDataScopes();
  registerAppColumnGrades();

  initializeBeanContext();

  // The ops server owns `[004]` of the `app_db/app_schema` chain (the framework
  // tables the scheduler, the leases and the trail need). Running the migration
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

  final appDatasource = TomDataSourceInfo.getDataSourceInfo('app_db')!.datasource;
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
  // the last in-flight run rather than the other way round.
  ProcessSignal.sigint.watch().listen((_) {
    tomLog.info('Advanced ops server stopping.');
    runtime.close();
    exit(0);
  });
}
