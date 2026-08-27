/// Advanced Container Layout (ACL) — a fluent, row-based layout engine.
///
/// ACL builds form-like grids one component at a time. You describe a row's
/// contents in sequence — sizing, gaps, growth, borders, titled groups and
/// responsive variants — and `build()` hands back a plain Flutter widget. The
/// model is taken from the Java Swing `StdAdvancedContainer` /
/// `AdvancedContainerLike` API, extended with first-class authorization and
/// device-adaptive behaviour.
///
/// ## Start here
///
/// - [AclBuilder] — the fluent builder, and the only type most callers touch.
///   `append`, `gap`, `newRow`, `setPSize` / `setMSize`, `expandX`, `build`.
/// - [Acl] — what `build()` returns: the rendered layout widget. [AclLayout]
///   is its unwrapped form and [AclContainer] the render stage beneath both.
///
/// ```dart
/// final Widget layout = AclBuilder(title: 'Address')
///     .append(const Text('Street'))
///     .gap()
///     .append(const Text('No.'))
///     .expandX()
///     .newRow()
///     .append(const Text('City'))
///     .build();
/// ```
///
/// ## The rest of the surface
///
/// | Area | Types |
/// | ---- | ----- |
/// | Growth flags | [AclFlags] — `expandX` / `expandY` / `expand` |
/// | Borders and titled groups | [AclBorderStyle], [AclBorderKind], [AclTitlePosition], [AclTitleBorderAlign] |
/// | Separators in gap rows | [AclSeparator], [AclSeparatorStyle], [AclSeparatorAlignment] |
/// | Row-*generating* containers | [AclFlowContainer], [AclFlowKind] — `wrap` and `grid`, for a flat child list whose row breaks the container decides |
/// | Responsive variants | [AclVariant], [AclRowBreakpoint], [AclVariantDetector] |
/// | Device inputs behind those variants | [AclDeviceContext], [AclFormFactor], [AclDensity], [AclInputMode] |
/// | Group show / hide | [AclGroupVisibilityController], [AclBinaryVisibilityController], [AclCallbackVisibilityController] |
/// | Alignment and direction | [RowAlignment], [AclRowCrossAlignment], [AclDirection], [AclDirectionScope] |
///
/// ## Prose documentation
///
/// Two documents cover this unit, and they answer different questions:
///
/// - `doc/advanced_container_layout.md` — the **module reference**: the public
///   API of this unit in isolation, which is what you want while writing a
///   layout.
/// - `doc/acl_design_specification.md` — the **design specification**: why the
///   engine is shaped the way it is, and the cross-cutting rules (sizing
///   resolution, variant precedence, authorization) that the reference assumes.
///
/// `lib/src/advanced_container_layout/readme.md` is the short orientation
/// between the two.
library;

export 'acl_container.dart';
export 'acl_builder.dart';
export 'acl_device_context.dart';
export 'acl_flags.dart';
export 'acl_flow.dart';
export 'acl_group_visibility.dart';
export 'acl_responsive.dart';
export 'acl_scope.dart';
export 'row_alignment.dart';
