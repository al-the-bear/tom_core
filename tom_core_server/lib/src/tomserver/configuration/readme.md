# configuration

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

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
| `TomYaml` | Parses YAML configuration resources. |

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
