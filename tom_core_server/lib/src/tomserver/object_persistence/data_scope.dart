import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../little_things/server_exception.dart';
import 'persistence_annotations.dart';
import 'query_builder.dart';

/// Thrown when a `@TomDbScope` names a scope kind that no resolver is
/// registered for in [TomDataScopeRegistry].
class TomDataScopeException extends TomServerException {
  /// Creates a data-scope exception.
  TomDataScopeException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Maps the current [TomPrincipal] to the set of scope-field values it is
/// allowed to see for a given scope kind.
///
/// Returning an empty list denies every row (the principal sees nothing);
/// returning `null` opts out of scoping entirely (every row is visible). A
/// `null` principal (unauthenticated request) is handled by each resolver — the
/// built-in resolvers treat it as "no allowed values" (deny), which is the
/// secure default.
typedef TomDataScopeResolver = List<Object?>? Function(TomPrincipal? principal);

/// Registry of the named row-scope resolvers a `@TomDbScope` can reference.
///
/// Two resolvers are registered out of the box:
///
///  - `'owner'` — the principal's own id (`principal.id`); a `null` principal
///    sees nothing;
///  - `'group'` — the principal's groups (`principal.aci.groups`); a `null`
///    principal sees nothing.
///
/// Applications register their own scope kinds (e.g. `'organization'`,
/// `'tenant'`) via [register]; [reset] restores just the built-ins (used by
/// tests to undo custom registrations).
class TomDataScopeRegistry {
  TomDataScopeRegistry._();

  static Map<String, TomDataScopeResolver> _defaults() => {
    'owner': (principal) =>
        principal == null ? const <Object?>[] : <Object?>[principal.id],
    'group': (principal) =>
        principal == null ? const <Object?>[] : principal.aci.groups,
  };

  static final Map<String, TomDataScopeResolver> _resolvers = _defaults();

  /// Registers (or replaces) the [resolver] for the scope kind [scope].
  static void register(String scope, TomDataScopeResolver resolver) {
    _resolvers[scope] = resolver;
  }

  /// The resolver for scope kind [scope], or `null` if none is registered.
  static TomDataScopeResolver? resolverFor(String scope) => _resolvers[scope];

  /// Restores the built-in resolvers, discarding any custom registrations.
  static void reset() {
    _resolvers
      ..clear()
      ..addAll(_defaults());
  }
}

/// A resolved row-scope predicate: the boolean [predicate] to AND into a
/// query's `WHERE`, plus the [parameters] the predicate binds (one entry per
/// allowed scope value, keyed by the placeholder name).
class TomDataScopePredicate {
  /// The predicate (`<field> IN (:__tomscope_0, …)` or a `FALSE` deny literal).
  final TomOperator<TomDbBool> predicate;

  /// The bind values for the predicate's parameters, keyed by placeholder name.
  final Map<String, Object?> parameters;

  /// Bundles a scope [predicate] with the [parameters] it binds.
  TomDataScopePredicate(this.predicate, this.parameters);
}

/// Builds the row-scope predicate for an entity's `@TomDbScope` from the
/// current principal's allowed values, using one bound parameter per value.
class TomDataScope {
  TomDataScope._();

  /// The prefix of the generated scope parameter names (`__tomscope_0`, …),
  /// chosen so it cannot collide with an application's own bind names.
  static const String parameterPrefix = '__tomscope_';

  /// Builds the scope predicate for [scope] on column [col] from [principal]'s
  /// allowed values, resolved through [TomDataScopeRegistry].
  ///
  /// Returns:
  ///  - `null` when the resolver opts out (its result is `null`) — no scoping;
  ///  - a `FALSE` predicate when the principal has no allowed values — deny all
  ///    (avoids emitting the syntactically invalid `IN ()`);
  ///  - `<col> IN (:__tomscope_0, …)` otherwise, one bound [Parameter] per
  ///    value so no value is concatenated into the SQL (C-7).
  ///
  /// Throws [TomDataScopeException] if `scope.scope` names an unregistered kind.
  static TomDataScopePredicate? build(
    TomQueryBuilder builder,
    TomDbScope scope,
    TomColumnInformation col,
    TomPrincipal? principal,
  ) {
    final resolver = TomDataScopeRegistry.resolverFor(scope.scope);
    if (resolver == null) {
      throw TomDataScopeException(
        'data_scope.build.unknown_scope',
        'No data-scope resolver registered for scope kind "${scope.scope}" '
            '(field "${scope.field}"). Register one with '
            'TomDataScopeRegistry.register.',
      );
    }
    final values = resolver(principal);
    if (values == null) return null;
    if (values.isEmpty) {
      // No allowed values -> deny every row. `IN ()` is invalid SQL, so a bare
      // FALSE predicate is the correct empty-set filter.
      return TomDataScopePredicate(builder.boolOp(false), const {});
    }
    final parameters = <String, Object?>{};
    final names = <String>[];
    for (var i = 0; i < values.length; i++) {
      final name = '$parameterPrefix$i';
      names.add(name);
      parameters[name] = values[i];
    }
    return TomDataScopePredicate(inColumn(builder, col, names), parameters);
  }

  /// Builds `<col> IN (:name0, :name1, …)` referencing [col] against one bound
  /// parameter per name in [parameterNames], dispatching the column/parameter
  /// SQL type on the column's declared Dart type (`int` → integer, otherwise
  /// string — the two realistic scope-value types).
  static TomOperator<TomDbBool> inColumn(
    TomQueryBuilder builder,
    TomColumnInformation col,
    List<String> parameterNames,
  ) {
    final field = col.getQueryFieldName();
    if (col.declaredType == int) {
      return builder.isIn<TomDbInt>(
        builder.intF(field, col),
        [for (final n in parameterNames) builder.p<TomDbInt>(n)],
      );
    }
    return builder.isIn<TomDbString>(
      builder.textF(field, col),
      [for (final n in parameterNames) builder.p<TomDbString>(n)],
    );
  }

  /// Builds `<col> = :parameterName`, dispatching the SQL type on [col]'s
  /// declared Dart type the same way [inColumn] does. Used to keep a primary-key
  /// equality typed consistently when a scope predicate is ANDed onto it.
  static TomOperator<TomDbBool> columnEqualsParam(
    TomQueryBuilder builder,
    TomColumnInformation col,
    String parameterName,
  ) {
    final field = col.getQueryFieldName();
    if (col.declaredType == int) {
      return builder.eq<TomDbInt>(
        builder.intF(field, col),
        builder.p<TomDbInt>(parameterName),
      );
    }
    return builder.eq<TomDbString>(
      builder.textF(field, col),
      builder.p<TomDbString>(parameterName),
    );
  }
}
