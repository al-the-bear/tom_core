/// The closed set of layout containers a CodeSpec may author
/// (`codespecs_mapping.md` §5.22).
///
/// The set is closed on purpose: a generated layout must be renderable by every
/// target platform, so a container kind exists here only when all targets can
/// express it. Adding a kind is a deliberate authored act on the catalogue, not
/// a per-spec escape hatch.
enum TomLayoutContainerKind {
  /// Horizontal sequence.
  row,

  /// Vertical sequence.
  column,

  /// Horizontal sequence that wraps onto further lines.
  wrap,

  /// Overlapping children painted back to front.
  stack,

  /// Proportional sequence driven by per-child flex factors.
  flex,

  /// Two-dimensional cell arrangement.
  grid,

  /// Insets around a single child.
  padding,

  /// Positions a single child within the available space.
  align,

  /// Constrains a single child to fixed dimensions.
  sizedBox,
}

/// The closed grammar of override deltas in the authored layer
/// (`codespecs_mapping.md` §5.22).
///
/// Every manual layout adjustment is expressed as one of these five operations
/// against a stable node id. Keeping the grammar closed is what makes the
/// authored layer *reconcilable*: each delta can be checked against a
/// regenerated base tree, which an opaque "hand-edited layout file" could not.
enum TomLayoutDeltaOp {
  /// Move an existing node under a different parent.
  reparent,

  /// Set a property on an existing container node.
  setContainerProp,

  /// Set a layout hint (flex, span, alignment) on an existing slot.
  setSlotHint,

  /// Add a container that the generated base does not contain.
  insertContainer,

  /// Drop a container the generated base contains (its children reparent to the
  /// removed container's parent).
  removeContainer,
}

/// A node in the generated base layout tree — either a [TomLayoutContainerNode]
/// or a [TomLayoutSlotNode].
///
/// Sealed so the two-layer reconcile can exhaustively distinguish containers
/// (which own children and can be inserted/removed) from slots (which reference
/// an element and can only be hinted).
sealed class TomLayoutNode {
  /// Stable identifier of this node, unique across the whole layout tree.
  ///
  /// Override deltas address nodes by this id, so it must survive regeneration
  /// of the base tree — that stability is what lets manual layout outlive model
  /// changes.
  String nodeId;

  /// Creates a layout node with the given stable [nodeId].
  TomLayoutNode({this.nodeId = ''});
}

/// A container node in the generated base layout tree.
class TomLayoutContainerNode extends TomLayoutNode {
  /// Which of the nine closed container kinds this node is.
  TomLayoutContainerKind kind;

  /// Container-level properties (spacing, alignment, column count, …), keyed by
  /// property name.
  Map<String, Object?> properties;

  /// Child nodes, in paint/flow order.
  List<TomLayoutNode> children;

  /// Creates a container node.
  TomLayoutContainerNode({
    super.nodeId,
    this.kind = TomLayoutContainerKind.column,
    Map<String, Object?>? properties,
    List<TomLayoutNode>? children,
  }) : properties = properties ?? <String, Object?>{},
       children = children ?? <TomLayoutNode>[];
}

/// A leaf node that *places* an element which is defined elsewhere.
///
/// The slot carries [referencedId] — the id of the field, action or component —
/// and never the element's definition. That is the semantics↔layout split of
/// `codespecs_mapping.md` §5.2: what an element *is* is authored once in the
/// semantic model; where it *sits* is authored here, so re-arranging a screen
/// cannot silently change a field's meaning, validation or binding.
class TomLayoutSlotNode extends TomLayoutNode {
  /// Id of the element (field, action, component) this slot places.
  String referencedId;

  /// Layout hints for the placed element (flex, span, alignment, …).
  Map<String, Object?> hints;

  /// Creates a slot node.
  TomLayoutSlotNode({
    super.nodeId,
    this.referencedId = '',
    Map<String, Object?>? hints,
  }) : hints = hints ?? <String, Object?>{};
}

/// One entry in the authored override layer — an id-addressed delta applied on
/// top of the generated base tree.
class TomLayoutOverrideDelta {
  /// Which of the five closed operations this delta performs.
  TomLayoutDeltaOp op;

