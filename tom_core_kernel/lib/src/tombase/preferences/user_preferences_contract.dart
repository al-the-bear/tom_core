/// The wire contract for server-stored user preferences (C-13): the DTOs and
/// the [TomApi] declaration both halves of the framework bind to.
///
/// The *store* is server-side — a table, a repository, a row scope — and cannot
/// live here. What has to live here is the part the two halves must agree on:
/// the shape of a preference on the wire, and the URI / method / request type /
/// result type / access policy of every endpoint that carries one (G-API-1,
/// G-API-3). The kernel is the framework's contracts package: it is the one
/// package a client and a server both already depend on, so declaring the API
/// anywhere else would mean one of them re-stating it — and a re-stated
/// contract is a contract that drifts.
///
/// ## A preference carries its own type
///
/// A preference value is stored as JSON text plus the name of the type it was
/// written as ([TomUserPreferenceDto.valueType]). The type name is not
/// decoration: it is what lets a reflected object round-trip
/// ([TomReflectionInfo.createInstanceFromJson] needs a `ClassMirror`), and it is
/// what makes a *mismatched* read fail loudly instead of quietly parsing a
/// `Duration` as an `int`. Reading a preference is therefore typed on both
/// sides — the caller says what it expects, and the stored value says what it
/// is.
library;

import '../http_connection/endpoints_apis.dart';
import '../http_connection/httpmethods.dart';
import '../reflection/reflection.dart';
import '../security/access_controls.dart';
import 'user_preference_codec.dart';

/// One stored preference as it travels the wire.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer.
@tomReflector
class TomUserPreferenceDto {
  /// The preference key — see [TomUserPreferenceKeys] for the ones the
  /// framework itself reads.
  String key;

  /// The name of the type [value] was written as.
  ///
  /// A scalar's Dart type name (`String`, `int`, `double`, `bool`,
  /// `DateTime`), or the simple name of a `@tomReflector` class. It is stored
  /// with the value rather than derived from it because JSON forgets: `3` is an
  /// `int` and a `double`, `"2026-01-01T00:00:00Z"` is a `String` and a
  /// `DateTime`, and a map is every reflected class at once.
  String valueType;

  /// The value's JSON text.
  ///
  /// Text rather than a decoded `Object?` so the DTO is flat: a
  /// `Map<String, Object?>` field would have to survive the reflection
  /// serializer twice — once as the DTO's own field and again as the
  /// preference's payload — and the two nestings do not compose.
  String value;

  /// When the preference was last written, in UTC, or `null` for one that has
  /// never been stored.
  ///
  /// UTC because the constructor converts it, not because callers remember to:
  /// a `DateTime` cannot carry the zone in its type, so a server writing
  /// `DateTime.now()` instead of `DateTime.now().toUtc()` would satisfy every
  /// check and still hand a client an instant whose meaning depends on which
  /// machine wrote it. That is the same rule the *value* path already applies
  /// to a stored `DateTime` — see [TomUserPreferenceCodec.dateTimeType] — and
  /// it applies here for the same reason: a preference follows the user across
  /// devices.
  ///
  /// The conversion preserves the instant; it only settles how the instant is
  /// named. Reflection now applies the same normalisation on the way out — a
  /// bare `DateTime` is written as `toUtc().toIso8601String()`, so the wire is
  /// safe whatever a caller assigned — which makes this the *field's* rule
  /// rather than the wire's last line of defence. It is still worth having
  /// here: a reader of `updatedAt` gets a UTC instant from the object as well
  /// as from the payload, so the two cannot disagree, and code that never
  /// serializes the DTO sees the same value the code that does would send.
  ///
  /// Assigning the field directly afterwards is not intercepted — a wire
  /// DTO's fields are plain and public (G-DTO), so there is no setter to hook.
  /// Every DTO the framework itself produces goes through this constructor.
  DateTime? updatedAt;

