# tom_core_d4rt examples

Runnable DartScript (`.d4rt`) examples that demonstrate the Tom Framework
bridges exposed by `tom_core_d4rt` from a **script author's** point of view —
the same way you would use them at the `d4rt` REPL or in a replay file.

Each script is written so it can be run two ways:

- **Normal mode** — prints the real runtime results of every call, so you can
  read what each bridge does:

  ```bash
  dart run bin/d4rt.dart -run-replay example/01_crypto_example.d4rt
  ```

- **Test mode** — the same script also asserts its results with the built-in
  `verify*` helpers and exits non-zero on failure, so it doubles as a smoke
  test:

  ```bash
  dart run bin/d4rt.dart -run-replay example/01_crypto_example.d4rt -test
  ```

Run all three at once:

```bash
example/run_examples.sh
```

You can also load a script inside the interactive REPL:

```bash
dart run bin/d4rt.dart
d4rt> .replay example/02_logging_example.d4rt
```

## The examples

| File | Bridge module | What it shows |
| ---- | ------------- | ------------- |
| `01_crypto_example.d4rt` | crypto (`tom_core_kernel` / `tom_crypto`) | Argon2 password hashing + verification round-trip, secure salt generation, the tunable global hash settings, and the JWT / RSA types the bridge exposes. |
| `02_logging_example.d4rt` | logging (`tom_core_kernel` / `tom_basics`) | Constructing a `TomLogger`, setting its level by `TomLogLevel` enum and by name, reading back the active level, and emitting log lines at each severity. |
| `03_security_example.d4rt` | security (`tom_core_kernel`) | The principal model (roles / entitlements / groups), ACL access-control checks, bearer authentication, and the resource-role registry + adapter that resolve a resource to an effective `TomAuthState`. |

## Notes for authors

- **One statement per line.** The replay runner parses each statement in
  isolation and does not reassemble multi-line expressions — keep each call on
  its own line.
- **No implicit null-to-string.** `null.toString()` throws in DartScript; guard
  nullable results (e.g. `x == null`) before printing them.
- **`#` starts a comment** in a `.d4rt` replay file.

See [`../doc/testing.md`](../doc/testing.md) for the full replay / `verify*`
reference and [`../README.md`](../README.md) for the bridge catalogue.
