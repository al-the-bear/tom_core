/// SAML 2.0 Web Browser SSO, service-provider initiated: the `AuthnRequest`
/// out over the HTTP-Redirect binding, the `Response` back over HTTP-POST.
///
/// ## The legs
///
/// 1. **Begin.** [TomSamlFlow.beginAuthorization] stores a pending record —
///    the same record and the same store an OAuth flow uses — whose `nonce` is
///    the `ID` of the `AuthnRequest`, and answers the identity provider's
///    single sign-on address carrying the deflated request, the `RelayState`
///    (the record's handle) and, when the provider configures a signing key,
///    the redirect-binding signature.
/// 2. **Consume.** The identity provider posts the `Response` to the
///    assertion consumer service. [TomSamlFlow.acceptResponse] spends the
///    pending record, verifies the response ([TomSamlResponseValidator]),
///    stores the verified identity under the same handle with the digest of a
///    fresh one-time code, and answers where to send the browser: the
///    application's page, with `code` and `state`.
/// 3. **Complete.** The page posts `code` and `state` to `/oauth/complete`,
///    as it does for an OpenID Connect provider. [TomSamlFlow.completeAuthorization]
///    checks the code and hands the verified identity to the login.
///
/// Why the third leg: the response arrives as a browser form post, and a
/// response to a browser form post can only be a page — the token pair would
/// land in the browser's history and logs. The handoff keeps the framework's
/// rule that tokens travel only in the body of the application's own call.
///
/// ## Replay and substitution
///
/// The pending record is spent when the response arrives, so a response posted
/// twice finds nothing the second time. A response must name, in
/// `InResponseTo`, the request this record sent, so a response captured from
/// another user's flow cannot complete this one. Unsolicited (identity-provider
/// initiated) responses carry no such link and are refused.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:xml/xml.dart';

import 'oauth_flow.dart';
import 'saml_provider.dart';
import 'saml_xml_signature.dart';

