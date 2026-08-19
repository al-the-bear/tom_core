/// The HTTP face of server-stored preferences: `/preferences/*`, bound to the
/// kernel's [tomUserPreferencesApi].
///
/// ## Where the gate is, and where it is not
///
/// Not here. The contract declares [TomAuthenticatedAccess] on each endpoint
/// (G-API-3) and the pipeline extracts it before a handler runs, so these
/// methods carry **no inline access annotation**. What they also do not carry
/// is any check that the caller owns what it touches: the entity's
/// `@TomDbScope(field: 'principal_id', scope: 'owner')` is that rule, applied
/// by the repository to every statement [TomUserPreferences] issues (C-3). One
/// principal reading another's preferences is not rejected by a handler — the
/// query never selects the row.
///
/// That is why no URI carries a principal: there is nothing to address but your
/// own preferences, so there is nothing for a handler to validate.
///
/// ## Why the endpoints ship at all
///
/// The store is a framework capability, but only a *client* makes it one: a
/// preference exists to follow a user across devices, and a device reaches it
/// over HTTP or not at all. Leaving every application to write these four
/// handlers would mean four chances to forget the scope, and a kernel-side
/// contract that nothing implements.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import '../endpoints/endpoint_pipeline.dart';
import 'user_preferences_service.dart';

/// Answers `404` for a preference that was never written and `400` for a key
/// that is not a legal key at all, and nothing else.
///
/// The default handler turns every failure into an opaque `500`, which is right
/// for a fault and wrong for both of these. A client that cannot tell a miss
/// from a fault must either treat every failure as "no such preference" —
/// papering a broken server over with a default — or every miss as a failure,
/// which makes reading an unset key an error. And a rejected key is squarely
/// the *caller's* mistake: the key arrives in the request URL, so on this side
/// it is untrusted input, and reporting a `500` would tell a client its own
/// malformed request was a server fault it should retry.
///
/// Only those two keys are translated. `preferences.not_configured` is a
/// deployment fault, not the client's business, and stays opaque along with
/// everything else.
class TomUserPreferencesErrorHandler extends TomErrorHandler {
  /// Const constructor so the handler can be used as an annotation argument.
  const TomUserPreferencesErrorHandler();

  /// The error key a read raises for a key the caller has never written.
  static const String notFoundKey = 'preferences.not_found';

  /// The error key raised for a key that violates [TomUserPreferenceKeys].
  static const String invalidKeyKey = 'preferences.key.invalid';

  /// The status each translated error key answers with.
  static const Map<String, int> _statusByErrorKey = {
    notFoundKey: 404,
    invalidKeyKey: 400,
  };

  @override
  Response handleInvocationError(Object error, Object stacktrace, Request r) {
    final status = error is TomException ? _statusByErrorKey[error.key] : null;
    if (error is TomException && status != null) {
      // The body follows the framework's error shape (`TomServer.errorHandler`)
      // so a client branches on `errorKey`, not on a message or a status alone.
      return Response(
        status,
        body: jsonEncode({
          'errorType': error.runtimeType.toString(),
          'errorKey': error.key,
          'uuid': error.uuid,
          'autoLog': error.autoLog,
          'requestUuid': error.requestUuid,
        }),
        headers: const {'x-tom-error': 'true'},
      );
    }
    return handleErrorDefault(error, stacktrace, r, null);
  }

  @override
  Response handleErrorDefault(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  ) => const TomDefaultErrorHandler().handleErrorDefault(
    error,
    stacktrace,
    r,
    result,
  );
}

/// The default [TomUserPreferencesApiService] implementation.
///
/// Holds no state of its own — the store is the [TomUserPreferences] bean and
/// the caller is the request zone — so the pipeline may construct it itself.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: tomUserPreferencesApiId)
class TomUserPreferencesServer implements TomUserPreferencesApiService {
  /// Creates the endpoint implementation.
  const TomUserPreferencesServer();

  @TomApiEndpointImplementation(
    apiId: tomUserPreferencesApiId,
    endpointId: tomUserPreferencesListEndpointId,
  )
  @override
  Future<List<TomUserPreferenceDto>> listPreferences() => _store().all();

  @TomApiEndpointImplementation(
    apiId: tomUserPreferencesApiId,
    endpointId: tomUserPreferencesReadEndpointId,
    errorHandler: TomUserPreferencesErrorHandler(),
  )
  @override
  Future<TomUserPreferenceDto> readPreference(
    TomUserPreferenceKeyRequest request,
  ) async {
    final dto = await _store().read(request.key);
    if (dto == null) {
      // A key the caller has never written is a miss, not a denial: reporting
      // it distinctly is safe precisely because the scope makes "not yours"
      // indistinguishable from "not there" — the answer leaks nothing about
      // another principal.
      throw TomEndpointHandlerException(
        'preferences.not_found',
        "No preference is stored under '${request.key}'.",
        parameters: {'key': request.key},
      );
    }
    return dto;
  }

  @TomApiEndpointImplementation(
    apiId: tomUserPreferencesApiId,
    endpointId: tomUserPreferencesWriteEndpointId,
    errorHandler: TomUserPreferencesErrorHandler(),
  )
  @override
  Future<TomUserPreferenceDto> writePreference(
    TomUserPreferenceWriteRequest request,
  ) {
    // `request.key` is the whole of what is addressed here: the write endpoint
    // is a PUT at the collection with no `{key}` capture, so the body is the
    // only place the key is stated.
    //
    // The request carries the value already encoded, so the write is a pass
    // through the codec's *decode* and back: it is what rejects a body whose
    // declared type and JSON text disagree, before the pair reaches a column
    // that would then hand the mismatch to every future reader.
    return _store().setEncoded(
      request.key,
      valueType: request.valueType,
      valueJson: request.value,
    );
  }

  @TomApiEndpointImplementation(
    apiId: tomUserPreferencesApiId,
    endpointId: tomUserPreferencesDeleteEndpointId,
    errorHandler: TomUserPreferencesErrorHandler(),
  )
  @override
  Future<void> deletePreference(TomUserPreferenceKeyRequest request) async {
    // A delete of something that is not there has already achieved its purpose,
    // so the absent case is not an error — a client clearing a preference twice
    // is not a client doing anything wrong.
    await _store().remove(request.key);
  }

  /// The installed store, or a failure that names the missing wiring.
  ///
  /// Resolved per call rather than held, so a deployment that installs its own
  /// [TomUserPreferences] bean after the pipeline has constructed this handler
  /// is obeyed.
  TomUserPreferences _store() {
    final store = TomUserPreferences.resolve();
    if (store == null) {
      throw TomEndpointHandlerException(
        'preferences.not_configured',
        'No TomUserPreferences bean is installed, so preferences cannot be '
            'read or written.',
      );
    }
    return store;
  }
}
