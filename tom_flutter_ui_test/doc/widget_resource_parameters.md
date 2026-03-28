# Widget Resource Parameters — Complete Inventory

Complete inventory of all Tom Flutter UI widget constructor parameters that can be loaded from resources. This document covers all 21 widget files and 291 widget classes.

**Scope:** Only parameters with an existing resolution method are listed. Widget, Callback, Controller, and opaque object parameters (ImageProvider, delegates, etc.) are excluded as they cannot be resource-resolved.

**Status key:**
- ✅ = Currently resolved in `buildContent()` via resource resolution
- ⛔ = Cannot use resource resolution (extension pattern or other constraint)
- ⬜ = Has a matching resolver but not yet wired

> **Note:** The ✅ status is based on source scanning and may not capture all resolved parameters. Verify against the actual `buildContent()` methods when in doubt.

---

## Available Resolution Methods

### Primitive Resolvers (TomNodeBase)

| Method | Return Type | Resource Value |
|--------|-------------|----------------|
| `resolveResourceOrNull` | `String?` | String |
| `resolveResource` | `String` | String (throws if missing) |
| `resolveResourceOrFail` | `String` | String (FlutterError if missing) |
| `resolveColorOrNull` | `Color?` | Hex string `#RRGGBB` / `#AARRGGBB` |
| `resolveColorOrFail` | `Color` | Hex string (FlutterError if missing) |
| `resolveDoubleOrNull` | `double?` | Numeric |
| `resolveDoubleOrFail` | `double` | Numeric (FlutterError if missing) |
| `resolveIntOrNull` | `int?` | Integer |
| `resolveIntOrFail` | `int` | Integer (FlutterError if missing) |
| `resolveBoolOrNull` | `bool?` | Boolean |
| `resolveEdgeInsetsOrNull` | `EdgeInsets?` | Map `{left,top,right,bottom}` |
| `resolveIcon` | `IconData?` | Icon name string |
| `resolveListOrNull` | `List?` | List |
| `resolveMapOrNull` | `Map?` | Map |

### Complex Resolvers (TomStyleResolvers)

| Method | Return Type | Map Keys |
|--------|-------------|----------|
| `resolveTextStyle` | `TextStyle?` | fontSize, fontWeight, fontStyle, color, backgroundColor, letterSpacing, wordSpacing, height, decoration, decorationColor, decorationStyle, overflow, fontFamily |
| `resolveButtonStyle` | `ButtonStyle?` | backgroundColor, foregroundColor, elevation, padding, minimumSize, maximumSize, shape, side |
| `resolveInputDecoration` | `InputDecoration?` | labelText, hintText, helperText, errorText, prefixText, suffixText, counterText, filled, fillColor, border, enabledBorder, focusedBorder, errorBorder |
| `resolveMenuStyle` | `MenuStyle?` | backgroundColor, surfaceTintColor, shadowColor, elevation, padding, minimumSize, maximumSize, shape, side |
| `resolveShapeBorder` | `ShapeBorder?` | type (roundedRectangle/stadium/circle/beveled), borderRadius, side |
| `resolveBorderSide` | `BorderSide?` | color, width, style |
| `resolveBorderRadius` | `BorderRadius?` | topLeft, topRight, bottomLeft, bottomRight, all |
| `resolveDecoration` | `Decoration?` | color, borderRadius, border, boxShadow |
| `resolveBoxConstraints` | `BoxConstraints?` | minWidth, maxWidth, minHeight, maxHeight |
| `resolveAlignment` | `AlignmentGeometry?` | x, y (or preset names) |
| `resolveOffset` | `Offset?` | dx, dy |
| `resolveTableBorder` | `TableBorder?` | top, right, bottom, left, horizontalInside, verticalInside, borderRadius |
| `resolveVisualDensity` | `VisualDensity?` | horizontal, vertical (or preset: comfortable/compact/standard) |
| `resolveIconThemeData` | `IconThemeData?` | color, opacity, size, fill, weight, grade, opticalSize |
| `resolveStrutStyle` | `StrutStyle?` | fontFamily, fontSize, fontWeight, fontStyle, height, leading, forceStrutHeight |
| `resolveTextHeightBehavior` | `TextHeightBehavior?` | applyHeightToFirstAscent, applyHeightToLastDescent, leadingDistribution |
| `resolveScrollPhysics` | `ScrollPhysics?` | type (bouncing/clamping/never/always/page) |

---

## Parameters by Widget Category

### Animated Widgets (`tom_animated.dart`)

#### TomAnimatedAlign

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | resolveAlignment | ✅ |
| heightFactor | double? | resolveDoubleOrNull | ✅ |
| widthFactor | double? | resolveDoubleOrNull | ✅ |

#### TomAnimatedContainer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| decoration | Decoration? | resolveDecoration | ✅ |
| foregroundDecoration | Decoration? | resolveDecoration | ✅ |
| constraints | BoxConstraints? | resolveBoxConstraints | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |
| transformAlignment | AlignmentGeometry? | resolveAlignment | ✅ |

#### TomAnimatedDefaultTextStyle

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | TextStyle | resolveTextStyle | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| softWrap | bool | resolveBoolOrNull | ✅ |

#### TomAnimatedFractionallySizedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | resolveAlignment | ✅ |
| widthFactor | double? | resolveDoubleOrNull | ✅ |
| heightFactor | double? | resolveDoubleOrNull | ✅ |

#### TomAnimatedOpacity

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opacity | double | resolveDoubleOrNull | ✅ |

#### TomAnimatedPadding

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry | resolveEdgeInsetsOrNull | ✅ |

#### TomAnimatedPhysicalModel

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | double | resolveDoubleOrNull | ✅ |
| color | Color | resolveColorOrNull | ✅ |
| shadowColor | Color | resolveColorOrNull | ✅ |
| borderRadius | BorderRadius | resolveBorderRadius | ✅ |


#### TomAnimatedBuilder

No resource-loadable parameters.

#### TomAnimatedCrossFade

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |
| excludeBottomFocus | bool? | resolveBoolOrNull | ✅ |

#### TomAnimatedPositioned

> ⛔ **Extension pattern** — Uses `extends AnimatedPositioned with TomWidgetMixin` so Stack recognizes it as Positioned. Parameters pass to super constructor at construction time, not at build time. Resource resolution not possible.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| left | double? | resolveDoubleOrNull | ⛔ |
| top | double? | resolveDoubleOrNull | ⛔ |
| right | double? | resolveDoubleOrNull | ⛔ |
| bottom | double? | resolveDoubleOrNull | ⛔ |
| width | double? | resolveDoubleOrNull | ⛔ |
| height | double? | resolveDoubleOrNull | ⛔ |

#### TomAnimatedPositionedDirectional

> ⛔ **Extension pattern** — Uses `extends AnimatedPositionedDirectional with TomWidgetMixin` so Stack recognizes it as Positioned. Parameters pass to super constructor at construction time, not at build time. Resource resolution not possible.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| start | double? | resolveDoubleOrNull | ⛔ |
| top | double? | resolveDoubleOrNull | ⛔ |
| end | double? | resolveDoubleOrNull | ⛔ |
| bottom | double? | resolveDoubleOrNull | ⛔ |
| width | double? | resolveDoubleOrNull | ⛔ |
| height | double? | resolveDoubleOrNull | ⛔ |

#### TomAnimatedRotation

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| turns | double? | resolveDoubleOrNull | ✅ |
| alignment | Alignment? | resolveAlignment | ✅ |

#### TomAnimatedScale

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| scale | double? | resolveDoubleOrNull | ✅ |
| alignment | Alignment? | resolveAlignment | ✅ |

#### TomAnimatedSize

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |

#### TomAnimatedSlide

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| offset | Offset | resolveOffset | ✅ |

#### TomAnimatedSwitcher

No resource-loadable parameters.

#### TomFadeTransition

No resource-loadable parameters.

#### TomHero

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| transitionOnUserGestures | bool? | resolveBoolOrNull | ✅ |

#### TomRotationTransition

No resource-loadable parameters.

#### TomScaleTransition

No resource-loadable parameters.

---

### Builder Widgets (`tom_builders.dart`)

#### TomFutureBuilder

No resource-loadable parameters.

#### TomLayoutBuilder

No resource-loadable parameters.

#### TomListenableBuilder

No resource-loadable parameters.

#### TomOrientationBuilder

No resource-loadable parameters.

#### TomStatefulBuilder

No resource-loadable parameters.

#### TomStreamBuilder

No resource-loadable parameters.

#### TomTweenAnimationBuilder

No resource-loadable parameters.

#### TomValueListenableBuilder

No resource-loadable parameters.

---

### Buttons (`tom_buttons.dart`)

#### TomElevatedButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | resolveButtonStyle | ✅ |

#### TomTextButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | resolveButtonStyle | ✅ |

#### TomOutlinedButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | resolveButtonStyle | ✅ |

#### TomFilledButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | resolveButtonStyle | ✅ |

#### TomFloatingActionButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| tooltip | String? | resolveResourceOrNull | ✅ |
| foregroundColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| focusColor | Color? | resolveColorOrNull | ✅ |
| hoverColor | Color? | resolveColorOrNull | ✅ |
| splashColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| focusElevation | double? | resolveDoubleOrNull | ✅ |
| hoverElevation | double? | resolveDoubleOrNull | ✅ |
| highlightElevation | double? | resolveDoubleOrNull | ✅ |
| disabledElevation | double? | resolveDoubleOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| mini | bool | resolveBoolOrNull | ✅ |
| isExtended | bool? | resolveBoolOrNull | ✅ |
| autofocus | bool | resolveBoolOrNull | ✅ |
| label | String? | resolveResourceOrNull | ✅ |


#### TomBackButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | resolveColorOrNull | ✅ |

#### TomButtonBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| buttonMinWidth | double? | resolveDoubleOrNull | ✅ |
| buttonHeight | double? | resolveDoubleOrNull | ✅ |
| buttonPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| overflowButtonSpacing | double? | resolveDoubleOrNull | ✅ |

#### TomCheckboxMenuButton

No resource-loadable parameters.

#### TomCloseButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | resolveColorOrNull | ✅ |

#### TomCupertinoActionSheetAction

No resource-loadable parameters.

#### TomCupertinoButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| minSize | double? | resolveDoubleOrNull | ✅ |
| pressedOpacity | double? | resolveDoubleOrNull | ✅ |

#### TomCupertinoContextMenuAction

No resource-loadable parameters.

#### TomCupertinoDialogAction

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| textStyle | TextStyle? | resolveTextStyle | ✅ |

#### TomDropdownMenuEntry

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | resolveButtonStyle | ✅ |

#### TomExpandIcon

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| size | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| disabledColor | Color? | resolveColorOrNull | ✅ |
| expandedColor | Color? | resolveColorOrNull | ✅ |

> **Note:** `semanticLabel` was incorrectly listed — Flutter's `ExpandIcon` widget doesn't expose this parameter.

#### TomIconButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| iconSize | double? | resolveDoubleOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |
| splashRadius | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| focusColor | Color? | resolveColorOrNull | ✅ |
| hoverColor | Color? | resolveColorOrNull | ✅ |
| highlightColor | Color? | resolveColorOrNull | ✅ |
| splashColor | Color? | resolveColorOrNull | ✅ |
| disabledColor | Color? | resolveColorOrNull | ✅ |
| constraints | BoxConstraints? | resolveBoxConstraints | ✅ |
| style | ButtonStyle? | resolveButtonStyle | ✅ |
| tooltip | String? | resolveResourceOrNull | ✅ |

#### TomMaterialButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| textColor | Color? | resolveColorOrNull | ✅ |
| disabledTextColor | Color? | resolveColorOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| disabledColor | Color? | resolveColorOrNull | ✅ |
| focusColor | Color? | resolveColorOrNull | ✅ |
| hoverColor | Color? | resolveColorOrNull | ✅ |
| highlightColor | Color? | resolveColorOrNull | ✅ |
| splashColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| focusElevation | double? | resolveDoubleOrNull | ✅ |
| hoverElevation | double? | resolveDoubleOrNull | ✅ |
| highlightElevation | double? | resolveDoubleOrNull | ✅ |
| disabledElevation | double? | resolveDoubleOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| minWidth | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |

#### TomMenuBar

No resource-loadable parameters.

#### TomMenuItemButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | resolveButtonStyle | ✅ |

#### TomRadioMenuButton

No resource-loadable parameters.

#### TomSegmentedButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | resolveButtonStyle | ✅ |

#### TomSnackBarAction

No resource-loadable parameters.

#### TomSubmenuButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignmentOffset | Offset? | resolveOffset | ✅ |
| style | ButtonStyle? | resolveButtonStyle | ✅ |

---

### Chips (`tom_chips.dart`)

#### TomFilterChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | resolveResourceOrNull | ✅ |
| labelStyle | TextStyle? | resolveTextStyle | ✅ |
| labelPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| showCheckmark | bool | resolveBoolOrNull | ✅ |
| checkmarkColor | Color? | resolveColorOrNull | ✅ |
| selectedColor | Color? | resolveColorOrNull | ✅ |
| disabledColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| selectedShadowColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| deleteIconColor | Color? | resolveColorOrNull | ✅ |
| shape | OutlinedBorder? | resolveShapeBorder | ✅ |
| side | BorderSide? | resolveBorderSide | ✅ |
| visualDensity | VisualDensity? | resolveVisualDensity | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| pressElevation | double? | resolveDoubleOrNull | ✅ |
| deleteButtonTooltipMessage | String? | resolveResourceOrNull | ✅ |

#### TomChoiceChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | resolveResourceOrNull | ✅ |
| labelStyle | TextStyle? | resolveTextStyle | ✅ |
| labelPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| selectedColor | Color? | resolveColorOrNull | ✅ |
| disabledColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| selectedShadowColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| shape | OutlinedBorder? | resolveShapeBorder | ✅ |
| side | BorderSide? | resolveBorderSide | ✅ |
| visualDensity | VisualDensity? | resolveVisualDensity | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| pressElevation | double? | resolveDoubleOrNull | ✅ |

#### TomActionChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | resolveResourceOrNull | ✅ |
| tooltip | String? | resolveResourceOrNull | ✅ |
| labelStyle | TextStyle? | resolveTextStyle | ✅ |
| labelPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| shape | OutlinedBorder? | resolveShapeBorder | ✅ |
| side | BorderSide? | resolveBorderSide | ✅ |
| visualDensity | VisualDensity? | resolveVisualDensity | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| pressElevation | double? | resolveDoubleOrNull | ✅ |

#### TomInputChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | resolveResourceOrNull | ✅ |
| tooltip | String? | resolveResourceOrNull | ✅ |
| labelStyle | TextStyle? | resolveTextStyle | ✅ |
| labelPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| deleteIconColor | Color? | resolveColorOrNull | ✅ |
| deleteButtonTooltipMessage | String? | resolveResourceOrNull | ✅ |
| showCheckmark | bool | resolveBoolOrNull | ✅ |
| checkmarkColor | Color? | resolveColorOrNull | ✅ |
| selectedColor | Color? | resolveColorOrNull | ✅ |
| disabledColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| selectedShadowColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| shape | OutlinedBorder? | resolveShapeBorder | ✅ |
| side | BorderSide? | resolveBorderSide | ✅ |
| visualDensity | VisualDensity? | resolveVisualDensity | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| pressElevation | double? | resolveDoubleOrNull | ✅ |


#### TomRawChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | resolveResourceOrNull | ✅ |
| labelStyle | TextStyle? | resolveTextStyle | ✅ |
| labelPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| deleteIconColor | Color? | resolveColorOrNull | ✅ |
| deleteButtonTooltipMessage | String? | resolveResourceOrNull | ✅ |
| pressElevation | double? | resolveDoubleOrNull | ✅ |
| checkmarkColor | Color? | resolveColorOrNull | ✅ |
| shape | OutlinedBorder? | resolveShapeBorder | ✅ |
| side | BorderSide? | resolveBorderSide | ✅ |
| selectedColor | Color? | resolveColorOrNull | ✅ |
| disabledColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| selectedShadowColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| visualDensity | VisualDensity? | resolveVisualDensity | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| tooltip | String? | resolveResourceOrNull | ✅ |

---

### Containers (`tom_containers.dart`)

#### TomCard

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| borderOnForeground | bool | resolveBoolOrNull | ✅ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| semanticContainer | bool | resolveBoolOrNull | ✅ |

#### TomExpansionTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ✅ |
| initiallyExpanded | bool | resolveBoolOrNull | ✅ |
| maintainState | bool | resolveBoolOrNull | ✅ |
| tilePadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| childrenPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| collapsedBackgroundColor | Color? | resolveColorOrNull | ✅ |
| textColor | Color? | resolveColorOrNull | ✅ |
| collapsedTextColor | Color? | resolveColorOrNull | ✅ |
| iconColor | Color? | resolveColorOrNull | ✅ |
| collapsedIconColor | Color? | resolveColorOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| collapsedShape | ShapeBorder? | resolveShapeBorder | ✅ |
| dense | bool | resolveBoolOrNull | ✅ |
| showTrailingIcon | bool | resolveBoolOrNull | ✅ |

#### TomScaffold

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| primary | bool | resolveBoolOrNull | ✅ |
| extendBody | bool | resolveBoolOrNull | ✅ |
| extendBodyBehindAppBar | bool | resolveBoolOrNull | ✅ |
| drawerScrimColor | Color? | resolveColorOrNull | ✅ |
| drawerEdgeDragWidth | double? | resolveDoubleOrNull | ✅ |
| drawerEnableOpenDragGesture | bool | resolveBoolOrNull | ✅ |
| endDrawerEnableOpenDragGesture | bool | resolveBoolOrNull | ✅ |
| restorationId | String? | resolveResourceOrNull | ✅ |

#### TomAppBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ✅ |
| automaticallyImplyLeading | bool | resolveBoolOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| scrolledUnderElevation | double? | resolveDoubleOrNull | ✅ |
| titleSpacing | double? | resolveDoubleOrNull | ✅ |
| toolbarHeight | double? | resolveDoubleOrNull | ✅ |
| leadingWidth | double? | resolveDoubleOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| foregroundColor | Color? | resolveColorOrNull | ✅ |
| iconTheme | IconThemeData? | resolveIconThemeData | ✅ |
| actionsIconTheme | IconThemeData? | resolveIconThemeData | ✅ |
| primary | bool | resolveBoolOrNull | ✅ |
| centerTitle | bool? | resolveBoolOrNull | ✅ |
| excludeHeaderSemantics | bool | resolveBoolOrNull | ✅ |
| toolbarOpacity | double | resolveDoubleOrNull | ✅ |
| bottomOpacity | double | resolveDoubleOrNull | ✅ |
| toolbarTextStyle | TextStyle? | resolveTextStyle | ✅ |
| titleTextStyle | TextStyle? | resolveTextStyle | ✅ |
| forceMaterialTransparency | bool | resolveBoolOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |

#### TomBottomAppBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |
| notchMargin | double | resolveDoubleOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |

#### TomDivider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| height | double? | resolveDoubleOrNull | ✅ |
| thickness | double? | resolveDoubleOrNull | ✅ |
| indent | double? | resolveDoubleOrNull | ✅ |
| endIndent | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |

#### TomContainer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| decoration | Decoration? | resolveDecoration | ✅ |
| foregroundDecoration | Decoration? | resolveDecoration | ✅ |
| constraints | BoxConstraints? | resolveBoxConstraints | ✅ |
| transformAlignment | AlignmentGeometry? | resolveAlignment | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |

#### TomColumn

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(no resource-loadable parameters with current resolvers)_ | | | |

#### TomRow

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(no resource-loadable parameters with current resolvers)_ | | | |

#### TomWrap

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| spacing | double? | resolveDoubleOrNull | ✅ |
| runSpacing | double? | resolveDoubleOrNull | ✅ |

#### TomStack

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | resolveAlignment | ✅ |


#### TomAlign

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| widthFactor | double? | resolveDoubleOrNull | ✅ |
| heightFactor | double? | resolveDoubleOrNull | ✅ |

#### TomAspectRatio

No resource-loadable parameters.

#### TomBaseline

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| baseline | double? | resolveDoubleOrFail | ✅ |

#### TomCarouselView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsets? | resolveEdgeInsetsOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| itemExtent | double? | resolveDoubleOrNull | ✅ |
| shrinkExtent | double? | resolveDoubleOrNull | ✅ |

