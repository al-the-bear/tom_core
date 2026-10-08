# tom_flutter_ui API Reference: Widgets Module

The public surface of `lib/src/widgets/`, as its barrel exports it.

## Overview

Sources: `lib/src/widgets/animated/tom_animated.dart`, `lib/src/widgets/builders/tom_builders.dart`, `lib/src/widgets/buttons/tom_buttons.dart`, `lib/src/widgets/chips/tom_chips.dart`, `lib/src/widgets/containers/acl/tom_acl.dart`, `lib/src/widgets/containers/tom_containers.dart`, `lib/src/widgets/dialogs/tom_dialogs.dart`, `lib/src/widgets/dialogs/tom_messenger.dart`, `lib/src/widgets/effects/tom_effects.dart`, `lib/src/widgets/images/tom_images.dart`, `lib/src/widgets/inputs/tom_inputs.dart`, `lib/src/widgets/interactions/tom_interactions.dart`, `lib/src/widgets/labels/tom_labels.dart`, `lib/src/widgets/lists/tom_lists.dart`, `lib/src/widgets/navigation/tom_navigation.dart`, `lib/src/widgets/navigation/tom_page_route.dart`, `lib/src/widgets/progress/tom_progress.dart`, `lib/src/widgets/selects/tom_selects.dart`, `lib/src/widgets/sliders/tom_sliders.dart`, `lib/src/widgets/slivers/tom_slivers.dart`, `lib/src/widgets/tables/tom_tables.dart`, `lib/src/widgets/toggles/tom_toggles.dart`, `lib/src/widgets/trees/tom_trees.dart`, `lib/src/widgets/widgets.dart`.

## Classes

### TomAboutDialog

**Kind:** `class`

