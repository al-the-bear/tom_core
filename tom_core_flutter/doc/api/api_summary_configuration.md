# Tom Core Flutter API Reference: Configuration Module

The machine-scoped configuration of a client install: an observable settings
holder that resolves from the shipped config resources and persists only the
install's overrides.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomBaseClientConfiguration](#tombaseclientconfiguration)
  - [TomSetting&lt;T&gt;](#tomsettingt)
  - [TomOverridableBy](#tomoverridableby)
  - [TomEffectiveSettings](#tomeffectivesettings)
  - [TomPreferenceLookup](#tompreferencelookup)
  - [TomClientEnvironment](#tomclientenvironment)
  - [TomClientConfigurationStore](#tomclientconfigurationstore)
  - [TomMemoryClientConfigurationStore](#tommemoryclientconfigurationstore)
  - [TomFileClientConfigurationStore](#tomfileclientconfigurationstore)
  - [TomClientConfigurationException](#tomclientconfigurationexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomclient/configuration/client_configuration.dart`,
`lib/src/tomclient/configuration/client_configuration_store.dart`,
`lib/src/tomclient/configuration/effective_settings.dart`,
`lib/src/tomclient/configuration/environment_reader.dart` with its variants
`lib/src/tomclient/configuration/environment_reader_io.dart` and
`lib/src/tomclient/configuration/environment_reader_neutral.dart`,
`lib/src/tomclient/configuration/file_configuration_store.dart` with its
variants `lib/src/tomclient/configuration/file_configuration_store_io.dart` and
`lib/src/tomclient/configuration/file_configuration_store_neutral.dart`.

`environment_reader.dart` and `file_configuration_store.dart` each export one of
their two variants by conditional export, chosen by whether `dart:io` exists.

A `TomBaseClientConfiguration` subclass declares its settings in
`declareSettings()` (called from the base constructor). Each setting resolves
to the shipped config-resources value for its dotted key, else the declared
default — that pair is the setting's **baseline**. `load()` layers this
install's persisted overrides on top; `save()` writes back exactly the settings
that differ from their baseline. Scope is **(client app, machine)**: there is no
user parameter anywhere in the module.

A setting may nevertheless declare that a narrower scope is allowed to shadow
it — `TomOverridableBy` — and `TomEffectiveSettings` reads the install's value
and the two preference stores as one value. The permission is authored on the
setting; the stores arrive as callbacks and neither is a dependency.

## Class Hierarchy

```
TomObservable  (kernel)
    ├── TomBaseClientConfiguration    (abstract; also a TomObserver)
    └── TomObject<T>  (kernel)
            └── TomSetting<T>

TomClientConfigurationStore          (abstract)
    ├── TomMemoryClientConfigurationStore
    └── TomFileClientConfigurationStore   (compile-time io / neutral variant)

TomException → TomClientException → TomClientConfigurationException

TomEffectiveSettings                 (composes the three client scopes)
TomOverridableBy                     (enum: none / user / device)
```

## Classes

### TomBaseClientConfiguration

Abstract base for a client app's machine-scoped settings holder.

- **Extends:** `TomObservable`
- **Implements:** `TomObserver<TomObservable>`

#### Constructors

| Constructor | Signature | Description |
| ----------- | --------- | ----------- |
| default | `TomBaseClientConfiguration({TomClientConfigurationStore? store})` | Wires the store (optional) and calls `declareSettings()`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `declareSettings` | `void declareSettings()` | **Abstract.** Declares every setting; called from the constructor. |
| `stringSetting` | `TomSetting<String> stringSetting(String key, String declaredDefault, {String? envAlias, TomOverridableBy overridableBy = TomOverridableBy.none})` | Declares a `String` setting. `envAlias` names an environment variable that, when set, supplies the value and takes the setting out of the install's hands — layer 0 of the resolution order. `overridableBy` opens the key to a narrower client scope; the default is the closed arm. |
| `intSetting` | `TomSetting<int> intSetting(String key, int declaredDefault, {String? envAlias, TomOverridableBy overridableBy = TomOverridableBy.none})` | Declares an `int` setting. Same two arguments, same meanings. |
| `doubleSetting` | `TomSetting<double> doubleSetting(String key, double declaredDefault, {String? envAlias, TomOverridableBy overridableBy = TomOverridableBy.none})` | Declares a `double` setting. Same two arguments, same meanings. |
| `boolSetting` | `TomSetting<bool> boolSetting(String key, bool declaredDefault, {String? envAlias, TomOverridableBy overridableBy = TomOverridableBy.none})` | Declares a `bool` setting. Same two arguments, same meanings. |
| `load` | `Future<void> load()` | Adopts the persisted overrides; idempotent; one notification. |
| `save` | `Future<void> save()` | Persists the overrides only; carries forward undeclared persisted keys. |
| `settingFor` | `TomSetting? settingFor(String key)` | The setting declared under `key`, or `null`. |
| `isOverridden` | `bool isOverridden(String key)` | Whether that setting differs from its baseline. |
| `reset` | `void reset(String key)` | Drops the override for `key` (in memory). |
| `resetAll` | `void resetAll()` | Drops every override; one notification. |
| `onNotify` | `void onNotify(TomObservable observable)` | Re-emits a member setting's change as a holder change. |
| `toString` | `String toString()` | `'$runtimeType(...)'` over every declared setting, comma-separated. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomClientConfigurationStore?` | Where overrides are persisted; assignable after construction. |
| `settings` | `Map<String, TomSetting>` | Every declared setting, keyed by dotted key (unmodifiable). |
| `hasOverrides` | `bool` | Whether any setting differs from its baseline. **Not a dirty flag** — a setting `load` adopted from the store is already overridden with nothing unsaved. |
| `hasUnsavedChanges` | `bool` | Whether `save` would write something other than what the store last held — a value changed, an override added, or an override dropped. The dirty flag a settings screen asks before it lets itself be dismissed. Reads no store: the comparison is against the snapshot the last `load` or `save` took, so it is answerable in a build. Keys this build does not declare are never unsaved, since `save` carries them forward untouched. With no store wired any override reads as unsaved. A persisted value that merely equals the baseline is not an override — `save` drops it and this does not report it — so an untouched holder that loaded one is not dirty. |

### TomSetting&lt;T&gt;

One observable, addressable setting.

- **Extends:** `TomObject<T>` — so `get()`, `set()`, `~`, `|`, `<<`, `call()`,
  `addObserver` and `TomObservingWidget` all apply.
- **Construction:** only via the holder's `*Setting` declaration methods.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The dotted configuration key — the setting's identity. |
| `declaredDefault` | `T` | The default written at the declaration site. |
| `baseline` | `T` | The value when the install has not overridden it. |
| `envAlias` | `String?` | The environment variable this setting may also be read from, verbatim; `null` when it is declared without one. |
| `isFromEnvironment` | `bool` | Whether `TomClientEnvironment` supplied the value. Such a setting is not loaded, not saved and not overridden; `reset` restores the operator's value. A settings screen reads this to disable the field — the setter is not taken away, since a `TomSetting` is a `TomObject`. |
| `overridableBy` | `TomOverridableBy` | Which narrower client scope may shadow this setting. Declared here, at the wider scope, and applied by `TomEffectiveSettings.valueOf`; it does not change what `get` answers. A setting that opens itself is validated against `TomUserPreferenceKeys` at declaration. |
| `isOverridden` | `bool` | `!isFromEnvironment && get() != baseline`. An operator's variable is not the install's override, and reporting it as one would have `save` bake it into the store. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `reset` | `void reset()` | Restores the value the setting has with no install override: `baseline`, or the **environment's** value when `isFromEnvironment`. |
| `applyRaw` | `void applyRaw(Object? raw)` | Coerces a store/config-shaped value to `T` and sets it. |
| `toString` | `String toString()` | `'key=value'`, with ` (overridden)` appended when it is. |

### TomOverridableBy

Which narrower client scope, if any, may shadow a `TomSetting`. Declared on the
setting — at the **wider** scope — so the relation is stated once and no
preference can open a key by itself. The value names the *narrowest* scope
permitted, and every scope between the setting and that one is permitted too.

| Value | Consulted, in order |
| ----- | ------------------- |
| `none` | the setting alone; no store is asked. The default on every declaration method, and the arm every security or infrastructure setting keeps. |
| `user` | the account store, then the setting. It does **not** open the device store: a value that should follow the account is not one a single device may fork. |
| `device` | the device store, the account store, then the setting. |

### TomEffectiveSettings

Reads a `TomSetting` together with the narrower scopes it opens itself to. The
one place the order between the three client scopes is written.

- **Extends:** none

#### Constructors

| Constructor | Signature | Description |
| ----------- | --------- | ----------- |
| default | `const TomEffectiveSettings({TomPreferenceLookup? fromUserStore, TomPreferenceLookup? fromDeviceStore})` | Composes the scopes reachable through the given lookups. Both are optional and independent; an omitted one is never consulted, so a holder built with neither resolves every setting to the install's value. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `fromUserStore` | `TomPreferenceLookup?` | Reads the signed-in user's server-stored preferences, or `null` when the application has no account store. |
| `fromDeviceStore` | `TomPreferenceLookup?` | Reads this device's preferences, or `null` when the application has no device store. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `valueOf` | `Future<T> valueOf<T extends Object>(TomSetting<T> setting)` | The narrowest store holding the key answers; failing that the next; failing all of them the setting's own value, which always exists. A `TomOverridableBy.none` setting is answered from the setting alone and costs no round trip. A preference stored under the key as a different type throws `TomUserPreferenceCodecException` from the store rather than falling through to the wider scope. |

There is no write path and no observation: a value is written by whichever
holder owns its scope, and a preference is a stored document with no change
notification, so an effective value has nothing to fire on when the narrower
scope moves.

### TomPreferenceLookup

```dart
typedef TomPreferenceLookup = Future<T?> Function<T extends Object>(String key);
```

Reads one key from a preference store; `null` means the store has never been
given that key. `TomDevicePreferences.get` and `TomUserPreferencesClient.get`
are each a `TomPreferenceLookup` as written, so an application passes the method
rather than an adapter. A callback rather than the store itself, so that an
application with no account store is not made to carry an HTTP client and one
with no device store is not made to carry a platform backend.

### TomClientEnvironment

Where a setting's `envAlias` is looked up. Abstract with a static-only surface.

A seam rather than a fixed source: `dart:io`'s process environment is right on a
desktop install and is what `reader` starts as, and it is absent everywhere else
— a browser has none, a mobile app is launched by the OS. Those platforms answer
"what did the operator configure" with a `--dart-define`, a value fetched at
startup or an MDM payload, and only the app knows which. Replace `reader`
**before** the holder is constructed: settings resolve their environment value at
declaration.

- **Extends:** none (abstract, static members only)

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `reader` | `String? Function(String name)` | Reads a variable, or answers `null` when it is not set. Defaults to the process environment where there is one. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `useDefaultReader` | `static void useDefaultReader()` | Restores the platform default, undoing an assignment to `reader`. |

### TomClientConfigurationStore

Abstract, two-method interface for where overrides are persisted.

#### Constructors

```dart
const TomClientConfigurationStore()
```

Allows `const` implementations. (The two shipped implementations are not
`const` — see `TomFileClientConfigurationStore` for why the file store cannot
be.)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `read` | `Future<Map<String, Object?>> read()` | The persisted override map; empty when nothing was persisted. |
| `update` | `Future<Map<String, Object?>> update(Map<String, Object?> Function(Map<String, Object?> current) change)` | Replaces the persisted map with what `change` makes of its current content, as one step no other update of the location interleaves with; returns what was persisted. All-or-nothing; a throwing `change` writes nothing; an empty result clears. |

### TomMemoryClientConfigurationStore

Process-lifetime store — tests, examples, deliberately stateless clients.

- **Extends:** `TomClientConfigurationStore`

```dart
TomMemoryClientConfigurationStore([Map<String, Object?>? initialValues])
```

### TomFileClientConfigurationStore

JSON file on the local filesystem, selected by conditional export.

- **Extends:** `TomClientConfigurationStore`

```dart
TomFileClientConfigurationStore(String path)
```

Not `const`, although the io variant alone could be: the neutral variant throws
from its constructor body and so cannot be, and one name behind a conditional
export must mean one signature on every target.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `path` | `String` | Absolute path of the JSON file holding the override map. |

Writes via write-then-rename; deletes the file on an empty write. On a target
without `dart:io` the same name resolves to a variant that **throws on
construction** with `client_configuration.store.unsupported_platform`.

### TomClientConfigurationException

Failures of this module.

- **Extends:** `TomClientException`

#### Constructors

```dart
TomClientConfigurationException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

See `TomException` (kernel) for the meaning of each argument. The types above are
the *kernel constructor's*, reached through Dart super-parameters — which resolve
against the immediate superclass, not against the field's original declaration.
The two can differ: `uuid`'s field is a non-nullable `late String` while the
parameter is `String?`, because omitting it is how a caller asks for a generated
one. `stack` is `StackTrace?`, the width `TomException`'s constructor declares.
`autoLog` is non-nullable and defaults to `false`; the
default is inherited too, so omitting it is not the same as passing `null` —
passing `null` does not compile.

| Key | Raised when |
| --- | ----------- |
| `client_configuration.store.not_configured` | `load`/`save` with no store wired |
| `client_configuration.value.type_mismatch` | A value cannot be read as the declared type |
| `client_configuration.key.duplicate` | The same key is declared twice |
| `client_configuration.key.unknown` | `reset`/`isOverridden` on an undeclared key |
| `client_configuration.store.unsupported_platform` | A file store without a filesystem |
| `client_configuration.store.invalid_content` | The store holds unreadable content |

Declaring a setting `overridableBy` anything but `none` under a name the
preference stores would refuse raises the preference vocabulary's own
`preferences.key.invalid`, from `TomUserPreferenceKeys` — restating it here
would create a second spelling that could disagree with the first.

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `readPlatformEnvironment` | `String? readPlatformEnvironment(String name)` | The default reader behind `TomClientEnvironment`: the process environment variable `name` where `dart:io` exists, and always `null` where it does not, so an `envAlias` is simply never set on the web. Chosen by conditional export. |
| `coerceSettingValue` | `T coerceSettingValue<T>(String key, Object? raw)` | Reads a loosely-typed external value as `T` (exact type, `int`→`double`, parseable `String`), else throws `client_configuration.value.type_mismatch`. |
