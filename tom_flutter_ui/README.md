# Tom Flutter UI

`tom_flutter_ui` is the Flutter widget library of the Tom Framework. It pairs the
platform-neutral state, security, and resource primitives in
[`tom_core_kernel`](../tom_core_kernel) with a Material- and Cupertino-aware
widget set, a declarative form system, a behavioural action system, and a fluent
row-based layout engine — so an application can be assembled from authorization-
aware, observable, resource-bound widgets rather than hand-wired Flutter ones.

Every widget understands the kernel's cross-cutting concerns: a `tomId` /
`tomGroup` for collective visibility control, the four-state `TomAuthState`
authorization model, resource-driven colours/icons/config, and observable state
binding. You opt into as much or as little of that as you need.

This package is internal to the Tom workspace (`publish_to: none`) and is
consumed by path.

## Getting started

```yaml
dependencies:
  tom_flutter_ui:
    path: ../tom_flutter_ui
```

```dart
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
```

A single barrel re-exports every module below.

## Module catalogue

| Module | Purpose |
| ------ | ------- |
| `widget_base/` | The foundational layer every other module builds on: the `TomAuthorizable` contract, construction-time helpers, the widget/family base classes (`TomNodeBase`, `TomPolicyNodeBase`, `TomWidgetFamily`), scope widgets, the screen-elements provider, and the style resolvers. |
| `theme/` | The theming layer — `TomTheme`, the read-only style and the style-variant system that the widgets and forms resolve their appearance through. |
| `actions/` | The Tom Action system — the behavioural counterpart to widgets. Typed, authorization-aware actions (`TomAction`, `TomActionController`, `TomActionContext`) with atomic transactions, undo/redo history, composite actions, and widget triggers. |
| `resource_auth/` | Resource- and authorization-driven inputs to the widgets: `TomAuthState`, resource-resolved `TomColors` / `TomIcons`, and the config provider. |
| `forms/` | The declarative form system: the `TomForm` data model, validators, selectable sources, the form event bus, the style/decoration system (Material + Cupertino), and the full field catalogue (see below) behind a `FormFieldFamily` factory. |
| `groups/` | `TomUIGroup` collective-visibility control — drive an entire UI region's authorization/visibility without an id on every leaf widget. |
| `advanced_container_layout/` | A fluent, row-based layout engine (`AdvancedContainerLike`) modelled on the Java Swing `StdAdvancedContainer` API, with ACL (authorization) integration. |
| `widgets/` | The general widget kit — buttons, chips, containers, dialogs, inputs, labels, lists, navigation, progress, selects, sliders, slivers, tables, toggles, trees, plus animated/builder/effect/image/interaction helpers. |
| `custom/` | Non-form composite widgets that reuse the same authorization/resource/state systems: auth guard, auth tree, empty state, error boundary, infinite scroll, loading overlay, radio group, skeleton loader. |

## The form field catalogue

The `forms/` module exposes a parallel Material and Cupertino field set, selected
through the `FormFieldFamily` factory. The field types span:

- **String** — single-line, multi-line, selection, and string-list fields.
- **Boolean** — switch/checkbox-style bool fields.
- **Numeric** — `int`, `double`, range, and int-list fields.
- **Date / time** — date, time, date-time, and `Duration` fields.
- **Enum / object** — enum and object fields, plus search/lookup fields.
- **File** — file-picker fields.
- **Nullable** — nullable wrappers over the above.
- **Collections** — list, inline-list, expandable-list, and master-detail list
  forms, with reordering, row-move, and unsaved-changes guarding.

Each field consumes the shared validation, style, and decoration systems, so the
Material and Cupertino concretes stay visually and behaviourally consistent.

## Usage

A `TomForm` is subclassed for each data model: declare the fields, build them in
`createFormElements()`, and the form drives bind / save / discard, validation,
authorization, and resource resolution for every field it owns.

```dart
@tomReflector
class AddressForm extends TomForm<AddressData> {
  AddressForm({super.parentForm}) : super(formId: 'address');

  late final TomFormStringInput street;
  late final TomFormStringInput city;

  @override
  void createFormElements() {
    // build the concrete fields and bind them to the model …
  }
}
```

The runnable [`example/phase1_demo.dart`](example/phase1_demo.dart) exercises the
full Phase-1 feature set end to end — string fields and dropdowns, the form
lifecycle, the four authorization states, `TomAuthorizationGroup` / `TomAuthorizer`,
form nesting, validation (sync, async, cross-field, debounced), and resource
resolution.

## Additional information

- Module-level documentation lives in [`doc/`](doc).
- Development guidelines live in
  [`_copilot_guidelines/`](_copilot_guidelines/index.md).
- The reference target state for the refactor is `tom_core_kernel`.
