# tom_flutter_ui

> Part of the Tom Framework. © Peter Nicolai Alexis Kyaw — BSD 3-Clause
> licensed.

The Flutter widget library of the Tom Framework: authorization-aware,
resource-bound, observable widgets, a declarative form system, the Tom Action
system, and a fluent row-based layout engine over
[`tom_core_kernel`](../tom_core_kernel/README.md).

## Overview

`tom_flutter_ui` pairs the platform-neutral state, security, and resource
primitives in [`tom_core_kernel`](../tom_core_kernel/README.md) with a Material-
and Cupertino-aware widget set, a declarative form system, a behavioural action
system, and a fluent row-based layout engine — so an application is assembled
from authorization-aware, observable, resource-bound widgets rather than
hand-wired Flutter ones.

Every Tom widget understands the kernel's cross-cutting concerns:

- a `tomId` / `tomGroup` for collective visibility control;
- the kernel's four-state [`TomAuthState`](../tom_core_kernel/README.md)
  authorization model (hidden / disabled / read-only / editable) — the UI
  honours all four distinctly, eliding hidden elements from the tree, greying
  disabled ones, and locking read-only ones;
- resource-driven colours / icons / config resolved by `tomId`;
- observable state binding to the kernel's `TomObject<T>` family.

You opt into as much or as little of that as you need: the general widget kit
renders with nothing but an app-level resource provider, while the form and ACL
layers add reflection-backed binding and authorization on top.

## Installation

```yaml
dependencies:
  tom_flutter_ui:
    path: ../tom_flutter_ui
```

Or:

```sh
flutter pub add tom_flutter_ui --path ../tom_flutter_ui
```

This package is internal to the Tom workspace (`publish_to: none`) and is
consumed by path. It targets **Dart SDK `^3.11.0`** / **Flutter `>=1.17.0`** and
depends on the sibling [`tom_core_kernel`](../tom_core_kernel/README.md) (state,
security, resources, reflection). A single barrel re-exports every module:

```dart
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
```

## Features

### Widget kit (`widgets/`)

The general-purpose widget toolkit — every common Flutter widget given a Tom
wrapper that adds `tomId`, authorization, and resource resolution.

| Type | What it is |
| ---- | ---------- |
| `TomElevatedButton`, `TomTextButton`, `TomIconButton` | Authorization-aware buttons |
| `TomText`, `TomRichText`, `TomBadge`, `TomChip` | Resource-bound display widgets |
| `TomCard`, `TomListTile`, `TomColumn`, `TomCenter`, `TomAlign` | Containers & layout |
| `TomCheckbox`, `TomSwitch`, `TomSlider`, `TomAutocomplete` | Inputs & toggles |
| `TomLinearProgressIndicator`, `TomCircularProgressIndicator` | Progress |
| `TomAlertDialog`, `TomAboutDialog`, `TomBottomSheet`, `TomBanner` | Dialogs & surfaces |
| `TomAnimated*` (`TomAnimatedContainer`, `TomAnimatedOpacity`, …) | Animated variants |
| `TomAclBuilder` | Widget-level entry point into the ACL layout engine |

### ACL — advanced container layout (`advanced_container_layout/`)

A fluent, row-based layout engine modelled on the Java Swing
`StdAdvancedContainer` / `AdvancedContainerLike` API, with first-class
authorization integration.

| Type | Responsibility |
| ---- | -------------- |
| `AclBuilder` | Fluent builder — `append`, `newRow`, sizing, growth, variants |
| `Acl` / `AclLayout` / `AclContainer` | The rendered layout widgets |
| `AclFlags` | `expandX` / `expandY` / `expand` growth flags |
| `AclBorderStyle`, `AclBorderKind`, `AclTitlePosition` | Border & titled-group styling |
| `AclVariant`, `AclRowBreakpoint`, `AclVariantDetector` | Responsive variants & breakpoints |
| `AclGroupVisibilityController`, `AclBinaryVisibilityController` | Group show/hide control |
| `AclDeviceContext`, `AclFormFactor`, `AclDensity` | Adaptive device sizing inputs |

### Forms (`forms/`)

The declarative form system: the `TomForm` data model, validators, selectable
sources, the form event bus, the Material+Cupertino style/decoration system, and
the full field catalogue behind a `FormFieldFamily` factory.

