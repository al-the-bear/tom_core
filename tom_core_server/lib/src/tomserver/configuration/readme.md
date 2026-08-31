# configuration

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Typed access to server configuration. A `TomBaseServerConfiguration` loads
property sources (YAML via `TomYaml`, env, args) into the active
`TomServerConfigResourceProvider`; `TomConfig<T>` and its typed subclasses then
resolve individual keys — obligatory (throws when absent) or with a default.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomBaseServerConfiguration` | Abstract configuration root: assembles the property sources and installs the active config provider. |
| `TomServerConfigResourceProvider` | Holds the merged config map; `exists(key)` / `get(key)` back every `TomConfig` lookup. |
| `TomConfig<T>` | Resolves one key to `T`; `TomConfig(key)` is obligatory, `TomConfig.withDefault(key, value)` falls back. `get()` / `~config` read the value. |
| `TomStringConfig` · `TomIntConfig` · `TomDoubleConfig` · `TomBoolConfig` | Typed specialisations of `TomConfig<T>`. |
| `TomConfigurationException` | Raised when a value fails the cast to `T`. Chains the `TypeError` as `rootException` — read it for a generic mismatch, where the message alone names a value that looks valid. |
| `TomYaml` | Parses YAML configuration resources, expanding `${VAR:default}` from `Platform.environment` or from an `environment:` map you pass (`TomEnvFile.resolveEnvironment()` to include a `.env`). Both entry points require the file to exist and throw `PathNotFoundException` when it does not — unlike `TomEnvFile.read`, which returns `{}`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  // With the active config provider populated (e.g. by a
  // TomBaseServerConfiguration), resolve typed keys:
  final port = TomIntConfig.withDefault('server.port', 8080);
  final host = TomStringConfig.withDefault('server.host', 'localhost');

  print(~port); // 8080  (default, since the key is absent here)
  print(~host); // localhost
}
```

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
