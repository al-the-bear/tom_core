/// Layout attribute flags for the components inside an `AclContainer`.
///
/// The flags are composable bits carried in `AclComponent.flags`. Their values
/// mirror the bit positions of the Java AWT constants used by
/// `AdvancedContainerLike`, which is why the assigned values are sparse rather
/// than consecutive — bits 8 and 16 are unassigned here.
///
/// Every constant in this class is part of the **public** component model, in
/// both directions. Callers set them through `AclBuilder.setAttr` (or the
/// `expandX()` / `expandY()` / `expand()` shortcuts, or `sameWidthAs` /
/// `sameHeightAs` / `sameSize`), and read them back through the named getters
/// on `AclComponent`: `expandX`, `expandY`, `isGap`, `useOtherDimX`,
/// `useOtherDimY`. A bit the engine never reads does not belong here: a flag
/// a caller can set and the layout ignores is a promise the container does not
/// keep, and it reads as a supported feature in the reference table.
///
/// `test/advanced_container_layout/acl_flags_contract_test.dart` holds that
/// line: it fails if a flag stops being read, stops being documented, or is
/// documented with the wrong bit.
class AclFlags {
  AclFlags._();

  /// Expand the component horizontally to fill available space.
  ///
  /// Read back as `AclComponent.expandX`. This claims an *exclusive* right to
  /// the row's surplus width; see "Expand Flags" (§13) in
  /// `doc/acl_design_specification.md` for why that differs from merely growing.
  static const int expandX = 1;

  /// Expand the component vertically to fill available space.
  ///
  /// Read back as `AclComponent.expandY`.
  static const int expandY = 2;

  /// Marks the component as an elastic gap slot rather than as content.
  ///
  /// Read back as `AclComponent.isGap`. A component carrying this bit is **not
  /// rendered**: the container skips its `child` in both the measuring and the
  /// building pass and puts a `Spacer` (or a fixed `SizedBox`) in its place,
  /// sized from `AclComponent.gapWeight` relative to the other gap slots in the
  /// same row. That is why `AclBuilder.gap()` passes a `SizedBox.shrink()` as
  /// the child — it is a placeholder that is never built.
  ///
  /// Prefer `AclBuilder.gap()` over setting this bit through `setAttr`. The
  /// builder sets the weight and the placeholder together and then stops
  /// targeting the slot, so a later per-component call cannot land on it.
  /// Setting the bit by hand on an appended component silently discards that
  /// component's widget.
  static const int gapElement = 4;

  /// Take the X dimension from the component named by
  /// `AclComponent.referenceKey`.
  ///
  /// Read back as `AclComponent.useOtherDimX`; set through
  /// `AclBuilder.sameWidthAs`.
  static const int otherDimX = 32;

  /// Take the Y dimension from the component named by
  /// `AclComponent.referenceKey`.
  ///
  /// Read back as `AclComponent.useOtherDimY`; set through
  /// `AclBuilder.sameHeightAs`.
  static const int otherDimY = 64;

  /// Convenience: take both dimensions from the reference component.
  ///
  /// Set through `AclBuilder.sameSize`.
  static const int otherDim = otherDimX | otherDimY;

  /// Convenience: expand in both directions.
  static const int expand = expandX | expandY;
}
