# settings

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The client-settings exchange. A client sends a `TomGetSettingsMessage` (carrying
its auth token); the server replies with a `TomGetSettingsResult` bundling
everything the client needs to configure itself — text resources, config, the
user's authorization (groups/roles/entitlements), and localization.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomGetSettingsMessage` | The settings request; carries `authorizationToken`. |
| `TomGetSettingsResult` | The settings response: `texts`, `config`, the four authorization sets `groups`, `roles`, `entitlements`, `resourceKeys` (JSON arrays on the wire, sets on arrival), plus locale fields. |

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

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
