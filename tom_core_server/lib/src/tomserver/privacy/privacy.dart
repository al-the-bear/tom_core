/// The data-protection operations: erasing a person, exporting what is held
/// about them, and keeping rows no longer than declared.
///
/// Every operation works through the repositories the application registers
/// ([TomPrivacy.register]), so it is the repository's write path that runs:
/// each deleted or anonymized row is audited, its file columns are cascaded,
/// encrypted columns stay encrypted and a tenant table stays within its
/// tenant. The operations themselves are audited too — one record per erasure,
/// export and retention run — so the trail shows what was done for whom.
///
/// | Operation | What it does |
/// | --------- | ------------ |
/// | [TomPrivacy.erase] | Applies each `@TomDataSubject` field's [TomErasure] to every row naming the subject, then shreds the subject's audit key. |
/// | [TomPrivacy.subjectAccess] / [TomPrivacy.exportSubject] | Collects every row naming the subject, one section per entity, rendered by the export module (CSV, XLSX, PDF). |
/// | [TomPrivacy.applyRetention] / [TomPrivacy.retentionJob] | Deletes or anonymizes the rows older than their `@TomRetention`. |
///
/// The operations read and write regardless of the caller's row scope
/// (`TomDataScope.runUnscoped`): erasing a person must reach every row about
/// them, not the rows the caller happens to see. Deciding who may ask for an
/// erasure or an export is therefore the caller's — an endpoint that offers
/// them gates them.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/audit_record.dart';
import '../audit/audit_trail.dart';
import '../export/tabular_renderer.dart';
import '../export/tabular_result.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/data_scope.dart';
import '../object_persistence/field_encryption.dart';
import '../object_persistence/paging.dart';
import '../tenancy/tenancy.dart';
import 'personal_data.dart';
import 'subject_keys.dart';

/// One registered entity: its repository, with the entity type captured.
class _TomPrivacyEntity<T extends Object> {
  _TomPrivacyEntity(this.repository);

  final TomRepository<T, dynamic> repository;

  Type get type => T;

  TomPersonalDataModel get model => TomPersonalDataModel.of(T);

  Future<List<T>> find(
    String sentence,
    Map<String, Object?> params, [
    TomPageRequest? page,
  ]) async => (await repository.findByQuerySentence(
    sentence,
    params,
    null,
    page,
  )).toList();

  Future<void> delete(Object row) => repository.delete(row as T);

  Future<void> save(Object row) => repository.save(row as T);

  TomTabularSection section(List<Object> rows) =>
      TomTabularSection.ofEntities<T>(
        Stream<T>.fromIterable(rows.cast<T>()),
        title: '$T',
      );
}

/// What an erasure did to one entity.
class TomErasureCount {
  /// The counts; see the fields.
  const TomErasureCount({
    required this.entity,
    this.deleted = 0,
    this.anonymized = 0,
    this.unlinked = 0,
  });

  /// The entity type.
  final Type entity;

  /// Rows deleted.
  final int deleted;

  /// Rows kept with the subject and their personal fields cleared.
  final int anonymized;

  /// Rows kept with only the subject field cleared.
  final int unlinked;

  /// Whether the entity held nothing about the subject.
  bool get isEmpty => deleted + anonymized + unlinked == 0;

  @override
  String toString() =>
      '$entity: $deleted deleted, $anonymized anonymized, $unlinked unlinked';
}

/// What [TomPrivacy.erase] did.
class TomErasureReport {
  /// A report; see the fields.
  const TomErasureReport({
    required this.subject,
    required this.counts,
    required this.auditKeyShredded,
  });

  /// The erased subject.
  final String subject;

  /// Per registered entity with a `@TomDataSubject` field, in registration
  /// order.
  final List<TomErasureCount> counts;

  /// Whether the subject's audit key was deleted — `false` when it was kept on
  /// request, or there was none.
  final bool auditKeyShredded;

  /// The count of [entity].
  TomErasureCount countOf(Type entity) =>
      counts.firstWhere((c) => c.entity == entity);

