// ignore_for_file: avoid_print
/// The package's example runner: every module example, in reading order.
///
/// `tom_core_server` has no single introductory program, because it is twenty
/// modules and no one program is the way in. What it has instead is a runnable
/// sample per module, and this is the index of them — as a list a reader can
/// read and a runner that executes it:
///
/// ```bash
/// dart run example/tom_core_server_example.dart
/// ```
///
/// from the package root, which is where the paths in [tour] resolve. Each
/// entry is one program with one line saying what it shows; to see only one,
/// run its path directly. The order is the one the README's sample map uses:
/// the server and its endpoints first, then persistence, then the services
/// built on it, then the small modules.
///
/// **A green run is a verification, not a transcript.** Every example states
/// its expectations through `example/_support/check.dart`, which throws when
/// one does not hold, so a program that exits 0 is one whose claims held. This
/// runner reports the exit code of each and fails if any of them did not —
/// which makes the whole set one command.
///
/// Four programs are deliberately left out; [notOnTheTour] names them with the
/// reason. `test/examples_test.dart` requires those two lists together to be
/// exactly the example programs in the package, so a module example added
/// later has to appear here rather than quietly not being on the tour.
library;

import 'dart:io';

import '_support/check.dart';

/// One example program, and what running it shows.
class TourStop {
  /// Creates a stop.
  const TourStop(this.path, this.shows);

  /// The program, relative to the package root.
  final String path;

  /// What a reader learns from its transcript.
  final String shows;
}

/// Every example program this runner runs, in reading order.
const List<TourStop> tour = [
  TourStop(
    'example/server/server_example.dart',
    'The request pipeline: per-request log state, the credential reader and '
        'the outcomes that tell its anonymous answers apart, two middlewares',
  ),
  TourStop(
    'example/endpoints/endpoints_example.dart',
    'Declaring routed endpoints, and what the router makes of them',
  ),
  TourStop(
    'example/object_persistence/object_persistence_example.dart',
    'Repositories, the persistence annotations, and the query builder',
  ),
  TourStop(
    'example/datasources/datasources_example.dart',
    'SQL-typed values and how each dialect renders them',
  ),
  TourStop(
    'example/db_migration/db_migration_example.dart',
    'Versioned schema migrations and the plan a chain produces',
  ),
  TourStop(
    'example/transactions/transactions_example.dart',
    'Local and XA transaction coordination',
  ),
  TourStop(
    'example/configuration/configuration_example.dart',
    'Typed configuration from arguments, environment and YAML resources',
  ),
  TourStop(
    'example/cache/cache_example.dart',
    'The isolate-backed cache, its lifetimes, and what "cache forever" means',
  ),
  TourStop(
    'example/authentication/authentication_example.dart',
    'The authentication service contract end to end, without a database',
  ),
  TourStop(
    'example/authentication/oauth_login_example.dart',
    'The OAuth 2.0 / OIDC handshake: signing in through an external provider',
  ),
  TourStop(
    'example/authentication/scim_provisioning_example.dart',
    'SCIM 2.0 provisioning, and deprovisioning that ends the sessions held',
  ),
  TourStop(
    'example/authentication/two_factor_enrolment_example.dart',
    'The first time a policy demands a factor the user has not set up yet',
  ),
  TourStop(
    'example/authentication/two_factor_login_example.dart',
    'The two-pass login a principal that still owes a second factor takes',
  ),
  TourStop(
    'example/authorization/authorization_example.dart',
    'The per-token principal cache, graded grants, resource roles, delegation',
  ),
  TourStop(
    'example/authorization/resource_data_scope_example.dart',
    'The grant-driven row scope those grants filter the database with',
  ),
  TourStop(
    'example/audit/audit_example.dart',
    'Audit records, the declared/automatic split, the hash chain, the trail '
        "schema and its write-once check, and anchors published outside the "
        'server',
  ),
  TourStop(
    'example/messaging/messaging_example.dart',
    'The outbound substrate without a mail server: composition, the MIME '
        'document, stand-in transports, the durable outbox',
  ),
  TourStop(
    'example/messaging/messaging_templated_example.dart',
    'The application-level half: the templated services, and the SMS channel',
  ),
  TourStop(
    'example/messaging/sms_gateway_presets.dart',
    'Worked field mappings for three named SMS gateways — as an example, not '
        'as library API',
  ),
  TourStop(
    'example/export/export_example.dart',
    'The streaming tabular shape, columns derived from a reflected entity, '
        'the CSV/XLSX/PDF renderers, the format registry and the storage '
        'backends',
  ),
  TourStop(
    'example/export/export_email.dart',
    'A third delivery channel, composed from the module rather than built in',
  ),
  TourStop(
    'example/export/export_retention.dart',
    'Reclaiming what stored exports accumulate, and who owns the enumeration',
  ),
  TourStop(
    'example/resources/resources_example.dart',
    'Localized text as an argument rather than ambient state: bundle sets, '
        'the three-rung fallback chain, and the completeness check',
  ),
  TourStop(
    'example/preferences/preferences_example.dart',
    'The five-piece bootstrap a user preference needs, with a scalar and a '
        'reflected object written and read back',
  ),
  TourStop(
    'example/file_storage/file_storage_example.dart',
    'The one streaming blob contract, the key grammar, the '
        'infrastructure-free backends and the blob-backed export store',
  ),
  TourStop(
    'example/scheduling/scheduling_example.dart',
    'The relational job queue and lease lock: the schema, why each constraint '
        'is load-bearing, and the UTC instant encoding',
  ),
  TourStop(
    'example/healthcheck/healthcheck_example.dart',
    'The health and readiness verdicts, and what a probe can act on',
  ),
  TourStop(
    'example/cmdline/cmdline_example.dart',
    'Reading a command line and an env file into a typed configuration',
  ),
  TourStop(
    'example/little_things/little_things_example.dart',
    'The exception family, the request id, and the error envelope',
  ),
];

