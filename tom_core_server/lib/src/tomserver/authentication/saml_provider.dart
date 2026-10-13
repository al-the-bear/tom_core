/// SAML 2.0 identity-provider configuration — as data, like the OAuth
/// providers beside it.
///
/// ## Where the values come from
///
/// [TomSamlProviders.load] reads the configuration tree under `saml.providers`,
/// one nested map per identity provider. Most identity providers publish their
/// entity id, single sign-on address and signing certificates as a metadata
/// document, so the shortest configuration names that document and this
/// server's own side:
///
/// ```yaml
/// saml:
///   providers:
///     corporate-saml:
///       metadataUrl: https://login.example.com/realms/staff/protocol/saml/descriptor
///       spEntityId: https://app.example.com/saml
///       acsUrl: https://app.example.com/saml/acs
///       redirectUri: https://app.example.com/sso/callback
///       spSigningKeyFile: /etc/tom/saml-sp.key.pem
///       spCertificateFile: /etc/tom/saml-sp.cert.pem
///       usernameAttribute: email
///       groupsClaim: groups
///       roleMapping:
///         admins: [tom.admin]
/// ```
///
/// Without metadata, the identity provider's side is configured directly:
/// `issuer` (its entity id), `ssoUrl` (its HTTP-Redirect single sign-on
/// service) and `idpCertificates` (its signing certificates, PEM or bare
/// base64) or `idpCertificateFiles`.
///
/// ## The three addresses
///
/// * `ssoUrl` is the identity provider's; the user's browser is sent there.
/// * `acsUrl` is this server's assertion consumer service (`POST /saml/acs`),
///   where the identity provider's form post lands.
/// * `redirectUri` is the **application's** page. Once the response is
///   verified, the browser is sent there with a one-time `code` and the
///   `state`, and the page completes the login through `/oauth/complete` —
///   exactly as it does for an OpenID Connect provider.
library;

import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:pointycastle/export.dart' as pc;
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:xml/xml.dart';

import '../configuration/base_server_configuration.dart';
import 'external_provider.dart';
import 'oauth_flow.dart';
import 'oauth_provider.dart';
import 'saml_xml_signature.dart';

/// SAML 2.0 namespace and binding identifiers.
abstract final class TomSamlNames {
  /// The assertion namespace (`saml:`).
  static const String assertion = 'urn:oasis:names:tc:SAML:2.0:assertion';

  /// The protocol namespace (`samlp:`).
  static const String protocol = 'urn:oasis:names:tc:SAML:2.0:protocol';

  /// The metadata namespace (`md:`).
  static const String metadata = 'urn:oasis:names:tc:SAML:2.0:metadata';

  /// The HTTP-Redirect binding.
  static const String redirectBinding =
      'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect';

  /// The HTTP-POST binding.
  static const String postBinding =
      'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST';

  /// The status of a successful response.
  static const String success = 'urn:oasis:names:tc:SAML:2.0:status:Success';

  /// The bearer subject-confirmation method.
  static const String bearer = 'urn:oasis:names:tc:SAML:2.0:cm:bearer';
}

/// One configured SAML 2.0 identity provider and this server's side of the
/// trust.
class TomSamlProviderConfig implements TomExternalProvider {
  /// Creates a provider configuration.
  const TomSamlProviderConfig({
    required this.id,
    required this.issuer,
    required this.ssoUrl,
    required this.idpSigningKeys,
    required this.spEntityId,
    required this.acsUrl,
    required this.redirectUri,
    this.nameIdFormat,
    this.subjectAttribute,
    this.usernameAttribute,
    this.displayNameAttribute,
    this.requireSignedAssertion = false,
    this.spSigningKey,
    this.spCertificate,
    this.provisioning = TomOAuthProvisioning.autoProvision,
    this.roleMapping = TomExternalRoleMapping.none,
    this.clockSkew = TomOAuthProviderConfig.defaultClockSkew,
    this.displayNameKey = '',
    this.iconKey = '',
  });

  /// The provider key under `saml.providers`, and what a login names.
  @override
  final String id;

