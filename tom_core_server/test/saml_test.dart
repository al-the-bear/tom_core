/// SAML 2.0 single sign-on: canonicalization, signature verification, the
/// response checks, the three-leg flow and the two endpoints.
///
/// The identity provider here is [SamlTestIdp], so every refusal can be
/// provoked on its own. Interoperability with a real identity provider is
/// `sso_keycloak_test.dart`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:xml/xml.dart';

import 'fixtures/reflection_fixture.dart' show registerFixtureAccessApi;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/saml_test_idp.dart';

const _acsUrl = 'https://app.example.test/saml/acs';
const _spEntityId = 'https://app.example.test/saml';
const _redirectUri = 'https://app.example.test/sso/callback';

final _now = DateTime.utc(2026, 10, 13, 9, 30);

TomSamlProviderConfig _provider({
  bool requireSignedAssertion = false,
  bool signRequests = false,
  List<String> certificates = const ['idp_cert.pem'],
  TomOAuthProvisioning provisioning = TomOAuthProvisioning.autoProvision,
}) => TomSamlProviderConfig.fromMap('corporate', {
  'issuer': 'https://idp.example.test/saml',
  'ssoUrl': 'https://idp.example.test/saml/sso',
  'idpCertificates': [for (final name in certificates) samlFixture(name)],
  'spEntityId': _spEntityId,
  'acsUrl': _acsUrl,
  'redirectUri': _redirectUri,
  'nameIdFormat': 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified',
  'usernameAttribute': 'email',
  'displayNameAttribute': 'displayName',
  'requireSignedAssertion': requireSignedAssertion,
  'provisioning': provisioning.name,
  if (signRequests) 'spSigningKeyFile': 'test/fixtures/saml/sp_key.pem',
  if (signRequests) 'spCertificateFile': 'test/fixtures/saml/sp_cert.pem',
  'defaultRoles': ['employee'],
  'roleMapping': {
    'admins': ['tom.admin'],
  },
});

final _idp = SamlTestIdp();

/// A response to [requestId], signed on the response.
XmlDocument _signedResponse(
  String requestId, {
  bool signResponse = true,
  bool signAssertion = false,
  DateTime? now,
}) {
  final document = _idp.response(
    requestId: requestId,
    acsUrl: _acsUrl,
    audience: _spEntityId,
    now: now ?? _now,
  );
  if (signAssertion) _idp.sign(SamlTestIdp.assertionOf(document));
  if (signResponse) _idp.sign(SamlTestIdp.responseOf(document));
  return document;
}

TomExternalIdentity _validate(
  XmlDocument document, {
  TomSamlProviderConfig? provider,
  String requestId = '_req1',
  DateTime? now,
}) => TomSamlResponseValidator(provider ?? _provider()).validate(
  SamlTestIdp.encode(document),
  requestId: requestId,
  now: now ?? _now,
);

/// The request context the endpoint pipeline reads.
Map<String, Object> get _logged => {
  TomRequestLogInfo.contextName: TomRequestLogInfo(),
};

Matcher _refusedWith(String key) =>
    throwsA(isA<TomSamlException>().having((e) => e.key, 'key', key));

