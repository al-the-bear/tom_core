import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../resource_auth/tom_auth_state.dart';
import '../../resource_auth/tom_id_prefix.dart';
import '../../theme/tom_theme.dart';
import '../../widget_base/tom_family_base.dart';
import '../../widget_base/tom_node_base.dart';

/// Tom wrapper for [DataTable].
///
/// Adds ID, group, authorization, and resource resolution to the standard
/// Flutter [DataTable]. Exposes the full underlying API.
class TomDataTable extends TomTableBase {
  final List<DataColumn> columns;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueSetter<bool?>? onSelectAll;
  final Decoration? decoration;
  final MaterialStateProperty<Color?>? dataRowColor;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final TextStyle? dataTextStyle;
  final MaterialStateProperty<Color?>? headingRowColor;
  final double? headingRowHeight;
  final TextStyle? headingTextStyle;
  final double? horizontalMargin;
  final double? columnSpacing;
  final bool showCheckboxColumn;
  final bool showBottomBorder;
  final double? dividerThickness;
  final double? checkboxHorizontalMargin;
  final TableBorder? border;
  final Clip clipBehavior;
  final List<DataRow> rows;

  const TomDataTable({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.columns,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSelectAll,
    this.decoration,
    this.dataRowColor,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.dataTextStyle,
    this.headingRowColor,
    this.headingRowHeight,
    this.headingTextStyle,
    this.horizontalMargin,
    this.columnSpacing,
    this.showCheckboxColumn = true,
    this.showBottomBorder = false,
    this.dividerThickness,
    this.checkboxHorizontalMargin,
    this.border,
    this.clipBehavior = Clip.none,
    required this.rows,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedDataRowMinHeight =
        dataRowMinHeight ?? resolveDoubleOrNull(context, 'dataRowMinHeight');
    final resolvedDataRowMaxHeight =
        dataRowMaxHeight ?? resolveDoubleOrNull(context, 'dataRowMaxHeight');
    final resolvedHeadingRowHeight =
        headingRowHeight ?? resolveDoubleOrNull(context, 'headingRowHeight');
    final resolvedHorizontalMargin =
        horizontalMargin ?? resolveDoubleOrNull(context, 'horizontalMargin');
    final resolvedColumnSpacing =
        columnSpacing ?? resolveDoubleOrNull(context, 'columnSpacing');
    final resolvedDividerThickness =
        dividerThickness ?? resolveDoubleOrNull(context, 'dividerThickness');
    final resolvedCheckboxHorizontalMargin =
        checkboxHorizontalMargin ?? resolveDoubleOrNull(context, 'checkboxHorizontalMargin');

    return DataTable(
      columns: columns,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      onSelectAll: onSelectAll,
      decoration: decoration,
      dataRowColor: dataRowColor,
      dataRowMinHeight: resolvedDataRowMinHeight,
      dataRowMaxHeight: resolvedDataRowMaxHeight,
      dataTextStyle: dataTextStyle,
      headingRowColor: headingRowColor,
      headingRowHeight: resolvedHeadingRowHeight,
      headingTextStyle: headingTextStyle,
      horizontalMargin: resolvedHorizontalMargin,
      columnSpacing: resolvedColumnSpacing,
      showCheckboxColumn: showCheckboxColumn,
      showBottomBorder: showBottomBorder,
      dividerThickness: resolvedDividerThickness,
      checkboxHorizontalMargin: resolvedCheckboxHorizontalMargin,
      border: border,
      clipBehavior: clipBehavior,
      rows: rows,
    );
  }
}

/// Tom wrapper for [PaginatedDataTable].
///
/// Adds ID, group, authorization, and resource resolution.
class TomPaginatedDataTable extends TomTableBase {
  final Widget? header;
  final List<Widget>? actions;
  final List<DataColumn> columns;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueSetter<bool?>? onSelectAll;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final TextStyle? dataTextStyle;
  final double headingRowHeight;
  final TextStyle? headingTextStyle;
  final double horizontalMargin;
  final double columnSpacing;
  final bool showCheckboxColumn;
  final bool showFirstLastButtons;
  final int? initialFirstRowIndex;
  final ValueChanged<int>? onPageChanged;
  final int rowsPerPage;
  final List<int> availableRowsPerPage;
  final ValueChanged<int?>? onRowsPerPageChanged;
  final DragStartBehavior dragStartBehavior;
  final double? arrowHeadColor;
  final double? checkboxHorizontalMargin;
  final MaterialStateProperty<Color?>? headingRowColor;
  final bool showEmptyRows;
  final DataTableSource source;

