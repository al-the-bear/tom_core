import 'package:flutter/material.dart';

import 'acl_container.dart';
import 'acl_flags.dart';
import 'acl_group_visibility.dart';
import 'acl_responsive.dart';
import 'row_alignment.dart';

class _ComponentData {
  Widget child;
  int flags;
  double gapBefore;
  double gapWeight;
  Size? preferredSize;
  Size? minimumSize;
  Size? maximumSize;
  Key? referenceKey;
  Key? alignXToKey;
  AclAxisPointX? alignXFrom;
  AclAxisPointX? alignXTo;
  double alignXGap = 0;
  Key? alignYToKey;
  AclAxisPointY? alignYFrom;
  AclAxisPointY? alignYTo;
  double alignYGap = 0;
  AclRowCrossAlignment rowCrossAlignment = AclRowCrossAlignment.center;
  bool rowCrossAlignmentSet = false;
  Key? componentKey;
  String? id;
  String? group;

  _ComponentData({
    required this.child,
    this.flags = 0,
    this.gapBefore = 0,
    this.gapWeight = 1.0,
    this.componentKey,
  });

  AclComponent toComponent() {
    return AclComponent(
      child: child,
      flags: flags,
      gapBefore: gapBefore,
      gapWeight: gapWeight,
      preferredSize: preferredSize,
      minimumSize: minimumSize,
      maximumSize: maximumSize,
      referenceKey: referenceKey,
      alignXToKey: alignXToKey,
      alignXFrom: alignXFrom,
      alignXTo: alignXTo,
      alignXGap: alignXGap,
      alignYToKey: alignYToKey,
      alignYFrom: alignYFrom,
      alignYTo: alignYTo,
      alignYGap: alignYGap,
      rowCrossAlignment: rowCrossAlignment,
      componentKey: componentKey,
      id: id,
      group: group,
    );
  }
}

class _RowData {
  List<_ComponentData> components = [];
  RowAlignment alignment = RowAlignment.left;
  double gapBefore = 0;
  bool isGapRow = false;
  double gapRowWeight = 1.0;
  AclSeparator? separator;
  double gapRowMinSize = 0;
  String? id;
  String? group;
  List<AclRowBreakpoint> breakpoints = [];

  AclRow toRow() {
    return AclRow(
      components: components.map((c) => c.toComponent()).toList(),
      alignment: alignment,
      gapBefore: gapBefore,
      isGapRow: isGapRow,
      gapRowWeight: gapRowWeight,
      separator: separator,
      gapRowMinSize: gapRowMinSize,
      id: id,
      group: group,
      breakpoints: breakpoints,
    );
  }
}

/// Fluent builder for [Acl] layout containers.
class AclBuilder {
  final List<_RowData> _rows = [];
  _RowData _currentRow = _RowData();
  _ComponentData? _currentComponent;

  int _defaultFlags = 0;
  AclBorderStyle _borderStyle = const AclBorderStyle.none();
  AclBorderStyle? _focusedBorderStyle;
  EdgeInsetsGeometry _padding = EdgeInsets.zero;
  Color? _backgroundColor;
  String? _title;
  Widget? _titleWidget;
  TextStyle? _titleStyle;
  AclTitlePosition _titlePosition;
  AclTitleBorderAlign _titleBorderAlign;
  double _titleVerticalOffset = 0.0;
  bool _scrollableX = false;
  bool _scrollableY = false;
  Size? _preferredContainerSize;
  Size? _minimumContainerSize;
  Size? _maximumContainerSize;
  final Map<Object, Key> _referenceKeyByObject = Map<Object, Key>.identity();
  // Maps each appended widget object (by identity) to the row it was added to.
  // Used for O(1) row-constraint validation in alignX*/alignY*.
  final Map<Object, _RowData> _rowByObject = Map<Object, _RowData>.identity();

  // §24 IDs
  String? _aclId;
  String? _parentIdPath;

  // §25 Groups
  String? _aclGroup;
  String? _activeGroupName;

  // §26 Visibility
  final Map<String, AclGroupVisibilityController> _groupVisibilityControllers = {};

  // §27 Variants
  final List<AclVariant> _variants = [];

