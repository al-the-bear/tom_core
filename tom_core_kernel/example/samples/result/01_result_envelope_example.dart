/// Demonstrates the two arms of [TomResult] — success and failure — and why an
/// application outcome travels in the envelope rather than in an HTTP status.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// A tiny domain to return results from
// =============================================================================

/// A user record, kept deliberately small so the examples stay about the
/// envelope rather than about the payload.
class UserView implements TomJsonSerializable {
  final String id;
  final String email;

  const UserView(this.id, this.email);

  @override
  Map<String, Object?> toJson() => {'id': id, 'email': email};
}

/// An in-memory store standing in for a repository.
const Map<String, UserView> _users = {
  'u-1': UserView('u-1', 'ada@example.com'),
};

/// Loads a user, or reports that there is no such user.
///
/// Note what this does *not* do: it does not throw, and it does not reach for a
/// 404. "No user with that id" is a perfectly ordinary answer to the question,
/// so it comes back as a value.
TomResult<UserView> loadUser(String id) {
  final user = _users[id];
  if (user == null) {
    return TomResult.failure(
      const TomErrorResult('USER_NOT_FOUND', message: 'No user with that id'),
    );
  }
  return TomResult.success(user);
}

// =============================================================================
// EXAMPLE 1: The Success Arm
// =============================================================================

class SuccessArmExample {
  static TomResult<UserView>? result;
  static bool isSuccess = false;
  static bool isError = false;
  static String? email;

  static void example1SuccessArm() {
    result = loadUser('u-1');

    isSuccess = result!.isSuccess;
    isError = result!.isError;
    email = result!.value?.email;

    assert(isSuccess, 'A found user is the success arm');
    assert(!isError, 'The two flags can never both be true');
    assert(email == 'ada@example.com', 'The payload rides on the success arm');
  }
}

// =============================================================================
// EXAMPLE 2: The Error Arm
// =============================================================================

class ErrorArmExample {
  static TomResult<UserView>? result;
  static bool isError = false;
  static String? code;
  static bool valueIsNull = false;

  static void example2ErrorArm() {
    result = loadUser('u-does-not-exist');

    isError = result!.isError;
    code = result!.error?.code;
    valueIsNull = result!.value == null;

    assert(isError, 'A missing user is the error arm');
    assert(code == 'USER_NOT_FOUND', 'The code is what the client branches on');
    assert(valueIsNull, 'The error arm never carries a payload');
  }
}

// =============================================================================
// EXAMPLE 3: Success With No Payload
// =============================================================================

class EmptySuccessExample {
  static TomResult<void>? result;
  static bool isSuccess = false;
  static bool valueIsNull = false;

  /// Deleting returns nothing meaningful. That is still a success — a `null`
  /// value on the success arm means "done, nothing to hand back", and is not to
  /// be confused with a failure.
  static TomResult<void> deleteUser(String id) => const TomResult.success();

  static void example3SuccessWithNoPayload() {
    result = deleteUser('u-1');

    isSuccess = result!.isSuccess;
    // A `void` payload cannot be read back through `value`, so the wire form is
    // where its absence is observable.
    valueIsNull = result!.toJson()['value'] == null;

    assert(isSuccess, 'An empty outcome is still a success');
    assert(valueIsNull, 'There is simply nothing to return');
  }
}

// =============================================================================
// EXAMPLE 4: Branching Without Guessing
// =============================================================================

class BranchingExample {
  static final List<String> log = [];

  /// The whole point of the envelope: one discriminator, read the same way by
  /// every caller, whatever the outcome.
  static String describe(TomResult<UserView> result) {
    if (result.isSuccess) {
      return 'ok:${result.value!.id}';
    }
    return 'err:${result.error!.code}';
  }

  static void example4Branching() {
    log
      ..clear()
      ..add(describe(loadUser('u-1')))
      ..add(describe(loadUser('nope')));

    assert(log[0] == 'ok:u-1', 'Success describes the payload');
    assert(log[1] == 'err:USER_NOT_FOUND', 'Failure describes the code');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  SuccessArmExample.example1SuccessArm();
  ErrorArmExample.example2ErrorArm();
  EmptySuccessExample.example3SuccessWithNoPayload();
  BranchingExample.example4Branching();
}

void main() {
  requireAsserts();
  run();
}
