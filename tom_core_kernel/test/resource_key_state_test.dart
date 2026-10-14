import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Resource-key protection answers the same four-state question the rest of the
// security module models, and it answers it from both of the principal's
// resource grants: the flat `resourceKeys` list — exact keys, `*` and
// `prefix.*` patterns — and the per-resource `resourceRoles`, mapped through
// `TomResourceRoleRegistry`. The boolean `isProtected` family is that state
// collapsed: protected unless the state shows content.

TomPrincipal _principal({
  List<String> resourceKeys = const [],
  Map<String, String> resourceRoles = const {},
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(
    id: '1',
    username: 'ada',
    firstname: 'Ada',
    lastname: 'Lovelace',
    email: 'ada@example.com',
  ),
  aci: TomAccessControlInformation(
    resourceKeys: resourceKeys,
    resourceRoles: resourceRoles,
  ),
);

void main() {
  setUp(() {
    TomResourceKeyProtection.globalSettingProtectionDefault = true;
    TomResourceRoleRegistry.reset();
  });
  tearDown(() {
    TomResourceKeyProtection.globalSettingProtectionDefault = false;
    TomResourceRoleRegistry.reset();
  });

  group('TomAccessControlInformation.holdsResourceKey', () {
    bool holds(List<String> grants, String key) =>
        TomAccessControlInformation(resourceKeys: grants).holdsResourceKey(key);

    test('an exact key is held', () {
      expect(holds(['user.email'], 'user.email'), isTrue);
      expect(holds(['user.email'], 'user.phone'), isFalse);
    });

    test('"*" holds every key', () {
      expect(holds(['*'], 'user.email'), isTrue);
      expect(holds(['*'], 'Orders'), isTrue);
    });

    test('"prefix.*" holds every key under the prefix, at any depth', () {
      expect(holds(['tom.user.*'], 'tom.user.email'), isTrue);
      expect(holds(['tom.user.*'], 'tom.user.address.city'), isTrue);
    });

    test('"prefix.*" holds neither the prefix itself nor a lookalike', () {
      // The boundary is the separator, not the text: `tom.username` is not
      // under `tom.user`.
      expect(holds(['tom.user.*'], 'tom.user'), isFalse);
      expect(holds(['tom.user.*'], 'tom.username'), isFalse);
    });

    test('a "*" anywhere but the last segment is an ordinary character', () {
      expect(holds(['tom.*.email'], 'tom.user.email'), isFalse);
      expect(holds(['tom.us*'], 'tom.user'), isFalse);
    });

    // A key beginning with `-` names a revocation: the server's endpoint
    // pipeline asks whether the principal holds `-<member>` to withdraw one
    // member of a container the principal otherwise holds. A revocation is
    // something a principal is issued by name; if `*` covered it, a principal
    // granted everything would also be refused everything.
    test('"*" does not hold a revocation', () {
      expect(holds(['*'], '-Orders.delete'), isFalse);
    });

    test('a revocation is held by name or by a revocation pattern', () {
      expect(holds(['-Orders.delete'], '-Orders.delete'), isTrue);
      expect(holds(['-Orders.*'], '-Orders.delete'), isTrue);
      expect(holds(['Orders.*'], '-Orders.delete'), isFalse);
    });
  });

  group('TomResourceKeyProtection.resourceStateFor', () {
    TomAuthState stateFor(TomPrincipal? principal, String key) =>
        TomResourceKeyProtection.resourceStateFor(principal, key);

    test('protection switched off grants everything, principal or not', () {
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
      expect(stateFor(null, 'user.salary'), TomAuthState.full);
      expect(stateFor(_principal(), 'user.salary'), TomAuthState.full);
    });

    test('no principal holds nothing', () {
      expect(stateFor(null, 'user.email'), TomAuthState.none);
    });

    test('a flat grant, exact or by pattern, is full access', () {
      expect(
        stateFor(_principal(resourceKeys: ['user.email']), 'user.email'),
        TomAuthState.full,
      );
      expect(
        stateFor(_principal(resourceKeys: ['user.*']), 'user.email'),
        TomAuthState.full,
      );
    });

    test('a resource role resolves through the registry', () {
      TomResourceRoleRegistry.registerAll({
        'viewer': TomAuthState.read,
        'locked': TomAuthState.disabled,
      });
      final principal = _principal(
        resourceRoles: {'user.email': 'viewer', 'user.salary': 'locked'},
      );

      expect(stateFor(principal, 'user.email'), TomAuthState.read);
      expect(stateFor(principal, 'user.salary'), TomAuthState.disabled);
    });

    test('a role the registry does not know grants nothing', () {
      final principal = _principal(resourceRoles: {'user.email': 'ghost'});
      expect(stateFor(principal, 'user.email'), TomAuthState.none);
    });

    test('with both a flat grant and a role, the wider state wins', () {
      TomResourceRoleRegistry.register('viewer', TomAuthState.read);
      final principal = _principal(
        resourceKeys: ['user.*'],
        resourceRoles: {'user.email': 'viewer'},
      );
      expect(stateFor(principal, 'user.email'), TomAuthState.full);
    });

    test('the zone form reads the ambient principal', () {
      TomResourceRoleRegistry.register('viewer', TomAuthState.read);
      final principal = _principal(resourceRoles: {'user.email': 'viewer'});

      runZoned(() {
        expect(
          TomResourceKeyProtection.resourceState('user.email'),
          TomAuthState.read,
        );
        expect(tomResourceState('user.email'), TomAuthState.read);
      }, zoneValues: {TomPrincipal: principal});
      expect(tomResourceState('user.email'), TomAuthState.none);
    });
  });

  group('the boolean view is the state collapsed', () {
    test('a read-only resource role is not protected', () {
      // The two grants are one answer: a principal granted `read` through a
      // resource role holds the key although the flat list does not name it.
      TomResourceRoleRegistry.register('viewer', TomAuthState.read);
      final principal = _principal(resourceRoles: {'user.email': 'viewer'});

      expect(
        TomResourceKeyProtection.isProtectedFor(principal, 'user.email'),
        isFalse,
      );
      expect(
        TomResourceKeyProtection.protectFor(
          principal,
          'ada@example.com',
          '[hidden]',
          'user.email',
        ),
        'ada@example.com',
      );
    });

    test('a disabled resource role shows no content, so it is protected', () {
      TomResourceRoleRegistry.register('locked', TomAuthState.disabled);
      final principal = _principal(resourceRoles: {'user.salary': 'locked'});

      expect(
        TomResourceKeyProtection.isProtectedFor(principal, 'user.salary'),
        isTrue,
      );
    });

    test('a pattern grant unprotects every key it covers', () {
      final principal = _principal(resourceKeys: ['tom.user.*']);
      for (final key in ['tom.user.email', 'tom.user.phone']) {
        expect(
          TomResourceKeyProtection.isProtectedFor(principal, key),
          isFalse,
          reason: key,
        );
      }
      expect(
        TomResourceKeyProtection.isProtectedFor(principal, 'tom.admin.flag'),
        isTrue,
      );
    });
  });

  group('TomResourceKeyAccess', () {
    test('resolves to the resource state, so it can grade read-only', () {
      TomResourceRoleRegistry.register('viewer', TomAuthState.read);
      final principal = _principal(resourceRoles: {'user.email': 'viewer'});
      const access = TomResourceKeyAccess('user.email');

      expect(access.resolveAuthState(principal), TomAuthState.read);
      expect(access.checkAccessibility(principal), isTrue);
    });

    test('a key the principal does not hold resolves to none', () {
      const access = TomResourceKeyAccess('user.salary');
      expect(access.resolveAuthState(_principal()), TomAuthState.none);
      expect(access.checkAccessibility(_principal()), isFalse);
    });
  });
}