#### TomCenter

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| widthFactor | double? | resolveDoubleOrNull | ✅ |
| heightFactor | double? | resolveDoubleOrNull | ✅ |

#### TomClipOval

No resource-loadable parameters.

#### TomClipPath

No resource-loadable parameters.

#### TomClipRRect

No resource-loadable parameters.

#### TomClipRSuperellipse

No resource-loadable parameters.

#### TomClipRect

No resource-loadable parameters.

#### TomColoredBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | resolveColorOrFail | ✅ |

#### TomConstrainedBox

No resource-loadable parameters.

#### TomConstraintsTransformBox

No resource-loadable parameters.

#### TomCupertinoExpansionTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrFail | ✅ |

#### TomCupertinoFormRow

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |

#### TomCupertinoFormSection

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |

#### TomCupertinoPageScaffold

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |

#### TomCupertinoScrollbar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| thumbVisibility | bool? | resolveBoolOrNull | ✅ |
| thickness | double? | resolveDoubleOrNull | ✅ |
| thicknessWhileDragging | double? | resolveDoubleOrNull | ✅ |

#### TomCupertinoTabScaffold

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |

#### TomCupertinoTabView

No resource-loadable parameters.

#### TomCustomMultiChildLayout

No resource-loadable parameters.

#### TomCustomPaint

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| isComplex | bool? | resolveBoolOrNull | ✅ |
| willChange | bool? | resolveBoolOrNull | ✅ |

#### TomCustomScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| cacheExtent | double? | resolveDoubleOrNull | ✅ |

#### TomCustomSingleChildLayout

No resource-loadable parameters.

#### TomDecoratedBox

No resource-loadable parameters.

#### TomDraggableScrollableSheet

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| initialChildSize | double? | resolveDoubleOrNull | ✅ |
| minChildSize | double? | resolveDoubleOrNull | ✅ |
| maxChildSize | double? | resolveDoubleOrNull | ✅ |
| expand | bool? | resolveBoolOrNull | ✅ |
| snap | bool? | resolveBoolOrNull | ✅ |
| shouldCloseOnMinExtent | bool? | resolveBoolOrNull | ✅ |

#### TomExpanded

No resource-loadable parameters.

#### TomExpansionPanel

No resource-loadable parameters.

#### TomExpansionPanelList

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| dividerColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| expandedHeaderPadding | EdgeInsets? | resolveEdgeInsetsOrNull | ✅ |

#### TomFittedBox

No resource-loadable parameters.

#### TomFlexible

No resource-loadable parameters.

#### TomFlow

No resource-loadable parameters.

#### TomFractionalTranslation

No resource-loadable parameters.

#### TomFractionallySizedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| widthFactor | double? | resolveDoubleOrNull | ✅ |
| heightFactor | double? | resolveDoubleOrNull | ✅ |

#### TomGridTile

No resource-loadable parameters.

#### TomGridTileBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |

#### TomIndexedStack

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| index | int? | resolveIntOrNull | ✅ |
| alignment | AlignmentGeometry | resolveAlignment | ✅ |

#### TomInk

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| decoration | Decoration? | resolveDecoration | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |

#### TomInteractiveViewer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| boundaryMargin | EdgeInsets? | resolveEdgeInsetsOrNull | ✅ |
| constrained | bool? | resolveBoolOrNull | ✅ |
| maxScale | double? | resolveDoubleOrNull | ✅ |
| minScale | double? | resolveDoubleOrNull | ✅ |
| interactionEndFrictionCoefficient | double? | resolveDoubleOrNull | ✅ |
| panEnabled | bool? | resolveBoolOrNull | ✅ |
| scaleEnabled | bool? | resolveBoolOrNull | ✅ |
| scaleFactor | double? | resolveDoubleOrNull | ✅ |
| alignment | Alignment? | resolveAlignment | ✅ |

#### TomIntrinsicHeight

No resource-loadable parameters.

#### TomIntrinsicWidth

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| stepWidth | double? | resolveDoubleOrNull | ✅ |
| stepHeight | double? | resolveDoubleOrNull | ✅ |

#### TomLimitedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| maxWidth | double? | resolveDoubleOrNull | ✅ |
| maxHeight | double? | resolveDoubleOrNull | ✅ |

#### TomListBody

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| reverse | bool? | resolveBoolOrNull | ✅ |

#### TomMaterial

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| textStyle | TextStyle? | resolveTextStyle | ✅ |
| borderRadius | BorderRadiusGeometry? | resolveBorderRadius | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |

#### TomNestedScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| physics | ScrollPhysics? | resolveScrollPhysics | ✅ |
| floatHeaderSlivers | bool? | resolveBoolOrNull | ✅ |
| restorationId | String? | resolveResourceOrNull | ✅ |

#### TomOffstage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| offstage | bool | resolveBoolOrNull | ✅ |

#### TomOpacity

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opacity | double? | resolveDoubleOrNull | ✅ |

#### TomOverflowBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| spacing | double? | resolveDoubleOrNull | ✅ |
| overflowSpacing | double? | resolveDoubleOrNull | ✅ |

#### TomOverflowBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | resolveAlignment | ✅ |
| minWidth | double? | resolveDoubleOrNull | ✅ |
| maxWidth | double? | resolveDoubleOrNull | ✅ |
| minHeight | double? | resolveDoubleOrNull | ✅ |
| maxHeight | double? | resolveDoubleOrNull | ✅ |

#### TomPadding

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry | resolveEdgeInsetsOrNull | ✅ |

#### TomPhysicalModel

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| borderRadius | BorderRadius? | resolveBorderRadius | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |

#### TomPhysicalShape

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |

#### TomPositioned

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| left | double? | resolveDoubleOrNull | ✅ |
| top | double? | resolveDoubleOrNull | ✅ |
| right | double? | resolveDoubleOrNull | ✅ |
| bottom | double? | resolveDoubleOrNull | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |

#### TomPositionedDirectional

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| start | double? | resolveDoubleOrNull | ✅ |
| top | double? | resolveDoubleOrNull | ✅ |
| end | double? | resolveDoubleOrNull | ✅ |
| bottom | double? | resolveDoubleOrNull | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |

#### TomRotatedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| quarterTurns | int? | resolveIntOrNull | ✅ |

#### TomSafeArea

No resource-loadable parameters.

#### TomScrollbar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| thumbVisibility | bool? | resolveBoolOrNull | ✅ |
| trackVisibility | bool? | resolveBoolOrNull | ✅ |
| thickness | double? | resolveDoubleOrNull | ✅ |
| interactive | bool? | resolveBoolOrNull | ✅ |

#### TomSingleChildScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| physics | ScrollPhysics? | resolveScrollPhysics | ✅ |
| restorationId | String? | resolveResourceOrNull | ✅ |

#### TomSizedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |

#### TomSizedOverflowBox

No resource-loadable parameters.

#### TomSliverAppBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| scrolledUnderElevation | double? | resolveDoubleOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| foregroundColor | Color? | resolveColorOrNull | ✅ |
| iconTheme | IconThemeData? | resolveIconThemeData | ✅ |
| actionsIconTheme | IconThemeData? | resolveIconThemeData | ✅ |
| titleSpacing | double? | resolveDoubleOrNull | ✅ |
| expandedHeight | double? | resolveDoubleOrNull | ✅ |
| collapsedHeight | double? | resolveDoubleOrNull | ✅ |
| leadingWidth | double? | resolveDoubleOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| toolbarTextStyle | TextStyle? | resolveTextStyle | ✅ |
| titleTextStyle | TextStyle? | resolveTextStyle | ✅ |

#### TomSliverFillRemaining

No resource-loadable parameters.

#### TomSliverGrid

No resource-loadable parameters.

#### TomSliverList

No resource-loadable parameters.

#### TomSliverToBoxAdapter

No resource-loadable parameters.

#### TomSpacer

No resource-loadable parameters.

#### TomTableCell

No resource-loadable parameters.

#### TomTransform

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |
| transformHitTests | bool? | resolveBoolOrNull | ✅ |

#### TomUnconstrainedBox

No resource-loadable parameters.

#### TomVisibility

No resource-loadable parameters.

---

### ACL Container (`acl/tom_acl.dart`)

#### TomAclBuilder

> **Note:** TomAclBuilder is a builder class, not a standard Tom widget. It uses `TomUIResources.resolveText()` directly instead of `TomNodeBase` resolvers, and constructor parameters are passed to the internal `AclBuilder` before `build()` is called. These params cannot use the standard resource resolution pattern.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| title | String? | resolveResourceOrNull | ⛔ |
| padding | EdgeInsetsGeometry | resolveEdgeInsetsOrNull | ⛔ |
| backgroundColor | Color? | resolveColorOrNull | ⛔ |
| titleStyle | TextStyle? | resolveTextStyle | ⛔ |
| titleVerticalOffset | double | resolveDoubleOrNull | ⛔ |

---

### Dialogs (`tom_dialogs.dart`)

#### TomAlertDialog

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| iconPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| iconColor | Color? | resolveColorOrNull | ✅ |
| titleText | String? | resolveResourceOrNull | ✅ |
| titlePadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| titleTextStyle | TextStyle? | resolveTextStyle | ✅ |
| contentPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| contentTextStyle | TextStyle? | resolveTextStyle | ✅ |
| actionsPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| actionsOverflowButtonSpacing | double? | resolveDoubleOrNull | ✅ |
| buttonPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| semanticLabel | String? | resolveResourceOrNull | ✅ |
| insetPadding | EdgeInsets | resolveEdgeInsetsOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |
| scrollable | bool | resolveBoolOrNull | ✅ |

#### TomSimpleDialog

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ✅ |
| titlePadding | EdgeInsets | resolveEdgeInsetsOrNull | ✅ |
| titleTextStyle | TextStyle? | resolveTextStyle | ✅ |
| contentPadding | EdgeInsets | resolveEdgeInsetsOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| semanticLabel | String? | resolveResourceOrNull | ✅ |
| insetPadding | EdgeInsets? | resolveEdgeInsetsOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |

#### TomDialog

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| insetPadding | EdgeInsets? | resolveEdgeInsetsOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |

#### TomBottomSheet

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| constraints | BoxConstraints? | resolveBoxConstraints | ✅ |
| enableDrag | bool | resolveBoolOrNull | ✅ |
| showDragHandle | bool? | resolveBoolOrNull | ✅ |

#### TomSnackBar

> **Note:** TomSnackBar extends SnackBar directly with `super.` parameters and uses `TomWidgetMixin`, not `TomDialogBase`. It has no `buildContent()` method — params are passed via the super constructor. These params cannot use the standard resource resolution pattern.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⛔ |
| elevation | double? | resolveDoubleOrNull | ⛔ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⛔ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⛔ |
| width | double? | resolveDoubleOrNull | ⛔ |
| shape | ShapeBorder? | resolveShapeBorder | ⛔ |
| showCloseIcon | bool? | resolveBoolOrNull | ⛔ |
| closeIconColor | Color? | resolveColorOrNull | ⛔ |
| actionOverflowThreshold | double? | resolveDoubleOrNull | ⛔ |

#### TomMaterialBanner

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| contentTextStyle | TextStyle? | resolveTextStyle | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| dividerColor | Color? | resolveColorOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| leadingPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| forceActionsBelow | bool | resolveBoolOrNull | ✅ |


#### TomAboutDialog

No resource-loadable parameters.

#### TomCupertinoActionSheet

No resource-loadable parameters.

#### TomCupertinoAlertDialog

No resource-loadable parameters.

#### TomCupertinoContextMenu

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| enableHapticFeedback | bool? | resolveBoolOrNull | ✅ |

#### TomDatePickerDialog

No resource-loadable parameters.

#### TomDateRangePickerDialog

No resource-loadable parameters.

#### TomLicensePage

No resource-loadable parameters.

#### TomModalBottomSheet

> **Note:** TomModalBottomSheet is a configuration holder whose `buildContent()` delegates directly to the builder callback. Params are used imperatively via `TomDialogs.showModalBottomSheet()`. These params cannot use the standard resource resolution pattern.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⛔ |
| elevation | double? | resolveDoubleOrNull | ⛔ |
| shape | ShapeBorder? | resolveShapeBorder | ⛔ |
| constraints | BoxConstraints? | resolveBoxConstraints | ⛔ |

#### TomSimpleDialogOption

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsets? | resolveEdgeInsetsOrNull | ✅ |

#### TomTimePickerDialog

No resource-loadable parameters.

#### TomTooltip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| height | double? | resolveDoubleOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| verticalOffset | double? | resolveDoubleOrNull | ✅ |
| decoration | Decoration? | resolveDecoration | ✅ |
| textStyle | TextStyle? | resolveTextStyle | ✅ |

---

### Effects (`tom_effects.dart`)

#### TomBackdropFilter

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(no params with current resolvers — filter is ImageFilter)_ | | | |

#### TomColorFiltered

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(no params with current resolvers — colorFilter is ColorFilter)_ | | | |

#### TomShaderMask

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(no params with current resolvers — shaderCallback is a callback)_ | | | |

#### TomSelectableRegion

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(no resource-loadable parameters)_ | | | |

#### TomSelectionArea

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(no resource-loadable parameters)_ | | | |

#### TomSensitiveContent

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(sensitivity is an enum — no generic enum resolver)_ | | | |

---

### Images (`tom_images.dart`)

#### TomIcon

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| size | double? | resolveDoubleOrNull | ✅ |
| fill | double? | resolveDoubleOrNull | ✅ |
| weight | double? | resolveDoubleOrNull | ✅ |
| grade | double? | resolveDoubleOrNull | ✅ |
| opticalSize | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| semanticLabel | String? | resolveResourceOrNull | ✅ |

#### TomImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| alignment | AlignmentGeometry | resolveAlignment | ✅ |
| matchTextDirection | bool | resolveBoolOrNull | ✅ |
| gaplessPlayback | bool | resolveBoolOrNull | ✅ |
| isAntiAlias | bool | resolveBoolOrNull | ✅ |
| semanticLabel | String? | resolveResourceOrNull | ✅ |

#### TomCircleAvatar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| foregroundColor | Color? | resolveColorOrNull | ✅ |
| radius | double? | resolveDoubleOrNull | ✅ |
| minRadius | double? | resolveDoubleOrNull | ✅ |
| maxRadius | double? | resolveDoubleOrNull | ✅ |

#### TomFadeInImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |
| alignment | AlignmentGeometry | resolveAlignment | ✅ |
| matchTextDirection | bool | resolveBoolOrNull | ✅ |
| excludeFromSemantics | bool | resolveBoolOrNull | ✅ |
| imageSemanticLabel | String? | resolveResourceOrNull | ✅ |
| placeholderColor | Color? | resolveColorOrNull | ✅ |

#### TomImageIcon

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| size | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| semanticLabel | String? | resolveResourceOrNull | ✅ |

#### TomInkImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| alignment | AlignmentGeometry | resolveAlignment | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |

#### TomNetworkImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| src | String | resolveResource | ✅ |
| scale | double | resolveDoubleOrNull | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |
| alignment | AlignmentGeometry | resolveAlignment | ✅ |
| matchTextDirection | bool | resolveBoolOrNull | ✅ |
| gaplessPlayback | bool | resolveBoolOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| semanticLabel | String? | resolveResourceOrNull | ✅ |
| excludeFromSemantics | bool | resolveBoolOrNull | ✅ |


#### TomAnimatedIcon

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | resolveColorOrNull | ✅ |
| size | double? | resolveDoubleOrNull | ✅ |
| semanticLabel | String? | resolveResourceOrNull | ✅ |

#### TomAssetImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |
| cacheWidth | int? | resolveIntOrNull | ✅ |
| cacheHeight | int? | resolveIntOrNull | ✅ |

#### TomFileImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | resolveDoubleOrNull | ✅ |
| height | double? | resolveDoubleOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |

#### TomImageFiltered

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| enabled | bool? | resolveBoolOrNull | ✅ |

---

### Inputs (`tom_inputs.dart`)

#### TomTextField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | InputDecoration? | resolveInputDecoration | ✅ |
| style | TextStyle? | resolveTextStyle | ✅ |
| strutStyle | StrutStyle? | resolveStrutStyle | ✅ |
| autofocus | bool | resolveBoolOrNull | ✅ |
| obscureText | bool | resolveBoolOrNull | ✅ |
| autocorrect | bool | resolveBoolOrNull | ✅ |
| enableSuggestions | bool | resolveBoolOrNull | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| minLines | int? | resolveIntOrNull | ✅ |
| expands | bool | resolveBoolOrNull | ✅ |
| maxLength | int? | resolveIntOrNull | ✅ |
| enabled | bool | resolveBoolOrNull | ✅ |
| readOnly | bool | resolveBoolOrNull | ✅ |
| showCursor | bool? | resolveBoolOrNull | ✅ |
| obscuringCharacter | String? | resolveResourceOrNull | ✅ |
| cursorWidth | double? | resolveDoubleOrNull | ✅ |
| cursorHeight | double? | resolveDoubleOrNull | ✅ |
| cursorColor | Color? | resolveColorOrNull | ✅ |
| cursorErrorColor | Color? | resolveColorOrNull | ✅ |
| scrollPadding | EdgeInsets | resolveEdgeInsetsOrNull | ✅ |
| enableInteractiveSelection | bool? | resolveBoolOrNull | ✅ |
| restorationId | String? | resolveResourceOrNull | ✅ |
| scribbleEnabled | bool | resolveBoolOrNull | ✅ |
| enableIMEPersonalizedLearning | bool | resolveBoolOrNull | ✅ |
| canRequestFocus | bool | resolveBoolOrNull | ✅ |
| label | String? | resolveResourceOrNull | ✅ |
| hint | String? | resolveResourceOrNull | ✅ |

#### TomTextFormField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | InputDecoration? | resolveInputDecoration | ✅ |
| style | TextStyle? | resolveTextStyle | ✅ |
| autofocus | bool | resolveBoolOrNull | ✅ |
| obscureText | bool | resolveBoolOrNull | ✅ |
| autocorrect | bool | resolveBoolOrNull | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| minLines | int? | resolveIntOrNull | ✅ |
| maxLength | int? | resolveIntOrNull | ✅ |
| initialValue | String? | resolveResourceOrNull | ✅ |
| enabled | bool | resolveBoolOrNull | ✅ |
| readOnly | bool | resolveBoolOrNull | ✅ |
| label | String? | resolveResourceOrNull | ✅ |
| hint | String? | resolveResourceOrNull | ✅ |

#### TomSearchBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| hintText | String? | resolveResourceOrNull | ✅ |
| constraints | BoxConstraints? | resolveBoxConstraints | ✅ |
| autoFocus | bool | resolveBoolOrNull | ✅ |

> **Note:** TomSearchBar uses `WidgetStateProperty<X>` for elevation, backgroundColor, surfaceTintColor, textStyle, etc. These are state-dependent wrappers and cannot be directly resource-resolved with current resolvers.


#### TomAutocomplete

No resource-loadable parameters.

#### TomCalendarDatePicker

No resource-loadable parameters.

#### TomCupertinoDatePicker

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| itemExtent | double? | resolveDoubleOrNull | ✅ |

#### TomCupertinoSearchTextField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| placeholder | String? | resolveResourceOrNull | ✅ |
| style | TextStyle? | resolveTextStyle | ✅ |
| placeholderStyle | TextStyle? | resolveTextStyle | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| borderRadius | BorderRadius? | resolveBorderRadius | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| itemColor | Color? | resolveColorOrNull | ✅ |
| itemSize | double? | resolveDoubleOrNull | ✅ |

#### TomCupertinoTextField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| placeholder | String? | resolveResourceOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| minLines | int? | resolveIntOrNull | ✅ |
| maxLength | int? | resolveIntOrNull | ✅ |
| style | TextStyle? | resolveTextStyle | ✅ |
| placeholderStyle | TextStyle? | resolveTextStyle | ✅ |

#### TomCupertinoTextFormFieldRow

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| placeholder | String? | resolveResourceOrNull | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| cursorWidth | double? | resolveDoubleOrNull | ✅ |
| cursorHeight | double? | resolveDoubleOrNull | ✅ |
| cursorColor | Color? | resolveColorOrNull | ✅ |
| scrollPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |

#### TomCupertinoTimerPicker

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| itemExtent | double? | resolveDoubleOrNull | ✅ |

