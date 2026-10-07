# Configuration Module

The **machine-scoped** configuration of a client app: one holder object that
owns every setting of this install, resolves each from the shipped config
resources, adopts the install's persisted overrides at startup, and persists
back **only what the install actually changed**.

Where [`TomProperty<T>`](resources.md) reads a single config key eagerly and
immutably, a `TomBaseClientConfiguration` gives the same values a lifecycle:
they are observable, writable, persistent, and addressable as a set.

## Table of Contents

- [Overview](#overview)
- [Scope](#scope)
- [Quick Start](#quick-start)
- [Resolution Order](#resolution-order)
  - [The environment layer](#the-environment-layer)
- [Shadowing by a Narrower Scope](#shadowing-by-a-narrower-scope)
- [Core Components](#core-components)
- [Observation](#observation)
- [Persistence](#persistence)
- [Error Keys](#error-keys)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomBaseClientConfiguration` | abstract class | Abstract holder of one install's machine-scoped settings. |
| `TomSetting` | class | One observable, addressable setting (`TomObject<T>` + key + baseline). |
| `TomClientEnvironment` | abstract class | Where a setting's `envAlias` is looked up; the reader is replaceable. Statics only. |
| `TomOverridableBy` | enum | Which narrower client scope, if any, may shadow a setting — `none` / `user` / `device`. |
| `TomEffectiveSettings` | class | Reads a setting together with the preference scopes it opens itself to. |
| `TomPreferenceLookup` | typedef | `Future<T?> Function<T extends Object>(String key)` — the one-key read both preference stores carry. |
| `TomClientConfigurationStore` | abstract class | Two-method (`read`/`write`) interface for persisting overrides. |
| `TomMemoryClientConfigurationStore` | class | Process-lifetime override store. |
| `TomFileClientConfigurationStore` | class | JSON file store (io variant; neutral variant throws). |
| `TomClientConfigurationException` | class | Module failures, keyed by stable dotted codes. |

## Scope

A client configuration holds the settings of **(this app, this machine)** — the
server URL to talk to, a log level, a polling interval, whether the debug
overlay is on.

There is no user parameter in the holder, in the store interface, or in the
persisted format, by design:

| Varies by | Belongs to |
| --------- | ---------- |
| client install / machine | **this module** |
| user, on this device | [`TomDevicePreferences`](preferences.md) — no session needed, but it does not follow the account |
| user, on every device | [`TomUserPreferencesClient`](preferences.md) — server-persisted, so it needs a session |
| server deployment | `TomBaseServerConfiguration` (`tom_core_server`) |

Both preference holders ship in this package, through this barrel; the
[preferences module](preferences.md) documents them.

Mixing those scopes into one holder is what turns a settings class into a junk
drawer, and it breaks the guarantee that reading a client setting never
requires a login. Keeping them apart is not the same as keeping them unrelated:
a setting may declare that a narrower scope is allowed to shadow it, and
[Shadowing by a Narrower Scope](#shadowing-by-a-narrower-scope) is how the three
are read as one value.

Per-field **validation** is likewise not the holder's job, and nothing else in
the module does it either. The *type* is checked — a raw value that cannot be
read as the declared type raises `client_configuration.value.type_mismatch` —
but the *value* never is: a `TomSetting<int>` stores and serves a refresh
interval of `-1`, a `TomSetting<String>` an empty server URL. There is no hook
to add a check, because `TomSetting`'s constructor is private and settings are
created only by the holder's `*Setting` methods. Range, format and enum
constraints are the **caller's** — applied after `load()`, or at the point of
use.

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

class AppConfiguration extends TomBaseClientConfiguration {
  AppConfiguration({super.store});

  late final TomSetting<String> serverUrl;
  late final TomSetting<int> refreshSeconds;
  late final TomSetting<bool> darkMode;

  @override
  void declareSettings() {
    serverUrl = stringSetting('client.server.url', 'https://api.example.com');
    refreshSeconds = intSetting('client.refresh.seconds', 60);
    darkMode = boolSetting('client.ui.darkMode', false);
  }
}

final config = AppConfiguration(
  store: TomFileClientConfigurationStore('$supportDir/client_config.json'),
);
await config.load();       // adopt this install's overrides

config.darkMode | true;    // observers fire, per field and holder-wide
await config.save();       // persist the overrides — and only those
```

`declareSettings()` is called by the base constructor. It exists because Dart
field initialisers cannot call instance methods, and because it makes the
declaration set **complete by the end of construction** — which is what lets
`settings`, `save()` and `resetAll()` be exhaustive.

Only four value types can be declared — `String`, `int`, `double`, `bool` —
exactly those that survive a JSON round-trip through a store.

## Resolution Order

Highest precedence first:

0. the **environment** — when the setting declares an `envAlias` and
   `TomClientEnvironment` reports it set;
1. the **persisted override** — what this install last saved;
2. the **shipped config-resources value** for the key
   (`TomConfigResourceProvider`);
3. the **declared default** at the declaration site.

Layers 2–3 form the setting's `baseline`, resolved once at declaration time.
A setting is *overridden* exactly when its value differs from that baseline —
and that is precisely the set `save()` persists.

### The environment layer

```dart
serverUrl = stringSetting(
  'client.server.url',
  'https://api.example.com',
  envAlias: 'APP_SERVER_URL',
);
```

`APP_SERVER_URL=https://staging.example` then decides that setting for the run.
This is the ordinary way an installer points a build at a different environment,
or a CI job runs a suite against a throwaway endpoint, without editing a file or
shipping a build.

**It outranks the override**, and that placement is the whole design. The two
layers answer different people: an override is what *this install* chose, an
environment variable is what the **operator who launched it** decided. A layer
the install could quietly out-vote would not configure a deployment at all.

Four things follow, and each is a consequence rather than a separate rule:

- `save()` **never writes** an environment-configured setting, so unsetting the
  variable later restores the layers below instead of finding the operator's
  value baked into the store;
- `isOverridden` is `false` for one — the install has not overridden it — so it
  is absent from `hasOverrides` and from `hasUnsavedChanges` too;
- `reset()` restores the **operator's** value, not the baseline: "drop the
  install's override" cannot mean "drop somebody else's decision";
- `load()` restores it as well, because `load()` produces the state a fresh
  start would produce and a fresh start reads the environment.

A value is *set* when the reader returns non-null, including the empty string:
`APP_SERVER_URL=` is an operator saying "present and empty", and reading that as
absent would send the setting to a shipped default they were deliberately
replacing. The value is coerced like any other external one, so
`APP_RETRIES=abc` against an `int` setting throws
`client_configuration.value.type_mismatch` at declaration — where it names the
key — rather than at the first read of whatever screen shows it.

`TomSetting.isFromEnvironment` is what a settings screen reads to disable the
field. The setter is not taken away — a `TomSetting` is a `TomObject`, and
removing its setter would remove the observable with it — so a screen that does
not check it lets the user type a value that nothing persists and that the next
`load()` replaces.

**Where the value comes from is the app's choice.** `TomClientEnvironment.reader`
starts as the process environment where there is one, and answers `null` where
there is not: a browser has no environment, and a mobile app is launched by the
OS rather than by a shell. Those platforms have their own answer — a
`--dart-define` baked at build time, a value fetched at startup, an
MDM-delivered payload — and only the app knows which, so it replaces the reader
rather than the framework picking one and calling it *the* environment. Replace
it **before** the holder is constructed; settings resolve their environment
value at declaration, which happens in the constructor.

External values are loosely typed (a JSON store, a YAML config file), so the
readings with exactly one sensible interpretation are accepted: the exact type,
`int` → `double`, and `String` → `int`/`double`/`bool` when it parses. Anything
else throws `client_configuration.value.type_mismatch` naming the key rather
than quietly falling back to the default — a fallback would hide a config typo
behind behaviour that merely looks correct.

## Shadowing by a Narrower Scope

The four resolution layers all answer one question — what does **this install**
hold? Two narrower scopes exist beside it, and a setting may declare that one of
them is allowed to answer instead:

```dart
theme = stringSetting(
  'client.ui.theme',
  'system',
  overridableBy: TomOverridableBy.device,
);
```

```dart
final effective = TomEffectiveSettings(
  fromDeviceStore: TomDevicePreferences.resolve()?.get,
  fromUserStore: accountPreferences.get,
);

final theme = await effective.valueOf(config.theme); // device ▸ user ▸ install
```

### Opt-in, and declared at the wider scope

`overridableBy` defaults to `TomOverridableBy.none`, so a setting is
**scope-pinned** until its author opens it. A preference that happens to carry
the same key as a pinned setting is a different value that is spelled the same,
and reading it would be a scope leak nobody asked for — so `valueOf` does not
merely rank it below the install's value, it never asks the store at all.

The permission is written once, on the setting, and is never restated by the
preference. There is therefore no second statement of the relation that could
drift out of agreement with the first, and no store that can open a key by
itself.

The arm names the **narrowest** scope permitted, and every scope between the
setting and that one is permitted too:

| Arm | Consulted, in order |
| --- | ------------------- |
| `none` | the setting alone |
| `user` | the account store, then the setting |
| `device` | the device store, the account store, then the setting |

`user` therefore does *not* open the device store: a value the author decided
should follow the account is not one an individual device may fork.

### What the composition is not

It does not **write**. A value is written by whichever holder owns its scope —
`config.theme | 'dark'` then `config.save()`, or `preferences.set(key, value)` —
because "where does this change belong" is the question the scopes exist to
answer, and a composed setter would have to guess.

It is not **observable**. A `TomSetting` is a `TomObject`; a preference is a
stored document with no change notification, so an effective value has nothing
to fire on when the narrower scope moves. A screen that must follow one re-reads
it at the points it already knows about — a sign-in, a preference edit it made
itself, a refresh.

It is not a **merge**. The narrowest store holding the key wins outright; there
is no per-field blending, and a preference stored under the key as the wrong
type raises `TomUserPreferenceCodecException` from the store rather than falling
through to the install's value. An unwritten preference is an ordinary state
that the wider scope answers; one written as the wrong type is a bug, and
quietly answering around it would hide it.

### The environment does not close a setting

Layer 0 and `overridableBy` are independent, and deliberately so. The
environment decides the **install's** value; `overridableBy` decides who may
shadow the install. So a setting an operator has configured can still be
shadowed by a user preference if its declaration says it may — and a setting the
operator must win is declared `TomOverridableBy.none`, which is the only lever
for that.

### Both stores arrive as callbacks

`TomEffectiveSettings` holds two `TomPreferenceLookup`s rather than the stores
themselves, for the reason [preferences.md](preferences.md) gives for
`getPreferred`: an application with no account store must not be made to carry
an HTTP client, and one with no device store must not be made to carry a
platform backend. `TomDevicePreferences.get` and `TomUserPreferencesClient.get`
are each a `TomPreferenceLookup` as written, so an application passes the method
rather than an adapter, and an omitted lookup is simply never consulted.

A setting that opens itself must carry a key **both preference stores accept**.
The declaration checks it against `TomUserPreferenceKeys` and refuses with
`preferences.key.invalid` — the preference vocabulary's own refusal rather than
a second spelling of it here — so the failure lands on the line that made the
promise rather than on the first effective read. A pinned setting is not
checked: its key never reaches a preference store.

## Core Components

### `TomBaseClientConfiguration`

| Member | Purpose |
| ------ | ------- |
| `declareSettings()` | **Abstract.** Declare every setting; called from the constructor |
| `stringSetting` / `intSetting` / `doubleSetting` / `boolSetting` | Declare a setting under a dotted key with a default |
| `load()` | Adopt the persisted overrides (idempotent) |
| `save()` | Persist the overrides, and only those |
| `store` | The override store; may be wired after construction. Changing it discards the loaded snapshot, keeps the settings — call `load()` to adopt the new store |
| `settings` / `settingFor(key)` | The declared settings, addressable as a set |
| `isOverridden(key)` / `hasOverrides` | Whether a setting differs from its **baseline** — a fact about the install, not a dirty flag |
| `hasUnsavedChanges` | Whether `save()` would write something other than what the store last held |
| `reset(key)` / `resetAll()` | Drop overrides in memory (call `save()` to make it stick) |

### Unsaved changes

`hasOverrides` answers "has the install changed something", and that is not the
question a settings screen asks before it lets itself be dismissed. A setting
`load()` adopted from the store is already overridden with nothing unsaved, so
`if (config.hasOverrides) warn()` warns every time, on a holder that was loaded
and never touched.

`hasUnsavedChanges` is the dirty flag: `true` exactly when `save()` would write
something other than what the store last held — a value changed, an override
added, or an override **dropped**, since a removal is unsaved work too.

```dart
if (config.hasUnsavedChanges) {
  final keep = await confirmDiscard(context);
  if (!keep) return;
}
Navigator.of(context).pop();
```

It reads no store, so it is answerable in a build or a dismiss guard where there
is no `await` — the comparison is against the snapshot the last `load()` or
`save()` took. It changes only when a setting changes, so a widget observing the
holder re-reads it at exactly the right moments. Keys this build does not
declare are never unsaved: `save()` carries them forward untouched, so nothing
here can make them differ. With no store wired there is no snapshot and any
override reads as unsaved — the honest answer, and a getter rather than a throw
because a dismiss guard has to be answerable.

There is still no autosave: `save()` remains the only write path, and a screen
that changes a setting and is dismissed without calling it loses the change.
What has changed is that the screen can now *ask*.

### `TomSetting<T>`

A `TomObject<T>` — so `~`, `|`, `<<`, `call()`, `addObserver` and
`TomObservingWidget` all work on it unchanged — plus:

- `key` — the dotted configuration key. This, not the Dart field name, is the
  setting's identity: it is what the config resources and the store are keyed
  by.
- `declaredDefault` — the default written at the declaration site.
- `baseline` — the value when the install has not overridden it.
- `envAlias` — the environment variable this setting may also be read from, or
  `null`; `isFromEnvironment` says whether it answered.
- `overridableBy` — which narrower client scope may shadow it.
- `isOverridden`, `reset()`.

### `TomEffectiveSettings`

| Member | Purpose |
| ------ | ------- |
| `valueOf(setting)` | The setting's value after the scopes it opens itself to have had their say |
| `fromUserStore` | Reads the signed-in user's server-stored preferences, or `null` when there is no account store |
| `fromDeviceStore` | Reads this device's preferences, or `null` when there is no device store |

Both fields are `TomPreferenceLookup`s — `Future<T?> Function<T extends
Object>(String key)`, the shape both shipped stores' `get` already has. See
[Shadowing by a Narrower Scope](#shadowing-by-a-narrower-scope).

### Stores

`TomClientConfigurationStore` is deliberately two methods — `read()` and
`write(values)`. There is no `clear` (writing an empty map *is* clearing) and no
per-key accessor, so adapting a new backend (`shared_preferences`, browser local
storage, a keychain) costs two methods.

`TomFileClientConfigurationStore` writes JSON via write-then-rename, so a
failure part-way through leaves the previous content readable rather than a
truncated override map. An empty write deletes the file. It is selected by
conditional export: on a target without `dart:io` the same name resolves to a
variant that **throws on construction** with
`client_configuration.store.unsupported_platform` rather than silently
degrading — a settings screen whose Save button appears to work but forgets
everything is worse than a failure at startup.

## Observation

Both granularities are live at once:

- **per field** — observe the `TomSetting`; a `TomObservingWidget` bound to it
  rebuilds on that one setting;
- **whole holder** — observe the holder; it observes each of its settings and
  re-emits, so one observer sees every change.

`load()` and `resetAll()` emit **one** holder notification for the whole
operation, not one per setting. Per-field observers still fire per field.

That survives nesting. A screen batching a multi-setting edit around a reload
mutes the holder itself and calls `load()` inside its own batch; because
`TomObservable.mute` counts depth rather than setting a flag, the load's release
does not free the caller's, and the screen still gets the one rebuild it asked
for. Were it a flag, the caller's suppressed writes would escape during the
load, the holder would come back unmuted without anyone asking, and every later
write in the batch would notify immediately. The property belongs to the kernel,
so `test/configuration_test.dart` asserts the consequence here rather than
assuming it.

> Observers are held by weak reference. Retain the observer returned by `>>`
> for as long as you want notifications, or it will silently stop firing.

## Persistence

**Only overrides are stored, never the full value set.** A setting the install
never changed is re-resolved from the shipped config resources at every start,
so shipping a new default in an app update actually reaches installs that never
touched that key. Persisting everything would freeze the shipped defaults at the
moment of the first save.

Keys in the store that the running build does not declare are **carried
forward** untouched — a build that has dropped a setting, or an older build
during a staged rollout, must not destroy an install's value for a key it does
not know.

Carry-forward reads the store at `save()` rather than reusing what `load()`
found, so it protects the keys of *the store being written* at the moment it is
written. That matters in two cases the snapshot would get wrong: a holder that
has been pointed at a **different store** must not deposit the first store's
keys into the second (nor destroy the second's own), and a key written by
**someone else since this holder loaded** must be carried forward rather than
deleted — which is exactly the loss the mechanism exists to prevent.

**Changing the store discards the loaded snapshot but not the settings.** A
snapshot describes the store it came from, so assigning a different store drops
it; the settings keep their current values, because a swap is not a load. Call
`load()` to adopt the new store's overrides.

**Saving is explicit.** There is no autosave: persisting is asynchronous, and a
setter that silently starts an unawaited write gives the caller no way to know
whether it landed, no way to handle failure, and one write per keystroke when a
settings screen is bound field-by-field.

## Error Keys

Every failure is a `TomClientConfigurationException` (a `TomClientException`)
with a stable dotted `key`, so callers branch on the code rather than on message
text:

| Key | Raised when |
| --- | ----------- |
| `client_configuration.store.not_configured` | `load()`/`save()` with no store wired |
| `client_configuration.value.type_mismatch` | A config or stored value cannot be read as the declared type |
| `client_configuration.key.duplicate` | The same key is declared twice |
| `client_configuration.key.unknown` | `reset`/`isOverridden` on an undeclared key |
| `client_configuration.store.unsupported_platform` | A file store on a target without a filesystem |
| `client_configuration.store.invalid_content` | The store holds content that is not a readable override map |

Two failures reached from this module deliberately carry a **foreign** key,
because the rule behind each belongs to another module and restating it here
would create a second spelling that could disagree with the first:

| Key | Raised when | Owner |
| --- | ----------- | ----- |
| `preferences.key.invalid` | A setting declared `overridableBy` anything but `none` carries a name the preference stores would refuse | `TomUserPreferenceKeys` |
| `resources.config_provider.not_installed` | A holder is constructed before the application's config provider is installed | `TomConfigResourceProvider` |

The second is a **construction-order** failure, and it is loud on purpose.
`declareSettings()` runs from the constructor and resolves every baseline
against the shipped resources, so a holder built first would serve declared
defaults that look configured. An application with no configuration bundle
installs an empty provider —
`TomConfigResourceProvider.setAppConfigProvider(TomConfigResourceProvider.from({}))`
— rather than installing none.

## Limitations

- **Four value types.** `String`, `int`, `double`, `bool`. A structured value
  belongs in the config resources, not in a per-install override.
- **The baseline is fixed at declaration.** Replacing the config provider
  afterwards does not move it — a baseline that shifted under a running app
  would make "is this overridden?", and therefore what gets persisted, depend on
  when you asked.
- **No web file store.** See `client_configuration.store.unsupported_platform`
  above; supply a browser-appropriate store explicitly.
- **An install cannot pin a setting to the value it sees today.** Only overrides
  are stored, and a stored value that merely *equals* the baseline is not one:
  it survives `load()` — it is applied, and it is the right value — and is
  deleted by the next `save()`, after which the setting follows whatever the
  shipped default becomes. There is no error and no signal. "Keep this build's
  refresh interval whatever the next update ships" is a real operation, and the
  module silently turns it into its opposite. Pinning would need a third state
  per setting — untouched / set-to-baseline / overridden — and a store format
  able to carry it; the override-only design is deliberate and is what lets a
  shipped default still move, so this is the price of it rather than an
  oversight. `hasUnsavedChanges` agrees with `save()` about such a key and does
  not report an untouched holder as dirty because of one.
- **No autosave.** `save()` is the only write path, so a screen that changes a
  setting and is dismissed without calling it loses the change on the next
  start. What the holder *can* do is answer whether that would happen — see
  [Unsaved changes](#unsaved-changes) — so the warning is the caller's to show,
  not the caller's to derive.
- **No per-field validation, and no hook to add one.** The type is enforced, the
  value is not: `-1` is an acceptable refresh interval and `''` an acceptable
  server URL. `TomSetting`'s constructor is private, so a validating subclass
  cannot be substituted — range, format and enum checks are the caller's, after
  `load()` or at the point of use.
- **Two holders must not share a store location.** `save()` writes *this
  holder's* complete override set for the keys it declares, plus whatever it
  found in the store under keys it does not. The carry-forward therefore
  protects a key another **build** owns — and does not protect a key both
  holders declare. A second holder that has not adopted the first's change
  holds that key at its baseline, so its view is "this install has no override"
  and that is what it writes: the first holder's value is erased, sequentially,
  with no concurrency involved. Reloading before every save avoids it; nothing
  enforces that, and nothing reports it.

  The narrower concurrency window stays open on top of that. Read-then-write is
  not a single operation, so two saves that genuinely overlap lose the earlier
  reader's change even if both reloaded, and nothing notices: there is no
  version stamp in the persisted document and `save()` cannot fail on a
  conflict.

  Both are accepted rather than guarded. A client configuration is scoped to
  (this app, this machine), so two holders over one location are two sources of
  truth for the same keys, and no merge rule reconciles them without changing
  what `save()` means: writing only the keys this holder *changed* would keep
  the other's value, at the cost of a `save()` that is no longer idempotent
  against an externally edited store and a holder that can disagree with it
  silently.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:convert` | dart | `file_configuration_store_io.dart` | `jsonDecode`, `jsonEncode` |
| `dart:io` | dart | `environment_reader_io.dart`, `file_configuration_store_io.dart` | `File`, `Platform` |
| `tom_core_kernel` | package | `client_configuration.dart`, `client_configuration_store.dart` | `TomObservable` / `TomObject` (the observation substrate), `TomConfigResourceProvider` (the shipped config layer), `TomException` |
| [little_things](little_things.md) | module | `client_configuration_store.dart` | `TomClientException` |
