# forms

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

The original (legacy) form primitives of `tom_core_flutter`: an observable
field (`TomFieldOld`) that binds a kernel value to a Flutter `TextField` with
validators and resource-resolved labels, and a form aggregate (`TomFormOld`)
that groups fields for form-wide validate/save.

> **Superseded.** New UI work should use the richer `TomForm` framework in
> [`tom_flutter_ui`](../../../../../tom_flutter_ui/README.md). These `Old`-suffixed
> types are retained for existing consumers (e.g. `tom_uam_client`).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomFieldOld<T>` | Observable field; wraps a kernel `TomObject<T>`, owns a `TextEditingController`, runs input/value validators, and resolves label/pattern/error keys (`<form>.<field>.…`) from the text resources. |
| `TomEmailField<T>` | `TomFieldOld` preset for e-mail entry. |
| `TomPasswordField<T>` | `TomFieldOld` preset with `obscureText` on. |
| `TomFormOld` | Observable map (field-name → field) extending the kernel `TomMap`; offers form-wide `validate()`, `save()`, `errors()`, and per-field widget builders. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  // Fields resolve their labels/patterns by key, so a text provider must exist.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from({'login.email.label': 'E-mail'}),
  );

  final email = TomEmailField<String>('login', 'email', '');

  email | 'user@example.com'; // set via the observable operator
  print(~email);              // prints: user@example.com

  final form = TomFormOld({'email': email});
  print(form.validate());     // true — all field validators pass
}
```

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