| Type | Responsibility |
| ---- | -------------- |
| `TomForm<T>` | The form base — bind / save / discard, validation, authorization |
| `FormFieldFamily` | Factory selecting the Material or Cupertino concrete per field |
| `TomFormStyle`, `TomFormStyleScope` | Presets (`material3`, `compact`, `bordered`) + inherited scoping |
| `LabelPlacement`, `DescriptionPlacement`, `RequiredIndicator` | Field decoration controls |
| `TomSelectableSource` | Pluggable option sources (sync / async / filtered) |
| `TomEnumSelectableSource<E>` | Enum options labelled from the text bundle, relabelled on a locale change |
| `TomFormEvent`, `TomFormEventSource`, `TomFormEventListener` | The form event bus |
| `TomListForm`, `TomMasterDetailListForm`, `TomListFormToolbar` | Collection / master-detail forms |
| `TomFormErrorBanner`, `TomFormInspector` | Error surfacing & debug inspection |

The field catalogue spans a parallel Material/Cupertino set: **string**
(`TomFormStringInput`, `TomFormStringDropdown`, `TomFormStringRadioGroup`,
`TomFormStringFilterChips`, `TomFormStringListField`), **boolean**
(`TomFormBoolSwitch`, `TomFormBoolCheckbox`, `TomFormBoolToggle`), **numeric**
(`TomFormIntInput`, `TomFormIntStepper`, `TomFormDoubleSlider`,
`TomFormIntRangeField`, `TomFormIntListField`), **date/time** (`TomFormDateField`,
`TomFormTimeField`, `TomFormDateTimeField`, `TomFormDurationField`,
`TomFormDateRangeField`), **enum/object** (`TomFormEnumDropdown`,
`TomFormEnumSegmented`, `TomFormObjectField`, `TomFormLookupField`,
`TomFormSearchField`), **file** (`TomFormFileField`, `TomFormFileUpload`,
`TomFormFileDropzone`, `TomFormFileThumbnail`), and **nullable** wrappers (`TomFormNStringInput`,
`TomFormNIntInput`, `TomFormNDateInput`, `TomFormNEnumDropdown`).

The file fields come with their own plumbing: `TomFilePickerRegistry` (one
application-wide picker adaptor, so the package needs no dependency on
`file_picker` / `image_picker`), `TomFileTransferController` (streaming upload
and download with progress, cancel and retry over the kernel's
`TomFileTransferClient`), and `TomFileTransferIndicator`. See
[`doc/forms_file_fields.md`](doc/forms_file_fields.md).

### Theming (`theme/`)

| Type | Responsibility |
| ---- | -------------- |
| `TomTheme`, `TomThemeScope` | The Tom theme and its inherited scope |
| `TomStateStyle` | The treatment of a withheld authorization state; the theme carries one per state (`read`, `disabled`) |
| `TomButtonVariants` | Button style-variant set |

### Resource & configuration inputs (`resource_auth/`)

| Type | Responsibility |
| ---- | -------------- |
| `TomUIColors`, `TomUIIcons` | Resource-resolved colour / icon namespaces |
| `TomUIColorAdapter`, `TomUIIconAdapter` | The pluggable resource adapter contracts |
| `AllColorsAdapter`, `AllIconsAdapter`, and the `MaterialOnly…` / `CupertinoOnly…` pairs | Full and single-family adapters for each namespace |
| `TomConfigProvider`, `TomConfigEnvironment`, `TomConfigPlatform` | Config / environment inputs |

### Kernel types (`kernel_types.dart`)

The package does not re-export `tom_core_kernel` wholesale: the two packages
answer different questions, and an application doing kernel work should import
the kernel and say so. One explicit list is the bridge instead, and every
kernel type named in a public `tom_flutter_ui` signature is on it. Importing
both barrels into one library is legal — the config enums above are named
`TomConfig…` precisely so they do not collide with the `TomEnvironment` and
`TomPlatform` that `tom_basics` (and so the kernel barrel) already declares.

| Group | Types |
| ----- | ----- |
| Authorization | `TomAuthState`, `TomAuthorizable`, `TomAuthorizationGroup`, `AuthGroupMode`, `TomAuthorizationAdapter`, `TomAuthorization`, `TomAuthorizer`, `TomAuthorizerStrategy`, `TomUIStateController` |
| Scopes | `TomScope`, `TomScopeBase`, `TomScopeMixin` — the type of `scope:` on every Tom widget |
| Observables | `TomObservable`, `TomObserver`, `TomFunctionObserver`, `TomObject`, `TomClass`, `TomList`, `TomListLifecycleListener`, `TomObservableEnum` |
| File transfer | `TomFileTransferClient`, `TomFileSource`, `TomFileMetadata`, `TomTransferProgress`, `TomTransferCancellation`, `TomFileTransferException` |

Anything outside that list is kernel work rather than UI work: import
`package:tom_core_kernel/tom_core_kernel.dart` for it. See
[`doc/kernel_types.md`](doc/kernel_types.md).

### Actions (`actions/`)

The behavioural counterpart to widgets — typed, authorization-aware actions with
atomic transactions, undo/redo history, composites, and widget triggers.

