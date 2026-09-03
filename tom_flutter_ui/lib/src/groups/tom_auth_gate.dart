import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

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
    required this.child,
  });

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
  /// to answer from the same four layers as everything else, and this is how
  /// they reach them without a place in the tree.
  static TomAuthState resolve({
    required String? tomId,
    TomAuthorizationGroup? tomGroup,
    TomScope? scope,
    TomAuthorizer? authorizer,
    TomUIStateController? uiStateController,
  }) => TomAuthGate(
    tomId: tomId,
    tomGroup: tomGroup,
    scope: scope,
    authorizer: authorizer,
    uiStateController: uiStateController,
    child: const SizedBox.shrink(),
  ).getAuth();

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
