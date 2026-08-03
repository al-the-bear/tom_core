/// The provider's *own* tokens — delegated authorization, not authentication.
///
/// ## The framework's position, stated once
///
/// **By default the framework keeps nothing.** A login exchanges an
/// authorization code, reads the claims it needs to identify the user, and lets
/// the provider's `access_token` and `refresh_token` fall out of scope with the
/// request. That is the correct default and not an omission: the framework mints
/// its own session, so a provider credential retained after the login is a
/// credential nobody uses — and one whose compromise reaches *beyond* this
/// deployment, because a refresh token is a long-lived key to a third party that
/// this deployment can neither revoke nor observe being used.
///
/// **A deployment that genuinely needs delegated access opts in, per provider,
/// and then the framework does the holding.** "Read the user's calendar", "list
/// their repositories", "send mail as them" all need a live provider access
/// token long after the login, and there is no way to have one without keeping
/// the refresh token that mints it. The choice is therefore not *whether* the
/// credential exists but *who* holds it, and the honest answer is that a
/// framework which stops at "we keep nothing" pushes three hard problems onto
/// every application at once: encryption at rest, retention tied to the identity
/// link, and refresh. The third is the dangerous one — an application left to
/// solve it reaches for the login path, because that is the code it can see that
/// already talks to the token endpoint, and a second login path that mints
/// sessions on a background refresh is exactly the drift the C-9 seam exists to
/// prevent.
///
/// So the position has two halves, and both are load-bearing:
///
/// * Nothing is stored unless [TomOAuthProviderConfig.storeTokens] is `true` for
///   the provider. A deployment that wants "Sign in with …" acquires no
///   third-party credential, ever, and does not have to know this library
///   exists.
/// * When it *is* stored, it is stored the way a credential must be: encrypted
///   with the framework's existing asymmetric primitive
///   ([TomJwtConfiguration.encrypt] — the same one behind a 2FA enrolment
///   secret), keyed by the same `(issuer, subject)` pair as the identity link,
///   and deleted when that link is deleted.
///
/// Refreshing lives on [TomOAuthFlow] and nowhere else. It is not a login: it
/// consults no [TomAuthenticationService], asks no 2FA policy and produces no
/// session. See [TomOAuthFlow.accessTokenFor].
///
/// ## What is *not* encrypted, and why that is deliberate
///
/// [TomExternalIdentityToken] keeps `token_scope`, `obtained_at` and
/// `expires_at` as ordinary columns beside the encrypted blob. They are not
/// secret — knowing that a grant covers `calendar.readonly` and expired last
/// Tuesday lets nobody call anything — and they are exactly what an operator
/// needs to answer "is this grant live, and what does it cover?" without the
/// private key. Putting them only inside the ciphertext would make a routine
/// operational question require the one key that must never leave the server.
///
/// The authoritative expiry is nonetheless the one *inside* the payload: the
/// column is a projection for humans, and nothing in this library decides
/// anything from it.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/persistence_annotations.dart';
import 'oauth_flow.dart';
import 'oauth_provider.dart';

// =============================================================================
// VALUE
// =============================================================================

/// One token grant as a provider issued it.
///
/// A value rather than the raw response map, for the reason
/// [TomOAuthCredential] is one: `expires_in` is a *duration from the moment of
/// the response* and becomes meaningless the instant it is stored, so something
/// has to resolve it against a clock exactly once. Doing that at the boundary —
/// here — means nothing downstream has to know when the response arrived.
class TomOAuthTokenGrant {
  /// The bearer token to present to the provider's API.
  final String accessToken;

  /// The token that mints a new [accessToken], or `null` when the provider
  /// issued none.
  ///
  /// Absent far more often than deployments expect: most providers return one
  /// only when explicitly asked (Google wants `access_type=offline`, and repeats
  /// it only under `prompt=consent`), which is what
  /// [TomOAuthProviderConfig.authorizationParameters] exists to carry.
  final String? refreshToken;

  /// The token type the provider named; `Bearer` in every practical case.
  final String tokenType;

  /// The scopes the grant actually covers.
  ///
  /// The *granted* scopes, which may be narrower than the requested ones — a
  /// user may decline part of a consent screen — so this is what an application
  /// must check before assuming a capability, not
  /// [TomOAuthProviderConfig.scopes].
  final String scope;

