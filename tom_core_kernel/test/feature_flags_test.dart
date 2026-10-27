/// Feature flags: the evaluation rules (tenant, role, percentage, order,
/// default), the context taken from the zone, the typed reads that never
/// throw, the configuration form, and a client's fetch of its snapshot.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

TomPrincipal _principal(String id, {List<String> roles = const []}) =>
    TomPrincipal(
      user: TomUser(id: id, username: id),
      aci: TomAccessControlInformation(roles: roles),
      authenticated: true,
    );

/// A provider that fails on every read.
class _Failing extends TomFlagProvider {
  @override
  FutureOr<TomFlagResolution<Object?>?> resolve(
    String flagKey,
    TomFlagContext context,
  ) => throw StateError('flag service down');
}

void main() {
  late TomFlagProvider previous;
  setUp(() => previous = TomFeatureFlags.provider);
  tearDown(() => TomFeatureFlags.provider = previous);

  group('a rule', () {
    test('by tenant, by role, and both at once', () {
      const rule = TomFlagRule(
        value: true,
        tenants: {'acme'},
        roles: {'beta', 'staff'},
      );
      expect(
        rule.matches(
          'f',
          const TomFlagContext(tenant: 'acme', roles: {'beta'}),
        ),
        isTrue,
      );
      expect(
        rule.matches(
          'f',
          const TomFlagContext(tenant: 'globex', roles: {'beta'}),
        ),
        isFalse,
      );
      expect(
        rule.matches('f', const TomFlagContext(tenant: 'acme', roles: {'x'})),
        isFalse,
      );
      expect(
        const TomFlagRule(value: 1).matches('f', const TomFlagContext()),
        isTrue,
        reason: 'a rule stating nothing matches everyone',
      );
    });

    test('by percentage: stable per principal, close to the share, '
        'and growing only by adding principals', () {
      const quarter = TomFlagRule(value: true, percentage: 25);
      const half = TomFlagRule(value: true, percentage: 50);
      final ids = [for (var i = 0; i < 4000; i++) 'user-$i'];
      bool inRollout(TomFlagRule rule, String id) =>
          rule.matches('new-checkout', TomFlagContext(targetingKey: id));
      final inQuarter = ids.where((id) => inRollout(quarter, id)).toSet();
      final inHalf = ids.where((id) => inRollout(half, id)).toSet();
      expect(inQuarter.length, closeTo(1000, 120));
      expect(inHalf.length, closeTo(2000, 150));
      expect(inHalf.containsAll(inQuarter), isTrue);
      // The same principal, asked again, gets the same answer.
      for (final id in ids.take(50)) {
        expect(inRollout(quarter, id), inQuarter.contains(id));
      }
      // Another flag buckets the same principals independently.
      final otherFlag = ids
          .where(
            (id) => quarter.matches('other', TomFlagContext(targetingKey: id)),
          )
          .toSet();
      expect(otherFlag, isNot(inQuarter));
      // No one in particular is in no percentage; 0 and 100 are exact.
      expect(quarter.matches('f', const TomFlagContext()), isFalse);
      expect(
        const TomFlagRule(
          value: true,
          percentage: 0,
        ).matches('f', const TomFlagContext(targetingKey: 'u')),
        isFalse,
      );
      expect(
        const TomFlagRule(
          value: true,
          percentage: 100,
        ).matches('f', const TomFlagContext(targetingKey: 'u')),
        isTrue,
      );
      expect(TomFlagRule.bucketOf('f', 'u'), TomFlagRule.bucketOf('f', 'u'));
    });
  });

  group('a flag', () {
    const flag = TomFlagDefinition(
      key: 'new-checkout',
      defaultValue: false,
      rules: [
        TomFlagRule(value: true, tenants: {'acme'}),
        TomFlagRule(value: false, roles: {'opted-out'}),
        TomFlagRule(value: true, roles: {'beta'}),
        TomFlagRule(value: true, percentage: 100),
      ],
    );

    test('takes the first rule that matches, else its default', () {
      final acme = flag.evaluate(
        const TomFlagContext(tenant: 'acme', roles: {'opted-out'}),
      );
      expect(acme.value, isTrue);
      expect(acme.reason, TomFlagResolutionReason.targetingMatch);
      expect(acme.variant, 'rule:0');
      expect(
        flag
            .evaluate(
              const TomFlagContext(targetingKey: 'u', roles: {'opted-out'}),
            )
            .value,
        isFalse,
      );
      final split = flag.evaluate(const TomFlagContext(targetingKey: 'u'));
      expect(split.reason, TomFlagResolutionReason.split);
      expect(split.variant, 'rule:3');
      final anonymous = flag.evaluate(const TomFlagContext());
      expect(anonymous.value, isFalse);
      expect(anonymous.reason, TomFlagResolutionReason.defaultValue);
    });
  });

  group('TomFeatureFlags', () {
    setUp(() {
      TomFeatureFlags.provider = TomRuleFlagProvider([
        const TomFlagDefinition(
          key: 'beta-ui',
          defaultValue: false,
          rules: [
            TomFlagRule(value: true, roles: {'beta'}),
          ],
        ),
        const TomFlagDefinition(
          key: 'acme-limit',
          defaultValue: 100,
          rules: [
            TomFlagRule(value: 5000, tenants: {'acme'}),
          ],
        ),
        const TomFlagDefinition(key: 'banner', defaultValue: 'Welcome'),
        const TomFlagDefinition(key: 'ratio', defaultValue: 0.5),
        const TomFlagDefinition(key: 'theme', defaultValue: {'accent': 'teal'}),
      ]);
    });

    test('evaluates for the principal and tenant of the zone', () async {
      expect(await TomFeatureFlags.isEnabled('beta-ui'), isFalse);
      final beta = await runZoned(
        () => TomFeatureFlags.isEnabled('beta-ui'),
        zoneValues: {
          TomPrincipal: _principal('ada', roles: ['beta']),
        },
      );
      expect(beta, isTrue);
      expect(
        await TomTenantContext.run(
          'acme',
          () => TomFeatureFlags.getInt('acme-limit', defaultValue: 0),
        ),
        5000,
      );
      final context = runZoned(
        TomFlagContext.current,
        zoneValues: {
          TomPrincipal: _principal('ada', roles: ['beta']),
        },
      );
      expect(context.targetingKey, isNotNull);
      expect(context.roles, {'beta'});
    });

    test('reads every type, and answers the caller default on a miss, a '
        'wrong type or a failing provider', () async {
      expect(
        await TomFeatureFlags.getString('banner', defaultValue: ''),
        'Welcome',
      );
      expect(await TomFeatureFlags.getDouble('ratio', defaultValue: 0), 0.5);
      expect(await TomFeatureFlags.getObject('theme', defaultValue: const {}), {
        'accent': 'teal',
      });
      final missing = await TomFeatureFlags.details<bool>('nope', true);
      expect(missing.value, isTrue);
      expect(missing.reason, TomFlagResolutionReason.flagNotFound);
      expect(missing.usedCallerDefault, isTrue);
      final wrongType = await TomFeatureFlags.details<bool>('banner', false);
      expect(wrongType.value, isFalse);
      expect(wrongType.reason, TomFlagResolutionReason.typeMismatch);
      TomFeatureFlags.provider = _Failing();
      final failed = await TomFeatureFlags.details<int>('acme-limit', 7);
      expect(failed.value, 7);
      expect(failed.reason, TomFlagResolutionReason.error);
      expect(failed.error, isA<StateError>());
    });
  });

  group('the configuration form', () {
    test('reads flags, rules and the exposed flag', () async {
      final provider = TomRuleFlagProvider.fromConfiguration({
        'new-checkout': {
          'default': false,
          'exposed': true,
          'rules': [
            {
              'tenants': ['acme'],
              'value': true,
            },
            {'percentage': 12.5, 'value': true},
          ],
        },
        'export-row-limit': {'default': 1000},
      });
      expect(provider.flags.keys, ['new-checkout', 'export-row-limit']);
      expect(provider.flags['new-checkout']!.rules.last.percentage, 12.5);
      // Only exposed flags are handed to clients.
      expect(await provider.evaluateAll(const TomFlagContext(tenant: 'acme')), {
        'new-checkout': true,
      });
    });

    test('refuses what it cannot read, naming the flag', () {
      for (final (bad, names) in [
        ('flags', ''),
        ({'x': true}, "'x'"),
        (
          {
            'bad key!': {'default': 1},
          },
          'bad key!',
        ),
        (
          {
            'f': {'default': 1, 'rule': []},
          },
          "'f'",
        ),
        (
          {
            'f': {'default': 1, 'exposed': 'yes'},
          },
          "'f'",
        ),
        (
          {
            'f': {
              'default': 1,
              'rules': [
                {
                  'tenants': ['a'],
                },
              ],
            },
          },
          "'f'",
        ),
        (
          {
            'f': {
              'default': 1,
              'rules': [
                {'value': 1, 'percentage': 120},
              ],
            },
          },
          "'f'",
        ),
        (
          {
            'f': {
              'default': 1,
              'rules': [
                {'value': 1, 'roles': []},
              ],
            },
          },
          "'f'",
        ),
        (
          {
            'f': {
              'default': 1,
              'rules': [
                {'value': 1, 'when': 'x'},
              ],
            },
          },
          "'f'",
        ),
      ]) {
        expect(
          () => TomRuleFlagProvider.fromConfiguration(bad),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(names),
            ),
          ),
          reason: '$bad',
        );
      }
    });
  });

  group('a client', () {
    test('fetches its snapshot and reads it like the server', () async {
      late http.Request seen;
      final provider = await TomFeatureFlagsClient.fetch(
        Uri.parse('https://api.example.com'),
        bearerToken: 'tok',
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'flags': {'new-checkout': true, 'export-row-limit': 50},
            }),
            200,
          );
        }),
      );
      expect(seen.url.toString(), 'https://api.example.com/feature-flags');
      expect(seen.headers['authorization'], 'Bearer tok');
      TomFeatureFlags.provider = provider;
      expect(await TomFeatureFlags.isEnabled('new-checkout'), isTrue);
      expect(
        await TomFeatureFlags.getInt('export-row-limit', defaultValue: 0),
        50,
      );
      final detail = await TomFeatureFlags.details<bool>('new-checkout', false);
      expect(detail.reason, TomFlagResolutionReason.staticValue);
    });

    test('a server that answers no flags is a failure to fetch', () async {
      for (final response in [
        http.Response('nope', 500),
        http.Response('{"other": 1}', 200),
      ]) {
        await expectLater(
          TomFeatureFlagsClient.fetch(
            Uri.parse('https://api.example.com'),
            client: MockClient((_) async => response),
          ),
          throwsA(
            isA<TomFeatureFlagsException>().having(
              (e) => e.key,
              'key',
              'feature_flags.fetch.failed',
            ),
          ),
        );
      }
    });
  });
}
