/// The client half of server-stored user preferences (C-13): the typed face an
/// application reads and writes `/preferences/*` through.
///
/// ## Why the framework owns this
///
/// The kernel declares the contract ([tomUserPreferencesApi]) and
/// `tom_core_server` implements it, but a preference exists to *follow a user
/// across devices* — which means it is only a capability once a device can
/// reach it. Without a framework client every application writes the four HTTP
/// calls itself: four spellings of the same URIs, four decodings of the same
/// DTO, four chances to read a broken server as "no such preference". That is
/// the same G-DI-3 failure the device store was built to remove, one layer up.
///
/// So this class is the counterpart of `TomDevicePreferences`, and deliberately
/// carries the same method set — `all` / `read` / `get` / `getOr` / `set` /
/// `remove` — over the same [TomUserPreferenceDto] and the same
/// [TomUserPreferenceCodec]. A call site reads identically whichever store it
/// addresses, which is what lets a preference *move* between them.
///
/// ## Addressed by the contract, not by strings
///
/// No URI is written here. Every request is built by
/// [TomApiEndpoint.resolveUri] from the endpoint's own declaration — its
/// method, its path template and its `urlParameterMapping` — so the address the
/// client calls and the route the server serves are two readings of one
/// declaration rather than two spellings that agree by inspection.
///
/// ## What a miss looks like
///
/// The server answers a key the caller has never written with a `404` carrying
/// the error envelope keyed [tomUserPreferencesNotFoundErrorKey]
/// (`TomUserPreferencesErrorHandler`), and that is the only answer this client
/// reads as absence: [read] and [get] answer `null`, [getOr] answers its
/// fallback. Every other failure throws, because a deployment whose preference
/// store is unreachable must not be indistinguishable from a user who has set
/// nothing — an application that could not tell them apart would paper the
/// outage over with a default and never learn.
///
/// That includes a *bare* `404`. The endpoint pipeline answers a denied or
/// unauthenticated call that way, deliberately indistinguishable from a route
/// that does not exist, so the status alone says only "refused or not there".
/// Read as absence it would hand a signed-out user the defaults; the envelope's
/// key is what separates "you have not set this" from "you may not ask".
///
/// ## Example
///
/// ```dart
/// final preferences = TomUserPreferencesClient(
///   baseUri: Uri.parse('https://api.example.com'),
/// );
///
/// await preferences.set(TomUserPreferenceKeys.theme, 'dark');
/// final theme = await preferences.getOr(TomUserPreferenceKeys.theme, 'system');
/// ```
///
/// Paired with the device store, the precedence documented on
/// [TomDevicePreferences] applies — the device value wins, and this client is
/// consulted only for a key this device has never written:
///
/// ```dart
/// final theme = await device.getPreferred<String>(
///   TomUserPreferenceKeys.theme,
///   () => preferences.get<String>(TomUserPreferenceKeys.theme),
/// );
/// ```
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/client_exceptions.dart';
import 'reflection_readiness.dart';

/// A failure raised by the server-preferences client.
///
/// The sibling of `TomDevicePreferenceException`, and a [TomClientException] for
/// the same reason: a caller can tell a preference failure from any other
/// client-side error with one `is` check. The `key` is a stable dotted code —
/// `preferences.client.not_found`, `preferences.client.rejected`,
/// `preferences.client.invalid_response` — so callers branch on the code rather
/// than on message text.
///
/// A *value* failure — a type mismatch, unparseable JSON in the preference
/// itself — arrives as the kernel's [TomUserPreferenceCodecException] instead,
/// because it means the same thing in both stores and is already named there.
class TomUserPreferencesClientException extends TomClientException {
  /// Creates a preferences-client exception. See [TomException] for the meaning
  /// of each argument.
  TomUserPreferencesClientException(
    super.key,
    super.defaultUserMessage, {
    super.uuid,
    super.requestUuid,
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.serverCallError,
  });
}

