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
  final WidgetStateProperty<Color?>? dataRowColor;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final TextStyle? dataTextStyle;
  final WidgetStateProperty<Color?>? headingRowColor;
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

  // Pre-resolved resource values
  late final int? _resolvedSortColumnIndex;
  late final bool _resolvedSortAscending;
  late final double? _resolvedDataRowMinHeight;
  late final double? _resolvedDataRowMaxHeight;
  late final double? _resolvedHeadingRowHeight;
  late final double? _resolvedHorizontalMargin;
  late final double? _resolvedColumnSpacing;
  late final double? _resolvedDividerThickness;
  late final double? _resolvedCheckboxHorizontalMargin;
  late final bool _resolvedShowCheckboxColumn;
  late final bool _resolvedShowBottomBorder;
  late final TextStyle? _resolvedDataTextStyle;
  late final TextStyle? _resolvedHeadingTextStyle;
  late final Decoration? _resolvedDecoration;
  late final TableBorder? _resolvedBorder;

  TomDataTable({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.columns,
    this.sortColumnIndex,
    this.sortAscending = true,
    ValueSetter<bool?>? onSelectAll,
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
  })  : onSelectAll = InScopeBuilder(scope: scope).wrap1n(onSelectAll) {
    _resolvedSortColumnIndex = sortColumnIndex ?? TomCtr.intVal(basePath, 'sortColumnIndex');
    _resolvedSortAscending = TomCtr.boolVal(basePath, 'sortAscending') ?? sortAscending;
    _resolvedDataRowMinHeight = dataRowMinHeight ?? TomCtr.doubleVal(basePath, 'dataRowMinHeight');
    _resolvedDataRowMaxHeight = dataRowMaxHeight ?? TomCtr.doubleVal(basePath, 'dataRowMaxHeight');
    _resolvedHeadingRowHeight = headingRowHeight ?? TomCtr.doubleVal(basePath, 'headingRowHeight');
    _resolvedHorizontalMargin = horizontalMargin ?? TomCtr.doubleVal(basePath, 'horizontalMargin');
    _resolvedColumnSpacing = columnSpacing ?? TomCtr.doubleVal(basePath, 'columnSpacing');
    _resolvedDividerThickness = dividerThickness ?? TomCtr.doubleVal(basePath, 'dividerThickness');
    _resolvedCheckboxHorizontalMargin = checkboxHorizontalMargin ?? TomCtr.doubleVal(basePath, 'checkboxHorizontalMargin');
    _resolvedShowCheckboxColumn = TomCtr.boolVal(basePath, 'showCheckboxColumn') ?? showCheckboxColumn;
    _resolvedShowBottomBorder = TomCtr.boolVal(basePath, 'showBottomBorder') ?? showBottomBorder;
    _resolvedDataTextStyle = dataTextStyle ?? _resolveTextStyle('dataTextStyle');
    _resolvedHeadingTextStyle = headingTextStyle ?? _resolveTextStyle('headingTextStyle');
    _resolvedDecoration = decoration ?? _resolveDecoration('decoration');
    _resolvedBorder = border ?? _resolveTableBorder('border');
  }

  @override
  Widget buildContent(BuildContext context) {
    return DataTable(
      columns: columns,
      sortColumnIndex: _resolvedSortColumnIndex,
      sortAscending: _resolvedSortAscending,
      onSelectAll: onSelectAll,
      decoration: _resolvedDecoration,
      dataRowColor: dataRowColor,
      dataRowMinHeight: _resolvedDataRowMinHeight,
      dataRowMaxHeight: _resolvedDataRowMaxHeight,
      dataTextStyle: _resolvedDataTextStyle,
      headingRowColor: headingRowColor,
      headingRowHeight: _resolvedHeadingRowHeight,
      headingTextStyle: _resolvedHeadingTextStyle,
      horizontalMargin: _resolvedHorizontalMargin,
      columnSpacing: _resolvedColumnSpacing,
      showCheckboxColumn: _resolvedShowCheckboxColumn,
      showBottomBorder: _resolvedShowBottomBorder,
      dividerThickness: _resolvedDividerThickness,
      checkboxHorizontalMargin: _resolvedCheckboxHorizontalMargin,
      border: _resolvedBorder,
      clipBehavior: clipBehavior,
      rows: rows,
    );
  }

  TextStyle? _resolveTextStyle(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTextStyle(basePath!, suffix);
  }

  Decoration? _resolveDecoration(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveDecoration(basePath!, suffix);
  }

  TableBorder? _resolveTableBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTableBorder(basePath!, suffix);
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
  final WidgetStateProperty<Color?>? headingRowColor;
  final bool showEmptyRows;
  final DataTableSource source;

  // Pre-resolved resource values
  late final int? _resolvedSortColumnIndex;
  late final bool _resolvedSortAscending;
  late final double? _resolvedDataRowMinHeight;
  late final double? _resolvedDataRowMaxHeight;
  late final double _resolvedHeadingRowHeight;
  late final double _resolvedHorizontalMargin;
  late final double _resolvedColumnSpacing;
  late final double? _resolvedCheckboxHorizontalMargin;
  late final bool _resolvedShowCheckboxColumn;
  late final bool _resolvedShowFirstLastButtons;
  late final int? _resolvedInitialFirstRowIndex;
  late final int _resolvedRowsPerPage;
  late final bool _resolvedShowEmptyRows;

  TomPaginatedDataTable({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.header,
    this.actions,
    required this.columns,
    this.sortColumnIndex,
    this.sortAscending = true,
    ValueSetter<bool?>? onSelectAll,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.headingRowHeight,
    this.horizontalMargin,
    this.columnSpacing,
    this.showCheckboxColumn = true,
    this.showFirstLastButtons = false,
    this.initialFirstRowIndex = 0,
    ValueChanged<int>? onPageChanged,
    this.rowsPerPage = PaginatedDataTable.defaultRowsPerPage,
    this.availableRowsPerPage = const [
      PaginatedDataTable.defaultRowsPerPage,
      PaginatedDataTable.defaultRowsPerPage * 2,
      PaginatedDataTable.defaultRowsPerPage * 5,
      PaginatedDataTable.defaultRowsPerPage * 10,
    ],
    ValueChanged<int?>? onRowsPerPageChanged,
    this.dragStartBehavior = DragStartBehavior.start,
    this.arrowHeadColor,
    this.checkboxHorizontalMargin,
    this.headingRowColor,
    this.showEmptyRows = false,
    required this.source,
  })  : onSelectAll = InScopeBuilder(scope: scope).wrap1n(onSelectAll),
        onPageChanged = InScopeBuilder(scope: scope).wrap1n(onPageChanged),
        onRowsPerPageChanged = InScopeBuilder(scope: scope).wrap1n(onRowsPerPageChanged) {
    _resolvedSortColumnIndex = sortColumnIndex ?? TomCtr.intVal(basePath, 'sortColumnIndex');
    _resolvedSortAscending = TomCtr.boolVal(basePath, 'sortAscending') ?? sortAscending;
    _resolvedDataRowMinHeight = dataRowMinHeight ?? TomCtr.doubleVal(basePath, 'dataRowMinHeight') ?? kMinInteractiveDimension;
    _resolvedDataRowMaxHeight = dataRowMaxHeight ?? TomCtr.doubleVal(basePath, 'dataRowMaxHeight') ?? kMinInteractiveDimension;
    _resolvedHeadingRowHeight = headingRowHeight ?? TomCtr.doubleVal(basePath, 'headingRowHeight') ?? 56.0;
    _resolvedHorizontalMargin = horizontalMargin ?? TomCtr.doubleVal(basePath, 'horizontalMargin') ?? 24.0;
    _resolvedColumnSpacing = columnSpacing ?? TomCtr.doubleVal(basePath, 'columnSpacing') ?? 56.0;
    _resolvedCheckboxHorizontalMargin = checkboxHorizontalMargin ?? TomCtr.doubleVal(basePath, 'checkboxHorizontalMargin');
    _resolvedShowCheckboxColumn = TomCtr.boolVal(basePath, 'showCheckboxColumn') ?? showCheckboxColumn;
    _resolvedShowFirstLastButtons = TomCtr.boolVal(basePath, 'showFirstLastButtons') ?? showFirstLastButtons;
    _resolvedInitialFirstRowIndex = initialFirstRowIndex ?? TomCtr.intVal(basePath, 'initialFirstRowIndex');
    _resolvedRowsPerPage = TomCtr.intVal(basePath, 'rowsPerPage') ?? rowsPerPage;
    _resolvedShowEmptyRows = TomCtr.boolVal(basePath, 'showEmptyRows') ?? showEmptyRows;
  }

  @override
  Widget buildContent(BuildContext context) {
    return PaginatedDataTable(
      header: header,
      actions: actions,
      columns: columns,
      sortColumnIndex: _resolvedSortColumnIndex,
      sortAscending: _resolvedSortAscending,
      onSelectAll: onSelectAll,
      dataRowMinHeight: _resolvedDataRowMinHeight,
      dataRowMaxHeight: _resolvedDataRowMaxHeight,
      headingRowHeight: _resolvedHeadingRowHeight,
      horizontalMargin: _resolvedHorizontalMargin,
      columnSpacing: _resolvedColumnSpacing,
      showCheckboxColumn: _resolvedShowCheckboxColumn,
      showFirstLastButtons: _resolvedShowFirstLastButtons,
      initialFirstRowIndex: _resolvedInitialFirstRowIndex,
      onPageChanged: onPageChanged,
      rowsPerPage: _resolvedRowsPerPage,
      availableRowsPerPage: availableRowsPerPage,
      onRowsPerPageChanged: onRowsPerPageChanged,
      dragStartBehavior: dragStartBehavior,
      checkboxHorizontalMargin: _resolvedCheckboxHorizontalMargin,
      showEmptyRows: _resolvedShowEmptyRows,
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

  // Pre-resolved resource values
  late final TableBorder? _resolvedBorder;

  TomTable({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    this.children = const [],
    this.columnWidths,
    this.defaultColumnWidth = const FlexColumnWidth(),
    this.textDirection,
    this.border,
    this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
    this.textBaseline,
  }) {
    _resolvedBorder = border ?? _resolveTableBorder('border');
  }

  @override
  Widget buildContent(BuildContext context) {
    return Table(
      children: children,
      columnWidths: columnWidths,
      defaultColumnWidth: defaultColumnWidth,
      textDirection: textDirection,
      border: _resolvedBorder,
      defaultVerticalAlignment: defaultVerticalAlignment,
      textBaseline: textBaseline,
    );
  }

  TableBorder? _resolveTableBorder(String suffix) {
    if (basePath == null) return null;
    return TomStyleResolvers.resolveTableBorder(basePath!, suffix);
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

  // Pre-resolved resource values
  late final bool _resolvedReverse;
  late final bool? _resolvedPrimary;
  late final bool _resolvedShrinkWrap;
  late final double? _resolvedCacheExtent;
  late final int? _resolvedSemanticChildCount;
  late final String? _resolvedRestorationId;
  late final EdgeInsetsGeometry? _resolvedPadding;

  TomGridView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
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
  }) {
    _resolvedReverse = TomCtr.boolVal(basePath, 'reverse') ?? reverse;
    _resolvedPrimary = primary ?? TomCtr.boolVal(basePath, 'primary');
    _resolvedShrinkWrap = TomCtr.boolVal(basePath, 'shrinkWrap') ?? shrinkWrap;
    _resolvedCacheExtent = cacheExtent ?? TomCtr.doubleVal(basePath, 'cacheExtent');
    _resolvedSemanticChildCount = semanticChildCount ?? TomCtr.intVal(basePath, 'semanticChildCount');
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return GridView.custom(
      scrollDirection: scrollDirection,
      reverse: _resolvedReverse,
      controller: controller,
      primary: _resolvedPrimary,
      physics: physics,
      shrinkWrap: _resolvedShrinkWrap,
      padding: _resolvedPadding,
      gridDelegate: gridDelegate,
      childrenDelegate: childrenDelegate,
      cacheExtent: _resolvedCacheExtent,
      semanticChildCount: _resolvedSemanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: _resolvedRestorationId,
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

  // Pre-resolved resource values
  late final double? _resolvedItemExtent;
  late final double? _resolvedCacheExtent;
  late final double _resolvedAnchor;
  late final double? _resolvedAutoScrollerVelocityScalar;
  late final bool _resolvedBuildDefaultDragHandles;
  late final bool _resolvedReverse;
  late final bool? _resolvedPrimary;
  late final bool _resolvedShrinkWrap;
  late final String? _resolvedRestorationId;
  late final EdgeInsets? _resolvedPadding;

  TomReorderableListView({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.children,
    required ReorderCallback onReorder,
    void Function(int)? onReorderStart,
    void Function(int)? onReorderEnd,
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
  })  : onReorder = InScopeBuilder(scope: scope).wrap2(onReorder),
        onReorderStart = InScopeBuilder(scope: scope).wrap1n(onReorderStart),
        onReorderEnd = InScopeBuilder(scope: scope).wrap1n(onReorderEnd) {
    _resolvedItemExtent = itemExtent ?? TomCtr.doubleVal(basePath, 'itemExtent');
    _resolvedCacheExtent = cacheExtent ?? TomCtr.doubleVal(basePath, 'cacheExtent');
    _resolvedAnchor = anchor ?? TomCtr.doubleVal(basePath, 'anchor') ?? 0.0;
    _resolvedAutoScrollerVelocityScalar = autoScrollerVelocityScalar ?? TomCtr.doubleVal(basePath, 'autoScrollerVelocityScalar');
    _resolvedBuildDefaultDragHandles = TomCtr.boolVal(basePath, 'buildDefaultDragHandles') ?? buildDefaultDragHandles;
    _resolvedReverse = TomCtr.boolVal(basePath, 'reverse') ?? reverse;
    _resolvedPrimary = primary ?? TomCtr.boolVal(basePath, 'primary');
    _resolvedShrinkWrap = TomCtr.boolVal(basePath, 'shrinkWrap') ?? shrinkWrap;
    _resolvedRestorationId = restorationId ?? TomCtr.textOrNull(basePath, 'restorationId');
    _resolvedPadding = padding ?? TomCtr.edgeInsets(basePath, 'padding');
  }

  @override
  Widget buildContent(BuildContext context) {
    return ReorderableListView(
      onReorder: onReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemExtent: _resolvedItemExtent,
      prototypeItem: prototypeItem,
      proxyDecorator: proxyDecorator,
      buildDefaultDragHandles: _resolvedBuildDefaultDragHandles,
      padding: _resolvedPadding,
      header: header,
      footer: footer,
      scrollDirection: scrollDirection,
      reverse: _resolvedReverse,
      scrollController: scrollController,
      primary: _resolvedPrimary,
      physics: physics,
      shrinkWrap: _resolvedShrinkWrap,
      anchor: _resolvedAnchor,
      cacheExtent: _resolvedCacheExtent,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: _resolvedRestorationId,
      clipBehavior: clipBehavior,
      autoScrollerVelocityScalar: _resolvedAutoScrollerVelocityScalar,
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
  _TomAuthContent({
    required this.tomId,
    this.tomGroup,
    this.scope,
    required this.child,
  }) : basePath = TomCtr.resolvePath(tomId, scope);

  final String? tomId;
  final TomUIGroup? tomGroup;
  final TomScope? scope;
  final Widget child;
  final String? basePath;

  @override
  Widget build(BuildContext context) {
    if (basePath == null) return child;

    final auth = TomUIAuthorization.resolveAuth(basePath!);

    // Hidden: return empty
    if (!auth.isVisible) {
      return const SizedBox.shrink();
    }

    // Readonly: apply styling
    if (auth == TomAuthState.read) {
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

  /// The resolved canonical resource base path.
  final String? basePath;

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
  }) : basePath = TomCtr.resolvePath(tomId, scope),
       super(
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
      : basePath = TomCtr.resolvePath(tomId, scope),
        super(const SizedBox.shrink(), placeholder: true);
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

  /// The resolved canonical resource base path.
  final String? basePath;

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
    super.numeric = false,
    super.onSort,
    super.mouseCursor,
  }) : basePath = TomCtr.resolvePath(tomId, scope),
       super(
          label: _TomAuthContent(
            tomId: tomId,
            tomGroup: tomGroup,
            child: label ?? TomCtr.defaultTextOrEmpty(TomCtr.childTomId(tomId, 'label'), scope, tomGroup),
          ),
          tooltip: tooltip ?? TomCtr.textOrNull(_p(tomId, scope, 'tooltip')),
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
    if (basePath == null) return true;
    return TomUIAuthorization.resolveAuth(basePath!).isVisible;
  }

  /// Returns true if this column should be readonly based on authorization.
  bool isReadonly(BuildContext context) {
    if (basePath == null) return false;
    return TomUIAuthorization.resolveAuth(basePath!) == TomAuthState.read;
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

  /// The resolved canonical resource base path.
  final String? basePath;

  /// Creates a Tom DataRow with authorization support.
  TomDataRow({
    this.tomId,
    this.tomGroup,
    this.scope,
    super.key,
    super.selected = false,
    super.onSelectChanged,
    super.onLongPress,
    super.color,
    required super.cells,
    super.mouseCursor,
  }) : basePath = TomCtr.resolvePath(tomId, scope),
       super();

  /// Returns true if this row should be visible based on authorization.
  ///
  /// Use this to filter rows before passing to DataTable:
  /// ```dart
  /// rows.where((r) => r is! TomDataRow || r.isVisible(context)).toList()
  /// ```
  bool isVisible(BuildContext context) {
    if (basePath == null) return true;
    return TomUIAuthorization.resolveAuth(basePath!).isVisible;
  }

  /// Returns true if this row should be readonly based on authorization.
  bool isReadonly(BuildContext context) {
    if (basePath == null) return false;
    return TomUIAuthorization.resolveAuth(basePath!) == TomAuthState.read;
  }
}
