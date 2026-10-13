/// The SCIM 2.0 service provider (RFC 7643 and RFC 7644), independent of HTTP:
/// users and groups created, read, queried, replaced, patched and deleted by an
/// identity provider, and the access consequences of each change.
///
/// ## Deprovisioning revokes access
///
/// A provisioning change that takes access away is applied to the sessions the
/// user already holds, not only to the next login. Through [TomScimService.revoke]
/// — `TomCacheInvalidator.revokePrincipal` by default — every token the user
/// holds is refused on every node within the invalidation channel's staleness
/// bound, and the principals cached for them are dropped, when:
///
/// | Change | Revoked |
/// | ------ | ------- |
/// | a user is deactivated (`active` becomes `false`) | that user |
/// | a user is deleted | that user |
/// | a user's `userName` changes | the old name |
/// | a group's membership changes | every member added or removed |
/// | a group is renamed or deleted | every member |
///
/// A group change revokes because the roles a session carries are derived from
/// its groups (`TomScimIdentityDirectory`): the client re-authenticates and
/// receives a token with the roles the groups now grant. A deactivated user's
/// next login is refused by that directory.
///
/// ## What is supported
///
/// The subset identity providers use — Microsoft Entra ID and Okta among them:
/// the `/Users` and `/Groups` endpoints with GET, POST, PUT, PATCH and DELETE;
/// filtering (see `scim_filter.dart`), paging with `startIndex` and `count`,
/// `attributes` and `excludedAttributes`; and the three discovery endpoints.
/// Not supported, and said so in the service provider configuration: bulk
/// operations, sorting, ETags, `/Me`, `.search`, and changing passwords.
library;

import 'dart:convert';

import '../cache/cache_invalidation.dart';
import 'scim_filter.dart';
import 'scim_resource.dart';

/// The SCIM service provider over a [TomScimStore].
class TomScimService {
  /// Creates the service over [store].
  ///
  /// [revoke] withdraws a user's sessions on a deprovisioning change;
  /// `TomCacheInvalidator.revokePrincipal` by default.
  TomScimService(this.store, {Future<void> Function(String username)? revoke})
    : revoke = revoke ?? TomCacheInvalidator.revokePrincipal;

  /// Where the resources are kept.
  final TomScimStore store;

  /// What a deprovisioning change calls for each affected username.
  final Future<void> Function(String username) revoke;

  /// The page size when a query names none.
  static const int defaultCount = 100;

  /// The largest page served; published as `filter.maxResults`.
  static const int maxCount = 200;

  // ---------------------------------------------------------------------------
  // Resources
  // ---------------------------------------------------------------------------

  /// Creates a resource of [type] from the request [body]; answers its
  /// representation.
  Future<Map<String, Object?>> create(
    TomScimResourceType type,
    Object? body,
    String base,
  ) async {
    final document = await _clientDocument(type, body);
    await _requireUniqueName(type, document, exceptId: null);
    final created = await store.create(type, document);
    await _afterChange(type, null, created);
    return _representation(created, base);
  }

  /// The resource [id] of [type]; throws `scim.not_found`.
  Future<Map<String, Object?>> get(
    TomScimResourceType type,
    String id,
    String base, {
    String? attributes,
    String? excludedAttributes,
  }) async {
    final resource = await _require(type, id);
    return _project(
      await _representation(resource, base),
      attributes,
      excludedAttributes,
    );
  }

  /// A page of the resources of [type] matching [filter].
  Future<Map<String, Object?>> list(
    TomScimResourceType type,
    String base, {
    String? filter,
    int? startIndex,
    int? count,
    String? attributes,
    String? excludedAttributes,
  }) async {
    final parsed = filter == null || filter.trim().isEmpty
        ? null
        : TomScimFilter.parse(filter, type);
    final candidates = await _candidates(type, parsed);
    final groups = type == TomScimResourceType.user
        ? await store.list(TomScimResourceType.group)
        : const <TomScimResource>[];
    final matched = <Map<String, Object?>>[];
    for (final resource in candidates) {
      final representation = _representationWith(resource, base, groups);
      if (parsed == null || parsed.matches(representation)) {
        matched.add(representation);
      }
    }
    final start = startIndex == null || startIndex < 1 ? 1 : startIndex;
    final size = count == null || count < 0
        ? defaultCount
        : (count > maxCount ? maxCount : count);
    final page = matched.skip(start - 1).take(size).toList();
    return {
      'schemas': [TomScimSchemas.listResponse],
      'totalResults': matched.length,
      'startIndex': start,
      'itemsPerPage': page.length,
      'Resources': [
        for (final representation in page)
          _project(representation, attributes, excludedAttributes),
      ],
    };
  }