  @override
  String toString() =>
      'TomErasureReport($subject: ${counts.join('; ')}; audit key '
      '${auditKeyShredded ? 'shredded' : 'kept'})';
}

/// A subject-access export: what is held about a subject, one section per
/// registered entity.
class TomSubjectAccess {
  /// The export; see the fields.
  const TomSubjectAccess({
    required this.subject,
    required this.result,
    required this.rowCounts,
  });

  /// The subject.
  final String subject;

  /// The tabular result, ready for any export format.
  final TomTabularResult result;

  /// The rows exported, per entity.
  final Map<Type, int> rowCounts;
}

/// One retention rule: rows of [entity] whose [field] lies more than [keep]
/// in the past are deleted, or anonymized.
class TomRetentionPolicy {
  /// A policy; [action] is [TomErasure.delete] or [TomErasure.anonymize].
  const TomRetentionPolicy({
    required this.entity,
    required this.field,
    required this.keep,
    this.action = TomErasure.delete,
  });

  /// The entity type, which must be registered.
  final Type entity;

  /// The declared name of the `DateTime` field the age is measured from.
  final String field;

  /// How long a row is kept.
  final Duration keep;

  /// What happens to an expired row.
  final TomErasure action;

  /// The policies the registered entities declare with `@TomRetention`.
  static List<TomRetentionPolicy> declared() => [
    for (final e in TomPrivacy._entities.values)
      if (e.model.retention case final r?)
        TomRetentionPolicy(
          entity: e.type,
          field: r.field,
          keep: Duration(days: r.days),
          action: r.action,
        ),
  ];

  @override
  String toString() =>
      'TomRetentionPolicy($entity.$field, ${keep.inDays} days, ${action.name})';
}

/// The outcome of one retention policy.
class TomRetentionCount {
  /// The count; see the fields.
  const TomRetentionCount(this.policy, this.cutoff, this.affected);

  /// The policy applied.
  final TomRetentionPolicy policy;

  /// The instant rows had to be newer than.
  final DateTime cutoff;

  /// Rows deleted or anonymized.
  final int affected;

  @override
  String toString() => '$policy: $affected';
}

/// The default name of the retention job.
const String tomRetentionJobName = 'privacy.retention';

/// The isolate's privacy operations — see the library documentation.
abstract final class TomPrivacy {
  static final Map<Type, _TomPrivacyEntity<Object>> _entities = {};
  static TomSubjectKeys? _subjectKeys;

  /// The configuration key of the settings — see [configure].
  static const String configurationKey = 'privacy';

  /// The audit target of an erasure.
  static const String erasureTarget = 'privacy.erasure';

  /// The audit target of a subject-access export.
  static const String subjectAccessTarget = 'privacy.subject_access';

  /// The audit target of a retention run.
  static const String retentionTarget = 'privacy.retention';

  /// Rows read per statement by a retention run.
  static int retentionBatchSize = 200;

  /// Registers [repository]: its entity takes part in erasure, export and
  /// retention. The order of registration is the order the operations visit
  /// the entities in. Registering an entity again replaces its repository.
  ///
  /// Resolves the entity's declarations at once, so a declaration the
  /// operations could not carry out is refused here (`privacy.model.*`).
  static void register<T extends Object>(TomRepository<T, dynamic> repository) {
    TomPersonalDataModel.of(T);
    _entities[T] = _TomPrivacyEntity<T>(repository);
  }

  /// The registered entity types, in registration order.
  static List<Type> get entities => List.unmodifiable(_entities.keys);

  /// The installed subject keys, or `null`.
  static TomSubjectKeys? get subjectKeys => _subjectKeys;

  /// Installs [keys] and makes the audit trail seal `@TomPersonal` values with
  /// them — see `subject_keys.dart`. Without subject keys the trail records
  /// personal values as they are, and an erasure cannot reach them there.
  static void installSubjectKeys(TomSubjectKeys keys) {
    _subjectKeys = keys;
    TomAuditTrail.personalValueSealer = keys.seal;
  }