/// Drives SAML 2.0 Web Browser SSO against the configured identity providers.
class TomSamlFlow {
  /// Creates a flow over the provider set and the pending-authorization store
  /// it shares with the OAuth flow.
  TomSamlFlow({
    required this.providers,
    required this.stateStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  /// The configured SAML identity providers.
  final TomSamlProviders providers;

  /// Where pending authorizations are kept.
  final TomOAuthStateStore stateStore;

  final DateTime Function() _clock;

  /// Starts a login at the provider [request] names: remembers the pending
  /// authorization and answers the address to send the browser to.
  Future<TomOAuthAuthorizationDto> beginAuthorization(
    TomOAuthAuthorizationRequest request,
  ) async {
    final provider = providers[request.providerId];
    final state = TomOAuthFlow.randomHandle(32);
    // An `ID` is an xs:ID — an NCName — so it must not begin with a digit or a
    // hyphen, which a base64url token may.
    final requestId = '_${TomOAuthFlow.randomHandle(20)}';
    final now = _clock();
    await stateStore.store(
      TomOAuthAuthorizationState(
        state: state,
        providerId: provider.id,
        createdAt: now,
        nonce: requestId,
        client: request.client,
        application: request.application,
        process: request.process,
        organization: request.organization,
        clientLanguage: request.clientLanguage,
        clientCountry: request.clientCountry,
        clientTimezone: request.clientTimezone,
      ),
    );
    return TomOAuthAuthorizationDto(
      authorizationUri: redirectUrlFor(
        provider,
        authnRequestXml(provider, requestId, now),
        state,
      ),
      state: state,
    );
  }

  /// The assertion consumer service: verifies [samlResponse] (the base64
  /// `SAMLResponse` form field) against the pending flow [relayState] names,
  /// and answers the address to send the browser to.
  ///
  /// On success, the application's `redirectUri` with `code` and `state`. A
  /// response that fails verification sends the browser to the same page with
  /// `error=access_denied` and `state`, the shape an OAuth provider's refusal
  /// takes, and the reason is logged here rather than handed to the browser.
  ///
  /// Throws `saml.acs.unknown_state` (client-facing) when [relayState] names no
  /// pending SAML flow — there is then no page to send the browser to.
  Future<String> acceptResponse({
    required String samlResponse,
    required String relayState,
  }) async {
    final pending = await stateStore.consume(relayState);
    final provider = pending == null
        ? null
        : providers.lookup(pending.providerId);
    if (pending == null || provider == null) {
      throw TomSamlException(
        'saml.acs.unknown_state',
        'The SAML response could not be accepted because its RelayState is '
            'unknown, expired or already used.',
        clientThrow: true,
      );
    }
    final TomExternalIdentity identity;
    try {
      identity = TomSamlResponseValidator(
        provider,
      ).validate(samlResponse, requestId: pending.nonce, now: _clock());
    } on TomSamlException catch (error) {
      tomLog.warn(
        "Refused a SAML response from provider '${provider.id}': "
        '$error',
      );
      return _withQuery(provider.redirectUri, {
        'error': 'access_denied',
        'error_description': error.key,
        'state': relayState,
      });
    }

    final code = TomOAuthFlow.randomHandle(32);
    await stateStore.store(
      TomOAuthAuthorizationState(
        state: relayState,
        providerId: provider.id,
        createdAt: _clock(),
        nonce: _digestOf(code),
        assertedIdentity: identity,
        client: pending.client,
        application: pending.application,
        process: pending.process,
        organization: pending.organization,
        clientLanguage: pending.clientLanguage,
        clientCountry: pending.clientCountry,
        clientTimezone: pending.clientTimezone,
      ),
    );
    return _withQuery(provider.redirectUri, {
      'code': code,
      'state': relayState,
    });
  }

  /// Completes a login whose response the assertion consumer service has
  /// verified: [pending] is the spent record, [code] the handoff code the
  /// application posted.
  ///
  /// Throws `saml.flow.not_asserted` when no verified response is waiting —
  /// the application posted before the identity provider did — and
  /// `saml.flow.handoff_mismatch` when [code] is not the one issued.
  Future<TomOAuthExchange> completeAuthorization(
    TomOAuthAuthorizationState pending,
    String code,
  ) async {
    final identity = pending.assertedIdentity;
    if (identity == null) {
      throw TomSamlException(
        'saml.flow.not_asserted',
        'The SAML login was completed before the identity provider answered.',
        clientThrow: true,
      );
    }
    if (!_constantTimeEquals(_digestOf(code), pending.nonce)) {
      throw TomSamlException(
        'saml.flow.handoff_mismatch',
        'The code presented does not complete this SAML login.',
        clientThrow: true,
      );
    }
    return TomOAuthExchange(
      identity,
      pending,
      provider: providers[pending.providerId],
    );
  }

  /// This server's service-provider metadata for [providerId], to register
  /// with the identity provider.
  String metadataFor(String providerId) {
    final provider = providers[providerId];
    final certificate = provider.spCertificate;
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
      ..write('<md:EntityDescriptor xmlns:md="${TomSamlNames.metadata}" ')
      ..write('entityID="${_attr(provider.spEntityId)}">')
      ..write('<md:SPSSODescriptor ')
      ..write('AuthnRequestsSigned="${provider.spSigningKey != null}" ')
      ..write('WantAssertionsSigned="${provider.requireSignedAssertion}" ')
      ..write('protocolSupportEnumeration="${TomSamlNames.protocol}">');
    if (certificate != null) {
      buffer
        ..write('<md:KeyDescriptor use="signing">')
        ..write('<ds:KeyInfo xmlns:ds="${TomXmlDsig.namespace}">')
        ..write('<ds:X509Data><ds:X509Certificate>$certificate')
        ..write('</ds:X509Certificate></ds:X509Data></ds:KeyInfo>')
        ..write('</md:KeyDescriptor>');
    }
    if (provider.nameIdFormat != null) {
      buffer.write(
        '<md:NameIDFormat>${_text(provider.nameIdFormat!)}</md:NameIDFormat>',
      );
    }
    buffer
      ..write('<md:AssertionConsumerService ')
      ..write('Binding="${TomSamlNames.postBinding}" ')
      ..write(
        'Location="${_attr(provider.acsUrl)}" index="0" isDefault="true"/>',
      )
      ..write('</md:SPSSODescriptor></md:EntityDescriptor>');
    return buffer.toString();
  }

  /// The `AuthnRequest` with id [requestId], issued at [instant].
  static String authnRequestXml(
    TomSamlProviderConfig provider,
    String requestId,
    DateTime instant,
  ) {
    final format = provider.nameIdFormat;
    return '<samlp:AuthnRequest xmlns:samlp="${TomSamlNames.protocol}" '
        'xmlns:saml="${TomSamlNames.assertion}" '
        'ID="${_attr(requestId)}" Version="2.0" '
        'IssueInstant="${_instant(instant)}" '
        'Destination="${_attr(provider.ssoUrl)}" '
        'AssertionConsumerServiceURL="${_attr(provider.acsUrl)}" '
        'ProtocolBinding="${TomSamlNames.postBinding}">'
        '<saml:Issuer>${_text(provider.spEntityId)}</saml:Issuer>'
        '<samlp:NameIDPolicy '
        '${format == null ? '' : 'Format="${_attr(format)}" '}'
        'AllowCreate="true"/>'
        '</samlp:AuthnRequest>';
  }

  /// The single sign-on address carrying [requestXml] over the HTTP-Redirect
  /// binding, signed when the provider has a signing key.
  ///
  /// The signature is over the query string exactly as it is sent —
  /// `SAMLRequest=…&RelayState=…&SigAlg=…` with each value URL-encoded
  /// (SAML Bindings, section 3.4.4.1) — which is why the query is assembled by hand
  /// rather than by a URI builder that may encode differently.
  static String redirectUrlFor(
    TomSamlProviderConfig provider,
    String requestXml,
    String relayState,
  ) {
    final deflated = ZLibCodec(raw: true).encode(utf8.encode(requestXml));
    var query =
        'SAMLRequest=${Uri.encodeQueryComponent(base64.encode(deflated))}'
        '&RelayState=${Uri.encodeQueryComponent(relayState)}';
    final key = provider.spSigningKey;
    if (key != null) {
      query += '&SigAlg=${Uri.encodeQueryComponent(TomXmlDsig.rsaSha256)}';
      final signature = TomXmlSignatureVerifier.signRsa(
        TomXmlDsig.rsaSha256,
        key,
        utf8.encode(query),
      );
      query +=
          '&Signature=${Uri.encodeQueryComponent(base64.encode(signature))}';
    }
    final separator = provider.ssoUrl.contains('?') ? '&' : '?';
    return '${provider.ssoUrl}$separator$query';
  }

  static String _withQuery(String base, Map<String, String> parameters) {
    final uri = Uri.parse(base);
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...parameters})
        .toString();
  }

