# settings

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The client-settings exchange. A client sends a `TomGetSettingsMessage` (carrying
its auth token); the server replies with a `TomGetSettingsResult` bundling
everything the client needs to configure itself — text resources, config, the
user's authorization (groups/roles/entitlements), and localization.

Beside it, **feature flags**: values a deployment switches without a release,
evaluated for the work at hand — its tenant, its principal's roles, or a stable
percentage of principals — and read through one provider contract shaped after
OpenFeature, so a vendor service can be plugged in without changing a call site.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomGetSettingsMessage` | The settings request; carries `authorizationToken`. |
| `TomGetSettingsResult` | The settings response: `texts`, `config`, the four authorization sets `groups`, `roles`, `entitlements`, `resourceKeys` (JSON arrays on the wire, sets on arrival), plus locale fields. |
| `TomFeatureFlags` | The flag API: `isEnabled`, `getString`, `getInt`, `getDouble`, `getObject`, and `details` with the reason; reads the installed `provider` and never throws. |
| `TomFlagContext` | Who a flag is evaluated for: `targetingKey`, `tenant`, `roles`, `attributes`; `current()` reads the principal and tenant of the zone. |
| `TomFlagProvider` | The provider contract: `resolve` one flag, `evaluateAll` for a client's snapshot. |
| `TomFlagResolution` | One evaluation: `value`, `reason`, `variant`, `error`, `usedCallerDefault`. |
| `TomFlagResolutionReason` | Why a flag has its value: `defaultValue`, `targetingMatch`, `split`, `staticValue`, `flagNotFound`, `typeMismatch`, `error`. |
| `TomRuleFlagProvider` | The built-in provider: flag definitions and their rules, read by `fromConfiguration`; `evaluateAll` answers the `exposed` flags only. |
| `TomStaticFlagProvider` | A provider of fixed values — a client's snapshot of what the server evaluated for it, or a test's. |
| `TomFlagDefinition` | One flag: `key`, `defaultValue`, `rules`, `exposed`; `evaluate` for a context. |
| `TomFlagRule` | One targeting rule: `tenants`, `roles`, `percentage` and the `value`; `matches`, and `bucketOf`, the stable hash bucket. |
| `tomFeatureFlagsApi` | The `GET /feature-flags` API (`TomPublicAccess`), id `tomFeatureFlagsApiId`, endpoint `tomFeatureFlagsEvaluateEndpointId`; `registerTomFeatureFlagsApi` registers it. |
| `TomFeatureFlagsClient` | `fetch` — a client's flags from a server, as a `TomStaticFlagProvider` to install. |
| `TomFeatureFlagsException` | A client could not fetch its flags (`feature_flags.fetch.failed`). |

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final request = TomGetSettingsMessage()..authorizationToken = 'jwt-token';

  // The server builds a result like this:
  final result = TomGetSettingsResult(
    texts: {'welcome': 'Welcome'},
    roles: ['admin'],
    clientLanguage: 'en',
  );

  print(request.authorizationToken);  // jwt-token
  print(result.texts['welcome']);     // Welcome
  print(result.roles);                // {admin}
}
```

Both classes carry `@tomReflector`, which is why every field is public, mutable
and non-`final` and neither class writes its own `toJson`/`fromJson`: the
generated reflection data builds a zero-argument instance and assigns the fields
by name. Every constructor parameter is optional — collections then default to a
fresh mutable empty one per instance (so a server can build a result
incrementally), strings to `null`.

## Why a received result stays mutable

On the client a `TomGetSettingsResult` is an answer the server gave, and nothing
stops code from writing `settings.roles.add('admin')` and then asking
`settings.roles.contains('admin')`. That is deliberate, and it is safe:

- **The authorization lists decide what the client shows, never what it may
  do.** Every call the client makes is judged by the server against the
  principal in its bearer token; the settings result is a copy of that answer
  for the client to render from. A client that edits its copy changes its own
  screen and nothing else — the server refuses the call the new button makes.
- **The shape is the reflected round trip's.** The deserializer builds a
  zero-argument instance and assigns each field by name, and a server builds a
  result up as each authorization source resolves. Unmodifiable views over
  private backing fields would give the generator a getter/field pair to
  resolve for every collection; a separate immutable client type would double
  the wire contract and add a conversion every consumer must remember. Neither
  buys protection the server does not already provide.

A consumer that wants to guard its own code against editing the answer takes an
unmodifiable snapshot where it receives it — `Set.unmodifiable(settings.roles)`
— as the `AuthorizationService` in `doc/settings/settings.md` does.

## Feature flags

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

Future<void> main() async {
  TomFeatureFlags.provider = TomRuleFlagProvider.fromConfiguration({
    'new-checkout': {
      'default': false,
      'exposed': true,
      'rules': [
        {'tenants': ['acme'], 'value': true},
        {'percentage': 10, 'value': true},
      ],
    },
    'export-row-limit': {'default': 1000},
  });

  final on = await TomTenantContext.run(
    'acme',
    () => TomFeatureFlags.isEnabled('new-checkout'),
  );
  final limit =
      await TomFeatureFlags.getInt('export-row-limit', defaultValue: 0);
  print('$on $limit'); // true 1000
}
```

A rule matches when every condition it states holds — the tenant is one of
`tenants`, the principal holds one of `roles`, the principal falls in the first
`percentage` percent of the flag's buckets — and the first matching rule gives
the value; none matching gives the flag's `default`. The bucket is a hash of the
flag key and the principal's id, so a principal stays in or out of a rollout
across requests and processes, and raising the percentage only adds principals.
A context without a targeting key (an anonymous caller) is in no percentage.

A read never throws: an unknown flag, a value of another type or a failing
provider answer the caller's default, and `details` says which
(`flagNotFound`, `typeMismatch`, `error`).

A server installs the provider from its `featureFlags` configuration key and
serves `GET /feature-flags`; a client fetches its evaluated flags once
(`TomFeatureFlagsClient.fetch`), installs the snapshot and reads locally. Only
flags marked `exposed` travel — a flag is server-only unless it says so.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
