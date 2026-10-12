import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_auth_layers.dart';
import '../widget_base/tom_scope_path.dart';
import 'tom_group_membership.dart';
import 'tom_widget_mixin.dart';

/// Applies Tom authorization to a subtree that cannot apply it itself.
///
/// Most Tom widgets resolve their own authorization: they extend a family base,
/// or they extend a Flutter widget whose `State` is public and can wrap
/// `super.build`. Some cannot do either. Three shapes recur:
///
/// - the Flutter original is **not a widget** at all, so there is no `build` to
///   wrap — `DataCell`, `DataColumn`, `ExpansionPanel` are plain classes that
///   *hold* widgets;
/// - the Flutter original is a widget whose `State` is **private** —
///   `_SnackBarState`, `_AnimatedPositionedState` — so `super.build(context)`
///   is unreachable from outside the framework;
/// - the value that needs gating is a constructor argument evaluated before any
///   [BuildContext] exists.
///
/// In all three the widget still owns a slot — `child`, `content`, `label` —
/// and gating it is what gating the widget means. [TomAuthGate] is that slot
/// wrapper. It mixes in [TomWidgetMixin], so it resolves through the same four
/// layers as every other Tom widget and applies the same visual treatment;
/// there is deliberately no second authorization rule in the package.
///
/// It is a widget rather than a helper function because the resolution needs a
/// [BuildContext] — the `disabled` and `read` treatments come from the ambient
/// [TomTheme] — and the wrappers construct their slots long before one exists.
///
/// ```dart
/// TomAuthGate(
///   tomId: 'salary',
///   tomGroup: payrollGroup,
///   child: Text(employee.salary),
/// )
/// ```
///
/// A gate with a [tomGroup] is a member of it while it is mounted, like every
/// other Tom widget (see [TomGroupMemberElement]): the gate *is* the group
/// member for the slot it governs, because the widget or plain class around it
/// has no element of its own to register from. A host that gates two slots under one id — `TomExpansionPanel`'s
/// header and body — lets one gate join and passes [joinsGroup] `false` to the
/// other, so the group counts the panel once.
class TomAuthGate extends StatelessWidget with TomWidgetMixin {
  /// Wraps [child] in this widget's authorization.
  ///
  /// [tomId] may be null; a gate with no resource path still applies whatever
  /// [tomGroup], [authorizer] and [uiStateController] say. Only a gate with
  /// none of the four returns [child] untouched — nothing to look up and
  /// nobody to ask means nothing to narrow.
  const TomAuthGate({
    super.key,
    required this.tomId,
    this.tomGroup,
    this.scope,
    this.authorizer,
    this.uiStateController,
    this.joinsGroup = true,
    required this.child,
  });

  @override
  StatelessElement createElement() => _TomAuthGateGroupMemberElement(this);

  @override
  final String? tomId;

  @override
  final TomAuthorizationGroup? tomGroup;

  @override
  final TomScope? scope;

  @override
  final TomAuthorizer? authorizer;

  @override
  final TomUIStateController? uiStateController;

  /// The subtree this gate governs.
  final Widget child;

  /// Whether this gate is a member of [tomGroup] while mounted. `false` only
  /// for a second gate over a host another gate already represents;
  /// authorization is resolved through the group either way.
  final bool joinsGroup;

  /// Whether any of the four layers has something to say about this slot.
  ///
  /// All four are checked, not just [tomId] and [tomGroup]: an [authorizer] or
  /// a [uiStateController] narrows on its own, without a resource path to
  /// start from, so a gate carrying either is configured even when it
  /// addresses no resource.
  bool get _isConfigured =>
      tomId != null ||
      tomGroup != null ||
      authorizer != null ||
      uiStateController != null;

  /// The state a gate with these inputs would apply, without building one.
  ///
  /// `DataRow` and `DataColumn` decide their own visibility *before* the table
  /// is built — a row cannot hide itself once `DataTable` has demanded one
  /// cell per column from it, so the caller filters instead. They still have
  /// to answer from the same four layers as everything else, so this resolves
  /// through [TomAuthLayers.resolve] with the path and scope a gate would
  /// derive — and, being no widget, joins no group.
  static TomAuthState resolve({
    required String? tomId,
    TomAuthorizationGroup? tomGroup,
    TomScope? scope,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) {
    final effectiveScope = scope ?? TomScope.current;
    return TomAuthLayers.resolve(
      basePath: TomScopePath.resolve(tomId, effectiveScope),
      group: tomGroup,
      groupScope: effectiveScope,
      authorizer: authorizer,
      uiStateController: uiStateController,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nothing configured means there is no rule to apply, so the child is
    // returned as it came — untouched, not merely resolved to `full`.
    if (!_isConfigured) return child;
    final hidden = checkHidden();
    if (hidden != null) return hidden;
    return applyAuthState(context, child);
  }
}

/// A gate's element: a member of the gate's group unless the gate was told not
/// to join it.
class _TomAuthGateGroupMemberElement extends TomStatelessGroupMemberElement {
  _TomAuthGateGroupMemberElement(TomAuthGate super.widget);

  @override
  TomAuthorizable? groupMemberFor(Widget widget) =>
      widget is TomAuthGate && widget.joinsGroup ? widget : null;
}
