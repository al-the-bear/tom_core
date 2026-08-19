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
/// The server answers `404` for a key the caller has never written
/// (`TomUserPreferencesErrorHandler`) and that is the only status this client
/// reads as absence: [read] and [get] answer `null`, [getOr] answers its
/// fallback. Every other failure throws, because a deployment whose preference
/// store is unreachable must not be indistinguishable from a user who has set
/// nothing — an application that could not tell them apart would paper the
/// outage over with a default and never learn.
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
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
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

  /// Every preference stored for the calling principal.
  Future<List<TomUserPreferenceDto>> all() => listPreferences();

  /// The preference stored under [key] as stored, or `null` when the server has
  /// never been given one.
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
    if (response.statusCode == 404) return null;
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
      parameters: {'key': request.key},
      body: tomReflectionInfo.convertToJsonString(request),
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
  @override
  Future<void> deletePreference(TomUserPreferenceKeyRequest request) async {
    TomUserPreferenceKeys.validate(request.key);
    final response = await _call(
      tomUserPreferencesApi[tomUserPreferencesDeleteEndpointId],
      parameters: {'key': request.key},
    );
    // A delete of something that is not there has already achieved its purpose,
    // so a 404 is success here — the same rule the server applies.
    if (response.statusCode == 404) return;
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

    return _PreferencesResponse(await call.getResponseStatusCode(), text);
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

  /// Throws unless [response] carries a 2xx status.
  void _requireSuccess(_PreferencesResponse response, {String? key}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw TomUserPreferencesClientException(
      'preferences.client.rejected',
      'The server rejected the preference request.',
      parameters: {
        if (key != null) 'key': key,
        'statusCode': response.statusCode,
        if (response.body.isNotEmpty) 'response': response.body,
      },
    );
  }

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

  /// Decodes the bare JSON array the list endpoint answers.
  List<TomUserPreferenceDto> _decodeDtoList(_PreferencesResponse response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stack) {
      throw _invalidResponse(response, error: error, stack: stack);
    }
    if (decoded is! List) throw _invalidResponse(response);

    final mirror = tomReflector.reflectType(TomUserPreferenceDto);
    if (mirror is! ClassMirror) throw _invalidResponse(response);

    return [
      for (final element in decoded)
        tomReflectionInfo.createInstanceFromJson<TomUserPreferenceDto>(
              mirror,
              element,
            ) ??
            (throw _invalidResponse(response)),
    ];
  }

  TomUserPreferencesClientException _invalidResponse(
    _PreferencesResponse response, {
    String? key,
    Object? error,
    StackTrace? stack,
  }) => TomUserPreferencesClientException(
    'preferences.client.invalid_response',
    'The server did not answer with a preference.',
    parameters: {
      if (key != null) 'key': key,
      'statusCode': response.statusCode,
      'response': response.body,
    },
    rootException: error,
    stack: stack,
  );

  static int _portOf(Uri uri) =>
      uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
}

/// One server answer: the status that says what happened and the text that says
/// what it was.
///
/// A pair rather than two futures because the status and the body are read
/// together at every call site, and a `TomServerCall` can be read only once.
class _PreferencesResponse {
  const _PreferencesResponse(this.statusCode, this.body);

  /// The HTTP status the server answered with.
  final int statusCode;

  /// The response body as text.
  final String body;
}
