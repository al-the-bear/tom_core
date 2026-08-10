// Re-export the canonical authorization types from tom_core_kernel.
// The definitions are now in tom_core_kernel/security/tom_authorization.dart;
// the UI layer uses those canonical names directly (no UI-specific aliases).
export 'package:tom_core_kernel/src/tombase/security/tom_authorization.dart'
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
