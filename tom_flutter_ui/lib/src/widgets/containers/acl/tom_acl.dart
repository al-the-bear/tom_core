import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../../widget_base/tom_construction_helpers.dart';
import '../../../theme/tom_theme.dart';
import '../../../widget_base/tom_style_resolvers.dart';
import '../../../advanced_container_layout/acl_builder.dart';
import '../../../advanced_container_layout/acl_container.dart';
import '../../../advanced_container_layout/acl_device_context.dart';
import '../../../advanced_container_layout/acl_group_visibility.dart';
import '../../../advanced_container_layout/row_alignment.dart';
import '../../../widget_base/tom_scope_path.dart';
import '../../../widget_base/tom_screen_elements_provider.dart';

/// A delegating wrapper around [AclBuilder] that adds Tom UI concerns:
///
/// - **Element provider** — typed access to screen elements via `(T p) => p.field`.
/// - **Authorization** — container-level visibility check via [TomAuthorization].
/// - **Resources** — container title resolved from [TomCtr] if not explicit.
/// - **Identity scope** — wraps the result in [TomScope] for descendant resolution.
///
/// The wrapper delegates all layout operations to a standard [AclBuilder].
/// This keeps the layout engine independent of Tom-specific concerns.
class TomAclBuilder<T extends TomScreenElementsProvider> {
  final String id;

  /// Whether this container contributes its ID to descendant paths.
  ///
  /// - `true` — identity container: ID appears in descendant paths.
  /// - `false` — layout container (default): ID is for own resources only.
  final bool idScope;

  final T elementProvider;
  final AclBuilder _builder;
  final String? _explicitTitle;
  final bool _explicitPadding;
  final bool _explicitBackgroundColor;
  final bool _explicitTitleStyle;
  final bool _explicitTitleVerticalOffset;
  final bool _explicitBorderStyle;
  final bool _explicitFocusedBorderStyle;
  final bool _explicitTitlePosition;
  final bool _explicitTitleBorderAlign;

  TomAclBuilder({
    required this.id,
    this.idScope = false,
    required this.elementProvider,
    String? title,
    Widget? titleWidget,
    AclBorderStyle? borderStyle,
    AclBorderStyle? focusedBorderStyle,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    TextStyle? titleStyle,
    AclTitlePosition? titlePosition,
    AclTitleBorderAlign? titleBorderAlign,
    double? titleVerticalOffset,
  }) : _explicitTitle = title,
       _explicitPadding = padding != null,
       _explicitBackgroundColor = backgroundColor != null,
       _explicitTitleStyle = titleStyle != null,
       _explicitTitleVerticalOffset = titleVerticalOffset != null,
       _explicitBorderStyle = borderStyle != null,
       _explicitFocusedBorderStyle = focusedBorderStyle != null,
       _explicitTitlePosition = titlePosition != null,
       _explicitTitleBorderAlign = titleBorderAlign != null,
       _builder = AclBuilder(
         title: title,
         titleWidget: titleWidget,
         borderStyle: borderStyle ?? const AclBorderStyle.none(),
         focusedBorderStyle: focusedBorderStyle,
         padding: padding ?? EdgeInsets.zero,
         backgroundColor: backgroundColor,
         titleStyle: titleStyle,
         titlePosition: titlePosition ?? AclTitlePosition.topLeft,
         titleBorderAlign: titleBorderAlign ?? AclTitleBorderAlign.bottom,
         titleVerticalOffset: titleVerticalOffset ?? 0.0,
       ) {
    _builder.setAclId(id);
    _builder.setAclIdScope(idScope);
  }

  // ── Element provider methods ──────────────────────────────────────────────

  /// Appends a widget selected from the element provider.
  TomAclBuilder<T> append(
    Widget Function(T provider) selector, {
    double dist = 0,
  }) {
    _builder.append(selector(elementProvider), dist: dist);
    return this;
  }

  /// Appends a form widget from the element provider.
  TomAclBuilder<T> appendForm(
    Widget Function(T provider) selector, {
    double dist = 0,
  }) {
    _builder.append(selector(elementProvider), dist: dist);
    return this;
  }

  /// Appends a master-detail layout with master and detail from the provider.
  TomAclBuilder<T> appendMasterDetail({
    required Widget Function(T provider) master,
    required Widget Function(T provider) detail,
  }) {
    // Layout master and detail side by side in the current row
    _builder.append(master(elementProvider));
    _builder.expandX();
    _builder.append(detail(elementProvider));
    _builder.expandX();
    return this;
  }

