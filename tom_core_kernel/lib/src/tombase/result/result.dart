/// The canonical success-or-error result envelope (CodeSpecs part **CE-ER**).
///
/// The TOM server contract (`codespecs_mapping.md` §7) draws a sharp line
/// between *transport* failures and *application* outcomes:
///
/// 1. All operations are POST; the operation name carries intent.
/// 2. Only 5xx HTTP codes are transport errors (infrastructure failure).
/// 3. **Every application-level outcome — success *or* a structured error — is
///    returned in a normal (2xx-transport) response body as one canonical
///    envelope.** A validation failure, a "not found", a business-rule
///    rejection: none of these are HTTP errors. They are *results*.
/// 4. Error texts are keyed by the structured [TomErrorResult.code], so client
///    copy and server error codes share one source (CE-TX ↔ CE-ER).
///
/// [TomResult] is that envelope. It is deliberately a **general** structure
/// shared by client and server (it lives in `tom_core_kernel`, not a
/// CodeSpecs-only package): the server produces it, the client consumes it, and
/// both sides read the same discriminator to branch.
///
/// A result is in exactly one of two arms:
///
/// - **success** — carries a [value] of type `T` (which may itself be `null`
///   for operations that return nothing meaningful, e.g. a delete);
/// - **error** — carries a [TomErrorResult] with a machine code, an optional
///   default message, per-field details, a retryable flag and a [severity].
///
/// ```dart
/// // server: produce a result
/// TomResult<UserView> loadUser(String id) {
///   final user = repo.find(id);
///   if (user == null) {
///     return TomResult.failure(
///       const TomErrorResult('USER_NOT_FOUND', message: 'No such user'),
///     );
///   }
///   return TomResult.success(user.toView());
/// }
///
/// // client: branch on the discriminator
/// final result = await api.loadUser(id);
/// if (result.isSuccess) {
///   render(result.value!);
/// } else {
///   showError(result.error!.code); // copy resolved via CE-TX by code
/// }
/// ```
library;

import '../json/json_serializable.dart';

/// How serious a [TomErrorResult] is — a hint the client uses to decide how to
/// present the error (a toast, a blocking dialog, a field annotation…).
///
/// The wire form is the lowercase enum name ([wireName]); [fromWire] parses it
/// back, tolerating unknown values by falling back to [error] so a newer server
/// severity never breaks an older client.
enum TomErrorSeverity {
  /// Informational — the operation may have partially succeeded or produced a
  /// non-blocking notice.
  info,

  /// A warning the user should see but which does not block the outcome.
  warning,

  /// A normal application error — the operation did not succeed.
  error,

  /// A severe/unexpected error; the user generally cannot proceed.
  fatal;

  /// The stable, lowercase wire token for this severity.
  String get wireName => name;

  /// Parses a wire token back to a severity, defaulting to [error] for `null`
  /// or unrecognized input (forward-compatibility across versions).
  static TomErrorSeverity fromWire(Object? value) {
    if (value is String) {
      for (final s in values) {
        if (s.name == value) return s;
      }
    }
    return TomErrorSeverity.error;
  }
}

/// A single field-level error detail inside a [TomErrorResult].
///
/// Carries the offending [field] path, a machine [code] (keyed to CE-TX copy
/// exactly like the top-level error code), and an optional default [message].
class TomFieldError implements TomJsonSerializable {
  /// The field (or dotted field path) the error applies to, e.g. `email` or
  /// `address.postalCode`.
  final String field;

  /// The machine-readable error code for this field, keyed to CE-TX copy.
  final String code;

  /// An optional default/developer message; user-facing copy resolves from
  /// [code] via the CE-TX message registry.
  final String? message;

  /// Creates a field-level error detail.
  const TomFieldError(this.field, this.code, {this.message});

  @override
  Map<String, Object?> toJson() => {
    'field': field,
    'code': code,
    if (message != null) 'message': message,
  };

  /// Reconstructs a [TomFieldError] from its [toJson] map.
  factory TomFieldError.fromJson(Map<String, Object?> json) => TomFieldError(
    json['field'] as String? ?? '',
    json['code'] as String? ?? '',
    message: json['message'] as String?,
  );

  @override
  String toString() => 'TomFieldError($field: $code)';
}

/// The error arm of a [TomResult] — a structured application error (CE-ER).
///
/// This is *not* an exception and *not* a transport error: it is a normal
/// result returned in a 2xx body. Its [code] is the single source that both
/// server logic and client copy key off (CE-TX ↔ CE-ER).
class TomErrorResult implements TomJsonSerializable {
  /// The machine-readable error code — the join key to CE-TX error copy and
  /// the token a client branches on. Stable across releases.
  final String code;

