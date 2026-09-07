/// The wire contract for external-identity login (C-9): the DTOs and the
/// [TomApi] declaration both halves of the framework bind to when a user signs
/// in through an OAuth 2.0 / OpenID Connect provider.
///
/// The *flow* is server-side — a client secret, a token-endpoint call, a
/// linking table — and cannot live here. What has to live here is the part the
/// two halves must agree on: which providers exist, how a client asks for an
/// authorization URI, and what the provider's redirect carries back (G-API-1,
/// G-API-3). The kernel is the framework's contracts package, so declaring the
/// API anywhere else would mean one of the two tiers re-stating it.
///
/// ## The callback returns a login, not an OAuth result
///
/// [tomOAuthCompleteEndpointId] answers with a [TomAuthenticationResult] — the
/// *same* type `/login` answers with, carrying the same token pair, the same
/// `requires2FA` handshake and the same enrolment offer. That is the contract's
/// half of the decision recorded in the server's authentication module readme:
/// an external identity is a way of *resolving a principal*, and everything
/// after the principal is resolved is the one login path every credential
/// reaches. A distinct "OAuth result" type here would be the first step towards
/// a second token issuer, and the copy that drifts is the one that stops asking
/// for a second factor.
///
/// ## Why the client never names a redirect URI
///
/// [TomOAuthAuthorizationRequest] carries the login *context* (client, locale,
/// organization) and nothing else. Where the provider sends the user back is
/// server configuration, because a redirect target a caller may choose is an
/// open redirect: an attacker who can name it can have the provider deliver a
/// live authorization code to a host they own.
library;

import '../http_connection/endpoints_apis.dart';
import '../http_connection/httpmethods.dart';
import '../reflection/reflection.dart';
import 'access_controls.dart';
import 'authentication_authorization.dart';
import 'user_principal_aci.dart';

/// One configured external-identity provider, as a client sees it.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer. Deliberately thin — a client needs to
/// render a button and post an id back. Issuer URLs, client ids, secrets and
/// scopes are the server's business and are not on the wire.
@tomReflector
class TomOAuthProviderDto {
  /// The scope every shipped provider's resource keys live under, so a resource
  /// bundle can be searched for "everything the provider catalog needs" by
  /// prefix — the same convention `Tom2FAMethodDescriptor` follows.
  static const String resourceScope = 'oauth';

  /// The provider key, as configured under `oauth.providers` on the server
  /// (`google`, `github`, `acme-sso`). What a client posts back in
  /// [TomOAuthAuthorizationRequest.providerId].
  String id = '';

  /// Resource key of the provider's short label ("Sign in with Google").
  ///
  /// A key rather than text (G-RES-1): the label is rendered in the user's
  /// language, and the server does not know it at configuration time.
  String displayNameKey = '';

  /// Resource key of the icon to render. A key rather than an asset path
  /// because the two client tiers (Flutter, web) name their assets
  /// differently, and the provider must not have to know which one is asking.
  String iconKey = '';

  /// Describes a provider with explicitly chosen keys.
  ///
  /// Every parameter is optional and the fields are mutable, because this is a
  /// wire DTO: reflection constructs it empty and fills it in (G-DTO-1/2).
  TomOAuthProviderDto({
    this.id = '',
    this.displayNameKey = '',
    this.iconKey = '',
  });

  /// Describes a provider whose text lives under `oauth.<id>.*`.
  ///
  /// Derives both keys from [id], which is what makes the convention structural
  /// rather than a matter of per-provider discipline: adding a provider cannot
  /// silently invent a second naming scheme.
  TomOAuthProviderDto.scoped(this.id)
    : displayNameKey = '$resourceScope.$id.name',
      iconKey = '$resourceScope.$id.icon';

  @override
  String toString() => 'TomOAuthProviderDto($id)';
}

