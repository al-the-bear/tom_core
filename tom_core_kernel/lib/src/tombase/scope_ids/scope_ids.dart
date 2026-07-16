import 'dart:async';
import 'package:tom_core_kernel/src/tombase/little_things/little_things.dart';

/// Shared scope-installation policy for [TomScope.runInScope] and
/// [TomScopeMixin.runInScope].
///
/// If [scope] is already the current zone scope (identical reference), [body]
/// runs directly without creating a new zone — this prevents duplicate scope
/// nesting. Otherwise [body] runs in a child zone carrying [scope].
T _runScoped<T>(TomScope scope, T Function() body) {
  if (identical(scope, TomScope.current)) return body();
  return runZoned(body, zoneValues: {TomScope: scope});
}

/// A hierarchical, zone-propagated identifier used to namespace resource
/// lookups (e.g. `app.checkout.orderForm`).
///
/// Scopes form a parent chain rooted at [defaultScope]. The active scope is
/// carried on the current [Zone], so [current] resolves to whichever scope was
/// installed by the nearest enclosing [withScope] / [runInScope] call.
abstract class TomScope {
  /// This scope's local identifier (the last segment of its path).
  String get id;

  /// The enclosing scope, or `null` for the root [defaultScope].
  TomScope? get parent;

  /// The root scope used when no scope is installed on the current zone.
  static TomScope defaultScope = TomScopeBase(scopeId: 'default', parentScope: null);

  /// The scope installed on the current [Zone], or [defaultScope] if none.
  static TomScope get current => getFromCurrentZone<TomScope>() ?? defaultScope;

  /// Runs [body] in a new child scope named [scope], parented to [current].
  static T withScope<T>(String scope, T Function() body) {
    return runZoned(body,
        zoneValues: {TomScope: TomScopeBase(scopeId: scope, parentScope: current)});
  }

  /// Runs [body] inside this scope's zone.
  ///
  /// If this scope is already the current zone scope (identical reference),
  /// [body] is executed directly without creating a new zone.
  /// This prevents duplicate scope nesting.
  T runInScope<T>(T Function() body) => _runScoped(this, body);

  /// Builds the scope path for any TomScope instance.
  /// Returns a dot-separated string (e.g., "app.checkout.orderForm").
  static String buildScopePath(TomScope scope) {
    final List<String> parts = [];
    TomScope? current = scope;
    while (current != null) {
      // Elide only the actual root sentinel ([defaultScope]) — identified by
      // identity, not by its 'default' id string. A legitimate domain scope
      // whose local id happens to be 'default' is not the sentinel and must
      // keep its segment in the path (bug §50).
      if (!identical(current, TomScope.defaultScope)) {
        parts.add(current.id);
      }
      current = current.parent;
    }
    return parts.reversed.join('.');
  }

  /// Returns the full scope path as a dot-separated string.
  /// Used as a prefix for resource lookups.
  String getScopePath() => buildScopePath(this);
}

/// Concrete [TomScope] built from a scope id and an optional parent.
class TomScopeBase with TomScopeMixin {
  TomScopeBase({required String scopeId, TomScope? parentScope}) {
    initScope(scopeId: scopeId, parentScope: parentScope);
  }
}

/// Reusable [TomScope] implementation backing [TomScopeBase].
///
/// Mix into a class and call [initScope] once during construction to set the
/// scope's identity. The backing fields are write-once.
mixin TomScopeMixin on Object implements TomScope {
  late final String _id;
  late final TomScope? _parent;

  /// Initialises this scope's identity. Call exactly once during construction.
  void initScope({required String scopeId, TomScope? parentScope}) {
    _id = scopeId;
    _parent = parentScope;
  }

  /// Sets the scope id. Only valid before [initScope] has run (write-once).
  set id(String newId) => _id = newId;

  /// Sets the parent scope. Only valid before [initScope] has run (write-once).
  set parent(TomScope? newParent) => _parent = newParent;

  @override
  String get id => _id;
  @override
  TomScope? get parent => _parent;

  @override
  String getScopePath() => TomScope.buildScopePath(this);

  @override
  T runInScope<T>(T Function() body) => _runScoped(this, body);
}

