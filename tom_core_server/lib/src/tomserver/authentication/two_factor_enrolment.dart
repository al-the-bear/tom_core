/// Which second factors a user has actually set up — the store behind "*choose
/// a method*".
///
/// ## Why this exists
///
/// [Tom2FARegistry.availableMethods] answers *what could be used here*. It is a
/// property of the deployment, identical for every user. The question a login
/// actually has to answer is narrower and per-user: *what has **this** user set
/// up?* Before this library there was no answer at all — the only enrolment
/// state was [TomTotp2FAService.globalSettingSecretResolver], a single hook that
/// spoke for exactly one mechanism and had no notion of "several", "primary" or
/// "none yet".
///
/// That gap is not cosmetic. "Has this user enrolled a second factor?" is the
/// condition a forced-enrolment flow branches on; "which of the user's factors
/// do we challenge?" is the choice the login offers; and neither is expressible
/// as one nullable secret.
///
/// ## The shape
///
/// - [Tom2FAEnrolment] — one set-up factor: the mechanism, a stable id, a
///   displayable [Tom2FAEnrolment.hint], when it was enrolled, whether it is the
///   user's default, and the mechanism's own opaque
///   [Tom2FAEnrolment.secretData].
/// - [Tom2FAEnrolmentStore] — read/write access to a principal's enrolments;
///   [Tom2FAEnrolmentStore.resolve] finds the installed one (G-DI-3).
/// - [TomMemory2FAEnrolmentStore] — for tests and for a deployment that has not
///   provisioned a database yet.
/// - [TomPersistent2FAEnrolmentStore] over [TomUserTwoFactorEnrolment] — the
///   real one, through the ordinary CRUD repository, with `secret_data`
///   **encrypted at rest**.
///
/// ## Why this is a separate library from `two_factor.dart`
///
/// The two import each other: the adaptor contract needs the store to resolve a
/// user's secret, and an enrolment is described in terms of a
/// [Tom2FAContext]. Dart permits the cycle, and the alternative — a third
/// library holding just the context — would split the 2FA flow across three
/// files to avoid an import graph nobody reads. The split that *is* worth
/// making is the one here: the mechanism contract has no dependency on
/// persistence annotations or a datasource, and this library does, so a
/// deployment that never persists an enrolment does not pay for the
/// repository.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/persistence_annotations.dart';
import 'two_factor.dart';

// =============================================================================
// VALUE
// =============================================================================

/// One second factor a user has set up.
///
/// A value, not a row: the memory store and the persistent store hand back the
/// same type, so nothing above them can tell which is installed. That is what
/// lets the login flow be tested without a database and run against one
/// unchanged.
class Tom2FAEnrolment {
  /// The mechanism key this enrolment is for — the same value
  /// [Tom2FARegistry.lookup] resolves.
  final String type;

  /// Identifies this enrolment among the user's others, stably across logins.
  ///
  /// Chosen by whatever performed the enrolment (a device id, a uuid), not by
  /// the store: the client that offers "remove this authenticator" needs a
  /// handle it can quote back, and a surrogate database key would tie that
  /// handle to one storage implementation.
  final String enrolmentId;

  /// A short displayable clue distinguishing this enrolment from the user's
  /// others — a masked phone number, a device name.
  ///
  /// Deliberately **not** resource-keyed, unlike everything on
  /// [Tom2FAMethodDescriptor]: a hint is user *data*, not interface text. There
  /// is no locale in which `'iPhone 14'` or `'•••• 4417'` should read
  /// differently, and routing it through a resource bundle would only invite a
  /// missing-key placeholder where the user expects to recognise their own
  /// device.
  final String hint;

  /// When the user set this factor up (UTC).
  final DateTime enrolledAt;

  /// Whether this is the factor to challenge when the user expresses no choice.
  ///
  /// At most one of a user's enrolments should carry it; the store does not
  /// enforce that, because the flow's fallback — first enrolment in the list —
  /// is well-defined either way, and a uniqueness rule that can be violated by
  /// a concurrent write would fail a login rather than merely pick oddly.
  final bool isPrimary;

