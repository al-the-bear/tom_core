# Tom Flutter UI — User Guide

*Part of the [Tom Flutter UI documentation set](README.md).*

**Date:** 2026-04-07
**Package:** tom_flutter_ui
**Prerequisites:** Familiarity with Flutter widget development and basic Dart

---

## 1. Overview

The Tom Flutter UI framework wraps Flutter's widget set with:

- **Four-state authorization** — widgets can be hidden, disabled, readonly, or fully interactive based on user permissions
- **Resource resolution** — text, icons, and configuration are loaded by path instead of hardcoded
- **Scope-based identity** — every widget gets a canonical path from its position in the scope hierarchy
- **Forms** — validated, observable form fields with typed values and coordinated save/discard
- **Actions** — named, authorized, stateless business logic units with undo support

This guide shows how to use these features in practice.

---

## 2. Quick Start — Your First Tom Widget

### Basic widget with authorization

```dart
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// A button that can be authorized and has resource-resolved text
TomElevatedButton(
  tomId: 'submitOrder',
  onPressed: () => submitOrder(),
  child: Text('Submit'),  // or omit — resolved from resources
)
```

The `tomId` identifies the widget for authorization and resource lookup. If you set up authorization, this button can be hidden, disabled, or read-only based on the user's permissions.

### Widget in a scope

```dart
TomScope.withScope('checkout', () {
  return Column(children: [
    TomTextField(
      tomId: 'email',
      // basePath resolves to: checkout.email
    ),
    TomElevatedButton(
      tomId: 'submit',
      // basePath resolves to: checkout.submit
    ),
  ]);
});
```

Scopes nest. A widget's `basePath` is built from the scope chain + its `tomId`.

---

## 3. Authorization

### The four states

| State | Effect | Widget Behavior |
|-------|--------|-----------------|
| `full` | Fully interactive | Normal rendering |
| `read` | Read-only | Visible, not editable (styled via `TomStateStyle`) |
| `disabled` | Visible but inaccessible | Greyed out, no content, pointer events absorbed |
| `none` | Hidden | `SizedBox.shrink()` — as if the widget doesn't exist |

### Setting up the global adapter

At app startup, set the authorization adapter:

```dart
void main() {
  // Set global authorization
  TomAuthorization.adapter = MyAuthorizationAdapter();

  runApp(MyApp());
}

class MyAuthorizationAdapter extends TomAuthorizationAdapter {
  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    // Your authorization logic here
    // resourceKeyPath is something like 'checkout.email' or 'admin.salary'
    return TomAuthState.full;  // default: full access
  }
}
```

### Per-widget modifiers

Widgets have three optional authorization controls:

```dart
TomTextField(
  tomId: 'salary',

  // Per-widget authorizer — modifies the global auth result
  authorizer: TomAuthorizer.fixed(TomAuthState.read),

  // Strategy — can the authorizer widen or only narrow?
  authorizerStrategy: TomAuthorizerStrategy.authorizerNarrowsOnly,

  // UI state controller — build-time narrowing for business rules
  uiStateController: TomUIStateController(
    apply: (currentAuth) {
      // Example: disable when list is empty
      return employeeList.isEmpty
          ? currentAuth.narrow(TomAuthState.disabled)
          : currentAuth;
    },
  ),
)
```

Resolution order: `TomAuthorization.resolveAuth(path)` → `authorizer.effectiveAuth()` → `uiStateController.apply()`

### Groups

Group widgets together for collective authorization:

```dart
final shippingGroup = TomAuthorizationGroup('shippingPanel');

Column(children: [
  TomTextField(tomId: 'street', authorizationGroup: shippingGroup),
  TomTextField(tomId: 'city', authorizationGroup: shippingGroup),
  TomTextField(tomId: 'zip', authorizationGroup: shippingGroup),
])
```

When the group is hidden by authorization, all members are hidden.

---

## 4. Resources

### Setting up the resource adapter

```dart
TomUIResources.adapter = MyResourceAdapter();

class MyResourceAdapter extends TomUIResourceAdapter {
  @override
  String resolveText(String basePath, String suffix) {
    // basePath: 'checkout.email'
    // suffix: 'label', 'hint', 'error.required', etc.
    return lookupFromResourceFile('$basePath.$suffix');
  }

  @override
  bool resourceExists(String basePath, String suffix) {
    return hasResource('$basePath.$suffix');
  }
}
```

### Using resources in widgets

Tom widgets resolve resources automatically via their `basePath`:

```dart
// In a widget's buildContent() method:
final label = resolveResource('label');      // looks up: {basePath}.label
final hint = resolveResourceOrNull('hint');  // looks up: {basePath}.hint
final icon = resolveIcon('icon');            // looks up: {basePath}.icon
```

Resource file entries:
```yaml
checkout.email.label: "Email Address"
checkout.email.hint: "your@email.com"
checkout.email.error.required: "Email is required"
checkout.submit.label: "Place Order"
checkout.submit.tooltip: "Submit your order for processing"
```

---

## 5. Widget Patterns

### Composition pattern (default — most widgets)

Extend a family base class and implement `buildContent()`:

```dart
class TomElevatedButton extends TomButtonBase {
  final VoidCallback? onPressed;
  final Widget? child;

  const TomElevatedButton({
    super.key,
    super.tomId,
    super.authorizationGroup,
    this.onPressed,
    this.child,
  });

  @override
  Widget buildContent(BuildContext context) {
    final label = child ?? Text(resolveResource('label'));
    return ElevatedButton(onPressed: onPressed, child: label);
  }
}
```

The base class handles authorization checks and readonly styling. You only implement the content.

### Extension pattern (type-constrained widgets)

When Flutter requires a specific type (e.g., `TabBar` checks `tab is Tab`):

```dart
class TomTab extends Tab with TomWidgetMixin {
  @override
  final String tomId;

  TomTab({required this.tomId, super.text, super.icon, super.key});

  @override
  Widget build(BuildContext context) {
    final hidden = checkHidden();
    if (hidden != null) return hidden;
    return applyAuthState(context, super.build(context));
  }
}
```

### Family base classes

| Base Class | Family | Use For |
|------------|--------|---------|
| `TomButtonBase` | Buttons | ElevatedButton, TextButton, IconButton, ... |
| `TomInputBase` | Text inputs | TextField, TextFormField, ... |
| `TomSelectBase` | Selection | DropdownButton, PopupMenuButton, ... |
| `TomToggleBase` | Toggles | Switch, Checkbox, Radio, ... |
| `TomSliderBase` | Sliders | Slider, RangeSlider, ... |
| `TomContainerBase` | Containers | Card, ExpansionTile, ... |
| `TomDialogBase` | Dialogs | AlertDialog, BottomSheet, ... |
| `TomTableBase` | Tables | DataTable, Table, ... |
| `TomLabelBase` | Labels | Text, Badge, ... |
| `TomImageBase` | Images | Icon, Image, CircleAvatar, ... |
| `TomNavigationBase` | Navigation | NavigationBar, TabBar, ... |
| `TomListBase` | Lists | ListView, AnimatedList, ... |
| `TomProgressBase` | Progress | CircularProgressIndicator, ... |
| `TomChipBase` | Chips | FilterChip, ActionChip, ... |
| `TomTreeBase` | Trees | TreeView |
| `TomSliverBase` | Slivers | SliverList, SliverGrid, ... |
| `TomAnimatedBase` | Animated | AnimatedContainer, Hero, ... |
| `TomEffectBase` | Effects | BackdropFilter, ShaderMask, ... |
| `TomInteractionBase` | Interactions | GestureDetector, InkWell, ... |
| `TomBuilderBase` | Builders | FutureBuilder, StreamBuilder, ... |

---

## 6. Forms

### Defining a form

A form is a `TomForm<T>` subclass whose target `T` is the `TomClass` it edits. Declare each field as a `late final` member and instantiate it in `createFormElements()`, passing `form: this` so the field registers with the form. Field member names match the target's members, so the reflection round-trip binds and saves straight back into the bound object.

```dart
@tomReflector
class AddressForm extends TomForm<Address> {
  AddressForm() : super(formId: 'addressForm');

  late final TomFormStringInput street;
  late final TomFormStringInput city;
  late final TomFormStringInput zip;
  late final TomFormStringInput email;

  @override
  void createFormElements() {
    street = TomFormStringInput('street', '', form: this,
        validators: [Validators.required()]);
    city = TomFormStringInput('city', '', form: this);
    zip = TomFormStringInput('zip', '', form: this);
    email = TomFormStringInput('email', '', form: this,
        validators: [Validators.required(), Validators.email()]);
  }
}
```

There is a typed field for every value kind — `TomFormIntInput`, `TomFormDoubleInput`, `TomFormDateTextInput`, `TomFormStringDropdown`, their nullable `TomFormN*` variants, and so on. A password field is simply a `TomFormStringInput` with `obscureText: true`.

### Using a form

```dart
final form = AddressForm();

// Bind to the instance being edited — snapshots initial values
form.bind(appState.address);

// Query state as the user edits
form.isDirty;  // true if any field changed from its bound value
form.isValid;  // true only once validation has RUN and passed — a freshly
               // bound form is pristine, so this is false even when the data
               // is fine. Gate a Save button on isDirty, not on this.

// Validate and write the edited values back into the bound Address.
// save() validates first, so it is safe on a never-validated form.
if (await form.save()) {
  // all fields valid; appState.address now holds the edited values
}

// Discard
form.discard();  // resets all fields to their bound/initial values
```

### Rendering a form

Each field exposes a ready-to-place widget via its `.widget` getter — drop them straight into any layout:

```dart
Column(
  children: [
    form.street.widget,
    form.city.widget,
    form.zip.widget,
    form.email.widget,
  ],
)
```

### Form field resource suffixes

Each form field resolves resources using its `basePath` + standard suffixes:

| Suffix | Purpose |
|--------|---------|
| `label` | Field label text |
| `hint` | Placeholder/hint text |
| `description` | Helper description below field |
| `error.required` | Required validation error |
| `error.format` | Format validation error |
| `info.title` | Info popup title |
| `help.title` | Help popup title |

