import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'tom_scope_path.dart';
import 'tom_widget_surface.dart';

/// Base class for all Tom UI elements (widgets, actions, containers).
///
/// Provides:
/// - [tomId] — unique ID within its scope.
/// - [tomGroup] — optional group membership.
/// - [scope] — optional explicit scope (defaults to [TomScope.current]).
/// - [authorizer] — optional per-widget authorizer.
/// - [uiStateController] — build-time state narrowing callback.
/// - Resource path resolution via [basePath].
/// - Debug identity via [debugLabel].
///
/// Resource paths are constructed by [TomScopePath.resolve] from either the
/// explicit [scope] or the current [TomScope] — the same rule every other
/// path in the library goes through, so a node and the resources, policies
/// and groups that address it always agree on where it lives.
///
/// Implements [TomWidgetSurface] — and through it [TomAuthorizable] — for
/// type-safe group registration and authorization system participation. That
/// interface is what the conformance suite enumerates against; a base that
/// dropped [basePath] would stop compiling here rather than stop gating in
/// production.
abstract class TomNodeBase extends StatelessWidget
    implements TomWidgetSurface {
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
  /// and combines its verdict with the resource state according to its own
  /// [TomAuthorizer.strategy].
  final TomAuthorizer? authorizer;

  /// Build-time callback that can further narrow the widget's state.
  ///
  /// Runs at build time (not construction time) and can only narrow,
  /// never widen, the effective authorization state.
  final TomUIStateController? uiStateController;

  /// The scope that was active when this widget was constructed.
  final TomScope constructionScope;

  /// The resolved canonical resource base path for this node.
  @override
  final String? basePath;

  TomNodeBase({
    super.key,
    this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.uiStateController,
  })  : constructionScope = scope ?? TomScope.current,
        basePath = TomScopePath.resolve(tomId, scope) {
      tomGroup?.register(this);
  }

  /// Debug description for this node.
  String get debugLabel {
    final parts = <String>[];
    if (tomId != null) parts.add('id: $tomId');
    if (tomGroup != null) parts.add('group: ${tomGroup!.groupId}');
    return '${runtimeType.toString()}(${parts.join(', ')})';
  }
}