  /// The mechanism's own state for this enrolment: a TOTP shared secret, a
  /// phone number, a credential id. Opaque to everything but the adaptor that
  /// wrote it.
  ///
  /// Treated as **secret in full**, not per key: the store encrypts the whole
  /// map, because a mechanism added later must not be able to leak by filing
  /// something sensitive under a key the store had not been told about.
  final Map<String, Object?> secretData;

  /// Records one enrolled factor.
  ///
  /// [enrolledAt] defaults to now and is normalised to UTC — the value crosses
  /// a database boundary, and a local-time timestamp read back on a server in
  /// another zone is silently wrong.
  Tom2FAEnrolment({
    required this.type,
    required this.enrolmentId,
    this.hint = '',
    DateTime? enrolledAt,
    this.isPrimary = false,
    Map<String, Object?> secretData = const {},
  })  : enrolledAt = (enrolledAt ?? DateTime.now()).toUtc(),
        secretData = Map.unmodifiable(secretData);

  /// This enrolment with selected fields replaced.
  Tom2FAEnrolment copyWith({
    String? type,
    String? enrolmentId,
    String? hint,
    DateTime? enrolledAt,
    bool? isPrimary,
    Map<String, Object?>? secretData,
  }) =>
      Tom2FAEnrolment(
        type: type ?? this.type,
        enrolmentId: enrolmentId ?? this.enrolmentId,
        hint: hint ?? this.hint,
        enrolledAt: enrolledAt ?? this.enrolledAt,
        isPrimary: isPrimary ?? this.isPrimary,
        secretData: secretData ?? this.secretData,
      );

  /// Names the enrolment without ever printing [secretData] — this value ends
  /// up in log lines, and a `toString` that helpfully dumped its fields would
  /// put a TOTP secret in the log the first time anyone debugged a login.
  @override
  String toString() => 'Tom2FAEnrolment($type/$enrolmentId'
      '${hint.isEmpty ? '' : ' "$hint"'}${isPrimary ? ', primary' : ''})';
}

/// What an adaptor produces when asked to *begin* setting a factor up — the
/// enrolment counterpart of [Tom2FAChallengeSpec].
///
/// The same split, for the same reason: [clientData] is what the user must be
/// given (for TOTP the base32 secret and the `otpauth://` URI behind the QR
/// code, for SMS the number a code was sent to), [enrolmentData] is what only
/// the server may see. Confirmation checks the typed code against
/// [enrolmentData], never against [clientData] — the latter travels in public
/// claims, and a confirmation that trusted it would let a client enrol a secret
/// of its own choosing and call it confirmed.
///
/// For TOTP the secret appears in *both*, deliberately: in [clientData] because
/// handing it to the user is the entire point of enrolment, and in
/// [enrolmentData] because the server must confirm against a copy the user's
/// browser could not have edited on the way past.
///
/// Carried between [Tom2FAEnrolmentSupport.beginEnrolment] and
/// [Tom2FAEnrolmentSupport.confirmEnrolment] in the interim token — see
/// [Tom2FAEnrolmentClaims] — so enrolment is as stateless as verification and
/// any instance can finish what another started. Nothing is written to the
/// [Tom2FAEnrolmentStore] until confirmation succeeds.
class Tom2FAEnrolmentOffer {
  /// The mechanism key this offer is for — the same value
  /// [Tom2FARegistry.lookup] resolves.
  final String type;

  /// A short displayable clue for the factor being set up, carried through to
  /// [Tom2FAEnrolment.hint] on confirmation. Empty when the mechanism has
  /// nothing worth showing.
  final String hint;

  /// The mechanism's client-visible enrolment payload; carried in the interim
  /// token's public claims and interpreted only by the mechanism's own client
  /// code.
  final Map<String, Object?> clientData;

