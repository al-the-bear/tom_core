/// The reflected entity the object-persistence example maps, queries and grades.
///
/// Declared beside the example rather than inside it because the example imports
/// the generated reflection, and a type the generator captures cannot also live
/// in a file that imports the generator's output.
///
/// It is captured through `example/example_reflection.dart`, the example suite's
/// single reflection root.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// An expense claim: one entity carrying every column shape the module's
/// connection-free surface needs to demonstrate itself.
///
/// The example compiles query sentences against it, groups it, pages it and
/// grades its columns, so the field list is chosen to make all four expressible
/// on one type rather than to model expenses well:
///
///  * [employee] is text, and is the group key — a grouped query needs a column
///    with few distinct values for the grouping to mean anything;
///  * [amount] is the numeric the aggregates run over (`SUM`, `AVG`, `MAX`);
///  * [submitted] is a timestamp, so an ordering has something to sort by that
///    is not also the group key;
///  * [approved] is a boolean, which the sentence compiler types differently
///    from every other column and so is worth having in a predicate.
///
/// The last two fields are what make column authorization (C-4) demonstrable,
/// and they carry **different grades on purpose** — a single graded column would
/// show that grading happens, but not that the two failure modes differ:
///
///  * [reimbursementAccount] is intended to resolve as `read`: the clerk may see
///    the account a claim pays out to, and an attempt to *change* it is a
///    genuine violation that gets named;
///  * [fraudScore] is intended to resolve as `none`: it is masked on the way
///    out, so a client never sees it, round-trips `null` for it, and must have
///    that silently overlaid rather than rejected.
///
/// Both are nullable because a graded field has to be — masking writes `null`,
/// and there is no other value that means "withheld".
///
/// The `datasource` is named and never reached. `@TomDbTable` requires one, and
/// everything the example does reads annotations or renders SQL text, so the
/// whole run happens with no database anywhere.
@tomReflector
@TomDbTable(
  datasource: 'unused_by_this_example',
  table: 'example_claim',
  primaryKeyFields: ['id'],
)
class ExampleClaimRecord {
  /// Surrogate primary key, and the tie-breaker the repository appends to a
  /// paged query whose sort does not already settle the order.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// Who claimed — the group key.
  @TomDbColumn(columnName: 'employee')
  String? employee;

  /// What it came to — the aggregated measure.
  @TomDbColumn(columnName: 'amount')
  double? amount;

  /// When it was filed — the sort column.
  @TomDbColumn(columnName: 'submitted')
  DateTime? submitted;

  /// Whether it cleared approval — a boolean predicate operand.
  @TomDbColumn(columnName: 'approved')
  bool? approved;

  /// Visible, not editable: graded `read` by the example's resolver.
  @TomDbColumn(
    columnName: 'reimbursement_account',
    authKey: 'example.claim.reimbursement_account',
  )
  String? reimbursementAccount;

  /// Withheld entirely: graded `none`, so reads mask it and writes overlay it.
  @TomDbColumn(columnName: 'fraud_score', authKey: 'example.claim.fraud_score')
  double? fraudScore;
}

/// A wiki article two people may edit at once: the entity the
/// optimistic-locking example maps.
///
/// [version] is maintained by the repository — `1` on insert, one more on
/// every save — and an update or delete presenting a version the row no longer
/// holds is refused instead of overwriting the other person's edit.
@tomReflector
@TomDbTable(
  datasource: 'unused_by_this_example',
  table: 'example_article',
  primaryKeyFields: ['id'],
)
class ExampleArticle {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The row's version.
  @TomVersion()
  @TomDbColumn(columnName: 'version')
  int? version;

  /// The article's body.
  @TomDbColumn(columnName: 'body')
  String? body;
}

/// A patient record whose personal data is encrypted at rest: the entity the
/// field-encryption example encrypts, indexes and redacts.
///
/// [name] and [email] are `@TomEncrypted`, so the table only ever holds their
/// ciphertext; [emailIndex] is the blind index of [email], the column a lookup
/// by e-mail address compares. [ward] is stored as it is, which is what lets a
/// query filter or group on it.
@tomReflector
@TomDbTable(
  datasource: 'unused_by_this_example',
  table: 'example_patient',
  primaryKeyFields: ['id'],
)
class ExamplePatientRecord {
  /// Surrogate primary key.
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  /// The patient's name, encrypted at rest.
  @TomEncrypted()
  @TomDbColumn(columnName: 'name')
  String? name;

  /// The patient's e-mail address, encrypted at rest and found by value.
  @TomEncrypted()
  @TomDbColumn(columnName: 'email')
  String? email;

  /// The blind index of [email].
  @TomBlindIndex('email')
  @TomDbColumn(columnName: 'email_bidx')
  String? emailIndex;

  /// The ward, stored as it is.
  @TomDbColumn(columnName: 'ward')
  String? ward;
}