  /// The identity provider's entity id. Every response and assertion must be
  /// issued by it, and identity links are keyed by it.
  @override
  final String issuer;

  /// The identity provider's HTTP-Redirect single sign-on service.
  final String ssoUrl;

  /// The keys the identity provider signs with — every certificate it
  /// publishes for signing, so a key rotation at the provider verifies
  /// throughout.
  final List<pc.RSAPublicKey> idpSigningKeys;

  /// This server's entity id: the audience every assertion must name.
  final String spEntityId;

  /// This server's assertion consumer service — the `Destination` and
  /// `Recipient` every response must name.
  final String acsUrl;

  /// The application page the browser is sent to with the handoff code.
  final String redirectUri;

  /// The `NameIDPolicy` format requested, or `null` to leave the choice to
  /// the identity provider.
  ///
  /// Ask for a persistent, username or email format: a transient name id
  /// changes on every login, and an identity whose subject changes cannot be
  /// linked to an account.
  final String? nameIdFormat;

  /// The attribute whose value is the stable subject, or `null` for the
  /// `NameID`.
  final String? subjectAttribute;

  /// The attribute a local username is derived from, or `null` for the
  /// subject.
  final String? usernameAttribute;

  /// The attribute carrying a display name, or `null`.
  final String? displayNameAttribute;

  /// Whether the assertion itself must be signed. Off by default: a signed
  /// response covers the assertion inside it, and is what most identity
  /// providers sign.
  final bool requireSignedAssertion;

  /// The key authentication requests are signed with, or `null` to send them
  /// unsigned.
  final pc.RSAPrivateKey? spSigningKey;

  /// This server's signing certificate, base64 DER, published in its metadata
  /// so the identity provider can verify signed requests; or `null`.
  final String? spCertificate;

  @override
  final TomOAuthProvisioning provisioning;

  @override
  final TomExternalRoleMapping roleMapping;

  @override
  final Duration clockSkew;

  /// Resource key of the provider's label.
  final String displayNameKey;

  /// Resource key of the provider's icon.
  final String iconKey;

  /// Reads one provider from its configuration [map], taking the identity
  /// provider's side from [metadata] (its parsed metadata document) where the
  /// map does not configure it.
  factory TomSamlProviderConfig.fromMap(
    String id,
    Map<Object?, Object?> map, {
    TomSamlIdpMetadata? metadata,
  }) {
    String? optional(String key) {
      final value = map[key];
      if (value == null || '$value'.isEmpty) return null;
      return '$value';
    }

    String required(String key, [String? fromMetadata]) {
      final value = optional(key) ?? fromMetadata;
      if (value == null) {
        throw TomSamlException(
          map['metadataUrl'] != null && metadata == null
              ? 'saml.config.metadata_not_loaded'
              : 'saml.config.missing_value',
          map['metadataUrl'] != null && metadata == null
              ? "SAML provider '$id' takes '$key' from its metadata document; "
                    'read the providers with TomSamlProviders.load, which '
                    'fetches it.'
              : "SAML provider '$id' is missing the required setting '$key'.",
          parameters: {'provider': id, 'key': key},
        );
      }
      return value;
    }

    final issuer = required('issuer', metadata?.entityId);
    if (metadata != null &&
        optional('issuer') != null &&
        metadata.entityId != optional('issuer')) {
      throw TomSamlException(
        'saml.config.metadata_issuer_mismatch',
        "The metadata of SAML provider '$id' describes the entity "
            "'${metadata.entityId}', but the provider is configured for "
            "'${optional('issuer')}'.",
        parameters: {'provider': id},
      );
    }

    final certificates = <String>[
      ..._stringsOf(id, 'idpCertificates', map['idpCertificates']),
      for (final file in _stringsOf(
        id,
        'idpCertificateFiles',
        map['idpCertificateFiles'],
      ))
        _readFile(id, file),
    ];
    final signingKeys = [
      for (final certificate
          in certificates.isEmpty
              ? metadata?.signingCertificates ?? const <String>[]
              : certificates)
        TomSamlCertificates.publicKeyOf(id, certificate),
    ];
    if (signingKeys.isEmpty) {
      throw TomSamlException(
        'saml.config.no_idp_certificate',
        "SAML provider '$id' configures no identity-provider signing "
            'certificate, so no response could ever be verified.',
        parameters: {'provider': id},
      );
    }

    final keyFile = optional('spSigningKeyFile');
    final certificateFile = optional('spCertificateFile');
    return TomSamlProviderConfig(
      id: id,
      issuer: issuer,
      ssoUrl: required('ssoUrl', metadata?.ssoRedirectUrl),
      idpSigningKeys: List.unmodifiable(signingKeys),
      spEntityId: required('spEntityId'),
      acsUrl: required('acsUrl'),
      redirectUri: required('redirectUri'),
      nameIdFormat: optional('nameIdFormat'),
      subjectAttribute: optional('subjectAttribute'),
      usernameAttribute: optional('usernameAttribute'),
      displayNameAttribute: optional('displayNameAttribute'),
      requireSignedAssertion: '${map['requireSignedAssertion']}' == 'true',
      spSigningKey: keyFile == null
          ? null
          : TomSamlCertificates.privateKeyOf(id, _readFile(id, keyFile)),
      spCertificate: certificateFile == null
          ? null
          : TomSamlCertificates.base64Of(_readFile(id, certificateFile)),
      provisioning: map['provisioning'] == null
          ? TomOAuthProvisioning.autoProvision
          : TomOAuthProvisioning.parse('${map['provisioning']}'),
      roleMapping: TomExternalRoleMapping.fromMap(id, map),
      clockSkew: map['clockSkewSeconds'] == null
          ? TomOAuthProviderConfig.defaultClockSkew
          : Duration(seconds: int.tryParse('${map['clockSkewSeconds']}') ?? 60),
      displayNameKey:
          optional('displayNameKey') ??
          '${TomOAuthProviderDto.resourceScope}.$id.name',
      iconKey:
          optional('iconKey') ??
          '${TomOAuthProviderDto.resourceScope}.$id.icon',
    );
  }

