# Tom Core Flutter API Reference: Index

Per-module API summaries for `tom_core_flutter` — the Flutter extension layer of
Tom Core. It re-exports all of `tom_core_kernel` (see that package's docs for
the kernel API) and adds the Flutter-specific surface documented here.

> `tom_core_flutter` also re-exports `tom_reflection` and its generated code.
> Those APIs are documented in the `tom_reflection` package.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Configuration | [api_summary_configuration.md](api_summary_configuration.md) | Machine-scoped client settings (`TomBaseClientConfiguration`, `TomSetting`, stores) and their composition with the narrower preference scopes. |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | Client-side exception types (`TomClientException`, `TomClientUIException`). |
| Observing | [api_summary_observing.md](api_summary_observing.md) | Kernel-observable → Flutter bridges (`TomObservingWidget`, `ValueListenableObserver`). |
| Preferences | [api_summary_preferences.md](api_summary_preferences.md) | Device-stored preferences (`TomDevicePreferences`, per-platform stores) and the account store's client (`TomUserPreferencesClient`). |
| Resources | [api_summary_resources.md](api_summary_resources.md) | Typed config properties (`TomProperty` and typed subclasses). |
| Runtime | [api_summary_runtime.md](api_summary_runtime.md) | Compile-time platform selection (`clientPlatformUtils`). |
| Security | [api_summary_security.md](api_summary_security.md) | The client second-factor flow (`Tom2FAFlowPanel`, `Tom2FAFlowController`), its pluggable mechanism registry and the shipped TOTP mechanism. |

## Modules

### Configuration (`lib/src/tomclient/configuration/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomBaseClientConfiguration` | abstract class | Abstract holder of one install's machine-scoped settings. |
| `TomSetting<T>` | class | One observable, addressable setting (`TomObject<T>` + key + baseline). |
| `TomClientEnvironment` | abstract class | Where a setting's `envAlias` is looked up; the reader is replaceable. Statics only. |
| `TomOverridableBy` | enum | Which narrower client scope, if any, may shadow a setting — `none` / `user` / `device`. |
| `TomEffectiveSettings` | class | Reads a setting together with the preference scopes it opens itself to. |
| `TomPreferenceLookup` | typedef | `Future<T?> Function<T extends Object>(String key)` — the one-key read both preference stores carry. |
| `TomClientConfigurationStore` | abstract class | Two-method (`read`/`update`) interface for persisting overrides. |
| `TomMemoryClientConfigurationStore` | class | Process-lifetime override store. |
| `TomFileClientConfigurationStore` | class | JSON file store (io variant; neutral variant throws). |
| `TomClientConfigurationException` | class | Module failures, keyed by stable dotted codes. |
| `coerceSettingValue` | function | Reads a loosely-typed external value as the declared type. |
| `readPlatformEnvironment` | function | The default environment reader — the process environment under `dart:io`, nothing elsewhere. |

### Little Things (`lib/src/tomclient/little_things/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomClientException` | class | Client-side subtype of the kernel `TomException`. |
| `TomClientUIException` | class | Client exception whose message is safe to show in the UI. |

### Observing (`lib/src/tomclient/observing/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomObservingWidget<T>` | class | Widget that rebuilds when its observable `subState` notifies. |
| `TomObservingWidgetState<T>` | class | `State` managing the observer lifecycle. |
| `ValueListenableObserver<T>` | class | Adapts a `TomObservable` to Flutter's `ValueListenable`. |

### Preferences (`lib/src/tomclient/preferences/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDevicePreferences` | class | The device-preferences interface; typed `get` / `set`, `getPreferred` precedence, bean-resolved. |
| `TomStoredDevicePreferences` | class | The shipped implementation — the typed API over a store. |
| `TomDevicePreferenceStore` | class | Two-method (`read`/`write`) backend interface; the only platform-specific part. |
| `TomMemoryDevicePreferenceStore` | class | Process-lifetime device store. |
| `TomPlatformDevicePreferenceStore` | class | Compile-time selected backend (file / `localStorage` / loud failure). |
| `TomDevicePreferenceStoreConflictDetection` | mixin | Detects a write over a document other than the one the store last saw; used by the three shipped backends. |
| `TomEncryptedDevicePreferenceStore` | class | Encrypts preference values through a `TomDevicePreferenceCipher` and delegates storage to another store. |
| `TomDevicePreferenceCipher` | abstract class | The encrypt/decrypt pair an application supplies to the encrypted store. |
| `TomDevicePreferenceJson` | class | The stored JSON document, written once for every persistent backend. |
| `TomDevicePreferenceException` | class | Module failures, keyed by stable dotted codes. |
| `TomUserPreferencesClient` | class | The account store: the same method set over the server's `/preferences/*` contract, addressed from the endpoint declarations. |
| `TomUserPreferencesClientException` | class | Client-side failures, keyed by stable dotted codes. |

### Resources (`lib/src/tomclient/resources/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomProperty<T>` | class | Typed config value resolved and cached at construction. |
| `TomStringProperty` | class | `String` config property. |
| `TomIntProperty` | class | `int` config property. |
| `TomDoubleProperty` | class | `double` config property. |
| `TomBoolProperty` | class | `bool` config property. |
| `TomPropertyException` | class | Both failures of a typed property, told apart by `key`. |

