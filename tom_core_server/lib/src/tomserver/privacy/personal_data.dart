/// What an entity declares about the personal data it holds: which column ties
/// a row to a person (the *data subject*), which columns hold that person's
/// data, and how long rows are kept.
///
/// The declarations drive the privacy operations of `privacy.dart` — erasure,
/// subject-access export and retention — and the crypto-shredding of personal
/// values in the audit trail (`subject_keys.dart`). They are read from the
/// entity by [TomPersonalDataModel.of], which refuses a declaration the
/// operations could not carry out.
library;

import '../little_things/server_exception.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/persistence_annotations.dart';

/// A privacy declaration or operation that cannot proceed.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `privacy.model.subject_type` | A `@TomDataSubject` field is not an `int` or a `String`, or is encrypted. |
/// | `privacy.model.subject_unknown` | A `@TomPersonal(subject:)` names a field that is not a `@TomDataSubject` field of the entity. |
/// | `privacy.model.subject_ambiguous` | A `@TomPersonal` field names no subject while the entity has more than one `@TomDataSubject` field, or none. |
/// | `privacy.model.structural_personal` | A `@TomPersonal` field is a key, version, reference or file column, which cannot be cleared. |
/// | `privacy.model.retention_field` | A `@TomRetention` names a field that is not a `DateTime` column of the entity, or keeps a row for less than a day. |
/// | `privacy.model.retention_anonymize` | A `@TomRetention` anonymizes an entity that has no `@TomDataSubject` field. |
/// | `privacy.not_registered` | An operation names an entity type with no repository registered. |
/// | `privacy.no_subject_keys` | Audit values are to be sealed, or a record revealed, with no subject keys installed. |
/// | `privacy.seal.invalid` | A sealed audit value does not open under its subject's key: it was altered, or belongs to another field. |
/// | `privacy.no_datasource` | The data source a `TomSqlSubjectKeyStore` names is not registered. |
/// | `privacy.config.invalid` | The `privacy` configuration has the wrong shape, or no field-encryption keyring is installed to wrap the subject keys. |
class TomPrivacyException extends TomServerException {
  /// Creates the exception; see [TomServerException] for the fields.
  TomPrivacyException(super.key, super.defaultUserMessage, {super.parameters})
    : super(clientThrow: false);
}

/// What erasing a data subject does to a row a [TomDataSubject] field ties to
/// them.
enum TomErasure {
  /// The row is deleted — it is the subject's own (their account, their
  /// workspace).
  delete,

  /// The row is kept, but no longer names the subject: this field is cleared,
  /// and so is every [TomPersonal] field belonging to it (a comment kept for
  /// the thread, its author and its text removed).
  anonymize,

  /// The row is kept and only this field is cleared (the assignee of a task
  /// someone else owns).
  unlink,
}

/// Marks the field holding the id of the person a row belongs to or names — a
/// data subject — and what erasing them does to the row.
///
/// The field is an `int` or `String` column holding the subject's id; every
/// field of every entity names subjects in the same id space (a user id, as a
/// rule), which is what lets one erasure reach all of them.
///
/// ```dart
/// @TomDataSubject(onErasure: TomErasure.anonymize)
/// @TomDbColumn(columnName: 'author_id')
/// int? authorId;
/// ```
class TomDataSubject {
  /// The field names the row's subject; [onErasure] says what erasing them
  /// does.
  const TomDataSubject({this.onErasure = TomErasure.delete});

  /// What erasing the subject does to the row.
  final TomErasure onErasure;
}

/// Marks a field holding personal data about the subject of a
/// [TomDataSubject] field of the same entity.
///
/// The field is exported with the rest of the row, cleared — set to
/// [replacement], or `null` — when its subject is erased or anonymized by
/// retention, and its values in the audit trail are sealed under the subject's
/// key, so erasing the subject makes them unreadable there too.
///
/// [subject] names the `@TomDataSubject` field whose subject the data is
/// about; it can be left out when the entity has exactly one.
class TomPersonal {
  /// Marks the field personal data about [subject]'s subject.
  const TomPersonal({this.subject, this.replacement});

  /// The declared name of the [TomDataSubject] field, or `null` for the
  /// entity's only one.
  final String? subject;