/// Typed access to the calling principal's server-stored preferences.
///
/// Implements the kernel's [TomUserPreferencesApiService], so the client and the
/// server are two implementations of one interface; the `get` / `getOr` / `set`
/// surface on top of it is the ergonomic face, shaped to match
/// `TomDevicePreferences`.
class TomUserPreferencesClient implements TomUserPreferencesApiService {
  /// Creates a client for the preferences endpoints of the server at [baseUri].
  ///
  /// [baseUri] is the server root, not the `/preferences` path: the API's own
  /// `uri` is part of the contract and is appended from it. A base that already
  /// carries a path (an API gateway prefix, say) keeps it.
  ///
  /// [channel] is optional; when omitted one is created for [baseUri]'s host and
  /// port. Pass an existing channel to share a connection pool with the rest of
  /// an application's calls — [close] then leaves it alone, because it belongs
  /// to whoever passed it in.
  ///
  /// [headers] are sent with every request, and [headerProvider] supplies the
  /// ones that must be computed *per request* — a credential that rotates would
  /// otherwise be captured once at construction. Returning an `Authorization`
  /// header from either suppresses the bearer token from
  /// [TomBearerAuthentication], so there is one credential on the request rather
  /// than two spellings of one.
  TomUserPreferencesClient({
    required Uri baseUri,
    TomServerChannel? channel,
    Map<String, String> headers = const {},
    Map<String, String> Function()? headerProvider,
  }) : baseUri = baseUri,
       headers = Map.unmodifiable(headers),
       _headerProvider = headerProvider,
       channel = channel ?? TomServerChannel(baseUri.host, _portOf(baseUri)),
       _ownsChannel = channel == null {
    // Idempotent, and done here rather than left to the application: every
    // request is resolved from the registered contract, so a client built
    // before anyone registered it would fail on its first call for a reason
    // that has nothing to do with the call.
    registerTomUserPreferencesApi();
  }

  /// The server root the endpoint paths are resolved against.
  final Uri baseUri;

  /// The channel providing the pooled HTTP client.
  final TomServerChannel channel;

  /// Extra headers sent with every request.
  final Map<String, String> headers;

  final bool _ownsChannel;

  final Map<String, String> Function()? _headerProvider;

  // ---------------------------------------------------------------------------
  // The store face — the surface TomDevicePreferences also carries
  // ---------------------------------------------------------------------------

  /// Every preference stored for the calling principal, **ordered by key,
  /// ascending** — the order [listPreferences] states, and the same one
  /// `TomDevicePreferences.all` answers in.
  ///
  /// Forwarded as received: this client does **not** re-sort. The order is the
  /// server's to produce, off an index that already covers it, and a client that
  /// sorted defensively would be spending a sort on every call to hide the one
  /// symptom by which a server breaking the contract could be noticed. Where the
  /// two faces disagree the store is wrong, and it should be possible to see
  /// that.
  ///
  /// **Unmodifiable**, like `TomDevicePreferences.all`. It is a decoded snapshot
  /// of one response, so adding to it would change nothing on the server — and
  /// the call site this face exists for, moving a preference between the two
  /// stores, is where a caller holds both results at once.
  Future<List<TomUserPreferenceDto>> all() => listPreferences();

  /// The preference stored under [key] as stored, or `null` when the server has
  /// never been given one.
  ///
  /// Throws a [TomUserPreferencesClientException] keyed
  /// `preferences.client.rejected` for any other failure — including a `404`
  /// that does not carry [tomUserPreferencesNotFoundErrorKey], which is a
  /// refusal rather than a miss.
  ///
  /// Throws a [TomUserPreferenceKeyException] when [key] is not a legal key —
  /// see [TomUserPreferenceKeys]. The check is here rather than left to the
  /// server because an illegal key does not survive being made into a URI: an
  /// empty key resolves to the *list* endpoint's own URI, so the request the
  /// server would answer is not the one this method was asked to make.
  Future<TomUserPreferenceDto?> read(String key) async {
    TomUserPreferenceKeys.validate(key);
    final response = await _call(
      tomUserPreferencesApi[tomUserPreferencesReadEndpointId],
      parameters: {'key': key},
    );
    if (_reportsAbsence(response)) return null;
    _requireSuccess(response, key: key);
    return _decodeDto(response, key: key);
  }

