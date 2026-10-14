/// The resources SCIM 2.0 provisions — users and groups — and the store they
/// are kept in.
///
/// A resource is kept as the JSON document the identity provider sent, minus
/// the attributes the service provider owns (`id`, `meta`, and a user's
/// `groups`, which are derived from the groups). Keeping the document rather
/// than a fixed set of columns is what lets every attribute an identity
/// provider maps — `title`, `phoneNumbers`, the enterprise extension — survive
/// a round trip, which is what the identity provider's own reconciliation
/// reads back.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// The SCIM schema and message identifiers this service uses.
abstract final class TomScimSchemas {
  /// The core User schema.
  static const String user = 'urn:ietf:params:scim:schemas:core:2.0:User';

  /// The core Group schema.
  static const String group = 'urn:ietf:params:scim:schemas:core:2.0:Group';

  /// The enterprise User extension.
  static const String enterpriseUser =
      'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User';

  /// A list response.
  static const String listResponse =
      'urn:ietf:params:scim:api:messages:2.0:ListResponse';

  /// A PATCH request.
  static const String patchOp = 'urn:ietf:params:scim:api:messages:2.0:PatchOp';

  /// An error response.
  static const String error = 'urn:ietf:params:scim:api:messages:2.0:Error';

  /// The service provider configuration.
  static const String serviceProviderConfig =
      'urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig';

  /// A resource type description.
  static const String resourceType =
      'urn:ietf:params:scim:schemas:core:2.0:ResourceType';

  /// A schema description.
  static const String schema = 'urn:ietf:params:scim:schemas:core:2.0:Schema';
}

/// The two resource types this service provisions.
enum TomScimResourceType {
  /// A user account.
  user('User', 'Users', TomScimSchemas.user, 'userName'),

  /// A group of users.
  group('Group', 'Groups', TomScimSchemas.group, 'displayName');

  const TomScimResourceType(
    this.resourceName,
    this.endpoint,
    this.schema,
    this.nameAttribute,
  );

  /// The resource type's name — `meta.resourceType`.
  final String resourceName;

  /// The path segment under the SCIM base — `Users` or `Groups`.
  final String endpoint;

  /// The core schema URN.
  final String schema;

  /// The attribute that names a resource uniquely within its type, compared
  /// case-insensitively: `userName` for a user, `displayName` for a group.
  final String nameAttribute;
}

/// A SCIM request that cannot be served, carrying the HTTP status and the SCIM
/// error type (RFC 7644, section 3.12) it is answered with.
///
/// | Key | Status | `scimType` |
/// | --- | ------ | ---------- |
/// | `scim.not_found` | 404 | — |
/// | `scim.uniqueness` | 409 | `uniqueness` |
/// | `scim.invalid_filter` | 400 | `invalidFilter` |
/// | `scim.invalid_path` | 400 | `invalidPath` |
/// | `scim.invalid_value` | 400 | `invalidValue` |
/// | `scim.invalid_syntax` | 400 | `invalidSyntax` |
/// | `scim.no_target` | 400 | `noTarget` |
/// | `scim.mutability` | 400 | `mutability` |
/// | `scim.unauthorized` | 401 | — |
/// | `scim.not_enabled` | 404 | — |
///
/// `clientThrow` is `true`: the message describes the caller's own request,
/// and the identity provider shows it to the administrator who configured it.
class TomScimException extends TomServerException {
  /// Creates the exception.
  TomScimException(
    super.key,
    super.defaultUserMessage, {
    required this.status,
    this.scimType,
    super.parameters,
  }) : super(clientThrow: true);

  /// The HTTP status the request is answered with.
  final int status;

  /// The SCIM error type, or `null` for none.
  final String? scimType;

  /// The SCIM error body (RFC 7644, section 3.12).
  Map<String, Object?> toJson() => {
    'schemas': [TomScimSchemas.error],
    'status': '$status',
    'scimType': ?scimType,
    'detail': clientMessage('The request could not be served.'),
  };
}

/// One stored resource: its id, the document, and its lifecycle instants.
class TomScimResource {
  /// Creates a resource.
  const TomScimResource({
    required this.id,
    required this.type,
    required this.document,
    required this.created,
    required this.lastModified,
    required this.version,
  });

  /// The service provider's id for the resource — stable, never reused.
  final String id;

  /// Whether this is a user or a group.
  final TomScimResourceType type;

  /// The attributes the client manages, as JSON; never `id`, `meta`, or a
  /// user's `groups`.
  final Map<String, Object?> document;

  /// When the resource was created.
  final DateTime created;

  /// When it last changed.
  final DateTime lastModified;

  /// Increments with every change; published as `meta.version`.
  final int version;