  /// What the field is set to when it is cleared — for a column that may not
  /// be `NULL`. `null` clears it to `NULL`.
  final Object? replacement;
}

/// Declares how long the rows of an entity are kept: a row whose [field] lies
/// more than [days] in the past is deleted, or anonymized, by a retention run.
///
/// ```dart
/// @TomRetention(field: 'createdAt', days: 365, action: TomErasure.anonymize)
/// ```
class TomRetention {
  /// Keeps rows for [days] after [field]; then applies [action].
  const TomRetention({
    required this.field,
    required this.days,
    this.action = TomErasure.delete,
  });

  /// The declared name of the `DateTime` field the age is measured from.
  final String field;

  /// How many days a row is kept.
  final int days;

  /// [TomErasure.delete], or [TomErasure.anonymize] to clear every subject
  /// and personal field instead. [TomErasure.unlink] reads as anonymize.
  final TomErasure action;
}

/// One `@TomDataSubject` field, resolved.
class TomSubjectField {
  /// The field and its declaration.
  const TomSubjectField(this.column, this.declaration);

  /// The column.
  final TomColumnInformation column;

  /// The annotation.
  final TomDataSubject declaration;

  /// What erasing the subject does to a row this field names them in.
  TomErasure get onErasure => declaration.onErasure;

  /// The declared name of the field.
  String get name => column.declaredName;

  /// [subject] as this column stores it: an `int` column binds an `int`.
  Object toColumnValue(Object subject) {
    if ('${column.declaredType}'.replaceAll('?', '') == 'int' &&
        subject is String) {
      return int.tryParse(subject) ?? subject;
    }
    return subject;
  }
}

/// One `@TomPersonal` field, resolved to the subject field it belongs to.
class TomPersonalField {
  /// The field, its subject field and its declaration.
  const TomPersonalField(this.column, this.subject, this.declaration);

  /// The column.
  final TomColumnInformation column;

  /// The subject field whose subject the data is about.
  final TomSubjectField subject;

  /// The annotation.
  final TomPersonal declaration;

  /// The declared name of the field.
  String get name => column.declaredName;
}

/// The personal-data declarations of one entity, resolved and checked.
class TomPersonalDataModel {
  TomPersonalDataModel._(
    this.entity,
    this.subjects,
    this.personal,
    this.retention,
    this.keys,
  );

  static final Map<Type, TomPersonalDataModel> _cache = {};

  /// The entity type.
  final Type entity;

  /// The `@TomDataSubject` fields, in declaration order.
  final List<TomSubjectField> subjects;

  /// The `@TomPersonal` fields, in declaration order.
  final List<TomPersonalField> personal;

  /// The `@TomRetention` declaration, or `null`.
  final TomRetention? retention;

  /// The primary-key columns.
  final List<TomColumnInformation> keys;

  /// Whether the entity declares anything about personal data.
  bool get isEmpty => subjects.isEmpty && personal.isEmpty && retention == null;

  /// The model of [entity], resolved once.
  ///
  /// Throws a `privacy.model.*` [TomPrivacyException] for a declaration the
  /// privacy operations could not carry out.
  static TomPersonalDataModel of(Type entity) =>
      _cache[entity] ??= _resolve(entity);

  /// Forgets every resolved model. For tests.
  static void clearCache() => _cache.clear();