/// The example programs the tour does not run, and why.
///
/// Stating the reason is the point: a program left off a list with no reason
/// is indistinguishable from one forgotten.
const Map<String, String> notOnTheTour = {
  'example/scheduling/cluster/cluster_node.dart':
      'a cluster member: waits for peers and a shared MariaDB — run the three '
      'together with example/scheduling/cluster/run_cluster_demo.sh',
  'example/scheduling/cluster/cluster_provision.dart':
      'provisions the cluster schema in a live MariaDB',
  'example/scheduling/cluster/cluster_verify.dart':
      'reads the run table a live cluster produced',
  'example/example_reflection.dart':
      'the reflection generator root: its `main` is empty by contract',
};

Future<void> run() async {
  // Before spawning anything: a path that no longer resolves is a stop the
  // tour cannot take, and reporting it as "the example failed" would send a
  // reader looking for a defect in a file that has moved.
  for (final stop in tour) {
    check(
      File(stop.path).existsSync(),
      'the tour names ${stop.path}, which is not in this package',
    );
  }

  print('Tom Core Server — ${tour.length} example programs\n');

  final failed = <String>[];
  for (var i = 0; i < tour.length; i++) {
    final stop = tour[i];
    print('═' * 72);
    print('[${i + 1}/${tour.length}] ${stop.path}');
    print('         ${stop.shows}');
    print('═' * 72);

    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      stop.path,
    ]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) failed.add(stop.path);
    print('');
  }

  print('═' * 72);
  // Every program is run before anything is reported: a reader who wants the
  // whole set wants to know which of them failed, not only the first.
  print(
    failed.isEmpty
        ? '${tour.length} examples, all green.'
        : '${failed.length} of ${tour.length} examples failed:\n'
              '  ${failed.join('\n  ')}',
  );
  check(failed.isEmpty, 'every example on the tour has to exit 0');
}

Future<void> main() => run();
