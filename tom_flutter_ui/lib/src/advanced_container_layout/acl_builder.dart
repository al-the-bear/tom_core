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

  /// Whether [preferredSize]'s width was fabricated by
  /// [_finalizeCurrentComponent] rather than declared by the author.
  bool preferredWidthIsDefault = false;
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
  bool? hideUnauthorized;

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
      preferredWidthIsDefault: preferredWidthIsDefault,
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
      hideUnauthorized: hideUnauthorized,
    );
  }
}

class _RowData {
  List<_ComponentData> components = [];
  RowAlignment alignment = RowAlignment.left;

  /// Whether [alignment] was set explicitly via `setRowHorizontalAlignment`
  /// (as opposed to inherited from the builder-wide default at row creation).
  /// Mirrors the vertical axis' `rowCrossAlignment == null` "not set yet"
  /// signal so a later default change can apply retroactively without
  /// clobbering explicit per-row overrides.
  ///
  /// [alignment] cannot carry that signal itself: it is non-nullable and every
  /// row starts at the builder default, so "still at the default" and "was
  /// explicitly set to the same value as the default" are indistinguishable
  /// without this flag. `setAclDefaultRowHorizontalAlignment` reads it to
  /// decide which already-created rows it may rewrite.
  bool alignmentSet = false;
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

  /// Per-row cross-axis alignment override. `null` means "use the
  /// builder's default" (set via `setAclDefaultRowVerticalAlignment`).
  AclRowCrossAlignment? rowCrossAlignment;

  AclRow toRow({
    required double defaultAppendGap,
    required List<(double, double)> defaultAppendGapBpOverrides,
    required double? fallbackHeight,
    required List<(double, double?)> fallbackHeightBpOverrides,
    required AclRowCrossAlignment defaultRowCrossAlignment,
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
      heightBpOverrides: heightIsExplicit
          ? heightBpOverrides
          : fallbackHeightBpOverrides,
      defaultAppendGap: defaultAppendGap,
      defaultAppendGapBpOverrides: defaultAppendGapBpOverrides,
      // Per-row override beats the builder-wide default.
      defaultRowCrossAlignment: rowCrossAlignment ?? defaultRowCrossAlignment,
    );
  }
}

/// Fluent builder for [Acl] layout containers.
class AclBuilder {
  final List<_RowData> _rows = [];
  _RowData _currentRow = _RowData();
  _ComponentData? _currentComponent;

  /// The component every per-component call applies to.
  ///
  /// Throws [StateError], naming the caller it was given, when there is none.
  /// That happens before the first [append], and after [gap], [newRow] or
  /// [gapRow] — each of which clears the current component, because none of
  /// them is a target for per-component settings.
  ///
  /// Throwing rather than returning is the point. A per-component call with no
  /// component is always a misordered chain, and the value the caller wrote is
  /// being dropped: `append(x).gap().setPSize(200)` sizes nothing, and the
  /// component keeps whatever it had. Nothing reports that, and the layout
  /// merely comes out subtly wrong — which is far more expensive to find than
  /// a throw at the call that is wrong.
  ///
  /// The cost is the conditional-append pattern — `if (x) b.append(...);
  /// b.setPSize(...)` — which now has to put the call inside the condition.
  /// That is where it belonged: outside, it was silently doing nothing on the
  /// branch the author was not thinking about.
  _ComponentData _requireComponent(String setter) {
    final component = _currentComponent;
    if (component == null) {
      throw StateError(
        '$setter must be called on a component: put it directly after '
        'append(), and before any gap(), newRow() or gapRow(). There is no '
        'current component here, so the value would be discarded.',
      );
    }
    return component;
  }

  int _defaultFlags = 0;
  double _defaultAppendGap = 8.0;
  List<(double, double)> _defaultAppendGapBpOverrides = const [];
  double? _defaultRowHeight;
  List<(double, double?)> _defaultRowHeightBpOverrides = const [];
  double _defaultRowGap = 8;
  Size? _defaultUnknownMinimumSize;
  Size? _defaultUnknownPreferredSize;
  AclRowCrossAlignment _defaultRowVerticalAlignment = AclRowCrossAlignment.top;
  RowAlignment _defaultRowHorizontalAlignment = RowAlignment.left;
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

  /// Every appended widget that can carry a component key, by identity.
  ///
  /// One map rather than two — the key and the row are written together and
  /// every reference check needs both, so an entry that has one and not the
  /// other is not a state this can reach.
  final Map<Widget, ({Key key, _RowData row})> _appended =
      Map<Widget, ({Key key, _RowData row})>.identity();

  /// Appended widgets that carry no component key — `Flexible`, `Expanded`
  /// and `Spacer`, which the row lays out itself. Kept so a reference to one
  /// can be told apart from a reference to a widget that was never appended.
  final Set<Widget> _unkeyedChildren = Set<Widget>.identity();

  // IDs
  String? _aclId;
  bool _idScope = false;

  // Groups
  String? _aclGroup;
  String? _activeGroupName;

  // Visibility
  final Map<String, AclGroupVisibilityController> _groupVisibilityControllers =
      {};

  // Variants
  final List<AclVariant> _variants = [];

