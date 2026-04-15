# FormStyle Migration

This document has two parts.

**Part 1** describes the current `TomFormStyle` system exactly as it exists
today — every option, how styles are provided to the widget tree, and how
fields consume them.

**Part 2** lays out the proposed replacement. The redesign is a **full
replacement**: the current flat `TomFormStyle` is retired and every consumer
migrates to the new structure in a single cut-over. No deprecated alias is
kept.

---

## Part 1 — Current state

### 1.1 Entry points

| Class / enum              | File                                                       |
| ------------------------- | ---------------------------------------------------------- |
| `TomFormStyle`            | `lib/src/forms/style/tom_form_style.dart`                  |
| `TomFormStyleScope`       | `lib/src/forms/style/tom_form_style_scope.dart`            |
| `LabelPlacement` et al.   | `lib/src/forms/style/form_style_enums.dart`                |
| `TomFieldDecorationMixin` | `lib/src/forms/decoration/tom_field_decoration_mixin.dart` |

The enums file holds `LabelPlacement`, `ErrorPlacement`,
`RequiredIndicator`, `DescriptionPlacement`, and `ActionIconPlacement`.

A single flat `TomFormStyle` class carries **every** style property for
**every** form field. Fields read the style via `TomFormStyleScope.of(context)`.

### 1.2 Enum vocabulary

| Enum                   | Values                                                       |
| ---------------------- | ------------------------------------------------------------ |
| `LabelPlacement`       | `above`, `below`, `floating`, `inline`, `hidden`             |
| `ErrorPlacement`       | `below`, `above`, `tooltip`, `both`, `replaceHint`           |
| `RequiredIndicator`    | `asterisk`, `text`, `none`, `custom`                         |
| `DescriptionPlacement` | `below`, `above`, `tooltip`                                  |
| `ActionIconPlacement`  | `trailing`, `leading`, `above`                               |

### 1.3 `TomFormStyle` properties

Anatomy defaults (what goes where):

| Property                  | Type                   | Default                       |
| ------------------------- | ---------------------- | ----------------------------- |
| `labelPlacement`          | `LabelPlacement`       | `above`                       |
| `errorPlacement`          | `ErrorPlacement`       | `below`                       |
| `requiredIndicator`       | `RequiredIndicator`    | `asterisk` (applies to label) |
| `requiredIndicatorOnHint` | `RequiredIndicator`    | `none`                        |
| `descriptionPlacement`    | `DescriptionPlacement` | `below`                       |
| `actionIconPlacement`     | `ActionIconPlacement`  | `trailing`                    |

Spacing:

| Property               | Type         | Default                                 |
| ---------------------- | ------------ | --------------------------------------- |
| `fieldSpacing`         | `double`     | `16.0` (between fields)                 |
| `fieldGroupSpacing`    | `double`     | `24.0` (between groups)                 |
| `labelFieldGap`        | `double`     | `4.0`  (label↔input)                    |
| `errorFieldGap`        | `double`     | `4.0`  (error↔input)                    |
| `fieldContentPadding`  | `EdgeInsets` | `EdgeInsets.symmetric(h:12, v:8)`       |

Border / shape:

| Property         | Type           | Default |
| ---------------- | -------------- | ------- |
| `fieldBorder`    | `InputBorder?` | `null`  |
| `focusedBorder`  | `InputBorder?` | `null`  |
| `errorBorder`    | `InputBorder?` | `null`  |
| `borderRadius`   | `double`       | `8.0`   |

Grouping containers:

| Property          | Type             | Default                  |
| ----------------- | ---------------- | ------------------------ |
| `groupDecoration` | `BoxDecoration?` | `null`                   |
| `groupPadding`    | `EdgeInsets`     | `EdgeInsets.all(16)`     |

Typography:

| Property           | Type         | Default                                 |
| ------------------ | ------------ | --------------------------------------- |
| `labelStyle`       | `TextStyle?` | `null` (falls back to theme bodyMedium) |
| `hintStyle`        | `TextStyle?` | `null`                                  |
| `errorStyle`       | `TextStyle?` | `null` (falls back to theme bodySmall)  |
| `descriptionStyle` | `TextStyle?` | `null` (falls back to theme bodySmall)  |

Authorization visuals:

| Property             | Type     | Default |
| -------------------- | -------- | ------- |
| `disabledOpacity`    | `double` | `0.5`   |
| `readOnlyBackground` | `Color?` | `null`  |

### 1.4 Presets

- `TomFormStyle.material3` — all defaults.
- `TomFormStyle.compact` — `LabelPlacement.floating`, `fieldSpacing: 8.0`,
  `fieldGroupSpacing: 16.0`.

### 1.5 Resource loading

`TomFormStyle.fromResources(String basePath)` reads every scalar/enum from
the `TomCtr` resource tree (JSON) under `basePath`. Examples:

```text
tomApp.forms.style.labelPlacement       -> "above"
tomApp.forms.style.fieldSpacing         -> 20.0
tomApp.forms.style.borderRadius         -> 12.0
tomApp.forms.style.readOnlyBackground   -> "#F5F5F5"
```

Typography and border objects (`labelStyle`, `fieldBorder`, etc.) are **not**
loadable from resources today — they are Dart-side only.

### 1.6 Scope mechanism

`TomFormStyleScope` is an `InheritedWidget`. Nested scopes override parents.
`TomFormStyleScope.of(context)` walks up the tree and returns
`TomFormStyle.material3` if no scope is found.

### 1.7 How fields consume the style

**Non-text fields** (slider, checkbox, segmented button, …) mix in
`TomFieldDecorationMixin<T>`, which builds the anatomy column around the
inner widget. It reads the scope and places the label row, description row,
error row and action-icon row using the enum values above.

**Text fields** (`TomFormStringInput`, `TomFormStringDropdown`) use the same
mixin for external anatomy and additionally push a few props directly into
Material's `InputDecoration`:

- `labelText` — only populated when `labelPlacement == floating`
  (plus the required-indicator suffix from `requiredIndicator`).
- `hintText` — with a suffix from `requiredIndicatorOnHint` when non-empty;
  overwritten by the error message when `errorPlacement == replaceHint` and
  the field is in error state.
- `hintStyle`, `labelStyle`, `contentPadding`, `border`, `focusedBorder`,
  `errorBorder`, `enabledBorder`.

Error text, description text, external label row and required-indicator
*widget* are rendered by the mixin — **never** via `InputDecoration`'s own
`errorText` / `helperText` / `labelText` slots (except for the floating case).

### 1.8 Limitations that drive the redesign

1. **Single flat class for all field types.** Every new field type (slider,
   switch, file picker, calendar, …) shares the same props — even when the
   prop is meaningless for that widget. There is no clean way to add
   widget-specific style knobs (e.g. the slider track colour, the checkbox
   fill, the file-drop dashed border).