  static List<String> _stringsOf(String id, String key, Object? raw) {
    if (raw == null) return const [];
    if (raw is List) return [for (final value in raw) '$value'];
    return ['$raw'];
  }

  static String _readFile(String id, String path) {
    try {
      return File(path).readAsStringSync();
    } catch (error) {
      throw TomSamlException(
        'saml.config.unreadable_file',
        "SAML provider '$id' names the file $path, which cannot be read.",
        parameters: {'provider': id, 'path': path},
        rootException: error,
      );
    }
  }

  @override
  TomOAuthProviderDto toDto() => TomOAuthProviderDto(
    id: id,
    displayNameKey: displayNameKey,
    iconKey: iconKey,
  );

  @override
  String toString() => 'TomSamlProviderConfig($id -> $issuer)';
}

/// Reading the certificates and keys a SAML configuration names.
abstract final class TomSamlCertificates {
  /// The RSA public key of [certificate] — an X.509 certificate as PEM or as
  /// the bare base64 DER metadata documents carry.
  static pc.RSAPublicKey publicKeyOf(String providerId, String certificate) {
    try {
      return jwt.RSAPublicKey.cert(_pem(certificate)).key;
    } catch (error) {
      throw TomSamlException(
        'saml.config.unreadable_certificate',
        "A signing certificate of SAML provider '$providerId' is not an X.509 "
            'certificate holding an RSA key.',
        parameters: {'provider': providerId},
        rootException: error,
      );
    }
  }

  /// The RSA private key in [pem] (PKCS#8 or PKCS#1).
  static pc.RSAPrivateKey privateKeyOf(String providerId, String pem) {
    try {
      return jwt.RSAPrivateKey(pem).key;
    } catch (error) {
      throw TomSamlException(
        'saml.config.unreadable_key',
        "The request signing key of SAML provider '$providerId' is not an RSA "
            'private key in PEM.',
        parameters: {'provider': providerId},
        rootException: error,
      );
    }
  }

  /// [certificate]'s base64 DER body, without PEM armour or whitespace.
  static String base64Of(String certificate) => certificate
      .replaceAll(RegExp(r'-----[A-Z ]+-----'), '')
      .replaceAll(RegExp(r'\s+'), '');

