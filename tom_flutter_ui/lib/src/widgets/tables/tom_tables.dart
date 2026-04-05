import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../resource_auth/tom_auth_state.dart';
import '../../theme/tom_theme.dart';
import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../../groups/tom_ui_group.dart';
import '../../widget_base/tom_style_resolvers.dart';

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
    final resolvedSortColumnIndex =
      sortColumnIndex ?? resolveIntOrNull('sortColumnIndex');
    final resolvedSortAscending =
      resolveBoolOrNull('sortAscending') ?? sortAscending;
    final resolvedDataRowMinHeight =
        dataRowMinHeight ?? resolveDoubleOrNull('dataRowMinHeight');
    final resolvedDataRowMaxHeight =
        dataRowMaxHeight ?? resolveDoubleOrNull('dataRowMaxHeight');
    final resolvedHeadingRowHeight =
        headingRowHeight ?? resolveDoubleOrNull('headingRowHeight');
    final resolvedHorizontalMargin =
        horizontalMargin ?? resolveDoubleOrNull('horizontalMargin');
    final resolvedColumnSpacing =
        columnSpacing ?? resolveDoubleOrNull('columnSpacing');
    final resolvedDividerThickness =
        dividerThickness ?? resolveDoubleOrNull('dividerThickness');
    final resolvedCheckboxHorizontalMargin =
        checkboxHorizontalMargin ?? resolveDoubleOrNull('checkboxHorizontalMargin');
    final resolvedShowCheckboxColumn =
      resolveBoolOrNull('showCheckboxColumn') ?? showCheckboxColumn;
    final resolvedShowBottomBorder =
      resolveBoolOrNull('showBottomBorder') ?? showBottomBorder;

    // Phase 3: Resolve TextStyle from resources
    final resolvedDataTextStyle =
        dataTextStyle ?? _resolveTextStyle('dataTextStyle');
    final resolvedHeadingTextStyle =
        headingTextStyle ?? _resolveTextStyle('headingTextStyle');

    return DataTable(
      columns: columns,
      sortColumnIndex: resolvedSortColumnIndex,
      sortAscending: resolvedSortAscending,
      onSelectAll: onSelectAll,
      decoration: decoration ?? _resolveDecoration('decoration'),
      dataRowColor: dataRowColor,
      dataRowMinHeight: resolvedDataRowMinHeight,
      dataRowMaxHeight: resolvedDataRowMaxHeight,
      dataTextStyle: resolvedDataTextStyle,
      headingRowColor: headingRowColor,
      headingRowHeight: resolvedHeadingRowHeight,
      headingTextStyle: resolvedHeadingTextStyle,
      horizontalMargin: resolvedHorizontalMargin,
      columnSpacing: resolvedColumnSpacing,
      showCheckboxColumn: resolvedShowCheckboxColumn,
      showBottomBorder: resolvedShowBottomBorder,
      dividerThickness: resolvedDividerThickness,
      checkboxHorizontalMargin: resolvedCheckboxHorizontalMargin,
      border: border ?? _resolveTableBorder('border'),
      clipBehavior: clipBehavior,
      rows: rows,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath, suffix);
  }

  Decoration? _resolveDecoration(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath, suffix);
  }

  TableBorder? _resolveTableBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTableBorder(basePath, suffix);
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
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final double? headingRowHeight;
  final double? horizontalMargin;
  final double? columnSpacing;
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
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.headingRowHeight,
    this.horizontalMargin,
    this.columnSpacing,
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
    final resolvedSortColumnIndex =
      sortColumnIndex ?? resolveIntOrNull('sortColumnIndex');
    final resolvedSortAscending =
      resolveBoolOrNull('sortAscending') ?? sortAscending;
    final resolvedDataRowMinHeight =
        dataRowMinHeight ?? resolveDoubleOrNull('dataRowMinHeight') ?? kMinInteractiveDimension;
    final resolvedDataRowMaxHeight =
        dataRowMaxHeight ?? resolveDoubleOrNull('dataRowMaxHeight') ?? kMinInteractiveDimension;
    final resolvedHeadingRowHeight =
        headingRowHeight ?? resolveDoubleOrNull('headingRowHeight') ?? 56.0;
    final resolvedHorizontalMargin =
        horizontalMargin ?? resolveDoubleOrNull('horizontalMargin') ?? 24.0;
    final resolvedColumnSpacing =
        columnSpacing ?? resolveDoubleOrNull('columnSpacing') ?? 56.0;
    final resolvedCheckboxHorizontalMargin =
        checkboxHorizontalMargin ?? resolveDoubleOrNull('checkboxHorizontalMargin');
    final resolvedShowCheckboxColumn =
        resolveBoolOrNull('showCheckboxColumn') ?? showCheckboxColumn;
    final resolvedShowFirstLastButtons =
        resolveBoolOrNull('showFirstLastButtons') ?? showFirstLastButtons;
    final resolvedInitialFirstRowIndex =
        initialFirstRowIndex ?? resolveIntOrNull('initialFirstRowIndex');
    final resolvedRowsPerPage =
        resolveIntOrNull('rowsPerPage') ?? rowsPerPage;
    final resolvedShowEmptyRows =
        resolveBoolOrNull('showEmptyRows') ?? showEmptyRows;

    return PaginatedDataTable(
      header: header,
      actions: actions,
      columns: columns,
      sortColumnIndex: resolvedSortColumnIndex,
      sortAscending: resolvedSortAscending,
      onSelectAll: onSelectAll,
      dataRowMinHeight: resolvedDataRowMinHeight,
      dataRowMaxHeight: resolvedDataRowMaxHeight,
      headingRowHeight: resolvedHeadingRowHeight,
      horizontalMargin: resolvedHorizontalMargin,
      columnSpacing: resolvedColumnSpacing,
      showCheckboxColumn: resolvedShowCheckboxColumn,
      showFirstLastButtons: resolvedShowFirstLastButtons,
      initialFirstRowIndex: resolvedInitialFirstRowIndex,
      onPageChanged: onPageChanged,
      rowsPerPage: resolvedRowsPerPage,
      availableRowsPerPage: availableRowsPerPage,
      onRowsPerPageChanged: onRowsPerPageChanged,
      dragStartBehavior: dragStartBehavior,
      checkboxHorizontalMargin: resolvedCheckboxHorizontalMargin,
      showEmptyRows: resolvedShowEmptyRows,
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
      border: border ?? _resolveTableBorder('border'),
      defaultVerticalAlignment: defaultVerticalAlignment,
      textBaseline: textBaseline,
    );
  }

  TableBorder? _resolveTableBorder(String suffix) {
    final basePath = resolveResourceBasePath();
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTableBorder(basePath, suffix);
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
    final resolvedReverse = resolveBoolOrNull('reverse') ?? reverse;
    final resolvedPrimary = primary ?? resolveBoolOrNull('primary');
    final resolvedShrinkWrap =
        resolveBoolOrNull('shrinkWrap') ?? shrinkWrap;
    final resolvedCacheExtent =
        cacheExtent ?? resolveDoubleOrNull('cacheExtent');
    final resolvedSemanticChildCount =
        semanticChildCount ?? resolveIntOrNull('semanticChildCount');
    final resolvedRestorationId =
        restorationId ?? resolveResourceOrNull('restorationId');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');

    return GridView.custom(
      scrollDirection: scrollDirection,
      reverse: resolvedReverse,
      controller: controller,
      primary: resolvedPrimary,
      physics: physics,
      shrinkWrap: resolvedShrinkWrap,
      padding: resolvedPadding,
      gridDelegate: gridDelegate,
      childrenDelegate: childrenDelegate,
      cacheExtent: resolvedCacheExtent,
      semanticChildCount: resolvedSemanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: resolvedRestorationId,
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
  final double? anchor;
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
    this.anchor,
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
        itemExtent ?? resolveDoubleOrNull('itemExtent');
    final resolvedCacheExtent =
        cacheExtent ?? resolveDoubleOrNull('cacheExtent');
    final resolvedAnchor =
        anchor ?? resolveDoubleOrNull('anchor') ?? 0.0;
    final resolvedAutoScrollerVelocityScalar =
        autoScrollerVelocityScalar ?? resolveDoubleOrNull('autoScrollerVelocityScalar');
    final resolvedBuildDefaultDragHandles =
      resolveBoolOrNull('buildDefaultDragHandles') ?? buildDefaultDragHandles;
    final resolvedReverse = resolveBoolOrNull('reverse') ?? reverse;
    final resolvedPrimary = primary ?? resolveBoolOrNull('primary');
    final resolvedShrinkWrap =
      resolveBoolOrNull('shrinkWrap') ?? shrinkWrap;
    final resolvedRestorationId =
      restorationId ?? resolveResourceOrNull('restorationId');
    final resolvedPadding =
        padding ?? resolveEdgeInsetsOrNull('padding');

    return ReorderableListView(
      onReorder: onReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: resolvedItemExtent,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
      buildDefaultDragHandles: resolvedBuildDefaultDragHandles,
      padding: resolvedPadding,
      header: header,
      footer: footer,
      scrollDirection: scrollDirection,
      reverse: resolvedReverse,
      scrollController: scrollController,
      primary: resolvedPrimary,
      physics: physics,
      shrinkWrap: resolvedShrinkWrap,
      anchor: resolvedAnchor,
      cacheExtent: resolvedCacheExtent,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: resolvedRestorationId,
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
///     TomDataCell(tomId: 'name', child: TomText(text: 'John')),
///     TomDataCell(tomId: 'email', child: TomText(text: 'john@example.com')),
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
  final TomUIGroup? tomGroup;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (tomId == null) return child;

    final scopePath = TomScope.current.getScopePath();
    final fullPath = scopePath.isNotEmpty ? '$scopePath.$tomId' : tomId!;
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

/// Tom extension of [DataCell] with built-in authorization and resource resolution.
///
/// Extends DataCell directly, preserving type identity (`TomDataCell is DataCell`).
/// Authorization is checked at render time via an internal wrapper widget.
///
/// - **Hidden**: Cell content renders as empty
/// - **Readonly**: Cell content has readonly styling, interactions disabled
/// - **Full access**: Normal rendering and behavior
///
/// Resources are resolved at construction time:
/// - [child] — if null, creates `TomText(tomId: '$tomId.child')`
///
/// Usage:
/// ```dart
/// TomDataTable(
///   columns: [...],
///   rows: [
///     DataRow(cells: [
///       TomDataCell(tomId: 'salary'),  // Resolves child from resources
///     ]),
///   ],
/// )
/// ```
class TomDataCell extends DataCell {
  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom DataCell with authorization support.
  ///
  /// The [child] content is automatically wrapped to check authorization
  /// at render time based on [tomId]. If [child] is null and [tomId] is
  /// provided, creates a default `TomText(tomId: '$tomId.child')`.
  TomDataCell({
    this.tomId,
    this.tomGroup,
    this.scope,
    Widget? child,
    bool placeholder = false,
    bool showEditIcon = false,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
    GestureTapCallback? onDoubleTap,
    GestureTapCancelCallback? onTapCancel,
    GestureTapDownCallback? onTapDown,
  }) : super(
          _TomAuthContent(
            tomId: tomId,
            tomGroup: tomGroup,
            child: child ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'child'), scope, tomGroup),
          ),
          placeholder: placeholder,
          showEditIcon: showEditIcon,
          onTap: onTap,
          onLongPress: onLongPress,
          onDoubleTap: onDoubleTap,
          onTapCancel: onTapCancel,
          onTapDown: onTapDown,
        );

  /// Creates an empty/placeholder cell.
  TomDataCell.empty({this.tomId, this.tomGroup, this.scope})
      : super(const SizedBox.shrink(), placeholder: true);
}

/// Tom extension of [DataColumn] with built-in authorization and resource resolution.
///
/// Extends DataColumn directly, preserving type identity (`TomDataColumn is DataColumn`).
/// Authorization is checked at render time via an internal wrapper widget.
///
/// - **Hidden**: Column header renders as empty (column still takes space)
/// - **Readonly**: Column header has readonly styling
/// - **Full access**: Normal rendering
///
/// Resources are resolved at construction time:
/// - [label] — if null, creates `TomText(tomId: '$tomId.label')`
/// - [tooltip] — resolved from `$tomId.tooltip`
///
/// Note: To completely remove a column from the table when hidden,
/// use [isVisible] to filter before passing to TomDataTable.
///
/// Usage:
/// ```dart
/// final columns = [
///   TomDataColumn(tomId: 'name'),  // Resolves label/tooltip from resources
///   TomDataColumn(tomId: 'salary'),
/// ].where((c) => c.isVisible(context)).toList();
/// ```
class TomDataColumn extends DataColumn {
  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom DataColumn with authorization support.
  ///
  /// The [label] content is automatically wrapped to check authorization
  /// at render time based on [tomId]. If [label] is null and [tomId] is
  /// provided, creates a default `TomText(tomId: '$tomId.label')`.
  TomDataColumn({
    this.tomId,
    this.tomGroup,
    this.scope,
    Widget? label,
    String? tooltip,
    bool numeric = false,
    DataColumnSortCallback? onSort,
    WidgetStateProperty<MouseCursor?>? mouseCursor,
  }) : super(
          label: _TomAuthContent(
            tomId: tomId,
            tomGroup: tomGroup,
            child: label ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'label'), scope, tomGroup),
          ),
          tooltip: tooltip ?? TomCtr.textOrNull(_p(tomId, scope, 'tooltip')),
          numeric: numeric,
          onSort: onSort,
          mouseCursor: mouseCursor,
        );

  /// Helper to build full path with suffix (for value resolution).
  static String? _p(String? tomId, TomScope? scope, String suffix) {
    final base = TomCtr.resolvePath(tomId, scope);
    return base != null ? '$base.$suffix' : null;
  }

  /// Returns true if this column should be visible based on authorization.
  ///
  /// Use this to filter columns before passing to DataTable:
  /// ```dart
  /// columns.where((c) => c is! TomDataColumn || c.isVisible(context)).toList()
  /// ```
  bool isVisible(BuildContext context) {
    if (tomId == null) return true;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    final fullPath = scopePath.isNotEmpty ? '$scopePath.$tomId' : tomId!;
    return TomUIAuthorization.resolveAuth(fullPath).visible;
  }

  /// Returns true if this column should be readonly based on authorization.
  bool isReadonly(BuildContext context) {
    if (tomId == null) return false;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    final fullPath = scopePath.isNotEmpty ? '$scopePath.$tomId' : tomId!;
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
///     TomDataCell(tomId: 'name'),  // Resolves from resources
///     TomDataCell(tomId: 'salary'),
///   ],
/// )).where((r) => r.isVisible(context)).toList();
/// ```
class TomDataRow extends DataRow {
  /// Tom ID for resource resolution and authorization.
  final String? tomId;

  /// Optional group membership.
  final TomUIGroup? tomGroup;

  /// Optional explicit scope for resource resolution.
  final TomScope? scope;

  /// Creates a Tom DataRow with authorization support.
  TomDataRow({
    this.tomId,
    this.tomGroup,
    this.scope,
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

  /// Returns true if this row should be visible based on authorization.
  ///
  /// Use this to filter rows before passing to DataTable:
  /// ```dart
  /// rows.where((r) => r is! TomDataRow || r.isVisible(context)).toList()
  /// ```
  bool isVisible(BuildContext context) {
    if (tomId == null) return true;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    final fullPath = scopePath.isNotEmpty ? '$scopePath.$tomId' : tomId!;
    return TomUIAuthorization.resolveAuth(fullPath).visible;
  }

  /// Returns true if this row should be readonly based on authorization.
  bool isReadonly(BuildContext context) {
    if (tomId == null) return false;
    final effectiveScope = scope ?? TomScope.current;
    final scopePath = effectiveScope.getScopePath();
    final fullPath = scopePath.isNotEmpty ? '$scopePath.$tomId' : tomId!;
    return TomUIAuthorization.resolveAuth(fullPath).readonly;
  }
}