  /// Creates a preference DTO. Every field defaults, because the reflection
  /// path instantiates a blank instance and fills it field by field.
  TomUserPreferenceDto({
    this.key = '',
    this.valueType = '',
    this.value = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt?.toUtc();

  @override
  String toString() => 'TomUserPreferenceDto($key: $valueType)';
}

/// The request for writing one preference.
///
/// Carries the same three fields as the result minus the timestamp: *when* a
/// preference was written is the server's answer, never the client's claim.
///
/// This request is the write's *only* statement of which preference it means —
/// the write URI is the bare collection, not `/{key}` — so [key] is read from
/// the body and nothing else can contradict it.
@tomReflector
class TomUserPreferenceWriteRequest {
  /// The preference key to write.
  ///
  /// Travels in the request body, not the URL.
  String key;

  /// The name of the type [value] is encoded as — see
  /// [TomUserPreferenceDto.valueType].
  String valueType;

  /// The value's JSON text.
  String value;

  /// Creates a write request.
  TomUserPreferenceWriteRequest({
    this.key = '',
    this.valueType = '',
    this.value = '',
  });

  @override
  String toString() => 'TomUserPreferenceWriteRequest($key: $valueType)';
}

/// The request for reading or deleting one preference by key.
///
/// A DTO rather than a bare `String` handler parameter because the path capture
/// binds onto a typed field (G-API-2), the same way the rest of the framework's
/// by-id endpoints do.
@tomReflector
class TomUserPreferenceKeyRequest {
  /// The addressed preference key (captured from the URL path).
  String key;

  /// Creates a by-key request.
  TomUserPreferenceKeyRequest({this.key = ''});

  @override
  String toString() => 'TomUserPreferenceKeyRequest($key)';
}

/// The API id [tomUserPreferencesApi] is registered and bound under.
///
/// A constant because the server's `@TomApiEndpointImplementation(apiId: …)`
/// has to name it, and a literal restated on the implementation side is the
/// one string that can go wrong without anything failing to compile.
const String tomUserPreferencesApiId = 'tomUserPreferences';

/// Endpoint id: read every preference of the calling principal.
const String tomUserPreferencesListEndpointId = 'listPreferences';

/// Endpoint id: read one preference of the calling principal by key.
const String tomUserPreferencesReadEndpointId = 'readPreference';

/// Endpoint id: write one preference of the calling principal.
const String tomUserPreferencesWriteEndpointId = 'writePreference';

/// Endpoint id: delete one preference of the calling principal by key.
const String tomUserPreferencesDeleteEndpointId = 'deletePreference';

/// Endpoint id: delete every preference of the calling principal.
const String tomUserPreferencesClearEndpointId = 'clearPreferences';

/// The error key the read endpoint answers with for a preference the caller
/// has never written — the contract's statement of absence.
///
/// **Absence is a status plus a key, never a status alone.** The read answers a
/// miss with `404` and the framework's error envelope, whose `errorKey` is this
/// constant. A `404` *without* that envelope means something else entirely:
/// the endpoint pipeline answers a denied or unauthenticated call with a bare
/// `404`, deliberately indistinguishable from a route that does not exist, and
/// a deployment that never mounted the API answers the same way. A caller that
/// read every `404` as "not set" would hand a signed-out user the defaults and
/// report a refused delete as done — so the key, not the status, is what a
/// caller branches on.
///
/// The result type stays [TomUserPreferenceDto] rather than a nullable one
/// because the endpoint pipeline answers a `null` result exactly as it answers
/// a `void` one — `200` with an empty body — which would make "not set" look
/// like success. Absence therefore has to be an error of the invocation, and
/// this constant is
/// what lets the two halves agree on which one. It lives here, in the contract,
/// because the server raises it and the client recognises it, and a key spelled
/// twice is a key that drifts.
const String tomUserPreferencesNotFoundErrorKey = 'preferences.not_found';

/// The most preferences one principal may hold: 256.
///
/// **This is what makes [TomUserPreferencesApiService.listPreferences] safe to
/// answer in full.** The list takes no page and no filter, because a caller
/// that syncs or renders preferences wants all of them, and a paged answer
/// would make every such caller loop. That is only sound if "all of them" is a
/// bounded quantity, so it is bounded here: at most this many entries, each
/// holding at most [TomUserPreferenceCodec.maxValueBytes] of value — a
/// worst-case answer of about four megabytes, and a typical one of a few
/// hundred bytes.
///
/// Keys are shape-checked rather than drawn from a closed set, so without the
/// ceiling a caller — or a bug in one, writing a key per document it opens —
/// could accumulate rows without limit, and every device would then download
/// all of them. 256 is far beyond what settings need and far below what would
/// make that download a problem; an application that wants a preference *per
/// item* has a table's worth of data and should store it in a table.
///
/// The server enforces it when a write would **add** a key: replacing an
/// existing preference is always allowed, so a principal at the ceiling can
/// still change every setting it has, and deleting one frees a place. A write
/// refused for the ceiling fails with [tomUserPreferencesLimitExceededErrorKey].
const int tomUserPreferencesMaxPerPrincipal = 256;

/// The error key a write answers with when it would add a preference beyond
/// [tomUserPreferencesMaxPerPrincipal].
///
/// On the wire a `409` carrying the error envelope with this `errorKey`: the
/// request is well-formed, and would succeed against a principal holding
/// fewer preferences, so it conflicts with the state rather than being wrong in
/// itself.
const String tomUserPreferencesLimitExceededErrorKey =
    'preferences.limit.exceeded';

/// Server-stored user preferences (`/preferences/*`).
///
/// Every endpoint is [TomAuthenticatedAccess]: there is no anonymous preference,
/// because a preference is *per principal* and an anonymous caller is not one.
/// That is the only policy the contract can state. **Which** rows a caller
/// reaches is not an endpoint-level question and is not decided here — the
/// server's entity declares `@TomDbScope(field: 'principal_id')`, so the
/// repository ANDs the caller's own id into every read and rejects every write
/// that would touch another principal's row (C-3). A URI carries no principal
/// parameter for exactly that reason: there is nothing to ask for but your own.
final TomApi tomUserPreferencesApi = TomApi(
  id: tomUserPreferencesApiId,
  name: 'User Preferences API',
  description: 'Per-principal preferences stored on the server.',
  uri: '/preferences',
  endpoints: [
    TomApiEndpoint<List<TomUserPreferenceDto>, Object?>(
      id: tomUserPreferencesListEndpointId,
      uri: '',
      method: TomHttpMethod.get,
      description:
          'Every preference of the caller, ordered by key. Unpaged by design '
          'and bounded by construction: at most '
          '$tomUserPreferencesMaxPerPrincipal entries, each value at most '
          '${TomUserPreferenceCodec.maxValueBytes} bytes of JSON.',
      requestTypes: const [],
      access: const TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<TomUserPreferenceDto, TomUserPreferenceKeyRequest>(
      id: tomUserPreferencesReadEndpointId,
      uri: '/{key}',
      method: TomHttpMethod.get,
      urlParameterMapping: const {'key': 'key'},
      access: const TomAuthenticatedAccess(),
    ),
    // The write is the one key-taking endpoint whose URI carries no `{key}`:
    // its request already has a `key` field, and an endpoint that captured the
    // key from the path *as well* would let one request name two different
    // preferences with no rule saying which one is written. Read and delete
    // have no such field, so for them the path is the only statement. The key
    // is stated exactly once, and here that once is the body.
    TomApiEndpoint<TomUserPreferenceDto, TomUserPreferenceWriteRequest>(
      id: tomUserPreferencesWriteEndpointId,
      uri: '',
      method: TomHttpMethod.put,
      description:
          'Writes one preference of the caller, replacing any previous value. '
          'A value longer than ${TomUserPreferenceCodec.maxValueBytes} bytes '
          'of JSON is refused (400, preferences.encoded.too_large); a write '
          'that would add a key beyond $tomUserPreferencesMaxPerPrincipal '
          'preferences is refused (409, '
          '$tomUserPreferencesLimitExceededErrorKey).',
      access: const TomAuthenticatedAccess(),
    ),
    // `void` and not `Object?`: the delete answers `200` with an empty body,
    // so there is no value for a caller to read and no type to give it. The
    // two spellings behave identically — nothing in the framework reads
    // [TomApiEndpoint.responseType] — which is exactly why the declaration has
    // to be the honest one. It is the only statement of the wire's shape that
    // a reader, a generated client or a documentation mirror can consult, and
    // `Object?` would tell all three to expect a JSON value that never comes.
    TomApiEndpoint<void, TomUserPreferenceKeyRequest>(
      id: tomUserPreferencesDeleteEndpointId,
      uri: '/{key}',
      method: TomHttpMethod.delete,
      urlParameterMapping: const {'key': 'key'},
      access: const TomAuthenticatedAccess(),
    ),
    // The bulk delete, at the collection. It shares its method with the delete
    // above and is distinguished only by the absence of a path segment, which
    // is the same collection/item pair the two `get`s already form — but here
    // the two answers are "one preference gone" and "all of them gone", so the
    // distinction has teeth. A caller that resolves the by-key URI with an
    // empty key addresses *this* endpoint, which is why every key-taking
    // method on both faces validates its key before it builds a URI.
    TomApiEndpoint<void, Object?>(
      id: tomUserPreferencesClearEndpointId,
      uri: '',
      method: TomHttpMethod.delete,
      description:
          'Deletes every preference of the caller in one statement. Idempotent '
          'and unconditional: a caller holding none is cleared with a 200, and '
          'there is no filter to narrow what goes.',
      requestTypes: const [],
      access: const TomAuthenticatedAccess(),
    ),
  ],
);

/// The typed service interface behind [tomUserPreferencesApi].
///
/// The contract's *Dart* face: the server implements it, and a client that
/// generates or hand-writes a caller implements the same shape. It carries no
/// annotation because the server-side ones (`@tomComponent`,
/// `@TomApiEndpointImplementation`) live in `tom_core_server` and cannot be
/// named here — the same split the rest of the framework's contracts follow.
abstract class TomUserPreferencesApiService {
  /// [tomUserPreferencesListEndpointId] — every preference of the caller,
  /// **ordered by key, ascending**.
  ///
  /// The order is part of the contract rather than an implementation's
  /// accident, and it is stated *here* rather than on either implementation
  /// because both of them answer it: a server that sorts and a client that
  /// forwards an unsorted list are not two flavours of one API, they are two
  /// APIs. Anything that renders the list, or diffs one caller's list against
  /// another's to decide what to sync, reads the sequence — so leaving it
  /// unstated makes those callers depend on whatever each side happens to do.
  ///
  /// **The key is the ordering column** because it is the one field that is
  /// unique within a caller's preferences and never changes while the
  /// preference exists: rewriting a value must not move it in the list, which
  /// rules out `updatedAt`, and there is no insertion order that survives a
  /// store being rebuilt.
  ///
  /// Ascending **by code unit** — plain ASCII order, so `Theme` precedes
  /// `theme`. That is exact rather than approximate only because
  /// [TomUserPreferenceKeys] admits ASCII alone: over that alphabet code-unit
  /// order, byte order and alphabetical order are the same order, so a Dart
  /// `compareTo` and a byte-collated SQL `ORDER BY` cannot disagree. A store
  /// whose backing column carries a case-insensitive collation *does* deviate
  /// from this, and that is a defect in the store rather than a second
  /// permitted reading of this sentence.
  ///
  /// **Unpaged, and bounded.** There is no page and no filter: every caller of
  /// this list wants all of it, and the list is small by construction — at
  /// most [tomUserPreferencesMaxPerPrincipal] entries, each holding at most
  /// [TomUserPreferenceCodec.maxValueBytes] of value.
  Future<List<TomUserPreferenceDto>> listPreferences();

  /// [tomUserPreferencesReadEndpointId] — the caller's preference under
  /// [TomUserPreferenceKeyRequest.key].
  ///
  /// A preference the caller has never written is a failure keyed
  /// [tomUserPreferencesNotFoundErrorKey] — on the wire, a `404` carrying the
  /// error envelope with that `errorKey`. A bare `404` is not absence: it is a
  /// denial, or a route that is not there.
  Future<TomUserPreferenceDto> readPreference(
    TomUserPreferenceKeyRequest request,
  );

  /// [tomUserPreferencesWriteEndpointId] — writes one preference of the
  /// caller, replacing any previous value.
  ///
  /// The written preference is [TomUserPreferenceWriteRequest.key] and only
  /// that: the endpoint is a `PUT` at the collection, so unlike
  /// [readPreference] and [deletePreference] the URL names no key.
  ///
  /// Refuses a value longer than [TomUserPreferenceCodec.maxValueBytes]
  /// (`preferences.encoded.too_large`, a `400`), and a write that would add a
  /// key beyond [tomUserPreferencesMaxPerPrincipal] preferences
  /// ([tomUserPreferencesLimitExceededErrorKey], a `409`). Replacing a key the
  /// caller already holds is never refused for the count.
  Future<TomUserPreferenceDto> writePreference(
    TomUserPreferenceWriteRequest request,
  );

  /// [tomUserPreferencesDeleteEndpointId] — deletes the caller's preference
  /// under [TomUserPreferenceKeyRequest.key].
  ///
  /// Idempotent: deleting a preference that is not there succeeds, so a delete
  /// never answers [tomUserPreferencesNotFoundErrorKey] and a `404` from it is
  /// always a refusal.
  Future<void> deletePreference(TomUserPreferenceKeyRequest request);

  /// [tomUserPreferencesClearEndpointId] — deletes **every** preference of the
  /// caller.
  ///
  /// The operation an account reset performs. It is an endpoint of its own
  /// rather than a loop over [listPreferences] and [deletePreference] because
  /// only the server can make it one statement: a loop that fails half way
  /// leaves an account in a state nobody asked for, and it is the account
  /// store — the one shared across every device a user owns — that would be
  /// left in it. The device store draws the same distinction, for the same
  /// reason, in `TomDevicePreferences.clear`.
  ///
  /// Idempotent and unconditional: a caller holding no preferences is cleared
  /// with a `200`, and there is no filter, because a partial clear is
  /// [deletePreference] repeated and a caller that wants one already has it.
  ///
  /// Answers nothing. How many rows went is the store's business — a count on
  /// the wire would invite a caller to branch on it, and the only branch it
  /// could support ("some were already gone") is the case the idempotence
  /// exists to make uninteresting.
  Future<void> clearPreferences();
}

/// Registers [tomUserPreferencesApi] with the global [tomRemoteApis] registry.
///
/// Idempotent, and called by both halves: a server calls it before mounting the
/// endpoints, a client before building a caller. Registration is explicit
/// rather than implicit in a top-level initializer because a deployment that
/// stores no preferences should not carry the API in its registry.
void registerTomUserPreferencesApi() {
  tomRemoteApis.register(tomUserPreferencesApi);
}
