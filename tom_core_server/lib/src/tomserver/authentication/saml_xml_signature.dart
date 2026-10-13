/// XML Signature verification for SAML 2.0: Exclusive XML Canonicalization and
/// the enveloped RSA signatures identity providers put on a `Response` or an
/// `Assertion`.
///
/// ## What is accepted
///
/// Exactly the profile SAML identity providers use, and nothing wider:
///
/// | Part | Accepted |
/// | ---- | -------- |
/// | Canonicalization | Exclusive XML Canonicalization 1.0, without comments, with an optional `InclusiveNamespaces` prefix list |
/// | Signature | RSA PKCS#1 v1.5 with SHA-256 or SHA-512 |
/// | Reference | exactly one, `URI="#<ID of the signed element>"` |
/// | Transforms | the enveloped-signature transform, then exclusive canonicalization |
/// | Digest | SHA-256 or SHA-512 |
///
/// SHA-1 is refused for both the signature and the digest; every identity
/// provider in use has defaulted to SHA-256 for a decade, and SHA-1 collisions
/// are practical.
///
/// ## What the verifier refuses to trust
///
/// The `KeyInfo` a signature carries is ignored. A signature verifies against
/// the identity provider's certificates *as configured*, never against a key
/// the document names — otherwise anyone could sign a response with their own
/// key and enclose it.
///
/// A signature is checked against the element it is a direct child of, and its
/// one reference must name that element's `ID`, which must be unique in the
/// document. Combined with reading the assertion only from the element that was
/// verified (`TomSamlResponseValidator` does this), it is what defeats
/// signature-wrapping: moving a validly signed element elsewhere and planting
/// an unsigned one where a careless reader looks.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'package:xml/xml.dart';

import '../little_things/server_exception.dart';

/// A SAML message, configuration value or signature that cannot be used.
///
/// `clientThrow` is `false` by default: what failed in a SAML response is the
/// operator's business, and telling a sender which check its forgery tripped
/// helps nobody but the sender.
class TomSamlException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomSamlException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.clientThrow = false,
  });
}

/// Namespace and algorithm identifiers of XML Signature.
abstract final class TomXmlDsig {
  /// The XML Signature namespace.
  static const String namespace = 'http://www.w3.org/2000/09/xmldsig#';

  /// Exclusive XML Canonicalization 1.0, without comments.
  static const String exclusiveC14n = 'http://www.w3.org/2001/10/xml-exc-c14n#';

  /// The enveloped-signature transform.
  static const String envelopedSignature =
      'http://www.w3.org/2000/09/xmldsig#enveloped-signature';

  /// RSA with SHA-256.
  static const String rsaSha256 =
      'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256';

  /// RSA with SHA-512.
  static const String rsaSha512 =
      'http://www.w3.org/2001/04/xmldsig-more#rsa-sha512';

  /// The SHA-256 digest.
  static const String sha256 = 'http://www.w3.org/2001/04/xmlenc#sha256';

  /// The SHA-512 digest.
  static const String sha512 = 'http://www.w3.org/2001/04/xmlenc#sha512';

  /// The XML namespace the `xml:` prefix is bound to.
  static const String xmlNamespace = 'http://www.w3.org/XML/1998/namespace';

  /// The namespace `xmlns` declarations are in.
  static const String xmlnsNamespace = 'http://www.w3.org/2000/xmlns/';
}

/// Exclusive XML Canonicalization 1.0 (without comments) of an element and its
/// subtree.
///
/// The serialisation a signature is computed over: namespace declarations
/// rendered only where an element or attribute uses them, attributes in
/// canonical order, empty elements written as start and end tag, text and
/// attribute values escaped one fixed way. Two documents that differ only in
/// those respects canonicalise identically, which is what lets a signature
/// survive the identity provider's serialiser and this server's parser.
abstract final class TomExclusiveCanonicalizer {
  /// The canonical form of [apex] and its subtree, leaving out [omit] (the
  /// enveloped signature) wherever it occurs.
  ///
  /// [inclusivePrefixes] is the `InclusiveNamespaces` prefix list; `#default`
  /// names the default namespace.
  static String canonicalize(
    XmlElement apex, {
    Set<String> inclusivePrefixes = const {},
    XmlNode? omit,
  }) {
    final buffer = StringBuffer();
    final inclusive = {
      for (final prefix in inclusivePrefixes)
        prefix == '#default' ? '' : prefix,
    };
    _element(apex, _inScopeAbove(apex), const {}, inclusive, omit, buffer);
    return buffer.toString();
  }

