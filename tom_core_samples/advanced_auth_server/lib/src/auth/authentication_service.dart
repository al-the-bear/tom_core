/// The auth server's [TomAuthenticationService] — the credential check that the
/// framework's `TomAuthenticationServer` delegates each login to (step 11).
///
/// It verifies a username/password against `auth_db`, loads the user's role keys
/// and group names, and builds the authenticated [TomPrincipal] +
/// [TomAccessControlDefinition] the server encodes into the bearer-token pair. A
/// rejected login throws [LoginException], which the server turns into a failed
/// `TomAuthenticationResult`.
///
/// The DB reads sit behind an [AuthUserStore] seam so the service is unit-testable
/// without a database or the reflection runtime: [RepositoryAuthUserStore] is the
/// real query-backed store wired at boot (step 13); [InMemoryAuthUserStore] is a
/// seeded store for tests. The service itself is pure over whichever store it is
/// handed.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../persistence/auth_persistence_model.dart';
import 'password_hashing.dart';

/// The user-lookup seam the [AdvancedAuthenticationService] reads through.
///
/// Splitting the three reads the login needs (find the account, load its role
/// keys, load its group names) onto a small interface lets the service run
/// against a real repository at boot and a seeded in-memory store under test,
/// with identical logic on both.
abstract class AuthUserStore {
  /// Returns the account row for [username], or `null` when no such user exists.
  Future<UserRecord?> findByUsername(String username);

  /// Returns the stable role keys assigned to the user with [userId] (e.g.
  /// `['admin']`), in assignment order. Empty when the user holds no roles.
  Future<List<String>> roleKeysForUser(int userId);

  /// Returns the names of the groups the user with [userId] belongs to. Empty
  /// when the user is in no group.
  Future<List<String>> groupNamesForUser(int userId);
}

/// Authenticates a login against `auth_db` and builds the authenticated
/// principal.
///
/// Single-tenant by design (the sample has one client/organization), so it skips
/// the multi-tenant client/application/process resolution the production
/// `tom_uam` service performs and authenticates purely on `(username, password)`.
class AdvancedAuthenticationService implements TomAuthenticationService {
  /// The store the login reads the account, roles, and groups through.
  final AuthUserStore store;

  /// Builds the service over [store] (a repository-backed store at boot, a seeded
  /// in-memory one under test).
  ///
  /// The login deliberately does **not** fold the principal's effective
  /// per-resource roles (C-5 ownership grants ∪ C-6 active share delegations) into
  /// the minted token (RCD3, option b). The bearer token is opaque to the client
  /// and never read for enforcement: the app server re-resolves the live grant and
  /// delegation rows from `auth_db` on every request (so a revoked share stops
  /// granting access immediately, not at token expiry), and the client reads its
  /// current effective roles from the app server's `/resource-roles` endpoint.
  /// A `resourceRoles` claim baked into the 2-hour token would therefore have no
  /// reader and could only go stale — so the login leaves it empty and
  /// [TomAccessControlInformation.resourceRoles] is populated live downstream, not
  /// at issue time.
  AdvancedAuthenticationService(this.store);

  /// Resolves [authData] into an authenticated [TomAuthenticationInfo], or throws
  /// [LoginException] when the login is rejected.
  ///
  /// Rejects an unknown user and a wrong password with the *same* generic key
  /// (`error.invalid-user-or-password`) so the response never reveals which of
  /// the two failed; a suspended account is rejected distinctly
  /// (`error.user.suspended`) because that is an actionable account state, not a
  /// credential guess.
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  ) async {
    final record = await store.findByUsername(authData.username);
    if (record == null || record.id == null) {
      throw LoginException(
        'error.invalid-user-or-password',
        'Invalid user or password',
      );
    }

    if (record.status == UserStatus.suspended.name) {
      throw LoginException('error.user.suspended', 'Account is suspended');
    }

    final password = authData.key?.toString() ?? '';
    if (!verifyUserPassword(record, password)) {
      throw LoginException(
        'error.invalid-user-or-password',
        'Invalid user or password',
      );
    }

    final roleKeys = await store.roleKeysForUser(record.id!);
    final groupNames = await store.groupNamesForUser(record.id!);

    final twoFactorType = record.twoFactorType ?? '';
    final requires2FA = twoFactorType.isNotEmpty;

    final principal = TomPrincipal(
      // Passing the password check is not yet being authenticated: an account
      // that owes a second factor is authenticated only once pass 2 clears it.
      // Stated the same way the kernel restores it from a token
      // (`authenticated = username != GUEST && !requires2FA`), so the in-memory
      // principal and the token-restored one never disagree.
      authenticated: !requires2FA,
      requires2FA: requires2FA,
      twoFactorType: requires2FA ? twoFactorType : null,
      context: {},
      organization: authData.organization,
      application: authData.application,
      process: authData.process,
      language: authData.language,
      country: authData.country,
      timezone: authData.timezone,
      clientLanguage: authData.language,
      clientCountry: authData.country,
      clientTimezone: authData.timezone,
      user: TomUser(
        id: record.id!,
        username: record.username ?? '',
        firstname: record.displayName,
        email: record.email,
        attributes: {},
      ),
      aci: TomAccessControlInformation(
        roles: roleKeys,
        groups: groupNames,
      ),
    );

    // The definition mirrors the user's directly-assigned roles/groups; the
    // sample has no role/group inheritance, so the binary ACI above already
    // carries the effective set. The server encodes this ACD into the
    // authorization token.
    final acd = TomAccessControlDefinition(
      roles: [for (final key in roleKeys) TomRole(name: key)],
      groups: [for (final name in groupNames) TomGroup(name: name)],
    );

    return TomAuthenticationInfo(principal, acd);
  }
}