  /// Replaces the resource [id] of [type] with the request [body] (PUT).
  Future<Map<String, Object?>> replace(
    TomScimResourceType type,
    String id,
    Object? body,
    String base,
  ) async {
    final before = await _require(type, id);
    final document = await _clientDocument(type, body);
    return _write(type, before, document, base);
  }

  /// Applies the PATCH request [body] to the resource [id] of [type].
  Future<Map<String, Object?>> patch(
    TomScimResourceType type,
    String id,
    Object? body,
    String base,
  ) async {
    final before = await _require(type, id);
    if (body is! Map || body['Operations'] is! List) {
      throw TomScimException(
        'scim.invalid_syntax',
        'A PATCH request carries an "Operations" list.',
        status: 400,
        scimType: 'invalidSyntax',
      );
    }
    final working = (jsonDecode(jsonEncode(before.document)) as Map)
        .cast<String, Object?>();
    for (final operation in body['Operations'] as List) {
      if (operation is! Map) {
        throw TomScimException(
          'scim.invalid_syntax',
          'Each PATCH operation is an object.',
          status: 400,
          scimType: 'invalidSyntax',
        );
      }
      _TomScimPatch(type).apply(working, operation.cast<String, Object?>());
    }
    final document = await _clientDocument(type, working);
    return _write(type, before, document, base);
  }