  static String _digestOf(String code) =>
      crypto.sha256.convert(utf8.encode(code)).toString();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }

  static String _instant(DateTime instant) {
    final utc = instant.toUtc();
    final text = utc.toIso8601String();
    // SAML's xs:dateTime in UTC, to the second: `2026-10-13T08:15:00Z`.
    return '${text.substring(0, 19)}Z';
  }

  static String _text(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _attr(String value) => _text(value).replaceAll('"', '&quot;');
}

/// Verifies a SAML `Response` for one provider and answers the identity it
/// asserts.
///
/// Every check is a refusal with its own key:
///
/// | Key | Refused because |
/// | --- | --------------- |
/// | `saml.response.malformed` | Not base64, not XML, or not a `samlp:Response`. |
/// | `saml.response.doctype` | The document declares a document type — the vector for entity expansion, and never present in SAML. |
/// | `saml.response.wrong_destination` | `Destination` is not this server's assertion consumer service. |
/// | `saml.response.wrong_request` | `InResponseTo` does not name the request this flow sent. |
/// | `saml.response.wrong_issuer` | The response or assertion was issued by another entity. |
/// | `saml.response.status_not_success` | The identity provider reports a failure — the user cancelled, or is not allowed in. |
/// | `saml.response.encrypted_unsupported` | The assertion is encrypted; configure the identity provider to sign, not encrypt. |
/// | `saml.response.assertion_count` | Not exactly one assertion. |
/// | `saml.signature.*` | The signature is missing or does not verify — see [TomXmlSignatureVerifier.verify]. |
/// | `saml.assertion.unsigned` | The provider requires a signed assertion and only the response is signed. |
/// | `saml.assertion.missing_subject` | No subject to link the identity to. |
/// | `saml.assertion.no_bearer_confirmation` | No bearer confirmation for this recipient, this request and the present moment. |
/// | `saml.assertion.not_yet_valid` / `saml.assertion.expired` | Outside the assertion's `Conditions`, beyond the provider's clock skew. |
/// | `saml.assertion.wrong_audience` | The assertion is not addressed to this service provider. |
class TomSamlResponseValidator {
  /// Creates a validator for [provider].
  const TomSamlResponseValidator(this.provider);

