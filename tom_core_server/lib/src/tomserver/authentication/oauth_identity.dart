/// The linking table (C-9): `(issuer, subject)` → a local account.
///
/// ## Why a table and not a claim
///
/// The obvious shortcut is to treat the provider's email claim as the username
/// and skip the join. It is wrong in two directions at once. People change their
/// email address, and when they do the shortcut silently creates a *second*
/// account for the same human — every past order, preference and grant left
/// behind on the old one. And two providers can assert the same email for two
/// different people (one of them by simply not verifying it), which is the same
/// failure with the roles reversed and rather more consequences.
///
/// A row records the pair the provider actually guarantees: a subject that is
/// stable within an issuer. The email may then change freely, because nothing
/// depends on it after provisioning.
///
/// ## Why several rows per account
///
/// The table's unique key is `(issuer, subject)` — *not* the local username. An
/// account may therefore hold a Google identity, a corporate SSO identity and a
/// local password at once, which is the state every real deployment converges
/// on: people sign up one way and later sign in another, and a framework that
/// modelled one external identity per account would force them to pick.
///
/// ## Why this entity carries no `@TomDbScope`
///
/// Every other per-user framework table declares
/// `@TomDbScope(field: 'principal_id', scope: 'owner')`, and this one
/// deliberately does not. The scope resolves the principal in the request zone,
/// and this table is read at the one moment when there **is** no principal: the
/// lookup is what decides who the caller is. A scope here would filter every
/// read against a null owner and match nothing, which reads as "no account is
/// linked" — a login that silently fails, or, with auto-provisioning on, a
/// second account created on every sign-in.
///
/// What protects it instead is that nothing reachable by a caller ever queries
/// it by anything but a `(issuer, subject)` pair the *provider* just asserted
/// over an authenticated back channel. There is no endpoint that reads this
/// table, no request parameter that reaches it, and a caller cannot ask for a
/// row: they can only present a code to a provider and have the provider name
/// the subject. That is the invariant to preserve — the day an endpoint exposes
/// "which accounts are linked to X", it needs an authorization rule of its own,
/// and the absence of a scope stops being safe.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/persistence_annotations.dart';
import 'oauth_flow.dart';
import 'oauth_provider.dart';

/// One external identity bound to one local account.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_external_identity',
  primaryKeyField: 'id',
)
class TomExternalIdentityLink {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn<int, TomDbInt>(columnName: 'id', isReadOnly: true)
  int id;

  /// The identity provider's issuer identifier
  /// ([TomOAuthProviderConfig.issuer]).
  @TomDbColumn<String, TomDbString>(columnName: 'issuer')
  String issuer;

  /// The provider's stable identifier for the user, within [issuer].
  @TomDbColumn<String, TomDbString>(columnName: 'subject')
  String subject;

  /// The local account's username — the value handed to the deployment's
  /// directory to resolve a `TomPrincipal`.
  ///
  /// A username rather than a numeric principal id because that is the handle
  /// [TomExternalIdentityDirectory] and [TomAuthenticationData] both already
  /// speak, so linking needs no second identifier and no assumption about how a
  /// deployment keys its own user table.
  @TomDbColumn<String, TomDbString>(columnName: 'local_username')
  String localUsername;

  /// The display name the provider asserted when the link was made, kept for
  /// operator diagnostics ("which Google account is this?").
  @TomDbColumn<String, TomDbString>(columnName: 'display_name')
  String displayName;

