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

Every method named in this document is a static on one of two classes, both
exported from `widget_base/`. The Resolver column below and in every per-widget
table names them qualified, so a row can be checked against the source without
first guessing where the method lives.

### Primitive Resolvers (`TomCtr`)

Declared in `lib/src/widget_base/tom_construction_helpers.dart`. All take
`(String? basePath, [String suffix])` and read the resource key
`<basePath>.<suffix>` — or `<basePath>` alone when the suffix is empty. A null
`basePath` (a widget with no `tomId`) reads as "no resource" rather than as an
error.

| Method | Return Type | Resource Value |
|--------|-------------|----------------|
| `TomCtr.textOrNull` | `String?` | String |
| `TomCtr.text` | `String` | String; `''` when `basePath` is null, else the key itself when unset |
| `TomCtr.color` | `Color?` | Hex string `#RRGGBB` / `#AARRGGBB` |
| `TomCtr.icon` | `IconData?` | Icon name string |
| `TomCtr.doubleVal` | `double?` | Numeric |
| `TomCtr.intVal` | `int?` | Integer |
| `TomCtr.boolVal` | `bool?` | Boolean |
| `TomCtr.edgeInsets` | `EdgeInsets?` | Map `{left,top,right,bottom}` |
| `TomCtr.value` | `dynamic` | Any |
| `TomCtr.list` | `List<dynamic>?` | List |
| `TomCtr.map` | `Map<String, dynamic>?` | Map (String keys only) |
| `TomCtr.exists` | `bool` | — (presence test) |

`TomCtr` also builds two composite values from a sub-tree of keys, alongside
the `TomStyleResolvers` family below:

| Method | Return Type | Keys read |
|--------|-------------|-----------|
| `TomCtr.textStyle` | `TextStyle?` | fontSize, fontWeight, fontFamily, color, letterSpacing, fontStyle |
| `TomCtr.inputBorder` | `InputBorder?` | kind (`outline`/`underline`/`none`), width, radius, color |
| `TomCtr.widgetStateColor` | `WidgetStateProperty<Color>?` | default colour plus per-state overrides |

#### The `…OrFail` family

Five accessors have a second form that throws instead of answering `null`. The
thrown type is **`StateError`** in every case — the package contains exactly one
`throw FlutterError`, in `tom_slivers.dart`, and it is unrelated to resource
resolution.

| Method | Return Type | Throws when |
|--------|-------------|-------------|
| `TomCtr.textOrFail` | `String` | `basePath` is null (an unset key yields the key, for development visibility) |
| `TomCtr.colorOrFail` | `Color` | `basePath` is null, the key is unset, or the value is not a colour |
| `TomCtr.iconOrFail` | `IconData` | `basePath` is null, the key is unset, or the name is unknown |
| `TomCtr.doubleOrFail` | `double` | `basePath` is null, the key is unset, or the value is not numeric |
| `TomCtr.intOrFail` | `int` | `basePath` is null, the key is unset, or the value is not an int |

Which accessors get an `…OrFail` is a rule, not an accident: one exists where
the resource can be a widget's **only** source for a required parameter that has
no default. `boolVal` and `edgeInsets` read parameters Flutter always defaults,
so a resource overrides a value rather than supplying one and its absence is
never a failure; `value`, `list` and `map` are raw escape hatches, and `TomCtr`
is not told what a caller means to do with a `List`, so it cannot decide what
"unusable" would be. The rule is stated in `doc/widget_base.md` and enforced by
`test/widget_base/tom_ctr_helpers_test.dart` in `tom_flutter_ui`.

#### `TomWidgetMixin` — the instance-level wrappers

`TomWidgetMixin` (`lib/src/groups/tom_widget_mixin.dart`) offers `getText`,
`resolveColorOrNull`, `resolveDoubleOrNull`, `resolveDoubleOrFail`,
`resolveIntOrNull`, `resolveBoolOrNull` and `resolveEdgeInsetsOrNull` — thin
forwarders to the `TomCtr` statics above that supply `basePath` from the widget.
They are **not** what the widgets in this document call: apart from `getText`,
each has no call site in the package. This document names the `TomCtr` statics
because that is what the code does.

`TomNodeBase` declares no resolution methods at all; it contributes the
`basePath` the resolvers read from.

### Complex Resolvers (`TomStyleResolvers`)

Declared in `lib/src/widget_base/tom_style_resolvers.dart`. All are statics
taking `(String basePath, String suffix)` — `basePath` non-null, unlike the
`TomCtr` family — and build a value from a sub-tree of keys under
`<basePath>.<suffix>`.

| Method | Return Type | Map Keys |
|--------|-------------|----------|
| `TomStyleResolvers.resolveTextStyle` | `TextStyle?` | fontSize, fontWeight, fontStyle, color, backgroundColor, letterSpacing, wordSpacing, height, decoration, decorationColor, decorationStyle, overflow, fontFamily |
| `TomStyleResolvers.resolveButtonStyle` | `ButtonStyle?` | backgroundColor, foregroundColor, elevation, padding, minimumSize, maximumSize, shape, side |
| `TomStyleResolvers.resolveInputDecoration` | `InputDecoration?` | labelText, hintText, helperText, errorText, prefixText, suffixText, counterText, filled, fillColor, border, enabledBorder, focusedBorder, errorBorder |
| `TomStyleResolvers.resolveMenuStyle` | `MenuStyle?` | backgroundColor, surfaceTintColor, shadowColor, elevation, padding, minimumSize, maximumSize, shape, side |
| `TomStyleResolvers.resolveShapeBorder` | `ShapeBorder?` | type (roundedRectangle/stadium/circle/beveled), borderRadius, side |
| `TomStyleResolvers.resolveBorderSide` | `BorderSide?` | color, width, style |
| `TomStyleResolvers.resolveBorderRadius` | `BorderRadius?` | topLeft, topRight, bottomLeft, bottomRight, all |
| `TomStyleResolvers.resolveDecoration` | `Decoration?` | color, borderRadius, border, boxShadow |
| `TomStyleResolvers.resolveBoxConstraints` | `BoxConstraints?` | minWidth, maxWidth, minHeight, maxHeight |
| `TomStyleResolvers.resolveAlignment` | `AlignmentGeometry?` | x, y (or preset names) |
| `TomStyleResolvers.resolveOffset` | `Offset?` | dx, dy |
| `TomStyleResolvers.resolveTableBorder` | `TableBorder?` | top, right, bottom, left, horizontalInside, verticalInside, borderRadius |
| `TomStyleResolvers.resolveVisualDensity` | `VisualDensity?` | horizontal, vertical (or preset: comfortable/compact/standard) |
| `TomStyleResolvers.resolveIconThemeData` | `IconThemeData?` | color, opacity, size, fill, weight, grade, opticalSize |
| `TomStyleResolvers.resolveStrutStyle` | `StrutStyle?` | fontFamily, fontSize, fontWeight, fontStyle, height, leading, forceStrutHeight |
| `TomStyleResolvers.resolveTextHeightBehavior` | `TextHeightBehavior?` | applyHeightToFirstAscent, applyHeightToLastDescent, leadingDistribution |
| `TomStyleResolvers.resolveScrollPhysics` | `ScrollPhysics?` | type (bouncing/clamping/never/always/page) |

---

## Parameters by Widget Category

### Animated Widgets (`tom_animated.dart`)

#### TomAnimatedAlign

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| heightFactor | double? | `TomCtr.doubleVal` | ✅ |
| widthFactor | double? | `TomCtr.doubleVal` | ✅ |

#### TomAnimatedContainer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| decoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| foregroundDecoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| constraints | BoxConstraints? | `TomStyleResolvers.resolveBoxConstraints` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |
| transformAlignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomAnimatedDefaultTextStyle

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | TextStyle | `TomStyleResolvers.resolveTextStyle` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| softWrap | bool | `TomCtr.boolVal` | ✅ |

#### TomAnimatedFractionallySizedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| widthFactor | double? | `TomCtr.doubleVal` | ✅ |
| heightFactor | double? | `TomCtr.doubleVal` | ✅ |

#### TomAnimatedOpacity

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opacity | double? | `TomCtr.doubleOrFail` | ✅ |
| alwaysIncludeSemantics | bool? | `TomCtr.boolVal` | ✅ |

#### TomAnimatedPadding

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry | `TomCtr.edgeInsets` | ✅ |

#### TomAnimatedPhysicalModel

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | double? | `TomCtr.doubleOrFail` | ✅ |
| color | Color? | `TomCtr.colorOrFail` | ✅ |
| shadowColor | Color? | `TomCtr.colorOrFail` | ✅ |
| borderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |


#### TomAnimatedBuilder

No resource-loadable parameters.

#### TomAnimatedCrossFade

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| excludeBottomFocus | bool? | `TomCtr.boolVal` | ✅ |

#### TomAnimatedPositioned

