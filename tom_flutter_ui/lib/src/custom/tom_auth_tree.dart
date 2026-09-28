/// Hierarchical tree with **per-node authorization**.
///
/// Every node carries its own resource key and resolves its
/// [TomAuthState] independently, so one tree can surface a different
/// shape per user role — which is what nav and permissions UIs need.
/// Contrast `TomTreeView`, whose authorization is widget-level: the
/// whole tree is hidden or disabled together. Pick this pair when the
/// grant varies *within* the tree, `TomTreeView` when it does not.
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
///
/// **Expanding and collapsing is independent of all four.** The chevron is a
/// control of its own, outside the barrier and outside the fade, so a
/// withheld section header can still be folded away. Activation is what
/// authorization governs here; navigating the structure a user is already
/// allowed to see is not, and a read-only tree stuck fully expanded is a
/// read-only tree nobody can use.
/// * `full` — node is fully interactive and children are evaluated
///   normally.
///
/// Paths compose along the branch. A node resolves
/// `<parentPath>.<ancestor ids…>.<own id>` — or the same under the ambient
/// [TomScope] when the tree is given no `parentPath` — so each branch has its
/// own namespace and an id need only be unique among its siblings. A flat
/// namespace would make `reports/view` and `invoices/view` one grant, which is
/// the distinction a permissions tree exists to draw.
///
/// The [IgnorePointer] wraps the node's **own row only**, never the
/// subtree — that is what lets a `full` child under a `read` parent stay
/// interactive. Contrast `TomAuthGuard` and `TomChoiceGroup`, which have
/// one key for one subtree and so block all of it; and note that
/// `TomAuthGuard.blockPointerOnRead` has no counterpart here, because a
/// tree row whose taps still fired would be indistinguishable from a
/// `full` one.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_scope_path.dart';

/// Data model for a node inside a [TomAuthTreeView]. Each node carries
/// its own [tomId] resource key for per-node authorization lookup.
class TomAuthTreeNode {
  /// Resource key segment for this node, unique **among its siblings**.
  ///
  /// A node's full path is its ancestors' ids joined to its own under the
  /// tree's `parentPath` (or the ambient [TomScope] when the tree has none),
  /// so a `view` under `reports` resolves `app.reports.view` and a `view`
  /// under `invoices` resolves `app.invoices.view`. The two are separate
  /// grants, which is the reason to reach for a tree rather than a list of
  /// guards: without composition the branches share one key and cannot be
  /// granted apart.
  final String tomId;

  /// Visual title for the node row.
  final Widget title;

  /// Optional leading widget (icon, avatar, …).
  ///
  /// Covered by the node's pointer block along with the rest of the row, so an
  /// interactive widget here is inert at `read` and `disabled` rather than
  /// merely faded.
  final Widget? leading;

  /// Optional trailing widget (badge, action button, …).
  ///
  /// Covered by the node's pointer block — see [leading]. An action button
  /// here is the usual reason to reach for the slot, and it must not fire on a
  /// row the user has been shown as unavailable.
  final Widget? trailing;

  /// Child nodes; empty when this node is a leaf.
  final List<TomAuthTreeNode> children;

  /// Whether the node should start expanded. Falls back to the tree's
  /// `initiallyExpanded` default when `null`.
  final bool? initiallyExpanded;

  /// Tap handler invoked when the node row is selected.
  ///
  /// Suppressed at `read` and `disabled` — as is everything else in the row,
  /// including [leading] and [trailing]. Nulling this handler alone would
  /// leave those two live, which is the one failure the block exists to
  /// prevent.
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

  /// Optional path prefix for the tree's **top-level** nodes. When `null` or
  /// empty, the active [TomScope] is used instead.
  ///
  /// Deeper nodes are qualified by their own ancestors, not by this — see
  /// [TomAuthTreeNode.tomId].
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

  /// Qualifies a **top-level** node's [tomId] under [parentPath] when the tree
  /// was given a non-empty one, and under the ambient scope otherwise.
  ///
  /// Each node hands its children a qualifier built from its own resolved
  /// path, so this one is only ever used at the root.
  String _qualifyPath(String tomId) {
    final parent = parentPath;
    if (parent != null && parent.isNotEmpty) {
      return TomScopePath.join(parent, tomId);
    }
    return TomScopePath.qualify(tomId);
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

  /// Qualifies this node's own [TomAuthTreeNode.tomId].
  ///
  /// The root's comes from the tree; every other node's is built by its parent
  /// from the path the parent itself resolved, which is what composes the
  /// branch. One field rather than a path plus a rule, so there is a single
  /// place the composition happens.
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

    // The expander is a control of its own, outside everything the auth
    // treatment applies to. Collapsing a section is navigation, not
    // activation: a user who may read a subtree but not act on its header
    // still has to be able to fold it away, and the header is exactly the row
    // most likely to be withheld.
    //
    // It is not faded at `disabled` either. Dimming says "unavailable", and
    // this control is available — a greyed thing that still works is the
    // failure the barrier below exists to prevent, run backwards.
    final expander = hasChildren
        ? InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Icon(
              _expanded ? Icons.expand_more : Icons.chevron_right,
              size: 20,
            ),
          )
        : const SizedBox(width: 20);

    final body = InkWell(
      onTap: isInteractive
          ? () {
              if (hasChildren) setState(() => _expanded = !_expanded);
              node.onTap?.call();
            }
          : null,
      child: Row(
        children: [
          if (node.leading != null) ...[
            node.leading!,
            const SizedBox(width: 8),
          ],
          Expanded(child: node.title),
          if (node.trailing != null) node.trailing!,
        ],
      ),
    );

    // Nulling `InkWell.onTap` above suppresses only the row's *own* gesture.
    // `leading` and `trailing` take arbitrary widgets — a per-row action button
    // being the usual reason to use them — so making the node non-interactive
    // means wrapping the body, exactly as [TomAuthGuard] wraps its child at
    // these two states.
    //
    // It wraps the body and nothing else. The expander is a sibling, so it
    // stays usable; and the children are siblings of `wrappedRow` in the
    // Column below, so each is still judged on its own key. Blocking the whole
    // subtree here would re-impose through the pointer layer the `read`-parent
    // cap that `inheritedForChildren` exists to avoid.
    Widget treated = body;
    if (effective == TomAuthState.disabled) {
      treated = Opacity(opacity: widget.disabledOpacity, child: treated);
    }
    if (!isInteractive) {
      treated = IgnorePointer(child: treated);
    }

    final wrappedRow = Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: Row(
        children: [
          expander,
          Expanded(child: treated),
        ],
      ),
    );

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
              // The child qualifies against *this* node's resolved path, so
              // ids compose down the branch.
              qualifyPath: (childId) => TomScopePath.join(fullPath, childId),
              disabledOpacity: widget.disabledOpacity,
              inheritedAuth: inheritedForChildren,
            ),
      ],
    );
  }
}
