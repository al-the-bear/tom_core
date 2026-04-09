import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Base class for all Tom UI elements (widgets, actions, containers).
///
/// Provides:
/// - [tomId] — unique ID within its scope.
/// - [tomGroup] — optional group membership.
/// - [scope] — optional explicit scope (defaults to [TomScope.current]).
/// - [authorizer] — optional per-widget authorizer.
/// - [authorizerStrategy] — how authorizer interacts with resource auth.
/// - [uiStateController] — build-time state narrowing callback.
/// - Resource path resolution via [basePath].
/// - Debug identity via [debugLabel].
///
/// Resource paths are constructed as: `<scopePath>.<tomId>` where scopePath
/// comes from either the explicit [scope] or the current [TomScope].
///
/// Implements [TomAuthorizable] for type-safe group registration and
/// authorization system participation.
abstract class TomNodeBase extends StatelessWidget implements TomAuthorizable {
  @override
  final String? tomId;

  @override
  final TomAuthorizationGroup? tomGroup;

  /// Optional explicit scope for resource/auth lookups.
  ///
  /// When provided, this scope is used instead of [TomScope.current].
  final TomScope? scope;

  /// Optional per-widget authorizer that can modify authorization outcomes.
  ///
  /// When set, the authorizer is consulted after resource-based authorization
  /// and can modify the effective state according to [authorizerStrategy].
  final TomAuthorizer? authorizer;

  /// Strategy controlling how [authorizer] interacts with resource auth.
  ///
  /// Defaults to [TomAuthorizerStrategy.authorizerNarrowsOnly].
  final TomAuthorizerStrategy authorizerStrategy;

  /// Build-time callback that can further narrow the widget's state.
  ///
  /// Runs at build time (not construction time) and can only narrow,
  /// never widen, the effective authorization state.
  final TomUIStateController? uiStateController;

  /// The scope that was active when this widget was constructed.
  final TomScope constructionScope;

  /// The resolved canonical resource base path for this node.
  final String? basePath;

  TomNodeBase({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.authorizerStrategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    this.uiStateController,
  })  : constructionScope = scope ?? TomScope.current,
        basePath = _resolveBasePath(tomId, scope) {
      tomGroup?.register(this);
  }

  static String? _resolveBasePath(String? tomId, TomScope? scope) {
    if (tomId == null) return null;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    if (scopePath.isNotEmpty) return '$scopePath.$tomId';
    return tomId;
  }

  /// Debug description for this node.
  String get debugLabel {
    final parts = <String>[];
    if (tomId != null) parts.add('id: $tomId');
    if (tomGroup != null) parts.add('group: ${tomGroup!.groupId}');
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }
}