/// Points the framework's built-in TOTP adaptor at the `two_factor_secret`
/// column, read through [store].
///
/// `TomTotp2FAService` deliberately ships without a secret source — where a
/// deployment keeps enrolment secrets is its own business, and guessing would
/// mean the framework reading a store it has no business knowing about. This is
/// the auth server's answer: the secret lives next to the account it belongs to,
/// and is fetched per verification rather than cached, so revoking an enrolment
/// takes effect on the next login and not at some cache horizon.
///
/// Call once at boot (and in a test's `setUp`); it is idempotent, so a re-boot
/// simply replaces the resolver with an equivalent one.
void installTotpSecretResolver(AuthUserStore store) {
  TomTotp2FAService.globalSettingSecretResolver = (context) async {
    final record = await store.findByUsername(context.principal.username);
    final secret = record?.twoFactorSecret ?? '';
    // Null, not empty: the adaptor reads `null` as "not enrolled" and fails the
    // login with `login.error.2fa.not-enrolled` rather than showing a prompt
    // that could never be satisfied.
    return secret.isEmpty ? null : secret;
  };
}

/// The query-backed [AuthUserStore] wired at boot (step 13).
///
/// Reads through the process-wide singleton repositories, resolving the
/// `user_roles -> roles.role_key` and `group_members -> groups.name` joins with
/// the repository query language. Requires a live `auth_db` connection and the
/// reflection runtime, so it is exercised end-to-end rather than in the unit
/// tests (which use [InMemoryAuthUserStore]).
class RepositoryAuthUserStore implements AuthUserStore {
  /// Creates the repository-backed store (stateless; reads the singletons).
  const RepositoryAuthUserStore();

  @override
  Future<UserRecord?> findByUsername(String username) async {
    final matches = await userRepository.findByQuerySentence(
      'FIND BY username = :username',
      {'username': username},
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<List<String>> roleKeysForUser(int userId) async {
    final assignments = await userRoleRepository.findByQuerySentence(
      'FIND BY user_id = :userId',
      {'userId': userId},
    );
    final keys = <String>[];
    for (final assignment in assignments) {
      if (assignment.roleId case final int roleId) {
        final role = await roleRepository.findById(roleId);
        final key = role?.roleKey;
        if (key != null) keys.add(key);
      }
    }
    return keys;
  }

  @override
  Future<List<String>> groupNamesForUser(int userId) async {
    final memberships = await groupMemberRepository.findByQuerySentence(
      'FIND BY user_id = :userId',
      {'userId': userId},
    );
    final names = <String>[];
    for (final membership in memberships) {
      if (membership.groupId case final int groupId) {
        final group = await groupRepository.findById(groupId);
        final name = group?.name;
        if (name != null) names.add(name);
      }
    }
    return names;
  }
}

/// A seeded, database-free [AuthUserStore] for tests (and local scaffolding).
///
/// Holds the account rows plus the `userId -> roleKeys` / `userId -> groupNames`
/// assignments directly, so a test can assert the accept/reject paths and the
/// principal's resolved roles without a connection or reflection.
class InMemoryAuthUserStore implements AuthUserStore {
  final List<UserRecord> _users;
  final Map<int, List<String>> _roleKeysByUserId;
  final Map<int, List<String>> _groupNamesByUserId;

  /// Seeds the store with [users] and their role/group assignments keyed by
  /// [UserRecord.id].
  InMemoryAuthUserStore({
    required List<UserRecord> users,
    Map<int, List<String>> roleKeysByUserId = const {},
    Map<int, List<String>> groupNamesByUserId = const {},
  })  : _users = users,
        _roleKeysByUserId = roleKeysByUserId,
        _groupNamesByUserId = groupNamesByUserId;

  @override
  Future<UserRecord?> findByUsername(String username) async {
    for (final user in _users) {
      if (user.username == username) return user;
    }
    return null;
  }

  @override
  Future<List<String>> roleKeysForUser(int userId) async =>
      _roleKeysByUserId[userId] ?? const [];

  @override
  Future<List<String>> groupNamesForUser(int userId) async =>
      _groupNamesByUserId[userId] ?? const [];
}
