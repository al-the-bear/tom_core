/// The drift guard over every reference migration shipped under `example/`.
///
/// A framework table's DDL exists twice: once as the constant the code owns —
/// an entity's `createTableSql`, or a descriptor's generated statement — and
/// once as the `.sql` file a deployment applies. Nothing in the language
/// relates the two, so they drift silently, and the drift surfaces at the first
/// read in production rather than at build time.
///
/// Two guards close that gap, split by what owns the DDL:
///
///  * **descriptor** tables converge structurally in
///    `framework_schema_test.dart`, which replays the shipped chain and
///    compares the resulting schema against the `TomFrameworkTable`
///    declarations. `audit_sql_test.dart` and `scheduling_schema_test.dart`
///    additionally compare those files against the statements their modules
///    issue.
///  * **entity** tables are pinned here, verbatim, against the
///    `createTableSql` the entity declares.
///
/// The test that matters most is neither. It is *every shipped reference
/// migration is covered by a drift guard*, which walks the example tree and
/// requires each `.sql` file to appear in exactly one of the two lists below.
/// A pin that was never written leaves no trace — there is no failing file,
/// because there is no file — so the absence has to be made visible somewhere
/// that is itself checked. It is now an absent entry in a list, and the list is
/// compared against the directory.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A reference migration whose DDL is owned by an entity's `createTableSql`.
///
/// [version] and [description] are the two halves the orchestrator parses out
/// of the filename; [ddl] is the constant the file must reproduce.
typedef _EntityPin = ({
  String path,
  String version,
  String description,
  String ddl,
});

/// The directory every module's reference chain lives in, relative to a
/// module directory under `example/`.
const String _chainDirectory = 'migrations/main/tomcore';

/// Builds the path of a reference migration from its parts, so the strings in
/// the two lists below cannot disagree about the directory convention they are
/// both asserting.
String _migration(String module, String filename) =>
    'example/$module/$_chainDirectory/$filename';

/// Every entity-owned reference migration, paired with the constant that owns
/// it.
final List<_EntityPin> _entityPins = [
  (
    path: _migration(
      'authentication',
      '[1]-create_tom_user_two_factor_enrolment.sql',
    ),
    version: '1',
    description: 'create_tom_user_two_factor_enrolment',
    ddl: TomUserTwoFactorEnrolment.createTableSql,
  ),
  (
    path: _migration(
      'authentication',
      '[3]-create_tom_external_identity_token.sql',
    ),
    version: '3',
    description: 'create_tom_external_identity_token',
    ddl: TomExternalIdentityToken.createTableSql,
  ),
  (
    path: _migration('authentication', '[4]-create_tom_external_identity.sql'),
    version: '4',
    description: 'create_tom_external_identity',
    ddl: TomExternalIdentityLink.createTableSql,
  ),
  (
    path: _migration('authorization', '[1]-create_tom_resource_grants.sql'),
    version: '1',
    description: 'create_tom_resource_grants',
    ddl: TomResourceGrant.createTableSql,
  ),
  (
    path: _migration(
      'authorization',
      '[2]-create_tom_principal_resource_grant.sql',
    ),
    version: '2',
    description: 'create_tom_principal_resource_grant',
    ddl: TomPrincipalResourceGrant.createTableSql,
  ),
  (
    path: _migration(
      'authorization',
      '[3]-create_tom_principal_delegation.sql',
    ),
    version: '3',
    description: 'create_tom_principal_delegation',
    ddl: TomPrincipalDelegation.createTableSql,
  ),
  (
    path: _migration('preferences', '[1]-create_tom_user_preference.sql'),
    version: '1',
    description: 'create_tom_user_preference',
    ddl: TomUserPreference.createTableSql,
  ),
  (
    path: _migration('preferences', '[2]-create_tom_preference_default.sql'),
    version: '2',
    description: 'create_tom_preference_default',
    ddl: TomPreferenceDefault.createTableSql,
  ),
];

