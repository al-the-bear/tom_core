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
| `selectedRuntimeEnvironmentName` | Which runtime environment the deployment selected (`env`), read from the command line, then the `.env`, then the OS environment. The selection has to happen *before* the configuration exists — it is what picks the overlay — so it reads those sources itself rather than coming out of the merge. |

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

See [`doc/configuration.md`](../../../../doc/configuration.md) for the source
precedence, the typed key wrappers and the loader hook, and
`example/configuration/configuration_example.dart` for a twelve-step walkthrough
that checks its own results — beginning with the loader hook, because a provider
installed after the first read is a provider that read did not see.
`test/configuration_test.dart` covers the module and also runs the example,
`test/runtime_environment_test.dart` covers the environment selector, and
`test/readme_quick_start_test.dart` runs the snippet above, so none can drift
unnoticed.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