2. **No resource-backed override mechanism for the scope.** `TomForm` is
   not a widget and has no role in styling — all fields read from the
   enclosing `TomFormStyleScope` directly. The current scope cannot
   layer resource-driven overrides onto a Dart-side base style; the
   whole style must be built up in Dart.
3. **No breakpoint awareness.** Every prop is a single value; you cannot say
   "bigger fields on desktop, compact on phone" without rebuilding a new
   `TomFormStyle` yourself based on `MediaQuery`.
4. **ACL gaps and row heights are not breakpoint aware either.**
   `setAclDefaultAppendGap(int pixels)` and row heights are scalars.
5. **Error indication is limited to text placement.** There is no built-in
   way to say "show a red exclamation icon inside the input" or "tint the
   border red on error" for non-text field types. Text fields get the
   border tinting only by you manually wiring `errorBorder`.
6. **No focus background.** There is no `focusedBackground` prop.
7. **No "bordered, no-underline" variant.** The current Material-leaning
   styling always ends up drawing the TextField's underline unless the user
   builds a custom `InputBorder`.

---

## Part 2 — Replacement

The replacement is a clean cut-over. `TomFormStyle`, `TomFormStyleScope`,
and any code that touches them are removed and replaced with the new API
in a single change set.

### 2.1 Design principles

1. **One style class per underlying widget type.** Style knobs that only
   make sense for a slider live on the slider's style; text-input knobs
   live on the text-input style. Shared anatomy (label/hint/description/
   error placement, spacing) lives on a common base.
2. **A single umbrella `TomFormStyle` owns every field-type style.** It
   is provided via a `TomFormStyleScope` (`InheritedWidget`). Fields
   read from the nearest enclosing scope directly. `TomForm` is not a
   widget and has no role in styling — there is no form-level style
   field and no form-to-form inheritance. A subtree overrides by
   wrapping in a nested `TomFormStyleScope`.
3. **Every style property can be breakpoint-aware.** On the public API,
   each such property is expressed as a plain value plus an overrides
   list (`prop` + `propBpOverrides`). Resolution happens against the
   available width, read independently of the ACL (see §2.2).
4. **Anatomy decisions stay in the mixin.** The mixin is unchanged in
   spirit — it still decides where to put the label, error, description.
   What changes is *where it reads them from* (typed sub-style instead
   of the flat class).
5. **Full cut-over.** No shim, no `@Deprecated` alias. Every demo, every
   test, every concrete field migrates at once.

### 2.2 Breakpoint primitive

**Public surface — one raw field plus one overrides list, per property.**
Every breakpoint-aware style property is expressed on its sub-style class
as *two* fields — the plain value and a matching list of
`(minWidth, value)` overrides:

```dart
class TomStringInputStyle extends TomFieldStyle {
  final double labelFieldGap;
  final List<(double, double)> labelFieldGapBpOverrides;

  final Color? focusedBackground;
  final List<(double, Color?)> focusedBackgroundBpOverrides;

  // …
}
```

Callers who don't care about breakpoints just set the plain field and
leave the overrides list empty (its default). Callers who need
breakpoints supply both:

```dart
// No breakpoints — just a value.
TomStringInputStyle(labelFieldGap: 4.0)

// Width-indexed.
TomStringInputStyle(
  labelFieldGap: 4.0,
  labelFieldGapBpOverrides: [(600, 6.0), (1200, 8.0)],
)
```

**Resolution helper.** A single type-safe generic method on the style
class resolves any `(value, overrides)` pair against a width:

```dart
// On TomFieldStyle (or a shared mixin reused by every *Style class).
T resolveForBp<T>(
  double width,
  T defaultValue,
  List<(double, T)> overrides,
);
```

Call-site example:

```dart
final gap = style.resolveForBp(
  width,
  style.labelFieldGap,
  style.labelFieldGapBpOverrides,
);
```

No wrapper class is exposed publicly. A private `Breakpointed<T>` struct
may be used as an implementation detail inside `resolveForBp` if
convenient, but the public surface stays "two fields + one method".

Override semantics: overrides are sorted by `minWidth` ascending; the
highest `minWidth <= currentWidth` wins; if none matches, `defaultValue`
is used.

**Width source — provided by `TomFormStyleScope`, independent of the
ACL.** Forms can be laid out inside an ACL *or* by any other means
(plain `Column`, custom widget, nested scroll view). Breakpoint
resolution therefore does not query the ACL. `TomFormStyleScope`
internally wraps its `child` in a `LayoutBuilder`, captures the
constraints' `maxWidth`, and publishes it through the same
`InheritedWidget` that carries the style. Fields read the current
width via `TomFormStyleScope.widthOf(context)` (or by using a per-type
mixin that hides this, see §2.3a) and resolve each breakpointed
property against it internally.

When a field is built outside any `TomFormStyleScope` (stand-alone
widget, testing), width falls back to `MediaQuery.sizeOf(context).width`
and the style defaults to `TomFormStyle.material3`.

This matches the ACL's own internal width measurement without
depending on the ACL, so the same breakpoint semantics apply whether
the form is rendered via ACL, via `Column`, or inside some other
layout container.

### 2.3 New shape

The umbrella class keeps the name `TomFormStyle`. The old flat
`TomFormStyle` is split into a shared base (`TomFieldStyle`, **partial**
— every property is nullable) and one style class per underlying widget
type. Every per-type field on the umbrella is suffixed with `Style`,
avoiding both the redundant `Field` suffix and Dart reserved-word
collisions (`switch` → `switchStyle`):

```text
TomFormStyle                               (umbrella — one instance per scope)
├─ defaults            : TomFieldStyle     (non-nullable; the base values)
├─ stringInputStyle    : TomStringInputStyle?     (partial override for text inputs)
├─ dropdownStyle       : TomDropdownStyle?
├─ sliderStyle         : TomSliderStyle?
├─ checkboxStyle       : TomCheckboxStyle?
├─ switchStyle         : TomSwitchStyle?
├─ segmentedStyle      : TomSegmentedStyle?
├─ radioGroupStyle     : TomRadioGroupStyle?
├─ datePickerStyle     : TomDatePickerStyle?
├─ timePickerStyle     : TomTimePickerStyle?
├─ filePickerStyle     : TomFilePickerStyle?
├─ chipsStyle          : TomChipsStyle?
└─ multilineInputStyle : TomMultilineInputStyle?
```

**Resolution rule — per-pair atomic (option b).** For any breakpointable
property *p* on a field of widget type *T* with sub-style field
`<t>Style` (e.g. `stringInputStyle`, `checkboxStyle`):

1. If `formStyle.<t>Style?.p` is non-null, take the whole pair
   (`<t>Style.p`, `<t>Style.pBpOverrides`) from the sub-style.