  /// The namespaces in scope at [element]'s parent: what an apex inherits from
  /// ancestors that are not part of the output.
  static Map<String, String> _inScopeAbove(XmlElement element) {
    final chain = <XmlElement>[];
    for (var node = element.parent; node is XmlElement; node = node.parent) {
      chain.add(node);
    }
    final scope = <String, String>{};
    for (final ancestor in chain.reversed) {
      scope.addAll(_declaredBy(ancestor));
    }
    return scope;
  }

  /// The namespace declarations on [element], prefix (`''` for the default)
  /// to URI.
  static Map<String, String> _declaredBy(XmlElement element) => {
    for (final attribute in element.attributes)
      if (attribute.name.qualified == 'xmlns')
        '': attribute.value
      else if (attribute.name.prefix == 'xmlns')
        attribute.name.local: attribute.value,
  };

  static bool _isDeclaration(XmlAttribute attribute) =>
      attribute.name.qualified == 'xmlns' || attribute.name.prefix == 'xmlns';

  static void _element(
    XmlElement element,
    Map<String, String> inheritedScope,
    Map<String, String> rendered,
    Set<String> inclusive,
    XmlNode? omit,
    StringBuffer out,
  ) {
    final scope = {...inheritedScope, ..._declaredBy(element)};
    final attributes = element.attributes.where((a) => !_isDeclaration(a));

    final utilized = <String>{
      element.name.prefix ?? '',
      for (final attribute in attributes)
        if (attribute.name.prefix != null && attribute.name.prefix != 'xml')
          attribute.name.prefix!,
      for (final prefix in inclusive)
        if (scope.containsKey(prefix)) prefix,
    };

    final declarations = <String, String>{};
    for (final prefix in utilized) {
      final uri = scope[prefix];
      if (prefix.isEmpty) {
        final defaultUri = uri ?? '';
        final previous = rendered[''] ?? '';
        if (defaultUri != previous) declarations[''] = defaultUri;
        continue;
      }
      if (uri == null) {
        throw TomSamlException(
          'saml.xml.unbound_prefix',
          "The XML uses the namespace prefix '$prefix' without declaring it.",
          parameters: {'prefix': prefix},
        );
      }
      if (rendered[prefix] != uri) declarations[prefix] = uri;
    }
    final nowRendered = {...rendered, ...declarations};

    out
      ..write('<')
      ..write(element.name.qualified);
    for (final prefix in declarations.keys.toList()..sort()) {
      out
        ..write(prefix.isEmpty ? ' xmlns="' : ' xmlns:$prefix="')
        ..write(_escapeAttribute(declarations[prefix]!))
        ..write('"');
    }
    final sorted = attributes.toList()
      ..sort((a, b) {
        final byNamespace = _attributeNamespace(
          a,
          scope,
        ).compareTo(_attributeNamespace(b, scope));
        return byNamespace != 0
            ? byNamespace
            : a.name.local.compareTo(b.name.local);
      });
    for (final attribute in sorted) {
      out
        ..write(' ')
        ..write(attribute.name.qualified)
        ..write('="')
        ..write(_escapeAttribute(attribute.value))
        ..write('"');
    }
    out.write('>');

    for (final child in element.children) {
      if (identical(child, omit)) continue;
      switch (child) {
        case XmlElement():
          _element(child, scope, nowRendered, inclusive, omit, out);
        case XmlCDATA():
          out.write(_escapeText(child.value));
        case XmlText():
          out.write(_escapeText(child.value));
        case XmlProcessing():
          out
            ..write('<?')
            ..write(child.target)
            ..write(child.value.isEmpty ? '' : ' ${child.value}')
            ..write('?>');
        default:
          // Comments are not part of the canonical form "without comments".
          break;
      }
    }

    out
      ..write('</')
      ..write(element.name.qualified)
      ..write('>');
  }

  /// An attribute's namespace URI for ordering: `''` for an unprefixed
  /// attribute, which is in no namespace whatever the default namespace is.
  static String _attributeNamespace(
    XmlAttribute attribute,
    Map<String, String> scope,
  ) {
    final prefix = attribute.name.prefix;
    if (prefix == null) return '';
    if (prefix == 'xml') return TomXmlDsig.xmlNamespace;
    return scope[prefix] ?? '';
  }