  /// The preference stored under [key], decoded as a [T].
  ///
  /// `null` when the preference does not exist. Throws a
  /// [TomUserPreferenceCodecException] when it exists but was written as a
  /// different type — see [TomUserPreferenceCodec.decode].
  Future<T?> get<T extends Object>(String key) async {
    final dto = await read(key);
    return dto == null ? null : TomUserPreferenceCodec.decode<T>(dto);
  }

  /// [get], with [fallback] for a preference that has never been written.
  ///
  /// A type *mismatch* still throws: an unwritten preference is an ordinary
  /// state that a default answers, while a preference stored as the wrong type
  /// is a bug, and silently answering [fallback] would hide it.
  Future<T> getOr<T extends Object>(String key, T fallback) async =>
      await get<T>(key) ?? fallback;

  /// Writes [value] under [key], replacing any previous value, and returns the
  /// stored DTO.
  ///
  /// Scalars and `DateTime`s are encoded by [TomUserPreferenceCodec]; anything
  /// else must be a `@tomReflector` class, which is what makes a preference a
  /// typed object rather than a stringly-typed blob.
  Future<TomUserPreferenceDto> set<T extends Object>(String key, T value) {
    final encoded = TomUserPreferenceCodec.encode(key, value);
    return writePreference(
      TomUserPreferenceWriteRequest(
        key: encoded.key,
        valueType: encoded.valueType,
        value: encoded.value,
      ),
    );
  }

  /// Deletes the preference stored under [key].
  ///
  /// Throws a [TomUserPreferencesClientException] keyed
  /// `preferences.client.rejected` when the server refuses the delete — see
  /// [deletePreference].
  ///
  /// Returns nothing, where the device store's `remove` answers a `bool`. That
  /// is not an oversight and not a gap to be filled later: the delete endpoint
  /// is idempotent by design — clearing a preference twice is not a client doing
  /// anything wrong — so the server does not report whether a row existed, and a
  /// `bool` invented here could only be a second round trip pretending to be an
  /// answer.
  Future<void> remove(String key) =>
      deletePreference(TomUserPreferenceKeyRequest(key: key));

  // ---------------------------------------------------------------------------
  // The contract face — TomUserPreferencesApiService
  // ---------------------------------------------------------------------------

  @override
  Future<List<TomUserPreferenceDto>> listPreferences() async {
    final response = await _call(
      tomUserPreferencesApi[tomUserPreferencesListEndpointId],
    );
    _requireSuccess(response);
    return _decodeDtoList(response);
  }

  /// The preference named by [request], or a failure when there is none.
  ///
  /// Throws `preferences.client.not_found` for a miss, because the contract's
  /// result type is not nullable. [read] is the same call with the miss
  /// expressed as `null`, and is what an application should use.
  @override
  Future<TomUserPreferenceDto> readPreference(
    TomUserPreferenceKeyRequest request,
  ) async {
    final dto = await read(request.key);
    if (dto == null) {
      throw TomUserPreferencesClientException(
        'preferences.client.not_found',
        "No preference is stored under '${request.key}'.",
        parameters: {'key': request.key},
      );
    }
    return dto;
  }

  /// Writes the already-encoded preference named by [request].
  ///
  /// The key travels in the body and nowhere else — the write endpoint's URI
  /// is the bare collection — so no `parameters` are passed here, and there is
  /// no path key that could name a different preference than the body does.
  ///
  /// Throws a [TomUserPreferenceKeyException] when the request's key is not a
  /// legal key. A DTO is checked here rather than in its constructor because
  /// the DTOs are instantiated blank and filled by reflection — a constructor
  /// that refused the empty default would refuse every deserialization.
  @override
  Future<TomUserPreferenceDto> writePreference(
    TomUserPreferenceWriteRequest request,
  ) async {
    TomUserPreferenceKeys.validate(request.key);
    final response = await _call(
      tomUserPreferencesApi[tomUserPreferencesWriteEndpointId],
      body: _encodeRequest(request),
    );
    _requireSuccess(response, key: request.key);
    return _decodeDto(response, key: request.key);
  }