### Runtime (`lib/src/tomclient/runtime/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `clientPlatformUtils` | getter | The `TomPlatformUtils` for the current Flutter target — one instance per process, built on first read. |
| `resetClientPlatformUtils` | function | *(`@visibleForTesting`)* Discards the built instance so the next read constructs again. |
| `TomBadCertificatePolicy` | final class | The hosts whose unverified TLS certificate the native client accepts — both loopback families by default; replaceable, and a replacement is logged. |
| `TomFlutterPlatformUtils` | class | *(**not exported** — import from `src/`)* Flutter platform utils (io / web / neutral compile-time variants). |

### Security (`lib/src/tomclient/security/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `Tom2FAFlowPanel` | class | Renders whichever stop of a second-factor login the controller reports — chooser, enrolment or challenge. |
| `Tom2FAFlowController` | abstract class | The seam an application implements over its own auth client: five moves, two pieces of read-only state. |
| `Tom2FAClientMechanism` | abstract class | One mechanism's client-side rendering, paired with its server adaptor by mechanism key alone. |
| `Tom2FAClientRegistry` | class | The process-wide mechanism catalog the flow dispatches through; entirely static. |
| `Tom2FAEnrolmentPanelContext` | class | What an enrolment panel is given to render itself. |
| `Tom2FAChallengePanelContext` | class | What a challenge panel is given to render itself. |
| `TomTotp2FAClientMechanism` | class | The shipped authenticator-app mechanism, registered under `'totp'`. |
| `TomWebAuthn2FAClientMechanism` | class | The shipped passkey mechanism, registered under `'webauthn'` where a platform authenticator exists. |
| `TomWebAuthnPlatform` | abstract class | The seam to whatever makes passkeys on this target — the browser on the web. |
| `TomUnavailableWebAuthnPlatform` | class | The binding for a target with no passkey support. |
| `TomWebAuthnPlatformException` | class | A passkey ceremony the platform could not complete. |
| `Tom2FATexts` | class | Every resource key the second-factor UI resolves, and the helpers that resolve them; entirely static. |
| `TomQrCodeView` | class | A QR code painted from the pure-Dart `qr` encoder, re-encoded only when its payload changes. |

## Alphabetical Type Index

| Type | Module |
| ---- | ------ |
| `clientPlatformUtils` | Runtime |
| `coerceSettingValue` | Configuration |
| `readPlatformEnvironment` | Configuration |
| `resetClientPlatformUtils` | Runtime |
| `Tom2FAChallengePanelContext` | Security |
| `Tom2FAClientMechanism` | Security |
| `Tom2FAClientRegistry` | Security |
| `Tom2FAEnrolmentPanelContext` | Security |
| `Tom2FAFlowController` | Security |
| `Tom2FAFlowPanel` | Security |
| `Tom2FATexts` | Security |
| `TomBadCertificatePolicy` | Runtime |
| `TomBaseClientConfiguration` | Configuration |
| `TomBoolProperty` | Resources |
| `TomClientConfigurationException` | Configuration |
| `TomClientConfigurationStore` | Configuration |
| `TomClientEnvironment` | Configuration |
| `TomClientException` | Little Things |
| `TomClientUIException` | Little Things |
| `TomDevicePreferenceCipher` | Preferences |
| `TomDevicePreferenceException` | Preferences |
| `TomDevicePreferenceJson` | Preferences |
| `TomDevicePreferences` | Preferences |
| `TomDevicePreferenceStore` | Preferences |
| `TomDevicePreferenceStoreConflictDetection` | Preferences |
| `TomDoubleProperty` | Resources |
| `TomEffectiveSettings` | Configuration |
| `TomEncryptedDevicePreferenceStore` | Preferences |
| `TomFileClientConfigurationStore` | Configuration |
| `TomFlutterPlatformUtils` | Runtime (internal — not exported) |
| `TomIntProperty` | Resources |
| `TomMemoryClientConfigurationStore` | Configuration |
| `TomMemoryDevicePreferenceStore` | Preferences |
| `TomObservingWidget<T>` | Observing |
| `TomObservingWidgetState<T>` | Observing |
| `TomOverridableBy` | Configuration |
| `TomPlatformDevicePreferenceStore` | Preferences |
| `TomPreferenceLookup` | Configuration |
| `TomProperty<T>` | Resources |
| `TomPropertyException` | Resources |
| `TomQrCodeView` | Security |
| `TomSetting<T>` | Configuration |
| `TomStoredDevicePreferences` | Preferences |
| `TomStringProperty` | Resources |
| `TomTotp2FAClientMechanism` | Security |
| `TomUnavailableWebAuthnPlatform` | Security |
| `TomUserPreferencesClient` | Preferences |
| `TomUserPreferencesClientException` | Preferences |
| `TomWebAuthn2FAClientMechanism` | Security |
| `TomWebAuthnPlatform` | Security |
| `TomWebAuthnPlatformException` | Security |
| `ValueListenableObserver<T>` | Observing |