  /// Forgets the registrations and the subject keys. For tests.
  static void reset() {
    _entities.clear();
    _subjectKeys = null;
    TomAuditTrail.personalValueSealer = null;
    retentionBatchSize = 200;
  }

  /// Installs subject keys from [settings], the `privacy` configuration map:
  ///
  /// | Key | Meaning |
  /// | --- | ------- |
  /// | `datasource` | the data source of the subject-key table (required) |
  /// | `table` | the table's name; default `tom_subject_key` |
  /// | `createSchema` | create the table on first use; default `true` |
  ///
  /// The keys are wrapped under the key-encryption keys of the installed
  /// field-encryption keyring, so `fieldEncryption` is configured as well.
  /// Throws `privacy.config.invalid` for a value of the wrong shape, or when
  /// no keyring is installed.
  static void configure(Object? settings) {
    Never invalid(String why) => throw TomPrivacyException(
      'privacy.config.invalid',
      'The $configurationKey configuration is invalid: $why.',
    );
    if (settings is! Map) invalid('it is not a map');
    final datasource = settings['datasource'];
    if (datasource is! String || datasource.isEmpty) {
      invalid('`datasource` names no data source');
    }
    final table = settings['table'] ?? 'tom_subject_key';
    if (table is! String) invalid('`table` is not a string');
    final createSchema = settings['createSchema'] ?? true;
    if (createSchema is! bool) invalid('`createSchema` is not a boolean');
    if (TomFieldEncryption.keyring == null) {
      invalid(
        'no field-encryption keyring is installed to wrap the subject keys; '
        'configure `fieldEncryption` as well',
      );
    }
    installSubjectKeys(
      TomSubjectKeys(
        store: TomSqlSubjectKeyStore(
          datasource,
          table: table,
          createSchema: createSchema,
        ),
      ),
    );
  }

  static _TomPrivacyEntity<Object> _registered(Type entity) =>
      _entities[entity] ??
      (throw TomPrivacyException(
        'privacy.not_registered',
        '$entity has no repository registered with TomPrivacy.',
        parameters: {'entity': '$entity'},
      ));

  static List<_TomPrivacyEntity<Object>> _selected(Iterable<Type>? entities) =>
      entities == null
      ? _entities.values.toList()
      : [for (final e in entities) _registered(e)];

  /// The rows of [entity] whose subject field [field] names [subject].
  static Future<List<Object>> _rowsNaming(
    _TomPrivacyEntity<Object> entity,
    TomSubjectField field,
    Object subject,
  ) => entity.find('find by ${field.name} = :subject', {
    'subject': field.toColumnValue(subject),
  });

  /// Erases [subject] from every registered entity — or from [entities], in
  /// that order — and answers what was done.
  ///
  /// For every `@TomDataSubject` field naming the subject, the row is deleted,
  /// anonymized or unlinked as the field declares. Then the subject's audit
  /// key is shredded, which makes their sealed values in the trail unreadable
  /// — unless [keepAuditKeys], for a trail under a legal hold, which an
  /// erasure would otherwise defeat. The erasure itself is audited
  /// ([erasureTarget]), the subject as its target key.
  static Future<TomErasureReport> erase(
    Object subject, {
    bool keepAuditKeys = false,
    Iterable<Type>? entities,
  }) => TomDataScope.runUnscoped(() async {
    final counts = <TomErasureCount>[];
    for (final entity in _selected(entities)) {
      final model = entity.model;
      if (model.subjects.isEmpty) continue;
      var deleted = 0, anonymized = 0, unlinked = 0;
      for (final field in model.subjects) {
        for (final row in await _rowsNaming(entity, field, subject)) {
          switch (field.onErasure) {
            case TomErasure.delete:
              await entity.delete(row);
              deleted++;
            case TomErasure.anonymize:
              model.clear(row, field, anonymize: true);
              await entity.save(row);
              anonymized++;
            case TomErasure.unlink:
              model.clear(row, field, anonymize: false);
              await entity.save(row);
              unlinked++;
          }
        }
      }
      counts.add(
        TomErasureCount(
          entity: entity.type,
          deleted: deleted,
          anonymized: anonymized,
          unlinked: unlinked,
        ),
      );
    }
    final keys = _subjectKeys;
    final shredded =
        !keepAuditKeys && keys != null && await keys.shred('$subject');
    final report = TomErasureReport(
      subject: '$subject',
      counts: List.unmodifiable(counts),
      auditKeyShredded: shredded,
    );
    await TomAuditTrail.recordAction(
      action: TomAuditAction.delete,
      target: erasureTarget,
      targetKey: '$subject',
      outcome: TomAuditOutcome.succeeded,
      detail:
          '${counts.where((c) => !c.isEmpty).join('; ')}; audit key '
          '${shredded ? 'shredded' : 'kept'}',
    );
    return report;
  });