  /// The provider the response must come from.
  final TomSamlProviderConfig provider;

  /// The largest response accepted, decoded. A real response is a few
  /// kilobytes; a megabyte bounds the parse a hostile post can force.
  static const int maxResponseBytes = 1024 * 1024;

  /// Verifies [samlResponse], the base64 `SAMLResponse` form field, answering
  /// the asserted identity; throws a [TomSamlException] for any refusal.
  ///
  /// [requestId] is the `ID` of the request this flow sent, which the response
  /// must answer; [now] is the instant the validity windows are read against.
  TomExternalIdentity validate(
    String samlResponse, {
    required String requestId,
    required DateTime now,
  }) {
    final document = _parse(samlResponse);
    final response = document.rootElement;
    if (!_is(response, TomSamlNames.protocol, 'Response')) {
      throw _refuse(
        'saml.response.malformed',
        'The message is not a SAML Response.',
      );
    }

    final destination = response.getAttribute('Destination');
    if (destination != null && destination != provider.acsUrl) {
      throw _refuse(
        'saml.response.wrong_destination',
        'The response is addressed to $destination, not to this service '
            "provider's assertion consumer service.",
      );
    }
    if (response.getAttribute('InResponseTo') != requestId) {
      throw _refuse(
        'saml.response.wrong_request',
        'The response does not answer the authentication request this login '
            'sent.',
      );
    }
    _requireIssuer(response, optional: true);
    _requireSuccess(response);

    if (_childrenOf(
      response,
      TomSamlNames.assertion,
      'EncryptedAssertion',
    ).isNotEmpty) {
      throw _refuse(
        'saml.response.encrypted_unsupported',
        'The response carries an encrypted assertion, which is not supported; '
            'configure the identity provider to sign the response instead.',
      );
    }
    final assertions = _childrenOf(
      response,
      TomSamlNames.assertion,
      'Assertion',
    );
    if (assertions.length != 1) {
      throw _refuse(
        'saml.response.assertion_count',
        'The response carries ${assertions.length} assertions where it must '
            'carry one.',
      );
    }
    final assertion = assertions.single;

    // The assertion read below is the one verified here — a child of the
    // verified response, or itself verified — never one found by searching
    // the document, which is what signature wrapping relies on.
    final verifier = TomXmlSignatureVerifier(provider.idpSigningKeys);
    final responseSigned =
        TomXmlSignatureVerifier.signatureOf(response) != null;
    final assertionSigned =
        TomXmlSignatureVerifier.signatureOf(assertion) != null;
    if (!responseSigned && !assertionSigned) {
      throw _refuse(
        'saml.signature.missing',
        'Neither the response nor its assertion is signed.',
      );
    }
    if (provider.requireSignedAssertion && !assertionSigned) {
      throw _refuse(
        'saml.assertion.unsigned',
        "Provider '${provider.id}' requires a signed assertion, and the "
            'assertion is not signed.',
      );
    }
    if (responseSigned) verifier.verify(response, document);
    if (assertionSigned) verifier.verify(assertion, document);

    _requireIssuer(assertion, optional: false);
    final subjectElement = _single(assertion, 'Subject');
    final nameId = subjectElement == null
        ? null
        : _single(subjectElement, 'NameID')?.innerText.trim();
    _requireBearerConfirmation(subjectElement, requestId, now);
    _requireConditions(assertion, now);

    final claims = _attributesOf(assertion);
    final subject = provider.subjectAttribute == null
        ? nameId
        : _scalar(claims[provider.subjectAttribute]);
    if (subject == null || subject.isEmpty) {
      throw _refuse(
        'saml.assertion.missing_subject',
        'The assertion names no subject to link the identity to.',
      );
    }
    return TomExternalIdentity(
      issuer: provider.issuer,
      subject: subject,
      username: provider.usernameAttribute == null
          ? subject
          : _scalar(claims[provider.usernameAttribute]) ?? '',
      displayName: provider.displayNameAttribute == null
          ? ''
          : _scalar(claims[provider.displayNameAttribute]) ?? '',
      claims: Map.unmodifiable(claims),
      groups: provider.roleMapping.groupsIn(claims),
      roles: provider.roleMapping.rolesFor(claims),
    );
  }

