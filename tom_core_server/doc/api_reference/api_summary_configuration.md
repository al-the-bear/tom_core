# Tom Core Server API Reference: Configuration Module

The server configuration surface: a process-wide resource provider, a reflected
base configuration class merged from all sources, typed single-property views,
and YAML loading with environment-variable substitution.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomServerConfigResourceProvider](#tomserverconfigresourceprovider)
  - [TomBaseServerConfiguration](#tombaseserverconfiguration)
  - [TomConfig&lt;T&gt;](#tomconfigt)
  - [TomStringConfig](#tomstringconfig)
  - [TomIntConfig](#tomintconfig)
  - [TomDoubleConfig](#tomdoubleconfig)
  - [TomBoolConfig](#tomboolconfig)
  - [TomYaml](#tomyaml)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/configuration/base_server_configuration.dart`,
`lib/src/tomserver/configuration/tom_config.dart`,
`lib/src/tomserver/configuration/yaml_resources.dart`.

`TomServerConfigResourceProvider` holds the resolved configuration tree and
answers dotted-path property lookups; a single provider is shared process-wide
through `getServerConfig`. `TomBaseServerConfiguration` is the reflected base
class subclasses extend to declare typed fields; its constructor fills those
fields from the merged sources (configuration resources, then the OS
environment, then a `.env` file, then command-line arguments, which win).

`TomConfig<T>` is a typed, eagerly-resolved view of a single property, with
specialised subclasses `TomStringConfig`, `TomIntConfig`, `TomDoubleConfig`, and
`TomBoolConfig`. `TomYaml` loads YAML files with `${VAR}` / `${VAR:default}`
environment-variable substitution.

## Class Hierarchy

```
TomServerConfigResourceProvider

TomBaseServerConfiguration  (abstract, @tomReflector)

TomConfig<T>
    ├── TomStringConfig   (T = String)
    ├── TomIntConfig      (T = int)
    ├── TomDoubleConfig   (T = double)
    └── TomBoolConfig     (T = bool)

TomYaml
```

## Classes

### TomServerConfigResourceProvider

Holds the resolved configuration tree and answers property lookups for
`TomConfig`. A single provider is shared process-wide via `getServerConfig`.
Keys may be dotted paths into the nested `resources` map.

#### Constructors

```dart
TomServerConfigResourceProvider()
TomServerConfigResourceProvider.load(Map<String, dynamic> Function() loader)
TomServerConfigResourceProvider.from(Map<String, dynamic> resources)
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setServerConfigProvider` | `static void setServerConfigProvider(TomServerConfigResourceProvider provider)` | Installs `provider` as the process-wide configuration source. |
| `getServerConfig` | `static TomServerConfigResourceProvider getServerConfig()` | Returns the active provider, creating a default one (using `loader` if set) on first access. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `loader` | `Map<String, dynamic> Function()?` | Optional factory for the default provider's `resources`, invoked the first time `getServerConfig` lazily creates a provider (static). |
| `resources` | `Map<String, dynamic>` | The configuration tree: a possibly-nested map of property values. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exists` | `bool exists(String s)` | Whether property `s` exists, as a dotted tree path or a top-level key. |
| `get` | `Object get(String s)` | Returns property `s` (dotted path or top-level key); an unknown key resolves to the key string `s` itself rather than throwing. |

### TomBaseServerConfiguration

Reflected base class for a server's configuration. Subclasses declare typed
fields; the reflection layer fills them from the merged configuration sources in
the constructor.

- **Extends:** annotated with `@tomReflector` (abstract).

#### Constructors

```dart
TomBaseServerConfiguration(List<String> args)
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getDefaultValues` | `static Map<String, Object?> getDefaultValues(List<String> args)` | Builds the merged value map used to populate a configuration instance, starting from a deep copy of the provider's resources and overlaying the OS environment, a `.env` file, then the parsed `args` (which win). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `appId` | `String` | Application id (default `""`). |
| `args` | `List<String>` | Raw command-line arguments (default `[]`). |
| `serverHeader` | `String` | `Server` response header (default `""`). |
| `autoCompress` | `bool` | Whether responses are auto-compressed (default `true`). |
| `poweredByHeader` | `String` | `X-Powered-By` header value (default `"tom"`). |
| `noSsl` | `bool` | Disables SSL when `true` (default `false`). |
| `listenToAnyIP` | `bool` | Binds to any IP when `true` (default `false`). |
| `port` | `int` | HTTP bind port; `0` is the "unconfigured" sentinel (default `0`). |
| `certificateChain` | `String` | TLS certificate chain; defaults to a throwaway self-signed `localhost` pair that MUST be overridden in production. |
| `privateKey` | `String` | TLS private key; defaults to a throwaway self-signed `localhost` key that MUST be overridden in production. |
| `jwtRsaPubKey` | `String?` | JWT RSA public key. |
| `jwtRsaPrivKey` | `String?` | JWT RSA private key. |
| `jwtSharedSecretKey` | `String?` | JWT shared-secret passphrase (default `"config-secret-passphrase"`; currently not in use). |
| `host` | `String` | Bind host; empty makes `TomServer.start` listen on `InternetAddress.anyIPv4` (default `""`). |
| `isolateCount` | `int` | Number of worker isolates (default `10`). |
| `authenticationMiddleware` | `Middleware?` | Optional authentication middleware. |
| `errorHandler` | `Response? Function(Request, Object, StackTrace)?` | Optional error handler. |
| `authenticationErrorHandler` | `Response? Function(Request, Object, StackTrace)?` | Optional authentication error handler. |
| `preExecutionHandler` | `Handler?` | Optional handler run before execution. |
| `postExecutionHandler` | `Handler?` | Optional handler run after execution. |
| `loggingMiddleware` | `Middleware` | Request-logging middleware (default `tomLoggingMiddleware()`). |
| `isolateLogging` | `bool` | Whether isolate logging is enabled (default `true`). |
| `logLevelExceptions` | `String` | Log level for exceptions (default `""`). |
| `logLevel` | `String` | Global log level (default `""`). |
| `databaseMigrationsDirectory` | `String` | Directory of database migrations (default `"./database_migrations"`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setValues` | `void setValues(Map<String, Object?> values)` | Assigns the merged configuration `values` onto this instance (implemented by generated reflection for the concrete subclass). |

### TomConfig&lt;T&gt;

A typed, eagerly-resolved view of a single configuration property. The value is
read once at construction from the active `TomServerConfigResourceProvider` and
cached; later provider changes are not observed.

- **Type Parameters:** `T` — the resolved value type.

#### Constructors

```dart
TomConfig(String key)
TomConfig.withDefault(String key, T value)
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `get` | `T? get()` | Returns the resolved value (or `null` only for a nullable `T` default). |

#### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `~` | `T? operator ~()` | Shorthand for `get`: `~config` returns the resolved value. |

### TomStringConfig

A `TomConfig` specialised to `String`.

- **Extends:** `TomConfig<String>`

#### Constructors

```dart
TomStringConfig(String key)
TomStringConfig.withDefault(String key, String value)
```

### TomIntConfig

A `TomConfig` specialised to `int`.

- **Extends:** `TomConfig<int>`

#### Constructors

```dart
TomIntConfig(String key)
TomIntConfig.withDefault(String key, int value)
```

### TomDoubleConfig

A `TomConfig` specialised to `double`.

- **Extends:** `TomConfig<double>`

#### Constructors

```dart
TomDoubleConfig(String key)
TomDoubleConfig.withDefault(String key, double value)
```

### TomBoolConfig

A `TomConfig` specialised to `bool`.

- **Extends:** `TomConfig<bool>`

#### Constructors

```dart
TomBoolConfig(String key)
TomBoolConfig.withDefault(String key, bool value)
```

### TomYaml

Utility class for loading and processing YAML configuration files with automatic
environment-variable substitution using `${VAR_NAME}` or `${VAR_NAME:default}`
syntax. All members are static.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `mergeInYamlFile` | `static void mergeInYamlFile(Map<String, Object?> result, String filename)` | Loads a YAML file and merges it into `result`, expanding environment variables from `Platform.environment`. |
| `loadYamlFile` | `static Map<String, Object?> loadYamlFile(String filename)` | Loads a YAML file and returns it as a map with environment-variable substitution. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomAppId` | `String tomAppId` | The process-wide application id, set from configuration at startup (default `""`). |
