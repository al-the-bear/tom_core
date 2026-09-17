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
  - [TomClientEnvironment](#tomclientenvironment)
  - [TomClientConfigurationStore](#tomclientconfigurationstore)
  - [TomMemoryClientConfigurationStore](#tommemoryclientconfigurationstore)
  - [TomFileClientConfigurationStore](#tomfileclientconfigurationstore)
  - [TomClientConfigurationException](#tomclientconfigurationexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomclient/configuration/client_configuration.dart`,
`client_configuration_store.dart`, `file_configuration_store.dart`.

A `TomBaseClientConfiguration` subclass declares its settings in
`declareSettings()` (called from the base constructor). Each setting resolves
to the shipped config-resources value for its dotted key, else the declared
default — that pair is the setting's **baseline**. `load()` layers this
install's persisted overrides on top; `save()` writes back exactly the settings
that differ from their baseline. Scope is **(client app, machine)**: there is no
user parameter anywhere in the module.

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
| `stringSetting` | `TomSetting<String> stringSetting(String key, String declaredDefault, {String? envAlias})` | Declares a `String` setting. `envAlias` names an environment variable that, when set, supplies the value and takes the setting out of the install's hands — layer 0 of the resolution order. |
| `intSetting` | `TomSetting<int> intSetting(String key, int declaredDefault)` | Declares an `int` setting. |
| `doubleSetting` | `TomSetting<double> doubleSetting(String key, double declaredDefault, {String? envAlias})` | Declares a `double` setting. `envAlias` names an environment variable that, when set, supplies the value and takes the setting out of the install's hands — layer 0 of the resolution order. |
| `boolSetting` | `TomSetting<bool> boolSetting(String key, bool declaredDefault, {String? envAlias})` | Declares a `bool` setting. `envAlias` names an environment variable that, when set, supplies the value and takes the setting out of the install's hands — layer 0 of the resolution order. |
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
| `isOverridden` | `bool` | `!isFromEnvironment && get() != baseline`. An operator's variable is not the install's override, and reporting it as one would have `save` bake it into the store. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `reset` | `void reset()` | Restores the value the setting has with no install override: `baseline`, or the **environment's** value when `isFromEnvironment`. |
| `applyRaw` | `void applyRaw(Object? raw)` | Coerces a store/config-shaped value to `T` and sets it. |
| `toString` | `String toString()` | `'key=value'`, with ` (overridden)` appended when it is. |

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
| `write` | `Future<void> write(Map<String, Object?> values)` | Replaces the persisted map, all-or-nothing. An empty map clears. |

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
That matters for `stack`: the field on `TomBaseException` is `Object?`, but
`TomException`'s constructor narrows it to `StackTrace?`, so that is what a
caller may pass here. `autoLog` is non-nullable and defaults to `false`; the
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

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `coerceSettingValue` | `T coerceSettingValue<T>(String key, Object? raw)` | Reads a loosely-typed external value as `T` (exact type, `int`→`double`, parseable `String`), else throws `client_configuration.value.type_mismatch`. |
