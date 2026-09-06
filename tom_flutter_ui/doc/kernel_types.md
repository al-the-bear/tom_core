# Kernel-Types Bridge

`lib/src/kernel_types.dart` is the **only** route by which a
`tom_core_kernel` type reaches a consumer of `tom_flutter_ui`. The package
barrel exports the nine module barrels and this one file; it does **not**
re-export the kernel wholesale.

That matters because the kernel types are not incidental to the UI surface —
they *are* the UI surface in places. `scope:` is a parameter on every Tom
widget and its type is the kernel's `TomScope`; `TomField` extends the kernel's
`TomObject`; `TomFormFileField.transferClient` takes a
`TomFileTransferClient`. A consumer who imports only
`package:tom_flutter_ui/tom_flutter_ui.dart` can read those types in a
signature, and unless they appear in the `show` list below, cannot name them.

## Table of Contents

- [What belongs in the list](#what-belongs-in-the-list)
- [The list](#the-list)
- [Why a list and not a blanket re-export](#why-a-list-and-not-a-blanket-re-export)
- [How the two directions are guarded](#how-the-two-directions-are-guarded)
- [Dependencies](#dependencies)

---

## What belongs in the list

Two rules decide membership.

1. **Declaration positions.** A kernel type used in a public `extends`,
   `implements`, `with` clause or type-parameter bound, or as the type of a
   public field, parameter, or return value anywhere under `lib/`.
2. **What makes those types usable.** The concrete class the kernel ships for a
   rule-1 abstract type, and the types a rule-1 type's own public members name.
   `TomScope` is abstract with no public constructor, so without `TomScopeBase`
   a consumer cannot build the very `scope:` argument rule 1 exposes;
   `TomObservable.addObserver` takes a `TomObserver`, and `TomFunctionObserver`
   is the only one the kernel ships.

The line stops there. Rule 2 is *one* step, not a transitive closure —
following it transitively would end at the whole kernel. An application wiring
the kernel's HTTP stack (a `TomHttpFileTransferClient` and its channel, say) is
doing kernel work rather than UI work, and imports
`package:tom_core_kernel/tom_core_kernel.dart` for it.

## The list

Twenty-seven names, in four groups.

| Group | Names | Why |
| ----- | ----- | --- |
| Authorization | `TomAuthState`, `TomAuthorizable`, `TomAuthorizationGroup`, `AuthGroupMode`, `TomAuthorizationAdapter`, `TomAuthorization`, `TomAuthorizer`, `TomAuthorizerStrategy`, `TomUIStateController` | The four-state model every Tom widget resolves against, plus the adapter, groups and controllers that feed it. Every Tom widget implements `TomAuthorizable`; `tomGroup:`, `authorizer:` and `uiStateController:` are constructor parameters. |
| Scopes | `TomScope`, `TomScopeBase`, `TomScopeMixin` | `scope:` is a parameter on every Tom widget, `TomScreenElementsProviderBase` mixes `TomScopeMixin` in, and `TomScopeBase` is the only concrete `TomScope` there is. |
| Observables | `TomObservable`, `TomObservableObservation`, `TomObserver`, `TomFunctionObserver`, `TomObject`, `TomClass`, `TomList`, `TomListLifecycleListener`, `TomObservableEnum` | `TomField` extends `TomObject`, `TomListForm` extends `TomObservable` and implements `TomListLifecycleListener`, the list forms bind a `TomList` of a `TomClass`, and observing any of them takes a `TomObserver`. `TomObservableObservation` is the extension declaring `>>`, the kernel's documented way to register an observer and get back the `TomFunctionObserver` you must retain; an extension reaches a consumer only if its own name is shown, so exporting that return type without the operator leaves `field >> (_) => …` undefined on a `TomField`. |
| File transfer | `TomFileTransferClient`, `TomFileSource`, `TomFileMetadata`, `TomTransferProgress`, `TomTransferCancellation`, `TomFileTransferException` | `TomFormFileField.transferClient` takes a client, `FileRef` is built from and converts to the client's types, and the client's own methods name the progress, cancellation and error types. |

With the bridge in place, the DONE condition reads as ordinary consumer code:

```dart
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Widget buildTitle() {
  final TomScope scope = TomScopeBase(scopeId: 'settings');
  return TomText(tomId: 'title', scope: scope, text: 'Settings');
}
```

The export names the kernel's **public barrel**,
`package:tom_core_kernel/tom_core_kernel.dart`, not the `lib/src/` paths that
declare the types. The barrel exports those files unfiltered, so the two are
equivalent today — but `lib/src/` is private by Dart convention, and naming it
would turn any reorganisation inside the kernel into a compile error here even
when the kernel's public surface never moved.

## Why a list and not a blanket re-export

Nothing here is published, so a wider surface would cost nothing in
compatibility terms. The reason is scope: the two packages answer different
questions, and an application doing kernel work should import the kernel and
say so. A blanket re-export would put the whole kernel behind a UI import,
which is the transitive end-point the previous section declines to walk to.

For a while the reason was blunter — a blanket re-export did not *compile*.
The kernel barrel re-exports `tom_basics` in full, which declares a
`TomEnvironment` and a `TomPlatform`, and `tom_flutter_ui` declared enums of
exactly those two names. Both spellings reached one import and every use of
either was an `ambiguous_import` error — including for a consumer following
this document's own advice to import the kernel directly for anything off the
list.

That is fixed at the source rather than worked around: the enums are now
`TomConfigEnvironment` and `TomConfigPlatform`, named for the
`TomConfigProvider` whose two fields they are. `tom_basics` keeps the plain
names — it is published, and its pair describe the runtime the process
executes in, which is the broader claim on the words. Importing both barrels
into one library is legal today, and
[`test/kernel_types_coexist_test.dart`](../test/kernel_types_coexist_test.dart)
fails to compile if that ever stops being true.

## How the two directions are guarded

A `show` list can fail in two directions, and each has its own guard.

| Direction | Guard | What it catches |
| --------- | ----- | --------------- |
| A kernel type reaches a public signature without reaching the bridge | [`tool/check_kernel_bridge.py`](../../tool/check_kernel_bridge.py) | Exactly the `TomScope` gap. It collects the kernel's public top-level type names, scans every declaration position under `lib/` (brace depth ≤ 1, so a method body never counts), and exits 1 naming each type and its sites. |
| A bridged name does not actually resolve through the barrel | [`test/kernel_types_test.dart`](../test/kernel_types_test.dart) | A consumer's-eye view: the file imports **only** the package barrel and Flutter, never `package:tom_core_kernel/...` and never a `lib/src/` path, and uses each bridged type. A name missing from the list is unnameable there and the file stops compiling. |

Neither guard could live inside `lib/`. The ~85 files declaring those
signatures import the kernel barrel unfiltered, so they compile whether or not
the bridge carries the type — the omission is only ever visible from outside.

## Dependencies

- `package:tom_core_kernel/tom_core_kernel.dart` — the sole export target.

This file declares nothing of its own; it is a `library;` directive, a dartdoc
comment, and one `export`.
