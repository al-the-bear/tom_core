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
| `stringSetting` | `TomSetting<String> stringSetting(String key, String declaredDefault)` | Declares a `String` setting. |
| `intSetting` | `TomSetting<int> intSetting(String key, int declaredDefault)` | Declares an `int` setting. |
| `doubleSetting` | `TomSetting<double> doubleSetting(String key, double declaredDefault)` | Declares a `double` setting. |
| `boolSetting` | `TomSetting<bool> boolSetting(String key, bool declaredDefault)` | Declares a `bool` setting. |
| `load` | `Future<void> load()` | Adopts the persisted overrides; idempotent; one notification. |
| `save` | `Future<void> save()` | Persists the overrides only; carries forward undeclared persisted keys. |
| `settingFor` | `TomSetting? settingFor(String key)` | The setting declared under `key`, or `null`. |
| `isOverridden` | `bool isOverridden(String key)` | Whether that setting differs from its baseline. |
| `reset` | `void reset(String key)` | Drops the override for `key` (in memory). |
| `resetAll` | `void resetAll()` | Drops every override; one notification. |
| `onNotify` | `void onNotify(TomObservable observable)` | Re-emits a member setting's change as a holder change. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomClientConfigurationStore?` | Where overrides are persisted; assignable after construction. |
| `settings` | `Map<String, TomSetting>` | Every declared setting, keyed by dotted key (unmodifiable). |
| `hasOverrides` | `bool` | Whether any setting differs from its baseline. |

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
| `isOverridden` | `bool` | `get() != baseline`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `reset` | `void reset()` | Restores `baseline`. |
| `applyRaw` | `void applyRaw(Object? raw)` | Coerces a store/config-shaped value to `T` and sets it. |

### TomClientConfigurationStore

Abstract, two-method interface for where overrides are persisted.

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

Writes via write-then-rename; deletes the file on an empty write. On a target
without `dart:io` the same name resolves to a variant that **throws on
construction** with `client_configuration.store.unsupported_platform`.

### TomClientConfigurationException

Failures of this module.

- **Extends:** `TomClientException`

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