> ⛔ **Extension pattern** — Uses `extends AnimatedPositioned with TomWidgetMixin` so Stack recognizes it as Positioned. Parameters pass to super constructor at construction time, not at build time. Resource resolution not possible.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| left | double? | `TomCtr.doubleVal` | ⛔ |
| top | double? | `TomCtr.doubleVal` | ⛔ |
| right | double? | `TomCtr.doubleVal` | ⛔ |
| bottom | double? | `TomCtr.doubleVal` | ⛔ |
| width | double? | `TomCtr.doubleVal` | ⛔ |
| height | double? | `TomCtr.doubleVal` | ⛔ |

#### TomAnimatedPositionedDirectional

> ⛔ **Extension pattern** — Uses `extends AnimatedPositionedDirectional with TomWidgetMixin` so Stack recognizes it as Positioned. Parameters pass to super constructor at construction time, not at build time. Resource resolution not possible.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| start | double? | `TomCtr.doubleVal` | ⛔ |
| top | double? | `TomCtr.doubleVal` | ⛔ |
| end | double? | `TomCtr.doubleVal` | ⛔ |
| bottom | double? | `TomCtr.doubleVal` | ⛔ |
| width | double? | `TomCtr.doubleVal` | ⛔ |
| height | double? | `TomCtr.doubleVal` | ⛔ |

#### TomAnimatedRotation

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| turns | double? | `TomCtr.doubleOrFail` | ✅ |
| alignment | Alignment? | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomAnimatedScale

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| scale | double? | `TomCtr.doubleOrFail` | ✅ |
| alignment | Alignment? | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomAnimatedSize

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomAnimatedSlide

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| offset | Offset | `TomStyleResolvers.resolveOffset` | ✅ |

#### TomAnimatedSwitcher

No resource-loadable parameters.

#### TomFadeTransition

No resource-loadable parameters.

#### TomHero

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| transitionOnUserGestures | bool? | `TomCtr.boolVal` | ✅ |

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
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

#### TomTextButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

#### TomOutlinedButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

#### TomFilledButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

#### TomFloatingActionButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| tooltip | String? | `TomCtr.textOrNull` | ✅ |
| foregroundColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| splashColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| focusElevation | double? | `TomCtr.doubleVal` | ✅ |
| hoverElevation | double? | `TomCtr.doubleVal` | ✅ |
| highlightElevation | double? | `TomCtr.doubleVal` | ✅ |
| disabledElevation | double? | `TomCtr.doubleVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| mini | bool | `TomCtr.boolVal` | ✅ |
| isExtended | bool? | `TomCtr.boolVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| label | String? | `TomCtr.textOrNull` | ✅ |


#### TomBackButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | `TomCtr.color` | ✅ |

#### TomCheckboxMenuButton

No resource-loadable parameters.

#### TomCloseButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoActionSheetAction

No resource-loadable parameters.

#### TomCupertinoButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| minSize | double? | `TomCtr.doubleVal` | ✅ |
| pressedOpacity | double? | `TomCtr.doubleVal` | ✅ |

#### TomCupertinoContextMenuAction

No resource-loadable parameters.

#### TomCupertinoDialogAction

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| textStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |

#### TomDropdownMenuEntry

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

#### TomExpandIcon

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| size | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| disabledColor | Color? | `TomCtr.color` | ✅ |
| expandedColor | Color? | `TomCtr.color` | ✅ |

> **Note:** `semanticLabel` was incorrectly listed — Flutter's `ExpandIcon` widget doesn't expose this parameter.

#### TomIconButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| iconSize | double? | `TomCtr.doubleVal` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| splashRadius | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| highlightColor | Color? | `TomCtr.color` | ✅ |
| splashColor | Color? | `TomCtr.color` | ✅ |
| disabledColor | Color? | `TomCtr.color` | ✅ |
| constraints | BoxConstraints? | `TomStyleResolvers.resolveBoxConstraints` | ✅ |
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |
| tooltip | String? | `TomCtr.textOrNull` | ✅ |

#### TomMenuBar

No resource-loadable parameters.

#### TomMenuItemButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

#### TomRadioMenuButton

No resource-loadable parameters.

#### TomSegmentedButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

#### TomSnackBarAction

No resource-loadable parameters.

#### TomSubmenuButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignmentOffset | Offset? | `TomStyleResolvers.resolveOffset` | ✅ |
| style | ButtonStyle? | `TomStyleResolvers.resolveButtonStyle` | ✅ |

---

### Chips (`tom_chips.dart`)

#### TomFilterChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | `TomCtr.textOrNull` | ✅ |
| labelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| labelPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| showCheckmark | bool | `TomCtr.boolVal` | ✅ |
| checkmarkColor | Color? | `TomCtr.color` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |
| disabledColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| selectedShadowColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| deleteIconColor | Color? | `TomCtr.color` | ✅ |
| shape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| pressElevation | double? | `TomCtr.doubleVal` | ✅ |
| deleteButtonTooltipMessage | String? | `TomCtr.textOrNull` | ✅ |

#### TomChoiceChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | `TomCtr.textOrNull` | ✅ |
| labelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| labelPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |
| disabledColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| selectedShadowColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| shape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| pressElevation | double? | `TomCtr.doubleVal` | ✅ |

#### TomActionChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | `TomCtr.textOrNull` | ✅ |
| tooltip | String? | `TomCtr.textOrNull` | ✅ |
| labelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| labelPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| shape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| pressElevation | double? | `TomCtr.doubleVal` | ✅ |

#### TomInputChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | `TomCtr.textOrNull` | ✅ |
| tooltip | String? | `TomCtr.textOrNull` | ✅ |
| labelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| labelPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| deleteIconColor | Color? | `TomCtr.color` | ✅ |
| deleteButtonTooltipMessage | String? | `TomCtr.textOrNull` | ✅ |
| showCheckmark | bool | `TomCtr.boolVal` | ✅ |
| checkmarkColor | Color? | `TomCtr.color` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |
| disabledColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| selectedShadowColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| shape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| pressElevation | double? | `TomCtr.doubleVal` | ✅ |


#### TomRawChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | `TomCtr.textOrNull` | ✅ |
| labelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| labelPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| deleteIconColor | Color? | `TomCtr.color` | ✅ |
| deleteButtonTooltipMessage | String? | `TomCtr.textOrNull` | ✅ |
| pressElevation | double? | `TomCtr.doubleVal` | ✅ |
| checkmarkColor | Color? | `TomCtr.color` | ✅ |
| shape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |
| disabledColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| selectedShadowColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| tooltip | String? | `TomCtr.textOrNull` | ✅ |

---

### Containers (`tom_containers.dart`)

#### TomCard

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| borderOnForeground | bool | `TomCtr.boolVal` | ✅ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| semanticContainer | bool | `TomCtr.boolVal` | ✅ |

#### TomExpansionTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| initiallyExpanded | bool | `TomCtr.boolVal` | ✅ |
| maintainState | bool | `TomCtr.boolVal` | ✅ |
| tilePadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| childrenPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| collapsedBackgroundColor | Color? | `TomCtr.color` | ✅ |
| textColor | Color? | `TomCtr.color` | ✅ |
| collapsedTextColor | Color? | `TomCtr.color` | ✅ |
| iconColor | Color? | `TomCtr.color` | ✅ |
| collapsedIconColor | Color? | `TomCtr.color` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| collapsedShape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| dense | bool | `TomCtr.boolVal` | ✅ |
| showTrailingIcon | bool | `TomCtr.boolVal` | ✅ |

#### TomScaffold

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| primary | bool | `TomCtr.boolVal` | ✅ |
| extendBody | bool | `TomCtr.boolVal` | ✅ |
| extendBodyBehindAppBar | bool | `TomCtr.boolVal` | ✅ |
| drawerScrimColor | Color? | `TomCtr.color` | ✅ |
| drawerEdgeDragWidth | double? | `TomCtr.doubleVal` | ✅ |
| drawerEnableOpenDragGesture | bool | `TomCtr.boolVal` | ✅ |
| endDrawerEnableOpenDragGesture | bool | `TomCtr.boolVal` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |

#### TomAppBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| automaticallyImplyLeading | bool | `TomCtr.boolVal` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| scrolledUnderElevation | double? | `TomCtr.doubleVal` | ✅ |
| titleSpacing | double? | `TomCtr.doubleVal` | ✅ |
| toolbarHeight | double? | `TomCtr.doubleVal` | ✅ |
| leadingWidth | double? | `TomCtr.doubleVal` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| foregroundColor | Color? | `TomCtr.color` | ✅ |
| iconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |
| actionsIconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |
| primary | bool | `TomCtr.boolVal` | ✅ |
| centerTitle | bool? | `TomCtr.boolVal` | ✅ |
| excludeHeaderSemantics | bool | `TomCtr.boolVal` | ✅ |
| toolbarOpacity | double | `TomCtr.doubleVal` | ✅ |
| bottomOpacity | double | `TomCtr.doubleVal` | ✅ |
| toolbarTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| titleTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| forceMaterialTransparency | bool | `TomCtr.boolVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |

#### TomBottomAppBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |
| notchMargin | double | `TomCtr.doubleVal` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomDivider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| height | double? | `TomCtr.doubleVal` | ✅ |
| thickness | double? | `TomCtr.doubleVal` | ✅ |
| indent | double? | `TomCtr.doubleVal` | ✅ |
| endIndent | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |

#### TomContainer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| decoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| foregroundDecoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| constraints | BoxConstraints? | `TomStyleResolvers.resolveBoxConstraints` | ✅ |
| transformAlignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

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
| spacing | double? | `TomCtr.doubleVal` | ✅ |
| runSpacing | double? | `TomCtr.doubleVal` | ✅ |

#### TomStack

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |


#### TomAlign

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| widthFactor | double? | `TomCtr.doubleVal` | ✅ |
| heightFactor | double? | `TomCtr.doubleVal` | ✅ |

#### TomAspectRatio

No resource-loadable parameters.

#### TomBaseline

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| baseline | double? | `TomCtr.doubleOrFail` | ✅ |

#### TomCarouselView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| itemExtent | double? | `TomCtr.doubleVal` | ✅ |
| shrinkExtent | double? | `TomCtr.doubleVal` | ✅ |

#### TomCenter

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| widthFactor | double? | `TomCtr.doubleVal` | ✅ |
| heightFactor | double? | `TomCtr.doubleVal` | ✅ |

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
| color | Color? | `TomCtr.colorOrFail` | ✅ |

#### TomConstrainedBox

No resource-loadable parameters.

#### TomConstraintsTransformBox

No resource-loadable parameters.

#### TomCupertinoExpansionTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrFail` | ✅ |

#### TomCupertinoFormRow

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomCupertinoFormSection

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoPageScaffold

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoScrollbar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| thumbVisibility | bool? | `TomCtr.boolVal` | ✅ |
| thickness | double? | `TomCtr.doubleVal` | ✅ |
| thicknessWhileDragging | double? | `TomCtr.doubleVal` | ✅ |

#### TomCupertinoTabScaffold

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoTabView

No resource-loadable parameters.

#### TomCustomMultiChildLayout

No resource-loadable parameters.

#### TomCustomPaint

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| isComplex | bool? | `TomCtr.boolVal` | ✅ |
| willChange | bool? | `TomCtr.boolVal` | ✅ |

#### TomCustomScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| cacheExtent | double? | `TomCtr.doubleVal` | ✅ |

#### TomCustomSingleChildLayout

No resource-loadable parameters.

#### TomDecoratedBox

No resource-loadable parameters.

#### TomDraggableScrollableSheet

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| initialChildSize | double? | `TomCtr.doubleVal` | ✅ |
| minChildSize | double? | `TomCtr.doubleVal` | ✅ |
| maxChildSize | double? | `TomCtr.doubleVal` | ✅ |
| expand | bool? | `TomCtr.boolVal` | ✅ |
| snap | bool? | `TomCtr.boolVal` | ✅ |
| shouldCloseOnMinExtent | bool? | `TomCtr.boolVal` | ✅ |

#### TomExpanded

No resource-loadable parameters.

#### TomExpansionPanel

No resource-loadable parameters.

#### TomExpansionPanelList

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| dividerColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| expandedHeaderPadding | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |

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
| widthFactor | double? | `TomCtr.doubleVal` | ✅ |
| heightFactor | double? | `TomCtr.doubleVal` | ✅ |

#### TomGridTile

No resource-loadable parameters.

#### TomGridTileBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |

#### TomIndexedStack

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| index | int? | `TomCtr.intVal` | ✅ |
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomInk

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| decoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

#### TomInteractiveViewer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| boundaryMargin | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |
| constrained | bool? | `TomCtr.boolVal` | ✅ |
| maxScale | double? | `TomCtr.doubleVal` | ✅ |
| minScale | double? | `TomCtr.doubleVal` | ✅ |
| interactionEndFrictionCoefficient | double? | `TomCtr.doubleVal` | ✅ |
| panEnabled | bool? | `TomCtr.boolVal` | ✅ |
| scaleEnabled | bool? | `TomCtr.boolVal` | ✅ |
| scaleFactor | double? | `TomCtr.doubleVal` | ✅ |
| alignment | Alignment? | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomIntrinsicHeight

No resource-loadable parameters.

#### TomIntrinsicWidth

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| stepWidth | double? | `TomCtr.doubleVal` | ✅ |
| stepHeight | double? | `TomCtr.doubleVal` | ✅ |

#### TomLimitedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| maxWidth | double? | `TomCtr.doubleVal` | ✅ |
| maxHeight | double? | `TomCtr.doubleVal` | ✅ |

#### TomListBody

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| reverse | bool? | `TomCtr.boolVal` | ✅ |

#### TomMaterial

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| textStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| borderRadius | BorderRadiusGeometry? | `TomStyleResolvers.resolveBorderRadius` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |

#### TomNestedScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| physics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |
| floatHeaderSlivers | bool? | `TomCtr.boolVal` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |

#### TomOffstage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| offstage | bool | `TomCtr.boolVal` | ✅ |

#### TomOpacity

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opacity | double? | `TomCtr.doubleOrFail` | ✅ |

#### TomOverflowBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| spacing | double? | `TomCtr.doubleVal` | ✅ |
| overflowSpacing | double? | `TomCtr.doubleVal` | ✅ |

#### TomOverflowBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| minWidth | double? | `TomCtr.doubleVal` | ✅ |
| maxWidth | double? | `TomCtr.doubleVal` | ✅ |
| minHeight | double? | `TomCtr.doubleVal` | ✅ |
| maxHeight | double? | `TomCtr.doubleVal` | ✅ |

#### TomPadding

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry | `TomCtr.edgeInsets` | ✅ |

#### TomPhysicalModel

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| borderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.colorOrFail` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |

#### TomPhysicalShape

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.colorOrFail` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |

#### TomPositioned

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| left | double? | `TomCtr.doubleVal` | ✅ |
| top | double? | `TomCtr.doubleVal` | ✅ |
| right | double? | `TomCtr.doubleVal` | ✅ |
| bottom | double? | `TomCtr.doubleVal` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

#### TomPositionedDirectional

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| start | double? | `TomCtr.doubleVal` | ✅ |
| top | double? | `TomCtr.doubleVal` | ✅ |
| end | double? | `TomCtr.doubleVal` | ✅ |
| bottom | double? | `TomCtr.doubleVal` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

#### TomRotatedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| quarterTurns | int? | `TomCtr.intOrFail` | ✅ |

#### TomSafeArea

No resource-loadable parameters.

#### TomScrollbar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| thumbVisibility | bool? | `TomCtr.boolVal` | ✅ |
| trackVisibility | bool? | `TomCtr.boolVal` | ✅ |
| thickness | double? | `TomCtr.doubleVal` | ✅ |
| interactive | bool? | `TomCtr.boolVal` | ✅ |

#### TomSingleChildScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| physics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |

#### TomSizedBox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

#### TomSizedOverflowBox

No resource-loadable parameters.

#### TomSliverAppBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| scrolledUnderElevation | double? | `TomCtr.doubleVal` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| foregroundColor | Color? | `TomCtr.color` | ✅ |
| iconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |
| actionsIconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |
| titleSpacing | double? | `TomCtr.doubleVal` | ✅ |
| expandedHeight | double? | `TomCtr.doubleVal` | ✅ |
| collapsedHeight | double? | `TomCtr.doubleVal` | ✅ |
| leadingWidth | double? | `TomCtr.doubleVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| toolbarTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| titleTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |

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
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| transformHitTests | bool? | `TomCtr.boolVal` | ✅ |

#### TomUnconstrainedBox

No resource-loadable parameters.

#### TomVisibility

No resource-loadable parameters.

---

### ACL Container (`acl/tom_acl.dart`)

#### TomAclBuilder

> **Note:** TomAclBuilder is a builder class, not a standard Tom widget, so it
> resolves nothing itself: its constructor records whether each parameter was
> supplied explicitly and hands the values to the internal `AclBuilder`. The
> resolution happens later, in `acl_container.dart`, against the container path
> and using the same `TomCtr` / `TomStyleResolvers` statics as everything else —
> the `_explicit*` flags are what tell the container whether it may fall back to
> a resource. The resolvers named below are therefore the ones that ultimately
> read each parameter, not calls the builder makes.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| title | String? | `TomCtr.textOrNull` | ⛔ |
| padding | EdgeInsetsGeometry | `TomCtr.edgeInsets` | ⛔ |
| backgroundColor | Color? | `TomCtr.color` | ⛔ |
| titleStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ⛔ |
| titleVerticalOffset | double | `TomCtr.doubleVal` | ⛔ |

---

### Dialogs (`tom_dialogs.dart`)

#### TomAlertDialog

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| iconPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| iconColor | Color? | `TomCtr.color` | ✅ |
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| titlePadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| titleTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| contentPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| contentTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| actionsPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| actionsOverflowButtonSpacing | double? | `TomCtr.doubleVal` | ✅ |
| buttonPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |
| insetPadding | EdgeInsets | `TomCtr.edgeInsets` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| scrollable | bool | `TomCtr.boolVal` | ✅ |

#### TomSimpleDialog

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| titlePadding | EdgeInsets | `TomCtr.edgeInsets` | ✅ |
| titleTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| contentPadding | EdgeInsets | `TomCtr.edgeInsets` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |
| insetPadding | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomDialog

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| insetPadding | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |

#### TomBottomSheet

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| constraints | BoxConstraints? | `TomStyleResolvers.resolveBoxConstraints` | ✅ |
| enableDrag | bool | `TomCtr.boolVal` | ✅ |
| showDragHandle | bool? | `TomCtr.boolVal` | ✅ |

#### TomSnackBar

> **Note:** TomSnackBar extends SnackBar directly with `super.` parameters and uses `TomWidgetMixin`, not `TomDialogBase`. It has no `buildContent()` method — params are passed via the super constructor. These params cannot use the standard resource resolution pattern.

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ⛔ |
| elevation | double? | `TomCtr.doubleVal` | ⛔ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ⛔ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ⛔ |
| width | double? | `TomCtr.doubleVal` | ⛔ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ⛔ |
| showCloseIcon | bool? | `TomCtr.boolVal` | ⛔ |
| closeIconColor | Color? | `TomCtr.color` | ⛔ |
| actionOverflowThreshold | double? | `TomCtr.doubleVal` | ⛔ |

#### TomMaterialBanner

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| contentTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| dividerColor | Color? | `TomCtr.color` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| leadingPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| forceActionsBelow | bool | `TomCtr.boolVal` | ✅ |


#### TomAboutDialog

No resource-loadable parameters.

#### TomCupertinoActionSheet

No resource-loadable parameters.

#### TomCupertinoAlertDialog

No resource-loadable parameters.

#### TomCupertinoContextMenu

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| enableHapticFeedback | bool? | `TomCtr.boolVal` | ✅ |

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
| backgroundColor | Color? | `TomCtr.color` | ⛔ |
| elevation | double? | `TomCtr.doubleVal` | ⛔ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ⛔ |
| constraints | BoxConstraints? | `TomStyleResolvers.resolveBoxConstraints` | ⛔ |

#### TomSimpleDialogOption

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |

#### TomTimePickerDialog

No resource-loadable parameters.

#### TomTooltip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| height | double? | `TomCtr.doubleVal` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| verticalOffset | double? | `TomCtr.doubleVal` | ✅ |
| decoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| textStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |

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
| size | double? | `TomCtr.doubleVal` | ✅ |
| fill | double? | `TomCtr.doubleVal` | ✅ |
| weight | double? | `TomCtr.doubleVal` | ✅ |
| grade | double? | `TomCtr.doubleVal` | ✅ |
| opticalSize | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |

#### TomImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| matchTextDirection | bool | `TomCtr.boolVal` | ✅ |
| gaplessPlayback | bool | `TomCtr.boolVal` | ✅ |
| isAntiAlias | bool | `TomCtr.boolVal` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |

#### TomCircleAvatar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| foregroundColor | Color? | `TomCtr.color` | ✅ |
| radius | double? | `TomCtr.doubleVal` | ✅ |
| minRadius | double? | `TomCtr.doubleVal` | ✅ |
| maxRadius | double? | `TomCtr.doubleVal` | ✅ |

#### TomFadeInImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| matchTextDirection | bool | `TomCtr.boolVal` | ✅ |
| excludeFromSemantics | bool | `TomCtr.boolVal` | ✅ |
| imageSemanticLabel | String? | `TomCtr.textOrNull` | ✅ |
| placeholderColor | Color? | `TomCtr.color` | ✅ |

#### TomImageIcon

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| size | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |

#### TomInkImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

#### TomNetworkImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| src | String | `TomCtr.text` | ✅ |
| scale | double | `TomCtr.doubleVal` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| matchTextDirection | bool | `TomCtr.boolVal` | ✅ |
| gaplessPlayback | bool | `TomCtr.boolVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |
| excludeFromSemantics | bool | `TomCtr.boolVal` | ✅ |


#### TomAnimatedIcon

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | `TomCtr.color` | ✅ |
| size | double? | `TomCtr.doubleVal` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |

#### TomAssetImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| cacheWidth | int? | `TomCtr.intVal` | ✅ |
| cacheHeight | int? | `TomCtr.intVal` | ✅ |

#### TomFileImage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |

#### TomImageFiltered

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| enabled | bool? | `TomCtr.boolVal` | ✅ |

---

### Inputs (`tom_inputs.dart`)

#### TomTextField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | InputDecoration? | `TomStyleResolvers.resolveInputDecoration` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| strutStyle | StrutStyle? | `TomStyleResolvers.resolveStrutStyle` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| obscureText | bool | `TomCtr.boolVal` | ✅ |
| autocorrect | bool | `TomCtr.boolVal` | ✅ |
| enableSuggestions | bool | `TomCtr.boolVal` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| minLines | int? | `TomCtr.intVal` | ✅ |
| expands | bool | `TomCtr.boolVal` | ✅ |
| maxLength | int? | `TomCtr.intVal` | ✅ |
| enabled | bool | `TomCtr.boolVal` | ✅ |
| readOnly | bool | `TomCtr.boolVal` | ✅ |
| showCursor | bool? | `TomCtr.boolVal` | ✅ |
| obscuringCharacter | String? | `TomCtr.textOrNull` | ✅ |
| cursorWidth | double? | `TomCtr.doubleVal` | ✅ |
| cursorHeight | double? | `TomCtr.doubleVal` | ✅ |
| cursorColor | Color? | `TomCtr.color` | ✅ |
| cursorErrorColor | Color? | `TomCtr.color` | ✅ |
| scrollPadding | EdgeInsets | `TomCtr.edgeInsets` | ✅ |
| enableInteractiveSelection | bool? | `TomCtr.boolVal` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |
| scribbleEnabled | bool | `TomCtr.boolVal` | ✅ |
| enableIMEPersonalizedLearning | bool | `TomCtr.boolVal` | ✅ |
| canRequestFocus | bool | `TomCtr.boolVal` | ✅ |
| scrollPhysics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |
| label | String? | `TomCtr.textOrNull` | ✅ |
| hint | String? | `TomCtr.textOrNull` | ✅ |

#### TomTextFormField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | InputDecoration? | `TomStyleResolvers.resolveInputDecoration` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| obscureText | bool | `TomCtr.boolVal` | ✅ |
| autocorrect | bool | `TomCtr.boolVal` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| minLines | int? | `TomCtr.intVal` | ✅ |
| maxLength | int? | `TomCtr.intVal` | ✅ |
| initialValue | String? | `TomCtr.textOrNull` | ✅ |
| enabled | bool | `TomCtr.boolVal` | ✅ |
| readOnly | bool | `TomCtr.boolVal` | ✅ |
| label | String? | `TomCtr.textOrNull` | ✅ |
| hint | String? | `TomCtr.textOrNull` | ✅ |

#### TomSearchBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| hintText | String? | `TomCtr.textOrNull` | ✅ |
| constraints | BoxConstraints? | `TomStyleResolvers.resolveBoxConstraints` | ✅ |
| autoFocus | bool | `TomCtr.boolVal` | ✅ |

> **Note:** TomSearchBar wraps elevation, backgroundColor, surfaceTintColor,
> textStyle and others in `WidgetStateProperty<X>`. The colour-valued ones are
> resolvable through `TomCtr.widgetStateColor`, which reads a default plus
> per-state overrides; the rest have no state-aware resolver, so `elevation`
> (`double`) and `textStyle` (`TextStyle`) cannot currently be resource-resolved.


#### TomAutocomplete

No resource-loadable parameters.

#### TomCalendarDatePicker

No resource-loadable parameters.

#### TomCupertinoDatePicker

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| itemExtent | double? | `TomCtr.doubleVal` | ✅ |

#### TomCupertinoSearchTextField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| placeholder | String? | `TomCtr.textOrNull` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| placeholderStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| borderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| itemColor | Color? | `TomCtr.color` | ✅ |
| itemSize | double? | `TomCtr.doubleVal` | ✅ |

#### TomCupertinoTextField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| placeholder | String? | `TomCtr.textOrNull` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| minLines | int? | `TomCtr.intVal` | ✅ |
| maxLength | int? | `TomCtr.intVal` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| placeholderStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |

