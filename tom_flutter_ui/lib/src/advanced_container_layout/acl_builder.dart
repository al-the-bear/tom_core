import 'package:flutter/material.dart';

import 'acl_container.dart';
import 'acl_device_context.dart';
import 'acl_flags.dart';
import 'acl_group_visibility.dart';
import 'acl_responsive.dart';
import 'row_alignment.dart';

part 'acl_builder_data.dart';
part 'acl_builder_sizing.dart';
part 'acl_builder_alignment.dart';
part 'acl_builder_chrome.dart';
part 'acl_builder_identity.dart';
part 'acl_builder_responsive.dart';

/// Fluent builder for [Acl] layout containers.
///
/// This class holds the builder's state and its core: appending components
/// and gaps, starting rows, raw flags, and [build]. The rest of the fluent API
/// lives in extensions on this class, one per method family and each in its
/// own part of this library — [AclBuilderSizing], [AclBuilderAlignment],
/// [AclBuilderChrome], [AclBuilderIdentity] and [AclBuilderResponsive]. They
/// are declared in the same library, so they come with the class and a chain
/// reads exactly as it would if every method were a member.
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

  // ── Per-component flags ────────────────────────────────────────────────────

  AclBuilder setAttr(int attr) {
    _requireComponent('setAttr').flags |= attr;
    return this;
  }

  AclBuilder clearAttr(int newAttr) {
    _requireComponent('clearAttr').flags &= ~newAttr;
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
