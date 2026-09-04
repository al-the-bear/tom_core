# Tom Widget Architecture: IDs, Resources, Groups

*Part of the [Tom Flutter UI documentation set](README.md).*

Date: 2026-03-18 (updated 2026-04-07; reconciled against shipped API 2026-07-15;
inline rename + proposed-appendix pass 2026-07-16 — done)
Status: **Design specification — partially implemented.** The core infrastructure
(node/policy/family base chain, authorization, scoping, actions, the `TomForm` /
`TomField` system, `TomScreenElementsProvider`, resource resolution) ships in
`tom_flutter_ui` / `tom_core_kernel`. Substantial portions below describe
**proposed, not-yet-implemented** API and some constructs are named differently
in the shipped code. Read the reconciliation tables in §0 before treating any
class/method name here as a shipped API.
Package: tom_flutter_ui / tom_core_kernel

---

## 0. Reconciliation against the shipped API (verified 2026-07-15)

> **Read this first.** This document is an *architecture / design specification*.
> Every `Tom*` / `Acl*` identifier below was cross-checked against the shipped
> `tom_flutter_ui`, `tom_core_kernel`, and `tom_core_flutter` sources on
> 2026-07-15. Names not in one of the two tables below **are shipped as written**
> (e.g. `TomForm`, `TomField`, `TomNodeBase`, `TomPolicyNodeBase`, `TomFamilyBase`,
> `TomAction*`, `TomScope`, `AclBuilder`, `TomScreenElementsProvider`,
> `TomAuthorization`, `TomUndoHistory`, `TomUIColors`, `TomUIIcons`, the observable
> `Tom*` value types, and the `TomZoned*` timezone types). For the *authoritative
> shipped* surface consult
> [`tom_flutter_ui_user_guide.md`](tom_flutter_ui_user_guide.md) and the package
> per-module docs under `tom_ai/core/tom_flutter_ui/doc/` (e.g. `forms.md`,
> `actions.md`, `groups.md`, `advanced_container_layout.md`) — not this spec.

### 0.1 — Renamed constructs (shipped under a different name)

These appear in the spec under a name the code does **not** use; read them as the
shipped class in the right column.

| Named in this spec | Shipped as | Where |
| ------------------ | ---------- | ----- |
| `TomStringFormField` | `TomFormStringField` / `TomFormStringInput` | `forms/fields/tom_form_string_field.dart` |
| `TomEmailFormField` | `TomFormStringInput` (+ `Validators.email()`) | `forms/fields/tom_form_string_field.dart` |
| `TomPasswordFormField` | `TomFormStringInput` (`obscureText: true`) | `forms/fields/tom_form_string_field.dart` |
| `TomIntFormField` | `TomFormIntInput` | `forms/fields/tom_form_int_field.dart` |
| `TomDoubleFormField` | `TomFormDoubleInput` | `forms/fields/tom_form_double_field.dart` |
| `TomTextFormFieldBase` | `TomTextFormFieldBase` / `TomInputBase` | `forms/tom_form.dart`, `widget_base/tom_family_base.dart` |
| `TomInputField` | `TomTextField` (widget) / `TomFormStringInput` (form) | `widgets/inputs/`, `forms/fields/` |
| `TomDropdown` | `TomFormStringDropdown` / `TomFormEnumDropdown` (+ `TomDropdownStyle`) | `forms/fields/` |
| `TomToggle` | `TomFormBoolSwitch` / `TomFormBoolCheckbox` (+ `TomToggleBase`) | `forms/fields/tom_form_bool_field.dart` |
| `TomButtonBase` | `TomButtonBase` | `widget_base/tom_family_base.dart` |
| `TomUndoHistory` | `TomUndoHistory` | `actions/tom_undo_history.dart` |
| `TomScreenElement` / `TomScreenElementProvider` (singular) | `TomScreenElementsProvider` / `TomScreenElementsProviderBase` (plural) | `widget_base/tom_screen_elements_provider.dart` |
| `TomUIAuthorization` | `TomAuthorization` | `tom_core_kernel/.../security/tom_authorization.dart` |
| `TomUIAuthorizationAdapter` | `TomAuthorizationAdapter` | `tom_core_kernel/.../security/tom_authorization.dart` |
| `TomUIResources` / `TomUIResourceAdapter` / `TomResourceAdapterProvider` | `TomTextResourceProvider` / `TomConfigResourceProvider` + `TomUIColors` / `TomUIIcons` | `tom_core_kernel/.../resources/`, `resource_auth/` |
| `TomZoned` | `TomZonedDate` / `TomZonedTime` / `TomZonedDateTime` | `tom_core_kernel/.../timezoned/` |
| `TomDatePicker` / `TomTimePicker` / `TomDateTimePicker` / `TomDateRangePicker` | `TomFormDatePicker` / `TomFormTimePicker` / `TomFormDateTimePicker` / `TomFormDateRangePicker` (+ `TomFormDateCalendar`, `TomFormDateTextInput`) | `forms/fields/tom_form_date_time_fields.dart` |
| `TomDateTimePickerFamilyBase` | `TomFormDateField` / `TomFormTimeField` / `TomFormDateTimeField` / `TomFormTimeRangeField` / `TomFormDateTimeRangeField` | `forms/fields/tom_form_date_time_fields.dart` |
| `TomFilePicker` / `TomFileRef` | `TomFormFileUpload` / `TomFormFileDropzone` (base `TomFormFileField`, value type `FileRef`) | `forms/fields/tom_form_file_field.dart` |
| `TomMasterDetail` | `TomMasterDetailListForm` (+ `TomListForm`, `TomListFormToolbar`) | `forms/list/` |
| `TomChoiceList` | `TomFormStringDropdown` / `TomFormEnumDropdown` / `TomListForm` | `forms/fields/`, `forms/list/` |
| `TomSearchFieldFamilyBase` | `TomFormSearchField` / `TomFormLookupField` (concrete `TomFormSearchInput` / `TomFormLookupDialog`) | `forms/fields/tom_form_search_lookup_fields.dart` |

### 0.2 — Proposed / not-yet-implemented constructs

