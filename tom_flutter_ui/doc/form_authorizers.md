# Form authorizers

How `TomAuthorizer` actually works on form fields and Tom* widgets, and
how to write authorizers that depend on *other* field values (e.g.
"disable email until phone is filled in").

---

## TL;DR

`TomAuthorizer.fromAction` takes a **nullary** closure:

```dart
factory TomAuthorizer.fromAction({
  required TomAuthState Function() actionAuth,
});
```

It does **not** accept a `(Object data) => ...` signature. Any sample
code you see passing a `data` parameter is either stale, aspirational,
or mixed up with the separate `TomUIStateController.apply({Object? data})`
API (which today is also not used by callers). Nothing in the current
pipeline hands the authorizer a data object — the only input the
authorizer ever receives is the widget's own resource-auth result.

---

## The real `TomAuthorizer` API

See [tom_core_kernel/lib/src/tombase/security/tom_authorization.dart:352](../../tom_core_kernel/lib/src/tombase/security/tom_authorization.dart#L352).

```dart
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

  factory TomAuthorizer.fixed(TomAuthState state) => ...;
  factory TomAuthorizer.fromAction({
    required TomAuthState Function() actionAuth,
  }) => ...;
}
```

### Evaluation pipeline

Every Tom widget routes its auth through
[tom_policy_node_base.dart:39](../lib/src/widget_base/tom_policy_node_base.dart#L39):

```dart
TomAuthState resolveEffectiveAuth() {
  var state = basePath != null
      ? TomAuthorization.resolveAuth(basePath!)   // 1. resource auth
      : TomAuthState.full;
  if (authorizer != null) {
    state = authorizer!.effectiveAuth(state);      // 2. this widget's authorizer
  }
  if (uiStateController != null) {
    state = uiStateController!.apply(state);       // 3. build-time narrowing
  }
  if (tomGroup != null) {
    state = tomGroup!.applyMode(state);            // 4. group override
  }
  return state;
}
```

There is no hook where a `data` object is threaded through. Anything
your authorizer needs beyond `resourceAuth` must be captured by the
closure itself (via `this`, a field reference, a controller, etc.).

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
authorizer: TomAuthorizer(
  strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
  resolve: (resourceAuth) => resourceAuth == TomAuthState.full
      ? TomAuthState.read
      : resourceAuth,
),
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
[demo_a_lifecycle.dart:243](../../tom_flutter_form_test/lib/demos/demo_a_lifecycle.dart#L243).

### Why not just listen on `state` as one object?

If the authorizer reads **one specific field**, listing just that field
is cheaper than rebuilding on every state mutation. If it reads many,
list them explicitly or fall back to a form-level `ListenableBuilder`
on `form.changes`. The builder dedupes: listing the same observable in
both the fields list and indirectly via `form.changes` only triggers
one rebuild per frame.

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
