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
  DateTime? updatedAt;

  /// Creates a preference DTO. Every field defaults, because the reflection
  /// path instantiates a blank instance and fills it field by field.
  TomUserPreferenceDto({
    this.key = '',
    this.valueType = '',
    this.value = '',
    this.updatedAt,
  });

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
      access: const TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<Object?, TomUserPreferenceKeyRequest>(
      id: tomUserPreferencesDeleteEndpointId,
      uri: '/{key}',
      method: TomHttpMethod.delete,
      urlParameterMapping: const {'key': 'key'},
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
  /// [tomUserPreferencesListEndpointId] — every preference of the caller.
  Future<List<TomUserPreferenceDto>> listPreferences();

  /// [tomUserPreferencesReadEndpointId] — the caller's preference under
  /// [TomUserPreferenceKeyRequest.key].
  Future<TomUserPreferenceDto> readPreference(
    TomUserPreferenceKeyRequest request,
  );

  /// [tomUserPreferencesWriteEndpointId] — writes one preference of the
  /// caller, replacing any previous value.
  ///
  /// The written preference is [TomUserPreferenceWriteRequest.key] and only
  /// that: the endpoint is a `PUT` at the collection, so unlike
  /// [readPreference] and [deletePreference] the URL names no key.
  Future<TomUserPreferenceDto> writePreference(
    TomUserPreferenceWriteRequest request,
  );

  /// [tomUserPreferencesDeleteEndpointId] — deletes the caller's preference
  /// under [TomUserPreferenceKeyRequest.key].
  Future<void> deletePreference(TomUserPreferenceKeyRequest request);
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