void main() {
  setUpAll(() {
    initializeReflection();
    registerFixtureAccessApi();
  });

  group('exclusive canonicalization', () {
    test('renders the example of the specification, section 2.2', () {
      // The specification's example with its prefixes renamed: an element
      // inherits two declarations it does not use and renders neither, and a
      // descendant re-declaring a prefix its output ancestor did not render
      // keeps the declaration.
      final document = XmlDocument.parse(
        '<outer:local xmlns:outer="foo:bar" xmlns:ftp="ftp://example.org">'
        '<net:element xmlns:net="http://example.net" xml:lang="en">'
        '<ftp:stuff xmlns:ftp="ftp://example.org"/></net:element></outer:local>',
      );
      final element = document.rootElement.firstElementChild!;
      expect(
        TomExclusiveCanonicalizer.canonicalize(element),
        '<net:element xmlns:net="http://example.net" xml:lang="en">'
        '<ftp:stuff xmlns:ftp="ftp://example.org"></ftp:stuff></net:element>',
      );
    });

    final document = XmlDocument.parse(
      '<a:r xmlns:a="urn:a" xmlns:b="urn:b" xmlns="urn:d">'
      '<a:c b:y="2" x="1" b:a="3"/><!-- gone --><d>t&amp;&#13;&gt;</d></a:r>',
    );

    test('renders only the namespaces used, in canonical order', () {
      expect(
        TomExclusiveCanonicalizer.canonicalize(document.rootElement),
        '<a:r xmlns:a="urn:a">'
        '<a:c xmlns:b="urn:b" x="1" b:a="3" b:y="2"></a:c>'
        '<d xmlns="urn:d">t&amp;&#xD;&gt;</d></a:r>',
      );
    });

    test('an apex brings the declarations it inherits', () {
      expect(
        TomExclusiveCanonicalizer.canonicalize(
          document.rootElement.firstElementChild!,
        ),
        '<a:c xmlns:a="urn:a" xmlns:b="urn:b" x="1" b:a="3" b:y="2"></a:c>',
      );
    });

    test(
      'an InclusiveNamespaces prefix list renders the prefixes it names',
      () {
        expect(
          TomExclusiveCanonicalizer.canonicalize(
            document.rootElement,
            inclusivePrefixes: {'#default', 'b'},
          ),
          '<a:r xmlns="urn:d" xmlns:a="urn:a" xmlns:b="urn:b">'
          '<a:c x="1" b:a="3" b:y="2"></a:c>'
          '<d>t&amp;&#xD;&gt;</d></a:r>',
        );
      },
    );

    test('an emptied default namespace is rendered only below a set one', () {
      final undeclared = XmlDocument.parse(
        '<r xmlns="urn:d"><e xmlns=""><f/></e></r>',
      );
      expect(
        TomExclusiveCanonicalizer.canonicalize(undeclared.rootElement),
        '<r xmlns="urn:d"><e xmlns=""><f></f></e></r>',
      );
      expect(
        TomExclusiveCanonicalizer.canonicalize(
          undeclared.rootElement.firstElementChild!,
        ),
        '<e><f></f></e>',
      );
    });

    test('escapes attribute values the one canonical way', () {
      final escaped = XmlDocument.parse('<e a="&lt;&amp;&quot;&#9;&#10;"/>');
      expect(
        TomExclusiveCanonicalizer.canonicalize(escaped.rootElement),
        '<e a="&lt;&amp;&quot;&#x9;&#xA;"></e>',
      );
    });
  });

  group('a response', () {
    test('signed on the response yields the asserted identity', () {
      final identity = _validate(_signedResponse('_req1'));
      expect(identity.issuer, 'https://idp.example.test/saml');
      expect(identity.subject, 'alice');
      expect(identity.username, 'alice@example.test');
      expect(identity.displayName, 'Alice Example');
      expect(identity.groups, ['admins', 'staff']);
      expect(identity.roles, ['employee', 'tom.admin']);
      expect(identity.claims['email'], 'alice@example.test');
    });

    test('a multi-valued attribute sent one element per value keeps every '
        'value', () {
      // Keycloak's group mapper sends `groups` this way.
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: _spEntityId,
        now: _now,
        attributePerValue: true,
      );
      _idp.sign(document.rootElement);
      final identity = _validate(document);
      expect(identity.groups, ['admins', 'staff']);
      expect(identity.claims['email'], 'alice@example.test');
    });

    test('signed on the assertion alone is accepted', () {
      final identity = _validate(
        _signedResponse('_req1', signResponse: false, signAssertion: true),
        provider: _provider(requireSignedAssertion: true),
      );
      expect(identity.subject, 'alice');
    });

    test('verifies against any configured certificate, for a rotation', () {
      final provider = _provider(
        certificates: ['idp_other_cert.pem', 'idp_cert.pem'],
      );
      expect(
        _validate(_signedResponse('_req1'), provider: provider).subject,
        'alice',
      );
    });

    test('unsigned is refused', () {
      expect(
        () => _validate(_signedResponse('_req1', signResponse: false)),
        _refusedWith('saml.signature.missing'),
      );
    });

    test('with only the response signed is refused when the assertion must '
        'be', () {
      expect(
        () => _validate(
          _signedResponse('_req1'),
          provider: _provider(requireSignedAssertion: true),
        ),
        _refusedWith('saml.assertion.unsigned'),
      );
    });

    test('changed after signing is refused', () {
      final document = _signedResponse('_req1');
      document.rootElement
              .findAllElements('NameID', namespaceUri: TomSamlNames.assertion)
              .single
              .innerText =
          'mallory';
      expect(
        () => _validate(document),
        _refusedWith('saml.signature.digest_mismatch'),
      );
    });

    test('signed by another key is refused', () {
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: _spEntityId,
        now: _now,
      );
      SamlTestIdp(keyName: 'idp_other_key.pem').sign(document.rootElement);
      expect(() => _validate(document), _refusedWith('saml.signature.invalid'));
    });

    test('signed with SHA-1 is refused', () {
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: _spEntityId,
        now: _now,
      );
      _idp.sign(
        document.rootElement,
        signatureAlgorithm: 'http://www.w3.org/2000/09/xmldsig#rsa-sha1',
      );
      expect(
        () => _validate(document),
        _refusedWith('saml.signature.unsupported_algorithm'),
      );
    });

    group('wrapped around its signed assertion is refused', () {
      // The attack: keep the validly signed assertion somewhere a verifier
      // finds it, and put an unsigned one where a careless reader looks.
      test('a second assertion beside the signed one', () {
        final document = _signedResponse(
          '_req1',
          signResponse: false,
          signAssertion: true,
        );
        final evil = SamlTestIdp.assertionOf(document).copy()
          ..setAttribute('ID', '_evil');
        document.rootElement.children.add(evil);
        expect(
          () => _validate(document),
          _refusedWith('saml.response.assertion_count'),
        );
      });

      test('the signed assertion moved aside, a forgery in its place under '
          'the same ID', () {
        final document = _signedResponse(
          '_req1',
          signResponse: false,
          signAssertion: true,
        );
        final signed = SamlTestIdp.assertionOf(document);
        final forgery = signed.copy();
        forgery
                .findAllElements('NameID', namespaceUri: TomSamlNames.assertion)
                .single
                .innerText =
            'mallory';
        final extensions = XmlElement(
          XmlName.parts('Extensions', prefix: 'samlp'),
        );
        document.rootElement.children.insert(
          document.rootElement.children.indexOf(signed),
          extensions,
        );
        extensions.children.add(signed);
        document.rootElement.children.add(forgery);
        expect(
          () => _validate(document),
          _refusedWith('saml.signature.wrong_reference'),
        );
      });
    });

    test('answering another request is refused', () {
      expect(
        () => _validate(_signedResponse('_req1'), requestId: '_req2'),
        _refusedWith('saml.response.wrong_request'),
      );
    });

    test('addressed to another service is refused', () {
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: _spEntityId,
        now: _now,
        destination: 'https://other.example.test/acs',
      );
      _idp.sign(document.rootElement);
      expect(
        () => _validate(document),
        _refusedWith('saml.response.wrong_destination'),
      );
    });

    test('for another audience is refused', () {
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: 'https://other.example.test/saml',
        now: _now,
      );
      _idp.sign(document.rootElement);
      expect(
        () => _validate(document),
        _refusedWith('saml.assertion.wrong_audience'),
      );
    });

    test('from another issuer is refused', () {
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: _spEntityId,
        now: _now,
        issuer: 'https://evil.example.test',
      );
      _idp.sign(document.rootElement);
      expect(
        () => _validate(document),
        _refusedWith('saml.response.wrong_issuer'),
      );
    });

    test('expired is refused, and accepted inside the clock skew', () {
      final document = _signedResponse('_req1');
      expect(
        _validate(
          document,
          now: _now.add(const Duration(minutes: 5, seconds: 30)),
        ).subject,
        'alice',
      );
      expect(
        () => _validate(document, now: _now.add(const Duration(minutes: 7))),
        _refusedWith('saml.assertion.no_bearer_confirmation'),
      );
    });

    test('not yet valid is refused', () {
      expect(
        () => _validate(
          _signedResponse('_req1'),
          now: _now.subtract(const Duration(minutes: 5)),
        ),
        _refusedWith('saml.assertion.not_yet_valid'),
      );
    });

    test('confirmed for another recipient is refused', () {
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: _spEntityId,
        now: _now,
        recipient: 'https://other.example.test/acs',
      );
      _idp.sign(document.rootElement);
      expect(
        () => _validate(document),
        _refusedWith('saml.assertion.no_bearer_confirmation'),
      );
    });

    test('reporting a failure is refused with the status', () {
      final document = _idp.response(
        requestId: '_req1',
        acsUrl: _acsUrl,
        audience: _spEntityId,
        now: _now,
        status: 'urn:oasis:names:tc:SAML:2.0:status:Responder',
      );
      _idp.sign(document.rootElement);
      expect(
        () => _validate(document),
        _refusedWith('saml.response.status_not_success'),
      );
    });

    test('declaring a document type is refused before it is parsed', () {
      final encoded = base64.encode(
        utf8.encode(
          '<!DOCTYPE r [<!ENTITY x "y">]>'
          '${_signedResponse('_req1').toXmlString()}',
        ),
      );
      expect(
        () => TomSamlResponseValidator(
          _provider(),
        ).validate(encoded, requestId: '_req1', now: _now),
        _refusedWith('saml.response.doctype'),
      );
    });

    test('carrying an encrypted assertion is refused', () {
      final document = _signedResponse('_req1', signResponse: false);
      SamlTestIdp.assertionOf(document).replace(
        XmlElement(XmlName.parts('EncryptedAssertion', prefix: 'saml')),
      );
      expect(
        () => _validate(document),
        _refusedWith('saml.response.encrypted_unsupported'),
      );
    });

    test('that is not base64 is refused', () {
      expect(
        () => TomSamlResponseValidator(
          _provider(),
        ).validate('%%%', requestId: '_req1', now: _now),
        _refusedWith('saml.response.malformed'),
      );
    });
  });

  group('the flow', () {
    late TomOAuthMemoryStateStore store;
    late TomSamlFlow saml;

    setUp(() {
      store = TomOAuthMemoryStateStore(clock: () => _now);
      saml = TomSamlFlow(
        providers: TomSamlProviders({'corporate': _provider()}),
        stateStore: store,
        clock: () => _now,
      );
    });

    TomOAuthAuthorizationRequest request() => TomOAuthAuthorizationRequest(
      providerId: 'corporate',
      client: 'web',
      organization: 'acme',
      clientLanguage: 'de',
    );

    test(
      'begins with a deflated AuthnRequest on the redirect binding',
      () async {
        final begun = await saml.beginAuthorization(request());
        final uri = Uri.parse(begun.authorizationUri);
        expect(uri.origin + uri.path, 'https://idp.example.test/saml/sso');
        expect(uri.queryParameters['RelayState'], begun.state);
        final xml = utf8.decode(
          ZLibCodec(
            raw: true,
          ).decode(base64.decode(uri.queryParameters['SAMLRequest']!)),
        );
        final authn = XmlDocument.parse(xml).rootElement;
        final pending = await store.peek(begun.state);
        expect(authn.name.local, 'AuthnRequest');
        expect(authn.getAttribute('ID'), pending!.nonce);
        expect(authn.getAttribute('AssertionConsumerServiceURL'), _acsUrl);
        expect(
          authn.getAttribute('Destination'),
          'https://idp.example.test/saml/sso',
        );
        expect(authn.firstElementChild!.innerText, _spEntityId);
        expect(uri.queryParameters, isNot(contains('Signature')));
      },
    );

    test('signs the request when the provider has a signing key', () async {
      final signing = TomSamlFlow(
        providers: TomSamlProviders({
          'corporate': _provider(signRequests: true),
        }),
        stateStore: store,
        clock: () => _now,
      );
      final begun = await signing.beginAuthorization(request());
      final query = Uri.parse(begun.authorizationUri).query;
      final signed = query.substring(0, query.indexOf('&Signature='));
      final signature = base64.decode(
        Uri.parse(begun.authorizationUri).queryParameters['Signature']!,
      );
      expect(
        Uri.parse(begun.authorizationUri).queryParameters['SigAlg'],
        TomXmlDsig.rsaSha256,
      );
      final spKey = TomSamlCertificates.publicKeyOf(
        'sp',
        samlFixture('sp_cert.pem'),
      );
      // Verified with the certificate the identity provider is given.
      final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
        ..init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(spKey));
      expect(
        signer.verifySignature(
          Uint8List.fromList(utf8.encode(signed)),
          pc.RSASignature(signature),
        ),
        isTrue,
      );
    });

    test('hands a verified response to the application and completes the '
        'login', () async {
      final begun = await saml.beginAuthorization(request());
      final requestId = (await store.peek(begun.state))!.nonce;

      final location = Uri.parse(
        await saml.acceptResponse(
          samlResponse: SamlTestIdp.encode(_signedResponse(requestId)),
          relayState: begun.state,
        ),
      );
      expect(location.origin + location.path, _redirectUri);
      expect(location.queryParameters['state'], begun.state);
      final code = location.queryParameters['code']!;

      final flow = TomOAuthFlow(
        providers: TomOAuthProviders(const {}),
        stateStore: store,
        transport: TomHttpOAuthTokenTransport(),
        saml: saml,
      );
      final exchange = await flow.completeAuthorization(
        code: code,
        state: begun.state,
      );
      expect(exchange.identity.subject, 'alice');
      expect(exchange.provider.id, 'corporate');
      // The login context came through the identity provider untouched.
      expect(exchange.pending.organization, 'acme');
      expect(exchange.pending.clientLanguage, 'de');
    });

    test('a response posted twice finds nothing the second time', () async {
      final begun = await saml.beginAuthorization(request());
      final response = SamlTestIdp.encode(
        _signedResponse((await store.peek(begun.state))!.nonce),
      );
      await saml.acceptResponse(
        samlResponse: response,
        relayState: begun.state,
      );
      // The record is now the handoff, not the request; spend it.
      await store.consume(begun.state);
      await expectLater(
        saml.acceptResponse(samlResponse: response, relayState: begun.state),
        _refusedWith('saml.acs.unknown_state'),
      );
    });

    test('a refused response sends the browser back with an error', () async {
      final begun = await saml.beginAuthorization(request());
      final location = Uri.parse(
        await saml.acceptResponse(
          samlResponse: SamlTestIdp.encode(
            _signedResponse('_not-this-request'),
          ),
          relayState: begun.state,
        ),
      );
      expect(location.queryParameters['error'], 'access_denied');
      expect(
        location.queryParameters['error_description'],
        'saml.response.wrong_request',
      );
      expect(location.queryParameters, isNot(contains('code')));
      expect(await store.peek(begun.state), isNull);
    });

    test('a completion with the wrong code is refused', () async {
      final begun = await saml.beginAuthorization(request());
      await saml.acceptResponse(
        samlResponse: SamlTestIdp.encode(
          _signedResponse((await store.peek(begun.state))!.nonce),
        ),
        relayState: begun.state,
      );
      await expectLater(
        saml.completeAuthorization(
          (await store.consume(begun.state))!,
          'guess',
        ),
        _refusedWith('saml.flow.handoff_mismatch'),
      );
    });

    test(
      'a completion before the identity provider answered is refused',
      () async {
        final begun = await saml.beginAuthorization(request());
        await expectLater(
          saml.completeAuthorization((await store.consume(begun.state))!, 'x'),
          _refusedWith('saml.flow.not_asserted'),
        );
      },
    );

    test(
      'logs in through the authentication service with the mapped roles',
      () async {
        final begun = await saml.beginAuthorization(request());
        final location = Uri.parse(
          await saml.acceptResponse(
            samlResponse: SamlTestIdp.encode(
              _signedResponse((await store.peek(begun.state))!.nonce),
            ),
            relayState: begun.state,
          ),
        );
        final identities = TomMemoryExternalIdentityStore();
        final directory = _ProvisioningDirectory();
        final info =
            await TomOAuthAuthenticationService(
              directory: directory,
              flow: TomOAuthFlow(
                providers: TomOAuthProviders(const {}),
                stateStore: store,
                transport: TomHttpOAuthTokenTransport(),
                saml: saml,
              ),
              identityStore: identities,
            ).authenticateUser(
              TomAuthenticationData(
                username: TomUser.guestUsername,
                key: TomOAuthCredential(
                  code: location.queryParameters['code']!,
                  state: begun.state,
                ),
                organization: '',
                application: '',
                process: '',
                language: 'en',
                country: 'XX',
                timezone: 'utc',
                client: '',
              ),
            );
        expect(info.principal.user.username, 'alice@example.test');
        expect(info.principal.aci.roles, ['employee', 'tom.admin']);
        expect(
          await identities.localUsernameFor(
            const TomExternalIdentity(
              issuer: 'https://idp.example.test/saml',
              subject: 'alice',
            ),
          ),
          'alice@example.test',
        );
      },
    );

    test('publishes this server\'s metadata', () {
      final signing = TomSamlFlow(
        providers: TomSamlProviders({
          'corporate': _provider(signRequests: true),
        }),
        stateStore: store,
      );
      final metadata = XmlDocument.parse(signing.metadataFor('corporate'));
      final descriptor = metadata.rootElement;
      expect(descriptor.getAttribute('entityID'), _spEntityId);
      final sp = descriptor.firstElementChild!;
      expect(sp.getAttribute('AuthnRequestsSigned'), 'true');
      expect(
        sp
            .findAllElements(
              'AssertionConsumerService',
              namespaceUri: TomSamlNames.metadata,
            )
            .single
            .getAttribute('Location'),
        _acsUrl,
      );
      expect(
        sp
            .findAllElements(
              'X509Certificate',
              namespaceUri: TomXmlDsig.namespace,
            )
            .single
            .innerText,
        TomSamlCertificates.base64Of(samlFixture('sp_cert.pem')),
      );
    });

    test('an id configured as both OAuth and SAML provider is refused', () {
      expect(
        () => TomOAuthFlow(
          providers: TomOAuthProviders({
            'corporate': const TomOAuthProviderConfig(
              id: 'corporate',
              issuer: 'https://x.test',
              authorizationEndpoint: 'https://x.test/a',
              tokenEndpoint: 'https://x.test/t',
              clientId: 'c',
              redirectUri: 'https://app.test/cb',
            ),
          }),
          stateStore: store,
          transport: TomHttpOAuthTokenTransport(),
          saml: saml,
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.duplicate_provider_id',
          ),
        ),
      );
    });
  });

  group('identity-provider metadata', () {
    String metadata({String entityId = 'https://idp.example.test/saml'}) =>
        '<md:EntityDescriptor xmlns:md="${TomSamlNames.metadata}" '
        'entityID="$entityId"><md:IDPSSODescriptor '
        'protocolSupportEnumeration="${TomSamlNames.protocol}">'
        '<md:KeyDescriptor use="signing"><ds:KeyInfo '
        'xmlns:ds="${TomXmlDsig.namespace}"><ds:X509Data><ds:X509Certificate>'
        '${TomSamlCertificates.base64Of(samlFixture('idp_cert.pem'))}'
        '</ds:X509Certificate></ds:X509Data></ds:KeyInfo></md:KeyDescriptor>'
        '<md:SingleSignOnService Binding="${TomSamlNames.postBinding}" '
        'Location="https://idp.example.test/post"/>'
        '<md:SingleSignOnService Binding="${TomSamlNames.redirectBinding}" '
        'Location="https://idp.example.test/redirect"/>'
        '</md:IDPSSODescriptor></md:EntityDescriptor>';

    Map<String, Object?> configured({Map<String, Object?> extra = const {}}) =>
        {
          'corporate': {
            'metadataUrl': 'https://idp.example.test/metadata',
            'spEntityId': _spEntityId,
            'acsUrl': _acsUrl,
            'redirectUri': _redirectUri,
            ...extra,
          },
        };

    test('supplies the entity id, the redirect address and the keys', () async {
      final transport = _MetadataTransport(metadata());
      final providers = await TomSamlProviders.discover(
        configured(),
        transport: transport,
      );
      final provider = providers['corporate'];
      expect(transport.fetched.toString(), 'https://idp.example.test/metadata');
      expect(provider.issuer, 'https://idp.example.test/saml');
      expect(provider.ssoUrl, 'https://idp.example.test/redirect');
      expect(
        _validate(_signedResponse('_req1'), provider: provider).subject,
        'alice',
      );
    });

    test(
      'describing another entity than the configured one is refused',
      () async {
        await expectLater(
          TomSamlProviders.discover(
            configured(extra: {'issuer': 'https://idp.example.test/other'}),
            transport: _MetadataTransport(metadata()),
          ),
          _refusedWith('saml.config.metadata_issuer_mismatch'),
        );
      },
    );

    test('the synchronous reader names the loader it needs', () {
      expect(
        () => TomSamlProviders.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'saml': {'providers': configured()},
          }),
        ),
        _refusedWith('saml.config.metadata_not_loaded'),
      );
    });

    test('a provider with no certificate is refused at start-up', () {
      expect(
        () => TomSamlProviderConfig.fromMap('corporate', {
          'issuer': 'https://idp.example.test/saml',
          'ssoUrl': 'https://idp.example.test/sso',
          'spEntityId': _spEntityId,
          'acsUrl': _acsUrl,
          'redirectUri': _redirectUri,
        }),
        _refusedWith('saml.config.no_idp_certificate'),
      );
    });
  });

  group('what cannot be configured or read is refused', () {
    test('metadata that is no identity-provider descriptor', () {
      expect(
        () => TomSamlIdpMetadata.parse('p', '<md:EntitiesDescriptor/>'),
        _refusedWith('saml.config.malformed_metadata'),
      );
    });

    test('metadata that cannot be fetched', () async {
      await expectLater(
        TomSamlProviders.discover({
          'p': {'metadataUrl': 'https://idp.example.test/metadata'},
        }, transport: _FailingTransport()),
        _refusedWith('saml.config.metadata_failed'),
      );
    });

    test(
      'a provider tree that is not a map, or a provider that is not',
      () async {
        await expectLater(
          TomSamlProviders.discover('providers'),
          _refusedWith('saml.config.not_a_map'),
        );
        await expectLater(
          TomSamlProviders.discover({'p': 'settings'}),
          _refusedWith('saml.config.provider_not_a_map'),
        );
      },
    );

    test('a login naming no configured provider', () {
      expect(
        () => TomSamlProviders(const {})['nobody'],
        _refusedWith('saml.config.unknown_provider'),
      );
    });

    test('a certificate, a key or a file that cannot be read', () {
      expect(
        () => TomSamlCertificates.publicKeyOf('p', 'not a certificate'),
        _refusedWith('saml.config.unreadable_certificate'),
      );
      expect(
        () => TomSamlCertificates.privateKeyOf('p', 'not a key'),
        _refusedWith('saml.config.unreadable_key'),
      );
      expect(
        () => TomSamlProviderConfig.fromMap('p', {
          'issuer': 'https://idp.example.test/saml',
          'ssoUrl': 'https://idp.example.test/sso',
          'idpCertificateFiles': ['test/fixtures/saml/missing.pem'],
          'spEntityId': _spEntityId,
          'acsUrl': _acsUrl,
          'redirectUri': _redirectUri,
        }),
        _refusedWith('saml.config.unreadable_file'),
      );
    });

    test('an element signed twice', () {
      final document = _signedResponse('_req1');
      _idp.sign(SamlTestIdp.responseOf(document));
      expect(
        () => _validate(document),
        _refusedWith('saml.signature.ambiguous'),
      );
    });

    test('a digest that is not base64', () {
      final document = _signedResponse('_req1');
      document.rootElement
              .findAllElements(
                'DigestValue',
                namespaceUri: TomXmlDsig.namespace,
              )
              .single
              .innerText =
          '%%%';
      expect(
        () => _validate(document),
        _refusedWith('saml.signature.malformed'),
      );
    });

    test('a prefix used without a declaration', () {
      final orphan = XmlElement(XmlName.parts('e', prefix: 'undeclared'));
      expect(
        () => TomExclusiveCanonicalizer.canonicalize(orphan),
        _refusedWith('saml.xml.unbound_prefix'),
      );
    });
  });

  group('the endpoints', () {
    late Router router;
    late TomOAuthMemoryStateStore store;

    setUp(() {
      store = TomOAuthMemoryStateStore(clock: () => _now);
      TomBean.resetBeanContext();
      TomBean.withType<TomSamlServer>(const TomSamlServer());
      TomBean.withType<TomSamlProviders>(
        TomSamlProviders({'corporate': _provider()}),
      );
      TomBean.withType<TomOAuthStateStore>(store);
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test('the assertion consumer service redirects the browser to the '
        'application', () async {
      final begun = await TomOAuthFlow.fromBeans().beginAuthorization(
        TomOAuthAuthorizationRequest(providerId: 'corporate'),
      );
      final requestId = (await store.peek(begun.state))!.nonce;
      final response = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/saml/acs'),
          context: _logged,
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body:
              'SAMLResponse=${Uri.encodeQueryComponent(SamlTestIdp.encode(_signedResponse(requestId, now: DateTime.now().toUtc())))}'
              '&RelayState=${Uri.encodeQueryComponent(begun.state)}',
        ),
      );
      expect(response.statusCode, 303);
      final location = Uri.parse(response.headers['location']!);
      expect(location.origin + location.path, _redirectUri);
      expect(location.queryParameters['state'], begun.state);
      expect(location.queryParameters['code'], isNotEmpty);
    });

    test('a post naming no pending login answers 400', () async {
      final response = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/saml/acs'),
          context: _logged,
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: 'SAMLResponse=eA%3D%3D&RelayState=unknown',
        ),
      );
      expect(response.statusCode, 400);
    });

    test('publishes the metadata of a configured provider', () async {
      final response = await router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/saml/metadata/corporate'),
          context: _logged,
        ),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/samlmetadata+xml');
      expect(await response.readAsString(), contains(_spEntityId));
      final unknown = await router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/saml/metadata/nobody'),
          context: _logged,
        ),
      );
      expect(unknown.statusCode, 404);
    });
  });
}