/// Captures a [TomScope] at construction time and wraps callback functions
/// so they execute within that scope when called later.
///
/// Flutter calls builder callbacks (e.g., `itemBuilder`, `builder`) outside
/// the original zone. This wrapper ensures Tom widgets created inside those
/// callbacks still get the correct scope for resource resolution.
///
/// Usage in Tom widget constructors:
/// ```dart
/// class TomFoo extends TomNodeBase {
///   final WidgetBuilder _builder;
///   TomFoo({required WidgetBuilder builder, super.scope})
///       : _builder = InScopeBuilder(scope: scope).wrap1(builder);
/// }
/// ```
class InScopeBuilder {
  final TomScope _scope;

  InScopeBuilder({TomScope? scope})
      : _scope = scope ?? TomScope.current;

  /// Wraps a 0-argument callback.
  R Function() wrap0<R>(R Function() fn) =>
      () => _scope.runInScope(() => fn());

  /// Wraps a 1-argument callback.
  R Function(A) wrap1<R, A>(R Function(A) fn) =>
      (a) => _scope.runInScope(() => fn(a));

  /// Wraps a 2-argument callback.
  R Function(A, B) wrap2<R, A, B>(R Function(A, B) fn) =>
      (a, b) => _scope.runInScope(() => fn(a, b));

  /// Wraps a 3-argument callback.
  R Function(A, B, C) wrap3<R, A, B, C>(R Function(A, B, C) fn) =>
      (a, b, c) => _scope.runInScope(() => fn(a, b, c));

  /// Wraps a 4-argument callback.
  R Function(A, B, C, D) wrap4<R, A, B, C, D>(R Function(A, B, C, D) fn) =>
      (a, b, c, d) => _scope.runInScope(() => fn(a, b, c, d));

  /// Wraps a 5-argument callback.
  R Function(A, B, C, D, E) wrap5<R, A, B, C, D, E>(
          R Function(A, B, C, D, E) fn) =>
      (a, b, c, d, e) => _scope.runInScope(() => fn(a, b, c, d, e));

  /// Wraps a nullable 0-argument callback. Returns null if [fn] is null.
  R Function()? wrap0n<R>(R Function()? fn) =>
      fn == null ? null : wrap0(fn);

  /// Wraps a nullable 1-argument callback. Returns null if [fn] is null.
  R Function(A)? wrap1n<R, A>(R Function(A)? fn) =>
      fn == null ? null : wrap1(fn);

  /// Wraps a nullable 2-argument callback. Returns null if [fn] is null.
  R Function(A, B)? wrap2n<R, A, B>(R Function(A, B)? fn) =>
      fn == null ? null : wrap2(fn);

  /// Wraps a nullable 3-argument callback. Returns null if [fn] is null.
  R Function(A, B, C)? wrap3n<R, A, B, C>(R Function(A, B, C)? fn) =>
      fn == null ? null : wrap3(fn);

  /// Wraps a nullable 4-argument callback. Returns null if [fn] is null.
  R Function(A, B, C, D)? wrap4n<R, A, B, C, D>(R Function(A, B, C, D)? fn) =>
      fn == null ? null : wrap4(fn);

  /// Wraps a nullable 5-argument callback. Returns null if [fn] is null.
  R Function(A, B, C, D, E)? wrap5n<R, A, B, C, D, E>(
          R Function(A, B, C, D, E)? fn) =>
      fn == null ? null : wrap5(fn);

  /// Wraps a callback with one positional and named parameters.
  /// Use for Flutter's [InputCounterWidgetBuilder] and similar typedefs
  /// that use named parameters.
  R Function(A, {required B currentLength, required C maxLength, required D isFocused})
      wrapCounter<R, A, B, C, D>(
          R Function(A, {required B currentLength, required C maxLength, required D isFocused}) fn) =>
      (a, {required currentLength, required maxLength, required isFocused}) =>
          _scope.runInScope(() => fn(a,
              currentLength: currentLength,
              maxLength: maxLength,
              isFocused: isFocused));
}