/// The shipped migrations that carry no entity constant, and what guards each.
///
/// Spelled out rather than left implicit: the coverage test needs to tell
/// "guarded somewhere else" from "guarded nowhere", and only a list can say
/// which of the two an unpinned file is.
final Map<String, String> _guardedElsewhere = {
  _migration('authentication', '[2]-create_tom_oauth_state.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'oauth_state_store_test.dart compares the file to oauthStateTableDdl',
  _migration('authentication', '[5]-create_tom_scim_resource.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against scimResourceTable',
  _migration('audit', '[1]-create_tom_audit_trail.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'audit_sql_test.dart compares the file to auditTrailTableDdl',
  _migration('audit', '[2]-guard_tom_audit_trail_no_update@hardened.sql'):
      'trigger, not a table — audit_sql_test.dart compares the file to '
      'auditTrailNoUpdateTriggerDdl',
  _migration('audit', '[3]-guard_tom_audit_trail_no_delete@immutable.sql'):
      'trigger, not a table — audit_sql_test.dart compares the file to '
      'auditTrailNoDeleteTriggerDdl',
  _migration('messaging', '[1]-create_tom_delivery_report.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against deliveryReportTable',
  _migration('messaging', '[2]-create_tom_message_inbox.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against inboxTable',
  _migration('endpoints', '[1]-create_tom_idempotency_key.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against idempotencyTable',
  _migration('transactions', '[1]-create_tom_saga.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against sagaTable',
  _migration('transactions', '[2]-create_tom_transaction_decision.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against decisionTable',
  _migration('object_persistence', '[1]-create_tom_encryption_key.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against encryptionKeyTable',
  _migration('privacy', '[1]-create_tom_subject_key.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against subjectKeyTable',
  _migration('cache', '[1]-create_tom_cache_invalidation.sql'):
      'descriptor table — framework_schema_test.dart converges the chain '
      'against invalidationTable',
  _migration('file_storage', '[1]-create_tom_blob.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'file_storage_schema_test.dart compares the file to '
      'blobManifestTableDdl',
  _migration('file_storage', '[2]-create_tom_blob_chunk.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'file_storage_schema_test.dart compares the file to blobChunkTableDdl',
  _migration('file_storage', '[3]-create_tom_blob_ledger.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'file_storage_schema_test.dart compares the file to blobLedgerTableDdl',
  _migration('file_storage', '[4]-create_tom_blob_content.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'file_storage_schema_test.dart compares the file to '
      'blobContentTableDdl',
  _migration('scheduling', '[1]-create_tom_job_run.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'scheduling_schema_test.dart compares the file to jobRunTableDdl',
  _migration('scheduling', '[2]-create_tom_lease.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'scheduling_schema_test.dart compares the file to leaseTableDdl',
  _migration('scheduling', '[3]-create_tom_scheduler_node.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'scheduling_schema_test.dart compares the file to '
      'schedulerNodeTableDdl',
  _migration('scheduling', '[4]-create_tom_job_pause.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'scheduling_schema_test.dart compares the file to jobPauseTableDdl',
  _migration('scheduling', '[5]-create_tom_job_run_archive.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'scheduling_schema_test.dart compares the file to '
      'jobRunArchiveTableDdl',
  _migration('export', '[1]-create_tom_export.sql'):
      'descriptor table — framework_schema_test.dart converges the chain, and '
      'export_register_test.dart compares the file to exportRegisterTableDdl',
};

/// Every `.sql` file actually shipped under `example/`, read from disk.
///
/// Discovered rather than listed, so a migration added without a guard shows up
/// as a file the lists do not mention instead of going unnoticed.
Set<String> _shippedMigrations() => Directory('example')
    .listSync()
    .whereType<Directory>()
    .map((module) => Directory('${module.path}/$_chainDirectory'))
    .where((chain) => chain.existsSync())
    .expand((chain) => chain.listSync().whereType<File>())
    .map((file) => file.path)
    .where((path) => path.endsWith('.sql'))
    .toSet();

/// Asserts that [pin] is discoverable by the orchestrator and still reproduces
/// the entity DDL it claims to.
void _pinsEntityDdl(_EntityPin pin) {
  group(pin.description, () {
    final file = File(pin.path);

    test('ships under the db_migration directory convention', () {
      expect(
        file.existsSync(),
        isTrue,
        reason: 'the reference migration must exist under example/',
      );
    });

    test('filename matches the migration discovery regex', () {
      // Mirrors db_migration.dart: RegExp(r'\[([0-9]+)]-([a-zA-Z_]+)').
      final name = file.uri.pathSegments.last.replaceAll('.sql', '');
      final match = RegExp(r'\[([0-9]+)]-([a-zA-Z_]+)').firstMatch(name);
      expect(
        match,
        isNotNull,
        reason: 'the orchestrator must be able to parse the version + name',
      );
      expect(match!.group(1), pin.version);
      expect(match.group(2), pin.description);
    });

    // A migration that described a different table from the entity would apply
    // cleanly and fail at the first read, in production.
    test('reproduces the entity DDL verbatim', () {
      expect(file.readAsStringSync(), contains(pin.ddl.trim()));
    });
  });
}

void main() {
  group('entity-owned reference migrations reproduce their DDL', () {
    for (final pin in _entityPins) {
      _pinsEntityDdl(pin);
    }
  });

  group('the guard covers the whole example tree', () {
    test('every shipped reference migration is covered by a drift guard', () {
      final guarded = {
        ..._entityPins.map((pin) => pin.path),
        ..._guardedElsewhere.keys,
      };
      expect(
        _shippedMigrations().difference(guarded),
        isEmpty,
        reason:
            'these migrations ship with nothing comparing them to the DDL the '
            'code owns. Add an entry to _entityPins if the table is an entity, '
            'or to _guardedElsewhere naming the test that covers it.',
      );
    });

    test('no guard names a migration that is no longer shipped', () {
      final guarded = {
        ..._entityPins.map((pin) => pin.path),
        ..._guardedElsewhere.keys,
      };
      expect(
        guarded.difference(_shippedMigrations()),
        isEmpty,
        reason:
            'a guard pointing at a file that does not exist passes for the '
            'wrong reason once its "must exist" test is the only thing left',
      );
    });

    // The guard's own proof. Without it, every verbatim test above would pass
    // just as happily against a comparison that never looked at anything.
    test('a migration that drifted from its entity is reported', () {
      final drifted = TomPrincipalDelegation.createTableSql.replaceFirst(
        'delegator_id VARCHAR(255)',
        'delegator_id VARCHAR(64)',
      );
      expect(
        drifted,
        isNot(TomPrincipalDelegation.createTableSql),
        reason: 'the mutation must actually change the DDL to prove anything',
      );
      expect(
        File(
          _migration(
            'authorization',
            '[3]-create_tom_principal_delegation.sql',
          ),
        ).readAsStringSync(),
        isNot(contains(drifted.trim())),
      );
    });
  });
}