#### TomCupertinoTextFormFieldRow

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| placeholder | String? | `TomCtr.textOrNull` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| cursorWidth | double? | `TomCtr.doubleVal` | ✅ |
| cursorHeight | double? | `TomCtr.doubleVal` | ✅ |
| cursorColor | Color? | `TomCtr.color` | ✅ |
| scrollPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomCupertinoTimerPicker

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| itemExtent | double? | `TomCtr.doubleVal` | ✅ |

#### TomDropdownMenuFormField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| label | String? | `TomCtr.textOrNull` | ✅ |
| hintText | String? | `TomCtr.textOrNull` | ✅ |
| helperText | String? | `TomCtr.textOrNull` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| menuHeight | double? | `TomCtr.doubleVal` | ✅ |
| expandedInsets | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| textStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |

#### TomEditableText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundCursorColor | Color? | `TomCtr.color` | ✅ |
| selectionColor | Color? | `TomCtr.color` | ✅ |
| cursorHeight | double? | `TomCtr.doubleVal` | ✅ |
| cursorWidth | double? | `TomCtr.doubleVal` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| minLines | int? | `TomCtr.intVal` | ✅ |

#### TomForm

No resource-loadable parameters.

#### TomInputDatePickerFormField

No resource-loadable parameters.

#### TomSearchAnchor

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| viewHintText | String? | `TomCtr.textOrNull` | ✅ |
| viewBackgroundColor | Color? | `TomCtr.color` | ✅ |
| viewElevation | double? | `TomCtr.doubleVal` | ✅ |
| viewSurfaceTintColor | Color? | `TomCtr.color` | ✅ |
| dividerColor | Color? | `TomCtr.color` | ✅ |
| headerTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| headerHintStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |

#### TomYearPicker

No resource-loadable parameters.

---

### Interactions (`tom_interactions.dart`)

#### TomGestureDetector

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| excludeFromSemantics | bool? | `TomCtr.boolVal` | ✅ |
| trackpadScrollCausesScale | bool? | `TomCtr.boolVal` | ✅ |
| trackpadScrollToScaleFactor | Offset | `TomStyleResolvers.resolveOffset` | ✅ |

#### TomInkWell

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| focusColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| highlightColor | Color? | `TomCtr.color` | ✅ |
| splashColor | Color? | `TomCtr.color` | ✅ |
| radius | double? | `TomCtr.doubleVal` | ✅ |
| borderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |
| customBorder | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| excludeFromSemantics | bool | `TomCtr.boolVal` | ✅ |
| canRequestFocus | bool | `TomCtr.boolVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |

#### TomInkResponse

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| containedInkWell | bool? | `TomCtr.boolVal` | ✅ |
| radius | double? | `TomCtr.doubleVal` | ✅ |
| borderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |
| customBorder | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| highlightColor | Color? | `TomCtr.color` | ✅ |
| splashColor | Color? | `TomCtr.color` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| excludeFromSemantics | bool? | `TomCtr.boolVal` | ✅ |
| autofocus | bool? | `TomCtr.boolVal` | ✅ |
| canRequestFocus | bool? | `TomCtr.boolVal` | ✅ |

#### TomDraggable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| feedbackOffset | Offset | `TomStyleResolvers.resolveOffset` | ✅ |
| maxSimultaneousDrags | int? | `TomCtr.intVal` | ✅ |
| ignoringFeedbackSemantics | bool? | `TomCtr.boolVal` | ✅ |
| ignoringFeedbackPointer | bool? | `TomCtr.boolVal` | ✅ |
| rootOverlay | bool? | `TomCtr.boolVal` | ✅ |


#### TomAbsorbPointer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| absorbing | bool? | `TomCtr.boolVal` | ✅ |

#### TomCupertinoMagnifier

No resource-loadable parameters.

#### TomDragTarget

No resource-loadable parameters.

#### TomIgnorePointer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| ignoring | bool? | `TomCtr.boolVal` | ✅ |

#### TomLongPressDraggable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| maxSimultaneousDrags | int? | `TomCtr.intVal` | ✅ |
| hapticFeedbackOnStart | bool? | `TomCtr.boolVal` | ✅ |
| ignoringFeedbackSemantics | bool? | `TomCtr.boolVal` | ✅ |
| ignoringFeedbackPointer | bool? | `TomCtr.boolVal` | ✅ |

#### TomMouseRegion

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opaque | bool? | `TomCtr.boolVal` | ✅ |
| hitTestBehavior | HitTestBehavior? | `TomCtr.textOrNull` | ✅ |

---

### Labels (`tom_labels.dart`)

#### TomText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| data | String? | `TomCtr.textOrNull` | ✅ |
| text | String? | `TomCtr.textOrNull` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| strutStyle | StrutStyle? | `TomStyleResolvers.resolveStrutStyle` | ✅ |
| softWrap | bool? | `TomCtr.boolVal` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| semanticsLabel | String? | `TomCtr.textOrNull` | ✅ |
| textHeightBehavior | TextHeightBehavior? | `TomStyleResolvers.resolveTextHeightBehavior` | ✅ |

#### TomSelectableText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| data | String? | `TomCtr.textOrNull` | ✅ |
| text | String? | `TomCtr.textOrNull` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| strutStyle | StrutStyle? | `TomStyleResolvers.resolveStrutStyle` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| minLines | int? | `TomCtr.intVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| showCursor | bool | `TomCtr.boolVal` | ✅ |
| cursorWidth | double | `TomCtr.doubleVal` | ✅ |
| cursorHeight | double? | `TomCtr.doubleVal` | ✅ |
| cursorColor | Color? | `TomCtr.color` | ✅ |
| scrollPhysics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |
| semanticsLabel | String? | `TomCtr.textOrNull` | ✅ |
| textHeightBehavior | TextHeightBehavior? | `TomStyleResolvers.resolveTextHeightBehavior` | ✅ |

#### TomRichText

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| softWrap | bool | `TomCtr.boolVal` | ✅ |
| maxLines | int? | `TomCtr.intVal` | ✅ |
| strutStyle | StrutStyle? | `TomStyleResolvers.resolveStrutStyle` | ✅ |
| textHeightBehavior | TextHeightBehavior? | `TomStyleResolvers.resolveTextHeightBehavior` | ✅ |
| selectionColor | Color? | `TomCtr.color` | ✅ |

#### TomBadge

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | `TomCtr.textOrNull` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| textColor | Color? | `TomCtr.color` | ✅ |
| textStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| alignment | AlignmentGeometry? | `TomStyleResolvers.resolveAlignment` | ✅ |
| offset | Offset? | `TomStyleResolvers.resolveOffset` | ✅ |
| isLabelVisible | bool | `TomCtr.boolVal` | ✅ |
| smallSize | double? | `TomCtr.doubleVal` | ✅ |
| largeSize | double? | `TomCtr.doubleVal` | ✅ |

#### TomListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| isThreeLine | bool | `TomCtr.boolVal` | ✅ |
| dense | bool? | `TomCtr.boolVal` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |
| iconColor | Color? | `TomCtr.color` | ✅ |
| textColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| splashColor | Color? | `TomCtr.color` | ✅ |
| tileColor | Color? | `TomCtr.color` | ✅ |
| selectedTileColor | Color? | `TomCtr.color` | ✅ |
| titleTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| subtitleTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| leadingAndTrailingTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| contentPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| enabled | bool | `TomCtr.boolVal` | ✅ |
| selected | bool | `TomCtr.boolVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| horizontalTitleGap | double? | `TomCtr.doubleVal` | ✅ |
| minVerticalPadding | double? | `TomCtr.doubleVal` | ✅ |
| minLeadingWidth | double? | `TomCtr.doubleVal` | ✅ |
| minTileHeight | double? | `TomCtr.doubleVal` | ✅ |


#### TomAboutListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| applicationName | String? | `TomCtr.textOrNull` | ✅ |
| applicationVersion | String? | `TomCtr.textOrNull` | ✅ |
| applicationLegalese | String? | `TomCtr.textOrNull` | ✅ |

#### TomBanner

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| message | String? | `TomCtr.textOrNull` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |

#### TomChip

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| labelText | String? | `TomCtr.textOrNull` | ✅ |
| deleteIconColor | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| labelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |

#### TomDefaultTextStyle

No resource-loadable parameters.

#### TomListTileTitle

No resource-loadable parameters.

#### TomListTileSubtitle

No resource-loadable parameters.

#### TomMenuAcceleratorLabel

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| label | String? | `TomCtr.textOrNull` | ✅ |

#### TomMergeSemantics

No resource-loadable parameters.

#### TomSemantics

No resource-loadable parameters.

#### TomVerticalDivider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| width | double? | `TomCtr.doubleVal` | ✅ |
| thickness | double? | `TomCtr.doubleVal` | ✅ |
| indent | double? | `TomCtr.doubleVal` | ✅ |
| endIndent | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |

---

### Lists (`tom_lists.dart`)

#### TomListView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| reverse | bool | `TomCtr.boolVal` | ✅ |
| primary | bool? | `TomCtr.boolVal` | ✅ |
| shrinkWrap | bool | `TomCtr.boolVal` | ✅ |
| physics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| itemExtent | double? | `TomCtr.doubleVal` | ✅ |
| cacheExtent | double? | `TomCtr.doubleVal` | ✅ |
| semanticChildCount | int? | `TomCtr.intVal` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |
| addAutomaticKeepAlives | bool | `TomCtr.boolVal` | ✅ |
| addRepaintBoundaries | bool | `TomCtr.boolVal` | ✅ |
| addSemanticIndexes | bool | `TomCtr.boolVal` | ✅ |

#### TomAnimatedList

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| initialItemCount | int | `TomCtr.intVal` | ✅ |
| reverse | bool | `TomCtr.boolVal` | ✅ |
| primary | bool? | `TomCtr.boolVal` | ✅ |
| shrinkWrap | bool | `TomCtr.boolVal` | ✅ |
| physics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomDismissible

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| crossAxisEndOffset | double? | `TomCtr.doubleVal` | ✅ |

#### TomListWheelScrollView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| diameterRatio | double? | `TomCtr.doubleVal` | ✅ |
| perspective | double? | `TomCtr.doubleVal` | ✅ |
| offAxisFraction | double? | `TomCtr.doubleVal` | ✅ |
| useMagnifier | bool | `TomCtr.boolVal` | ✅ |
| magnification | double? | `TomCtr.doubleVal` | ✅ |
| overAndUnderCenterOpacity | double? | `TomCtr.doubleVal` | ✅ |
| itemExtent | double? | `TomCtr.doubleOrFail` | ✅ |
| squeeze | double? | `TomCtr.doubleVal` | ✅ |
| renderChildrenOutsideViewport | bool | `TomCtr.boolVal` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |

#### TomCupertinoListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| leadingSize | double? | `TomCtr.doubleVal` | ✅ |
| leadingToTitle | double? | `TomCtr.doubleVal` | ✅ |


#### TomCupertinoListSection

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| topMargin | double? | `TomCtr.doubleVal` | ✅ |
| hasLeading | bool? | `TomCtr.boolVal` | ✅ |
| additionalDividerMargin | double? | `TomCtr.doubleVal` | ✅ |

---

### Navigation (`tom_navigation.dart`)

#### TomNavigationRail

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| selectedIndex | int? | `TomCtr.intVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| minWidth | double? | `TomCtr.doubleVal` | ✅ |
| minExtendedWidth | double? | `TomCtr.doubleVal` | ✅ |
| indicatorColor | Color? | `TomCtr.color` | ✅ |
| indicatorShape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| useIndicator | bool? | `TomCtr.boolVal` | ✅ |
| groupAlignment | double? | `TomCtr.doubleVal` | ✅ |
| selectedLabelTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| unselectedLabelTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| selectedIconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |
| unselectedIconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |
| extended | bool | `TomCtr.boolVal` | ✅ |

#### TomNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| selectedIndex | int | `TomCtr.intVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| indicatorColor | Color? | `TomCtr.color` | ✅ |
| indicatorShape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

> **Note:** TomNavigationBar uses `WidgetStateProperty<TextStyle?>` for labelTextStyle and `WidgetStateProperty<IconThemeData?>` for iconTheme — these cannot be directly resource-resolved.

#### TomTabBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| isScrollable | bool | `TomCtr.boolVal` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| indicatorColor | Color? | `TomCtr.color` | ✅ |
| indicatorWeight | double? | `TomCtr.doubleVal` | ✅ |
| indicatorPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| indicator | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| dividerColor | Color? | `TomCtr.color` | ✅ |
| dividerHeight | double? | `TomCtr.doubleVal` | ✅ |
| labelColor | Color? | `TomCtr.color` | ✅ |
| unselectedLabelColor | Color? | `TomCtr.color` | ✅ |
| labelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| unselectedLabelStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| labelPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| automaticIndicatorColorAdjustment | bool | `TomCtr.boolVal` | ✅ |
| splashBorderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |

#### TomNavigationDrawer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| selectedIndex | int? | `TomCtr.intVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| indicatorColor | Color? | `TomCtr.color` | ✅ |
| indicatorShape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| tilePadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomDrawer

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |

#### TomBottomNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| currentIndex | int | `TomCtr.intVal` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| iconSize | double? | `TomCtr.doubleVal` | ✅ |
| selectedItemColor | Color? | `TomCtr.color` | ✅ |
| unselectedItemColor | Color? | `TomCtr.color` | ✅ |
| selectedIconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |
| unselectedIconTheme | IconThemeData? | `TomStyleResolvers.resolveIconThemeData` | ✅ |


#### TomBreadcrumb

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomCupertinoNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoNavigationBarBackButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| previousPageTitle | String? | `TomCtr.textOrNull` | ✅ |

#### TomCupertinoSliverNavigationBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| previousPageTitle | String? | `TomCtr.textOrNull` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoTabBar

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| iconSize | double? | `TomCtr.doubleVal` | ✅ |
| height | double? | `TomCtr.doubleVal` | ✅ |

#### TomDrawerHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| margin | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomFlexibleSpaceBar

No resource-loadable parameters.

#### TomNavigationDestination

No resource-loadable parameters.

#### TomNavigationDrawerDestination

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |

#### TomPageView

No resource-loadable parameters.

#### TomStepper

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| physics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| connectorThickness | double? | `TomCtr.doubleVal` | ✅ |
| connectorColor | Color? | `TomCtr.color` | ✅ |

#### TomTab

No resource-loadable parameters.

#### TomTabBarView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| viewportFraction | double? | `TomCtr.doubleVal` | ✅ |

#### TomTabPageSelector

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| indicatorSize | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |

#### TomUserAccountsDrawerHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| arrowColor | Color? | `TomCtr.color` | ✅ |

---

### Progress (`tom_progress.dart`)

#### TomCircularProgressIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| value | double? | `TomCtr.doubleVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| strokeWidth | double? | `TomCtr.doubleVal` | ✅ |
| strokeAlign | double | `TomCtr.doubleVal` | ✅ |
| semanticsLabel | String? | `TomCtr.textOrNull` | ✅ |
| semanticsValue | String? | `TomCtr.textOrNull` | ✅ |

#### TomLinearProgressIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| value | double? | `TomCtr.doubleVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| minHeight | double? | `TomCtr.doubleVal` | ✅ |
| semanticsLabel | String? | `TomCtr.textOrNull` | ✅ |
| semanticsValue | String? | `TomCtr.textOrNull` | ✅ |
| borderRadius | BorderRadiusGeometry? | `TomStyleResolvers.resolveBorderRadius` | ✅ |

#### TomRefreshIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| displacement | double | `TomCtr.doubleVal` | ✅ |
| edgeOffset | double | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| semanticsLabel | String? | `TomCtr.textOrNull` | ✅ |
| semanticsValue | String? | `TomCtr.textOrNull` | ✅ |
| strokeWidth | double | `TomCtr.doubleVal` | ✅ |

#### TomCupertinoActivityIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| animating | bool | `TomCtr.boolVal` | ✅ |
| radius | double | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoLinearActivityIndicator

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| value | double? | `TomCtr.doubleVal` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| trackHeight | double? | `TomCtr.doubleVal` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomCupertinoSliverRefreshControl

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| refreshTriggerPullDistance | double? | `TomCtr.doubleVal` | ✅ |
| refreshIndicatorExtent | double? | `TomCtr.doubleVal` | ✅ |

---

### Selects (`tom_selects.dart`)

#### TomDropdownButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| elevation | int? | `TomCtr.intVal` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| iconDisabledColor | Color? | `TomCtr.color` | ✅ |
| iconEnabledColor | Color? | `TomCtr.color` | ✅ |
| iconSize | double? | `TomCtr.doubleVal` | ✅ |
| isDense | bool | `TomCtr.boolVal` | ✅ |
| isExpanded | bool | `TomCtr.boolVal` | ✅ |
| itemHeight | double? | `TomCtr.doubleVal` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| dropdownColor | Color? | `TomCtr.color` | ✅ |
| menuMaxHeight | double? | `TomCtr.doubleVal` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| borderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| hint | String? | `TomCtr.textOrNull` | ✅ |