  XmlDocument _parse(String samlResponse) {
    final List<int> bytes;
    try {
      bytes = base64.decode(samlResponse.replaceAll(RegExp(r'\s+'), ''));
    } on FormatException catch (error) {
      throw _refuse(
        'saml.response.malformed',
        'The SAMLResponse is not base64.',
        error,
      );
    }
    if (bytes.length > maxResponseBytes) {
      throw _refuse(
        'saml.response.malformed',
        'The SAMLResponse is larger than $maxResponseBytes bytes.',
      );
    }
    // Line ends are normalised as an XML parser must (XML 1.0, section 2.11) before
    // anything is canonicalised, so the canonical form matches the signer's.
    final xml = utf8
        .decode(bytes, allowMalformed: false)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (xml.toUpperCase().contains('<!DOCTYPE')) {
      throw _refuse(
        'saml.response.doctype',
        'The SAMLResponse declares a document type, which SAML never does.',
      );
    }
    try {
      return XmlDocument.parse(xml);
    } catch (error) {
      throw _refuse(
        'saml.response.malformed',
        'The SAMLResponse is not XML.',
        error,
      );
    }
  }

  void _requireIssuer(XmlElement element, {required bool optional}) {
    final issuer = _single(element, 'Issuer', TomSamlNames.assertion);
    if (issuer == null && optional) return;
    if (issuer?.innerText.trim() != provider.issuer) {
      throw _refuse(
        'saml.response.wrong_issuer',
        "The <${element.name.local}> was issued by "
            "'${issuer?.innerText.trim()}', not by '${provider.issuer}'.",
      );
    }
  }

  void _requireSuccess(XmlElement response) {
    final status = _single(response, 'Status', TomSamlNames.protocol);
    final code = status == null
        ? null
        : _single(status, 'StatusCode', TomSamlNames.protocol);
    final value = code?.getAttribute('Value');
    if (value != TomSamlNames.success) {
      final detail = code == null
          ? null
          : _single(
              code,
              'StatusCode',
              TomSamlNames.protocol,
            )?.getAttribute('Value');
      throw _refuse(
        'saml.response.status_not_success',
        'The identity provider answered with the status $value'
            '${detail == null ? '' : ' ($detail)'}.',
      );
    }
  }

  void _requireBearerConfirmation(
    XmlElement? subject,
    String requestId,
    DateTime now,
  ) {
    final confirmations = subject == null
        ? const <XmlElement>[]
        : _childrenOf(subject, TomSamlNames.assertion, 'SubjectConfirmation');
    for (final confirmation in confirmations) {
      if (confirmation.getAttribute('Method') != TomSamlNames.bearer) continue;
      final data = _single(confirmation, 'SubjectConfirmationData');
      if (data == null) continue;
      if (data.getAttribute('Recipient') != provider.acsUrl) continue;
      final inResponseTo = data.getAttribute('InResponseTo');
      if (inResponseTo != null && inResponseTo != requestId) continue;
      final notOnOrAfter = _instant(data.getAttribute('NotOnOrAfter'));
      if (notOnOrAfter == null ||
          !now.isBefore(notOnOrAfter.add(provider.clockSkew))) {
        continue;
      }
      final notBefore = _instant(data.getAttribute('NotBefore'));
      if (notBefore != null &&
          now.isBefore(notBefore.subtract(provider.clockSkew))) {
        continue;
      }
      return;
    }
    throw _refuse(
      'saml.assertion.no_bearer_confirmation',
      'The assertion carries no bearer confirmation for this recipient, this '
          'request and the present moment.',
    );
  }