The forward-looking constructs that still have **no shipped equivalent** are
catalogued in [Appendix A — Proposed / not-yet-built constructs](#appendix-a--proposed--not-yet-built-constructs).
Do not treat any name in that appendix as an available API.

> **Reconciliation note (2026-07-16).** The forward-looking constructs were
> relocated into Appendix A non-destructively, then the design owner's
> abandoned-vs-intended call was applied: constructs whose need the shipped
> framework fully covers a different way — the theming config objects
> (`TomThemeConfig` family), the `TomFieldImplementation` field layer, the action
> UI-flow requests (`requestUi()`, `TomConfirmation`, `TomHelpButton`, …), the
> `TomActionRegistryProvider`, and `AclJsonLayout` — were **deleted** as abandoned
> and now survive only as a record in Appendix A.2. Constructs that address a
> capability the framework does not yet provide — the paginated
> `TomListDataSource` / `TomTreeDataSource` subsystem with its `TomEditBuffer`, the
> multi-level resource-fallback adapter, `TomRouteContext`, and the
> `TomTimeSlot` / `TomTimeSlotRestriction` time-window model — are **retained** as
> intended future work in Appendix A.1. `TomSearchFieldFamilyBase` was found to
> have shipped (renamed) and moved up to the §0.1 mapping.

---

## 1. Vision

This architecture is intentionally simple.

It has two dimensions:

1. **Widgets** — the visual dimension. Everything the user sees and interacts with.
2. **Actions** — the behavioral dimension. Everything the application does in response to user intent or system events.

Both dimensions share the same infrastructure:

1. **Resources** — text, icons, and configuration loaded by path.
2. **ID** — unique identity for authorization, resource base path, and debug identification.
3. **Group** — optional membership for collective visibility control. Groups can contain both widgets and actions.
4. **State binding** — connection between UI elements and the observable application state (`TomClass` / `TomObject`). All UI elements that display or modify data must be able to interact with the application state. Widgets have internal edit state; validated values are committed to the application state on save (see §13.4).

The system separates:

- screen element definition (what is on screen, with directly instantiated widgets),
- layout arrangement (how elements are positioned),
- optional theme or style layer.

There is no separate "implementation choice" layer — the concrete widget class is chosen at definition time.

This aligns directly with json-Acl-layout goals.

### Locale, process context, and resource loading

Resources are locale-aware (language + region) and process-context-aware (e.g., "self-service" vs. "back-office"). However, the correct resource set is resolved during application initialization and login — the resource loading procedure selects the appropriate locale and process context overlays before delivering resources to the UI layer. This requires no further consideration in the widget architecture; widgets simply look up resource keys and receive the pre-resolved values.

### Migration note

**Migration complete.** The `TomForm`, `TomField`, and related classes have been implemented in `tom_flutter_ui` (in `lib/src/forms/`). The old sample code in `tom_core_flutter` and `tom_uam_client` has been superseded. Current implementations: `TomForm`, `TomField<T>`, `TomTextFormFieldBase<T>`, `TomFormStringInput`, `TomFormIntInput`, `TomFormDoubleInput`.

---

## 2. The Four Core Elements

## 2.1 Resources

Resources are loaded from:

- a base path derived from route, container chain, optional form ID, and widget ID,
- plus a resource suffix defined by the widget internals.

Canonical path format:

`<scopeSegment1>.<scopeSegment2>...<scopeSegmentN>.<widgetId>.<resources-as-needed-in-the-widget>`

Path segments are the plain IDs provided to scope providers and widgets — e.g., `checkout.addressForm.street.label`. If a resource key is missing, the system falls back to the key itself as visible value.

> **Note on ID prefixes:** The architecture originally defined automatic prefixes (`r-`, `c-`, `f-`, `w-`, `g-`) to distinguish segment roles. The current implementation uses plain IDs throughout — no prefixes are applied to any path type. Widget, scope, controller, and action paths all use the plain IDs set by the developer. Prefixes may be added in a future iteration if disambiguation is needed.

This allows changing implementation without breaking the screen while resources are being added.

## 2.2 ID

Each widget or container may have an ID.

The ID is used for:

- authorization target lookup,
- resource base path calculation,
- debug tree inspection and tracing.

### ID convention

Each segment in the path uses a plain ID set by the developer:

| Scope | Example | Resolved path segment |
|-------|---------|----------------------|
| Scope provider | `'checkout'` | `checkout` |
| Element provider | `'clientInfo'` | `clientInfo` |
| Form | `'addressForm'` | `addressForm` |
| Widget | `'street'` | `street` |
| Action | `'submitOrder'` | `submitOrder` |
| Controller | `'orderMgmt'` | `orderMgmt` |
| Group | `'shippingPanel'` | `shippingPanel` |

Action and controller paths use plain IDs (implemented in `TomAction.canonicalPath` and `TomActionController.canonicalPrefix`). All path types use plain IDs — path resolution in `TomScopePath` joins `scopePath.tomId` without prefixes.

```
# Authorization examples
checkout.addressForm.street: true
checkout.addressForm.street.readonly: true

# Resource file examples
checkout.addressForm.street.label = "Street"
checkout.addressForm.street.hint = "123 Main St"

# Action paths
orderMgmt.submitOrder.label = "Submit Order"
```

## 2.3 Group

Each widget or action can directly belong to:

- no group, or
- exactly one group.

A widget may still be influenced by parent container groups through hierarchy.

Groups can contain both widgets and actions. A single authorization key controlling a group hides all members — both visual elements and their associated actions. This ensures that hiding a UI region also disables the business logic triggers within it.

Group rule:

- if multiple members (widgets or actions) in the same group have IDs, each of those IDs can control the visibility state of the entire group.

## 2.4 State Binding

UI elements interact with application state through `TomObject<T>` bindings. There are three distinct binding modes:

### Display binding (read-only observation)

The widget observes a `TomObject<T>` and rebuilds when the value changes. It never writes back. Used by labels, images, progress indicators, and any widget that shows data without editing it.

### Direct binding (read/write)

The widget reads from and writes directly to a `TomObject<T>`. Changes are immediate — no validation buffer. This is used by simple Tom-wrapped Flutter widgets (toggles, sliders, simple inputs) where immediate state feedback is desired and the widget is not part of a validated form.

### Form binding (read + validated write)

The widget belongs to a `TomForm<T>` where `T` is a `TomClass` from the application state. The form binds to a specific `TomClass` instance, and form fields map directly onto the members defined by the target class. This mapping can be validated using reflection to catch mismatches early.

The widget maintains internal edit state separate from the application state. On form save, validation runs across all form fields. Only when all fields pass validation is state committed to the target `TomClass` instance. This is used by Tom Form Components (§12.2) in form contexts.

A `TomForm<MyAddress>` can later be mapped to different objects of type `MyAddress` in the application state — for example, the same address form used for billing address and for each delivery address in a list. The form definition is the type binding; the concrete instance is provided at mount time.

Complex screens may contain:

- **Sub-forms**: A form can include other forms. An `OrderForm` might contain a `BillingAddressForm` and a `DeliveryAddressForm`, each typed to their respective `TomClass`. The owning form coordinates save/discard across all sub-forms.
- **Repeated forms**: The same form type can appear multiple times. A delivery section might contain several `TomForm<DeliveryAddress>` instances, each bound to a different `DeliveryAddress` object in a list within the application state. Each instance has its own edit state.
- **Mixed nesting**: A screen can combine a top-level `OrderForm` with a list of `ItemForm` sub-forms and a single `PaymentForm`, all coordinated through the screen element provider.

See §13.4 for the validation buffer mechanics and form-class binding details.

### Action widgets

Buttons and other action trigger widgets have no direct state binding. They reference an action by ID and delegate execution to the action system (see §8A). The action’s `canExecute()` state drives the enabled/disabled state of all trigger widgets automatically.

### Dynamic configuration bindings

Configuration data (e.g., available time slots, dropdown options) may come from the application state, a database, or external configuration, and may depend on other fields (e.g., office selection determines available hours, contact person determines calendar-based slots). These are also `TomObject<T>` bindings — the widget observes them and updates when they change.

---

## 3. Visibility and Authorization

Authorization controls four states (implemented as `TomAuthState` enum in `tom_core_kernel`):

- **none** — the widget is hidden (as if it doesn't exist). Not rendered in the layout.
- **disabled** — the widget is visible but greyed out, no content shown. Indicates data may exist but cannot be accessed, or might not exist for a given object.
- **read** — the widget shows current value/state in read-only mode but cannot be edited.
- **full** — the widget is fully interactive and editable.

State ordering from most to least restrictive: `none` < `disabled` < `read` < `full`.

### Per-widget authorization modifier

In addition to resource-based authorization, each widget can have:

- **`TomAuthorizer authorizer`** — a per-widget callback that modifies the resolved auth state.
- **`TomAuthorizerStrategy authorizerStrategy`** — controls how the authorizer interacts with resource auth:
  - `authorizerDecides` — authorizer result replaces resource auth
  - `authorizerNarrowsOnly` (default) — authorizer can only narrow, never widen
- **`TomUIStateController uiStateController`** — build-time callback that can further narrow the effective auth state. This handles business-rule narrowing (e.g., empty list disables reorder buttons). Cannot widen auth.

Authorization resolution order:
1. Resource-based authorization (`TomAuthorization.resolveAuth(path)`)
2. Per-widget authorizer (`authorizer.effectiveAuth(state)`)
3. Build-time UI state controller (`uiStateController.apply(state)`)

Each step can only narrow (make more restrictive), never widen, unless `authorizerDecides` strategy is used.

Final visibility rule:
- If auth says `none` → widget is hidden (hard bound).
- If auth says `disabled` → widget is greyed out, no content.
- If auth says `read` → widget is readonly (business logic cannot loosen this).
- If auth says `full` → widget is fully interactive.

Authorization examples with prefixed IDs:

```yaml
# Full access to email field
checkout.shipping.addressForm.email: true

# Email field is visible but readonly (user can see but not edit)
checkout.shipping.addressForm.email: true
checkout.shipping.addressForm.email.readonly: true

# Email field is hidden entirely
checkout.shipping.addressForm.email: false

# Entire form is hidden
checkout.shipping.addressForm: false

# Entire scope is hidden
checkout.shipping: false
```

### 3.1 Kernel authorization model (existing)

The kernel security layer (`tom_core_kernel/lib/src/tombase/security/`) provides the data and checks that the UI adapter consumes.

**TomPrincipal**

Authenticated user context, available zone-scoped or via `TomBearerAuthentication.getPrincipal()`.

```dart
var principal = TomBearerAuthentication.getPrincipal();
// principal.user          -> TomUser (name, email, etc.)
// principal.aci           -> TomAccessControlInformation
// principal.authenticated -> bool
```

**TomAccessControlInformation (ACI)**

Groups all authorization data resolved during login.

```dart
principal.aci.roles         // List<String> — job functions
principal.aci.groups        // List<String> — organizational units
principal.aci.entitlements  // List<String> — fine-grained permissions
principal.aci.resourceKeys  // List<String> — field-level access keys
```

**TomResourceKeyProtection**

Static field-level protection check against the current principal's resource keys.

```dart
// Check if a resource key is protected from the current user
bool hidden = TomResourceKeyProtection.isProtected('checkout.emailField');

// Protect a value with automatic fallback
var value = TomResourceKeyProtection.protect(user.email, '[hidden]', 'user.email');
```

Global protection mode switches (defined, not yet wired to UI):

- `globalSettingUseAutomaticFormFieldProtection`
- `globalSettingUseAutomaticActionProtection`
- `globalSettingUseAutomaticActionProtectionForDisabling`

**TomAccessControl hierarchy**

Annotation-style access control with concrete implementations:

- `TomPublicAccess`, `TomAuthenticatedAccess`, `TomGuestAccess`
- `TomRoleAccess(['admin', 'manager'])`
- `TomGroupAccess(['finance'])`
- `TomEntitlementAccess(['feature.reports.*'])`
- `TomResourceKeyAccess('user.salary')`
- `TomCustomAccess(handler: 'name', resourceId: 'id')`

Each provides `checkAccessibility(TomPrincipal?)` → `bool`.

**TomAccessControlDefinition**

Resolves complete effective permissions from role/group inheritance hierarchies at login time via `completeFromDefinition(userAci)`.

Source files:

- `tom_core_kernel/.../security/access_controls.dart`
- `tom_core_kernel/.../security/user_principal_aci.dart`
- `tom_core_kernel/.../security/bearer_authentication.dart`

### 3.2 UI authorization adapter

The kernel provides boolean access checks. The UI needs to resolve the four authorization states. The `TomAuthorization` singleton bridges this gap (located in `tom_core_kernel`).

```dart
/// Four authorization states for a UI element.
enum TomAuthState {
  none,      // Hidden — element does not exist from user's perspective
  disabled,  // Visible but greyed out, no content shown
  read,      // Read-only — shows value but cannot be modified
  full;      // Fully interactive and editable

  bool get isVisible => this != none;
  bool get isInteractive => this == full;
  bool get showsContent => this == read || this == full;
  TomAuthState narrow(TomAuthState other) => index <= other.index ? this : other;
}
```

```dart
abstract class TomAuthorizationAdapter {
  /// Resolves the authorization state for a given resource key path.
  TomAuthState resolveAuth(String resourceKeyPath);
}
```

The `TomAuthorization` singleton resolves auth state globally (no BuildContext needed):

```dart
class TomAuthorization {
  TomAuthorization._();

  /// The installed adapter, or `null` when none is. Readable so a diagnostics
  /// screen can ask what is wired, and so a caller that installs an adapter
  /// for one operation can put the previous one back.
  static TomAuthorizationAdapter? adapter;

  /// Returns [TomAuthState.full] if no adapter is set (development mode).
  static TomAuthState resolveAuth(String resourceKeyPath) {
    return adapter?.resolveAuth(resourceKeyPath) ?? TomAuthState.full;
  }

  /// Resets the adapter. Intended for testing only.
  static void reset() => adapter = null;
}
```

Per-widget authorization modifiers (in `tom_core_kernel`):

```dart
class TomAuthorizer {
  final TomAuthState Function(TomAuthState resourceAuth) resolve;
  final TomAuthorizerStrategy strategy;

  TomAuthState effectiveAuth(TomAuthState resourceAuth) {
    final result = resolve(resourceAuth);
    return switch (strategy) {
      TomAuthorizerStrategy.authorizerDecides => result,
      TomAuthorizerStrategy.authorizerNarrowsOnly => resourceAuth.narrow(result),
    };
  }
}

enum TomAuthorizerStrategy { authorizerDecides, authorizerNarrowsOnly }

class TomUIStateController {
  final TomAuthState Function(TomAuthState current) apply;
  // Can only narrow — enforced at call site
}
```

> **Migration note:** The authorization types `TomAuthorization` / `TomAuthorizationAdapter` live in `tom_core_kernel` and all code uses them directly.

---

## 4. Required Class Hierarchy

This is a base-class hierarchy, not mixins.

All Tom widgets must pass through this chain.

```text
TomNodeBase
  -> TomPolicyNodeBase
    -> TomFamilyBase
      -> Family Branch Base (Button, Input, Select, ...)
        -> Concrete Widget Class (Material/Cupertino/Custom)
```

## 4.1 TomNodeBase

Responsibility:

- owns ID,
- owns direct group (0 or 1),
- resolves inherited group influence,
- builds resource base path,
- publishes debug identity.

## 4.2 TomPolicyNodeBase

Responsibility:

- obtains the `TomAuthorizationAdapter` from the widget tree,
- resolves authorization visibility for this widget's resource key path,
- combines authorization visibility with context restrictions,
- wraps output in the common policy boundary.

This base class is mandatory for all Tom widgets.

Concrete outline:

```dart
abstract class TomPolicyNodeBase extends TomNodeBase {
  TomPolicyNodeBase({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
  });

  @override
  Widget build(BuildContext context) {
    // Authorization: four-state model
    final authState = resolveEffectiveAuth();

    // Build based on auth state
    switch (authState) {
      case TomAuthState.none:
        return const SizedBox.shrink();
      case TomAuthState.disabled:
        return buildDisabled(context);
      case TomAuthState.read:
        return buildReadonly(context);
      case TomAuthState.full:
        return buildContent(context);
    }
  }

  /// Resolves effective auth by combining resource auth, authorizer, and UI state.
  TomAuthState resolveEffectiveAuth() {
    var state = (basePath != null)
        ? TomAuthorization.resolveAuth(basePath!)
        : TomAuthState.full;
    if (authorizer != null) state = authorizer!.effectiveAuth(state);
    if (uiStateController != null) state = uiStateController!.apply(state);
    return state;
  }

  /// Subclasses implement their actual widget content.
  Widget buildContent(BuildContext context);

  /// Disabled presentation (visible but not available), from the theme.
  Widget buildDisabled(BuildContext context) {
    return TomThemeScope.disabledStyleOf(context).apply(buildContent(context));
  }
}
```

The `basePath` (resolved at construction from `TomScope.current`) is used for all resource and authorization lookups. See the scoping section in `tom_ui_design_architecture.md` for details on `TomScope`, `TomScreenElementsProvider`, and Zone-based path resolution.

## 4.3 TomFamilyBase

Responsibility:

- standard family behavior,
- family-level resource extension strategy,
- common family debug metadata.

Examples of family branches (20 implemented):

- TomButtonBase
- TomInputBase
- TomSelectBase
- TomToggleBase
- TomSliderBase
- TomContainerBase
- TomDialogBase
- TomTableBase
- TomLabelBase
- TomImageBase
- TomNavigationBase
- TomProgressBase
- TomChipBase
- TomListBase
- TomTreeBase
- TomSliverBase
- TomAnimatedBase
- TomEffectBase
- TomInteractionBase
- TomBuilderBase

---

## 5. Common Policy Wrapper

Authorization enforcement is built into `TomPolicyNodeBase.build()` directly (see §4.2). The four-state model (`none`/`disabled`/`read`/`full`) is handled via a switch statement — there is no separate wrapper widget.

For the `read` (readonly) state, `TomPolicyNodeBase.buildReadonly()` resolves a `TomStateStyle` from the nearest `TomThemeScope` inherited widget. When no theme scope exists, `TomStateStyle.readonly` is used (AbsorbPointer + 0.6 opacity):

```dart
Widget buildReadonly(BuildContext context) {
  final style = TomThemeScope.readonlyStyleOf(context);
  return style.apply(buildContent(context));
}
```

The `disabled` state resolves the same way, from the other half of the theme.
`TomStateStyle.disabled` is the fallback (AbsorbPointer + 0.38 opacity):

```dart
Widget buildDisabled(BuildContext context) {
  final style = TomThemeScope.disabledStyleOf(context);
  return style.apply(buildContent(context));
}
```

Both hooks remain overridable — a widget family that renders its own inert form
overrides the hook rather than restyling the theme — but their defaults come
from the one `TomStateStyle` pair the theme carries, which is also what
`TomWidgetMixin.applyAuthState` resolves for widgets that extend a Flutter
widget directly.

The `TomUIStateController` allows business logic to further narrow auth state at build time — for example, disabling a reorder button when a list is empty. This narrowing cannot widen the auth-resolved state.

This keeps authorization enforcement simple and predictable: four well-defined states, each with a distinct visual representation.

---

## 6. Family API and Concrete Implementations

Within a family, we provide one common API and multiple concrete classes.

External logic should usually depend on family type, not concrete widget class.

## 6.1 Button family example

```dart
abstract class TomButtonBase extends TomFamilyBase {
  /// Direct callback (for simple cases without action system).
  final VoidCallback? onPressed;

  /// Action ID to trigger via the action registry.
  /// When set, onPressed is derived from the action's execute(),
  /// and enabled/disabled is derived from canExecute().
  final String? actionId;

  final String? textKey;
  final String? iconKey;

  const TomButtonBase({
    super.key,
    super.tomId,
    super.group,
    this.onPressed,
    this.actionId,
    this.textKey,
    this.iconKey,
  });
}
```

Concrete classes:

- TomElevatedButton
- TomTextButton
- TomOutlinedButton
- TomFilledButton
- TomIconButton
- TomCupertinoButton

All share family behavior, but each exposes full native API of its delegated Flutter widget plus Tom extras.

## 6.2 API compatibility rule

Each concrete class must:

- delegate to the underlying Flutter widget,
- expose that widget's full public API,
- add Tom extras (ID, group, debug, policy integration).

---

## 7. Resource Resolution Model

Resource lookup starts from one canonical base path:

`<scopeSegment1>.<scopeSegment2>...<widgetId>`

Then the widget appends internal resource suffixes it needs.

Example internal suffixes:

- `label`
- `hint`
- `error.required`
- `help.overlayTitle`

Final key examples:

- `checkout.mainForm.emailField.label`
- `checkout.mainForm.emailField.hint`
- `checkout.shipping.street.help.overlayTitle`

### 7.1 Fallback strategy

Fallbacks are used to avoid duplicate resource entries while still allowing precise overrides.

The current implementation in `TomTextResourceProvider` resolves resources by direct path lookup: `basePath.suffix`. If the resource is not found, the full key string is returned as a development fallback (making missing resources visible in the UI).

> **Planned extension:** A multi-level fallback chain (widget-only key, form+widget key, etc.) is designed for future implementation to support shared resource defaults across screens.

For requested key:

`r-<route>.c-<containers>.f-<form>.w-<widget>.<suffix>`

fallback hierarchy:

1. Exact widget key:
  - `r-<route>.c-<containers>.f-<form>.w-<widget>.<suffix>`
2. Container form widget key (drop route):
  - `c-<containers>.f-<form>.w-<widget>.<suffix>`
3. Route form widget key (drop containers):
  - `r-<route>.f-<form>.w-<widget>.<suffix>`
4. Form widget key:
  - `f-<form>.w-<widget>.<suffix>`
5. Widget key:
  - `w-<widget>.<suffix>`

The prefixes make each fallback level unambiguous — you can always tell whether a segment is a route, container, form, or widget.

If all lookups miss, the value falls back to the full exact key string.

### 7.2 Resource adapter

> **Intended — not yet built (Appendix A.1).** The multi-level fallback adapter
> below (`TomUIResourceAdapter`, `TomFallbackResourceAdapter`,
> `TomResourceAdapterProvider`) is retained intended future work: the shipped code
> resolves text via `TomTextResourceProvider` directly with a single-level path
> lookup, and the multi-level fallback chain the framework does not yet provide is
> catalogued in Appendix A.1.

The widget system uses `TomTextResourceProvider` from the kernel (`tom_core_kernel/.../resources/tom_resource_provider.dart`) for text resources. The fallback strategy requires a dedicated adapter that implements the chain from §7.1.

```dart
abstract class TomUIResourceAdapter {
  /// Resolves a text resource with the fallback chain.
  String resolveText(String basePath, String suffix);

  /// Checks if a resource key exists at any fallback level.
  bool resourceExists(String basePath, String suffix);
}
```

Default implementation:

```dart
class TomFallbackResourceAdapter implements TomUIResourceAdapter {
  final TomTextResourceProvider _provider;

  TomFallbackResourceAdapter([TomTextResourceProvider? provider])
      : _provider = provider ?? TomTextResourceProvider.getAppResources();

  @override
  String resolveText(String basePath, String suffix) {
    final fullKey = '$basePath.$suffix';
    final candidates = buildFallbackChain(basePath, suffix);

    for (final candidate in candidates) {
      if (_provider.exists(candidate)) {
        return _provider.getText(candidate);
      }
    }

    // Fall back to full key as visible value
    return fullKey;
  }

  @override
  bool resourceExists(String basePath, String suffix) {
    final candidates = buildFallbackChain(basePath, suffix);
    return candidates.any(_provider.exists);
  }

  /// Builds the ordered fallback candidate list per §7.1.
  ///
  /// Input basePath segments: [route?, container1, ..., form?, widget]
  /// The caller marks which segments are route, containers, form, widget
  /// via the TomNodeBase path metadata.
  List<String> buildFallbackChain(String basePath, String suffix) {
    // Example: basePath = "checkout.mainForm.emailField"
    //          suffix   = "label"
    //
    // 1. checkout.mainForm.emailField.label         (exact)
    // 2. mainForm.emailField.label                  (containers.form.widget)
    // 3. checkout.emailField.label                  (route.widget — skip containers/form)
    // 4. mainForm.emailField.label                  (form.widget)
    // 5. emailField.label                           (widget only)
    //
    // Concrete implementation resolves from TomNodeBase path metadata.
    // Simplified here for illustration.
    final fullKey = '$basePath.$suffix';
    final segments = basePath.split('.');
    final candidates = <String>[fullKey];

    if (segments.length > 1) {
      // Drop first segment (route)
      candidates.add('${segments.sublist(1).join('.')}.$suffix');
    }
    if (segments.length > 2) {
      // Route + last segment (widget)
      candidates.add('${segments.first}.${segments.last}.$suffix');
      // Last two segments (form.widget or just widget path)
      candidates.add('${segments.sublist(segments.length - 2).join('.')}.$suffix');
    }
    // Widget-only
    candidates.add('${segments.last}.$suffix');

    return candidates;
  }
}
```

Provided via InheritedWidget:

```dart
class TomResourceAdapterProvider extends InheritedWidget {
  final TomUIResourceAdapter adapter;

  const TomResourceAdapterProvider({
    super.key,
    required this.adapter,
    required super.child,
  });

  static TomUIResourceAdapter of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TomResourceAdapterProvider>()!
        .adapter;
  }
}
```

Connection to existing `TomField` resource access:

Current `TomField` calls `t("$formName.$fieldName.label")` via `TomTextResourceProvider` directly. The evolution path replaces this with:

```dart
final resourceAdapter = TomResourceAdapterProvider.of(context);
final labelText = resourceAdapter.resolveText(basePath, 'label');
```

This gives the fallback chain automatically without changing field semantics.

---

## 8. Group Model in Practice

## 8.1 Membership

- Widget or action direct group: optional single value.
- Parent containers can add inherited group influence.
- A group can contain any mix of widgets and actions.

## 8.2 Group-controlled visibility

If several members (widgets or actions) in a group have IDs, each can influence full group visibility.

Typical setup:

- one controller widget with ID and group,
- multiple related widgets in same group without IDs,
- associated actions in same group (e.g., a CRUD action set for an entity panel),
- optional additional controllers in same group.

When a group is hidden by authorization, **all** members are hidden — both visual elements and their action triggers. This ensures consistency: a user cannot trigger an action whose associated UI region is not visible.

## 8.3 Why this matters

This enables semantic control of whole UI regions without requiring IDs on every leaf widget or action. A single authorization key can control a complete functional unit — its visual presentation and its behavior.

The group membership of both widgets and actions must be extractable in the debug view (§9) to validate correct authorization setup.

---

## 8A. Actions

Actions are the behavioral dimension of the architecture — the counterpart to widgets. While widgets represent what the user sees, actions represent what the application does. Both share the same infrastructure (IDs, resources, groups, authorization).

An action is a named, authorized unit of business logic. It can be triggered by buttons, menu entries, keyboard shortcuts, timed events, external events, or other actions.

### Core properties

| Property | Description |
|----------|-------------|
| ID | Unique action ID. Used for authorization, resource lookup, and debug identification. |
| Resources | Label, tooltip, icon, confirmation text — loaded via the same resource adapter and fallback chain as widgets. |
| Group | Optional group membership — shared with widgets for collective visibility control. |
| Authorization | Boolean visible/hidden. An action is either authorized or not. There is no "readonly" for actions. |

Action resource path examples:

```
orderMgmt.submitOrder.label
orderMgmt.submitOrder.tooltip
orderMgmt.cancelOrder.label
```

### Stateless actions

**Actions must be stateless.** No mutable instance state may survive between invocations. If an action needs working state during execution, it creates a transient state object for that invocation. This guarantees that repeated invocations never carry over stale data and that actions remain safe to share across triggers, screens, and sessions.

### TomAction base class

Each action declares two type parameters:
- `TContext` — the typed context required for execution (extends `TomActionContext`),
- `TUndo` — the undo state type returned by `execute()`.

```dart
abstract class TomAction<TContext extends TomActionContext, TUndo> {
  /// The action ID. Used as the last segment in the canonical path.
  String get actionId;

  /// Optional group membership.
  String? get group => null;

  const TomAction();

  /// Whether this action can currently execute.
  /// Drives the enabled/disabled state of all trigger widgets.
  bool canExecute(TContext context);

  /// Execute the action. Returns the undo state if undoable, null otherwise.
  /// Each invocation must be self-contained — no mutable instance fields.
  TUndo? execute(TContext context, TomActionTransaction tx);

  /// Whether this action supports undo.
  bool get isUndoable => false;

  /// Undo the action using the state returned by execute().
  /// Only called if isUndoable is true.
  void undo(TUndo undoState) {
    throw UnsupportedError('Action $actionId does not support undo');
  }
}
```

### Typed action context

Every action declares exactly which context it requires. `TomActionContext` is the base class providing common infrastructure. Specific actions extend it to declare the state subtree, selections, or parameters they operate on.

```dart
/// Base context — always available.
class TomActionContext {
  /// Access to the application state tree.
  final TomClass appState;

  /// The current route context (route ID, parameters).
  final TomRouteContext routeContext;

  /// The widget tree context for resolving InheritedWidgets.
  final BuildContext? widgetContext;

  const TomActionContext({
    required this.appState,
    required this.routeContext,
    this.widgetContext,
  });
}
```

A specific action context extends this base to declare exactly what the action needs — typically the state subtree or selected entity the action operates on:

```dart
/// Context for order-related actions — narrows the state subtree.
class OrderActionContext extends TomActionContext {
  final Order selectedOrder;
  final OrderRepository orderRepo;

  const OrderActionContext({
    required this.selectedOrder,
    required this.orderRepo,
    required super.appState,
    required super.routeContext,
    super.widgetContext,
  });
}
```

This enables type-safe action execution — `execute()` receives the exact context type, not a generic bag of optional fields:

```dart
class DeleteOrderAction extends TomAction<OrderActionContext, Order> {
  @override
  String get actionId => 'deleteOrder';

  @override
  bool get isUndoable => true;

  @override
  bool canExecute(OrderActionContext context) {
    return context.selectedOrder.status != OrderStatus.shipped;
  }

  @override
  Order? execute(OrderActionContext context, TomActionTransaction tx) {
    final order = context.selectedOrder;
    context.orderRepo.remove(order.id);
    return order; // undo state
  }

  @override
  void undo(Order undoState) {
    // Restore the deleted order — lookup repo from current app state
    undoState.repository.add(undoState);
  }
}
```

Actions declare what they need through `canExecute()` — if required data is missing or preconditions fail, the action reports itself as not executable, and all trigger widgets disable automatically.

---

## 8B. Action Controllers

Actions are often associated with a business entity or a functional area. An **action controller** groups related actions and provides a scope for them — similar to how a form groups fields.

### Controller ID and action resolution

A controller has an ID. The actual ID of an action within a controller is the combination of controller-id + action-id:

```
orderMgmt.create
orderMgmt.update
orderMgmt.delete
orderMgmt.archive
```

Controller-scoped actions can also appear within a route context:

```
checkout.orderMgmt.submitOrder
```

### TomActionController

Actions are accessed as typed fields on the controller — not through dynamic lookup. This guarantees compile-time safety when referencing actions.

```dart
abstract class TomActionController {
  /// The controller ID. Used as the first segment in action canonical paths.
  String getControllerId();

  /// Optional group membership for the controller and all its actions.
  String? get group => null;

  const TomActionController();

  /// All actions managed by this controller (for registry and debug).
  List<TomAction> get actions;
}
```

Example:

```dart
class OrderController extends TomActionController {
  @override
  String getControllerId() => 'orderMgmt';

  final create = CreateOrderAction();
  final update = UpdateOrderAction();
  final delete = DeleteOrderAction();
  final archive = ArchiveOrderAction();

  @override
  List<TomAction> get actions => [create, update, delete, archive];
}
```

Usage is type-safe — the action is known at compile time:

```dart
final orderCtrl = OrderController();

// Compile-time safe: type is DeleteOrderAction
orderCtrl.delete.canExecute(context);
orderCtrl.delete.execute(context, tx);

// No dynamic lookup, no string-based resolution at the call site
```

The `getAction()` pattern is deliberately removed. All consumer code accesses actions through typed fields. The `actions` list exists for registry enumeration and debug tooling, not for lookup.

### Stateless enforcement

Because actions are stateless (see §8A), controller fields are safe to hold as `final` — the action instance itself holds no mutable state. Each invocation receives its context and transaction as parameters, and any working state is created transiently within `execute()`.

### Form as an implicit controller

Forms automatically act as controllers for their standard actions. When a form with ID `addressForm` mounts, it registers:

```
f-addressForm.a-save       — wraps form.commit(), undoable (stores pre-commit state)
f-addressForm.a-discard    — wraps form.discard(), not undoable (no state was modified)
f-addressForm.a-validate   — wraps form.validate(), not undoable, not state-modifying
```

`discard` is not undoable because it happens before save — no application state has been modified, so there is nothing to reverse. However, it is still an action so it can be triggered uniformly through any action trigger.

---

## 8C. Action Triggers

Triggers connect actions to the user or to system events. A trigger references an action by ID and calls `execute()`. The trigger does not know how the action works.

### Trigger types

| Type | Examples | Source |
|------|----------|--------|
| **UI trigger** | Button tap, menu entry (window menu, context menu), keyboard shortcut, swipe gesture, toolbar button | User interaction |
| **Timed trigger** | Scheduled execution, delay, periodic interval | Timer/scheduler |
| **Event trigger** | Incoming message, push notification, WebSocket event, file change | External system |
| **Conditional trigger** | Action B fires after Action A completes, based on a condition | Action chain (within a transaction) |

### How triggers work

- A trigger references an action ID (e.g., `actionId: 'submitOrder'` or `actionId: 'orderMgmt.delete'`).
- Authorization hides/shows all triggers for a hidden action automatically.
- `canExecute()` disables all triggers uniformly — a button, a context menu entry, and a keyboard shortcut for the same action all enable/disable together.
- Multiple triggers can reference the same action. The action executes identically regardless of which trigger invoked it.

### Button family integration

The button family gains an `actionId` parameter alongside (or instead of) the existing `onPressed` callback:

```dart
TomElevatedButton(
  tomId: 'submitBtn',
  actionId: 'submitOrder',  // resolved via action registry
  // onPressed is derived from the action's execute()
  // enabled/disabled is derived from the action's canExecute()
)
```

When `actionId` is set, the button:
1. Looks up the action in the action registry.
2. Observes `canExecute()` to drive enabled/disabled state.
3. Calls `execute()` on tap (within a transaction).
4. Uses the action's resources for label/tooltip if not explicitly overridden.

---

## 8D. Action Transactions and Undo/Redo

A single user intent (one "undo step") may involve multiple sub-actions. Transactions group these into one atomic undo unit.

### TomActionTransaction

```dart
class TomActionTransaction {
  final String transactionId;
  final List<_TransactionEntry> _entries = [];

  TomActionTransaction({required this.transactionId});

  /// Execute a sub-action within this transaction.
  void run<TCtx extends TomActionContext, TUndo>(
    TomAction<TCtx, TUndo> action,
    TCtx context,
  ) {
    final undoState = action.execute(context, this);
    _entries.add(_TransactionEntry(action: action, undoState: undoState));
  }

  /// Whether the entire transaction is undoable.
  /// A transaction is undoable only if ALL actions in it are undoable.
  bool get isUndoable => _entries.every((e) => e.action.isUndoable);
}
```

### Undo rules

1. Each action declares whether it is undoable (default: no).
2. Undoable actions carry a reverse function that restores previous state.
3. **A transaction is undoable only if all sub-actions within it are undoable.** If any sub-action is non-undoable (e.g., "send email"), the entire transaction cannot be undone. There is no partial undo.
4. If the most recent transaction in the history is not undoable, the undo option is not available.
5. Undo reverses all sub-actions in reverse order within the transaction.
6. Redo stack is cleared on any new action execution (standard).
7. Configurable history depth limit.

### TomUndoHistory

```dart
class TomUndoHistory {
  final int maxDepth;
  final List<TomActionTransaction> _undoStack = [];
  final List<TomActionTransaction> _redoStack = [];

  TomUndoHistory({this.maxDepth = 50});

  /// Whether undo is available.
  /// False if the stack is empty or the most recent transaction is not undoable.
  bool get canUndo => _undoStack.isNotEmpty && _undoStack.last.isUndoable;

  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  void record(TomActionTransaction tx) {
    _undoStack.add(tx);
    _redoStack.clear(); // new action clears redo
    if (_undoStack.length > maxDepth) _undoStack.removeAt(0);
  }

  void undo() {
    if (!canUndo) return;
    final tx = _undoStack.removeLast();
    // Reverse all sub-actions in reverse order
    for (final entry in tx._entries.reversed) {
      entry.action.undo(entry.undoState);
    }
    _redoStack.add(tx);
  }

  void redo() {
    if (!canRedo) return;
    final tx = _redoStack.removeLast();
    for (final entry in tx._entries) {
      entry.action.execute(tx);
    }
    _undoStack.add(tx);
  }
}
```

> **The `redo()` body above is proposed, not shipped, and cannot be written as
> given.** The shipped `TomUndoHistory.redo` moves the transaction back onto the
> undo stack and re-applies nothing. A replaying redo needs `TomAction.execute`,
> whose real signature is `execute(TContext context, TomActionTransaction tx)` —
> and a transaction records `(action, undoState)` pairs, never the context an
> action ran with, so there is no argument to call it with. Making redo replay
> means recording contexts too, or letting each action implement its own redo.
> The shipped constructor also takes `maxSize`, not `maxDepth`, and its `canUndo`
> is not gated on `isUndoable`. See `TomUndoHistory.redo` and
> [`actions.md`](actions.md) for the shipped contract.

### Conditional/chained actions within a transaction

When an action triggers another action based on conditions, both belong to the same transaction:

```dart
class SubmitOrderAction extends TomAction<OrderActionContext, OrderSnapshot> {
  @override
  String get actionId => 'submitOrder';

  @override
  bool canExecute(OrderActionContext context) => true;

  @override
  OrderSnapshot? execute(OrderActionContext context, TomActionTransaction tx) {
    final snapshot = captureOrderState(context.selectedOrder);
    processPayment(context.selectedOrder);
    if (context.selectedOrder.requiresShipping) {
      tx.run(ReserveShippingAction(), shippingContext); // conditional sub-action
    }
    tx.run(SendConfirmationAction(), confirmContext);    // non-undoable sub-action
    return snapshot;
  }
}
```

In this example, because `sendConfirmation` is non-undoable, the entire `submitOrder` transaction becomes non-undoable.

---

## 8E. Action Authorization Hierarchy

Actions are authorized using the same `TomAuthState` adapter as widgets, but with a lookup hierarchy that respects scope.

### Authorization lookup order

For an action `submitOrder` triggered on route `checkout`:

```
1. checkout.submitOrder              ← route-specific authorization
2. submitOrder                       ← global authorization
```

For a controller-scoped action `orderMgmt.delete` on route `admin`:

```
1. admin.orderMgmt.delete             ← route + controller-specific
2. orderMgmt.delete                   ← controller-specific (any route)
3. admin.delete                       ← route + action (without controller)
4. delete                             ← global action
```

### Override rules

- If a **global** action is set to `false` (hidden), it cannot be enabled for a specific route. Global denial is absolute.
- If there is **no global setting**, the action can be authorized per route.
- If a route-specific setting exists, it takes precedence over the absence of a global setting.
- This mirrors the widget authorization model: authorization can restrict but never loosen what a higher scope has denied.

```yaml
# Global: submitOrder is allowed everywhere unless overridden per route
submitOrder: true

# Route-specific: submitOrder is hidden on the reporting screen
reporting.submitOrder: false

# Global: deleteOrder is globally forbidden — cannot be enabled per route
deleteOrder: false
# This has NO effect — global denial wins:
admin.deleteOrder: true  # IGNORED
```

### Action registration tiers

| Tier | Registration point | Scope | Examples |
|------|-------------------|-------|----------|
| **Global** | App startup (root `TomActionController` / `TomActionContext`) | Available everywhere | Logout, navigate, theme toggle |
| **Screen** | Screen element provider | Available on that screen | Screen-specific CRUD, form actions |
| **Form** | Form mount | Available while form is active | save, discard, validate |

The action registry merges all tiers. Lookup checks the most specific scope first (form → screen → global).

---

## 9. Debug View

The debug view provides comprehensive inspection of the widget and action system at runtime. It is a development tool — not part of the production UI — that allows developers and testers to validate authorization setup, resource configuration, group membership, action registration, and the overall ID structure.

### 9.0 Data collection

All debug information is collected from live widget and action instances through the base class hierarchy:

- **`TomNodeBase`** reports its ID, resolved path, group membership, and family type.
- **`TomPolicyNodeBase`** reports its authorization state (visible/hidden/readonly), the raw auth result from the adapter, and any context restrictions applied.
- **`TomFamilyBase`** reports the family type and resource suffixes it requested.
- **`TomAction`** instances report their action ID, resolved path, controller (if any), group membership, authorization state, `canExecute()` state, and whether they are undoable.
- **`TomActionController`** instances report their controller ID, registered actions, and group membership.

Data collection is **pull-based**: the debug view walks the widget tree (via `debugDescribeChildren` and element visitor) and queries the action registry. No runtime overhead exists when the debug view is not active.

### 9.1 Authorization configuration and setup

Shows for each widget and action:

- ID and resolved full path (with prefixes),
- target policy source (which authorization key matched),
- effective authorization state (`visible`, `hidden`, `readonly`),
- for actions: whether the action is globally denied or route-specifically authorized,
- authorization lookup hierarchy that was evaluated (all levels, with hit/miss per level),
- non-overridable authorization bound used inside widget class.

**Filtering:**

- Search by ID (partial match, regex supported),
- filter by authorization state (show only hidden, only readonly, only fully visible),
- filter by scope (global actions, screen actions, form actions),
- filter by group.

**Export:**

- Copy as structured text (one node),
- copy as YAML (subtree),
- export full authorization map as YAML (all widgets + actions with their effective states).

### 9.2 Resource file creation and editing

Shows for each widget and action:

- canonical key root segments (route, containers, form/controller, widget/action),
- requested resource suffixes,
- full fallback chain in evaluation order with hit/miss per level,
- resolved value and its source (which fallback level matched),
- missing keys with generated file-entry suggestions (copy-ready resource lines).

**Filtering:**

- Search by resource key (partial match),
- filter by status: resolved, missing, fallback-resolved,
- filter by widget/action type.

**Export:**

- Copy missing resource entries (ready to paste into resource file),
- copy all resource entries for a subtree,
- export resource coverage report (resolved vs. missing per screen).

### 9.3 Authorization flow trace

Shows the full authorization resolution flow for a selected widget or action:

- raw authorization result from the adapter (which key was checked, what was returned),
- for actions: full authorization hierarchy evaluation (route-specific → global, with result per level),
- group membership and group-level authorization effect,
- context restrictions applied afterward (business logic readonly/disabled),
- final effective state with reason chain (e.g., "hidden because group 'shipping-panel' is hidden via `r-checkout.c-shipping: false`").

**Filtering:**

- Select specific widget/action by ID or by clicking in the widget tree view,
- filter by reason type (auth-denied, group-denied, context-restricted).

**Export:**

- Copy authorization trace for selected node,
- copy full trace for a subtree.

### 9.4 Resource lookup trace

Shows the full resource resolution flow for a selected widget or action:

- each attempted key in the fallback chain,
- hit or miss status per key,
- resolved value and source file/location,
- fallback-to-full-key event when all attempts miss,
- timing information (if resource lookup is slow).

**Filtering:**

- Select specific widget/action by ID,
- filter by hit/miss status,
- search by resource key or resolved value.

**Export:**

- Copy key trace for selected node,
- copy all unresolved keys for the current screen.

### 9.5 UI ID structure verification

Shows the full ID tree for the current screen:

- hierarchical view: route → containers → forms → widgets,
- parallel view: actions and controllers alongside the widget tree,
- direct group assignment per widget and action,
- inherited group influences from parent containers,
- group membership overview: each group with all its members (widgets + actions),
- warnings for:
  - missing IDs (widgets/actions without IDs that should have them),
  - duplicate IDs within the same scope,
  - unexpected ID patterns,
  - orphaned actions (registered but no trigger widget references them),
  - group inconsistencies (action in a group but its trigger widget is not, or vice versa).

**Filtering:**

- Search by ID, group name, family type, or action type,
- filter by node type (widgets only, actions only, controllers only),
- expand/collapse tree levels.

**Export:**

- Copy node (single entry),
- copy subtree (hierarchical),
- copy group membership table,
- export full ID tree as YAML.

### 9.6 Action registry view

Shows the complete action registry for the current screen:

- all registered actions grouped by tier (global → screen → form),
- for each action:
  - action ID and resolved path,
  - controller (if any),
  - authorization state,
  - `canExecute()` current state and reason,
  - undoable flag,
  - group membership,
  - trigger widgets referencing this action (backlinks to the widget tree),
- action history: recent transactions with their undo/redo state.

**Filtering:**

- Search by action ID or controller ID,
- filter by tier (global, screen, form),
- filter by state (executable, not executable, unauthorized),
- filter by undoable/non-undoable.

**Export:**

- Copy action registry as YAML,
- copy action history as YAML,
- export action-trigger mapping (which triggers reference which actions).

### 9.7 Compound copy and export

For cross-cutting analysis, the debug view supports compound export operations:

- **Full screen snapshot**: exports the complete debug state of the current screen (widget tree, action registry, authorization map, resource coverage, group membership) as a single structured YAML document.
- **Authorization validation report**: summarizes all authorization decisions, group effects, and potential issues.
- **Resource gap report**: lists all missing resources across the current screen with suggested entries.

All export operations produce structured text (YAML or key-value format) that can be pasted into files, sent in bug reports, or diffed across sessions.

---

## 10. Theming and Configuration Model

Theming must be consistent globally and still overridable per widget.

## 10.1 Theme layers

1. Global theme defaults (app level).
2. Family theme defaults (for example all button-like widgets).
3. Variant theme defaults (for example elevated button variant).
4. Screen-level configuration overrides.
5. Per-widget explicit overrides.

Higher layers override lower layers.

## 10.2 Configuration approach

Use theming objects that cascade from the widget tree down into family base
classes. The shipped model layers as:

- `TomThemeSpec` — the global theme specification,
- `TomFormStyle` / `TomFormStyleScope` — form- and scope-level style,
- `TomThemeScope` — subtree theme override,
- `TomStateStyle` and `TomStyleResolvers` — read-only and resolved styling,
- widget override fields in concrete classes.

This keeps style logic centralized while preserving precise control.

## 10.3 Interaction with resources

Resources define text and semantic content. Theme config defines visual rendering. They remain separate but can be composed in the same build path.

## 10.4 Practical guideline

Use per-widget overrides only when needed. Prefer family or variant configuration for consistency.

---

## 11. Separation with json-Acl-layout

The model separates two concerns: *what* a screen contains, and *how* those
contents are arranged.

The canonical layout contract is the shipped `AclBuilder` / `TomAclBuilder`
command surface, specified in
[`acl_design_specification.md`](acl_design_specification.md). It is not a JSON
document. A declarative JSON form of the *same* commands is intended future
work rather than a second layout system: JSON names each slot with a string
`ref` and feeds into `AclBuilder` through `processJson` / `buildFromJson`, so
the arrangement it expresses is the arrangement the builder already
understands. Its shape is given in
[§13.7](#137-json-acl-layout-as-aclbuilder-alternative) below and in
[`acl_design_specification.md`, "JSON-ACL Support (future)"](acl_design_specification.md#json-acl-support-future).

An earlier proposal instead gave the JSON its own entry-point class,
`AclJsonLayout`, which resolved widget names against a `Map<String, Widget>`
passed to `build()`. That name is abandoned — see
[A.2](#a2--abandoned-removed-framework-covers-the-need-a-different-way) — and
nothing in this document defers to it.

## 11.1 Screen element definition

Defines what elements exist, what they mean (field identity, validation, group relationships), and which concrete widget classes render them. The widget is directly instantiated in the definition — there is no separate "implementation choice" layer or factory.

## 11.2 Layout definition

Defines how screen elements are arranged and made responsive. Uses `AclBuilder` in Dart or JSON-ACL layout format.

## 11.3 Why this separation is beneficial

Benefits:

- adjust layout without touching element definitions or business meaning,
- reuse one screen definition with different layouts (desktop vs. mobile),
- keep style changes mostly independent via theming.

There is no cost of a mapping layer — the concrete widget class is chosen directly in the definition.

## 11.5 Implementation status

The form and field system has been implemented in `tom_flutter_ui/lib/src/forms/tom_form.dart`.

### Current state

`TomForm` is an abstract class extending `TomClass` that implements `TomScreenElementsProvider`. Fields are auto-discovered via `getMembers()` (tom_reflection):

```dart
@tomReflector
abstract class TomForm extends TomClass implements TomScreenElementsProvider {
  late final TomScope scope;
  late final String formId;
  late final TomForm? parentForm;
  late final Map<String, TomField> fields = {};

  TomForm({required this.formId, this.parentForm}) {
    scope = TomScope.current;
    getMembers().entries.where((entry) => entry.value is TomField).forEach((entry) {
      fields[entry.key] = entry.value as TomField;
    });
  }

  void prepareForSelfObservation() {
    TomScope.withScope(formId, () => createFormElements());
  }

  void createFormElements();
  List<Widget> getFields() => fields.values.map((f) => f.getField()).toList();
  Widget getField(String name) => fields[name]!.getField();
  bool validate() { ... }
  Map<String, Object> save() { ... }
}
```

`TomField<T>` extends `TomObject<T>` for observable field values:

```dart
abstract class TomField<T> extends TomObject<T> {
  late String scope;
  String fieldName;
  TomForm form;
  T initialValue;
  bool obscureText;

  bool validate();
  T save();
  String? get errorText;
  Widget getField();
}
```

Concrete implementations: `TomTextFormFieldBase<T>` (with `TextEditingController`, input/value validators, pattern validation from resources), `TomFormStringInput`, `TomFormIntInput`, `TomFormDoubleInput`.

### Implemented field types

| Class | Type | Description |
|-------|------|-------------|
| `TomFormStringInput` | `String` | Standard text input; `obscureText: true` for passwords, `Validators.email()` for email |
| `TomFormIntInput` | `int` | Integer with optional min/max |
| `TomFormDoubleInput` | `double` | Decimal with optional min/max |

### Implemented: authorization-aware TomForm

`TomForm` is now scope-aware through its `TomScope` field and `TomScreenElementsProvider` implementation. Form-level authorization is resolved through the standard `TomAuthorization.resolveAuth()` mechanism using the form's scope path.

### Implemented: resource-aware TomField

`TomTextFormFieldBase<T>` resolves resources via scoped translation helper `t(key)` which uses `TomTextResourceProvider.getAppResources().getText('$scope.$key')`. Authorization for individual fields flows through the standard widget hierarchy (`TomPolicyNodeBase` → `resolveEffectiveAuth()`).
  final String? formId;

### Implemented: resource-aware TomField

`TomTextFormFieldBase<T>` resolves resources via scoped translation helper `t(key)` which uses `TomTextResourceProvider.getAppResources().getText('$scope.$key')`. Authorization for individual fields flows through the standard widget hierarchy (`TomPolicyNodeBase` → `resolveEffectiveAuth()`).

---

## 12. Widget Family Reference

This section lists all planned widget families, grouped by their relationship to Flutter widgets.

### 12.1 Families derived from Flutter widgets

| Family | Family Base Class | Flutter Classes Covered | State Binding | Notes |
|--------|------------------|------------------------|---------------|-------|
| Button | `TomButtonBase` | `ElevatedButton`, `TextButton`, `OutlinedButton`, `FilledButton`, `IconButton`, `CupertinoButton` | Action trigger via `actionId` or direct `onPressed` callback | Text, filled, icon and Cupertino variants |
| Input | `TomInputBase` | `TextField`, `TextFormField`, `CupertinoTextField` | `TomObject<String>` read/write | Single-line and multi-line text input |
| Select | `TomSelectBase` | `DropdownButton`, `DropdownButtonFormField`, `PopupMenuButton`, `CupertinoPicker` | `TomObject<T>` read/write; items from `TomObject<List<T>>` or static list | Typed selection from list of options |
| Toggle | `TomToggleBase` | `Switch`, `CupertinoSwitch`, `Checkbox`, `CupertinoCheckbox`, `Radio` | `TomObject<bool>` or `TomObject<T>` (radio) read/write | Boolean and radio-group toggling |
| Slider | `TomSliderBase` | `Slider`, `RangeSlider`, `CupertinoSlider` | `TomObject<double>` or `TomObject<(double,double)>` read/write | Continuous and discrete value selection |
| Container | `TomContainerBase` | `Container`, `Card`, `ExpansionTile`, `ExpansionPanel`, `CupertinoListSection` | None (structural) | Visual grouping; Acl containers handle layout nesting directly |
| Dialog | `TomDialogBase` | `AlertDialog`, `SimpleDialog`, `CupertinoAlertDialog`, `BottomSheet`, `CupertinoActionSheet` | None (result via Future) | Modal and non-modal dialogs |
| Table | `TomTableBase` | `DataTable`, `PaginatedDataTable` | Read-only from `TomListDataSource<T>` | Tabular data display |
| Label | `TomLabelBase` | `Text`, `RichText`, `SelectableText` | `TomObject<String>` read-only (or resource text) | Static and bound labels |
| Image | `TomImageBase` | `Image`, `CircleAvatar`, `Icon`, `FadeInImage` | `TomObject<String>` read-only (URL/path) or static | Static, network, and avatar images |
| Navigation | `TomNavigationBase` | `TabBar`, `BottomNavigationBar`, `NavigationRail`, `CupertinoTabBar`, `Drawer` | `TomObject<int>` read/write (selected index) | App-level navigation |
| Progress | `TomProgressBase` | `CircularProgressIndicator`, `LinearProgressIndicator`, `CupertinoActivityIndicator` | `TomObject<double>` read-only (0.0–1.0) or indeterminate | Loading and progress indicators |
| Chip | `TomChipBase` | `Chip`, `FilterChip`, `ChoiceChip`, `ActionChip`, `InputChip` | `TomObject<Set<T>>` or `TomObject<T>` read/write | Tagging, filtering, and action chips |
| List | `TomListBase` | `ListView`, `ListTile`, `CupertinoListTile`, `ReorderableListView` | Read-only from `TomListDataSource<T>`; selection via `TomObject<T?>` | Scrollable list display |
| Tree | `TomTreeBase` | `TreeView` (custom) | Read-only from `TomTreeDataSource<T>`; selection via `TomObject<T?>` | Hierarchical data display |
| Sliver | `TomSliverBase` | `SliverList`, `SliverGrid`, `SliverAppBar`, etc. | Varies | Sliver-based scrollable content |
| Animated | `TomAnimatedBase` | `AnimatedContainer`, `AnimatedOpacity`, `Hero`, etc. | Varies | Animated transitions |
| Effect | `TomEffectBase` | `BackdropFilter`, `ClipRect`, `ClipRRect`, etc. | None | Visual effects and clipping |
| Interaction | `TomInteractionBase` | `GestureDetector`, `InkWell`, `Dismissible`, etc. | Varies | Touch and gesture handling |
| Builder | `TomBuilderBase` | `LayoutBuilder`, `FutureBuilder`, `StreamBuilder`, etc. | Varies | Builder pattern widgets |

### 12.2 Tom Form Component families

Tom Form Components are custom extended fields that replace the simpler Flutter-derived widgets for use in forms. The goal is not only to create components Flutter does not have, but also to provide a sufficiently comprehensive feature set so they can be reused across all common requirements found in state-of-the-art applications.

They have their own family bases and internally compose widgets from other families.

| Form Component Family | Family Base Class | State Binding | Description | Built From |
|----------------------|------------------|---------------|-------------|------------|
| FormField | `TomTextFormFieldBase` | `TomObject<T>` read/write via validation buffer | Full-featured form fields with all decorations (see §12.3) | Input, Label, Button, Icon families |
| DateTimePicker | `TomFormDateField` / `TomFormTimeField` / `TomFormDateTimeField` | `TomObject<T>` read/write (`DateTime` / `TimeOfDay`) via validation buffer | `TomFormDatePicker` / `TomFormTimePicker` / `TomFormDateTimePicker` / `TomFormDateRangePicker` / `TomFormDateCalendar` / `TomFormDateTextInput` | Input, Button, Dialog families |
| MasterDetail | `TomMasterDetailListForm` | Read from `TomList`; edit via detail `TomForm` | List/tree + detail edit form pattern | List or Tree, Container, FormField families |
| SearchField | `TomFormSearchField` / `TomFormLookupField` (concrete `TomFormSearchInput` / `TomFormLookupDialog`) | `TomObject<T>` read/write (selected); search source from data source or static list | Input with live search, dropdown results, selection | Input, List, Container families |
| FileUpload | `TomFormFileUpload` / `TomFormFileDropzone` (base `TomFormFileField`) | `TomObject<FileRef?>` read/write | File selection, preview, progress | Button, Progress, Label families |

> **Note — paginated data-source layer (retained-intended, Appendix A.1).** The
> component families above ship today over observable `TomList` collections:
> master-detail as the concrete `TomMasterDetailListForm` / `TomListForm` with
> selection via `TomSelectableSource`, and edit/undo via `TomActionTransaction` +
> `TomUndoHistory`. The **paginated** `TomListDataSource` / `TomTreeDataSource`
> data-source layer and its `TomEditBuffer` (§14) remain intended future work for
> the large-collection case; see Appendix A.1.

All form components follow the same base hierarchy:

- TomNodeBase
- TomPolicyNodeBase
- TomTextFormFieldBase (or specific form component family base)
- concrete form component class

Form component behavior:

- one root ID for semantic field identity,
- optional group membership on root,
- internal parts inherit root resource base path and append part-specific suffixes,
- all parts use same resource and policy principles.

### Widget type identification

Rather than declaring widget types externally (via an enum or config), each widget provides its family types through the base class interface:

```dart
abstract class TomFamilyBase extends TomPolicyNodeBase {
  /// The primary family type of this widget.
  TomWidgetFamily get family;

  /// All family types this widget belongs to.
  /// A date-time-picker is both a FormField and a DateTimePicker.
  /// A search field is both a FormField and a SearchField.
  Set<TomWidgetFamily> get families => {family};

  /// Check if this widget has a specific nature.
  bool isFamily(TomWidgetFamily type) => families.contains(type);
}
```

This avoids errors from mismatched type declarations and allows for widgets with multiple natures — the design intent being that a `TomFormDateTimePicker` would report both `TomWidgetFamily.formField` and `TomWidgetFamily.dateTimePicker`. Only the widget class itself knows about its natures.

> **Status: not yet built.** This part of the design is unrealised. `families`
> is overridden nowhere in the package, so every Tom widget reports exactly one
> family; and the six form values named here are claimed by no type at all,
> because form fields descend from `TomField<T>` rather than from
> `TomFamilyBase` and so carry no family. The multi-nature machinery above is
> real and works — it simply has no users yet. See
> [widget_base.md](widget_base.md#the-widget-family-taxonomy).

### 12.3 Form field anatomy

Every Tom Form Component derived from `TomTextFormFieldBase` is a full-featured form input. All elements load their text from resources, so no separate group-based visibility control is needed — the field controls its own children.

Standard anatomy from top to bottom:

```
┌─────────────────────────────────────────────────────┐
│  [label]                              [info-icon] [?]│  label row
├─────────────────────────────────────────────────────┤
│  [error message above field]                        │  top error (optional)
├─────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────┐ [action-icon]│  input row
│  │  [placeholder / hint text]       │ [action-icon]│
│  └───────────────────────────────────┘              │
├─────────────────────────────────────────────────────┤
│  [error message below field]                        │  bottom error (optional)
├─────────────────────────────────────────────────────┤
│  [field description / helper text]                  │  description row
└─────────────────────────────────────────────────────┘
```

**Note on resource keys**: The suffixes listed below are illustrative samples. The actual resource keys used by each widget will be determined during implementation. Some widgets may use additional or different suffixes. Some text or configuration may also come from data or external configuration (e.g., calendar configuration files) rather than resource files.

Sample resource suffixes for a form field:

| Suffix | Purpose | Example |
|--------|---------|--------|
| `label` | Field label text | "Email address" |
| `hint` | Placeholder text inside empty field | "you@example.com" |
| `description` | Helper text below the field | "We will never share your email." |
| `error.required` | Error when value is empty | "Email is required." |
| `error.format` | Error when format is invalid | "Please enter a valid email." |
| `error.min` | Error for minimum constraint | "Must be at least 3 characters." |
| `error.max` | Error for maximum constraint | "Must be at most 255 characters." |
| `error.custom` | Custom validation error | (app-specific) |
| `info.title` | Info dialog/overlay title | "Email address" |
| `info.body` | Info dialog/overlay content | "Your primary contact email..." |
| `help.title` | Help dialog/overlay title | "Help" |
| `help.body` | Help dialog/overlay content | "Enter the email you used to..." |
| `action.<name>.tooltip` | Action icon button tooltip | "Clear field" |

Visual behavior:

- **Default value**: field shows the default from the bound state; placeholder/hint is only visible when the field is empty.
- **Error color change**: when an error is active, the field border, label, and error message text change to the error color (from theme).
- **Info icon**: opens an overlay or dialog with `info.title` and `info.body`.
- **Help icon (?)**: opens an overlay or dialog with `help.title` and `help.body`.
- **Action icons**: positioned to the right of the input; each action has a resource-based tooltip.

### 12.4 Date and time picker form components

All date/time pickers derive from the `TomFormDateField` / `TomFormTimeField` / `TomFormDateTimeField` field bases. They use `TomTimezone` and `TomZonedDateTime`/`TomZonedDate`/`TomZonedTime` from `tom_core_kernel/lib/src/tombase/timezoned` for internal UTC storage and display-time conversion.

**Core principle: all internal storage is UTC. All timezone conversion happens during input and display only.**

Picker types:

| Concrete Class | Bound Type | Description |
|---------------|------------|-------------|
| `TomFormDatePicker` | `TomZonedDate` | Date-only selection |
| `TomFormTimePicker` | `TomZonedTime` | Time-only selection |
| `TomFormDateTimePicker` | `TomZonedDateTime` | Combined date and time selection |
| `TomFormDateRangePicker` | `(TomZonedDate, TomZonedDate)` | Start-date / end-date pair |
| `TomFormTimeRangeField` | `(TomZonedTime, TomZonedTime)` | Start-time / end-time pair |
| `TomFormDateTimeRangeField` | `(TomZonedDateTime, TomZonedDateTime)` | Start-datetime / end-datetime pair |

All pickers support both manual keyboard input and graphical selection.

**Manual input**: the text field accepts typed values in locale-appropriate format. Parsing uses `TomTimezone` for correct UTC conversion.

**Graphical input**: a calendar/clock overlay opens on tap or icon click. The overlay is a separate compound composed of navigation buttons, day/month/year grids, and hour/minute selectors.

**Slot-based restriction model**:

Pickers accept a `TomTimeSlotRestriction` that constrains selectable dates and times with millisecond precision.

```dart
class TomTimeSlotRestriction {
  /// Allowed date range (inclusive). Null = no bound.
  final TomZonedDate? firstDate;
  final TomZonedDate? lastDate;

  /// Allowed weekdays (1=Monday .. 7=Sunday). Empty = all days.
  final Set<int> allowedWeekdays;

  /// Per-day time slots. Each slot is a (start, end) pair in UTC.
  /// Empty list = all times on allowed days.
  /// Multiple slots per day are supported (e.g., morning + afternoon).
  final List<TomTimeSlot> allowedTimeSlots;

  /// Specific blocked dates (holidays, etc.).
  final Set<TomZonedDate> blockedDates;

  /// Specific blocked datetime ranges.
  final List<(TomZonedDateTime, TomZonedDateTime)> blockedRanges;
}

class TomTimeSlot {
  final TomZonedTime start; // inclusive
  final TomZonedTime end;   // exclusive
  // Millisecond precision from TomZonedTime
}
```

Restriction examples:

- "All days, all times" → empty restriction (default)
- "Weekdays only, 08:00–17:00" → `allowedWeekdays: {1,2,3,4,5}`, one slot `08:00–17:00`
- "Mon/Wed/Fri, morning 09:00–12:00 and afternoon 14:00–17:30" → weekdays + two slots
- "Any day except 2026-12-25, 2026-12-26" → `blockedDates: {dec25, dec26}`

**Dynamic restrictions**: Restrictions are often not static. They can be bound to `TomObject<TomTimeSlotRestriction>` so they update dynamically. For example, selecting an office location updates the available time slots from the office's calendar; selecting a contact person restricts to their available hours. The restriction binding follows the same `TomObject<T>` pattern as all other state bindings.

Additional sample resource suffixes for pickers (see note in §12.3 about resource keys being illustrative):

| Suffix | Purpose |
|--------|--------|
| `picker.dateLabel` | Label in date portion |
| `picker.timeLabel` | Label in time portion |
| `picker.startLabel` | Label for range start |
| `picker.endLabel` | Label for range end |
| `picker.blocked` | Message for blocked date/time |

### 12.5 Linked fields and dynamic add/delete patterns

Since form components include their own labels, descriptions, error messages, and action buttons, grouping for simple visibility control is rarely needed.

Groups become relevant for:

- **Linked field pairs**: e.g., "Start date" and "End date" that must appear/disappear together. Both fields share a group, one field's ID controls group visibility.
- **Dynamic list items**: a repeating set of fields (e.g., "add phone number") with add/delete buttons. Each item row shares a group. The "add" button sits outside the group. The "delete" button sits inside the group with each item.
- **Conditional sections**: a checkbox or radio reveals/hides a section of related fields. The controlling widget's ID drives the group.

Example: dynamic address list

```
[Add Address button]                         ← outside group

┌─ group: "address.0" ──────────────────────┐
│ [Street field] [City field] [Delete btn]  │
└───────────────────────────────────────────┘
┌─ group: "address.1" ──────────────────────┐
│ [Street field] [City field] [Delete btn]  │
└───────────────────────────────────────────┘
```

The list showing items and the fields for editing them are in the same group — when the group is hidden, both the display and the edit controls disappear together.

---

## 13. Screen Definition and ACL Layout Integration

This section defines how screens are declared and how declarations connect to the ACL layout engine.

### 13.1 Screen definition approach

Screen elements are defined by directly instantiating the concrete Tom widget classes. There is no factory, no type enum, no untyped config map. All widget-specific parameters (bindings, restrictions, items, callbacks) are passed as typed constructor arguments, verified by the Dart compiler.

A screen definition consists of:

1. **`TomScreenElementsProvider`** — a marker interface whose base class (`TomScreenElementsProviderBase`) **is itself a `TomScope`**. Declares widgets as typed fields, discovered via `@tomReflect`.
2. Each field is a directly-instantiated Tom widget with typed constructor arguments.
3. The **layout** (how elements are arranged on screen) is a separate `AclBuilder` call.

### 13.2 TomScreenElementsProvider — scoped widget groups

```dart
/// Marker interface for screen element providers.
abstract interface class TomScreenElementsProvider {
  TomScope get scope;
}

/// Base class that IS a TomScope — creates hierarchical scope chain.
class TomScreenElementsProviderBase with TomScopeMixin
    implements TomScreenElementsProvider {
  TomScreenElementsProviderBase([String? scopeId,
      TomScreenElementsProvider? parent]) {
    final parentScope = parent?.scope ?? TomScope.current;
    initScope(scopeId: scopeId ?? parentScope.id, parentScope: parentScope.parent);
  }

  @override
  TomScope get scope => this; // the provider IS a scope
}
```

Concrete implementation for a login screen:

```dart
@tomReflect
class LoginScreenElements extends TomScreenElementsProviderBase {
  final AppState appState;
  final void Function() onLogin;

  LoginScreenElements({required this.appState, required this.onLogin})
      : super('login');

  late final email = TomTextField(
    tomId: 'email',
    binding: appState.formData.username,
    keyboardType: TextInputType.emailAddress,
    scope: this,
  );

  late final password = TomTextField(
    tomId: 'password',
    binding: appState.formData.password,
    obscureText: true,
    scope: this,
  );

  late final loginButton = TomElevatedButton(
    tomId: 'loginButton',
    onPressed: onLogin,
    scope: this,
  );
}
```

Every parameter is type-safe. The email field takes a `TomObject<String>`, the button takes a `VoidCallback`. No `Map<String, dynamic>` config. Fields are discovered automatically via `@tomReflect` annotation — no manual element list or per-widget wrapper objects needed.

Widget paths are resolved from the provider's scope: `login.email`, `login.password`, `login.loginButton`.

### 13.3 Nested providers

Providers can nest, creating hierarchical scope chains:

```dart
@tomReflect
class OrderScreenProvider extends TomScreenElementsProviderBase {
  OrderScreenProvider() : super('order');

  late final submitButton = TomElevatedButton(tomId: 'submit', scope: this);
  late final details = OrderDetailsProvider(this); // nested
}

@tomReflect
class OrderDetailsProvider extends TomScreenElementsProviderBase {
  OrderDetailsProvider(TomScreenElementsProvider parent) : super('details', parent);

  late final nameField = TomTextField(tomId: 'name', scope: this);
}
```

Resulting paths (with outer zone `'demo'`): `demo.order.submit`, `demo.order.details.name`.

### 13.4 Validation buffer — form-level state management

Tom Form Components (§12.2) do **not** write directly to the application state. Simple Tom-wrapped Flutter widgets with direct bindings do write immediately (see §2.4).

#### TomForm<T> — typed binding to TomClass

A form is typed to its target: `TomForm<T>` where `T extends TomClass`. The form knows the shape of the data it edits. Form fields map directly onto the members defined by the target class:

```dart
/// A form that edits an Address object in the application state.
class AddressForm extends TomForm<Address> {
  AddressForm({required super.formId});

  /// Fields map to Address members. The binding is resolved
  /// when the form is bound to a concrete Address instance.
  late final street = field<String>('street');    // → Address.street
  late final city = field<String>('city');        // → Address.city
  late final zip = field<String>('zip');          // → Address.zip
  late final country = field<String>('country');  // → Address.country
}
```

The field-to-member mapping can be validated using reflection: if `Address` does not have a `street` member of type `String`, this is detected as a configuration error at startup or in the debug view.

The form definition specifies the **type** binding. The concrete **instance** is provided at mount time:

```dart
// Same AddressForm type, different target instances
final billingForm = AddressForm(formId: 'billingAddress')
    ..bind(appState.order.billingAddress);

final deliveryForm = AddressForm(formId: 'deliveryAddress')
    ..bind(appState.order.deliveryAddress);
```

#### Sub-forms and nesting

Complex screens compose forms hierarchically:

```dart
class OrderForm extends TomForm<Order> {
  OrderForm() : super(formId: 'order');

  // Direct fields on Order
  late final orderNumber = field<String>('orderNumber');
  late final notes = field<String>('notes');

  // Sub-forms — each typed to its own TomClass
  late final billing = subForm(AddressForm(formId: 'billingAddress'));
  late final shipping = subForm(AddressForm(formId: 'shippingAddress'));

  // Repeated sub-forms — for lists of items
  late final items = subFormList<OrderItem, OrderItemForm>(
    (index) => OrderItemForm(formId: 'item_$index'),
  );
}
```

The owning form coordinates save/discard across all sub-forms:

- `OrderForm.save()` validates and commits the order fields, then calls `save()` on `billing`, `shipping`, and each item form.
- If any sub-form fails validation, the entire save is aborted.
- `OrderForm.discard()` resets all sub-forms.

#### Repeated forms

The same form type can appear multiple times, each bound to a different object:

```dart
// Delivery section with multiple addresses
final deliveryForms = appState.order.deliveryAddresses.map((addr, index) =>
  AddressForm(formId: 'delivery_$index')..bind(addr)
).toList();
```

Each instance has its own edit state, validation, and save/discard lifecycle.

#### Field binding mechanics

For form components, the binding model works through the form:

1. Each form field widget maintains **internal edit state** — what the user is currently typing or selecting.
2. The form knows which `TomClass` member each field maps to.
3. On **save** (explicit save action or auto-save trigger), **validation runs first** across all form fields.
4. If any validation fails, fields show errors and the target `TomClass` is **not modified**.
5. Only when all validation passes are field values **committed to the target object** (member by member).
6. On **cancel/discard**, the internal state is reset from the target object.
7. If field state does not map directly to target members, the form's save callback can apply business logic mapping before committing.

```dart
abstract class TomTextFormFieldBase<T> extends TomFamilyBase {
  /// Binding to the application state (read source + write target after validation).
  final TomObject<T> binding;

  /// Internal edit state — holds the user's current input.
  /// Not visible to the application state until committed.
  late T _editValue;

  /// Whether the internal state has uncommitted changes.
  bool get isDirty => _editValue != binding.value;

  /// Validate the current edit state. Returns list of errors (empty = valid).
  List<String> validate();

  /// Commit: validate, then copy to application state if valid.
  bool commit() {
    final errors = validate();
    if (errors.isNotEmpty) return false;
    binding.value = _editValue;
    return true;
  }

  /// Discard: reset internal state from application state.
  void discard() {
    _editValue = binding.value;
  }
}
```

This pattern ensures the application state is always in a valid, consistent state. The widget tree shows the user's in-progress edits, but the observable state only changes on successful validation.

**Why the form references but is not the application state**: The form *type* (`TomForm<Address>`) defines the structure. The form *instance* is bound to a concrete `TomClass` object at mount time. This separation enables reuse — `AddressForm` works for billing, delivery, or any `Address` object — and supports repeated forms (multiple delivery addresses) and business logic mapping where widget state doesn't map 1:1 to state fields.

**Form-level save**: The form coordinates save across all its fields and sub-forms:

```dart
abstract class TomForm<T extends TomClass> {
  final String formId;
  T? _target;

  TomForm({required this.formId});

  void bind(T target) => _target = target;

  /// Validate and commit all fields. Returns true if all valid.
  bool save() {
    if (!validateAll()) return false;
    commitAll(); // writes validated values to _target members
    return true;
  }

  /// Discard all field edits — reset from target object.
  void discardAll() { /* reset each field from _target */ }

  /// Validate all fields and sub-forms. Returns true if all valid.
  bool validateAll() { /* validate fields + sub-forms */ }
}
```

### 13.5 Connecting to ACL layout

The layout arranges screen elements using `AclBuilder`. The provider gives access to elements by ID:

```dart
Widget buildLoginScreen(BuildContext context) {
  final form = LoginScreenElements(
    appState: appState,
    onLogin: handleLogin,
  );

  return AclBuilder(title: 'Login')
    ..setAclId('loginPanel')
    ..append(form['email']!.widget)..expandX()
    ..newRow(dist: 8)
    ..append(form['password']!.widget)..expandX()
    ..newRow(dist: 16)
    ..gap()
    ..append(form['loginButton']!.widget)
    ..build();
}
```

This keeps a clean separation:

- `TomScreenElementsProvider` declares **what** is on the screen, with directly instantiated widgets as typed fields, discovered via reflection.
- `AclBuilder` declares **how** it is arranged on screen.
- Resources, authorization, and theming are resolved automatically by the widget system.

### 13.6 Complex example — user profile form

```dart
@tomReflect
class ProfileScreenElements extends TomScreenElementsProviderBase {
  final AppState appState;
  final void Function() onSave;

  ProfileScreenElements({required this.appState, required this.onSave})
      : super('profileForm');

  late final firstName = TomTextField(
    tomId: 'firstName',
    binding: appState.user.firstName,
    scope: this,
  );

  late final lastName = TomTextField(
    tomId: 'lastName',
    binding: appState.user.lastName,
    scope: this,
  );

  late final email = TomTextField(
    tomId: 'email',
    binding: appState.user.email,
    keyboardType: TextInputType.emailAddress,
    scope: this,
  );

  late final birthDate = TomFormDatePicker(
    tomId: 'birthDate',
    binding: appState.user.birthDate,
    lastDate: TomZonedDate.now(),
    scope: this,
  );

  late final workStart = TomFormTimePicker(
    tomId: 'workStart',
    binding: appState.user.workStartTime,
    // Dynamic restriction — bound to observable state, updates when office changes
    restriction: appState.officeConfig.availableTimeSlots,
    scope: this,
  );

  late final role = TomFormEnumDropdown<Role>(
    tomId: 'role',
    binding: appState.user.role,
    items: Role.values,
    scope: this,
  );

  late final isAdmin = TomFormBoolSwitch(
    tomId: 'isAdmin',
    binding: appState.user.isAdmin,
    authorizationGroup: adminGroup,
    scope: this,
  );

  late final adminNotes = TomFormStringInput(
    tomId: 'adminNotes',
    binding: appState.user.adminNotes,
    maxLines: 5,
    authorizationGroup: adminGroup,
    scope: this,
  );

  late final save = TomElevatedButton(
    tomId: 'save',
    onPressed: onSave,
    scope: this,
  );

  final adminGroup = TomAuthorizationGroup('adminSection');
}

Widget buildProfileScreen(BuildContext context) {
  final form = ProfileScreenElements(
    appState: appState,
    onSave: () {
      if (form.saveAll()) {
        // all valid, proceed
      }
    },
  );

  return AclBuilder(title: 'User Profile')
    ..setAclId('profilePanel')
    // Name row
    ..append(form['firstName']!.widget)..expandX()
    ..append(form['lastName']!.widget, dist: 8)..expandX()
    ..addRowBreakpoint(atWidth: 500)
    ..newRow(dist: 8)
    // Email + birth date
    ..append(form['email']!.widget)..expandX()
    ..append(form['birthDate']!.widget, dist: 8)
    ..newRow(dist: 8)
    // Work time + role
    ..append(form['workStart']!.widget)
    ..append(form['role']!.widget, dist: 8)..expandX()
    ..newRow(dist: 12)
    // Admin section
    ..append(form['isAdmin']!.widget)
    ..newRow(dist: 8)
    ..startGroup('adminSection')
    ..append(form['adminNotes']!.widget)..expandX()
    ..endGroup()
    ..newRow(dist: 16)
    ..gap()
    ..append(form['save']!.widget)
    ..build();
}
```

Note how `workStart` binds its restriction to `appState.officeConfig.availableTimeSlots` — a `TomObject<TomTimeSlotRestriction>` that changes when the user selects a different office. The `TomFormTimePicker` observes this and updates its selectable slots. This is fully type-safe.

### 13.7 JSON-ACL layout as AclBuilder alternative

> **Intended — not yet built (Appendix A.1).** `AclBuilder` ships today for
> programmatic layout; the JSON feeding methods below (`processJson` /
> `buildFromJson`) are retained intended future work, not shipped. The abandoned
> `AclJsonLayout` name (a separate JSON entry-point) was dropped in favour of
> feeding JSON directly into the shipped `AclBuilder`.

The JSON-ACL format is not a separate system — it feeds directly into `AclBuilder`:

```dart
// Option 1: Mix JSON with builder commands
Widget buildScreen(BuildContext context) {
  final form = LoginScreenElements(appState: appState, onLogin: handleLogin);

  return AclBuilder(title: 'Login')
    ..setAclId('loginPanel')
    ..processJson(layoutJson, elementProvider: form)  // insert JSON layout commands
    ..build();
}

// Option 2: Build entirely from JSON
Widget buildScreen(BuildContext context) {
  final form = LoginScreenElements(appState: appState, onLogin: handleLogin);

  return AclBuilder(title: 'Login')
    .buildFromJson(layoutJson, elementProvider: form);
}
```

The JSON references elements by ID. The `TomScreenElementsProvider` resolves ID → element → widget:

```json
{
  "containerId": "loginPanel",
  "rows": [
    { "elements": [{ "ref": "email", "expandX": true }] },
    { "elements": [{ "ref": "password", "expandX": true }], "dist": 8 },
    { "elements": [{ "type": "gap" }, { "ref": "loginButton" }], "dist": 16 }
  ]
}
```

`processJson` can appear multiple times in a builder chain, mixed with programmatic builder calls. This allows partial JSON layouts combined with dynamic Dart logic.

The JSON format is a layout-only concern — it never defines widget types, bindings, or configuration. Those are always in the Dart `TomScreenElementsProvider`.

---

## 14. Tree and List View Strategy

Tree views and list views displaying many records require a different data approach than form fields bound to application state.

### 14.1 Problem

Form fields bind to `TomClass` / `TomObject` fields in the application state. This works for single-record editing (one user profile, one order). But list/tree views may display hundreds or thousands of records. Loading all records into the observable application state is not feasible.

### 14.2 Data source abstraction

List and tree views use a data source abstraction separate from the application state:

```dart
abstract class TomListDataSource<T> {
  /// Total number of records available (may be estimated for virtual scroll).
  int get totalCount;

  /// Load a page of records.
  Future<List<T>> loadPage(int offset, int limit);

  /// Single record by ID (for detail view).
  Future<T?> loadById(String id);

  /// Notify listeners when data changes.
  ValueNotifier<int> get revision;
}

abstract class TomTreeDataSource<T> {
  /// Load root nodes.
  Future<List<T>> loadRoots();

  /// Load children of a node.
  Future<List<T>> loadChildren(T parent);

  /// Whether a node has children (for expand indicator before loading).
  bool hasChildren(T node);

  /// Notify listeners when data changes.
  ValueNotifier<int> get revision;
}
```

### 14.3 List view pattern

A Tom list view composes:

1. **Data source** — provides paginated records.
2. **Row template** — defines how each record is displayed (columns, actions).
3. **Selection model** — single, multi, or none.
4. **Action bar** — buttons above the list (add, delete, refresh, filter).

```dart
class TomListView<T> extends TomPolicyNodeBase {
  final TomListDataSource<T> dataSource;
  final Widget Function(T item, int index) rowBuilder;
  final TomListSelectionMode selectionMode;
  final void Function(T item)? onSelect;
  final List<Widget>? actions;
}

enum TomListSelectionMode { none, single, multi }
```

The list view handles:

- Virtual scrolling — only materializes visible rows.
- Pull-to-refresh and scroll-to-load-more.
- Loading and empty states (with resource-based messages).
- Selection state lives in a `TomListSelectionState` object, not in the main app state.

### 14.4 Tree view pattern

Same approach with hierarchical data:

```dart
class TomTreeView<T> extends TomPolicyNodeBase {
  final TomTreeDataSource<T> dataSource;
  final Widget Function(T node, int depth) nodeBuilder;
  final void Function(T node)? onSelect;
  final bool expandOnSelect;
}
```

Expand/collapse state is local to the tree widget instance.

### 14.5 Master-detail pattern

> **Intended — not yet built (Appendix A.1).** The paginated data-source layer
> (`TomListDataSource` / `TomTreeDataSource`), the `TomMasterDetail` node, and the
> `TomEditBuffer` below are retained intended future work for the large-collection
> case the framework does not yet cover; see Appendix A.1. Master-detail over a
> bounded collection ships today as the concrete `TomMasterDetailListForm` /
> `TomListForm` over an observable `TomList`, with the detail pane bound to a
> `TomForm` and edit/undo via `TomActionTransaction` + `TomUndoHistory`.

Combining list/tree with a detail edit form:

```
┌───────────────────────┬─────────────────────────────┐
│  List / Tree          │  Detail Form                │
│                       │                             │
│  ▸ Record A           │  [firstName]  [lastName]    │
│  ● Record B (selected)│  [email]                    │
│  ▸ Record C           │  [Save] [Cancel]            │
│                       │                             │
└───────────────────────┴─────────────────────────────┘
```

Workflow:

1. User selects a record in the list/tree.
2. The detail form loads the selected record into a **temporary edit buffer** — a `TomClass` instance separate from the data source.
3. The edit buffer is bound to form fields via the `TomScreenElementsProvider`.
4. On save, the buffer is committed back to the data source.
5. On cancel, the buffer is discarded.

```dart
class TomMasterDetail<T> extends TomPolicyNodeBase {
  final TomListDataSource<T> dataSource;       // or TomTreeDataSource<T>
  final Widget Function(T item) listRowBuilder;
  final TomScreenElementsProvider Function(T item) formBuilder; // creates element provider for selected item
  final Future<void> Function(T item, Map<String, Object> values) onSave;
}
```

### 14.6 Edit buffer strategy

The edit buffer is the bridge between mass-data list views and the single-record `TomClass` form binding:

- `TomListDataSource` or `TomTreeDataSource` provides records as plain objects or DTOs.
- When a record is selected for editing, a **`TomEditBuffer`** is created — a `TomClass` populated from the selected record.
- The `TomScreenElementsProvider` binds its fields to `TomEditBuffer` fields.
- On save, `TomEditBuffer` values are extracted and sent back to the data source (API call, local storage, etc.).
- The data source fires `revision` notification, the list reloads the affected page.

```dart
class TomEditBuffer<T> extends TomClass {
  // Fields populated from selected record T
  // After save, values extracted and sent to data source

  void loadFrom(T record) { ... }  // populate fields
  Map<String, Object> extractValues() { ... }  // for save
  void discard() { ... }  // reset to last loaded values
}
```

This keeps the application state lean — only the currently-edited record has observable state. The list/tree data source manages bulk data through paginated loading.

### 14.7 Authorization for list views

List views participate in the same authorization model:

- The list view widget itself has an ID and can be hidden/disabled/readonly.
- Individual list columns can have resource keys for field-level protection (sensitive columns hidden).
- Action buttons (add, delete) have IDs and can be individually authorized.
- The data source is responsible for server-side filtering — the UI authorization layer handles client-side display only.

---

## 15. Implementation Status

### Completed

- Base class chain: `TomNodeBase` → `TomPolicyNodeBase` → `TomFamilyBase` → 20 family branch bases
- 290 wrapped Flutter widgets, 273 of them on a family branch base
- `TomWidgetFamily` enum (26 values: 20 Flutter-derived + 6 custom form families)
- Authorization: `TomAuthState`, `TomAuthorizable`, `TomAuthorizationGroup`, `TomAuthorization` singleton, `TomAuthorizer`, `TomAuthorizerStrategy`, `TomUIStateController`
- Authorization enforcement in `TomPolicyNodeBase` (4-state switch, `resolveEffectiveAuth()`)
- `TomStateStyle` via `TomThemeScope` for readonly visual treatment
- Scope system: `TomScope`, `TomScopeMixin`, Zone-based path resolution
- `TomScreenElementsProvider` interface and `TomScreenElementsProviderBase`
- `TomStatelessWidget`, `TomStatefulWidget`, `TomState` — scope-preserving base classes
- Resource resolution: `TomUIIcons`, `TomUIColors`, `TomStyleResolvers` (1100+ lines with 17 style parsers), backed by kernel `TomTextResourceProvider` / `TomConfigResourceProvider`
- `TomCtr` construction helpers for resource resolution at widget construction time
- Action system: `TomAction`, `TomSimpleAction`, `TomActionContext`, `TomActionController`, `TomActionTrigger`, `TomActionTransaction`, `TomCompositeAction`, `TomUndoHistory`
- Forms: `TomForm`, `TomField<T>`, `TomTextFormFieldBase<T>`, `TomFormStringField` / `TomFormStringInput`, `TomFormIntField` / `TomFormIntInput`, `TomFormDoubleField` / `TomFormDoubleInput`, `TomFormBoolCheckbox` / `TomFormBoolSwitch`, `TomFormStringDropdown` / `TomFormEnumDropdown`, `TomFormDateTextInput`, `TomListForm`
- `TomWidgetMixin` for extension-pattern widgets (18 widgets)

### Remaining (planned — intended future work)

These address capabilities the shipped framework does not yet cover; the design
is catalogued in Appendix A.1.

- Time-window slot restrictions for pickers (`TomTimeSlot` / `TomTimeSlotRestriction`; the pickers themselves ship as `TomFormDatePicker` / `TomFormTimePicker` / `TomFormDateTimePicker`, and multiline / search-lookup fields ship)
- Nested/sub-form coordination beyond the shipped `TomListForm`
- Resource fallback chain (multi-level resolution; `TomUIResourceAdapter` / `TomFallbackResourceAdapter`)
- Timed and event-based action triggers
- `TomListDataSource` / `TomTreeDataSource` paginated data-source and master-detail pattern with `TomEditBuffer` (lists/trees over bounded collections ship via `TomListView` / `TomListForm` / `TomTreeView`)
- `TomRouteContext` navigation context for action contexts
- Debug view tooling

---

## 16. Final Decision

This architecture intentionally favors clarity over generic abstraction.

**Two dimensions:**

- **widgets** (visual) and **actions** (behavioral) share the same infrastructure: IDs, resources, groups, authorization,
- both are first-class citizens with their own identification (actions use plain dot-separated paths like widgets),
- locale and process context are resolved during application initialization — the widget/action layer receives pre-resolved resources.

**Core infrastructure:**

- four shared concerns: resources, ID, group, state binding,
- three widget binding modes: display (read-only), direct (read/write), form (validated write via `TomForm<T extends TomClass>` with sub-form and repeated-form nesting),
- authorization uses a four-state model (`none`/`disabled`/`read`/`full`) with per-widget `TomAuthorizer` and build-time `TomUIStateController` for business-rule narrowing,
- all paths use plain IDs without prefixes — widgets, scopes, controllers, and actions,
- groups can contain both widgets and actions — a single authorization key controls an entire functional unit.

**Action system:**

- `TomAction<TContext, TUndo>` base class with typed context, `canExecute()`, `execute()`, optional `undo()`,
- actions are **stateless** — no mutable instance state survives between invocations; each invocation creates transient state if needed,
- each action declares a typed `TomActionContext` subclass specifying the state subtree it operates on,
- actions drive user interaction (confirmation dialogs, file entry, input) through `TomActionController` / `TomActionContext` and standard dialogs (`TomDialogBase`) — consistent behavior regardless of trigger source,
- `TomActionController` groups related actions under a scoped ID, with **field-based typesafe access** (no dynamic `getAction()` lookup),
- three registration tiers: global (app-wide), screen (per screen), form (auto-registered save/discard/validate),
- action authorization hierarchy: route-specific → global, with global denial being absolute,
- triggers (buttons, menus, keyboard shortcuts, timed events, external events, conditional chains) all reference actions by ID,
- `TomActionTransaction` groups sub-actions into one undo step, with typed `run()` method,
- a transaction is undoable only if all sub-actions are undoable — no partial undo,
- `TomUndoHistory` provides undo/redo with configurable depth,
- actions declare their data needs through `canExecute()` — all triggers disable uniformly when preconditions fail.

**Widgets:**

- all widgets share one base hierarchy and one policy boundary,
- widget family types are reported by the widget itself through the base class (not declared externally),
- families provide common behavior,
- concrete classes can be created one-by-one as needed,
- screen elements are defined with directly instantiated widgets — no factory, no type enum, no untyped config,
- Tom Form Components maintain internal edit state; validated values are committed to application state on form save,
- simple Tom-wrapped Flutter widgets can bind directly to state for immediate feedback,
- forms reference application state but are not themselves application state, enabling reuse and business logic mapping,
- delegated widget APIs remain fully available.

**Debug and tooling:**

- comprehensive debug view with seven views: authorization, resources, auth trace, resource trace, ID structure, action registry, compound export,
- all views support filtering (search, state filters, scope filters) and structured export (YAML, text),
- data collected from live widget/action instances via base class hierarchy — no runtime overhead when inactive.

**Layout and integration:**

- screen definition and layout are separate but both Dart-first,
- JSON-ACL layout integrates directly into AclBuilder via `processJson`/`buildFromJson`,
- Tom Form Components replace simple Flutter-derived widgets for form use, providing comprehensive reusable field components,
- list/tree views use paginated data sources with edit buffers for detail forms,
- all existing sample code is replaced in one migration — no backward compatibility overhead.

This gives a clear path to stable semantics with flexible implementation and layout choices.

---

## Appendix A — Proposed / not-yet-built constructs

> **Status (2026-07-16).** Every forward-looking construct was relocated here
> non-destructively, then the design owner's abandoned-vs-intended call split
> the catalogue in two:
>
> - **A.1 — Intended (retained).** Each addresses a capability the shipped
>   framework does **not yet** provide. The body sections keep an inline
>   **Intended — not yet built (Appendix A.1)** marker; the design is preserved as
>   future work. Do **not** treat any A.1 name as an available API yet.
> - **A.2 — Abandoned (removed).** Each was a proposed *name* for a need the
>   shipped framework now fully covers a different way, with no residual capability
>   gap. Its body prose was deleted; this table is the only surviving record, kept
>   so the decision is auditable.
>
> Constructs that appeared in an earlier draft but have since **shipped** — the
> date/time pickers, `TomFormDateCalendar` / `TomFormDateTextInput`, file upload
> (`TomFormFileUpload` / `TomFormFileDropzone`), the master-detail list
> (`TomMasterDetailListForm` / `TomListForm`), the choice list, and the
> search/lookup fields (`TomSearchFieldFamilyBase` → `TomFormSearchField` /
> `TomFormLookupField`) — have moved to the §0.1 renamed mapping and are no longer
> listed here.

### A.1 — Intended (retained future work)

| Intended construct(s) | Capability gap / current partial coverage |
| --------------------- | ----------------------------------------- |
| `TomListDataSource`, `TomTreeDataSource`, `TomListSelectionMode`, `TomListSelectionState`, the `TomMasterDetail` node, `TomEditBuffer` | Paginated large-collection data-source subsystem with detail-edit buffer (§12.2, §14). Shipped `TomMasterDetailListForm` / `TomListForm` / `TomSelectableSource` cover only bounded, observable `TomList` collections; the paginated (thousands-of-records) case is not yet built. |
| `TomUIResourceAdapter`, `TomFallbackResourceAdapter`, `TomResourceAdapterProvider` | Multi-level resource-fallback chain (§7.1–7.2). Shipped code resolves text via `TomTextResourceProvider` with a single-level path lookup only. |
| `TomRouteContext` | Navigation/route context woven into `TomActionContext` (§8A). `TomNavigationBase` ships, but the route-context object itself is not built. |
| `TomTimeSlot`, `TomTimeSlotRestriction` | Time-window restriction model for the date/time pickers (§12.4). The pickers ship (`TomFormDatePicker` / `TomFormTimePicker` / `TomFormDateTimePicker`); the slot-restriction binding is not yet built. |
| `AclBuilder.processJson` / `buildFromJson` | JSON-ACL layout feeding into the shipped `AclBuilder` (§13.7). `AclBuilder` ships for programmatic layout; the JSON-feed methods are not yet built. |

### A.2 — Abandoned (removed; framework covers the need a different way)

| Abandoned name(s) | Shipped mechanism that replaced the need |
| ----------------- | ---------------------------------------- |
| `TomMultilineField` | Not a class; multiline ships via `TomFormStringInput(maxLines: …)` / `TomTextField`. |
| `TomListEditorFamilyBase`, `TomMasterDetailFamilyBase` | Family-base *names* dropped; master-detail / list editing ships as `TomMasterDetailListForm` / `TomListForm` over observable `TomList`. (The paginated data layer these would have sat on is retained in A.1.) |
| `TomThemeConfig`, `TomVariantThemeConfig`, `TomFamilyThemeConfig` | Theming ships via `TomThemeSpec` / `TomFormStyle` / `TomFormStyleScope` / `TomThemeScope` / `TomStateStyle` / `TomStyleResolvers`. |
| `TomFieldImplementation` | Pluggable field-implementation layer dropped; fields ship as `TomField` + `TomTextFormFieldBase` subclasses. |
| `requestUi()`, `TomConfirmation`, `TomInputField` / `TomChoiceList` / `TomFilePicker` (as UI-flow requests), `TomUiRequest`, `TomHelpButton` | Action UI-flow request layer dropped; actions drive UI via `TomActionController` / `TomActionContext` + `TomDialogBase`. Buttons ship as `TomIconButton` / `TomTextButton`; file entry as the `TomFormFileUpload` form field. |
| `TomActionRegistryProvider` | Actions register via `TomActionController` / `TomActionContext` (global tier at app startup). |
| `AclJsonLayout` | JSON-driven layout entry-point name dropped; JSON feeds directly into the shipped `AclBuilder` (see §13.7, retained in A.1). |