  /// When the link was created (UTC).
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'linked_at')
  DateTime? linkedAt;

  /// When the link was last used to sign in (UTC), or `null` if never.
  ///
  /// Not decoration: it is what lets an operator answer "is this link still in
  /// use?" before revoking a provider, and what makes an unexpected sign-in
  /// visible.
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'last_login_at')
  DateTime? lastLoginAt;

  /// Creates a link. Every field defaults, because the repository instantiates
  /// a blank entity and fills it column by column when mapping a result.
  TomExternalIdentityLink({
    this.id = -1,
    this.issuer = '',
    this.subject = '',
    this.localUsername = '',
    this.displayName = '',
    this.linkedAt,
    this.lastLoginAt,
  });

  /// The DDL this entity expects, reproduced verbatim by the framework
  /// migration so the two cannot drift.
  ///
  /// `(issuer, subject)` is unique because that pair *is* the external
  /// identity: a duplicate would make which local account a sign-in reaches
  /// depend on row order. The index on `local_username` is what makes "every
  /// identity linked to this account" — the account-settings question — a
  /// lookup rather than a scan.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_external_identity (
  id BIGINT NOT NULL AUTO_INCREMENT,
  issuer VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  local_username VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL DEFAULT '',
  linked_at DATETIME NULL,
  last_login_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_external_identity (issuer, subject),
  KEY idx_tom_external_identity_local (local_username)
);''';
}

/// The repository for [TomExternalIdentityLink].
class TomExternalIdentityLinkRepository
    extends TomSqlDatasourceRepository<TomExternalIdentityLink, int> {}

/// Read/write access to the linking table.
///
/// An interface for the same reason [Tom2FAEnrolmentStore] is one: a deployment
/// that already has an identity-linking table of its own should be able to point
/// the framework at it rather than run two, and a test should be able to exercise
/// the whole login without a database.
abstract class TomExternalIdentityStore {
  /// The local username [identity] is linked to, or `null` when it is unknown.
  Future<String?> localUsernameFor(TomExternalIdentity identity);

  /// Links [identity] to [localUsername], replacing any previous link for the
  /// same `(issuer, subject)`.
  Future<void> link(TomExternalIdentity identity, String localUsername);

  /// Records that [identity] was just used to sign in.
  ///
  /// Separate from [link] because the two happen at different times: linking is
  /// once, signing in is every time, and folding them together would rewrite
  /// the display name on every login from whatever the provider currently says.
  Future<void> recordLogin(TomExternalIdentity identity);

  /// Every identity linked to [localUsername] — what an account-settings page
  /// lists, and what a deployment checks before removing the last credential.
  Future<List<TomExternalIdentityLink>> identitiesOf(String localUsername);

  /// The installed [TomExternalIdentityStore] bean, or `null` when none is
  /// registered.
  ///
  /// `null` rather than a default: unlike a state store, there is no correct
  /// in-memory fallback here. A link that vanishes on restart would send a
  /// returning user through provisioning again — creating a duplicate account
  /// or refusing a login that worked yesterday — so a deployment that offers
  /// external identity must say where its links live.
  static TomExternalIdentityStore? resolve() {
    final installed = TomBean.getBeanByType(TomExternalIdentityStore);
    return installed is TomExternalIdentityStore ? installed : null;
  }
}

/// A [TomExternalIdentityStore] over `tom_external_identity`.
class TomPersistentExternalIdentityStore implements TomExternalIdentityStore {
  /// The repository links are read and written through.
  final TomSqlDatasourceRepository<TomExternalIdentityLink, int> repository;

  /// Creates the store over [repository].
  const TomPersistentExternalIdentityStore(this.repository);

  @override
  Future<String?> localUsernameFor(TomExternalIdentity identity) async {
    final row = await _rowFor(identity);
    return row?.localUsername;
  }

  @override
  Future<void> link(TomExternalIdentity identity, String localUsername) async {
    // Reuse the found row rather than inserting a second: the repository takes
    // its UPDATE path exactly when the surrogate key is set, and the unique key
    // on (issuer, subject) would reject the alternative anyway.
    final row = await _rowFor(identity) ?? TomExternalIdentityLink();
    row.issuer = identity.issuer;
    row.subject = identity.subject;
    row.localUsername = localUsername;
    row.displayName = identity.displayName;
    row.linkedAt ??= DateTime.now().toUtc();
    await repository.save(row);
  }

  @override
  Future<void> recordLogin(TomExternalIdentity identity) async {
    final row = await _rowFor(identity);
    if (row == null) return;
    row.lastLoginAt = DateTime.now().toUtc();
    await repository.save(row);
  }

  @override
  Future<List<TomExternalIdentityLink>> identitiesOf(
    String localUsername,
  ) async {
    final rows = await repository.findByQuerySentence(
      'FIND BY local_username = :localUsername',
      {'localUsername': localUsername},
    );
    return List.unmodifiable(rows);
  }

  /// The row for [identity], or `null`.
  Future<TomExternalIdentityLink?> _rowFor(TomExternalIdentity identity) async {
    final matches = await repository.findByQuerySentence(
      'FIND BY issuer = :issuer AND subject = :subject',
      {'issuer': identity.issuer, 'subject': identity.subject},
    );
    return matches.isEmpty ? null : matches.first;
  }
}

/// A [TomExternalIdentityStore] that keeps links in memory.
///
/// For tests and bring-up **only**, and it says so rather than being quietly
/// available: links that vanish on restart are the failure mode described on
/// [TomExternalIdentityStore.resolve]. It is shipped because the alternative is
/// every test writing the same map.
class TomMemoryExternalIdentityStore implements TomExternalIdentityStore {
  final Map<String, TomExternalIdentityLink> _links = {};

  /// Creates an empty in-memory store.
  TomMemoryExternalIdentityStore();

  @override
  Future<String?> localUsernameFor(TomExternalIdentity identity) async =>
      _links[_keyOf(identity.issuer, identity.subject)]?.localUsername;

  @override
  Future<void> link(TomExternalIdentity identity, String localUsername) async {
    final key = _keyOf(identity.issuer, identity.subject);
    final row = _links[key] ?? TomExternalIdentityLink();
    row.issuer = identity.issuer;
    row.subject = identity.subject;
    row.localUsername = localUsername;
    row.displayName = identity.displayName;
    row.linkedAt ??= DateTime.now().toUtc();
    _links[key] = row;
  }

  @override
  Future<void> recordLogin(TomExternalIdentity identity) async {
    _links[_keyOf(identity.issuer, identity.subject)]?.lastLoginAt =
        DateTime.now().toUtc();
  }

  @override
  Future<List<TomExternalIdentityLink>> identitiesOf(
    String localUsername,
  ) async => List.unmodifiable(
    _links.values.where((row) => row.localUsername == localUsername),
  );

  /// The map key.
  ///
  /// The separator is a NUL, which cannot occur in a URL-shaped issuer or in a
  /// provider subject — so no two distinct identities can collide on it, the
  /// way `issuer:subject` would for an issuer that ends in a colon.
  String _keyOf(String issuer, String subject) => '$issuer\u0000$subject';
}