  // ── Delegated layout methods ──────────────────────────────────────────────

  /// Starts a new content row.
  TomAclBuilder<T> newRow({
    double dist = 0,
    double? height,
    List<(double, double?)> heightBpOverrides = const [],
  }) {
    _builder.newRow(
      dist: dist,
      height: height,
      heightBpOverrides: heightBpOverrides,
    );
    return this;
  }

  /// Sets the height on the current (most-recently-started) row.
  ///
  /// See [AclBuilder.setRowHeight] for semantics.
  TomAclBuilder<T> setRowHeight(
    double? height, [
    List<(double, double?)> heightBpOverrides = const [],
  ]) {
    _builder.setRowHeight(height, heightBpOverrides);
    return this;
  }

  /// Inserts an elastic horizontal gap.
  TomAclBuilder<T> gap({double weight = 1}) {
    _builder.gap(weight: weight);
    return this;
  }

  /// Inserts an elastic vertical gap row.
  TomAclBuilder<T> gapRow({
    double weight = 1,
    AclSeparator? separator,
    double minSize = 0,
  }) {
    _builder.gapRow(weight: weight, separator: separator, minSize: minSize);
    return this;
  }

  /// Expands the most recently appended component horizontally.
  TomAclBuilder<T> expandX() {
    _builder.expandX();
    return this;
  }

  /// Expands the most recently appended component vertically.
  TomAclBuilder<T> expandY() {
    _builder.expandY();
    return this;
  }

  /// Expands the most recently appended component in both directions.
  TomAclBuilder<T> expand() {
    _builder.expand();
    return this;
  }

  /// Horizontal main-axis alignment for the **current row only**.
  TomAclBuilder<T> setRowHorizontalAlignment(RowAlignment alignment) {
    _builder.setRowHorizontalAlignment(alignment);
    return this;
  }

  /// Vertical cross-axis alignment for the **current row only** —
  /// inherited by components that don't call [setVerticalAlignment].
  TomAclBuilder<T> setRowVerticalAlignment(AclRowCrossAlignment alignment) {
    _builder.setRowVerticalAlignment(alignment);
    return this;
  }

  /// Sets a preferred size on the current component.
  TomAclBuilder<T> setPSize(double width, [double height = 0]) {
    _builder.setPSize(width, height);
    return this;
  }

  /// Sets a minimum size on the current component.
  TomAclBuilder<T> setMSize(double width, [double height = 0]) {
    _builder.setMSize(width, height);
    return this;
  }

  /// Sets a maximum size on the current component.
  ///
  /// An omitted or 0 axis is left unconstrained rather than capped at 0 —
  /// unlike [setPSize] and [setMSize], where 0 falls back to 0. See
  /// [AclBuilder.setXSize].
  TomAclBuilder<T> setXSize(double width, [double height = 0]) {
    _builder.setXSize(width, height);
    return this;
  }

  /// Sets the preferred width using a character count.
  TomAclBuilder<T> setPWidthInChars(
    int chars, {
    double charWidth = 8,
    double height = 40,
  }) {
    _builder.setPWidthInChars(chars, charWidth: charWidth, height: height);
    return this;
  }

  /// Sets the minimum width using a character count.
  TomAclBuilder<T> setMWidthInChars(int chars, {double charWidth = 8}) {
    _builder.setMWidthInChars(chars, charWidth: charWidth);
    return this;
  }

  /// Sets the maximum width using a character count.
  TomAclBuilder<T> setXWidthInChars(int chars, {double charWidth = 8}) {
    _builder.setXWidthInChars(chars, charWidth: charWidth);
    return this;
  }

  /// Sets a flag attribute on the current component.
  TomAclBuilder<T> setAttr(int attr) {
    _builder.setAttr(attr);
    return this;
  }

  /// Clears a flag attribute on the current component.
  TomAclBuilder<T> clearAttr(int attr) {
    _builder.clearAttr(attr);
    return this;
  }

  /// Sets a size reference to another component.
  TomAclBuilder<T> setComp(Object reference, int otherAttr) {
    _builder.setComp(reference, otherAttr);
    return this;
  }

  /// Constrains the current component to the same width as [reference].
  TomAclBuilder<T> sameWidthAs(Object reference) {
    _builder.sameWidthAs(reference);
    return this;
  }

  /// Constrains the current component to the same height as [reference].
  TomAclBuilder<T> sameHeightAs(Object reference) {
    _builder.sameHeightAs(reference);
    return this;
  }

