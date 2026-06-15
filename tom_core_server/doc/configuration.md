# Configuration Module

Server configuration in three layers: a **resource provider** that holds the
resolved configuration tree, **typed accessors** (`TomConfig<T>`) for individual
properties, and a reflected **configuration base class**
(`TomBaseServerConfiguration`) that a server subclasses and that is filled from
all configuration sources at startup. `TomYaml` loads YAML files with
environment-variable substitution.

## Table of Contents

- [Overview](#overview)
- [The Resource Provider](#the-resource-provider)
- [Typed Property Access](#typed-property-access)
- [The Server Configuration Base](#the-server-configuration-base)
- [Source Precedence](#source-precedence)
- [Loading YAML](#loading-yaml)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomServerConfigResourceProvider` | class | Holds the configuration tree; answers `exists`/`get` (dotted paths) |
| `TomConfig<T>` | class | A typed, eagerly-resolved view of one property |
| `TomStringConfig` / `TomIntConfig` / `TomDoubleConfig` / `TomBoolConfig` | class | `TomConfig` specialised to a concrete type |
| `TomBaseServerConfiguration` | reflected class | Base for a server's settings; merges all sources on construction |
| `TomYaml` | class | Loads YAML files with `${VAR:default}` substitution |
| `tomAppId` | variable | Process-wide application id |

## The Resource Provider

The provider is shared process-wide. Install a populated one at startup:

```dart
TomServerConfigResourceProvider.setServerConfigProvider(
  TomServerConfigResourceProvider.from({
    'server': {'port': 8080, 'host': '0.0.0.0'},
    'featureFlags': {'beta': true},
  }),
);

final cfg = TomServerConfigResourceProvider.getServerConfig();
cfg.exists('server.port'); // true  — dotted path into the tree
cfg.get('server.port');    // 8080
```

`get` resolves a **dotted path** into the nested tree, falling back to a
top-level key. As a deliberate convenience an *unknown* key resolves to the key
string itself rather than throwing — so distinguish absence with `exists`
(which is what `TomConfig` does internally).

Alternatively, supply a lazy `loader` (used when the default provider is created
on first `getServerConfig`) or construct with `.load(loader)`.

## Typed Property Access

`TomConfig<T>` reads its value **once at construction** from the active provider
and caches it. Resolution order:

1. provider has the key → cast its value to `T` (a bad cast throws);
2. else a default was supplied → use it;
3. else the property is obligatory → construction throws.

```dart
final port = TomIntConfig.withDefault('server.port', 8080).get(); // 8080
final host = TomStringConfig('server.host').get();                // obligatory

// The ~ operator is shorthand for .get():
final beta = ~TomBoolConfig.withDefault('featureFlags.beta', false);
```

Because the value is captured at construction, build a `TomConfig` *after* the
provider is installed; later provider changes are not observed by an existing
instance.

## The Server Configuration Base

A server subclasses `TomBaseServerConfiguration` and declares typed fields
(`port`, `host`, `noSsl`, `certificateChain`, `privateKey`, `isolateCount`,
handler/middleware hooks, logging levels, …). The class is `@tomReflector`, and
its constructor fills those fields from the merged configuration via the
generated `setValues`:

```dart
@tomReflector
class MyServerConfig extends TomBaseServerConfiguration {
  MyServerConfig(super.args);
  // setValues is provided by the generated reflection.
}

void main(List<String> argv) {
  final config = MyServerConfig(argv); // reads env, .env, and argv
  TomServer(config).start();
}
```

> The default `certificateChain` / `privateKey` are a throwaway self-signed
> `localhost` pair for local development and **must be overridden in
> production**. JWT signing-key fields exist; richer JWT-creation settings are a
> tracked follow-up.

## Source Precedence

`getDefaultValues(args)` merges sources with later ones overriding earlier:

```text
configuration resources  ─┐
OS environment           ─┼─►  merged values  ─►  setValues(...)  ─►  the config
.env file (./.env)       ─┤    (args win over .env win over env win over resources)
command-line arguments   ─┘
```

All non-resource sources flow through the command-line conversion rules (see
`doc/cmdline.md`), so `port=8080` becomes the int `8080`, `noSsl=true` the bool
`true`, and so on.

## Loading YAML

`TomYaml` reads a YAML file into a clean JSON-like map and expands
`${VAR}` / `${VAR:default}` placeholders from `Platform.environment`:

```dart
// config.yaml:
//   database:
//     host: ${DB_HOST:localhost}
//     port: ${DB_PORT:3306}
final map = TomYaml.loadYamlFile('config.yaml');
// or merge into an existing map:
TomYaml.mergeInYamlFile(existing, 'config.yaml');
```

A placeholder with no matching environment variable falls back to its `:default`
(or stays unresolved if no default is given).

## Core Components

- **`TomServerConfigResourceProvider`** — the configuration tree and its
  `exists` / `get` lookups; the `setServerConfigProvider` / `getServerConfig`
  singleton and the `loader` hook.
- **`TomConfig<T>`** (+ `TomStringConfig` / `TomIntConfig` / `TomDoubleConfig` /
  `TomBoolConfig`) — typed, eagerly-resolved property views; `get()` / `~`.
- **`TomBaseServerConfiguration`** — the reflected settings base;
  `getDefaultValues` (the source merge) and the reflected `setValues`.
- **`TomYaml`** — YAML loading with environment substitution.

## Dependencies

- `tom_core_kernel` — `tomReflector`, `getObjectFromTree`, `mergeMapsOneSided`,
  `makeCleanJsonMap`, `substituteEnvVars`.
- The cmdline module — `TomArgs` and `TomEnvFile` (source parsing/merging).
- `shelf` — the `Middleware` / `Handler` / `Request` / `Response` types used by
  the configuration's handler fields.
- `yaml` — YAML parsing for `TomYaml`.