#### TomPopupMenuButton

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| tooltip | String? | `TomCtr.textOrNull` | ✅ |
| elevation | double? | `TomCtr.doubleVal` | ✅ |
| shadowColor | Color? | `TomCtr.color` | ✅ |
| surfaceTintColor | Color? | `TomCtr.color` | ✅ |
| padding | EdgeInsetsGeometry | `TomCtr.edgeInsets` | ✅ |
| iconSize | double? | `TomCtr.doubleVal` | ✅ |
| offset | Offset? | `TomStyleResolvers.resolveOffset` | ✅ |
| enabled | bool | `TomCtr.boolVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| color | Color? | `TomCtr.color` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| constraints | BoxConstraints? | `TomStyleResolvers.resolveBoxConstraints` | ✅ |

#### TomDropdownMenu

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| enabled | bool | `TomCtr.boolVal` | ✅ |
| width | double? | `TomCtr.doubleVal` | ✅ |
| menuHeight | double? | `TomCtr.doubleVal` | ✅ |
| label | String? | `TomCtr.textOrNull` | ✅ |
| hintText | String? | `TomCtr.textOrNull` | ✅ |
| helperText | String? | `TomCtr.textOrNull` | ✅ |
| errorText | String? | `TomCtr.textOrNull` | ✅ |
| enableFilter | bool | `TomCtr.boolVal` | ✅ |
| enableSearch | bool | `TomCtr.boolVal` | ✅ |
| textStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| expandedInsets | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |
| menuStyle | MenuStyle? | `TomStyleResolvers.resolveMenuStyle` | ✅ |
| requestFocusOnTap | bool | `TomCtr.boolVal` | ✅ |

#### TomMenuAnchor

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| alignmentOffset | Offset? | `TomStyleResolvers.resolveOffset` | ✅ |
| consumeOutsideTap | bool | `TomCtr.boolVal` | ✅ |
| style | MenuStyle? | `TomStyleResolvers.resolveMenuStyle` | ✅ |

#### TomDropdownButtonFormField

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | InputDecoration? | `TomStyleResolvers.resolveInputDecoration` | ✅ |
| elevation | int? | `TomCtr.intVal` | ✅ |
| style | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| iconDisabledColor | Color? | `TomCtr.color` | ✅ |
| iconEnabledColor | Color? | `TomCtr.color` | ✅ |
| iconSize | double? | `TomCtr.doubleVal` | ✅ |
| isDense | bool | `TomCtr.boolVal` | ✅ |
| isExpanded | bool | `TomCtr.boolVal` | ✅ |
| itemHeight | double? | `TomCtr.doubleVal` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| dropdownColor | Color? | `TomCtr.color` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| menuMaxHeight | double? | `TomCtr.doubleVal` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| alignment | AlignmentGeometry | `TomStyleResolvers.resolveAlignment` | ✅ |
| borderRadius | BorderRadius? | `TomStyleResolvers.resolveBorderRadius` | ✅ |


#### TomCheckedPopupMenuItem

No resource-loadable parameters.

#### TomCupertinoPicker

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| diameterRatio | double? | `TomCtr.doubleVal` | ✅ |
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| offAxisFraction | double? | `TomCtr.doubleVal` | ✅ |
| magnification | double? | `TomCtr.doubleVal` | ✅ |
| squeeze | double? | `TomCtr.doubleVal` | ✅ |
| itemExtent | double? | `TomCtr.doubleVal` | ✅ |

#### TomCupertinoSegmentedControl

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| unselectedColor | Color? | `TomCtr.color` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |
| borderColor | Color? | `TomCtr.color` | ✅ |
| pressedColor | Color? | `TomCtr.color` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomCupertinoSlidingSegmentedControl

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| backgroundColor | Color? | `TomCtr.color` | ✅ |
| thumbColor | Color? | `TomCtr.color` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

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
| min | double | `TomCtr.doubleVal` | ✅ |
| max | double | `TomCtr.doubleVal` | ✅ |
| divisions | int? | `TomCtr.intVal` | ✅ |
| label | String? | `TomCtr.textOrNull` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| inactiveColor | Color? | `TomCtr.color` | ✅ |
| thumbColor | Color? | `TomCtr.color` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |

#### TomRangeSlider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| min | double | `TomCtr.doubleVal` | ✅ |
| max | double | `TomCtr.doubleVal` | ✅ |
| divisions | int? | `TomCtr.intVal` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| inactiveColor | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoSlider

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| min | double | `TomCtr.doubleVal` | ✅ |
| max | double | `TomCtr.doubleVal` | ✅ |
| divisions | int? | `TomCtr.intVal` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| thumbColor | Color | `TomCtr.color` | ✅ |

---

### Slivers (`tom_slivers.dart`)

#### TomDecoratedSliver

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| decoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |

#### TomSliverConstrainedCrossAxis

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| maxExtent | double? | `TomCtr.doubleOrFail` | ✅ |

#### TomSliverCrossAxisExpanded

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| flex | int? | `TomCtr.intVal` | ✅ |

#### TomSliverFillViewport

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| viewportFraction | double? | `TomCtr.doubleVal` | ✅ |
| padEnds | bool | `TomCtr.boolVal` | ✅ |

#### TomSliverFixedExtentList

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| itemExtent | double? | `TomCtr.doubleOrFail` | ✅ |

#### TomSliverOffstage

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| offstage | bool? | `TomCtr.boolVal` | ✅ |

#### TomSliverOpacity

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| opacity | double? | `TomCtr.doubleOrFail` | ✅ |
| alwaysIncludeSemantics | bool? | `TomCtr.boolVal` | ✅ |

#### TomSliverPadding

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |

#### TomSliverPersistentHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| pinned | bool? | `TomCtr.boolVal` | ✅ |
| floating | bool? | `TomCtr.boolVal` | ✅ |

#### TomSliverResizingHeader

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| _(minExtentPrototype/maxExtentPrototype are doubles but semantically not resource values)_ | | | |

#### TomSliverSafeArea

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| left | bool? | `TomCtr.boolVal` | ✅ |
| top | bool? | `TomCtr.boolVal` | ✅ |
| right | bool? | `TomCtr.boolVal` | ✅ |
| bottom | bool? | `TomCtr.boolVal` | ✅ |
| minimum | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |

#### TomSliverVisibility

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| visible | bool | `TomCtr.boolVal` | ✅ |
| maintainSize | bool | `TomCtr.boolVal` | ✅ |
| maintainAnimation | bool | `TomCtr.boolVal` | ✅ |
| maintainState | bool | `TomCtr.boolVal` | ✅ |

#### TomPinnedHeaderSliver, TomSliverCrossAxisGroup, TomSliverFloatingHeader, TomSliverMainAxisGroup, TomSliverPrototypeExtentList, TomSliverVariedExtentList

No resource-loadable parameters beyond inherited `tomId`/`tomGroup`.

---

### Tables (`tom_tables.dart`)

#### TomDataTable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| sortAscending | bool | `TomCtr.boolVal` | ✅ |
| sortColumnIndex | int? | `TomCtr.intVal` | ✅ |
| decoration | Decoration? | `TomStyleResolvers.resolveDecoration` | ✅ |
| dataRowMinHeight | double? | `TomCtr.doubleVal` | ✅ |
| dataRowMaxHeight | double? | `TomCtr.doubleVal` | ✅ |
| dataTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| headingRowHeight | double? | `TomCtr.doubleVal` | ✅ |
| headingTextStyle | TextStyle? | `TomStyleResolvers.resolveTextStyle` | ✅ |
| horizontalMargin | double? | `TomCtr.doubleVal` | ✅ |
| columnSpacing | double? | `TomCtr.doubleVal` | ✅ |
| showCheckboxColumn | bool | `TomCtr.boolVal` | ✅ |
| showBottomBorder | bool | `TomCtr.boolVal` | ✅ |
| dividerThickness | double? | `TomCtr.doubleVal` | ✅ |
| checkboxHorizontalMargin | double? | `TomCtr.doubleVal` | ✅ |
| border | TableBorder? | `TomStyleResolvers.resolveTableBorder` | ✅ |

#### TomPaginatedDataTable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| sortAscending | bool | `TomCtr.boolVal` | ✅ |
| sortColumnIndex | int? | `TomCtr.intVal` | ✅ |
| dataRowMinHeight | double? | `TomCtr.doubleVal` | ✅ |
| dataRowMaxHeight | double? | `TomCtr.doubleVal` | ✅ |
| headingRowHeight | double? | `TomCtr.doubleVal` | ✅ |
| horizontalMargin | double? | `TomCtr.doubleVal` | ✅ |
| columnSpacing | double? | `TomCtr.doubleVal` | ✅ |
| showCheckboxColumn | bool | `TomCtr.boolVal` | ✅ |
| showFirstLastButtons | bool | `TomCtr.boolVal` | ✅ |
| initialFirstRowIndex | int | `TomCtr.intVal` | ✅ |
| rowsPerPage | int | `TomCtr.intVal` | ✅ |
| checkboxHorizontalMargin | double? | `TomCtr.doubleVal` | ✅ |
| showEmptyRows | bool | `TomCtr.boolVal` | ✅ |

#### TomTable

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| border | TableBorder? | `TomStyleResolvers.resolveTableBorder` | ✅ |

#### TomGridView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| reverse | bool | `TomCtr.boolVal` | ✅ |
| primary | bool? | `TomCtr.boolVal` | ✅ |
| shrinkWrap | bool | `TomCtr.boolVal` | ✅ |
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| cacheExtent | double? | `TomCtr.doubleVal` | ✅ |
| semanticChildCount | int? | `TomCtr.intVal` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |

#### TomReorderableListView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| buildDefaultDragHandles | bool | `TomCtr.boolVal` | ✅ |
| padding | EdgeInsets? | `TomCtr.edgeInsets` | ✅ |
| reverse | bool | `TomCtr.boolVal` | ✅ |
| primary | bool? | `TomCtr.boolVal` | ✅ |
| shrinkWrap | bool | `TomCtr.boolVal` | ✅ |
| anchor | double? | `TomCtr.doubleVal` | ✅ |
| restorationId | String? | `TomCtr.textOrNull` | ✅ |
| autoScrollerVelocityScalar | double? | `TomCtr.doubleVal` | ✅ |
| itemExtent | double? | `TomCtr.doubleVal` | ✅ |
| cacheExtent | double? | `TomCtr.doubleVal` | ✅ |


#### TomDataCell

No resource-loadable parameters.

---

### Toggles (`tom_toggles.dart`)

#### TomSwitch

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | `TomCtr.color` | ✅ |
| activeTrackColor | Color? | `TomCtr.color` | ✅ |
| inactiveThumbColor | Color? | `TomCtr.color` | ✅ |
| inactiveTrackColor | Color? | `TomCtr.color` | ✅ |
| splashRadius | double? | `TomCtr.doubleVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |

> **Note:** TomSwitch uses `WidgetStateProperty<Color?>` for thumbColor,
> trackColor and trackOutlineColor. These are resolvable through
> `TomCtr.widgetStateColor` — listed ⬜ rather than ⛔ because the resolver
> exists and the wiring does not.

#### TomCheckbox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| tristate | bool | `TomCtr.boolVal` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| checkColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| splashRadius | double? | `TomCtr.doubleVal` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| shape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| isError | bool | `TomCtr.boolVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |

#### TomRadio

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| splashRadius | double? | `TomCtr.doubleVal` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| toggleable | bool | `TomCtr.boolVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |

#### TomSwitchListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| isThreeLine | bool | `TomCtr.boolVal` | ✅ |
| dense | bool? | `TomCtr.boolVal` | ✅ |
| contentPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| activeTrackColor | Color? | `TomCtr.color` | ✅ |
| inactiveThumbColor | Color? | `TomCtr.color` | ✅ |
| inactiveTrackColor | Color? | `TomCtr.color` | ✅ |
| tileColor | Color? | `TomCtr.color` | ✅ |
| selectedTileColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |

#### TomCheckboxListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrNull` | ✅ |
| isThreeLine | bool | `TomCtr.boolVal` | ✅ |
| dense | bool? | `TomCtr.boolVal` | ✅ |
| contentPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| checkColor | Color? | `TomCtr.color` | ✅ |
| tristate | bool | `TomCtr.boolVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| tileColor | Color? | `TomCtr.color` | ✅ |
| selectedTileColor | Color? | `TomCtr.color` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| checkboxShape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |


#### TomCupertinoCheckbox

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | `TomCtr.color` | ✅ |
| inactiveColor | Color? | `TomCtr.color` | ✅ |
| checkColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| side | BorderSide? | `TomStyleResolvers.resolveBorderSide` | ✅ |
| shape | OutlinedBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |
| semanticLabel | String? | `TomCtr.textOrNull` | ✅ |

#### TomCupertinoRadio

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeColor | Color? | `TomCtr.color` | ✅ |
| inactiveColor | Color? | `TomCtr.color` | ✅ |
| fillColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |

#### TomCupertinoSwitch

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| activeTrackColor | Color? | `TomCtr.color` | ✅ |
| thumbColor | Color? | `TomCtr.color` | ✅ |
| trackColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| onLabelColor | Color? | `TomCtr.color` | ✅ |
| offLabelColor | Color? | `TomCtr.color` | ✅ |

#### TomRadioListTile

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| titleText | String? | `TomCtr.textOrFail` | ✅ |
| isThreeLine | bool | `TomCtr.boolVal` | ✅ |
| dense | bool? | `TomCtr.boolVal` | ✅ |
| contentPadding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| activeColor | Color? | `TomCtr.color` | ✅ |
| tileColor | Color? | `TomCtr.color` | ✅ |
| selectedTileColor | Color? | `TomCtr.color` | ✅ |
| visualDensity | VisualDensity? | `TomStyleResolvers.resolveVisualDensity` | ✅ |
| enableFeedback | bool? | `TomCtr.boolVal` | ✅ |
| toggleable | bool | `TomCtr.boolVal` | ✅ |
| autofocus | bool | `TomCtr.boolVal` | ✅ |
| shape | ShapeBorder? | `TomStyleResolvers.resolveShapeBorder` | ✅ |

#### TomToggleButtons

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| color | Color? | `TomCtr.color` | ✅ |
| selectedColor | Color? | `TomCtr.color` | ✅ |
| disabledColor | Color? | `TomCtr.color` | ✅ |
| fillColor | Color? | `TomCtr.color` | ✅ |
| focusColor | Color? | `TomCtr.color` | ✅ |
| highlightColor | Color? | `TomCtr.color` | ✅ |
| hoverColor | Color? | `TomCtr.color` | ✅ |
| splashColor | Color? | `TomCtr.color` | ✅ |
| borderColor | Color? | `TomCtr.color` | ✅ |
| selectedBorderColor | Color? | `TomCtr.color` | ✅ |
| disabledBorderColor | Color? | `TomCtr.color` | ✅ |
| borderWidth | double? | `TomCtr.doubleVal` | ✅ |

---

### Trees (`tom_trees.dart`)

#### TomTreeView

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| padding | EdgeInsetsGeometry? | `TomCtr.edgeInsets` | ✅ |
| indentation | double? | `TomCtr.doubleVal` | ✅ |
| shrinkWrap | bool | `TomCtr.boolVal` | ✅ |
| physics | ScrollPhysics? | `TomStyleResolvers.resolveScrollPhysics` | ✅ |

#### TomTreeNode

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| initiallyExpanded | bool | `TomCtr.boolVal` | ✅ |

#### TomTreeSliver

| Parameter | Type | Resolver | Status |
|-----------|------|----------|--------|
| addAutomaticKeepAlives | bool? | `TomCtr.boolVal` | ✅ |
| addRepaintBoundaries | bool? | `TomCtr.boolVal` | ✅ |
| addSemanticIndexes | bool? | `TomCtr.boolVal` | ✅ |

---

## Summary Statistics

| Category | Widgets | Total Params | ✅ Resolved | ⛔ Excluded | ⬜ Remaining |
|----------|---------|-------------|-------------|-------------|--------------|
| Animated Widgets | 20 | 47 | 35 | 12 | 0 |
| Builder Widgets | 8 | 0 | 0 | 0 | 0 |
| Buttons | 21 | 49 | 49 | 0 | 0 |
| Chips | 5 | 83 | 83 | 0 | 0 |
| Containers | 81 | 203 | 203 | 0 | 0 |
| ACL Container | 1 | 5 | 0 | 5 | 0 |
| Dialogs | 17 | 75 | 62 | 13 | 0 |
| Effects | 6 | 0 | 0 | 0 | 0 |
| Images | 11 | 56 | 56 | 0 | 0 |
| Inputs | 16 | 89 | 89 | 0 | 0 |
| Interactions | 10 | 39 | 39 | 0 | 0 |
| Labels | 15 | 80 | 80 | 0 | 0 |
| Lists | 6 | 39 | 39 | 0 | 0 |
| Navigation | 21 | 81 | 81 | 0 | 0 |
| Progress | 6 | 30 | 30 | 0 | 0 |
| Selects | 12 | 76 | 76 | 0 | 0 |
| Sliders | 3 | 18 | 18 | 0 | 0 |
| Slivers | 13 | 21 | 21 | 0 | 0 |
| Tables | 6 | 46 | 46 | 0 | 0 |
| Toggles | 10 | 95 | 95 | 0 | 0 |
| Trees | 3 | 8 | 8 | 0 | 0 |
| **Total** | **291** | **1140** | **1110** | **30** | **0** |

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
| `WidgetStateProperty<X>` | State-dependent wrapper — except `X == Color`, which `TomCtr.widgetStateColor` does resolve | overlayColor, fillColor |
| `Animation<X>` | Animation controller ref | valueColor, animation |
| `Curve` | Named singleton pattern | fadeInCurve, fadeOutCurve |
| `Matrix4` | Complex transform | transform |
| `ColorFilter` | Composite filter object | colorFilter |
| `ImageFilter` | Composite filter object | filter |

## Candidate Resolver Types (Not Yet Implemented)

| Type | Usage Count | Priority |
|------|-------------|----------|
| EdgeInsetsGeometry (via `TomCtr.edgeInsets`) | ~45 params | Already exists on `TomCtr` |
| Enum types (generic enum resolver) | ~60+ params | Medium — needs per-enum mapping |
| Duration | ~8 params | Low — can use int milliseconds |
| Radius | ~3 params | Low |
| Size | ~3 params | Low |