  AclBuilder({
    String? title,
    Widget? titleWidget,
    AclBorderStyle borderStyle = const AclBorderStyle.none(),
    AclBorderStyle? focusedBorderStyle,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Color? backgroundColor,
    TextStyle? titleStyle,
    AclTitlePosition titlePosition = AclTitlePosition.topLeft,
    AclTitleBorderAlign titleBorderAlign = AclTitleBorderAlign.bottom,
    double titleVerticalOffset = 0.0,
  })  : _title = title,
        _titleWidget = titleWidget,
        _borderStyle = borderStyle,
        _focusedBorderStyle = focusedBorderStyle,
        _padding = padding,
        _backgroundColor = backgroundColor,
        _titleStyle = titleStyle,
        _titlePosition = titlePosition,
        _titleBorderAlign = titleBorderAlign,
        _titleVerticalOffset = titleVerticalOffset {
    _rows.add(_currentRow);
  }

  // ── Component placement ────────────────────────────────────────────────────

  /// Appends a component to the current row.
  AclBuilder append(Widget child, {double dist = 0}) {
    final canAttachComponentKey =
        child is! Flexible && child is! Expanded && child is! Spacer;
    if (canAttachComponentKey && _rowByObject.containsKey(child)) {
      throw UnsupportedError(
        'AclBuilder: the same widget instance was appended more than once. '
        'Each component must be a distinct object so identity-based lookup '
        'and key generation stay unambiguous.',
      );
    }
    final componentKey =
        canAttachComponentKey ? _resolveReferenceKey(child) : null;
    _currentComponent = _ComponentData(
      child: child,
      flags: _defaultFlags,
      gapBefore: dist,
      componentKey: componentKey,
    );
    // Inherit active group from startGroup()/endGroup() range.
    if (_activeGroupName != null) {
      _currentComponent!.group = _activeGroupName;
    }
    if (componentKey != null) {
      _referenceKeyByObject[child] = componentKey;
      _rowByObject[child] = _currentRow;
    }
    _currentRow.components.add(_currentComponent!);
    return this;
  }

  /// Inserts an elastic horizontal gap slot into the current row.
  AclBuilder gap({double weight = 1}) {
    final gapWidget = const SizedBox.shrink();
    final data = _ComponentData(
      child: gapWidget,
      flags: AclFlags.gapElement,
      gapBefore: 0,
      gapWeight: weight,
    );
    _currentComponent = null; // gap is not a target for per-component methods
    _currentRow.components.add(data);
    return this;
  }

  // ── Row management ─────────────────────────────────────────────────────────

  /// Starts a new content row.
  AclBuilder newRow({double dist = 0}) {
    _currentRow = _RowData()..gapBefore = dist;
    _rows.add(_currentRow);
    _currentComponent = null;
    return this;
  }

  /// Inserts an elastic vertical gap row; **implicitly starts a new content row**.
  ///
  /// In scrollable-Y mode, the gap row collapses to zero height.
  ///
  /// When the layout also contains [expandY] components, gap rows yield all
  /// extra vertical space to those rows. In that case:
  /// * A [separator] gapRow renders at [minSize] height (minimum 9 px).
  /// * A pure spacing gapRow renders at [minSize] height, or collapses to
  ///   nothing if [minSize] is 0 (the default).
  AclBuilder gapRow({double weight = 1, AclSeparator? separator, double minSize = 0}) {
    final gapRowData = _RowData()
      ..isGapRow = true
      ..gapRowWeight = weight
      ..separator = separator
      ..gapRowMinSize = minSize;
    _rows.add(gapRowData);
    // Implicitly start a fresh content row after the gap row
    _currentRow = _RowData();
    _rows.add(_currentRow);
    _currentComponent = null;
    return this;
  }

  // ── Per-component sizing ───────────────────────────────────────────────────

  AclBuilder setPSize(double width, double height) {
    if (_currentComponent != null) {
      _currentComponent!.preferredSize = Size(width, height);
    }
    return this;
  }

  AclBuilder setMSize(double width, double height) {
    if (_currentComponent != null) {
      _currentComponent!.minimumSize = Size(width, height);
    }
    return this;
  }

  AclBuilder setXSize(double width, double height) {
    if (_currentComponent != null) {
      _currentComponent!.maximumSize = Size(width, height);
    }
    return this;
  }

  /// Sets the **preferred** width of the current component using a character-count.
  /// [charWidth] is the width of one character in pixels (default 8).
  /// [height] is used as the preferred height when no height has been set yet.
  AclBuilder setPWidthInChars(
    int chars, {
    double charWidth = 8,
    double height = 40,
  }) {
    if (_currentComponent == null) return this;
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = _currentComponent!.preferredSize?.height ?? height;
    _currentComponent!.preferredSize = Size(width, currentHeight);
    return this;
  }

