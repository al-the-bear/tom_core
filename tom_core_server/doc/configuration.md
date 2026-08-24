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
- [Deployment Settings](#deployment-settings)
- [Source Precedence](#source-precedence)
- [Loading YAML](#loading-yaml)
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
| `TomConfigurationException` | exception | A property failed the cast to `T`; chains the `TypeError` |
| `TomBaseServerConfiguration` | reflected class | Base for a server's settings; merges all sources on construction |
| `TomYaml` | class | Loads YAML files with `${VAR:default}` substitution |
| `tomAppId` | getter | Process-wide application id, read from the active configuration's `appId` |

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

Alternatively, supply a lazy `loader` (used when the default provider is created
on first `getServerConfig`) or construct with `.load(loader)`.

## Typed Property Access

`TomConfig<T>` reads its value **once at construction** from the active provider
and caches it. Resolution order:

1. provider has the key → cast its value to `T` (a bad cast throws a
   [`TomConfigurationException`](#what-a-bad-cast-throws));
2. else a default was supplied → use it;
3. else the property is obligatory → construction throws.

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

### What a bad cast throws

Step 1 raises a `TomConfigurationException` — a `TomServerException`, so it is
a real `Exception` and carries the isolate name and the request UUID like every
other server error. Its `key` is
`configuration.tom_config.property_type_mismatch`, and `parameters` holds the
`key`, `type` and `value` separately, so a handler can report them without
parsing the message.

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

Note the asymmetry with step 3: an obligatory key with no default throws a bare
`String`, not an exception at all. See [Not Yet
Implemented](#not-yet-implemented).

Because the value is captured at construction, build a `TomConfig` *after* the
provider is installed; later provider changes are not observed by an existing
instance.

The provider is the *only* source read. An environment variable or a
command-line argument is not one of the three steps above — it reaches the
configuration object's fields instead. See *Source Precedence* below for the one
line that makes it reachable here too.

## The Server Configuration Base

A server subclasses `TomBaseServerConfiguration` and declares typed fields
(`port`, `host`, `noSsl`, `certificateChain`, `privateKey`, `isolateCount`,
handler/middleware hooks, logging levels, and the three deployment blocks in
*Deployment Settings* below). The class is `@tomReflector`, and its constructor
fills those fields from the merged configuration via the generated `setValues`:

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

One field on the base is **derived rather than configured**: `args` holds the
command line the configuration was built from. The constructor assigns it after
`setValues`, so a configuration key that happens to be spelled `args` is merged
like any other but does not land in the field — the invocation is what the field
promises, and the invocation is what survives. Treat it as sensitive: the
command line is one of the channels a deployment uses to supply a secret, so log
individual fields rather than this list.

> The default `certificateChain` / `privateKey` are a throwaway self-signed
> `localhost` pair for local development and **must be overridden in
> production**. JWT signing-key fields exist; richer JWT-creation settings are a
> tracked follow-up.

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

## Deployment Settings

Three blocks of the configuration base exist for the deployment rather than for
the code: they say who the server logs in as, how it sends mail, and how it
sends SMS. They are grouped here because their reader is an operator filling in
an environment rather than a developer calling an API — and an operator cannot
look up a setting they were never told exists.

**Each block has one switch.** Leave it unset and the block is *disabled*, not
misconfigured — the server starts, and the messaging module registers a no-op
transport. That is the wanted behaviour for a test run, a local build and a CI
job, all of which should compose messages and deliver none. The opposite case, a
block that is set but unusable, throws when the settings are built, because
someone meant to send.

| Block | Switch | Unset means |
| ----- | ------ | ----------- |
| Server self-login | `authServerLoginUri` + `serviceAccountName` | The server never logs itself in and runs uncapped |
| Outbound mail | `smtpHost` | This deployment sends no mail |
| Outbound SMS | `smsEndpoint` | This deployment sends no SMS |

**Four settings are secret-bearing** — `serviceAccountCredential`,
`smtpPassword`, `smsApiKey` and `smsApiSecret` — under the same rule as
`privateKey` and the JWT signing keys. Their *declaration* belongs in the class,
so the shape and the source key are known; their **value is never authored**. It
is supplied out of band at deploy time through the precedence chain below — the
OS environment, `.env`, or the command line — and must never be written into a
spec or a checked-in configuration tree.

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
`doc/api_reference/api_summary_configuration.md`.

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
for therefore do not resolve alike:

| Written in YAML | Value in the map | `TomIntConfig` |
| --------------- | ---------------- | -------------- |
| `port: 3306` | `3306` (`int`) | resolves |
| `port: ${DB_PORT:3306}` | `'3306'` (`String`) | throws |

This holds even when `DB_PORT` is unset and the default supplies the same
digits. Substitution is the only configuration source that reaches `TomConfig`
untyped — the environment, a `.env` file and the command line each pass
through a converting reader — and `TomConfig` casts rather than parses. So
read a substituted number as text and parse it:

```dart
final port = int.parse(~TomStringConfig('database.port'));
```

### A missing file throws

Both entry points read the file with no existence check, so an absent path
surfaces as a `PathNotFoundException`. The file is required, not optional. The
sibling loader in the same configuration pipeline does the opposite, and that is
the trap — having met one, a reader has a reasonable and wrong expectation of
the other:

| Loader | Absent file |
| ------ | ----------- |
| `TomEnvFile.read('.env')` | returns `{}` |
| `TomYaml.loadYamlFile('config.yaml')` | throws `PathNotFoundException` |
| `TomYaml.mergeInYamlFile(map, 'config.yaml')` | throws `PathNotFoundException` |

This matters for the layered overlay above, where the per-environment or
per-locale file is genuinely optional and absence is the normal case. Guard it:

```dart
void mergeYamlIfPresent(Map<String, Object?> into, String path) {
  if (!File(path).existsSync()) return;
  TomYaml.mergeInYamlFile(into, path);
}
```

Catching works too — `mergeInYamlFile` reads before it merges, so a throw
leaves the target map untouched and the caller carries on with what it had.
But catch `PathNotFoundException` specifically. A bare `catch` around the load
also swallows a syntax error in a file that *is* there and reports it as
absent, so a malformed overlay silently stops being applied.

## Not Yet Implemented

- **A misspelled setting is silently ignored.** Nothing validates the merged
  tree against the fields it will fill. `getDefaultValues` returns whatever the
  sources said, and the reflection layer assigns the keys that name a field and
  drops the rest — so `prot=8080` merges as a live key, `port` is never set,
  and the server comes up on its subclass default. A typo is indistinguishable
  from a setting nobody supplied, and neither is reported. Completeness is the
  caller's check, after the last source is merged.
- **An unknown key reads back as its own name.**
  `TomServerConfigResourceProvider.get` answers a key it does not hold with the
  key string itself, not `null` and not a throw. A caller that forgets to gate
  on `exists` receives `'server.port'` where it expected a port — which fails
  the next cast if it is lucky, and silently succeeds where a `String` was
  wanted if it is not. Gate on `exists`, or read through `TomConfig`, which
  does.
- **A `TomConfig` resolves once, at construction.** The value is read from the
  active provider when the object is built and cached, so a provider installed
  afterwards is not observed. Install the provider before declaring the
  properties — but that ordering is a convention, not something the API
  enforces, and a property held in a top-level `final` resolves when its
  library is first touched, which may be before `main` has installed anything.
- **An obligatory miss throws a bare `String`.** The third resolution branch
  throws the message rather than an exception carrying it, so `on Exception
  catch` does not catch it and a plain `catch (e)` hands back a `String`. Use a
  bare `catch` around the declaration of an obligatory property. A failed
  *cast* is unaffected — that path throws a `TomConfigurationException`, so the
  two failures of one constructor need two different catch shapes.
- **A substituted YAML value is text.** `${VAR}` expansion runs after the YAML
  parser has assigned types, so `port: ${DB_PORT:3306}` yields the `String`
  `'3306'` where `port: 3306` yields an `int`, and `TomConfig` casts rather
  than parses. See [A substituted value is a
  string](#a-substituted-value-is-a-string).
- **`TomYaml` has no optional load, and the two sibling loaders disagree.**
  Both entry points throw `PathNotFoundException` for an absent file, where
  `TomEnvFile.read` in the same pipeline returns `{}`. There is no
  `loadYamlFileIfPresent`, so every consumer of an optional overlay writes its
  own guard — the sample servers each carry a private `mergeYamlIfPresent`,
  and a bare `catch` is the tempting alternative that also hides a malformed
  file.
  See [A missing file throws](#a-missing-file-throws).
- **The default TLS material is a checked-in self-signed pair.**
  `certificateChain` and `privateKey` default to a throwaway `localhost`
  certificate committed to this repository — convenient for local development,
  and worthless as authentication anywhere else, since its private key is
  public. Nothing refuses to start when a deployment leaves it in place, so
  overriding both in production is the deployment's responsibility.
- **`jwtSharedSecretKey` defaults to a literal passphrase.** The field carries
  `"config-secret-passphrase"` out of the box and is marked as not currently in
  use. Nothing consumes it today, so the default is inert rather than
  dangerous — but it is a secret-shaped value with a published default, and it
  must be set before anything starts signing with it.

## Core Components

- **`TomServerConfigResourceProvider`** — the configuration tree and its
  `exists` / `get` lookups; the `setServerConfigProvider` / `getServerConfig`
  singleton and the `loader` hook.
- **`TomConfig<T>`** (+ `TomStringConfig` / `TomIntConfig` / `TomDoubleConfig` /
  `TomBoolConfig`) — typed, eagerly-resolved property views; `get()` / `~`.
- **`TomBaseServerConfiguration`** — the reflected settings base;
  `getDefaultValues` (the source merge) and the reflected `setValues`.
- **`TomYaml`** — YAML loading with environment substitution.

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

Every step checks its own result and the run fails when one does not hold, so a
green run is a verification rather than a transcript. The checks are a plain
`if`/`throw` and not `assert`, because `dart run` leaves assertions disabled: an
`assert` would compile out under the very command above, and the example would
print a plausible transcript and exit 0 with every expectation violated. One
thing is deliberately left out and the header says why — constructing a
`TomBaseServerConfiguration` subclass needs a generated `setValues`, so it is
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

The two are linked in both directions — the example's header names this
document and the suite, and the suite runs the example, under exactly the
command above, requiring exit 0 and requiring every numbered step to have
reported (the count read off the example, so a step added later is covered
without editing the test). Two further tests cover what the exit code cannot
see: one reads the example's source and requires it to state its
expectations through the throwing helper rather than `assert`, the other
requires its `PATH` step to keep demonstrating that `TomConfig` does not
reach the environment on its own. So each claim this document makes is
falsifiable from the suite, as is each limitation it admits to.

## Dependencies

- `tom_core_kernel` — `tomReflector`, `getObjectFromTree`, `mergeMapsOneSided`,
  `makeCleanJsonMap`, `substituteEnvVars`.
- The cmdline module — `TomArgs` and `TomEnvFile` (source parsing/merging).
- `shelf` — the `Middleware` / `Handler` / `Request` / `Response` types used by
  the configuration's handler fields.
- `yaml` — YAML parsing for `TomYaml`.