  /// Deletes the resource [id] of [type]; throws `scim.not_found`.
  Future<void> delete(TomScimResourceType type, String id) async {
    final before = await _require(type, id);
    await store.delete(type, id);
    if (type == TomScimResourceType.user) {
      await _removeMemberEverywhere(id);
    }
    await _afterChange(type, before, null);
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// The service provider configuration (RFC 7643, section 5).
  Map<String, Object?> serviceProviderConfig(String base) => {
    'schemas': [TomScimSchemas.serviceProviderConfig],
    'patch': {'supported': true},
    'bulk': {'supported': false, 'maxOperations': 0, 'maxPayloadSize': 0},
    'filter': {'supported': true, 'maxResults': maxCount},
    'changePassword': {'supported': false},
    'sort': {'supported': false},
    'etag': {'supported': false},
    'authenticationSchemes': [
      {
        'type': 'oauthbearertoken',
        'name': 'Bearer token',
        'description':
            'A bearer token configured for the identity provider (scim.bearerTokens).',
        'primary': true,
      },
    ],
    'meta': {
      'resourceType': 'ServiceProviderConfig',
      'location': '$base/ServiceProviderConfig',
    },
  };

  /// The resource type descriptions (RFC 7643, section 6).
  List<Map<String, Object?>> resourceTypes(String base) => [
    for (final type in TomScimResourceType.values) resourceType(type, base),
  ];

  /// The description of [type].
  Map<String, Object?> resourceType(TomScimResourceType type, String base) => {
    'schemas': [TomScimSchemas.resourceType],
    'id': type.resourceName,
    'name': type.resourceName,
    'endpoint': '/${type.endpoint}',
    'schema': type.schema,
    if (type == TomScimResourceType.user)
      'schemaExtensions': [
        {'schema': TomScimSchemas.enterpriseUser, 'required': false},
      ],
    'meta': {
      'resourceType': 'ResourceType',
      'location': '$base/ResourceTypes/${type.resourceName}',
    },
  };

  /// The schema descriptions (RFC 7643, section 7).
  List<Map<String, Object?>> schemas(String base) => [
    _schema(TomScimSchemas.user, 'User', [
      _attribute('userName', uniqueness: 'server', required: true),
      _attribute(
        'name',
        type: 'complex',
        subAttributes: [
          _attribute('formatted'),
          _attribute('familyName'),
          _attribute('givenName'),
          _attribute('middleName'),
        ],
      ),
      _attribute('displayName'),
      _attribute('externalId', caseExact: true),
      _attribute('active', type: 'boolean'),
      _attribute(
        'emails',
        type: 'complex',
        multiValued: true,
        subAttributes: [
          _attribute('value'),
          _attribute('type'),
          _attribute('primary', type: 'boolean'),
        ],
      ),
      _attribute(
        'groups',
        type: 'complex',
        multiValued: true,
        mutability: 'readOnly',
        subAttributes: [
          _attribute('value', caseExact: true, mutability: 'readOnly'),
          _attribute('display', mutability: 'readOnly'),
        ],
      ),
    ], base),
    _schema(TomScimSchemas.group, 'Group', [
      _attribute('displayName', uniqueness: 'server', required: true),
      _attribute('externalId', caseExact: true),
      _attribute(
        'members',
        type: 'complex',
        multiValued: true,
        subAttributes: [
          _attribute('value', caseExact: true, mutability: 'immutable'),
          _attribute('display'),
          _attribute('type'),
        ],
      ),
    ], base),
  ];

  static Map<String, Object?> _schema(
    String id,
    String name,
    List<Map<String, Object?>> attributes,
    String base,
  ) => {
    'schemas': [TomScimSchemas.schema],
    'id': id,
    'name': name,
    'attributes': attributes,
    'meta': {'resourceType': 'Schema', 'location': '$base/Schemas/$id'},
  };

  static Map<String, Object?> _attribute(
    String name, {
    String type = 'string',
    bool multiValued = false,
    bool required = false,
    bool caseExact = false,
    String mutability = 'readWrite',
    String uniqueness = 'none',
    List<Map<String, Object?>>? subAttributes,
  }) => {
    'name': name,
    'type': type,
    'multiValued': multiValued,
    'required': required,
    'caseExact': caseExact,
    'mutability': mutability,
    'returned': 'default',
    'uniqueness': uniqueness,
    'subAttributes': ?subAttributes,
  };

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<TomScimResource> _require(TomScimResourceType type, String id) async {
    final resource = await store.read(type, id);
    if (resource == null) {
      throw TomScimException(
        'scim.not_found',
        'No ${type.resourceName} has the id "$id".',
        status: 404,
      );
    }
    return resource;
  }

  /// The resources a filter can match: one lookup for the commonest query an
  /// identity provider sends, `userName eq "…"` (or `displayName eq "…"`), and
  /// every resource of the type otherwise.
  Future<List<TomScimResource>> _candidates(
    TomScimResourceType type,
    TomScimFilter? filter,
  ) async {
    if (filter is TomScimComparison &&
        filter.operator == 'eq' &&
        filter.value is String &&
        filter.attribute.toLowerCase() == type.nameAttribute.toLowerCase()) {
      final found = await store.findByName(type, filter.value! as String);
      return found == null ? const [] : [found];
    }
    return store.list(type);
  }

  Future<Map<String, Object?>> _write(
    TomScimResourceType type,
    TomScimResource before,
    Map<String, Object?> document,
    String base,
  ) async {
    await _requireUniqueName(type, document, exceptId: before.id);
    final after = await store.replace(type, before.id, document);
    if (after == null) {
      throw TomScimException(
        'scim.not_found',
        'No ${type.resourceName} has the id "${before.id}".',
        status: 404,
      );
    }
    await _afterChange(type, before, after);
    return _representation(after, base);
  }

  Future<void> _requireUniqueName(
    TomScimResourceType type,
    Map<String, Object?> document, {
    required String? exceptId,
  }) async {
    final name = '${scimLookup(document, type.nameAttribute)}';
    final existing = await store.findByName(type, name);
    if (existing != null && existing.id != exceptId) {
      throw TomScimException(
        'scim.uniqueness',
        'A ${type.resourceName} named "$name" already exists.',
        status: 409,
        scimType: 'uniqueness',
      );
    }
  }

  /// The client-managed document [body] describes, validated: an object, with
  /// its name attribute, without the attributes the service owns, `active` a
  /// boolean, and every group member an existing resource.
  Future<Map<String, Object?>> _clientDocument(
    TomScimResourceType type,
    Object? body,
  ) async {
    if (body is! Map) {
      throw TomScimException(
        'scim.invalid_syntax',
        'The request body is not a JSON object.',
        status: 400,
        scimType: 'invalidSyntax',
      );
    }
    final document = <String, Object?>{};
    body.forEach((key, value) {
      final name = '$key';
      final lower = name.toLowerCase();
      if (lower == 'id' || lower == 'meta' || lower == 'schemas') return;
      if (type == TomScimResourceType.user && lower == 'groups') return;
      document[name] = value;
    });

    final name = scimLookup(document, type.nameAttribute);
    if (name is! String || name.trim().isEmpty) {
      throw TomScimException(
        'scim.invalid_value',
        'A ${type.resourceName} needs a non-empty "${type.nameAttribute}".',
        status: 400,
        scimType: 'invalidValue',
      );
    }

    final activeKey = scimKeyOf(document, 'active');
    if (activeKey != null) {
      final active = document[activeKey];
      if (active is String &&
          {'true', 'false'}.contains(active.toLowerCase())) {
        // Entra ID has sent the boolean as the string "False".
        document[activeKey] = active.toLowerCase() == 'true';
      } else if (active is! bool) {
        throw TomScimException(
          'scim.invalid_value',
          '"active" must be a boolean.',
          status: 400,
          scimType: 'invalidValue',
        );
      }
    }

    if (type == TomScimResourceType.group) {
      final membersKey = scimKeyOf(document, 'members');
      if (membersKey != null) {
        document[membersKey] = await _members(document[membersKey]);
      }
    }
    return document;
  }

  /// [raw] as a member list of existing users and groups, without duplicates.
  Future<List<Map<String, Object?>>> _members(Object? raw) async {
    if (raw == null) return const [];
    if (raw is! List) {
      throw TomScimException(
        'scim.invalid_value',
        '"members" must be a list.',
        status: 400,
        scimType: 'invalidValue',
      );
    }
    final members = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final entry in raw) {
      final value = entry is Map ? scimLookup(entry.cast(), 'value') : null;
      if (value == null || '$value'.isEmpty) {
        throw TomScimException(
          'scim.invalid_value',
          'Every member names a resource in "value".',
          status: 400,
          scimType: 'invalidValue',
        );
      }
      final id = '$value';
      if (!seen.add(id)) continue;
      final user = await store.read(TomScimResourceType.user, id);
      final group = user == null
          ? await store.read(TomScimResourceType.group, id)
          : null;
      if (user == null && group == null) {
        throw TomScimException(
          'scim.invalid_value',
          'The member "$id" is neither a user nor a group.',
          status: 400,
          scimType: 'invalidValue',
        );
      }
      members.add({
        'value': id,
        'type': user != null ? 'User' : 'Group',
        if (entry is Map && scimLookup(entry.cast(), 'display') != null)
          'display': scimLookup(entry.cast(), 'display'),
      });
    }
    return members;
  }

