/// How a request that carries no tenant claim names its tenant: by its host,
/// or by a header.
///
/// The token's `tenant` claim always comes first and is not a resolver: a
/// request that has authenticated is for its token's tenant, and the
/// resolvers only answer for the requests that have not — the login, the
/// public page, the identity provider's redirect. `TomTenancy.resolveRequest`
/// combines the two.
///
/// A header is the weakest of the sources, because a client chooses it
/// freely; it is safe here because it only ever *proposes* a tenant. Data stays
/// closed until a login in that tenant succeeds, and once a token exists its
/// claim wins and a contradicting header is refused.
library;

import 'package:shelf/shelf.dart';

/// Reads a tenant id from a request, or answers `null`.
abstract interface class TomTenantResolver {
  /// The tenant [request] names, or `null` when it names none.
  String? resolve(Request request);
}

/// Names the tenant by host: an exact entry in [hosts], or the first label
/// of a host under [suffix] — `acme.app.example.com` under `app.example.com`.
class TomTenantHostResolver implements TomTenantResolver {
  /// Creates the resolver.
  const TomTenantHostResolver({this.suffix, this.hosts = const {}});

  /// The domain tenants are subdomains of, or `null`.
  final String? suffix;

  /// Host → tenant, for tenants on a domain of their own.
  final Map<String, String> hosts;

  @override
  String? resolve(Request request) {
    final host = request.requestedUri.host.toLowerCase();
    final exact = hosts[host];
    if (exact != null) return exact;
    final domain = suffix?.toLowerCase();
    if (domain == null || !host.endsWith('.$domain')) return null;
    final label = host.substring(0, host.length - domain.length - 1);
    return label.isEmpty || label.contains('.') ? null : label;
  }
}

/// Names the tenant by a request header — [defaultHeader] unless configured.
class TomTenantHeaderResolver implements TomTenantResolver {
  /// Creates the resolver.
  const TomTenantHeaderResolver({this.header = defaultHeader});

  /// The header read when none is configured.
  static const String defaultHeader = 'X-Tenant-Id';

  /// The header naming the tenant.
  final String header;

  @override
  String? resolve(Request request) {
    final value = request.headers[header.toLowerCase()]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

/// The outcome of resolving a request's tenant: a tenant, none, or a
/// rejection to answer with.
class TomTenantResolution {
  /// The request is for [tenant].
  const TomTenantResolution.of(String this.tenant)
    : status = null,
      key = null,
      message = null;

  /// The request names no tenant.
  const TomTenantResolution.none()
    : tenant = null,
      status = null,
      key = null,
      message = null;

  /// The request is refused with [status], keyed [key].
  const TomTenantResolution.rejected(
    int this.status,
    String this.key,
    String this.message,
  ) : tenant = null;

  /// The tenant, or `null`.
  final String? tenant;

  /// The HTTP status of a rejection, or `null`.
  final int? status;

  /// The key of a rejection, or `null`.
  final String? key;

  /// The message of a rejection, or `null`.
  final String? message;

  /// Whether the request is refused.
  bool get isRejected => status != null;
}
