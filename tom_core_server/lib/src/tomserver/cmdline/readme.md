# cmdline

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Command-line and environment ingestion. `TomArgs` parses `key=value` argv into a
typed map (or straight onto a reflected config object); `TomEnvFile` reads the
same `key=value` shape from a `.env` file. Both share one value-conversion table
(`"true"`/`"false"` → `bool`, unpadded all-digits → `int`, decimal → `double`,
quoted → unquoted string, otherwise the raw `String`). A digit run is typed only
when a type can carry it faithfully, so one too large for a 64-bit `int` and one
with leading zeros both stay `String`s — `007` is an identifier and `7` is a
different one.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomArgs` | Static namespace: `fillFromArgs<T>` populates a reflected object, `parseArgsToMap` returns a loose `Map`, `convertToObjectMap` normalises an existing string map (e.g. `Platform.environment`). |
| `TomEnvFile` | Reads a `.env` file into a `Map<String, Object?>` via `read([path])` / `readAsync([path])`; supports comments, blank lines, quoted and inline-commented values. Missing file → empty map. `resolveEnvironment` returns the OS environment with the `.env` layered on top, stringified — the map to hand `TomYaml.loadYamlFile(..., environment:)` so `${VAR:default}` placeholders see the `.env`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  final map = TomArgs.parseArgsToMap(['port=8080', 'host=localhost', '--debug']);

  print(map['port']);    // 8080  (int)
  print(map['host']);    // localhost  (String)
  print(map['debug']);   // true  (bool flag, named without its dashes)

  // Read a .env file (returns {} when the file is absent):
  final env = TomEnvFile.read('.env');
  print(env.isEmpty);    // true  (no .env in this example)
}
```

See [`doc/cmdline.md`](../../../../doc/cmdline.md) for the argument grammar, the
type coercion it applies and how a `.env` file merges with it, and
`example/cmdline/cmdline_example.dart` for an eight-step walkthrough that checks
its own results. `test/cmdline_test.dart` covers the module and also runs both
the example and the snippet above, so neither can drift unnoticed.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