  /// The access consequences of a change from [before] to [after] — see the
  /// library documentation.
  Future<void> _afterChange(
    TomScimResourceType type,
    TomScimResource? before,
    TomScimResource? after,
  ) async {
    if (type == TomScimResourceType.user) {
      if (before == null) return;
      if (after == null ||
          (before.active && !after.active) ||
          before.nameKey != after.nameKey) {
        await revoke(before.name);
      }
      return;
    }
    final membersBefore = _memberIds(before);
    final membersAfter = _memberIds(after);
    final renamedOrGone =
        before != null && (after == null || before.nameKey != after.nameKey);
    final affected = renamedOrGone
        ? {...membersBefore, ...membersAfter}
        : membersBefore
              .difference(membersAfter)
              .union(membersAfter.difference(membersBefore));
    for (final id in affected) {
      final user = await store.read(TomScimResourceType.user, id);
      if (user != null) await revoke(user.name);
    }
  }

  static Set<String> _memberIds(TomScimResource? group) {
    if (group == null) return const {};
    final members = group.attribute('members');
    if (members is! List) return const {};
    return {
      for (final member in members)
        if (member is Map && member['value'] != null) '${member['value']}',
    };
  }

  Future<void> _removeMemberEverywhere(String userId) async {
    for (final group in await store.list(TomScimResourceType.group)) {
      if (!_memberIds(group).contains(userId)) continue;
      final document = Map<String, Object?>.of(group.document);
      final key = scimKeyOf(document, 'members')!;
      document[key] = [
        for (final member in document[key]! as List)
          if (!(member is Map && '${member['value']}' == userId)) member,
      ];
      await store.replace(TomScimResourceType.group, group.id, document);
    }
  }

  Future<Map<String, Object?>> _representation(
    TomScimResource resource,
    String base,
  ) async => _representationWith(
    resource,
    base,
    resource.type == TomScimResourceType.user
        ? await store.list(TomScimResourceType.group)
        : const [],
  );