Tom wrapper for [AboutDialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applicationIcon` | `final Widget? applicationIcon` |  |
| `applicationLegalese` | `final String? applicationLegalese` |  |
| `applicationName` | `final String? applicationName` |  |
| `applicationVersion` | `final String? applicationVersion` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget>? children` |  |

### TomAboutListTile

**Kind:** `class`

Tom wrapper for [AboutListTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `aboutBoxChildren` | `final List<Widget>? aboutBoxChildren` |  |
| `applicationIcon` | `final Widget? applicationIcon` |  |
| `applicationLegalese` | `final String? applicationLegalese` |  |
| `applicationName` | `final String? applicationName` |  |
| `applicationVersion` | `final String? applicationVersion` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `dense` | `final bool dense` |  |
| `icon` | `final Widget? icon` |  |

### TomAbsorbPointer

**Kind:** `class`

Tom wrapper for [AbsorbPointer].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `absorbing` | `final bool? absorbing` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |

### TomAclBuilder

**Kind:** `class`

A delegating wrapper around [AclBuilder] that adds Tom UI concerns: - **Element provider** — typed access to screen elements via `(T p) => p.field`.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `addRowBreakpoint` | `TomAclBuilder<T> addRowBreakpoint({ required double atWidth, double splitRowDist = 0})` | Adds a row breakpoint. |
| `addVariant` | `TomAclBuilder<T> addVariant( String name, { required double atWidth, required void Function(AclBuilder) builder})` | Adds a responsive variant. |
| `alignBottomToBottom` | `TomAclBuilder<T> alignBottomToBottom(Widget reference, {double gap = 0})` |  |
| `alignBottomToMiddle` | `TomAclBuilder<T> alignBottomToMiddle(Widget reference, {double gap = 0})` |  |
| `alignBottomToTop` | `TomAclBuilder<T> alignBottomToTop(Widget reference, {double gap = 0})` |  |
| `alignCenterToCenter` | `TomAclBuilder<T> alignCenterToCenter(Widget reference, {double gap = 0})` |  |
| `alignCenterToLeft` | `TomAclBuilder<T> alignCenterToLeft(Widget reference, {double gap = 0})` |  |
| `alignCenterToRight` | `TomAclBuilder<T> alignCenterToRight(Widget reference, {double gap = 0})` |  |
| `alignLeftToCenter` | `TomAclBuilder<T> alignLeftToCenter(Widget reference, {double gap = 0})` |  |
| `alignLeftToLeft` | `TomAclBuilder<T> alignLeftToLeft(Widget reference, {double gap = 0})` |  |
| `alignLeftToRight` | `TomAclBuilder<T> alignLeftToRight(Widget reference, {double gap = 0})` |  |
| `alignMiddleToBottom` | `TomAclBuilder<T> alignMiddleToBottom(Widget reference, {double gap = 0})` |  |
| `alignMiddleToMiddle` | `TomAclBuilder<T> alignMiddleToMiddle(Widget reference, {double gap = 0})` |  |
| `alignMiddleToTop` | `TomAclBuilder<T> alignMiddleToTop(Widget reference, {double gap = 0})` |  |
| `alignRightToCenter` | `TomAclBuilder<T> alignRightToCenter(Widget reference, {double gap = 0})` |  |
| `alignRightToLeft` | `TomAclBuilder<T> alignRightToLeft(Widget reference, {double gap = 0})` |  |
| `alignRightToRight` | `TomAclBuilder<T> alignRightToRight(Widget reference, {double gap = 0})` |  |
| `alignTopToBottom` | `TomAclBuilder<T> alignTopToBottom(Widget reference, {double gap = 0})` |  |
| `alignTopToMiddle` | `TomAclBuilder<T> alignTopToMiddle(Widget reference, {double gap = 0})` |  |
| `alignTopToTop` | `TomAclBuilder<T> alignTopToTop(Widget reference, {double gap = 0})` |  |
| `append` | `TomAclBuilder<T> append( Widget Function(T provider) selector, { double dist = 0})` | Appends a widget selected from the element provider. |
| `appendForm` | `TomAclBuilder<T> appendForm( Widget Function(T provider) selector, { double dist = 0})` | Appends a form widget from the element provider. |
| `appendMasterDetail` | `TomAclBuilder<T> appendMasterDetail({ required Widget Function(T provider) master, required Widget Function(T provider) detail})` | Appends a master-detail layout with master and detail from the provider. |
| `build` | `Widget build(BuildContext context)` | Builds the final widget tree. |
| `clearAttr` | `TomAclBuilder<T> clearAttr(int attr)` | Clears a flag attribute on the current component. |
| `defaultFlags` | `int get defaultFlags` | Gets the current default flags. |
| `elementProvider` | `final T elementProvider` |  |
| `endGroup` | `TomAclBuilder<T> endGroup()` | Ends a group range. |
| `endVariant` | `TomAclBuilder<T> endVariant()` | Ends an inline variant block. |
| `expand` | `TomAclBuilder<T> expand()` | Expands the most recently appended component in both directions. |
| `expandX` | `TomAclBuilder<T> expandX()` | Expands the most recently appended component horizontally. |
| `expandY` | `TomAclBuilder<T> expandY()` | Expands the most recently appended component vertically. |
| `gap` | `TomAclBuilder<T> gap({double weight = 1})` | Inserts an elastic horizontal gap. |
| `gapRow` | `TomAclBuilder<T> gapRow({ double weight = 1, AclSeparator? separator, double minSize = 0})` | Inserts an elastic vertical gap row. |
| `group` | `TomAclBuilder<T> group(String name)` | Assigns the current component to a group. |
| `id` | `final String id` |  |
| `idScope` | `final bool idScope` | Whether this container contributes its ID to descendant paths. |
| `newRow` | `TomAclBuilder<T> newRow({ double dist = 0, double? height, List<(double, double?)> heightBpOverrides = const []})` | Starts a new content row. |
| `sameHeightAs` | `TomAclBuilder<T> sameHeightAs(Widget reference)` | Constrains the current component to the same height as [reference]. |
| `sameSize` | `TomAclBuilder<T> sameSize(Widget reference)` | Constrains the current component to the same size as [reference]. |
| `sameWidthAs` | `TomAclBuilder<T> sameWidthAs(Widget reference)` | Constrains the current component to the same width as [reference]. |
| `setAclBackgroundColor` | `TomAclBuilder<T> setAclBackgroundColor(Color color)` | Sets the background color. |
| `setAclBorderInsets` | `TomAclBuilder<T> setAclBorderInsets(EdgeInsetsGeometry insets)` | Sets the container border insets. |
| `setAclBorderStyle` | `TomAclBuilder<T> setAclBorderStyle(AclBorderStyle borderStyle)` | Sets the container border style. |
| `setAclDefaultAppendGap` | `TomAclBuilder<T> setAclDefaultAppendGap( double gap, [ List<(double, double)> gapBpOverrides = const []])` | Sets the default horizontal gap before each appended component, including the first component of every row. |
| `setAclDefaultFlags` | `TomAclBuilder<T> setAclDefaultFlags(int flags)` | Sets default flags for new components. |
| `setAclDefaultHideUnauthorized` | `TomAclBuilder<T> setAclDefaultHideUnauthorized(bool value)` | Container-wide default for hide-when-unauthorized. |
| `setAclDefaultRowGap` | `TomAclBuilder<T> setAclDefaultRowGap(int pixels)` | Sets the default vertical gap between content rows. |
| `setAclDefaultRowHeight` | `TomAclBuilder<T> setAclDefaultRowHeight( double? height, [ List<(double, double?)> heightBpOverrides = const []])` | Sets the builder-wide default row height. |
| `setAclDefaultRowHorizontalAlignment` | `TomAclBuilder<T> setAclDefaultRowHorizontalAlignment( AclRowAlignment alignment)` | Builder-wide default for the **horizontal** main-axis placement of every row. |
| `setAclDefaultRowVerticalAlignment` | `TomAclBuilder<T> setAclDefaultRowVerticalAlignment( AclRowCrossAlignment alignment)` | Builder-wide default for the **vertical** cross-axis placement of every row. |
| `setAclDefaultUnknownMinimumSize` | `TomAclBuilder<T> setAclDefaultUnknownMinimumSize( double width, [ double height = 0])` | Sets a default minimum size for components without an explicit minimum. |
| `setAclDefaultUnknownPreferredSize` | `TomAclBuilder<T> setAclDefaultUnknownPreferredSize( double width, [ double height = 0])` | Sets a default preferred size for components without an explicit preferred size. |
| `setAclDirection` | `TomAclBuilder<T> setAclDirection(AclDirection direction)` | Sets the layout direction (LTR/RTL). |
| `setAclExpandXDefault` | `TomAclBuilder<T> setAclExpandXDefault(bool enabled)` | Sets the default expand-X behaviour for newly appended components. |
| `setAclFocusedBorderStyle` | `TomAclBuilder<T> setAclFocusedBorderStyle(AclBorderStyle style)` | Sets the focused border style. |
| `setAclGroup` | `TomAclBuilder<T> setAclGroup(String name)` | Sets the container group. |
| `setAclMSize` | `TomAclBuilder<T> setAclMSize(double width, double height)` | Sets the minimum container size. |
| `setAclPSize` | `TomAclBuilder<T> setAclPSize(double width, double height)` | Sets the preferred container size. |
| `setAclPadding` | `TomAclBuilder<T> setAclPadding(EdgeInsetsGeometry padding)` | Sets the container padding. |
| `setAclPaddingBottom` | `TomAclBuilder<T> setAclPaddingBottom(double value)` | Sets the bottom padding. |
| `setAclPaddingLeft` | `TomAclBuilder<T> setAclPaddingLeft(double value)` | Sets the left padding. |
| `setAclPaddingPx` | `TomAclBuilder<T> setAclPaddingPx( double left, double top, double right, double bottom)` | Sets the container padding from explicit LTRB values. |
| `setAclPaddingRight` | `TomAclBuilder<T> setAclPaddingRight(double value)` | Sets the right padding. |
| `setAclPaddingTop` | `TomAclBuilder<T> setAclPaddingTop(double value)` | Sets the top padding. |
| `setAclScrollableX` | `TomAclBuilder<T> setAclScrollableX()` | Enables horizontal scrolling. |
| `setAclScrollableY` | `TomAclBuilder<T> setAclScrollableY()` | Enables vertical scrolling. |
| `setAclTitle` | `TomAclBuilder<T> setAclTitle(String? title)` | Sets the container title. |
| `setAclTitleBorderAlign` | `TomAclBuilder<T> setAclTitleBorderAlign(AclTitleBorderAlign align)` | Sets the title border alignment. |
| `setAclTitlePosition` | `TomAclBuilder<T> setAclTitlePosition(AclTitlePosition position)` | Sets the title position. |
| `setAclTitleStyle` | `TomAclBuilder<T> setAclTitleStyle(TextStyle style)` | Sets the title text style. |
| `setAclTitleVerticalOffset` | `TomAclBuilder<T> setAclTitleVerticalOffset(double offset)` | Sets the title vertical offset. |
| `setAclTitleWidget` | `TomAclBuilder<T> setAclTitleWidget(Widget? widget)` | Sets the container title widget. |
| `setAclXSize` | `TomAclBuilder<T> setAclXSize(double width, double height)` | Sets the maximum container size. |
| `setAttr` | `TomAclBuilder<T> setAttr(int attr)` | Sets a flag attribute on the current component. |
| `setComp` | `TomAclBuilder<T> setComp(Widget reference, int otherAttr)` | Sets a size reference to another component. |
| `setGroupVisibilityController` | `TomAclBuilder<T> setGroupVisibilityController( String groupName, AclGroupVisibilityController controller)` | Sets a group visibility controller. |
| `setHideUnauthorized` | `TomAclBuilder<T> setHideUnauthorized(bool? value)` | Per-component override for hide-when-unauthorized on the most recently appended component. |
| `setId` | `TomAclBuilder<T> setId(String componentId)` | Sets the component ID. |
| `setMSize` | `TomAclBuilder<T> setMSize(double width, [double height = 0])` | Sets a minimum size on the current component. |
| `setMWidthInChars` | `TomAclBuilder<T> setMWidthInChars(int chars, {double charWidth = 8})` | Sets the minimum width using a character count. |
| `setPSize` | `TomAclBuilder<T> setPSize(double width, [double height = 0])` | Sets a preferred size on the current component. |
| `setPWidthInChars` | `TomAclBuilder<T> setPWidthInChars( int chars, { double charWidth = 8, double height = 40})` | Sets the preferred width using a character count. |
| `setRowGroup` | `TomAclBuilder<T> setRowGroup(String name)` | Sets the row group. |
| `setRowHeight` | `TomAclBuilder<T> setRowHeight( double? height, [ List<(double, double?)> heightBpOverrides = const []])` | Sets the height on the current (most-recently-started) row. |
| `setRowHorizontalAlignment` | `TomAclBuilder<T> setRowHorizontalAlignment(AclRowAlignment alignment)` | Horizontal main-axis alignment for the **current row only**. |
| `setRowId` | `TomAclBuilder<T> setRowId(String rowId)` | Sets the row ID. |
| `setRowIdScope` | `TomAclBuilder<T> setRowIdScope(bool idScope)` | Sets whether the current row's ID contributes to descendant paths. |
| `setRowVerticalAlignment` | `TomAclBuilder<T> setRowVerticalAlignment(AclRowCrossAlignment alignment)` | Vertical cross-axis alignment for the **current row only** — inherited by components that don't call [setVerticalAlignment]. |
| `setVerticalAlignment` | `TomAclBuilder<T> setVerticalAlignment(AclRowCrossAlignment alignment)` | Overrides the vertical alignment for the **current component only** — takes precedence over the row and builder defaults. |
| `setXSize` | `TomAclBuilder<T> setXSize(double width, [double height = 0])` | Sets a maximum size on the current component. |
| `setXWidthInChars` | `TomAclBuilder<T> setXWidthInChars(int chars, {double charWidth = 8})` | Sets the maximum width using a character count. |
| `startGroup` | `TomAclBuilder<T> startGroup(String name)` | Begins a group range. |
| `startVariant` | `TomAclBuilder<T> startVariant({ double? width, double? height, AclInputMode? input, AclFormFactor? formFactor, Orientation? orientation, Set<TargetPlatform>? platforms, bool? isWeb, AclDensity? density, TextDirection? textDirection, double? minAccessibilityScale, AclVariantDetector? detector})` | Begins an inline variant block. |

### TomActionChip

**Kind:** `class`

Tom wrapper for [ActionChip].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `avatar` | `final Widget? avatar` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `elevation` | `final double? elevation` |  |
| `label` | `final Widget? label` |  |
| `labelPadding` | `final EdgeInsetsGeometry? labelPadding` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelText` | `final String? labelText` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `pressElevation` | `final double? pressElevation` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `side` | `final BorderSide? side` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `tooltip` | `final String? tooltip` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomAlertDialog

**Kind:** `class`

Tom wrapper for [AlertDialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actions` | `final List<Widget>? actions` |  |
| `actionsAlignment` | `final MainAxisAlignment? actionsAlignment` |  |
| `actionsOverflowAlignment` | `final OverflowBarAlignment? actionsOverflowAlignment` |  |
| `actionsOverflowButtonSpacing` | `final double? actionsOverflowButtonSpacing` |  |
| `actionsOverflowDirection` | `final VerticalDirection? actionsOverflowDirection` |  |
| `actionsPadding` | `final EdgeInsetsGeometry? actionsPadding` |  |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `buttonPadding` | `final EdgeInsetsGeometry? buttonPadding` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `content` | `final Widget? content` |  |
| `contentPadding` | `final EdgeInsetsGeometry? contentPadding` |  |
| `contentTextStyle` | `final TextStyle? contentTextStyle` |  |
| `elevation` | `final double? elevation` |  |
| `icon` | `final Widget? icon` |  |
| `iconColor` | `final Color? iconColor` |  |
| `iconPadding` | `final EdgeInsetsGeometry? iconPadding` |  |
| `insetPadding` | `final EdgeInsets insetPadding` |  |
| `scrollable` | `final bool scrollable` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `title` | `final Widget? title` |  |
| `titlePadding` | `final EdgeInsetsGeometry? titlePadding` |  |
| `titleText` | `final String? titleText` |  |
| `titleTextStyle` | `final TextStyle? titleTextStyle` |  |

### TomAlign

**Kind:** `class`

Tom wrapper for [Align].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `heightFactor` | `final double? heightFactor` |  |
| `widthFactor` | `final double? widthFactor` |  |

### TomAnimatedAlign

**Kind:** `class`

Tom wrapper for [AnimatedAlign].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `heightFactor` | `final double? heightFactor` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `widthFactor` | `final double? widthFactor` |  |

### TomAnimatedBuilder

**Kind:** `class`

Tom wrapper for [AnimatedBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final TransitionBuilder builder` |  |
| `child` | `final Widget? child` |  |
| `effectiveListenable` | `Listenable get effectiveListenable` |  |

### TomAnimatedContainer

**Kind:** `class`

Tom wrapper for [AnimatedContainer].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final Color? color` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `curve` | `final Curve curve` |  |
| `decoration` | `final Decoration? decoration` |  |
| `duration` | `final Duration? duration` |  |
| `foregroundDecoration` | `final Decoration? foregroundDecoration` |  |
| `height` | `final double? height` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `transform` | `final Matrix4? transform` |  |
| `transformAlignment` | `final AlignmentGeometry? transformAlignment` |  |
| `width` | `final double? width` |  |

### TomAnimatedCrossFade

**Kind:** `class`

Tom wrapper for [AnimatedCrossFade].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `crossFadeState` | `final CrossFadeState crossFadeState` |  |
| `duration` | `final Duration? duration` |  |
| `excludeBottomFocus` | `final bool? excludeBottomFocus` |  |
| `firstChild` | `final Widget firstChild` |  |
| `firstCurve` | `final Curve firstCurve` |  |
| `layoutBuilder` | `final AnimatedCrossFadeBuilder layoutBuilder` |  |
| `reverseDuration` | `final Duration? reverseDuration` |  |
| `secondChild` | `final Widget secondChild` |  |
| `secondCurve` | `final Curve secondCurve` |  |
| `sizeCurve` | `final Curve sizeCurve` |  |

### TomAnimatedDefaultTextStyle

**Kind:** `class`

Tom wrapper for [AnimatedDefaultTextStyle].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `maxLines` | `final int? maxLines` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `overflow` | `final TextOverflow overflow` |  |
| `softWrap` | `final bool? softWrap` |  |
| `style` | `final TextStyle style` |  |
| `textAlign` | `final TextAlign? textAlign` |  |
| `textHeightBehavior` | `final TextHeightBehavior? textHeightBehavior` |  |
| `textWidthBasis` | `final TextWidthBasis textWidthBasis` |  |

### TomAnimatedFractionallySizedBox

**Kind:** `class`

Tom wrapper for [AnimatedFractionallySizedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `heightFactor` | `final double? heightFactor` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `widthFactor` | `final double? widthFactor` |  |

### TomAnimatedIcon

**Kind:** `class`

Tom wrapper for [AnimatedIcon].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `icon` | `final AnimatedIconData icon` |  |
| `progress` | `final Animation<double> progress` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `size` | `final double? size` |  |
| `textDirection` | `final TextDirection? textDirection` |  |

### TomAnimatedList

**Kind:** `class`

Tom wrapper for [AnimatedList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `initialItemCount` | `final int initialItemCount` |  |
| `itemBuilder` | `final AnimatedItemBuilder itemBuilder` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `primary` | `final bool? primary` |  |
| `reverse` | `final bool reverse` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |
| `shrinkWrap` | `final bool shrinkWrap` |  |

### TomAnimatedOpacity

**Kind:** `class`

Tom wrapper for [AnimatedOpacity].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alwaysIncludeSemantics` | `final bool? alwaysIncludeSemantics` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `opacity` | `final double? opacity` |  |

### TomAnimatedPadding

**Kind:** `class`

Tom wrapper for [AnimatedPadding].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |

### TomAnimatedPhysicalModel

**Kind:** `class`

Tom wrapper for [AnimatedPhysicalModel].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `animateColor` | `final bool? animateColor` |  |
| `animateShadowColor` | `final bool? animateShadowColor` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final Color? color` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `elevation` | `final double? elevation` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final BoxShape shape` |  |

### TomAnimatedPositioned

**Kind:** `class`

Tom wrapper for [AnimatedPositioned] with construction-time resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-widget authorizer, applied after the group's mode. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomAnimatedPositionedDirectional

**Kind:** `class`

Tom wrapper for [AnimatedPositionedDirectional] with construction-time resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-widget authorizer, applied after the group's mode. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomAnimatedRotation

**Kind:** `class`

Tom wrapper for [AnimatedRotation].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final Alignment? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `filterQuality` | `final FilterQuality? filterQuality` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `turns` | `final double? turns` |  |

### TomAnimatedScale

**Kind:** `class`

Tom wrapper for [AnimatedScale].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final Alignment? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `filterQuality` | `final FilterQuality? filterQuality` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `scale` | `final double? scale` |  |

### TomAnimatedSize

**Kind:** `class`

Tom wrapper for [AnimatedSize].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |
| `reverseDuration` | `final Duration? reverseDuration` |  |

### TomAnimatedSlide

**Kind:** `class`

Tom wrapper for [AnimatedSlide].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `duration` | `final Duration? duration` |  |
| `offset` | `final Offset? offset` |  |
| `onEnd` | `final VoidCallback? onEnd` |  |

### TomAnimatedSwitcher

**Kind:** `class`

Tom wrapper for [AnimatedSwitcher].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `duration` | `final Duration? duration` |  |
| `layoutBuilder` | `final AnimatedSwitcherLayoutBuilder layoutBuilder` |  |
| `reverseDuration` | `final Duration? reverseDuration` |  |
| `switchInCurve` | `final Curve switchInCurve` |  |
| `switchOutCurve` | `final Curve switchOutCurve` |  |
| `transitionBuilder` | `final AnimatedSwitcherTransitionBuilder transitionBuilder` |  |

### TomAppBar

**Kind:** `class`

Tom wrapper for [AppBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actions` | `final List<Widget>? actions` |  |
| `actionsIconTheme` | `final IconThemeData? actionsIconTheme` |  |
| `automaticallyImplyLeading` | `final bool automaticallyImplyLeading` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `bottom` | `final PreferredSizeWidget? bottom` |  |
| `bottomOpacity` | `final double bottomOpacity` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `centerTitle` | `final bool? centerTitle` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `elevation` | `final double? elevation` |  |
| `excludeHeaderSemantics` | `final bool excludeHeaderSemantics` |  |
| `flexibleSpace` | `final Widget? flexibleSpace` |  |
| `forceMaterialTransparency` | `final bool forceMaterialTransparency` |  |
| `foregroundColor` | `final Color? foregroundColor` |  |
| `iconTheme` | `final IconThemeData? iconTheme` |  |
| `leading` | `final Widget? leading` |  |
| `leadingWidth` | `final double? leadingWidth` |  |
| `notificationPredicate` | `final ScrollNotificationPredicate notificationPredicate` |  |
| `preferredSize` | `Size get preferredSize` |  |
| `primary` | `final bool primary` |  |
| `scrolledUnderElevation` | `final double? scrolledUnderElevation` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `systemOverlayStyle` | `final SystemUiOverlayStyle? systemOverlayStyle` |  |
| `title` | `final Widget? title` |  |
| `titleSpacing` | `final double? titleSpacing` |  |
| `titleText` | `final String? titleText` |  |
| `titleTextStyle` | `final TextStyle? titleTextStyle` |  |
| `toolbarHeight` | `final double? toolbarHeight` |  |
| `toolbarOpacity` | `final double toolbarOpacity` |  |
| `toolbarTextStyle` | `final TextStyle? toolbarTextStyle` |  |

### TomAspectRatio

**Kind:** `class`

Tom wrapper for [AspectRatio].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `aspectRatio` | `final double aspectRatio` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |

### TomAssetImage

**Kind:** `class`

Tom wrapper for [Image] that uses [AssetImage] as its provider.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `bundle` | `final AssetBundle? bundle` |  |
| `cacheHeight` | `final int? cacheHeight` |  |
| `cacheWidth` | `final int? cacheWidth` |  |
| `centerSlice` | `final Rect? centerSlice` |  |
| `color` | `final Color? color` |  |
| `colorBlendMode` | `final BlendMode? colorBlendMode` |  |
| `errorBuilder` | `final ImageErrorWidgetBuilder? errorBuilder` |  |
| `excludeFromSemantics` | `final bool excludeFromSemantics` |  |
| `filterQuality` | `final FilterQuality filterQuality` |  |
| `fit` | `final BoxFit? fit` |  |
| `frameBuilder` | `final ImageFrameBuilder? frameBuilder` |  |
| `gaplessPlayback` | `final bool gaplessPlayback` |  |
| `height` | `final double? height` |  |
| `isAntiAlias` | `final bool isAntiAlias` |  |
| `matchTextDirection` | `final bool matchTextDirection` |  |
| `name` | `final String name` |  |
| `package` | `final String? package` |  |
| `repeat` | `final ImageRepeat repeat` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `width` | `final double? width` |  |

### TomAutocomplete

**Kind:** `class`

Tom wrapper for [Autocomplete].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `displayStringForOption` | `final AutocompleteOptionToString<T> displayStringForOption` |  |
| `fieldViewBuilder` | `final AutocompleteFieldViewBuilder fieldViewBuilder` |  |
| `initialValue` | `final TextEditingValue? initialValue` |  |
| `onSelected` | `final AutocompleteOnSelected<T>? onSelected` |  |
| `optionsBuilder` | `final AutocompleteOptionsBuilder<T> optionsBuilder` |  |
| `optionsViewBuilder` | `final AutocompleteOptionsViewBuilder<T>? optionsViewBuilder` |  |
| `optionsViewOpenDirection` | `final OptionsViewOpenDirection optionsViewOpenDirection` |  |

### TomBackButton

**Kind:** `class`

Tom wrapper for [BackButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |

### TomBackdropFilter

**Kind:** `class`

Tom wrapper for [BackdropFilter].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `blendMode` | `final BlendMode? blendMode` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `filter` | `final ImageFilter filter` |  |

### TomBadge

**Kind:** `class`

Tom wrapper for [Badge].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `isLabelVisible` | `final bool isLabelVisible` |  |
| `label` | `final Widget? label` |  |
| `labelText` | `final String? labelText` |  |
| `largeSize` | `final double? largeSize` |  |
| `offset` | `final Offset? offset` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `smallSize` | `final double? smallSize` |  |
| `textColor` | `final Color? textColor` |  |
| `textStyle` | `final TextStyle? textStyle` |  |

### TomBanner

**Kind:** `class`

Tom wrapper for [Banner].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `color` | `final Color? color` |  |
| `location` | `final BannerLocation location` |  |
| `message` | `final String? message` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textStyle` | `final TextStyle textStyle` |  |

### TomBaseline

**Kind:** `class`

Tom wrapper for [Baseline].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `baseline` | `final double? baseline` |  |
| `baselineType` | `final TextBaseline baselineType` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |

### TomBottomAppBar

**Kind:** `class`

Tom wrapper for [BottomAppBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final Color? color` |  |
| `elevation` | `final double? elevation` |  |
| `height` | `final double? height` |  |
| `notchMargin` | `final double notchMargin` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final NotchedShape? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |

### TomBottomNavigationBar

**Kind:** `class`

Tom wrapper for [BottomNavigationBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `currentIndex` | `final int currentIndex` |  |
| `elevation` | `final double? elevation` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `fixedColor` | `final Color? fixedColor` |  |
| `iconSize` | `final double? iconSize` |  |
| `items` | `final List<BottomNavigationBarItem> items` |  |
| `landscapeLayout` | `final BottomNavigationBarLandscapeLayout? landscapeLayout` |  |
| `mouseCursor` | `final MouseCursor? mouseCursor` |  |
| `onTap` | `final ValueChanged<int>? onTap` |  |
| `selectedFontSize` | `final double? selectedFontSize` |  |
| `selectedIconTheme` | `final IconThemeData? selectedIconTheme` |  |
| `selectedItemColor` | `final Color? selectedItemColor` |  |
| `selectedLabelStyle` | `final TextStyle? selectedLabelStyle` |  |
| `showSelectedLabels` | `final bool? showSelectedLabels` |  |
| `showUnselectedLabels` | `final bool? showUnselectedLabels` |  |
| `type` | `final BottomNavigationBarType? type` |  |
| `unselectedFontSize` | `final double? unselectedFontSize` |  |
| `unselectedIconTheme` | `final IconThemeData? unselectedIconTheme` |  |
| `unselectedItemColor` | `final Color? unselectedItemColor` |  |
| `unselectedLabelStyle` | `final TextStyle? unselectedLabelStyle` |  |

### TomBottomSheet

**Kind:** `class`

Tom wrapper for [BottomSheet].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `animationController` | `final AnimationController? animationController` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final WidgetBuilder builder` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `elevation` | `final double? elevation` |  |
| `enableDrag` | `final bool enableDrag` |  |
| `onClosing` | `final VoidCallback onClosing` |  |
| `onDragEnd` | `final BottomSheetDragEndHandler? onDragEnd` |  |
| `onDragStart` | `final BottomSheetDragStartHandler? onDragStart` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `showDragHandle` | `final bool? showDragHandle` |  |

### TomBreadcrumb

**Kind:** `class`

Tom wrapper for a custom Breadcrumb navigation widget.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `crossAxisAlignment` | `final CrossAxisAlignment crossAxisAlignment` |  |
| `items` | `final List<Widget> items` |  |
| `mainAxisAlignment` | `final MainAxisAlignment mainAxisAlignment` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `separator` | `final Widget separator` |  |

### TomCalendarDatePicker

**Kind:** `class`

Tom wrapper for [CalendarDatePicker].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `currentDate` | `final DateTime? currentDate` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `initialDate` | `final DateTime initialDate` |  |
| `lastDate` | `final DateTime lastDate` |  |
| `onDateChanged` | `final ValueChanged<DateTime> onDateChanged` |  |
| `selectableDayPredicate` | `final SelectableDayPredicate? selectableDayPredicate` |  |

### TomCard

**Kind:** `class`

Tom wrapper for [Card].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `borderOnForeground` | `final bool borderOnForeground` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `color` | `final Color? color` |  |
| `elevation` | `final double? elevation` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `semanticContainer` | `final bool semanticContainer` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |

### TomCarouselView

**Kind:** `class`

Tom wrapper for [CarouselView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `controller` | `final CarouselController? controller` |  |
| `elevation` | `final double? elevation` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `onTap` | `final ValueChanged<int>? onTap` |  |
| `overlayColor` | `final Clip? overlayColor` |  |
| `padding` | `final EdgeInsets? padding` |  |
| `reverse` | `final bool reverse` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `shrinkExtent` | `final double? shrinkExtent` |  |

### TomCenter

**Kind:** `class`

Tom wrapper for [Center].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `heightFactor` | `final double? heightFactor` |  |
| `widthFactor` | `final double? widthFactor` |  |

### TomCheckbox

**Kind:** `class`

Tom wrapper for [Checkbox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkColor` | `final Color? checkColor` |  |
| `fillColor` | `final WidgetStateProperty<Color?>? fillColor` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `isError` | `final bool isError` |  |
| `onChanged` | `final ValueChanged<bool?>? onChanged` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `side` | `final BorderSide? side` |  |
| `splashRadius` | `final double? splashRadius` |  |
| `tristate` | `final bool tristate` |  |
| `value` | `final bool? value` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomCheckboxListTile

**Kind:** `class`

Tom wrapper for [CheckboxListTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkColor` | `final Color? checkColor` |  |
| `checkboxShape` | `final OutlinedBorder? checkboxShape` |  |
| `contentPadding` | `final EdgeInsetsGeometry? contentPadding` |  |
| `controlAffinity` | `final ListTileControlAffinity controlAffinity` |  |
| `dense` | `final bool? dense` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `isThreeLine` | `final bool isThreeLine` |  |
| `onChanged` | `final ValueChanged<bool?>? onChanged` |  |
| `secondary` | `final Widget? secondary` |  |
| `selectedTileColor` | `final Color? selectedTileColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `side` | `final BorderSide? side` |  |
| `subtitle` | `final Widget? subtitle` |  |
| `tileColor` | `final Color? tileColor` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |
| `tristate` | `final bool tristate` |  |
| `value` | `final bool? value` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomCheckboxMenuButton

**Kind:** `class`

Tom wrapper for [CheckboxMenuButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `isError` | `final bool isError` |  |
| `label` | `final String? label` |  |
| `onChanged` | `final ValueChanged<bool?>? onChanged` |  |
| `onFocusChange` | `final VoidCallback? onFocusChange` |  |
| `onHover` | `final VoidCallback? onHover` |  |
| `shortcut` | `final MenuSerializableShortcut? shortcut` |  |
| `tristate` | `final bool tristate` |  |
| `value` | `final bool? value` |  |

### TomCheckedPopupMenuItem

**Kind:** `class`

Tom widget that EXTENDS [CheckedPopupMenuItem] with authorization.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomChip

**Kind:** `class`

Tom wrapper for [Chip] (as label display).

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `avatar` | `final Widget? avatar` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final WidgetStateProperty<Color?>? color` |  |
| `deleteButtonTooltipMessage` | `final String? deleteButtonTooltipMessage` |  |
| `deleteIcon` | `final Widget? deleteIcon` |  |
| `deleteIconColor` | `final Color? deleteIconColor` |  |
| `elevation` | `final double? elevation` |  |
| `iconTheme` | `final IconThemeData? iconTheme` |  |
| `label` | `final Widget? label` |  |
| `labelPadding` | `final EdgeInsetsGeometry? labelPadding` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelText` | `final String? labelText` |  |
| `materialTapTargetSize` | `final MaterialTapTargetSize? materialTapTargetSize` |  |
| `onDeleted` | `final VoidCallback? onDeleted` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `side` | `final BorderSide? side` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomChoiceChip

**Kind:** `class`

Tom wrapper for [ChoiceChip].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `avatar` | `final Widget? avatar` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `disabledColor` | `final Color? disabledColor` |  |
| `elevation` | `final double? elevation` |  |
| `label` | `final Widget? label` |  |
| `labelPadding` | `final EdgeInsetsGeometry? labelPadding` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelText` | `final String? labelText` |  |
| `onSelected` | `final ValueChanged<bool>? onSelected` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `pressElevation` | `final double? pressElevation` |  |
| `selected` | `final bool selected` |  |
| `selectedColor` | `final Color? selectedColor` |  |
| `selectedShadowColor` | `final Color? selectedShadowColor` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `side` | `final BorderSide? side` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomCircleAvatar

**Kind:** `class`

Tom wrapper for [CircleAvatar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `backgroundImage` | `final ImageProvider? backgroundImage` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `foregroundColor` | `final Color? foregroundColor` |  |
| `foregroundImage` | `final ImageProvider? foregroundImage` |  |
| `maxRadius` | `final double? maxRadius` |  |
| `minRadius` | `final double? minRadius` |  |
| `onBackgroundImageError` | `final ImageErrorListener? onBackgroundImageError` |  |
| `onForegroundImageError` | `final ImageErrorListener? onForegroundImageError` |  |
| `radius` | `final double? radius` |  |

### TomCircularProgressIndicator

**Kind:** `class`

Tom wrapper for [CircularProgressIndicator].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `semanticsLabel` | `final String? semanticsLabel` |  |
| `semanticsValue` | `final String? semanticsValue` |  |
| `strokeAlign` | `final double strokeAlign` |  |
| `strokeCap` | `final StrokeCap? strokeCap` |  |
| `strokeWidth` | `final double? strokeWidth` |  |
| `value` | `final double? value` |  |
| `valueColor` | `final Animation<Color?>? valueColor` |  |

### TomClipOval

**Kind:** `class`

Tom wrapper for [ClipOval].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `clipper` | `final CustomClipper<Rect>? clipper` |  |

### TomClipPath

**Kind:** `class`

Tom wrapper for [ClipPath].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `clipper` | `final CustomClipper<Path>? clipper` |  |

### TomClipRRect

**Kind:** `class`

Tom wrapper for [ClipRRect].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `borderRadius` | `final BorderRadiusGeometry borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `clipper` | `final CustomClipper<RRect>? clipper` |  |

### TomClipRSuperellipse

**Kind:** `class`

Tom wrapper for [ClipRSuperellipse].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `borderRadius` | `final BorderRadiusGeometry borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |

### TomClipRect

**Kind:** `class`

Tom wrapper for [ClipRect].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `clipper` | `final CustomClipper<Rect>? clipper` |  |

### TomCloseButton

**Kind:** `class`

Tom wrapper for [CloseButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |

### TomColorFiltered

**Kind:** `class`

Tom wrapper for [ColorFiltered].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `colorFilter` | `final ColorFilter colorFilter` |  |

### TomColoredBox

**Kind:** `class`

Tom wrapper for [ColoredBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `color` | `final Color? color` |  |

### TomColumn

**Kind:** `class`

Tom wrapper for [Column].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `crossAxisAlignment` | `final CrossAxisAlignment crossAxisAlignment` |  |
| `mainAxisAlignment` | `final MainAxisAlignment mainAxisAlignment` |  |
| `mainAxisSize` | `final MainAxisSize mainAxisSize` |  |
| `textBaseline` | `final TextBaseline? textBaseline` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `verticalDirection` | `final VerticalDirection verticalDirection` |  |

### TomConstrainedBox

**Kind:** `class`

Tom wrapper for [ConstrainedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `constraints` | `final BoxConstraints constraints` |  |

### TomConstraintsTransformBox

**Kind:** `class`

Tom wrapper for [ConstraintsTransformBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `constraintsTransform` | `final BoxConstraintsTransform constraintsTransform` |  |
| `debugTransformType` | `final String debugTransformType` |  |
| `textDirection` | `final TextDirection? textDirection` |  |

### TomContainer

**Kind:** `class`

Tom wrapper for [Container].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final Color? color` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `decoration` | `final Decoration? decoration` |  |
| `foregroundDecoration` | `final Decoration? foregroundDecoration` |  |
| `height` | `final double? height` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `transform` | `final Matrix4? transform` |  |
| `transformAlignment` | `final AlignmentGeometry? transformAlignment` |  |
| `width` | `final double? width` |  |

### TomCupertinoActionSheet

**Kind:** `class`

Tom wrapper for [CupertinoActionSheet].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actionScrollController` | `final ScrollController? actionScrollController` |  |
| `actions` | `final List<Widget> actions` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `cancelButton` | `final Widget? cancelButton` |  |
| `message` | `final Widget? message` |  |
| `messageScrollController` | `final ScrollController? messageScrollController` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |

### TomCupertinoActionSheetAction

**Kind:** `class`

Tom wrapper for [CupertinoActionSheetAction].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `isDefaultAction` | `final bool isDefaultAction` |  |
| `isDestructiveAction` | `final bool isDestructiveAction` |  |
| `onPressed` | `final VoidCallback onPressed` |  |

### TomCupertinoActivityIndicator

**Kind:** `class`

Tom wrapper for [CupertinoActivityIndicator].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `animating` | `final bool animating` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `radius` | `final double radius` |  |

### TomCupertinoAlertDialog

**Kind:** `class`

Tom wrapper for [CupertinoAlertDialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actionScrollController` | `final ScrollController? actionScrollController` |  |
| `actions` | `final List<Widget> actions` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `content` | `final Widget? content` |  |
| `insetAnimationCurve` | `final EdgeInsets? insetAnimationCurve` |  |
| `scrollController` | `final ScrollController? scrollController` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |

### TomCupertinoButton

**Kind:** `class`

Tom wrapper for [CupertinoButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `color` | `final Color? color` |  |
| `disabledColor` | `final Color disabledColor` |  |
| `filled` | `final bool filled` |  |
| `label` | `final String? label` |  |
| `minSize` | `final double? minSize` | The button's minimum edge length, forwarded to [CupertinoButton.minimumSize] as a square. |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `pressedOpacity` | `final double? pressedOpacity` |  |

### TomCupertinoCheckbox

**Kind:** `class`

Tom wrapper for [CupertinoCheckbox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkColor` | `final Color? checkColor` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `inactiveColor` | `final Color? inactiveColor` |  |
| `onChanged` | `final ValueChanged<bool?>? onChanged` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `side` | `final BorderSide? side` |  |
| `tristate` | `final bool tristate` |  |
| `value` | `final bool? value` |  |

### TomCupertinoContextMenu

**Kind:** `class`

Tom wrapper for [CupertinoContextMenu].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actions` | `final List<Widget> actions` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `enableHapticFeedback` | `final bool? enableHapticFeedback` |  |

### TomCupertinoContextMenuAction

**Kind:** `class`

Tom wrapper for [CupertinoContextMenuAction].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `isDefaultAction` | `final bool isDefaultAction` |  |
| `isDestructiveAction` | `final bool isDestructiveAction` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `trailingIcon` | `final IconData? trailingIcon` |  |

### TomCupertinoDatePicker

**Kind:** `class`

Tom wrapper for [CupertinoDatePicker].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `initialDateTime` | `final DateTime? initialDateTime` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `maximumDate` | `final DateTime? maximumDate` |  |
| `maximumYear` | `final int? maximumYear` |  |
| `minimumDate` | `final DateTime? minimumDate` |  |
| `minimumYear` | `final int minimumYear` |  |
| `minuteInterval` | `final int minuteInterval` |  |
| `mode` | `final CupertinoDatePickerMode mode` |  |
| `onDateTimeChanged` | `final ValueChanged<DateTime> onDateTimeChanged` |  |
| `showDayOfWeek` | `final bool showDayOfWeek` |  |
| `use24hFormat` | `final bool use24hFormat` |  |

### TomCupertinoDialogAction

**Kind:** `class`

Tom wrapper for [CupertinoDialogAction].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `isDefaultAction` | `final bool isDefaultAction` |  |
| `isDestructiveAction` | `final bool isDestructiveAction` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `textStyle` | `final TextStyle? textStyle` |  |

### TomCupertinoExpansionTile

**Kind:** `class`

Tom wrapper for [CupertinoExpansionTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `controller` | `final ExpansibleController? controller` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |
| `transitionMode` | `final ExpansionTileTransitionMode transitionMode` |  |

### TomCupertinoFormRow

**Kind:** `class`

Tom wrapper for [CupertinoFormRow].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `error` | `final Widget? error` |  |
| `helper` | `final Widget? helper` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `prefix` | `final Widget? prefix` |  |

### TomCupertinoFormSection

**Kind:** `class`

Tom wrapper for [CupertinoFormSection].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `decoration` | `final BoxDecoration? decoration` |  |
| `footer` | `final Widget? footer` |  |
| `header` | `final Widget? header` |  |
| `insetGrouped` | `final bool insetGrouped` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |

### TomCupertinoLinearActivityIndicator

**Kind:** `class`

Tom wrapper for [CupertinoActivityIndicator.partiallyRevealed].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `trackHeight` | `final double? trackHeight` |  |
| `value` | `final double? value` |  |

### TomCupertinoListSection

**Kind:** `class`

Tom wrapper for [CupertinoListSection].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `additionalDividerMargin` | `final double additionalDividerMargin` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `decoration` | `final Widget? decoration` |  |
| `dividerMargin` | `final Color? dividerMargin` |  |
| `footer` | `final Widget? footer` |  |
| `hasLeading` | `final bool? hasLeading` |  |
| `header` | `final Widget? header` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `separatorColor` | `final Widget? separatorColor` |  |
| `topMargin` | `final double? topMargin` |  |
| `type` | `final CupertinoListSectionType type` |  |

### TomCupertinoListTile

**Kind:** `class`

Tom wrapper for [CupertinoListTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `additionalInfo` | `final Widget? additionalInfo` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `leading` | `final Widget? leading` |  |
| `leadingSize` | `final double? leadingSize` |  |
| `leadingToTitle` | `final double? leadingToTitle` |  |
| `onTap` | `final VoidCallback? onTap` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `subtitle` | `final Widget? subtitle` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |
| `trailing` | `final Widget? trailing` |  |

### TomCupertinoNavigationBar

**Kind:** `class`

Tom wrapper for [CupertinoNavigationBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `automaticallyImplyLeading` | `final bool automaticallyImplyLeading` |  |
| `automaticallyImplyMiddle` | `final bool automaticallyImplyMiddle` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `border` | `final Border? border` |  |
| `brightness` | `final Brightness? brightness` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `heroTag` | `final Object? heroTag` |  |
| `leading` | `final Widget? leading` |  |
| `middle` | `final Widget? middle` |  |
| `padding` | `final EdgeInsetsDirectional? padding` |  |
| `previousPageTitle` | `final String? previousPageTitle` |  |
| `trailing` | `final Widget? trailing` |  |
| `transitionBetweenRoutes` | `final bool transitionBetweenRoutes` |  |

### TomCupertinoNavigationBarBackButton

**Kind:** `class`

Tom wrapper for [CupertinoNavigationBarBackButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `previousPageTitle` | `final String? previousPageTitle` |  |

### TomCupertinoPageScaffold

**Kind:** `class`

Tom wrapper for [CupertinoPageScaffold].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `navigationBar` | `final ObstructingPreferredSizeWidget? navigationBar` |  |
| `resizeToAvoidBottomInset` | `final bool resizeToAvoidBottomInset` |  |

### TomCupertinoPicker

**Kind:** `class`

Tom wrapper for [CupertinoPicker].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `diameterRatio` | `final double? diameterRatio` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `looping` | `final bool looping` |  |
| `magnification` | `final double? magnification` |  |
| `offAxisFraction` | `final double? offAxisFraction` |  |
| `onSelectedItemChanged` | `final ValueChanged<int> onSelectedItemChanged` |  |
| `selectionOverlay` | `final Widget? selectionOverlay` |  |
| `squeeze` | `final double? squeeze` |  |
| `useMagnifier` | `final bool useMagnifier` |  |

### TomCupertinoRadio

**Kind:** `class`

Tom wrapper for [CupertinoRadio].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `enabled` | `final bool? enabled` | Whether the radio accepts input, forwarded to [CupertinoRadio.enabled]. |
| `fillColor` | `final Color? fillColor` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `inactiveColor` | `final Color? inactiveColor` |  |
| `mouseCursor` | `final MouseCursor? mouseCursor` |  |
| `toggleable` | `final bool toggleable` |  |
| `useCheckmarkStyle` | `final bool useCheckmarkStyle` |  |
| `value` | `final T value` |  |

### TomCupertinoScrollbar

**Kind:** `class`

Tom wrapper for [CupertinoScrollbar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `controller` | `final ScrollController? controller` |  |
| `notificationPredicate` | `final ScrollNotificationPredicate? notificationPredicate` |  |
| `radius` | `final Radius radius` |  |
| `radiusWhileDragging` | `final Radius radiusWhileDragging` |  |
| `thickness` | `final double? thickness` |  |
| `thicknessWhileDragging` | `final double? thicknessWhileDragging` |  |
| `thumbVisibility` | `final bool? thumbVisibility` |  |

### TomCupertinoSearchTextField

**Kind:** `class`

Tom wrapper for [CupertinoSearchTextField].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autocorrect` | `final bool autocorrect` |  |
| `autofocus` | `final bool autofocus` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `controller` | `final TextEditingController? controller` |  |
| `decoration` | `final BoxDecoration? decoration` |  |
| `enabled` | `final bool enabled` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `itemColor` | `final Color? itemColor` |  |
| `itemSize` | `final double? itemSize` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onSubmitted` | `final ValueChanged<String>? onSubmitted` |  |
| `onSuffixTap` | `final VoidCallback? onSuffixTap` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `placeholder` | `final String? placeholder` |  |
| `placeholderStyle` | `final TextStyle? placeholderStyle` |  |
| `prefixIcon` | `final Widget prefixIcon` |  |
| `restorationId` | `final String? restorationId` |  |
| `smartDashesType` | `final SmartDashesType? smartDashesType` |  |
| `smartQuotesType` | `final SmartQuotesType? smartQuotesType` |  |
| `style` | `final TextStyle? style` |  |
| `suffixIcon` | `final Icon suffixIcon` |  |
| `suffixMode` | `final OverlayVisibilityMode suffixMode` |  |

### TomCupertinoSegmentedControl

**Kind:** `class`

Tom wrapper for [CupertinoSegmentedControl].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `borderColor` | `final Color? borderColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final Map<T, Widget> children` |  |
| `groupValue` | `final T? groupValue` |  |
| `onValueChanged` | `final ValueChanged<T> onValueChanged` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `pressedColor` | `final Color? pressedColor` |  |
| `selectedColor` | `final Color? selectedColor` |  |
| `unselectedColor` | `final Color? unselectedColor` |  |

### TomCupertinoSlider

**Kind:** `class`

Tom wrapper for [CupertinoSlider].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `divisions` | `final int? divisions` |  |
| `max` | `final double max` |  |
| `min` | `final double min` |  |
| `onChangeEnd` | `final ValueChanged<double>? onChangeEnd` |  |
| `onChangeStart` | `final ValueChanged<double>? onChangeStart` |  |
| `onChanged` | `final ValueChanged<double>? onChanged` |  |
| `thumbColor` | `final Color thumbColor` |  |
| `value` | `final double value` |  |

### TomCupertinoSlidingSegmentedControl

**Kind:** `class`

Tom wrapper for [CupertinoSlidingSegmentedControl].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final Map<T, Widget> children` |  |
| `groupValue` | `final T? groupValue` |  |
| `onValueChanged` | `final ValueChanged<T?> onValueChanged` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `thumbColor` | `final Color? thumbColor` |  |

### TomCupertinoSliverNavigationBar

**Kind:** `class`

Tom wrapper for [CupertinoSliverNavigationBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alwaysShowMiddle` | `final bool alwaysShowMiddle` |  |
| `automaticallyImplyLeading` | `final bool automaticallyImplyLeading` |  |
| `automaticallyImplyTitle` | `final bool automaticallyImplyTitle` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `border` | `final Border? border` |  |
| `brightness` | `final Brightness? brightness` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `heroTag` | `final Object heroTag` |  |
| `largeTitle` | `final Widget? largeTitle` |  |
| `leading` | `final Widget? leading` |  |
| `middle` | `final Widget? middle` |  |
| `padding` | `final EdgeInsetsDirectional? padding` |  |
| `previousPageTitle` | `final String? previousPageTitle` |  |
| `stretch` | `final bool stretch` |  |
| `trailing` | `final Widget? trailing` |  |
| `transitionBetweenRoutes` | `final bool transitionBetweenRoutes` |  |

### TomCupertinoSliverRefreshControl

**Kind:** `class`

Tom wrapper for [CupertinoSliverRefreshControl].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final RefreshControlIndicatorBuilder? builder` |  |
| `onRefresh` | `final RefreshCallback? onRefresh` |  |
| `refreshIndicatorExtent` | `final double? refreshIndicatorExtent` |  |
| `refreshTriggerPullDistance` | `final double? refreshTriggerPullDistance` |  |

### TomCupertinoSwitch

**Kind:** `class`

Tom wrapper for [CupertinoSwitch].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeTrackColor` | `final Color? activeTrackColor` |  |
| `applyTheme` | `final bool applyTheme` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `offLabelColor` | `final Color? offLabelColor` |  |
| `onChanged` | `final ValueChanged<bool>? onChanged` |  |
| `onLabelColor` | `final Color? onLabelColor` |  |
| `thumbColor` | `final Color? thumbColor` |  |
| `trackColor` | `final Color? trackColor` |  |
| `value` | `final bool value` |  |

### TomCupertinoTabBar

**Kind:** `class`

Tom wrapper for [CupertinoTabBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `border` | `final Border? border` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `currentIndex` | `final int currentIndex` |  |
| `height` | `final double? height` |  |
| `iconSize` | `final double? iconSize` |  |
| `inactiveColor` | `final Color inactiveColor` |  |
| `items` | `final List<BottomNavigationBarItem> items` |  |
| `onTap` | `final ValueChanged<int>? onTap` |  |

### TomCupertinoTabScaffold

**Kind:** `class`

Tom wrapper for [CupertinoTabScaffold].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `controller` | `final CupertinoTabController? controller` |  |
| `resizeToAvoidBottomInset` | `final bool resizeToAvoidBottomInset` |  |
| `restorationId` | `final String? restorationId` |  |
| `tabBar` | `final CupertinoTabBar tabBar` |  |
| `tabBuilder` | `final IndexedWidgetBuilder tabBuilder` |  |

### TomCupertinoTabView

**Kind:** `class`

Tom wrapper for [CupertinoTabView] (extension pattern).

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomCupertinoTextField

**Kind:** `class`

Tom wrapper for [CupertinoTextField].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autocorrect` | `final bool autocorrect` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `clearButtonMode` | `final OverlayVisibilityMode clearButtonMode` |  |
| `controller` | `final TextEditingController? controller` |  |
| `decoration` | `final BoxDecoration? decoration` |  |
| `enabled` | `final bool enabled` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `maxLength` | `final int? maxLength` |  |
| `maxLines` | `final int? maxLines` |  |
| `minLines` | `final int? minLines` |  |
| `obscureText` | `final bool obscureText` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onEditingComplete` | `final VoidCallback? onEditingComplete` |  |
| `onSubmitted` | `final ValueChanged<String>? onSubmitted` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `placeholder` | `final String? placeholder` |  |
| `placeholderStyle` | `final TextStyle? placeholderStyle` |  |
| `prefix` | `final Widget? prefix` |  |
| `prefixMode` | `final OverlayVisibilityMode prefixMode` |  |
| `readOnly` | `final bool readOnly` |  |
| `style` | `final TextStyle? style` |  |
| `suffix` | `final Widget? suffix` |  |
| `suffixMode` | `final OverlayVisibilityMode suffixMode` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textCapitalization` | `final TextCapitalization textCapitalization` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textInputAction` | `final TextInputAction? textInputAction` |  |

### TomCupertinoTextFormFieldRow

**Kind:** `class`

Tom wrapper for [CupertinoTextFormFieldRow].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autocorrect` | `final bool autocorrect` |  |
| `autofillHints` | `final Iterable<String>? autofillHints` |  |
| `autofocus` | `final bool autofocus` |  |
| `autovalidateMode` | `final AutovalidateMode autovalidateMode` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `contextMenuBuilder` | `final EditableTextContextMenuBuilder? contextMenuBuilder` |  |
| `controller` | `final TextEditingController? controller` |  |
| `cursorColor` | `final Color? cursorColor` |  |
| `cursorHeight` | `final double? cursorHeight` |  |
| `cursorWidth` | `final double? cursorWidth` |  |
| `decoration` | `final BoxDecoration? decoration` |  |
| `enableInteractiveSelection` | `final bool enableInteractiveSelection` |  |
| `enableSuggestions` | `final bool enableSuggestions` |  |
| `enabled` | `final bool? enabled` |  |
| `expands` | `final bool expands` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `initialValue` | `final String? initialValue` |  |
| `inputFormatters` | `final List<TextInputFormatter>? inputFormatters` |  |
| `keyboardAppearance` | `final Brightness? keyboardAppearance` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `maxLength` | `final int? maxLength` |  |
| `maxLines` | `final int? maxLines` |  |
| `minLines` | `final int? minLines` |  |
| `obscureText` | `final bool obscureText` |  |
| `obscuringCharacter` | `final String obscuringCharacter` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onEditingComplete` | `final VoidCallback? onEditingComplete` |  |
| `onFieldSubmitted` | `final ValueChanged<String>? onFieldSubmitted` |  |
| `onSaved` | `final FormFieldSetter<String>? onSaved` |  |
| `onTap` | `final GestureTapCallback? onTap` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `placeholder` | `final String? placeholder` |  |
| `placeholderStyle` | `final TextStyle? placeholderStyle` |  |
| `prefix` | `final Widget? prefix` |  |
| `readOnly` | `final bool readOnly` |  |
| `restorationId` | `final String? restorationId` |  |
| `scrollPadding` | `final EdgeInsets? scrollPadding` |  |
| `scrollPhysics` | `final ScrollPhysics? scrollPhysics` |  |
| `selectionControls` | `final TextSelectionControls? selectionControls` |  |
| `showCursor` | `final bool? showCursor` |  |
| `smartDashesType` | `final SmartDashesType? smartDashesType` |  |
| `smartQuotesType` | `final SmartQuotesType? smartQuotesType` |  |
| `spellCheckConfiguration` | `final SpellCheckConfiguration? spellCheckConfiguration` |  |
| `strutStyle` | `final StrutStyle? strutStyle` |  |
| `style` | `final TextStyle? style` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textAlignVertical` | `final TextAlignVertical? textAlignVertical` |  |
| `textCapitalization` | `final TextCapitalization textCapitalization` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textInputAction` | `final TextInputAction? textInputAction` |  |
| `validator` | `final FormFieldValidator<String>? validator` |  |

### TomCupertinoTimerPicker

**Kind:** `class`

Tom wrapper for [CupertinoTimerPicker].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `initialTimerDuration` | `final Duration initialTimerDuration` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `minuteInterval` | `final int minuteInterval` |  |
| `mode` | `final CupertinoTimerPickerMode mode` |  |
| `onTimerDurationChanged` | `final ValueChanged<Duration> onTimerDurationChanged` |  |
| `secondInterval` | `final int secondInterval` |  |

### TomCustomMultiChildLayout

**Kind:** `class`

Tom wrapper for [CustomMultiChildLayout].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `delegate` | `final MultiChildLayoutDelegate delegate` |  |

### TomCustomPaint

**Kind:** `class`

Tom wrapper for [CustomPaint].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `foregroundPainter` | `final CustomPainter? foregroundPainter` |  |
| `isComplex` | `final bool? isComplex` |  |
| `painter` | `final CustomPainter? painter` |  |
| `size` | `final Size? size` |  |
| `willChange` | `final bool? willChange` |  |

### TomCustomScrollView

**Kind:** `class`

Tom wrapper for [CustomScrollView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `anchor` | `final double anchor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `cacheExtent` | `final double? cacheExtent` |  |
| `center` | `final Key? center` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `keyboardDismissBehavior` | `final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `primary` | `final bool? primary` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollBehavior` | `final ScrollBehavior? scrollBehavior` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |
| `semanticChildCount` | `final int? semanticChildCount` |  |
| `shrinkWrap` | `final bool shrinkWrap` |  |
| `slivers` | `final List<Widget> slivers` |  |

### TomCustomSingleChildLayout

**Kind:** `class`

Tom wrapper for [CustomSingleChildLayout].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `delegate` | `final SingleChildLayoutDelegate delegate` |  |

### TomDataCell

**Kind:** `class`

Tom extension of [DataCell] with built-in authorization and resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authState` | `TomAuthState get authState` | The authorization state this cell resolves to. |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-cell authorizer, applied after the group's mode. |
| `basePath` | `final String? basePath` | The resolved canonical resource base path. |
| `empty` | `TomDataCell.empty({ this.tomId, this.tomGroup, this.scope, this.authorizer, this.uiStateController}) : basePath = TomCtr.resolvePath(tomId, scope), super(const SizedBox.shrink(), placeholder: true)` | Creates an empty/placeholder cell. |
| `isReadonly` | `bool get isReadonly` | Returns true if this cell should be readonly based on authorization. |
| `isVisible` | `bool get isVisible` | Returns true if this cell's content is rendered at all. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution and authorization. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomDataColumn

**Kind:** `class`

Tom extension of [DataColumn] with built-in authorization and resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authState` | `TomAuthState get authState` | The authorization state this column resolves to. |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-column authorizer, applied after the group's mode. |
| `basePath` | `final String? basePath` | The resolved canonical resource base path. |
| `isReadonly` | `bool get isReadonly` | Returns true if this column should be readonly based on authorization. |
| `isVisible` | `bool get isVisible` | Returns true if this column should be visible based on authorization. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution and authorization. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomDataRow

**Kind:** `class`

Tom extension of [DataRow] with built-in authorization.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authState` | `TomAuthState get authState` | The authorization state this row resolves to. |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-row authorizer, applied after the group's mode. |
| `basePath` | `final String? basePath` | The resolved canonical resource base path. |
| `isReadonly` | `bool get isReadonly` | Returns true if this row should be readonly based on authorization. |
| `isVisible` | `bool get isVisible` | Returns true if this row should be visible based on authorization. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution and authorization. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomDataTable

**Kind:** `class`

Tom wrapper for [DataTable].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `border` | `final TableBorder? border` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkboxHorizontalMargin` | `final double? checkboxHorizontalMargin` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `columnSpacing` | `final double? columnSpacing` |  |
| `columns` | `final List<DataColumn> columns` |  |
| `dataRowColor` | `final WidgetStateProperty<Color?>? dataRowColor` |  |
| `dataRowMaxHeight` | `final double? dataRowMaxHeight` |  |
| `dataRowMinHeight` | `final double? dataRowMinHeight` |  |
| `dataTextStyle` | `final TextStyle? dataTextStyle` |  |
| `decoration` | `final Decoration? decoration` |  |
| `dividerThickness` | `final double? dividerThickness` |  |
| `headingRowColor` | `final WidgetStateProperty<Color?>? headingRowColor` |  |
| `headingRowHeight` | `final double? headingRowHeight` |  |
| `headingTextStyle` | `final TextStyle? headingTextStyle` |  |
| `horizontalMargin` | `final double? horizontalMargin` |  |
| `onSelectAll` | `final ValueSetter<bool?>? onSelectAll` |  |
| `rows` | `final List<DataRow> rows` |  |
| `showBottomBorder` | `final bool showBottomBorder` |  |
| `showCheckboxColumn` | `final bool showCheckboxColumn` |  |
| `sortAscending` | `final bool sortAscending` |  |
| `sortColumnIndex` | `final int? sortColumnIndex` |  |

### TomDatePickerDialog

**Kind:** `class`

Tom wrapper for [DatePickerDialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `cancelText` | `final String? cancelText` |  |
| `confirmText` | `final String? confirmText` |  |
| `currentDate` | `final DateTime? currentDate` |  |
| `errorFormatText` | `final String? errorFormatText` |  |
| `errorInvalidText` | `final String? errorInvalidText` |  |
| `fieldHintText` | `final String? fieldHintText` |  |
| `fieldLabelText` | `final String? fieldLabelText` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `helpText` | `final String? helpText` |  |
| `initialCalendarMode` | `final DatePickerMode initialCalendarMode` |  |
| `initialDate` | `final DateTime initialDate` |  |
| `initialEntryMode` | `final DatePickerEntryMode initialEntryMode` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `lastDate` | `final DateTime lastDate` |  |
| `selectableDayPredicate` | `final SelectableDayPredicate? selectableDayPredicate` |  |
| `switchToCalendarEntryModeIcon` | `final Icon? switchToCalendarEntryModeIcon` |  |
| `switchToInputEntryModeIcon` | `final Icon? switchToInputEntryModeIcon` |  |

### TomDateRangePickerDialog

**Kind:** `class`

Tom wrapper for [DateRangePickerDialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `cancelText` | `final String? cancelText` |  |
| `confirmText` | `final String? confirmText` |  |
| `currentDate` | `final DateTime? currentDate` |  |
| `errorFormatText` | `final String? errorFormatText` |  |
| `errorInvalidRangeText` | `final String? errorInvalidRangeText` |  |
| `errorInvalidText` | `final String? errorInvalidText` |  |
| `fieldEndHintText` | `final String? fieldEndHintText` |  |
| `fieldEndLabelText` | `final String? fieldEndLabelText` |  |
| `fieldStartHintText` | `final String? fieldStartHintText` |  |
| `fieldStartLabelText` | `final String? fieldStartLabelText` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `helpText` | `final String? helpText` |  |
| `initialDateRange` | `final DateTimeRange? initialDateRange` |  |
| `initialEntryMode` | `final DatePickerEntryMode initialEntryMode` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `lastDate` | `final DateTime lastDate` |  |
| `saveText` | `final String? saveText` |  |
| `switchToCalendarEntryModeIcon` | `final Icon? switchToCalendarEntryModeIcon` |  |
| `switchToInputEntryModeIcon` | `final Icon? switchToInputEntryModeIcon` |  |

### TomDecoratedBox

**Kind:** `class`

Tom wrapper for [DecoratedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `decoration` | `final Decoration decoration` |  |
| `position` | `final DecorationPosition position` |  |

### TomDecoratedSliver

**Kind:** `class`

Tom wrapper for [DecoratedSliver].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `decoration` | `final Decoration? decoration` |  |
| `sliver` | `final Widget sliver` |  |

### TomDefaultTextStyle

**Kind:** `class`

Tom wrapper for [DefaultTextStyle].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `maxLines` | `final int? maxLines` |  |
| `overflow` | `final TextOverflow overflow` |  |
| `softWrap` | `final bool softWrap` |  |
| `style` | `final TextStyle style` |  |
| `textAlign` | `final TextAlign? textAlign` |  |
| `textHeightBehavior` | `final TextHeightBehavior? textHeightBehavior` |  |
| `textWidthBasis` | `final TextWidthBasis textWidthBasis` |  |

### TomDialog

**Kind:** `class`

Tom wrapper for [Dialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `elevation` | `final double? elevation` |  |
| `insetPadding` | `final EdgeInsets? insetPadding` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |

### TomDialogs

**Kind:** `class`

Tom-prefixed static wrappers for Flutter's function-based dialog APIs.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `showDatePicker` | `static Future<DateTime?> showDatePicker({ required BuildContext context, DateTime? initialDate, required DateTime firstDate, required DateTime lastDate, DateTime? currentDate, DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar, SelectableDayPredicate? selectableDayPredicate, String? helpText, String? cancelText, String? confirmText, Locale? locale, bool barrierDismissible = true, Color? barrierColor, String? barrierLabel, bool useRootNavigator = true, RouteSettings? routeSettings, TextDirection? textDirection, TransitionBuilder? builder, DatePickerMode initialDatePickerMode = DatePickerMode.day, String? errorFormatText, String? errorInvalidText, String? fieldHintText, String? fieldLabelText, TextInputType? keyboardType, Offset? anchorPoint, ValueChanged<DatePickerEntryMode>? onDatePickerModeChange, Icon? switchToInputEntryModeIcon, Icon? switchToCalendarEntryModeIcon})` | Wraps [showDatePicker]. |
| `showDateRangePicker` | `static Future<DateTimeRange?> showDateRangePicker({ required BuildContext context, DateTimeRange? initialDateRange, required DateTime firstDate, required DateTime lastDate, DateTime? currentDate, DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar, String? helpText, String? cancelText, String? confirmText, String? saveText, String? errorFormatText, String? errorInvalidText, String? errorInvalidRangeText, String? fieldStartHintText, String? fieldEndHintText, String? fieldStartLabelText, String? fieldEndLabelText, Locale? locale, bool barrierDismissible = true, Color? barrierColor, String? barrierLabel, bool useRootNavigator = true, RouteSettings? routeSettings, TextDirection? textDirection, TransitionBuilder? builder, Offset? anchorPoint, TextInputType keyboardType = TextInputType.datetime, Icon? switchToInputEntryModeIcon, Icon? switchToCalendarEntryModeIcon})` | Wraps [showDateRangePicker]. |
| `showDialog` | `static Future<T?> showDialog<T>({ required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true, Color? barrierColor, String? barrierLabel, bool useSafeArea = true, bool useRootNavigator = true, RouteSettings? routeSettings, Offset? anchorPoint, TraversalEdgeBehavior? traversalEdgeBehavior})` | Wraps [showDialog]. |
| `showMenu` | `static Future<T?> showMenu<T>({ required BuildContext context, required RelativeRect position, required List<PopupMenuEntry<T>> items, T? initialValue, double? elevation, Color? shadowColor, Color? surfaceTintColor, String? semanticLabel, ShapeBorder? shape, Color? color, bool useRootNavigator = false, BoxConstraints? constraints, Clip clipBehavior = Clip.none, RouteSettings? routeSettings, AnimationStyle? popUpAnimationStyle})` | Wraps [showMenu]. |
| `showModalBottomSheet` | `static Future<T?> showModalBottomSheet<T>({ required BuildContext context, required WidgetBuilder builder, Color? backgroundColor, String? barrierLabel, double? elevation, ShapeBorder? shape, Clip? clipBehavior, BoxConstraints? constraints, Color? barrierColor, bool isScrollControlled = false, double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0, bool useRootNavigator = false, bool isDismissible = true, bool enableDrag = true, bool? showDragHandle, bool useSafeArea = false, RouteSettings? routeSettings, AnimationController? transitionAnimationController, Offset? anchorPoint})` | Wraps [showModalBottomSheet]. |
| `showSearch` | `static Future<T?> showSearch<T>({ required BuildContext context, required SearchDelegate<T> delegate, String? query = '', bool useRootNavigator = false})` | Wraps [showSearch]. |
| `showTimePicker` | `static Future<TimeOfDay?> showTimePicker({ required BuildContext context, required TimeOfDay initialTime, TransitionBuilder? builder, bool barrierDismissible = true, Color? barrierColor, String? barrierLabel, bool useRootNavigator = true, TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial, String? cancelText, String? confirmText, String? helpText, String? errorInvalidText, String? hourLabelText, String? minuteLabelText, RouteSettings? routeSettings, EntryModeChangeCallback? onEntryModeChanged, Offset? anchorPoint, Orientation? orientation})` | Wraps [showTimePicker]. |

### TomDismissible

**Kind:** `class`

Tom wrapper for [Dismissible].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `background` | `final Widget? background` |  |
| `behavior` | `final HitTestBehavior behavior` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `confirmDismiss` | `final ConfirmDismissCallback? confirmDismiss` |  |
| `crossAxisEndOffset` | `final double? crossAxisEndOffset` |  |
| `direction` | `final DismissDirection direction` |  |
| `dismissThresholds` | `final Map<DismissDirection, double> dismissThresholds` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `movementDuration` | `final Duration movementDuration` |  |
| `onDismissed` | `final DismissDirectionCallback? onDismissed` |  |
| `onResize` | `final VoidCallback? onResize` |  |
| `onUpdate` | `final DismissUpdateCallback? onUpdate` |  |
| `resizeDuration` | `final Duration? resizeDuration` |  |
| `secondaryBackground` | `final Widget? secondaryBackground` |  |

### TomDivider

**Kind:** `class`

Tom wrapper for [Divider].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `endIndent` | `final double? endIndent` |  |
| `height` | `final double? height` |  |
| `indent` | `final double? indent` |  |
| `thickness` | `final double? thickness` |  |

### TomDragTarget

**Kind:** `class`

Tom wrapper for [DragTarget].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final DragTargetBuilder<T> builder` |  |
| `hitTestBehavior` | `final HitTestBehavior? hitTestBehavior` |  |
| `onAcceptWithDetails` | `final DragTargetAcceptWithDetails<T>? onAcceptWithDetails` |  |
| `onLeave` | `final DragTargetLeave<T>? onLeave` |  |
| `onMove` | `final DragTargetMove<T>? onMove` |  |
| `onWillAcceptWithDetails` | `final DragTargetWillAcceptWithDetails<T>? onWillAcceptWithDetails` |  |

### TomDraggable

**Kind:** `class`

Tom wrapper for [Draggable].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `affinity` | `final Axis? affinity` |  |
| `allowedButtonsFilter` | `final bool allowedButtonsFilter` |  |
| `axis` | `final Axis? axis` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `childWhenDragging` | `final Widget? childWhenDragging` |  |
| `data` | `final T? data` |  |
| `dragAnchorStrategy` | `final DragAnchorStrategy dragAnchorStrategy` |  |
| `feedback` | `final Widget feedback` |  |
| `feedbackOffset` | `final Offset feedbackOffset` |  |
| `hitTestBehavior` | `final HitTestBehavior hitTestBehavior` |  |
| `ignoringFeedbackPointer` | `final bool? ignoringFeedbackPointer` |  |
| `ignoringFeedbackSemantics` | `final bool? ignoringFeedbackSemantics` |  |
| `maxSimultaneousDrags` | `final int? maxSimultaneousDrags` |  |
| `onDragCompleted` | `final VoidCallback? onDragCompleted` |  |
| `onDragEnd` | `final DragEndCallback? onDragEnd` |  |
| `onDragStarted` | `final VoidCallback? onDragStarted` |  |
| `onDragUpdate` | `final DragUpdateCallback? onDragUpdate` |  |
| `onDraggableCanceled` | `final DraggableCanceledCallback? onDraggableCanceled` |  |
| `rootOverlay` | `final bool? rootOverlay` |  |

### TomDraggableScrollableSheet

**Kind:** `class`

Tom wrapper for [DraggableScrollableSheet].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final ScrollableWidgetBuilder builder` |  |
| `controller` | `final DraggableScrollableController? controller` |  |
| `expand` | `final bool? expand` |  |
| `initialChildSize` | `final double? initialChildSize` |  |
| `maxChildSize` | `final double? maxChildSize` |  |
| `minChildSize` | `final double? minChildSize` |  |
| `shouldCloseOnMinExtent` | `final bool? shouldCloseOnMinExtent` |  |
| `snap` | `final bool? snap` |  |
| `snapAnimationDuration` | `final double? snapAnimationDuration` |  |
| `snapSizes` | `final List<double>? snapSizes` |  |

### TomDrawer

**Kind:** `class`

Tom wrapper for [Drawer].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `elevation` | `final double? elevation` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `width` | `final double? width` |  |

### TomDrawerHeader

**Kind:** `class`

Tom wrapper for [DrawerHeader].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `curve` | `final Curve curve` |  |
| `decoration` | `final Decoration? decoration` |  |
| `duration` | `final Duration duration` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |

### TomDropdownButton

**Kind:** `class`

Tom wrapper for [DropdownButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `autofocus` | `final bool autofocus` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `dropdownColor` | `final Color? dropdownColor` |  |
| `elevation` | `final int? elevation` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hint` | `final String? hint` |  |
| `icon` | `final Widget? icon` |  |
| `iconDisabledColor` | `final Color? iconDisabledColor` |  |
| `iconEnabledColor` | `final Color? iconEnabledColor` |  |
| `iconSize` | `final double? iconSize` |  |
| `isDense` | `final bool isDense` |  |
| `isExpanded` | `final bool isExpanded` |  |
| `itemHeight` | `final double? itemHeight` |  |
| `items` | `final List<DropdownMenuItem<T>>? items` |  |
| `menuMaxHeight` | `final double? menuMaxHeight` |  |
| `onChanged` | `final ValueChanged<T?>? onChanged` |  |
| `onTap` | `final VoidCallback? onTap` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `style` | `final TextStyle? style` |  |
| `underline` | `final Widget? underline` |  |
| `value` | `final T? value` |  |

### TomDropdownButtonFormField

**Kind:** `class`

Tom wrapper for [DropdownButtonFormField].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `autofocus` | `final bool autofocus` |  |
| `autovalidateMode` | `final AutovalidateMode? autovalidateMode` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `decoration` | `final InputDecoration? decoration` |  |
| `disabledHint` | `final Widget? disabledHint` |  |
| `dropdownColor` | `final Color? dropdownColor` |  |
| `elevation` | `final int? elevation` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hint` | `final Widget? hint` |  |
| `icon` | `final Widget? icon` |  |
| `iconDisabledColor` | `final Color? iconDisabledColor` |  |
| `iconEnabledColor` | `final Color? iconEnabledColor` |  |
| `iconSize` | `final double? iconSize` |  |
| `isDense` | `final bool isDense` |  |
| `isExpanded` | `final bool isExpanded` |  |
| `itemHeight` | `final double? itemHeight` |  |
| `items` | `final List<DropdownMenuItem<T>>? items` |  |
| `menuMaxHeight` | `final double? menuMaxHeight` |  |
| `onChanged` | `final ValueChanged<T?>? onChanged` |  |
| `onSaved` | `final FormFieldSetter<T>? onSaved` |  |
| `onTap` | `final VoidCallback? onTap` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `style` | `final TextStyle? style` |  |
| `validator` | `final FormFieldValidator<T>? validator` |  |
| `value` | `final T? value` |  |

### TomDropdownMenu

**Kind:** `class`

Tom wrapper for [DropdownMenu].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `controller` | `final TextEditingController? controller` |  |
| `dropdownMenuEntries` | `final List<DropdownMenuEntry<T>> dropdownMenuEntries` |  |
| `enableFilter` | `final bool enableFilter` |  |
| `enableSearch` | `final bool enableSearch` |  |
| `enabled` | `final bool enabled` |  |
| `errorText` | `final String? errorText` |  |
| `expandedInsets` | `final EdgeInsets? expandedInsets` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `helperText` | `final String? helperText` |  |
| `hintText` | `final String? hintText` |  |
| `initialSelection` | `final T? initialSelection` |  |
| `inputDecorationTheme` | `final InputDecorationTheme? inputDecorationTheme` |  |
| `label` | `final String? label` |  |
| `leadingIcon` | `final Widget? leadingIcon` |  |
| `menuHeight` | `final double? menuHeight` |  |
| `menuStyle` | `final MenuStyle? menuStyle` |  |
| `onSelected` | `final ValueChanged<T?>? onSelected` |  |
| `requestFocusOnTap` | `final bool requestFocusOnTap` |  |
| `searchCallback` | `final SearchCallback<T>? searchCallback` |  |
| `selectedTrailingIcon` | `final Widget? selectedTrailingIcon` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textStyle` | `final TextStyle? textStyle` |  |
| `trailingIcon` | `final Widget? trailingIcon` |  |
| `width` | `final double? width` |  |

### TomDropdownMenuEntry

**Kind:** `class`

Tom wrapper for [DropdownMenuEntry] used as an action button.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `enabled` | `final bool enabled` |  |
| `label` | `final String? label` |  |
| `labelWidget` | `final Widget? labelWidget` |  |
| `leadingIcon` | `final Widget? leadingIcon` |  |
| `style` | `final ButtonStyle? style` |  |
| `toEntry` | `DropdownMenuEntry<T> toEntry(BuildContext context)` | Creates the underlying [DropdownMenuEntry] for use in a [DropdownMenu]. |
| `trailingIcon` | `final Widget? trailingIcon` |  |
| `value` | `final T value` |  |

### TomDropdownMenuFormField

**Kind:** `class`

Tom wrapper for [DropdownMenuFormField].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignmentOffset` | `final Offset? alignmentOffset` |  |
| `autovalidateMode` | `final AutovalidateMode autovalidateMode` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `closeBehavior` | `final DropdownMenuCloseBehavior closeBehavior` |  |
| `controller` | `final TextEditingController? controller` |  |
| `dropdownMenuEntries` | `final List<DropdownMenuEntry<T>> dropdownMenuEntries` |  |
| `enableFilter` | `final bool enableFilter` |  |
| `enableSearch` | `final bool enableSearch` |  |
| `enabled` | `final bool enabled` |  |
| `expandedInsets` | `final EdgeInsetsGeometry? expandedInsets` |  |
| `filterCallback` | `final FilterCallback<T>? filterCallback` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `forceErrorText` | `final String? forceErrorText` |  |
| `helperText` | `final String? helperText` |  |
| `hintText` | `final String? hintText` |  |
| `initialSelection` | `final T? initialSelection` |  |
| `inputDecorationTheme` | `final Object? inputDecorationTheme` |  |
| `inputFormatters` | `final List<TextInputFormatter>? inputFormatters` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `label` | `final String? label` |  |
| `leadingIcon` | `final Widget? leadingIcon` |  |
| `maxLines` | `final int maxLines` |  |
| `menuHeight` | `final double? menuHeight` |  |
| `menuStyle` | `final MenuStyle? menuStyle` |  |
| `onSaved` | `final FormFieldSetter<T>? onSaved` |  |
| `onSelected` | `final ValueChanged<T?>? onSelected` |  |
| `requestFocusOnTap` | `final bool? requestFocusOnTap` |  |
| `restorationId` | `final String? restorationId` |  |
| `searchCallback` | `final SearchCallback<T>? searchCallback` |  |
| `selectedTrailingIcon` | `final Widget? selectedTrailingIcon` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textInputAction` | `final TextInputAction? textInputAction` |  |
| `textStyle` | `final TextStyle? textStyle` |  |
| `trailingIcon` | `final Widget? trailingIcon` |  |
| `validator` | `final FormFieldValidator<T>? validator` |  |
| `width` | `final double? width` |  |

### TomDropdownMenuItem

**Kind:** `class`

Tom widget that EXTENDS [DropdownMenuItem] with authorization.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomEditableText

**Kind:** `class`

Tom wrapper for [EditableText].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autocorrect` | `final bool autocorrect` |  |
| `autofocus` | `final bool autofocus` |  |
| `backgroundCursorColor` | `final Color? backgroundCursorColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final TextEditingController controller` |  |
| `cursorColor` | `final Color cursorColor` |  |
| `cursorHeight` | `final double? cursorHeight` |  |
| `cursorOffset` | `final Offset? cursorOffset` |  |
| `cursorRadius` | `final Radius? cursorRadius` |  |
| `cursorWidth` | `final double? cursorWidth` |  |
| `enableInteractiveSelection` | `final bool enableInteractiveSelection` |  |
| `expands` | `final bool expands` |  |
| `focusNode` | `final FocusNode focusNode` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `maxLines` | `final int? maxLines` |  |
| `minLines` | `final int? minLines` |  |
| `obscureText` | `final bool obscureText` |  |
| `obscuringCharacter` | `final String obscuringCharacter` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onEditingComplete` | `final VoidCallback? onEditingComplete` |  |
| `onSelectionChanged` | `final SelectionChangedCallback? onSelectionChanged` |  |
| `onSubmitted` | `final ValueChanged<String>? onSubmitted` |  |
| `readOnly` | `final bool readOnly` |  |
| `rendererIgnoresPointer` | `final bool rendererIgnoresPointer` |  |
| `scrollController` | `final ScrollController? scrollController` |  |
| `scrollPhysics` | `final ScrollPhysics? scrollPhysics` |  |
| `selectionColor` | `final Color? selectionColor` |  |
| `selectionControls` | `final TextSelectionControls? selectionControls` |  |
| `showCursor` | `final bool showCursor` |  |
| `showSelectionHandles` | `final bool showSelectionHandles` |  |
| `strutStyle` | `final StrutStyle? strutStyle` |  |
| `style` | `final TextStyle style` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textCapitalization` | `final TextCapitalization textCapitalization` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textInputAction` | `final TextInputAction? textInputAction` |  |
| `textScaler` | `final TextScaler? textScaler` |  |

### TomElevatedButton

**Kind:** `class`

Tom wrapper for [ElevatedButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `icon` | `final Widget? icon` |  |
| `label` | `final String? label` |  |
| `onFocusChange` | `final ValueChanged<bool>? onFocusChange` |  |
| `onHover` | `final ValueChanged<bool>? onHover` |  |
| `onLongPress` | `final VoidCallback? onLongPress` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `style` | `final ButtonStyle? style` |  |

### TomExpandIcon

**Kind:** `class`

Tom wrapper for [ExpandIcon].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `disabledColor` | `final Color? disabledColor` |  |
| `expandedColor` | `final Color? expandedColor` |  |
| `isExpanded` | `final bool isExpanded` |  |
| `onPressed` | `final ValueChanged<bool>? onPressed` |  |
| `padding` | `final EdgeInsetsGeometry padding` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `size` | `final double? size` |  |

### TomExpanded

**Kind:** `class`

Tom widget that EXTENDS [Expanded] with authorization and resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomExpansionPanel

**Kind:** `class`

Tom equivalent for [ExpansionPanel] (non-widget data class).

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-panel authorizer, applied after the group's mode. |
| `backgroundColor` | `final Color? backgroundColor` | Background color of the panel. |
| `body` | `final Widget body` | The body content when expanded. |
| `canTapOnHeader` | `final bool canTapOnHeader` | Whether tapping the header toggles expansion. |
| `headerBuilder` | `final ExpansionPanelHeaderBuilder headerBuilder` | Callback that builds the header widget. |
| `highlightColor` | `final Color? highlightColor` | Highlight color when tapping the header. |
| `isExpanded` | `final bool isExpanded` | Whether the panel is expanded. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `splashColor` | `final Color? splashColor` | Splash color when tapping the header. |
| `toPanel` | `ExpansionPanel toPanel()` | Converts this to a Flutter [ExpansionPanel]. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution and authorization. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomExpansionPanelList

**Kind:** `class`

Tom wrapper for [ExpansionPanelList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `animationDuration` | `final Duration animationDuration` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<ExpansionPanel> children` |  |
| `dividerColor` | `final Color? dividerColor` |  |
| `elevation` | `final double? elevation` |  |
| `expandedHeaderPadding` | `final EdgeInsets? expandedHeaderPadding` |  |
| `expansionCallback` | `final ExpansionPanelCallback? expansionCallback` |  |

### TomExpansionTile

**Kind:** `class`

Tom wrapper for [ExpansionTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `childrenPadding` | `final EdgeInsetsGeometry? childrenPadding` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `collapsedBackgroundColor` | `final Color? collapsedBackgroundColor` |  |
| `collapsedIconColor` | `final Color? collapsedIconColor` |  |
| `collapsedShape` | `final ShapeBorder? collapsedShape` |  |
| `collapsedTextColor` | `final Color? collapsedTextColor` |  |
| `controlAffinity` | `final ListTileControlAffinity? controlAffinity` |  |
| `dense` | `final bool dense` |  |
| `expandedAlignment` | `final Alignment? expandedAlignment` |  |
| `expandedCrossAxisAlignment` | `final CrossAxisAlignment? expandedCrossAxisAlignment` |  |
| `iconColor` | `final Color? iconColor` |  |
| `initiallyExpanded` | `final bool initiallyExpanded` |  |
| `leading` | `final Widget? leading` |  |
| `maintainState` | `final bool maintainState` |  |
| `onExpansionChanged` | `final ValueChanged<bool>? onExpansionChanged` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `showTrailingIcon` | `final bool showTrailingIcon` |  |
| `subtitle` | `final Widget? subtitle` |  |
| `textColor` | `final Color? textColor` |  |
| `tilePadding` | `final EdgeInsetsGeometry? tilePadding` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |
| `trailing` | `final Widget? trailing` |  |

### TomFadeInImage

**Kind:** `class`

Tom wrapper for [FadeInImage].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `excludeFromSemantics` | `final bool excludeFromSemantics` |  |
| `fadeInCurve` | `final Curve fadeInCurve` |  |
| `fadeInDuration` | `final Duration fadeInDuration` |  |
| `fadeOutCurve` | `final Curve fadeOutCurve` |  |
| `fadeOutDuration` | `final Duration fadeOutDuration` |  |
| `filterQuality` | `final FilterQuality filterQuality` |  |
| `fit` | `final BoxFit? fit` |  |
| `height` | `final double? height` |  |
| `image` | `final ImageProvider image` |  |
| `imageErrorBuilder` | `final ImageErrorWidgetBuilder? imageErrorBuilder` |  |
| `imageSemanticLabel` | `final String? imageSemanticLabel` |  |
| `matchTextDirection` | `final bool matchTextDirection` |  |
| `placeholder` | `final ImageProvider placeholder` |  |
| `placeholderColor` | `final Color? placeholderColor` |  |
| `placeholderColorBlendMode` | `final BlendMode? placeholderColorBlendMode` |  |
| `placeholderErrorBuilder` | `final ImageErrorWidgetBuilder? placeholderErrorBuilder` |  |
| `placeholderFit` | `final BoxFit? placeholderFit` |  |
| `repeat` | `final ImageRepeat repeat` |  |
| `width` | `final double? width` |  |

### TomFadeTransition

**Kind:** `class`

Tom wrapper for [FadeTransition].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alwaysIncludeSemantics` | `final bool alwaysIncludeSemantics` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `opacity` | `final Animation<double> opacity` |  |

### TomFileImage

**Kind:** `class`

Tom wrapper for [Image] that uses [FileImage] as its provider.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `centerSlice` | `final Rect? centerSlice` |  |
| `color` | `final Color? color` |  |
| `colorBlendMode` | `final BlendMode? colorBlendMode` |  |
| `errorBuilder` | `final ImageErrorWidgetBuilder? errorBuilder` |  |
| `excludeFromSemantics` | `final bool excludeFromSemantics` |  |
| `filePath` | `final String filePath` |  |
| `filterQuality` | `final FilterQuality filterQuality` |  |
| `fit` | `final BoxFit? fit` |  |
| `frameBuilder` | `final ImageFrameBuilder? frameBuilder` |  |
| `gaplessPlayback` | `final bool gaplessPlayback` |  |
| `height` | `final double? height` |  |
| `isAntiAlias` | `final bool isAntiAlias` |  |
| `matchTextDirection` | `final bool matchTextDirection` |  |
| `repeat` | `final ImageRepeat repeat` |  |
| `scale` | `final double scale` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `width` | `final double? width` |  |

### TomFilledButton

**Kind:** `class`

Tom wrapper for [FilledButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `icon` | `final Widget? icon` |  |
| `label` | `final String? label` |  |
| `onFocusChange` | `final ValueChanged<bool>? onFocusChange` |  |
| `onHover` | `final ValueChanged<bool>? onHover` |  |
| `onLongPress` | `final VoidCallback? onLongPress` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `style` | `final ButtonStyle? style` |  |
| `tonal` | `final bool tonal` |  |

### TomFilterChip

**Kind:** `class`

Tom wrapper for [FilterChip].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `avatar` | `final Widget? avatar` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkmarkColor` | `final Color? checkmarkColor` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `deleteButtonTooltipMessage` | `final String? deleteButtonTooltipMessage` |  |
| `deleteIcon` | `final Widget? deleteIcon` |  |
| `deleteIconColor` | `final Color? deleteIconColor` |  |
| `disabledColor` | `final Color? disabledColor` |  |
| `elevation` | `final double? elevation` |  |
| `label` | `final Widget? label` |  |
| `labelPadding` | `final EdgeInsetsGeometry? labelPadding` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelText` | `final String? labelText` |  |
| `onDeleted` | `final VoidCallback? onDeleted` |  |
| `onSelected` | `final ValueChanged<bool>? onSelected` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `pressElevation` | `final double? pressElevation` |  |
| `selected` | `final bool selected` |  |
| `selectedColor` | `final Color? selectedColor` |  |
| `selectedShadowColor` | `final Color? selectedShadowColor` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `showCheckmark` | `final bool showCheckmark` |  |
| `side` | `final BorderSide? side` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomFittedBox

**Kind:** `class`

Tom wrapper for [FittedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `fit` | `final BoxFit fit` |  |

### TomFlexible

**Kind:** `class`

Tom widget that EXTENDS [Flexible] with authorization and resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomFlexibleSpaceBar

**Kind:** `class`

Tom wrapper for [FlexibleSpaceBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `background` | `final Widget? background` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `centerTitle` | `final bool centerTitle` |  |
| `collapseMode` | `final CollapseMode collapseMode` |  |
| `expandedTitleScale` | `final double expandedTitleScale` |  |
| `stretchModes` | `final List<StretchMode> stretchModes` |  |
| `title` | `final Widget? title` |  |
| `titlePadding` | `final EdgeInsetsGeometry? titlePadding` |  |

### TomFloatingActionButton

**Kind:** `class`

Tom wrapper for [FloatingActionButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `disabledElevation` | `final double? disabledElevation` |  |
| `elevation` | `final double? elevation` |  |
| `extended` | `TomFloatingActionButton.extended({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, VoidCallback? onPressed, this.label, this.icon, this.tooltip, this.foregroundColor, this.backgroundColor, this.focusColor, this.hoverColor, this.splashColor, this.elevation, this.focusElevation, this.hoverElevation, this.highlightElevation, this.disabledElevation, this.shape, this.clipBehavior = Clip.none, this.autofocus = false, this.focusNode, this.isExtended, this.extendedIconLabelChild, this.heroTag}) : onPressed = ScopeCapture(scope: scope).wrap0n(onPressed), _variant = _FABVariant.extended, child = null, mini = false` | Creates an extended floating action button with icon and label. |
| `extendedIconLabelChild` | `final Widget? extendedIconLabelChild` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusElevation` | `final double? focusElevation` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `foregroundColor` | `final Color? foregroundColor` |  |
| `heroTag` | `final Object? heroTag` |  |
| `highlightElevation` | `final double? highlightElevation` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `hoverElevation` | `final double? hoverElevation` |  |
| `icon` | `final Widget? icon` |  |
| `isExtended` | `final bool? isExtended` |  |
| `label` | `final String? label` |  |
| `large` | `TomFloatingActionButton.large({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, VoidCallback? onPressed, this.child, this.tooltip, this.foregroundColor, this.backgroundColor, this.focusColor, this.hoverColor, this.splashColor, this.elevation, this.focusElevation, this.hoverElevation, this.highlightElevation, this.disabledElevation, this.shape, this.clipBehavior = Clip.none, this.autofocus = false, this.focusNode, this.heroTag}) : onPressed = ScopeCapture(scope: scope).wrap0n(onPressed), _variant = _FABVariant.large, isExtended = null, mini = false, icon = null, label = null, extendedIconLabelChild = null` | Creates a large floating action button. |
| `mini` | `final bool mini` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `small` | `TomFloatingActionButton.small({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, VoidCallback? onPressed, this.child, this.tooltip, this.foregroundColor, this.backgroundColor, this.focusColor, this.hoverColor, this.splashColor, this.elevation, this.focusElevation, this.hoverElevation, this.highlightElevation, this.disabledElevation, this.shape, this.clipBehavior = Clip.none, this.autofocus = false, this.focusNode, this.heroTag}) : onPressed = ScopeCapture(scope: scope).wrap0n(onPressed), _variant = _FABVariant.small, isExtended = null, mini = false, icon = null, label = null, extendedIconLabelChild = null` | Creates a small floating action button. |
| `splashColor` | `final Color? splashColor` |  |
| `tooltip` | `final String? tooltip` |  |

### TomFlow

**Kind:** `class`

Tom wrapper for [Flow].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `delegate` | `final FlowDelegate delegate` |  |

### TomFormClassic

**Kind:** `class`

Tom wrapper for [Form].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autovalidateMode` | `final AutovalidateMode? autovalidateMode` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `canPop` | `final bool? canPop` |  |
| `child` | `final Widget child` |  |
| `onChanged` | `final VoidCallback? onChanged` |  |
| `onPopInvokedWithResult` | `final PopInvokedWithResultCallback<Object?>? onPopInvokedWithResult` |  |

### TomFractionalTranslation

**Kind:** `class`

Tom wrapper for [FractionalTranslation].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `transformHitTests` | `final bool? transformHitTests` |  |
| `translation` | `final Offset translation` |  |

### TomFractionallySizedBox

**Kind:** `class`

Tom wrapper for [FractionallySizedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `heightFactor` | `final double? heightFactor` |  |
| `widthFactor` | `final double? widthFactor` |  |

### TomFutureBuilder

**Kind:** `class`

Tom-aware wrapper for [FutureBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final AsyncWidgetBuilder<T> builder` | The builder function that creates the widget tree based on future state. |
| `future` | `final Future<T>? future` | The asynchronous computation to wait for. |
| `initialData` | `final T? initialData` | The initial data to use before the future completes. |

### TomGestureDetector

**Kind:** `class`

Tom wrapper for [GestureDetector].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `behavior` | `final HitTestBehavior? behavior` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `excludeFromSemantics` | `final bool? excludeFromSemantics` |  |
| `onDoubleTap` | `final GestureDoubleTapCallback? onDoubleTap` |  |
| `onForcePressEnd` | `final GestureForcePressEndCallback? onForcePressEnd` |  |
| `onForcePressPeak` | `final GestureForcePressPeakCallback? onForcePressPeak` |  |
| `onForcePressStart` | `final GestureForcePressStartCallback? onForcePressStart` |  |
| `onForcePressUpdate` | `final GestureForcePressUpdateCallback? onForcePressUpdate` |  |
| `onHorizontalDragCancel` | `final GestureDragCancelCallback? onHorizontalDragCancel` |  |
| `onHorizontalDragDown` | `final GestureDragDownCallback? onHorizontalDragDown` |  |
| `onHorizontalDragEnd` | `final GestureDragEndCallback? onHorizontalDragEnd` |  |
| `onHorizontalDragStart` | `final GestureDragStartCallback? onHorizontalDragStart` |  |
| `onHorizontalDragUpdate` | `final GestureDragUpdateCallback? onHorizontalDragUpdate` |  |
| `onLongPress` | `final GestureLongPressCallback? onLongPress` |  |
| `onLongPressEnd` | `final GestureLongPressEndCallback? onLongPressEnd` |  |
| `onLongPressMoveUpdate` | `final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate` |  |
| `onLongPressStart` | `final GestureLongPressStartCallback? onLongPressStart` |  |
| `onLongPressUp` | `final GestureLongPressUpCallback? onLongPressUp` |  |
| `onPanCancel` | `final GestureDragCancelCallback? onPanCancel` |  |
| `onPanDown` | `final GestureDragDownCallback? onPanDown` |  |
| `onPanEnd` | `final GestureDragEndCallback? onPanEnd` |  |
| `onPanStart` | `final GestureDragStartCallback? onPanStart` |  |
| `onPanUpdate` | `final GestureDragUpdateCallback? onPanUpdate` |  |
| `onScaleEnd` | `final GestureScaleEndCallback? onScaleEnd` |  |
| `onScaleStart` | `final GestureScaleStartCallback? onScaleStart` |  |
| `onScaleUpdate` | `final GestureScaleUpdateCallback? onScaleUpdate` |  |
| `onSecondaryTap` | `final GestureTapCallback? onSecondaryTap` |  |
| `onSecondaryTapCancel` | `final GestureTapCallback? onSecondaryTapCancel` |  |
| `onSecondaryTapDown` | `final GestureTapDownCallback? onSecondaryTapDown` |  |
| `onSecondaryTapUp` | `final GestureTapUpCallback? onSecondaryTapUp` |  |
| `onTap` | `final GestureTapCallback? onTap` |  |
| `onTapCancel` | `final GestureTapCallback? onTapCancel` |  |
| `onTapDown` | `final GestureTapDownCallback? onTapDown` |  |
| `onTapUp` | `final GestureTapUpCallback? onTapUp` |  |
| `onTertiaryTapCancel` | `final GestureTapCallback? onTertiaryTapCancel` |  |
| `onTertiaryTapDown` | `final GestureTapDownCallback? onTertiaryTapDown` |  |
| `onTertiaryTapUp` | `final GestureTapUpCallback? onTertiaryTapUp` |  |
| `onVerticalDragCancel` | `final GestureDragCancelCallback? onVerticalDragCancel` |  |
| `onVerticalDragDown` | `final GestureDragDownCallback? onVerticalDragDown` |  |
| `onVerticalDragEnd` | `final GestureDragEndCallback? onVerticalDragEnd` |  |
| `onVerticalDragStart` | `final GestureDragStartCallback? onVerticalDragStart` |  |
| `onVerticalDragUpdate` | `final GestureDragUpdateCallback? onVerticalDragUpdate` |  |
| `supportedDevices` | `final Set<PointerDeviceKind>? supportedDevices` |  |
| `trackpadScrollCausesScale` | `final bool? trackpadScrollCausesScale` |  |
| `trackpadScrollToScaleFactor` | `final Offset trackpadScrollToScaleFactor` |  |

### TomGridTile

**Kind:** `class`

Tom wrapper for [GridTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `footer` | `final Widget? footer` |  |
| `header` | `final Widget? header` |  |

### TomGridTileBar

**Kind:** `class`

Tom wrapper for [GridTileBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `leading` | `final Widget? leading` |  |
| `subtitle` | `final Widget? subtitle` |  |
| `title` | `final Widget? title` |  |
| `trailing` | `final Widget? trailing` |  |

### TomGridView

**Kind:** `class`

Tom wrapper for [GridView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `cacheExtent` | `final double? cacheExtent` |  |
| `childrenDelegate` | `final SliverChildDelegate childrenDelegate` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `gridDelegate` | `final SliverGridDelegate gridDelegate` |  |
| `keyboardDismissBehavior` | `final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `primary` | `final bool? primary` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |
| `semanticChildCount` | `final int? semanticChildCount` |  |
| `shrinkWrap` | `final bool shrinkWrap` |  |

### TomHero

**Kind:** `class`

Tom wrapper for [Hero].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `createRectTween` | `final CreateRectTween? createRectTween` |  |
| `flightShuttleBuilder` | `final HeroFlightShuttleBuilder? flightShuttleBuilder` |  |
| `placeholderBuilder` | `final HeroPlaceholderBuilder? placeholderBuilder` |  |
| `tag` | `final Object tag` |  |
| `transitionOnUserGestures` | `final bool? transitionOnUserGestures` |  |

### TomIcon

**Kind:** `class`

Tom wrapper for [Icon].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applyTextScaling` | `final bool? applyTextScaling` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `fill` | `final double? fill` |  |
| `grade` | `final double? grade` |  |
| `icon` | `final IconData? icon` | The icon to display. |
| `opticalSize` | `final double? opticalSize` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `shadows` | `final List<Shadow>? shadows` |  |
| `size` | `final double? size` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `weight` | `final double? weight` |  |

### TomIconButton

**Kind:** `class`

Tom wrapper for [IconButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `disabledColor` | `final Color? disabledColor` |  |
| `filled` | `TomIconButton.filled({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, VoidCallback? onPressed, this.iconSize, this.visualDensity, this.padding, this.alignment, this.splashRadius, this.color, this.focusColor, this.hoverColor, this.highlightColor, this.splashColor, this.disabledColor, this.autofocus = false, this.constraints, this.style, this.isSelected, this.selectedIcon, this.icon, this.tooltip, this.focusNode}) : onPressed = ScopeCapture(scope: scope).wrap0n(onPressed), _variant = _IconButtonVariant.filled` | Creates a filled icon button. |
| `filledTonal` | `TomIconButton.filledTonal({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, VoidCallback? onPressed, this.iconSize, this.visualDensity, this.padding, this.alignment, this.splashRadius, this.color, this.focusColor, this.hoverColor, this.highlightColor, this.splashColor, this.disabledColor, this.autofocus = false, this.constraints, this.style, this.isSelected, this.selectedIcon, this.icon, this.tooltip, this.focusNode}) : onPressed = ScopeCapture(scope: scope).wrap0n(onPressed), _variant = _IconButtonVariant.filledTonal` | Creates a filled tonal icon button. |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `highlightColor` | `final Color? highlightColor` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `icon` | `final Widget? icon` |  |
| `iconSize` | `final double? iconSize` |  |
| `isSelected` | `final bool? isSelected` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `outlined` | `TomIconButton.outlined({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, VoidCallback? onPressed, this.iconSize, this.visualDensity, this.padding, this.alignment, this.splashRadius, this.color, this.focusColor, this.hoverColor, this.highlightColor, this.splashColor, this.disabledColor, this.autofocus = false, this.constraints, this.style, this.isSelected, this.selectedIcon, this.icon, this.tooltip, this.focusNode}) : onPressed = ScopeCapture(scope: scope).wrap0n(onPressed), _variant = _IconButtonVariant.outlined` | Creates an outlined icon button. |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `selectedIcon` | `final Widget? selectedIcon` |  |
| `splashColor` | `final Color? splashColor` |  |
| `splashRadius` | `final double? splashRadius` |  |
| `style` | `final ButtonStyle? style` |  |
| `tooltip` | `final String? tooltip` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomIgnorePointer

**Kind:** `class`

Tom wrapper for [IgnorePointer].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `ignoring` | `final bool? ignoring` |  |

### TomImage

**Kind:** `class`

Tom wrapper for [Image].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `centerSlice` | `final Rect? centerSlice` |  |
| `color` | `final Color? color` |  |
| `colorBlendMode` | `final BlendMode? colorBlendMode` |  |
| `filterQuality` | `final FilterQuality filterQuality` |  |
| `fit` | `final BoxFit? fit` |  |
| `gaplessPlayback` | `final bool gaplessPlayback` |  |
| `height` | `final double? height` |  |
| `imageProvider` | `final ImageProvider imageProvider` |  |
| `isAntiAlias` | `final bool isAntiAlias` |  |
| `matchTextDirection` | `final bool matchTextDirection` |  |
| `repeat` | `final ImageRepeat repeat` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `width` | `final double? width` |  |

### TomImageFiltered

**Kind:** `class`

Tom wrapper for [ImageFiltered].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `enabled` | `final bool? enabled` |  |
| `imageFilter` | `final ImageFilter imageFilter` |  |

### TomImageIcon

**Kind:** `class`

Tom wrapper for [ImageIcon].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `image` | `final ImageProvider? image` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `size` | `final double? size` |  |

### TomIndexedStack

**Kind:** `class`

Tom wrapper for [IndexedStack].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `index` | `final int? index` |  |
| `sizing` | `final StackFit sizing` |  |
| `textDirection` | `final TextDirection? textDirection` |  |

### TomInk

**Kind:** `class`

Tom wrapper for [Ink].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `color` | `final Color? color` |  |
| `decoration` | `final Decoration? decoration` |  |
| `height` | `final double? height` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `width` | `final double? width` |  |

### TomInkImage

**Kind:** `class`

Tom wrapper for [Ink.image].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `centerSlice` | `final Rect? centerSlice` |  |
| `child` | `final Widget? child` |  |
| `colorFilter` | `final ColorFilter? colorFilter` |  |
| `fit` | `final BoxFit? fit` |  |
| `height` | `final double? height` |  |
| `image` | `final ImageProvider image` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `repeat` | `final ImageRepeat repeat` |  |
| `width` | `final double? width` |  |

### TomInkResponse

**Kind:** `class`

Tom wrapper for [InkResponse].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool? autofocus` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `canRequestFocus` | `final bool? canRequestFocus` |  |
| `child` | `final Widget? child` |  |
| `containedInkWell` | `final bool? containedInkWell` |  |
| `customBorder` | `final ShapeBorder? customBorder` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `excludeFromSemantics` | `final bool? excludeFromSemantics` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `highlightColor` | `final Color? highlightColor` |  |
| `highlightShape` | `final BoxShape highlightShape` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `hoverDuration` | `final Duration? hoverDuration` |  |
| `mouseCursor` | `final MouseCursor? mouseCursor` |  |
| `onDoubleTap` | `final GestureTapCallback? onDoubleTap` |  |
| `onFocusChange` | `final ValueChanged<bool>? onFocusChange` |  |
| `onHighlightChanged` | `final ValueChanged<bool>? onHighlightChanged` |  |
| `onHover` | `final ValueChanged<bool>? onHover` |  |
| `onLongPress` | `final GestureLongPressCallback? onLongPress` |  |
| `onTap` | `final GestureTapCallback? onTap` |  |
| `onTapCancel` | `final GestureTapCallback? onTapCancel` |  |
| `onTapDown` | `final GestureTapDownCallback? onTapDown` |  |
| `onTapUp` | `final GestureTapUpCallback? onTapUp` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `radius` | `final double? radius` |  |
| `splashColor` | `final Color? splashColor` |  |
| `splashFactory` | `final InteractiveInkFeatureFactory? splashFactory` |  |
| `statesController` | `final WidgetStatesController? statesController` |  |

### TomInkWell

**Kind:** `class`

Tom wrapper for [InkWell].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `canRequestFocus` | `final bool canRequestFocus` |  |
| `child` | `final Widget? child` |  |
| `customBorder` | `final ShapeBorder? customBorder` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `excludeFromSemantics` | `final bool excludeFromSemantics` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `highlightColor` | `final Color? highlightColor` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `hoverDuration` | `final Duration? hoverDuration` |  |
| `mouseCursor` | `final MouseCursor? mouseCursor` |  |
| `onDoubleTap` | `final GestureTapCallback? onDoubleTap` |  |
| `onFocusChange` | `final ValueChanged<bool>? onFocusChange` |  |
| `onHighlightChanged` | `final ValueChanged<bool>? onHighlightChanged` |  |
| `onHover` | `final ValueChanged<bool>? onHover` |  |
| `onLongPress` | `final GestureLongPressCallback? onLongPress` |  |
| `onSecondaryTap` | `final GestureTapCallback? onSecondaryTap` |  |
| `onSecondaryTapCancel` | `final GestureTapCallback? onSecondaryTapCancel` |  |
| `onSecondaryTapDown` | `final GestureTapDownCallback? onSecondaryTapDown` |  |
| `onSecondaryTapUp` | `final GestureTapUpCallback? onSecondaryTapUp` |  |
| `onTap` | `final GestureTapCallback? onTap` |  |
| `onTapCancel` | `final GestureTapCallback? onTapCancel` |  |
| `onTapDown` | `final GestureTapDownCallback? onTapDown` |  |
| `onTapUp` | `final GestureTapUpCallback? onTapUp` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `radius` | `final double? radius` |  |
| `splashColor` | `final Color? splashColor` |  |
| `splashFactory` | `final InteractiveInkFeatureFactory? splashFactory` |  |
| `statesController` | `final WidgetStatesController? statesController` |  |

### TomInputChip

**Kind:** `class`

Tom wrapper for [InputChip].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `avatar` | `final Widget? avatar` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkmarkColor` | `final Color? checkmarkColor` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `deleteButtonTooltipMessage` | `final String? deleteButtonTooltipMessage` |  |
| `deleteIcon` | `final Widget? deleteIcon` |  |
| `deleteIconColor` | `final Color? deleteIconColor` |  |
| `disabledColor` | `final Color? disabledColor` |  |
| `elevation` | `final double? elevation` |  |
| `isEnabled` | `final bool isEnabled` |  |
| `label` | `final Widget? label` |  |
| `labelPadding` | `final EdgeInsetsGeometry? labelPadding` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelText` | `final String? labelText` |  |
| `onDeleted` | `final VoidCallback? onDeleted` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `onSelected` | `final ValueChanged<bool>? onSelected` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `pressElevation` | `final double? pressElevation` |  |
| `selected` | `final bool selected` |  |
| `selectedColor` | `final Color? selectedColor` |  |
| `selectedShadowColor` | `final Color? selectedShadowColor` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `showCheckmark` | `final bool showCheckmark` |  |
| `side` | `final BorderSide? side` |  |
| `tooltip` | `final String? tooltip` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomInputDatePickerFormField

**Kind:** `class`

Tom wrapper for [InputDatePickerFormField].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `acceptEmptyDate` | `final bool acceptEmptyDate` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `errorFormatText` | `final String? errorFormatText` |  |
| `errorInvalidText` | `final String? errorInvalidText` |  |
| `fieldHintText` | `final String? fieldHintText` |  |
| `fieldLabelText` | `final String? fieldLabelText` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `initialDate` | `final DateTime initialDate` |  |
| `keyboardType` | `final TextInputType keyboardType` |  |
| `lastDate` | `final DateTime lastDate` |  |
| `onDateSaved` | `final ValueChanged<DateTime>? onDateSaved` |  |
| `onDateSubmitted` | `final ValueChanged<DateTime>? onDateSubmitted` |  |
| `selectableDayPredicate` | `final SelectableDayPredicate? selectableDayPredicate` |  |

### TomInteractiveViewer

**Kind:** `class`

Tom wrapper for [InteractiveViewer].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final Alignment? alignment` |  |
| `boundaryMargin` | `final EdgeInsets? boundaryMargin` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `constrained` | `final bool? constrained` |  |
| `interactionEndFrictionCoefficient` | `final double? interactionEndFrictionCoefficient` |  |
| `maxScale` | `final double? maxScale` |  |
| `minScale` | `final double? minScale` |  |
| `onInteractionEnd` | `final GestureScaleEndCallback? onInteractionEnd` |  |
| `onInteractionStart` | `final GestureScaleStartCallback? onInteractionStart` |  |
| `onInteractionUpdate` | `final GestureScaleUpdateCallback? onInteractionUpdate` |  |
| `panAxis` | `final PanAxis panAxis` |  |
| `panEnabled` | `final bool? panEnabled` |  |
| `scaleEnabled` | `final bool? scaleEnabled` |  |
| `scaleFactor` | `final double? scaleFactor` |  |
| `transformationController` | `final TransformationController? transformationController` |  |

### TomIntrinsicHeight

**Kind:** `class`

Tom wrapper for [IntrinsicHeight].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |

### TomIntrinsicWidth

**Kind:** `class`

Tom wrapper for [IntrinsicWidth].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `stepHeight` | `final double? stepHeight` |  |
| `stepWidth` | `final double? stepWidth` |  |

### TomLayoutBuilder

**Kind:** `class`

Tom-aware wrapper for [LayoutBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final LayoutWidgetBuilder builder` | The builder function that creates the widget tree based on constraints. |

### TomLicensePage

**Kind:** `class`

Tom wrapper for [LicensePage].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applicationIcon` | `final Widget? applicationIcon` |  |
| `applicationLegalese` | `final String? applicationLegalese` |  |
| `applicationName` | `final String? applicationName` |  |
| `applicationVersion` | `final String? applicationVersion` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |

### TomLimitedBox

**Kind:** `class`

Tom wrapper for [LimitedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `maxHeight` | `final double? maxHeight` |  |
| `maxWidth` | `final double? maxWidth` |  |

### TomLinearProgressIndicator

**Kind:** `class`

Tom wrapper for [LinearProgressIndicator].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `borderRadius` | `final BorderRadiusGeometry? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `minHeight` | `final double? minHeight` |  |
| `semanticsLabel` | `final String? semanticsLabel` |  |
| `semanticsValue` | `final String? semanticsValue` |  |
| `value` | `final double? value` |  |
| `valueColor` | `final Animation<Color?>? valueColor` |  |

### TomListBody

**Kind:** `class`

Tom wrapper for [ListBody].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `mainAxis` | `final Axis mainAxis` |  |
| `reverse` | `final bool? reverse` |  |

### TomListTile

**Kind:** `class`

Tom wrapper for [ListTile] (as display label).

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `contentPadding` | `final EdgeInsetsGeometry? contentPadding` |  |
| `dense` | `final bool? dense` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `enabled` | `final bool enabled` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `horizontalTitleGap` | `final double? horizontalTitleGap` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `iconColor` | `final Color? iconColor` |  |
| `isThreeLine` | `final bool isThreeLine` |  |
| `leading` | `final Widget? leading` |  |
| `leadingAndTrailingTextStyle` | `final TextStyle? leadingAndTrailingTextStyle` |  |
| `minLeadingWidth` | `final double? minLeadingWidth` |  |
| `minTileHeight` | `final double? minTileHeight` |  |
| `minVerticalPadding` | `final double? minVerticalPadding` |  |
| `mouseCursor` | `final MouseCursor? mouseCursor` |  |
| `onLongPress` | `final VoidCallback? onLongPress` |  |
| `onTap` | `final VoidCallback? onTap` |  |
| `selected` | `final bool selected` |  |
| `selectedColor` | `final Color? selectedColor` |  |
| `selectedTileColor` | `final Color? selectedTileColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `splashColor` | `final Color? splashColor` |  |
| `subtitle` | `final Widget? subtitle` |  |
| `subtitleTextStyle` | `final TextStyle? subtitleTextStyle` |  |
| `textColor` | `final Color? textColor` |  |
| `tileColor` | `final Color? tileColor` |  |
| `title` | `final Widget? title` |  |
| `titleAlignment` | `final ListTileTitleAlignment? titleAlignment` |  |
| `titleText` | `final String? titleText` |  |
| `titleTextStyle` | `final TextStyle? titleTextStyle` |  |
| `trailing` | `final Widget? trailing` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomListView

**Kind:** `class`

Tom wrapper for [ListView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `addAutomaticKeepAlives` | `final bool addAutomaticKeepAlives` |  |
| `addRepaintBoundaries` | `final bool addRepaintBoundaries` |  |
| `addSemanticIndexes` | `final bool addSemanticIndexes` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `TomListView.builder({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, this.scrollDirection = Axis.vertical, this.reverse = false, this.controller, this.primary, this.physics, this.shrinkWrap = false, this.padding, this.itemExtent, this.prototypeItem, required NullableIndexedWidgetBuilder itemBuilder, int? itemCount, this.cacheExtent, this.semanticChildCount, this.dragStartBehavior = DragStartBehavior.start, this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual, this.restorationId, this.clipBehavior = Clip.hardEdge, this.addAutomaticKeepAlives = true, this.addRepaintBoundaries = true, this.addSemanticIndexes = true}) : _children = null, _childrenDelegate = SliverChildBuilderDelegate( ScopeCapture(scope: scope).wrap2(itemBuilder), childCount: itemCount, addAutomaticKeepAlives: addAutomaticKeepAlives, addRepaintBoundaries: addRepaintBoundaries, addSemanticIndexes: addSemanticIndexes)` | Creates a scrollable, linear array of widgets that are created on demand. |
| `cacheExtent` | `final double? cacheExtent` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `custom` | `TomListView.custom({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, this.scrollDirection = Axis.vertical, this.reverse = false, this.controller, this.primary, this.physics, this.shrinkWrap = false, this.padding, this.itemExtent, this.prototypeItem, required SliverChildDelegate childrenDelegate, this.cacheExtent, this.semanticChildCount, this.dragStartBehavior = DragStartBehavior.start, this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual, this.restorationId, this.clipBehavior = Clip.hardEdge, this.addAutomaticKeepAlives = true, this.addRepaintBoundaries = true, this.addSemanticIndexes = true}) : _children = null, _childrenDelegate = childrenDelegate` | Creates a scrollable, linear array of widgets with a custom child model. |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `keyboardDismissBehavior` | `final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `primary` | `final bool? primary` |  |
| `prototypeItem` | `final Widget? prototypeItem` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |
| `semanticChildCount` | `final int? semanticChildCount` |  |
| `separated` | `TomListView.separated({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, this.scrollDirection = Axis.vertical, this.reverse = false, this.controller, this.primary, this.physics, this.shrinkWrap = false, this.padding, required NullableIndexedWidgetBuilder itemBuilder, required IndexedWidgetBuilder separatorBuilder, required int itemCount, this.cacheExtent, this.dragStartBehavior = DragStartBehavior.start, this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual, this.restorationId, this.clipBehavior = Clip.hardEdge, this.addAutomaticKeepAlives = true, this.addRepaintBoundaries = true, this.addSemanticIndexes = true}) : itemExtent = null, prototypeItem = null, semanticChildCount = itemCount, _children = null, _childrenDelegate = SliverChildBuilderDelegate( ScopeCapture(scope: scope).wrap2((BuildContext context, int index) { final int itemIndex = index ~/ 2; if (index.isEven) { return itemBuilder(context, itemIndex); } return separatorBuilder(context, itemIndex); }), childCount: _computeActualChildCount(itemCount), addAutomaticKeepAlives: addAutomaticKeepAlives, addRepaintBoundaries: addRepaintBoundaries,` | Creates a fixed-length scrollable linear array of list "items" separated by list item "separators". |
| `shrinkWrap` | `final bool shrinkWrap` |  |

### TomListWheelScrollView

**Kind:** `class`

Tom wrapper for [ListWheelScrollView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `childDelegate` | `final ListWheelChildDelegate childDelegate` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `diameterRatio` | `final double? diameterRatio` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `magnification` | `final double? magnification` |  |
| `offAxisFraction` | `final double? offAxisFraction` |  |
| `onSelectedItemChanged` | `final ValueChanged<int>? onSelectedItemChanged` |  |
| `overAndUnderCenterOpacity` | `final double? overAndUnderCenterOpacity` |  |
| `perspective` | `final double? perspective` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `renderChildrenOutsideViewport` | `final bool renderChildrenOutsideViewport` |  |
| `restorationId` | `final String? restorationId` |  |
| `scrollBehavior` | `final ScrollBehavior? scrollBehavior` |  |
| `squeeze` | `final double? squeeze` |  |
| `useMagnifier` | `final bool useMagnifier` |  |

### TomListenableBuilder

**Kind:** `class`

Tom-aware wrapper for [ListenableBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final TransitionBuilder builder` | The builder function that creates the widget tree. |
| `child` | `final Widget? child` | The child widget to pass to the builder (optimization for static content). |
| `listenable` | `final Listenable listenable` | The [Listenable] to listen to. |

### TomLongPressDraggable

**Kind:** `class`

Tom wrapper for [LongPressDraggable].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `axis` | `final Axis? axis` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `childWhenDragging` | `final Widget? childWhenDragging` |  |
| `data` | `final T? data` |  |
| `delay` | `final Duration delay` |  |
| `dragAnchorStrategy` | `final DragAnchorStrategy dragAnchorStrategy` |  |
| `feedback` | `final Widget feedback` |  |
| `feedbackOffset` | `final Offset feedbackOffset` |  |
| `hapticFeedbackOnStart` | `final bool? hapticFeedbackOnStart` |  |
| `ignoringFeedbackPointer` | `final bool? ignoringFeedbackPointer` |  |
| `ignoringFeedbackSemantics` | `final bool? ignoringFeedbackSemantics` |  |
| `maxSimultaneousDrags` | `final int? maxSimultaneousDrags` |  |
| `onDragCompleted` | `final VoidCallback? onDragCompleted` |  |
| `onDragEnd` | `final DragEndCallback? onDragEnd` |  |
| `onDragStarted` | `final VoidCallback? onDragStarted` |  |
| `onDragUpdate` | `final DragUpdateCallback? onDragUpdate` |  |
| `onDraggableCanceled` | `final DraggableCanceledCallback? onDraggableCanceled` |  |

### TomMaterial

**Kind:** `class`

Tom wrapper for [Material].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `animationDuration` | `final Duration animationDuration` |  |
| `borderOnForeground` | `final bool borderOnForeground` |  |
| `borderRadius` | `final BorderRadiusGeometry? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final Color? color` |  |
| `elevation` | `final double? elevation` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `textStyle` | `final TextStyle? textStyle` |  |
| `type` | `final MaterialType type` |  |

### TomMaterialBanner

**Kind:** `class`

Tom wrapper for [MaterialBanner].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actions` | `final List<Widget> actions` |  |
| `animation` | `final Animation<double>? animation` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `content` | `final Widget content` |  |
| `contentTextStyle` | `final TextStyle? contentTextStyle` |  |
| `dividerColor` | `final Color? dividerColor` |  |
| `elevation` | `final double? elevation` |  |
| `forceActionsBelow` | `final bool forceActionsBelow` |  |
| `leading` | `final Widget? leading` |  |
| `leadingPadding` | `final EdgeInsetsGeometry? leadingPadding` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `onVisible` | `final VoidCallback? onVisible` |  |
| `overflowAlignment` | `final OverflowBarAlignment overflowAlignment` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |

### TomMenuAcceleratorLabel

**Kind:** `class`

Tom wrapper for [MenuAcceleratorLabel].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final MenuAcceleratorChildBuilder? builder` |  |
| `label` | `final String? label` |  |

### TomMenuAnchor

**Kind:** `class`

Tom wrapper for [MenuAnchor].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignmentOffset` | `final Offset? alignmentOffset` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final Widget Function(BuildContext, MenuController, Widget?)? builder` |  |
| `child` | `final Widget? child` |  |
| `childFocusNode` | `final FocusNode? childFocusNode` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `consumeOutsideTap` | `final bool consumeOutsideTap` |  |
| `controller` | `final MenuController? controller` |  |
| `menuChildren` | `final List<Widget> menuChildren` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onOpen` | `final VoidCallback? onOpen` |  |
| `style` | `final MenuStyle? style` |  |

### TomMenuBar

**Kind:** `class`

Tom wrapper for [MenuBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `style` | `final MenuStyle? style` |  |

### TomMenuItemButton

**Kind:** `class`

Tom wrapper for [MenuItemButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `closeOnActivate` | `final bool closeOnActivate` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `label` | `final String? label` |  |
| `leadingIcon` | `final Widget? leadingIcon` |  |
| `onFocusChange` | `final VoidCallback? onFocusChange` |  |
| `onHover` | `final VoidCallback? onHover` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `shortcut` | `final MenuSerializableShortcut? shortcut` |  |
| `style` | `final ButtonStyle? style` |  |
| `trailingIcon` | `final Widget? trailingIcon` |  |

### TomMessenger

**Kind:** `abstract final class`

Tom-native presenter for transient messages (snack bars).

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `showMessage` | `static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showMessage( BuildContext context, String message)` | Shows a plain [message] wrapped in a [TomSnackBar]/[TomText], the common case for one-line notifications. |
| `showSnackBar` | `showSnackBar(BuildContext context, SnackBar snackBar)` |  |
| `showSnackBarIfPresent` | `showSnackBarIfPresent(BuildContext context, SnackBar snackBar)` |  |

### TomModalBottomSheet

**Kind:** `class`

Tom wrapper for the material modal bottom sheet shown by [showModalBottomSheet].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `anchorPoint` | `final Offset? anchorPoint` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `barrierColor` | `final Color? barrierColor` |  |
| `barrierLabel` | `final String? barrierLabel` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final WidgetBuilder builder` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `elevation` | `final double? elevation` |  |
| `enableDrag` | `final bool enableDrag` |  |
| `isDismissible` | `final bool isDismissible` |  |
| `isScrollControlled` | `final bool isScrollControlled` |  |
| `routeSettings` | `final RouteSettings? routeSettings` |  |
| `scrollControlDisabledMaxHeightRatio` | `final double scrollControlDisabledMaxHeightRatio` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `showDragHandle` | `final bool? showDragHandle` |  |
| `transitionAnimationController` | `final AnimationController? transitionAnimationController` |  |
| `useRootNavigator` | `final bool useRootNavigator` |  |
| `useSafeArea` | `final bool useSafeArea` |  |

### TomMouseRegion

**Kind:** `class`

Tom wrapper for [MouseRegion].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `cursor` | `final MouseCursor cursor` |  |
| `hitTestBehavior` | `final HitTestBehavior? hitTestBehavior` |  |
| `onEnter` | `final PointerEnterEventListener? onEnter` |  |
| `onExit` | `final PointerExitEventListener? onExit` |  |
| `onHover` | `final PointerHoverEventListener? onHover` |  |
| `opaque` | `final bool? opaque` |  |

### TomNavigationBar

**Kind:** `class`

Tom wrapper for [NavigationBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `animationDuration` | `final Duration? animationDuration` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `destinations` | `final List<Widget> destinations` |  |
| `elevation` | `final double? elevation` |  |
| `height` | `final double? height` |  |
| `indicatorColor` | `final Color? indicatorColor` |  |
| `indicatorShape` | `final ShapeBorder? indicatorShape` |  |
| `labelBehavior` | `final NavigationDestinationLabelBehavior? labelBehavior` |  |
| `labelTextStyle` | `final WidgetStateProperty<TextStyle?>? labelTextStyle` |  |
| `onDestinationSelected` | `final ValueChanged<int>? onDestinationSelected` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `selectedIndex` | `final int selectedIndex` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |

### TomNavigationDestination

**Kind:** `class`

Tom widget that EXTENDS [NavigationDestination] with authorization and resources.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `build` | `Widget build(BuildContext context)` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomNavigationDrawer

**Kind:** `class`

Tom wrapper for [NavigationDrawer].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `elevation` | `final double? elevation` |  |
| `indicatorColor` | `final Color? indicatorColor` |  |
| `indicatorShape` | `final ShapeBorder? indicatorShape` |  |
| `onDestinationSelected` | `final ValueChanged<int>? onDestinationSelected` |  |
| `selectedIndex` | `final int? selectedIndex` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `tilePadding` | `final EdgeInsetsGeometry? tilePadding` |  |

### TomNavigationDrawerDestination

**Kind:** `class`

Tom widget that EXTENDS [NavigationDrawerDestination] with authorization.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `build` | `Widget build(BuildContext context)` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomNavigationRail

**Kind:** `class`

Tom wrapper for [NavigationRail].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `destinations` | `final List<NavigationRailDestination> destinations` |  |
| `elevation` | `final double? elevation` |  |
| `extended` | `final bool extended` |  |
| `groupAlignment` | `final double? groupAlignment` |  |
| `indicatorColor` | `final Color? indicatorColor` |  |
| `indicatorShape` | `final ShapeBorder? indicatorShape` |  |
| `labelType` | `final NavigationRailLabelType? labelType` |  |
| `leading` | `final Widget? leading` |  |
| `minExtendedWidth` | `final double? minExtendedWidth` |  |
| `minWidth` | `final double? minWidth` |  |
| `onDestinationSelected` | `final ValueChanged<int>? onDestinationSelected` |  |
| `selectedIconTheme` | `final IconThemeData? selectedIconTheme` |  |
| `selectedIndex` | `final int? selectedIndex` |  |
| `selectedLabelTextStyle` | `final TextStyle? selectedLabelTextStyle` |  |
| `trailing` | `final Widget? trailing` |  |
| `unselectedIconTheme` | `final IconThemeData? unselectedIconTheme` |  |
| `unselectedLabelTextStyle` | `final TextStyle? unselectedLabelTextStyle` |  |
| `useIndicator` | `final bool? useIndicator` |  |

### TomNestedScrollView

**Kind:** `class`

Tom wrapper for [NestedScrollView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `body` | `final Widget body` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `floatHeaderSlivers` | `final bool? floatHeaderSlivers` |  |
| `headerSliverBuilder` | `final NestedScrollViewHeaderSliversBuilder headerSliverBuilder` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollBehavior` | `final ScrollBehavior? scrollBehavior` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |

### TomNetworkImage

**Kind:** `class`

Tom wrapper for [Image] that uses [NetworkImage] as its provider.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `centerSlice` | `final Rect? centerSlice` |  |
| `color` | `final Color? color` |  |
| `colorBlendMode` | `final BlendMode? colorBlendMode` |  |
| `errorBuilder` | `final ImageErrorWidgetBuilder? errorBuilder` |  |
| `excludeFromSemantics` | `final bool excludeFromSemantics` |  |
| `filterQuality` | `final FilterQuality filterQuality` |  |
| `fit` | `final BoxFit? fit` |  |
| `frameBuilder` | `final ImageFrameBuilder? frameBuilder` |  |
| `gaplessPlayback` | `final bool gaplessPlayback` |  |
| `headers` | `final Map<String, String>? headers` |  |
| `height` | `final double? height` |  |
| `isAntiAlias` | `final bool isAntiAlias` |  |
| `loadingBuilder` | `final ImageLoadingBuilder? loadingBuilder` |  |
| `matchTextDirection` | `final bool matchTextDirection` |  |
| `repeat` | `final ImageRepeat repeat` |  |
| `scale` | `final double scale` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `src` | `final String src` |  |
| `width` | `final double? width` |  |

### TomOffstage

**Kind:** `class`

Tom wrapper for [Offstage].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `offstage` | `final bool offstage` |  |

### TomOpacity

**Kind:** `class`

Tom wrapper for [Opacity].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alwaysIncludeSemantics` | `final bool alwaysIncludeSemantics` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `opacity` | `final double? opacity` |  |

### TomOrientationBuilder

**Kind:** `class`

Tom-aware wrapper for [OrientationBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final OrientationWidgetBuilder builder` | The builder function that creates the widget tree based on orientation. |

### TomOutlinedButton

**Kind:** `class`

Tom wrapper for [OutlinedButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `icon` | `final Widget? icon` |  |
| `label` | `final String? label` |  |
| `onFocusChange` | `final ValueChanged<bool>? onFocusChange` |  |
| `onHover` | `final ValueChanged<bool>? onHover` |  |
| `onLongPress` | `final VoidCallback? onLongPress` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `style` | `final ButtonStyle? style` |  |

### TomOverflowBar

**Kind:** `class`

Tom wrapper for [OverflowBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final MainAxisAlignment? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `overflowAlignment` | `final OverflowBarAlignment overflowAlignment` |  |
| `overflowDirection` | `final VerticalDirection overflowDirection` |  |
| `overflowSpacing` | `final double? overflowSpacing` |  |
| `spacing` | `final double? spacing` |  |
| `textDirection` | `final TextDirection? textDirection` |  |

### TomOverflowBox

**Kind:** `class`

Tom wrapper for [OverflowBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `fit` | `final OverflowBoxFit fit` |  |
| `maxHeight` | `final double? maxHeight` |  |
| `maxWidth` | `final double? maxWidth` |  |
| `minHeight` | `final double? minHeight` |  |
| `minWidth` | `final double? minWidth` |  |

### TomPadding

**Kind:** `class`

Tom wrapper for [Padding].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `padding` | `final EdgeInsetsGeometry padding` |  |

### TomPageRoute

**Kind:** `class`

A [MaterialPageRoute] that propagates the active [TomScope] across navigation.

### TomPageView

**Kind:** `class`

Tom wrapper for [PageView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `allowImplicitScrolling` | `final bool allowImplicitScrolling` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final PageController? controller` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `onPageChanged` | `final ValueChanged<int>? onPageChanged` |  |
| `padEnds` | `final bool padEnds` |  |
| `pageSnapping` | `final bool pageSnapping` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollBehavior` | `final ScrollBehavior? scrollBehavior` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |

### TomPaginatedDataTable

**Kind:** `class`

Tom wrapper for [PaginatedDataTable].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actions` | `final List<Widget>? actions` |  |
| `arrowHeadColor` | `final double? arrowHeadColor` |  |
| `availableRowsPerPage` | `final List<int> availableRowsPerPage` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkboxHorizontalMargin` | `final double? checkboxHorizontalMargin` |  |
| `columnSpacing` | `final double? columnSpacing` |  |
| `columns` | `final List<DataColumn> columns` |  |
| `dataRowMaxHeight` | `final double? dataRowMaxHeight` |  |
| `dataRowMinHeight` | `final double? dataRowMinHeight` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `header` | `final Widget? header` |  |
| `headingRowColor` | `final WidgetStateProperty<Color?>? headingRowColor` |  |
| `headingRowHeight` | `final double? headingRowHeight` |  |
| `horizontalMargin` | `final double? horizontalMargin` |  |
| `initialFirstRowIndex` | `final int? initialFirstRowIndex` |  |
| `onPageChanged` | `final ValueChanged<int>? onPageChanged` |  |
| `onRowsPerPageChanged` | `final ValueChanged<int?>? onRowsPerPageChanged` |  |
| `onSelectAll` | `final ValueSetter<bool?>? onSelectAll` |  |
| `rowsPerPage` | `final int rowsPerPage` |  |
| `showCheckboxColumn` | `final bool showCheckboxColumn` |  |
| `showEmptyRows` | `final bool showEmptyRows` |  |
| `showFirstLastButtons` | `final bool showFirstLastButtons` |  |
| `sortAscending` | `final bool sortAscending` |  |
| `sortColumnIndex` | `final int? sortColumnIndex` |  |
| `source` | `final DataTableSource source` |  |

### TomPhysicalModel

**Kind:** `class`

Tom wrapper for [PhysicalModel].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final Color? color` |  |
| `elevation` | `final double? elevation` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final BoxShape shape` |  |

### TomPhysicalShape

**Kind:** `class`

Tom wrapper for [PhysicalShape].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `clipper` | `final CustomClipper<Path> clipper` |  |
| `color` | `final Color? color` |  |
| `elevation` | `final double? elevation` |  |
| `shadowColor` | `final Color? shadowColor` |  |

### TomPinnedHeaderSliver

**Kind:** `class`

Tom wrapper for [PinnedHeaderSliver].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |

### TomPopupMenuButton

**Kind:** `class`

Tom wrapper for [PopupMenuButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `color` | `final Color? color` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `elevation` | `final double? elevation` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `enabled` | `final bool enabled` |  |
| `icon` | `final Widget? icon` |  |
| `iconSize` | `final double? iconSize` |  |
| `initialValue` | `final T? initialValue` |  |
| `itemBuilder` | `final PopupMenuItemBuilder<T> itemBuilder` |  |
| `offset` | `final Offset? offset` |  |
| `onCanceled` | `final PopupMenuCanceled? onCanceled` |  |
| `onSelected` | `final PopupMenuItemSelected<T>? onSelected` |  |
| `padding` | `final EdgeInsetsGeometry padding` |  |
| `position` | `final PopupMenuPosition? position` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `tooltip` | `final String? tooltip` |  |

### TomPopupMenuDivider

**Kind:** `class`

Tom widget that EXTENDS [PopupMenuDivider] with authorization.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomPopupMenuItem

**Kind:** `class`

Tom widget that EXTENDS [PopupMenuItem] with authorization and resources.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomPositioned

**Kind:** `class`

Tom wrapper for [Positioned] with authorization and resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `bottom` | `final double? bottom` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `fill` | `TomPositioned.fill({ super.key, super.tomId, super.tomGroup, super.scope, super.authorizer, super.uiStateController, this.left = 0.0, this.top = 0.0, this.right = 0.0, this.bottom = 0.0, required this.child}) : width = null, height = null` | Creates a Tom Positioned widget that fills the Stack. |
| `height` | `final double? height` |  |
| `left` | `final double? left` |  |
| `right` | `final double? right` |  |
| `top` | `final double? top` |  |
| `width` | `final double? width` |  |

### TomPositionedDirectional

**Kind:** `class`

Tom wrapper for [PositionedDirectional] with authorization and resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `bottom` | `final double? bottom` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `end` | `final double? end` |  |
| `height` | `final double? height` |  |
| `start` | `final double? start` |  |
| `top` | `final double? top` |  |
| `width` | `final double? width` |  |

### TomRadio

**Kind:** `class`

Tom wrapper for [Radio].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `enabled` | `final bool? enabled` | Whether the radio accepts input, forwarded to [Radio.enabled]. |
| `fillColor` | `final WidgetStateProperty<Color?>? fillColor` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `splashRadius` | `final double? splashRadius` |  |
| `toggleable` | `final bool toggleable` |  |
| `value` | `final T value` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomRadioListTile

**Kind:** `class`

Tom wrapper for [RadioListTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `contentPadding` | `final EdgeInsetsGeometry? contentPadding` |  |
| `controlAffinity` | `final ListTileControlAffinity controlAffinity` |  |
| `dense` | `final bool? dense` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `enabled` | `final bool? enabled` | Whether the tile accepts input, forwarded to [RadioListTile.enabled]. |
| `fillColor` | `final WidgetStateProperty<Color?>? fillColor` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `isThreeLine` | `final bool isThreeLine` |  |
| `secondary` | `final Widget? secondary` |  |
| `selectedTileColor` | `final Color? selectedTileColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `subtitle` | `final Widget? subtitle` |  |
| `tileColor` | `final Color? tileColor` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |
| `toggleable` | `final bool toggleable` |  |
| `value` | `final T value` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomRadioMenuButton

**Kind:** `class`

Tom wrapper for [RadioMenuButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `groupValue` | `final T? groupValue` |  |
| `label` | `final String? label` |  |
| `onChanged` | `final ValueChanged<T?>? onChanged` |  |
| `onFocusChange` | `final VoidCallback? onFocusChange` |  |
| `onHover` | `final VoidCallback? onHover` |  |
| `shortcut` | `final MenuSerializableShortcut? shortcut` |  |
| `toggleable` | `final bool toggleable` |  |
| `value` | `final T value` |  |

### TomRangeSlider

**Kind:** `class`

Tom wrapper for [RangeSlider].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `divisions` | `final int? divisions` |  |
| `inactiveColor` | `final Color? inactiveColor` |  |
| `labels` | `final RangeLabels? labels` |  |
| `max` | `final double max` |  |
| `min` | `final double min` |  |
| `onChangeEnd` | `final ValueChanged<RangeValues>? onChangeEnd` |  |
| `onChangeStart` | `final ValueChanged<RangeValues>? onChangeStart` |  |
| `onChanged` | `final ValueChanged<RangeValues>? onChanged` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `semanticFormatterCallback` | `final SemanticFormatterCallback? semanticFormatterCallback` |  |
| `values` | `final RangeValues values` |  |

### TomRawChip

**Kind:** `class`

Tom wrapper for [RawChip].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `avatar` | `final Widget? avatar` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `checkmarkColor` | `final Color? checkmarkColor` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `deleteButtonTooltipMessage` | `final String? deleteButtonTooltipMessage` |  |
| `deleteIcon` | `final Widget? deleteIcon` |  |
| `deleteIconColor` | `final Color? deleteIconColor` |  |
| `disabledColor` | `final Color? disabledColor` |  |
| `elevation` | `final double? elevation` |  |
| `isEnabled` | `final bool isEnabled` |  |
| `label` | `final Widget? label` |  |
| `labelPadding` | `final EdgeInsetsGeometry? labelPadding` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `labelText` | `final String? labelText` |  |
| `materialTapTargetSize` | `final MaterialTapTargetSize? materialTapTargetSize` |  |
| `onDeleted` | `final VoidCallback? onDeleted` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `onSelected` | `final ValueChanged<bool>? onSelected` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `pressElevation` | `final double? pressElevation` |  |
| `selected` | `final bool selected` |  |
| `selectedColor` | `final Color? selectedColor` |  |
| `selectedShadowColor` | `final Color? selectedShadowColor` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final OutlinedBorder? shape` |  |
| `showCheckmark` | `final bool? showCheckmark` |  |
| `side` | `final BorderSide? side` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `tooltip` | `final String? tooltip` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomRefreshIndicator

**Kind:** `class`

Tom wrapper for [RefreshIndicator].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `color` | `final Color? color` |  |
| `displacement` | `final double displacement` |  |
| `edgeOffset` | `final double edgeOffset` |  |
| `notificationPredicate` | `final ScrollNotificationPredicate notificationPredicate` |  |
| `onRefresh` | `final Future<void> Function() onRefresh` |  |
| `semanticsLabel` | `final String? semanticsLabel` |  |
| `semanticsValue` | `final String? semanticsValue` |  |
| `strokeWidth` | `final double strokeWidth` |  |
| `triggerMode` | `final RefreshIndicatorTriggerMode triggerMode` |  |

### TomRefreshProgressIndicator

**Kind:** `class`

Tom wrapper for [RefreshProgressIndicator] with construction-time resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomReorderableList

**Kind:** `class`

Tom wrapper for [ReorderableList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `anchor` | `final double anchor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `cacheExtent` | `final double? cacheExtent` |  |
| `childrenDelegate` | `final SliverChildDelegate childrenDelegate` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `itemExtentBuilder` | `final ItemExtentBuilder? itemExtentBuilder` |  |
| `keyboardDismissBehavior` | `final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior` |  |
| `onReorderEnd` | `final void Function(int)? onReorderEnd` |  |
| `onReorderItem` | `final ReorderCallback onReorderItem` |  |
| `onReorderStart` | `final void Function(int)? onReorderStart` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `primary` | `final bool? primary` |  |
| `prototypeItem` | `final Widget? prototypeItem` |  |
| `proxyDecorator` | `final ReorderItemProxyDecorator? proxyDecorator` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |
| `shrinkWrap` | `final bool? shrinkWrap` |  |

### TomReorderableListView

**Kind:** `class`

Tom wrapper for [ReorderableListView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `anchor` | `final double? anchor` |  |
| `autoScrollerVelocityScalar` | `final double? autoScrollerVelocityScalar` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `buildDefaultDragHandles` | `final bool buildDefaultDragHandles` |  |
| `cacheExtent` | `final double? cacheExtent` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `footer` | `final Widget? footer` |  |
| `header` | `final Widget? header` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `keyboardDismissBehavior` | `final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior` |  |
| `onReorderEnd` | `final void Function(int)? onReorderEnd` |  |
| `onReorderItem` | `final ReorderCallback onReorderItem` |  |
| `onReorderStart` | `final void Function(int)? onReorderStart` |  |
| `padding` | `final EdgeInsets? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `primary` | `final bool? primary` |  |
| `prototypeItem` | `final Widget? prototypeItem` |  |
| `proxyDecorator` | `final ReorderItemProxyDecorator? proxyDecorator` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollController` | `final ScrollController? scrollController` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |
| `shrinkWrap` | `final bool shrinkWrap` |  |

### TomRichText

**Kind:** `class`

Tom wrapper for [RichText].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `locale` | `final Locale? locale` |  |
| `maxLines` | `final int? maxLines` |  |
| `overflow` | `final TextOverflow overflow` |  |
| `selectionColor` | `final Color? selectionColor` |  |
| `selectionRegistrar` | `final SelectionRegistrar? selectionRegistrar` |  |
| `softWrap` | `final bool softWrap` |  |
| `strutStyle` | `final StrutStyle? strutStyle` |  |
| `text` | `final InlineSpan text` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textHeightBehavior` | `final TextHeightBehavior? textHeightBehavior` |  |
| `textWidthBasis` | `final TextWidthBasis textWidthBasis` |  |

### TomRotatedBox

**Kind:** `class`

Tom wrapper for [RotatedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `quarterTurns` | `final int? quarterTurns` |  |

### TomRotationTransition

**Kind:** `class`

Tom wrapper for [RotationTransition].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final Alignment alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `filterQuality` | `final FilterQuality? filterQuality` |  |
| `turns` | `final Animation<double> turns` |  |

### TomRow

**Kind:** `class`

Tom wrapper for [Row].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `crossAxisAlignment` | `final CrossAxisAlignment crossAxisAlignment` |  |
| `mainAxisAlignment` | `final MainAxisAlignment mainAxisAlignment` |  |
| `mainAxisSize` | `final MainAxisSize mainAxisSize` |  |
| `textBaseline` | `final TextBaseline? textBaseline` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `verticalDirection` | `final VerticalDirection verticalDirection` |  |

### TomSafeArea

**Kind:** `class`

Tom wrapper for [SafeArea].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `bottom` | `final bool bottom` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `left` | `final bool left` |  |
| `maintainBottomViewPadding` | `final bool maintainBottomViewPadding` |  |
| `minimum` | `final EdgeInsets minimum` |  |
| `right` | `final bool right` |  |
| `top` | `final bool top` |  |

### TomScaffold

**Kind:** `class`

Tom wrapper for [Scaffold].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `appBar` | `final PreferredSizeWidget? appBar` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `body` | `final Widget? body` |  |
| `bottomNavigationBar` | `final Widget? bottomNavigationBar` |  |
| `bottomSheet` | `final Widget? bottomSheet` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `drawer` | `final Widget? drawer` |  |
| `drawerEdgeDragWidth` | `final double? drawerEdgeDragWidth` |  |
| `drawerEnableOpenDragGesture` | `final bool drawerEnableOpenDragGesture` |  |
| `drawerScrimColor` | `final Color? drawerScrimColor` |  |
| `endDrawer` | `final Widget? endDrawer` |  |
| `endDrawerEnableOpenDragGesture` | `final bool endDrawerEnableOpenDragGesture` |  |
| `extendBody` | `final bool extendBody` |  |
| `extendBodyBehindAppBar` | `final bool extendBodyBehindAppBar` |  |
| `floatingActionButton` | `final Widget? floatingActionButton` |  |
| `floatingActionButtonAnimator` | `final FloatingActionButtonAnimator? floatingActionButtonAnimator` |  |
| `floatingActionButtonLocation` | `final FloatingActionButtonLocation? floatingActionButtonLocation` |  |
| `persistentFooterAlignment` | `final AlignmentDirectional persistentFooterAlignment` |  |
| `persistentFooterButtons` | `final List<Widget>? persistentFooterButtons` |  |
| `primary` | `final bool primary` |  |
| `resizeToAvoidBottomInset` | `final bool? resizeToAvoidBottomInset` |  |
| `restorationId` | `final String? restorationId` |  |

### TomScaleTransition

**Kind:** `class`

Tom wrapper for [ScaleTransition].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final Alignment alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `filterQuality` | `final FilterQuality? filterQuality` |  |
| `scale` | `final Animation<double> scale` |  |

### TomScrollbar

**Kind:** `class`

Tom wrapper for [Scrollbar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `controller` | `final ScrollController? controller` |  |
| `interactive` | `final bool? interactive` |  |
| `notificationPredicate` | `final ScrollNotificationPredicate? notificationPredicate` |  |
| `radius` | `final Radius? radius` |  |
| `scrollbarOrientation` | `final ScrollbarOrientation? scrollbarOrientation` |  |
| `thickness` | `final double? thickness` |  |
| `thumbVisibility` | `final bool? thumbVisibility` |  |
| `trackVisibility` | `final bool? trackVisibility` |  |

### TomSearchAnchor

**Kind:** `class`

Tom wrapper for [SearchAnchor].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final SearchAnchorChildBuilder? builder` |  |
| `dividerColor` | `final Color? dividerColor` |  |
| `headerHintStyle` | `final TextStyle? headerHintStyle` |  |
| `headerTextStyle` | `final TextStyle? headerTextStyle` |  |
| `isFullScreen` | `final bool isFullScreen` |  |
| `searchController` | `final SearchController? searchController` |  |
| `suggestionsBuilder` | `final SuggestionsBuilder suggestionsBuilder` |  |
| `textCapitalization` | `final TextCapitalization? textCapitalization` |  |
| `viewBackgroundColor` | `final Color? viewBackgroundColor` |  |
| `viewConstraints` | `final BoxConstraints? viewConstraints` |  |
| `viewElevation` | `final double? viewElevation` |  |
| `viewHintText` | `final String? viewHintText` |  |
| `viewLeading` | `final Widget? viewLeading` |  |
| `viewOnSubmitted` | `final TextInputAction? viewOnSubmitted` |  |
| `viewShape` | `final OutlinedBorder? viewShape` |  |
| `viewSide` | `final BorderSide? viewSide` |  |
| `viewSurfaceTintColor` | `final Color? viewSurfaceTintColor` |  |
| `viewTrailing` | `final List<Widget>? viewTrailing` |  |

### TomSearchBar

**Kind:** `class`

Tom wrapper for [SearchBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autoFocus` | `final bool autoFocus` |  |
| `backgroundColor` | `final WidgetStateProperty<Color?>? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `controller` | `final TextEditingController? controller` |  |
| `elevation` | `final WidgetStateProperty<double?>? elevation` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hintStyle` | `final WidgetStateProperty<TextStyle?>? hintStyle` |  |
| `hintText` | `final String? hintText` |  |
| `leading` | `final Widget? leading` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onTap` | `final VoidCallback? onTap` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `padding` | `final WidgetStateProperty<EdgeInsetsGeometry?>? padding` |  |
| `shape` | `final WidgetStateProperty<OutlinedBorder?>? shape` |  |
| `side` | `final WidgetStateProperty<BorderSide?>? side` |  |
| `surfaceTintColor` | `final WidgetStateProperty<Color?>? surfaceTintColor` |  |
| `textCapitalization` | `final TextCapitalization textCapitalization` |  |
| `textStyle` | `final WidgetStateProperty<TextStyle?>? textStyle` |  |
| `trailing` | `final Iterable<Widget>? trailing` |  |

### TomSegmentedButton

**Kind:** `class`

Tom wrapper for [SegmentedButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `emptySelectionAllowed` | `final bool emptySelectionAllowed` |  |
| `multiSelectionEnabled` | `final bool multiSelectionEnabled` |  |
| `onSelectionChanged` | `final ValueChanged<Set<T>>? onSelectionChanged` |  |
| `segments` | `final List<ButtonSegment<T>> segments` |  |
| `selected` | `final Set<T> selected` |  |
| `selectedIcon` | `final Widget? selectedIcon` |  |
| `showSelectedIcon` | `final bool showSelectedIcon` |  |
| `style` | `final ButtonStyle? style` |  |

### TomSelectableRegion

**Kind:** `class`

Tom wrapper for [SelectableRegion].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `contextMenuBuilder` | `final SelectableRegionContextMenuBuilder? contextMenuBuilder` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `magnifierConfiguration` | `final TextMagnifierConfiguration magnifierConfiguration` |  |
| `onSelectionChanged` | `final ValueChanged<SelectedContent?>? onSelectionChanged` |  |
| `selectionControls` | `final TextSelectionControls selectionControls` |  |

### TomSelectableText

**Kind:** `class`

Tom wrapper for [SelectableText].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `contextMenuBuilder` | `final EditableTextContextMenuBuilder? contextMenuBuilder` |  |
| `cursorColor` | `final Color? cursorColor` |  |
| `cursorHeight` | `final double? cursorHeight` |  |
| `cursorRadius` | `final Radius? cursorRadius` |  |
| `cursorWidth` | `final double cursorWidth` |  |
| `dragStartBehavior` | `final DragStartBehavior? dragStartBehavior` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `magnifierConfiguration` | `final TextMagnifierConfiguration? magnifierConfiguration` |  |
| `maxLines` | `final int? maxLines` |  |
| `minLines` | `final int? minLines` |  |
| `onSelectionChanged` | `final SelectionChangedCallback? onSelectionChanged` |  |
| `onTap` | `final VoidCallback? onTap` |  |
| `scrollPhysics` | `final ScrollPhysics? scrollPhysics` |  |
| `selectionControls` | `final TextSelectionControls? selectionControls` |  |
| `semanticsLabel` | `final String? semanticsLabel` |  |
| `showCursor` | `final bool showCursor` |  |
| `strutStyle` | `final StrutStyle? strutStyle` |  |
| `style` | `final TextStyle? style` |  |
| `text` | `final String? text` | The text to display. |
| `textAlign` | `final TextAlign? textAlign` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textHeightBehavior` | `final TextHeightBehavior? textHeightBehavior` |  |
| `textWidthBasis` | `final TextWidthBasis? textWidthBasis` |  |

### TomSelectionArea

**Kind:** `class`

Tom wrapper for [SelectionArea].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `contextMenuBuilder` | `final SelectableRegionContextMenuBuilder? contextMenuBuilder` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `magnifierConfiguration` | `final TextMagnifierConfiguration? magnifierConfiguration` |  |
| `onSelectionChanged` | `final ValueChanged<SelectedContent?>? onSelectionChanged` |  |
| `selectionControls` | `final TextSelectionControls? selectionControls` |  |

### TomSensitiveContent

**Kind:** `class`

Tom wrapper for [SensitiveContent].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `sensitivity` | `final ContentSensitivity? sensitivity` |  |

### TomShaderMask

**Kind:** `class`

Tom wrapper for [ShaderMask].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `blendMode` | `final BlendMode? blendMode` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `shaderCallback` | `final ShaderCallback shaderCallback` |  |

### TomSimpleDialog

**Kind:** `class`

Tom wrapper for [SimpleDialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget>? children` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `contentPadding` | `final EdgeInsetsGeometry contentPadding` |  |
| `elevation` | `final double? elevation` |  |
| `insetPadding` | `final EdgeInsets? insetPadding` |  |
| `semanticLabel` | `final String? semanticLabel` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `title` | `final Widget? title` |  |
| `titlePadding` | `final EdgeInsetsGeometry titlePadding` |  |
| `titleText` | `final String? titleText` |  |
| `titleTextStyle` | `final TextStyle? titleTextStyle` |  |

### TomSimpleDialogOption

**Kind:** `class`

Tom wrapper for [SimpleDialogOption].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `padding` | `final EdgeInsets? padding` |  |

### TomSingleChildScrollView

**Kind:** `class`

Tom wrapper for [SingleChildScrollView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final ScrollController? controller` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `keyboardDismissBehavior` | `final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `restorationId` | `final String? restorationId` |  |
| `reverse` | `final bool reverse` |  |
| `scrollDirection` | `final Axis scrollDirection` |  |

### TomSizedBox

**Kind:** `class`

Tom wrapper for [SizedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `height` | `final double? height` |  |
| `width` | `final double? width` |  |

### TomSizedOverflowBox

**Kind:** `class`

Tom wrapper for [SizedOverflowBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `size` | `final Size size` |  |

### TomSlider

**Kind:** `class`

Tom wrapper for [Slider].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `allowedInteraction` | `final SliderInteraction? allowedInteraction` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `divisions` | `final int? divisions` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `inactiveColor` | `final Color? inactiveColor` |  |
| `label` | `final String? label` |  |
| `max` | `final double max` |  |
| `min` | `final double min` |  |
| `onChangeEnd` | `final ValueChanged<double>? onChangeEnd` |  |
| `onChangeStart` | `final ValueChanged<double>? onChangeStart` |  |
| `onChanged` | `final ValueChanged<double>? onChanged` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `semanticFormatterCallback` | `final SemanticFormatterCallback? semanticFormatterCallback` |  |
| `thumbColor` | `final Color? thumbColor` |  |
| `value` | `final double value` |  |

### TomSliverAppBar

**Kind:** `class`

Tom wrapper for [SliverAppBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `actions` | `final List<Widget>? actions` |  |
| `actionsIconTheme` | `final IconThemeData? actionsIconTheme` |  |
| `automaticallyImplyLeading` | `final bool automaticallyImplyLeading` |  |
| `backgroundColor` | `final Color? backgroundColor` |  |
| `bottom` | `final PreferredSizeWidget? bottom` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `centerTitle` | `final bool? centerTitle` |  |
| `clipBehavior` | `final Clip? clipBehavior` |  |
| `collapsedHeight` | `final double? collapsedHeight` |  |
| `elevation` | `final double? elevation` |  |
| `excludeHeaderSemantics` | `final bool excludeHeaderSemantics` |  |
| `expandedHeight` | `final double? expandedHeight` |  |
| `flexibleSpace` | `final Widget? flexibleSpace` |  |
| `floating` | `final bool floating` |  |
| `forceMaterialTransparency` | `final bool forceMaterialTransparency` |  |
| `foregroundColor` | `final Color? foregroundColor` |  |
| `iconTheme` | `final IconThemeData? iconTheme` |  |
| `leading` | `final Widget? leading` |  |
| `leadingWidth` | `final double? leadingWidth` |  |
| `pinned` | `final bool pinned` |  |
| `primary` | `final bool primary` |  |
| `scrolledUnderElevation` | `final double? scrolledUnderElevation` |  |
| `shadowColor` | `final Color? shadowColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `snap` | `final bool snap` |  |
| `stretch` | `final bool stretch` |  |
| `stretchTriggerOffset` | `final double stretchTriggerOffset` |  |
| `surfaceTintColor` | `final Color? surfaceTintColor` |  |
| `systemOverlayStyle` | `final SystemUiOverlayStyle? systemOverlayStyle` |  |
| `title` | `final Widget? title` |  |
| `titleSpacing` | `final double? titleSpacing` |  |
| `titleText` | `final String? titleText` |  |
| `titleTextStyle` | `final TextStyle? titleTextStyle` |  |
| `toolbarHeight` | `final double toolbarHeight` |  |
| `toolbarTextStyle` | `final TextStyle? toolbarTextStyle` |  |

### TomSliverConstrainedCrossAxis

**Kind:** `class`

Tom wrapper for [SliverConstrainedCrossAxis].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `maxExtent` | `final double? maxExtent` |  |
| `sliver` | `final Widget sliver` |  |

### TomSliverCrossAxisExpanded

**Kind:** `class`

Tom wrapper for [SliverCrossAxisExpanded].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `flex` | `final int? flex` |  |
| `sliver` | `final Widget sliver` |  |

### TomSliverCrossAxisGroup

**Kind:** `class`

Tom wrapper for [SliverCrossAxisGroup].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `slivers` | `final List<Widget> slivers` |  |

### TomSliverFillRemaining

**Kind:** `class`

Tom wrapper for [SliverFillRemaining].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `fillOverscroll` | `final bool fillOverscroll` |  |
| `hasScrollBody` | `final bool hasScrollBody` |  |

### TomSliverFillViewport

**Kind:** `class`

Tom wrapper for [SliverFillViewport].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `delegate` | `final SliverChildDelegate delegate` |  |
| `padEnds` | `final bool padEnds` |  |
| `viewportFraction` | `final double? viewportFraction` |  |

### TomSliverFixedExtentList

**Kind:** `class`

Tom wrapper for [SliverFixedExtentList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `delegate` | `final SliverChildDelegate delegate` |  |
| `itemExtent` | `final double? itemExtent` |  |

### TomSliverFloatingHeader

**Kind:** `class`

Tom wrapper for [SliverFloatingHeader].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |

### TomSliverGrid

**Kind:** `class`

Tom wrapper for [SliverGrid].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `delegate` | `final SliverChildDelegate delegate` |  |
| `gridDelegate` | `final SliverGridDelegate gridDelegate` |  |

### TomSliverList

**Kind:** `class`

Tom wrapper for [SliverList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `delegate` | `final SliverChildDelegate delegate` |  |

### TomSliverMainAxisGroup

**Kind:** `class`

Tom wrapper for [SliverMainAxisGroup].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `slivers` | `final List<Widget> slivers` |  |

### TomSliverOffstage

**Kind:** `class`

Tom wrapper for [SliverOffstage].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `offstage` | `final bool? offstage` |  |
| `sliver` | `final Widget sliver` |  |

### TomSliverOpacity

**Kind:** `class`

Tom wrapper for [SliverOpacity].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alwaysIncludeSemantics` | `final bool? alwaysIncludeSemantics` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `opacity` | `final double? opacity` |  |
| `sliver` | `final Widget sliver` |  |

### TomSliverPadding

**Kind:** `class`

Tom wrapper for [SliverPadding].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `sliver` | `final Widget sliver` |  |

### TomSliverPersistentHeader

**Kind:** `class`

Tom wrapper for [SliverPersistentHeader].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `delegate` | `final SliverPersistentHeaderDelegate delegate` |  |
| `floating` | `final bool? floating` |  |
| `pinned` | `final bool? pinned` |  |

### TomSliverPrototypeExtentList

**Kind:** `class`

Tom wrapper for [SliverPrototypeExtentList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `delegate` | `final SliverChildDelegate delegate` |  |
| `prototypeItem` | `final Widget prototypeItem` |  |

### TomSliverReorderableList

**Kind:** `class`

Tom wrapper for [SliverReorderableList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `itemBuilder` | `final Widget Function(BuildContext, int) itemBuilder` |  |
| `itemCount` | `final int itemCount` |  |
| `itemExtent` | `final double? itemExtent` |  |
| `itemExtentBuilder` | `final ItemExtentBuilder? itemExtentBuilder` |  |
| `onReorderEnd` | `final void Function(int)? onReorderEnd` |  |
| `onReorderItem` | `final ReorderCallback onReorderItem` |  |
| `onReorderStart` | `final void Function(int)? onReorderStart` |  |
| `prototypeItem` | `final Widget? prototypeItem` |  |
| `proxyDecorator` | `final ReorderItemProxyDecorator? proxyDecorator` |  |

### TomSliverResizingHeader

**Kind:** `class`

Tom wrapper for [SliverResizingHeader].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `maxExtentPrototype` | `final Widget? maxExtentPrototype` | Prototype widget laid out once to define the header's maximum extent. |
| `minExtentPrototype` | `final Widget? minExtentPrototype` | Prototype widget laid out once to define the header's minimum extent. |

### TomSliverSafeArea

**Kind:** `class`

Tom wrapper for [SliverSafeArea].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `bottom` | `final bool? bottom` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `left` | `final bool? left` |  |
| `minimum` | `final EdgeInsets? minimum` |  |
| `right` | `final bool? right` |  |
| `sliver` | `final Widget sliver` |  |
| `top` | `final bool? top` |  |

### TomSliverToBoxAdapter

**Kind:** `class`

Tom wrapper for [SliverToBoxAdapter].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |

### TomSliverVariedExtentList

**Kind:** `class`

Tom wrapper for [SliverVariedExtentList].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `delegate` | `final SliverChildDelegate delegate` |  |
| `itemExtentBuilder` | `final ItemExtentBuilder itemExtentBuilder` |  |

### TomSliverVisibility

**Kind:** `class`

Tom wrapper for [SliverVisibility].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `maintainAnimation` | `final bool? maintainAnimation` |  |
| `maintainInteractivity` | `final bool? maintainInteractivity` |  |
| `maintainSemantics` | `final bool? maintainSemantics` |  |
| `maintainSize` | `final bool? maintainSize` |  |
| `maintainState` | `final bool? maintainState` |  |
| `replacementSliver` | `final Widget replacementSliver` |  |
| `sliver` | `final Widget sliver` |  |
| `visible` | `final bool? visible` |  |

### TomSnackBar

**Kind:** `class`

Tom wrapper for [SnackBar] with construction-time resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-widget authorizer, applied after the group's mode. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomSnackBarAction

**Kind:** `class`

Tom wrapper for [SnackBarAction] with construction-time resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` | Optional per-widget authorizer, applied after the group's mode. |
| `scope` | `final TomScope? scope` | Optional explicit scope for resource resolution. |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` | Optional group membership. |
| `tomId` | `final String? tomId` | Tom ID for resource resolution. |
| `uiStateController` | `final TomUIStateController? uiStateController` | Optional build-time UI-state controller, applied last. |

### TomSpacer

**Kind:** `class`

Tom widget that EXTENDS [Spacer] with authorization.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomStack

**Kind:** `class`

Tom wrapper for [Stack].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `fit` | `final StackFit fit` |  |
| `textDirection` | `final TextDirection? textDirection` |  |

### TomStatefulBuilder

**Kind:** `class`

Tom-aware wrapper for [StatefulBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final StatefulWidgetBuilder builder` | The builder function that creates the widget tree with setState capability. |

### TomStepper

**Kind:** `class`

Tom wrapper for [Stepper].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `connectorColor` | `final Color? connectorColor` |  |
| `connectorThickness` | `final double? connectorThickness` |  |
| `controlsBuilder` | `final Widget Function(BuildContext, ControlsDetails)? controlsBuilder` |  |
| `currentStep` | `final int currentStep` |  |
| `elevation` | `final double? elevation` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `onStepCancel` | `final VoidCallback? onStepCancel` |  |
| `onStepContinue` | `final VoidCallback? onStepContinue` |  |
| `onStepTapped` | `final VoidCallback? onStepTapped` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `steps` | `final List<Step> steps` |  |
| `type` | `final StepperType type` |  |

### TomStreamBuilder

**Kind:** `class`

Tom-aware wrapper for [StreamBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final AsyncWidgetBuilder<T> builder` | The builder function that creates the widget tree based on stream state. |
| `initialData` | `final T? initialData` | The initial data to use before the stream emits any events. |
| `stream` | `final Stream<T>? stream` | The stream to listen to. |

### TomSubmenuButton

**Kind:** `class`

Tom wrapper for [SubmenuButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignmentOffset` | `final Offset? alignmentOffset` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `label` | `final String? label` |  |
| `leadingIcon` | `final Widget? leadingIcon` |  |
| `menuChildren` | `final List<Widget> menuChildren` |  |
| `menuStyle` | `final MenuStyle? menuStyle` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onFocusChange` | `final VoidCallback? onFocusChange` |  |
| `onHover` | `final VoidCallback? onHover` |  |
| `onOpen` | `final VoidCallback? onOpen` |  |
| `style` | `final ButtonStyle? style` |  |
| `trailingIcon` | `final Widget? trailingIcon` |  |

### TomSwitch

**Kind:** `class`

Tom wrapper for [Switch].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `activeThumbImage` | `final ImageProvider? activeThumbImage` |  |
| `activeTrackColor` | `final Color? activeTrackColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `dragStartBehavior` | `final DragStartBehavior? dragStartBehavior` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `inactiveThumbColor` | `final Color? inactiveThumbColor` |  |
| `inactiveThumbImage` | `final ImageProvider? inactiveThumbImage` |  |
| `inactiveTrackColor` | `final Color? inactiveTrackColor` |  |
| `onChanged` | `final ValueChanged<bool>? onChanged` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `splashRadius` | `final double? splashRadius` |  |
| `thumbColor` | `final WidgetStateProperty<Color?>? thumbColor` |  |
| `thumbIcon` | `final WidgetStateProperty<Icon?>? thumbIcon` |  |
| `trackColor` | `final WidgetStateProperty<Color?>? trackColor` |  |
| `trackOutlineColor` | `final WidgetStateProperty<Color?>? trackOutlineColor` |  |
| `trackOutlineWidth` | `final WidgetStateProperty<double?>? trackOutlineWidth` |  |
| `value` | `final bool value` |  |

### TomSwitchListTile

**Kind:** `class`

Tom wrapper for [SwitchListTile].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activeColor` | `final Color? activeColor` |  |
| `activeTrackColor` | `final Color? activeTrackColor` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `contentPadding` | `final EdgeInsetsGeometry? contentPadding` |  |
| `controlAffinity` | `final ListTileControlAffinity controlAffinity` |  |
| `dense` | `final bool? dense` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `inactiveThumbColor` | `final Color? inactiveThumbColor` |  |
| `inactiveTrackColor` | `final Color? inactiveTrackColor` |  |
| `isThreeLine` | `final bool isThreeLine` |  |
| `onChanged` | `final ValueChanged<bool>? onChanged` |  |
| `secondary` | `final Widget? secondary` |  |
| `selectedTileColor` | `final Color? selectedTileColor` |  |
| `shape` | `final ShapeBorder? shape` |  |
| `subtitle` | `final Widget? subtitle` |  |
| `tileColor` | `final Color? tileColor` |  |
| `title` | `final Widget? title` |  |
| `titleText` | `final String? titleText` |  |
| `value` | `final bool value` |  |
| `visualDensity` | `final VisualDensity? visualDensity` |  |

### TomTab

**Kind:** `class`

Tom widget that EXTENDS [Tab] with authorization and resources.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `build` | `Widget build(BuildContext context)` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomTabBar

**Kind:** `class`

Tom wrapper for [TabBar].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `automaticIndicatorColorAdjustment` | `final bool automaticIndicatorColorAdjustment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `controller` | `final TabController? controller` |  |
| `dividerColor` | `final Color? dividerColor` |  |
| `dividerHeight` | `final double? dividerHeight` |  |
| `dragStartBehavior` | `final DragStartBehavior? dragStartBehavior` |  |
| `indicator` | `final Decoration? indicator` |  |
| `indicatorColor` | `final Color? indicatorColor` |  |
| `indicatorPadding` | `final EdgeInsetsGeometry? indicatorPadding` |  |
| `indicatorSize` | `final TabBarIndicatorSize? indicatorSize` |  |
| `indicatorWeight` | `final double? indicatorWeight` |  |
| `isScrollable` | `final bool isScrollable` |  |
| `labelColor` | `final Color? labelColor` |  |
| `labelPadding` | `final EdgeInsetsGeometry? labelPadding` |  |
| `labelStyle` | `final TextStyle? labelStyle` |  |
| `onTap` | `final ValueChanged<int>? onTap` |  |
| `overlayColor` | `final WidgetStateProperty<Color?>? overlayColor` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `preferredSize` | `Size get preferredSize` |  |
| `splashBorderRadius` | `final BorderRadius? splashBorderRadius` |  |
| `splashFactory` | `final InteractiveInkFeatureFactory? splashFactory` |  |
| `tabAlignment` | `final TabAlignment? tabAlignment` |  |
| `tabs` | `final List<Widget> tabs` |  |
| `textScaler` | `final TextScaler? textScaler` |  |
| `unselectedLabelColor` | `final Color? unselectedLabelColor` |  |
| `unselectedLabelStyle` | `final TextStyle? unselectedLabelStyle` |  |

### TomTabBarView

**Kind:** `class`

Tom wrapper for [TabBarView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `controller` | `final TabController? controller` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `viewportFraction` | `final double? viewportFraction` |  |

### TomTabPageSelector

**Kind:** `class`

Tom wrapper for [TabPageSelector].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `borderStyle` | `final BorderStyle? borderStyle` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `controller` | `final TabController? controller` |  |
| `indicatorSize` | `final double? indicatorSize` |  |
| `selectedColor` | `final Color? selectedColor` |  |

### TomTable

**Kind:** `class`

Tom wrapper for [Table].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `border` | `final TableBorder? border` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<TableRow> children` |  |
| `columnWidths` | `final Map<int, TableColumnWidth>? columnWidths` |  |
| `defaultColumnWidth` | `final TableColumnWidth defaultColumnWidth` |  |
| `defaultVerticalAlignment` | `final TableCellVerticalAlignment defaultVerticalAlignment` |  |
| `textBaseline` | `final TextBaseline? textBaseline` |  |
| `textDirection` | `final TextDirection? textDirection` |  |

### TomTableCell

**Kind:** `class`

Tom widget that EXTENDS [TableCell] with authorization and resource resolution.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `basePath` | `final String? basePath` |  |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

### TomText

**Kind:** `class`

Tom wrapper for [Text].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `defaultFor` | `static TomText? defaultFor( String? tomId, [ TomScope? scope, TomAuthorizationGroup? tomGroup])` | A `TomText` for the slot named by [tomId], or `null` when there is no id. |
| `defaultOrEmpty` | `static Widget defaultOrEmpty( String? tomId, [ TomScope? scope, TomAuthorizationGroup? tomGroup])` | As [defaultFor], but substitutes `SizedBox.shrink()` for a null [tomId] so the result is always a widget. |
| `locale` | `final Locale? locale` |  |
| `maxLines` | `final int? maxLines` |  |
| `overflow` | `final TextOverflow? overflow` |  |
| `semanticsLabel` | `final String? semanticsLabel` |  |
| `softWrap` | `final bool? softWrap` |  |
| `strutStyle` | `final StrutStyle? strutStyle` |  |
| `style` | `final TextStyle? style` |  |
| `text` | `final String? text` | The text to display. |
| `textAlign` | `final TextAlign? textAlign` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textHeightBehavior` | `final TextHeightBehavior? textHeightBehavior` |  |
| `textWidthBasis` | `final TextWidthBasis? textWidthBasis` |  |

### TomTextButton

**Kind:** `class`

Tom wrapper for [TextButton].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `icon` | `final Widget? icon` |  |
| `label` | `final String? label` |  |
| `onFocusChange` | `final ValueChanged<bool>? onFocusChange` |  |
| `onHover` | `final ValueChanged<bool>? onHover` |  |
| `onLongPress` | `final VoidCallback? onLongPress` |  |
| `onPressed` | `final VoidCallback? onPressed` |  |
| `style` | `final ButtonStyle? style` |  |

### TomTextField

**Kind:** `class`

Tom wrapper for [TextField].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autocorrect` | `final bool autocorrect` |  |
| `autofillHints` | `final Iterable<String>? autofillHints` |  |
| `autofocus` | `final bool autofocus` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `buildCounter` | `final InputCounterWidgetBuilder? buildCounter` |  |
| `canRequestFocus` | `final bool canRequestFocus` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `contentInsertionConfiguration` | `final ContentInsertionConfiguration? contentInsertionConfiguration` |  |
| `contextMenuBuilder` | `final EditableTextContextMenuBuilder? contextMenuBuilder` |  |
| `controller` | `final TextEditingController? controller` |  |
| `cursorColor` | `final Color? cursorColor` |  |
| `cursorErrorColor` | `final Color? cursorErrorColor` |  |
| `cursorHeight` | `final double? cursorHeight` |  |
| `cursorRadius` | `final Radius? cursorRadius` |  |
| `cursorWidth` | `final double? cursorWidth` |  |
| `decoration` | `final InputDecoration? decoration` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `enableIMEPersonalizedLearning` | `final bool enableIMEPersonalizedLearning` |  |
| `enableInteractiveSelection` | `final bool? enableInteractiveSelection` |  |
| `enableSuggestions` | `final bool enableSuggestions` |  |
| `enabled` | `final bool enabled` |  |
| `expands` | `final bool expands` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hint` | `final String? hint` |  |
| `ignorePointers` | `final bool? ignorePointers` |  |
| `inputFormatters` | `final List<TextInputFormatter>? inputFormatters` |  |
| `keyboardAppearance` | `final Brightness? keyboardAppearance` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `label` | `final String? label` |  |
| `magnifierConfiguration` | `final TextMagnifierConfiguration? magnifierConfiguration` |  |
| `maxLength` | `final int? maxLength` |  |
| `maxLengthEnforcement` | `final MaxLengthEnforcement? maxLengthEnforcement` |  |
| `maxLines` | `final int? maxLines` |  |
| `minLines` | `final int? minLines` |  |
| `mouseCursor` | `final MouseCursor? mouseCursor` |  |
| `obscureText` | `final bool obscureText` |  |
| `obscuringCharacter` | `final String? obscuringCharacter` |  |
| `onAppPrivateCommand` | `final AppPrivateCommandCallback? onAppPrivateCommand` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onEditingComplete` | `final VoidCallback? onEditingComplete` |  |
| `onSubmitted` | `final ValueChanged<String>? onSubmitted` |  |
| `onTap` | `final GestureTapCallback? onTap` |  |
| `onTapAlwaysCalled` | `final bool onTapAlwaysCalled` |  |
| `onTapOutside` | `final TapRegionCallback? onTapOutside` |  |
| `readOnly` | `final bool readOnly` |  |
| `restorationId` | `final String? restorationId` |  |
| `scribbleEnabled` | `final bool scribbleEnabled` |  |
| `scrollController` | `final ScrollController? scrollController` |  |
| `scrollPadding` | `final EdgeInsets scrollPadding` |  |
| `scrollPhysics` | `final ScrollPhysics? scrollPhysics` |  |
| `selectionControls` | `final TextSelectionControls? selectionControls` |  |
| `selectionHeightStyle` | `final BoxHeightStyle selectionHeightStyle` |  |
| `selectionWidthStyle` | `final BoxWidthStyle selectionWidthStyle` |  |
| `showCursor` | `final bool? showCursor` |  |
| `smartDashesType` | `final SmartDashesType? smartDashesType` |  |
| `smartQuotesType` | `final SmartQuotesType? smartQuotesType` |  |
| `spellCheckConfiguration` | `final SpellCheckConfiguration? spellCheckConfiguration` |  |
| `strutStyle` | `final StrutStyle? strutStyle` |  |
| `style` | `final TextStyle? style` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textAlignVertical` | `final TextAlignVertical? textAlignVertical` |  |
| `textCapitalization` | `final TextCapitalization textCapitalization` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textInputAction` | `final TextInputAction? textInputAction` |  |
| `undoController` | `final UndoHistoryController? undoController` |  |

### TomTextFormField

**Kind:** `class`

Tom wrapper for [TextFormField].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `autocorrect` | `final bool autocorrect` |  |
| `autofocus` | `final bool autofocus` |  |
| `autovalidateMode` | `final AutovalidateMode? autovalidateMode` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `controller` | `final TextEditingController? controller` |  |
| `decoration` | `final InputDecoration? decoration` |  |
| `enabled` | `final bool enabled` |  |
| `focusNode` | `final FocusNode? focusNode` |  |
| `hint` | `final String? hint` |  |
| `initialValue` | `final String? initialValue` |  |
| `keyboardType` | `final TextInputType? keyboardType` |  |
| `label` | `final String? label` |  |
| `maxLength` | `final int? maxLength` |  |
| `maxLines` | `final int? maxLines` |  |
| `minLines` | `final int? minLines` |  |
| `obscureText` | `final bool obscureText` |  |
| `onChanged` | `final ValueChanged<String>? onChanged` |  |
| `onEditingComplete` | `final VoidCallback? onEditingComplete` |  |
| `onFieldSubmitted` | `final ValueChanged<String>? onFieldSubmitted` |  |
| `onSaved` | `final FormFieldSetter<String>? onSaved` |  |
| `readOnly` | `final bool readOnly` |  |
| `style` | `final TextStyle? style` |  |
| `textAlign` | `final TextAlign textAlign` |  |
| `textCapitalization` | `final TextCapitalization textCapitalization` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `textInputAction` | `final TextInputAction? textInputAction` |  |
| `validator` | `final FormFieldValidator<String>? validator` |  |

### TomTimePickerDialog

**Kind:** `class`

Tom wrapper for [TimePickerDialog].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `cancelText` | `final String? cancelText` |  |
| `confirmText` | `final String? confirmText` |  |
| `errorInvalidText` | `final String? errorInvalidText` |  |
| `helpText` | `final String? helpText` |  |
| `hourLabelText` | `final String? hourLabelText` |  |
| `initialEntryMode` | `final TimePickerEntryMode initialEntryMode` |  |
| `initialTime` | `final TimeOfDay initialTime` |  |
| `minuteLabelText` | `final String? minuteLabelText` |  |
| `onEntryModeChanged` | `final EntryModeChangeCallback? onEntryModeChanged` |  |
| `orientation` | `final Orientation? orientation` |  |

### TomToggleButtons

**Kind:** `class`

Tom wrapper for [ToggleButtons].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `borderColor` | `final Color? borderColor` |  |
| `borderRadius` | `final BorderRadius? borderRadius` |  |
| `borderWidth` | `final double? borderWidth` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `color` | `final Color? color` |  |
| `constraints` | `final BoxConstraints? constraints` |  |
| `direction` | `final Axis direction` |  |
| `disabledBorderColor` | `final Color? disabledBorderColor` |  |
| `disabledColor` | `final Color? disabledColor` |  |
| `fillColor` | `final Color? fillColor` |  |
| `focusColor` | `final Color? focusColor` |  |
| `focusNodes` | `final List<FocusNode>? focusNodes` |  |
| `highlightColor` | `final Color? highlightColor` |  |
| `hoverColor` | `final Color? hoverColor` |  |
| `isSelected` | `final List<bool> isSelected` |  |
| `onPressed` | `final ValueChanged<int>? onPressed` |  |
| `renderBorder` | `final bool renderBorder` |  |
| `selectedBorderColor` | `final Color? selectedBorderColor` |  |
| `selectedColor` | `final Color? selectedColor` |  |
| `splashColor` | `final Color? splashColor` |  |
| `textStyle` | `final TextStyle? textStyle` |  |
| `verticalDirection` | `final VerticalDirection verticalDirection` |  |

### TomTooltip

**Kind:** `class`

Tom wrapper for [Tooltip].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `decoration` | `final Decoration? decoration` |  |
| `enableFeedback` | `final bool? enableFeedback` |  |
| `enableTapToDismiss` | `final bool enableTapToDismiss` |  |
| `excludeFromSemantics` | `final bool? excludeFromSemantics` |  |
| `exitDuration` | `final Duration? exitDuration` |  |
| `height` | `final double? height` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `message` | `final String? message` |  |
| `onTriggered` | `final TooltipTriggeredCallback? onTriggered` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `preferBelow` | `final bool? preferBelow` |  |
| `richMessage` | `final InlineSpan? richMessage` |  |
| `showDuration` | `final Duration? showDuration` |  |
| `textAlign` | `final TextAlign? textAlign` |  |
| `textStyle` | `final TextStyle? textStyle` |  |
| `triggerMode` | `final TooltipTriggerMode? triggerMode` |  |
| `verticalOffset` | `final double? verticalOffset` |  |
| `waitDuration` | `final Duration? waitDuration` |  |

### TomTransform

**Kind:** `class`

Tom wrapper for [Transform].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry? alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `filterQuality` | `final FilterQuality? filterQuality` |  |
| `origin` | `final Offset? origin` |  |
| `transform` | `final Matrix4 transform` |  |
| `transformHitTests` | `final bool? transformHitTests` |  |

### TomTreeNode

**Kind:** `class`

Data model for a tree node used by [TomTreeView].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `children` | `final List<TomTreeNode> children` |  |
| `initiallyExpanded` | `final bool? initiallyExpanded` |  |
| `leading` | `final Widget? leading` |  |
| `onTap` | `final VoidCallback? onTap` |  |
| `title` | `final Widget title` |  |
| `trailing` | `final Widget? trailing` |  |

### TomTreeSliver

**Kind:** `class`

Tom wrapper for [TreeSliver].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `addAutomaticKeepAlives` | `final bool? addAutomaticKeepAlives` |  |
| `addRepaintBoundaries` | `final bool? addRepaintBoundaries` |  |
| `addSemanticIndexes` | `final bool? addSemanticIndexes` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `controller` | `final TreeSliverController? controller` |  |
| `indentation` | `final TreeSliverIndentationType indentation` |  |
| `onNodeToggle` | `final TreeSliverNodeCallback? onNodeToggle` |  |
| `toggleAnimationStyle` | `final AnimationStyle? toggleAnimationStyle` |  |
| `tree` | `final List<TreeSliverNode<T>> tree` |  |
| `treeNodeBuilder` | `final TreeSliverNodeBuilder treeNodeBuilder` |  |
| `treeRowExtentBuilder` | `final TreeSliverRowExtentBuilder treeRowExtentBuilder` |  |

### TomTreeView

**Kind:** `class`

Tom custom TreeView widget.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `indentation` | `final double? indentation` |  |
| `nodes` | `final List<TomTreeNode> nodes` |  |
| `padding` | `final EdgeInsetsGeometry? padding` |  |
| `physics` | `final ScrollPhysics? physics` |  |
| `shrinkWrap` | `final bool shrinkWrap` |  |

### TomTweenAnimationBuilder

**Kind:** `class`

Tom-aware wrapper for [TweenAnimationBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final ValueWidgetBuilder<T> builder` | The builder function that creates the widget tree based on the animated value. |
| `child` | `final Widget? child` | The child widget to pass to the builder (optimization for static content). |
| `curve` | `final Curve? curve` | The curve to apply to the animation. |
| `duration` | `final Duration duration` | The duration of the animation. |
| `onEnd` | `final VoidCallback? onEnd` | Callback invoked when the animation ends. |
| `tween` | `final Tween<T> tween` | The tween to animate. |

### TomUnconstrainedBox

**Kind:** `class`

Tom wrapper for [UnconstrainedBox].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final AlignmentGeometry alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget? child` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `constrainedAxis` | `final Axis? constrainedAxis` |  |
| `textDirection` | `final TextDirection? textDirection` |  |

### TomUserAccountsDrawerHeader

**Kind:** `class`

Tom wrapper for [UserAccountsDrawerHeader].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `accountEmail` | `final Widget? accountEmail` |  |
| `accountName` | `final Widget? accountName` |  |
| `arrowColor` | `final Color? arrowColor` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `currentAccountPicture` | `final Widget? currentAccountPicture` |  |
| `currentAccountPictureSize` | `final Size currentAccountPictureSize` |  |
| `decoration` | `final Decoration? decoration` |  |
| `margin` | `final EdgeInsetsGeometry? margin` |  |
| `onDetailsPressed` | `final VoidCallback? onDetailsPressed` |  |
| `otherAccountsPictures` | `final List<Widget>? otherAccountsPictures` |  |
| `otherAccountsPicturesSize` | `final Size otherAccountsPicturesSize` |  |

### TomValueListenableBuilder

**Kind:** `class`

Tom-aware wrapper for [ValueListenableBuilder].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `builder` | `final ValueWidgetBuilder<T> builder` | The builder function that creates the widget tree based on the value. |
| `child` | `final Widget? child` | The child widget to pass to the builder (optimization for static content). |
| `valueListenable` | `final ValueListenable<T> valueListenable` | The [ValueListenable] to listen to. |

### TomVerticalDivider

**Kind:** `class`

Tom wrapper for [VerticalDivider].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `color` | `final Color? color` |  |
| `endIndent` | `final double? endIndent` |  |
| `indent` | `final double? indent` |  |
| `thickness` | `final double? thickness` |  |
| `width` | `final double? width` |  |

### TomVisibility

**Kind:** `class`

Tom wrapper for [Visibility].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `child` | `final Widget child` |  |
| `maintainAnimation` | `final bool maintainAnimation` |  |
| `maintainInteractivity` | `final bool maintainInteractivity` |  |
| `maintainSemantics` | `final bool maintainSemantics` |  |
| `maintainSize` | `final bool maintainSize` |  |
| `maintainState` | `final bool maintainState` |  |
| `replacement` | `final Widget replacement` |  |
| `visible` | `final bool visible` |  |

### TomWrap

**Kind:** `class`

Tom wrapper for [Wrap].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `alignment` | `final WrapAlignment alignment` |  |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `children` | `final List<Widget> children` |  |
| `clipBehavior` | `final Clip clipBehavior` |  |
| `crossAxisAlignment` | `final WrapCrossAlignment crossAxisAlignment` |  |
| `direction` | `final Axis direction` |  |
| `runAlignment` | `final WrapAlignment runAlignment` |  |
| `runSpacing` | `final double? runSpacing` |  |
| `spacing` | `final double? spacing` |  |
| `textDirection` | `final TextDirection? textDirection` |  |
| `verticalDirection` | `final VerticalDirection verticalDirection` |  |

### TomYearPicker

**Kind:** `class`

Tom wrapper for [YearPicker].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `buildContent` | `Widget buildContent(BuildContext context)` |  |
| `currentDate` | `final DateTime currentDate` |  |
| `dragStartBehavior` | `final DragStartBehavior dragStartBehavior` |  |
| `firstDate` | `final DateTime firstDate` |  |
| `lastDate` | `final DateTime lastDate` |  |
| `onChanged` | `final ValueChanged<DateTime> onChanged` |  |
| `selectedDate` | `final DateTime selectedDate` |  |

## Global Functions and Constants

None — this module exports types only.
