/// The provisioned users as the accounts external login resolves.
///
/// SCIM makes the identity provider the register of accounts: it creates them
/// before their owners first sign in, and deactivates them when they leave.
/// [TomScimIdentityDirectory] is the [TomExternalIdentityDirectory] that reads
/// that register, so single sign-on and provisioning meet in one place:
///
/// ```dart
/// TomAuthenticationServer.globalSettingUserAuthenticationService =
///     TomOAuthAuthenticationService(
///       directory: TomScimIdentityDirectory(
///         store,
///         roleMapping: const TomExternalRoleMapping(roles: {
///           'Admins': ['tom.admin'],
///         }),
///       ),
///     );
/// ```
///
/// with the identity provider configured `provisioning: linkExisting` — the
/// login links to the provisioned account and never creates one.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'authentication_server.dart';
import 'external_provider.dart';
import 'oauth_authentication_service.dart';
import 'scim_filter.dart';
import 'scim_resource.dart';

/// A [TomExternalIdentityDirectory] over the SCIM-provisioned users.
///
/// | Account | Answer |
/// | ------- | ------ |
/// | not provisioned | `null` — the login takes its provider's provisioning branch |
/// | provisioned and active | a principal whose roles come from its groups |
/// | provisioned and inactive | refused, `login.error.scim.inactive` |
///
/// Roles are derived from the user's groups on every login, through
/// [roleMapping] applied to the groups' display names, so a group change at
/// the identity provider reaches the next session — and, because the SCIM
/// service revokes the members of a changed group, the current one too.
class TomScimIdentityDirectory extends TomExternalIdentityDirectory {
  /// Creates the directory over [store].
  TomScimIdentityDirectory(
    this.store, {
    this.roleMapping = TomExternalRoleMapping.none,
  });

  /// Where the provisioned users and groups are.
  final TomScimStore store;

  /// Group display name → Tom roles; its `groupsClaim` is not consulted.
  final TomExternalRoleMapping roleMapping;

  @override
  Future<TomAuthenticationInfo?> authenticatedPrincipalFor(
    String username,
    TomAuthenticationData authData,
  ) async {
    final user = await store.findByName(TomScimResourceType.user, username);
    if (user == null) return null;
    if (!user.active) {
      throw TomLoginException(
        'login.error.scim.inactive',
        "The account '${user.name}' has been deactivated by its identity "
            'provider.',
        reason: TomLoginFailure.accountProblem,
      );
    }
    final groups = [
      for (final group in await store.list(TomScimResourceType.group))
        if (_hasMember(group, user.id)) group.name,
    ];
    final roles = roleMapping.rolesFor({roleMapping.groupsClaim: groups});
    final name = user.attribute('name');
    return TomAuthenticationInfo(
      TomPrincipal(
        authenticated: true,
        organization: authData.organization,
        application: authData.application,
        process: authData.process,
        language: authData.language,
        country: authData.country,
        clientLanguage: authData.language,
        clientCountry: authData.country,
        clientTimezone: authData.timezone,
        user: TomUser(
          id: int.tryParse(user.id) ?? -1,
          username: user.name,
          firstname: name is Map
              ? '${scimLookup(name.cast(), 'givenName') ?? ''}'
              : null,
          lastname: name is Map
              ? '${scimLookup(name.cast(), 'familyName') ?? ''}'
              : null,
          email: _primaryEmail(user),
          attributes: {'scimId': user.id, 'externalId': ?user.externalId},
        ),
        aci: TomAccessControlInformation(roles: roles, groups: groups),
      ),
      TomAccessControlDefinition(),
    );
  }

  static bool _hasMember(TomScimResource group, String userId) {
    final members = group.attribute('members');
    return members is List &&
        members.any((m) => m is Map && '${m['value']}' == userId);
  }

  static String? _primaryEmail(TomScimResource user) {
    final emails = user.attribute('emails');
    if (emails is! List || emails.isEmpty) return null;
    final maps = [
      for (final e in emails)
        if (e is Map) e,
    ];
    final primary = maps.firstWhere(
      (e) => e['primary'] == true,
      orElse: () => maps.isEmpty ? const {} : maps.first,
    );
    final value = primary['value'];
    return value == null ? null : '$value';
  }
}