  static String _pem(String certificate) {
    final body = base64Of(certificate);
    final lines = [
      for (var i = 0; i < body.length; i += 64)
        body.substring(i, i + 64 > body.length ? body.length : i + 64),
    ];
    return '-----BEGIN CERTIFICATE-----\n${lines.join('\n')}\n'
        '-----END CERTIFICATE-----\n';
  }
}

/// What an identity provider's metadata document says about it.
class TomSamlIdpMetadata {
  /// Creates the parsed metadata.
  const TomSamlIdpMetadata({
    required this.entityId,
    required this.ssoRedirectUrl,
    required this.signingCertificates,
  });

  /// The identity provider's entity id.
  final String entityId;

  /// Its HTTP-Redirect single sign-on service, or `null` when it offers none.
  final String? ssoRedirectUrl;

  /// Its signing certificates, base64 DER.
  final List<String> signingCertificates;

  /// Parses an `EntityDescriptor` (or the first one in an `EntitiesDescriptor`)
  /// with an `IDPSSODescriptor`.
  ///
  /// Throws `saml.config.malformed_metadata` for anything else.
  factory TomSamlIdpMetadata.parse(String providerId, String xml) {
    XmlElement? descriptor;
    try {
      if (xml.toUpperCase().contains('<!DOCTYPE')) {
        // throws-outside-family: programmer error — caught just below and
        // reported as the keyed `saml.config.malformed_metadata`.
        throw const FormatException('a document type declaration');
      }
      final document = XmlDocument.parse(xml);
      descriptor = document.descendantElements.firstWhere(
        (e) =>
            e.name.local == 'EntityDescriptor' &&
            e.name.namespaceUri == TomSamlNames.metadata &&
            e.childElements.any((c) => c.name.local == 'IDPSSODescriptor'),
      );
    } catch (error) {
      throw TomSamlException(
        'saml.config.malformed_metadata',
        "The metadata of SAML provider '$providerId' is not an identity "
            'provider EntityDescriptor.',
        parameters: {'provider': providerId},
        rootException: error,
      );
    }
    final idp = descriptor.childElements.firstWhere(
      (c) => c.name.local == 'IDPSSODescriptor',
    );
    String? redirect;
    for (final service in idp.childElements.where(
      (c) => c.name.local == 'SingleSignOnService',
    )) {
      if (service.getAttribute('Binding') == TomSamlNames.redirectBinding) {
        redirect = service.getAttribute('Location');
        break;
      }
    }
    final certificates = <String>[
      for (final key in idp.childElements.where(
        (c) => c.name.local == 'KeyDescriptor',
      ))
        if ((key.getAttribute('use') ?? 'signing') == 'signing')
          for (final certificate in key.descendantElements.where(
            (e) =>
                e.name.local == 'X509Certificate' &&
                e.name.namespaceUri == TomXmlDsig.namespace,
          ))
            TomSamlCertificates.base64Of(certificate.innerText),
    ];
    return TomSamlIdpMetadata(
      entityId: descriptor.getAttribute('entityID') ?? '',
      ssoRedirectUrl: redirect,
      signingCertificates: List.unmodifiable(certificates),
    );
  }
}

/// The configured SAML identity providers.
///
/// Installed as a bean so a deployment's start-up can load them once —
/// fetching metadata — and every flow uses that set:
///
/// ```dart
/// TomBean.withType<TomSamlProviders>(await TomSamlProviders.load());
/// ```
class TomSamlProviders {
  /// The configuration path the provider set is read from.
  static const String configurationKey = 'saml.providers';

  /// The configured providers, keyed by id.
  final Map<String, TomSamlProviderConfig> providers;

  /// Creates a provider set over an explicit map.
  TomSamlProviders(Map<String, TomSamlProviderConfig> providers)
    : providers = Map.unmodifiable(providers);

  /// The installed [TomSamlProviders] bean, or `null`.
  static TomSamlProviders? resolve() {
    final installed = TomBean.getBeanByType(TomSamlProviders);
    return installed is TomSamlProviders ? installed : null;
  }