/// The request that starts an authorization-code flow.
///
/// Carries the same login context a password [TomAuthenticationMessage] does,
/// minus the credential — because there is no credential yet; that is what the
/// provider is about to establish. The context is captured *now* rather than at
/// the callback because the redirect arrives as a plain browser navigation that
/// carries none of it: no client id, no locale, no organization. The server
/// stores it with the pending authorization and replays it when the code comes
/// back, so an externally-authenticated session is issued in exactly the
/// organization and locale the login was started in.
@tomReflector
class TomOAuthAuthorizationRequest {
  /// The provider to authorize against — [TomOAuthProviderDto.id].
  String providerId = '';

  /// The calling client (`web`, `flutter`, …), as in
  /// [TomAuthenticationMessage.client].
  String client = '';

  /// The application the login is for.
  String application = '';

  /// The process the login is for.
  String process = '';

  /// The organization the login is for.
  String organization = '';

  /// The client's language code. Defaults to [TomClientContext.defaultLanguage].
  ///
  /// The three client-context fields start where
  /// [TomAuthenticationMessage]'s namesakes start, so a request that omits
  /// them carries the same context whichever login produced it. They were
  /// once empty here, which made an omitted field mean something different on
  /// this path — `''` is not a resolvable language, country or zone, so a
  /// consumer that parses rather than forwards behaved differently depending
  /// on the entry point.
  String clientLanguage = TomClientContext.defaultLanguage;

  /// The client's country code, or [TomClientContext.noCountry] for none.
  String clientCountry = TomClientContext.noCountry;

  /// The client's IANA timezone name. Defaults to
  /// [TomClientContext.defaultTimezone].
  String clientTimezone = TomClientContext.defaultTimezone;

  /// Creates an authorization request.
  TomOAuthAuthorizationRequest({
    this.providerId = '',
    this.client = '',
    this.application = '',
    this.process = '',
    this.organization = '',
    this.clientLanguage = TomClientContext.defaultLanguage,
    this.clientCountry = TomClientContext.noCountry,
    this.clientTimezone = TomClientContext.defaultTimezone,
  });

  @override
  String toString() => 'TomOAuthAuthorizationRequest($providerId)';
}

/// Where to send the user, and the handle the flow is remembered under.
@tomReflector
class TomOAuthAuthorizationDto {
  /// The provider's authorization endpoint with the flow's parameters applied
  /// — `client_id`, `redirect_uri`, `scope`, `state` and, when the provider
  /// supports it, the PKCE `code_challenge`. The client navigates to it and
  /// does nothing else with it.
  String authorizationUri = '';

  /// The opaque handle of the pending authorization.
  ///
  /// Returned so a client can *correlate* the redirect it later observes with
  /// the flow it started. It is not a credential: presenting it does not
  /// authenticate anything, because completing the flow additionally requires
  /// the authorization code the provider issues and the PKCE verifier the
  /// server kept.
  String state = '';

  /// Creates an authorization response.
  TomOAuthAuthorizationDto({this.authorizationUri = '', this.state = ''});

  @override
  String toString() => 'TomOAuthAuthorizationDto($state)';
}

/// What the provider's redirect carries back.
///
/// Either [code] + [state] (success) or [error] + [errorDescription] (the user
/// declined, the provider refused). The fields are named for the DTO; the
/// snake_cased query parameters they bind from are declared once in the
/// endpoint's [TomApiEndpoint.urlParameterMapping], which is what keeps the
/// provider's spelling out of the Dart shape.
@tomReflector
class TomOAuthCallbackRequest {
  /// The authorization code to exchange, when the flow succeeded.
  String code = '';

  /// The handle of the pending authorization ([TomOAuthAuthorizationDto.state]).
  String state = '';

  /// The provider's error code (`access_denied`, …), when it refused.
  String error = '';

  /// The provider's human-readable elaboration of [error], when it sent one.
  String errorDescription = '';

  /// Creates a callback request.
  TomOAuthCallbackRequest({
    this.code = '',
    this.state = '',
    this.error = '',
    this.errorDescription = '',
  });

  @override
  String toString() => 'TomOAuthCallbackRequest($state, error: $error)';
}