  /// Deletes the preference named by [request].
  ///
  /// Throws a [TomUserPreferenceKeyException] when the request's key is not a
  /// legal key — including the empty one [TomUserPreferenceKeyRequest]'s own
  /// default produces, which would otherwise resolve to the list endpoint's URI
  /// and send a `DELETE` at the collection.
  ///
  /// Every non-2xx answer throws, a `404` included. The server's delete is
  /// idempotent — a preference that is not there is deleted with a `200` — so
  /// a `404` from this endpoint is never "already gone": it is the pipeline's
  /// refusal, and reporting it as success would tell the caller a preference
  /// was cleared that is still stored.
  @override
  Future<void> deletePreference(TomUserPreferenceKeyRequest request) async {
    TomUserPreferenceKeys.validate(request.key);
    final response = await _call(
      tomUserPreferencesApi[tomUserPreferencesDeleteEndpointId],
      parameters: {'key': request.key},
    );
    _requireSuccess(response, key: request.key);
  }

  /// Releases the HTTP client, when this client created it.
  void close() {
    if (_ownsChannel) channel.close();
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  /// Issues [endpoint] against [baseUri] and reads the whole answer.
  ///
  /// [parameters] are keyed by request-DTO field name, as
  /// [TomApiEndpoint.resolveUri] expects. [body] is the request's JSON text, or
  /// `null` for the methods that carry none.
  Future<_PreferencesResponse> _call(
    TomApiEndpoint endpoint, {
    Map<String, Object?> parameters = const {},
    String? body,
  }) async {
    final encoding = endpoint.requestEncoding ?? utf8;
    final requestHeaders = _requestHeaders(endpoint);
    final call = channel.prepareCall(
      TomServerCallSpecs(
        endpoint.method.name,
        endpoint.resolveUri(baseUri, parameters: parameters),
        headers: requestHeaders,
        followRedirects: endpoint.followRedirects,
        maxRedirects: endpoint.maxRedirects,
        persistentConnection: endpoint.persistentConnection,
        // The channel writes the bearer *after* the spec headers, so asking for
        // it while a caller has already named an `Authorization` would silently
        // replace theirs. Suppressing it here is what makes that header win.
        includeBearerAuthentication:
            endpoint.includeBearerAuthentication &&
            !_carriesAuthorization(requestHeaders),
      ),
    );

    final text = await call
        .send(
          TomServerCallLoad(
            stringBody: body,
            contentType: body == null ? null : TomMimeType.json.toHeaderValue(),
            encoding: encoding,
          ),
        )
        .readAsString(endpoint.responseEncoding ?? utf8);

    return _PreferencesResponse(
      await call.getResponseStatusCode(),
      text,
      await call.getResponseHeaders(),
    );
  }

  /// The headers one request carries, with the bearer token resolved last.
  ///
  /// A provider that already named an `Authorization` header wins and the
  /// built-in bearer is suppressed: it is answering the same question with
  /// better information, and two credentials on one request is exactly the
  /// ambiguity this seam exists to remove.
  Map<String, String> _requestHeaders(TomApiEndpoint endpoint) => {
    ...endpoint.requestHeaders,
    ...headers,
    ...?_headerProvider?.call(),
  };

  /// Whether [headers] already names an `Authorization`.
  ///
  /// Case-insensitively, because HTTP header names are — a caller who wrote
  /// `authorization` meant the same header, and matching only the capitalised
  /// spelling would send two.
  static bool _carriesAuthorization(Map<String, String> headers) =>
      headers.keys.any((name) => name.toLowerCase() == 'authorization');

  /// Whether [response] is the server saying the preference was never written.
  ///
  /// A `404` whose body is the error envelope with `errorKey`
  /// [tomUserPreferencesNotFoundErrorKey], and nothing less: a bare `404` is
  /// the pipeline refusing the call, and an envelope naming any other key is a
  /// different failure that merely shares the status. A body that is not JSON
  /// is not an envelope, so it answers `false` rather than throwing — the
  /// caller then reports the response as the rejection it is.
  static bool _reportsAbsence(_PreferencesResponse response) =>
      response.statusCode == 404 &&
      _envelopeErrorKey(response) == tomUserPreferencesNotFoundErrorKey;

  /// The `errorKey` of the framework error envelope [response] carries, or
  /// `null` when its body is not one — plain text, or JSON of another shape.
  static String? _envelopeErrorKey(_PreferencesResponse response) {
    final Object? envelope;
    try {
      envelope = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    if (envelope is! Map) return null;
    final errorKey = envelope['errorKey'];
    return errorKey is String ? errorKey : null;
  }

  /// Throws unless [response] carries a 2xx status.
  ///
  /// Every rejection is `preferences.client.rejected`; what tells them apart
  /// is carried in its parameters — the status, and, when the server answered
  /// with its error envelope, the server's own `errorKey`. That is how a caller
  /// tells a write refused for the account's ceiling
  /// ([tomUserPreferencesLimitExceededErrorKey], a `409`) from a value the
  /// server would not store (`preferences.encoded.*`, a `400`) without parsing
  /// the body itself.
  void _requireSuccess(_PreferencesResponse response, {String? key}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final errorKey = _envelopeErrorKey(response);
    final callError = _callErrorOf(response);
    throw TomUserPreferencesClientException(
      'preferences.client.rejected',
      'The server rejected the preference request.',
      parameters: {
        if (key != null) 'key': key,
        'statusCode': response.statusCode,
        if (errorKey != null) 'errorKey': errorKey,
        if (response.body.isNotEmpty) 'response': response.body,
      },
      requestUuid: callError.requestUuid,
      serverCallError: callError,
    );
  }

  /// The whole HTTP answer as the kernel's typed failure record.
  ///
  /// Built for every rejection rather than only for a framework envelope,
  /// because a caller reaching for [TomException.serverCallError] is asking
  /// "what did the call do" — and "the gateway answered 502 with HTML" is an
  /// answer. [TomServerCallError]'s own constructor reads the envelope when
  /// `x-tom-error` claims one, which is where `errorKey`, `uuid` and
  /// `requestUuid` come from; a body that is not one simply leaves them null.
  ///
  /// The server's `requestUuid` is then copied onto the exception, so a client
  /// failure names the request the server logged it under. Both sides of one
  /// failed call carry the same id, which is the only way the two logs can be
  /// read together.
  static TomServerCallError _callErrorOf(_PreferencesResponse response) =>
      TomServerCallError(
        statusCode: response.statusCode,
        response: response.body,
        headers: {...response.headers},
        internalError:
            TomServerCallError.isSuccessStatusCode(response.statusCode)
            ? 0
            : TomServerCallError.serverError,
      );

  /// Decodes a single-DTO response body.
  TomUserPreferenceDto _decodeDto(
    _PreferencesResponse response, {
    String? key,
  }) {
    try {
      return tomReflectionInfo.convertFromJsonString(
        TomUserPreferenceDto(),
        response.body,
      );
    } catch (error, stack) {
      throw _invalidResponse(response, key: key, error: error, stack: stack);
    }
  }

  /// Encodes a request body through reflection.
  ///
  /// Wrapped because this is the *outbound* half of the same coupling: a write
  /// attempted without `initializeReflection()` fails before a request is made,
  /// and reporting that as anything but what it is sends the caller to the
  /// network.
  String _encodeRequest(Object request) {
    try {
      return tomReflectionInfo.convertToJsonString(request);
    } catch (error, stack) {
      if (isReflectionUninitialised(error)) {
        throw _reflectionNotInitialised(error, stack);
      }
      rethrow;
    }
  }

  /// Decodes the bare JSON array the list endpoint answers.
  List<TomUserPreferenceDto> _decodeDtoList(_PreferencesResponse response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stack) {
      throw _invalidResponse(response, error: error, stack: stack);
    }
    if (decoded is! List) throw _invalidResponse(response);

    try {
      final mirror = tomReflector.reflectType(TomUserPreferenceDto);
      if (mirror is! ClassMirror) throw _invalidResponse(response);

      // Unmodifiable, matching what `TomDevicePreferences.all` already
      // promises. The two faces exist to be interchangeable at a call site, and
      // the call site the module is designed for — moving a preference from one
      // store to the other — is exactly where a caller holds both results at
      // once; one of them silently accepting `add` would be a difference
      // discoverable only by trying it.
      //
      // Unmodifiable is also the right answer on its own terms. This list is a
      // decoded snapshot of one response: adding to it changes nothing on the
      // server, so a mutation that appeared to work would be a change that did
      // nothing, which is worse than the `UnsupportedError` it now raises.
      return List<TomUserPreferenceDto>.unmodifiable([
        for (final element in decoded)
          tomReflectionInfo.createInstanceFromJson<TomUserPreferenceDto>(
            mirror,
            element,
          ),
      ]);
    } on TomUserPreferencesClientException {
      rethrow;
    } catch (error, stack) {
      throw _invalidResponse(response, error: error, stack: stack);
    }
  }

  /// The failure raised when the application never initialised reflection.
  TomUserPreferencesClientException _reflectionNotInitialised(
    Object error,
    StackTrace stack, {
    String? key,
  }) => TomUserPreferencesClientException(
    'preferences.client.reflection_not_initialised',
    'Preferences are encoded through reflection, and this application never '
        'called initializeReflection(). Call it as the first action in main().',
    parameters: {if (key != null) 'key': key},
    rootException: error,
    stack: stack,
  );

  TomUserPreferencesClientException _invalidResponse(
    _PreferencesResponse response, {
    String? key,
    Object? error,
    StackTrace? stack,
  }) {
    // Reflection that was never initialised is a fault of *this program*, not
    // of the answer. Reported as `invalid_response` it blames a server that is
    // behaving correctly, which is the worst available diagnosis: the first
    // thing the caller does is inspect something that is fine.
    if (error != null && isReflectionUninitialised(error)) {
      return _reflectionNotInitialised(
        error,
        stack ?? StackTrace.current,
        key: key,
      );
    }
    // A body this client could not read is a *decoding* failure, so the call
    // error carries `jsonDecodingError` rather than the status — the status was
    // very likely a 200. What the two failures share is the answer itself, and
    // a caller that wants to see what arrived reads it from the same place
    // either way.
    final callError = TomServerCallError(
      statusCode: response.statusCode,
      response: response.body,
      headers: {...response.headers},
      internalError: TomServerCallError.jsonDecodingError,
      exception: error,
      stackTrace: stack,
    );
    return TomUserPreferencesClientException(
      'preferences.client.invalid_response',
      'The server did not answer with a preference.',
      parameters: {
        if (key != null) 'key': key,
        'statusCode': response.statusCode,
        'response': response.body,
      },
      rootException: error,
      stack: stack,
      requestUuid: callError.requestUuid,
      serverCallError: callError,
    );
  }

  static int _portOf(Uri uri) =>
      uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
}

/// One server answer: the status that says what happened and the text that says
/// what it was.
///
/// A pair rather than two futures because the status and the body are read
/// together at every call site, and a `TomServerCall` can be read only once.
class _PreferencesResponse {
  const _PreferencesResponse(this.statusCode, this.body, this.headers);

  /// The HTTP status the server answered with.
  final int statusCode;

  /// The response body as text.
  final String body;

  /// The response headers, as the transport keyed them.
  ///
  /// Carried because `x-tom-error` is what tells a [TomServerCallError] that
  /// the body is a framework error envelope and worth reading the `errorKey`,
  /// `uuid` and `requestUuid` out of. Dropping the headers here would leave
  /// every failure from this client uncorrelated with the server's own record
  /// of it.
  final Map<String, String> headers;
}
