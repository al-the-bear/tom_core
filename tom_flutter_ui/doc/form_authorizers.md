# Form authorizers

How `TomAuthorizer` actually works on form fields and Tom* widgets, and
how to write authorizers that depend on *other* field values (e.g.
"disable email until phone is filled in").

---

## TL;DR

`TomAuthorizer.fromAction` takes a **nullary** closure:

```dart
// factory TomAuthorizer.fromAction({required TomAuthState Function() actionAuth})
final authorizer = TomAuthorizer.fromAction(actionAuth: () => action.authState);
```

It does **not** accept a `(Object data) => ...` signature. Any sample
code you see passing a `data` parameter is either stale, aspirational,
or mixed up with the separate `TomUIStateController.apply({Object? data})`
API (which today is also not used by callers). Nothing in the current
pipeline hands the authorizer a data object — the only input the
authorizer ever receives is the widget's own resource-auth result.

---

## The real `TomAuthorizer` API

See [`TomAuthorizer`](../../tom_core_kernel/lib/src/tombase/security/tom_authorization.dart)
in `tom_core_kernel`.

```dart quote
class TomAuthorizer {
  final TomAuthorizerStrategy strategy;
  final TomAuthState Function(TomAuthState resourceAuth) resolve;

  const TomAuthorizer({
    this.strategy = TomAuthorizerStrategy.authorizerNarrowsOnly,
    required this.resolve,
  });

  TomAuthState effectiveAuth(TomAuthState resourceAuth) {
    final r = resolve(resourceAuth);
    switch (strategy) {
      case TomAuthorizerStrategy.authorizerDecides: return r;
      case TomAuthorizerStrategy.authorizerNarrowsOnly:
        return resourceAuth.narrow(r);
    }
  }

  factory TomAuthorizer.fixed(TomAuthState state) { ... }
  factory TomAuthorizer.fromAction({
    required TomAuthState Function() actionAuth,
  }) { ... }
}
```

### Evaluation pipeline

Every Tom widget routes its auth through
[`TomPolicyNodeBase.resolveEffectiveAuth`](../lib/src/widget_base/tom_policy_node_base.dart):

```dart quote
abstract class TomPolicyNodeBase extends TomNodeBase {
  // TomAuthLayers.resolve applies, in order: 1. resource auth at basePath;
  // 2. the group, in the frame basePath was built from; 3. this widget's
  // authorizer; 4. build-time narrowing by the UI state controller.
  TomAuthState resolveEffectiveAuth() => TomAuthLayers.resolve(
        basePath: basePath,
        group: tomGroup,
        groupScope: constructionScope,
        authorizer: authorizer,
        uiStateController: uiStateController,
      );
}
```

