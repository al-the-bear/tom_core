# Forms Module

`forms/` is the **declarative form system** of `tom_flutter_ui`: a data model
(`TomForm` / `TomField`) that binds to a reflected `TomClass`, a validation
layer, pluggable selectable sources, a typed event bus, a Material + Cupertino
style/decoration system, and the full field catalogue behind a
`FormFieldFamily` factory.

The guiding split is **data vs presentation**. A `TomForm` is a *model*: it owns
the fields, their dirty/valid state, the bind→edit→validate→save lifecycle, and
authorization — none of which needs a widget tree. Each `TomField` exposes a
`widget` getter that renders that state; swapping the Material concrete for its
Cupertino sibling changes the rendering without touching the model.

## Table of Contents

- [Overview](#overview)
- [Data model: `TomForm` and `TomField`](#data-model-tomform-and-tomfield)
- [Validation](#validation)
- [Selectable sources](#selectable-sources)
- [The event bus](#the-event-bus)
- [Style and decoration](#style-and-decoration)
- [The field catalogue and `FormFieldFamily`](#the-field-catalogue-and-formfieldfamily)
- [List and master-detail forms](#list-and-master-detail-forms)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomForm<T extends TomClass>` | abstract model | Owns fields and the bind/save/discard/validate lifecycle; is a `TomScreenElementsProvider`, `TomActionController`, and `TomFormEventSource`. |
| `TomField<T>` | abstract model | A single value with dirty tracking (`get`/`set`/`commit`/`reset`), validation state, and 5-layer authorization; renders via its `widget` getter. |
| `Validators` | static factory | Built-in `required`/`email`/`minLength`/`maxLength`/`pattern`/`min`/`max`/`compose` rules. |
| `ValidationResult` | sealed | `ValidationPristine` / `ValidationSuccess` / `ValidationError` / `ValidationPending`. |
| `FormValidationError` | value | A cross-field error spanning several `TomField`s. |
| `SelectableItem<T>` / `TomSelectableSource<T>` | value / interface | Items for selection fields; `StaticSelectableSource` is the fixed-list implementation. |
| `TomFormEvent` (+ subtypes) | events | Field/form/list lifecycle events fired on the bus. |
| `TomFormEventListener` / `TomFormInspector` | mixin / collector | Typed event handling; the inspector buffers and filters events. |
| `TomFormStyle` / `TomBreakpoint` / `LabelPlacement` … | style | The responsive, themeable decoration system and anatomy placement enums. |
| `FormFieldFamily` | factory | Builds a Material or Cupertino concrete from one declaration, returning the shared abstract base. |
| `TomListForm` / `TomMasterDetailListForm` … | model | Collections of sub-forms with add/remove/reorder. |

## Data model: `TomForm` and `TomField`

A concrete form extends `TomForm<T>` for its bound data type `T` and declares
its fields. `bind(T)` attaches a data object, edits flow through the fields,
`validate()` runs all field validators, and `save()` writes back (optionally
committing baselines so the fields are no longer dirty); `discard()` resets.
`isDirty` and `isValid` aggregate the field states.

`TomField<T>` is the unit of state and is fully usable without rendering:

```dart
final name = field; // some TomField<String>
name.get();             // current value
name.set('Bob');        // mutate; isDirty becomes true
name.isDirty;           // value != initialValue
name.commit();          // current value becomes the new initial (clears dirty)
name.reset();           // restore the initial value and clear validation state
await name.validate();  // run validators → ValidationResult
```

Authorization is resolved through five layers (field override → form → group →
authorizer → adapter) into a `TomAuthState` (`none` < `disabled` < `read` <
`full`), so a field can be hidden, shown read-only, or made interactive without
the form knowing why.

## Validation

`Validators` is a static factory of `Validator<T>` functions — each is a
`FutureOr<ValidationResult> Function(T value)`, so rules can be sync or async.
`compose` chains rules and **stops on the first failure**:

```dart
final rule = Validators.compose<String>([
  Validators.required(),     // → error.required
  Validators.minLength(3),   // → error.minLength {min: 3}
  Validators.maxLength(12),  // → error.maxLength {max: 12}
]);
final result = await rule('ab'); // ValidationError('error.minLength', {min: 3})
```

Results are a `sealed` family: `ValidationPristine` (never validated),
`ValidationSuccess`, `ValidationError(errorKey, {params})`, and
`ValidationPending` (async in flight). `ValidationError` equality compares only
the `errorKey`, so tests can assert the key without reconstructing params.
`FormValidationError` represents a **cross-field** error (e.g. "end before
start"); it carries the involved `TomField`s and exposes their ids via `tomIds`.

## Selectable sources

Selection fields (dropdowns, pickers, lookups, search) read their options from a
`TomSelectableSource<T>`. Each option is a `SelectableItem<T>` (`value`, `label`,
optional `description`, and an `enabled` flag; equality is by `value`).
`StaticSelectableSource` wraps a fixed list and returns an **unmodifiable**
snapshot from `getItems()`; dynamic sources can additionally expose an
`itemsStream` (static sources return `null`).

## The event bus

`TomForm` is a `TomFormEventSource` — `addListener` / `removeListener` /
`fireEvent`. Events are a typed hierarchy under `TomFormEvent` (carrying a
`timestamp`, a `source` id, and a `description`): field events
(`FieldValueChangedEvent`, `FieldValidatedEvent`, `FieldAuthChangedEvent`,
`FieldBoundEvent`, `FieldCommittedEvent`), form events (`FormBoundEvent`,
`FormSavedEvent`, `FormDiscardedEvent`, `FormValidatedEvent`), and list-form
events (`ListItemAddedEvent`, `ListItemRemovedEvent`, `ListItemReorderedEvent`).

`TomFormEventListener` is a mixin with a no-op handler per event type and a
`handleEvent` dispatcher, so a listener overrides only what it cares about.
`TomFormInspector` is a ready-made collector — it buffers every event and offers
`ofType<E>()`, `fromSource(id)`, `length`, `isEmpty`, and `clear()` for
debugging, tests, or event-log UIs.

## Style and decoration

Form rendering is themeable and responsive, kept separate from the model:

- `TomFormStyle` / `TomFormStyleScope` deliver the active style down the tree;
  `TomThemeSpec` carries the theme spec, and the `cs.*` colour-scheme token
  resolvers (`resolveColorSchemeToken` / `resolveAnyColor` / `isColorSchemeToken`)
  map token strings to concrete `Color`s against the active `ColorScheme`.
- `TomBreakpoint` holds the shared `mobile` / `tablet` / `desktop` ladder
  (mutable, retuned once at startup) and `resolve(name)` maps a named key to its
  current pixel value (unknown names → `null`, i.e. "skip this entry").
- The anatomy enums (`LabelPlacement`, `ErrorPlacement`, `RequiredIndicator`,
  `DescriptionPlacement`, `ActionIconPlacement`) configure where each part of a
  field sits, consumed by the decoration mixins
  (`TomStringInputDecorationMixin`, `TomDropdownDecorationMixin`,
  `TomGenericFieldDecorationMixin`).

## The field catalogue and `FormFieldFamily`

Every field type ships in two families that share an abstract base
(`TomFormStringField`, `TomFormEnumField<T>`, `TomFormFileField`, …): the
Material `TomForm…` concretes and the Cupertino `TomCupertinoForm…` concretes.
`FormFieldFamily` is the factory that picks one at construction time while
returning the shared base, so a single declaration can resolve to either side —
e.g. swap families by breakpoint:

```dart
final family = isNarrow ? FormFieldFamily.cupertino : FormFieldFamily.material;
final name = family.stringInput('user.name', '');   // TomFormStringField
final age  = family.intInput('user.age', 0);        // TomFormIntField
final dob  = family.datePicker('user.dob', DateTime(2000),
    firstDate: DateTime(1900), lastDate: DateTime.now());
```

Factory methods cover strings, numerics (int/double, nullable variants),
boolean switches, date/time pickers, enum/object pickers, search/lookup, and
file upload. `FormFieldFamily.material` / `.cupertino` are const singletons;
`isCupertino` reports which side a family resolves to.

## List and master-detail forms

For repeating data the module provides sub-form collections: `TomListForm` (the
base add/remove/reorder model), `TomInlineListForm`, `TomExpandableListForm`,
and `TomMasterDetailListForm`, with supporting widgets (toolbar, move/reorder
controls). They fire the `ListItem*` events above so the surrounding UI can
react to structural changes.

## Dependencies

- `package:flutter/material.dart` / `package:flutter/cupertino.dart` — the two
  rendering families and shared types (`TimeOfDay`, `IconData`, …).
- `package:tom_core_kernel/...` — `TomClass`/reflection, `TomScope`,
  `TomObject`/observables, and the authorization types
  (`TomAuthState`, `TomAuthorizer`, `TomUIStateController`, …).

> The model, validation, selectable-source, event, and style-value surfaces are
> pure logic and need no widget tree, but the package barrel pulls in
> `flutter/material` (→ `dart:ui`), so run the example under the Flutter
> toolchain — see
> [`example/forms/forms_example.dart`](../example/forms/forms_example.dart),
> exercised by `flutter test`.
