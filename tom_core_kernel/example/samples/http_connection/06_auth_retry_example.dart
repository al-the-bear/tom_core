/// Demonstrates the framework-owned "expired-token → refresh → retry-once"
/// coordinator: [tomRunWithAuthRetry], [TomAuthRefresher], [TomAuthRetryPolicy],
/// and [TomAuthExpiredException].
///
/// Unlike `03_retry_policies_example.dart` (which shows a hand-rolled backoff
/// *pattern*), this example drives the actual kernel API that authenticated
/// clients inherit instead of re-implementing token recovery by hand.
///
/// The HTTP layer is faked with a scripted sender so the example is
/// deterministic and offline: each `send()` pops the next pre-scripted response.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A minimal stand-in for an HTTP response: just the status the coordinator
/// keys its decisions on, plus an optional server error key.
class _FakeResponse {
  final int statusCode;
  final String? errorKey;
  const _FakeResponse(this.statusCode, {this.errorKey});
}

/// A [TomAuthRefresher] whose behaviour is scripted for the example: it counts
/// invocations and either succeeds (a usable new token) or declines (no
/// session, so the original failure should stand).
class _ScriptedRefresher implements TomAuthRefresher {
  _ScriptedRefresher({this.succeeds = true});

  /// Whether a refresh yields a usable new token (worth retrying).
  final bool succeeds;

  /// How many times [refresh] was invoked.
  int refreshCount = 0;

  @override
  Future<bool> refresh() async {
    refreshCount++;
    return succeeds;
  }
}

/// Builds a sender that returns each scripted response in turn, recording how
/// many times it was called.
({Future<_FakeResponse> Function() send, int Function() calls}) _scriptedSender(
  List<_FakeResponse> script,
) {
  var index = 0;
  Future<_FakeResponse> send() async {
    final response = script[index < script.length ? index : script.length - 1];
    index++;
    return response;
  }

  return (send: send, calls: () => index);
}

