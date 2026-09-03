import 'package:flutter/widgets.dart';

import 'acl_container.dart';
import 'row_alignment.dart';

/// The container kinds that flow a **flat** ordered child list into rows,
/// rather than having the rows authored directly.
///
/// The ACL row list is already a *column* of *rows*, so `row` and `column`
/// need no widget of their own — an [AclRow] is a row and an
/// [AclContainer]'s row list is a column. `wrap` and `grid` are the two
/// kinds that are **not** expressible that way, because the caller supplies
/// one undivided child sequence and the container decides where the row
/// breaks fall.
///
/// Both kinds are realised by *generating* [AclRow]s and handing them to the
/// ordinary [AclContainer] engine — they add a row-assignment rule, not a
/// second layout engine. Everything downstream (id addressing, alignment
/// anchors, gap rows, responsive variants, the hide-unauthorized pass) keeps
/// working unchanged.
enum AclFlowKind {
  /// Fill a row until the next child no longer fits, then break.
  wrap,

  /// Break every `columns` children, giving each an equal-width cell.
  grid,
}

/// Width [aclWrapRows] attributes to a component that declares no size.
///
/// The flow pass runs *before* layout, so it cannot measure a child's natural
/// width the way [AclContainer]'s pre-calculation pass can. Components that
/// declare neither a preferred nor a minimum width are therefore assumed to
/// be this wide when deciding where a row breaks.
const double kAclDefaultFlowItemWidth = 150.0;

/// The width [aclWrapRows] uses when deciding whether [comp] still fits.
///
/// Mirrors the engine's own resolution order (preferred → minimum → natural),
/// with [defaultItemWidth] standing in for the natural size that is not
/// measurable this early.
double aclFlowItemWidth(AclComponent comp, double defaultItemWidth) {
  final preferred = comp.preferredSize?.width;
  if (preferred != null && preferred > 0) return preferred;
  final minimum = comp.minimumSize?.width;
  if (minimum != null && minimum > 0) return minimum;
  return defaultItemWidth;
}

/// Flows [components] into rows, breaking whenever the next component would
/// overflow [availableWidth].
///
/// A component wider than the whole line still gets a row of its own rather
/// than being dropped — a row always receives at least one component.
///
/// [gutterWidth] separates components within a row and [runSpacing] separates
/// the generated rows. Generated rows are addressable as `r<n>`, or as
/// `<prefix>.r<n>` when [rowIdPrefix] is given.
///
/// A flowed row has no author-written id to carry, so its position in the
/// generated sequence is the only handle anything outside this function — a
/// stored layout override, a test, a resource lookup — can use to name one.
/// Pass no prefix when the rows go to an [AclContainer]: the container
/// composes the path from its own `aclId` (see `idScope`), so a prefix here
/// would duplicate that segment.
List<AclRow> aclWrapRows(
  List<AclComponent> components, {
  required double availableWidth,
  double gutterWidth = 8.0,
  double runSpacing = 8.0,
  double defaultItemWidth = kAclDefaultFlowItemWidth,
  RowAlignment alignment = RowAlignment.left,
  String? rowIdPrefix,
}) {
  if (components.isEmpty) return const [];

  final rows = <AclRow>[];
  var current = <AclComponent>[];
  var usedWidth = 0.0;

  void flush() {
    if (current.isEmpty) return;
    rows.add(
      _flowRow(
        current,
        index: rows.length,
        runSpacing: runSpacing,
        alignment: alignment,
        rowIdPrefix: rowIdPrefix,
      ),
    );
    current = <AclComponent>[];
    usedWidth = 0.0;
  }

  for (final comp in components) {
    final width = aclFlowItemWidth(comp, defaultItemWidth);
    var gap = current.isEmpty ? 0.0 : gutterWidth;
    if (current.isNotEmpty && usedWidth + gap + width > availableWidth) {
      flush();
      gap = 0.0;
    }
    current.add(comp.copyWith(gapBefore: gap, gapBeforeIsDefault: false));
    usedWidth += gap + width;
  }
  flush();

  return rows;
}

/// Flows [components] into rows of [columns] equal-width cells.
///
/// Unlike [aclWrapRows] the break positions do not depend on measurement —
/// every row holds exactly [columns] components (the last may hold fewer).
/// The row assignment is therefore reproducible from the declaration alone,
/// which is what a design that states a column count per breakpoint needs and
/// a measurement-driven wrap cannot promise.
///
/// When [availableWidth] is known each component is given a cell width of
/// `(availableWidth - gutterWidth * (columns - 1)) / columns`; its height
/// preference is left alone (`0` means "natural height" to the engine). When
/// it is null the components keep their declared sizes and only the row
/// assignment applies.
List<AclRow> aclGridRows(
  List<AclComponent> components, {
  required int columns,
  double? availableWidth,
  double gutterWidth = 8.0,
  double runSpacing = 8.0,
  RowAlignment alignment = RowAlignment.left,
  String? rowIdPrefix,
}) {
  if (columns < 1) {
    throw ArgumentError.value(columns, 'columns', 'must be at least 1');
  }
  if (components.isEmpty) return const [];

  final cellWidth = availableWidth == null
      ? null
      : ((availableWidth - gutterWidth * (columns - 1)) / columns).clamp(
          0.0,
          double.infinity,
        );

  final rows = <AclRow>[];
  for (var start = 0; start < components.length; start += columns) {
    final end = (start + columns).clamp(0, components.length);
    final cells = <AclComponent>[];
    for (var i = start; i < end; i++) {
      final comp = components[i];
      cells.add(
        comp.copyWith(
          gapBefore: i == start ? 0.0 : gutterWidth,
          gapBeforeIsDefault: false,
          preferredSize: cellWidth == null
              ? null
              : Size(cellWidth, comp.preferredSize?.height ?? 0),
        ),
      );
    }
    rows.add(
      _flowRow(
        cells,
        index: rows.length,
        runSpacing: runSpacing,
        alignment: alignment,
        rowIdPrefix: rowIdPrefix,
      ),
    );
  }
  return rows;
}