  /// [resource] as the client sees it: schemas, id, the document, the derived
  /// `groups` of a user, member references and `meta`.
  static Map<String, Object?> _representationWith(
    TomScimResource resource,
    String base,
    List<TomScimResource> groups,
  ) {
    final type = resource.type;
    final document = Map<String, Object?>.of(resource.document);
    final membersKey = scimKeyOf(document, 'members');
    if (membersKey != null && document[membersKey] is List) {
      document[membersKey] = [
        for (final member in document[membersKey]! as List)
          if (member is Map)
            {
              ...member.cast<String, Object?>(),
              r'$ref':
                  '$base/${member['type'] == 'Group' ? 'Groups' : 'Users'}/'
                  '${member['value']}',
            },
      ];
    }
    return {
      'schemas': [
        type.schema,
        for (final key in document.keys)
          if (key.toLowerCase().startsWith('urn:')) key,
      ],
      'id': resource.id,
      ...document,
      if (type == TomScimResourceType.user)
        'groups': [
          for (final group in groups)
            if (_memberIds(group).contains(resource.id))
              {
                'value': group.id,
                'display': group.name,
                r'$ref': '$base/Groups/${group.id}',
                'type': 'direct',
              },
        ],
      'meta': {
        'resourceType': type.resourceName,
        'created': resource.created.toUtc().toIso8601String(),
        'lastModified': resource.lastModified.toUtc().toIso8601String(),
        'location': '$base/${type.endpoint}/${resource.id}',
        'version': 'W/"${resource.version}"',
      },
    };
  }

  /// [representation] narrowed by the `attributes` / `excludedAttributes`
  /// parameters. `schemas`, `id` and `meta` are always returned.
  static Map<String, Object?> _project(
    Map<String, Object?> representation,
    String? attributes,
    String? excludedAttributes,
  ) {
    Set<String> names(String? raw) => {
      for (final name in (raw ?? '').split(','))
        if (name.trim().isNotEmpty)
          name.trim().split(':').last.split('.').first.toLowerCase(),
    };
    final wanted = names(attributes);
    final excluded = names(excludedAttributes);
    if (wanted.isEmpty && excluded.isEmpty) return representation;
    const always = {'schemas', 'id', 'meta'};
    return {
      for (final entry in representation.entries)
        if (always.contains(entry.key) ||
            ((wanted.isEmpty || wanted.contains(entry.key.toLowerCase())) &&
                !excluded.contains(entry.key.toLowerCase())))
          entry.key: entry.value,
    };
  }
}

/// RFC 7644 section 3.5.2 PATCH, applied to a resource's document in place.
class _TomScimPatch {
  _TomScimPatch(this.type);

  final TomScimResourceType type;

  void apply(Map<String, Object?> document, Map<String, Object?> operation) {
    final op = '${scimLookup(operation, 'op') ?? ''}'.toLowerCase();
    if (!const {'add', 'replace', 'remove'}.contains(op)) {
      throw TomScimException(
        'scim.invalid_syntax',
        'Unknown PATCH operation "${scimLookup(operation, 'op')}".',
        status: 400,
        scimType: 'invalidSyntax',
      );
    }
    final rawPath = scimLookup(operation, 'path');
    final value = scimLookup(operation, 'value');
    if (rawPath == null || '$rawPath'.trim().isEmpty) {
      if (op == 'remove') {
        throw TomScimException(
          'scim.no_target',
          'A remove operation names a path.',
          status: 400,
          scimType: 'noTarget',
        );
      }
      if (value is! Map) {
        throw TomScimException(
          'scim.invalid_value',
          'An operation without a path carries an object value.',
          status: 400,
          scimType: 'invalidValue',
        );
      }
      value.forEach((key, attributeValue) {
        final name = '$key';
        if (name.toLowerCase().startsWith('urn:') && attributeValue is Map) {
          // An extension object: its attributes, each under the extension.
          attributeValue.forEach((sub, subValue) {
            _apply(document, op, TomScimPath('$sub', schema: name), subValue);
          });
        } else {
          _apply(document, op, TomScimPath.parse(name, type), attributeValue);
        }
      });
      return;
    }
    _apply(document, op, TomScimPath.parse('$rawPath', type), value);
  }