  const TomPaginatedDataTable({
    super.key,
    super.tomId,
    super.tomGroup,
    this.header,
    this.actions,
    required this.columns,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSelectAll,
    this.dataRowMinHeight = kMinInteractiveDimension,
    this.dataRowMaxHeight = kMinInteractiveDimension,
    this.dataTextStyle,
    this.headingRowHeight = 56.0,
    this.headingTextStyle,
    this.horizontalMargin = 24.0,
    this.columnSpacing = 56.0,
    this.showCheckboxColumn = true,
    this.showFirstLastButtons = false,
    this.initialFirstRowIndex = 0,
    this.onPageChanged,
    this.rowsPerPage = PaginatedDataTable.defaultRowsPerPage,
    this.availableRowsPerPage = const [
      PaginatedDataTable.defaultRowsPerPage,
      PaginatedDataTable.defaultRowsPerPage * 2,
      PaginatedDataTable.defaultRowsPerPage * 5,
      PaginatedDataTable.defaultRowsPerPage * 10,
    ],
    this.onRowsPerPageChanged,
    this.dragStartBehavior = DragStartBehavior.start,
    this.arrowHeadColor,
    this.checkboxHorizontalMargin,
    this.headingRowColor,
    this.showEmptyRows = false,
    required this.source,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedDataRowMinHeight =
        resolveDoubleOrNull(context, 'dataRowMinHeight') ?? dataRowMinHeight;
    final resolvedDataRowMaxHeight =
        resolveDoubleOrNull(context, 'dataRowMaxHeight') ?? dataRowMaxHeight;
    final resolvedHeadingRowHeight =
        resolveDoubleOrNull(context, 'headingRowHeight') ?? headingRowHeight;
    final resolvedHorizontalMargin =
        resolveDoubleOrNull(context, 'horizontalMargin') ?? horizontalMargin;
    final resolvedColumnSpacing =
        resolveDoubleOrNull(context, 'columnSpacing') ?? columnSpacing;
    final resolvedCheckboxHorizontalMargin =
        checkboxHorizontalMargin ?? resolveDoubleOrNull(context, 'checkboxHorizontalMargin');

    return PaginatedDataTable(
      header: header,
      actions: actions,
      columns: columns,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      onSelectAll: onSelectAll,
      dataRowMinHeight: resolvedDataRowMinHeight,
      dataRowMaxHeight: resolvedDataRowMaxHeight,
      headingRowHeight: resolvedHeadingRowHeight,
      horizontalMargin: resolvedHorizontalMargin,
      columnSpacing: resolvedColumnSpacing,
      showCheckboxColumn: showCheckboxColumn,
      showFirstLastButtons: showFirstLastButtons,
      initialFirstRowIndex: initialFirstRowIndex,
      onPageChanged: onPageChanged,
      rowsPerPage: rowsPerPage,
      availableRowsPerPage: availableRowsPerPage,
      onRowsPerPageChanged: onRowsPerPageChanged,
      dragStartBehavior: dragStartBehavior,
      checkboxHorizontalMargin: resolvedCheckboxHorizontalMargin,
      showEmptyRows: showEmptyRows,
      source: source,
    );
  }
}

/// Tom wrapper for [Table].
///
/// Adds ID, group, authorization, and resource resolution.
class TomTable extends TomTableBase {
  final List<TableRow> children;
  final Map<int, TableColumnWidth>? columnWidths;
  final TableColumnWidth defaultColumnWidth;
  final TextDirection? textDirection;
  final TableBorder? border;
  final TableCellVerticalAlignment defaultVerticalAlignment;
  final TextBaseline? textBaseline;

