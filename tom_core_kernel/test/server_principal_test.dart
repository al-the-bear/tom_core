/// Tests for **server-as-principal**: the ambient [TomServerPrincipal] holder
/// and the `min(user, server)` meet inside access evaluation.
///
/// The property under test throughout is that the deployment's grants **cap**
/// the user's and never widen them, and that a deployment which never installed
/// a server principal evaluates exactly as it did before the feature existed.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Builds a principal carrying [entitlements] (and optionally [roles]).
TomPrincipal _principal({
  List<String> entitlements = const [],
  List<String> roles = const [],
  String username = 'user',
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(
    id: '1',
    username: username,
    firstname: 'Test',
    lastname: 'User',
    email: 'test@example.com',
  ),
  aci: TomAccessControlInformation(roles: roles, entitlements: entitlements),
  organization: 'org',
  application: 'app',
  process: 'proc',
);

void main() {
  // Every test decides its own regime; leaking an installed principal into the
  // next test would silently change what that test measures.
  setUp(TomServerPrincipal.clear);
  tearDown(TomServerPrincipal.clear);

  group('TomServerPrincipal (the ambient holder)', () {
    test('starts unconfigured', () {
      expect(TomServerPrincipal.isConfigured, isFalse);
      expect(TomServerPrincipal.current, isNull);
    });

    test('install makes the principal current', () {
      final server = _principal(entitlements: ['feature.tasks']);
      TomServerPrincipal.install(server);
      expect(TomServerPrincipal.isConfigured, isTrue);
      expect(TomServerPrincipal.current, same(server));
    });

    test('install replaces an existing principal, as a token refresh must', () {
      TomServerPrincipal.install(_principal(entitlements: ['a']));
      final refreshed = _principal(entitlements: ['b']);
      TomServerPrincipal.install(refreshed);
      expect(TomServerPrincipal.current, same(refreshed));
    });

    test('clear returns the process to uncapped', () {
      TomServerPrincipal.install(_principal(entitlements: ['a']));
      TomServerPrincipal.clear();
      expect(TomServerPrincipal.isConfigured, isFalse);
      expect(TomServerPrincipal.current, isNull);
    });
  });

  group('The meet — unconfigured deployment (the degradation path)', () {
    test('with no server principal the user grant is returned untouched', () {
      const control = TomEntitlementAccess(['feature.tasks']);
      final user = _principal(entitlements: ['feature.tasks']);

      expect(control.resolveAuthState(user), TomAuthState.full);
      expect(control.checkAccessibility(user), isTrue);
    });

    test('an unentitled user is still denied without a server principal', () {
      const control = TomEntitlementAccess(['feature.tasks']);
      final user = _principal(entitlements: ['feature.other']);

      expect(control.resolveAuthState(user), TomAuthState.none);
      expect(control.checkAccessibility(user), isFalse);
    });

    test(
      'a role control is unaffected by the absence of a server principal',
      () {
        const control = TomRoleAccess(['admin']);
        expect(
          control.checkAccessibility(_principal(roles: ['admin'])),
          isTrue,
        );
        expect(
          control.checkAccessibility(_principal(roles: ['user'])),
          isFalse,
        );
      },
    );
  });

  group('The meet — the deployment caps the user', () {
    test('a deployment entitled to the feature leaves a full user at full', () {
      TomServerPrincipal.install(_principal(entitlements: ['feature.tasks']));
      const control = TomEntitlementAccess(['feature.tasks']);

      expect(
        control.resolveAuthState(_principal(entitlements: ['feature.tasks'])),
        TomAuthState.full,
      );
    });

    test(
      'a deployment NOT entitled to the feature drops a full user to none',
      () {
        TomServerPrincipal.install(_principal(entitlements: ['feature.other']));
        const control = TomEntitlementAccess(['feature.tasks']);
        final user = _principal(entitlements: ['feature.tasks']);

        expect(control.resolveAuthState(user), TomAuthState.none);
        expect(control.checkAccessibility(user), isFalse);
      },
    );

    test('an empty server entitlement set denies everything — it is not the '
        'same as no server principal', () {
      TomServerPrincipal.install(_principal(entitlements: const []));
      const control = TomEntitlementAccess(['feature.tasks']);
      final user = _principal(entitlements: ['feature.tasks']);

      expect(control.resolveAuthState(user), TomAuthState.none);

      TomServerPrincipal.clear();
      expect(control.resolveAuthState(user), TomAuthState.full);
    });

    test('the meet never widens — an unentitled user stays denied on an '
        'entitled deployment', () {
      TomServerPrincipal.install(_principal(entitlements: ['feature.tasks']));
      const control = TomEntitlementAccess(['feature.tasks']);

      expect(
        control.resolveAuthState(_principal(entitlements: const [])),
        TomAuthState.none,
      );
    });

    test('a control that expresses no deployment opinion is uncapped — an '
        'unrelated server grant cannot veto a role check', () {
      TomServerPrincipal.install(_principal(entitlements: ['feature.other']));
      const control = TomRoleAccess(['admin']);

      expect(control.checkAccessibility(_principal(roles: ['admin'])), isTrue);
    });
  });

  group('The meet — the four-state ladder', () {
    /// Each row: the user's grade, the deployment's grade, the expected meet.
    const ladder = <(TomAuthState, TomAuthState, TomAuthState)>[
      (TomAuthState.full, TomAuthState.full, TomAuthState.full),
      (TomAuthState.full, TomAuthState.read, TomAuthState.read),
      (TomAuthState.full, TomAuthState.disabled, TomAuthState.disabled),
      (TomAuthState.full, TomAuthState.none, TomAuthState.none),
      (TomAuthState.read, TomAuthState.full, TomAuthState.read),
      (TomAuthState.read, TomAuthState.read, TomAuthState.read),
      (TomAuthState.read, TomAuthState.disabled, TomAuthState.disabled),
      (TomAuthState.read, TomAuthState.none, TomAuthState.none),
      (TomAuthState.disabled, TomAuthState.full, TomAuthState.disabled),
      (TomAuthState.disabled, TomAuthState.read, TomAuthState.disabled),
      (TomAuthState.disabled, TomAuthState.disabled, TomAuthState.disabled),
      (TomAuthState.disabled, TomAuthState.none, TomAuthState.none),
      (TomAuthState.none, TomAuthState.full, TomAuthState.none),
      (TomAuthState.none, TomAuthState.none, TomAuthState.none),
    ];

    test('min(user, server) over every pair', () {
      TomServerPrincipal.install(_principal(entitlements: ['x']));
      for (final (userGrade, serverGrade, expected) in ladder) {
        final control = _LadderControl(userGrade, serverGrade);
        expect(
          control.resolveAuthState(_principal()),
          expected,
          reason: 'min($userGrade, $serverGrade) should be $expected',
        );
      }
    });

    test('checkAccessibility is the binary view of the same meet', () {
      TomServerPrincipal.install(_principal(entitlements: ['x']));
      for (final (userGrade, serverGrade, expected) in ladder) {
        final control = _LadderControl(userGrade, serverGrade);
        expect(
          control.checkAccessibility(_principal()),
          expected.showsContent,
          reason: 'binary view of min($userGrade, $serverGrade)',
        );
      }
    });

    test('a two-state control degenerates to a plain AND', () {
      for (final userAllows in [true, false]) {
        for (final serverAllows in [true, false]) {
          TomServerPrincipal.install(
            _principal(entitlements: serverAllows ? ['feature.x'] : const []),
          );
          const control = TomEntitlementAccess(['feature.x']);
          final user = _principal(
            entitlements: userAllows ? ['feature.x'] : const [],
          );
          expect(
            control.checkAccessibility(user),
            userAllows && serverAllows,
            reason: 'user=$userAllows AND server=$serverAllows',
          );
        }
      }
    });
  });

  group('The meet — graded controls', () {
    test(
      'a graded ladder is capped at the deployment grade, not per level',
      () {
        // full needs `feature.tasks.write`, read needs `feature.tasks.read`.
        final control = TomGradedAccess(
          full: const TomEntitlementAccess([r'^feature\.tasks\.write$']),
          read: const TomEntitlementAccess([r'^feature\.tasks\.read$']),
        );
        final user = _principal(
          entitlements: ['feature.tasks.write', 'feature.tasks.read'],
        );

        // Deployment entitled to both → the user keeps full.
        TomServerPrincipal.install(
          _principal(
            entitlements: ['feature.tasks.write', 'feature.tasks.read'],
          ),
        );
        expect(control.resolveAuthState(user), TomAuthState.full);

        // Deployment entitled to read only → the user's full is capped to read.
        TomServerPrincipal.install(
          _principal(entitlements: ['feature.tasks.read']),
        );
        expect(control.resolveAuthState(user), TomAuthState.read);

        // Deployment entitled to neither → nothing is granted.
        TomServerPrincipal.install(_principal(entitlements: ['feature.other']));
        expect(control.resolveAuthState(user), TomAuthState.none);
      },
    );

    test('a graded ladder with no server principal keeps its uncapped '
        'verdict', () {
      final control = TomGradedAccess(
        full: const TomEntitlementAccess([r'^feature\.tasks\.write$']),
        read: const TomEntitlementAccess([r'^feature\.tasks\.read$']),
      );
      expect(
        control.resolveAuthState(
          _principal(entitlements: ['feature.tasks.read']),
        ),
        TomAuthState.read,
      );
      expect(
        control.resolveAuthState(
          _principal(entitlements: ['feature.tasks.write']),
        ),
        TomAuthState.full,
      );
    });
  });
}

/// A control with both operands pinned, used to walk the ladder exhaustively.
class _LadderControl extends TomAccessControl {
  final TomAuthState userGrade;
  final TomAuthState serverGrade;
  const _LadderControl(this.userGrade, this.serverGrade);

  @override
  TomAuthState resolvePrincipalAuthState(TomPrincipal? principal) => userGrade;

  @override
  TomAuthState resolveServerAuthState(TomPrincipal serverPrincipal) =>
      serverGrade;
}
