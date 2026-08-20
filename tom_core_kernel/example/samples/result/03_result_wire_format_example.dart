/// Demonstrates the wire form of [TomResult]: the explicit `success`
/// discriminator, the raw success payload on decode, and the tolerance built
/// into [TomResult.fromJson].
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: The Explicit Discriminator
// =============================================================================

class DiscriminatorExample {
  static Map<String, Object?>? successJson;
  static Map<String, Object?>? failureJson;

  /// The `success` boolean is always present. Branching on *which key exists*
  /// would work right up until an operation legitimately succeeds with a `null`
  /// payload — at which point "no value key" and "failed" become
  /// indistinguishable.
  static void example1ExplicitDiscriminator() {
    successJson = const TomResult<String>.success('ok').toJson();
    failureJson = const TomResult<String>.failure(
      TomErrorResult('NOPE'),
    ).toJson();

    assert(successJson!['success'] == true, 'Success is stated, not inferred');
    assert(successJson!['value'] == 'ok', 'The payload rides alongside it');
    assert(successJson!.containsKey('error') == false, 'One arm only');

    assert(failureJson!['success'] == false, 'Failure is stated too');
    assert(failureJson!.containsKey('value') == false, 'One arm only');
  }
}

// =============================================================================
// EXAMPLE 2: An Empty Success Still Says So
// =============================================================================

class EmptySuccessWireExample {
  static Map<String, Object?>? json;
  static TomResult<void>? decoded;

  static void example2EmptySuccessOnTheWire() {
    json = const TomResult<void>.success().toJson();
    decoded = TomResult<void>.fromJson(json!);

    assert(json!['success'] == true, 'The discriminator carries the outcome');
    assert(json!['value'] == null, '…and the payload is simply null');
    assert(decoded!.isSuccess, 'Which round-trips as a success, not an error');
  }
}

// =============================================================================
// EXAMPLE 3: Nested Serializable Payloads Expand
// =============================================================================

class Receipt implements TomJsonSerializable {
  final String id;
  final int cents;

  const Receipt(this.id, this.cents);

  @override
  Map<String, Object?> toJson() => {'id': id, 'cents': cents};
}

class NestedPayloadExample {
  static Map<String, Object?>? json;
  static Map<String, Object?>? payload;

  /// A [TomJsonSerializable] payload is expanded through its own `toJson`, so
  /// the envelope does not have to know anything about the type it carries.
  static void example3NestedPayload() {
    json = const TomResult<Receipt>.success(Receipt('r-9', 1250)).toJson();
    payload = json!['value'] as Map<String, Object?>;

    assert(payload!['id'] == 'r-9', 'The payload serialized itself');
    assert(payload!['cents'] == 1250, '…including all of its fields');
  }
}

// =============================================================================
// EXAMPLE 4: Round-Tripping an Error
// =============================================================================

class ErrorRoundTripExample {
  static TomResult<void>? decoded;
  static TomErrorResult? error;

  static void example4ErrorRoundTrip() {
    final original = TomResult<void>.failure(
      const TomErrorResult(
        'REGISTRATION_INVALID',
        message: 'Two fields were rejected',
        fieldErrors: [
          TomFieldError('email', 'EMAIL_MALFORMED'),
          TomFieldError('password', 'PASSWORD_TOO_SHORT'),
        ],
        retryable: false,
        severity: TomErrorSeverity.warning,
      ),
    );

    decoded = TomResult<void>.fromJson(original.toJson());
    error = decoded!.error;

    assert(error!.code == 'REGISTRATION_INVALID', 'The code survives');
    assert(error!.fieldErrors.length == 2, 'So do the field details');
    assert(
      error!.severity == TomErrorSeverity.warning,
      'And the severity, via its lowercase wire token',
    );
  }
}

// =============================================================================
// EXAMPLE 5: The Payload Stays Raw on Decode
// =============================================================================

class RawPayloadExample {
  static TomResult<Map<String, Object?>>? envelope;
  static Receipt? typed;

  /// `fromJson` hands back the raw decoded payload — a map, list or primitive —
  /// and leaves the typed conversion to the call site. That is what keeps the
  /// envelope itself free of any reflection dependency.
  static void example5RawPayloadOnDecode() {
    final wire = const TomResult<Receipt>.success(
      Receipt('r-9', 1250),
    ).toJson();

    envelope = TomResult<Map<String, Object?>>.fromJson(wire);
    final raw = envelope!.value!;
    typed = Receipt(raw['id']! as String, raw['cents']! as int);

    assert(envelope!.isSuccess, 'Still the success arm');
    assert(
      typed!.id == 'r-9',
      'The call site knows the type; the envelope does not',
    );
  }
}

// =============================================================================
// EXAMPLE 6: Tolerating a Malformed Payload
// =============================================================================

class MalformedPayloadExample {
  static TomResult<String>? missingDiscriminator;
  static TomResult<String>? unparseableError;
  static TomErrorSeverity? unknownSeverity;

  /// A parser that threw here would turn the server's bad day into a client
  /// crash, so each of these degrades to a well-formed result instead.
  static void example6MalformedPayload() {
    // No `success` key and no `error` — read as a success.
    missingDiscriminator = TomResult<String>.fromJson({'value': 'ok'});

    // An `error` arm that is not a map — read as UNKNOWN_ERROR.
    unparseableError = TomResult<String>.fromJson({
      'success': false,
      'error': 'boom',
    });

    // A severity a newer server invented — read as the ordinary one.
    unknownSeverity = TomErrorSeverity.fromWire('catastrophic');

    assert(missingDiscriminator!.isSuccess, 'Absent discriminator, no error');
    assert(
      unparseableError!.error!.code == 'UNKNOWN_ERROR',
      'A garbled error arm is still an error arm',
    );
    assert(
      unknownSeverity == TomErrorSeverity.error,
      'An older client degrades rather than breaking',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  DiscriminatorExample.example1ExplicitDiscriminator();
  EmptySuccessWireExample.example2EmptySuccessOnTheWire();
  NestedPayloadExample.example3NestedPayload();
  ErrorRoundTripExample.example4ErrorRoundTrip();
  RawPayloadExample.example5RawPayloadOnDecode();
  MalformedPayloadExample.example6MalformedPayload();
}

void main() {
  requireAsserts();
  run();
}