  /// When [accessToken] stops being accepted (UTC), or `null` when the provider
  /// declared no lifetime.
  final DateTime? expiresAt;

  /// When this grant was obtained (UTC).
  final DateTime obtainedAt;

  /// Records a grant. Both instants are normalised to UTC, because the value
  /// crosses a storage boundary and a local-time instant read back on a server
  /// in another zone is silently wrong.
  TomOAuthTokenGrant({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.scope = '',
    DateTime? expiresAt,
    DateTime? obtainedAt,
  }) : expiresAt = expiresAt?.toUtc(),
       obtainedAt = (obtainedAt ?? DateTime.now()).toUtc();

  /// Whether the grant can mint a fresh access token by itself.
  bool get hasRefreshToken =>
      refreshToken != null && refreshToken!.trim().isNotEmpty;

  /// Whether [accessToken] has expired as of [now].
  ///
  /// A grant with no declared lifetime is never expired — the provider said
  /// nothing, and guessing a lifetime would throw away a working token.
  bool isExpired([DateTime? now]) => expiresWithin(Duration.zero, now);

  /// Whether [accessToken] expires within [margin] of [now].
  ///
  /// The margin is the point: a token that expires in two seconds is useless to
  /// a caller about to make a request over a slow link, so "is it still valid?"
  /// is the wrong question and "will it still be valid when it arrives?" is the
  /// right one.
  bool expiresWithin(Duration margin, [DateTime? now]) {
    final deadline = expiresAt;
    if (deadline == null) return false;
    return !(now ?? DateTime.now()).toUtc().add(margin).isBefore(deadline);
  }

  /// Reads a grant from a provider's token-endpoint [response].
  ///
  /// [previous] carries a refresh over: RFC 6749 §6 lets a provider omit
  /// `refresh_token` from a refresh response, meaning *keep using the one you
  /// have*, and a reader that took the omission literally would discard the
  /// long-lived credential on the first refresh and work perfectly until the
  /// access token expired.
  factory TomOAuthTokenGrant.fromTokenResponse(
    Map<String, Object?> response, {
    TomOAuthTokenGrant? previous,
    DateTime? now,
  }) {
    final issuedAt = (now ?? DateTime.now()).toUtc();
    final lifetime = _secondsOf(response['expires_in']);
    return TomOAuthTokenGrant(
      accessToken: _stringOf(response['access_token']),
      refreshToken:
          _nullableStringOf(response['refresh_token']) ?? previous?.refreshToken,
      tokenType: _nullableStringOf(response['token_type']) ?? 'Bearer',
      scope: _nullableStringOf(response['scope']) ?? previous?.scope ?? '',
      expiresAt: lifetime == null ? null : issuedAt.add(lifetime),
      obtainedAt: issuedAt,
    );
  }

  /// This grant as the JSON that goes into the encrypted column.
  ///
  /// The expiry is written as an instant rather than as the provider's
  /// `expires_in`, because the duration was only ever meaningful relative to a
  /// response that is long gone by the time anything reads this back.
  Map<String, Object?> toJson() => <String, Object?>{
    'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    'tokenType': tokenType,
    'scope': scope,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    'obtainedAt': obtainedAt.toIso8601String(),
  };

