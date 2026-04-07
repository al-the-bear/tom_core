// Re-export the canonical authorization types from tom_core_kernel.
// The definitions are now in tom_core_kernel/security/tom_authorization.dart.
//
// Legacy names are provided as typedefs for backward compatibility.
export 'package:tom_core_kernel/src/tombase/security/tom_authorization.dart'
    show
        TomAuthState,
        TomAuthorizable,
        TomAuthorizationGroup,
        TomAuthorizationAdapter,
        TomAuthorization,
        TomAuthorizer,
        TomAuthorizerStrategy,
        TomUIStateController;

// ---------------------------------------------------------------------------
// Backward-compatible typedefs for old names
// ---------------------------------------------------------------------------
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// @Deprecated('Use TomAuthorization instead')
typedef TomUIAuthorization = TomAuthorization;

/// @Deprecated('Use TomAuthorizationAdapter instead')
typedef TomUIAuthorizationAdapter = TomAuthorizationAdapter;
