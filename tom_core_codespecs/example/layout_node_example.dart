// CE-LO — the base/override two-layer layout model.
//
// The hardest idea in the package, and the one a class listing does not
// convey: a layout is a GENERATED tree plus a list of id-addressed deltas, and
// the deltas are meant to survive the next regeneration. Nothing merges them
// into the tree, because merging would put the author's adjustments where the
// generator will overwrite them.
//
// The consequence is the part worth running: a delta whose target the
// regenerated tree no longer has is REPORTED and KEPT, not dropped. Dropping
// it would silently discard the author's work at exactly the moment they most
// need to be told.
//
// Run with:
//   dart run --enable-asserts example/layout_node_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

void main() {
  requireAsserts();
  print('== CE-LO: layout base + overrides ==');

  // `base` is what the generator writes; it is never hand-edited.
  final layout = TomLayoutModel(
    layoutId: 'payment_form',
    base: TomLayoutContainerNode(
      nodeId: 'root',
      kind: TomLayoutContainerKind.column,
      children: [
        TomLayoutSlotNode(nodeId: 'amount', referencedId: 'amount'),
        TomLayoutContainerNode(
          nodeId: 'row1',
          kind: TomLayoutContainerKind.row,
          children: [TomLayoutSlotNode(nodeId: 'iban', referencedId: 'iban')],
        ),
      ],
    ),
    // `overrides` is what the author writes, addressed by node id.
    overrides: [
      TomLayoutOverrideDelta(
        op: TomLayoutDeltaOp.setSlotHint,
        targetNodeId: 'amount',
        properties: {'flex': 2},
      ),
    ],
  );

  print('  nodes: ${(layout.nodeIds.toList()..sort()).join(", ")}');
  assert(layout.nodeIds.length == 4);
  assert(layout.findNode('iban') is TomLayoutSlotNode);
  assert(layout.findNode('row1') is TomLayoutContainerNode);
  assert(layout.findNode('nothing') == null);

  // Every delta resolves against the current tree, so nothing to report.
  assert(layout.reconcileWarnings().isEmpty);
  print('  reconcile: clean');

  // Now a regeneration drops the field an author had already adjusted.
  final stale = TomLayoutOverrideDelta(
    op: TomLayoutDeltaOp.reparent,
    targetNodeId: 'removed_field',
    newParentNodeId: 'root',
  );
  layout.overrides.add(stale);

  final warnings = layout.reconcileWarnings();
  for (final warning in warnings) {
    print('  warning: $warning');
  }
  assert(warnings.length == 1);
  assert(warnings.single.contains('removed_field'));

  // The delta is still there. That is the whole design: the author is told,
  // and decides — the model does not decide for them by deleting it.
  assert(layout.overrides.contains(stale));
  print(
    '  the stale delta was reported and KEPT '
    '(${layout.overrides.length} overrides)',
  );

  // An insert is the one op whose target does not have to exist yet: the
  // delta creates it, so only the parent is checked.
  layout.overrides.add(
    TomLayoutOverrideDelta(
      op: TomLayoutDeltaOp.insertContainer,
      targetNodeId: 'new_row',
      newParentNodeId: 'root',
      position: 0,
    ),
  );
  assert(layout.reconcileWarnings().length == 1, 'insert adds no warning');
  print('  insertContainer checks only its parent, so still 1 warning');

  _kindDrift();
}

/// The drift a vanished id does not cover, and the reason the base is sealed.
///
/// An id that disappeared is conspicuous. An id a regeneration re-used for a
/// different KIND of node still resolves, so the delta goes on applying and
/// quietly means something else — a hint meant for a field landing on the row
/// that contains it. Telling the two kinds apart is what the sealed
/// `TomLayoutNode` base is for.
void _kindDrift() {
  print('  -- kind drift --');

  // The same tree, regenerated: `amount` is now a row rather than the field.
  final regenerated = TomLayoutModel(
    layoutId: 'payment_form',
    base: TomLayoutContainerNode(
      nodeId: 'root',
      children: [
        TomLayoutContainerNode(
          nodeId: 'amount',
          kind: TomLayoutContainerKind.row,
          children: [TomLayoutSlotNode(nodeId: 'amount_field')],
        ),
      ],
    ),
    // The author's delta is unchanged and still resolves — to the wrong thing.
    overrides: [
      TomLayoutOverrideDelta(
        op: TomLayoutDeltaOp.setSlotHint,
        targetNodeId: 'amount',
        properties: {'flex': 2},
      ),
    ],
  );

  assert(regenerated.nodeIds.contains('amount'), 'the id still resolves');
  final warnings = regenerated.reconcileWarnings();
  for (final warning in warnings) {
    print('  warning: $warning');
  }
  assert(warnings.length == 1);
  assert(warnings.single.contains('not a slot'));

  // A slot can never be a new parent, because only a container owns children.
  regenerated.overrides.add(
    TomLayoutOverrideDelta(
      op: TomLayoutDeltaOp.reparent,
      targetNodeId: 'root',
      newParentNodeId: 'amount_field',
    ),
  );
  final both = regenerated.reconcileWarnings();
  print('  warning: ${both.last}');
  assert(both.length == 2);
  assert(both.last.contains('cannot own children'));
}