  /// Reads back what [toJson] wrote, or `null` when [json] is not a well-formed
  /// grant.
  ///
  /// Nullable rather than throwing, for the reason
  /// [TomPersistentOAuthTokenStore] needs it to be: the input has been through
  /// storage and a key rotation, and "this grant is unreadable" has one sane
  /// response — treat the user as not having granted anything — which a caller
  /// can express far better than an exception thrown from a decoder.
  static TomOAuthTokenGrant? fromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['accessToken'];
    if (access is! String || access.isEmpty) return null;
    final expiresAt = json['expiresAt'];
    final obtainedAt = json['obtainedAt'];
    return TomOAuthTokenGrant(
      accessToken: access,
      refreshToken: _nullableStringOf(json['refreshToken']),
      tokenType: _nullableStringOf(json['tokenType']) ?? 'Bearer',
      scope: _nullableStringOf(json['scope']) ?? '',
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
      obtainedAt: obtainedAt is String
          ? (DateTime.tryParse(obtainedAt) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Names the grant without printing either token.
  ///
  /// Both are credentials and this value reaches log lines; a `toString` that
  /// helpfully dumped its fields would put a third party's long-lived refresh
  /// token in the log the first time anyone debugged a delegated call.
  @override
  String toString() =>
      'TomOAuthTokenGrant($tokenType'
      '${scope.isEmpty ? '' : ', scope: $scope'}'
      '${expiresAt == null ? '' : ', expires: ${expiresAt!.toIso8601String()}'}'
      '${hasRefreshToken ? ', refreshable' : ''})';

  static String _stringOf(Object? value) => value == null ? '' : '$value';

  static String? _nullableStringOf(Object? value) {
    if (value == null) return null;
    final text = '$value';
    return text.isEmpty ? null : text;
  }

  /// `expires_in` as a duration. Providers send it as a number, and a few send
  /// it as a numeric string; both are accepted and anything else is ignored,
  /// because a lifetime nobody can parse is better treated as "unstated" than as
  /// "already expired".
  static Duration? _secondsOf(Object? value) {
    if (value is num) return Duration(seconds: value.round());
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return Duration(seconds: parsed.round());
    }
    return null;
  }
}

// =============================================================================
// CONTRACT
// =============================================================================

/// Where a provider's tokens live, keyed by the identity they were granted for.
///
/// Keyed on `(issuer, subject)` — the identity link's unique key — and *not* on
/// a local username, for the reason the link itself is not: a user may hold two
/// grants from two providers, and a local account is not what a provider issued
/// against.
///
/// An interface for the same reason [TomExternalIdentityStore] is one, and
/// separate from it for a reason worth stating: a deployment may keep its
/// identity links in a table of its own and still want the framework to hold the
/// credentials properly, or keep the links here and refuse to hold credentials
/// at all. Folding token storage into the link store would have made those two
/// choices one choice.
abstract class TomOAuthTokenStore {
  /// The grant held for `(issuer, subject)`, or `null` when none is.
  Future<TomOAuthTokenGrant?> read(String issuer, String subject);

  /// Records [grant] for `(issuer, subject)`, replacing any previous one.
  Future<void> store(String issuer, String subject, TomOAuthTokenGrant grant);

  /// Removes the grant for `(issuer, subject)`; removing one that is not there
  /// is a no-op, not an error.
  ///
  /// Called by [TomExternalIdentityStore.unlink], which is what makes "a token
  /// never outlives the link it was granted through" true rather than intended.
  Future<void> delete(String issuer, String subject);

  /// The installed [TomOAuthTokenStore] bean, or `null` when none is registered.
  ///
  /// `null` is the ordinary state and the safe one: no store means no provider
  /// token is ever written, which is precisely the framework's default position.
  static TomOAuthTokenStore? resolve() {
    final installed = TomBean.getBeanByType(TomOAuthTokenStore);
    return installed is TomOAuthTokenStore ? installed : null;
  }
}

// =============================================================================
// IN-MEMORY IMPLEMENTATION
// =============================================================================

/// A [TomOAuthTokenStore] held in a map, for tests and bring-up.
///
/// Not durable, and that is less of a problem here than for an identity link: a
/// grant lost on restart costs the user one re-consent, where a link lost on
/// restart costs them their account. It still says so, because a deployment that
/// installs this and then wonders why background jobs re-prompt every deploy has
/// found a real bug.
class TomMemoryOAuthTokenStore implements TomOAuthTokenStore {
  final Map<String, TomOAuthTokenGrant> _grants = {};

  /// Creates an empty store.
  TomMemoryOAuthTokenStore();

  @override
  Future<TomOAuthTokenGrant?> read(String issuer, String subject) async =>
      _grants[_keyOf(issuer, subject)];

  @override
  Future<void> store(
    String issuer,
    String subject,
    TomOAuthTokenGrant grant,
  ) async => _grants[_keyOf(issuer, subject)] = grant;

  @override
  Future<void> delete(String issuer, String subject) async =>
      _grants.remove(_keyOf(issuer, subject));

  /// Drops everything, so one test's grants cannot reach the next.
  void clear() => _grants.clear();

