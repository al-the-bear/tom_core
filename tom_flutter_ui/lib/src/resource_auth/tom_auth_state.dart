// Re-export the canonical authorization types from tom_core_kernel; the UI
// layer uses those canonical names directly (no UI-specific aliases).
//
// The export goes through the kernel's public barrel, not through
// `src/tombase/security/tom_authorization.dart` where the types are declared.
// The barrel already exports that file unfiltered, so the two spellings are
// equivalent today — but `lib/src/` is private by Dart convention, and naming
// it here would make any reorganisation inside the kernel a compile error in
// this package even when the kernel's public surface never moved.
export 'package:tom_core_kernel/tom_core_kernel.dart'
    show
        TomAuthState,
        TomAuthorizable,
        TomAuthorizationGroup,
        AuthGroupMode,
        TomAuthorizationAdapter,
        TomAuthorization,
        TomAuthorizer,
        TomAuthorizerStrategy,
        TomUIStateController;