  /// Default hide-when-unauthorized behaviour applied to every component
  /// whose own [AclComponent.hideUnauthorized] is `null`. See
  /// [setAclDefaultHideUnauthorized].
  bool _defaultHideUnauthorized = false;

  // Inline Component Variants
  bool _inVariantBlock = false;
  AclVariantDetector? _currentVariantDetector;

  // Layout Direction
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
  }) : _title = title,
       _titleWidget = titleWidget,
       _borderStyle = borderStyle,
       _focusedBorderStyle = focusedBorderStyle,
       _padding = padding,
       _backgroundColor = backgroundColor,
       _titleStyle = titleStyle,
       _titlePosition = titlePosition,
       _titleBorderAlign = titleBorderAlign,
       _titleVerticalOffset = titleVerticalOffset {
    _currentRow.alignment = _defaultRowHorizontalAlignment;
    _rows.add(_currentRow);
  }

  // ── Component placement ────────────────────────────────────────────────────

  /// Default preferred width for components without an explicit preferred size
  /// and no custom [setAclDefaultUnknownPreferredSize].
  ///
  /// Large enough to prevent buttons/small widgets from collapsing next to
  /// elastic gaps, but still participates proportionally in the grow/shrink
  /// distribution alongside explicitly sized components.
  ///
  /// This is a **floor, not a cap**. A component that is appended without a
  /// size hint and whose content needs more than this takes the width its
  /// content needs; only content that fits inside the default is held at the
  /// default. See [append] for the full contract.
  static const double defaultPreferredWidth = 150;

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
          dp.width == 0 ? defaultPreferredWidth : dp.width,
          dp.height,
        );
      } else {
        c.preferredSize = const Size(defaultPreferredWidth, 0);
      }
      // Why: the container must be able to tell this fabricated width from one
      // the author actually asked for. An author-declared width is honoured
      // literally; a defaulted one is only a floor, and the container measures
      // the child and widens the component when its content needs more. Without
      // the flag both look identical downstream and the default becomes a cap —
      // which is what used to turn a forgotten size hint into a RenderFlex
      // overflow instead of a component that simply fits.
      c.preferredWidthIsDefault = true;
    }
    // Apply default minimum size if none was explicitly set. Unlike the
    // preferred size above, 0 needs no special case here: a minimum of 0 *is*
    // "no minimum on that axis", which is what passing 0 asks for.
    if (c.minimumSize == null && _defaultUnknownMinimumSize != null) {
      c.minimumSize = _defaultUnknownMinimumSize;
    }
  }

  /// Appends a component to the current row.
  ///
  /// ## Sizing a component that is appended without a hint
  ///
  /// A component that gets no [setPSize] / [setMSize] / [setXSize] and no
  /// [expandX] is given [defaultPreferredWidth] — but as a **floor**, not a cap:
  ///
  /// * content that fits inside the default occupies the default, so a button
  ///   or a short label does not collapse next to an elastic gap;
  /// * content that needs more — a `Row` of controls, say, which cannot shrink
  ///   below the sum of its children — is measured and the component is widened
  ///   to what the content needs, then takes part in the row's fit/shrink
  ///   distribution at that width;
  /// * content that still does not fit the row is **clipped**, never
  ///   overflowed. The child keeps the width it laid out at, so narrowing the
  ///   container changes how much of the component is visible and nothing else.
  ///
  /// Measurement lands one frame after the component first renders; until then
  /// the plain default applies and the clip covers the difference.
  ///
  /// Sizing hints are therefore about *intent* — "this field is 220 wide",
  /// "these two line up" — not about preventing overflow. Overflow is the
  /// container's problem, and it has been made incapable of showing one.
  AclBuilder append(Widget child, {double dist = 0}) {
    _finalizeCurrentComponent();
    // `Expanded` is a `Flexible`; `Spacer` is neither, and is named because it
    // renders as one.
    final canAttachComponentKey = child is! Flexible && child is! Spacer;
    for (final instance in _instancesOf(child)) {
      if (!_alreadyAppended(instance)) continue;
      throw UnsupportedError(
        identical(instance, child)
            ? 'AclBuilder: the same widget instance was appended more than '
                  'once. Each component must be a distinct object so '
                  'identity-based lookup and key generation stay unambiguous. '
                  'Build a second instance — or, for elastic space, use gap().'
            : 'AclBuilder: this ${child.runtimeType} wraps a widget that was '
                  'already appended. The wrapper is new but its child is not, '
                  'so the same widget would be built in two places and a '
                  'reference to it could mean either.',
      );
    }
    // When the caller did not pass an explicit non-zero `dist`, tag the
    // component so the container can resolve the row's breakpoint-aware
    // default gap at render time instead of baking it in now.
    final usesDefaultGap = dist == 0;
    final componentKey = canAttachComponentKey ? _newComponentKey() : null;
    _currentComponent = _ComponentData(
      child: child,
      flags: _defaultFlags,
      gapBefore: usesDefaultGap ? 0 : dist,
      gapBeforeIsDefault: usesDefaultGap,
      componentKey: componentKey,
    );
    // Components inherit the row's vertical alignment (if the row set
    // one via setRowVerticalAlignment / setRowAlignTop / Middle /
    // Bottom), otherwise fall back to the builder-wide default.
    // Per-component overrides via [setVerticalAlignment] still win by
    // setting `rowCrossAlignmentSet = true`.
    _currentComponent!.rowCrossAlignment =
        _currentRow.rowCrossAlignment ?? _defaultRowVerticalAlignment;
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
      _appended[child] = (key: componentKey, row: _currentRow);
    } else {
      _unkeyedChildren.addAll(_instancesOf(child));
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
    final effectiveDist = (dist == 0 && _defaultRowGap > 0)
        ? _defaultRowGap
        : dist;
    _currentRow = _RowData()
      ..gapBefore = effectiveDist
      ..alignment = _defaultRowHorizontalAlignment;
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
  AclBuilder gapRow({
    double weight = 1,
    AclSeparator? separator,
    double minSize = 0,
  }) {
    _finalizeCurrentComponent();
    final gapRowData = _RowData()
      ..isGapRow = true
      ..gapRowWeight = weight
      ..separator = separator
      ..gapRowMinSize = minSize;
    _rows.add(gapRowData);
    // Implicitly start a fresh content row after the gap row
    _currentRow = _RowData()..alignment = _defaultRowHorizontalAlignment;
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
    final component = _requireComponent('setPSize');
    final cur = component.preferredSize;
    component.preferredSize = Size(
      width == 0 ? (cur?.width ?? 0) : width,
      height == 0 ? (cur?.height ?? 0) : height,
    );
    return this;
  }

  /// Sets a minimum size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value, or defaulting to 0 / 0).
  AclBuilder setMSize(double width, [double height = 0]) {
    final component = _requireComponent('setMSize');
    final cur = component.minimumSize;
    component.minimumSize = Size(
      width == 0 ? (cur?.width ?? 0) : width,
      height == 0 ? (cur?.height ?? 0) : height,
    );
    return this;
  }

  /// Sets a maximum size on the current component.
  ///
  /// Pass 0 for [width] or [height] to leave that dimension unchanged
  /// (preserving any previously set value, or leaving it **unconstrained**
  /// when none was set).
  ///
  /// The unset fallback is `double.infinity`, not 0 as it is on [setPSize]
  /// and [setMSize]. A preferred or minimum of 0 is no constraint, so those
  /// two can share the sentinel; a *maximum* of 0 means "no size at all", and
  /// the container turns it into `BoxConstraints(maxHeight: 0)` faithfully
  /// enough to collapse the child. `setXSize(200)` therefore caps the width
  /// and says nothing about the height, which is what it reads as.
  /// [setXWidthInChars] uses the same fallback for the same reason.
  AclBuilder setXSize(double width, [double height = 0]) {
    final component = _requireComponent('setXSize');
    final cur = component.maximumSize;
    component.maximumSize = Size(
      width == 0 ? (cur?.width ?? double.infinity) : width,
      height == 0 ? (cur?.height ?? double.infinity) : height,
    );
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
    final component = _requireComponent('setPWidthInChars');
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = component.preferredSize?.height ?? height;
    component.preferredSize = Size(width, currentHeight);
    return this;
  }

  /// Sets the **minimum** width of the current component using a character-count.
  /// Preserves the existing minimum height (defaults to 0 if unset).
  AclBuilder setMWidthInChars(int chars, {double charWidth = 8}) {
    final component = _requireComponent('setMWidthInChars');
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = component.minimumSize?.height ?? 0.0;
    component.minimumSize = Size(width, currentHeight);
    return this;
  }

  /// Sets the **maximum** width of the current component using a character-count.
  /// Preserves the existing maximum height (defaults to infinity if unset).
  AclBuilder setXWidthInChars(int chars, {double charWidth = 8}) {
    final component = _requireComponent('setXWidthInChars');
    final width = (chars * charWidth).clamp(0.0, double.maxFinite);
    final currentHeight = component.maximumSize?.height ?? double.infinity;
    component.maximumSize = Size(width, currentHeight);
    return this;
  }

  // ── Per-component flags ────────────────────────────────────────────────────

  AclBuilder setAttr(int attr) {
    _requireComponent('setAttr').flags |= attr;
    return this;
  }

  AclBuilder clearAttr(int newAttr) {
    _requireComponent('clearAttr').flags &= ~newAttr;
    return this;
  }

  // ── Per-component size references ──────────────────────────────────────────

  /// Links the current component's size to [reference]'s rendered size.
  ///
  /// [otherAttr] must carry at least one of [AclFlags.otherDimX] /
  /// [AclFlags.otherDimY]; only those bits are taken from it. Anything else
  /// would record a reference the layout never reads — a link that exists in
  /// the component and does nothing.
  AclBuilder setComp(Widget reference, int otherAttr) {
    final component = _requireComponent('setComp');
    final dimensions = otherAttr & AclFlags.otherDim;
    if (dimensions == 0) {
      throw ArgumentError.value(
        otherAttr,
        'otherAttr',
        'setComp needs AclFlags.otherDimX, AclFlags.otherDimY or '
            'AclFlags.otherDim — without one the reference is recorded and '
            'never read. Use sameWidthAs / sameHeightAs / sameSize instead.',
      );
    }
    final entry = _requireAppended(
      reference,
      'sameWidthAs / sameHeightAs / sameSize',
    );
    if (entry.row == _currentRow) {
      throw UnsupportedError(
        'AclBuilder: sameWidthAs / sameHeightAs / sameSize cannot reference a '
        'component in the same row. Move the reference to a different row, '
        'or use a cross-row anchor.',
      );
    }
    component.referenceKey = entry.key;
    component.flags |= dimensions;
    return this;
  }

  AclBuilder sameWidthAs(Widget reference) =>
      setComp(reference, AclFlags.otherDimX);

  AclBuilder sameHeightAs(Widget reference) =>
      setComp(reference, AclFlags.otherDimY);

  AclBuilder sameSize(Widget reference) =>
      setComp(reference, AclFlags.otherDim);

  // ── Per-component vertical alignment ──────────────────────────────────────

  /// Overrides the vertical (cross-axis) alignment for the **current
  /// component only**, taking precedence over the row's and builder's
  /// default. Components only have one axis of alignment inside a row —
  /// horizontal placement is a whole-row concern — so a single method
  /// with an [AclRowCrossAlignment] argument covers every case.
  AclBuilder setVerticalAlignment(AclRowCrossAlignment align) {
    final component = _requireComponent('setVerticalAlignment');
    if (component.alignYToKey != null) {
      throw UnsupportedError(
        'AclBuilder.setVerticalAlignment() cannot be combined with an '
        'alignY* method on the same component — alignY* overrides the '
        'row cross-alignment.',
      );
    }
    component.rowCrossAlignment = align;
    component.rowCrossAlignmentSet = true;
    return this;
  }

  // ── Cross-row horizontal alignment ────────────────────────────────────────

  AclBuilder alignLeftToLeft(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignLeftToCenter(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignLeftToRight(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.left,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignCenterToLeft(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignCenterToCenter(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignCenterToRight(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.center,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  AclBuilder alignRightToLeft(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.left,
        gap: gap,
      );

  AclBuilder alignRightToCenter(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.center,
        gap: gap,
      );

  AclBuilder alignRightToRight(Widget reference, {double gap = 0}) =>
      _setHorizontalAlignment(
        reference: reference,
        selfPoint: AclAxisPointX.right,
        referencePoint: AclAxisPointX.right,
        gap: gap,
      );

  // ── Same-row vertical alignment ───────────────────────────────────────────

  AclBuilder alignTopToTop(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignTopToMiddle(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignTopToBottom(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.top,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignMiddleToTop(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignMiddleToMiddle(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignMiddleToBottom(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.center,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  AclBuilder alignBottomToTop(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.top,
        gap: gap,
      );

  AclBuilder alignBottomToMiddle(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.center,
        gap: gap,
      );

  AclBuilder alignBottomToBottom(Widget reference, {double gap = 0}) =>
      _setVerticalAlignment(
        reference: reference,
        selfPoint: AclAxisPointY.bottom,
        referencePoint: AclAxisPointY.bottom,
        gap: gap,
      );

  // ── Row-level alignment ───────────────────────────────────────────────────
  //
  // Two orthogonal axes:
  //   * Horizontal — where components sit along the row's main axis
  //     (RowAlignment.left / center / right). Set via
  //     [setRowHorizontalAlignment] or the [setRowAlignLeft] / Center /
  //     Right shortcuts.
  //   * Vertical — where components sit along the row's cross axis
  //     (AclRowCrossAlignment.top / center / bottom). Set via
  //     [setRowVerticalAlignment] or the [setRowAlignTop] / Middle /
  //     Bottom shortcuts.
  //
  // Components inherit the row's vertical alignment unless they opt out
  // via [setVerticalAlignment]. The row itself falls back to the
  // builder-wide default (see [setAclDefaultRowVerticalAlignment] and
  // [setAclDefaultRowHorizontalAlignment]).

  /// Horizontal main-axis placement for the **current row only**.
  AclBuilder setRowHorizontalAlignment(RowAlignment align) {
    _currentRow.alignment = align;
    _currentRow.alignmentSet = true;
    return this;
  }

  /// Vertical cross-axis placement for the **current row only**.
  ///
  /// Components appended to this row — before OR after this call —
  /// inherit the row's alignment unless they explicitly override via
  /// [setVerticalAlignment]. Without this call the row inherits the
  /// builder-wide default (see [setAclDefaultRowVerticalAlignment]).
  AclBuilder setRowVerticalAlignment(AclRowCrossAlignment align) {
    _currentRow.rowCrossAlignment = align;
    // Retroactively propagate to components in the current row that
    // haven't set their own alignment. New components appended after
    // this call inherit via [_onComponentAppended] (see append()).
    for (final comp in _currentRow.components) {
      if (!comp.rowCrossAlignmentSet) {
        comp.rowCrossAlignment = align;
      }
    }
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

  /// Replaces the default [AclFlags] register applied to every subsequent
  /// [append]. The built-in default is 0 — no flags.
  ///
  /// Prefer [setAclExpandXDefault] for the common single-flag case; it adds
  /// or removes one flag rather than replacing the whole register.
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
  /// non-zero `dist`. Pass 0 to disable (the built-in default is 8).
  AclBuilder setAclDefaultRowGap(int pixels) {
    _defaultRowGap = pixels.toDouble();
    return this;
  }

  /// Sets the builder-wide default for the hide-when-unauthorized
  /// behaviour. When `true`, every appended component whose child
  /// implements [TomAuthorizable] and currently evaluates to
  /// [TomAuthState.none] is **dropped from the row** at build time;
  /// the `gapBefore` of the component that follows it is also dropped
  /// so the next visible component takes the hidden component's slot.
  /// When a row is left with no components it is dropped in turn, along
  /// with the next row's `gapBefore`.
  ///
  /// The default is `false`, which switches this pass off. That does **not**
  /// leave unauthorized elements visible: a row or component carrying an `id`
  /// is separately gated at render time on `TomAuthorization.resolveAuth` of
  /// its policy path, and that gate never consults this flag. It also runs too
  /// late to move a gap, so its arithmetic comes out the other way round — a
  /// denied component keeps **both** adjacent gaps, and a denied row loses its
  /// own. See "Not this mechanism: the id-based policy gates" in
  /// `doc/acl_design_specification.md` §26b, and
  /// `test/advanced_container_layout/acl_auth_visibility_test.dart` for the
  /// measured numbers.
  ///
  /// With this pass off and no id to gate on, a component renders whatever its
  /// own self-shrink-on-`none` path produces, inside its preserved gap.
  ///
  /// Override per-component with [setHideUnauthorized].
  AclBuilder setAclDefaultHideUnauthorized(bool value) {
    _defaultHideUnauthorized = value;
    return this;
  }

  /// Overrides the container's hide-when-unauthorized default for the
  /// most recently appended component. Pass `null` to clear the override
  /// and fall back to the container default.
  ///
  /// See [setAclDefaultHideUnauthorized] for the full semantics.
  AclBuilder setHideUnauthorized(bool? value) {
    _requireComponent('setHideUnauthorized').hideUnauthorized = value;
    return this;
  }

  /// Builder-wide default for the **vertical** cross-axis placement of
  /// every row. Individual rows override via [setRowVerticalAlignment];
  /// individual components override via [setVerticalAlignment].
  ///
  /// The factory default is [AclRowCrossAlignment.top] — chosen so that
  /// fields whose height grows (e.g. when an error message appears
  /// below the input) do not drag their neighbours down off the row's
  /// top edge.
  AclBuilder setAclDefaultRowVerticalAlignment(AclRowCrossAlignment alignment) {
    _defaultRowVerticalAlignment = alignment;
    // Retroactively apply to rows and components that haven't set their
    // own alignment — keeps call order flexible.
    for (final row in _rows) {
      if (row.rowCrossAlignment == null) {
        for (final comp in row.components) {
          if (!comp.rowCrossAlignmentSet) {
            comp.rowCrossAlignment = alignment;
          }
        }
      }
    }
    return this;
  }

  /// Builder-wide default for the **horizontal** main-axis placement of
  /// every row. Individual rows override via [setRowHorizontalAlignment]
  /// or the Left/Center/Right shortcuts.
  ///
  /// The factory default is [RowAlignment.left].
  AclBuilder setAclDefaultRowHorizontalAlignment(RowAlignment alignment) {
    _defaultRowHorizontalAlignment = alignment;
    // Retroactively apply to every row that hasn't set its own alignment —
    // including the eagerly-created first row — so call order stays flexible.
    // Rows that called setRowHorizontalAlignment keep their own value.
    for (final row in _rows) {
      if (!row.alignmentSet) {
        row.alignment = alignment;
      }
    }
    return this;
  }

  /// Sets a default minimum size for components that do not have an explicit
  /// minimum size ([setMSize] / [setMWidthInChars]).
  ///
  /// There is no built-in default: unless this is called, a component without
  /// an explicit minimum keeps a null minimum size.
  ///
  /// [width] and [height] are stored verbatim, including zeros, and a later
  /// call replaces **both** dimensions — there is no per-axis fallback and no
  /// previous value to fall back on. A 0 therefore means "a minimum of 0 on
  /// that axis", which the layout cannot tell apart from no minimum at all;
  /// that is what makes storing it harmless, not a special case that skips it.
  /// Contrast [setMSize], which does leave a dimension alone on a 0, because a
  /// component it targets already has a minimum to leave alone.
  ///
  /// **Note:** setting a minimum that is smaller than the preferred size has no
  /// visible effect — the preferred size already acts as the floor. Setting a
  /// minimum that is *larger* than the preferred size in combination with
  /// [expandX] components creates a "grow up to preferred, then distribute
  /// remainder to expandX" behaviour — see "Row Sizing — Three Phases" (§6)
  /// in `doc/acl_design_specification.md`.
  AclBuilder setAclDefaultUnknownMinimumSize(
    double width, [
    double height = 0,
  ]) {
    _defaultUnknownMinimumSize = Size(width, height);
    return this;
  }

  /// Sets a default preferred size for components that do not have an explicit
  /// preferred size ([setPSize] / [setPWidthInChars]).
  ///
  /// Replaces the built-in default of 150 × 0.
  ///
  /// A 0 [width] falls back to [defaultPreferredWidth] — the *factory* 150,
  /// not whatever an earlier call to this setter passed. [height] has no such
  /// fallback: it is stored verbatim, and 0 leaves the height unconstrained
  /// because 0 already is the built-in height.
  ///
  /// This is the only 0-means-fall-back among the builder-wide setters;
  /// [setAclDefaultUnknownMinimumSize] stores its zeros, and the two gap
  /// setters read 0 as "off".
  AclBuilder setAclDefaultUnknownPreferredSize(
    double width, [
    double height = 0,
  ]) {
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

  AclBuilder setAclPaddingPx(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    _padding = EdgeInsets.fromLTRB(left, top, right, bottom);
    return this;
  }

  AclBuilder setAclPaddingTop(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      resolved.left,
      value,
      resolved.right,
      resolved.bottom,
    );
    return this;
  }

  AclBuilder setAclPaddingBottom(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      resolved.left,
      resolved.top,
      resolved.right,
      value,
    );
    return this;
  }

  AclBuilder setAclPaddingLeft(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      value,
      resolved.top,
      resolved.right,
      resolved.bottom,
    );
    return this;
  }

  AclBuilder setAclPaddingRight(double value) {
    final resolved = _padding.resolve(TextDirection.ltr);
    _padding = EdgeInsets.fromLTRB(
      resolved.left,
      resolved.top,
      value,
      resolved.bottom,
    );
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

  // ── IDs ────────────────────────────────────────────────────────────────────

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
    _requireComponent('setId').id = id;
    return this;
  }

  // ── Groups ─────────────────────────────────────────────────────────────────

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
    _requireComponent('group').group = name;
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

  // ── Visibility ─────────────────────────────────────────────────────────────

  AclBuilder setGroupVisibilityController(
    String groupName,
    AclGroupVisibilityController controller,
  ) {
    _groupVisibilityControllers[groupName] = controller;
    return this;
  }

  // ── Responsive Variants ────────────────────────────────────────────────────

  /// Registers a replacement row tree used when the container's available
  /// width drops below [atWidth]. Variants are matched narrowest-first, so the
  /// most specific one wins.
  ///
  /// **The variant builder does not inherit this builder's defaults.** It is a
  /// fresh [AclBuilder], so every `setAclDefault*` value configured here —
  /// append gap, row gap, row height, row alignments, flags, unknown preferred
  /// and minimum sizes — is back at its framework default inside [builder].
  /// Restate the ones the variant needs:
  ///
  /// ```dart
  /// AclBuilder()
  ///     .setAclDefaultAppendGap(16)
  ///     .append(street).append(number)
  ///     .addVariant('narrow', atWidth: 480, builder: (b) => b
  ///         .setAclDefaultAppendGap(16)   // restate: not inherited
  ///         .append(street)
  ///         .newRow()
  ///         .append(number));
  /// ```
  ///
  /// The container's *chrome* — border, padding, background, title — is
  /// unaffected by which variant is active, because it belongs to the
  /// container rather than to any row tree. A variant supplies rows and
  /// nothing else.
  ///
  /// `test/advanced_container_layout/acl_variant_inheritance_test.dart` pins
  /// both halves of this.
  /// Copies every builder-wide **row-level** default onto [target].
  ///
  /// Used by [addVariant] so a variant's rows are built against the same
  /// defaults as the container's own. Each field here is one a row or a
  /// component reads while it is being appended; a field the container reads at
  /// [build] time is deliberately absent, and
  /// `test/advanced_container_layout/acl_variant_inheritance_test.dart`
  /// classifies every `_default*` field one way or the other, so a new one
  /// cannot quietly be neither.
  ///
  /// [target] must be freshly constructed and untouched: the row alignment is
  /// stamped onto a row when the row is *created*, and the constructor has
  /// already created the first one, so this restamps it. A target that had
  /// rows appended would have them silently realigned.
  void _copyRowDefaultsTo(AclBuilder target) {
    target._defaultFlags = _defaultFlags;
    target._defaultAppendGap = _defaultAppendGap;
    target._defaultAppendGapBpOverrides = _defaultAppendGapBpOverrides;
    target._defaultRowHeight = _defaultRowHeight;
    target._defaultRowHeightBpOverrides = _defaultRowHeightBpOverrides;
    target._defaultRowGap = _defaultRowGap;
    target._defaultUnknownMinimumSize = _defaultUnknownMinimumSize;
    target._defaultUnknownPreferredSize = _defaultUnknownPreferredSize;
    target._defaultRowVerticalAlignment = _defaultRowVerticalAlignment;
    target._defaultRowHorizontalAlignment = _defaultRowHorizontalAlignment;
    // The alignment is applied at row *creation*, and the target's first row
    // was created by its constructor — before these defaults arrived. Later
    // rows pick it up from `newRow`; this one has to be told.
    target._currentRow.alignment = _defaultRowHorizontalAlignment;
  }

  AclBuilder addVariant(
    String name, {
    required double atWidth,
    required void Function(AclBuilder) builder,
  }) {
    // The variant restates its rows; it does not restate the defaults those
    // rows are built against. Copying them across *before* the callback runs
    // is what makes that true: `append` and `newRow` read these as they go, so
    // a default set afterwards would not reach the rows already built. An
    // explicit setting inside the variant still wins — it simply overwrites
    // the inherited value on the way past.
    //
    // Only row-level defaults travel. The container's own settings — chrome,
    // `aclId`, `idScope`, `aclGroup`, `defaultHideUnauthorized` — are read
    // from *this* builder when `build()` runs and land on the container
    // widget, which a variant never replaces: `_selectVariantRows` swaps the
    // row list and nothing else. They already apply to variant rows, so
    // copying them here would be a second channel to the same place.
    final variantBuilder = AclBuilder();
    _copyRowDefaultsTo(variantBuilder);
    builder(variantBuilder);
    // Why: the variant's rows are harvested straight out of the throwaway
    // builder, so nothing else ever calls the finalization `build()` performs.
    // Without it the last component appended inside the variant keeps a null
    // preferred size and never carries `preferredWidthIsDefault` — which is the
    // flag that puts it inside the measure/clip box. It would then lay out
    // unclipped on the first frame, before any measurement exists, and overflow
    // for exactly that frame.
    variantBuilder._finalizeCurrentComponent();
    _variants.add(
      AclVariant(
        name: name,
        atWidth: atWidth,
        rows: variantBuilder._rows
            .map(
              (r) => r.toRow(
                defaultAppendGap: variantBuilder._defaultAppendGap,
                defaultAppendGapBpOverrides:
                    variantBuilder._defaultAppendGapBpOverrides,
                fallbackHeight: variantBuilder._defaultRowHeight,
                fallbackHeightBpOverrides:
                    variantBuilder._defaultRowHeightBpOverrides,
                defaultRowCrossAlignment:
                    variantBuilder._defaultRowVerticalAlignment,
              ),
            )
            .toList(),
      ),
    );
    return this;
  }

  // ── Row Breakpoints ────────────────────────────────────────────────────────

  /// Adds a row breakpoint at the current position in the builder chain.
  ///
  /// The split index is calculated from the number of components appended so
  /// far. Call this **between** `append()` calls to indicate where the row
  /// should break when the container width drops below [atWidth].
  AclBuilder addRowBreakpoint({
    required double atWidth,
    double splitRowDist = 0,
  }) {
    _currentRow.breakpoints.add(
      AclRowBreakpoint(
        atWidth: atWidth,
        splitAfter: _currentRow.components.length,
        splitRowDist: splitRowDist,
      ),
    );
    return this;
  }

  // ── Inline Component Variants ──────────────────────────────────────────────

  /// Opens a block whose appended components belong to one device variant.
  ///
  /// Everything appended until the matching [endVariant] is tagged with a
  /// single detector. At layout time the container evaluates each row's
  /// variants **in declaration order and keeps the first that matches**;
  /// components of the losing variants are dropped from that row entirely.
  ///
  /// A `startVariant()` with no arguments builds no detector and marks its
  /// components as the **default variant**. It is not part of that ordered
  /// race — it is the fallback taken when no gated variant matched, so it may
  /// be declared anywhere in the row. It is also what shows when the container
  /// has no device context to test against at all, which happens whenever the
  /// incoming constraints have unbounded *width*.
  ///
  /// The named facets are forwarded to
  /// [AclDeviceContext.buildConvenienceDetector] and combine with AND. Read its
  /// documentation before gating on [height] in particular: an unbounded
  /// container reports an unknown height, which **fails** the facet, so a
  /// height-gated variant never activates while the container shrink-wraps.
  ///
  /// Passing [detector] supplies the predicate directly and ignores every named
  /// facet — use it for conditions the convenience parameters cannot express.
  ///
  /// Throws [StateError] when a variant block is already open.
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
    _currentVariantDetector =
        detector ??
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

  /// Closes the block opened by [startVariant].
  ///
  /// Components appended after this call are untagged again, and untagged
  /// components survive variant filtering unconditionally — they appear
  /// whichever variant wins.
  ///
  /// Throws [StateError] when no variant block is open.
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

  /// Sets the layout direction for this container, deciding whether components
  /// within a row flow left-to-right or right-to-left.
  ///
  /// Leaving it unset is not the same as passing [AclDirection.ltr]: an unset
  /// direction defers to the nearest [AclDirectionScope] ancestor and only
  /// falls back to [AclDirection.ltr] when there is none, whereas an explicit
  /// value overrides any enclosing scope. Set it when this container must
  /// oppose its surroundings; otherwise prefer a scope near the app root.
  ///
  /// See "Layout Direction (RTL/LTR)" (§30) in
  /// `doc/acl_design_specification.md`.
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
          .map(
            (row) => row.toRow(
              defaultAppendGap: _defaultAppendGap,
              defaultAppendGapBpOverrides: _defaultAppendGapBpOverrides,
              fallbackHeight: _defaultRowHeight,
              fallbackHeightBpOverrides: _defaultRowHeightBpOverrides,
              defaultRowCrossAlignment: _defaultRowVerticalAlignment,
            ),
          )
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
      groupVisibilityControllers: Map.unmodifiable(_groupVisibilityControllers),
      variants: sortedVariants,
      direction: _direction,
      defaultHideUnauthorized: _defaultHideUnauthorized,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  AclBuilder _setHorizontalAlignment({
    required Widget reference,
    required AclAxisPointX selfPoint,
    required AclAxisPointX referencePoint,
    required double gap,
  }) {
    final component = _requireComponent('alignX*');
    final entry = _requireAppended(reference, 'alignX*');
    if (entry.row == _currentRow) {
      throw UnsupportedError(
        'AclBuilder: alignX* same-row reference — the reference widget '
        'must be in a different row. Use alignY* for same-row vertical alignment.',
      );
    }
    component.alignXToKey = entry.key;
    component.alignXFrom = selfPoint;
    component.alignXTo = referencePoint;
    component.alignXGap = gap;
    return this;
  }

  AclBuilder _setVerticalAlignment({
    required Widget reference,
    required AclAxisPointY selfPoint,
    required AclAxisPointY referencePoint,
    required double gap,
  }) {
    final component = _requireComponent('alignY*');
    if (component.rowCrossAlignmentSet) {
      throw UnsupportedError(
        'AclBuilder: alignY* cannot be combined with setVerticalAlignment() '
        'on the same component — remove the setVerticalAlignment() call.',
      );
    }
    final entry = _requireAppended(reference, 'alignY*');
    if (entry.row != _currentRow) {
      throw UnsupportedError(
        'AclBuilder: alignY* cross-row reference — the reference widget '
        'must be in the same row. Use alignX* for cross-row horizontal alignment.',
      );
    }
    component.alignYToKey = entry.key;
    component.alignYFrom = selfPoint;
    component.alignYTo = referencePoint;
    component.alignYGap = gap;
    return this;
  }

  /// Every widget instance appending [child] makes this builder responsible
  /// for: [child] itself, and — when it is a flex wrapper — the widget it
  /// wraps, down the whole chain.
  ///
  /// **The chain is `Flexible` and its subclasses, which is what `Expanded`
  /// is, and nothing else.** A wrapper is unwrapped because the builder gives
  /// it no key of its own: the widget that ends up in the tree, and that a
  /// reference would have to mean, is the one inside. Any other wrapper —
  /// `Padding`, `Center`, one of the caller's own — is a component in its own
  /// right and is compared as itself. A new wrapper type that the row lays out
  /// natively has to be added here *and* to [append]'s `canAttachComponentKey`
  /// test, or it re-opens the hole this closes.
  ///
  /// `Spacer` yields only itself: it wraps nothing the caller passed in.
  Iterable<Widget> _instancesOf(Widget child) sync* {
    yield child;
    var inner = child;
    while (inner is Flexible) {
      inner = inner.child;
      yield inner;
    }
  }

  bool _alreadyAppended(Widget instance) =>
      _appended.containsKey(instance) || _unkeyedChildren.contains(instance);

  Key _newComponentKey() =>
      GlobalKey(debugLabel: 'acl-ref-${_appended.length}');

  /// The row [reference] was appended to, refusing anything this container has
  /// no component for.
  ///
  /// A reference that resolves to nothing is the worst shape this API can
  /// take: the layout still builds, the component silently keeps its own
  /// size, and the only symptom is that two things a reader was told would
  /// match do not. [caller] names the method the author actually wrote.
  ({Key key, _RowData row}) _requireAppended(Widget reference, String caller) {
    final entry = _appended[reference];
    if (entry != null) return entry;
    if (_unkeyedChildren.contains(reference)) {
      throw UnsupportedError(
        'AclBuilder: $caller cannot reference a Flexible, Expanded or Spacer. '
        'The row lays those out itself, so they carry no component key and '
        'there is nothing for the reference to resolve against. Append the '
        'content as a plain widget and reference that.',
      );
    }
    throw UnsupportedError(
      'AclBuilder: $caller was given a widget this builder has no component '
      'for. Pass the very widget instance handed to an earlier append() — '
      'capture it in a variable and reference that — not a Key, a copy, or a '
      'widget appended later.',
    );
  }
}

extension AclBuilderExtensions on AclBuilder {
  AclBuilder expandX() => setAttr(AclFlags.expandX);
  AclBuilder expandY() => setAttr(AclFlags.expandY);
  AclBuilder expand() => setAttr(AclFlags.expand);

  // ── Row-level horizontal alignment shortcuts ──
  AclBuilder setRowAlignLeft() => setRowHorizontalAlignment(RowAlignment.left);
  AclBuilder setRowAlignCenter() =>
      setRowHorizontalAlignment(RowAlignment.center);
  AclBuilder setRowAlignRight() =>
      setRowHorizontalAlignment(RowAlignment.right);

  // ── Row-level vertical alignment shortcuts ──
  AclBuilder setRowAlignTop() =>
      setRowVerticalAlignment(AclRowCrossAlignment.top);
  AclBuilder setRowAlignMiddle() =>
      setRowVerticalAlignment(AclRowCrossAlignment.center);
  AclBuilder setRowAlignBottom() =>
      setRowVerticalAlignment(AclRowCrossAlignment.bottom);
}
