import 'package:flutter/widgets.dart';

import '../../../resource_auth/tom_auth_state.dart';
import '../../../resource_auth/tom_id_prefix.dart';
import '../../../resource_auth/tom_resources.dart';
import '../../../theme/tom_theme.dart';
import '../../../widget_base/tom_style_resolvers.dart';
import '../../../advanced_container_layout/acl_builder.dart';
import '../../../advanced_container_layout/acl_container.dart';
import '../../../advanced_container_layout/acl_group_visibility.dart';
import '../../../advanced_container_layout/row_alignment.dart';
import '../../../widget_base/tom_node_base.dart';
import '../../../widget_base/tom_screen_elements_provider.dart';

/// A delegating wrapper around [AclBuilder] that adds Tom UI concerns:
///
/// - **Element provider** — typed access to screen elements via `(T p) => p.field`.
/// - **Authorization** — container-level visibility check via [TomUIAuthorization].
/// - **Resources** — container title resolved from [TomUIResources] if not explicit.
/// - **Identity scope** — wraps the result in [TomNodeScope] for descendant resolution.
///
/// The wrapper delegates all layout operations to a standard [AclBuilder].
/// This keeps the layout engine independent of Tom-specific concerns.
class TomAclBuilder<T extends TomScreenElementsProvider> {
  final String id;
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
  })  : _explicitTitle = title,
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
  }

  // ── Element provider methods ──────────────────────────────────────────────

  /// Appends a widget selected from the element provider.
  TomAclBuilder<T> append(Widget Function(T provider) selector,
      {double dist = 0}) {
    _builder.append(selector(elementProvider), dist: dist);
    return this;
  }

  /// Appends a form widget from the element provider.
  TomAclBuilder<T> appendForm(Widget Function(T provider) selector,
      {double dist = 0}) {
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
  TomAclBuilder<T> newRow({double dist = 0}) {
    _builder.newRow(dist: dist);
    return this;
  }

  /// Inserts an elastic horizontal gap.
  TomAclBuilder<T> gap({double weight = 1}) {
    _builder.gap(weight: weight);
    return this;
  }

  /// Inserts an elastic vertical gap row.
  TomAclBuilder<T> gapRow(
      {double weight = 1, AclSeparator? separator, double minSize = 0}) {
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

  /// Sets the row alignment for the current row.
  TomAclBuilder<T> setRowAlignment(RowAlignment alignment) {
    _builder.setRowAlignment(alignment);
    return this;
  }

  /// Sets a preferred size on the current component.
  TomAclBuilder<T> setPSize(double width, double height) {
    _builder.setPSize(width, height);
    return this;
  }

  /// Sets a minimum size on the current component.
  TomAclBuilder<T> setMSize(double width, double height) {
    _builder.setMSize(width, height);
    return this;
  }

  /// Sets a maximum size on the current component.
  TomAclBuilder<T> setXSize(double width, double height) {
    _builder.setXSize(width, height);
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
      String groupName, AclGroupVisibilityController controller) {
    _builder.setGroupVisibilityController(groupName, controller);
    return this;
  }

  /// Sets the row ID.
  TomAclBuilder<T> setRowId(String rowId) {
    _builder.setRowId(rowId);
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
  TomAclBuilder<T> addVariant(String name,
      {required double atWidth,
      required void Function(AclBuilder) builder}) {
    _builder.addVariant(name, atWidth: atWidth, builder: builder);
    return this;
  }

  /// Adds a row breakpoint.
  TomAclBuilder<T> addRowBreakpoint(
      {required double atWidth, double splitRowDist = 0}) {
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

  /// Sets the container padding.
  TomAclBuilder<T> setAclPadding(EdgeInsetsGeometry padding) {
    _builder.setAclPadding(padding);
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

  // ── Build ─────────────────────────────────────────────────────────────────

  /// Builds the final widget tree.
  ///
  /// Steps:
  /// 1. Check container-level authorization — if hidden, return [SizedBox.shrink].
  /// 2. Resolve title from resources if not explicitly set.
  /// 3. Build the underlying [AclBuilder].
  /// 4. Wrap in [TomNodeScope] providing the container's identity to descendants.
  ///
  /// ACL containers with IDs act as implicit group scopes — any widget inside
  /// can use this container's ID as part of their canonical path.
  ///
  /// The returned widget must be placed in a [BuildContext] that has a
  /// [TomThemeScope] ancestor for readonly styling (falls back to default).
  Widget build(BuildContext context) {
    final containerPath = TomIdPrefix.prefixed(TomIdPrefix.container, id);

    // Container-level authorization
    final auth = TomUIAuthorization.resolveAuth(containerPath);
    if (!auth.visible) return const SizedBox.shrink();

    // Resolve unset parameters from resources
    if (_explicitTitle == null) {
      final resourceTitle = TomUIResources.resolveText(containerPath, 'title');
      // Only use resource title if it doesn't look like a missing-key fallback
      if (!resourceTitle.startsWith('c-')) {
        _builder.setAclTitle(resourceTitle);
      }
    }
    if (!_explicitPadding) {
      final resPadding =
          TomUIResources.resolveEdgeInsets(containerPath, 'padding');
      if (resPadding != null) _builder.setAclPadding(resPadding);
    }
    if (!_explicitBackgroundColor) {
      final resBg =
          TomUIResources.resolveColor(containerPath, 'backgroundColor');
      if (resBg != null) _builder.setAclBackgroundColor(resBg);
    }
    if (!_explicitTitleStyle) {
      final resStyle =
          TomStyleResolvers.resolveTextStyle(containerPath, 'titleStyle');
      if (resStyle != null) _builder.setAclTitleStyle(resStyle);
    }
    if (!_explicitTitleVerticalOffset) {
      final resOffset = TomUIResources.resolveDouble(
          containerPath, 'titleVerticalOffset');
      if (resOffset != null) _builder.setAclTitleVerticalOffset(resOffset);
    }
    if (!_explicitBorderStyle) {
      final resBorder = _resolveBorderStyle(containerPath, 'borderStyle');
      if (resBorder != null) _builder.setAclBorderStyle(resBorder);
    }
    if (!_explicitFocusedBorderStyle) {
      final resFocused =
          _resolveBorderStyle(containerPath, 'focusedBorderStyle');
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

    final acl = _builder.build();

    // Wrap in TomNodeScope for descendant resource/auth resolution
    // ACL containers with IDs are implicit group scopes
    Widget result = acl;
    if (auth.readonly) {
      final style = TomThemeScope.readonlyStyleOf(context);
      result = style.apply(result);
    }

    return TomNodeScope.extend(
      context,
      containerId: id,
      child: result,
    );
  }

  /// Resolves an [AclBorderStyle] from a resource map at [basePath]/[suffix].
  AclBorderStyle? _resolveBorderStyle(String basePath, String suffix) {
    final map = TomUIResources.resolveMap(basePath, suffix);
    if (map == null || map.isEmpty) return null;
    return AclBorderStyle(
      kind: _parseBorderKind(map['kind'] as String?) ?? AclBorderKind.none,
      color: TomUIResources.resolveColor(basePath, '$suffix.color') ??
          const Color(0x00000000),
      lineWidth:
          TomUIResources.resolveDouble(basePath, '$suffix.lineWidth') ?? 1.0,
      rounded: TomUIResources.resolveBool(basePath, '$suffix.rounded') ?? false,
      borderRadius:
          TomUIResources.resolveDouble(basePath, '$suffix.borderRadius') ?? 0.0,
      borderInsets:
          TomUIResources.resolveEdgeInsets(basePath, '$suffix.borderInsets') ??
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
    final value = TomUIResources.resolveValue(basePath, 'titlePosition');
    if (value == null) return null;
    final text = value.toString();
    for (final pos in AclTitlePosition.values) {
      if (pos.name == text) return pos;
    }
    return null;
  }

  /// Resolves an [AclTitleBorderAlign] from a resource text at [basePath]/titleBorderAlign.
  AclTitleBorderAlign? _resolveTitleBorderAlign(String basePath) {
    final value = TomUIResources.resolveValue(basePath, 'titleBorderAlign');
    if (value == null) return null;
    final text = value.toString();
    for (final align in AclTitleBorderAlign.values) {
      if (align.name == text) return align;
    }
    return null;
  }
}