### Form identity and scoping

Forms are scope providers. Fields inside a form get paths like:

```
checkout.addressForm.street
checkout.addressForm.email
```

Where `checkout` is the outer scope and `addressForm` is the form's scope.

---

## 7. Actions

### Defining an action

```dart
class DeleteOrderAction extends TomAction<OrderActionContext, Order> {
  @override
  String get actionId => 'delete';

  @override
  bool canExecute(OrderActionContext context) {
    return context.selectedOrder != null;
  }

  @override
  Order? execute(OrderActionContext context, TomActionTransaction tx) {
    final order = context.selectedOrder;
    context.orderRepo.delete(order.id);
    return order;  // returned for undo
  }

  @override
  bool get isUndoable => true;

  @override
  void undo(Order undoState) {
    // Restore the deleted order
  }
}
```

### Action controllers

Group related actions in a controller:

```dart
class OrderController extends TomActionController {
  @override
  final String controllerId = 'orderMgmt';

  final create = CreateOrderAction();
  final delete = DeleteOrderAction();

  OrderController() {
    registerAction(create);
    registerAction(delete);
  }
}
```

Action paths use plain IDs (same as widgets):
```
orderMgmt.delete
orderMgmt.create
```

### Triggering actions

```dart
TomElevatedButton(
  tomId: 'deleteBtn',
  onPressed: () {
    final tx = TomActionTransaction();
    orderController.delete.execute(
      OrderActionContext(selectedOrder: selected),
      tx,
    );
  },
)
```

---

## 8. Theming

Tom uses Flutter's native `ThemeData` for all styling. The only Tom-specific addition is `TomStateStyle` for authorization-readonly widgets.

### Setup

```dart
TomThemeScope(
  theme: TomTheme(
    readonlyStyle: TomStateStyle(opacity: 0.5),
  ),
  child: MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: MyApp(),
  ),
)
```

### Style variants for buttons

```dart
final variants = TomButtonVariants.of(context);

TomElevatedButton(
  tomId: 'save',
  style: variants.primary,     // Primary action style
  onPressed: () => save(),
)

TomElevatedButton(
  tomId: 'delete',
  style: variants.destructive, // Destructive action style
  onPressed: () => delete(),
)
```

Available variants: `primary`, `secondary`, `auxiliary`, `destructive`.

---

## 9. ID System — Paths and Scopes

### How paths are built

Paths are built at construction time from the scope hierarchy:

```
<scope1>.<scope2>.<formId>.<widgetId>
```

**Only scope providers contribute to paths.** Layout wrappers (Column, Row, etc.) do NOT affect paths, even if they have a `tomId`.

### Scope providers

| Provider | Effect |
|----------|--------|
| `TomScope.withScope('id', () {...})` | Zone-based scope |
| `TomScreenElementsProvider` | Element provider scope |
| `TomForm` | Form scope |
| Widget `scope:` parameter | Explicit scope override |

### All paths use plain IDs

Widget and scope paths use **plain IDs**: `checkout.shipping.street`

Action paths also use **plain IDs**: `orderMgmt.delete`

---

## 10. Screen Definitions

### Element provider

```dart
@tomReflect
class LoginScreenElements extends TomScreenElementsProviderBase {
  LoginScreenElements() : super('login');

  late final greeting = TomText(tomId: 'greeting');
  late final loginForm = LoginForm();
  late final loginButton = TomElevatedButton(tomId: 'loginBtn');
  late final cancelButton = TomElevatedButton(tomId: 'cancelBtn');
}
```

### Layout with AclProviderBuilder

```dart
Widget buildLoginScreen() {
  return AclProviderBuilder<LoginScreenElements>(
    id: 'loginScreen',
    elementProvider: LoginScreenElements(),
  )
    .append((p) => p.greeting)
    .newRow(dist: 24)
    .appendForm((p) => p.loginForm)
    .newRow(dist: 16)
    .append((p) => p.cancelButton)
    .append((p) => p.loginButton)
    .build();
}
```

---

## 11. App Initialization Checklist

```dart
void main() {
  // 1. Set global authorization adapter
  TomAuthorization.adapter = MyAuthAdapter();

  // 2. Set global resource adapter
  TomUIResources.adapter = MyResourceAdapter();

  // 3. Run app with TomThemeScope
  runApp(
    TomThemeScope(
      theme: TomTheme(readonlyStyle: TomStateStyle(opacity: 0.5)),
      child: MaterialApp(
        theme: myThemeData,
        home: MyApp(),
      ),
    ),
  );
}
```

---

## Further Reading

| Document | What It Covers |
|----------|---------------|
| [tom_ui_design_architecture.md](tom_ui_design_architecture.md) | Full architecture reference (all 14 sections) |
| [tom_ui_widgets_forms.md](tom_ui_widgets_forms.md) | Complete forms framework specification |
| [acl_design_specification.md](acl_design_specification.md) | ACL layout engine specification |
| [tom_observable_state_management.md](tom_observable_state_management.md) | Observable state management patterns |
| [tom_ui_flutter_widgets.md](tom_ui_flutter_widgets.md) | Flutter widget inventory with wrap decisions |