| Type | Responsibility |
| ---- | -------------- |
| `TomAction`, `TomSimpleAction`, `TomCompositeAction` | The action base & primitives |
| `TomActionController`, `TomActionContext` | Action registry (canonical-path prefix) & per-invocation context |
| `TomActionTransaction`, `TomUndoHistory`, `TomUndoRedoContext` | Atomicity & undo/redo |
| `TomCompositeAction`, `TomCompositeStep` | Composed multi-step actions |
| `TomActionTrigger` | Widget trigger binding — the one type that dispatches an action |

### Foundation & groups (`widget_base/`, `groups/`, `custom/`)

| Type | Responsibility |
| ---- | -------------- |
| `TomNodeBase`, `TomPolicyNodeBase`, `TomWidgetFamily` | The widget / family base classes |
| `TomStatelessWidget`, `TomStatefulWidget`, `TomState` | Construction-time helpers |
| `TomScreenElementsProviderBase`, `TomStyleResolvers`, `TomCtr` | Element provider & resolvers |
| `TomAuthorizationGroup` | Collective visibility control without an id on every leaf |
| `TomAuthGuard`, `TomAuthTreeView`, `TomEmptyState`, `TomErrorBoundary` | Non-form composites |
| `TomInfiniteScroll`, `TomLoadingOverlay`, `TomRadioGroup`, `TomSkeletonLoader` | More composites |

## Quick start

The general widget kit renders with nothing but an app-level resource provider —
no reflection or codegen required:

```dart
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  // Tom widgets resolve labels/colours through the resource layer; install a
  // provider and the all-colours adapter so the kit renders with its explicit
  // values rather than failing a resource lookup.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomUIColors.adapter = AllColorsAdapter();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: _Demo()))));
}

class _Demo extends StatelessWidget {
  const _Demo();
  @override
  Widget build(BuildContext context) {
    // A two-row ACL layout: label + badge, then a button. Explicit text/child
    // values render without any resource entries in the provider.
    return AclBuilder()
        .append(TomText(text: 'Hello, Tom'))
        .append(TomBadge(labelText: '3', child: const Icon(Icons.star)))
        .newRow()
        .append(TomElevatedButton(
          onPressed: () {},
          child: const Text('Save'),
        ))
        .build(); // returns an Acl widget (a StatelessWidget)
  }
}
```

Run it with `flutter run example/gallery_demo.dart` for the full gallery.

## Example projects

| Sample | Demonstrates |
| ------ | ------------ |
| [`example/gallery_demo.dart`](example/gallery_demo.dart) | A single `runApp` demo paging the three pillars — widget kit, custom composites, and the form feature set (lifecycle, four authorization states, authorizers, nesting, validation) |
| [`example/widgets/`](example/widgets) | Per-widget usage snippets for the general kit |
| [`example/advanced_container_layout/`](example/advanced_container_layout) | ACL sizing, growth, borders, variants, breakpoints |
| [`example/forms/`](example/forms) | Form fields, validation, styles, list / master-detail forms |
| [`example/actions/`](example/actions) | Actions, transactions, undo/redo, triggers |
| [`example/theme/`](example/theme) · [`example/resource_auth/`](example/resource_auth) · [`example/groups/`](example/groups) · [`example/custom/`](example/custom) · [`example/widget_base/`](example/widget_base) | Per-module samples |

The companion demo/test apps [`tom_flutter_form_test`](../tom_flutter_form_test/doc/demo_catalogue.md)
and [`tom_flutter_ui_test`](../tom_flutter_ui_test/doc/demo_catalogue.md) exercise
the whole library across dozens of interactive demos — see their demo catalogues.

> **Cross-package samples.** The `tom_core_samples` showcases —
> [`core_flutter_ui_showcase`](../tom_core_samples/core_flutter_ui_showcase/README.md),
> [`core_flutter_form_showcase`](../tom_core_samples/core_flutter_form_showcase/README.md),
> [`core_flutter_acl_sample`](../tom_core_samples/core_flutter_acl_sample/README.md),
> and [`core_flutter_acl_responsive`](../tom_core_samples/core_flutter_acl_responsive/README.md)
> — teach this library surface by surface against one todo-management domain. See
> the [samples map](../tom_core_samples/README.md) for the full learning path.

## Usage

### A form

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

### Styling forms

`TomFormStyle` carries three presets — `material3` (default), `compact`
(floating labels, tighter gaps), and `bordered` — applied to a subtree via
`TomFormStyleScope`. Fields below the scope resolve their decoration through it;
`LabelPlacement`, `DescriptionPlacement`, and `RequiredIndicator` tune individual
field chrome.

### The ACL layout engine