  /// The mechanism's server-only enrolment payload; carried in the interim
  /// token's encrypted section and handed back to
  /// [Tom2FAEnrolmentSupport.confirmEnrolment].
  final Map<String, Object?> enrolmentData;

  /// How many confirmation attempts this offer tolerates before it is burned.
  final int attemptsAllowed;

  /// How long the offer stays confirmable.
  ///
  /// Bounded, not open-ended: an unconfirmed secret sitting in a token forever
  /// is a credential nobody is watching, and the user who abandoned the setup
  /// has no way to revoke it.
  final Duration validity;

  /// Describes a freshly begun enrolment.
  const Tom2FAEnrolmentOffer({
    required this.type,
    this.hint = '',
    this.clientData = const {},
    this.enrolmentData = const {},
    this.attemptsAllowed = 3,
    this.validity = const Duration(minutes: 10),
  });

  /// The offer as a JSON-safe map, for [Tom2FAEnrolmentClaims.offerData].
  ///
  /// Whole, including [enrolmentData]: the claim it goes into is the encrypted
  /// one, and an offer that round-tripped without its server section could not
  /// be confirmed by the instance that received it.
  Map<String, Object?> toClaim() => {
        _claimType: type,
        _claimHint: hint,
        _claimClientData: clientData,
        _claimEnrolmentData: enrolmentData,
        _claimAttemptsAllowed: attemptsAllowed,
        _claimValiditySeconds: validity.inSeconds,
      };

  /// Reads back what [toClaim] wrote, or `null` when [claim] is not a
  /// well-formed offer.
  ///
  /// Nullable rather than throwing because the input is a decoded token: a
  /// truncated, tampered-with or older-release claim is an ordinary thing to
  /// meet, and the caller's response to all three is the same — refuse the
  /// confirmation. Fields other than the type fall back to their defaults, so
  /// an offer written before a field existed still confirms.
  static Tom2FAEnrolmentOffer? fromClaim(Object? claim) {
    if (claim is! Map) return null;
    final type = claim[_claimType];
    if (type is! String || type.isEmpty) return null;
    final validitySeconds = claim[_claimValiditySeconds];
    return Tom2FAEnrolmentOffer(
      type: type,
      hint: claim[_claimHint] is String ? claim[_claimHint] as String : '',
      clientData: _mapOf(claim[_claimClientData]),
      enrolmentData: _mapOf(claim[_claimEnrolmentData]),
      attemptsAllowed:
          claim[_claimAttemptsAllowed] is int ? claim[_claimAttemptsAllowed] as int : 3,
      validity: Duration(
        seconds: validitySeconds is int ? validitySeconds : 600,
      ),
    );
  }

  static Map<String, Object?> _mapOf(Object? value) => value is Map
      ? {for (final entry in value.entries) '${entry.key}': entry.value}
      : const {};

  static const String _claimType = 'type';
  static const String _claimHint = 'hint';
  static const String _claimClientData = 'clientData';
  static const String _claimEnrolmentData = 'enrolmentData';
  static const String _claimAttemptsAllowed = 'attemptsAllowed';
  static const String _claimValiditySeconds = 'validitySeconds';

  /// Names the offer without printing either payload — [clientData] carries the
  /// secret being enrolled, and this value reaches log lines.
  @override
  String toString() =>
      'Tom2FAEnrolmentOffer($type${hint.isEmpty ? '' : ' "$hint"'})';
}

// =============================================================================
// CONTRACT
// =============================================================================

