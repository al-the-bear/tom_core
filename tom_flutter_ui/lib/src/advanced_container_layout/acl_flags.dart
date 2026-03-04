/// Flags for component layout attributes in AclContainer.
///
/// These flags mirror the Java AWT constants used in AdvancedContainerLike.
class AclFlags {
  AclFlags._();

  /// Expand component horizontally to fill available space
  static const int expandX = 1;

  /// Expand component vertically to fill available space
  static const int expandY = 2;

  /// Internal flag: component is a gap/spacer element
  static const int gapElement = 4;

  /// Component background should follow parent container background
  static const int panelBackground = 8;

  /// Size is specified in character units rather than pixels
  static const int charDim = 16;

  /// Use X dimension from reference component
  static const int otherDimX = 32;

  /// Use Y dimension from reference component
  static const int otherDimY = 64;

  /// Use both dimensions from reference component
  static const int otherDim = otherDimX | otherDimY;

  /// Convenience: expand in both directions
  static const int expand = expandX | expandY;
}
