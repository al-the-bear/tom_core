import 'acl_container.dart';

/// A responsive layout variant that replaces the default row tree when the
/// container's available width drops below [atWidth].
class AclVariant {
  final String name;
  final double atWidth;
  final List<AclRow> rows;

  const AclVariant({
    required this.name,
    required this.atWidth,
    required this.rows,
  });
}

/// A row breakpoint that splits a row after [splitAfter] components when the
/// container's available width drops below [atWidth].
class AclRowBreakpoint {
  final double atWidth;

  /// 1-based component index after which to insert the row break.
  final int splitAfter;

  /// Vertical gap before the newly created split row.
  final double splitRowDist;

  const AclRowBreakpoint({
    required this.atWidth,
    required this.splitAfter,
    this.splitRowDist = 0,
  });
}
