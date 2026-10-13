/// What every external identity provider has in common, whatever protocol it
/// speaks: an id, an issuer, a provisioning policy and a role mapping.
///
/// Two protocols implement it. [TomOAuthProviderConfig] is an OAuth 2.0 /
/// OpenID Connect provider; `TomSamlProviderConfig` is a SAML 2.0 identity
/// provider. Everything downstream of "the provider has said who this is" —
/// linking the identity to a local account, provisioning one, applying the
/// mapped roles, issuing the session — is written against this type, so an
/// enterprise identity provider behaves the same over either protocol.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'oauth_provider.dart';

/// One configured external identity provider, protocol-neutral.
abstract interface class TomExternalProvider {
  /// The configuration id; what a login request names.
  String get id;

  /// The identifier the provider asserts identities under — the OIDC `iss`, or
  /// the SAML identity provider's entity id. Links are keyed by it.
  String get issuer;

  /// What a successful login with no local account does.
  TomOAuthProvisioning get provisioning;

  /// How the provider's group claims become Tom roles.
  TomExternalRoleMapping get roleMapping;

  /// The tolerance applied to the provider's validity instants.
  Duration get clockSkew;

  /// The provider as the client-facing descriptor.
  TomOAuthProviderDto toDto();
}

/// How an identity provider's group claims become Tom roles.
///
/// Configured per provider:
///
/// ```yaml
/// groupsClaim: groups            # a claim, attribute or dotted path
/// defaultRoles: [employee]       # every login from this provider
/// roleMapping:
///   admins: [tom.admin]          # external group -> Tom roles
///   staff: [tom.user, tom.reporting]
/// ```
///
/// The provider is the authority for the roles it maps: they are recomputed
/// from the claims on **every** login and applied to that session's principal,
/// alongside whatever roles the local account holds. Removing a user from a
/// group at the identity provider therefore removes the mapped role at their
/// next login, without the framework writing to the deployment's user store —
/// which it does not own. A deployment that wants the mapped roles persisted
/// reads them off [TomExternalIdentity.roles] when it provisions the account.
///
/// Groups that the mapping does not name grant nothing. An identity provider
/// typically asserts dozens of groups, most of them about mailing lists, and a
/// group nobody mapped is not a permission.
class TomExternalRoleMapping {
  /// Creates a mapping.
  const TomExternalRoleMapping({
    this.groupsClaim = defaultGroupsClaim,
    this.roles = const {},
    this.defaultRoles = const [],
  });

  /// The claim read when a provider names none.
  static const String defaultGroupsClaim = 'groups';

  /// A mapping that grants nothing.
  static const TomExternalRoleMapping none = TomExternalRoleMapping();

  /// The claim (OIDC) or attribute (SAML) carrying the user's groups.
  ///
  /// A dotted path reaches into a nested claim — Keycloak puts realm roles at
  /// `realm_access.roles` — and a claim whose name itself contains a dot is
  /// found before the path is split.
  final String groupsClaim;

  /// External group → the Tom roles it grants.
  final Map<String, List<String>> roles;

  /// The roles every login from this provider receives.
  final List<String> defaultRoles;

  /// Reads a mapping from a provider's configuration [map].
  ///
  /// Throws `oauth.config.invalid_role_mapping` when `roleMapping` is not a
  /// map of group to role list: a mistyped security setting must stop the
  /// start, not grant nothing quietly.
  factory TomExternalRoleMapping.fromMap(
    String providerId,
    Map<Object?, Object?> map,
  ) {
    final rawMapping = map['roleMapping'];
    final mapping = <String, List<String>>{};
    if (rawMapping != null) {
      if (rawMapping is! Map) {
        throw _invalid(providerId, 'roleMapping', rawMapping);
      }
      rawMapping.forEach((group, roles) {
        mapping['$group'] = _roleList(providerId, 'roleMapping.$group', roles);
      });
    }
    final groupsClaim = map['groupsClaim'];
    return TomExternalRoleMapping(
      groupsClaim: groupsClaim == null || '$groupsClaim'.isEmpty
          ? defaultGroupsClaim
          : '$groupsClaim',
      roles: Map.unmodifiable(mapping),
      defaultRoles: map['defaultRoles'] == null
          ? const []
          : _roleList(providerId, 'defaultRoles', map['defaultRoles']),
    );
  }

  /// The groups [claims] assert, read at [groupsClaim].
  ///
  /// A list, a single string, or absent — the shapes providers actually send.
  /// A single string is one group: a provider configured to send one group
  /// sends it unwrapped, and splitting it on commas would invent groups.
  List<String> groupsIn(Map<String, Object?> claims) {
    final value = claimAt(claims, groupsClaim);
    if (value == null) return const [];
    if (value is List) {
      return List.unmodifiable(
        value.map((g) => '$g').where((g) => g.isNotEmpty),
      );
    }
    final single = '$value';
    return single.isEmpty ? const [] : List.unmodifiable([single]);
  }

  /// The Tom roles [claims] earn: the [defaultRoles], then the roles of every
  /// mapped group, without duplicates and in that order.
  List<String> rolesFor(Map<String, Object?> claims) {
    final granted = <String>{...defaultRoles};
    for (final group in groupsIn(claims)) {
      granted.addAll(roles[group] ?? const []);
    }
    return List.unmodifiable(granted);
  }

  /// The value at [path] in [claims]: the claim of that exact name when there
  /// is one, otherwise the dotted path followed through nested maps.
  static Object? claimAt(Map<String, Object?> claims, String path) {
    if (claims.containsKey(path)) return claims[path];
    Object? current = claims;
    for (final segment in path.split('.')) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  static List<String> _roleList(String providerId, String key, Object? raw) {
    if (raw is String) return List.unmodifiable([raw]);
    if (raw is! List) throw _invalid(providerId, key, raw);
    return List.unmodifiable(raw.map((r) => '$r').where((r) => r.isNotEmpty));
  }

  static TomOAuthException _invalid(
    String providerId,
    String key,
    Object? raw,
  ) => TomOAuthException(
    'oauth.config.invalid_role_mapping',
    "Provider '$providerId' declares '$key' as a ${raw.runtimeType}; "
        'roleMapping is a map of external group to a list of Tom roles, '
        'and defaultRoles is a list of Tom roles.',
    parameters: {'provider': providerId, 'key': key},
  );

  @override
  String toString() =>
      'TomExternalRoleMapping($groupsClaim, ${roles.length} groups, '
      'default $defaultRoles)';
}

/// [roles] added to [info]'s principal for this session.
///
/// The principal's own roles are kept; mapped roles join them. Applied before
/// the access-control definition completes the principal's rights, so a mapped
/// role brings everything the definition derives from it.
void applyExternalRoles(TomPrincipal principal, List<String> roles) {
  if (roles.isEmpty) return;
  final aci = principal.aci;
  principal.aci = TomAccessControlInformation(
    roles: [
      ...aci.roles,
      for (final role in roles)
        if (!aci.roles.contains(role)) role,
    ],
    entitlements: aci.entitlements,
    resourceKeys: aci.resourceKeys,
    groups: aci.groups,
    resourceRoles: aci.resourceRoles,
  );
}