  /// Sets the **minimum** width of the current component using a character-count.
  /// Preserves the existing minimum height (defaults to 0 if unset).
  AclBuilder setMWidthInChars(int chars, {double charWidth = 8}) {
    if (_currentComponent == null) return this;
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = _currentComponent!.minimumSize?.height ?? 0.0;
    _currentComponent!.minimumSize = Size(width, currentHeight);
    return this;
  }

  /// Sets the **maximum** width of the current component using a character-count.
  /// Preserves the existing maximum height (defaults to infinity if unset).
  AclBuilder setXWidthInChars(int chars, {double charWidth = 8}) {
    if (_currentComponent == null) return this;
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = _currentComponent!.maximumSize?.height ?? double.infinity;
    _currentComponent!.maximumSize = Size(width, currentHeight);
    return this;
  }

  // ── Per-component flags ────────────────────────────────────────────────────

  AclBuilder setAttr(int attr) {
    if (_currentComponent != null) _currentComponent!.flags |= attr;
    return this;
  }

  AclBuilder clearAttr(int newAttr) {
    if (_currentComponent != null) _currentComponent!.flags &= ~newAttr;
    return this;
  }

  // ── Per-component size references ──────────────────────────────────────────

  AclBuilder setComp(Object reference, int otherAttr) {
    if (_currentComponent != null) {
      if (_rowByObject[reference] == _currentRow) {
        throw UnsupportedError(
          'AclBuilder: sameWidthAs / sameHeightAs / sameSize cannot reference a '
          'component in the same row. Move the reference to a different row, '
          'or use a cross-row anchor.',
        );
      }
      _currentComponent!.referenceKey = _resolveReferenceKey(reference);
      _currentComponent!.flags |= (otherAttr & AclFlags.otherDim);
    }
    return this;
  }

  AclBuilder sameWidthAs(Object reference) =>
      setComp(reference, AclFlags.otherDimX);

  AclBuilder sameHeightAs(Object reference) =>
      setComp(reference, AclFlags.otherDimY);

  AclBuilder sameSize(Object reference) => setComp(reference, AclFlags.otherDim);

  // ── Per-component row cross-alignment ─────────────────────────────────────

  AclBuilder alignTopInRow() {
    if (_currentComponent != null) {
      if (_currentComponent!.alignYToKey != null) {
        throw UnsupportedError(
          'AclBuilder: alignTopInRow() cannot be combined with an alignY* method on '
          'the same component — alignY* overrides the row cross-alignment.',
        );
      }
      _currentComponent!.rowCrossAlignment = AclRowCrossAlignment.top;
      _currentComponent!.rowCrossAlignmentSet = true;
    }
    return this;
  }

  AclBuilder alignMiddleInRow() {
    if (_currentComponent != null) {
      if (_currentComponent!.alignYToKey != null) {
        throw UnsupportedError(
          'AclBuilder: alignMiddleInRow() cannot be combined with an alignY* method on '
          'the same component — alignY* overrides the row cross-alignment.',
        );
      }
      _currentComponent!.rowCrossAlignment = AclRowCrossAlignment.center;
      _currentComponent!.rowCrossAlignmentSet = true;
    }
    return this;
  }

  AclBuilder alignBottomInRow() {
    if (_currentComponent != null) {
      if (_currentComponent!.alignYToKey != null) {
        throw UnsupportedError(
          'AclBuilder: alignBottomInRow() cannot be combined with an alignY* method on '
          'the same component — alignY* overrides the row cross-alignment.',
        );
      }
      _currentComponent!.rowCrossAlignment = AclRowCrossAlignment.bottom;
      _currentComponent!.rowCrossAlignmentSet = true;
    }
    return this;
  }

  // ── Cross-row horizontal alignment ────────────────────────────────────────