The authorizer runs third, after the group has established the ceiling but
before the controller narrows it — so `resourceAuth` as the authorizer sees it
already carries any group override. The controller is deliberately last;
[the two-lanes section](#authorizer-vs-tomuistatecontroller--two-lanes-two-timings)
explains why moving it would break its "can only narrow" guarantee.

The authorizer gets no hook through which a `data` object is threaded — that
parameter exists only on the controller's `resolve`. Anything your authorizer
needs beyond `resourceAuth` must be captured by the closure itself (via
`this`, a field reference, a controller, etc.).

---

## Two things authorizers are *for*

### 1. Binding a button to a `TomAction`

This is what the `fromAction` factory exists for. `TomAction.authorizer`
already wraps it:

```dart
// tom_action.dart
TomAuthorizer get authorizer => TomAuthorizer.fromAction(
      actionAuth: () => authState,
    );
```

So the canonical Save button is:

```dart
TomElevatedButton(
  tomId: 'saveBtn',
  authorizer: form.saveAction.authorizer,
  onPressed: form.saveAction.trigger,
  label: form.saveAction.label,
)
```

The button stays `full` when the action is executable, goes
`disabled` (visible but greyed) when the resource says `full` but the
action says `none`, and hides entirely when the resource itself says
`none`. All of that logic lives inside `fromAction` — you don't write it.

### 2. Narrowing a field based on its own resource (role-driven `read`)

```dart
final authorizer = TomAuthorizer(
  strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
  resolve: (resourceAuth) => resourceAuth == TomAuthState.full
      ? TomAuthState.read
      : resourceAuth,
);
```

This is declarative and stateless — the closure has no sibling
dependencies, so there's nothing to rebuild on. It runs during the
widget's normal build.

---

## The hard case: "disable email when phone is empty"

This is **not** what `fromAction` is for. `fromAction` calls a closure
that takes no arguments and returns a `TomAuthState`. You can cram a
sibling read into that closure, but you still have to solve the real
problem — the widget has to *rebuild* so the closure gets called again
when the sibling changes.

### Step 1 — the authorizer itself

Capture the form so you can read `phone`:

```dart
class CheckoutForm extends TomForm<TomClass> {
  CheckoutForm() : super(formId: 'checkout');

  late final phone = TomFormStringInput('phone', '', form: this);

  late final email = TomFormStringInput(
    'email', '',
    form: this,
    authorizer: TomAuthorizer(
      strategy: TomAuthorizerStrategy.authorizerDecides,
      resolve: (resourceAuth) {
        if (resourceAuth == TomAuthState.none) return TomAuthState.none;
        return phone.get().trim().isEmpty
            ? TomAuthState.disabled
            : resourceAuth;
      },
    ),
  );
}
```

That closure will give the *right* answer whenever it runs. The missing
piece is making it run when `phone` changes — the email field rebuilds
on changes to **its own** value, not on its sibling's.

### Step 2 — rebuild the form on any observable it depends on

Tom ships a first-class widget for this:
[tom_multi_observable_builder.dart](../lib/src/forms/widgets/tom_multi_observable_builder.dart).

`TomMultiObservableBuilder(observables: [...])` registers/deregisters
listeners on a list of `TomObservable` and calls `builder` on every
change. `TomField<T>` extends `TomObject<T>` extends `TomObservable`,
so every form field can be dropped directly into the list.

Wrap the part of the tree that contains the email widget — the whole
ACL layout is usually the right granularity:

```dart
@override
Widget build(BuildContext context) {
  return TomMultiObservableBuilder(
    observables: [form.phone],   // re-run the authorizer when phone changes
    builder: (context) => TomAclBuilder(
      id: 'checkoutAcl',
      elementProvider: form,
    )
        .append((f) => f.phone.widget)
        .newRow()
        .append((f) => f.email.widget)
        .build(context),
  );
}
```

Now: user types into phone → `phone` notifies its observers →
`TomMultiObservableBuilder` rebuilds its subtree → the email widget is
rebuilt → its authorizer's `resolve` runs again → `phone.get()` returns
the new value → email flips between `disabled` and `full`.

### Wrapping "the state AND the form itself"

The principle generalises. The observables list can hold any mix of:

- **individual fields** — `form.phone`, `state.phone` — rebuild when a
  specific value changes;
- **the form's bound state** — include the whole `TomClass` subtree
  you care about when the decision reads "many" of its fields;
- **composed observables** — e.g. a derived `TomObservable` that fans
  in several fields.

For form-wide rebuilds there is a second, orthogonal handle:
`TomForm.changes` is a plain `Listenable`, so you can nest the two:

```dart
return ListenableBuilder(
  listenable: form.changes,                  // structural / dirty / valid
  builder: (context, _) => TomMultiObservableBuilder(
    observables: [form.phone, state.phone],  // values the authorizer reads
    builder: (context) => _buildAcl(context),
  ),
);
```

That's exactly the pattern demo_a_lifecycle.dart uses — see
[`_buildActionRow`](../../tom_core_samples/tom_flutter_form_test/lib/demos/demo_a_lifecycle.dart).

### Why not just listen on `state` as one object?

If the authorizer reads **one specific field**, listing just that field
is cheaper than rebuilding on every state mutation. If it reads many,
list them explicitly or fall back to a form-level `ListenableBuilder`
on `form.changes`. The builder dedupes: listing the same observable in
both the fields list and indirectly via `form.changes` only triggers
one rebuild per frame.

---

## Authorizer vs `TomUIStateController` — two lanes, two timings

Everything above treats the authorizer as if it were the only hook. It
isn't. The auth pipeline in
[`TomPolicyNodeBase.resolveEffectiveAuth`](../lib/src/widget_base/tom_policy_node_base.dart)
runs **both** an authorizer *and* a `TomUIStateController`, in that order,
and the controller runs **last of all**:

```text
resourceAuth
  → tomGroup.applyMode()
  → authorizer.effectiveAuth()
  → uiStateController.apply()
```

The group comes second, not last, and that is load-bearing rather than
arbitrary: `applyMode` *widens* under `controlsNarrowest` and replaces the
state outright under `controlsAll`, so a group applied after the controller
would undo the narrowing the controller had just performed and the "can only
narrow" promise would not hold. Fields insert a fifth layer — the enclosing
form, which always narrows — between the group and the authorizer; see
[`TomField.resolveEffectiveAuth`](../lib/src/forms/tom_form.dart).

They look similar but have different jobs:

| Aspect         | `TomAuthorizer`                                | `TomUIStateController`                               |
| -------------- | ---------------------------------------------- | ---------------------------------------------------- |
| Lifetime       | Construction-time — `final` reference          | Build-time — closure runs every resolve              |
| Typical source | Role / resource / action authorization         | UI business rules (dirty? empty? row-owned?)         |
| Can widen?     | Yes with `authorizerDecides` strategy          | No — always narrows via `currentAuth.narrow(result)` |
| Mutable owner  | Fields: `form.email.authorizer = ...`          | Fields: `form.email.uiStateController = ...`         |
| Receives       | `(TomAuthState resourceAuth)`                  | `(TomAuthState currentAuth, Object? data)`           |

**Rule of thumb**: if the rule is about *whether this user is allowed to
do this thing at all*, it's an authorizer. If the rule is about
*whether the current UI state allows this action right now*, it's a
`TomUIStateController`. "Disable save while the form is clean" is a
textbook `TomUIStateController` — nothing about it is authorization.

### Minimal controller recap

[`TomUIStateController`](../../tom_core_kernel/lib/src/tombase/security/tom_authorization.dart),
in `tom_core_kernel`:

```dart
class TomUIStateController {
  final TomAuthState Function(TomAuthState currentAuth, Object? data) resolve;
  const TomUIStateController({required this.resolve});

  TomAuthState apply(TomAuthState currentAuth, {Object? data}) {
    final result = resolve(currentAuth, data);
    return currentAuth.narrow(result);   // ← never widens
  }
}
```

---

## The dual-use button: action authorizer + dirty-gate

The intended shape of a Save button with both lanes wired up:

```dart
TomElevatedButton(
  tomId: 'saveBtn',
  // Lane 1 — authorization: "is this user allowed to save at all?"
  authorizer: form.saveAction.authorizer,   // == TomAuthorizer.fromAction(
                                            //       actionAuth: () => action.authState)

  // Lane 2 — UI state: "is the form in a state where save makes sense?"
  uiStateController: TomUIStateController(
    resolve: (currentAuth, _) {
      if (currentAuth == TomAuthState.none) return currentAuth; // stay hidden
      if (!form.isDirty)  return TomAuthState.disabled;         // nothing to save
      return currentAuth;                                       // pass through
    },
  ),

  onPressed: form.saveAction.trigger,
  label: form.saveAction.label,
)
```

Read top-to-bottom: resource says `full` → action authorizer confirms
the user has save permission (still `full`) → controller checks the
form and narrows to `disabled` because nothing has changed yet →
button paints greyed. Flip a field and the same path returns `full`,
so the button lights up.

**Lane 2 gates on `isDirty`, not on `isValid`, and that is deliberate.**
`isValid` means "validation has run and passed": every field starts
`TomValidationPristine`, pristine is not success, and editing a field clears
only *that* field's state. A button also gated on `isValid` would therefore
stay disabled until the user had touched every field in the form — and go
dark again the moment they saved, because `commit()` returns the fields to
pristine. Let `save()` reject bad data instead: it runs a full `validate()`
before writing and returns `false`, so nothing is lost by letting the user
press the button. See `doc/forms.md` § "Data model".

Because `uiStateController` only narrows, the authorizer stays
authoritative for the "hide the button entirely" direction — even if
the controller wanted to widen `disabled` back up to `full`, the
`narrow()` in `apply()` would prevent it. This is what lets you compose
them safely without worrying about the controller quietly granting
access it shouldn't.

### Rebuilding on form state

`isDirty` and `isValid` don't push a notification on their own — they
flip as a side effect of field edits and validation passes, surfaced
through `form.changes` (a plain `Listenable`). Same rebuild story as
for cross-field authorizers, just at form granularity:

```dart
ListenableBuilder(
  listenable: form.changes,
  builder: (_, __) => _buildAclContainingTheSaveButton(),
)
```

If the button also depends on a specific field value, combine with
`TomMultiObservableBuilder` as shown earlier. The host widget rebuilds
→ the button rebuilds → its `uiStateController.resolve` re-reads
`form.isDirty` → state flips.

### Implementation note — button constructors

The pattern above is the documented API (see the docstring on
[TomActionTrigger](../lib/src/actions/tom_action_trigger.dart#L18)
and on `TomAuthorizer` itself). At time of writing, the concrete button
subclasses in [tom_buttons.dart](../lib/src/widgets/buttons/tom_buttons.dart)
do not yet expose `authorizer` / `authorizerStrategy` / `uiStateController`
through their own `super:` forwarding — `TomButtonBase` declares them,
but `TomElevatedButton(...)`, `TomTextButton(...)`, etc. list only
`tomId`, `tomGroup`, `scope` for forwarding. Until that one-line change
is added per subclass, prefer the form-field route below for the
reactive lane; the `authorizer` lane on a button is fine to wire once
the forwarding is in place.

---

## Form-field dual-use (works today)

The form-field side of the pipeline *already* supports both lanes —
fields are long-lived `TomObservable` objects, so both `authorizer` and
`uiStateController` can be set (and reassigned) directly on the field:

```dart
// demo_b_authorization.dart — real code in the repo
form.email.uiStateController = TomUIStateController(
  resolve: (currentAuth, _) {
    if (form.phone.get().trim().isEmpty) return TomAuthState.disabled;
    return currentAuth;
  },
);
```

See [`_applyUIStateController`](../../tom_core_samples/tom_flutter_form_test/lib/demos/demo_b_authorization.dart).
Combine it with an authorizer on the same field — for example a role-
based `authorizerNarrowsOnly` narrowing to `read` for non-admins — and
you get the same two-lane composition the Save button above describes.

Wrap the ACL (or whichever widget hosts the email field) in
`TomMultiObservableBuilder(observables: [form.phone])` so the rebuild
fires when phone changes. That's the missing third of the story: a
`uiStateController` is only as reactive as whatever rebuilds its host.

---

## What to avoid

- **Don't** reach for `Flutter`'s `ValueListenableBuilder` here. `TomField`
  is a `TomObservable`, not a `ValueListenable`, and wrapping one adds
  lifecycle that `TomMultiObservableBuilder` already handles (clean
  register/deregister, identity-based list diffing on widget update).
- **Don't** try to pass sibling values into the authorizer via a `data`
  parameter — there is no such parameter on `TomAuthorizer.resolve`
  today, and `TomUIStateController.apply(..., data:)` is not called
  with a data value at any call site.
- **Don't** mutate a captured `TomAuthorizer` at runtime. The widget
  caches the reference; rebuild-driven re-evaluation is the only
  mechanism that changes the returned state.

---

## Checklist for cross-field authorizers

1. Write the closure: capture the form/state and return the right
   `TomAuthState` for each branch. Remember that `resourceAuth` can
   already be `none`/`read`/`disabled` — decide whether your rule
   *narrows* (`authorizerNarrowsOnly`) or *overrides*
   (`authorizerDecides`).
2. Identify which observables the closure reads.
3. Wrap the hosting widget (typically the ACL layout, sometimes the
   whole form card) in `TomMultiObservableBuilder(observables: [...])`
   listing exactly those observables. Add `ListenableBuilder(listenable:
   form.changes, ...)` around it if the decision also depends on
   form-level state (`isDirty`, `isValid`, structural edits).
4. Verify by changing a dependency: the affected fields must flip
   between `full`/`read`/`disabled`/`none` without the user touching
   the dependent field itself.