/// Where a principal's set-up second factors live.
///
/// Reads and writes only. Deciding *whether* a factor is owed is
/// [Tom2FAPolicy]'s, issuing and verifying one is [Tom2FAService]'s; a store
/// that also decided would make the two answerable in two places.
///
/// The [Tom2FAContext] rather than a bare principal id is the key throughout,
/// for the same reason the adaptors take one: a multi-tenant deployment may
/// scope enrolments by organization, and a store handed only an id could not.
abstract class Tom2FAEnrolmentStore {
  /// Every factor this principal has set up, in no guaranteed order beyond
  /// what the implementation offers.
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context);

  /// Records [enrolment], replacing any existing one with the same
  /// [Tom2FAEnrolment.enrolmentId] for this principal.
  ///
  /// Upsert rather than insert: re-running an enrolment is how a user replaces
  /// a lost authenticator, and making that path an error would leave the user
  /// with a factor they cannot use and cannot overwrite.
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment);

  /// Removes this principal's enrolment with [enrolmentId]; removing one that
  /// is not there is a no-op, not an error.
  Future<void> remove(Tom2FAContext context, String enrolmentId);

  /// The store this deployment installed, or `null`.
  ///
  /// Nullable with **no** default, unlike [Tom2FAPolicy.resolve]: a policy has
  /// a meaningful "behave as before" fallback, whereas a fallback store would
  /// be an empty one — and an empty store is indistinguishable from *this user
  /// has enrolled nothing*, which is exactly the answer callers must not be
  /// given wrongly. `null` says "no store here, ask the legacy hook"; an empty
  /// list says "asked, and this user has none".
  ///
  /// Uses [TomBean.getBeanByType] because *not installed* is an ordinary case;
  /// the resolving handle would throw.
  static Tom2FAEnrolmentStore? resolve() {
    final installed = TomBean.getBeanByType(Tom2FAEnrolmentStore);
    return installed is Tom2FAEnrolmentStore ? installed : null;
  }

  /// The storage key for the principal in [context].
  ///
  /// One place, so the memory store and the persistent store agree on what
  /// "this user" means and a test written against one is meaningful for the
  /// other.
  static String principalKeyOf(Tom2FAContext context) =>
      context.principal.id.toString();
}

/// What a mechanism implements when a user can *set it up* — the third
/// question, asked only of the mechanisms that have an answer.
///
/// ## Why this is not on [Tom2FAService]
///
/// [Tom2FAService] asks two questions and says so: issue a challenge, verify a
/// submission. Enrolment is a third, and not every mechanism has one — a
/// hardware token an administrator provisions, or a mechanism backed by a
/// corporate directory, is *acquired* entirely outside the framework and has
/// nothing to offer here. Widening the base contract would force those adaptors
/// to implement a method whose only honest body is a throw, and every caller to
/// treat that throw as a normal outcome. A separate interface makes "can this be
/// enrolled?" an `is` check that [Tom2FARegistry.enrollableMethods] answers for
/// the whole registry at once.
///
/// ## Why confirmation is not optional
///
/// The pair is `begin` then `confirm`, and nothing is stored in between. Storing
/// an unconfirmed secret locks the user out of their own account whenever the QR
/// scan silently failed: the server believes a factor is enrolled, the
/// authenticator holds nothing, and the next login demands a code that cannot be
/// produced. Making the user type back a derived code proves the secret arrived
/// before it is allowed to become a login requirement.
///
/// Implementations must be stateless between the two calls, for the same reason
/// [Tom2FAService] must be: they may run on different instances. Everything the
/// confirmation needs travels in the [Tom2FAEnrolmentOffer].
abstract class Tom2FAEnrolmentSupport {
  /// Begins setting this mechanism up for [context]'s principal: generates
  /// whatever the factor needs and returns it as an offer.
  ///
  /// Nothing is persisted. Throws [LoginException] when this user cannot enrol
  /// this mechanism at all (no phone number on file, a quota reached).
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context);

  /// Confirms [offer] against what the user typed back, returning the enrolment
  /// to store.
  ///
  /// Returns only on success — the return type is non-nullable precisely so that
  /// "an enrolment came back" cannot mean anything but "confirmed". A wrong
  /// [submitted] throws [LoginException]; the caller may re-offer the same
  /// offer until [Tom2FAEnrolmentOffer.attemptsAllowed] is spent.
  ///
  /// Implementations must derive the expected answer from
  /// [Tom2FAEnrolmentOffer.enrolmentData] and never from
  /// [Tom2FAEnrolmentOffer.clientData].
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  );
}