#### TomDropdownMenuFormField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| label | String? | resolveResourceOrNull | ✅ |
| hintText | String? | resolveResourceOrNull | ✅ |
| helperText | String? | resolveResourceOrNull | ✅ |
| width | double? | resolveDoubleOrNull | ✅ |
| menuHeight | double? | resolveDoubleOrNull | ✅ |
| expandedInsets | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| textStyle | TextStyle? | resolveTextStyle | ✅ |

#### TomEditableText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundCursorColor | Color? | resolveColorOrNull | ✅ |
| selectionColor | Color? | resolveColorOrNull | ✅ |
| cursorHeight | double? | resolveDoubleOrNull | ✅ |
| cursorWidth | double? | resolveDoubleOrNull | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| minLines | int? | resolveIntOrNull | ✅ |

#### TomForm

No resource-loadable parameters.

#### TomInputDatePickerFormField

No resource-loadable parameters.

#### TomSearchAnchor

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| viewHintText | String? | resolveResourceOrNull | ✅ |
| viewBackgroundColor | Color? | resolveColorOrNull | ✅ |
| viewElevation | double? | resolveDoubleOrNull | ✅ |
| viewSurfaceTintColor | Color? | resolveColorOrNull | ✅ |
| dividerColor | Color? | resolveColorOrNull | ✅ |
| headerTextStyle | TextStyle? | resolveTextStyle | ✅ |
| headerHintStyle | TextStyle? | resolveTextStyle | ✅ |

#### TomYearPicker

No resource-loadable parameters.

---

### Interactions (`tom_interactions.dart`)

#### TomGestureDetector

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| excludeFromSemantics | bool? | resolveBoolOrNull | ✅ |
| trackpadScrollCausesScale | bool? | resolveBoolOrNull | ✅ |
| trackpadScrollToScaleFactor | Offset | resolveOffset | ✅ |

#### TomInkWell

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| focusColor | Color? | resolveColorOrNull | ✅ |
| hoverColor | Color? | resolveColorOrNull | ✅ |
| highlightColor | Color? | resolveColorOrNull | ✅ |
| splashColor | Color? | resolveColorOrNull | ✅ |
| radius | double? | resolveDoubleOrNull | ✅ |
| borderRadius | BorderRadius? | resolveBorderRadius | ✅ |
| customBorder | ShapeBorder? | resolveShapeBorder | ✅ |
| enableFeedback | bool? | resolveBoolOrNull | ✅ |
| excludeFromSemantics | bool | resolveBoolOrNull | ✅ |
| canRequestFocus | bool | resolveBoolOrNull | ✅ |
| autofocus | bool | resolveBoolOrNull | ✅ |

#### TomInkResponse

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| containedInkWell | bool? | resolveBoolOrNull | ✅ |
| radius | double? | resolveDoubleOrNull | ✅ |
| borderRadius | BorderRadius? | resolveBorderRadius | ✅ |
| customBorder | ShapeBorder? | resolveShapeBorder | ✅ |
| focusColor | Color? | resolveColorOrNull | ✅ |
| hoverColor | Color? | resolveColorOrNull | ✅ |
| highlightColor | Color? | resolveColorOrNull | ✅ |
| splashColor | Color? | resolveColorOrNull | ✅ |
| enableFeedback | bool? | resolveBoolOrNull | ✅ |
| excludeFromSemantics | bool? | resolveBoolOrNull | ✅ |
| autofocus | bool? | resolveBoolOrNull | ✅ |
| canRequestFocus | bool? | resolveBoolOrNull | ✅ |

#### TomDraggable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| feedbackOffset | Offset | resolveOffset | ✅ |
| maxSimultaneousDrags | int? | resolveIntOrNull | ✅ |
| ignoringFeedbackSemantics | bool? | resolveBoolOrNull | ✅ |
| ignoringFeedbackPointer | bool? | resolveBoolOrNull | ✅ |
| rootOverlay | bool? | resolveBoolOrNull | ✅ |


#### TomAbsorbPointer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| absorbing | bool? | resolveBoolOrNull | ✅ |

#### TomCupertinoMagnifier

No resource-loadable parameters.

#### TomDragTarget

No resource-loadable parameters.

#### TomIgnorePointer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| ignoring | bool? | resolveBoolOrNull | ✅ |

#### TomLongPressDraggable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| maxSimultaneousDrags | int? | resolveIntOrNull | ✅ |
| hapticFeedbackOnStart | bool? | resolveBoolOrNull | ✅ |
| ignoringFeedbackSemantics | bool? | resolveBoolOrNull | ✅ |
| ignoringFeedbackPointer | bool? | resolveBoolOrNull | ✅ |

#### TomMouseRegion

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opaque | bool? | resolveBoolOrNull | ✅ |

---

### Labels (`tom_labels.dart`)

#### TomText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| data | String? | resolveResourceOrNull | ✅ |
| text | String? | resolveResourceOrNull | ✅ |
| style | TextStyle? | resolveTextStyle | ✅ |
| strutStyle | StrutStyle? | resolveStrutStyle | ✅ |
| softWrap | bool? | resolveBoolOrNull | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| semanticsLabel | String? | resolveResourceOrNull | ✅ |
| textHeightBehavior | TextHeightBehavior? | resolveTextHeightBehavior | ✅ |

#### TomSelectableText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| data | String? | resolveResourceOrNull | ✅ |
| text | String? | resolveResourceOrNull | ✅ |
| style | TextStyle? | resolveTextStyle | ✅ |
| strutStyle | StrutStyle? | resolveStrutStyle | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| minLines | int? | resolveIntOrNull | ✅ |
| autofocus | bool | resolveBoolOrNull | ✅ |
| showCursor | bool | resolveBoolOrNull | ✅ |
| cursorWidth | double | resolveDoubleOrNull | ✅ |
| cursorHeight | double? | resolveDoubleOrNull | ✅ |
| cursorColor | Color? | resolveColorOrNull | ✅ |
| semanticsLabel | String? | resolveResourceOrNull | ✅ |
| textHeightBehavior | TextHeightBehavior? | resolveTextHeightBehavior | ✅ |

#### TomRichText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| softWrap | bool | resolveBoolOrNull | ✅ |
| maxLines | int? | resolveIntOrNull | ✅ |
| strutStyle | StrutStyle? | resolveStrutStyle | ✅ |
| textHeightBehavior | TextHeightBehavior? | resolveTextHeightBehavior | ✅ |
| selectionColor | Color? | resolveColorOrNull | ✅ |

#### TomBadge

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | resolveResourceOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| textColor | Color? | resolveColorOrNull | ✅ |
| textStyle | TextStyle? | resolveTextStyle | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| alignment | AlignmentGeometry? | resolveAlignment | ✅ |
| offset | Offset? | resolveOffset | ✅ |
| isLabelVisible | bool | resolveBoolOrNull | ✅ |
| smallSize | double? | resolveDoubleOrNull | ✅ |
| largeSize | double? | resolveDoubleOrNull | ✅ |

#### TomListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ✅ |
| isThreeLine | bool | resolveBoolOrNull | ✅ |
| dense | bool? | resolveBoolOrNull | ✅ |
| visualDensity | VisualDensity? | resolveVisualDensity | ✅ |
| shape | ShapeBorder? | resolveShapeBorder | ✅ |
| selectedColor | Color? | resolveColorOrNull | ✅ |
| iconColor | Color? | resolveColorOrNull | ✅ |
| textColor | Color? | resolveColorOrNull | ✅ |
| focusColor | Color? | resolveColorOrNull | ✅ |
| hoverColor | Color? | resolveColorOrNull | ✅ |
| splashColor | Color? | resolveColorOrNull | ✅ |
| tileColor | Color? | resolveColorOrNull | ✅ |
| selectedTileColor | Color? | resolveColorOrNull | ✅ |
| titleTextStyle | TextStyle? | resolveTextStyle | ✅ |
| subtitleTextStyle | TextStyle? | resolveTextStyle | ✅ |
| leadingAndTrailingTextStyle | TextStyle? | resolveTextStyle | ✅ |
| contentPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ✅ |
| enabled | bool | resolveBoolOrNull | ✅ |
| selected | bool | resolveBoolOrNull | ✅ |
| autofocus | bool | resolveBoolOrNull | ✅ |
| enableFeedback | bool? | resolveBoolOrNull | ✅ |
| horizontalTitleGap | double? | resolveDoubleOrNull | ✅ |
| minVerticalPadding | double? | resolveDoubleOrNull | ✅ |
| minLeadingWidth | double? | resolveDoubleOrNull | ✅ |
| minTileHeight | double? | resolveDoubleOrNull | ✅ |


#### TomAboutListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| applicationName | String? | resolveResourceOrNull | ✅ |
| applicationVersion | String? | resolveResourceOrNull | ✅ |
| applicationLegalese | String? | resolveResourceOrNull | ✅ |

#### TomBanner

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| message | String? | resolveResourceOrNull | ✅ |
| color | Color? | resolveColorOrNull | ✅ |

#### TomChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | resolveResourceOrNull | ✅ |
| deleteIconColor | Color? | resolveColorOrNull | ✅ |
| backgroundColor | Color? | resolveColorOrNull | ✅ |
| shadowColor | Color? | resolveColorOrNull | ✅ |
| surfaceTintColor | Color? | resolveColorOrNull | ✅ |
| elevation | double? | resolveDoubleOrNull | ✅ |
| labelStyle | TextStyle? | resolveTextStyle | ✅ |

#### TomDefaultTextStyle

No resource-loadable parameters.

#### TomListTileTitle

No resource-loadable parameters.

#### TomListTileSubtitle

No resource-loadable parameters.

#### TomMenuAcceleratorLabel

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| label | String? | resolveResourceOrNull | ⬜ |

#### TomMergeSemantics

No resource-loadable parameters.

#### TomSemantics

No resource-loadable parameters.

#### TomVerticalDivider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | resolveDoubleOrNull | ⬜ |
| thickness | double? | resolveDoubleOrNull | ⬜ |
| indent | double? | resolveDoubleOrNull | ⬜ |
| endIndent | double? | resolveDoubleOrNull | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |

---

### Lists (`tom_lists.dart`)