  /// What every registered entity — or [entities] — holds about [subject]:
  /// the rows any `@TomDataSubject` field ties to them, one section per
  /// entity, every mapped column (file references excluded). Encrypted
  /// columns are exported decrypted: the export is the subject's own data.
  ///
  /// The export is audited ([subjectAccessTarget], action `read`).
  static Future<TomSubjectAccess> subjectAccess(
    Object subject, {
    Iterable<Type>? entities,
  }) => TomDataScope.runUnscoped(() async {
    final sections = <TomTabularSection>[];
    final counts = <Type, int>{};
    for (final entity in _selected(entities)) {
      final model = entity.model;
      if (model.subjects.isEmpty) continue;
      final rows = <String, Object>{};
      for (final field in model.subjects) {
        for (final row in await _rowsNaming(entity, field, subject)) {
          rows['${model.keyOf(row)}'] ??= row;
        }
      }
      counts[entity.type] = rows.length;
      sections.add(entity.section(rows.values.toList()));
    }
    if (sections.isEmpty) {
      throw TomPrivacyException(
        'privacy.not_registered',
        'No registered entity has a @TomDataSubject field to export.',
      );
    }
    await TomAuditTrail.recordAction(
      action: TomAuditAction.read,
      target: subjectAccessTarget,
      targetKey: '$subject',
      outcome: TomAuditOutcome.succeeded,
      detail: [
        for (final e in counts.entries) '${e.key}: ${e.value}',
      ].join('; '),
    );
    return TomSubjectAccess(
      subject: '$subject',
      result: TomTabularResult(
        title: 'Personal data of $subject',
        sections: sections,
        metadata: {'subject': '$subject'},
      ),
      rowCounts: Map.unmodifiable(counts),
    );
  });