// =============================================================================
// IN-MEMORY IMPLEMENTATION
// =============================================================================

/// A [Tom2FAEnrolmentStore] held in a map, for tests and for a deployment
/// running before its database exists.
///
/// Not a cache in front of anything and not durable: everything it holds is
/// lost with the process. That is the point — a test that must assert on the
/// login flow's branches should not need MariaDB to do it.
class TomMemory2FAEnrolmentStore implements Tom2FAEnrolmentStore {
  final Map<String, Map<String, Tom2FAEnrolment>> _byPrincipal = {};

  /// Creates an empty store.
  TomMemory2FAEnrolmentStore();

  @override
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context) async {
    final principal = Tom2FAEnrolmentStore.principalKeyOf(context);
    // Copied out, so a caller iterating the result cannot be surprised by a
    // concurrent enrolment, and cannot mutate the store by editing the list.
    return List.unmodifiable(_byPrincipal[principal]?.values ?? const []);
  }

  @override
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment) async {
    final principal = Tom2FAEnrolmentStore.principalKeyOf(context);
    (_byPrincipal[principal] ??= {})[enrolment.enrolmentId] = enrolment;
  }

  @override
  Future<void> remove(Tom2FAContext context, String enrolmentId) async {
    final principal = Tom2FAEnrolmentStore.principalKeyOf(context);
    _byPrincipal[principal]?.remove(enrolmentId);
  }

  /// Drops everything, so one test's enrolments cannot reach the next.
  void clear() => _byPrincipal.clear();
}

// =============================================================================
// PERSISTENT IMPLEMENTATION
// =============================================================================

/// The persisted form of one [Tom2FAEnrolment] — a row of
/// `tom_user_two_factor_enrolment`.
///
/// Mapped through the ordinary object-persistence annotations, like every other
/// framework table that has an entity ([TomPrincipalResourceGrant],
/// [TomPrincipalDelegation]): a second persistence path for one table would
/// have to reimplement binding, row mapping and the audit hook, and would drift.
///
/// [secretData] is **not** a column. What is stored is [secretDataCipher] — the
/// JSON of the map, encrypted; see [TomPersistent2FAEnrolmentStore] for the
/// scheme and why.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_user_two_factor_enrolment',
  primaryKeyField: 'id',
)
class TomUserTwoFactorEnrolment {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn<int, TomDbInt>(columnName: 'id', isReadOnly: true)
  int id;

  /// The principal the factor belongs to (`TomPrincipal.id`, stringified —
  /// matching [TomPrincipalResourceGrant.principalId]).
  @TomDbColumn<String, TomDbString>(columnName: 'principal_id')
  String principalId;

  /// The enrolment's stable client-facing handle
  /// ([Tom2FAEnrolment.enrolmentId]).
  @TomDbColumn<String, TomDbString>(columnName: 'enrolment_id')
  String enrolmentId;

  /// The mechanism key ([Tom2FAEnrolment.type]).
  @TomDbColumn<String, TomDbString>(columnName: 'mechanism')
  String mechanism;

  /// The displayable hint ([Tom2FAEnrolment.hint]).
  @TomDbColumn<String, TomDbString>(columnName: 'hint')
  String hint;