#### TomListView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| reverse | bool | resolveBoolOrNull | ⬜ |
| primary | bool? | resolveBoolOrNull | ⬜ |
| shrinkWrap | bool | resolveBoolOrNull | ⬜ |
| physics | ScrollPhysics? | resolveScrollPhysics | ✅ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| itemExtent | double? | resolveDoubleOrNull | ⬜ |
| cacheExtent | double? | resolveDoubleOrNull | ⬜ |
| semanticChildCount | int? | resolveIntOrNull | ⬜ |
| restorationId | String? | resolveResourceOrNull | ⬜ |
| addAutomaticKeepAlives | bool | resolveBoolOrNull | ⬜ |
| addRepaintBoundaries | bool | resolveBoolOrNull | ⬜ |
| addSemanticIndexes | bool | resolveBoolOrNull | ⬜ |

#### TomAnimatedList

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| initialItemCount | int | resolveIntOrNull | ⬜ |
| reverse | bool | resolveBoolOrNull | ⬜ |
| primary | bool? | resolveBoolOrNull | ⬜ |
| shrinkWrap | bool | resolveBoolOrNull | ⬜ |
| physics | ScrollPhysics? | resolveScrollPhysics | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomDismissible

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| crossAxisEndOffset | double? | resolveDoubleOrNull | ⬜ |

#### TomListWheelScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| diameterRatio | double? | resolveDoubleOrNull | ⬜ |
| perspective | double? | resolveDoubleOrNull | ⬜ |
| offAxisFraction | double? | resolveDoubleOrNull | ⬜ |
| useMagnifier | bool | resolveBoolOrNull | ⬜ |
| magnification | double? | resolveDoubleOrNull | ⬜ |
| overAndUnderCenterOpacity | double? | resolveDoubleOrNull | ⬜ |
| itemExtent | double? | resolveDoubleOrNull | ⬜ |
| squeeze | double? | resolveDoubleOrNull | ⬜ |
| renderChildrenOutsideViewport | bool | resolveBoolOrNull | ⬜ |
| restorationId | String? | resolveResourceOrNull | ⬜ |

#### TomCupertinoListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| leadingSize | double? | resolveDoubleOrNull | ⬜ |
| leadingToTitle | double? | resolveDoubleOrNull | ⬜ |


#### TomCupertinoListSection

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| topMargin | double? | resolveDoubleOrNull | ⬜ |
| hasLeading | bool? | resolveBoolOrNull | ⬜ |
| additionalDividerMargin | double? | resolveDoubleOrNull | ⬜ |

---

### Navigation (`tom_navigation.dart`)

#### TomNavigationRail

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| selectedIndex | int? | resolveIntOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| elevation | double? | resolveDoubleOrNull | ⬜ |
| minWidth | double? | resolveDoubleOrNull | ⬜ |
| minExtendedWidth | double? | resolveDoubleOrNull | ⬜ |
| indicatorColor | Color? | resolveColorOrNull | ⬜ |
| indicatorShape | ShapeBorder? | resolveShapeBorder | ✅ |
| useIndicator | bool? | resolveBoolOrNull | ⬜ |
| groupAlignment | double? | resolveDoubleOrNull | ⬜ |
| selectedLabelTextStyle | TextStyle? | resolveTextStyle | ⬜ |
| unselectedLabelTextStyle | TextStyle? | resolveTextStyle | ⬜ |
| selectedIconTheme | IconThemeData? | resolveIconThemeData | ✅ |
| unselectedIconTheme | IconThemeData? | resolveIconThemeData | ✅ |
| extended | bool | resolveBoolOrNull | ⬜ |

#### TomNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| selectedIndex | int | resolveIntOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| indicatorColor | Color? | resolveColorOrNull | ⬜ |
| indicatorShape | ShapeBorder? | resolveShapeBorder | ✅ |
| elevation | double? | resolveDoubleOrNull | ⬜ |
| shadowColor | Color? | resolveColorOrNull | ⬜ |
| surfaceTintColor | Color? | resolveColorOrNull | ⬜ |
| height | double? | resolveDoubleOrNull | ⬜ |

> **Note:** TomNavigationBar uses `WidgetStateProperty<TextStyle?>` for labelTextStyle and `WidgetStateProperty<IconThemeData?>` for iconTheme — these cannot be directly resource-resolved.

#### TomTabBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| isScrollable | bool | resolveBoolOrNull | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| indicatorColor | Color? | resolveColorOrNull | ⬜ |
| indicatorWeight | double? | resolveDoubleOrNull | ⬜ |
| indicatorPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| indicator | Decoration? | resolveDecoration | ⬜ |
| dividerColor | Color? | resolveColorOrNull | ⬜ |
| dividerHeight | double? | resolveDoubleOrNull | ⬜ |
| labelColor | Color? | resolveColorOrNull | ⬜ |
| unselectedLabelColor | Color? | resolveColorOrNull | ⬜ |
| labelStyle | TextStyle? | resolveTextStyle | ⬜ |
| unselectedLabelStyle | TextStyle? | resolveTextStyle | ⬜ |
| labelPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| automaticIndicatorColorAdjustment | bool | resolveBoolOrNull | ⬜ |
| splashBorderRadius | BorderRadius? | resolveBorderRadius | ⬜ |

#### TomNavigationDrawer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| selectedIndex | int? | resolveIntOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| shadowColor | Color? | resolveColorOrNull | ⬜ |
| surfaceTintColor | Color? | resolveColorOrNull | ⬜ |
| elevation | double? | resolveDoubleOrNull | ⬜ |
| indicatorColor | Color? | resolveColorOrNull | ⬜ |
| indicatorShape | ShapeBorder? | resolveShapeBorder | ⬜ |
| tilePadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomDrawer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| shadowColor | Color? | resolveColorOrNull | ⬜ |
| surfaceTintColor | Color? | resolveColorOrNull | ⬜ |
| elevation | double? | resolveDoubleOrNull | ⬜ |
| shape | ShapeBorder? | resolveShapeBorder | ⬜ |
| width | double? | resolveDoubleOrNull | ⬜ |
| semanticLabel | String? | resolveResourceOrNull | ⬜ |

#### TomBottomNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| currentIndex | int | resolveIntOrNull | ⬜ |
| elevation | double? | resolveDoubleOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| iconSize | double? | resolveDoubleOrNull | ⬜ |
| selectedItemColor | Color? | resolveColorOrNull | ⬜ |
| unselectedItemColor | Color? | resolveColorOrNull | ⬜ |
| selectedIconTheme | IconThemeData? | resolveIconThemeData | ⬜ |
| unselectedIconTheme | IconThemeData? | resolveIconThemeData | ⬜ |


#### TomBreadcrumb

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomCupertinoNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⬜ |

#### TomCupertinoNavigationBarBackButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| previousPageTitle | String? | resolveResourceOrNull | ⬜ |

#### TomCupertinoSliverNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| previousPageTitle | String? | resolveResourceOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |

#### TomCupertinoTabBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| activeColor | Color? | resolveColorOrNull | ⬜ |
| iconSize | double? | resolveDoubleOrNull | ⬜ |
| height | double? | resolveDoubleOrNull | ⬜ |

#### TomDrawerHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| margin | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomFlexibleSpaceBar

No resource-loadable parameters.

#### TomNavigationDestination

No resource-loadable parameters.

#### TomNavigationDrawerDestination

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⬜ |

#### TomPageView

No resource-loadable parameters.

#### TomStepper

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| physics | ScrollPhysics? | resolveScrollPhysics | ⬜ |
| elevation | double? | resolveDoubleOrNull | ⬜ |
| connectorThickness | double? | resolveDoubleOrNull | ⬜ |
| connectorColor | Color? | resolveColorOrNull | ⬜ |

#### TomTab

No resource-loadable parameters.

#### TomTabBarView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| viewportFraction | double? | resolveDoubleOrNull | ⬜ |

#### TomTabPageSelector

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| indicatorSize | double? | resolveDoubleOrNull | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |
| selectedColor | Color? | resolveColorOrNull | ⬜ |

#### TomUserAccountsDrawerHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| arrowColor | Color? | resolveColorOrNull | ⬜ |

---

### Progress (`tom_progress.dart`)

#### TomCircularProgressIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| value | double? | resolveDoubleOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |
| strokeWidth | double? | resolveDoubleOrNull | ⬜ |
| strokeAlign | double | resolveDoubleOrNull | ⬜ |
| semanticsLabel | String? | resolveResourceOrNull | ⬜ |
| semanticsValue | String? | resolveResourceOrNull | ⬜ |

#### TomLinearProgressIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| value | double? | resolveDoubleOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |
| minHeight | double? | resolveDoubleOrNull | ⬜ |
| semanticsLabel | String? | resolveResourceOrNull | ⬜ |
| semanticsValue | String? | resolveResourceOrNull | ⬜ |
| borderRadius | BorderRadiusGeometry? | resolveBorderRadius | ⬜ |

#### TomRefreshIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| displacement | double | resolveDoubleOrNull | ⬜ |
| edgeOffset | double | resolveDoubleOrNull | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| semanticsLabel | String? | resolveResourceOrNull | ⬜ |
| semanticsValue | String? | resolveResourceOrNull | ⬜ |
| strokeWidth | double | resolveDoubleOrNull | ⬜ |

#### TomCupertinoActivityIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| animating | bool | resolveBoolOrNull | ⬜ |
| radius | double | resolveDoubleOrNull | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |

#### TomCupertinoLinearActivityIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| value | double? | resolveDoubleOrNull | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |
| trackHeight | double? | resolveDoubleOrNull | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomCupertinoSliverRefreshControl

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| refreshTriggerPullDistance | double? | resolveDoubleOrNull | ⬜ |
| refreshIndicatorExtent | double? | resolveDoubleOrNull | ⬜ |

---

### Selects (`tom_selects.dart`)

#### TomDropdownButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | int? | resolveIntOrNull | ⬜ |
| style | TextStyle? | resolveTextStyle | ⬜ |
| iconDisabledColor | Color? | resolveColorOrNull | ⬜ |
| iconEnabledColor | Color? | resolveColorOrNull | ⬜ |
| iconSize | double? | resolveDoubleOrNull | ⬜ |
| isDense | bool | resolveBoolOrNull | ⬜ |
| isExpanded | bool | resolveBoolOrNull | ⬜ |
| itemHeight | double? | resolveDoubleOrNull | ⬜ |
| focusColor | Color? | resolveColorOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |
| dropdownColor | Color? | resolveColorOrNull | ⬜ |
| menuMaxHeight | double? | resolveDoubleOrNull | ⬜ |
| enableFeedback | bool? | resolveBoolOrNull | ⬜ |
| alignment | AlignmentGeometry | resolveAlignment | ⬜ |
| borderRadius | BorderRadius? | resolveBorderRadius | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| hint | String? | resolveResourceOrNull | ⬜ |

#### TomPopupMenuButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| tooltip | String? | resolveResourceOrNull | ⬜ |
| elevation | double? | resolveDoubleOrNull | ⬜ |
| shadowColor | Color? | resolveColorOrNull | ⬜ |
| surfaceTintColor | Color? | resolveColorOrNull | ⬜ |
| padding | EdgeInsetsGeometry | resolveEdgeInsetsOrNull | ⬜ |
| iconSize | double? | resolveDoubleOrNull | ⬜ |
| offset | Offset? | resolveOffset | ⬜ |
| enabled | bool | resolveBoolOrNull | ⬜ |
| shape | ShapeBorder? | resolveShapeBorder | ⬜ |
| color | Color? | resolveColorOrNull | ⬜ |
| enableFeedback | bool? | resolveBoolOrNull | ⬜ |
| constraints | BoxConstraints? | resolveBoxConstraints | ⬜ |

#### TomDropdownMenu

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| enabled | bool | resolveBoolOrNull | ⬜ |
| width | double? | resolveDoubleOrNull | ⬜ |
| menuHeight | double? | resolveDoubleOrNull | ⬜ |
| label | String? | resolveResourceOrNull | ⬜ |
| hintText | String? | resolveResourceOrNull | ⬜ |
| helperText | String? | resolveResourceOrNull | ⬜ |
| errorText | String? | resolveResourceOrNull | ⬜ |
| enableFilter | bool | resolveBoolOrNull | ⬜ |
| enableSearch | bool | resolveBoolOrNull | ⬜ |
| textStyle | TextStyle? | resolveTextStyle | ⬜ |
| expandedInsets | EdgeInsets? | resolveEdgeInsetsOrNull | ⬜ |
| requestFocusOnTap | bool | resolveBoolOrNull | ⬜ |

#### TomMenuAnchor

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignmentOffset | Offset? | resolveOffset | ⬜ |
| consumeOutsideTap | bool | resolveBoolOrNull | ⬜ |

#### TomDropdownButtonFormField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | InputDecoration? | resolveInputDecoration | ⬜ |
| elevation | int? | resolveIntOrNull | ⬜ |
| style | TextStyle? | resolveTextStyle | ⬜ |
| iconDisabledColor | Color? | resolveColorOrNull | ⬜ |
| iconEnabledColor | Color? | resolveColorOrNull | ⬜ |
| iconSize | double? | resolveDoubleOrNull | ⬜ |
| isDense | bool | resolveBoolOrNull | ⬜ |
| isExpanded | bool | resolveBoolOrNull | ⬜ |
| itemHeight | double? | resolveDoubleOrNull | ⬜ |
| focusColor | Color? | resolveColorOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |
| dropdownColor | Color? | resolveColorOrNull | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| menuMaxHeight | double? | resolveDoubleOrNull | ⬜ |
| enableFeedback | bool? | resolveBoolOrNull | ⬜ |
| alignment | AlignmentGeometry | resolveAlignment | ⬜ |
| borderRadius | BorderRadius? | resolveBorderRadius | ⬜ |


#### TomCheckedPopupMenuItem

No resource-loadable parameters.

#### TomCupertinoPicker

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| diameterRatio | double? | resolveDoubleOrNull | ⬜ |
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| offAxisFraction | double? | resolveDoubleOrNull | ⬜ |
| magnification | double? | resolveDoubleOrNull | ⬜ |
| squeeze | double? | resolveDoubleOrNull | ⬜ |
| itemExtent | double? | resolveDoubleOrNull | ⬜ |

#### TomCupertinoSegmentedControl

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| unselectedColor | Color? | resolveColorOrNull | ⬜ |
| selectedColor | Color? | resolveColorOrNull | ⬜ |
| borderColor | Color? | resolveColorOrNull | ⬜ |
| pressedColor | Color? | resolveColorOrNull | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomCupertinoSlidingSegmentedControl

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | resolveColorOrNull | ⬜ |
| thumbColor | Color? | resolveColorOrNull | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomDropdownMenuItem

No resource-loadable parameters.

#### TomPopupMenuDivider

No resource-loadable parameters.

#### TomPopupMenuItem

No resource-loadable parameters.

---

### Sliders (`tom_sliders.dart`)

#### TomSlider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| min | double | resolveDoubleOrNull | ⬜ |
| max | double | resolveDoubleOrNull | ⬜ |
| divisions | int? | resolveIntOrNull | ⬜ |
| label | String? | resolveResourceOrNull | ⬜ |
| activeColor | Color? | resolveColorOrNull | ⬜ |
| inactiveColor | Color? | resolveColorOrNull | ⬜ |
| thumbColor | Color? | resolveColorOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |

#### TomRangeSlider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| min | double | resolveDoubleOrNull | ⬜ |
| max | double | resolveDoubleOrNull | ⬜ |
| divisions | int? | resolveIntOrNull | ⬜ |
| activeColor | Color? | resolveColorOrNull | ⬜ |
| inactiveColor | Color? | resolveColorOrNull | ⬜ |

#### TomCupertinoSlider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| min | double | resolveDoubleOrNull | ⬜ |
| max | double | resolveDoubleOrNull | ⬜ |
| divisions | int? | resolveIntOrNull | ⬜ |
| activeColor | Color? | resolveColorOrNull | ⬜ |
| thumbColor | Color | resolveColorOrNull | ⬜ |

---

### Slivers (`tom_slivers.dart`)

#### TomDecoratedSliver

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | Decoration? | resolveDecoration | ✅ |

#### TomSliverConstrainedCrossAxis

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| maxExtent | double? | resolveDoubleOrNull | ✅ |

#### TomSliverCrossAxisExpanded

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| flex | int? | resolveIntOrNull | ⬜ |

#### TomSliverFillViewport

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| viewportFraction | double? | resolveDoubleOrNull | ⬜ |
| padEnds | bool | resolveBoolOrNull | ⬜ |

#### TomSliverFixedExtentList

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| itemExtent | double? | resolveDoubleOrNull | ✅ |

#### TomSliverOffstage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| offstage | bool? | resolveBoolOrNull | ✅ |

#### TomSliverOpacity

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opacity | double? | resolveDoubleOrNull | ✅ |
| alwaysIncludeSemantics | bool? | resolveBoolOrNull | ⬜ |

#### TomSliverPadding

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |

#### TomSliverPersistentHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| pinned | bool? | resolveBoolOrNull | ⬜ |
| floating | bool? | resolveBoolOrNull | ⬜ |

#### TomSliverResizingHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(minExtentPrototype/maxExtentPrototype are doubles but semantically not resource values)_ | | | |

#### TomSliverSafeArea

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| left | bool? | resolveBoolOrNull | ⬜ |
| top | bool? | resolveBoolOrNull | ⬜ |
| right | bool? | resolveBoolOrNull | ⬜ |
| bottom | bool? | resolveBoolOrNull | ⬜ |
| minimum | EdgeInsets? | resolveEdgeInsetsOrNull | ⬜ |

#### TomSliverVisibility

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| visible | bool | resolveBoolOrNull | ⬜ |
| maintainSize | bool | resolveBoolOrNull | ⬜ |
| maintainAnimation | bool | resolveBoolOrNull | ⬜ |
| maintainState | bool | resolveBoolOrNull | ⬜ |

#### TomPinnedHeaderSliver, TomSliverCrossAxisGroup, TomSliverFloatingHeader, TomSliverMainAxisGroup, TomSliverPrototypeExtentList, TomSliverVariedExtentList

No resource-loadable parameters beyond inherited `tomId`/`tomGroup`.

---

### Tables (`tom_tables.dart`)

#### TomDataTable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| sortAscending | bool | resolveBoolOrNull | ⬜ |
| sortColumnIndex | int? | resolveIntOrNull | ⬜ |
| decoration | Decoration? | resolveDecoration | ⬜ |
| dataRowMinHeight | double? | resolveDoubleOrNull | ⬜ |
| dataRowMaxHeight | double? | resolveDoubleOrNull | ⬜ |
| dataTextStyle | TextStyle? | resolveTextStyle | ⬜ |
| headingRowHeight | double? | resolveDoubleOrNull | ⬜ |
| headingTextStyle | TextStyle? | resolveTextStyle | ⬜ |
| horizontalMargin | double? | resolveDoubleOrNull | ⬜ |
| columnSpacing | double? | resolveDoubleOrNull | ⬜ |
| showCheckboxColumn | bool | resolveBoolOrNull | ⬜ |
| showBottomBorder | bool | resolveBoolOrNull | ⬜ |
| dividerThickness | double? | resolveDoubleOrNull | ⬜ |
| checkboxHorizontalMargin | double? | resolveDoubleOrNull | ⬜ |
| border | TableBorder? | resolveTableBorder | ✅ |

#### TomPaginatedDataTable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| sortAscending | bool | resolveBoolOrNull | ⬜ |
| sortColumnIndex | int? | resolveIntOrNull | ⬜ |
| dataRowMinHeight | double? | resolveDoubleOrNull | ⬜ |
| dataRowMaxHeight | double? | resolveDoubleOrNull | ⬜ |
| headingRowHeight | double? | resolveDoubleOrNull | ⬜ |
| horizontalMargin | double? | resolveDoubleOrNull | ⬜ |
| columnSpacing | double? | resolveDoubleOrNull | ⬜ |
| showCheckboxColumn | bool | resolveBoolOrNull | ⬜ |
| showFirstLastButtons | bool | resolveBoolOrNull | ⬜ |
| initialFirstRowIndex | int | resolveIntOrNull | ⬜ |
| rowsPerPage | int | resolveIntOrNull | ⬜ |
| checkboxHorizontalMargin | double? | resolveDoubleOrNull | ⬜ |
| showEmptyRows | bool | resolveBoolOrNull | ⬜ |