  static TomPersonalDataModel _resolve(Type entity) {
    Never refuse(String key, String message) => throw TomPrivacyException(
      key,
      message,
      parameters: {'entity': '$entity'},
    );
    final mirror = TomAnnotationAnalyzer.findMirror(entity);
    final columns =
        TomAnnotationAnalyzer.getPersistentColumns(entity) ??
        const <TomColumnInformation>[];
    Iterable<Object> metadataOf(String field) =>
        mirror?.declarations[field]?.metadata ?? const [];
    String typeOf(TomColumnInformation c) =>
        '${c.declaredType}'.replaceAll('?', '');

    final subjects = <TomSubjectField>[];
    for (final c in columns) {
      final declared = metadataOf(c.declaredName).whereType<TomDataSubject>();
      if (declared.isEmpty) continue;
      if (!const {'int', 'String'}.contains(typeOf(c)) || c.encrypted != null) {
        refuse(
          'privacy.model.subject_type',
          '$entity.${c.declaredName} is a @TomDataSubject field of type '
              '${c.declaredType}${c.encrypted != null ? ', encrypted' : ''}; '
              'a subject id is a plain int or String column.',
        );
      }
      subjects.add(TomSubjectField(c, declared.first));
    }

    final personal = <TomPersonalField>[];
    for (final c in columns) {
      final declared = metadataOf(c.declaredName).whereType<TomPersonal>();
      if (declared.isEmpty) continue;
      final declaration = declared.first;
      if (c.entityId != null ||
          c.version != null ||
          c.reference != null ||
          c.fileReference != null) {
        refuse(
          'privacy.model.structural_personal',
          '$entity.${c.declaredName} is a key, version, reference or file '
              'column; @TomPersonal fields are cleared on erasure.',
        );
      }
      final TomSubjectField subject;
      if (declaration.subject != null) {
        subject =
            subjects.where((s) => s.name == declaration.subject).firstOrNull ??
            refuse(
              'privacy.model.subject_unknown',
              '$entity.${c.declaredName} names the subject field '
                  '${declaration.subject}, which is not a @TomDataSubject '
                  'field of $entity.',
            );
      } else if (subjects.length == 1) {
        subject = subjects.single;
      } else {
        refuse(
          'privacy.model.subject_ambiguous',
          '$entity.${c.declaredName} is @TomPersonal and names no subject, '
              'but $entity has ${subjects.length} @TomDataSubject fields; '
              'name one with @TomPersonal(subject: ...).',
        );
      }
      personal.add(TomPersonalField(c, subject, declaration));
    }

    final retention = mirror?.metadata.whereType<TomRetention>().firstOrNull;
    if (retention != null) {
      final field = columns
          .where((c) => c.declaredName == retention.field)
          .firstOrNull;
      if (field == null || typeOf(field) != 'DateTime' || retention.days < 1) {
        refuse(
          'privacy.model.retention_field',
          '$entity keeps rows by ${retention.field} for ${retention.days} '
              'days; retention needs a DateTime field of the entity and at '
              'least one day.',
        );
      }
      if (retention.action != TomErasure.delete && subjects.isEmpty) {
        refuse(
          'privacy.model.retention_anonymize',
          '$entity anonymizes rows on retention but has no @TomDataSubject '
              'field to clear.',
        );
      }
    }

    final table = TomAnnotationAnalyzer.findTable(entity);
    final keys = [
      for (final f in table?.primaryKeyFields ?? const <String>[])
        ...columns.where((c) => c.declaredName == f || c.field == f),
    ];
    return TomPersonalDataModel._(
      entity,
      List.unmodifiable(subjects),
      List.unmodifiable(personal),
      retention,
      List.unmodifiable(keys),
    );
  }

  /// The personal fields of [subject].
  List<TomPersonalField> personalOf(TomSubjectField subject) => [
    for (final p in personal)
      if (identical(p.subject, subject)) p,
  ];

  /// For an audit record of [row]: each personal field's name, mapped to the
  /// id of the subject whose key its values are sealed under. A field whose
  /// subject field is `null` or `''` in [row] is left out — there is no one to
  /// seal it for.
  Map<String, String> sealingSubjects(Object? row) {
    if (row == null || personal.isEmpty) return const {};
    return {
      for (final p in personal)
        // An encrypted field's value is already redacted in the trail.
        if (p.column.encrypted == null)
          if (p.subject.column.getVariableValue(row) case final Object id
              // An empty id names nobody: a non-nullable column's default.
              when '$id'.isNotEmpty)
            p.name: '$id',
    };
  }

  /// Clears in [row] the subject field [subject] and, when [anonymize], its
  /// personal fields; answers whether anything changed.
  bool clear(Object row, TomSubjectField subject, {required bool anonymize}) {
    var changed = false;
    void set(TomColumnInformation c, Object? value) {
      if (c.getVariableValue(row) == value) return;
      c.setVariableValue(row, value);
      changed = true;
    }

    if (anonymize) {
      for (final p in personalOf(subject)) {
        set(p.column, p.declaration.replacement);
      }
    }
    set(subject.column, null);
    return changed;
  }

  /// The primary key of [row], as a list of its key values.
  List<Object?> keyOf(Object row) => [
    for (final k in keys) k.getVariableValue(row),
  ];
}