  /// The map key. A NUL separator, for the reason
  /// [TomMemoryExternalIdentityStore] uses one: it cannot occur in a URL-shaped
  /// issuer or a provider subject, so no two distinct identities can collide.
  String _keyOf(String issuer, String subject) => '$issuer\u0000$subject';
}

// =============================================================================
// PERSISTENT IMPLEMENTATION
// =============================================================================

/// The persisted form of one [TomOAuthTokenGrant] — a row of
/// `tom_external_identity_token`.
///
/// A table of its own rather than three more columns on `tom_external_identity`,
/// which was the tempting shape because it makes the cascade automatic. Two
/// things decided against it. The link row is a *value that travels*:
/// [TomExternalIdentityStore.identitiesOf] hands it to an account-settings page,
/// and a credential riding along on that listing is a leak waiting for the first
/// serialiser that does not know to exclude it. And the two stores are separate
/// beans precisely so a deployment can substitute one without the other —
/// putting the credential on the link row would have made holding tokens
/// conditional on also using the framework's link table.
///
/// [TomOAuthTokenGrant] is **not** mapped column by column. What is stored is
/// [tokenData] — the grant's JSON, encrypted; see [TomPersistentOAuthTokenStore]
/// for the scheme. The three plain columns beside it are the operator
/// projection, not the source of truth.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_external_identity_token',
  primaryKeyField: 'id',
)
class TomExternalIdentityToken {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn<int, TomDbInt>(columnName: 'id', isReadOnly: true)
  int id;

  /// The identity provider's issuer identifier — the first half of the key this
  /// row shares with [TomExternalIdentityLink].
  @TomDbColumn<String, TomDbString>(columnName: 'issuer')
  String issuer;

  /// The provider's stable identifier for the user, within [issuer].
  @TomDbColumn<String, TomDbString>(columnName: 'subject')
  String subject;

  /// The encrypted [TomOAuthTokenGrant]: base64 of RSA-OAEP over the grant's
  /// JSON. Never readable from the row alone.
  @TomDbColumn<String, TomDbString>(columnName: 'token_data')
  String tokenData;

  /// The granted scopes, in the clear — an operator's answer to "what does this
  /// grant cover?", which is not a secret and must not need the private key.
  @TomDbColumn<String, TomDbString>(columnName: 'token_scope')
  String tokenScope;

