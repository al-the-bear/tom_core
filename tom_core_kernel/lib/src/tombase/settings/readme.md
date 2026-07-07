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
| `TomGetSettingsResult` | The settings response: `texts`, `config`, `groups`, `roles`, `entitlements`, `resourceKeys`, plus locale fields. |

## Quick start

```dart
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
  print(result.roles);                // [admin]
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
