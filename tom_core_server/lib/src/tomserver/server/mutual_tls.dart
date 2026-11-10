/// Mutual TLS between services: a client certificate, verified against the
/// deployment's client CA, authenticates its caller as a service principal.
///
/// ## How a certificate becomes a principal
///
/// 1. The server asks every TLS client for a certificate and verifies a
///    presented one against the configured client CA; a certificate the CA did
///    not issue fails the handshake.
/// 2. A verified certificate is looked up by the SHA-256 fingerprint of its
///    DER encoding in [TomMutualTls.services]. Only a listed certificate names
///    a principal: a CA can issue certificates for many purposes, and being
///    signed by it is not by itself a grant.
/// 3. The authentication middleware uses that principal for a request that
///    carries no bearer token and no API key. On a path under one of
///    [TomMutualTls.requiredPaths] it uses only that principal, and answers
///    `401` (`server.mutual_tls.required`) when the request presented no
///    listed certificate — the paths only services may call.
///
/// The client half is [TomMutualTls.clientContext] and
/// [TomMutualTlsClientFactory]: outgoing framework calls that present this
/// service's certificate.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../ratelimit/rate_limit.dart';

/// Thrown when the mutual-TLS settings cannot be applied, and when a request
/// to a path that requires a client certificate presents none.
class TomMutualTlsException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomMutualTlsException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow,
  });
}

/// The connection of a TLS request, with the client certificate it presented.
///
/// What [TomMutualTls.serve] puts on every request in place of the plain
/// connection information, under [TomClientAddress.connectionInfoKey], so
/// everything that reads the peer address keeps working.
class TomTlsConnectionInfo implements HttpConnectionInfo {
  /// The connection [info] of a request that presented [certificate].
  TomTlsConnectionInfo(HttpConnectionInfo info, this.certificate)
    : remoteAddress = info.remoteAddress,
      remotePort = info.remotePort,
      localPort = info.localPort;

  @override
  final InternetAddress remoteAddress;

  @override
  final int remotePort;

  @override
  final int localPort;

  /// The verified client certificate, or `null` when none was presented.
  final X509Certificate? certificate;
}

/// The mutual-TLS configuration: the client CA, the certificates that name
/// service principals, and the paths only services may call.
final class TomMutualTls {
  /// Mutual TLS trusting the client certificates [clientAuthoritiesPem]
  /// issued, mapping [services] (SHA-256 fingerprint → principal), and
  /// requiring a listed certificate under [requiredPaths].
  TomMutualTls({
    required this.clientAuthoritiesPem,
    Map<String, TomPrincipal> services = const {},
    this.requiredPaths = const [],
  }) : services = {
         for (final MapEntry(:key, :value) in services.entries)
           normalizeFingerprint(key): value,
       };

  /// The PEM certificates of the CAs client certificates are verified
  /// against.
  final String clientAuthoritiesPem;

  /// The service principal each listed certificate names, by its normalised
  /// SHA-256 fingerprint ([normalizeFingerprint]).
  final Map<String, TomPrincipal> services;

  /// The path prefixes a request may only reach with a listed certificate.
  final List<String> requiredPaths;

  /// The configuration key holding the settings — see [configure].
  static const String configurationKey = 'mutualTls';

  /// The installed configuration, or `null` when mutual TLS is off.
  static TomMutualTls? current;