2. Otherwise take the whole pair (`defaults.p`, `defaults.pBpOverrides`)
   from `defaults`.

**The `(value, overrides)` duo is treated atomically** — a sub-style
cannot partially override only the value or only the overrides list.
This removes an entire class of "which breakpoint list applies?" bugs
and makes the merge trivial per call-site.

For non-breakpointable properties (enums, bools, widget-specific
additions), the same rule applies with just the single value.

`defaults` is fully populated (never null). Each `Tom<Type>Style`
carries the *same property shape* as `TomFieldStyle` but with every
field nullable, plus any widget-specific additions — so a caller only
has to specify the deltas for that widget type. Presets
(`material3`/`compact`/`bordered`) fully populate `defaults` and leave
the per-type sub-styles at their preset-chosen values (often `null` when
the defaults suffice).

**`TomFormStyle` is about the style of form fields — not layout.** Gaps
between fields, gaps between rows, field-group containers and section
cards are *layout* concerns and live on the ACL (row alignment, row gap,
append gap) or on whatever widget wraps a group. The following
properties from the old `TomFormStyle` are therefore **dropped** (no
replacement on the style class):

- `fieldSpacing`, `fieldGroupSpacing`
- `groupDecoration`, `groupPadding`

These were layout properties masquerading as style.

**`TomFieldStyle` (shared base)** carries everything that applies to
every field type:

- Anatomy placements: `labelPlacement`, `errorPlacement`,
  `requiredIndicator`, `requiredIndicatorOnHint`, `descriptionPlacement`,
  `actionIconPlacement`.
- Intra-field anatomy gaps (within a single field's decoration):
  `labelFieldGap`, `errorFieldGap`.
- Field-box shape: `fieldContentPadding`, `borderRadius`, `fieldBorder`,
  `focusedBorder`, `errorBorder`.
- Typography: `labelStyle`, `hintStyle`, `errorStyle`, `descriptionStyle`.
- State visuals: `disabledOpacity`, `readOnlyBackground`,
  `focusedBackground` (new — per (d)), `errorBorderEnabled`,
  `errorIconEnabled` (new — per (g)).

Every per-widget-type class has:

1. A *partial override* portion — the same properties as `TomFieldStyle`
   but each nullable — allowing per-widget-type tweaks without
   re-specifying everything.
2. *Widget-specific additions* — `TomSliderStyle` adds `trackColor`,
   `activeColor`, `thumbColor`; `TomCheckboxStyle` adds `fillColor`,
   `checkColor`; `TomStringInputStyle` adds `variant`
   (`material`/`bordered`), etc.

Breakpoint-aware properties use the pair convention from §2.2 — a plain
field `prop` alongside an override list `propBpOverrides`.

No name collisions with Flutter: Flutter exposes `ButtonStyle`,
`SwitchThemeData`, `CheckboxThemeData`, etc. — none of the
`Tom*Style` names above clash.

**Color state variations — decision.** All style colors on `TomFieldStyle`
and the per-type sub-styles use **`WidgetStateProperty<Color>`** (not
plain `Color?`). This matches Flutter's built-in widgets (`Checkbox`,
`Slider`, `Switch`, `RadioListTile`, …) 1:1, so style values can be
passed straight through to the underlying widget without a lift-and-wrap
step, and apps can drive hover/pressed/focused/selected/disabled
variations natively.

Practical implications:

- Every color field is typed `WidgetStateProperty<Color>` (non-nullable)
  on `TomFieldStyle`; the same-named field on each `Tom<T>Style`
  partial-override class is `WidgetStateProperty<Color>?`.
- `withTheme` maps to `WidgetStateProperty`-returning helpers
  (`WidgetStateProperty.resolveWith(...)` or `WidgetStatePropertyAll(...)`
  for single-state cases).
- `TomCtr` gains a `TomCtr.widgetStateColor(path)` resolver (see §2.9)
  that reads the flat default color at `path` and per-state overrides at
  `path.states.<stateName>`. Missing overrides fall back to the default.
- Breakpointed color properties remain pair-fields on the style
  (`Breakpointed<WidgetStateProperty<Color>>` conceptually); the existing
  `(value, overrides)` pair convention applies, with each entry being a
  `WidgetStateProperty<Color>`.

Shorthand API: callers who only want a single color across all states
use `WidgetStatePropertyAll(Colors.red)` or a small
`TomFormStyle.solid(Color)` helper that wraps it — the doc can ship that
convenience once the base type is settled.

### 2.3a Per-widget decoration mixin

There is **one decoration mixin per underlying widget type** — not a
single generic `TomFieldDecorationMixin` plus a `*Styled` trait. Each
mixin receives the complete `TomFormStyle` from the scope and reads
directly from `defaults` and the matching sub-style, picking per-pair
via the atomic rule in §2.3:

```dart
mixin TomStringInputDecorationMixin<String> on TomField<String> {
  Widget decorateField(BuildContext context, Widget innerWidget) {
    final form  = TomFormStyleScope.of(context);
    final over  = form.stringInputStyle;          // may be null
    final base  = form.defaults;                  // never null
    final width = TomFormStyleScope.widthOf(context);

    // Per-pair atomic pick — either both come from `over`, or both from `base`.
    final labelFieldGap = over?.labelFieldGap != null
        ? base.resolveForBp(width, over!.labelFieldGap!, over.labelFieldGapBpOverrides)
        : base.resolveForBp(width, base.labelFieldGap, base.labelFieldGapBpOverrides);

    // Widget-specific props (not on TomFieldStyle) read from `over` only:
    final variant = over?.variant ?? StringInputVariant.material;

    // …build the anatomy…
  }
}

mixin TomCheckboxDecorationMixin on TomField<bool> {
  Widget decorateField(BuildContext context, Widget innerWidget) {
    final form = TomFormStyleScope.of(context);
    final over = form.checkboxStyle;
    final base = form.defaults;
    // Same pattern, different sub-style.
    // Widget-specific: over?.fillColor, over?.checkColor.
  }
}
// …one per widget type
```

Concrete fields apply the mixin for their widget type:

```dart
class TomFormStringInput extends TomFormStringField
    with TomStringInputDecorationMixin<String> { … }

class TomFormBoolCheckbox extends TomFormBoolField
    with TomCheckboxDecorationMixin { … }
```

This removes the indirection of a shared `resolveStyle`/`mergedWith`
method entirely: the mixin has both halves of the style in scope and
picks exactly what it needs per property. Repetition of the pair-pick
pattern is eliminated by a tiny helper on `TomFieldStyle`:

```dart
// Picks (value, overrides) atomically from `over` if set, else from `base`.
T pickPair<T>(
  double width,
  T? overValue,
  List<(double, T)> overOverrides,
  T baseValue,
  List<(double, T)> baseOverrides,
) {
  if (overValue != null) {
    return resolveForBp(width, overValue, overOverrides);
  }
  return resolveForBp(width, baseValue, baseOverrides);
}
```

Mixin code becomes one line per property:

```dart
final gap = base.pickPair(width,
    over?.labelFieldGap, over?.labelFieldGapBpOverrides ?? const [],
    base.labelFieldGap, base.labelFieldGapBpOverrides);
```

### 2.4 Presets and theme derivation

`TomFormStyle` exposes three presets, each filling in `defaults` fully:

- `TomFormStyle.material3` — current Material-default look.
  `errorBorderEnabled: false`, `errorIconEnabled: false`.
- `TomFormStyle.compact`   — smaller fonts, floating labels.
  `errorBorderEnabled: false`, `errorIconEnabled: false`.
- `TomFormStyle.bordered`  — new: every field that *can* render a box
  renders with a full outlined border and **no underline**; for those
  fields the label uses `LabelPlacement.floating` (the Flutter floating
  label on an outlined input already draws the label at the top-left of
  the border). `errorBorderEnabled: true`, `errorIconEnabled: true`.

**Theme derivation (per (c)).** Every preset supports
`.withTheme(ThemeData theme)` returning a derivative with every
color- and typography-bearing property mapped from the theme. Using
`ThemeData` (not just `ColorScheme`) lets us pick up text styles too.
Typical call-site:

```dart
final style = TomFormStyle.material3.withTheme(Theme.of(context));
```

**Proposed mapping** (each bullet: style property ← theme source).
Color properties produce a `WidgetStateProperty<Color>` — typically via
`WidgetStatePropertyAll(color)` for the single-state case, or
`WidgetStateProperty.resolveWith((states) => ...)` when we want the
state variation Flutter already defines for that widget.

- `labelStyle` ← `textTheme.bodyMedium`
- `hintStyle` ← `textTheme.bodyMedium.copyWith(color: colorScheme.onSurfaceVariant)`
- `errorStyle` ← `textTheme.bodySmall.copyWith(color: colorScheme.error)`
- `descriptionStyle` ← `textTheme.bodySmall.copyWith(color: colorScheme.onSurfaceVariant)`
- `fieldBorder` (outlined) ← `OutlineInputBorder` in `colorScheme.outline`
- `focusedBorder` ← `OutlineInputBorder` in `colorScheme.primary` (width 2)
- `errorBorder` ← `OutlineInputBorder` in `colorScheme.error`
- `focusedBackground` ← `WidgetStatePropertyAll(colorScheme.surfaceContainerHighest)`
- `readOnlyBackground` ← `WidgetStatePropertyAll(colorScheme.surfaceContainer)`
- String/multiline input text color ← `WidgetStatePropertyAll(colorScheme.onSurface)`
- `checkboxStyle.fillColor`, `switchStyle.thumbColor`, `sliderStyle.activeColor` ← `WidgetStateProperty.resolveWith` returning `colorScheme.primary` when `selected`, `colorScheme.onSurface.withOpacity(0.38)` when `disabled`, else `colorScheme.outline`
- `checkboxStyle.checkColor` ← `WidgetStatePropertyAll(colorScheme.onPrimary)`
- `sliderStyle.trackColor` ← `WidgetStatePropertyAll(colorScheme.surfaceVariant)`

**Preservation rule.** `withTheme` must **not** overwrite any property a
caller has set explicitly on the style. Only properties whose values
still equal the preset's original (untouched) defaults get replaced by
the themed equivalents. Implementation: each preset is generated from an
internal "origin template" so the `withTheme` method can check per-field
whether the current value is still identity-equal to the template's
value; if yes, replace; if not, leave it alone.

Practical consequences:

- `TomFormStyle.material3.withTheme(t)` — replaces all preset colors
  and text styles with themed ones.
- `TomFormStyle.material3.copyWith(labelStyle: myStyle).withTheme(t)`
  — `labelStyle` is kept at `myStyle`; everything else is themed.
- `TomFormStyle.material3.withTheme(t).copyWith(labelStyle: myStyle)`
  — user's `copyWith` wins over the themed value (standard Dart
  pattern); identical end result to the line above.

`withTheme` only touches color and typography on `defaults`; placements,
gaps, borders-enabled flags, and breakpoint overrides stay untouched.
Per-type sub-styles (`stringInputStyle`, `sliderStyle`, …) are preserved
as-is — if the caller has set a sub-style, `withTheme` does not modify
it.

### 2.5 Scope

`TomFormStyleScope` stays as the single way to provide a `TomFormStyle`
to the widget tree — an `InheritedWidget` that fields read from
directly. `TomForm` is not a widget and is not involved in styling at
all: there is no form-level style field, no form-to-form inheritance,
and no implicit per-subform scope. If you want a subtree styled
differently, wrap it in another `TomFormStyleScope`.

**Constructor** (matching the pattern used by other `Tom*` widgets such
as `TomSnackBar`, `TomDropdownMenu`, etc.):

```dart
TomFormStyleScope({
  super.key,
  this.tomId,                       // optional — enables resource overrides when set
  this.scope,                       // optional — overrides the ambient TomScope
  required this.style,              // programmatic base TomFormStyle
  required Widget child,
});
```

- `tomId` is *nullable*, matching the rest of the Tom widget family. When
  set, the scope looks for resource overrides under
  `<resolvedScope>.<tomId>.*` (see §2.9). When `null`, the style is
  pure-Dart — no resource overlay is attempted.
- `scope` is optional and resolved via `TomCtr.resolvePath(tomId, scope)`
  exactly like `TomSnackBar`/`TomDropdownMenu` do: when omitted, the
  ambient `TomScope` from the surrounding zone is used; when supplied,
  it overrides for this subtree. Callers usually either (a) rely on
  zone scope set earlier with `TomScope.withScope(scopeId, () => …)`, or
  (b) pass `scope` explicitly.
- `style` is the Dart-side base. Resources (when `tomId` is set) only
  override individual named properties — anything absent in the resource
  tree keeps its value from `style`.

**Typical use** — the form sits inside a `TomScope.withScope` block (the
standard pattern for Tom forms), and the scope picks up that ambient
scope automatically:

```dart
TomScope.withScope('companyBasicInfo', () => TomFormStyleScope(
  tomId: 'basicForm',
  style: TomFormStyle.material3.withTheme(Theme.of(context)),
  child: myFormTree,
));
```

**Explicit scope override** — when the widget is built outside the
desired zone (e.g. inside a builder callback that escapes the zone):

```dart
TomFormStyleScope(
  scope: someExplicitScope,         // TomScope instance
  tomId: 'basicForm',
  style: TomFormStyle.material3,
  child: myFormTree,
)
```

