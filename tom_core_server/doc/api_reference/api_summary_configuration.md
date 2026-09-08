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
  - [TomConfigurationException](#tomconfigurationexception)
  - [TomYaml](#tomyaml)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/configuration/base_server_configuration.dart`,
`lib/src/tomserver/configuration/tom_config.dart`,
`lib/src/tomserver/configuration/yaml_resources.dart`,
`lib/src/tomserver/configuration/runtime_environment.dart`.

`TomServerConfigResourceProvider` holds the resolved configuration tree and
answers dotted-path property lookups; a single provider is shared process-wide
through `getServerConfig`. `TomBaseServerConfiguration` is the reflected base
class subclasses extend to declare typed fields; its constructor fills those
fields from the merged sources (configuration resources, then the OS
environment, then a `.env` file, then command-line arguments, which win).

`TomConfig<T>` is a typed, eagerly-resolved view of a single property, with
specialised subclasses `TomStringConfig`, `TomIntConfig`, `TomDoubleConfig`, and
`TomBoolConfig`; a value that fails the cast raises
`TomConfigurationException`, which chains the `TypeError`. `TomYaml` loads YAML
files with `${VAR}` / `${VAR:default}` environment-variable substitution.

## Class Hierarchy

```
TomServerConfigResourceProvider

TomBaseServerConfiguration  (abstract, @tomReflector)

TomConfig<T>
    ├── TomStringConfig   (T = String)
    ├── TomIntConfig      (T = int)
    ├── TomDoubleConfig   (T = double)
    └── TomBoolConfig     (T = bool)

TomException  (tom_core_kernel)
    └── TomServerException
            └── TomConfigurationException

TomYaml
```

## Classes

### TomServerConfigResourceProvider

Holds the resolved configuration tree and answers property lookups for
`TomConfig`. A single provider is shared process-wide via `getServerConfig`.
Keys may be dotted paths into the nested `resources` map. A dotted key is tried
as a path first and as a literal top-level key only if the walk fails, so
`server.port` resolves whether it was written nested or flat; where a tree
carries both, the path wins and the flat key is unreachable.

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
| `loader` | `Map<String, dynamic> Function()?` | Optional factory for the default provider's `resources`, invoked the first time `getServerConfig` lazily creates a provider (static). Reachable **only before a provider exists** — it fires on that creation, so after any `setServerConfigProvider` call it can never run and `.load` is the equivalent left. |
| `resources` | `Map<String, dynamic>` | The configuration tree: a possibly-nested map of property values. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exists` | `bool exists(String s)` | Whether property `s` exists, as a dotted tree path or a top-level key. A property configured explicitly as `null` **exists** — clearing a setting is a configuration act, and `TomConfig` must see it as configured so it does not substitute a default the operator was overriding. |
| `get` | `Object? get(String s)` | Returns property `s` (dotted path or top-level key). Returns `null` when the property is present and explicitly `null`; an *unknown* key resolves to the key string `s` itself rather than throwing. The two are distinguishable: `null` means cleared, the key string means unknown — gate on `exists` rather than testing for `null`. |

### TomBaseServerConfiguration

Reflected base class for a server's configuration. Subclasses declare typed
fields; the reflection layer fills them from the merged configuration sources in
the constructor.

- **Extends:** none (abstract base)
- **Annotations:** `@tomReflector` — the generated reflection data the
  constructor reads the subclass's fields from. A subclass that skips
  `build_runner` has no fields to fill.

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
| `jwtRsaPubKey` | `String?` | PEM of the JWT RSA public key, which encrypts the token payload. Read by `installJwtSigning`; `null` means "not configured" and falls back to the framework's bundled sample key — permitted in a development or test environment, refused anywhere else. Environment name `JWT_RSA_PUB_KEY` (default `null`). |
| `jwtRsaPrivKey` | `String?` | PEM of the JWT RSA private key, under the same rule; secret-bearing. Environment name `JWT_RSA_PRIV_KEY` (default `null`). |
| `jwtSharedSecretKey` | `String?` | Passphrase of the HMAC key that signs the token, and the one value two servers must agree on to trust each other's tokens; secret-bearing. Same rule and same fallback. Environment name `JWT_SHARED_SECRET_KEY` (default `null`). |
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
| `loggingMiddleware` | `Middleware` | Request-logging middleware (default `tomLoggingMiddleware()`). Shelf's `logRequests()` drops in unchanged and adds timing, but reads nothing from the request context, so it honours neither `shouldBeLogged` (the `logRequests: false` opt-out that keeps `/health` probes out of the log) nor `hasBeenLogged`. |
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

A key configured explicitly as `null` is **present**, so it resolves through the
provider and a `withDefault` default does not apply — substituting one would
discard the setting the operator wrote. A nullable `T` resolves to `null` (the
setting is cleared); a non-nullable `T` throws, naming the key, the type and the
value. Declare the property nullable where clearing it is a legitimate
deployment choice.

A failed cast throws `TomConfigurationException`; an obligatory key with no
default throws a bare `String`, which is not an `Exception` at all. The two
failure modes of one constructor therefore need two different catch shapes.

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

### TomConfigurationException

A configuration property failed the cast to `T` and the `int`→`double` widening
did not apply. Raised by every `TomConfig` constructor.

- **Extends:** `TomServerException`

The `TypeError` the cast raised is chained as `rootException`, with its trace in
`stack`. Read it before concluding the file is right: the message names the key,
the wanted type and the value, which is enough for a scalar mismatch but not for
a generic one. A YAML `hosts: [a, b]` read as `List<String>` fails on the
element type, and the message reports `with value [a, b]` — exactly what the
operator wrote. Only the cause says `List<dynamic> is not a subtype of
List<String>`.

| Field | Value |
| ----- | ----- |
| `key` | `configuration.tom_config.property_type_mismatch` |
| `parameters` | `key`, `type` and `value`, so a handler need not parse the message |
| `rootException` | the `TypeError` raised by the failed cast |
| `stack` | that `TypeError`'s stack trace |

#### Constructors

```dart
TomConfigurationException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog,
  bool clientThrow,
})
```

### TomYaml

Utility class for loading and processing YAML configuration files with automatic
environment-variable substitution using `${VAR_NAME}` or `${VAR_NAME:default}`
syntax. All members are static.

Substitution runs after the YAML parser has assigned types and writes its
expansion back as text, so a substituted value is always a `String`:
`port: 3306` yields the `int` `3306`, `port: ${DB_PORT:3306}` the `String`
`'3306'`. This is the only configuration source that reaches `TomConfig<T>`
untyped, and `TomConfig<T>` casts rather than parses.

`loadYamlFile` is the class's only loader; the other three methods are one line
over it, so none of them can disagree about how a file is read.

The variables come from `Platform.environment` unless an `environment` map is
passed. Since Dart's process environment is read-only, that parameter is the
only way a `.env` file can reach a placeholder — pass
`TomEnvFile.resolveEnvironment()`, which returns the OS environment with the
`.env` layered over it.

The methods come in a strict and a tolerant pair. `loadYamlFile` and
`mergeInYamlFile` require the file to exist and throw `PathNotFoundException`
when it does not — the opposite of `TomEnvFile.read`, which returns an empty map
for an absent `.env`. `loadYamlFileIfPresent` and `mergeInYamlFileIfPresent`
forgive that one condition and no other: a file that is there and does not parse
still throws, so a mistyped overlay is not reported as a missing one. Each
tolerant method also *says* whether the file was there — `null` versus a map,
`false` versus `true` — because an overlay that never applied is what an
operator hunting a setting with no effect needs to be told.

#### Static Methods

| Method | Signature | Description | Throws |
| ------ | --------- | ----------- | ------ |
| `loadYamlFile` | `static Map<String, Object?> loadYamlFile(String filename, {Map<String, String>? environment})` | Loads a YAML file and returns it as a map with environment-variable substitution. `environment` supplies the variables; omitted, it is `Platform.environment`. | `PathNotFoundException` if `filename` is absent |
| `mergeInYamlFile` | `static void mergeInYamlFile(Map<String, Object?> result, String filename, {Map<String, String>? environment})` | Loads a YAML file with `loadYamlFile` and merges it one-sided into `result`, passing `environment` through. The load is an argument to the merge, so it completes first and a throw leaves `result` untouched. The merge recurses into subtrees, so the overwrite is per leaf: a file naming `db.host` alone leaves the `db` branch's other keys standing. | `PathNotFoundException` if `filename` is absent |
| `loadYamlFileIfPresent` | `static Map<String, Object?>? loadYamlFileIfPresent(String filename, {Map<String, String>? environment})` | `loadYamlFile`, returning `null` when there is no such file. Absence is the only forgiven condition: a file that exists and does not parse still throws. `null` rather than `{}`, so an absent overlay is distinguishable from an empty one. | anything but `PathNotFoundException` — a `YamlException` for a malformed file above all |
| `mergeInYamlFileIfPresent` | `static bool mergeInYamlFileIfPresent(Map<String, Object?> result, String filename, {Map<String, String>? environment})` | `mergeInYamlFile` over `loadYamlFileIfPresent`: an absent `filename` leaves `result` untouched and returns `false`, a present one merges and returns `true`. The shape the layered-overlay pattern needs, where most of the candidate files are expected not to exist. | anything but `PathNotFoundException` |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomAppId` | `String get tomAppId` | The process-wide application id: the `appId` of the configuration this isolate built, or `""` before it has built one. Read-only — an application states its name in `TomBaseServerConfiguration.appId` and nothing else publishes it. Resolves the field on each read, so a name set in a subclass constructor (which runs *after* the base constructor) is reported correctly. Read by `tomLoggingMiddleware`, which prefixes the access line with it. |
| `selectedRuntimeEnvironmentName` | `String? selectedRuntimeEnvironmentName(List<String> args, {String variable = 'env'})` | The runtime environment name the deployment selected, from the command line (`env=dev`, undashed), then the `.env` file, then the OS environment — the same three sources the configuration merge reads, in the same order. `null` when nobody named one, which is what `TomRuntime.setCurrentEnvironment` takes as "apply the fallback". The selection cannot come out of the merge, because it is what picks the `config-resources_<env>.yaml` overlay the merge reads; reading only `Platform.environment` would let a boot load the `dev` overlay while running as a production deployment. Declared in `configuration/runtime_environment.dart`. |
