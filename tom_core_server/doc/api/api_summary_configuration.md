# Tom Core Server API Reference: Configuration Module

The server configuration surface: a process-wide resource provider, a reflected
base configuration class merged from all sources, typed single-property views,
YAML loading with environment-variable substitution, and secret references
resolved from a secret store before the configuration is built.

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
  - [TomSecretsException](#tomsecretsexception)
  - [TomSecretReference](#tomsecretreference)
  - [TomSecretPayload](#tomsecretpayload)
  - [TomSecretsProvider](#tomsecretsprovider)
  - [TomMapSecretsProvider](#tommapsecretsprovider)
  - [TomSecretSubscription](#tomsecretsubscription)
  - [TomSecretsRefresh](#tomsecretsrefresh)
  - [TomSecrets](#tomsecrets)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/configuration/base_server_configuration.dart`,
`lib/src/tomserver/configuration/tom_config.dart`,
`lib/src/tomserver/configuration/yaml_resources.dart`,
`lib/src/tomserver/configuration/runtime_environment.dart`,
`lib/src/tomserver/configuration/secrets.dart`.

`TomServerConfigResourceProvider` holds the resolved configuration tree and
answers dotted-path property lookups; a single provider is shared process-wide
through `getServerConfig`. `TomBaseServerConfiguration` is the reflected base
class subclasses extend to declare typed fields; its constructor fills those
fields from the merged sources (configuration resources, then the OS
environment, then a `.env` file, then command-line arguments, which win).

`TomConfig<T>` is a typed, eagerly-resolved view of a single property, with
specialised subclasses `TomStringConfig`, `TomIntConfig`, `TomDoubleConfig`, and
`TomBoolConfig`; every way resolution fails raises `TomConfigurationException`,
one type told apart by `key`, and a failed cast chains the `TypeError`. `TomYaml` loads YAML
files with `${VAR}` / `${VAR:default}` environment-variable substitution.

`TomSecrets` resolves configuration values written as
`secret:<provider>:<path>[#<field>]` through the `TomSecretsProvider` registered
under the provider name. A boot calls `TomSecrets.load` with
`TomBaseServerConfiguration.collectSources(args)` before it builds its
configuration; `getDefaultValues` then substitutes each reference in place, so
a secret has the precedence of the source it was written in.
`TomSecretReference` parses a reference, `TomSecretPayload` is what a provider
read, `TomMapSecretsProvider` answers from a map, `watch` / `refresh` /
`startRefresh` carry rotation (`TomSecretSubscription`, `TomSecretsRefresh`),
and every failure is a `TomSecretsException`.

## Class Hierarchy

```text
TomServerConfigResourceProvider

TomBaseServerConfiguration  (abstract, @tomReflector)

TomConfig<T>
    ├── TomStringConfig   (T = String)
    ├── TomIntConfig      (T = int)
    ├── TomDoubleConfig   (T = double)
    └── TomBoolConfig     (T = bool)

TomException  (tom_core_kernel)
    └── TomServerException
            ├── TomConfigurationException
            └── TomSecretsException

TomYaml

TomSecrets  (abstract final)
TomSecretsProvider  (abstract)
    └── TomMapSecretsProvider  (implements)
TomSecretReference
TomSecretPayload
TomSecretSubscription
TomSecretsRefresh
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
| `getServerConfig` | `static TomServerConfigResourceProvider getServerConfig()` | Returns the active provider, creating a default one (using `loader` if set) on first access. The provider it creates when `loader` is unset is a **placeholder**: returned rather than refused, so a direct `exists`/`get` still answers, but marked (`isUnconfiguredPlaceholder`) and refused by `TomConfig`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `loader` | `Map<String, dynamic> Function()?` | Optional factory for the default provider's `resources`, invoked the first time `getServerConfig` lazily creates a provider (static). Reachable **only before a provider exists** — it fires on that creation, so after any `setServerConfigProvider` call it can never run and `.load` is the equivalent left. |
| `isUnconfiguredPlaceholder` | `bool` | Whether this provider is the placeholder `getServerConfig` creates when nothing has been installed and no `loader` was set (read-only). True of exactly one object: the one built because a caller asked for the active provider before anything supplied it. A provider installed, built by `loader`, or constructed directly is false however empty its `resources` are — an empty tree installed on purpose is a statement, which is the same distinction `exists` draws one level down. `TomConfig` reads it and refuses to resolve; a caller reading the provider directly is unaffected, since `exists` answering false for every key is true. |
| `resources` | `Map<String, dynamic>` | The configuration tree: a possibly-nested map of property values. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `exists` | `bool exists(String s)` | Whether property `s` exists, as a dotted tree path or a top-level key. A property configured explicitly as `null` **exists** — clearing a setting is a configuration act, and `TomConfig` must see it as configured so it does not substitute a default the operator was overriding. |
| `get` | `Object? get(String s)` | Returns property `s` (dotted path or top-level key). **Gate on `exists` first**: the method is total — it never throws and never answers `null` for a key the tree does not hold — so it cannot by itself report a key nobody configured. Returns `null` when the property is present and explicitly `null`; an *unknown* key resolves to the key string `s` itself. Keeping those two answers apart is the reason for the shape: `null` means cleared, the key string means unknown, and collapsing them onto `null` would cost the distinction `exists` exists to preserve. Throwing would cost the other half — a total read is what lets a caller walk a tree of optional settings without a `try` at every step. The price is that the fallback is indistinguishable from a configured value equal to its own key, which is why the gate is `exists` and not a test on the value. `TomConfig` gates; every read inside this package is gated, and a test fails on one that is not. |

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

Applies the kernel's protection settings from `args`
(`TomResourceKeyProtection.applyArguments` — `tom.protection…=true|false`;
throws `TomProtectionSettingException` for a misspelt setting), then calls
`setValues(getDefaultValues(args))`, then `assertRequiredSettings` on the same
merged map, then logs each of `settingWarnings` as a warning, then assigns
`args` to the field of the same name. The order matters
in every direction: `setValues` runs first so a subclass's constructor body sees
resolved fields, the required-setting check runs before the instance registers
itself as the isolate's active configuration, and the `args` assignment runs
last so a merged key spelled `args` cannot displace the invocation.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getDefaultValues` | `static Map<String, Object?> getDefaultValues(List<String> args)` | The merged value map used to populate a configuration instance: `collectSources(args)` with every secret reference replaced by the secret `TomSecrets.load` resolved for it (`TomSecrets.substitute`), in place and so with its source's precedence. Throws `TomSecretsException` `secrets.reference.unresolved` for a reference that was not loaded. |
| `collectSources` | `static Map<String, Object?> collectSources(List<String> args)` | The configuration sources merged in precedence order — a deep copy of the provider's resources, then the OS environment, a `.env` file, then the parsed `args` (which win) — with secret references still unresolved. What a boot hands to `TomSecrets.load` before it builds its configuration. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `appId` | `String` | Application id (default `""`). |
| `args` | `List<String>` | The command line the configuration was built from. **Derived, not configurable** — assigned by the constructor after `setValues`, so a merged key spelled `args` does not land here. May hold a secret, since the command line is one of the out-of-band channels for supplying one. |
| `serverHeader` | `String` | The `Server` response header, applied after the socket is listening. Empty (the default) is the "say nothing" value and sends no header. |
| `autoCompress` | `bool` | Whether the bound socket compresses compressible responses (default `true`). Only ever turned *on*: `false` leaves the socket at Dart's own default rather than disabling compression. |
| `poweredByHeader` | `String` | The `X-Powered-By` header value (default `"tom"`), fixed when the socket is bound. Empty sends no header. |
| `noSsl` | `bool` | Binds plain HTTP instead of TLS (default `false`). When set, no `SecurityContext` is built and `certificateChain` / `privateKey` are never read — the supported way to run behind a TLS-terminating proxy. |
| `listenToAnyIp` | `bool` | Overrides `host` with `anyIPv4` (default `false`). Read *after* `host`, so it does not add an address — it discards whichever one was configured, which is what a container wants when its inherited host names an address that does not exist inside it. |
| `port` | `int` | HTTP bind port; `0` is the "unconfigured" sentinel (default `0`). |
| `developmentCertificateChain` | `String` | The PEM chain `certificateChain` defaults to (static, const). Named rather than written inline so `usesDevelopmentTlsMaterial` compares against the very text the field defaults to. |
| `developmentPrivateKey` | `String` | The PEM key `privateKey` defaults to (static, const). Published, which is what `usesDevelopmentTlsMaterial` exists to detect. |
| `certificateChain` | `String` | TLS certificate chain; defaults to `developmentCertificateChain`, a throwaway self-signed `localhost` pair that MUST be overridden in production. |
| `privateKey` | `String` | TLS private key; defaults to `developmentPrivateKey`, whose value is **published in this repository**. MUST be overridden in production. |
| `jwtRsaPubKey` | `String?` | PEM of the RSA public key that encrypts the token's access-control payload. Read by `installJwtSigning`; `null` means "not configured" and falls back to the framework's bundled sample key — permitted in a development or test environment, refused anywhere else. Environment name `JWT_RSA_PUB_KEY` (default `null`). |
| `jwtRsaPrivKey` | `String?` | PEM of the RSA private key that decrypts that payload, under the same rule; secret-bearing. Environment name `JWT_RSA_PRIV_KEY` (default `null`). |
| `jwtSharedSecretKey` | `String?` | Passphrase of the HMAC key that signs and verifies tokens when `jwtAlgorithm` is `HS256`; read under no other algorithm. Secret-bearing. Same rule and same fallback. Environment name `JWT_SHARED_SECRET_KEY` (default `null`). |
| `jwtAlgorithm` | `String?` | The token signing algorithm: `RS256` (when unset), `ES256` or `HS256`. Any other name is refused with `jwt.keys.unknown_algorithm`. Environment name `JWT_ALGORITHM` (default `null`). |
| `jwtSigningKeyFile` | `String?` | Path of the PEM file (PKCS#8) holding the private key RS256 or ES256 tokens are signed with; the file is secret-bearing. Unset with no verification keys falls back to the bundled RSA pair under RS256 — in development or test only — and is refused under ES256 everywhere. Environment name `JWT_SIGNING_KEY_FILE` (default `null`). |
| `jwtVerificationKeyFiles` | `String?` | Comma-separated paths of PEM files (SPKI) holding public keys that still verify tokens: on an issuing server the keys it rotated away from, on a verify-only server the issuer's current and retired keys. Environment name `JWT_VERIFICATION_KEY_FILES` (default `null`). |
| `jwtIssuer` | `String?` | The `iss` every issued token carries and every verified token must carry; `tom` when unset. Environment name `JWT_ISSUER` (default `null`). |
| `jwtAudience` | `String?` | The `aud` every issued token carries and every verified token must carry; unset issues and requires none. Environment name `JWT_AUDIENCE` (default `null`). |
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
| `isolateCount` | `int` | How many worker isolates the deployment runs (default `10`). The framework reads it for one decision — a count above `1` binds the socket `shared` — while starting the pool is the application's boot step, so raising this without sizing the pool from it yields a shared socket and one listener. |
| `authenticationMiddleware` | `Middleware?` | Replaces the pipeline's authentication layer. `null` installs `tomDefaultAuthenticationMiddleware`, which publishes the principal every downstream layer reads; a replacement that publishes none leaves the pipeline running as nobody rather than failing. |
| `errorHandler` | `Response? Function(Request, Object, StackTrace)?` | Replaces the default error response (`tomErrorEnvelope` as a 500 with `x-tom-error: true`). Installed at two pipeline layers unless `authenticationErrorHandler` separates them. Returning `null` rethrows rather than answering. |
| `authenticationErrorHandler` | `Response? Function(Request, Object, StackTrace)?` | The error response for failures at or above the authentication layer; falls back to `errorHandler`. Separate them to answer an authentication failure with a `401` challenge rather than the `500` envelope. |
| `preExecutionHandler` | `Handler?` | A handler offered the request before the router, in a shelf `Cascade`: it answers or returns 404 to step aside. Not middleware — it cannot see or alter the router's response. |
| `postExecutionHandler` | `Handler?` | A handler reached only when the router answers 404 — a fallback, not a post-processing step. It never sees the router's response; use a `Middleware` when the response must be inspected. |
| `loggingMiddleware` | `Middleware` | Request-logging middleware (default `tomLoggingMiddleware()`). Shelf's `logRequests()` drops in unchanged and adds timing, but reads nothing from the request context, so it honours neither `shouldBeLogged` (the `logRequests: false` opt-out that keeps `/health` probes out of the log) nor `hasBeenLogged`. |
| `isolateLogging` | `bool` | Whether the deployment moves logging into an isolate of its own (default `true`). Gates the application's `TomIsolateLogging.startIsolatedLogging` boot step; the framework only carries the value. |
| `logLevelExceptions` | `String` | Per-logger level overrides as `name1=level1,name2=level2` — the "exception" is to the global `logLevel`, not an error. Applied by the application's boot; an unparseable pattern is logged and the overrides are lost. |
| `logLevel` | `String` | The global log level by name (`TRACE` … `FATAL`, or an aggregate such as `PRODUCTION`). Empty leaves the logger as it was — a deployment that says nothing does not get silence. Applied by the application's boot, so anything logged before that call uses the previous level. Environment name `LOG_LEVEL`. |
| `logFormat` | `String` | How log entries are written: `text` (default, one human-readable line per entry) or `json` (one JSON object per line carrying `trace_id`, `span_id`, `request_id` and `tenant` — the kernel's `TomJsonLogOutput`). Applied by `TomServer.start` through `TomServer.applyLogFormat` when the output is still the default console output, so an output the application installed is kept; an unrecognised value is logged as an error and changes nothing. Environment name `LOG_FORMAT`. See [server.md](../server.md#the-log-format). |
| `frameworkReadiness` | `bool` | Whether `TomServer.start` answers `GET /ready` with `TomFrameworkReadinessAnalyzer` — data sources answering, no migration running or failed, started outboxes delivering — when the application installed no readiness analyzer of its own (default `true`). Environment name `FRAMEWORK_READINESS`. See [healthcheck.md](../healthcheck.md#the-framework-readiness-checks). |
| `databaseMigrationsDirectory` | `String` | The directory `TomDbMigrations.migrateDatabases` reads, one subdirectory per datasource name (default `"./database_migrations"`). Relative, so a server started from anywhere but its package root finds no migrations. Migration is the application's boot step. |
| `openApiDocument` | `String` | The generated OpenAPI document this server publishes at `GET /openapi.json` (default `""`, publish none). `TomServer.start` hands it to `TomOpenApiServer.globalSettingDocumentPath`; the file is written at build time by `tom_core_openapi` and only served here. Relative to the working directory unless absolute, like `databaseMigrationsDirectory`. Environment name `OPEN_API_DOCUMENT`. |
| `metricsEndpoint` | `bool` | Whether `TomServer.start` answers Prometheus scrapes at `metricsPath`, ahead of authentication (default `false`). The series are recorded either way. Environment name `METRICS_ENDPOINT`. See [metrics.md](../metrics.md#configuration). |
| `metricsPath` | `String` | The path scrapes are answered at when `metricsEndpoint` is on (default `"/metrics"`). Environment name `METRICS_PATH`. |
| `metricsToken` | `String` | The bearer token a scrape must present, compared in constant time; empty leaves the endpoint open (default `""`). **Secret-bearing.** Environment name `METRICS_TOKEN`. |
| `otlpEndpoint` | `String` | The OTLP/HTTP receiver's base URL, such as `http://collector:4318`, that `TomServer.start` pushes metrics to through `TomServer.metricsExporter`; empty pushes none (default `""`). Environment name `OTLP_ENDPOINT`. |
| `otlpHeaders` | `String` | Headers of every OTLP export, as `key=value,key=value` — the form of `OTEL_EXPORTER_OTLP_HEADERS`, values percent-decoded (default `""`). May carry a credential. Environment name `OTLP_HEADERS`. |
| `otlpMetricsIntervalSeconds` | `int` | How often metrics are pushed to `otlpEndpoint`, in seconds (default `60`). Environment name `OTLP_METRICS_INTERVAL_SECONDS`. |

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

Five fields are **secret-bearing**: `serviceAccountCredential`, `smtpPassword`,
`smsApiKey`, `smsApiSecret` and `metricsToken`, under the same rule as `privateKey` and the JWT
keys. Their *declaration* lives here so the shape and the source key are known;
their **value is never authored**. It is supplied out-of-band at deploy time
through the ordinary precedence chain — OS environment, `.env`, or command line
— and must never be written into a spec or a checked-in configuration tree.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setValues` | `void setValues(Map<String, Object?> values)` | Assigns the merged configuration `values` onto this instance (implemented by generated reflection for the concrete subclass). |
| `usesDevelopmentTlsMaterial` | `bool usesDevelopmentTlsMaterial()` | Whether **either** half of the TLS material is still the checked-in development pair. Either half, because the two fail differently: a default `privateKey` means the server authenticates itself with a key published in this repository; a default `certificateChain` beside an overridden key means the pair cannot match, so the bind fails. Compared against `developmentCertificateChain` / `developmentPrivateKey`, the very constants the fields default to, so the check cannot drift from what it checks. Says nothing about whether TLS is *served* — `noSsl` answers that — and `TomServer.warnOnDevelopmentTlsMaterial` puts the two questions together. |
| `assertRequiredSettings` | `void assertRequiredSettings(Map<String, Object?> values)` | Throws `TomConfigurationException` (`configuration.base_configuration.required_settings_missing`) naming every field marked `@TomRequiredField` that `values` supplies no value for. Called by the constructor with the merged map — the only place the question can be asked, since the answer is "did *any* source name this setting" and no single source knows. A key present with `null` counts as missing (a `.env` line `DB_URL=`); an explicitly empty `String` counts as supplied (`dbUrl=` on the command line). Nothing on this class is marked: every field here has a documented default, and a field whose constructor falls back is not required. A configuration with no mirrors — a hand-written `setValues` — is not checked, because the annotation is read through them. Public, so a configuration composed some other way can ask the same question of its own map. |
| `settingWarnings` | `List<String> settingWarnings(Map<String, Object?> values, Map<String, dynamic> configurationFile)` | The startup warnings this configuration owes its operator, at most two: every top-level key of `configurationFile` (the configuration resources, before the other layers are merged over them) that names no field of the class, and every field marked `@TomRecommendedField` that `values` supplies no value for. Only the resources are checked for surplus keys, because the merged map carries the process environment. Logged by the constructor with `tomLog.warn`; the start goes on. Empty for a configuration with no mirrors. |

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

Every resolution failure throws `TomConfigurationException` — the bad cast, the
obligatory key with no default, and the property declared before any provider
existed — so one `on TomConfigurationException catch` around the declaration
covers them all and the `key` says which occurred.

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

A configuration property could not be resolved. Raised by every `TomConfig`
constructor, and by `TomBaseServerConfiguration.assertRequiredSettings`.

- **Extends:** `TomServerException`

**One type, several conditions, told apart by `key`** — the shape
`tom_core_flutter`'s `TomProperty` uses on the client side for the same
question, so a caller writes one clause and still discriminates:

| `key` | Condition |
| ----- | --------- |
| `configuration.tom_config.property_not_configured` | The key is absent and the property declared no default. |
| `configuration.tom_config.property_type_mismatch` | The key holds a value that cannot be cast to the property's `T`. |
| `configuration.tom_config.no_provider_installed` | The property was declared before any provider existed. |
| `configuration.base_configuration.required_settings_missing` | A field marked `@TomRequiredField` was supplied by no source. |

All are raised during **construction**, so catching one means wrapping the
declaration rather than the read. `parameters` carries the property `key` and
the `type` it was wanted as — and, for a mismatch, the offending `value` — so a
handler reports them without parsing the message.

`clientThrow` is **`false`** for this type, unlike `TomServerException`'s
`true`: every message names an internal configuration key, and the mismatch
names the value as well, which for `smtpPassword` or `jwtSharedSecretKey` is the
secret itself. The decision is made where the exception is defined rather than
at each raise site.

For a mismatch the `TypeError` the cast raised is chained as `rootException`,
with its trace in `stack`. Read it before concluding the file is right: the
message names the key, the wanted type and the value, which is enough for a
scalar mismatch but not for a generic one. A YAML `hosts: [a, b]` read as
`List<String>` fails on the element type, and the message reports `with value
[a, b]` — exactly what the operator wrote. Only the cause says `List<dynamic> is
not a subtype of List<String>`.

#### Constructors

```dart
TomConfigurationException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog,
  bool clientThrow = false,
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
untyped, and a typed `TomConfig<T>` reads such text as its type by the
`TomArgs.convertToObjectMap` table, so `TomIntConfig` resolves both to `3306`.

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

### TomSecretsException

A failure to read or resolve a secret, keyed `secrets.<area>.<condition>`.
Never names a secret's value — only its reference or path.

- **Extends:** `TomServerException`

| `key` | Condition |
| ----- | --------- |
| `secrets.reference.malformed` | A reference that is not `secret:<provider>:<path>[#<field>]`, or names an empty path or field. |
| `secrets.reference.unresolved` | A reference `TomSecrets.load` or `resolve` never resolved, read through `current` or `substitute`. |
| `secrets.provider.unknown` | No provider is registered under the reference's provider name. |
| `secrets.field.required` | The secret holds several values and the reference names no field. |
| `secrets.field.missing` | The secret has no member of the field's name. |
| `secrets.fetch.not_found` | The provider's store holds nothing at the path. |
| `secrets.fetch.failed` | Any other fetch failure; a provider exception that is not a `TomSecretsException` is wrapped in it as `rootException`. |

`parameters` carries the `reference`, or the `provider` and `path`.
`clientThrow` defaults to `false`: a message names an internal reference.

#### Constructors

```dart
TomSecretsException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  bool clientThrow = false,
})
```

### TomSecretReference

A parsed `secret:<provider>:<path>[#<field>]` reference. The provider runs to
the first colon after the prefix, so a path may hold colons; the field follows
the last `#`. Two references are equal when their text is.

#### Constructors

```dart
const TomSecretReference(this.provider, this.path, [this.field])
```

#### Factory Constructors

```dart
factory TomSecretReference.parse(String text)
```

| Factory | Description |
| ------- | ----------- |
| `parse` | Parses `text`. Throws `TomSecretsException` `secrets.reference.malformed` for text without the prefix, without a provider or path, or with an empty path or field. |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `prefix` | `String` | The prefix every reference starts with, `secret:` (a `const`). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `provider` | `String` | The provider's registered name. |
| `path` | `String` | Where the secret lives in the provider's own terms — a Vault API path, a secret id or ARN, a Key Vault secret name. |
| `field` | `String?` | The member of a multi-valued secret to take, or `null` for the whole. |
| `hashCode` | `int` | *(getter)* *(override)* Derived from the reference's text, so equal references hash alike. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isReference` | `static bool isReference(Object? value)` | Whether `value` is a `String` starting with `prefix`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | The reference as written: `secret:<provider>:<path>[#<field>]`. The key `TomSecrets` stores values and watchers under. |

#### Operators

| Operator | Signature | Description |
| -------- | --------- | ----------- |
| `==` | `bool operator ==(Object other)` | Equal when `other` is a `TomSecretReference` with the same text. |

### TomSecretPayload

What a provider read for one path.

#### Constructors

```dart
const TomSecretPayload(this.data, {this.version})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `data` | `Object` | The secret: a `String`, or a `Map<String, Object?>` for a secret with several members. |
| `version` | `String?` | The store's version of the secret, when it reports one. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `valueOf` | `String valueOf(TomSecretReference reference)` | The value `reference` names. Without a field, `data` must be a `String` (`secrets.field.required` otherwise). With a field, the member of a map — or of the JSON object a string decodes to — is taken; a member that is not a string is JSON-encoded; an absent one is `secrets.field.missing`. |

### TomSecretsProvider

A secret store. Implemented once per store and registered with
`TomSecrets.register` under `name`, the middle part of the references that
address it.

```dart
abstract class TomSecretsProvider {
  String get name;
  Future<TomSecretPayload> fetch(String path);
  Future<void> close() async {}
}
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | *(getter)* The name references use for this store (`vault`, `aws`, `azure`). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fetch` | `Future<TomSecretPayload> fetch(String path)` | Reads the secret at `path`. Throws `TomSecretsException` — `secrets.fetch.not_found` for a path the store does not hold, `secrets.fetch.failed` for anything else — and never puts the value in a message. |
| `close` | `Future<void> close()` | Releases anything the provider holds open; the default holds nothing. Called by `TomSecrets.reset`. |

### TomMapSecretsProvider

A provider over a map — for tests, and for local development where a
deployment's secrets come from a file nobody commits.

- **Implements:** `TomSecretsProvider`

#### Constructors

```dart
TomMapSecretsProvider(this.name, Map<String, Object> secrets)
```

`secrets` is copied.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The provider name references use. |
| `secrets` | `Map<String, Object>` | The secrets, by path — a `String` or a map of members. Change them to simulate a rotation. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fetch` | `Future<TomSecretPayload> fetch(String path)` | The entry at `path`; `secrets.fetch.not_found` when there is none. |
| `close` | `Future<void> close()` | Does nothing. |

### TomSecretSubscription

A watcher's registration, returned by `TomSecrets.watch`. It has no public
constructor.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `cancel` | `void cancel()` | Stops the watcher being called. |

### TomSecretsRefresh

What one `TomSecrets.refresh` found.

#### Constructors

```dart
const TomSecretsRefresh({this.changed = const [], this.failed = const []})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `changed` | `List<String>` | The references whose value changed. |
| `failed` | `List<String>` | The references that could not be fetched, kept at their last value. |

### TomSecrets

The registered providers and the secrets resolved through them. All members
are static. A boot registers its providers, calls `load` with
`TomBaseServerConfiguration.collectSources(args)`, and then builds its
configuration, whose `getDefaultValues` calls `substitute`. The first load is
fatal on any failure; a `refresh` keeps the last value of a reference it
cannot fetch.

```dart
abstract final class TomSecrets {
  static void register(TomSecretsProvider provider);
  static Map<String, TomSecretsProvider> get providers;
  static Set<String> get references;
  static Future<void> load(Object? values);
  static Future<String> resolve(String reference);
  static String current(String reference);
  static Object? substitute(Object? values);
  static TomSecretSubscription watch(
    String reference,
    void Function(String value) onChange,
  );
  static Future<TomSecretsRefresh> refresh();
  static void startRefresh(Duration every);
  static void stopRefresh();
  static Future<void> reset();
}
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `providers` | `Map<String, TomSecretsProvider>` | *(getter)* The registered providers, by name (unmodifiable). |
| `references` | `Set<String>` | *(getter)* The references resolved so far (unmodifiable). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register(TomSecretsProvider provider)` | Registers `provider` under its name, replacing one of that name. |
| `load` | `static Future<void> load(Object? values)` | Resolves every reference `values` holds — strings anywhere in the tree — fetching each provider path once however many fields of it are named, and remembers the values. Throws `TomSecretsException` on the first reference it cannot resolve. |
| `resolve` | `static Future<String> resolve(String reference)` | Resolves `reference` now and answers its value; fails as `load` does. |
| `current` | `static String current(String reference)` | The resolved value of `reference`; `secrets.reference.unresolved` when it was never loaded. |
| `substitute` | `static Object? substitute(Object? values)` | `values` with every reference replaced by its resolved value, maps and lists walked; `secrets.reference.unresolved` for a reference not loaded, never its text left in place. |
| `watch` | `static TomSecretSubscription watch(String reference, void Function(String value) onChange)` | Calls `onChange` with the new value whenever a `refresh` finds `reference` changed. |
| `refresh` | `static Future<TomSecretsRefresh> refresh()` | Fetches every resolved reference again and calls the watchers of those that changed; a watcher that throws is logged. A reference that cannot be fetched keeps its value and is listed in `failed`. |
| `startRefresh` | `static void startRefresh(Duration every)` | Refreshes every `every` until `stopRefresh`, replacing a running timer. |
| `stopRefresh` | `static void stopRefresh()` | Stops the periodic refresh. |
| `reset` | `static Future<void> reset()` | Stops the timer, closes every provider and forgets every provider, value and watcher — a server's shutdown, and test support. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `tomAppId` | `String get tomAppId` | The process-wide application id: the `appId` of the configuration this isolate built, or `""` before it has built one. Read-only — an application states its name in `TomBaseServerConfiguration.appId` and nothing else publishes it. Resolves the field on each read, so a name set in a subclass constructor (which runs *after* the base constructor) is reported correctly. Read by `tomLoggingMiddleware`, which prefixes the access line with it. |
| `selectedRuntimeEnvironmentName` | `String? selectedRuntimeEnvironmentName(List<String> args, {String variable = 'env'})` | The runtime environment name the deployment selected, from the command line (`env=dev`, or `--env=dev` — `TomArgs` strips a key's leading dashes), then the `.env` file, then the OS environment — the same three sources the configuration merge reads, in the same order. `null` when nobody named one, which is what `TomRuntime.setCurrentEnvironment` takes as "apply the fallback". The selection cannot come out of the merge, because it is what picks the `config-resources_<env>.yaml` overlay the merge reads; reading only `Platform.environment` would let a boot load the `dev` overlay while running as a production deployment. Declared in `configuration/runtime_environment.dart`. |
| `isDevelopmentOrTestRuntime` | `bool isDevelopmentOrTestRuntime()` | Whether the current runtime environment is a development or test one — the question the server asks before relaxing something for convenience (signing with the sample JWT keys, booting with resource-key grants unenforced without a warning). A boot that never set a current environment answers `false`: not having said "development" is not development. Declared in `configuration/runtime_environment.dart`. |