`TomFormStyleScope.of(context)` returns the nearest scope's style with
resource overrides applied when `tomId != null`. Default when no scope is
found: `TomFormStyle.material3`.

### 2.6 Per-request mapping

**(a)** *Dropped per your call* — `ErrorPlacement.replaceLabel` is **not**
added.

**(b)** Three new ACL APIs, all using the raw-value + overrides pair:

```dart
AclBuilder.setAclDefaultRowHeight(
  double? height, [
  List<(double, double?)> heightBpOverrides = const [],
]);

builder.setRowHeight(
  double? height, [
  List<(double, double?)> heightBpOverrides = const [],
]);

builder.newRow({
  double? height,
  List<(double, double?)> heightBpOverrides = const [],
});
```

**(c)** Full restructure into `TomFormStyle` + per-widget-type sub-styles.
Every style property that makes sense per breakpoint gets the pair-of-
fields treatment (`prop` + `propBpOverrides`). Every existing knob stays
addressable; new knobs become natural to add per widget type.

**(d)** New `focusedBackground` on the shared `TomFieldStyle` base:

```dart
final Color? focusedBackground;
final List<(double, Color?)> focusedBackgroundBpOverrides;
```

Applied only to fields that have a discrete input box (text inputs,
multiline, dropdowns, date/time pickers, file picker). For fields
without a clear box — checkbox, switch, slider, radio group — the
property is **skipped**: the mixin does not paint a focus background
behind the widget.

**(e)** `TomFormStyle.bordered` preset — **no new enum value**. The
bordered look is achieved by combining existing pieces:

- `labelPlacement: LabelPlacement.floating` (Flutter already draws the
  floating label at the top-left of an `OutlineInputBorder`).
- An outlined `fieldBorder` / `focusedBorder` / `errorBorder`.
- `TextField`'s underline suppressed (either via `OutlineInputBorder`
  replacing the default or by explicitly disabling `isCollapsed`
  underline drawing where needed).

Fields that don't get a border by nature (checkbox, switch, radio) are
unaffected — they render as usual; the "bordered" is a dropdown-*with*-a-
border, not a dropdown inside a separate box.

**(f)** `setAclDefaultAppendGap` changes to:

1. default of `8.0` (up from `0`),
2. applied to the first component of each row as well,
3. accepts the raw-value + overrides pair:

```dart
builder.setAclDefaultAppendGap(
  double gap, [
  List<(double, double)> gapBpOverrides = const [],
]);
```

**(g)** Two new orthogonal flags on `TomFieldStyle`, each using the pair:

```dart
final bool errorBorderEnabled;
final List<(double, bool)> errorBorderEnabledBpOverrides;

final bool errorIconEnabled;
final List<(double, bool)> errorIconEnabledBpOverrides;
```

- `errorBorderEnabled` recolours the border/line on error (uses
  `errorBorder` from the style).
- `errorIconEnabled` renders a red circle-exclamation. Position: the
  trailing slot of the input row, **to the right of any existing suffix
  icon** (dropdown arrow, password-reveal eye, clear button, …) — never
  replacing them.

Both are independent of `ErrorPlacement` (which only controls *error
text* placement). Defaults per preset: both `false` for `material3` and
`compact`, both `true` for `bordered`.

### 2.7 New / changed enum values

None. The bordered variant reuses `LabelPlacement.floating` combined with
an outlined border, avoiding a redundant enum value.

### 2.8 Migration plan

A single changeset covers:

1. **New code** — style classes in a single bundled file
   `lib/src/forms/style/tom_form_style.dart`:
   - `TomFieldStyle` shared base (non-nullable) with `resolveForBp<T>`
     and `pickPair<T>` helpers (§2.2, §2.3a).
   - Every `Tom<Type>Style` partial-override class — same property
     shape as `TomFieldStyle` but each field nullable, plus
     widget-specific additions.
   - Umbrella `TomFormStyle` holding `defaults: TomFieldStyle` and
     nullable per-type sub-styles (each suffixed `*Style`).
   - Presets `TomFormStyle.material3 / compact / bordered` with
     `withTheme(ThemeData)` that preserves user-set properties
     (§2.4).
   - `TomFormStyleScope` (`InheritedWidget`) with optional
     `tomId` / `scope` and resource overlay per §2.9. Wraps its child
     in a `LayoutBuilder` and exposes `widthOf(context)` for
     breakpoint resolution.
2. **Decoration mixins** — one per underlying widget type, replacing
   the single generic `TomFieldDecorationMixin`. Each mixin reads the
   scope, accesses `defaults` and its matching sub-style directly, and
   applies the per-pair atomic pick via `pickPair` (§2.3a):
   `TomStringInputDecorationMixin`, `TomDropdownDecorationMixin`,
   `TomSliderDecorationMixin`, `TomCheckboxDecorationMixin`,
   `TomSwitchDecorationMixin`, `TomSegmentedDecorationMixin`,
   `TomRadioGroupDecorationMixin`, `TomDatePickerDecorationMixin`,
   `TomTimePickerDecorationMixin`, `TomFilePickerDecorationMixin`,
   `TomChipsDecorationMixin`, `TomMultilineInputDecorationMixin`.
3. **TomCtr additions (centralised resource parsing).** Whatever isn't
   already present goes into `TomCtr`; style code never parses JSON
   directly:
   - `TomCtr.textStyle(path)` (TextStyle parser)
   - `TomCtr.inputBorder(path)` (InputBorder parser)
   - `TomCtr.breakpointed<T>(path, T Function(String) read)` reading
     `path` + `path.breakpoints` (§2.9).

4. **Removals**: the old flat `TomFormStyle`, its flat `fromResources`
   factory, the single `TomFieldDecorationMixin`, and `fieldSpacing` /
   `fieldGroupSpacing` / `groupDecoration` / `groupPadding` (layout
   concerns — not replaced on the style class).

5. **Fields**: each concrete field mixes in its matching decoration
   mixin. `TomFormStringInput` / `TomFormStringDropdown` wire their
   `InputDecoration` from the style properties picked by the mixin.

6. **ACL**: `setAclDefaultRowHeight`, `setRowHeight`, `newRow(height:)`,
   revised `setAclDefaultAppendGap` semantics + default 8px + breakpoint
   support.

7. **Error visuals**: border-colour-on-error and trailing error-icon
   rendered by the decoration mixins / input wrappers, gated by the two
   new flags.

8. **Tests**: every style-related test and every demo is migrated. The
   style-aware tests in `test/forms/style/**` and the style assertions
   across field tests rewrite to the new API.

