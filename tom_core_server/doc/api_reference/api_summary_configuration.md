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

Calls `setValues(getDefaultValues(args))`, then assigns `args` to the field of
the same name. The order matters in both directions: `setValues` runs first so
a subclass's constructor body sees resolved fields, and the `args` assignment
runs after it so a merged key spelled `args` cannot displace the invocation.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getDefaultValues` | `static Map<String, Object?> getDefaultValues(List<String> args)` | Builds the merged value map used to populate a configuration instance, starting from a deep copy of the provider's resources and overlaying the OS environment, a `.env` file, then the parsed `args` (which win). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `appId` | `String` | Application id (default `""`). |
| `args` | `List<String>` | The command line the configuration was built from. **Derived, not configurable** — assigned by the constructor after `setValues`, so a merged key spelled `args` does not land here. May hold a secret, since the command line is one of the out-of-band channels for supplying one. |
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
| `authServerLoginUri` | `String?` | Absolute URI of the auth server's login endpoint, e.g. `https://auth.example.com/auth/login`; `null` or blank disables server self-login (default `null`). |
| `serviceAccountName` | `String?` | Login name of this deployment's service account; `null` or blank disables server self-login (default `null`). |
| `serviceAccountCredential` | `String?` | The service account's secret — **secret-bearing**: declared here so the shape and source key are known, but never authored; supplied out-of-band at deploy time (default `null`). |
| `serviceAccountOrganization` | `String?` | Organization presented with the deployment's own login; `null` for a single-tenant deployment (default `null`). |
| `serviceAccountApplication` | `String?` | Application the deployment logs into; `null` when the auth server does not scope service logins by application (default `null`). |
| `serviceAccountProcess` | `String?` | Process (a sub-context of `serviceAccountApplication`) the deployment logs into; `null` when unscoped (default `null`). |
| `serviceAccountClient` | `String?` | Client identifier the deployment's own login originates from; `null` when the auth server does not scope service logins by client (default `null`). |
| `smtpHost` | `String?` | The mail server's host name; `null` or blank means this deployment sends no mail (default `null`). |
| `smtpPort` | `int` | The mail server's port. `0` is the "unconfigured" sentinel — as with `port` — letting the transport pick the default that goes with `smtpSecurity`: 25, 587 or 465 (default `0`). |
| `smtpSecurity` | `String` | How the connection is secured: `none`, `startTls` or `implicitTls`. An unrecognised value falls back to `startTls`, so a typo fails closed rather than sending the password in the clear (default `'startTls'`). |
| `smtpUsername` | `String?` | The login name presented to the mail server; `null` or blank for an unauthenticated relay (default `null`). |
| `smtpPassword` | `String?` | The mail server password — **secret-bearing**: declared here, never authored, supplied out-of-band. Setting `smtpUsername` without it is rejected when the settings are built, so the omission surfaces at startup rather than as a `535` on the first notification (default `null`). |
| `smtpFromAddress` | `String?` | The address mail is sent from when a message does not name its own; effectively mandatory for any deployment that actually sends, since most relays require an envelope sender they are authorised for (default `null`). |
| `smtpFromName` | `String?` | The display name shown beside `smtpFromAddress`; `null` sends the bare address (default `null`). |
| `smtpClientName` | `String` | The name announced in `EHLO`; some relays check that it resolves (default `'localhost'`). |
| `smtpAllowInsecureCertificate` | `bool` | Whether to accept a mail server certificate that does not validate. It exists because self-signed certificates are common on internal relays, and a developer who cannot turn this on will set `smtpSecurity` to `none` instead — strictly worse, since that sends `smtpPassword` in the clear (default `false`). |
| `smsEndpoint` | `String?` | The gateway's submit URL; `null` or blank means this deployment sends no SMS. Must be `http` or `https`, checked when the settings are built, so a typo surfaces at startup rather than as an unroutable request (default `null`). |
| `smsApiKey` | `String?` | The gateway credential — **secret-bearing**: declared here, never authored, supplied out-of-band exactly as `smtpPassword` is (default `null`). |
| `smsApiSecret` | `String?` | The second half of a two-part gateway credential — **secret-bearing**. Required only by `smsAuthScheme` `basic`, where `smsApiKey` is the user and this is the password; single-token gateways leave it unset (default `null`). |
| `smsSenderId` | `String?` | The sender shown to the recipient — a short code, a long number, or an alphanumeric sender id where the destination country permits one. A message may override it via `TomMessage.metadata` (default `null`). |
| `smsAuthScheme` | `String` | How the credential is presented: `none`, `bearer` or `basic`. An unrecognised value falls back to `bearer`, whose worst outcome is a `401` rather than a credential in the clear. Gateways wanting the key in the payload use `none` (default `'bearer'`). |
| `smsTimeoutSeconds` | `int` | How long to wait for the gateway before treating the attempt as deferred. A timeout is transient — the message may have been accepted — so the attempt is retried and deduplicated by message id (default `30`). |
| `smsMaxSegments` | `int` | The most segments a single message may occupy, or `0` for no cap. Over the cap fails *permanently* at send: a message too long now is too long on the retry (default `3`). |
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

Three of the blocks above are whole subsystems that are **off until
configured**, and each names one field that switches it on:

| Unset field | Effect |
| ----------- | ------ |
| `authServerLoginUri` or `serviceAccountName` | The deployment never logs itself in and runs **uncapped** — its own grants do not cap its users', which is how every server behaved before server-as-principal existed. |
| `smtpHost` | The deployment sends no mail; the messaging module registers a no-op transport rather than failing to start. |
| `smsEndpoint` | The deployment sends no SMS, answered the same way. |

Unset means *disabled*, not *misconfigured*: a test run, a local build and a CI
job all want a server that composes messages and never delivers them. A field
that is **set but unusable** is the opposite case and throws when the settings
are built — someone meant to send.

Four fields are **secret-bearing**: `serviceAccountCredential`, `smtpPassword`,
`smsApiKey` and `smsApiSecret`, under the same rule as `privateKey` and the JWT
keys. Their *declaration* lives here so the shape and the source key are known;
their **value is never authored**. It is supplied out-of-band at deploy time
through the ordinary precedence chain — OS environment, `.env`, or command line
— and must never be written into a spec or a checked-in configuration tree.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setValues` | `void setValues(Map<String, Object?> values)` | Assigns the merged configuration `values` onto this instance (implemented by generated reflection for the concrete subclass). |

### TomConfig&lt;T&gt;

A typed, eagerly-resolved view of a single configuration property. The value is
read once at construction from the active `TomServerConfigResourceProvider` and
cached; later provider changes are not observed.

The provider's value is cast to `T`, with one widening: an `int` resolves as a
`double` when `T` is `double` or `double?`, matching the reflected path that
fills a configuration object's fields. A configuration file cannot say
"double" — YAML `rate: 2` and JSON `"rate": 2` both decode to an `int` — so
without this a file could fill a declared `double` field and fail the matching
lookup. The converse is deliberately absent: a decimal is still refused for an
`int`, because narrowing would need a rounding policy.

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