  static String _escapeText(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\r', '&#xD;');

  static String _escapeAttribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('"', '&quot;')
      .replaceAll('\t', '&#x9;')
      .replaceAll('\n', '&#xA;')
      .replaceAll('\r', '&#xD;');
}

/// Verifies the enveloped XML signature on a SAML element against a fixed set
/// of trusted RSA keys.
class TomXmlSignatureVerifier {
  /// Creates a verifier trusting [keys] — the identity provider's configured
  /// signing keys. Several, because an identity provider rotating its key
  /// publishes both for a while.
  const TomXmlSignatureVerifier(this.keys);

  /// The keys a signature may verify against.
  final List<pc.RSAPublicKey> keys;

  /// The enveloped signature among [signed]'s children, or `null` when it has
  /// none.
  ///
  /// Throws `saml.signature.ambiguous` when there are several.
  static XmlElement? signatureOf(XmlElement signed) {
    final signatures = _children(signed, TomXmlDsig.namespace, 'Signature');
    if (signatures.length > 1) {
      throw TomSamlException(
        'saml.signature.ambiguous',
        'The element <${signed.name.qualified}> carries more than one '
            'signature.',
      );
    }
    return signatures.isEmpty ? null : signatures.single;
  }

  /// Verifies the enveloped signature that is a direct child of [signed] and
  /// covers it, in [document]; throws a [TomSamlException] unless it does.
  ///
  /// | Key | Meaning |
  /// | --- | ------- |
  /// | `saml.signature.missing` | [signed] carries no signature. |
  /// | `saml.signature.unsupported_algorithm` | A canonicalization, transform, signature or digest algorithm outside the accepted profile. |
  /// | `saml.signature.wrong_reference` | The signature does not reference exactly [signed], by an `ID` unique in the document. |
  /// | `saml.signature.digest_mismatch` | The signed element was changed after signing. |
  /// | `saml.signature.invalid` | The signature does not verify against any trusted key. |
  void verify(XmlElement signed, XmlDocument document) {
    final signature = signatureOf(signed);
    if (signature == null) {
      throw TomSamlException(
        'saml.signature.missing',
        'The element <${signed.name.qualified}> is not signed.',
      );
    }
    final signedInfo = _single(signature, 'SignedInfo');

    final canonicalization = _single(signedInfo, 'CanonicalizationMethod');
    _requireAlgorithm(canonicalization, const {TomXmlDsig.exclusiveC14n});
    final signedInfoPrefixes = _inclusivePrefixes(canonicalization);

    final signatureMethod = _requireAlgorithm(
      _single(signedInfo, 'SignatureMethod'),
      const {TomXmlDsig.rsaSha256, TomXmlDsig.rsaSha512},
    );

    final references = _children(signedInfo, TomXmlDsig.namespace, 'Reference');
    final id = signed.getAttribute('ID') ?? '';
    if (references.length != 1 ||
        id.isEmpty ||
        references.single.getAttribute('URI') != '#$id' ||
        _elementsWithId(document, id) != 1) {
      throw TomSamlException(
        'saml.signature.wrong_reference',
        'The signature on <${signed.name.qualified}> does not reference that '
            'element alone by an ID unique in the document.',
      );
    }
    final reference = references.single;

    final transforms = _optional(reference, 'Transforms');
    final transformAlgorithms = <String>[];
    var referencePrefixes = <String>{};
    for (final transform
        in transforms == null
            ? const <XmlElement>[]
            : _children(transforms, TomXmlDsig.namespace, 'Transform')) {
      final algorithm = _requireAlgorithm(transform, const {
        TomXmlDsig.envelopedSignature,
        TomXmlDsig.exclusiveC14n,
      });
      transformAlgorithms.add(algorithm);
      if (algorithm == TomXmlDsig.exclusiveC14n) {
        referencePrefixes = _inclusivePrefixes(transform);
      }
    }
    if (!transformAlgorithms.contains(TomXmlDsig.envelopedSignature)) {
      throw TomSamlException(
        'saml.signature.unsupported_algorithm',
        'The signature does not apply the enveloped-signature transform, so it '
            'cannot cover the element that contains it.',
      );
    }

    final digestAlgorithm = _requireAlgorithm(
      _single(reference, 'DigestMethod'),
      const {TomXmlDsig.sha256, TomXmlDsig.sha512},
    );
    final expectedDigest = _base64Of(_single(reference, 'DigestValue'));
    final canonicalSigned = TomExclusiveCanonicalizer.canonicalize(
      signed,
      inclusivePrefixes: referencePrefixes,
      omit: signature,
    );
    final actualDigest = _digest(digestAlgorithm, utf8.encode(canonicalSigned));
    if (!_constantTimeEquals(actualDigest, expectedDigest)) {
      throw TomSamlException(
        'saml.signature.digest_mismatch',
        'The content of <${signed.name.qualified}> does not match the digest '
            'its signature covers; it was changed after signing.',
      );
    }

    final canonicalSignedInfo = TomExclusiveCanonicalizer.canonicalize(
      signedInfo,
      inclusivePrefixes: signedInfoPrefixes,
    );
    final signatureBytes = _base64Of(_single(signature, 'SignatureValue'));
    final data = Uint8List.fromList(utf8.encode(canonicalSignedInfo));
    for (final key in keys) {
      if (_verifyRsa(signatureMethod, key, data, signatureBytes)) return;
    }
    throw TomSamlException(
      'saml.signature.invalid',
      'The signature on <${signed.name.qualified}> does not verify against any '
          'of the identity provider\'s configured certificates.',
    );
  }