9. **Demos** in `tom_flutter_form_test/lib/demos/`:
   - Demos 5–7 switch to the new `TomFormStyle` shape.
   - Demo 6 gains controls for the new flags — bordered variant, focus
     background, error-icon and error-border toggles.
   - **New Demo 8 — Breakpoints**: a single form whose style changes at
     configurable widths (drag a splitter to watch labels move inline →
     above → floating, fonts shrink, borders toggle).
   - **New Demo 9 — Preset showcase**: a grid rendering *every* form
     field type (currently few; many more as per
     `tom_ui_widgets_forms.md`) under each preset side-by-side
     (`material3`, `compact`, `bordered`) with a `withTheme` toggle to
     prove consistency against the surrounding Material theme.

### 2.9 Resource loading

Resource loading is **opt-in**: it runs only when `tomId` is set on
`TomFormStyleScope`. When `tomId` is `null`, the programmatic `style`
is used as-is — no resource lookup.

**Path pattern.** When `tomId` is set, the namespace uses a **fixed path
pattern** — no walking, no cross-scope fallbacks — built by the same
`TomCtr.resolvePath(tomId, scope)` helper that every other `Tom*` widget
uses:

```text
<resolvedPath>.<property-path>    where resolvedPath = TomCtr.resolvePath(tomId, scope)
```

`resolvedPath` takes `scope:` into account when supplied, otherwise uses
the ambient `TomScope`.

**All resource parsing goes through `TomCtr`.** Any resolver that isn't
already present is added there (centralised), not scattered across style
classes. Expected `TomCtr` surface used by the style system:

- Existing: `TomCtr.color(path)`, `TomCtr.doubleVal(path)`,
  `TomCtr.intVal(path)`, `TomCtr.boolVal(path)`,
  `TomCtr.edgeInsets(path)`, `TomCtr.textOrNull(path)`
  (enums / strings).
- New, added as part of this migration:
  - `TomCtr.textStyle(path)` — reads font family, size, weight, color,
    letter-spacing, etc. from a sub-tree.
  - `TomCtr.inputBorder(path)` — reads border kind (outline/underline/
    none), width, radius, color.
  - `TomCtr.widgetStateColor(path)` — reads the flat default color at
    `path` plus per-state overrides at
    `path.states.<stateName>`; returns a `WidgetStateProperty<Color>`.
    Recognised state names mirror Flutter's
    `WidgetState` enum (`hovered`, `focused`, `pressed`, `selected`,
    `disabled`, `error`, `dragged`, `scrolledUnder`). Missing states
    fall back to the default.
  - `TomCtr.breakpointed<T>(path, T Function(String) read)` — reads the
    `(value, overrides)` pair; see flat-value convention below.

**Flat value + `.breakpoints` sidecar for breakpointed properties.** The
plain property stays at its natural path (a single scalar or nested
resource, unchanged from the non-breakpointed case). Overrides live in
a single sibling key suffixed `.breakpoints`, whose value is a JSON
array of `[minWidth, value]` pairs:

```json
{
  "basicForm": {
    "stringInputStyle": {
      "focusedBackground":             "#EAF4FF",
      "focusedBackground.breakpoints": [[600, "#DCEBFF"], [1200, null]]
    }
  }
}
```

This keeps the default-case JSON identical to today's flat scheme — no
existing resource file needs to change to keep working. Authors who
want breakpoints add a single sibling key; everything else stays.

`TomCtr.breakpointed<T>(path, read)` reads `path` and
`path.breakpoints` together and returns a `(T, List<(double, T)>)`
pair that the style merges into its `prop` + `propBpOverrides` fields.

**Per-state color overrides.** Because every style color is a
`WidgetStateProperty<Color>` (§2.3 decision), `TomCtr.widgetStateColor`
reads the flat default plus sibling keys for each state:

```json
{
  "basicForm": {
    "checkboxStyle": {
      "fillColor":                  "#757575",
      "fillColor.states.selected":  "#1976D2",
      "fillColor.states.disabled":  "#BDBDBD"
    }
  }
}
```

Combined with the `.breakpoints` convention, per-state + per-breakpoint
colors are expressed as:

```json
{
  "fillColor":                    "#757575",
  "fillColor.states.selected":    "#1976D2",
  "fillColor.breakpoints":        [[600, "#9E9E9E"]],
  "fillColor.states.selected.breakpoints": [[600, "#1565C0"]]
}
```

— i.e. `.breakpoints` can attach to either the default path or a
state-qualified path. The resolver composes these into a single
`Breakpointed<WidgetStateProperty<Color>>`.

**Examples.**

```text
companyBasicInfo.basicForm.labelPlacement                        = "inline"
companyBasicInfo.basicForm.stringInputStyle.variant              = "bordered"
companyBasicInfo.basicForm.stringInputStyle.labelStyle.fontSize  = 14
companyBasicInfo.basicForm.sliderStyle.trackColor                = "#80C8FF"
companyBasicInfo.basicForm.stringInputStyle.focusedBackground    = "#EAF4FF"
companyBasicInfo.basicForm.stringInputStyle.focusedBackground.breakpoints
                                                                 = [[600, "#DCEBFF"]]
```

- `companyBasicInfo` is the resolved `TomScope`.
- `basicForm` is the `tomId` passed to `TomFormStyleScope`.
- Shared (base / defaults) properties sit directly under
  `<resolvedPath>.*`; per-widget-type overrides sit under
  `<resolvedPath>.<typeStyleField>.*` (e.g. `stringInputStyle`,
  `sliderStyle`).

**Override semantics.** The programmatic `style:` passed to
`TomFormStyleScope` is the base. Resources override **individual
properties** on top. Anything not named in resources keeps its base
value. This means the typical usage is:

```dart
TomFormStyleScope(
  tomId: 'basicForm',
  style: TomFormStyle.material3.withTheme(Theme.of(context)),
  child: myForm,
)
```

…and the JSON only needs to list the specific deltas — "my customer
wants label placement inline and a bigger hint font" — rather than
re-specifying the entire style.

**Resolution point.** `TomFormStyleScope.of(context)` performs the
merge — on first build it reads `<resolvedPath>.*` from `TomCtr` via
the centralised resolvers, overlays the values on the programmatic
`style`, caches the result, and returns it. Resource changes at runtime
invalidate the cache through the existing resource-provider
notification path.

**No partial matches across scope boundaries.** A form scoped
`companyBasicInfo.basicForm` never falls back to the root or to any
other scope's resources. If the resource file doesn't specify a value,
the programmatic base is used as-is.

### 2.10 Out of scope for this migration

- The actual new field types listed in `tom_ui_widgets_forms.md` that are
  not yet implemented. The sub-style classes for them are created (empty
  of widget-specific knobs) so future implementations slot in without
  another migration, but building the widgets themselves is separate
  work.
- Replacing the ACL breakpoint mechanism. The existing
  `addRowBreakpoint(atWidth:)` stays; `Breakpointed<T>` uses the same
  width notion so everything aligns.