  /// Reads the provider set from the configuration tree, without fetching any
  /// metadata: a provider that relies on `metadataUrl` for a value it does not
  /// configure is refused with `saml.config.metadata_not_loaded`. Answers an
  /// empty set when the key is absent.
  factory TomSamlProviders.fromConfiguration([
    TomServerConfigResourceProvider? config,
  ]) {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    if (!provider.exists(configurationKey)) return TomSamlProviders(const {});
    return TomSamlProviders({
      for (final entry in _providerMaps(provider.get(configurationKey)).entries)
        entry.key: TomSamlProviderConfig.fromMap(entry.key, entry.value),
    });
  }

  /// Reads the provider set from the configuration tree, fetching the
  /// metadata document of every provider that names a `metadataUrl`.
  static Future<TomSamlProviders> load({
    TomServerConfigResourceProvider? config,
    TomOAuthTokenTransport? transport,
  }) async {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    if (!provider.exists(configurationKey)) return TomSamlProviders(const {});
    return discover(provider.get(configurationKey), transport: transport);
  }

  /// The provider set [raw] configures, with each `metadataUrl` fetched and
  /// parsed. Values a provider configures explicitly win over its metadata.
  ///
  /// The metadata is trusted because of where it was fetched from — the
  /// configured address — so name an `https` address. A document that cannot
  /// be fetched fails with `saml.config.metadata_failed`, at start-up.
  static Future<TomSamlProviders> discover(
    Object? raw, {
    TomOAuthTokenTransport? transport,
  }) async {
    final http = transport ?? TomOAuthTokenTransport.resolve();
    final parsed = <String, TomSamlProviderConfig>{};
    for (final entry in _providerMaps(raw).entries) {
      final url = entry.value['metadataUrl'];
      TomSamlIdpMetadata? metadata;
      if (url != null) {
        final String body;
        try {
          body = await http.getJson(Uri.parse('$url'), const {
            'Accept': 'application/samlmetadata+xml, application/xml',
          });
        } catch (error) {
          throw TomSamlException(
            'saml.config.metadata_failed',
            "The metadata of SAML provider '${entry.key}' could not be read "
                'from $url: $error',
            parameters: {'provider': entry.key, 'url': '$url'},
            rootException: error,
          );
        }
        metadata = TomSamlIdpMetadata.parse(entry.key, body);
      }
      parsed[entry.key] = TomSamlProviderConfig.fromMap(
        entry.key,
        entry.value,
        metadata: metadata,
      );
    }
    return TomSamlProviders(parsed);
  }

  static Map<String, Map<Object?, Object?>> _providerMaps(Object? raw) {
    if (raw is! Map) {
      throw TomSamlException(
        'saml.config.not_a_map',
        "Configuration '$configurationKey' must be a map of provider id to "
            'provider settings, but was a ${raw.runtimeType}.',
      );
    }
    return {
      for (final entry in raw.entries)
        '${entry.key}': entry.value is Map
            ? entry.value as Map<Object?, Object?>
            : throw TomSamlException(
                'saml.config.provider_not_a_map',
                "SAML provider '${entry.key}' must be a map of settings, but "
                    'was a ${entry.value.runtimeType}.',
                parameters: {'provider': '${entry.key}'},
              ),
    };
  }

  /// Whether no provider is configured.
  bool get isEmpty => providers.isEmpty;

  /// The providers as client-facing descriptors, in configuration order.
  List<TomOAuthProviderDto> get descriptors =>
      List.unmodifiable(providers.values.map((p) => p.toDto()));

  /// The provider configured under [id], or `null`.
  TomSamlProviderConfig? lookup(String id) => providers[id];

  /// The provider configured under [id]; throws `saml.config.unknown_provider`
  /// for any other id.
  TomSamlProviderConfig operator [](String id) {
    final provider = providers[id];
    if (provider == null) {
      throw TomSamlException(
        'saml.config.unknown_provider',
        "No SAML provider is configured under the id '$id'.",
        parameters: {'provider': id},
        clientThrow: true,
      );
    }
    return provider;
  }

  @override
  String toString() => 'TomSamlProviders(${providers.keys.join(', ')})';
}