/// A transport whose every fetch fails, as an unreachable host does.
class _FailingTransport implements TomOAuthTokenTransport {
  @override
  Future<String> getJson(Uri uri, Map<String, String> headers) =>
      throw const SocketException('connection refused');

  @override
  Future<String> postForm(
    Uri uri,
    Map<String, String> form,
    Map<String, String> headers,
  ) => throw UnimplementedError();
}

/// A transport answering every fetch with a metadata document.
class _MetadataTransport implements TomOAuthTokenTransport {
  _MetadataTransport(this.document);

  final String document;
  Uri? fetched;

  @override
  Future<String> getJson(Uri uri, Map<String, String> headers) async {
    fetched = uri;
    return document;
  }

  @override
  Future<String> postForm(
    Uri uri,
    Map<String, String> form,
    Map<String, String> headers,
  ) => throw UnimplementedError();
}

/// A directory that provisions every identity under its asserted username.
class _ProvisioningDirectory extends TomExternalIdentityDirectory {
  final Set<String> accounts = {};

  TomAuthenticationInfo _info(String username, TomAuthenticationData data) =>
      TomAuthenticationInfo(
        TomPrincipal(
          authenticated: true,
          context: {},
          requires2FA: false,
          twoFactorType: null,
          clientId: 0,
          organization: data.organization,
          organizationId: 0,
          application: data.application,
          applicationId: 0,
          process: data.process,
          processId: 0,
          language: data.language,
          country: data.country,
          clientCountry: data.country,
          clientLanguage: data.language,
          clientTimezone: data.timezone,
          user: TomUser(
            id: '1',
            username: username,
            firstname: '',
            lastname: '',
            attributes: {},
            timezone: 'utc',
          ),
        ),
        TomAccessControlDefinition(),
      );

  @override
  Future<TomAuthenticationInfo?> authenticatedPrincipalFor(
    String username,
    TomAuthenticationData authData,
  ) async => accounts.contains(username) ? _info(username, authData) : null;

  @override
  Future<TomAuthenticationInfo> provisionFromExternalIdentity(
    TomExternalIdentity identity,
    TomAuthenticationData authData,
  ) async {
    accounts.add(identity.username);
    return _info(identity.username, authData);
  }
}