  void _requireConditions(XmlElement assertion, DateTime now) {
    final conditions = _single(assertion, 'Conditions');
    if (conditions == null) {
      throw _refuse(
        'saml.assertion.wrong_audience',
        'The assertion carries no conditions, so it names no audience.',
      );
    }
    final notBefore = _instant(conditions.getAttribute('NotBefore'));
    if (notBefore != null &&
        now.isBefore(notBefore.subtract(provider.clockSkew))) {
      throw _refuse(
        'saml.assertion.not_yet_valid',
        'The assertion is not valid before ${notBefore.toIso8601String()}.',
      );
    }
    final notOnOrAfter = _instant(conditions.getAttribute('NotOnOrAfter'));
    if (notOnOrAfter != null &&
        !now.isBefore(notOnOrAfter.add(provider.clockSkew))) {
      throw _refuse(
        'saml.assertion.expired',
        'The assertion expired at ${notOnOrAfter.toIso8601String()}.',
      );
    }
    final restrictions = _childrenOf(
      conditions,
      TomSamlNames.assertion,
      'AudienceRestriction',
    );
    // Every restriction must admit this audience (SAML Core §2.5.1.4); at
    // least one must exist, or the assertion is addressed to anyone.
    final admitted =
        restrictions.isNotEmpty &&
        restrictions.every(
          (restriction) => _childrenOf(
            restriction,
            TomSamlNames.assertion,
            'Audience',
          ).any((audience) => audience.innerText.trim() == provider.spEntityId),
        );
    if (!admitted) {
      throw _refuse(
        'saml.assertion.wrong_audience',
        "The assertion is not addressed to '${provider.spEntityId}'.",
      );
    }
  }

  /// The assertion's attributes: a single value as a string, several as a
  /// list, under the attribute's `Name` and, when it differs, its
  /// `FriendlyName`.
  ///
  /// An attribute that occurs several times contributes all its values: some
  /// identity providers (Keycloak among them) send a multi-valued attribute as
  /// one `Attribute` element per value rather than one element with several
  /// `AttributeValue`s, and keeping only the last would drop every group but
  /// one.
  static Map<String, Object?> _attributesOf(XmlElement assertion) {
    final values = <String, List<String>>{};
    for (final statement in _childrenOf(
      assertion,
      TomSamlNames.assertion,
      'AttributeStatement',
    )) {
      for (final attribute in _childrenOf(
        statement,
        TomSamlNames.assertion,
        'Attribute',
      )) {
        final attributeValues = [
          for (final value in _childrenOf(
            attribute,
            TomSamlNames.assertion,
            'AttributeValue',
          ))
            value.innerText,
        ];
        final name = attribute.getAttribute('Name');
        final friendly = attribute.getAttribute('FriendlyName');
        for (final key in {
          if (name != null && name.isNotEmpty) name,
          if (friendly != null && friendly.isNotEmpty) friendly,
        }) {
          values.putIfAbsent(key, () => []).addAll(attributeValues);
        }
      }
    }
    return {
      for (final entry in values.entries)
        entry.key: entry.value.length == 1
            ? entry.value.single
            : List<String>.unmodifiable(entry.value),
    };
  }

  static String? _scalar(Object? value) => switch (value) {
    null => null,
    List() => value.isEmpty ? null : '${value.first}',
    _ => '$value',
  };

  static DateTime? _instant(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw TomSamlException(
        'saml.response.malformed',
        "The instant '$value' is not an xs:dateTime.",
      );
    }
    return parsed.toUtc();
  }

  static bool _is(XmlElement element, String namespace, String local) =>
      element.name.local == local && element.name.namespaceUri == namespace;

  static List<XmlElement> _childrenOf(
    XmlElement parent,
    String namespace,
    String local,
  ) => [
    for (final child in parent.childElements)
      if (_is(child, namespace, local)) child,
  ];

  static XmlElement? _single(
    XmlElement parent,
    String local, [
    String namespace = TomSamlNames.assertion,
  ]) {
    final found = _childrenOf(parent, namespace, local);
    if (found.length > 1) {
      throw TomSamlException(
        'saml.response.malformed',
        'The <${parent.name.local}> carries ${found.length} <$local> elements '
            'where it may carry one.',
      );
    }
    return found.isEmpty ? null : found.single;
  }

  static TomSamlException _refuse(
    String key,
    String message, [
    Object? cause,
  ]) => TomSamlException(key, message, rootException: cause);
}
