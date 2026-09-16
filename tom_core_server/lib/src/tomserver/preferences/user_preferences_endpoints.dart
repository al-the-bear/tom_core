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

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import '../endpoints/endpoint_pipeline.dart';
import 'user_preferences_service.dart';

/// Answers the failures that are the caller's business with a status of their
/// own, and leaves every other failure opaque.
///
/// | Error key | Status | Why it is not a server fault |
/// | --------- | ------ | ---------------------------- |
/// | [tomUserPreferencesNotFoundErrorKey] | `404` | a preference never written is a miss |
/// | `preferences.key.invalid` | `400` | the key is the caller's input |
/// | `preferences.encoded.*` | `400` | so is the encoded value in a write's body |
/// | [tomUserPreferencesLimitExceededErrorKey] | `409` | the write is sound, the caller is full |
///
/// The default handler turns every failure into an opaque `500`, which is right
/// for a fault and wrong for all of these. A client that cannot tell a miss
/// from a fault must either treat every failure as "no such preference" —
/// papering a broken server over with a default — or every miss as a failure,
/// which makes reading an unset key an error. And a rejected key or value is
/// squarely the *caller's* mistake: the key arrives in the request URL and the
/// value in its body, so on this side both are untrusted input, and reporting
/// a `500` would tell a client its own malformed request was a server fault it
/// should retry. The write boundary's refusals are matched as a family — every
/// key `TomUserPreferenceCodec.validateEncoded` raises is under
/// `preferences.encoded.` — so a refusal added there is a `400` here without
/// this table being revisited.
///
/// The ceiling is a `409` rather than a `400` because nothing is wrong with the
/// request: the same write succeeds for a principal holding fewer preferences,
/// and succeeds for this one after it deletes one.
///
/// Every answer carries the error envelope, and for the `404` that is what
/// gives it its meaning: the pipeline answers a denied call with a *bare*
/// `404`, so "never written" and "refused" share a status and differ only in
/// the body. A client reads absence from the envelope's `errorKey`
/// ([tomUserPreferencesNotFoundErrorKey]), never from the status alone.
///
/// Nothing else is translated. `preferences.not_configured` is a deployment
/// fault, not the client's business, and stays opaque along with everything
/// else.
class TomUserPreferencesErrorHandler extends TomStatusMappingErrorHandler {
  /// Const constructor so the handler can be used as an annotation argument.
  const TomUserPreferencesErrorHandler();

  /// The error key raised for a key that violates [TomUserPreferenceKeys].
  static const String invalidKeyKey = 'preferences.key.invalid';

  /// The family every refusal of the write boundary
  /// (`TomUserPreferenceCodec.validateEncoded`) is raised under.
  static const String _encodedRefusalPrefix = 'preferences.encoded.';

  /// The status each translated error key answers with.
  ///
  /// The miss is keyed by the contract's [tomUserPreferencesNotFoundErrorKey]
  /// rather than a key of this module's own, because the client has to
  /// recognise it: a `404` is absence only when it carries that key.
  ///
  /// Only the *status* is this module's contribution. The body is the
  /// framework's envelope, rendered by the base class — so a client branches on
  /// `errorKey` and sees one shape rather than one per endpoint.
  @override
  Map<String, int> get statusByErrorKey => const {
    tomUserPreferencesNotFoundErrorKey: 404,
    invalidKeyKey: 400,
    tomUserPreferencesLimitExceededErrorKey: 409,
  };

  /// [statusByErrorKey], plus the whole `preferences.encoded.*` family.
  ///
  /// A prefix rather than four entries: the write boundary raises one key per
  /// way a pair can disagree, and every one of them is the caller's malformed
  /// request. Listing them would mean a fifth refusal silently becoming a
  /// `500`.
  @override
  int statusFor(Object error) {
    if (error is TomException && error.key.startsWith(_encodedRefusalPrefix)) {
      return 400;
    }
    return super.statusFor(error);
  }
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
        tomUserPreferencesNotFoundErrorKey,
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