  /// The RSA signature of [data] with [key] under [algorithm] — the signing
  /// half of [verify], for an SP that signs what it sends.
  static Uint8List signRsa(
    String algorithm,
    pc.RSAPrivateKey key,
    List<int> data,
  ) {
    final signer = _signer(algorithm)
      ..init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(key));
    return signer.generateSignature(Uint8List.fromList(data)).bytes;
  }

  static bool _verifyRsa(
    String algorithm,
    pc.RSAPublicKey key,
    Uint8List data,
    Uint8List signature,
  ) {
    final signer = _signer(algorithm)
      ..init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(key));
    try {
      return signer.verifySignature(data, pc.RSASignature(signature));
    } on ArgumentError {
      // A signature of the wrong length for this key is not this key's.
      return false;
    }
  }

  static pc.RSASigner _signer(String algorithm) => switch (algorithm) {
    TomXmlDsig.rsaSha256 => pc.RSASigner(
      pc.SHA256Digest(),
      '0609608648016503040201',
    ),
    TomXmlDsig.rsaSha512 => pc.RSASigner(
      pc.SHA512Digest(),
      '0609608648016503040203',
    ),
    _ => throw TomSamlException(
      'saml.signature.unsupported_algorithm',
      'The signature algorithm $algorithm is not supported.',
      parameters: {'algorithm': algorithm},
    ),
  };

  static List<int> _digest(String algorithm, List<int> data) =>
      algorithm == TomXmlDsig.sha512
      ? crypto.sha512.convert(data).bytes
      : crypto.sha256.convert(data).bytes;

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  static int _elementsWithId(XmlDocument document, String id) => document
      .descendantElements
      .where((element) => element.getAttribute('ID') == id)
      .length;

  static Set<String> _inclusivePrefixes(XmlElement method) {
    for (final child in method.childElements) {
      if (child.name.local == 'InclusiveNamespaces' &&
          child.name.namespaceUri == TomXmlDsig.exclusiveC14n) {
        return (child.getAttribute('PrefixList') ?? '')
            .split(RegExp(r'\s+'))
            .where((prefix) => prefix.isNotEmpty)
            .toSet();
      }
    }
    return const {};
  }

  static String _requireAlgorithm(XmlElement method, Set<String> accepted) {
    final algorithm = method.getAttribute('Algorithm') ?? '';
    if (!accepted.contains(algorithm)) {
      throw TomSamlException(
        'saml.signature.unsupported_algorithm',
        'The signature uses the algorithm "$algorithm" for '
            '<${method.name.local}>; accepted: ${accepted.join(', ')}.',
        parameters: {'algorithm': algorithm},
      );
    }
    return algorithm;
  }

  static Uint8List _base64Of(XmlElement element) {
    try {
      return base64.decode(element.innerText.replaceAll(RegExp(r'\s+'), ''));
    } on FormatException catch (error) {
      throw TomSamlException(
        'saml.signature.malformed',
        'The signature element <${element.name.local}> is not valid base64.',
        rootException: error,
      );
    }
  }

  static List<XmlElement> _children(
    XmlElement parent,
    String namespace,
    String local,
  ) => [
    for (final child in parent.childElements)
      if (child.name.local == local && child.name.namespaceUri == namespace)
        child,
  ];

  static XmlElement? _optional(XmlElement parent, String local) {
    final found = _children(parent, TomXmlDsig.namespace, local);
    return found.isEmpty ? null : found.first;
  }

  static XmlElement _single(XmlElement parent, String local) {
    final found = _children(parent, TomXmlDsig.namespace, local);
    if (found.length != 1) {
      throw TomSamlException(
        'saml.signature.malformed',
        'The signature has ${found.length} <$local> elements where it must '
            'have one.',
        parameters: {'element': local},
      );
    }
    return found.single;
  }
}
