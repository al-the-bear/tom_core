import 'package:flutter/widgets.dart';

import '../../../resource_auth/tom_auth_state.dart';
import '../../../resource_auth/tom_id_prefix.dart';
import '../../../resource_auth/tom_resources.dart';
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

  TomAclBuilder({
    required this.id,
    required this.elementProvider,
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
  })  : _explicitTitle = title,
        _builder = AclBuilder(
          title: title,
          titleWidget: titleWidget,
          borderStyle: borderStyle,
          focusedBorderStyle: focusedBorderStyle,
          padding: padding,
          backgroundColor: backgroundColor,
          titleStyle: titleStyle,
          titlePosition: titlePosition,
          titleBorderAlign: titleBorderAlign,
          titleVerticalOffset: titleVerticalOffset,
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
  Widget build() {
    final containerPath = TomIdPrefix.prefixed(TomIdPrefix.container, id);

    // Container-level authorization
    final auth = TomUIAuthorization.resolveAuth(containerPath);
    if (!auth.visible) return const SizedBox.shrink();

    // Resolve title from resources if not explicitly set
    if (_explicitTitle == null) {
      final resourceTitle = TomUIResources.resolveText(containerPath, 'title');
      // Only use resource title if it doesn't look like a missing-key fallback
      if (!resourceTitle.startsWith('c-')) {
        _builder.setAclTitle(resourceTitle);
      }
    }

    final acl = _builder.build();

    // Wrap in TomNodeScope for descendant resource/auth resolution
    Widget result = acl;
    if (auth.readonly) {
      result = AbsorbPointer(child: Opacity(opacity: 0.6, child: result));
    }

    return TomNodeScope(
      fullIdPath: containerPath,
      groupName: null,
      child: result,
    );
  }
}