  /// Constrains the current component to the same size as [reference].
  TomAclBuilder<T> sameSize(Object reference) {
    _builder.sameSize(reference);
    return this;
  }

  // ── Per-component vertical alignment ──────────────────────────────────────

  /// Overrides the vertical alignment for the **current component
  /// only** — takes precedence over the row and builder defaults.
  TomAclBuilder<T> setVerticalAlignment(AclRowCrossAlignment alignment) {
    _builder.setVerticalAlignment(alignment);
    return this;
  }

  // ── Cross-row horizontal alignment ────────────────────────────────────────

  TomAclBuilder<T> alignLeftToLeft(Object reference, {double gap = 0}) {
    _builder.alignLeftToLeft(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignLeftToCenter(Object reference, {double gap = 0}) {
    _builder.alignLeftToCenter(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignLeftToRight(Object reference, {double gap = 0}) {
    _builder.alignLeftToRight(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignCenterToLeft(Object reference, {double gap = 0}) {
    _builder.alignCenterToLeft(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignCenterToCenter(Object reference, {double gap = 0}) {
    _builder.alignCenterToCenter(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignCenterToRight(Object reference, {double gap = 0}) {
    _builder.alignCenterToRight(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignRightToLeft(Object reference, {double gap = 0}) {
    _builder.alignRightToLeft(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignRightToCenter(Object reference, {double gap = 0}) {
    _builder.alignRightToCenter(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignRightToRight(Object reference, {double gap = 0}) {
    _builder.alignRightToRight(reference, gap: gap);
    return this;
  }

  // ── Same-row vertical alignment ───────────────────────────────────────────

  TomAclBuilder<T> alignTopToTop(Object reference, {double gap = 0}) {
    _builder.alignTopToTop(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignTopToMiddle(Object reference, {double gap = 0}) {
    _builder.alignTopToMiddle(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignTopToBottom(Object reference, {double gap = 0}) {
    _builder.alignTopToBottom(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignMiddleToTop(Object reference, {double gap = 0}) {
    _builder.alignMiddleToTop(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignMiddleToMiddle(Object reference, {double gap = 0}) {
    _builder.alignMiddleToMiddle(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignMiddleToBottom(Object reference, {double gap = 0}) {
    _builder.alignMiddleToBottom(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignBottomToTop(Object reference, {double gap = 0}) {
    _builder.alignBottomToTop(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignBottomToMiddle(Object reference, {double gap = 0}) {
    _builder.alignBottomToMiddle(reference, gap: gap);
    return this;
  }

  TomAclBuilder<T> alignBottomToBottom(Object reference, {double gap = 0}) {
    _builder.alignBottomToBottom(reference, gap: gap);
    return this;
  }

  /// Sets the component ID.
  TomAclBuilder<T> setId(String componentId) {
    _builder.setId(componentId);
    return this;
  }

  /// Assigns the current component to a group.
  TomAclBuilder<T> group(String name) {
    _builder.group(name);
    return this;
  }

  /// Begins a group range.
  TomAclBuilder<T> startGroup(String name) {
    _builder.startGroup(name);
    return this;
  }

  /// Ends a group range.
  TomAclBuilder<T> endGroup() {
    _builder.endGroup();
    return this;
  }

  /// Sets a group visibility controller.
  TomAclBuilder<T> setGroupVisibilityController(
    String groupName,
    AclGroupVisibilityController controller,
  ) {
    _builder.setGroupVisibilityController(groupName, controller);
    return this;
  }

  /// Sets the row ID.
  TomAclBuilder<T> setRowId(String rowId) {
    _builder.setRowId(rowId);
    return this;
  }

  /// Sets whether the current row's ID contributes to descendant paths.
  TomAclBuilder<T> setRowIdScope(bool idScope) {
    _builder.setRowIdScope(idScope);
    return this;
  }

  /// Sets the row group.
  TomAclBuilder<T> setRowGroup(String name) {
    _builder.setRowGroup(name);
    return this;
  }

  /// Sets the container group.
  TomAclBuilder<T> setAclGroup(String name) {
    _builder.setAclGroup(name);
    return this;
  }

  /// Adds a responsive variant.
  TomAclBuilder<T> addVariant(
    String name, {
    required double atWidth,
    required void Function(AclBuilder) builder,
  }) {
    _builder.addVariant(name, atWidth: atWidth, builder: builder);
    return this;
  }

  /// Adds a row breakpoint.
  TomAclBuilder<T> addRowBreakpoint({
    required double atWidth,
    double splitRowDist = 0,
  }) {
    _builder.addRowBreakpoint(atWidth: atWidth, splitRowDist: splitRowDist);
    return this;
  }

  /// Sets the preferred container size.
  TomAclBuilder<T> setAclPSize(double width, double height) {
    _builder.setAclPSize(width, height);
    return this;
  }

  /// Sets the minimum container size.
  TomAclBuilder<T> setAclMSize(double width, double height) {
    _builder.setAclMSize(width, height);
    return this;
  }

  /// Sets the maximum container size.
  TomAclBuilder<T> setAclXSize(double width, double height) {
    _builder.setAclXSize(width, height);
    return this;
  }

  /// Enables horizontal scrolling.
  TomAclBuilder<T> setAclScrollableX() {
    _builder.setAclScrollableX();
    return this;
  }

  /// Enables vertical scrolling.
  TomAclBuilder<T> setAclScrollableY() {
    _builder.setAclScrollableY();
    return this;
  }

  /// Sets the container border style.
  TomAclBuilder<T> setAclBorderStyle(AclBorderStyle borderStyle) {
    _builder.setAclBorderStyle(borderStyle);
    return this;
  }

  /// Sets the container border insets.
  TomAclBuilder<T> setAclBorderInsets(EdgeInsetsGeometry insets) {
    _builder.setAclBorderInsets(insets);
    return this;
  }

  /// Sets the focused border style.
  TomAclBuilder<T> setAclFocusedBorderStyle(AclBorderStyle style) {
    _builder.setAclFocusedBorderStyle(style);
    return this;
  }

  /// Sets the container padding.
  TomAclBuilder<T> setAclPadding(EdgeInsetsGeometry padding) {
    _builder.setAclPadding(padding);
    return this;
  }

  /// Sets the container padding from explicit LTRB values.
  TomAclBuilder<T> setAclPaddingPx(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    _builder.setAclPaddingPx(left, top, right, bottom);
    return this;
  }

  /// Sets the top padding.
  TomAclBuilder<T> setAclPaddingTop(double value) {
    _builder.setAclPaddingTop(value);
    return this;
  }

  /// Sets the bottom padding.
  TomAclBuilder<T> setAclPaddingBottom(double value) {
    _builder.setAclPaddingBottom(value);
    return this;
  }

  /// Sets the left padding.
  TomAclBuilder<T> setAclPaddingLeft(double value) {
    _builder.setAclPaddingLeft(value);
    return this;
  }

  /// Sets the right padding.
  TomAclBuilder<T> setAclPaddingRight(double value) {
    _builder.setAclPaddingRight(value);
    return this;
  }

  /// Sets the background color.
  TomAclBuilder<T> setAclBackgroundColor(Color color) {
    _builder.setAclBackgroundColor(color);
    return this;
  }

  /// Sets the layout direction (LTR/RTL).
  TomAclBuilder<T> setAclDirection(AclDirection direction) {
    _builder.setAclDirection(direction);
    return this;
  }

  /// Sets default flags for new components.
  TomAclBuilder<T> setAclDefaultFlags(int flags) {
    _builder.setAclDefaultFlags(flags);
    return this;
  }

  /// Gets the current default flags.
  int get defaultFlags => _builder.defaultFlags;

  /// Sets the default expand-X behaviour for newly appended components.
  TomAclBuilder<T> setAclExpandXDefault(bool enabled) {
    _builder.setAclExpandXDefault(enabled);
    return this;
  }

  /// Sets the default horizontal gap before each appended component,
  /// including the first component of every row.
  ///
  /// See [AclBuilder.setAclDefaultAppendGap] for semantics.
  TomAclBuilder<T> setAclDefaultAppendGap(
    double gap, [
    List<(double, double)> gapBpOverrides = const [],
  ]) {
    _builder.setAclDefaultAppendGap(gap, gapBpOverrides);
    return this;
  }

  /// Sets the builder-wide default row height.
  ///
  /// See [AclBuilder.setAclDefaultRowHeight] for semantics.
  TomAclBuilder<T> setAclDefaultRowHeight(
    double? height, [
    List<(double, double?)> heightBpOverrides = const [],
  ]) {
    _builder.setAclDefaultRowHeight(height, heightBpOverrides);
    return this;
  }

  /// Sets the default vertical gap between content rows.
  TomAclBuilder<T> setAclDefaultRowGap(int pixels) {
    _builder.setAclDefaultRowGap(pixels);
    return this;
  }

  /// Builder-wide default for the **vertical** cross-axis placement of
  /// every row.
  TomAclBuilder<T> setAclDefaultRowVerticalAlignment(
    AclRowCrossAlignment alignment,
  ) {
    _builder.setAclDefaultRowVerticalAlignment(alignment);
    return this;
  }

  /// Builder-wide default for the **horizontal** main-axis placement of
  /// every row.
  TomAclBuilder<T> setAclDefaultRowHorizontalAlignment(RowAlignment alignment) {
    _builder.setAclDefaultRowHorizontalAlignment(alignment);
    return this;
  }

  /// Container-wide default for hide-when-unauthorized. See
  /// [AclBuilder.setAclDefaultHideUnauthorized].
  TomAclBuilder<T> setAclDefaultHideUnauthorized(bool value) {
    _builder.setAclDefaultHideUnauthorized(value);
    return this;
  }

  /// Per-component override for hide-when-unauthorized on the most
  /// recently appended component. See [AclBuilder.setHideUnauthorized].
  TomAclBuilder<T> setHideUnauthorized(bool? value) {
    _builder.setHideUnauthorized(value);
    return this;
  }

  /// Sets a default minimum size for components without an explicit minimum.
  /// Zeros are stored as zeros. See
  /// [AclBuilder.setAclDefaultUnknownMinimumSize].
  TomAclBuilder<T> setAclDefaultUnknownMinimumSize(
    double width, [
    double height = 0,
  ]) {
    _builder.setAclDefaultUnknownMinimumSize(width, height);
    return this;
  }

  /// Sets a default preferred size for components without an explicit
  /// preferred size. A 0 width falls back to the built-in 150. See
  /// [AclBuilder.setAclDefaultUnknownPreferredSize].
  TomAclBuilder<T> setAclDefaultUnknownPreferredSize(
    double width, [
    double height = 0,
  ]) {
    _builder.setAclDefaultUnknownPreferredSize(width, height);
    return this;
  }

  /// Sets the container title.
  TomAclBuilder<T> setAclTitle(String? title) {
    _builder.setAclTitle(title);
    return this;
  }

  /// Sets the container title widget.
  TomAclBuilder<T> setAclTitleWidget(Widget? widget) {
    _builder.setAclTitleWidget(widget);
    return this;
  }

  /// Sets the title text style.
  TomAclBuilder<T> setAclTitleStyle(TextStyle style) {
    _builder.setAclTitleStyle(style);
    return this;
  }

  /// Sets the title position.
  TomAclBuilder<T> setAclTitlePosition(AclTitlePosition position) {
    _builder.setAclTitlePosition(position);
    return this;
  }

  /// Sets the title border alignment.
  TomAclBuilder<T> setAclTitleBorderAlign(AclTitleBorderAlign align) {
    _builder.setAclTitleBorderAlign(align);
    return this;
  }

  /// Sets the title vertical offset.
  TomAclBuilder<T> setAclTitleVerticalOffset(double offset) {
    _builder.setAclTitleVerticalOffset(offset);
    return this;
  }

  // ── Inline Component Variants ─────────────────────────────────────────────

  /// Begins an inline variant block.
  TomAclBuilder<T> startVariant({
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
    _builder.startVariant(
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
      detector: detector,
    );
    return this;
  }

  /// Ends an inline variant block.
  TomAclBuilder<T> endVariant() {
    _builder.endVariant();
    return this;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /// Builds the final widget tree.
  ///
  /// Steps:
  /// 1. Check container-level authorization — if hidden, return [SizedBox.shrink].
  /// 2. Resolve title from resources if not explicitly set.
  /// 3. Build the underlying [AclBuilder].
  /// 4. Wrap in [TomScope] providing scope context to descendants.
  ///
  /// ACL containers with IDs act as implicit group scopes — any widget inside
  /// can use this container's ID as part of their canonical path.
  ///
  /// The returned widget must be placed in a [BuildContext] that has a
  /// [TomThemeScope] ancestor for the withheld-state styling (falls back to
  /// the default theme).
  Widget build(BuildContext context) {
    // Self-path: <scopePath>.<id>
    final containerPath = TomScopePath.qualify(id);

    // Container-level authorization
    final auth = TomAuthorization.resolveAuth(containerPath);
    if (!auth.isVisible) return const SizedBox.shrink();

    // Resolve unset parameters from resources
    if (_explicitTitle == null) {
      final resourceTitle = TomCtr.text(containerPath, 'title');
      // Only use resource title if it doesn't look like a missing-key fallback
      if (!resourceTitle.contains('.title')) {
        _builder.setAclTitle(resourceTitle);
      }
    }
    if (!_explicitPadding) {
      final resPadding = TomCtr.edgeInsets(containerPath, 'padding');
      if (resPadding != null) _builder.setAclPadding(resPadding);
    }
    if (!_explicitBackgroundColor) {
      final resBg = TomCtr.color(containerPath, 'backgroundColor');
      if (resBg != null) _builder.setAclBackgroundColor(resBg);
    }
    if (!_explicitTitleStyle) {
      final resStyle = TomStyleResolvers.resolveTextStyle(
        containerPath,
        'titleStyle',
      );
      if (resStyle != null) _builder.setAclTitleStyle(resStyle);
    }
    if (!_explicitTitleVerticalOffset) {
      final resOffset = TomCtr.doubleVal(containerPath, 'titleVerticalOffset');
      if (resOffset != null) _builder.setAclTitleVerticalOffset(resOffset);
    }
    if (!_explicitBorderStyle) {
      final resBorder = _resolveBorderStyle(containerPath, 'borderStyle');
      if (resBorder != null) _builder.setAclBorderStyle(resBorder);
    }
    if (!_explicitFocusedBorderStyle) {
      final resFocused = _resolveBorderStyle(
        containerPath,
        'focusedBorderStyle',
      );
      if (resFocused != null) _builder.setAclFocusedBorderStyle(resFocused);
    }
    if (!_explicitTitlePosition) {
      final resPos = _resolveTitlePosition(containerPath);
      if (resPos != null) _builder.setAclTitlePosition(resPos);
    }
    if (!_explicitTitleBorderAlign) {
      final resAlign = _resolveTitleBorderAlign(containerPath);
      if (resAlign != null) _builder.setAclTitleBorderAlign(resAlign);
    }

    // ACL containers no longer create new scopes - scoping is external.
    //
    // Why applyAuthState rather than a `read` branch: `disabled` is visible
    // too, so a gate that only reacts to `read` hands a withheld container to
    // the user fully live. Routing through the theme maps all four states from
    // the one place that knows what each of them looks like.
    return TomThemeScope.applyAuthState(context, auth, _builder.build);
  }

  /// Resolves an [AclBorderStyle] from a resource map at [basePath]/[suffix].
  AclBorderStyle? _resolveBorderStyle(String basePath, String suffix) {
    final map = TomCtr.map(basePath, suffix);
    if (map == null || map.isEmpty) return null;
    return AclBorderStyle(
      kind: _parseBorderKind(map['kind'] as String?) ?? AclBorderKind.none,
      color: TomCtr.color(basePath, '$suffix.color') ?? const Color(0x00000000),
      lineWidth: TomCtr.doubleVal(basePath, '$suffix.lineWidth') ?? 1.0,
      rounded: TomCtr.boolVal(basePath, '$suffix.rounded') ?? false,
      borderRadius: TomCtr.doubleVal(basePath, '$suffix.borderRadius') ?? 0.0,
      borderInsets:
          TomCtr.edgeInsets(basePath, '$suffix.borderInsets') ??
          EdgeInsets.zero,
    );
  }

  /// Parses a string to [AclBorderKind], or returns null if unrecognized.
  static AclBorderKind? _parseBorderKind(String? value) {
    if (value == null) return null;
    for (final kind in AclBorderKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  /// Resolves an [AclTitlePosition] from a resource text at [basePath]/titlePosition.
  AclTitlePosition? _resolveTitlePosition(String basePath) {
    final value = TomCtr.value(basePath, 'titlePosition');
    if (value == null) return null;
    final text = value.toString();
    for (final pos in AclTitlePosition.values) {
      if (pos.name == text) return pos;
    }
    return null;
  }

  /// Resolves an [AclTitleBorderAlign] from a resource text at [basePath]/titleBorderAlign.
  AclTitleBorderAlign? _resolveTitleBorderAlign(String basePath) {
    final value = TomCtr.value(basePath, 'titleBorderAlign');
    if (value == null) return null;
    final text = value.toString();
    for (final align in AclTitleBorderAlign.values) {
      if (align.name == text) return align;
    }
    return null;
  }
}