#### TomTable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| border | TableBorder? | resolveTableBorder | ⬜ |

#### TomGridView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| reverse | bool | resolveBoolOrNull | ⬜ |
| primary | bool? | resolveBoolOrNull | ⬜ |
| shrinkWrap | bool | resolveBoolOrNull | ⬜ |
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| cacheExtent | double? | resolveDoubleOrNull | ⬜ |
| semanticChildCount | int? | resolveIntOrNull | ⬜ |
| restorationId | String? | resolveResourceOrNull | ⬜ |

#### TomReorderableListView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| buildDefaultDragHandles | bool | resolveBoolOrNull | ⬜ |
| padding | EdgeInsets? | resolveEdgeInsetsOrNull | ⬜ |
| reverse | bool | resolveBoolOrNull | ⬜ |
| primary | bool? | resolveBoolOrNull | ⬜ |
| shrinkWrap | bool | resolveBoolOrNull | ⬜ |
| anchor | double? | resolveDoubleOrNull | ⬜ |
| restorationId | String? | resolveResourceOrNull | ⬜ |
| autoScrollerVelocityScalar | double? | resolveDoubleOrNull | ⬜ |
| itemExtent | double? | resolveDoubleOrNull | ⬜ |
| cacheExtent | double? | resolveDoubleOrNull | ⬜ |


#### TomDataCell

No resource-loadable parameters.

---

### Toggles (`tom_toggles.dart`)

#### TomSwitch

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | resolveColorOrNull | ⬜ |
| activeTrackColor | Color? | resolveColorOrNull | ⬜ |
| inactiveThumbColor | Color? | resolveColorOrNull | ⬜ |
| inactiveTrackColor | Color? | resolveColorOrNull | ⬜ |
| splashRadius | double? | resolveDoubleOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |

> **Note:** TomSwitch uses `WidgetStateProperty<Color?>` for thumbColor, trackColor, trackOutlineColor — these cannot be directly resource-resolved.

#### TomCheckbox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| tristate | bool | resolveBoolOrNull | ⬜ |
| activeColor | Color? | resolveColorOrNull | ⬜ |
| checkColor | Color? | resolveColorOrNull | ⬜ |
| focusColor | Color? | resolveColorOrNull | ⬜ |
| hoverColor | Color? | resolveColorOrNull | ⬜ |
| splashRadius | double? | resolveDoubleOrNull | ⬜ |
| visualDensity | VisualDensity? | resolveVisualDensity | ✅ |
| shape | OutlinedBorder? | resolveShapeBorder | ⬜ |
| side | BorderSide? | resolveBorderSide | ⬜ |
| isError | bool | resolveBoolOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |

#### TomRadio

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | resolveColorOrNull | ⬜ |
| focusColor | Color? | resolveColorOrNull | ⬜ |
| hoverColor | Color? | resolveColorOrNull | ⬜ |
| splashRadius | double? | resolveDoubleOrNull | ⬜ |
| visualDensity | VisualDensity? | resolveVisualDensity | ⬜ |
| toggleable | bool | resolveBoolOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |

#### TomSwitchListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ⬜ |
| isThreeLine | bool | resolveBoolOrNull | ⬜ |
| dense | bool? | resolveBoolOrNull | ⬜ |
| contentPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| activeColor | Color? | resolveColorOrNull | ⬜ |
| activeTrackColor | Color? | resolveColorOrNull | ⬜ |
| inactiveThumbColor | Color? | resolveColorOrNull | ⬜ |
| inactiveTrackColor | Color? | resolveColorOrNull | ⬜ |
| tileColor | Color? | resolveColorOrNull | ⬜ |
| selectedTileColor | Color? | resolveColorOrNull | ⬜ |
| hoverColor | Color? | resolveColorOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |
| shape | ShapeBorder? | resolveShapeBorder | ⬜ |
| visualDensity | VisualDensity? | resolveVisualDensity | ⬜ |
| enableFeedback | bool? | resolveBoolOrNull | ⬜ |

#### TomCheckboxListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | resolveResourceOrNull | ⬜ |
| isThreeLine | bool | resolveBoolOrNull | ⬜ |
| dense | bool? | resolveBoolOrNull | ⬜ |
| contentPadding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| activeColor | Color? | resolveColorOrNull | ⬜ |
| checkColor | Color? | resolveColorOrNull | ⬜ |
| tristate | bool | resolveBoolOrNull | ⬜ |
| shape | ShapeBorder? | resolveShapeBorder | ⬜ |
| side | BorderSide? | resolveBorderSide | ⬜ |
| tileColor | Color? | resolveColorOrNull | ⬜ |
| selectedTileColor | Color? | resolveColorOrNull | ⬜ |
| visualDensity | VisualDensity? | resolveVisualDensity | ⬜ |
| enableFeedback | bool? | resolveBoolOrNull | ⬜ |
| autofocus | bool | resolveBoolOrNull | ⬜ |
| checkboxShape | OutlinedBorder? | resolveShapeBorder | ⬜ |


#### TomCupertinoCheckbox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | resolveColorOrNull | ⬜ |
| inactiveColor | Color? | resolveColorOrNull | ⬜ |
| checkColor | Color? | resolveColorOrNull | ⬜ |
| focusColor | Color? | resolveColorOrNull | ⬜ |
| side | BorderSide? | resolveBorderSide | ⬜ |
| shape | OutlinedBorder? | resolveShapeBorder | ⬜ |
| semanticLabel | String? | resolveResourceOrNull | ⬜ |

#### TomCupertinoRadio

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | resolveColorOrNull | ⬜ |
| inactiveColor | Color? | resolveColorOrNull | ⬜ |
| fillColor | Color? | resolveColorOrNull | ⬜ |
| focusColor | Color? | resolveColorOrNull | ⬜ |

#### TomCupertinoSwitch

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeTrackColor | Color? | resolveColorOrNull | ⬜ |
| thumbColor | Color? | resolveColorOrNull | ⬜ |
| trackColor | Color? | resolveColorOrNull | ⬜ |
| focusColor | Color? | resolveColorOrNull | ⬜ |
| onLabelColor | Color? | resolveColorOrNull | ⬜ |
| offLabelColor | Color? | resolveColorOrNull | ⬜ |

---

### Trees (`tom_trees.dart`)

#### TomTreeView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | resolveEdgeInsetsOrNull | ⬜ |
| indentation | double? | resolveDoubleOrNull | ⬜ |
| shrinkWrap | bool | resolveBoolOrNull | ⬜ |
| physics | ScrollPhysics? | resolveScrollPhysics | ✅ |

#### TomTreeNode

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| initiallyExpanded | bool | resolveBoolOrNull | ⬜ |

#### TomTreeSliver

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| addAutomaticKeepAlives | bool? | resolveBoolOrNull | ✅ |
| addRepaintBoundaries | bool? | resolveBoolOrNull | ✅ |
| addSemanticIndexes | bool? | resolveBoolOrNull | ✅ |

---

## Summary Statistics

| Category | Widgets | Total Params | ✅ Resolved | ⛔ Excluded | ⬜ Remaining |
|----------|---------|-------------|-------------|-------------|--------------|
| Animated Widgets | 20 | 46 | 34 | 12 | 0 |
| Builder Widgets | 8 | 0 | 0 | 0 | 0 |
| Buttons | 23 | 70 | 70 | 0 | 0 |
| Chips | 5 | 83 | 83 | 0 | 0 |
| Containers | 81 | 203 | 203 | 0 | 0 |
| ACL Container | 1 | 5 | 0 | 5 | 0 |
| Dialogs | 17 | 75 | 62 | 13 | 0 |
| Effects | 6 | 0 | 0 | 0 | 0 |
| Images | 11 | 56 | 56 | 0 | 0 |
| Inputs | 16 | 88 | 88 | 0 | 0 |
| Interactions | 10 | 38 | 38 | 0 | 0 |
| Labels | 15 | 79 | 73 | 0 | 6 |
| Lists | 6 | 39 | 1 | 0 | 38 |
| Navigation | 21 | 81 | 4 | 0 | 77 |
| Progress | 6 | 30 | 0 | 0 | 30 |
| Selects | 12 | 74 | 0 | 0 | 74 |
| Sliders | 3 | 18 | 0 | 0 | 18 |
| Slivers | 13 | 21 | 5 | 0 | 16 |
| Tables | 6 | 46 | 1 | 0 | 45 |
| Toggles | 8 | 71 | 1 | 0 | 70 |
| Trees | 3 | 8 | 4 | 0 | 4 |
| **Total** | **291** | **1131** | **722** | **30** | **379** |

**Status key:**
- ✅ **Resolved** — Resource resolution implemented in `buildContent()`
- ⛔ **Excluded** — Cannot use resource resolution (extension pattern or other constraint)
- ⬜ **Remaining** — Has resolver but not yet wired

---

## Excluded Parameter Types

These parameter types appear frequently but **cannot be resource-resolved** with the current resolver infrastructure:

| Type | Reason | Examples |
|------|--------|----------|
| `Widget` / `List<Widget>` | UI components, not data | child, title, leading, trailing, actions |
| `VoidCallback` / Function types | Code references | onPressed, onChanged, onTap |
| `TextEditingController` | Stateful controller | controller |
| `ScrollController` | Stateful controller | controller |
| `FocusNode` | Stateful object | focusNode |
| `ImageProvider` | Requires factory logic | image, backgroundImage |
| `SliverChildDelegate` | Complex builder pattern | delegate |
| `WidgetStateProperty<X>` | State-dependent wrapper | overlayColor, fillColor |
| `Animation<X>` | Animation controller ref | valueColor, animation |
| `Curve` | Named singleton pattern | fadeInCurve, fadeOutCurve |
| `Matrix4` | Complex transform | transform |
| `ColorFilter` | Composite filter object | colorFilter |
| `ImageFilter` | Composite filter object | filter |

## Candidate Resolver Types (Not Yet Implemented)

| Type | Usage Count | Priority |
|------|-------------|----------|
| EdgeInsetsGeometry (via resolveEdgeInsetsOrNull) | ~45 params | Already exists in TomNodeBase |
| Enum types (generic enum resolver) | ~60+ params | Medium — needs per-enum mapping |
| Duration | ~8 params | Low — can use int milliseconds |
| Radius | ~3 params | Low |
| Size | ~3 params | Low |
