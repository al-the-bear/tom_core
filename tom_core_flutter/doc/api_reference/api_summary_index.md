# Tom Core Flutter API Reference: Index

Per-module API summaries for `tom_core_flutter` — the Flutter extension layer of
Tom Core. It re-exports all of `tom_core_kernel` (see that package's docs for
the kernel API) and adds the Flutter-specific surface documented here.

> `tom_core_flutter` also re-exports `tom_reflection` and its generated code.
> Those APIs are documented in the `tom_reflection` package.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Configuration | [api_summary_configuration.md](api_summary_configuration.md) | Machine-scoped client settings (`TomBaseClientConfiguration`, `TomSetting`, stores). |
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
| `TomBaseClientConfiguration` | class | Abstract holder of one install's machine-scoped settings. |
| `TomSetting<T>` | class | One observable, addressable setting (`TomObject<T>` + key + baseline). |
| `TomClientEnvironment` | abstract class | Where a setting's `envAlias` is looked up; the reader is replaceable. Statics only. |
| `TomClientConfigurationStore` | class | Two-method (`read`/`write`) interface for persisting overrides. |
| `TomMemoryClientConfigurationStore` | class | Process-lifetime override store. |
| `TomFileClientConfigurationStore` | class | JSON file store (io variant; neutral variant throws). |
| `TomClientConfigurationException` | class | Module failures, keyed by stable dotted codes. |
| `coerceSettingValue` | function | Reads a loosely-typed external value as the declared type. |

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

### Runtime (`lib/src/tomclient/runtime/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `clientPlatformUtils` | getter | Fresh `TomPlatformUtils` for the current Flutter target. The module's only exported symbol. |
| `allowsBadCertificateForHost` | function | *(native variant, **not exported** — import from `src/`)* Loopback-only bad-cert TLS predicate. |
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
| `Tom2FATexts` | class | Every resource key the second-factor UI resolves, and the helpers that resolve them; entirely static. |
| `TomQrCodeView` | class | A QR code painted from the pure-Dart `qr` encoder, re-encoded only when its payload changes. |

## Alphabetical Type Index

| Type | Module |
| ---- | ------ |
| `allowsBadCertificateForHost` | Runtime (internal — not exported) |
| `clientPlatformUtils` | Runtime |
| `coerceSettingValue` | Configuration |
| `Tom2FAChallengePanelContext` | Security |
| `Tom2FAClientMechanism` | Security |
| `Tom2FAClientRegistry` | Security |
| `Tom2FAEnrolmentPanelContext` | Security |
| `Tom2FAFlowController` | Security |
| `Tom2FAFlowPanel` | Security |
| `Tom2FATexts` | Security |
| `TomBaseClientConfiguration` | Configuration |
| `TomBoolProperty` | Resources |
| `TomClientConfigurationException` | Configuration |
| `TomClientConfigurationStore` | Configuration |
| `TomClientEnvironment` | Configuration |
| `TomClientException` | Little Things |
| `TomClientUIException` | Little Things |
| `TomDevicePreferenceException` | Preferences |
| `TomDevicePreferenceJson` | Preferences |
| `TomDevicePreferences` | Preferences |
| `TomDevicePreferenceStore` | Preferences |
| `TomDoubleProperty` | Resources |
| `TomFileClientConfigurationStore` | Configuration |
| `TomFlutterPlatformUtils` | Runtime (internal — not exported) |
| `TomIntProperty` | Resources |
| `TomMemoryClientConfigurationStore` | Configuration |
| `TomMemoryDevicePreferenceStore` | Preferences |
| `TomObservingWidget<T>` | Observing |
| `TomObservingWidgetState<T>` | Observing |
| `TomPlatformDevicePreferenceStore` | Preferences |
| `TomProperty<T>` | Resources |
| `TomQrCodeView` | Security |
| `TomSetting<T>` | Configuration |
| `TomStoredDevicePreferences` | Preferences |
| `TomStringProperty` | Resources |
| `TomTotp2FAClientMechanism` | Security |
| `TomUserPreferencesClient` | Preferences |
| `TomUserPreferencesClientException` | Preferences |
| `ValueListenableObserver<T>` | Observing |