  /// The resource's name attribute — `userName` or `displayName`.
  String get name => '${attribute(type.nameAttribute) ?? ''}';

  /// [name] as uniqueness compares it.
  String get nameKey => name.toLowerCase();

  /// The `externalId` the identity provider assigned, or `null`.
  String? get externalId {
    final value = attribute('externalId');
    return value == null ? null : '$value';
  }

  /// Whether a user is active. A user with no `active` attribute is active;
  /// a group always is.
  bool get active => attribute('active') != false;

  /// The top-level attribute [name], looked up case-insensitively, as SCIM
  /// attribute names are.
  Object? attribute(String name) {
    final wanted = name.toLowerCase();
    for (final entry in document.entries) {
      if (entry.key.toLowerCase() == wanted) return entry.value;
    }
    return null;
  }

  @override
  String toString() => 'TomScimResource(${type.resourceName} $id $name)';
}

/// Where provisioned resources are kept.
///
/// Uniqueness of the name attribute is the service's to check, through
/// [findByName], before it writes; a store may enforce it as well.
abstract interface class TomScimStore {
  /// Stores [document] as a new resource of [type] and answers it with its
  /// assigned id.
  Future<TomScimResource> create(
    TomScimResourceType type,
    Map<String, Object?> document,
  );

  /// The resource [id] of [type], or `null`.
  Future<TomScimResource?> read(TomScimResourceType type, String id);

  /// The resource of [type] whose name attribute equals [name]
  /// case-insensitively, or `null`.
  Future<TomScimResource?> findByName(TomScimResourceType type, String name);

  /// Every resource of [type], in id order.
  Future<List<TomScimResource>> list(TomScimResourceType type);

  /// Replaces the document of resource [id] and answers the result, or `null`
  /// when there is no such resource.
  Future<TomScimResource?> replace(
    TomScimResourceType type,
    String id,
    Map<String, Object?> document,
  );

  /// Deletes resource [id]; answers whether it existed.
  Future<bool> delete(TomScimResourceType type, String id);
}

/// A [TomScimStore] in one process's memory — for a single node, a test, or a
/// deployment that mirrors the resources into its own user table through the
/// service's hooks.
///
/// Kept per tenant: the resources a request reaches are those of the tenant in
/// context ([TomTenantContext.currentId]), each tenant with its own id
/// sequence, so two tenants' identity providers see only their own users and
/// groups — the same partition [TomSqlScimStore] gets from tenancy's routing.
/// Without tenancy there is one partition.
class TomMemoryScimStore implements TomScimStore {
  final Map<String?, _TomScimPartition> _partitions = {};

  /// The resources of the tenant in context.
  _TomScimPartition get _partition => _partitions.putIfAbsent(
    TomTenantContext.currentId,
    _TomScimPartition.new,
  );

  Map<String, TomScimResource> get _resources => _partition.resources;

  DateTime _now() => DateTime.now().toUtc();

  @override
  Future<TomScimResource> create(
    TomScimResourceType type,
    Map<String, Object?> document,
  ) async {
    final now = _now();
    final resource = TomScimResource(
      id: '${++_partition.sequence}',
      type: type,
      document: Map.unmodifiable(document),
      created: now,
      lastModified: now,
      version: 1,
    );
    _resources[resource.id] = resource;
    return resource;
  }

  @override
  Future<TomScimResource?> read(TomScimResourceType type, String id) async {
    final found = _resources[id];
    return found?.type == type ? found : null;
  }

  @override
  Future<TomScimResource?> findByName(
    TomScimResourceType type,
    String name,
  ) async {
    final key = name.toLowerCase();
    for (final resource in _resources.values) {
      if (resource.type == type && resource.nameKey == key) return resource;
    }
    return null;
  }

  @override
  Future<List<TomScimResource>> list(TomScimResourceType type) async => [
    for (final resource in _resources.values)
      if (resource.type == type) resource,
  ];

  @override
  Future<TomScimResource?> replace(
    TomScimResourceType type,
    String id,
    Map<String, Object?> document,
  ) async {
    final existing = await read(type, id);
    if (existing == null) return null;
    final replaced = TomScimResource(
      id: id,
      type: type,
      document: Map.unmodifiable(document),
      created: existing.created,
      lastModified: _now(),
      version: existing.version + 1,
    );
    _resources[id] = replaced;
    return replaced;
  }

  @override
  Future<bool> delete(TomScimResourceType type, String id) async {
    final existing = await read(type, id);
    if (existing == null) return false;
    _resources.remove(id);
    return true;
  }
}

/// One tenant's resources in a [TomMemoryScimStore].
class _TomScimPartition {
  final Map<String, TomScimResource> resources = {};
  int sequence = 0;
}