  const TomTable({
    super.key,
    super.tomId,
    super.tomGroup,
    this.children = const [],
    this.columnWidths,
    this.defaultColumnWidth = const FlexColumnWidth(),
    this.textDirection,
    this.border,
    this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
    this.textBaseline,
  });

  @override
  Widget buildContent(BuildContext context) {
    return Table(
      children: children,
      columnWidths: columnWidths,
      defaultColumnWidth: defaultColumnWidth,
      textDirection: textDirection,
      border: border,
      defaultVerticalAlignment: defaultVerticalAlignment,
      textBaseline: textBaseline,
    );
  }
}

/// Tom wrapper for [GridView].
///
/// Adds ID, group, authorization, and resource resolution.
class TomGridView extends TomTableBase {
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final SliverGridDelegate gridDelegate;
  final SliverChildDelegate childrenDelegate;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  const TomGridView({
    super.key,
    super.tomId,
    super.tomGroup,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    required this.gridDelegate,
    required this.childrenDelegate,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedCacheExtent =
        cacheExtent ?? resolveDoubleOrNull(context, 'cacheExtent');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull(context, 'padding');

    return GridView.custom(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: resolvedPadding,
      gridDelegate: gridDelegate,
      childrenDelegate: childrenDelegate,
      cacheExtent: resolvedCacheExtent,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
    );
  }
}

/// Tom wrapper for [ReorderableListView].
///
/// Adds ID, group, authorization, and resource resolution.
class TomReorderableListView extends TomTableBase {
  final List<Widget> children;
  final ReorderCallback onReorder;
  final void Function(int)? onReorderStart;
  final void Function(int)? onReorderEnd;
  final double? itemExtent;
  final Widget? prototypeItem;
  final ReorderItemProxyDecorator? proxyDecorator;
  final bool buildDefaultDragHandles;
  final EdgeInsets? padding;
  final Widget? header;
  final Widget? footer;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? scrollController;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double anchor;
  final double? cacheExtent;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final double? autoScrollerVelocityScalar;

  const TomReorderableListView({
    super.key,
    super.tomId,
    super.tomGroup,
    required this.children,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.prototypeItem,
    this.proxyDecorator,
    this.buildDefaultDragHandles = true,
    this.padding,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.scrollController,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.anchor = 0.0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
  });

  @override
  Widget buildContent(BuildContext context) {
    // Phase 2: Resolve optional parameters from resources
    final resolvedItemExtent =
        itemExtent ?? resolveDoubleOrNull(context, 'itemExtent');
    final resolvedCacheExtent =
        cacheExtent ?? resolveDoubleOrNull(context, 'cacheExtent');
    final resolvedAnchor =
        resolveDoubleOrNull(context, 'anchor') ?? anchor;
    final resolvedAutoScrollerVelocityScalar =
        autoScrollerVelocityScalar ?? resolveDoubleOrNull(context, 'autoScrollerVelocityScalar');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull(context, 'padding');

    return ReorderableListView(
      onReorder: onReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: resolvedItemExtent,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
      buildDefaultDragHandles: buildDefaultDragHandles,
      padding: resolvedPadding,
      header: header,
      footer: footer,
      scrollDirection: scrollDirection,
      reverse: reverse,
      scrollController: scrollController,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      anchor: resolvedAnchor,
      cacheExtent: resolvedCacheExtent,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
      autoScrollerVelocityScalar: resolvedAutoScrollerVelocityScalar,
      children: children,
    );
  }
}

// ============================================================================
// DATA TABLE HELPER CLASSES
// These are non-widget classes that wrap Flutter's DataCell, DataColumn,
// DataRow for use with TomDataTable.
// ============================================================================

/// Tom equivalent for [DataCell] (non-widget data class).
///
/// DataCell is not a widget — it's a data class for DataTable rows.
/// This class mirrors DataCell's API and adds Tom ID support for
/// resource resolution and authorization tracking.
///
/// Usage:
/// ```dart
/// TomDataRow(
///   cells: [
///     TomDataCell(tomId: 'name', child: TomText('John')),
///     TomDataCell(tomId: 'email', child: TomText('john@example.com')),
///   ],
/// )
/// ```

// =============================================================================
// AUTHORIZATION-AWARE CONTENT WRAPPER
// =============================================================================

/// Internal widget that wraps content with authorization checking.
///
/// At render time, checks the tomId's authorization state and:
/// - Hidden: renders SizedBox.shrink()
/// - Readonly: applies readonly styling
/// - Full access: renders the child normally
class _TomAuthContent extends StatelessWidget {
  const _TomAuthContent({
    required this.tomId,
    this.tomGroup,
    required this.child,
  });

