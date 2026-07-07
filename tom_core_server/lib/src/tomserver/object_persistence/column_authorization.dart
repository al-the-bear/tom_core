/// Column-level access rights (C-4).
///
/// The kernel's [TomAuthState] four-state grade (`none < disabled < read <
/// full`) is a *presentation* contract — the client renders a field editable,
/// read-only, greyed-out, or hidden. C-4 makes the **server** honour the same
/// grade *authoritatively* at the persistence boundary, so a hostile or buggy
/// client cannot read a column it may not see or write one it may not change:
///
/// - **Read masking.** A column the principal cannot see (state without
///   [TomAuthState.showsContent] — `none`/`disabled`) is nulled out of every
///   row the repository returns, so its value never leaves the server.
/// - **Write enforcement.** A change to a column the principal is not `full` on
///   is rejected when the column is *visible* (`read`) — the caller could see
///   the value, so changing it is a genuine violation — and silently overlaid
///   from the stored value when the column is *masked* (`none`/`disabled`), so a
///   round-tripped masked-null never clobbers the stored value.
///
/// A column opts in through [TomDbColumn.authKey]; the repository resolves that
/// key to a [TomAuthState] through a resolver (by default the process-wide
/// [TomAuthorization] singleton, per the C-4 spec). A column with no `authKey`
/// is unrestricted, so entities that declare none keep their behaviour exactly.
///
/// The **decision** ([decideWrites], [maskedColumns], [stateForKey]) is pure and
/// reflection-free: it takes value/­key accessors as callbacks so the same
/// algorithm drives the repository's reflection path *and* a sample's DTO path,
/// and can be unit-tested without a database or the reflection runtime. The
/// reflection-backed I/O ([applyReadMask]) lives beside it for the repository.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'persistence_annotations.dart';

/// Resolves a column's [TomDbColumn.authKey] to the current principal's
/// [TomAuthState] for that resource key.
///
/// The repository's default resolver is [TomAuthorization.resolveAuth]; tests
/// pass a stub mapping keys to states.
typedef TomColumnAuthResolver = TomAuthState Function(String authKey);

/// Thrown when a write changes a column the current principal is not authorized
/// to change (C-4): the column is *visible* to the principal (state
/// [TomAuthState.read]) but not [TomAuthState.full], so altering its value is a
/// genuine, rejectable violation rather than a masked-value round-trip.
class TomColumnAuthorizationException extends TomServerException {
  /// Creates a column-authorization exception.
  TomColumnAuthorizationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow,
  });
}

/// The write outcome for a set of authorized columns [C]: which the caller may
/// write (grade [TomAuthState.full], overlaid from the incoming value) and which
/// must be preserved from the baseline (every non-`full` grade).
class TomColumnWriteDecision<C> {
  /// Columns the caller may write — their incoming value is persisted.
  final List<C> writable;

  /// Columns the caller may not write — the baseline value is persisted instead
  /// (silently for masked columns, and for unchanged visible columns).
  final List<C> preserved;

  /// Bundles the [writable] and [preserved] partitions.
  const TomColumnWriteDecision(this.writable, this.preserved);
}

/// The C-4 decision algorithm, pure over abstract column tokens.
///
/// Both the SQL repository (over reflected [TomColumnInformation]) and a
/// service-layer field check (over its own field descriptors) call these; they
/// supply value/key accessors and — for a rejection — their own exception, so
/// the single algorithm serves every enforcement point.
class TomColumnAuthorization {
  TomColumnAuthorization._();

  /// The resource-key resolver used when a caller passes none: the process-wide
  /// [TomAuthorization] singleton (which yields [TomAuthState.full] in
  /// development mode, leaving unconfigured deployments unrestricted).
  static TomAuthState _defaultResolver(String authKey) =>
      TomAuthorization.resolveAuth(authKey);

  /// The [TomAuthState] the principal holds on the column identified by
  /// [authKey], or [TomAuthState.full] when [authKey] is `null` (an
  /// unrestricted column).
  static TomAuthState stateForKey(
    String? authKey, {
    TomColumnAuthResolver? resolver,
  }) {
    if (authKey == null) return TomAuthState.full;
    return (resolver ?? _defaultResolver)(authKey);
  }

  /// The subset of [columns] the principal may **not** see — their grade lacks
  /// [TomAuthState.showsContent] (`none`/`disabled`). The caller nulls these out
  /// of each returned row so a masked value never leaves the server.
  static List<C> maskedColumns<C>({
    required Iterable<C> columns,
    required String? Function(C) keyOf,
    TomColumnAuthResolver? resolver,
  }) => [
    for (final column in columns)
      if (!stateForKey(keyOf(column), resolver: resolver).showsContent) column,
  ];

  /// Partitions [columns] into the ones the caller may write and the ones whose
  /// baseline value must be preserved, rejecting an unauthorized visible change.
  ///
  /// For each column, [gradeOf] gives its resource key (or `null` = unrestricted)
  /// and [changed] whether the incoming value differs from the baseline. The
  /// grade decides the outcome:
  ///
  /// - [TomAuthState.full] → **writable** (the incoming value is persisted);
  /// - [TomAuthState.read] (visible, not editable) → if [changed], the caller is
  ///   altering a value they can see but not edit: [onForbidden] is invoked
  ///   (and must not return); if unchanged, the column is **preserved**;
  /// - [TomAuthState.disabled] / [TomAuthState.none] (masked) → **preserved**
  ///   unconditionally, so a round-tripped masked-null cannot clobber the stored
  ///   value and cannot itself constitute a violation.
  static TomColumnWriteDecision<C> decideWrites<C>({
    required Iterable<C> columns,
    required String? Function(C) gradeOf,
    required bool Function(C) changed,
    required Never Function(C column, String authKey, TomAuthState grade)
        onForbidden,
    TomColumnAuthResolver? resolver,
  }) {
    final writable = <C>[];
    final preserved = <C>[];
    for (final column in columns) {
      final authKey = gradeOf(column);
      final grade = stateForKey(authKey, resolver: resolver);
      if (grade.isInteractive) {
        writable.add(column);
        continue;
      }
      // Not full: the column's value is not the caller's to change. A *visible*
      // (read) column that the caller changed is a genuine violation; a masked
      // column — or an unchanged visible one — is preserved from the baseline.
      if (grade.showsContent && changed(column)) {
        onForbidden(column, authKey!, grade);
      }
      preserved.add(column);
    }
    return TomColumnWriteDecision(writable, preserved);
  }

  /// Nulls out — in place — every field of [instance] the principal may not see
  /// (the [maskedColumns] of [columns]); returns [instance] for chaining.
  ///
  /// The masked fields must be nullable on the entity (a masked value becomes
  /// `null`); an entity opts a column into masking by declaring its
  /// [TomDbColumn.authKey], and such columns are modelled nullable so the value
  /// can be withheld.
  static T applyReadMask<T extends Object>(
    T instance,
    List<TomColumnInformation> columns, {
    TomColumnAuthResolver? resolver,
  }) {
    final masked = maskedColumns<TomColumnInformation>(
      columns: columns,
      keyOf: (column) => column.column?.authKey,
      resolver: resolver,
    );
    for (final column in masked) {
      column.setVariableValue(instance, null);
    }
    return instance;
  }
}
