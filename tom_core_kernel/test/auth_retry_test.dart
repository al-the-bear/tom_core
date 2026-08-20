/// Unit tests for the kernel's pluggable refresh-once-on-expiry coordinator
/// [tomRunWithAuthRetry]: it must recover a single expired-token failure by
/// refreshing and replaying exactly once, give up (as a typed error) on a
/// persistent expiry without looping, leave non-expiry statuses untouched, and
/// honour the active [TomAuthRetryPolicy].
///
/// A tiny [_FakeRefresher] stands in for a live auth server (a "mock auth
/// server" at the coordinator seam), and a scripted response queue drives the
/// `send` callback — so the whole mechanism is exercised without a socket.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

/// A refresher whose outcome is scripted: it either yields a fresh token
/// ([succeed]), reports "nothing to refresh" (returns `false`), or throws.
class _FakeRefresher implements TomAuthRefresher {
  _FakeRefresher({this.succeed = true, this.error});

  final bool succeed;
  final Object? error;
  int calls = 0;

  @override
  Future<bool> refresh() async {
    calls++;
    if (error != null) throw error!;
    return succeed;
  }
}

/// Drives the `send` callback from a queue of `(status, errorKey)` pairs, one
/// per attempt, recording how many times it was called.
class _ScriptedSend {
  _ScriptedSend(this._responses);
  final List<(int, String?)> _responses;
  int calls = 0;

  Future<(int, String?)> call() async {
    final r = _responses[calls];
    calls++;
    return r;
  }
}

void main() {
  group('tomRunWithAuthRetry', () {
    // Beans are process-global; keep the policy resolution isolated per test.
    setUp(TomBean.resetBeanContext);
    tearDown(TomBean.resetBeanContext);

    Future<(int, String?)> run(
      _ScriptedSend send,
      TomAuthRefresher refresher, {
      TomAuthRetryPolicy? policy,
    }) => tomRunWithAuthRetry<(int, String?)>(
      send: send.call,
      statusOf: (r) => r.$1,
      errorKeyOf: (r) => r.$2,
      refresher: refresher,
      policy: policy,
    );

    test('a 2xx is returned unchanged, with no refresh', () async {
      final send = _ScriptedSend([(200, null)]);
      final refresher = _FakeRefresher();

      final result = await run(send, refresher);

      expect(result.$1, 200);
      expect(send.calls, 1);
      expect(refresher.calls, 0);
    });

    test(
      'a non-expiry error (403) is returned as-is, with no refresh',
      () async {
        final send = _ScriptedSend([(403, 'app.access.forbidden')]);
        final refresher = _FakeRefresher();

        final result = await run(send, refresher);

        expect(result.$1, 403);
        expect(send.calls, 1);
        expect(refresher.calls, 0);
      },
    );

    test(
      'a 401 refreshes once and retries, returning the recovered response',
      () async {
        final send = _ScriptedSend([(401, 'auth.token.expired'), (200, null)]);
        final refresher = _FakeRefresher();

        final result = await run(send, refresher);

        expect(result.$1, 200);
        expect(refresher.calls, 1);
        expect(send.calls, 2); // original + exactly one retry.
      },
    );

    test(
      'a 401 that persists after refresh throws TomAuthExpiredException',
      () async {
        final send = _ScriptedSend([
          (401, 'auth.token.expired'),
          (401, 'auth.token.invalid'),
        ]);
        final refresher = _FakeRefresher();

        await expectLater(
          run(send, refresher),
          throwsA(
            isA<TomAuthExpiredException>()
                .having((e) => e.key, 'key', 'auth.token.invalid')
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
        expect(refresher.calls, 1); // one refresh, then it gives up — no loop.
        expect(send.calls, 2);
      },
    );

    test(
      'a refresher that reports "nothing to refresh" surfaces the original',
      () async {
        final send = _ScriptedSend([(401, 'auth.token.expired')]);
        final refresher = _FakeRefresher(succeed: false);

        final result = await run(send, refresher);

        expect(result.$1, 401);
        expect(refresher.calls, 1);
        expect(send.calls, 1); // no retry when the refresher can't refresh.
      },
    );

    test('a throwing refresher propagates its own error', () async {
      final send = _ScriptedSend([(401, 'auth.token.expired')]);
      final boom = StateError('refresh failed');
      final refresher = _FakeRefresher(error: boom);

      await expectLater(run(send, refresher), throwsA(same(boom)));
      expect(send.calls, 1);
    });

    test('the active policy is resolved from a registered bean', () async {
      // A policy that treats 419 (not 401) as the expiry status.
      TomBean.withType(
        TomAuthRetryPolicy,
        const TomAuthRetryPolicy(expiryStatusCodes: {419}),
      );
      final send = _ScriptedSend([(419, 'auth.expired'), (200, null)]);
      final refresher = _FakeRefresher();

      // No explicit policy: it must pick up the bean.
      final result = await tomRunWithAuthRetry<(int, String?)>(
        send: send.call,
        statusOf: (r) => r.$1,
        refresher: refresher,
      );

      expect(result.$1, 200);
      expect(refresher.calls, 1);
      expect(send.calls, 2);
    });
  });
}