  final String? tomId;
  final String? tomGroup;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tomId == null) return child;

    final scope = TomNodeScope.of(context);
    final fullPath = scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
    final auth = TomUIAuthorization.resolveAuth(fullPath);

    // Hidden: return empty
    if (!auth.visible) {
      return const SizedBox.shrink();
    }

    // Readonly: apply styling
    if (auth.readonly) {
      final style = TomThemeScope.readonlyStyleOf(context);
      return style.apply(child);
    }

    // Full access
    return child;
  }
}

// =============================================================================
// TOM DATA TABLE CLASSES
// =============================================================================

/// Tom extension of [DataCell] with built-in authorization.
///
/// Extends DataCell directly, preserving type identity (`TomDataCell is DataCell`).
/// Authorization is checked at render time via an internal wrapper widget.
///
/// - **Hidden**: Cell content renders as empty
/// - **Readonly**: Cell content has readonly styling, interactions disabled
/// - **Full access**: Normal rendering and behavior
///
/// Usage:
/// ```dart
/// TomDataTable(
///   columns: [...],
///   rows: [
///     DataRow(cells: [
///       TomDataCell(tomId: 'salary', child: TomText('\$150,000')),
///     ]),
///   ],
/// )
/// ```
class TomDataCell extends DataCell {
  /// Creates a Tom DataCell with authorization support.
  ///
  /// The [child] content is automatically wrapped to check authorization
  /// at render time based on [tomId].
  TomDataCell({
    this.tomId,
    this.tomGroup,
    required Widget child,
    bool placeholder = false,
    bool showEditIcon = false,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
    GestureTapCallback? onDoubleTap,
    GestureTapCancelCallback? onTapCancel,
    GestureTapDownCallback? onTapDown,
  }) : super(
          _TomAuthContent(tomId: tomId, tomGroup: tomGroup, child: child),
          placeholder: placeholder,
          showEditIcon: showEditIcon,
          onTap: onTap,
          onLongPress: onLongPress,
          onDoubleTap: onDoubleTap,
          onTapCancel: onTapCancel,
          onTapDown: onTapDown,
        );

