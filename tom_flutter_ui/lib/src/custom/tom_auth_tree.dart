/// Hierarchical tree with **per-node authorization**.
///
/// Every node carries its own resource key and resolves its
/// [TomAuthState] independently, so one tree can surface a different
/// shape per user role — which is what nav and permissions UIs need.
/// Contrast [TomTreeView], whose authorization is widget-level: the
/// whole tree is hidden or disabled together. Pick this pair when the
/// grant varies *within* the tree, [TomTreeView] when it does not.
///
/// Lookup rules per node:
///
/// * `none` — node is hidden along with its subtree.
/// * `disabled` — node is rendered behind an [IgnorePointer] and faded
///   to [TomAuthTreeView.disabledOpacity]; its children inherit the
///   parent's effective auth (i.e. cannot be widened by their own keys).
/// * `read` — node is rendered behind an [IgnorePointer] (content
///   visible, nothing in the row interactive) but children remain
///   individually evaluated.
/// * `full` — node is fully interactive and children are evaluated
///   normally.
///
/// The [IgnorePointer] wraps the node's **own row only**, never the
/// subtree — that is what lets a `full` child under a `read` parent stay
/// interactive. Contrast `TomAuthGuard` and `TomRadioGroup`, which have
/// one key for one subtree and so block all of it; and note that
/// `TomAuthGuard.blockPointerOnRead` has no counterpart here, because a
/// tree row whose taps still fired would be indistinguishable from a
/// `full` one.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Data model for a node inside a [TomAuthTreeView]. Each node carries
/// its own [tomId] resource key for per-node authorization lookup.
class TomAuthTreeNode {
  /// Resource key used to resolve this node's [TomAuthState]. Combined
  /// with the parent path via the active [TomScope] when the tree
  /// builds.
  final String tomId;

  /// Visual title for the node row.
  final Widget title;

  /// Optional leading widget (icon, avatar, …).
  final Widget? leading;

  /// Optional trailing widget (badge, action button, …).
  final Widget? trailing;

  /// Child nodes; empty when this node is a leaf.
  final List<TomAuthTreeNode> children;

  /// Whether the node should start expanded. Falls back to the tree's
  /// `initiallyExpanded` default when `null`.
  final bool? initiallyExpanded;

  /// Tap handler invoked when the node row is selected. Suppressed by
  /// the auth resolver in `read` / `disabled` states.
  final VoidCallback? onTap;

  TomAuthTreeNode({
    required this.tomId,
    required this.title,
    this.leading,
    this.trailing,
    this.children = const [],
    this.initiallyExpanded,
    this.onTap,
  });
}

/// Tree view that resolves authorization independently per node.
class TomAuthTreeView extends StatelessWidget {
  /// Top-level nodes for the tree.
  final List<TomAuthTreeNode> nodes;

  /// Optional parent path prefix. When `null`, the active [TomScope] is
  /// used to qualify each node's `tomId`.
  final String? parentPath;

  /// Indentation in logical pixels per nesting level. Defaults to `24`.
  final double indentation;

  /// Default expansion state for nodes that don't override
  /// [TomAuthTreeNode.initiallyExpanded]. Defaults to `true` so users
  /// see the full structure on first paint.
  final bool initiallyExpanded;

  /// Padding around the outer scroll view.
  final EdgeInsetsGeometry? padding;

  /// Whether the inner [ListView] should `shrinkWrap`. Defaults to
  /// `false` so the tree fills available height.
  final bool shrinkWrap;

  /// Optional scroll physics for the inner [ListView].
  final ScrollPhysics? physics;

  /// Opacity applied when a node's auth is `disabled`. Defaults to
  /// `0.4`.
  final double disabledOpacity;

  const TomAuthTreeView({
    super.key,
    required this.nodes,
    this.parentPath,
    this.indentation = 24,
    this.initiallyExpanded = true,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.disabledOpacity = 0.4,
  });

