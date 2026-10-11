# widget_base

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The foundation every other module rests on: the base widget classes that carry a
`tomId` and the authorization contract, the Material/Cupertino family selection,
the screen-elements provider, and the construction-time resolvers (`TomCtr`,
`TomStyleResolvers`) that turn resource entries into concrete Flutter values.

Being the foundation, **nothing here imports `widgets/`** — the dependency arrow
runs one way, and `test/widget_base/widget_base_layering_test.dart` checks it
transitively. A helper that wants to *return a widget* belongs in `widgets/`,
next to the callers it serves; the resolvers here return data and ids.

## Key types

This table is a complete inventory of what `widget_base/widget_base.dart`
exports; `test/module_readme_inventory_test.dart` fails if the module gains a
public type or static this table does not name. It gives each member its
**responsibility**; for signatures, defaults and return nullability see
[`doc/api/api_summary_widget_base.md`](../../../doc/api/api_summary_widget_base.md),
which the same test holds to the same barrel.

| Type | Responsibility |
| ---- | -------------- |
| `TomWidgetSurface` | The four members every Tom wrapper adds over its Flutter widget — `tomId`, `tomGroup`, `basePath`, `effectiveAuthState` |
| `TomNodeBase` / `TomPolicyNodeBase` | Base widget classes carrying `tomId` + authorization |
| `TomFamilyBase` | The common supertype of the family bases below; it declares no members of its own |
| `TomAuthLayers` | Composes the four authorization layers in order; `TomAuthLayers.resolve` is the one place that order lives |
| `TomStatelessWidget` / `TomStatefulWidget` / `TomState` | Construction-time base helpers |
| `TomScreenElementsProvider` / `TomScreenElementsProviderBase` | The element-provider contract forms/ACL build against |
| `TomScopePath` | Joins a scope path and a `tomId` into a canonical resource path — `TomScopePath.join`, `qualify`, `resolve` |
| `TomCtr` | Resource resolvers (below) |
| `TomStyleResolvers` | Style-map parsers (below) |

### The family bases

Twenty subclasses of `TomFamilyBase`, one per widget role — what a widget is
*for*, not what it looks like. A widget's family *is* the base it extends, and
it is asked with a type test (`widget is TomButtonBase`); there is no tag to
read. A wrapper extends exactly one of them, and no base extends another, so
every widget belongs to exactly one family without declaring it:

`TomButtonBase`, `TomInputBase`, `TomSelectBase`, `TomToggleBase`,
`TomSliderBase`, `TomContainerBase`, `TomDialogBase`, `TomTableBase`,
`TomLabelBase`, `TomImageBase`, `TomNavigationBase`, `TomProgressBase`,
`TomChipBase`, `TomListBase`, `TomTreeBase`, `TomSliverBase`,
`TomAnimatedBase`, `TomEffectBase`, `TomInteractionBase`, `TomBuilderBase`.

### `TomCtr` — resource entry to Dart value

Each reader takes a resource path and answers a typed value. Three shapes say
what a *miss* means, so the caller picks rather than the resolver: plain (`text`)
answers the key back — a missing label renders as its own path, which is how you
spot one on screen — `…OrNull` answers `null`, and `…OrFail` throws.

| Member | Answers |
| ------ | ------- |
| `text` / `textOrNull` / `textOrFail` | A `String` |
| `color` / `colorOrFail` | A `Color`, resolved through `TomUIColors` |
| `icon` / `iconOrFail` | An `IconData`, resolved through `TomUIIcons` |
| `doubleVal` / `doubleOrFail` | A `double` |
| `intVal` / `intOrFail` | An `int` |
| `boolVal` | A `bool` |
| `value` | The raw entry, whatever type it holds |
| `list` / `map` | A `List` / `Map` entry |
| `edgeInsets` | An `EdgeInsets` from a number or a map |
| `textStyle` | A `TextStyle` from a style map |
| `inputBorder` | An `InputBorder` |
| `widgetStateColor` | A `WidgetStateProperty<Color>` from per-state entries |
| `breakpointed<T>` | A base value plus its `(width, value)` overrides, for a property that varies by breakpoint |
| `exists` | Whether the entry is there at all, without reading it |
| `resolvePath` / `childTomId` | Path arithmetic: the full path for a `tomId`, and a child's id beneath it |

### `TomStyleResolvers` — style map to Flutter object

Every entry is a `parse…` / `resolve…` pair: `parse…` takes a map you already
hold, `resolve…` takes a resource path and reads the map first. They cover
`TextStyle` (`parseTextStyle` / `resolveTextStyle`), `ButtonStyle`
(`parseButtonStyle` / `resolveButtonStyle`), `InputDecoration`
(`parseInputDecoration` / `resolveInputDecoration`), `MenuStyle`
(`parseMenuStyle` / `resolveMenuStyle`), `ShapeBorder` (`parseShapeBorder` /
`resolveShapeBorder`), `BorderSide` (`parseBorderSide` / `resolveBorderSide`),
`BorderRadius` (`parseBorderRadius` / `resolveBorderRadius`), `Decoration`
(`parseDecoration` / `resolveDecoration`), `BoxConstraints`
(`parseBoxConstraints` / `resolveBoxConstraints`), `Alignment`
(`parseAlignment` / `resolveAlignment`), `Offset` (`parseOffset` /
`resolveOffset`), `TableBorder` (`parseTableBorder` / `resolveTableBorder`),
`VisualDensity` (`parseVisualDensity` / `resolveVisualDensity`),
`IconThemeData` (`parseIconThemeData` / `resolveIconThemeData`), `StrutStyle`
(`parseStrutStyle` / `resolveStrutStyle`), `TextHeightBehavior`
(`parseTextHeightBehavior` / `resolveTextHeightBehavior`) and `ScrollPhysics`
(`parseScrollPhysics` / `resolveScrollPhysics`).

Two have no `resolve…` twin, because nothing addresses them by their own
resource path — they are read as part of a larger map: `parseEdgeInsets` and
`parseFontWeight`.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void resolveFromResources() {
  TomUIColors.adapter = TomAllColorsAdapter();
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from({'login': {'title': 'Sign in', 'gap': 12}}),
  );

  final title = TomCtr.text('login', 'title');    // 'Sign in'
  final gap = TomCtr.doubleVal('login', 'gap');   // 12.0
  print('$title / $gap');

  final style = TomStyleResolvers.parseButtonStyle({
    'backgroundColor': '#FF5722',
    'elevation': 4,
  });
  print(style); // a ButtonStyle built from the map
}
```

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
