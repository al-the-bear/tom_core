# tom_flutter_ui API Reference: Theme Module

The public surface of `lib/src/theme/`, as its barrel exports it.

## Overview

Sources: `lib/src/theme/theme.dart`, `lib/src/theme/tom_state_style.dart`, `lib/src/theme/tom_style_variants.dart`, `lib/src/theme/tom_theme.dart`.

## Classes

### TomButtonVariants

**Kind:** `class`

Convenience factories that produce standard [ButtonStyle] objects for semantic action variants (primary, secondary, destructive, auxiliary).

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `auxiliary` | `late final ButtonStyle auxiliary = TextButton.styleFrom( foregroundColor: _colors.onSurfaceVariant)` | Utility action — text-only, subtle. |
| `destructive` | `late final ButtonStyle destructive = ElevatedButton.styleFrom( backgroundColor: _colors.error, foregroundColor: _colors.onError)` | Dangerous / irreversible action — error color. |
| `fromColorScheme` | `factory TomButtonVariants.fromColorScheme(ColorScheme colorScheme)` | Resolves variants from the given [colorScheme]. |
| `of` | `factory TomButtonVariants.of(BuildContext context)` | Resolves variants from the nearest [Theme]. |
| `primary` | `late final ButtonStyle primary = ElevatedButton.styleFrom( backgroundColor: _colors.primary, foregroundColor: _colors.onPrimary)` | Main action — filled, prominent color. |
| `secondary` | `late final ButtonStyle secondary = OutlinedButton.styleFrom( foregroundColor: _colors.primary)` | Supporting action — outlined. |

### TomStateStyle

**Kind:** `class`

Controls the visual treatment of a non-interactive authorization state.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `absorbPointers` | `final bool absorbPointers` | Whether pointer events are absorbed (blocked). |
| `apply` | `Widget apply(Widget content)` | Applies this style to the given content widget. |
| `builder` | `final Widget Function(Widget content)? builder` | Optional custom builder that replaces the default treatment entirely. |
| `colorOverlay` | `final Color? colorOverlay` | Optional color overlay applied via [ColorFiltered]. |
| `disabled` | `static const disabled = TomStateStyle(opacity: 0.38)` | The framework default for `disabled` — AbsorbPointer + 0.38 opacity. |
| `equalsIgnoringBuilder` | `bool equalsIgnoringBuilder(TomStateStyle other)` | Whether this style equals [other] in every field but [builder]. |
| `opacity` | `final double opacity` | Opacity applied to the content, from 0.0 (invisible) to 1.0 (opaque). |
| `readonly` | `static const readonly = TomStateStyle()` | The framework default for `read` — AbsorbPointer + 0.6 opacity. |

### TomTheme

**Kind:** `class`

Tom-specific theme extensions that layer on top of Flutter's [ThemeData].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applyAuthState` | `Widget applyAuthState(TomAuthState state, ValueGetter<Widget> content)` | Renders [content] under the treatment [state] calls for. |
| `copyWith` | `TomTheme copyWith({ TomStateStyle? readonlyStyle, TomStateStyle? disabledStyle})` | Creates a copy of this theme with the given overrides. |
| `defaultTheme` | `static const defaultTheme = TomTheme()` | A sensible default theme. |
| `disabledStyle` | `final TomStateStyle disabledStyle` | Treatment for `TomAuthState.disabled` — visible, but not available. |
| `readonlyStyle` | `final TomStateStyle readonlyStyle` | Treatment for `TomAuthState.read` — visible, but not editable. |

### TomThemeScope

**Kind:** `class`

Provides a [TomTheme] to descendant widgets.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applyAuthState` | `static Widget applyAuthState( BuildContext context, TomAuthState state, ValueGetter<Widget> content)` | Renders [content] under the treatment [state] calls for, using the nearest theme. |
| `debugResetInlineBuilderDetection` | `static void debugResetInlineBuilderDetection()` | Clears the inline-builder detector's state. For tests only. |
| `disabledStyleOf` | `static TomStateStyle disabledStyleOf(BuildContext context)` | Returns the nearest `disabled` treatment, or [TomStateStyle.disabled]. |
| `inlineBuilderThreshold` | `static const int inlineBuilderThreshold = 3` | Consecutive builder-only changes after which a builder is taken to be written inline. |
| `of` | `static TomTheme of(BuildContext context)` | Returns the nearest [TomTheme], or [TomTheme.defaultTheme] if none. |
| `readonlyStyleOf` | `static TomStateStyle readonlyStyleOf(BuildContext context)` | Returns the nearest `read` treatment, or [TomStateStyle.readonly]. |
| `theme` | `final TomTheme theme` | The theme for this scope. |
| `updateShouldNotify` | `bool updateShouldNotify(TomThemeScope oldWidget)` |  |

## Global Functions and Constants

None — this module exports types only.
