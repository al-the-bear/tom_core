# Configuration Module

Server configuration in three layers: a **resource provider** that holds the
resolved configuration tree, **typed accessors** (`TomConfig<T>`) for individual
properties, and a reflected **configuration base class**
(`TomBaseServerConfiguration`) that a server subclasses and that is filled from
all configuration sources at startup. `TomYaml` loads YAML files with
environment-variable substitution, and `TomSecrets` resolves values written as
**secret references** — `secret:<provider>:<path>[#<field>]` — from a secret
store before the configuration is built.

## Table of Contents

- [Overview](#overview)
- [The Resource Provider](#the-resource-provider)
- [Typed Property Access](#typed-property-access)
  - [A cleared key takes step 1, not step 2](#a-cleared-key-takes-step-1-not-step-2)
  - [What a failed resolution throws](#what-a-failed-resolution-throws)
    - [The chained cause of a bad cast](#the-chained-cause-of-a-bad-cast)
- [The Server Configuration Base](#the-server-configuration-base)
  - [Unknown keys in the configuration resources](#unknown-keys-in-the-configuration-resources)
  - [The development TLS pair announces itself](#the-development-tls-pair-announces-itself)
  - [Requiring a setting](#requiring-a-setting)
  - [Recommending a setting](#recommending-a-setting)
  - [Naming the application](#naming-the-application)
  - [Switching protection off from the command line](#switching-protection-off-from-the-command-line)
- [Deployment Settings](#deployment-settings)
  - [JWT Signing Keys](#jwt-signing-keys)
  - [Server Self-Login](#server-self-login)
  - [Outbound Mail (SMTP)](#outbound-mail-smtp)
  - [Outbound SMS (HTTP Gateway)](#outbound-sms-http-gateway)
- [Publishing the OpenAPI Document](#publishing-the-openapi-document)
- [Publishing Metrics](#publishing-metrics)
- [Log Format and Readiness](#log-format-and-readiness)
- [Graceful Shutdown](#graceful-shutdown)
- [Outgoing HTTP Calls](#outgoing-http-calls)
- [Idempotency Keys](#idempotency-keys)
- [Field-Level Encryption](#field-level-encryption)
- [Privacy](#privacy)
- [Transaction Recovery](#transaction-recovery)
- [Source Precedence](#source-precedence)
  - [A `SCREAMING_SNAKE_CASE` variable names a `lowerCamelCase` field](#a-screaming_snake_case-variable-names-a-lowercamelcase-field)
- [Secret References](#secret-references)
  - [Where a reference may appear](#where-a-reference-may-appear)
  - [Precedence is the source's](#precedence-is-the-sources)
  - [Boot order: load, then build](#boot-order-load-then-build)
  - [Rotation: refresh and watch](#rotation-refresh-and-watch)
  - [Writing a provider](#writing-a-provider)
  - [The provider libraries](#the-provider-libraries)
  - [Error keys](#error-keys)
- [Loading YAML](#loading-yaml)
  - [Where the variables come from — and how a `.env` reaches them](#where-the-variables-come-from--and-how-a-env-reaches-them)
  - [An overlay is a patch, not a replacement](#an-overlay-is-a-patch-not-a-replacement)
  - [A substituted value is a string](#a-substituted-value-is-a-string)
  - [A missing file throws, unless you ask for the tolerant loader](#a-missing-file-throws-unless-you-ask-for-the-tolerant-loader)
- [Not Yet Implemented](#not-yet-implemented)
- [Core Components](#core-components)
- [Verification](#verification)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomServerConfigResourceProvider` | class | Holds the configuration tree; answers `exists`/`get` (dotted paths) |
| `TomConfig<T>` | class | A typed, eagerly-resolved view of one property |
| `TomStringConfig` / `TomIntConfig` / `TomDoubleConfig` / `TomBoolConfig` | class | `TomConfig` specialised to a concrete type |
| `TomConfigurationException` | class | A property failed the cast to `T`; chains the `TypeError` |
| `TomBaseServerConfiguration` | abstract class | Base for a server's settings; merges all sources on construction |
| `TomYaml` | class | Loads YAML files with `${VAR:default}` substitution |
| `tomAppId` | getter | Process-wide application id, read from the active configuration's `appId` |
| `selectedRuntimeEnvironmentName` | function | Which runtime environment this deployment selected, read before any configuration exists: command line, then `.env`, then the OS environment |
| `isDevelopmentOrTestRuntime` | function | Whether the current runtime environment is development or test; a boot that declared none is neither |
| `TomSecrets` | abstract final class | The registered secrets providers and the secrets resolved through them: `load` before the configuration is built, `substitute` in the merge, `refresh` / `watch` / `startRefresh` for rotation |
| `TomSecretsProvider` | abstract class | A secret store, registered under the name references use |
| `TomMapSecretsProvider` | class | A provider answering from a map — tests and local development |
| `TomSecretReference` | class | A parsed `secret:<provider>:<path>[#<field>]` reference |
| `TomSecretPayload` | class | What a provider read for one path, and the field a reference picks from it |
| `TomSecretSubscription` | class | A watcher's registration, ended by `cancel` |
| `TomSecretsRefresh` | class | What one refresh found: the references that changed and the ones that failed |
| `TomSecretsException` | class | A secret that could not be read or resolved, keyed `secrets.*` (extends `TomServerException`) |

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

The fallback is what lets a setting be written flat. These two files are
equivalent, and `server.port` reads `8080` from either:

```yaml
server:          # nested
  port: 8080
```

```yaml
server.port: 8080   # flat
```

They are only equivalent while just one of them is present. The path is tried
first, so where a file carries **both**, the nested value answers and the flat
key becomes unreachable — not merged, not reported, simply never consulted.
Adding a `server:` block to a file that already had a flat `server.port` is
therefore a silent way to lose the flat one. Pick one spelling per key.

**A key set explicitly to `null` exists.** Writing a key with no value is how a
deployment *clears* a setting, and that is a different statement from not
mentioning the key at all:

```dart
final cfg = TomServerConfigResourceProvider.from({'smtpHost': null});
cfg.exists('smtpHost');  // true  — configured, and configured as nothing
cfg.get('smtpHost');     // null
cfg.exists('smsHost');   // false — never mentioned
cfg.get('smsHost');      // 'smsHost' — the key-string fallback above
```

`null` and the key-string fallback are therefore the two distinguishable
answers `get` gives for "no value": `null` means *cleared*, the key string
means *unknown*. Gate on `exists` rather than testing `get(...) == null`.

**That is the contract, and the gate is the caller's half of it.** `get` is
total: it never throws and never answers `null` for a key the tree does not
hold, so it cannot by itself report a key nobody configured. Both halves of
that are deliberate. Answering `null` for an unknown key would collapse it with
a cleared one and cost the module the distinction `exists` was built to
preserve. Throwing would cost the other half — a read that cannot fail is what
lets a caller walk a tree of optional settings without a `try` at every step.

The price is that the fallback is indistinguishable from a configured value
that happens to equal its own key, which is why the gate is `exists` and not a
test on the value:

```dart
final cfg = TomServerConfigResourceProvider.from({'host': 'host'});
cfg.exists('host');  // true  — configured, and configured as 'host'
cfg.get('host');     // 'host'
cfg.exists('port');  // false — never mentioned
cfg.get('port');     // 'port' — the same shape of answer, the opposite meaning
```

Forgetting the gate costs what this API cannot take back: a missing `host`
reads as the host name `host`, and the failure surfaces at connect time rather
than at lookup. Every read inside `tom_core_server` is gated, and a test fails
on one that is not — it reads the provider locals off the source rather than
from a list, so a new call site is covered whatever it names its variable.

Alternatively, supply a lazy `loader` (used when the default provider is created
on first `getServerConfig`) or construct with `.load(loader)`.

## Typed Property Access

`TomConfig<T>` reads its value **once at construction** from the active provider
and caches it. Resolution order:

1. provider has the key → cast its value to `T` (a bad cast throws a
   [`TomConfigurationException`](#what-a-failed-resolution-throws));
2. else a default was supplied → use it;
3. else the property is obligatory → construction throws the same type under
   `configuration.tom_config.property_not_configured`.

```dart
final port = TomIntConfig.withDefault('server.port', 8080).get(); // 8080
final host = TomStringConfig('server.host').get();                // obligatory

// The ~ operator is shorthand for .get():
final beta = ~TomBoolConfig.withDefault('featureFlags.beta', false);
```

**A whole number is a `double` when a `double` was asked for.** Step 1 widens an
`int` to a `double` when `T` is `double` or `double?`, so `rate: 2` and
`rate: 2.0` mean the same thing:

```dart
// config/server.yaml → rate: 2
final rate = TomDoubleConfig('rate').get();   // 2.0, not a throw
```

A configuration file cannot say "double" — both YAML `rate: 2` and JSON
`"rate": 2` decode to an `int` — and the reflected path that fills a
configuration object's *fields* widens the same way (see *Command-Line
Arguments* in [cmdline.md](cmdline.md)). Without this, one file could fill a
declared `double` field and fail the matching `TomDoubleConfig` lookup.

The converse does **not** hold: `2.5` is still refused for an `int`. Narrowing
would need a rounding policy, and truncating silently discards what the operator
wrote.

### A cleared key takes step 1, not step 2

A default covers an **absent** key. A key the operator explicitly set to `null`
is *present*, so it takes step 1 and the default never applies — substituting
it would discard exactly the setting they wrote:

```dart
// config/server.yaml → smtpHost:      (written, with no value)

TomConfig<String?>.withDefault('smtpHost', 'mail.example.com').get();
// → null, not 'mail.example.com'
```

Whether that is a value or an error depends only on `T`:

| `T` | A key explicitly set to `null` |
| --- | ------------------------------ |
| nullable (`String?`) | resolves to `null` — the setting is cleared |
| non-nullable (`String`) | throws, naming the key, the type and the value |

The throw is the intended answer for the non-nullable case: the operator asked
for nothing where the code requires something, and that is a misconfiguration
worth failing at startup rather than at first use. Declare the property nullable
when clearing it is a legitimate deployment choice — which is why every
optional deployment setting in *Deployment Settings* below is typed `String?`.

This is the same distinction the provider draws in *The Resource Provider*
above, carried one layer up: `exists` reports a cleared key as configured
precisely so `TomConfig` cannot silently fall through to a default.

### What a failed resolution throws

Every way resolution can fail raises a `TomConfigurationException` — a
`TomServerException`, so it is a real `Exception` and carries the isolate name
and the request UUID like every other server error. **One type, three
conditions, told apart by `key`:**

| `key` | Condition |
| ----- | --------- |
| `configuration.tom_config.property_not_configured` | The key is absent and the property declared no default. |
| `configuration.tom_config.property_type_mismatch` | The key holds a value that cannot be cast to `T`. |
| `configuration.tom_config.no_provider_installed` | The property was declared before any provider existed. |

So a startup handler writes one clause and still discriminates:

```dart
try {
  final host = TomStringConfig('server.host');
} on TomConfigurationException catch (e) {
  stderr.writeln('${e.key}: ${e.parameters?['key']}');
}
```

All three are raised during **construction**, so catching one means wrapping the
declaration rather than the read. `parameters` holds the property `key` and the
`type` it was wanted as — and, for a mismatch, the offending `value` — so a
handler reports them without parsing the message.

**None of them is sent to a client.** `clientThrow` is `false` for this type: a
configuration message names an internal key, and the mismatch names the value as
well, which for `smtpPassword` or `jwtSharedSecretKey` is the secret itself. The
endpoints pipeline masks it behind a generic response.

The same shape is used on the client side by `tom_core_flutter`'s `TomProperty`
(`resources.property.not_configured` / `resources.property.type_mismatch`), so
an operator who has met one recognises the other.

#### The chained cause of a bad cast

The `TypeError` the cast raised is chained as `rootException`, with its stack
trace in `stack`. That matters more than it looks. The message alone —

```text
Could not set property of type List<String> from value of property hosts
with value [a, b]
```

— names a value the operator wrote and that looks perfectly valid. A YAML
`hosts: [a, b]` decodes as `List<dynamic>`, so the cast fails on the *element*
type, and only the chained cause says so:

```dart
try {
  TomConfig<List<String>>('hosts');
} on TomConfigurationException catch (e) {
  print(e.rootException);
  // type 'List<dynamic>' is not a subtype of type 'List<String>' in type cast
}
```

So read `rootException` before concluding the file is right and the code is
wrong. The same applies to any generic type — `Map<String, String>` over a
decoded `Map<String, dynamic>` fails the identical way.

Because the value is captured at construction, build a `TomConfig` *after* the
provider is installed; later provider changes are not observed by an existing
instance.

**Building one before any provider exists is refused**, rather than answered
from the empty placeholder `getServerConfig` would otherwise create:

```text
TomConfigurationException: configuration.tom_config.no_provider_installed
Property 'server.port' was resolved before a configuration provider was
installed. A TomConfig reads its value once, at construction, so it must be
built after TomServerConfigResourceProvider.setServerConfigProvider (or after a
TomBaseServerConfiguration, which installs one) — not as a static or a field
initialiser, which run at class-load time.
```

That is the ordering mistake the eager read exposes, and it is worth its own
answer because the three things it used to do all hid it: a defaulted property
quietly took its default, an obligatory one threw naming the *key* as though the
operator had forgotten it, and neither said that the configuration did not exist
yet. The exposure is highest exactly where `TomConfig` is most natural to write
— a static or a field initialiser, which resolves when its library is first
touched, before `main` has run.

Only the provider **nobody asked for** is refused. One installed explicitly is
never a placeholder however empty it is — an empty tree installed on purpose is
a statement, and a defaulted property takes its default against it — and neither
is one the static `loader` hook built, which is the documented lazy path.

The provider is the *only* source read. An environment variable or a
command-line argument is not one of the three steps above — it reaches the
configuration object's fields instead. See *Source Precedence* below for the one
line that makes it reachable here too.

## The Server Configuration Base

A server subclasses `TomBaseServerConfiguration` and declares typed fields
(`port`, `host`, `noSsl`, `certificateChain`, `privateKey`, `isolateCount`,
handler/middleware hooks, logging levels, and the three deployment blocks in
*Deployment Settings* below). The class is `@tomReflector`, and its constructor
fills those fields from the merged configuration through `setValues`, which a
subclass implements in one line by handing the merged map to the generated
reflection:

```dart
@tomReflector
class MyServerConfig extends TomBaseServerConfiguration {
  MyServerConfig(super.args);

  @override
  void setValues(Map<String, Object?> values) =>
      tomReflectionInfo.setValues<MyServerConfig>(this, values);
}

void main(List<String> argv) {
  final config = MyServerConfig(argv); // reads env, .env, and argv
  TomServer(config).start();
}
```

One field on the base is **derived rather than configured**: `args` holds the
command line the configuration was built from. The constructor assigns it after
`setValues`, so a configuration key that happens to be spelled `args` is merged
like any other but does not land in the field — the invocation is what the field
promises, and the invocation is what survives. Treat it as sensitive: the
command line is one of the channels a deployment uses to supply a secret, so log
individual fields rather than this list.

> The default `certificateChain` / `privateKey` are a throwaway self-signed
> `localhost` pair for local development and **must be overridden in
> production**; a boot that serves TLS with either half still at its default
> [says so in the log](#the-development-tls-pair-announces-itself). The JWT
> fields are the server's token signing configuration — algorithm, key files,
> issuer, audience and the payload-encryption pair — read by `installJwtSigning`
> (see [JWT Signing Keys](#jwt-signing-keys)); all of them default to `null`,
> and key material left unset falls back to the framework's bundled sample key,
> which is permitted in a development or test environment and refused anywhere
> else. A token's expiry is supplied in code, by the code that mints it.

### Unknown keys in the configuration resources

A key the configuration resources hold that names no field is reported at
startup, in one warning that lists every such key:

```text
WARN  The configuration resources name 2 keys no field of BillingConfiguration
declares: prot, app. They are not bound to the configuration; check the
spelling of any that was meant as a setting.
```

**Only that layer is checked.** The merged tree carries the whole process
environment by construction — every `PATH`, `HOME`, `SHELL` and `LANG` is a key
that names no field — so a check over it would bury a mistyped setting among
dozens of lines and refuse nothing useful. The resources are the deployment's
own file, so a key there that matches no field is either a typo or a value some
other code reads, and both are worth one line. The environment, `.env` and
command-line layers keep their tolerance.

**It warns rather than refuses.** The resources are read by more than this
class: the samples keep `app.title` there for an endpoint to return, and a
refusal would make the configuration the arbiter of a file it only partly owns.
`settingWarnings(values, configurationFile)` is the check on its own, public for
a configuration composed some other way, and returns the warnings rather than
logging them.

### The development TLS pair announces itself

`certificateChain` and `privateKey` default to a complete self-signed
`localhost` certificate and its RSA key, both committed to this repository. They
stay: a development machine has to be able to speak HTTPS without a certificate
authority. What has changed is that a boot serving them is no longer silent —
`TomServer.start` warns before it builds the `SecurityContext`:

```text
WARN  TLS is enabled and the certificate chain and the private key is still the
development pair committed to tom_core_server. Its private key is published, so
this server authenticates itself with a key anyone can read. Set
certificateChain and privateKey for any deployment that is not a local
development machine.
```

**Either half triggers it**, and the message names which. A default
`privateKey` is the danger — the key is public. A default `certificateChain`
beside an overridden key is a different fault with the same remedy: the pair
does not match, so the socket fails to bind, and hearing that before the bind is
cheaper than reading the error afterwards.

A plaintext server (`noSsl`) is silent, because nothing is served over TLS and a
warning that does not apply is the kind that teaches an operator to ignore the
ones that do.

**Nothing refuses to start.** A refusal would cost every local run that serves
TLS an extra opt-in setting, and a deployment that reads its logs has been told.
`TomBaseServerConfiguration.usesDevelopmentTlsMaterial` is the condition on its
own, for a deployment that would rather refuse than warn:

```dart
if (configuration.usesDevelopmentTlsMaterial) {
  throw StateError('refusing to start with the development certificate');
}
```

### Requiring a setting

Mark a field `@TomRequiredField()` and the constructor refuses to build a
configuration no source supplied it for:

```dart
@tomReflector
class BillingConfiguration extends TomBaseServerConfiguration {
  @TomRequiredField()
  String dbUrl = '';

  BillingConfiguration(super.args);

  @override
  void setValues(Map<String, Object?> values) =>
      tomReflectionInfo.setValues<BillingConfiguration>(this, values);
}
```

```text
TomConfigurationException: configuration.base_configuration.required_settings_missing
No source supplied the required setting dbUrl for BillingConfiguration. A
resource file, the environment, a .env file or a command-line argument must
name it.
```

The merged map is the only place the question can be asked: the answer is "did
*any* source name this setting", and no single source knows. Binding cannot
report it either — a setting nobody supplied leaves the field at its
initialiser, which reads exactly like a setting nobody required, so the failure
otherwise surfaces much later as a connection to `localhost:0` or an empty
application id.

Every missing setting is named at once, in declaration order, so a deployment
fixes them in one pass rather than one restart at a time. The refusal happens
before the instance registers itself as the isolate's active configuration: one
that will not start must not become the one `tomAppId` resolves through on its
way out.

**A field with a fallback is not required.** `port` and `appId` on the base
carry none of these, deliberately: every field there has a documented default,
and a field whose constructor supplies one would be refused for the very launch
the default exists to serve.

| The sources hold | Verdict |
| ---------------- | ------- |
| no key at all | **refused** — no source named it |
| the key, with `null` (a `.env` line `DB_URL=`) | **refused** — named, given nothing |
| the key, with `''` (`dbUrl=` on the command line) | accepted — set to nothing deliberately |

A configuration whose `setValues` assigns its fields by hand rather than through
the reflection is **not** checked: the annotation is read through the mirrors,
so such a class has none to read. A server whose `setValues` goes through the
reflection is reflected by construction, so the check is in force wherever the framework binds the fields.
`assertRequiredSettings` is public, so a configuration composed some other way
can ask the same question of its own map.

### Recommending a setting

Mark a field `@TomRecommendedField()` for a setting a deployment should supply
but can run without. No source naming it is not a refusal but a warning,
logged once at startup for every such field together:

```dart
@tomReflector
class BillingConfiguration extends TomBaseServerConfiguration {
  @TomRequiredField()
  String dbUrl = '';

  @TomRecommendedField()
  String supportEmail = '';

  BillingConfiguration(super.args);

  @override
  void setValues(Map<String, Object?> values) =>
      tomReflectionInfo.setValues<BillingConfiguration>(this, values);
}
```

```text
WARN  No source supplied the recommended setting supportEmail for
BillingConfiguration; its default is in use.
```

The rules are the required check's: any source counts, a `null` value is not
supplied and an empty one is. The three verdicts read together — a required
setting refuses, a recommended one warns, an unmarked one is silent — are the
whole convention, and they are stated on the field they govern.

### Naming the application

`appId` is the server's own name — what it calls itself wherever several servers
of one deployment meet. It is an ordinary configuration key, so the merge can
supply it (`appId` in a resource file, in the environment, in `.env`, or
`appId=…` on the command line). A server with a fixed name states it in the
constructor body instead.

Whichever way it is set, `tomAppId` reports it process-wide, and
`tomLoggingMiddleware` prefixes each access line with it. There is nothing to
publish by hand: `tomAppId` is a getter over the configuration this isolate
built, not a variable to assign.

To have both a default and an override, guard the assignment the way `port` is
guarded:

```dart
MyServerConfig(super.args) {
  if (appId.isEmpty) appId = 'billing';
}
```

The guard is what makes it a *default*. A constructor body runs after the base
has applied the merged values, so an unconditional `appId = 'billing';` discards
whatever the environment or the command line supplied.

### Switching protection off from the command line

The base constructor also hands its arguments to the kernel's
`TomResourceKeyProtection.applyArguments`, before anything else, so the
authorization system's switches can be set on any server's command line:

```bash
dart run bin/server.dart tom.protection=false          # everything off
dart run bin/server.dart tom.protection.json=false     # one tier off
dart run -Dtom.protection.database=false bin/server.dart  # the same as a define
```

The settings are `tom.protection` (all at once), `tom.protection.resourceKeys`
(whether resource-key grants are enforced — off by default), and
`tom.protection.endpoint`, `.json`, `.database` and `.ui` for the four automatic
tiers, which are on by default. A specific setting beats `tom.protection`. A
misspelt setting or a value other than `true`/`false` throws
`TomProtectionSettingException` and the server does not start: a tier believed
off while it is on, or the reverse, is worse than a failed start. The kernel's
security guide describes what each switch governs.

Resource-key enforcement stays off by default on purpose: switching it on
refuses every endpoint that declares no access and blanks every protected value
nobody holds a grant for, which an application without configured grants cannot
survive. A production deployment is expected to switch it on once its grants
exist — `tom.protection.resourceKeys=true` — and a server that boots with it off
outside a development or test environment says so in a warning
(`TomServer.warnOnUnenforcedResourceKeys`), without refusing to start.

## Deployment Settings

Four blocks of the configuration base exist for the deployment rather than for
the code: they say what the server signs tokens with, who it logs in as, how it
sends mail, and how it sends SMS. They are grouped here because their reader is
an operator filling in an environment rather than a developer calling an API —
and an operator cannot look up a setting they were never told exists.

**Three of the four have one switch.** Leave it unset and the block is
*disabled*, not misconfigured — the server starts, and the messaging module
registers a no-op transport. That is the wanted behaviour for a test run, a local
build and a CI job, all of which should compose messages and deliver none. The
opposite case, a block that is set but unusable, throws when the settings are
built, because someone meant to send.

| Block | Switch | Unset means |
| ----- | ------ | ----------- |
| Server self-login | `authServerLoginUri` + `serviceAccountName` | The server never logs itself in and runs uncapped |
| Outbound mail | `smtpHost` | This deployment sends no mail |
| Outbound SMS | `smsEndpoint` | This deployment sends no SMS |

**The JWT block is the exception, and it is the dangerous one.** There is nothing
to disable: a server that issues or accepts tokens signs and verifies whatever
its configuration left it holding. Unset, that is the sample key material bundled
in `tom_crypto` — published in its sources, and therefore no secret at all. So the
block does not fail open the way the other three do. `installJwtSigning` refuses
to start a server on the bundled keys outside a development or test environment,
and warns loudly inside one. See
[authentication.md](authentication.md#the-signing-keys).

**Six settings are secret-bearing** — `jwtRsaPrivKey`, `jwtSharedSecretKey`,
`serviceAccountCredential`, `smtpPassword`, `smsApiKey` and `smsApiSecret` —
under the same rule as `privateKey`. Their *declaration* belongs in the class, so
the shape and the source key are known; their **value is never authored**. It is
supplied out of band at deploy time through the precedence chain below — the OS
environment, `.env`, or the command line — and must never be written into a spec
or a checked-in configuration tree.

`jwtSigningKeyFile` is secret-bearing one step removed: its value is a path,
which may be authored, and the file it names holds the private signing key,
which never is.

**External identity providers are configured in the tree, not on the base.**
`oauth.providers` (OAuth 2.0 / OpenID Connect, with `discovery: true` reading a
provider's endpoints from its issuer), `oauth.stateStore` and `saml.providers`
(SAML 2.0, with `metadataUrl` reading the identity provider's side) are nested
maps read through `TomServerConfigResourceProvider` by the authentication module,
one entry per provider. A provider's `clientSecret` is secret-bearing and is
written as a `${...}` placeholder resolved from the environment; a SAML
provider's `spSigningKeyFile` is secret-bearing one step removed, like
`jwtSigningKeyFile`. The keys are documented in
[authentication.md](authentication.md#provider-configuration-is-data) and its
[single sign-on part](authentication.md#single-sign-on-with-enterprise-identity-providers).

**SCIM provisioning is configured in the tree too.** `scim.bearerTokens` (a list,
or one string — one secret per identity provider, and two during a rotation) and
the optional `scim.baseUrl` are read by `TomScimProvisioning.fromConfiguration`.
Every bearer token is secret-bearing and written as a `${...}` placeholder. See
[authentication.md](authentication.md#enabling-scim).

**Rate limits are configured in the tree.** `rateLimits` — `limiter` (`memory`
or `sql`), `datasource`, `trustedProxies` and the `rules` list (`name`, `per`,
`limit`, `windowSeconds`, `paths`, `anonymousOnly`) — is read by
`TomRateLimits.fromConfiguration`, which `TomServer.start` calls when no limits
were installed in code. Without the key nothing is limited. See
[ratelimit.md](ratelimit.md#configuration).

### JWT Signing Keys

What the server signs an issued token with, what it verifies an incoming one
against, and which issuer and audience both must name. `installJwtSigning`
reads these fields at boot; see
[authentication.md](authentication.md#the-signing-keys) for the algorithms, the
key ids, the published JSON Web Key Set and the rotation procedure.

An auth server that issues and an application server that accepts are
configured as a pair: under RS256 or ES256 the application server lists the
auth server's public key in `jwtVerificationKeyFiles` and holds no signing key;
under HS256 both hold the same `jwtSharedSecretKey`. In both cases they name the
same `jwtIssuer` and `jwtAudience`.

All of them default to `null`, meaning *not configured* — the framework ships no
key of its own, because a key everyone can read is not a key. Key material left
unset falls back to the sample material in `tom_crypto`, which
`installJwtSigning` permits only in a development or test environment and
refuses elsewhere with `TomSigningKeyException`. ES256 has no sample key, so an
unconfigured ES256 server is refused everywhere.

| Setting | Environment name | Type | What it decides |
| ------- | ---------------- | ---- | --------------- |
| `jwtRsaPubKey` | `JWT_RSA_PUB_KEY` | `String?` | PEM of the RSA public key that encrypts the access-control payload carried inside a token, under every algorithm. Deployment-specific but not secret. |
| `jwtRsaPrivKey` | `JWT_RSA_PRIV_KEY` | `String?` | PEM of its private counterpart, which decrypts that payload. Held by the issuer and every server reading its tokens. **Secret-bearing** — supplied out of band, never authored. |
| `jwtSharedSecretKey` | `JWT_SHARED_SECRET_KEY` | `String?` | Passphrase of the HMAC key that signs and verifies tokens under `HS256`, and read under no other algorithm. **Secret-bearing** — whoever holds it can mint a token this deployment accepts. |
| `jwtAlgorithm` | `JWT_ALGORITHM` | `String?` | The signing algorithm: `RS256` when unset, `ES256` or `HS256`. Anything else is refused with `jwt.keys.unknown_algorithm`. |
| `jwtSigningKeyFile` | `JWT_SIGNING_KEY_FILE` | `String?` | Path of the PEM file (PKCS#8) holding the private key RS256 or ES256 tokens are signed with. The file is **secret-bearing**; the path is not. A verify-only server leaves it unset. |
| `jwtVerificationKeyFiles` | `JWT_VERIFICATION_KEY_FILES` | `String?` | Comma-separated paths of PEM files (SPKI) holding public keys that still verify tokens: on the issuing server, the keys it rotated away from; on a verify-only server, the issuer's current and retired keys. |
| `jwtIssuer` | `JWT_ISSUER` | `String?` | The `iss` every issued token carries and every verified token must carry; `tom` when unset. |
| `jwtAudience` | `JWT_AUDIENCE` | `String?` | The `aud` every issued token carries and every verified token must carry; unset issues and requires none. |

A `.env` file is read a line at a time, so a PEM supplied through one goes on a
single line with its newlines written as spaces; the parser strips spaces and
newlines alike before decoding, so the value is the same key either way. The
signing and verification keys are read from files instead, and need no such
care.

See `authentication/jwt_signing.dart` and `authentication/jwt_keys.dart`.

### Server Self-Login

A deployed server is itself a principal. It logs in against the auth server with
a service credential, and the token it gets back carries *this deployment's*
feature grants, which cap every user's grants (the `min(user, server)` meet in
`TomAccessControl`). These seven settings say who the deployment is and where it
presents that identity. All default to `null`; a deployment that leaves them
unset runs uncapped, exactly as every server built before self-login existed.

| Setting | Type | What it decides |
| ------- | ---- | --------------- |
| `authServerLoginUri` | `String?` | Absolute URI of the auth server's login endpoint, e.g. `https://auth.example.com/auth/login`. Deployment-specific but not secret. Blank disables self-login. |
| `serviceAccountName` | `String?` | The login name of this deployment's service account. Blank disables self-login. |
| `serviceAccountCredential` | `String?` | The service account's secret. **Secret-bearing** — supplied out of band, never authored. |
| `serviceAccountOrganization` | `String?` | Organization presented with the deployment's own login; `null` for a single-tenant deployment. |
| `serviceAccountApplication` | `String?` | Application the deployment logs into; `null` when the auth server does not scope service logins by application. |
| `serviceAccountProcess` | `String?` | Process within the application; `null` when unscoped. |
| `serviceAccountClient` | `String?` | Client identifier the login originates from; `null` when unscoped. |

See `authentication/server_self_login.dart`.

### Outbound Mail (SMTP)

The declarations behind `TomSmtpSettings.fromConfiguration`. Nine settings, all
optional.

| Setting | Type | Default | What it decides |
| ------- | ---- | ------- | --------------- |
| `smtpHost` | `String?` | `null` | The mail server's host name. Blank means this deployment sends no mail. |
| `smtpPort` | `int` | `0` | The mail server's port. `0` is the unconfigured sentinel, letting the transport pick the default that goes with `smtpSecurity` (25, 587 or 465). |
| `smtpSecurity` | `String` | `startTls` | How the connection is secured: `none`, `startTls` or `implicitTls`. An unrecognised value falls back to `startTls` — failing *closed* is the only acceptable direction for a setting that decides whether a password crosses the network in the clear. |
| `smtpUsername` | `String?` | `null` | The login name presented to the mail server. Blank for an unauthenticated relay. |
| `smtpPassword` | `String?` | `null` | The mail server password. **Secret-bearing.** Supplying `smtpUsername` without it is rejected when the settings are built, so the omission surfaces at startup naming the setting rather than as a `535` on the first notification. |
| `smtpFromAddress` | `String?` | `null` | The address mail is sent from when a message does not name its own. Effectively mandatory for a deployment that actually sends: most relays require an envelope sender they are authorised for. |
| `smtpFromName` | `String?` | `null` | The display name shown beside `smtpFromAddress`; `null` sends the bare address. |
| `smtpClientName` | `String` | `localhost` | The name announced in `EHLO`. Some relays check that it resolves. |
| `smtpAllowInsecureCertificate` | `bool` | `false` | Whether to accept a mail server certificate that does not validate. It should stay `false` in any deployment. It exists because self-signed certificates are common on internal relays, and a developer who cannot turn this on will set `smtpSecurity` to `none` instead — which is strictly worse, since that sends `smtpPassword` in the clear. |

See `messaging/smtp_transport.dart` and `doc/messaging.md`.

### Outbound SMS (HTTP Gateway)

The declarations behind `TomSmsGatewaySettings.fromConfiguration`. Unlike SMTP
there is no protocol here — every gateway is an HTTP API of its own invention —
so these seven settings carry only what all of them need: where, with which
credential, as whom. A particular vendor's field names, body format and error
codes live in a `TomSmsGatewayProtocol`, which is code the deployment supplies
rather than configuration.

| Setting | Type | Default | What it decides |
| ------- | ---- | ------- | --------------- |
| `smsEndpoint` | `String?` | `null` | The gateway's submit URL. Blank means this deployment sends no SMS. Must be `http` or `https`; anything else is rejected when the settings are built, so a typo surfaces at startup rather than as an unroutable request at 03:00. |
| `smsApiKey` | `String?` | `null` | The gateway credential. **Secret-bearing.** |
| `smsApiSecret` | `String?` | `null` | The second half of a two-part credential. **Secret-bearing.** Required only by `smsAuthScheme` `basic`, where `smsApiKey` is the user and this is the password. |
| `smsSenderId` | `String?` | `null` | The sender shown to the recipient — a short code, a long number, or an alphanumeric sender id where the destination country permits one. A message may override it through its metadata. |
| `smsAuthScheme` | `String` | `bearer` | How the credential is presented: `none`, `bearer` or `basic`. An unrecognised value falls back to `bearer`; unlike `smtpSecurity`'s fallback the worst outcome is a `401`, not a credential in the clear. Gateways that want the key *in the payload* use `none` and name the field on the protocol. |
| `smsTimeoutSeconds` | `int` | `30` | How long to wait for the gateway before treating the attempt as deferred. A timeout is transient — the message may well have been accepted — so the honest answer is to retry and let the message id deduplicate. |
| `smsMaxSegments` | `int` | `3` | The most segments one message may occupy, or `0` for no cap. Segmentation is invisible at composition time: one extra sentence, or a parameter with an umlaut in it, can quietly triple the cost of every message. Over the cap fails *permanently* — a message too long now is too long on the retry. |

See `messaging/sms_transport.dart` and `doc/messaging.md`.

The remaining fields — the server, TLS, JWT, handler and logging settings — are
listed with their types and defaults in
`doc/api/api_summary_configuration.md`.

## Publishing the OpenAPI Document

One setting decides whether the server publishes its OpenAPI document at
`GET /openapi.json`. The document is not generated here: `tom_core_openapi`
writes it at build time from the endpoint annotations, and the server serves the
file it is pointed at.

| Setting | Type | Default | What it decides |
| ------- | ---- | ------- | --------------- |
| `openApiDocument` | `String` | `""` | The generated document to serve. Empty publishes none, and `GET /openapi.json` answers `404` with `openapi.document.not_served`. A path that names no file answers `404` with `openapi.document.missing` and logs a warning. Relative to the working directory unless absolute, like `databaseMigrationsDirectory`. Environment name `OPEN_API_DOCUMENT`. |

`TomServer.start` copies the value into
`TomOpenApiServer.globalSettingDocumentPath` before it builds the router. The
route itself is described in [endpoints.md](endpoints.md#the-openapi-document).

```yaml
# assets/config-resources_default.yaml
openApiDocument: "openapi/openapi.json"
```

## Publishing Metrics

Six settings decide how the series the framework records leave the process: a
Prometheus scrape, an OTLP push, both or neither. The series are recorded
either way; both exports are off by default.

| Setting | Type | Default | What it decides |
| ------- | ---- | ------- | --------------- |
| `metricsEndpoint` | `bool` | `false` | Whether `TomServer.start` answers Prometheus scrapes at `metricsPath`, ahead of authentication. Environment name `METRICS_ENDPOINT`. |
| `metricsPath` | `String` | `/metrics` | The path scrapes are answered at. Environment name `METRICS_PATH`. |
| `metricsToken` | `String` | `""` | The bearer token a scrape must present; empty leaves the endpoint open, which is right only where nothing but the scraper reaches the port. **Secret-bearing.** Environment name `METRICS_TOKEN`. |
| `otlpEndpoint` | `String` | `""` | The OTLP/HTTP receiver's base URL (`http://collector:4318`); `/v1/metrics` is appended. Empty pushes nothing. Environment name `OTLP_ENDPOINT`. |
| `otlpHeaders` | `String` | `""` | Headers sent with every push, as `key=value,key=value` with percent-encoded values — the form of `OTEL_EXPORTER_OTLP_HEADERS`. An entry without `=` stops the start with `otlp.config.invalid_headers`. Secret-bearing when it carries a credential. Environment name `OTLP_HEADERS`. |
| `otlpMetricsIntervalSeconds` | `int` | `60` | How often metrics are pushed. Environment name `OTLP_METRICS_INTERVAL_SECONDS`. |

```yaml
# assets/config-resources_default.yaml
metricsEndpoint: true
metricsToken: "${METRICS_TOKEN}"
otlpEndpoint: "http://otel-collector:4318"
```

The series, the scrape endpoint and the export are described in
[metrics.md](metrics.md); where the scrape sits in the pipeline, in
[server.md](server.md#the-pipeline).

## Log Format and Readiness

Two settings decide what the server tells an operator's tooling about itself
without being asked in code: the shape of its log lines, and whether `GET /ready`
answers with the framework's own checks.

| Setting | Type | Default | What it decides |
| ------- | ---- | ------- | --------------- |
| `logFormat` | `String` | `text` | `text` writes one human-readable line per entry; `json` one JSON object per line carrying `trace_id`, `span_id`, `request_id` and `tenant`, for a log collector to index. `TomServer.start` applies it when the output is still the default console output, so an application that installed its own keeps it. An unrecognised value is logged as an error and changes nothing. Environment name `LOG_FORMAT`. |
| `frameworkReadiness` | `bool` | `true` | Whether `TomServer.start` answers `GET /ready` with `TomFrameworkReadinessAnalyzer` — every data source answering, no migration running or failed, every started outbox delivering — when the application installed no readiness analyzer of its own. Environment name `FRAMEWORK_READINESS`. |

```yaml
# assets/config-resources_default.yaml
logFormat: json
```

The JSON line and the correlation ids it carries are described in
[server.md](server.md#correlation-ids-and-structured-logs); the readiness checks,
their body and how to compose them into an application's own analyzer, in
[healthcheck.md](healthcheck.md#the-framework-readiness-checks).

## Graceful Shutdown

Three settings decide how the server stops on SIGTERM or SIGINT: how long the
work in flight gets to finish, how long requests are still taken after readiness
turned to `503`, and whether the process exits afterwards. `TomServer` reads
them when it builds `TomServer.gracefulShutdown`, and `start()` applies the
exit setting when it registers the shutdown for the signals.

| Setting | Type | Default | What it decides |
| ------- | ---- | ------- | --------------- |
| `shutdownGracePeriodSeconds` | `int` | `20` | How long a graceful shutdown waits for the requests already accepted and the scheduled work already running — the outbox included — before it closes what is left. Keep it below the orchestrator's own grace period (Kubernetes' `terminationGracePeriodSeconds`, 30 by default) less `shutdownReadinessDelaySeconds`: after that the process is killed whatever it is doing, and the leases and pools are never handed back. Environment name `SHUTDOWN_GRACE_PERIOD_SECONDS`. |
| `shutdownReadinessDelaySeconds` | `int` | `0` | How long requests are still accepted after `GET /ready` turned to `503`, so a load balancer that has not yet noticed sends nothing into a closed socket. Zero suits a server reached directly; behind a Kubernetes Service set it to the readiness probe's period plus its timeout. Environment name `SHUTDOWN_READINESS_DELAY_SECONDS`. |
| `exitOnShutdownSignal` | `bool` | `true` | Whether a SIGTERM or SIGINT ends the process — exit code `0` — once the graceful shutdown and every shutdown-cleanup phase after it have run. An orchestrator waits for the process to exit, and one that lingers is killed at the end of the grace period instead. A shutdown started by calling `TomServer.shutdown` never exits. Environment name `EXIT_ON_SHUTDOWN_SIGNAL`. |

```yaml
# assets/config-resources_default.yaml
shutdownGracePeriodSeconds: 20
shutdownReadinessDelaySeconds: 15
```

The shutdown's steps, what it waits for and how the three settings fit a
Kubernetes pod's `terminationGracePeriodSeconds` and probes are described in
[server.md](server.md#graceful-shutdown).

## Outgoing HTTP Calls

Every HTTP call the framework makes to another service — an identity
provider, an object store, an OTLP receiver, a webhook, an SMS or push gateway,
the auth server's login, a secret store — goes through the kernel's
`TomResilientClient`: a timeout on every attempt, retries with backoff for a
call that may be repeated, and a circuit breaker and a bulkhead per destination.
The one exception is the APNs push exchange, which speaks HTTP/2 over a
connection of its own (see [messaging.md](messaging.md#http2)).
What each policy does, what is retried and the metrics it records are described
in the kernel's
[HTTP connection guide](../../tom_core_kernel/doc/http_connection/http_connection.md).

The `httpClient` key of the configuration resources
(`TomServer.httpClientConfigurationKey`) sets those policies for the deployment.
It is a nested map read through `TomServerConfigResourceProvider`, like
`rateLimits`, not a field of the configuration base: `TomServer.start` hands it
to `TomHttpResilience.configure` through `TomServer.configureHttpClients`.
Without the key the framework's defaults stand.

| Key | Type | Default | What it decides |
| --- | ---- | ------- | --------------- |
| `timeoutMs` | `int` | `30000` | How long one attempt of a call with a buffered body — every API call — may wait for the response's status and headers. `0` waits forever. |
| `streamedTimeoutMs` | `int` | none | The same for a call whose body is streamed (`StreamedRequest`, `MultipartRequest` — a file upload through a `TomServerChannel`). A server answers an upload only once the whole body has arrived, so this limit also caps the upload's duration; it is off unless set, and `0` switches it off again. Set it per destination to the longest upload expected. |
| `retry` | map, `true` or `false` | on | `maxAttempts` (`3`, the first attempt included), `initialBackoffMs` (`200`, doubling per retry, jittered), `maxBackoffMs` (`5000`, also the longest `Retry-After` honoured) and `retryStatuses` (`[429, 502, 503, 504]`). `false` never retries. Only a call with an idempotent method or an `Idempotency-Key` header is retried at all; the methods are not configurable. |
| `circuitBreaker` | map, or `false` | on | `failureThreshold` (`5` consecutive failed attempts open the circuit) and `openDurationMs` (`30000` before one trial call is let through). `false` switches the breaker off. |
| `bulkhead` | map, or `false` | on | `maxConcurrent` (`32` calls in flight per destination) and `maxQueued` (`64` waiting; beyond that a call is refused at once). `false` switches the limit off. |
| `destinations` | map | none | Policies of single destinations, keyed by `scheme://host[:port]` or any URL on it. Each value takes the keys above and replaces parts of the top-level policy; a destination not named here runs under the top level. |

A key a map leaves out keeps the value it had, so a destination entry names
only what differs. `true` for `circuitBreaker` or `bulkhead` keeps the policy's
own values. `retry: true`, or a `retry` map, where retries were switched off —
a destination under a top-level `retry: false` — starts again from the
framework's retry policy, three attempts.

```yaml
# assets/config-resources_default.yaml
httpClient:
  timeoutMs: 10000
  streamedTimeoutMs: 600000
  retry: {maxAttempts: 3, initialBackoffMs: 200, maxBackoffMs: 5000}
  circuitBreaker: {failureThreshold: 5, openDurationMs: 30000}
  bulkhead: {maxConcurrent: 32, maxQueued: 64}
  destinations:
    "https://login.microsoftonline.com": {timeoutMs: 5000}
    "https://idp.example.com": {timeoutMs: 5000, retry: false}
    "http://otel-collector:4318": {circuitBreaker: false}
    "https://files.example.com": {streamedTimeoutMs: 1800000}
    "https://s3.eu-west-1.amazonaws.com": {timeoutMs: 120000}
```

**An S3 upload is buffered, not streamed.** `TomS3BlobStore` sends every
request with its body in memory — a single `PUT` up to `partSize`, or one
multipart part — so its uploads fall under `timeoutMs`, not
`streamedTimeoutMs`: the timeout covers sending up to 8 MiB. A store reached
over a slow link gives its destination a longer `timeoutMs`, as above; see
[file_storage.md](file_storage.md#s3).

**A value of the wrong shape stops the start.** `httpClient` that is not a map,
a `destinations` entry that is not a map, a section that is neither a map nor a
boolean, or a negative or non-numeric number throws a `TomHttpResilienceException`
keyed `http.client.config.invalid` before anything is applied, so a misspelt
setting does not leave a dependency running under a policy nobody chose.

**When it applies.** `start()` applies the key first, before the deployment's
own login ([Server Self-Login](#server-self-login)) and anything else that
reaches out. Secrets are
[loaded](#boot-order-load-then-build) before the configuration exists, so a
boot that wants its secret store reached under the configured policies calls
`TomServer.configureHttpClients` with the merged sources first:

```dart
TomServer.configureHttpClients(
  TomServerConfigResourceProvider.from(
    TomBaseServerConfiguration.collectSources(args),
  ),
);
await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
```

Applying the same map again in `start()` changes nothing. Applying `httpClient`
replaces every destination policy set before it with its `destinations`, so
code that sets one with `TomHttpResilience.setDestinationPolicy` does so after
`start()`.

The policies and the circuit and bulkhead state are per isolate. `httpClient`
is not a field of the configuration base, so the startup warning about
[unknown keys](#unknown-keys-in-the-configuration-resources) names it.

## Idempotency Keys

An endpoint annotated `@TomIdempotent` stores the response to a request that
carries an `Idempotency-Key` and answers a retry with the same key from the
store (see [endpoints.md](endpoints.md#idempotency-keys)). The `idempotency` key
of the configuration resources (`TomServer.idempotencyConfigurationKey`) says
where those records are kept and how long. Like `httpClient` it is a nested map
read through `TomServerConfigResourceProvider`, not a field of the configuration
base: `TomServer.start` hands it to `TomIdempotency.configure` through
`TomServer.configureIdempotency`. Without the key the records are kept in
memory, which holds on one process only.

| Key | Type | Default | What it decides |
| --- | ---- | ------- | --------------- |
| `datasource` | `String` | none | The registered data source the records are kept in: a `TomSqlIdempotencyStore` over it replaces the in-memory store, so every instance sharing the database sees every key. Resolved by name on each request, so under tenancy a routed data source keeps each tenant's keys in the tenant's schema or database. Absent: the in-memory store. |
| `table` | `String` | `tom_idempotency_key` | The table's name. Only read with `datasource`. |
| `createSchema` | `bool` | `true` | Whether the store creates the table on first use in each data source. `false` for a database user that may not run DDL; the deployment then applies the reference migration `example/endpoints/migrations/main/tomcore/[1]-create_tom_idempotency_key.sql` (or its `migrations_postgresql` form). Only read with `datasource`. |
| `retentionMinutes` | `int` | `1440` | How long a stored response is replayed (`TomIdempotency.defaultRetention`); an endpoint's `@TomIdempotent(retention:)` overrides it. Choose it longer than clients keep retrying. |
| `inProgressTimeoutSeconds` | `int` | `300` | How long a claimed key may stay unfinished before a retry takes it over (`TomIdempotency.inProgressTimeout`), for a request whose process died. Keep it longer than the slowest idempotent request. |

```yaml
# assets/config-resources_default.yaml
idempotency:
  datasource: main
  createSchema: false
  retentionMinutes: 1440
  inProgressTimeoutSeconds: 300
```

**A value of the wrong shape stops the start.** `idempotency` that is not a map,
or a `retentionMinutes` or `inProgressTimeoutSeconds` that is not a positive
whole number, throws a `TomIdempotencyException` keyed
`endpoint.idempotency.config.invalid` before anything is applied. A data source
the name does not resolve to is reported per request, as
`endpoint.idempotency.no_datasource`.

**When it applies.** `start()` applies the key right after `httpClient`, before
the router is built. A deployment that installs a store of its own assigns
`TomIdempotency.store` after `start()`, or leaves `datasource` out. The
settings are per isolate. `idempotency` is not a field of the configuration
base, so the startup warning about
[unknown keys](#unknown-keys-in-the-configuration-resources) names it.

## Field-Level Encryption

An entity field annotated `@TomEncrypted` is stored as ciphertext under a data
key, and the data keys are kept in a table, wrapped under a key-encryption key
that never touches the database (see
[object_persistence.md](object_persistence.md#field-level-encryption)). The
`fieldEncryption` key of the configuration resources
(`TomFieldEncryption.configurationKey`) names that table and the key-encryption
keys. Like `idempotency` it is a nested map read through
`TomServerConfigResourceProvider`, not a field of the configuration base:
`TomServer.start` hands it to `TomFieldEncryption.configure` through
`TomServer.configureFieldEncryption`, which installs the keyring. Without the
key no keyring is installed, and an encrypted column fails its first write — or
its first read of a ciphertext — with `field_encryption.not_configured` rather
than storing plaintext.

| Key | Type | Default | What it decides |
| --- | ---- | ------- | --------------- |
| `datasource` | `String` | required | The registered data source the data-key table is in: a `TomSqlDataKeyStore` over it. Resolved by name on every call, so under tenancy a routed data source keeps each tenant's data keys in the tenant's schema or database. |
| `table` | `String` | `tom_encryption_key` | The table's name. |
| `createSchema` | `bool` | `true` | Whether the store creates the table on first use in each data source. `false` for a database user that may not run DDL; the deployment then applies the reference migration `example/object_persistence/migrations/main/tomcore/[1]-create_tom_encryption_key.sql` (or its `migrations_postgresql` form). |
| `keys` | list of maps | required | The key-encryption keys, **primary first**: each `{id, key}`, `id` its name (1 to 128 characters, recorded with every data key it wraps) and `key` the base64 of its 32 bytes, or a `secret:` reference to it. The primary wraps every data key created; the others only unwrap, so a rotated-out key stays listed until the data keys are re-wrapped. |
| `refreshSeconds` | `int` | `300` | How often a node reads the data keys again, which is how it learns of a rotation another node made. |
| `acceptPlaintext` | `bool` | `true` | Whether a stored value of an encrypted column that is not ciphertext reads as it is (`TomFieldEncryption.acceptPlaintext`). On while a column that held plaintext is being encrypted; off once every column is, and a plaintext value then fails its read with `field_encryption.plaintext_refused`. |

```yaml
# assets/config-resources_default.yaml
fieldEncryption:
  datasource: main
  createSchema: false
  keys:
    - id: kek-2026
      key: "secret:vault:secret/data/billing#fieldKek"
  refreshSeconds: 300
  acceptPlaintext: false
```

**A key belongs in a secret store.** The key-encryption key is what makes a
database dump useless, so it is written as a [secret
reference](#secret-references) rather than a value. `TomFieldEncryption.configure`
resolves a reference in `keys[].key` itself, through the registered providers
(`TomSecrets.resolve`), whatever path the configuration came through — the
provider holds the resources as written, and the reference works there as it
is. A reference that cannot be resolved stops the start with the
`TomSecretsException` the [load](#boot-order-load-then-build) would raise.

**Rotating a key-encryption key** is a configuration change: list the new key
first and the old one second, restart, re-wrap the data keys
(`TomFieldEncryption.keyring!.rewrap()`, in every tenant whose data keys are
kept apart), then drop the old key from the list.

**A value of the wrong shape stops the start.** `fieldEncryption` that is not a
map, a missing `datasource` or `keys`, a `table` that is not a string, a
`createSchema` or `acceptPlaintext` that is not a boolean, a `refreshSeconds`
that is not a positive whole number, or a `keys` entry without an `id` and a
`key` throws a `TomFieldEncryptionException` keyed
`field_encryption.config.invalid` before anything is installed; a key that is
not the base64 of 32 bytes throws `field_encryption.invalid_kek`. A data source
the name does not resolve to throws `field_encryption.no_datasource` when the
keyring first loads, which `start()` awaits.

**When it applies.** `start()` applies the key right after `idempotency`, before
the deployment's own login and before anything reads an entity; the data source
must be registered by then. A deployment that installs a keyring of its own
calls `TomFieldEncryption.install` and leaves the key out. The keyring is per
isolate. `fieldEncryption` is not a field of the configuration base, so the
startup warning about
[unknown keys](#unknown-keys-in-the-configuration-resources) names it.

## Privacy

The privacy module seals the values of `@TomPersonal` fields in the audit trail
under a key per data subject, so erasing the subject makes them unreadable there
(see [privacy.md](privacy.md#crypto-shredding-in-the-audit-trail)). The
`privacy` key of the configuration resources (`TomPrivacy.configurationKey`)
names the table those subject keys are kept in. It is a nested map read through
`TomServerConfigResourceProvider`, not a field of the configuration base:
`TomServer.start` hands it to `TomPrivacy.configure` through
`TomServer.configurePrivacy`, which installs the subject keys over a
`TomSqlSubjectKeyStore`. Without the key no subject keys are installed and the
trail records personal values as they are.

| Key | Type | Default | What it decides |
| --- | ---- | ------- | --------------- |
| `datasource` | `String` | required | The registered data source the subject-key table is in. Resolved by name on every call, so under tenancy a routed data source keeps each tenant's subject keys in the tenant's schema or database. |
| `table` | `String` | `tom_subject_key` | The table's name. |
| `createSchema` | `bool` | `true` | Whether the store creates the table on first use in each data source. `false` for a database user that may not run DDL; the deployment then applies the reference migration `example/privacy/migrations/main/tomcore/[1]-create_tom_subject_key.sql` (or its `migrations_postgresql` form). |

```yaml
# assets/config-resources_default.yaml
privacy:
  datasource: main
  createSchema: false
```

**The keys are wrapped under the field-encryption keys.** A subject key is
stored wrapped under the key-encryption keys of the keyring
[`fieldEncryption`](#field-level-encryption) installs, so the two keys go
together: a `privacy` section with no keyring installed stops the start with
`privacy.config.invalid`. Subject keys installed in code without key-encryption
keys fail the first seal with `privacy.no_subject_keys`, and the audit trail
being fail-closed, so does the write it audits.

**A value of the wrong shape stops the start.** `privacy` that is not a map, a
missing or empty `datasource`, a `table` that is not a string or a
`createSchema` that is not a boolean throws a `TomPrivacyException` keyed
`privacy.config.invalid` before anything is installed — as does a `privacy`
section when no `fieldEncryption` keyring is installed to wrap the subject
keys. A data source the name
does not resolve to throws `privacy.no_datasource` at the first seal.

**When it applies.** `start()` applies the key right after `fieldEncryption`,
whose keyring wraps the subject keys, and before the deployment's own login. The
subject keys are per isolate. Which entities an erasure reaches, and the
retention job, are registered in code (`TomPrivacy.register`,
`TomPrivacy.retentionJob`), not configured. `privacy` is not a field of the
configuration base, so the startup warning about
[unknown keys](#unknown-keys-in-the-configuration-resources) names it.

## Transaction Recovery

A process that dies between the two phases of a two-phase commit leaves its
branches prepared on the servers. The coordinator records its commit decision
before the commit phase, and a recovery commits the branches a recorded
decision names and rolls back the rest (see
[transactions.md](transactions.md#recovering-prepared-branches)). The
`transactions` key of the configuration resources
(`TomTransactionRecovery.configurationKey`) says where decisions are recorded
and whether the server recovers at start. It is a nested map read through
`TomServerConfigResourceProvider`, not a field of the configuration base:
`TomServer.start` hands it to `TomTransactionRecovery.configure` through
`TomServer.recoverTransactions`. Without the key no decision is recorded and
nothing is recovered.

| Key | Type | Default | What it decides |
| --- | ---- | ------- | --------------- |
| `decisionLog` | `String` | none | The registered data source decisions are recorded in, as a `TomSqlDecisionLog` installed as `TomTransactionManager.decisionLog`. A **one-phase** data source (`mariadb`, `postgresql`): a decision has to be durable on its own before the first branch commits. Without it nothing is recorded, and a recovery can only roll back. |
| `decisionTable` | `String` | `tom_transaction_decision` | The decision table's name. |
| `createSchema` | `bool` | `true` | Whether the log creates the table on first use. `false` for a database user that may not run DDL; the deployment then applies the reference migration `example/transactions/migrations/main/tomcore/[2]-create_tom_transaction_decision.sql` (or its `migrations_postgresql` form). |
| `recoverOnStart` | `bool` | `false` | Whether `start()` recovers every registered two-phase data source before the server takes a request. |
| `recoveryMinimumAgeSeconds` | `int` | `60` | How old a prepared branch has to be before a recovery resolves it (`TomTransactionRecovery.minimumAge`). Longer than any two-phase transaction stays open, plus the clock skew between nodes: a younger branch may belong to a live process between its phases. |

```yaml
# assets/config-resources_default.yaml
transactions:
  decisionLog: main
  recoverOnStart: true
  recoveryMinimumAgeSeconds: 120
```

**Every process that writes through a two-phase data source records into the
same log.** A recovery judges a branch by the decisions it can read; a decided
branch recorded elsewhere looks undecided and is rolled back.

**A value of the wrong shape stops the start.** `transactions` that is not a
map, or a `recoveryMinimumAgeSeconds` that is not a whole number of seconds or
is negative, throws a `TomTransactionRecoveryException` keyed
`transactions.recovery.config.invalid` before anything is recovered. A
`decisionLog` naming no registered data source throws
`transactions.recovery.no_datasource` where the log is first read or written:
the start's recovery, with `recoverOnStart`, which stops the start; otherwise
the first decision, and the transaction recording it rolls back.

**When it applies.** `start()` applies the key right after `privacy` and before
the deployment's own login. The start recovery scans the data sources
registered when `start()` is called, so the application registers them first.
With `recoverOnStart` every node recovers at its start; two recoveries at once
are safe — a branch both list is resolved by one and reported as failed by the
other. The decision log and the minimum age are per isolate. `transactions` is
not a field of the configuration base, so the startup warning about
[unknown keys](#unknown-keys-in-the-configuration-resources) names it.

## Source Precedence

`getDefaultValues(args)` merges sources with later ones overriding earlier —
the merge itself is `collectSources(args)`, and `getDefaultValues` is that map
with its [secret references](#secret-references) replaced by their secrets:

```text
configuration resources  ─┐
OS environment           ─┼─►  merged values  ─►  setValues(...)  ─►  the config
.env file (./.env)       ─┤    (args win over .env win over env win over resources)
command-line arguments   ─┘
```

All non-resource sources flow through the command-line conversion rules (see
`doc/cmdline.md`), so `port=8080` becomes the int `8080`, `noSsl=true` the bool
`true`, and so on.

### A `SCREAMING_SNAKE_CASE` variable names a `lowerCamelCase` field

The two environment sources — the OS environment and the `.env` file — are each
passed through `TomArgs.resolveEnvironmentNames`, which adds, for every key
written in `SCREAMING_SNAKE_CASE`, a second entry under the field name it
spells. So `JWT_SHARED_SECRET_KEY` reaches `jwtSharedSecretKey`,
`AUTH_SERVER_LOGIN_URI` reaches `authServerLoginUri`, and a deployment can use
the spelling every container platform, CI secret store and `.env` file already
uses instead of a variable literally named `jwtSharedSecretKey`.

| Written | Reaches |
| ------- | ------- |
| `PORT` | `port` |
| `SMS_API_KEY` | `smsApiKey` |
| `OAUTH2_TOKEN_URI` | `oauth2TokenUri` — a digit does not open a segment |
| `SMTP_HOST` | `smtpHost` |

Four rules bound it:

- **The original key is kept.** The alias is added alongside, so a `${VAR}`
  placeholder in a datasource or resource YAML — which expands verbatim — is
  unaffected.
- **An exact key wins over its screaming twin.** A variable literally named
  `jwtSharedSecretKey` names the target with no convention in between, so it is
  never overruled.
- **The mapping is applied per source, before merging.** An alias therefore
  carries its own source's precedence; derived after merging it would let a
  low-precedence alias outrank a high-precedence exact key.
- **A name outside the convention contributes nothing.** `SCREAMING__DOUBLE`,
  `_LEADING`, `Mixed_Case` and `mixedCase` are all left alone. Approximating one
  would be a guess, and a guess that happened to match a declared field would
  bind a value nobody aimed at it.

The convention is total. Every configuration field writes an acronym as a word
(`jwtRsaPubKey`, `smsApiKey`, `listenToAnyIp`), so a field's environment
variable is its name in `SCREAMING_SNAKE_CASE` — `LISTEN_TO_ANY_IP` for
`listenToAnyIp` — with no list of exceptions to know. A test holds every field
of the base configuration to that round trip.

A key an alias creates that matches no field is dropped exactly as any other
unknown key is: `setValues` traces it and moves on. So the aliasing cannot fail
a boot, only reach one more field than it did before.

The chain ends where the diagram ends. `getDefaultValues` starts from a **copy**
of the provider's resources and hands the merged result to `setValues`, so an
environment variable or an argument reaches the configuration object's *fields*
and nothing else — it does not enter the provider, and `TomConfig` reads nothing
but the provider. The isolation is deliberate: merging into the live provider
would let one server's arguments leak into every later lookup in the process.

To read such a value through `TomConfig`, install the merged map as the provider
first — one line, and the caller's to write:

```dart
TomServerConfigResourceProvider.setServerConfigProvider(
  TomServerConfigResourceProvider.from(
    TomBaseServerConfiguration.getDefaultValues(args).cast<String, dynamic>(),
  ),
);
```

Without it an obligatory `TomConfig` throws, and — the case worth watching —
`TomConfig.withDefault` does not: it answers its default as though the
environment had said nothing, because an unmerged key is simply an absent one.

## Secret References

A configuration value may be written as a **reference** to a secret store
instead of the value itself. The boot reads every reference once, before it
builds the configuration object, and the merge puts the secret where the
reference was — so a database password, a JWT key or an API token is never
written into a resource file, an environment variable or a command line, only
where to find it.

```text
secret:<provider>:<path>[#<field>]
```

| Part | Meaning |
| ---- | ------- |
| `secret:` | The prefix that makes a string a reference. A value is a reference only when it **starts** with it; a string that merely contains `secret:` is a plain value. |
| `<provider>` | The name a `TomSecretsProvider` was registered under — `vault`, `aws`, `azure`, or a third party's. Up to the first colon. |
| `<path>` | Where the secret lives in the provider's own terms — a Vault API path, a Secrets Manager name or ARN, a Key Vault secret name. Everything after the provider's colon, so a path may hold colons (an ARN does). |
| `#<field>` | One member of a secret that holds several — a Vault KV entry, a JSON secret. After the **last** `#`. Without it the secret must be a single value. |

```yaml
# assets/config-resources_default.yaml
jwtSharedSecretKey: "secret:vault:secret/data/billing#jwt"
smtpPassword: "secret:azure:smtp-password"
databases:
  - name: billing
    password: "secret:aws:prod/billing#password"
```

### Where a reference may appear

In **any of the four sources** — the configuration resources, the OS
environment, the `.env` file, the command line — and at **any depth**: a
reference nested in a map or a list is found and replaced like a top-level one.
The environment spellings apply unchanged, so
`JWT_SHARED_SECRET_KEY=secret:vault:secret/data/billing#jwt` reaches
`jwtSharedSecretKey` as a reference and then as the secret.

The substitution happens in `TomBaseServerConfiguration.getDefaultValues`, the
map the configuration object is built from. `TomConfig` reads the provider, and
the provider holds the resources as written — a reference there reads back as
its own text through `TomConfig`. A server that reads secrets through
`TomConfig` installs the substituted map as the provider, the one line shown at
the end of [Source Precedence](#source-precedence).

### Precedence is the source's

A reference is replaced **in place**, so the secret has the precedence of the
source the reference was written in. Secrets are not a layer with a rank of
their own; the order of [Source Precedence](#source-precedence) decides,
unchanged. Two consequences, both from `example/configuration/secrets_example.dart`:

```dart
TomSecrets.register(TomMapSecretsProvider('vault', {
  'secret/data/billing': {'password': 'pw-1'},
  'secret/data/jwt': 'signing-key-1',
}));

// A plain command-line value beats a resource that names a secret.
TomServerConfigResourceProvider.setServerConfigProvider(
  TomServerConfigResourceProvider.from({
    'dbPassword': 'secret:vault:secret/data/billing#password',
  }),
);
var args = ['dbPassword=from-the-command-line'];
await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
print(TomBaseServerConfiguration.getDefaultValues(args)['dbPassword']);
// from-the-command-line

// A reference on the command line beats a plain resource value.
TomServerConfigResourceProvider.setServerConfigProvider(
  TomServerConfigResourceProvider.from({'jwtKey': 'from-the-resource'}),
);
args = ['jwtKey=secret:vault:secret/data/jwt'];
await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
print(TomBaseServerConfiguration.getDefaultValues(args)['jwtKey']);
// signing-key-1
```

In the first case the resource's reference is overwritten in the merge before
anything is loaded, so that secret is never fetched at all.

### Boot order: load, then build

`TomBaseServerConfiguration.collectSources(args)` is the merge of the four
sources with the references still in it — the input `getDefaultValues`
substitutes. A boot hands it to `TomSecrets.load` after registering its
providers and **before** it constructs the configuration:

```dart
Future<void> main(List<String> args) async {
  TomSecrets.register(TomMapSecretsProvider('local', {'db': 'dev-password'}));
  await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
  final configuration = MyServerConfig(args); // receives the secrets
  TomSecrets.startRefresh(const Duration(minutes: 5));
  await TomServer(configuration).start();
}
```

`load` collects every reference in the tree, groups them by provider and path,
and fetches **each path once** however many fields of it are named. It is
**fatal**: the first reference that cannot be resolved — an unknown provider, a
path the store does not hold, an unreachable store, a missing field — throws a
`TomSecretsException`, because a server that cannot read its secrets at start
must not start. A configuration built without the load is refused rather than
started on reference text: `getDefaultValues` throws
`secrets.reference.unresolved` for a reference `load` did not resolve, so a
server cannot come up with `secret:vault:…` as its database password.

`TomSecrets.resolve(reference)` resolves one reference on demand, with the same
fatal behaviour, and `TomSecrets.current(reference)` answers a resolved value.

### Rotation: refresh and watch

The configuration object is built once, so a rotated secret does not change a
field already read. Code holding a credential that rotates — a connection pool,
an outgoing API client — watches its reference instead:

```dart
final subscription = TomSecrets.watch(
  'secret:vault:secret/data/jwt',
  (value) => signer.rekey(value),
);
// ...
subscription.cancel();
```

`TomSecrets.refresh()` fetches every resolved reference again and calls the
watchers of the references whose value changed, with the new value; a watcher
that throws is logged and the others still run. `startRefresh(every)` refreshes
on a timer until `stopRefresh()`. The outcome is a `TomSecretsRefresh`:
`changed` lists the references whose value changed, `failed` the ones that
could not be fetched.

A refresh is **fail-soft** where the load is fatal: a reference whose store
cannot be reached, or no longer holds it, **keeps its last value**, is logged
as a warning and is listed in `failed`. A store outage must not take a running
server's credentials away; a server that could not read them at start never
started.

`TomSecrets.reset()` stops the timer, closes every provider and forgets the
values and watchers — a server's shutdown, and a test's tear-down.

### Writing a provider

A store is reached through a `TomSecretsProvider`:

```dart quote
abstract class TomSecretsProvider {
  String get name;
  Future<TomSecretPayload> fetch(String path);
  Future<void> close() async {}
}
```

`fetch` answers a `TomSecretPayload` — the secret as a `String`, or a
`Map<String, Object?>` for one with several members, and the store's version
when it reports one. The payload, not the provider, picks the field: a map is
read by key, and a string that holds a JSON object is decoded for a field, the
shape a store that keeps one JSON string needs; a member that is not a string
is handed on JSON-encoded. `fetch` throws `TomSecretsException` —
`secrets.fetch.not_found` for a path the store does not hold,
`secrets.fetch.failed` for anything else — and never puts a secret's value in a
message. `TomSecrets.register` installs it under its `name`, replacing one of
that name. Step 9 of the example is a complete third-party provider:

```dart
class PrefixProvider implements TomSecretsProvider {
  @override
  String get name => 'prefix';

  @override
  Future<TomSecretPayload> fetch(String path) async =>
      TomSecretPayload('hello $path', version: '1');

  @override
  Future<void> close() async {}
}
```

`TomMapSecretsProvider(name, secrets)` answers from a map — for tests, and for
local development where a deployment's secrets come from a file nobody commits.
Changing its `secrets` map simulates a rotation.

### The provider libraries

The three stores are libraries of one package, `tom_core_secrets` in
`tom_core_extensions`, so a deployment imports only the store it uses and no
cloud SDK; each talks to its store's HTTP API with
`package:http` and builds itself from configuration with `fromConfiguration`.

| Library | Provider | Reference | Authentication | Settings |
| ------- | -------- | --------- | -------------- | -------- |
| [`tom_core_secrets/vault.dart`](../../../core_extension/tom_core_secrets/README.md#hashicorp-vault-vaultdart) | `TomVaultSecretsProvider` | `secret:vault:secret/data/billing#jwt` — the API path after `/v1/`, KV version 1 or 2 | a token, or AppRole; Vault Enterprise namespaces | `secrets.vault`, `VAULT_*` |
| [`tom_core_secrets/aws.dart`](../../../core_extension/tom_core_secrets/README.md#aws-secrets-manager-awsdart) | `TomAwsSecretsProvider` | `secret:aws:prod/billing#password` — a secret name or ARN | static keys, or a credentials source for a role; signed with `TomAwsV4Signer` | `secrets.aws`, `AWS_*` |
| [`tom_core_secrets/azure.dart`](../../../core_extension/tom_core_secrets/README.md#azure-key-vault-azuredart) | `TomAzureKeyVaultSecretsProvider` | `secret:azure:db-password[/<version>]` | a service principal, the host's managed identity, or a static token | `secrets.azure`, `AZURE_*` |

A provider's settings live under `secrets.<store>` in the configuration
resources and are read as written — they are the credentials that open the
store, so a reference inside them is not resolved. `secrets` is a top-level key
no configuration field declares, so the startup warning about [unknown
keys](#unknown-keys-in-the-configuration-resources) names it.

### Error keys

Every failure is a `TomSecretsException`, a `TomServerException` with
`clientThrow` `false`. A message names the reference or the path, never a
secret's value.

| Key | Raised by | When |
| --- | --------- | ---- |
| `secrets.reference.malformed` | `TomSecretReference.parse` | A reference without the `secret:` prefix, without a provider or path, or with an empty path or field. |
| `secrets.reference.unresolved` | `TomSecrets.current`, `TomSecrets.substitute`, `getDefaultValues` | A reference that `load` or `resolve` never resolved. |
| `secrets.provider.unknown` | `load`, `resolve` | No provider is registered under the reference's provider name. |
| `secrets.field.required` | `load`, `resolve` | The secret holds several values and the reference names no field. |
| `secrets.field.missing` | `load`, `resolve` | The secret has no member of the field's name. |
| `secrets.fetch.not_found` | a provider's `fetch` | The store holds nothing at the path. |
| `secrets.fetch.failed` | a provider's `fetch`; `load`, `resolve` | Anything else a fetch fails with — a provider exception that is not a `TomSecretsException` is wrapped in this key, with the original as `rootException`. |

The provider libraries add their own `secrets.<store>.*` keys for their
configuration and login failures; each lists them in its guide.

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

### Where the variables come from — and how a `.env` reaches them

`Platform.environment` is the default, not the only option. Both entry points
take an `environment:` map, and when one is given it **replaces** the process
environment rather than layering over it — so the caller decides exactly what the
file can see:

```dart
final environment = TomEnvFile.resolveEnvironment();   // OS env + ./.env
final map = TomYaml.loadYamlFile('config.yaml', environment: environment);
TomYaml.mergeInYamlFile(existing, 'overlay.yaml', environment: environment);
```

This parameter is the only route by which a `.env` file can reach a placeholder.
Dart's process environment is read-only, so reading a `.env` cannot put its
values where the default expansion looks — a boot that reads a `.env` for its
config keys but loads its YAML the default way will expand to the placeholder
defaults while its configuration reports the `.env` values. That gap is worst for
the datasource YAML, where the placeholders usually are: a `.env` shared with a
Docker Compose file moves the database and the server keeps dialling the default.

`resolveEnvironment` layers the `.env` **over** the OS environment, matching the
precedence `getDefaultValues` uses for config keys, so both halves of a boot read
the same file the same way. (Docker Compose resolves the other way round.)

### An overlay is a patch, not a replacement

`mergeInYamlFile` is one-sided: keys the file names overwrite what is already
in the target, and keys it does not name survive. The merge **recurses into
subtrees**, so naming one key of a branch replaces that key alone and leaves
the branch's other keys standing:

```yaml
# base.yaml            # env.yaml (overlaid onto it)
db:                    db:
  host: localhost        host: db.prod.internal
  port: 3306
  pool: 20
```

```dart
final config = TomYaml.loadYamlFile('base.yaml');
TomYaml.mergeInYamlFile(config, 'env.yaml');
// db.host = db.prod.internal   (overlaid)
// db.port = 3306, db.pool = 20 (survive — not wiped by the partial branch)
```

This is what makes a per-environment file worth having: it states only its
differences. Were the merge to replace branches wholesale, `env.yaml` above
would silently drop `port` and `pool`.

### A substituted value is a string

Substitution runs *after* the YAML parser has assigned types, and writes its
expansion back into the tree as text. The placeholder and the literal it stands
for therefore arrive differently in the map — and resolve alike through a typed
`TomConfig`:

| Written in YAML | Value in the map | `TomIntConfig` |
| --------------- | ---------------- | -------------- |
| `port: 3306` | `3306` (`int`) | `3306` |
| `port: ${DB_PORT:3306}` | `'3306'` (`String`) | `3306` |

The map keeps the text, because a value a `String` setting reads must not be
retyped for it — a numeric password substituted from the environment is still a
password. A typed `TomConfig` whose value is a `String` reads it as the text of
its type, by the table the environment, a `.env` file and the command line
already go through (`TomArgs.convertToObjectMap`): `'3306'` for an `int`,
`'2.5'` for a `double`, `'true'` for a `bool`. Text that is not of the wanted
type is still `configuration.tom_config.property_type_mismatch`.

### A missing file throws, unless you ask for the tolerant loader

The strict entry points read the file with no existence check, so an absent path
surfaces as a `PathNotFoundException`. The file is required, not optional. The
sibling loader in the same configuration pipeline does the opposite, and that is
the trap — having met one, a reader has a reasonable and wrong expectation of
the other:

| Loader | Absent file |
| ------ | ----------- |
| `TomEnvFile.read('.env')` | returns `{}` |
| `TomYaml.loadYamlFile('config.yaml')` | throws `PathNotFoundException` |
| `TomYaml.mergeInYamlFile(map, 'config.yaml')` | throws `PathNotFoundException` |
| `TomYaml.loadYamlFileIfPresent('config.yaml')` | returns `null` |
| `TomYaml.mergeInYamlFileIfPresent(map, 'config.yaml')` | returns `false` |

The tolerant pair is what the layered overlay above needs, where the
per-environment or per-locale file is genuinely optional and absence is the
normal case:

```dart
for (final env in TomRuntime.getEnvironmentHierarchy()) {
  final applied = TomYaml.mergeInYamlFileIfPresent(
    tree,
    'assets/config-resources_${env.env}.yaml',
  );
  if (!applied) tomLog.info('no overlay for ${env.env}');
}
```

Two things about it are deliberate.

**It forgives an absent file and nothing else.** A file that is there and does
not parse still throws. That is the difference between the tolerant loader and
the bare `catch` it replaces: a `catch (e)` around the load also swallows a
syntax error and reports it as absence, so a mistyped overlay goes on being
skipped and the settings in it silently never apply — which reads, from the
outside, exactly like a setting that was never written.

**It says whether the file was there** — `null` versus a map,
`false` versus `true`. An overlay that never applied is precisely what an
operator hunting a setting with no effect needs to be told, and a loader that
answers `{}` for both an absent file and an empty one cannot tell them.

The strict pair remains the right choice for a file the process cannot run
without: an asset that ships with the package and is missing at boot is almost
always a wrong working directory, and a tolerant load turns that into a server
started with no configuration whose first symptom appears several layers later.

## Not Yet Implemented

- **A misspelled setting outside the configuration resources is silently
  ignored.** The environment, `.env` and command-line layers are not checked
  against the fields they fill, so `prot=8080` on a command line merges as a
  live key, `port` is never set, and the server comes up on its subclass
  default. The resources are checked, with a warning (see [Unknown keys in the
  configuration resources](#unknown-keys-in-the-configuration-resources)); the
  other layers carry the process environment, where an unknown key is the
  normal case.
  <!-- pinned: test/configuration_test.dart › a misspelled setting merges as a live key and fills no field -->
- **A `TomConfig` resolves once, at construction.** The value is read from the
  active provider when the object is built and cached, so a provider installed
  *afterwards* is not observed — a second install does not update an existing
  instance. Building one before **any** provider exists is no longer part of
  this: it is refused, naming the ordering (see [Typed Property
  Access](#typed-property-access)). What remains is the narrower case of a
  `TomConfig` built against one provider and read after another was installed,
  which the API cannot distinguish from an intentional snapshot.
  <!-- pinned: test/configuration_test.dart › a TomConfig does not observe a provider installed later -->
- **Nothing refuses to start on the checked-in TLS pair.** `certificateChain`
  and `privateKey` default to a throwaway `localhost` certificate committed to
  this repository — convenient for local development, and worthless as
  authentication anywhere else, since its private key is public. A boot that
  serves TLS with either half still at its default now [warns every
  time](#the-development-tls-pair-announces-itself), but it does start:
  refusing would cost every local TLS run an opt-in setting. Overriding both in
  production is still the deployment's responsibility, and
  `usesDevelopmentTlsMaterial` is the condition for one that would rather
  refuse.
  <!-- pinned: test/configuration_test.dart › the default TLS material is the checked-in self-signed pair -->
- **The JWT key material defaults to nothing, deliberately.**
  `jwtSigningKeyFile`, `jwtVerificationKeyFiles`, `jwtSharedSecretKey`,
  `jwtRsaPrivKey` and `jwtRsaPubKey` are all `null` out of the box, and
  `installJwtSigning` reads that nullness as "not configured": it then falls
  back to the framework's bundled sample keys, which are written into
  the `tom_crypto` sources and therefore secret from nobody. That fallback warns
  at boot, marks the resulting `TomJwtConfiguration` as a dummy certificate — so
  the framework warns again on every sign and verify — and is **refused
  outright** with a `TomSigningKeyException` unless the runtime environment is a
  development or test one. A server that never declared an environment counts as
  not-development. This is the one place where the "unconfigured" state is not
  merely reported but blocks the boot, and the reason is that the alternative is
  a server signing with a published passphrase and saying nothing. Contrast the
  TLS pair above, which fails open. ES256 has no sample key, so an unconfigured
  ES256 server is refused in every environment.
  The configuration carries the key material, the algorithm, the issuer and the
  audience; a token's expiry is set where it is minted, by the code that mints
  it, because it is that code's policy.
  <!-- pinned: test/configuration_test.dart › the JWT key material defaults to nothing at all -->

## Core Components

- **`TomServerConfigResourceProvider`** — the configuration tree and its
  `exists` / `get` lookups; the `setServerConfigProvider` / `getServerConfig`
  singleton and the `loader` hook.
- **`TomConfig<T>`** (+ `TomStringConfig` / `TomIntConfig` / `TomDoubleConfig` /
  `TomBoolConfig`) — typed, eagerly-resolved property views; `get()` / `~`.
- **`TomBaseServerConfiguration`** — the reflected settings base;
  `collectSources` (the source merge), `getDefaultValues` (the merge with its
  secret references substituted) and the reflected `setValues`.
- **`TomYaml`** — YAML loading with environment substitution.
- **`TomSecrets`** (+ `TomSecretsProvider`, `TomMapSecretsProvider`,
  `TomSecretReference`, `TomSecretPayload`, `TomSecretSubscription`,
  `TomSecretsRefresh`, `TomSecretsException`) — secret references: the
  provider registry, the fatal load before the configuration is built, the
  in-place substitution, and the fail-soft refresh with its watchers.

## Verification

`example/configuration/configuration_example.dart` walks the codegen-free
surface in twelve steps, with no setup of any kind — defer a tree to the
`loader` hook, install one directly, resolve a dotted path, fall back to a
default, read through `~`, watch an obligatory miss throw, load a YAML file
with `${VAR:default}` substitution, layer a second file over it and install
the result through `.load`, and then the two steps that make [Source
Precedence](#source-precedence) legible: `PATH` failing to resolve through
`TomConfig` although every platform sets it, and the same lookup succeeding
once the merged map has been installed as the provider. The last step is the
other failure shape — a bad cast raising `TomConfigurationException` and the
`TypeError` it chains, which is also where the contrast with step 6's bare
`String` becomes visible in code rather than in prose.

All three ways to install a tree are executed there, in the order a startup
meets them. The `loader` hook is step 1 because that is the only place it can
be: it fires when `getServerConfig()` *creates* the process provider, so once
any provider exists the hook is unreachable and `.load` is the form left.
Layering shows both halves an overlay needs — the overwrite is per leaf, so a
sibling the overlay omits survives, and an overlay that is *absent* throws
rather than being skipped. Run it exactly as its header documents:

```bash
dart run example/configuration/configuration_example.dart
```

Every step checks its own result through the shared `example/_support/check.dart`
and the run fails when one does not hold, so a green run is a verification
rather than a transcript — see
[A green run is a verification](../README.md#a-green-example-run-is-a-verification)
for why that helper throws instead of asserting. One
thing is deliberately left out and the header says why — constructing a
`TomBaseServerConfiguration` subclass needs reflection generated for it, so it is
described in [The Server Configuration Base](#the-server-configuration-base)
here instead. Its static `getDefaultValues` needs no subclass and is used.

`test/configuration_test.dart` covers the module end to end in one process:

```bash
dart test test/configuration_test.dart   # or `testkit :test` for the package
```

Sixty-three tests in eight groups carry the behaviour — the provider's
`exists` / `get` (including the explicit-null cases), `TomConfig`'s three
resolution branches and its one widening, `getDefaultValues` and the four-layer
merge order, the derived `args` field, the boundary between the merged map and
the provider, `TomYaml`, the example, and the limitations listed under [Not Yet
Implemented](#not-yet-implemented). Nothing here is tagged and nothing needs an
external server, so all of it runs in the default `testkit :test`.

`example/configuration/secrets_example.dart` walks [Secret
References](#secret-references) in nine steps against a `TomMapSecretsProvider`:
loading three references from a resource with each provider path read once, the
substituted merge, a command-line value beating a resource reference and a
command-line reference beating a resource value, an unloaded reference refused
(`secrets.reference.unresolved`), an unknown provider failing the load
(`secrets.provider.unknown`), a rotation reaching a watcher, a refresh that
cannot fetch keeping the last value, and a third-party provider. Run it with
`dart run example/configuration/secrets_example.dart`; `test/examples_test.dart`
runs it and requires all nine steps. `test/secrets_test.dart` covers the same
surface in four groups — parsing references, reading a payload's fields,
resolving configuration (precedence, unloaded and unknown references, one fetch
per path) and rotation (watchers, fail-soft refresh, `startRefresh`) — with no
external store.

The two are linked in both directions — the example's header names this
document and the suite, and the suite runs the example, under exactly the
command above, requiring exit 0 and requiring every numbered step to have
reported (the count read off the example, so a step added later is covered
without editing the test). Two further tests cover what the exit code cannot
see: one reads the example's source and requires it to state its
expectations through the shared throwing helper rather than `assert`, the other
requires its `PATH` step to keep demonstrating that `TomConfig` does not
reach the environment on its own. So each claim this document makes is
falsifiable from the suite, as is each limitation it admits to.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `secrets.dart` | `Timer`, for `startRefresh` |
| `dart:convert` | dart | `secrets.dart` | `jsonDecode` / `jsonEncode`, for a field of a JSON secret |
| `dart:io` | dart | `base_server_configuration.dart`, `runtime_environment.dart`, `yaml_resources.dart` | `File`, `Platform` |
| `shelf` | package | `base_server_configuration.dart` | the `Middleware` / `Handler` / `Request` / `Response` types used by the configuration's handler fields |
| `tom_core_kernel` | package | `base_server_configuration.dart`, `runtime_environment.dart`, `secrets.dart`, `yaml_resources.dart` | `tomReflector`, `getObjectFromTree`, `mergeMapsOneSided`, `makeCleanJsonMap`, `substituteEnvVars`, `TomRuntime`, `tomLog` |
| `yaml` | package | `yaml_resources.dart` | YAML parsing for `TomYaml` |
| [cmdline](cmdline.md) | module | `base_server_configuration.dart`, `runtime_environment.dart`, `tom_config.dart` | `TomArgs` and `TomEnvFile` (source parsing/merging); `TomArgs.convertToObjectMap` also reads a text value as the type a `TomConfig` wants |
| [little_things](little_things.md) | module | `secrets.dart`, `tom_config.dart` | `TomServerException`, the base of `TomConfigurationException` and `TomSecretsException` |
| [server](server.md) | module | `base_server_configuration.dart` | `tomLoggingMiddleware` |