  /// An optional default/developer-facing message. User-facing text is resolved
  /// from [code] via the CE-TX message registry, not taken from here.
  final String? message;

  /// Per-field error details, when the failure is attributable to specific
  /// input fields (e.g. form validation). Empty for whole-operation errors.
  final List<TomFieldError> fieldErrors;

  /// Whether the caller may retry the same operation unchanged and reasonably
  /// expect a different outcome (e.g. a transient lock contention).
  final bool retryable;

  /// How serious the error is — a presentation hint for the client.
  final TomErrorSeverity severity;

  /// Creates a structured error result.
  const TomErrorResult(
    this.code, {
    this.message,
    this.fieldErrors = const [],
    this.retryable = false,
    this.severity = TomErrorSeverity.error,
  });

  @override
  Map<String, Object?> toJson() => {
    'code': code,
    if (message != null) 'message': message,
    if (fieldErrors.isNotEmpty)
      'fieldErrors': [for (final e in fieldErrors) e.toJson()],
    'retryable': retryable,
    'severity': severity.wireName,
  };

  /// Reconstructs a [TomErrorResult] from its [toJson] map.
  factory TomErrorResult.fromJson(Map<String, Object?> json) {
    final rawFields = json['fieldErrors'];
    return TomErrorResult(
      json['code'] as String? ?? '',
      message: json['message'] as String?,
      fieldErrors: rawFields is List
          ? [
              for (final e in rawFields)
                if (e is Map)
                  TomFieldError.fromJson(Map<String, Object?>.from(e)),
            ]
          : const [],
      retryable: json['retryable'] as bool? ?? false,
      severity: TomErrorSeverity.fromWire(json['severity']),
    );
  }

  @override
  String toString() =>
      'TomErrorResult($code${message != null ? ': $message' : ''}, '
      'severity: ${severity.name}, retryable: $retryable, '
      'fields: ${fieldErrors.length})';
}

/// The canonical CE-ER success-or-error envelope (`codespecs_mapping.md` §7).
///
/// A [TomResult] is always in exactly one arm: [isSuccess] (carrying [value]) or
/// error (carrying [error]). Construct with [TomResult.success] or
/// [TomResult.failure]; never both, never neither.
///
/// The wire form carries an explicit `success` boolean discriminator so
/// generated clients in any language can branch without inspecting which key is
/// present:
///
/// ```json
/// { "success": true,  "value": { ... } }
/// { "success": false, "error": { "code": "…", "severity": "error", … } }
/// ```
class TomResult<T> implements TomJsonSerializable {
  /// The success payload, present (possibly `null`) when [isSuccess]; always
  /// `null` on the error arm.
  final T? value;

  /// The structured error, present when this result is an error; `null` on the
  /// success arm.
  final TomErrorResult? error;

  const TomResult._(this.value, this.error);

  /// Creates a success result carrying [value] (which may be `null` for
  /// operations with no meaningful payload).
  const TomResult.success([T? value]) : this._(value, null);

  /// Creates an error result carrying the structured [error].
  const TomResult.failure(TomErrorResult error) : this._(null, error);

  /// Whether this result is the success arm.
  bool get isSuccess => error == null;

  /// Whether this result is the error arm.
  bool get isError => error != null;

  @override
  Map<String, Object?> toJson() => {
    'success': isSuccess,
    if (isSuccess) 'value': _encodeValue(value),
    if (isError) 'error': error!.toJson(),
  };

  /// Encodes the success [value] into a JSON-safe form.
  ///
  /// Primitives, maps and lists pass through; a [TomJsonSerializable] is
  /// expanded via its `toJson`; any other object is returned as-is so the outer
  /// encoder (the server pipeline / `dart:convert`'s default `toEncodable`,
  /// which calls `toJson()`) handles reflected `TomClass` values.
  static Object? _encodeValue(Object? v) {
    if (v == null) return null;
    if (v is TomJsonSerializable) return v.toJson();
    return v;
  }

  /// Reconstructs a [TomResult] from its [toJson] map.
  ///
  /// The success [value] is left as the raw decoded payload (map / list /
  /// primitive); callers that need a typed `T` convert it with the reflection
  /// serializer at the call site — the envelope stays reflection-free.
  factory TomResult.fromJson(Map<String, Object?> json) {
    final success = json['success'] as bool? ?? (json['error'] == null);
    if (success) {
      return TomResult<T>.success(json['value'] as T?);
    }
    final rawError = json['error'];
    return TomResult<T>.failure(
      rawError is Map
          ? TomErrorResult.fromJson(Map<String, Object?>.from(rawError))
          : const TomErrorResult('UNKNOWN_ERROR'),
    );
  }

  @override
  String toString() =>
      isSuccess ? 'TomResult.success($value)' : 'TomResult.failure($error)';
}
