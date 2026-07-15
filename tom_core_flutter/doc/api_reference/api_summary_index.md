# Tom Core Flutter API Reference: Index

Per-module API summaries for `tom_core_flutter` — the Flutter extension layer of
Tom Core. It re-exports all of `tom_core_kernel` (see that package's docs for
the kernel API) and adds the Flutter-specific surface documented here.

> `tom_core_flutter` also re-exports `tom_reflection` and its generated code.
> Those APIs are documented in the `tom_reflection` package.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Forms | [api_summary_forms.md](api_summary_forms.md) | Legacy observable form fields + form aggregate (`TomFieldOld`, `TomFormOld`). |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | Client-side exception types (`TomClientException`, `TomClientUIException`). |
| Observing | [api_summary_observing.md](api_summary_observing.md) | Kernel-observable → Flutter bridges (`TomObservingWidget`, `ValueListenableObserver`). |
| Resources | [api_summary_resources.md](api_summary_resources.md) | Typed config properties (`TomProperty` and typed subclasses). |
| Runtime | [api_summary_runtime.md](api_summary_runtime.md) | Compile-time platform selection (`clientPlatformUtils`, `TomFlutterPlatformUtils`). |
| Security | [api_summary_security.md](api_summary_security.md) | Client 2FA annotation (`TomClient2FAAdaptor`). |

## Modules

### Forms (`lib/src/tomclient/forms/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomFieldOld<T>` | class | Observable form field resolving text from kernel resources. |
| `TomEmailField<T>` | class | Field with a built-in e-mail validator. |
| `TomPasswordField<T>` | class | Field with a built-in password validator (`obscureText` default `true`). |
| `TomFormOld` | class | Observable collection of fields with form-wide validate/save/errors. |

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
| `clientPlatformUtils` | getter | Fresh `TomPlatformUtils` for the current Flutter target. |
| `allowsBadCertificateForHost` | function | *(native variant)* Loopback-only bad-cert TLS predicate. |
| `TomFlutterPlatformUtils` | class | Flutter platform utils (io / web / neutral compile-time variants). |

### Security (`lib/src/tomclient/security/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomClient2FAAdaptor` | class | Annotation declaring a client 2FA adaptor's mechanism. |

## Alphabetical Type Index

| Type | Module |
| ---- | ------ |
| `allowsBadCertificateForHost` | Runtime |
| `clientPlatformUtils` | Runtime |
| `TomBoolProperty` | Resources |
| `TomClient2FAAdaptor` | Security |
| `TomClientException` | Little Things |
| `TomClientUIException` | Little Things |
| `TomDoubleProperty` | Resources |
| `TomEmailField<T>` | Forms |
| `TomFieldOld<T>` | Forms |
| `TomFlutterPlatformUtils` | Runtime |
| `TomFormOld` | Forms |
| `TomIntProperty` | Resources |
| `TomObservingWidget<T>` | Observing |
| `TomObservingWidgetState<T>` | Observing |
| `TomPasswordField<T>` | Forms |
| `TomProperty<T>` | Resources |
| `TomStringProperty` | Resources |
| `ValueListenableObserver<T>` | Observing |