AclRow _flowRow(
  List<AclComponent> components, {
  required int index,
  required double runSpacing,
  required RowAlignment alignment,
  required String? rowIdPrefix,
}) {
  return AclRow(
    components: List.unmodifiable(components),
    alignment: alignment,
    gapBefore: index == 0 ? 0.0 : runSpacing,
    // An unqualified `r<n>`: an AclRow.id is relative everywhere else in ACL,
    // and the container composes the path. A caller using these functions
    // standalone can pass a prefix to get fully-qualified ids instead.
    id: rowIdPrefix == null ? 'r$index' : '$rowIdPrefix.r$index',
  );
}

/// A widget whose rows are **generated** from a flat child list by an
/// [AclFlowKind] rule, then rendered through a composed [AclContainer].
///
/// This is the substrate for both `wrap` and `grid` container kinds. It
/// measures the available width with a [LayoutBuilder], asks [aclWrapRows] /
/// [aclGridRows] for the row assignment, and renders the result through the
/// ordinary [AclContainer] — so everything the engine applies per row and per
/// component keeps working on a flowed layout.
///
/// It does **not** extend [AclContainer], and forwards only the eight
/// arguments declared below as passthroughs. In particular it forwards no
/// `variants`, so no [AclVariant] can replace the generated rows: a flow
/// container re-runs its rule at every width, and [columnsBpOverrides] is the
/// responsive knob that replaces a variant per column count.
class AclFlowContainer extends StatelessWidget {
  /// Which row-assignment rule applies.
  final AclFlowKind kind;

  /// The undivided, ordered child sequence to flow.
  final List<AclComponent> components;

  /// Cells per row for [AclFlowKind.grid]; ignored by [AclFlowKind.wrap].
  final int columns;

  /// `(minWidth, columns)` overrides raising [columns] above certain widths —
  /// a per-breakpoint column count.
  final List<(double, int)> columnsBpOverrides;

  /// Horizontal space between components in a generated row.
  final double gutterWidth;

  /// Vertical space between generated rows.
  final double runSpacing;

  /// Assumed width for unsized components when wrapping.
  final double defaultItemWidth;

  /// Horizontal alignment applied to every generated row.
  final RowAlignment alignment;

  // ── AclContainer passthroughs ─────────────────────────────────────────────

  final String? aclId;
  final bool idScope;
  final String? aclGroup;
  final String? parentIdPath;
  final EdgeInsetsGeometry padding;
  final AclBorderStyle borderStyle;
  final Color? backgroundColor;
  final bool scrollableY;

  const AclFlowContainer({
    super.key,
    required this.kind,
    required this.components,
    this.columns = 1,
    this.columnsBpOverrides = const [],
    this.gutterWidth = 8.0,
    this.runSpacing = 8.0,
    this.defaultItemWidth = kAclDefaultFlowItemWidth,
    this.alignment = RowAlignment.left,
    this.aclId,
    this.idScope = false,
    this.aclGroup,
    this.parentIdPath,
    this.padding = EdgeInsets.zero,
    this.borderStyle = const AclBorderStyle.none(),
    this.backgroundColor,
    this.scrollableY = false,
  });

  /// Returns the rows this container would generate at [availableWidth].
  ///
  /// Exposed so the row assignment can be asserted without pumping a widget,
  /// and so a caller that already owns the width can pre-compute it.
  List<AclRow> buildRows(double availableWidth) {
    switch (kind) {
      case AclFlowKind.wrap:
        return aclWrapRows(
          components,
          availableWidth: availableWidth,
          gutterWidth: gutterWidth,
          runSpacing: runSpacing,
          defaultItemWidth: defaultItemWidth,
          alignment: alignment,
        );
      case AclFlowKind.grid:
        return aclGridRows(
          components,
          columns: aclResolveBreakpointed(
            columns,
            columnsBpOverrides,
            availableWidth,
          ),
          availableWidth: availableWidth,
          gutterWidth: gutterWidth,
          runSpacing: runSpacing,
          alignment: alignment,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The flow rule needs a finite line length. An unbounded width means
        // "never break", which the largest finite double expresses without a
        // special case in the flow functions.
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth - _horizontalPadding(context)
            : double.maxFinite;
        return AclContainer(
          rows: buildRows(width),
          padding: padding,
          borderStyle: borderStyle,
          backgroundColor: backgroundColor,
          scrollableY: scrollableY,
          aclId: aclId,
          idScope: idScope,
          aclGroup: aclGroup,
          parentIdPath: parentIdPath,
        );
      },
    );
  }

  /// Padding is applied by the inner [AclContainer], so it is not available
  /// to the children — the flow rule must break against the *content* width.
  double _horizontalPadding(BuildContext context) {
    final resolved = padding.resolve(Directionality.maybeOf(context));
    return resolved.left + resolved.right;
  }
}