/// The API id [tomOAuthApi] is registered and bound under.
///
/// A constant because the server's `@TomApiEndpointImplementation(apiId: …)`
/// has to name it, and a literal restated on the implementation side is the one
/// string that can go wrong without anything failing to compile.
const String tomOAuthApiId = 'tomOAuth';

/// Endpoint id: the configured providers a client may offer.
const String tomOAuthProvidersEndpointId = 'listOAuthProviders';

/// Endpoint id: start an authorization-code flow for one provider.
const String tomOAuthBeginEndpointId = 'beginOAuthAuthorization';

/// Endpoint id: the provider's redirect target — completes the login.
const String tomOAuthCompleteEndpointId = 'completeOAuthAuthorization';

/// External-identity login (`/oauth/*`).
///
/// Every endpoint is [TomPublicAccess], and necessarily so: this is how a caller
/// who is *not yet* authenticated becomes authenticated, exactly like `/login`.
/// Public does not mean unguarded — the flow is protected by the `state` handle
/// (single-use, server-issued, TTL-bounded) and the PKCE verifier, neither of
/// which a caller supplies.
///
/// The URIs carry the *protocol*; the login they result in is the same login
/// every other credential produces (see the library documentation above).
final TomApi tomOAuthApi = TomApi(
  id: tomOAuthApiId,
  name: 'External Identity API',
  description: 'OAuth 2.0 / OpenID Connect authorization-code login.',
  uri: '/oauth',
  endpoints: [
    TomApiEndpoint<List<TomOAuthProviderDto>, Object?>(
      id: tomOAuthProvidersEndpointId,
      uri: '/providers',
      method: TomHttpMethod.get,
      requestTypes: const [],
      access: const TomPublicAccess(),
    ),
    TomApiEndpoint<TomOAuthAuthorizationDto, TomOAuthAuthorizationRequest>(
      id: tomOAuthBeginEndpointId,
      uri: '/authorize',
      method: TomHttpMethod.post,
      access: const TomPublicAccess(),
    ),
    // The provider redirects a *browser* here, so everything arrives in the
    // query string and there is no body to bind from. The mapping is what makes
    // those parameters reach the typed DTO, and it names the provider's
    // snake_case spelling on the left of the one entry that differs.
    TomApiEndpoint<TomAuthenticationResult, TomOAuthCallbackRequest>(
      id: tomOAuthCompleteEndpointId,
      uri: '/callback',
      method: TomHttpMethod.get,
      urlParameterMapping: const {
        'code': 'code',
        'state': 'state',
        'error': 'error',
        'error_description': 'errorDescription',
      },
      access: const TomPublicAccess(),
    ),
  ],
);

/// The typed service interface behind [tomOAuthApi].
///
/// The contract's *Dart* face: the server implements it, and a client that
/// generates or hand-writes a caller implements the same shape. It carries no
/// annotation because the server-side ones (`@tomComponent`,
/// `@TomApiEndpointImplementation`) live in `tom_core_server` and cannot be
/// named here — the same split the rest of the framework's contracts follow.
abstract class TomOAuthApiService {
  /// [tomOAuthProvidersEndpointId] — the providers this deployment configures.
  Future<List<TomOAuthProviderDto>> listOAuthProviders();

  /// [tomOAuthBeginEndpointId] — starts a flow and answers where to send the
  /// user.
  Future<TomOAuthAuthorizationDto> beginOAuthAuthorization(
    TomOAuthAuthorizationRequest request,
  );

  /// [tomOAuthCompleteEndpointId] — exchanges the code and completes the login,
  /// answering exactly what a password login answers.
  Future<TomAuthenticationResult> completeOAuthAuthorization(
    TomOAuthCallbackRequest request,
  );
}

/// Registers [tomOAuthApi] with the global [tomRemoteApis] registry.
///
/// Idempotent, and called by both halves: a server calls it before mounting the
/// endpoints, a client before building a caller. Registration is explicit rather
/// than implicit in a top-level initializer because a deployment that configures
/// no providers should not carry the API in its registry.
void registerTomOAuthApi() {
  tomRemoteApis.register(tomOAuthApi);
}
