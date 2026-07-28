/// Demonstrates the structured detail a [TomErrorResult] carries: per-field
/// errors, the retryable flag, and the severity hint.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXAMPLE 1: Field-Level Validation Errors
// =============================================================================

class FieldErrorsExample {
  static TomResult<void>? result;
  static int fieldErrorCount = 0;
  static List<String> offendingFields = const [];

  /// Validates a registration form.
  ///
  /// Field errors exist so the client can annotate the *inputs* rather than
  /// showing one opaque message. The server names the field; the client decides
  /// how to render it.
  static TomResult<void> register(String email, String password) {
    final problems = <TomFieldError>[
      if (!email.contains('@')) const TomFieldError('email', 'EMAIL_MALFORMED'),
      if (password.length < 12)
        const TomFieldError('password', 'PASSWORD_TOO_SHORT'),
    ];

    if (problems.isNotEmpty) {
      return TomResult.failure(
        TomErrorResult(
          'REGISTRATION_INVALID',
          fieldErrors: problems,
          severity: TomErrorSeverity.warning,
        ),
      );
    }
    return const TomResult.success();
  }

  static void example1FieldLevelErrors() {
    result = register('not-an-email', 'short');

    fieldErrorCount = result!.error!.fieldErrors.length;
    offendingFields = [
      for (final e in result!.error!.fieldErrors) e.field,
    ];

    assert(fieldErrorCount == 2, 'Both inputs were rejected');
    assert(
      offendingFields.join(',') == 'email,password',
      'Each error names the field it belongs to',
    );
  }
}

// =============================================================================
// EXAMPLE 2: Dotted Field Paths for Nested Input
// =============================================================================

class NestedFieldPathExample {
  static TomFieldError? error;
  static String? field;

  /// A dotted path lets the client locate an input inside a nested structure
  /// without the server knowing anything about the form's layout.
  static void example2DottedFieldPaths() {
    error = const TomFieldError(
      'address.postalCode',
      'POSTAL_CODE_UNKNOWN',
      message: 'Not a postal code we recognise for that country',
    );

    field = error!.field;

    assert(field == 'address.postalCode', 'The path addresses a nested input');
    assert(error!.message != null, 'The message is for developers, not users');
  }
}

// =============================================================================
// EXAMPLE 3: The Retryable Flag
// =============================================================================

class RetryableExample {
  static TomErrorResult? transient;
  static TomErrorResult? permanent;

  /// `retryable` answers one narrow question: would this same call, unchanged,
  /// plausibly succeed? Lock contention would; a wrong password would not.
  static void example3Retryable() {
    transient = const TomErrorResult('LOCK_CONTENDED', retryable: true);
    permanent = const TomErrorResult('CREDENTIALS_REJECTED');

    assert(transient!.retryable, 'Contention clears on its own');
    assert(
      !permanent!.retryable,
      'Retrying identical wrong credentials fails identically',
    );
  }
}

// =============================================================================
// EXAMPLE 4: Severity as a Presentation Hint
// =============================================================================

class SeverityExample {
  static final List<String> presentations = [];

  /// Severity does not change what happened — it suggests how loudly to say it.
  static String present(TomErrorResult error) => switch (error.severity) {
        TomErrorSeverity.info => 'notice',
        TomErrorSeverity.warning => 'toast',
        TomErrorSeverity.error => 'dialog',
        TomErrorSeverity.fatal => 'blocking-dialog',
      };

  static void example4Severity() {
    presentations
      ..clear()
      ..add(present(
        const TomErrorResult('PARTIAL', severity: TomErrorSeverity.info),
      ))
      ..add(present(
        const TomErrorResult('ODD', severity: TomErrorSeverity.warning),
      ))
      ..add(present(const TomErrorResult('FAILED')))
      ..add(present(
        const TomErrorResult('BROKEN', severity: TomErrorSeverity.fatal),
      ));

    assert(
      presentations.join(',') == 'notice,toast,dialog,blocking-dialog',
      'Each severity maps to a different presentation',
    );
    assert(
      const TomErrorResult('X').severity == TomErrorSeverity.error,
      'The default severity is the ordinary one',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  FieldErrorsExample.example1FieldLevelErrors();
  NestedFieldPathExample.example2DottedFieldPaths();
  RetryableExample.example3Retryable();
  SeverityExample.example4Severity();
}

void main() => run();
