import 'package:flutter/material.dart';

import 'acl_container.dart';
import 'acl_device_context.dart';
import 'acl_flags.dart';
import 'acl_group_visibility.dart';
import 'acl_responsive.dart';
import 'row_alignment.dart';

class _ComponentData {
  Widget child;
  int flags;
  double gapBefore;
  bool gapBeforeIsDefault;
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
  AclRowCrossAlignment rowCrossAlignment = AclRowCrossAlignment.top;
  bool rowCrossAlignmentSet = false;
  Key? componentKey;
  String? id;
  String? group;
  bool inlineVariant = false;
  AclVariantDetector? variantDetector;

  _ComponentData({
    required this.child,
    this.flags = 0,
    this.gapBefore = 0,
    this.gapBeforeIsDefault = false,
    this.gapWeight = 1.0,
    this.componentKey,
  });

  AclComponent toComponent() {
    return AclComponent(
      child: child,
      flags: flags,
      gapBefore: gapBefore,
      gapBeforeIsDefault: gapBeforeIsDefault,
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
      inlineVariant: inlineVariant,
      variantDetector: variantDetector,
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
  bool idScope = false;
  List<AclRowBreakpoint> breakpoints = [];

  /// Row-level height (null = inherit builder default).
  double? height;
  bool heightIsExplicit = false;
  List<(double, double?)> heightBpOverrides = const [];

  AclRow toRow({
    required double defaultAppendGap,
    required List<(double, double)> defaultAppendGapBpOverrides,
    required double? fallbackHeight,
    required List<(double, double?)> fallbackHeightBpOverrides,
  }) {
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
      idScope: idScope,
      breakpoints: breakpoints,
      height: heightIsExplicit ? height : fallbackHeight,
      heightBpOverrides:
          heightIsExplicit ? heightBpOverrides : fallbackHeightBpOverrides,
      defaultAppendGap: defaultAppendGap,
      defaultAppendGapBpOverrides: defaultAppendGapBpOverrides,
    );
  }
}

/// Fluent builder for [Acl] layout containers.
class AclBuilder {
  final List<_RowData> _rows = [];
  _RowData _currentRow = _RowData();
  _ComponentData? _currentComponent;

  int _defaultFlags = 0;
  double _defaultAppendGap = 8.0;
  List<(double, double)> _defaultAppendGapBpOverrides = const [];
  double? _defaultRowHeight;
  List<(double, double?)> _defaultRowHeightBpOverrides = const [];
  double _defaultRowGap = 8;
  Size? _defaultUnknownMinimumSize;
  Size? _defaultUnknownPreferredSize;
  AclRowCrossAlignment _defaultRowCrossAlignment = AclRowCrossAlignment.top;
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
  bool _idScope = false;

  // §25 Groups
  String? _aclGroup;
  String? _activeGroupName;

  // §26 Visibility
  final Map<String, AclGroupVisibilityController> _groupVisibilityControllers = {};

  // §27 Variants
  final List<AclVariant> _variants = [];

  // §29 Inline Component Variants
  bool _inVariantBlock = false;
  AclVariantDetector? _currentVariantDetector;

  // §30 Layout Direction
  AclDirection? _direction;

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

  /// Default preferred width for components without an explicit preferred size
  /// and no custom [_defaultUnknownPreferredSize].
  /// Large enough to prevent buttons/small widgets from collapsing next to
  /// elastic gaps, but still participates proportionally in the grow/shrink
  /// distribution alongside explicitly sized components.
  static const double _defaultPreferredWidth = 150;

  /// Applies default preferred and minimum sizes to the current component if
  /// no explicit sizes were set. Called whenever the current-component scope is
  /// about to change (append, gap, newRow, gapRow, build).
  void _finalizeCurrentComponent() {
    if (_currentComponent == null) return;
    final c = _currentComponent!;
    // Apply default preferred size if none was explicitly set.
    if (c.preferredSize == null) {
      final dp = _defaultUnknownPreferredSize;
      if (dp != null) {
        c.preferredSize = Size(
          dp.width == 0 ? _defaultPreferredWidth : dp.width,
          dp.height,
        );
      } else {
        c.preferredSize = const Size(_defaultPreferredWidth, 0);
      }
    }
    // Apply default minimum size if none was explicitly set.
    if (c.minimumSize == null && _defaultUnknownMinimumSize != null) {
      final dm = _defaultUnknownMinimumSize!;
      c.minimumSize = Size(
        dm.width == 0 ? 0 : dm.width,
        dm.height == 0 ? 0 : dm.height,
      );
    }
  }