  /// The node this delta addresses.
  ///
  /// For [TomLayoutDeltaOp.insertContainer] this is the id the *new* container
  /// will carry, so it is deliberately not required to exist in the base tree.
  String targetNodeId;

  /// New parent for [TomLayoutDeltaOp.reparent] and
  /// [TomLayoutDeltaOp.insertContainer]; `null` for the other operations.
  String? newParentNodeId;

  /// Insert position within the new parent's children, or `null` to append.
  int? position;

  /// Property or hint values for [TomLayoutDeltaOp.setContainerProp] and
  /// [TomLayoutDeltaOp.setSlotHint].
  Map<String, Object?> properties;

  /// Creates an override delta.
  TomLayoutOverrideDelta({
    this.op = TomLayoutDeltaOp.setSlotHint,
    this.targetNodeId = '',
    this.newParentNodeId,
    this.position,
    Map<String, Object?>? properties,
  }) : properties = properties ?? <String, Object?>{};
}

/// The two-layer layout holder a CodeSpec's `@CsLayout` (CE-LO) is built on.
///
/// **Why this is a gap (`codespecs_mapping.md` §5.2/§5.12/§5.22, verdict
/// *gap*).** The `tom_flutter_ui` substrate (`AclComponent` in
/// `advanced_container_layout/`) is a *rendering leaf*: it holds a live `Widget
/// child` and its own alignment flags, so it describes one already-built widget
/// tree. CodeSpecs needs the layer above that — an **authorable, serializable
/// layout description** in which (a) placement references elements by stable id
/// instead of embedding them, and (b) a generated [base] tree and an authored
/// [overrides] layer are kept *separate* so regeneration does not destroy
/// manual layout work. `tom_flutter_ui` has no such base/override layering and
/// no id-addressed delta grammar, so the model lands here as a concrete
/// `tom_core`-family class — never an abstract `Cs*` base (the framework
/// carries annotations only, `codespecs_mapping.md` §1.1).
///
/// A CodeSpec `@CsLayout` class *is a* [TomLayoutModel]. CE-LO is a *client*
/// part (`codespecs_mapping.md` §4.2), so the layout lives in the client
/// project of the three-project output trio.
class TomLayoutModel {
  /// Stable identifier of this layout (typically the form or screen it lays
  /// out).
  String layoutId;

  /// The generated layer — regenerated wholesale from the semantic model. Never
  /// hand-edited; manual work goes into [overrides].
  TomLayoutContainerNode? base;

  /// The authored layer — id-addressed deltas applied on top of [base].
  List<TomLayoutOverrideDelta> overrides;

  /// Creates a two-layer layout model.
  TomLayoutModel({
    this.layoutId = '',
    this.base,
    List<TomLayoutOverrideDelta>? overrides,
  }) : overrides = overrides ?? <TomLayoutOverrideDelta>[];

  /// Every node id in the generated [base] tree.
  Set<String> get nodeIds {
    final ids = <String>{};
    void walk(TomLayoutNode node) {
      ids.add(node.nodeId);
      if (node is TomLayoutContainerNode) {
        node.children.forEach(walk);
      }
    }

    final root = base;
    if (root != null) walk(root);
    return ids;
  }

  /// The node with [nodeId] in the generated [base] tree, or `null`.
  TomLayoutNode? findNode(String nodeId) {
    TomLayoutNode? search(TomLayoutNode node) {
      if (node.nodeId == nodeId) return node;
      if (node is TomLayoutContainerNode) {
        for (final child in node.children) {
          final hit = search(child);
          if (hit != null) return hit;
        }
      }
      return null;
    }

    final root = base;
    return root == null ? null : search(root);
  }

