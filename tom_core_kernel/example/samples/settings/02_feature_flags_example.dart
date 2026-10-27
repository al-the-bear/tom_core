/// Demonstrates feature flags: rules by tenant, role and percentage, read for
/// the principal and tenant in the zone, and a client's snapshot.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/settings/02_feature_flags_example.dart
/// ```
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The flags a deployment keeps under `featureFlags` in its configuration.
const Map<String, Object?> sampleFlags = {
  'new-checkout': {
    'default': false,
    'exposed': true,
    'rules': [
      {
        'tenants': ['acme'],
        'value': true,
      },
      {
        'roles': ['beta'],
        'value': true,
      },
      {'percentage': 10, 'value': true},
    ],
  },
  'export-row-limit': {'default': 1000},
};

TomPrincipal _principal(String id, [List<String> roles = const []]) =>
    TomPrincipal(
      user: TomUser(id: id, username: id),
      aci: TomAccessControlInformation(roles: roles),
      authenticated: true,
    );

Future<bool> _asPrincipal(TomPrincipal principal, String flag) => runZoned(
  () => TomFeatureFlags.isEnabled(flag),
  zoneValues: {TomPrincipal: principal},
);

/// Run all feature-flag examples.
Future<void> run() async {
  print('=== 02: Feature Flags Example ===\n');
  final previous = TomFeatureFlags.provider;
  try {
    // EXAMPLE 1: install the flags of the configuration.
    TomFeatureFlags.provider = TomRuleFlagProvider.fromConfiguration(
      sampleFlags,
    );
    print(
      '1. flags installed: ${(TomFeatureFlags.provider as TomRuleFlagProvider).flags.keys}',
    );

    // EXAMPLE 2: an anonymous caller gets the default.
    final anonymous = await TomFeatureFlags.isEnabled('new-checkout');
    print('2. anonymous: $anonymous');
    assert(!anonymous, 'no rule matches no one in particular');

    // EXAMPLE 3: a tenant rule.
    final acme = await TomTenantContext.run(
      'acme',
      () => TomFeatureFlags.isEnabled('new-checkout'),
    );
    print('3. tenant acme: $acme');
    assert(acme, 'the tenant rule switches it on for acme');

    // EXAMPLE 4: a role rule.
    final beta = await _asPrincipal(
      _principal('ada', ['beta']),
      'new-checkout',
    );
    print('4. beta tester: $beta');
    assert(beta, 'the role rule switches it on for beta testers');

    // EXAMPLE 5: a percentage rollout reaches about one principal in ten,
    // always the same ones.
    var reached = 0;
    for (var i = 0; i < 1000; i++) {
      if (await _asPrincipal(_principal('user-$i'), 'new-checkout')) reached++;
    }
    print('5. rollout reached $reached of 1000');
    assert(reached > 50 && reached < 150, 'about ten percent');

    // EXAMPLE 6: a read never throws; the details say why a value was given.
    final missing = await TomFeatureFlags.details<int>('unknown', 42);
    final limit = await TomFeatureFlags.getInt(
      'export-row-limit',
      defaultValue: 0,
    );
    print(
      '6. unknown: ${missing.value} (${missing.reason.name}), limit: $limit',
    );
    assert(missing.reason == TomFlagResolutionReason.flagNotFound);
    assert(limit == 1000);

    // EXAMPLE 7: a client reads the snapshot the server evaluated for it —
    // only the exposed flags.
    final snapshot = await TomFeatureFlags.provider.evaluateAll(
      const TomFlagContext(tenant: 'acme'),
    );
    TomFeatureFlags.provider = TomStaticFlagProvider(snapshot);
    print('7. client snapshot: $snapshot');
    assert(snapshot.keys.single == 'new-checkout');
    assert(await TomFeatureFlags.isEnabled('new-checkout'));
  } finally {
    TomFeatureFlags.provider = previous;
  }
}

/// Standalone entry point.
Future<void> main() => run();
