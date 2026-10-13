/// The two SAML endpoints that cannot be the application's call: the assertion
/// consumer service, which the identity provider's form post reaches, and the
/// service-provider metadata the identity provider is configured from.
///
/// A SAML login is otherwise begun and completed through `/oauth/begin` and
/// `/oauth/complete`, like every other external login — see `saml_flow.dart`.
library;

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import '../endpoints/endpoint_results.dart';
import '../endpoints/form_binding.dart';
import 'oauth_flow.dart';
import 'saml_xml_signature.dart';

/// `POST /saml/acs` and `GET /saml/metadata/<providerId>`.
///
/// Both public: the identity provider's form post carries no credential of
/// this deployment — the signed response *is* the credential — and metadata
/// is published by design.
@tomReflector
@tomService
abstract class TomSamlService {
  /// The assertion consumer service: accepts the identity provider's
  /// `SAMLResponse` and `RelayState` and redirects the browser (`303`) to the
  /// application's page with the handoff `code` and `state`, or with
  /// `error=access_denied` when the response is refused.
  ///
  /// A `RelayState` naming no pending SAML login answers `400`: there is no
  /// page to send the browser to.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.post],
    uri: "/saml/acs",
    consumes: TomMimeType.urlEncoded,
    produces: TomMimeType.plainText,
  )
  Future<Object> assertionConsumer(TomMultipartForm form);

  /// This server's service-provider metadata for the SAML provider
  /// [providerId], as `application/samlmetadata+xml`; `404` for an unknown id.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: "/saml/metadata/<providerId>",
    produces: TomMimeType.xml,
    logRequests: false,
  )
  Future<Response> metadata(String providerId);
}

/// The default [TomSamlService]: answers from the installed flow.
@tomReflector
@tomComponent
class TomSamlServer implements TomSamlService {
  /// Creates the endpoint implementation.
  const TomSamlServer();

  @override
  Future<Object> assertionConsumer(TomMultipartForm form) async {
    final saml = TomOAuthFlow.fromBeans().saml;
    final response = form.fields['SAMLResponse'] ?? '';
    final relayState = form.fields['RelayState'] ?? '';
    if (saml == null || response.isEmpty || relayState.isEmpty) {
      return _badRequest('The post carries no SAML response for this server.');
    }
    try {
      return TomRedirect.seeOther(
        await saml.acceptResponse(
          samlResponse: response,
          relayState: relayState,
        ),
      );
    } on TomSamlException catch (error) {
      return _badRequest(
        error.clientMessage('The SAML response could not be accepted.'),
      );
    }
  }

  @override
  Future<Response> metadata(String providerId) async {
    final saml = TomOAuthFlow.fromBeans().saml;
    if (saml == null || saml.providers.lookup(providerId) == null) {
      return Response.notFound(
        'No SAML provider is configured under that id.',
        headers: {TomHeader.contentType: TomMimeType.plainText.toHeaderValue()},
      );
    }
    return Response.ok(
      saml.metadataFor(providerId),
      headers: {TomHeader.contentType: 'application/samlmetadata+xml'},
    );
  }

  static Response _badRequest(String message) => Response.badRequest(
    body: message,
    headers: {TomHeader.contentType: TomMimeType.plainText.toHeaderValue()},
  );
}
