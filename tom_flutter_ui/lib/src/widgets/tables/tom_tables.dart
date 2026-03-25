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
    return DataTable(
      columns: columns,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      onSelectAll: onSelectAll,
      decoration: decoration,
      dataRowColor: dataRowColor,
      dataRowMinHeight: dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight,
      dataTextStyle: dataTextStyle,
      headingRowColor: headingRowColor,
      headingRowHeight: headingRowHeight,
      headingTextStyle: headingTextStyle,
      horizontalMargin: horizontalMargin,
      columnSpacing: columnSpacing,
      showCheckboxColumn: showCheckboxColumn,
      showBottomBorder: showBottomBorder,
      dividerThickness: dividerThickness,
      checkboxHorizontalMargin: checkboxHorizontalMargin,
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
    return PaginatedDataTable(
      header: header,
      actions: actions,
      columns: columns,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      onSelectAll: onSelectAll,
      dataRowMinHeight: dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight,
      headingRowHeight: headingRowHeight,
      horizontalMargin: horizontalMargin,
      columnSpacing: columnSpacing,
      showCheckboxColumn: showCheckboxColumn,
      showFirstLastButtons: showFirstLastButtons,
      initialFirstRowIndex: initialFirstRowIndex,
      onPageChanged: onPageChanged,
      rowsPerPage: rowsPerPage,
      availableRowsPerPage: availableRowsPerPage,
      onRowsPerPageChanged: onRowsPerPageChanged,
      dragStartBehavior: dragStartBehavior,
      checkboxHorizontalMargin: checkboxHorizontalMargin,
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
    return GridView.custom(
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      gridDelegate: gridDelegate,
      childrenDelegate: childrenDelegate,
      cacheExtent: cacheExtent,
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
    return ReorderableListView(
      onReorder: onReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: itemExtent,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
      buildDefaultDragHandles: buildDefaultDragHandles,
      padding: padding,
      header: header,
      footer: footer,
      scrollDirection: scrollDirection,
      reverse: reverse,
      scrollController: scrollController,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      anchor: anchor,
      cacheExtent: cacheExtent,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
      autoScrollerVelocityScalar: autoScrollerVelocityScalar,
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
///     TomDataCell(tomId: 'name', child: TomText('John')).toCell(),
///     TomDataCell(tomId: 'email', child: TomText('john@example.com')).toCell(),
///   ],
/// )
/// ```
class TomDataCell {
  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final String? tomGroup;

  /// The widget to display in the cell.
  final Widget child;

  /// Whether tapping cell shows placeholder.
  final bool placeholder;

  /// Whether to show edit icon.
  final bool showEditIcon;

  /// Callback when cell is tapped.
  final GestureTapCallback? onTap;

  /// Callback when cell is long-pressed.
  final GestureLongPressCallback? onLongPress;

  /// Callback when cell is double-tapped.
  final GestureTapCallback? onDoubleTap;

  /// Callback when cell tap is cancelled.
  final GestureTapCancelCallback? onTapCancel;

  /// Callback when cell tap starts.
  final GestureTapDownCallback? onTapDown;

  const TomDataCell({
    this.tomId,
    this.tomGroup,
    required this.child,
    this.placeholder = false,
    this.showEditIcon = false,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onTapCancel,
    this.onTapDown,
  });

  /// Convenience constructor for empty/placeholder cells.
  const TomDataCell.empty({this.tomId, this.tomGroup})
      : child = const SizedBox.shrink(),
        placeholder = true,
        showEditIcon = false,
        onTap = null,
        onLongPress = null,
        onDoubleTap = null,
        onTapCancel = null,
        onTapDown = null;

  /// Resolves the full canonical path for this cell.
  String? _resolveFullPath(BuildContext context) {
    if (tomId == null) return null;
    final scope = TomNodeScope.of(context);
    return scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
  }

  /// Gets authorization state for this cell.
  TomAuthState getAuth(BuildContext context) {
    final path = _resolveFullPath(context);
    if (path == null) return TomAuthState.fullAccess;
    return TomUIAuthorization.resolveAuth(path);
  }

  /// Converts this to a Flutter [DataCell] WITHOUT authorization checking.
  ///
  /// Use [toCellWithAuth] for authorization-aware conversion.
  DataCell toCell() {
    return DataCell(
      child,
      placeholder: placeholder,
      showEditIcon: showEditIcon,
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      onTapCancel: onTapCancel,
      onTapDown: onTapDown,
    );
  }

  /// Converts this to a Flutter [DataCell] with authorization.
  ///
  /// - If hidden: returns an empty placeholder cell
  /// - If readonly: applies readonly styling and disables interactions
  /// - If full access: returns the normal cell
  DataCell toCellWithAuth(BuildContext context) {
    final auth = getAuth(context);

    // Hidden: return empty placeholder cell
    if (!auth.visible) {
      return const DataCell(SizedBox.shrink(), placeholder: true);
    }

    // Readonly: apply styling and disable interactions
    if (auth.readonly) {
      final style = TomThemeScope.readonlyStyleOf(context);
      return DataCell(
        style.apply(child),
        placeholder: placeholder,
        showEditIcon: false, // No editing when readonly
        // Disable all interactions
        onTap: null,
        onLongPress: null,
        onDoubleTap: null,
        onTapCancel: null,
        onTapDown: null,
      );
    }

    // Full access
    return toCell();
  }

  /// Returns true if this cell should be visible based on authorization.
  bool isVisible(BuildContext context) => getAuth(context).visible;

  /// Returns true if this cell should be readonly based on authorization.
  bool isReadonly(BuildContext context) => getAuth(context).readonly;
}

/// Tom equivalent for [DataColumn] (non-widget data class).
///
/// DataColumn is not a widget — it's a data class for DataTable headers.
/// This class mirrors DataColumn's API and adds Tom ID support for
/// resource resolution and authorization tracking.
///
/// Usage:
/// ```dart
/// TomDataTable(
///   columns: [
///     TomDataColumn(tomId: 'name', label: TomText('Name')).toColumn(),
///     TomDataColumn(tomId: 'email', label: TomText('Email')).toColumn(),
///   ],
///   rows: [...],
/// )
/// ```
class TomDataColumn {
  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final String? tomGroup;

  /// The column header label widget.
  final Widget label;

  /// Tooltip when hovering over the header.
  final String? tooltip;

  /// Whether this is a numeric column (right-aligned).
  final bool numeric;

  /// Whether this column can be sorted.
  final DataColumnSortCallback? onSort;

  /// Mouse cursor for this column.
  final WidgetStateProperty<MouseCursor?>? mouseCursor;

  const TomDataColumn({
    this.tomId,
    this.tomGroup,
    required this.label,
    this.tooltip,
    this.numeric = false,
    this.onSort,
    this.mouseCursor,
  });

  /// Resolves the full canonical path for this column.
  String? _resolveFullPath(BuildContext context) {
    if (tomId == null) return null;
    final scope = TomNodeScope.of(context);
    return scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
  }

  /// Gets authorization state for this column.
  TomAuthState getAuth(BuildContext context) {
    final path = _resolveFullPath(context);
    if (path == null) return TomAuthState.fullAccess;
    return TomUIAuthorization.resolveAuth(path);
  }

  /// Converts this to a Flutter [DataColumn] WITHOUT authorization checking.
  ///
  /// Use [toColumnWithAuth] for authorization-aware conversion.
  DataColumn toColumn() {
    return DataColumn(
      label: label,
      tooltip: tooltip,
      numeric: numeric,
      onSort: onSort,
      mouseCursor: mouseCursor,
    );
  }

  /// Converts this to a Flutter [DataColumn] with authorization.
  ///
  /// - If hidden: returns null (column should be filtered out)
  /// - If readonly: disables sorting
  /// - If full access: returns the normal column
  ///
  /// Returns null if the column should be hidden. Caller must filter nulls.
  DataColumn? toColumnWithAuth(BuildContext context) {
    final auth = getAuth(context);

    // Hidden: return null (caller filters these out)
    if (!auth.visible) {
      return null;
    }

    // Readonly: disable sorting
    if (auth.readonly) {
      return DataColumn(
        label: label,
        tooltip: tooltip,
        numeric: numeric,
        onSort: null, // No sorting when readonly
        mouseCursor: mouseCursor,
      );
    }

    // Full access
    return toColumn();
  }

  /// Returns true if this column should be visible based on authorization.
  bool isVisible(BuildContext context) => getAuth(context).visible;

  /// Returns true if this column should be readonly based on authorization.
  bool isReadonly(BuildContext context) => getAuth(context).readonly;
}

/// Tom equivalent for [DataRow] (non-widget data class).
///
/// DataRow is not a widget — it's a data class for DataTable rows.
/// This class mirrors DataRow's API and adds Tom ID support for
/// resource resolution and authorization tracking.
///
/// Usage:
/// ```dart
/// TomDataTable(
///   columns: [...],
///   rows: [
///     TomDataRow(
///       tomId: 'user1',
///       cells: [
///         TomDataCell(child: TomText('1')).toCell(),
///         TomDataCell(child: TomText('John')).toCell(),
///       ],
///     ).toRow(),
///   ],
/// )
/// ```
class TomDataRow {
  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final String? tomGroup;

  /// Unique key for this row.
  final LocalKey? key;

  /// Whether this row is selected.
  final bool selected;

  /// Callback when selection changes.
  final ValueChanged<bool?>? onSelectChanged;

  /// Callback when row is long-pressed.
  final GestureLongPressCallback? onLongPress;

  /// Color of this row.
  final WidgetStateProperty<Color?>? color;

  /// The cells in this row.
  final List<DataCell> cells;

  /// Mouse cursor for this row.
  final WidgetStateProperty<MouseCursor?>? mouseCursor;

  const TomDataRow({
    this.tomId,
    this.tomGroup,
    this.key,
    this.selected = false,
    this.onSelectChanged,
    this.onLongPress,
    this.color,
    required this.cells,
    this.mouseCursor,
  });

  /// Factory constructor that takes [TomDataCell] list and converts them.
  factory TomDataRow.fromTomCells({
    String? tomId,
    String? tomGroup,
    LocalKey? key,
    bool selected = false,
    ValueChanged<bool?>? onSelectChanged,
    GestureLongPressCallback? onLongPress,
    WidgetStateProperty<Color?>? color,
    required List<TomDataCell> cells,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
  }) {
    return TomDataRow(
      tomId: tomId,
      tomGroup: tomGroup,
      key: key,
      selected: selected,
      onSelectChanged: onSelectChanged,
      onLongPress: onLongPress,
      color: color,
      cells: cells.map((c) => c.toCell()).toList(),
      mouseCursor: mouseCursor,
    );
  }

  /// Factory constructor that takes [TomDataCell] list and applies auth.
  ///
  /// Each cell's visibility and readonly state is checked via authorization.
  static TomDataRow fromTomCellsWithAuth(
    BuildContext context, {
    String? tomId,
    String? tomGroup,
    LocalKey? key,
    bool selected = false,
    ValueChanged<bool?>? onSelectChanged,
    GestureLongPressCallback? onLongPress,
    WidgetStateProperty<Color?>? color,
    required List<TomDataCell> cells,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
  }) {
    return TomDataRow(
      tomId: tomId,
      tomGroup: tomGroup,
      key: key,
      selected: selected,
      onSelectChanged: onSelectChanged,
      onLongPress: onLongPress,
      color: color,
      cells: cells.map((c) => c.toCellWithAuth(context)).toList(),
      mouseCursor: mouseCursor,
    );
  }

  /// Resolves the full canonical path for this row.
  String? _resolveFullPath(BuildContext context) {
    if (tomId == null) return null;
    final scope = TomNodeScope.of(context);
    return scope?.appendWidget(tomId!) ??
        TomIdPrefix.prefixed(TomIdPrefix.widget, tomId!);
  }

  /// Gets authorization state for this row.
  TomAuthState getAuth(BuildContext context) {
    final path = _resolveFullPath(context);
    if (path == null) return TomAuthState.fullAccess;
    return TomUIAuthorization.resolveAuth(path);
  }

  /// Converts this to a Flutter [DataRow] WITHOUT authorization checking.
  ///
  /// Use [toRowWithAuth] for authorization-aware conversion.
  DataRow toRow() {
    return DataRow(
      key: key,
      selected: selected,
      onSelectChanged: onSelectChanged,
      onLongPress: onLongPress,
      color: color,
      cells: cells,
      mouseCursor: mouseCursor,
    );
  }

  /// Converts this to a Flutter [DataRow] with authorization.
  ///
  /// - If hidden: returns null (row should be filtered out)
  /// - If readonly: disables selection and long-press
  /// - If full access: returns the normal row
  ///
  /// Note: This checks row-level auth. Cell-level auth requires using
  /// [TomDataRow.fromTomCellsWithAuth] with [TomDataCell] instances.
  ///
  /// Returns null if the row should be hidden. Caller must filter nulls.
  DataRow? toRowWithAuth(BuildContext context) {
    final auth = getAuth(context);

    // Hidden: return null (caller filters these out)
    if (!auth.visible) {
      return null;
    }

    // Readonly: disable interactions
    if (auth.readonly) {
      return DataRow(
        key: key,
        selected: selected,
        onSelectChanged: null, // No selection when readonly
        onLongPress: null, // No long-press when readonly
        color: color,
        cells: cells,
        mouseCursor: mouseCursor,
      );
    }

    // Full access
    return toRow();
  }

  /// Returns true if this row should be visible based on authorization.
  bool isVisible(BuildContext context) => getAuth(context).visible;

  /// Returns true if this row should be readonly based on authorization.
  bool isReadonly(BuildContext context) => getAuth(context).readonly;
}