  /// Appends a component to the current row.
  AclBuilder append(Widget child, {double dist = 0}) {
    _finalizeCurrentComponent();
    final canAttachComponentKey =
        child is! Flexible && child is! Expanded && child is! Spacer;
    if (canAttachComponentKey && _rowByObject.containsKey(child)) {
      throw UnsupportedError(
        'AclBuilder: the same widget instance was appended more than once. '
        'Each component must be a distinct object so identity-based lookup '
        'and key generation stay unambiguous.',
      );
    }
    // When the caller did not pass an explicit non-zero `dist`, tag the
    // component so the container can resolve the row's breakpoint-aware
    // default gap at render time instead of baking it in now.
    final usesDefaultGap = dist == 0;
    final componentKey =
        canAttachComponentKey ? _resolveReferenceKey(child) : null;
    _currentComponent = _ComponentData(
      child: child,
      flags: _defaultFlags,
      gapBefore: usesDefaultGap ? 0 : dist,
      gapBeforeIsDefault: usesDefaultGap,
      componentKey: componentKey,
    );
    // Apply the ACL-wide default row cross alignment. Per-component
    // overrides (alignTopInRow / alignMiddleInRow / alignBottomInRow) still
    // win by setting `rowCrossAlignmentSet = true`.
    _currentComponent!.rowCrossAlignment = _defaultRowCrossAlignment;
    // Inherit active group from startGroup()/endGroup() range.
    if (_activeGroupName != null) {
      _currentComponent!.group = _activeGroupName;
    }
    // Tag with inline variant if inside a startVariant/endVariant block.
    if (_inVariantBlock) {
      _currentComponent!.inlineVariant = true;
      _currentComponent!.variantDetector = _currentVariantDetector;
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
    _finalizeCurrentComponent();
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
  ///
  /// Optional [height] fixes the row's rendered height (null falls back to
  /// the builder's default set via [setAclDefaultRowHeight]). [heightBpOverrides]
  /// allows per-breakpoint overrides following the standard `(minWidth, value)`
  /// resolution rule.
  AclBuilder newRow({
    double dist = 0,
    double? height,
    List<(double, double?)> heightBpOverrides = const [],
  }) {
    _finalizeCurrentComponent();
    // Apply default row gap if no explicit dist was specified.
    final effectiveDist =
        (dist == 0 && _defaultRowGap > 0) ? _defaultRowGap : dist;
    _currentRow = _RowData()..gapBefore = effectiveDist;
    final heightIsExplicit = height != null || heightBpOverrides.isNotEmpty;
    if (heightIsExplicit) {
      _currentRow
        ..height = height
        ..heightBpOverrides = heightBpOverrides
        ..heightIsExplicit = true;
    }
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
    _finalizeCurrentComponent();
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

  /// Sets a preferred size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value, or defaulting to 0 / 0).
  AclBuilder setPSize(double width, [double height = 0]) {
    if (_currentComponent != null) {
      final cur = _currentComponent!.preferredSize;
      _currentComponent!.preferredSize = Size(
        width == 0 ? (cur?.width ?? 0) : width,
        height == 0 ? (cur?.height ?? 0) : height,
      );
    }
    return this;
  }

  /// Sets a minimum size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value, or defaulting to 0 / 0).
  AclBuilder setMSize(double width, [double height = 0]) {
    if (_currentComponent != null) {
      final cur = _currentComponent!.minimumSize;
      _currentComponent!.minimumSize = Size(
        width == 0 ? (cur?.width ?? 0) : width,
        height == 0 ? (cur?.height ?? 0) : height,
      );
    }
    return this;
  }

  /// Sets a maximum size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value).
  AclBuilder setXSize(double width, [double height = 0]) {
    if (_currentComponent != null) {
      final cur = _currentComponent!.maximumSize;
      _currentComponent!.maximumSize = Size(
        width == 0 ? (cur?.width ?? 0) : width,
        height == 0 ? (cur?.height ?? 0) : height,
      );
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

  /// Sets the default expand-X behaviour for newly appended components.
  ///
  /// When [enabled] is `true`, [AclFlags.expandX] is added to the default
  /// flags so every subsequent [append] call gets expandX automatically.
  /// When `false`, the flag is removed from the defaults.
  ///
  /// Individual components can still override via [clearAttr]/[setAttr].
  AclBuilder setAclExpandXDefault(bool enabled) {
    if (enabled) {
      _defaultFlags |= AclFlags.expandX;
    } else {
      _defaultFlags &= ~AclFlags.expandX;
    }
    return this;
  }

  /// Sets the default horizontal gap inserted before every appended
  /// component of every row, including the first component.
  ///
  /// Applies only when the individual [append] call does not specify a
  /// non-zero `dist`. Pass [gap] = 0 to disable (the built-in default is 8).
  ///
  /// [gapBpOverrides] is a list of `(minWidth, gap)` pairs; at render time
  /// the pair with the highest `minWidth <= availableWidth` wins.
  AclBuilder setAclDefaultAppendGap(
    double gap, [
    List<(double, double)> gapBpOverrides = const [],
  ]) {
    _defaultAppendGap = gap;
    _defaultAppendGapBpOverrides = gapBpOverrides;
    return this;
  }

  /// Sets the builder-wide default row height (null = intrinsic).
  ///
  /// Applied to every row that does not set its own height via
  /// [setRowHeight] or [newRow]'s `height:` parameter.
  /// [heightBpOverrides] is a list of `(minWidth, height?)` pairs.
  AclBuilder setAclDefaultRowHeight(
    double? height, [
    List<(double, double?)> heightBpOverrides = const [],
  ]) {
    _defaultRowHeight = height;
    _defaultRowHeightBpOverrides = heightBpOverrides;
    return this;
  }

  /// Sets the height on the current (most-recently-started) row.
  ///
  /// [heightBpOverrides] follows the same `(minWidth, height?)` shape as
  /// [setAclDefaultRowHeight]. Passing `null` height with an empty overrides
  /// list clears the row-level override (the builder default applies).
  AclBuilder setRowHeight(
    double? height, [
    List<(double, double?)> heightBpOverrides = const [],
  ]) {
    _currentRow.height = height;
    _currentRow.heightBpOverrides = heightBpOverrides;
    _currentRow.heightIsExplicit = true;
    return this;
  }

  /// Sets the default vertical gap (in pixels) inserted before each new
  /// content row started with [newRow].
  ///
  /// Only applies when the individual [newRow] call does not specify a
  /// non-zero `dist`. Pass 0 to disable (the default).
  AclBuilder setAclDefaultRowGap(int pixels) {
    _defaultRowGap = pixels.toDouble();
    return this;
  }

  /// Sets the default vertical cross-axis alignment applied to every
  /// component of every row of this ACL instance.
  ///
  /// The global builder default is [AclRowCrossAlignment.top] — chosen
  /// so that fields whose height grows (e.g. when an error message
  /// appears below the input) do not drag their neighbours off the
  /// baseline. Set to [AclRowCrossAlignment.center] or
  /// [AclRowCrossAlignment.bottom] for non-form layouts where the
  /// centre/bottom line is the visual anchor.
  ///
  /// Per-component overrides via `alignTopInRow() / alignMiddleInRow() /
  /// alignBottomInRow()` still win for that component.
  AclBuilder setAclDefaultRowAlignment(AclRowCrossAlignment alignment) {
    _defaultRowCrossAlignment = alignment;
    // Retroactively apply to any already-appended components that did not
    // have an explicit override — keeps call order flexible.
    for (final row in _rows) {
      for (final comp in row.components) {
        if (!comp.rowCrossAlignmentSet) {
          comp.rowCrossAlignment = alignment;
        }
      }
    }
    return this;
  }

  /// Sets a default minimum size for components that do not have an explicit
  /// minimum size ([setMSize] / [setMWidthInChars]).
  ///
  /// Pass 0 for [width] or [height] to leave that dimension untouched
  /// (i.e. no default minimum is applied on that axis).
  ///
  /// **Note:** setting a minimum that is smaller than the preferred size has no
  /// visible effect — the preferred size already acts as the floor. Setting a
  /// minimum that is *larger* than the preferred size in combination with
  /// [expandX] components creates a "grow up to preferred, then distribute
  /// remainder to expandX" behaviour (see §6).
  AclBuilder setAclDefaultUnknownMinimumSize(double width, [double height = 0]) {
    _defaultUnknownMinimumSize = Size(width, height);
    return this;
  }

  /// Sets a default preferred size for components that do not have an explicit
  /// preferred size ([setPSize] / [setPWidthInChars]).
  ///
  /// Replaces the built-in default of 150 × 0. Pass 0 for [width] to keep
  /// the built-in default width (150); pass 0 for [height] to keep the
  /// default height of 0 (unconstrained).
  AclBuilder setAclDefaultUnknownPreferredSize(double width, [double height = 0]) {
    _defaultUnknownPreferredSize = Size(width, height);
    return this;
  }

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

  AclBuilder setAclPaddingPx(double left, double top, double right, double bottom) {
    _padding = EdgeInsets.fromLTRB(left, top, right, bottom);
    return this;
  }

  AclBuilder setAclPaddingTop(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(resolved.left, value, resolved.right, resolved.bottom);
    return this;
  }

  AclBuilder setAclPaddingBottom(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(resolved.left, resolved.top, resolved.right, value);
    return this;
  }

  AclBuilder setAclPaddingLeft(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(value, resolved.top, resolved.right, resolved.bottom);
    return this;
  }

  AclBuilder setAclPaddingRight(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(resolved.left, resolved.top, value, resolved.bottom);
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

  /// Sets whether this container's ID contributes to descendant paths.
  ///
  /// - `true` — identity container: descendants see `c-<id>` in their paths.
  /// - `false` — layout container (default): ID is for own resources/auth only.
  AclBuilder setAclIdScope(bool idScope) {
    _idScope = idScope;
    return this;
  }

  AclBuilder setRowId(String id) {
    _currentRow.id = id;
    return this;
  }

  /// Sets whether the current row's ID contributes to descendant paths.
  ///
  /// - `true` — identity row: components inside see `rw-<id>` in their paths.
  /// - `false` — layout row (default): ID is for own resources/auth only.
  AclBuilder setRowIdScope(bool idScope) {
    _currentRow.idScope = idScope;
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
      rows: variantBuilder._rows
          .map((r) => r.toRow(
                defaultAppendGap: variantBuilder._defaultAppendGap,
                defaultAppendGapBpOverrides:
                    variantBuilder._defaultAppendGapBpOverrides,
                fallbackHeight: variantBuilder._defaultRowHeight,
                fallbackHeightBpOverrides:
                    variantBuilder._defaultRowHeightBpOverrides,
              ))
          .toList(),
    ));
    return this;
  }

  // ── Row Breakpoints (§28) ──────────────────────────────────────────────────

  /// Adds a row breakpoint at the current position in the builder chain.
  ///
  /// The split index is calculated from the number of components appended so
  /// far. Call this **between** `append()` calls to indicate where the row
  /// should break when the container width drops below [atWidth].
  AclBuilder addRowBreakpoint({
    required double atWidth,
    double splitRowDist = 0,
  }) {
    _currentRow.breakpoints.add(AclRowBreakpoint(
      atWidth: atWidth,
      splitAfter: _currentRow.components.length,
      splitRowDist: splitRowDist,
    ));
    return this;
  }

  // ── Inline Component Variants (§29) ────────────────────────────────────────

  AclBuilder startVariant({
    double? width,
    double? height,
    AclInputMode? input,
    AclFormFactor? formFactor,
    Orientation? orientation,
    Set<TargetPlatform>? platforms,
    bool? isWeb,
    AclDensity? density,
    TextDirection? textDirection,
    double? minAccessibilityScale,
    AclVariantDetector? detector,
  }) {
    if (_inVariantBlock) {
      throw StateError(
        'AclBuilder.startVariant(): already inside a variant block. '
        'Call endVariant() before starting a new one.',
      );
    }
    _inVariantBlock = true;
    _currentVariantDetector = detector ??
        AclDeviceContext.buildConvenienceDetector(
          width: width,
          height: height,
          input: input,
          formFactor: formFactor,
          orientation: orientation,
          platforms: platforms,
          isWeb: isWeb,
          density: density,
          textDirection: textDirection,
          minAccessibilityScale: minAccessibilityScale,
        );
    return this;
  }

  AclBuilder endVariant() {
    if (!_inVariantBlock) {
      throw StateError(
        'AclBuilder.endVariant(): not inside a variant block. '
        'Call startVariant() first.',
      );
    }
    _inVariantBlock = false;
    _currentVariantDetector = null;
    return this;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  /// Sets the layout direction for this container (see §30).
  AclBuilder setAclDirection(AclDirection direction) {
    _direction = direction;
    return this;
  }

  Acl build() {
    _finalizeCurrentComponent();
    // Sort variants by atWidth ascending so the narrowest (most specific)
    // variant matches first during selection.
    final sortedVariants = List<AclVariant>.from(_variants)
      ..sort((a, b) => a.atWidth.compareTo(b.atWidth));

    return Acl(
      rows: _rows
          .map((row) => row.toRow(
                defaultAppendGap: _defaultAppendGap,
                defaultAppendGapBpOverrides: _defaultAppendGapBpOverrides,
                fallbackHeight: _defaultRowHeight,
                fallbackHeightBpOverrides: _defaultRowHeightBpOverrides,
              ))
          .toList(),
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
      idScope: _idScope,
      aclGroup: _aclGroup,
      parentIdPath: _parentIdPath,
      groupVisibilityControllers: Map.unmodifiable(_groupVisibilityControllers),
      variants: sortedVariants,
      direction: _direction,
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
