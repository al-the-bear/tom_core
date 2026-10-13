/// A SAML identity provider in a test: builds `Response` documents and signs
/// them the way an identity provider does, so the service provider's checks can
/// be exercised one at a time.
///
/// The signer shares only [TomExclusiveCanonicalizer] with the code under test.
/// That the canonical form is the *standard's* is not proven here — the
/// canonicalizer's own vectors and the Keycloak interoperability suite prove
/// it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:xml/xml.dart';

/// A fixture file under `test/fixtures/saml/`.
String samlFixture(String name) =>
    File('test/fixtures/saml/$name').readAsStringSync();

/// The test identity provider.
class SamlTestIdp {
  /// Creates an identity provider signing with the fixture key [keyName].
  SamlTestIdp({
    this.entityId = 'https://idp.example.test/saml',
    String keyName = 'idp_key.pem',
  }) : key = TomSamlCertificates.privateKeyOf('test', samlFixture(keyName));

  /// The identity provider's entity id.
  final String entityId;

  /// The key it signs with.
  final pc.RSAPrivateKey key;

  /// A response document answering [requestId], before any signature.
  XmlDocument response({
    required String requestId,
    required String acsUrl,
    required String audience,
    required DateTime now,
    String nameId = 'alice',
    Map<String, List<String>> attributes = const {
      'email': ['alice@example.test'],
      'displayName': ['Alice Example'],
      'groups': ['admins', 'staff'],
    },
    String? destination,
    String? inResponseTo,
    String? issuer,
    String status = 'urn:oasis:names:tc:SAML:2.0:status:Success',
    Duration validity = const Duration(minutes: 5),
    Duration notBeforeOffset = const Duration(seconds: -10),
    String? recipient,
    bool attributePerValue = false,
  }) {
    String instant(DateTime value) =>
        '${value.toUtc().toIso8601String().substring(0, 19)}Z';
    final attributeXml = StringBuffer();
    void writeAttribute(String name, Iterable<String> values) {
      attributeXml.write(
        '<saml:Attribute Name="$name" '
        'NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:basic">',
      );
      for (final value in values) {
        attributeXml.write(
          '<saml:AttributeValue xmlns:xs="http://www.w3.org/2001/XMLSchema" '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          'xsi:type="xs:string">$value</saml:AttributeValue>',
        );
      }
      attributeXml.write('</saml:Attribute>');
    }

    attributes.forEach((name, values) {
      if (attributePerValue) {
        for (final value in values) {
          writeAttribute(name, [value]);
        }
      } else {
        writeAttribute(name, values);
      }
    });
    final xml =
        '<samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" '
        'xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" '
        'ID="_resp${requestId.hashCode.abs()}" Version="2.0" '
        'IssueInstant="${instant(now)}" '
        'Destination="${destination ?? acsUrl}" '
        'InResponseTo="${inResponseTo ?? requestId}">'
        '<saml:Issuer>${issuer ?? entityId}</saml:Issuer>'
        '<samlp:Status><samlp:StatusCode Value="$status"/></samlp:Status>'
        '<saml:Assertion ID="_assert${requestId.hashCode.abs()}" '
        'Version="2.0" IssueInstant="${instant(now)}">'
        '<saml:Issuer>${issuer ?? entityId}</saml:Issuer>'
        '<saml:Subject>'
        '<saml:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified">'
        '$nameId</saml:NameID>'
        '<saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">'
        '<saml:SubjectConfirmationData InResponseTo="${inResponseTo ?? requestId}" '
        'NotOnOrAfter="${instant(now.add(validity))}" '
        'Recipient="${recipient ?? acsUrl}"/>'
        '</saml:SubjectConfirmation>'
        '</saml:Subject>'
        '<saml:Conditions NotBefore="${instant(now.add(notBeforeOffset))}" '
        'NotOnOrAfter="${instant(now.add(validity))}">'
        '<saml:AudienceRestriction><saml:Audience>$audience</saml:Audience>'
        '</saml:AudienceRestriction>'
        '</saml:Conditions>'
        '<saml:AuthnStatement AuthnInstant="${instant(now)}">'
        '<saml:AuthnContext><saml:AuthnContextClassRef>'
        'urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport'
        '</saml:AuthnContextClassRef></saml:AuthnContext></saml:AuthnStatement>'
        '<saml:AttributeStatement>$attributeXml</saml:AttributeStatement>'
        '</saml:Assertion>'
        '</samlp:Response>';
    return XmlDocument.parse(xml);
  }

  /// The response element of [document].
  static XmlElement responseOf(XmlDocument document) => document.rootElement;

  /// The assertion element of [document].
  static XmlElement assertionOf(XmlDocument document) => document
      .rootElement
      .childElements
      .firstWhere((e) => e.name.local == 'Assertion');

  /// Signs [target] in place with an enveloped signature, placed after its
  /// `Issuer` as the schema requires.
  void sign(
    XmlElement target, {
    String signatureAlgorithm = TomXmlDsig.rsaSha256,
    String digestAlgorithm = TomXmlDsig.sha256,
    pc.RSAPrivateKey? withKey,
  }) {
    final id = target.getAttribute('ID')!;
    final digestBytes = utf8.encode(
      TomExclusiveCanonicalizer.canonicalize(target),
    );
    final digest = switch (digestAlgorithm) {
      TomXmlDsig.sha512 => crypto.sha512.convert(digestBytes).bytes,
      'http://www.w3.org/2000/09/xmldsig#sha1' =>
        crypto.sha1.convert(digestBytes).bytes,
      _ => crypto.sha256.convert(digestBytes).bytes,
    };
    final signature = XmlDocumentFragment.parse(
      '<ds:Signature xmlns:ds="${TomXmlDsig.namespace}">'
      '<ds:SignedInfo>'
      '<ds:CanonicalizationMethod Algorithm="${TomXmlDsig.exclusiveC14n}"/>'
      '<ds:SignatureMethod Algorithm="$signatureAlgorithm"/>'
      '<ds:Reference URI="#$id">'
      '<ds:Transforms>'
      '<ds:Transform Algorithm="${TomXmlDsig.envelopedSignature}"/>'
      '<ds:Transform Algorithm="${TomXmlDsig.exclusiveC14n}"/>'
      '</ds:Transforms>'
      '<ds:DigestMethod Algorithm="$digestAlgorithm"/>'
      '<ds:DigestValue>${base64.encode(digest)}</ds:DigestValue>'
      '</ds:Reference>'
      '</ds:SignedInfo>'
      '<ds:SignatureValue></ds:SignatureValue>'
      '</ds:Signature>',
    ).firstElementChild!;
    final issuerIndex = target.children.indexWhere(
      (n) => n is XmlElement && n.name.local == 'Issuer',
    );
    target.children.insert(issuerIndex + 1, signature);
    final signedInfo = signature.childElements.first;
    final canonical = TomExclusiveCanonicalizer.canonicalize(signedInfo);
    final value = TomXmlSignatureVerifier.signRsa(
      signatureAlgorithm == TomXmlDsig.rsaSha512
          ? TomXmlDsig.rsaSha512
          : TomXmlDsig.rsaSha256,
      withKey ?? key,
      utf8.encode(canonical),
    );
    signature.childElements
        .firstWhere((e) => e.name.local == 'SignatureValue')
        .innerText = base64.encode(
      value,
    );
  }

  /// [document] as the base64 `SAMLResponse` form field.
  static String encode(XmlDocument document) =>
      base64.encode(utf8.encode(document.toXmlString()));
}