  /// When the factor was set up (UTC).
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'enrolled_at')
  DateTime? enrolledAt;

  /// Whether this is the user's default factor.
  @TomDbColumn<bool, TomDbBool>(columnName: 'is_primary')
  bool isPrimary;

  /// The encrypted [Tom2FAEnrolment.secretData]: base64 of RSA-OAEP over the
  /// map's JSON. Never readable from the row alone.
  @TomDbColumn<String, TomDbString>(columnName: 'secret_data')
  String secretDataCipher;

  /// Creates a row. Every field defaults, because the repository instantiates a
  /// blank entity and fills it column by column when mapping a result.
  TomUserTwoFactorEnrolment({
    this.id = -1,
    this.principalId = '',
    this.enrolmentId = '',
    this.mechanism = '',
    this.hint = '',
    this.enrolledAt,
    this.isPrimary = false,
    this.secretDataCipher = '',
  });

  /// The DDL this entity expects, reproduced verbatim by the framework
  /// migration so the two cannot drift.
  ///
  /// `(principal_id, enrolment_id)` is unique because that pair *is* the
  /// enrolment's identity — the upsert in
  /// [TomPersistent2FAEnrolmentStore.store] relies on there being at most one
  /// row to find, and a duplicate would make which secret answers a login
  /// depend on row order.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_user_two_factor_enrolment (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  enrolment_id VARCHAR(255) NOT NULL,
  mechanism VARCHAR(64) NOT NULL,
  hint VARCHAR(255) NOT NULL DEFAULT '',
  enrolled_at DATETIME NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  secret_data TEXT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_two_factor_enrolment (principal_id, enrolment_id),
  KEY idx_tom_user_two_factor_enrolment_principal (principal_id)
);''';
}

/// The repository for [TomUserTwoFactorEnrolment].
///
/// Shipped rather than left to the deployment (as the authorization tables are)
/// because [TomPersistent2FAEnrolmentStore] is itself shipped and would
/// otherwise be unusable without the caller writing this one empty line.
class TomUserTwoFactorEnrolmentRepository
    extends TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int> {}

/// A [Tom2FAEnrolmentStore] over `tom_user_two_factor_enrolment`, with the
/// mechanism's secret encrypted at rest.
///
/// ## The encryption scheme, and why this one
///
/// [Tom2FAEnrolment.secretData] is JSON-encoded and then passed through
/// [TomJwtConfiguration.encrypt] — **RSA-OAEP** (SHA-1 MGF1, PointyCastle's
/// `OAEPEncoding(RSAEngine())`), block-chained so a map of any size is safe,
/// base64-wrapped for a `TEXT` column. Reading it back is the inverse through
/// [TomJwtConfiguration.decrypt], with the RSA private key.
///
/// A TOTP shared secret is a *credential*: anyone holding it can generate the
/// user's codes forever, so a readable `tom_user_two_factor_enrolment` is a
/// complete 2FA bypass and a database backup is a bearer token. Storing it in
/// the clear would make the second factor security theatre against exactly the
/// attacker it exists to stop — the one who already reached the database.
///
/// The scheme is [TomJwtConfiguration]'s and not a new one because that is the
/// framework's existing at-rest/in-transit asymmetric primitive: it is what the
/// authorization token's encrypted claims section already uses, so a deployment
/// that has provisioned real keys has provisioned *these* keys, and one that has
/// not gets the same loud dummy-key warning here as everywhere else. A second,
/// 2FA-only cipher would mean a second key to rotate and a second place to get
/// it wrong.
///
/// [cipher] is a constructor argument so a deployment can hand this store a
/// **different** key pair from its token configuration — enrolment secrets are
/// long-lived where a signing key is rotated often, and a deployment that wants
/// them decoupled should not have to fork the store to get it. Unset, it
/// follows [TomJwtConfiguration.defaultSignConfiguration] at *call* time, so
/// installing production keys after boot is obeyed.
class TomPersistent2FAEnrolmentStore implements Tom2FAEnrolmentStore {
  /// The repository the store reads and writes enrolment rows through.
  final TomSqlDatasourceRepository<TomUserTwoFactorEnrolment, int> repository;

  final TomJwtConfiguration? _cipher;

  /// Creates the store over [repository], optionally with its own [cipher].
  const TomPersistent2FAEnrolmentStore(
    this.repository, {
    TomJwtConfiguration? cipher,
  }) : _cipher = cipher;

  /// The configuration used for this call — the injected one, else the current
  /// default. Resolved per call so a late key installation takes effect.
  TomJwtConfiguration get _configuration =>
      _cipher ?? TomJwtConfiguration.defaultSignConfiguration;

  @override
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context) async {
    final rows = await repository.findByQuerySentence(
      'FIND BY principal_id = :principalId',
      {'principalId': Tom2FAEnrolmentStore.principalKeyOf(context)},
    );
    return List.unmodifiable(rows.map(_toEnrolment));
  }

  @override
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment) async {
    final principalId = Tom2FAEnrolmentStore.principalKeyOf(context);
    final existing = await _rowFor(principalId, enrolment.enrolmentId);

    // Reuse the found row rather than inserting a second: the repository takes
    // its UPDATE path exactly when the surrogate key is set, so carrying the id
    // over is what makes this an upsert.
    final row = existing ?? TomUserTwoFactorEnrolment();
    row.principalId = principalId;
    row.enrolmentId = enrolment.enrolmentId;
    row.mechanism = enrolment.type;
    row.hint = enrolment.hint;
    row.enrolledAt = enrolment.enrolledAt;
    row.isPrimary = enrolment.isPrimary;
    row.secretDataCipher = _encode(enrolment.secretData);

    await repository.save(row);
  }

  @override
  Future<void> remove(Tom2FAContext context, String enrolmentId) async {
    await repository.deleteByQuerySentence(
      'DELETE BY principal_id = :principalId AND enrolment_id = :enrolmentId',
      {
        'principalId': Tom2FAEnrolmentStore.principalKeyOf(context),
        'enrolmentId': enrolmentId,
      },
    );
  }

  Future<TomUserTwoFactorEnrolment?> _rowFor(
    String principalId,
    String enrolmentId,
  ) async {
    final matches = await repository.findByQuerySentence(
      'FIND BY principal_id = :principalId AND enrolment_id = :enrolmentId',
      {'principalId': principalId, 'enrolmentId': enrolmentId},
    );
    return matches.isEmpty ? null : matches.first;
  }

  Tom2FAEnrolment _toEnrolment(TomUserTwoFactorEnrolment row) => Tom2FAEnrolment(
        type: row.mechanism,
        enrolmentId: row.enrolmentId,
        hint: row.hint,
        enrolledAt: row.enrolledAt,
        isPrimary: row.isPrimary,
        secretData: _decode(row.secretDataCipher),
      );

  /// Encrypts [secretData] for storage; an empty map is stored as an empty
  /// string rather than as ciphertext of `{}`, so a mechanism that keeps no
  /// secret costs no key operation and leaves nothing to decrypt.
  String _encode(Map<String, Object?> secretData) =>
      secretData.isEmpty ? '' : _configuration.encrypt(jsonEncode(secretData));

  /// Decrypts a stored [cipherText] back into the mechanism's map.
  ///
  /// A row that cannot be decrypted — written under a key that has since been
  /// rotated away — yields an **empty** map rather than throwing. The caller is
  /// a login, and the honest reading of "the secret is unrecoverable" is *this
  /// factor cannot answer a challenge*, which an empty map already expresses:
  /// the adaptor finds no secret and the login fails as not-enrolled. Throwing
  /// would instead fail the *whole* login, including the user's other, perfectly
  /// good factors.
  Map<String, Object?> _decode(String cipherText) {
    if (cipherText.isEmpty) return const {};
    try {
      final decoded = jsonDecode(_configuration.decrypt(cipherText));
      return decoded is Map<String, Object?> ? decoded : const {};
    } catch (error) {
      // Logged without the ciphertext and without the error's own message: a
      // decryption failure's detail is about the key, and this line is destined
      // for a log an operator reads.
      tomLog.error(
        'Undecryptable 2FA enrolment secret (${error.runtimeType}); '
        'treating the enrolment as unusable',
      );
      return const {};
    }
  }
}