  /// Installs [current] from [config]:
  ///
  /// ```yaml
  /// mutualTls:
  ///   clientCa: |              # PEM of the CA(s) client certificates come from
  ///     -----BEGIN CERTIFICATE-----
  ///     ...
  ///   services:                # SHA-256 fingerprint of a client certificate
  ///     "16:41:54:...:E4:A2":
  ///       id: orders-service
  ///       roles: [service]
  ///   requiredPaths: [/internal]
  ///   client:                  # this service's own certificate, presented on
  ///     certificateChain: |    # outgoing framework calls
  ///       -----BEGIN CERTIFICATE-----
  ///     privateKey: |
  ///       -----BEGIN PRIVATE KEY-----
  ///     trustedCa: |           # optional: the CA the callees' certificates
  ///       -----BEGIN CERTIFICATE-----   # come from
  /// ```
  ///
  /// Throws `server.mutual_tls.config.invalid` for a value of the wrong shape,
  /// before anything is applied.
  static void configure(Object? config) {
    if (config is! Map) {
      _invalid('The mutual-TLS settings must be a map.');
    }
    final known = {'clientCa', 'services', 'requiredPaths', 'client'};
    final unknown = config.keys
        .map((k) => '$k')
        .where((k) => !known.contains(k));
    if (unknown.isNotEmpty) {
      _invalid('Unknown mutual-TLS settings: ${unknown.join(', ')}.');
    }
    final ca = config['clientCa'];
    if (ca is! String || !ca.contains('BEGIN CERTIFICATE')) {
      _invalid("The mutual-TLS 'clientCa' must be a PEM certificate.");
    }
    final services = <String, TomPrincipal>{};
    final rawServices = config['services'] ?? const {};
    if (rawServices is! Map) {
      _invalid("The mutual-TLS 'services' must map fingerprints to services.");
    }
    for (final MapEntry(:key, :value) in rawServices.entries) {
      final fingerprint = normalizeFingerprint('$key');
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
        _invalid("'$key' is not a SHA-256 fingerprint.");
      }
      if (value is! Map || value['id'] is! String) {
        _invalid("The service of '$key' needs an 'id'.");
      }
      final roles = value['roles'] ?? const [];
      if (roles is! List) _invalid("The 'roles' of '$key' must be a list.");
      services[fingerprint] = servicePrincipal(
        '${value['id']}',
        username: value['username'] is String ? value['username'] : null,
        roles: [for (final role in roles) '$role'],
      );
    }
    final required = config['requiredPaths'] ?? const [];
    if (required is! List) {
      _invalid("The mutual-TLS 'requiredPaths' must be a list of paths.");
    }
    final client = config['client'];
    SecurityContext? clientContext;
    if (client != null) {
      if (client is! Map ||
          client['certificateChain'] is! String ||
          client['privateKey'] is! String) {
        _invalid(
          "The mutual-TLS 'client' needs a 'certificateChain' and a "
          "'privateKey'.",
        );
      }
      clientContext = TomMutualTls.clientContext(
        certificateChainPem: client['certificateChain'] as String,
        privateKeyPem: client['privateKey'] as String,
        trustedCaPem: client['trustedCa'] as String?,
      );
    }
    current = TomMutualTls(
      clientAuthoritiesPem: ca,
      services: services,
      requiredPaths: [for (final path in required) '$path'],
    );
    if (clientContext != null) {
      TomHttpClientFactory.setGlobalHttpClientFactory(
        TomMutualTlsClientFactory(clientContext),
      );
    }
  }

  static Never _invalid(String message) =>
      throw TomMutualTlsException('server.mutual_tls.config.invalid', message);

  /// A service principal: authenticated, holding [roles], named [id].
  static TomPrincipal servicePrincipal(
    String id, {
    String? username,
    List<String> roles = const [],
  }) => TomPrincipal(
    user: TomUser(id: id, username: username ?? id),
    aci: TomAccessControlInformation(roles: roles),
    authenticated: true,
  );

  /// [fingerprint] in the form [services] is keyed by: lower-case hex, no
  /// separators — so `16:41:54:9C:...` from `openssl x509 -fingerprint` and
  /// `1641549c...` name the same certificate.
  static String normalizeFingerprint(String fingerprint) =>
      fingerprint.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toLowerCase();

  /// The SHA-256 fingerprint of [certificate]'s DER encoding.
  static String fingerprintOf(X509Certificate certificate) =>
      sha256.convert(certificate.der).toString();

  /// The SHA-256 fingerprint of the first certificate in [pem] — what to
  /// list in [services] for a client certificate file.
  ///
  /// Throws `server.mutual_tls.config.invalid` when [pem] holds no
  /// certificate.
  static String fingerprintOfPem(String pem) {
    final match = RegExp(
      r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----',
    ).firstMatch(pem);
    if (match == null) _invalid('The PEM text holds no certificate.');
    final der = base64.decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
    return sha256.convert(der).toString();
  }

  /// The verified client certificate [request] presented, or `null`.
  static X509Certificate? certificateOf(Request request) {
    final info = request.context[TomClientAddress.connectionInfoKey];
    return info is TomTlsConnectionInfo ? info.certificate : null;
  }

  /// The service principal [request]'s certificate names, or `null`.
  TomPrincipal? principalFor(Request request) {
    final certificate = certificateOf(request);
    return certificate == null ? null : services[fingerprintOf(certificate)];
  }

  /// Whether [request]'s path is one only a listed certificate may reach.
  bool requires(Request request) {
    final path = request.requestedUri.path;
    return requiredPaths.any(
      (prefix) =>
          path == prefix ||
          path.startsWith(prefix.endsWith('/') ? prefix : '$prefix/'),
    );
  }

  /// The error a request to a [requires] path without a listed certificate
  /// is refused with.
  static TomMutualTlsException certificateRequired(Request request) =>
      TomMutualTlsException(
        'server.mutual_tls.required',
        'This path is only served to services presenting a known client '
            'certificate.',
        parameters: {'path': request.requestedUri.path},
        clientThrow: true,
      );

  /// [context], the server's TLS context, also asking for and verifying
  /// client certificates against [clientAuthoritiesPem].
  void applyTo(SecurityContext context) {
    final authorities = utf8.encode(clientAuthoritiesPem);
    context
      ..setTrustedCertificatesBytes(authorities)
      ..setClientAuthoritiesBytes(authorities);
  }

  /// Binds a TLS server on [address]:[port] that asks every client for a
  /// certificate and serves [handler], each request carrying its certificate
  /// in a [TomTlsConnectionInfo].
  Future<HttpServer> serve(
    Handler handler,
    Object address,
    int port, {
    required SecurityContext securityContext,
    bool shared = false,
    String? poweredByHeader,
  }) async {
    applyTo(securityContext);
    final server = await HttpServer.bindSecure(
      address,
      port,
      securityContext,
      requestClientCertificate: true,
      shared: shared,
    );
    // The certificate is put on the request here, from the `HttpRequest` it
    // came with: shelf's adapter puts its own connection information on a
    // request (read lazily, of a type of its own) and nothing of the TLS
    // session, so a wrapper around the `HttpRequest` would not reach the
    // handler.
    runZonedGuarded(
      () => server.listen(
        (httpRequest) => handleRequest(
          httpRequest,
          (request) => handler(
            request.change(
              context: {
                TomClientAddress.connectionInfoKey: TomTlsConnectionInfo(
                  request.context[TomClientAddress.connectionInfoKey]!
                      as HttpConnectionInfo,
                  httpRequest.certificate,
                ),
              },
            ),
          ),
          poweredByHeader: poweredByHeader,
        ),
      ),
      (error, stack) => tomLog.error(
        'Asynchronous error in a mutual-TLS handler: $error\n$stack',
      ),
    );
    return server;
  }

  /// A client TLS context presenting [certificateChainPem] (with
  /// [privateKeyPem]) and, when [trustedCaPem] is given, trusting the servers
  /// that CA issued in addition to the platform's roots.
  static SecurityContext clientContext({
    required String certificateChainPem,
    required String privateKeyPem,
    String? trustedCaPem,
  }) {
    final context = SecurityContext(withTrustedRoots: true)
      ..useCertificateChainBytes(utf8.encode(certificateChainPem))
      ..usePrivateKeyBytes(utf8.encode(privateKeyPem));
    if (trustedCaPem != null) {
      context.setTrustedCertificatesBytes(utf8.encode(trustedCaPem));
    }
    return context;
  }
}

/// The outgoing framework client presenting this service's certificate:
/// a [TomResilientClient] over an `HttpClient` with [context].
///
/// [TomMutualTls.configure] installs it as the global client factory when the
/// settings carry a `client` section.
class TomMutualTlsClientFactory implements TomHttpClientAbstractFactory {
  /// A factory whose clients use [context].
  TomMutualTlsClientFactory(this.context);

  /// The client TLS context — see [TomMutualTls.clientContext].
  final SecurityContext context;

  @override
  http.Client getClient() =>
      TomResilientClient(IOClient(HttpClient(context: context)));
}