---

## Part 3 — Phased implementation plan

The design in Part 2 is a full replacement, but it is too large to land
in a single working session. The plan below splits it into eight
self-contained phases. Each phase ends with:

- Compile clean (`flutter analyze` shows no new errors).
- All existing tests green (`flutter test` in both `tom_flutter_ui` and
  `tom_flutter_form_test`).
- A commit that leaves the codebase in a coherent state.

Phases 1–4 complete the style-system cut-over; phase 5 is the ACL work
(logically independent and can be scheduled in parallel); phase 6
activates the new error visuals; phases 7–8 add the new showcase demos.
A dedicated phase 0 is a preparation pass that does not touch code.

### 3.0 Phase 0 — Dry run (no code changes)

Read-only pass to confirm assumptions before touching code. Produce:

- A list of every `TomFormStyle` / `TomFormStyleScope` /
  `TomFieldDecorationMixin` consumer (already enumerated: 13 files in
  `tom_flutter_ui`, 8 in `tom_flutter_form_test` including the
  auto-generated `main.reflection.dart`).
- A list of every color-bearing property in the old `TomFormStyle`, so
  the `WidgetStateProperty<Color>` conversion is exhaustive.
- Sample paths used by `TomCtr` today (so the new
  `TomCtr.widgetStateColor` and `TomCtr.breakpointed` sit next to
  existing peers with the same conventions).

Output: a short notes file (can be scratch) — no commit.

### 3.1 Phase 1 — `TomCtr` additions (foundation, purely additive)

**Goal.** Add the four new resolvers to `TomCtr` without touching any
consumer.

**Scope.**

- `TomCtr.textStyle(path)` — reads `fontSize`, `fontWeight`,
  `fontFamily`, `color`, `letterSpacing`, `fontStyle` from a sub-tree
  and returns `TextStyle?`.
- `TomCtr.inputBorder(path)` — reads `kind`
  (`outline`/`underline`/`none`), `width`, `radius`, `color` and returns
  `InputBorder?`.
- `TomCtr.widgetStateColor(path)` — reads the flat default plus sibling
  keys `path.states.<stateName>` (`hovered`, `focused`, `pressed`,
  `selected`, `disabled`, `error`, `dragged`, `scrolledUnder`) and
  returns `WidgetStateProperty<Color>?`.
- `TomCtr.breakpointed<T>(path, T Function(dynamic) parse)` — reads
  `path` and `path.breakpoints` and returns `(T, List<(double, T)>)`.

**Non-goals.** No style-system changes. No consumer updates.

**Tests.** New unit test file
`test/widget_base/tom_ctr_helpers_test.dart` covering each resolver
with representative resource trees (present, absent, malformed).

**Deliverable.** ~250 lines added to
`lib/src/widget_base/tom_construction_helpers.dart`, new test file.

### 3.2 Phase 2 — New style types introduced, old types renamed `*Legacy`

**Goal.** Land the new class hierarchy under its canonical names
without breaking any consumer. Old types keep working under a suffix.

**Scope.**

1. Rename in place (class-rename only; files stay where they are):
   - `TomFormStyle` → `TomFormStyleLegacy`
     (in `lib/src/forms/style/tom_form_style.dart`, file unchanged).
   - `TomFormStyleScope` → `TomFormStyleScopeLegacy`
     (same file treatment).
   - `TomFieldDecorationMixin` → `TomFieldDecorationMixinLegacy`.
2. Mechanical consumer update: every consumer of the three classes (13
   lib+test files in `tom_flutter_ui`, 8 in `tom_flutter_form_test`)
   updates to the `*Legacy` name via find-replace.
3. Add new canonical types (this is the core of the new API, shipped
   unused in this phase):
   - `lib/src/forms/style/tom_form_style.dart` is rewritten to contain:
     `TomFieldStyle` base (with `resolveForBp<T>` and `pickPair<T>`),
     every `Tom<Type>Style` partial-override subclass (all 12 listed
     in §2.3 — even the ones whose widgets don't exist yet, so the
     umbrella is future-proof), the umbrella `TomFormStyle`, the three
     presets with `withTheme(ThemeData)` and the preservation rule.
   - `lib/src/forms/style/tom_form_style_scope.dart` contains the new
     `TomFormStyleScope` that wraps its child in `LayoutBuilder` and
     exposes `widthOf(context)`.
4. Unit tests for the new classes under `test/forms/style/new/` (new
   folder to avoid conflating with the legacy tests that still run).

**Non-goals.** Fields still use `*Legacy`. Decoration mixin still
`TomFieldDecorationMixinLegacy`. No demo changes except the rename.

**Tests.** All existing tests stay green after the rename. New unit
tests for `resolveForBp`, `pickPair`, `TomFieldStyle` defaults, preset
constructors, `withTheme` preservation rule.

**Deliverable.** Two legacy renames across ~20 files, one new
`tom_form_style.dart` (~1000 lines), one new
`tom_form_style_scope.dart` (~100 lines), new test folder.

### 3.3 Phase 3 — Decoration mixin + field cut-over

**Goal.** Switch the two existing concrete field widgets
(`TomFormStringInput`, `TomFormStringDropdown`) off the legacy API onto
the new one.

**Scope.**