  /// Every delta that does not resolve against the current [base] tree.
  ///
  /// Three things can be wrong with a delta after the base is regenerated, and
  /// all three are reported rather than silently applied or silently dropped:
  ///
  /// - **an id that resolves to nothing** — the node the delta addressed is
  ///   gone from the regenerated tree;
  /// - **an id that resolves to the wrong kind of node** — the id survived but
  ///   now names a container where the delta needs a slot, or the other way
  ///   round;
  /// - **a delta that names no new parent** where its operation requires one.
  ///
  /// The second is what the closed delta grammar exists for. An id that
  /// vanished is conspicuous; an id a regeneration re-used for a different kind
  /// of node still resolves, so without this check the delta goes on applying
  /// and quietly means something other than what was authored.
  ///
  /// Each operation requires the kind its own documentation states:
  /// [TomLayoutDeltaOp.setContainerProp] and [TomLayoutDeltaOp.removeContainer]
  /// address a container, [TomLayoutDeltaOp.setSlotHint] a slot, and
  /// [TomLayoutDeltaOp.reparent] moves a node of either kind. A **new parent is
  /// always a container**, because only a container owns children.
  ///
  /// [TomLayoutDeltaOp.insertContainer] is the one operation whose target is
  /// not required to exist — the delta creates it. It is required not to exist
  /// *already*: a [TomLayoutNode.nodeId] is unique across the tree, so an
  /// insert whose id the regenerated base has since taken is the same drift
  /// seen from the other side.
  ///
  /// Nothing is dropped. The list is advice to whoever regenerated the base;
  /// the deltas stay exactly as authored, because the author is the one who can
  /// decide what a warning means.
  List<String> reconcileWarnings() {
    final warnings = <String>[];

    for (final delta in overrides) {
      final op = delta.op;

      // The target. An insert creates its own, so for that one operation the
      // question is inverted: the id must be free rather than taken.
      if (op == TomLayoutDeltaOp.insertContainer) {
        if (findNode(delta.targetNodeId) != null) {
          warnings.add(
            'layout "$layoutId": insertContainer delta would create node '
            '"${delta.targetNodeId}", which the base already contains',
          );
        }
      } else {
        final target = findNode(delta.targetNodeId);
        if (target == null) {
          warnings.add(_unknownNode(op, delta.targetNodeId));
        } else {
          final required = _targetKind(op);
          if (required != null && _kindOf(target) != required) {
            warnings.add(
              'layout "$layoutId": ${op.name} delta addresses '
              '${_kindOf(target)} "${delta.targetNodeId}", which is not a '
              '$required',
            );
          }
        }
      }

      // The new parent, for the two operations that move or add a node.
      if (op == TomLayoutDeltaOp.reparent ||
          op == TomLayoutDeltaOp.insertContainer) {
        final parentId = delta.newParentNodeId;
        if (parentId == null) {
          warnings.add(
            'layout "$layoutId": ${op.name} delta names no new parent',
          );
          continue;
        }
        final parent = findNode(parentId);
        if (parent == null) {
          warnings.add(_unknownNode(op, parentId));
        } else if (parent is! TomLayoutContainerNode) {
          warnings.add(
            'layout "$layoutId": ${op.name} delta names ${_kindOf(parent)} '
            '"$parentId" as the new parent, which cannot own children',
          );
        }
      }
    }

    return warnings;
  }

  /// The wording every unresolvable id is reported with.
  String _unknownNode(TomLayoutDeltaOp op, String nodeId) =>
      'layout "$layoutId": ${op.name} delta references unknown node "$nodeId"';

  /// The node kind [op] must address, or `null` when either kind is allowed.
  ///
  /// `reparent` is the `null`: a container and a slot can both be moved.
  static String? _targetKind(TomLayoutDeltaOp op) => switch (op) {
    TomLayoutDeltaOp.setContainerProp => _container,
    TomLayoutDeltaOp.removeContainer => _container,
    TomLayoutDeltaOp.setSlotHint => _slot,
    TomLayoutDeltaOp.reparent => null,
    TomLayoutDeltaOp.insertContainer => null,
  };

  /// What [node] is, in the words the warnings use.
  ///
  /// Exhaustive over the sealed [TomLayoutNode] hierarchy, which is what the
  /// base is sealed for.
  static String _kindOf(TomLayoutNode node) => switch (node) {
    TomLayoutContainerNode() => _container,
    TomLayoutSlotNode() => _slot,
  };

  static const String _container = 'container';
  static const String _slot = 'slot';
}
