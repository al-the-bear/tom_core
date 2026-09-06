/// The kernel types that reach a consumer through the `tom_flutter_ui` barrel.
///
/// `tom_flutter_ui` does not re-export `tom_core_kernel` wholesale, so this
/// file is the package's **only** bridge to it. Every kernel type named in a
/// public `tom_flutter_ui` signature has to appear below, or a consumer can
/// read the type in a signature and not name it — which is exactly what
/// happened to `TomScope`: `scope:` is a parameter on every Tom widget, and it
/// was absent from the one `show` list the package had. Nothing inside `lib/`
/// could catch that, because the files declaring those signatures import the
/// kernel barrel unfiltered; the omission is only visible from outside.
///
/// Two rules decide what belongs here.
///
/// 1. **Declaration positions.** A kernel type used in a public `extends`,
///    `implements`, `with` or type-parameter bound, or as the type of a public
///    field, parameter, or return value. `tool/check_kernel_bridge.py` enforces
///    this one mechanically.
/// 2. **What makes those types usable.** The concrete class the kernel ships
///    for a rule-1 abstract type, and the types a rule-1 type's own public
///    members name. `TomScope` is abstract with no public constructor, so
///    without `TomScopeBase` a consumer cannot build the very `scope:` argument
///    rule 1 exposes; `TomObservable.addObserver` takes a `TomObserver`, and
///    `TomFunctionObserver` is the only one the kernel ships.
///
/// The line stops there. An application wiring the kernel's HTTP stack — a
/// `TomHttpFileTransferClient` and its channel, say — is doing kernel work
/// rather than UI work and imports `package:tom_core_kernel/tom_core_kernel.dart`
/// for it. Following the companions transitively would end at the whole kernel.
///
/// **Why a list and not a blanket re-export.** Because the two packages answer
/// different questions, and a consumer who needs the kernel's should say so.
/// A blanket re-export would put the whole kernel behind a UI import, which is
/// the transitive end-point the previous paragraph declines to walk to.
///
/// The choice is only ever scope. Importing both barrels into one library is
/// legal, and `test/kernel_types_coexist_test.dart` holds it that way — which
/// takes a deliberate naming rule to stay true: the kernel barrel re-exports
/// `tom_basics` in full, and `tom_basics` declares a `TomEnvironment` and a
/// `TomPlatform`, so this package's config enums are `TomConfigEnvironment`
/// and `TomConfigPlatform`, named for the `TomConfigProvider` they configure.
/// A name declared on both sides is an `ambiguous_import` for every consumer
/// that imports both, so the narrower concept takes the qualified name.
///
/// The export names the kernel's **public barrel**, not the `lib/src/` paths
/// that declare the types. The barrel exports those files unfiltered, so the
/// two are equivalent today — but `lib/src/` is private by Dart convention, and
/// naming it would turn any reorganisation inside the kernel into a compile
/// error here even when the kernel's public surface never moved.
library;

export 'package:tom_core_kernel/tom_core_kernel.dart'
    show
        // Authorization — the four-state model every Tom widget resolves
        // against, plus the adapter, groups and controllers that feed it.
        TomAuthState,
        TomAuthorizable,
        TomAuthorizationGroup,
        AuthGroupMode,
        TomAuthorizationAdapter,
        TomAuthorization,
        TomAuthorizer,
        TomAuthorizerStrategy,
        TomUIStateController,
        // Scopes — `scope:` is a parameter on every Tom widget,
        // `TomScreenElementsProviderBase` mixes `TomScopeMixin` in, and
        // `TomScopeBase` is the only concrete `TomScope` there is.
        TomScope,
        TomScopeBase,
        TomScopeMixin,
        // Observables — `TomField` extends `TomObject`, `TomListForm` extends
        // `TomObservable` and implements `TomListLifecycleListener`, the list
        // forms bind a `TomList` of a `TomClass`, and observing any of them
        // takes a `TomObserver`.
        //
        // `TomObservableObservation` is the extension declaring `>>`, the
        // kernel's documented way to register an observer and get back the
        // `TomFunctionObserver` you must retain to keep it alive. An extension
        // reaches a consumer only if its own name is shown, so omitting it
        // while exporting the type it returns leaves `field >> (_) => …`
        // undefined on a `TomField` — a form field is UI, and observing one is
        // the most ordinary thing a consumer of this package does.
        TomObservable,
        TomObservableObservation,
        TomObserver,
        TomFunctionObserver,
        TomObject,
        TomClass,
        TomList,
        TomListLifecycleListener,
        TomObservableEnum,
        // File transfer — `TomFormFileField.transferClient` takes a client,
        // `FileRef` is built from and converts to the client's types, and the
        // client's own methods name the progress, cancellation and error types.
        TomFileTransferClient,
        TomFileSource,
        TomFileMetadata,
        TomTransferProgress,
        TomTransferCancellation,
        TomFileTransferException;