  String _qualifyPath(String tomId) {
    if (parentPath != null && parentPath!.isNotEmpty) {
      return '$parentPath.$tomId';
    }
    final scopePath = TomScope.current.getScopePath();
    return scopePath.isEmpty ? tomId : '$scopePath.$tomId';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: [
        for (final node in nodes)
          _AuthTreeNodeWidget(
            node: node,
            depth: 0,
            indentation: indentation,
            initiallyExpandedDefault: initiallyExpanded,
            qualifyPath: _qualifyPath,
            disabledOpacity: disabledOpacity,
            inheritedAuth: TomAuthState.full,
          ),
      ],
    );
  }
}

class _AuthTreeNodeWidget extends StatefulWidget {
  final TomAuthTreeNode node;
  final int depth;
  final double indentation;
  final bool initiallyExpandedDefault;
  final String Function(String tomId) qualifyPath;
  final double disabledOpacity;
  final TomAuthState inheritedAuth;

  const _AuthTreeNodeWidget({
    required this.node,
    required this.depth,
    required this.indentation,
    required this.initiallyExpandedDefault,
    required this.qualifyPath,
    required this.disabledOpacity,
    required this.inheritedAuth,
  });

  @override
  State<_AuthTreeNodeWidget> createState() => _AuthTreeNodeWidgetState();
}

class _AuthTreeNodeWidgetState extends State<_AuthTreeNodeWidget> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded =
        widget.node.initiallyExpanded ?? widget.initiallyExpandedDefault;
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final fullPath = widget.qualifyPath(node.tomId);
    final ownAuth = TomAuthorization.resolveAuth(fullPath);
    final effective = ownAuth.narrow(widget.inheritedAuth);

    if (effective == TomAuthState.none) return const SizedBox.shrink();

    final hasChildren = node.children.isNotEmpty;
    final indent = widget.depth * widget.indentation;
    final isInteractive = effective == TomAuthState.full;

    // Per the "Lookup rules per node" list in this library's doc comment: only
    // a `disabled` parent caps its subtree (children inherit the cap, and
    // cannot be widened by their own keys).
    // A `read`/`full` parent leaves descendants individually evaluated, so we
    // pass `full` down and let each child resolve on its own key. (`none`
    // already returned above, so the subtree never renders.)
    final inheritedForChildren = effective == TomAuthState.disabled
        ? TomAuthState.disabled
        : TomAuthState.full;

    final row = InkWell(
      onTap: isInteractive
          ? () {
              if (hasChildren) setState(() => _expanded = !_expanded);
              node.onTap?.call();
            }
          : null,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: indent),
        child: Row(
          children: [
            if (hasChildren)
              Icon(
                _expanded ? Icons.expand_more : Icons.chevron_right,
                size: 20,
              )
            else
              const SizedBox(width: 20),
            if (node.leading != null) ...[
              node.leading!,
              const SizedBox(width: 8),
            ],
            Expanded(child: node.title),
            if (node.trailing != null) node.trailing!,
          ],
        ),
      ),
    );

    // Nulling `InkWell.onTap` above suppresses only the row's *own* gesture.
    // `leading` and `trailing` take arbitrary widgets — a per-row action button
    // being the usual reason to use them — so making the node non-interactive
    // means wrapping the row, exactly as [TomAuthGuard] wraps its child at
    // these two states.
    //
    // It wraps the row and nothing else. The children are siblings of
    // `wrappedRow` in the Column below, outside the barrier, so each is still
    // judged on its own key; blocking the whole subtree here would re-impose
    // through the pointer layer the `read`-parent cap that
    // `inheritedForChildren` exists to avoid.
    Widget wrappedRow = row;
    if (effective == TomAuthState.disabled) {
      wrappedRow = Opacity(opacity: widget.disabledOpacity, child: wrappedRow);
    }
    if (!isInteractive) {
      wrappedRow = IgnorePointer(child: wrappedRow);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        wrappedRow,
        if (_expanded && hasChildren)
          for (final child in node.children)
            _AuthTreeNodeWidget(
              node: child,
              depth: widget.depth + 1,
              indentation: widget.indentation,
              initiallyExpandedDefault: widget.initiallyExpandedDefault,
              qualifyPath: widget.qualifyPath,
              disabledOpacity: widget.disabledOpacity,
              inheritedAuth: inheritedForChildren,
            ),
      ],
    );
  }
}
