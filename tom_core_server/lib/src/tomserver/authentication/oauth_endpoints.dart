/// The HTTP face of external identity: `/oauth/*`, bound to the kernel's
/// [tomOAuthApi] (C-9).
///
/// ## Three endpoints, all of them calls the application makes
///
/// Including the third. `/oauth/complete` is *not* the address the provider
/// redirects to — that is a page of the application, named by the provider
/// configuration's `redirectUri`. The provider redirects a **browser** there;
/// the page reads `code` and `state` off its own query string and posts them
/// here, and the token pair comes back to the front end in a response body it
/// controls.
///
/// The arrangement matters rather than being a preference. An endpoint the
/// provider redirects *to* answers a browser navigation, so a token pair would
/// land in the address bar, in the session's history, in the server's access
/// log and in the `Referer` of whatever the page loaded next — and a cancelled
/// authorization would render a fault body as a page. This endpoint was a `GET`
/// at `/callback` once, which invited exactly that reading; it is a `POST` at
/// `/complete` now, and nothing in the framework is browser-facing.
///
/// A deployment that wants the provider to reach the server directly puts its
/// own handler at that address: it is the one piece that has to know where the
/// user should end up afterwards, which is an application decision and not a
/// framework one.
///
/// ## Why the completion issues a login rather than reporting an OAuth result
///
/// It returns a [TomAuthenticationResult] — the same type
/// [TomAuthenticationServer.authenticateUser] returns for a password login, with
/// the same fields, including the 2FA challenge fields. That is the module's
/// central decision made literal: [completeOAuthAuthorization] does not issue a
/// token, does not consult a 2FA policy and does not resolve grants. It hands a
/// [TomOAuthCredential] to [TomAuthenticationServer.authenticateExternal] and
/// returns whatever comes back, so an externally-authenticated user is
/// challenged for a second factor by the same code that challenges a password
/// user, or not at all.
///
/// ## Why all three are public
///
/// There is no caller to authenticate. A user reaching `/oauth/providers` has
/// not logged in yet — that is what they are trying to do — and the completion
/// arrives with nothing but a code the application forwarded. What stands in for authentication
/// here is the `state` handle: server-issued, single-use and TTL-bounded, so an
/// unauthenticated endpoint still cannot be driven by anyone who did not start
/// a flow through [beginOAuthAuthorization].
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import '../endpoints/endpoint_pipeline.dart';
import 'authentication_server.dart';
import 'oauth_authentication_service.dart';
import 'oauth_flow.dart';

/// The default [TomOAuthApiService] implementation.
///
/// Stateless: the provider set, the pending-authorization store and the HTTP
/// transport are all resolved per call through [TomOAuthFlow.fromBeans], so a
/// deployment that installs its own beans after the pipeline has constructed
/// this handler is obeyed.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: tomOAuthApiId)
class TomOAuthServer implements TomOAuthApiService {
  /// Creates the endpoint implementation.
  const TomOAuthServer();

  @TomApiEndpointImplementation(
    apiId: tomOAuthApiId,
    endpointId: tomOAuthProvidersEndpointId,
  )
  @override
  Future<List<TomOAuthProviderDto>> listOAuthProviders() async =>
      _flow().providers.descriptors;

  @TomApiEndpointImplementation(
    apiId: tomOAuthApiId,
    endpointId: tomOAuthBeginEndpointId,
  )
  @override
  Future<TomOAuthAuthorizationDto> beginOAuthAuthorization(
    TomOAuthAuthorizationRequest request,
  ) => _flow().beginAuthorization(request);

  @TomApiEndpointImplementation(
    apiId: tomOAuthApiId,
    endpointId: tomOAuthCompleteEndpointId,
  )
  @override
  Future<TomAuthenticationResult> completeOAuthAuthorization(
    TomOAuthCallbackRequest request,
  ) async {
    if (request.error.isNotEmpty) {
      // The user pressed *Cancel*, or the provider refused. Neither is a server
      // fault, and neither reaches the code exchange — there is no code.
      throw TomEndpointHandlerException(
        'oauth.callback.provider_error',
        'The identity provider refused the authorization: ${request.error} '
            '${request.errorDescription}',
        parameters: {'error': request.error},
      );
    }

    // Read (without spending) the pending record for the context the login
    // started in. The message must be built *before* the credential is
    // authenticated, and the completion carries only what the provider's
    // redirect gave the application — no client, locale or organization of its
    // own — so this is the only place the real context can come from. The
    // record is spent later, inside the flow.
    final pending = await TomOAuthStateStore.resolve().peek(request.state);
    if (pending == null) {
      throw TomEndpointHandlerException(
        'oauth.callback.unknown_state',
        'The authorization could not be completed because its state handle is '
            'unknown, expired or already used.',
      );
    }

    return TomAuthenticationServer().authenticateExternal(
      _messageFor(pending),
      TomOAuthCredential(code: request.code, state: request.state),
    );
  }

  /// The login message for a pending authorization.
  ///
  /// The username is deliberately left at its default: which local account this
  /// is, is what the provider's answer decides, and naming one here would be
  /// asserting an identity the completion has not yet established.
  TomAuthenticationMessage _messageFor(TomOAuthAuthorizationState pending) {
    final message = TomAuthenticationMessage();
    if (pending.client.isNotEmpty) message.client = pending.client;
    if (pending.application.isNotEmpty) {
      message.application = pending.application;
    }
    if (pending.process.isNotEmpty) message.process = pending.process;
    if (pending.organization.isNotEmpty) {
      message.organization = pending.organization;
    }
    if (pending.clientLanguage.isNotEmpty) {
      message.clientLanguage = pending.clientLanguage;
    }
    if (pending.clientCountry.isNotEmpty) {
      message.clientCountry = pending.clientCountry;
    }
    if (pending.clientTimezone.isNotEmpty) {
      message.clientTimezone = pending.clientTimezone;
    }
    return message;
  }

  /// The flow, from the installed beans and the configuration tree.
  TomOAuthFlow _flow() => TomOAuthFlow.fromBeans();
}