- New per-widget decoration mixins:
  - `TomStringInputDecorationMixin<String>` — handles text input
    anatomy (replaces the former `TomFieldDecorationMixin`'s logic).
  - `TomDropdownDecorationMixin<String>` — handles dropdown anatomy.
- Both read from the new `TomFormStyle` via `TomFormStyleScope.of`
  using `pickPair` to resolve every anatomy property per-pair.
- Migrate `TomFormStringInput` to `TomStringInputDecorationMixin` and
  the new style properties.
- Migrate `TomFormStringDropdown` to `TomDropdownDecorationMixin`.
- Also create the 10 *stub* decoration mixins for the unimplemented
  field types — empty mixins that future field widgets can mix in.
- Migrate `test/forms/decoration/tom_field_decoration_mixin_test.dart`
  into separate tests under `test/forms/decoration/` per new mixin.
- Migrate `test/forms/fields/tom_form_string_field_test.dart`.

**Non-goals.** Demos still compile against `TomFormStyleLegacy` and the
old-shaped `copyWith(labelPlacement: ...)` calls. Demo migration is
phase 4.

**Tests.** Fields exercise the new API end-to-end. The legacy tests for
the old mixin are deleted (its replacement is the new per-widget mixin
tests).

**Deliverable.** New decoration files under
`lib/src/forms/decoration/`, rewritten
`lib/src/forms/fields/tom_form_string_field.dart`, migrated mixin and
field tests.

### 3.4 Phase 4 — Demo migration + legacy deletion

**Goal.** Migrate the seven existing demos to the new API and delete
the `*Legacy` classes entirely.

**Scope.**

- Rewrite each demo's `TomFormStyle.material3.copyWith(...)` call to
  work against the new umbrella (moving flat props into
  `defaults.copyWith(...)` as needed; using `withTheme` where it makes
  sense).
- Delete `TomFormStyleLegacy`, `TomFormStyleScopeLegacy`,
  `TomFieldDecorationMixinLegacy` from their files. Remove the file
  scaffolding they lived in if it's now empty.
- Update `tom_flutter_form_test/lib/main.reflection.dart` (regenerate
  via the reflection build step).
- Delete the old-flat-style resource schema docs/examples, if any.
- Remove dropped properties (`fieldSpacing`, `fieldGroupSpacing`,
  `groupDecoration`, `groupPadding`) from all code and docs.

**Non-goals.** ACL / error visuals / new demos — later phases.

**Tests.** All existing tests still green. Demo 6 controls still
correspond to real style props (any control that only worked against
the flat class gets mapped to `defaults.<prop>` or removed).

**Deliverable.** Seven demo updates, three file deletions/shrinks,
regenerated reflection file, green tests.

*After Phase 4, the style-system cut-over is complete.* Phases 5–8
are independent follow-ups.

### 3.5 Phase 5 — ACL row height + append gap extensions

**Goal.** Add the three new row-height APIs and revise
`setAclDefaultAppendGap` per §2.6 (b) and (f).

**Scope.**

- `AclBuilder.setAclDefaultRowHeight(double?, [List<(double, double?)> overrides])`.
- `AclBuilder.setRowHeight(double?, [List<(double, double?)> overrides])`
  (on the most-recent row).
- `AclBuilder.newRow({double? height, List<(double, double?)> heightBpOverrides})`.
- `setAclDefaultAppendGap` signature change:
  - Accept `(double gap, [List<(double, double)> gapBpOverrides])`.
  - Default gap value bumps from 0 to 8.
  - Gap applies to the first component of each row as well.
  - Existing call-sites in demos that passed 0 explicitly stay correct;
    those that relied on the 0 default and expect no gap need to pass
    0 explicitly (audit needed).
- Mirror the additions on `TomAclBuilder<T>`.
- Unit tests in `test/tom_flutter_ui_test.dart` under the `AclBuilder`
  / `AclContainer` groups covering per-row height, default row height,
  breakpoint resolution, and first-component gap.

**Non-goals.** Style system. Demos only change if the 8px default
breaks a current layout (those that want the previous no-gap default
are updated with an explicit `0`).

**Deliverable.** ~200–300 lines in ACL builder + container, new tests.

### 3.6 Phase 6 — Error visuals wiring

**Goal.** Activate `errorBorderEnabled` and `errorIconEnabled` in the
two existing decoration mixins.

**Scope.**

- In `TomStringInputDecorationMixin` and `TomDropdownDecorationMixin`:
  - When `errorBorderEnabled` resolves to `true` and the field is in
    error, use the style's `errorBorder` for the underlying
    `InputDecoration`; otherwise use `fieldBorder` / `focusedBorder`.
  - When `errorIconEnabled` resolves to `true` and the field is in
    error, append a red circle-exclamation icon to the input's
    trailing slot — to the right of any existing suffix icon.
- The presets already carry the right defaults from Phase 2
  (`false`/`false` for material3/compact, `true`/`true` for bordered).
- Widget tests asserting the error icon shows only when in error and
  only when enabled; asserting the border color switches on error.

**Non-goals.** Extending the visuals to other field types (none exist
yet). Styling the error icon itself beyond the canonical red circle.

**Deliverable.** Edits to two decoration mixins, new widget tests.

### 3.7 Phase 7 — Demo 8 (Breakpoints)

**Goal.** New tutorial demo proving breakpoint resolution end-to-end.

**Scope.** A form with a draggable splitter. As the width changes,
styles adapt live: label moves inline → above → floating, fonts shrink
at narrow widths, border toggles, etc. Uses `TomFormStyleScope`'s
`widthOf` implicitly (no demo code touches width directly).

**Deliverable.** `lib/demos/demo_8_breakpoints.dart`, demo registered
in `main.dart`.

### 3.8 Phase 8 — Demo 9 (Preset showcase)

**Goal.** Side-by-side showcase proving visual consistency between
form fields and the surrounding Material theme.

**Scope.** A grid: rows = every currently-implemented field type
(string input, dropdown — more rows become available as widget types
are implemented); columns = the three presets (`material3`, `compact`,
`bordered`). A toggle flips `withTheme(Theme.of(context))` on/off to
show the derivation working.

**Deliverable.** `lib/demos/demo_9_preset_showcase.dart`, demo
registered in `main.dart`.

### 3.9 Sequencing notes

- **Phases 1–4 form the style-system cut-over** and must be done in
  order.
- **Phase 5 (ACL)** can be done in parallel with phases 1–4 — it
  touches different files. If sequencing in the same branch, do it
  after phase 4 to keep diff review boundaries clean.
- **Phase 6 (error visuals)** depends on the new decoration mixins, so
  it must come after phase 3.
- **Phases 7–8 (new demos)** depend on the final style API, so they
  come last.

### 3.10 Rollback plan per phase

Every phase commits to its own revision; if a phase reveals a design
problem:

- **Phase 1** is purely additive — revert is trivial (delete the four
  helpers, drop the test file).
- **Phase 2** is a rename + new unused classes — revert reverses the
  find-replace and deletes the new files; no behavioural change to
  revert.
- **Phase 3** is the first behavioural change — if rolled back, Phase 2
  must also be reverted (legacy classes come back into use).
- **Phase 4** deletes legacy. Once merged, revert requires resurrecting
  the legacy classes — avoid if possible; prefer fixing forward.
- **Phases 5–8** are additive or cosmetic; revert is per-phase.

### 3.11 Estimated effort

| Phase | Size    | Risk   | Notes                                                      |
| ----- | ------- | ------ | ---------------------------------------------------------- |
| 0     | XS      | None   | Read-only preparation.                                     |
| 1     | S       | Low    | Pure TomCtr additions.                                     |
| 2     | L       | Medium | Big rename + big new-class file. Safe because unused.      |
| 3     | L       | Medium | Core behavioural change; runs the new API in production.   |
| 4     | M       | Low    | Mechanical demo migration + legacy deletion.               |
| 5     | M       | Low    | Independent of the style work.                             |
| 6     | S       | Low    | Small, localized.                                          |
| 7     | S       | None   | New demo only.                                             |
| 8     | S       | None   | New demo only.                                             |

Sizes: XS = minutes, S = 1 session, M = 1 long session, L = 1–2
sessions depending on test failures.