  /// Creates an empty/placeholder cell.
  TomDataCell.empty({this.tomId, this.tomGroup})
      : super(const SizedBox.shrink(), placeholder: true);

  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final String? tomGroup;
}

/// Tom extension of [DataColumn] with built-in authorization.
///
/// Extends DataColumn directly, preserving type identity (`TomDataColumn is DataColumn`).
/// Authorization is checked at render time via an internal wrapper widget.
///
/// - **Hidden**: Column header renders as empty (column still takes space)
/// - **Readonly**: Column header has readonly styling
/// - **Full access**: Normal rendering
///
/// Note: To completely remove a column from the table when hidden,
/// use [isVisible] to filter before passing to TomDataTable.
///
/// Usage:
/// ```dart
/// final columns = [
///   TomDataColumn(tomId: 'name', label: TomText('Name')),
///   TomDataColumn(tomId: 'salary', label: TomText('Salary')),
/// ].where((c) => c.isVisible(context)).toList();
/// ```
class TomDataColumn extends DataColumn {
  /// Creates a Tom DataColumn with authorization support.
  ///
  /// The [label] content is automatically wrapped to check authorization
  /// at render time based on [tomId].
  TomDataColumn({
    this.tomId,
    this.tomGroup,
    required Widget label,
    String? tooltip,
    bool numeric = false,
    DataColumnSortCallback? onSort,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
  }) : super(
          label: _TomAuthContent(tomId: tomId, tomGroup: tomGroup, child: label),
          tooltip: tooltip,
          numeric: numeric,
          onSort: onSort,
          mouseCursor: mouseCursor,
        );

  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final String? tomGroup;

  /// Returns true if this column should be visible based on authorization.
  ///
  /// Use this to filter columns before passing to DataTable:
  /// ```dart
  /// columns.where((c) => c is! TomDataColumn || c.isVisible(context)).toList()
  /// ```
  bool isVisible(BuildContext context) {
    if (tomId == null) return true;
    final scope = TomNodeScope.of(context);
    final fullPath = scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
    return TomUIAuthorization.resolveAuth(fullPath).visible;
  }

  /// Returns true if this column should be readonly based on authorization.
  bool isReadonly(BuildContext context) {
    if (tomId == null) return false;
    final scope = TomNodeScope.of(context);
    final fullPath = scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
    return TomUIAuthorization.resolveAuth(fullPath).readonly;
  }
}

/// Tom extension of [DataRow] with built-in authorization.
///
/// Extends DataRow directly, preserving type identity (`TomDataRow is DataRow`).
///
/// Row-level authorization affects:
/// - **Hidden**: Use [isVisible] to filter rows before passing to DataTable
/// - **Readonly**: Use [isReadonly] to conditionally disable interactions
///
/// Cell-level authorization is handled automatically when using [TomDataCell].
///
/// Usage:
/// ```dart
/// final rows = employees.map((e) => TomDataRow(
///   tomId: 'employee.${e.id}',
///   cells: [
///     TomDataCell(tomId: 'name', child: TomText(e.name)),
///     TomDataCell(tomId: 'salary', child: TomText('\$${e.salary}')),
///   ],
/// )).where((r) => r.isVisible(context)).toList();
/// ```
class TomDataRow extends DataRow {
  /// Creates a Tom DataRow with authorization support.
  TomDataRow({
    this.tomId,
    this.tomGroup,
    super.key,
    bool selected = false,
    ValueChanged<bool?>? onSelectChanged,
    GestureLongPressCallback? onLongPress,
    WidgetStateProperty<Color?>? color,
    required List<DataCell> cells,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
  }) : super(
          selected: selected,
          onSelectChanged: onSelectChanged,
          onLongPress: onLongPress,
          color: color,
          cells: cells,
          mouseCursor: mouseCursor,
        );

  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final String? tomGroup;

  /// Returns true if this row should be visible based on authorization.
  ///
  /// Use this to filter rows before passing to DataTable:
  /// ```dart
  /// rows.where((r) => r is! TomDataRow || r.isVisible(context)).toList()
  /// ```
  bool isVisible(BuildContext context) {
    if (tomId == null) return true;
    final scope = TomNodeScope.of(context);
    final fullPath = scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
    return TomUIAuthorization.resolveAuth(fullPath).visible;
  }

  /// Returns true if this row should be readonly based on authorization.
  bool isReadonly(BuildContext context) {
    if (tomId == null) return false;
    final scope = TomNodeScope.of(context);
    final fullPath = scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
    return TomUIAuthorization.resolveAuth(fullPath).readonly;
  }
}
