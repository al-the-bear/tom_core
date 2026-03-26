import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_base/tom_family_base.dart';

/// Tom custom TreeView widget.
///
/// A simple tree view that renders a hierarchy of nodes with expand/collapse.
/// Adds ID, group, authorization, and resource resolution.
///
/// Each [TomTreeNode] in [nodes] can have children, forming a recursive tree.
class TomTreeView extends TomTreeBase {
  final List<TomTreeNode> nodes;
  final EdgeInsetsGeometry? padding;
  final double indentation;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const TomTreeView({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.nodes,
    this.padding,
    this.indentation = 24.0,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedIndentation =
        resolveDoubleOrNull(context, 'indentation') ?? indentation;

    return ListView(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: [
        for (final node in nodes) _TomTreeNodeWidget(node: node, depth: 0, indentation: resolvedIndentation),
      ],
    );
  }
}

/// Data model for a tree node used by [TomTreeView].
class TomTreeNode {
  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final List<TomTreeNode> children;
  final bool initiallyExpanded;
  final VoidCallback? onTap;

  const TomTreeNode({
    required this.title,
    this.leading,
    this.trailing,
    this.children = const [],
    this.initiallyExpanded = false,
    this.onTap,
  });
}

class _TomTreeNodeWidget extends StatefulWidget {
  final TomTreeNode node;
  final int depth;
  final double indentation;

  const _TomTreeNodeWidget({
    required this.node,
    required this.depth,
    required this.indentation,
  });

  @override
  State<_TomTreeNodeWidget> createState() => _TomTreeNodeWidgetState();
}

class _TomTreeNodeWidgetState extends State<_TomTreeNodeWidget> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.node.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final indent = widget.depth * widget.indentation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            if (hasChildren) {
              setState(() => _expanded = !_expanded);
            }
            node.onTap?.call();
          },
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
        ),
        if (_expanded && hasChildren)
          for (final child in node.children)
            _TomTreeNodeWidget(
              node: child,
              depth: widget.depth + 1,
              indentation: widget.indentation,
            ),
      ],
    );
  }
}

// =============================================================================
// Section II: Additional Tree Widgets
// =============================================================================

/// Tom wrapper for [TreeSliver].
///
/// High-performance sliver-based tree with lazy loading. Auth per tree node;
/// modern tree for large datasets.
class TomTreeSliver<T> extends TomTreeBase {
  final List<TreeSliverNode<T>> tree;
  final TreeSliverNodeBuilder treeNodeBuilder;
  final TreeSliverRowExtentBuilder treeRowExtentBuilder;
  final TreeSliverController? controller;
  final TreeSliverNodeCallback? onNodeToggle;
  final AnimationStyle? toggleAnimationStyle;
  final TreeSliverIndentationType indentation;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;

  const TomTreeSliver({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.tree,
    this.treeNodeBuilder = TreeSliver.defaultTreeNodeBuilder,
    this.treeRowExtentBuilder = TreeSliver.defaultTreeRowExtentBuilder,
    this.controller,
    this.onNodeToggle,
    this.toggleAnimationStyle,
    this.indentation = TreeSliverIndentationType.standard,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  });

  @override
  Widget buildContent(BuildContext context) {
    return TreeSliver<T>(
      tree: tree,
      treeNodeBuilder: treeNodeBuilder,
      treeRowExtentBuilder: treeRowExtentBuilder,
      controller: controller,
      onNodeToggle: onNodeToggle,
      toggleAnimationStyle: toggleAnimationStyle,
      indentation: indentation,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
      addSemanticIndexes: addSemanticIndexes,
    );
  }
}
