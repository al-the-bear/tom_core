/// The sample's walk through tenancy, step by step, against a live MariaDB or
/// PostgreSQL. `bin/multi_tenant_start.dart` runs it and prints what each step
/// found; `test/live_scenario_test.dart` runs it and asserts it.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'entities.dart';

/// The database the sample runs against, read from the environment:
/// `MT_DB_ENGINE` (`mariadb` or `postgresql`), `MT_DB_HOST`, `MT_DB_PORT`,
/// `MT_DB_USER`, `MT_DB_PASSWORD`, `MT_DB_NAME`.
class MtDatabase {
  /// A database of [engine] at [host]:[port].
  const MtDatabase({
    required this.engine,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.name,
  });

  /// The database the environment names; the defaults are the sample's
  /// `docker-compose.yaml`.
  factory MtDatabase.fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final engine = env['MT_DB_ENGINE'] ?? 'mariadb';
    final postgres = engine == 'postgresql';
    return MtDatabase(
      engine: engine,
      host: env['MT_DB_HOST'] ?? '127.0.0.1',
      port: int.parse(env['MT_DB_PORT'] ?? (postgres ? '5441' : '3341')),
      user: env['MT_DB_USER'] ?? (postgres ? 'postgres' : 'root'),
      password: env['MT_DB_PASSWORD'] ?? 'password',
      name: env['MT_DB_NAME'] ?? 'mtapp',
    );
  }

  /// `mariadb` or `postgresql`, the data source's `type`.
  final String engine;

  /// The server's host.
  final String host;

  /// The server's port.
  final int port;

  /// The user; it creates the tenants' schemas.
  final String user;

  /// The password.
  final String password;

  /// The database — the system schema on MariaDB, the database holding every
  /// schema on PostgreSQL.
  final String name;

  /// The settings of the data source `main`.
  Map<String, Object> get settings => {
    'type': engine,
    'host': host,
    'port': port,
    'username': user,
    'password': password,
    'databaseName': name,
    if (engine == 'postgresql') 'sslMode': 'disable',
  };

  /// Whether a server answers at [host]:[port].
  Future<bool> isReachable() async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }
}

/// The server configuration the sample's start reads nothing but defaults
/// from: the tenancy and the migrations come from the configuration
/// resources (`assets/config.yaml`).
class MtServerConfiguration extends TomBaseServerConfiguration {
  /// Defaults only.
  MtServerConfiguration() : super(const []);

  @override
  void setValues(Map<String, Object?> values) {}
}

/// What the start did — the tenancy steps of `TomServer.start`, in its order.
class MtStart {
  /// The three results.
  const MtStart(this.tenancy, this.migration, this.guard);

  /// What `configureTenancy` decided.
  final TomTenancyStartupReport tenancy;

  /// What `migrateOnStart` migrated.
  final TomMigrationResult? migration;

  /// How the system schema stands against the code (`guardSchemaOnStart`).
  final TomSchemaVersionCheck? guard;
}

/// The sample, step by step.
class MultiTenantSample {
  /// The sample against [database].
  MultiTenantSample(this.database);

  /// Where it runs.
  final MtDatabase database;

  /// The configuration resources, `assets/config.yaml`.
  late final TomServerConfigResourceProvider config;

  late final MtPlanRepository _plans = MtPlanRepository();
  late final MtInvoiceRepository _invoices = MtInvoiceRepository();
  late final MtContractRepository _contracts = MtContractRepository();
  late final MtReviewReportRepository _reports = MtReviewReportRepository();

  /// The installed tenancy.
  TomTenancy get tenancy => TomTenancy.current!;

  /// Registers `main` and runs the tenancy steps of `TomServer.start` — the
  /// same calls, in the same order, without binding a socket: the tenancy
  /// the configuration describes installed and checked, the migrations of the
  /// system schema, each type's shared schema and each tenant of its own, and
  /// the version guard.
  Future<MtStart> start() async {
    await TomDataSourceInfo.initializeDatasourceInfo({
      'main': database.settings,
    });
    config = TomServerConfigResourceProvider.from(
      TomYaml.loadYamlFile('assets/config.yaml'),
    );
    TomServerConfigResourceProvider.setServerConfigProvider(config);
    final server = TomServer(MtServerConfiguration());
    final tenancyReport = await server.configureTenancy(config);
    final migration = await server.migrateOnStart(config);
    final guard = await server.guardSchemaOnStart(config);
    return MtStart(tenancyReport, migration, guard);
  }

  /// The plan catalogue as [tenant] reads it: a system table, the same rows in
  /// every tenant.
  Future<List<String>> plansIn(String tenant) async => [
    for (final plan in await tenancy.runFor(tenant, _plans.findAll)) plan.code!,
  ]..sort();