  /// When the grant was obtained (UTC), in the clear.
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'obtained_at')
  DateTime? obtainedAt;

  /// When the access token expires (UTC), in the clear.
  ///
  /// A **projection**: the authoritative expiry lives inside [tokenData], and
  /// nothing in this library decides anything from this column. It exists so
  /// "which grants have gone stale?" is a query rather than a decryption pass.
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'expires_at')
  DateTime? expiresAt;

  /// Creates a row. Every field defaults, because the repository instantiates a
  /// blank entity and fills it column by column when mapping a result.
  TomExternalIdentityToken({
    this.id = -1,
    this.issuer = '',
    this.subject = '',
    this.tokenData = '',
    this.tokenScope = '',
    this.obtainedAt,
    this.expiresAt,
  });

  /// The DDL this entity expects, reproduced verbatim by the framework
  /// migration so the two cannot drift.
  ///
  /// `(issuer, subject)` is unique because a second grant for the same identity
  /// would make which credential an application presents depend on row order —
  /// and the older of two rows is by definition the one whose refresh token the
  /// provider may already have rotated away.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_external_identity_token (
  id BIGINT NOT NULL AUTO_INCREMENT,
  issuer VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  token_data TEXT NULL,
  token_scope VARCHAR(1024) NOT NULL DEFAULT '',
  obtained_at DATETIME NULL,
  expires_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_external_identity_token (issuer, subject)
);''';
}

/// The repository for [TomExternalIdentityToken].
class TomExternalIdentityTokenRepository
    extends TomSqlDatasourceRepository<TomExternalIdentityToken, int> {}

/// A [TomOAuthTokenStore] over `tom_external_identity_token`, with the grant
/// encrypted at rest.
///
/// ## The encryption scheme, and why this one
///
/// The grant is JSON-encoded and passed through [TomJwtConfiguration.encrypt] —
/// RSA-OAEP, block-chained, base64-wrapped for a `TEXT` column — and read back
/// through the inverse. It is the framework's existing at-rest asymmetric
/// primitive, the same one behind a 2FA enrolment secret and a token's encrypted
/// claims section, so a deployment that has provisioned real keys has
/// provisioned *these* keys and one that has not gets the same loud dummy-key
/// warning here as everywhere else.
///
/// A provider refresh token is the most dangerous thing this framework ever
/// writes to a database. A password hash resists an offline attack; a 2FA secret
/// is confined to this deployment's logins. A refresh token is a *live, bearer*
/// credential at a third party, useful to whoever holds it, valid long after the
/// session that produced it, and revocable only by the user noticing. Storing it
/// in the clear would make a database backup a set of keys to other people's
/// mail.
///
/// [cipher] is a constructor argument for the reason
/// [TomPersistent2FAEnrolmentStore] takes one: a deployment may want these
/// long-lived secrets under a different key pair from its frequently rotated
/// signing key. Unset, it follows [TomJwtConfiguration.defaultSignConfiguration]
/// at *call* time, so installing production keys after boot is obeyed.
class TomPersistentOAuthTokenStore implements TomOAuthTokenStore {
  /// The repository grants are read and written through.
  final TomSqlDatasourceRepository<TomExternalIdentityToken, int> repository;

  final TomJwtConfiguration? _cipher;

  /// Creates the store over [repository], optionally with its own [cipher].
  const TomPersistentOAuthTokenStore(
    this.repository, {
    TomJwtConfiguration? cipher,
  }) : _cipher = cipher;

  /// The configuration used for this call — the injected one, else the current
  /// default. Resolved per call so a late key installation takes effect.
  TomJwtConfiguration get _configuration =>
      _cipher ?? TomJwtConfiguration.defaultSignConfiguration;

  @override
  Future<TomOAuthTokenGrant?> read(String issuer, String subject) async {
    final row = await _rowFor(issuer, subject);
    if (row == null || row.tokenData.isEmpty) return null;
    return _decode(row.tokenData);
  }

  @override
  Future<void> store(
    String issuer,
    String subject,
    TomOAuthTokenGrant grant,
  ) async {
    // Reuse the found row rather than inserting a second: the repository takes
    // its UPDATE path exactly when the surrogate key is set, and the unique key
    // on (issuer, subject) would reject the alternative anyway.
    final row = await _rowFor(issuer, subject) ?? TomExternalIdentityToken();
    row.issuer = issuer;
    row.subject = subject;
    row.tokenData = _configuration.encrypt(jsonEncode(grant.toJson()));
    row.tokenScope = grant.scope;
    row.obtainedAt = grant.obtainedAt;
    row.expiresAt = grant.expiresAt;
    await repository.save(row);
  }

  @override
  Future<void> delete(String issuer, String subject) async {
    await repository.deleteByQuerySentence(
      'DELETE BY issuer = :issuer AND subject = :subject',
      {'issuer': issuer, 'subject': subject},
    );
  }

  Future<TomExternalIdentityToken?> _rowFor(
    String issuer,
    String subject,
  ) async {
    final matches = await repository.findByQuerySentence(
      'FIND BY issuer = :issuer AND subject = :subject',
      {'issuer': issuer, 'subject': subject},
    );
    return matches.isEmpty ? null : matches.first;
  }

  /// Decrypts a stored [cipherText] back into a grant.
  ///
  /// A row that cannot be decrypted — written under a key that has since been
  /// rotated away — yields `null` rather than throwing. The honest reading of
  /// "the credential is unrecoverable" is *this user has granted nothing*, which
  /// sends the caller down the re-consent path; throwing would instead fail
  /// whatever background work asked, over and over, until someone read the log.
  TomOAuthTokenGrant? _decode(String cipherText) {
    try {
      return TomOAuthTokenGrant.fromJson(
        jsonDecode(_configuration.decrypt(cipherText)),
      );
    } catch (error) {
      // Logged without the ciphertext and without the error's own message: a
      // decryption failure's detail is about the key, and this line is destined
      // for a log an operator reads.
      tomLog.error(
        'Undecryptable external-identity token grant (${error.runtimeType}); '
        'treating the identity as holding no provider tokens',
      );
      return null;
    }
  }
}
