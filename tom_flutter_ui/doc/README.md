# Tom Flutter UI — documentation set

*The index for everything under `tom_flutter_ui/doc/`. Start here.*

> **⚠️ Work in progress — unstable API.** `tom_flutter_ui` is part of the Tom
> Core stack, under active development and not yet stable; its version number is
> a publishing counter and carries no promise about API maturity. Design
> specifications below mark which parts are **shipped** versus **proposed**;
> read each doc's status line before treating a class or method name as a stable
> API.

This folder documents `tom_flutter_ui` at three levels:

- **Design specifications** — the *why* and the cross-cutting model: identity,
  the four-state authorization model, resource resolution, the forms framework,
  the action system, and the layout engine. These are the authoritative
  references for how the pieces fit together.
- **Module references** — one focused doc per `lib/src/` module, describing the
  public API of that module in isolation. Reach for these when you are working
  inside a single module.
- **API summaries** — a symbol-level mirror of a module's surface, under
  `api/`. Reach for one when you know what you are looking for and want the
  signature, not the explanation.

Every Tom widget builds on the platform-neutral state, security, and resource
primitives in [`tom_core_kernel`](../../tom_core_kernel/README.md); the package
overview is in the [package README](../README.md).

## Start here

| Document | Role |
| --- | --- |
| [tom_flutter_ui_user_guide.md](tom_flutter_ui_user_guide.md) | Practical getting-started guide — the fastest path from zero to a working authorization-aware screen. |
| [tom_ui_design_architecture.md](tom_ui_design_architecture.md) | Master architecture reference — identity, authorization, resources, widgets, forms, actions, screens, data sources, theming, and debug tooling in one place. |

## Design specifications

| Document | Scope | Status |
| --- | --- | --- |
| [tom_ui_design_architecture.md](tom_ui_design_architecture.md) | The whole UI architecture (14 sections + appendix). | Architecture reference — core infrastructure implemented. |
| [tom_observable_state_management.md](tom_observable_state_management.md) | The observable-state foundation (`TomObject<T>` family) that everything else binds to. | Living document — implemented, extended as patterns evolve. |
| [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) | The complete forms-framework specification — typed observable fields, validation, layout separation. | Active specification. |
| [tom_ui_list_forms.md](tom_ui_list_forms.md) | The list-form layer (`TomListForm` and its three renderers) — the *list* dimension of the forms model. | Active. |
| [acl_design_specification.md](acl_design_specification.md) | The Advanced Container Layout engine — the declarative row-based layout container (`Acl` / `AclBuilder`). | Design specification. |
| [container_widget_resources_authorization.md](container_widget_resources_authorization.md) | IDs, resources, and groups across the widget tree — how identity and resource paths drive authorization. | Design specification — partially implemented; read the §0 reconciliation tables first. |
| [tom_ui_flutter_widgets.md](tom_ui_flutter_widgets.md) | Inventory of Flutter SDK widgets relevant to Tom, with per-widget wrap decisions (composition vs. extension). | Reference (scanned from Flutter SDK). |

## Module references

One doc per `lib/src/` module — the public API of that module in isolation.

| Document | Module |
| --- | --- |
| [widget_base.md](widget_base.md) | `widget_base/` — the family base chain, `TomWidgetMixin`, identity, resource/authorization plumbing. |
| [widgets.md](widgets.md) | `widgets/` — the general widget kit. |
| [forms.md](forms.md) | `forms/` — the form / field runtime. |
| [form_authorizers.md](form_authorizers.md) | Form-field authorizers — how per-field `TomAuthState` is applied. |
| [groups.md](groups.md) | `groups/` — `tomGroup` collective visibility control. |
| [actions.md](actions.md) | `actions/` — the action runtime. |
| [resource_auth.md](resource_auth.md) | `resource_auth/` — colour / icon / config resolution. |
| [advanced_container_layout.md](advanced_container_layout.md) | `advanced_container_layout/` — the ACL widgets and builder. |
| [theme.md](theme.md) | `theme/` — theming and `TomButtonVariants`. |
| [custom.md](custom.md) | `custom/` — extension points for application-specific widgets. |
| [kernel_types.md](kernel_types.md) | `kernel_types.dart` — the one bridge to `tom_core_kernel`: every kernel type named in a public signature here. |
| [debug_and_inspection_system.md](debug_and_inspection_system.md) | The runtime debug / inspection overlay. |

## API summaries

Symbol-level mirrors of a module's public surface: every exported type with its
members, signatures and defaults, for looking something up rather than reading
about it. The module reference beside each one is the document that explains
*why*; the summary is the inventory.

| Document | Module |
| --- | --- |
| [api/api_summary_actions.md](api/api_summary_actions.md) | `actions/` — thirteen public types. Companion to [actions.md](actions.md). |

Only `actions` has one so far; the other modules are covered by their module
reference alone.

## Working notes

Migration and analysis notes kept for maintainers; not part of the public API
surface.

| Document | Purpose |
| --- | --- |
| [formstyle_migration.md](formstyle_migration.md) | `FormStyle` migration notes. |
| [flutter_alignments_improvements.md](flutter_alignments_improvements.md) | Flutter alignment gaps and improvement areas. |
| [flutter_dart_listener_patterns.md](flutter_dart_listener_patterns.md) | Background reference: all Flutter/Dart observer/observable/listener patterns and their trade-offs — context for the Tom observable-state layer. |