`AclBuilder` is fluent: `append()` adds a component to the current row, `newRow()`
starts a new one, `setPSize` / `setMSize` set preferred / minimum sizes, and
`expandX()` distributes surplus width. `addVariant` / `addRowBreakpoint` make the
layout responsive; `AclBorderStyle` + `AclTitlePosition` draw titled groups.
`build()` returns an `Acl` widget you drop into any Flutter tree.

### Actions

A `TomActionController` owns and names a group of `TomAction`s, supplying the
`<scopePath>.<controllerId>.<actionId>` canonical path used for authorization
and resource lookup — it is a registry and never runs an action. `TomActionTrigger` is what
dispatches one: bind it to a widget callback and it checks `canExecute`, opens a
`TomActionTransaction` so the mutation is atomic, and pushes the committed
transaction onto the application's `TomUndoHistory`.

## Architecture

```
tom_flutter_ui
├── widget_base/                 # TomNodeBase / TomPolicyNodeBase / TomWidgetFamily,
│                                #   scope widgets, screen-elements provider, resolvers
├── theme/                       # TomTheme + style-variant system
├── resource_auth/               # TomUIColors / TomUIIcons / TomConfigProvider
├── kernel_types.dart            # the one bridge to tom_core_kernel
├── groups/                      # TomWidgetMixin — collective-visibility wiring
├── actions/                     # TomAction system (transactions, undo/redo, triggers)
├── advanced_container_layout/   # AclBuilder fluent row engine + Acl render widgets
├── forms/                       # TomForm model + FormFieldFamily field catalogue + styles
├── widgets/                     # general widget kit (buttons … trees, animated variants)
└── custom/                      # non-form composites (auth guard/tree, overlays, skeleton)
```

Every layer rests on `widget_base` (the `TomAuthorizable` contract + base
classes) and resolves cross-cutting concerns through `resource_auth` (colours,
icons, configuration) and `theme` (appearance). `forms`, `widgets`, and
`advanced_container_layout` are the three feature surfaces an app composes.

| Type | Responsibility |
| ---- | -------------- |
| `TomNodeBase` / `TomPolicyNodeBase` | Base widget classes carrying `tomId` + authorization |
| `TomWidgetFamily` | Material/Cupertino family selection |
| `TomForm<T>` | The form data model + lifecycle |
| `FormFieldFamily` | Per-field Material/Cupertino concrete factory |
| `AclBuilder` / `Acl` | The fluent layout builder and its rendered widget |
| `TomAction` / `TomActionController` | The action system entry points |
| `TomUIColors` / `TomUIIcons` | Resource-resolved colour / icon namespaces |
| `TomAuthorizationGroup` | Collective visibility control |

## Ecosystem

```
        tom_core_kernel  (state · security · resources · reflection)
                 │
   ┌─────────────┼──────────────────────┐
   │             │                       │
tom_core_flutter │                 tom_flutter_ui   ← this package
 (kernel-on-     │              (widget kit · forms ·
  Flutter        │               ACL · actions · theme)
  binding)       │
                 ▼
                tom_core_server
```

`tom_flutter_ui` is the rich UI toolkit; the lower-level kernel-on-Flutter
binding lives in [`tom_core_flutter`](../tom_core_flutter/README.md). Both demo
harnesses ([`tom_flutter_form_test`](../tom_flutter_form_test/README.md),
[`tom_flutter_ui_test`](../tom_flutter_ui_test/README.md)) target
`tom_flutter_ui` + `tom_core_kernel` and do **not** depend on
`tom_core_flutter`. See the repository map at [`../README.md`](../README.md).

## Further documentation

Per-module guides live in [`doc/`](doc):
[`widget_base.md`](doc/widget_base.md), [`theme.md`](doc/theme.md),
[`actions.md`](doc/actions.md),
[`resource_auth.md`](doc/resource_auth.md), [`forms.md`](doc/forms.md)
(+ [`form_authorizers.md`](doc/form_authorizers.md),
[`forms_file_fields.md`](doc/forms_file_fields.md),
[`formstyle_migration.md`](doc/formstyle_migration.md)),
[`groups.md`](doc/groups.md),
[`advanced_container_layout.md`](doc/advanced_container_layout.md)
(+ [`flutter_alignments_improvements.md`](doc/flutter_alignments_improvements.md)),
[`widgets.md`](doc/widgets.md), [`custom.md`](doc/custom.md),
[`kernel_types.md`](doc/kernel_types.md), and
[`debug_and_inspection_system.md`](doc/debug_and_inspection_system.md).
Development guidelines live in `_copilot_guidelines/`, which is workspace
tooling rather than part of this package's documentation.

## Status

- **Version:** 1.1.0 (`publish_to: none`)
- **Tests:** run with `flutter test`. No count is given: a count is a claim
  nothing checks, and every added test would be a README edit nobody makes. The
  version above is checked, because a wrong one is the claim that actively
  misleads.