  AclBuilder alignLeftToLeft(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignLeftToCenter(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignLeftToRight(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignCenterToLeft(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignCenterToCenter(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignCenterToRight(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignRightToLeft(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignRightToCenter(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignRightToRight(Object reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  // ── Same-row vertical alignment ───────────────────────────────────────────

  AclBuilder alignTopToTop(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignTopToMiddle(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignTopToBottom(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignMiddleToTop(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignMiddleToMiddle(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignMiddleToBottom(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignBottomToTop(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignBottomToMiddle(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignBottomToBottom(Object reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  // ── Row-level ──────────────────────────────────────────────────────────────

  AclBuilder setRowAlignment(RowAlignment align) {
    _currentRow.alignment = align;
    return this;
  }

  // ── Container-level sizing ─────────────────────────────────────────────────

  AclBuilder setAclPSize(double width, double height) {
    _preferredContainerSize = Size(width, height);
    return this;
  }

  AclBuilder setAclMSize(double width, double height) {
    _minimumContainerSize = Size(width, height);
    return this;
  }

  AclBuilder setAclXSize(double width, double height) {
    _maximumContainerSize = Size(width, height);
    return this;
  }

  AclBuilder setAclScrollableX() {
    _scrollableX = true;
    return this;
  }

  AclBuilder setAclScrollableY() {
    _scrollableY = true;
    return this;
  }

  // ── Container-level decoration ─────────────────────────────────────────────

  AclBuilder setAclDefaultFlags(int flags) {
    _defaultFlags = flags;
    return this;
  }

  int get defaultFlags => _defaultFlags;

  AclBuilder setAclBorderStyle(AclBorderStyle style) {
    _borderStyle = style;
    return this;
  }

  AclBuilder setAclBorderInsets(EdgeInsetsGeometry insets) {
    _borderStyle = _borderStyle.copyWith(borderInsets: insets);
    return this;
  }

  AclBuilder setAclFocusedBorderStyle(AclBorderStyle style) {
    _focusedBorderStyle = style;
    return this;
  }

  AclBuilder setAclPadding(EdgeInsetsGeometry padding) {
    _padding = padding;
    return this;
  }

  AclBuilder setAclBackgroundColor(Color color) {
    _backgroundColor = color;
    return this;
  }

  AclBuilder setAclTitle(String? title) {
    _title = title;
    return this;
  }

  AclBuilder setAclTitleWidget(Widget? widget) {
    _titleWidget = widget;
    return this;
  }

  AclBuilder setAclTitleStyle(TextStyle style) {
    _titleStyle = style;
    return this;
  }

  AclBuilder setAclTitlePosition(AclTitlePosition position) {
    _titlePosition = position;
    return this;
  }

  AclBuilder setAclTitleBorderAlign(AclTitleBorderAlign align) {
    _titleBorderAlign = align;
    return this;
  }

  AclBuilder setAclTitleVerticalOffset(double offset) {
    _titleVerticalOffset = offset;
    return this;
  }

  // ── IDs (§24) ──────────────────────────────────────────────────────────────

  AclBuilder setAclId(String id) {
    _aclId = id;
    return this;
  }

  AclBuilder setRowId(String id) {
    _currentRow.id = id;
    return this;
  }

  AclBuilder setId(String id) {
    if (_currentComponent != null) {
      _currentComponent!.id = id;
    }
    return this;
  }

  // ── Groups (§25) ───────────────────────────────────────────────────────────

  AclBuilder startGroup(String name) {
    if (_activeGroupName != null) {
      throw UnsupportedError(
        'AclBuilder: startGroup("$name") called while group "$_activeGroupName" '
        'is already active. Call endGroup() first.',
      );
    }
    _activeGroupName = name;
    return this;
  }

  AclBuilder endGroup() {
    if (_activeGroupName == null) {
      throw UnsupportedError(
        'AclBuilder: endGroup() called without a matching startGroup().',
      );
    }
    _activeGroupName = null;
    return this;
  }

  AclBuilder group(String name) {
    if (_currentComponent != null) {
      _currentComponent!.group = name;
    }
    return this;
  }

  AclBuilder setAclGroup(String name) {
    _aclGroup = name;
    return this;
  }

  AclBuilder setRowGroup(String name) {
    _currentRow.group = name;
    return this;
  }

  // ── Visibility (§26) ───────────────────────────────────────────────────────

  AclBuilder setGroupVisibilityController(
    String groupName,
    AclGroupVisibilityController controller,
  ) {
    _groupVisibilityControllers[groupName] = controller;
    return this;
  }

  // ── Responsive Variants (§27) ──────────────────────────────────────────────

  AclBuilder addVariant(
    String name, {
    required double atWidth,
    required void Function(AclBuilder) builder,
  }) {
    final variantBuilder = AclBuilder(
      borderStyle: _borderStyle,
      focusedBorderStyle: _focusedBorderStyle,
      padding: _padding,
      backgroundColor: _backgroundColor,
      titleStyle: _titleStyle,
      titlePosition: _titlePosition,
      titleBorderAlign: _titleBorderAlign,
      titleVerticalOffset: _titleVerticalOffset,
    );
    builder(variantBuilder);
    _variants.add(AclVariant(
      name: name,
      atWidth: atWidth,
      rows: variantBuilder._rows.map((r) => r.toRow()).toList(),
    ));
    return this;
  }

  // ── Row Breakpoints (§28) ──────────────────────────────────────────────────

  AclBuilder addRowBreakpoint({
    required double atWidth,
    required int splitAfter,
    double splitRowDist = 0,
  }) {
    _currentRow.breakpoints.add(AclRowBreakpoint(
      atWidth: atWidth,
      splitAfter: splitAfter,
      splitRowDist: splitRowDist,
    ));
    return this;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  Acl build() {
    // Sort variants by atWidth descending for selection.
    final sortedVariants = List<AclVariant>.from(_variants)
      ..sort((a, b) => b.atWidth.compareTo(a.atWidth));

    return Acl(
      rows: _rows.map((row) => row.toRow()).toList(),
      borderStyle: _borderStyle,
      focusedBorderStyle: _focusedBorderStyle,
      padding: _padding,
      backgroundColor: _backgroundColor,
      scrollableX: _scrollableX,
      scrollableY: _scrollableY,
      title: _title,
      titleWidget: _titleWidget,
      titleStyle: _titleStyle,
      titlePosition: _titlePosition,
      titleBorderAlign: _titleBorderAlign,
      titleVerticalOffset: _titleVerticalOffset,
      preferredContainerSize: _preferredContainerSize,
      minimumContainerSize: _minimumContainerSize,
      maximumContainerSize: _maximumContainerSize,
      aclId: _aclId,
      aclGroup: _aclGroup,
      parentIdPath: _parentIdPath,
      groupVisibilityControllers: Map.unmodifiable(_groupVisibilityControllers),
      variants: sortedVariants,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  AclBuilder _setHorizontalAlignment({
    required Object reference,
    required AclAxisPointX selfPoint,
    required AclAxisPointX referencePoint,
    required double gap,
  }) {
    if (_currentComponent != null) {
      final refRow = _rowByObject[reference];
      if (refRow == null) {
        throw UnsupportedError(
          'AclBuilder: alignX* forward reference — the reference widget '
          'must have been appended in a previous row before calling alignX* methods.',
        );
      }
      if (refRow == _currentRow) {
        throw UnsupportedError(
          'AclBuilder: alignX* same-row reference — the reference widget '
          'must be in a different row. Use alignY* for same-row vertical alignment.',
        );
      }
      _currentComponent!.alignXToKey = _resolveReferenceKey(reference);
      _currentComponent!.alignXFrom = selfPoint;
      _currentComponent!.alignXTo = referencePoint;
      _currentComponent!.alignXGap = gap;
    }
    return this;
  }

  AclBuilder _setVerticalAlignment({
    required Object reference,
    required AclAxisPointY selfPoint,
    required AclAxisPointY referencePoint,
    required double gap,
  }) {
    if (_currentComponent != null) {
      if (_currentComponent!.rowCrossAlignmentSet) {
        throw UnsupportedError(
          'AclBuilder: alignY* cannot be combined with alignTopInRow()/alignMiddleInRow()'
          '/alignBottomInRow() on the same component — remove the alignInRow() call.',
        );
      }
      final refRow = _rowByObject[reference];
      if (refRow == null) {
        throw UnsupportedError(
          'AclBuilder: alignY* forward reference — the reference widget '
          'must have been appended earlier in the same row before calling alignY* methods.',
        );
      }
      if (refRow != _currentRow) {
        throw UnsupportedError(
          'AclBuilder: alignY* cross-row reference — the reference widget '
          'must be in the same row. Use alignX* for cross-row horizontal alignment.',
        );
      }
      _currentComponent!.alignYToKey = _resolveReferenceKey(reference);
      _currentComponent!.alignYFrom = selfPoint;
      _currentComponent!.alignYTo = referencePoint;
      _currentComponent!.alignYGap = gap;
    }
    return this;
  }

  Key _resolveReferenceKey(Object reference) {
    if (reference is Key) return reference;
    return _referenceKeyByObject.putIfAbsent(
      reference,
      () => GlobalKey(debugLabel: 'acl-ref-${_referenceKeyByObject.length}'),
    );
  }
}

extension AclBuilderExtensions on AclBuilder {
  AclBuilder expandX() => setAttr(AclFlags.expandX);
  AclBuilder expandY() => setAttr(AclFlags.expandY);
  AclBuilder expand() => setAttr(AclFlags.expand);

  AclBuilder setRowAlignLeft() => setRowAlignment(RowAlignment.left);
  AclBuilder setRowAlignCenter() => setRowAlignment(RowAlignment.center);
  AclBuilder setRowAlignRight() => setRowAlignment(RowAlignment.right);
}
