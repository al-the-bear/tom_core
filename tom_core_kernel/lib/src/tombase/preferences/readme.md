# preferences

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The **wire contract** for server-stored user preferences: the DTOs, the value
codec, the well-known key vocabulary, and the `TomApi` declaration the server
binds its endpoints to. The *store* lives in `tom_core_server`
(`preferences/`); what lives here is everything a client and a server must
agree on, in the one package they both already depend on.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomUserPreferenceKeys` | The keys the framework itself reads (`tom.timezone`, `tom.language`, …) |
| `TomUserPreferenceDto` | One preference on the wire: key, value type, JSON value, `updatedAt` |
| `TomUserPreferenceWriteRequest` / `TomUserPreferenceKeyRequest` | The typed request DTOs |
| `TomUserPreferenceCodec` | Encodes/decodes scalars and reflected objects; refuses a type-mismatched read |
| `tomUserPreferencesApi` | The `TomApi`: `GET`/`PUT`/`DELETE` under `/preferences`, all `TomAuthenticatedAccess` |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // A value carries its own type across the wire, so a mismatched read fails
  // loudly instead of coercing.
  final dto = TomUserPreferenceCodec.encode(
    TomUserPreferenceKeys.timezone,
    'Europe/Berlin',
  );
  print(dto.valueType);                              // String
  print(TomUserPreferenceCodec.decode<String>(dto)); // Europe/Berlin
}
```

Only `TomAuthenticatedAccess` is declared on the endpoints: *which* rows a
caller reaches is not an endpoint-level question. The server's entity carries
`@TomDbScope(field: 'principal_id')`, so the repository confines every read and
write to the caller's own preferences.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