Future<void> run() async {
  print('=== 06: Auth Refresh/Retry Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: The zero-config default policy
  // -------------------------------------------------------------------------
  print('1. Default retry policy:');
  print(
    '   - Expiry status codes: ${tomDefaultAuthRetryPolicy.expiryStatusCodes}',
  );
  print(
    '   - Max refresh retries: ${tomDefaultAuthRetryPolicy.maxRefreshRetries}',
  );
  print('   - 401 is expiry: ${tomDefaultAuthRetryPolicy.isAuthExpiry(401)}');
  print('   - 403 is expiry: ${tomDefaultAuthRetryPolicy.isAuthExpiry(403)}\n');

  // -------------------------------------------------------------------------
  // Example 2: Happy path — no expiry, no refresh
  // -------------------------------------------------------------------------
  print('2. Happy path (200, no refresh):');

  final happyRefresher = _ScriptedRefresher();
  final happySender = _scriptedSender([const _FakeResponse(200)]);
  final happyResult = await tomRunWithAuthRetry<_FakeResponse>(
    send: happySender.send,
    statusOf: (r) => r.statusCode,
    refresher: happyRefresher,
  );
  print('   - Result status: ${happyResult.statusCode}');
  print(
    '   - Sends: ${happySender.calls()}, refreshes: ${happyRefresher.refreshCount}\n',
  );

  // -------------------------------------------------------------------------
  // Example 3: Expiry then successful refresh + retry
  // -------------------------------------------------------------------------
  print('3. Expiry recovered by one refresh (401 → refresh → 200):');

  final recoverRefresher = _ScriptedRefresher(succeeds: true);
  final recoverSender = _scriptedSender([
    const _FakeResponse(401),
    const _FakeResponse(200),
  ]);
  final recovered = await tomRunWithAuthRetry<_FakeResponse>(
    send: recoverSender.send,
    statusOf: (r) => r.statusCode,
    refresher: recoverRefresher,
  );
  print('   - Result status: ${recovered.statusCode}');
  print(
    '   - Sends: ${recoverSender.calls()}, refreshes: ${recoverRefresher.refreshCount}\n',
  );

  // -------------------------------------------------------------------------
  // Example 4: Refresher declines (no session) — original response stands
  // -------------------------------------------------------------------------
  print('4. Refresh declined (401 → no session → 401 returned):');

  final declineRefresher = _ScriptedRefresher(succeeds: false);
  final declineSender = _scriptedSender([const _FakeResponse(401)]);
  final declined = await tomRunWithAuthRetry<_FakeResponse>(
    send: declineSender.send,
    statusOf: (r) => r.statusCode,
    refresher: declineRefresher,
  );
  print('   - Result status: ${declined.statusCode} (unchanged)');
  print(
    '   - Sends: ${declineSender.calls()}, refreshes: ${declineRefresher.refreshCount}\n',
  );

  // -------------------------------------------------------------------------
  // Example 5: Persistent expiry after refresh — throws
  // -------------------------------------------------------------------------
  print('5. Persistent expiry (401 → refresh → 401) throws:');

  final deadRefresher = _ScriptedRefresher(succeeds: true);
  final deadSender = _scriptedSender([
    const _FakeResponse(401, errorKey: 'auth.token_dead'),
    const _FakeResponse(401, errorKey: 'auth.token_dead'),
  ]);
  TomAuthExpiredException? thrown;
  try {
    await tomRunWithAuthRetry<_FakeResponse>(
      send: deadSender.send,
      statusOf: (r) => r.statusCode,
      refresher: deadRefresher,
      errorKeyOf: (r) => r.errorKey,
    );
  } on TomAuthExpiredException catch (e) {
    thrown = e;
  }
  print('   - Threw TomAuthExpiredException: ${thrown != null}');
  print('   - key: ${thrown?.key}, statusCode: ${thrown?.statusCode}');
  print('   - refreshes: ${deadRefresher.refreshCount}\n');

  // -------------------------------------------------------------------------
  // Example 6: Non-expiry error passes through untouched
  // -------------------------------------------------------------------------
  print('6. Non-expiry error (403) returned unchanged:');

  final forbiddenRefresher = _ScriptedRefresher();
  final forbiddenSender = _scriptedSender([const _FakeResponse(403)]);
  final forbidden = await tomRunWithAuthRetry<_FakeResponse>(
    send: forbiddenSender.send,
    statusOf: (r) => r.statusCode,
    refresher: forbiddenRefresher,
  );
  print('   - Result status: ${forbidden.statusCode}');
  print(
    '   - refreshes: ${forbiddenRefresher.refreshCount} (no refresh on 403)\n',
  );

  // -------------------------------------------------------------------------
  // Example 7: A custom policy tunes the expiry set and retry budget
  // -------------------------------------------------------------------------
  print('7. Custom policy (expiry {419}, 2 retries):');

  const customPolicy = TomAuthRetryPolicy(
    expiryStatusCodes: {419},
    maxRefreshRetries: 2,
  );
  print('   - 419 is expiry: ${customPolicy.isAuthExpiry(419)}');
  print(
    '   - 401 is expiry: ${customPolicy.isAuthExpiry(401)} (not under this policy)',
  );

  final customRefresher = _ScriptedRefresher(succeeds: true);
  final customSender = _scriptedSender([
    const _FakeResponse(419),
    const _FakeResponse(419),
    const _FakeResponse(200),
  ]);
  final customResult = await tomRunWithAuthRetry<_FakeResponse>(
    send: customSender.send,
    statusOf: (r) => r.statusCode,
    refresher: customRefresher,
    policy: customPolicy,
  );
  print('   - Result status: ${customResult.statusCode}');
  print('   - refreshes: ${customRefresher.refreshCount} (of budget 2)\n');

  // -------------------------------------------------------------------------
  // Example 8: The active policy resolves from a registered bean
  // -------------------------------------------------------------------------
  print('8. Active policy resolution via bean:');

  print(
    '   - Without a bean, active == default: '
    '${identical(TomAuthRetryPolicy.active, tomDefaultAuthRetryPolicy)}',
  );

  TomBean.withType(
    TomAuthRetryPolicy,
    const TomAuthRetryPolicy(expiryStatusCodes: {440}, maxRefreshRetries: 3),
  );
  final active = TomAuthRetryPolicy.active;
  print(
    '   - After registering a bean, active expiry codes: ${active.expiryStatusCodes}',
  );
  print('   - active max retries: ${active.maxRefreshRetries}');
  TomBean.resetBeanContext();
  print(
    '   - After reset, active == default again: '
    '${identical(TomAuthRetryPolicy.active, tomDefaultAuthRetryPolicy)}\n',
  );

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: default policy
  assert(tomDefaultAuthRetryPolicy.expiryStatusCodes.contains(401));
  assert(tomDefaultAuthRetryPolicy.maxRefreshRetries == 1);
  assert(tomDefaultAuthRetryPolicy.isAuthExpiry(401));
  assert(!tomDefaultAuthRetryPolicy.isAuthExpiry(403));

  // Example 2: happy path
  assert(happyResult.statusCode == 200);
  assert(happySender.calls() == 1);
  assert(happyRefresher.refreshCount == 0);

  // Example 3: recovered
  assert(recovered.statusCode == 200);
  assert(recoverSender.calls() == 2);
  assert(recoverRefresher.refreshCount == 1);

  // Example 4: declined refresh
  assert(declined.statusCode == 401);
  assert(declineSender.calls() == 1);
  assert(declineRefresher.refreshCount == 1);

  // Example 5: persistent expiry throws
  assert(thrown != null);
  assert(thrown!.statusCode == 401);
  assert(thrown!.key == 'auth.token_dead');
  assert(deadRefresher.refreshCount == 1);

  // Example 6: non-expiry passthrough
  assert(forbidden.statusCode == 403);
  assert(forbiddenRefresher.refreshCount == 0);

  // Example 7: custom policy
  assert(customPolicy.isAuthExpiry(419));
  assert(!customPolicy.isAuthExpiry(401));
  assert(customResult.statusCode == 200);
  assert(customRefresher.refreshCount == 2);

  // Example 8: active policy bean resolution
  // (assertions embedded above via identical(...) prints; re-check default)
  assert(identical(TomAuthRetryPolicy.active, tomDefaultAuthRetryPolicy));
}

/// Standalone entry point.
Future<void> main() async => run();