  /// [subjectAccess], rendered in [format] — `csv`, `xlsx`, `pdf`, or a
  /// format of [formats] — as bytes.
  static Future<List<int>> exportSubject(
    Object subject, {
    String format = 'xlsx',
    TomExportFormats? formats,
    Iterable<Type>? entities,
  }) async {
    final access = await subjectAccess(subject, entities: entities);
    final renderer = (formats ?? TomExportFormats.standard()).rendererFor(
      format,
    );
    final bytes = <int>[];
    await for (final chunk in renderer.render(access.result)) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  /// Applies [policies] — by default the `@TomRetention` declarations of the
  /// registered entities — at [now], and answers what each did.
  ///
  /// Expired rows are deleted, or anonymized — every subject field and its
  /// personal fields cleared — through the entity's repository, a batch at a
  /// time. Each policy's run is audited ([retentionTarget]).
  ///
  /// A tenant table's policy run with no tenant in context under an installed
  /// tenancy is applied in every tenant in turn, and its count is their sum; in
  /// a tenant it is applied in that tenant only. A system table's runs once.
  static Future<List<TomRetentionCount>> applyRetention({
    Iterable<TomRetentionPolicy>? policies,
    DateTime? now,
  }) => TomDataScope.runUnscoped(() async {
    final at = (now ?? DateTime.now()).toUtc();
    final results = <TomRetentionCount>[];
    for (final policy in policies ?? TomRetentionPolicy.declared()) {
      final entity = _registered(policy.entity);
      final cutoff = at.subtract(policy.keep);
      final tenancy = TomTenancy.current;
      var affected = 0;
      if (TomAnnotationAnalyzer.isTenantTable(policy.entity) &&
          tenancy != null &&
          TomTenantContext.currentId == null) {
        await tenancy.forEachTenant(
          (_) async => affected += await _retain(entity, policy, cutoff),
        );
      } else {
        affected = await _retain(entity, policy, cutoff);
      }
      results.add(TomRetentionCount(policy, cutoff, affected));
      await TomAuditTrail.recordAction(
        action: policy.action != TomErasure.delete
            ? TomAuditAction.update
            : TomAuditAction.delete,
        target: retentionTarget,
        targetKey: '${policy.entity}',
        outcome: TomAuditOutcome.succeeded,
        detail: '$affected rows older than ${cutoff.toIso8601String()}',
      );
    }
    return results;
  });

  /// Applies [policy] to [entity] in the zone's tenant: the rows older than
  /// [cutoff] deleted or anonymized; answers how many.
  static Future<int> _retain(
    _TomPrivacyEntity<Object> entity,
    TomRetentionPolicy policy,
    DateTime cutoff,
  ) async {
    final model = entity.model;
    final anonymize = policy.action != TomErasure.delete;
    final key = model.keys.isEmpty
        ? policy.field
        : model.keys.first.declaredName;
    var affected = 0;
    for (var page = 0; ; page++) {
      // Deleted rows leave the result, so a delete always reads the first
      // page; anonymized rows stay, so the anonymizing run pages on.
      final rows = await entity.find(
        'find by ${policy.field} < :cutoff',
        {'cutoff': cutoff},
        TomPageRequest.page(
          anonymize ? page : 0,
          retentionBatchSize,
          sort: [TomSortField.asc(key)],
        ),
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        if (anonymize) {
          var changed = false;
          for (final field in model.subjects) {
            changed |= model.clear(row, field, anonymize: true);
          }
          if (!changed) continue;
          await entity.save(row);
        } else {
          await entity.delete(row);
        }
        affected++;
      }
      if (rows.length < retentionBatchSize) break;
    }
    return affected;
  }

  /// A scheduler job applying [policies] (default: the declared ones) on
  /// [schedule].
  ///
  /// The body uses the isolate's registrations, so register the job on a
  /// scheduler with a `TomInlineJobDispatcher`; a worker isolate has none.
  static TomJobDefinition retentionJob({
    required TomSchedule schedule,
    Iterable<TomRetentionPolicy>? policies,
    String name = tomRetentionJobName,
    Duration timeout = const Duration(hours: 1),
  }) => TomJobDefinition(
    name: name,
    schedule: schedule,
    body: (run) => _TomRetentionCommand(policies?.toList(), run.scheduledFor),
    timeout: timeout,
    // A run deletes what is expired at its window; running it again finds
    // nothing more to do.
    requestsRecovery: true,
  );

  /// [record] with its sealed personal values opened — or shown as
  /// `[erased]` where the subject's key was shredded.
  static Future<TomAuditRecord> reveal(TomAuditRecord record) async {
    final keys = _subjectKeys;
    if (keys == null) {
      throw TomPrivacyException(
        'privacy.no_subject_keys',
        'No subject keys are installed to reveal an audit record with.',
      );
    }
    return keys.reveal(record);
  }
}

class _TomRetentionCommand extends TomCommand {
  _TomRetentionCommand(this._policies, this._at);

  final List<TomRetentionPolicy>? _policies;
  final DateTime _at;

  @override
  Future<Object?> execute() async => [
    for (final c in await TomPrivacy.applyRetention(
      policies: _policies,
      now: _at,
    ))
      '$c',
  ];
}