  /// Writes a new invoice of [tenant] — `insert`, since its id is chosen
  /// here: `save` with an id set is an update of a row that exists.
  Future<void> invoice(String tenant, String id, String plan, int cents) =>
      tenancy.runFor(
        tenant,
        () => _invoices.insert(
          MtInvoice()
            ..id = id
            ..planCode = plan
            ..amountCents = cents,
        ),
      );

  /// The invoice ids [tenant] sees: its own only.
  Future<List<String>> invoicesOf(String tenant) async => [
    for (final invoice in await tenancy.runFor(tenant, _invoices.findAll))
      invoice.id!,
  ]..sort();

  /// Writes a contract of [tenant].
  Future<void> contract(String tenant, String id, String title) =>
      tenancy.runFor(
        tenant,
        () => _contracts.insert(
          MtContract()
            ..id = id
            ..title = title,
        ),
      );

  /// Onboards [tenant] of [type] at runtime: recorded, provisioned, migrated
  /// by its type's tree and served — one call.
  Future<TomMigrationRun?> onboard(String tenant, String type) =>
      tenancy.addTenant(TomTenant(tenant, type: type));

  /// Runs the contract review — a job planned once per active `enterprise`
  /// tenant — through two windows of a scheduler over the job queue in the
  /// system schema, and answers the reports it wrote, by tenant.
  Future<Map<String, int>> reviewContracts() async {
    var clock = DateTime.utc(2026, 11, 11, 9, 30);
    final scheduler = TomScheduler(
      store: TomSqlJobStore(
        TomDataSourceInfo.getBaseDataSourceInfo('main')!.datasource,
      ),
      dispatcher: const TomInlineJobDispatcher(),
      clock: () => clock,
    );
    try {
      scheduler.register(contractReviewJob());
      await scheduler.tick();
      clock = clock.add(const Duration(hours: 1));
      await scheduler.tick();
      await scheduler.drain();
    } finally {
      await scheduler.close();
    }
    return {
      for (final report in await _reports.findAll())
        report.tenant!: report.contracts!,
    };
  }

  /// The request-side answer for a request naming [tenant] by header: `null`
  /// when it is served, else the refusal's key.
  String? refusalOf(String tenant) => tenancy
      .resolveRequest(
        Request(
          'GET',
          Uri.parse('http://sample/invoices'),
          headers: {'X-Tenant-Id': tenant},
        ),
      )
      .key;

  /// A node starting again — or a second node — over the same registry: the
  /// tenancy reinstalled from the configuration, whose seed does not name the
  /// tenants onboarded at runtime; the registry does. Answers the tenants it
  /// serves.
  Future<List<String>> restart() async {
    await TomTenancy.reset();
    await TomServer(MtServerConfiguration()).configureTenancy(config);
    return tenancy.tenants.keys.toList()..sort();
  }

  /// Writes an invoice of [tenant] and a review report in one transaction —
  /// a tenant table and a system table — and answers the refusal's key, or
  /// `null` when it committed. Refused on one-phase data sources, where the
  /// two would be two commits.
  Future<String?> invoiceWithReport(String tenant) async {
    try {
      await tenancy.runFor(
        tenant,
        () => TomTransactionManager.runInTransaction((_) async {
          await _invoices.insert(
            MtInvoice()
              ..id = '$tenant-tx'
              ..planCode = 'starter'
              ..amountCents = 1,
          );
          await _reports.insert(
            MtReviewReport()
              ..id = '$tenant@tx'
              ..tenant = tenant
              ..contracts = 0,
          );
        }),
      );
      return null;
    } on TomServerException catch (error) {
      return error.key;
    }
  }

  /// Ends the run: the tenancy and the data sources closed.
  Future<void> stop() async {
    await TomTenancy.reset();
    await TomDataSourceInfo.closeAll();
  }
}

/// The job reviewing an enterprise tenant's contracts, planned once per
/// active tenant of the type `enterprise` — the declaration
/// (`TomJobTenants`), not a loop over the tenants in the body.
TomJobDefinition contractReviewJob() => TomJobDefinition(
  name: 'contracts.review',
  schedule: TomIntervalSchedule(const Duration(hours: 1)),
  tenants: const TomJobTenants(types: ['enterprise']),
  body: (run) => MtContractReview(run.scheduledFor),
);

/// One run of the contract review, inside its tenant: counts the tenant's
/// contracts — a tenant table — and records the count in the system table
/// `mt_review_report`, which stays in the system schema.
class MtContractReview extends TomCommand {
  /// The run of [window].
  MtContractReview(this.window);

  /// The window reviewed.
  final DateTime window;

  @override
  Future<Object?> execute() async {
    final tenant = TomTenantContext.currentId!;
    final contracts = (await MtContractRepository().findAll()).length;
    await MtReviewReportRepository().insert(
      MtReviewReport()
        ..id = '$tenant@${window.toIso8601String()}'
        ..tenant = tenant
        ..contracts = contracts,
    );
    return contracts;
  }
}