  void _apply(
    Map<String, Object?> document,
    String op,
    TomScimPath path,
    Object? value,
  ) {
    final top = path.attribute.toLowerCase();
    if (path.schema == null &&
        (top == 'id' ||
            top == 'meta' ||
            top == 'schemas' ||
            (type == TomScimResourceType.user && top == 'groups'))) {
      throw TomScimException(
        'scim.mutability',
        'The attribute "${path.attribute}" is set by the service provider.',
        status: 400,
        scimType: 'mutability',
      );
    }

    var container = document;
    if (path.schema != null) {
      final schemaKey = scimKeyOf(document, path.schema!) ?? path.schema!;
      final existing = document[schemaKey];
      if (existing is Map) {
        container = existing.cast<String, Object?>();
        document[schemaKey] = container;
      } else if (op == 'remove') {
        return;
      } else {
        container = <String, Object?>{};
        document[schemaKey] = container;
      }
    }
    final key = scimKeyOf(container, path.attribute) ?? path.attribute;
    final current = container[key];

    if (path.filter != null) {
      _applyFiltered(container, key, op, path, value);
      return;
    }

    if (path.subAttribute != null) {
      final sub = path.subAttribute!;
      if (current is List) {
        for (final element in current) {
          if (element is Map) _setSub(element.cast(), sub, op, value);
        }
        return;
      }
      if (current is Map) {
        _setSub(current.cast(), sub, op, value);
        container[key] = current;
        return;
      }
      if (op == 'remove') return;
      container[key] = {sub: value};
      return;
    }

    switch (op) {
      case 'remove':
        if (value is List && current is List) {
          final drop = {for (final entry in value) _identity(entry)};
          container[key] = [
            for (final element in current)
              if (!drop.contains(_identity(element))) element,
          ];
        } else {
          container.remove(key);
        }
      case 'add':
        if (current is List || value is List) {
          final merged = [...?(current is List ? current : null)];
          final present = {for (final element in merged) _identity(element)};
          for (final element in value is List ? value : [value]) {
            if (present.add(_identity(element))) merged.add(element);
          }
          container[key] = merged;
        } else if (current is Map && value is Map) {
          container[key] = {...current, ...value};
        } else {
          container[key] = value;
        }
      case 'replace':
        if (current is Map && value is Map) {
          container[key] = {...current, ...value};
        } else {
          container[key] = value;
        }
    }
  }

  void _applyFiltered(
    Map<String, Object?> container,
    String key,
    String op,
    TomScimPath path,
    Object? value,
  ) {
    final filter = path.filter!;
    final list = [...?(container[key] is List ? container[key] as List : null)];
    final matched = [
      for (final element in list)
        if (element is Map && filter.matches(element.cast<String, Object?>()))
          element,
    ];
    final sub = path.subAttribute;
    if (op == 'remove') {
      if (sub == null) {
        list.removeWhere(matched.contains);
      } else {
        for (final element in matched) {
          element.remove(scimKeyOf(element.cast(), sub) ?? sub);
        }
      }
      container[key] = list;
      return;
    }
    if (matched.isEmpty) {
      // `emails[type eq "work"].value` on a user with no work email: the
      // element the filter describes is created, which is what identity
      // providers sending this form expect.
      if (filter is TomScimComparison && filter.operator == 'eq') {
        list.add({
          filter.attribute: filter.value,
          if (sub != null) sub: value,
          if (sub == null && value is Map) ...value.cast<String, Object?>(),
        });
        container[key] = list;
        return;
      }
      throw TomScimException(
        'scim.no_target',
        'No value of "${path.attribute}" matches the path\'s filter.',
        status: 400,
        scimType: 'noTarget',
      );
    }
    for (final element in matched) {
      final map = element.cast<String, Object?>();
      if (sub != null) {
        map[scimKeyOf(map, sub) ?? sub] = value;
      } else if (value is Map) {
        map.addAll(value.cast<String, Object?>());
      }
    }
    container[key] = list;
  }

  static void _setSub(
    Map<String, Object?> target,
    String sub,
    String op,
    Object? value,
  ) {
    final key = scimKeyOf(target, sub) ?? sub;
    if (op == 'remove') {
      target.remove(key);
    } else {
      target[key] = value;
    }
  }

  /// What makes two values of a multi-valued attribute the same one: a
  /// reference's `value`, otherwise the whole value.
  static String _identity(Object? element) {
    if (element is Map) {
      final value = scimLookup(element.cast(), 'value');
      if (value != null) return 'value:$value';
    }
    return jsonEncode(element);
  }
}
