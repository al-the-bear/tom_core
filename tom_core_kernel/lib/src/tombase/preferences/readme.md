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
| `TomUserPreferenceKeys` | The keys the framework itself reads (`tom.timezone`, `tom.language`, …), and the rule every other key satisfies: 1–191 characters, starting with an ASCII letter, thereafter letters, digits, `.`, `_`, `-` |
| `TomUserPreferenceKeyException` | Raised by `TomUserPreferenceKeys.validate` for a key that breaks the rule; the endpoints answer it with a `400` |
| `TomUserPreferenceDto` | One preference on the wire: key, value type, JSON value, `updatedAt` |
| `TomUserPreferenceWriteRequest` / `TomUserPreferenceKeyRequest` | The typed request DTOs |
| `TomUserPreferenceCodec` | Encodes/decodes scalars and reflected objects; refuses a type-mismatched read, and a value over `maxValueBytes` (16 KiB of encoded JSON) |
| `TomUserPreferenceCodecException` | What that refusal raises — e.g. `preferences.encode.not_json` for a value with no JSON form, where a substitute would be a different value read back as if it were the one stored |
| `TomUserPreferencesApiService` | The typed service interface behind the API. It carries no server annotations, because `@tomComponent` and `@TomApiEndpointImplementation` live in `tom_core_server` and cannot be named here — the same split every framework contract follows |
| `tomUserPreferencesApi` | The `TomApi`: `GET`/`PUT`/`DELETE` under `/preferences`, all `TomAuthenticatedAccess`. Five endpoints — the four by-key and collection reads and writes, plus a bulk `DELETE /preferences` that clears the account |
| `tomUserPreferencesMaxPerPrincipal` / `tomUserPreferencesLimitExceededErrorKey` | The store's ceiling — 256 preferences per principal — and the key of the `409` a write answers when it would add one more. With the codec's 16 KiB `maxValueBytes` it bounds the unpaged list |
| `tomUserPreferencesNotFoundErrorKey` | `preferences.not_found` — how the read says "never written": a `404` carrying the error envelope with this `errorKey`. A bare `404` is a refusal, so the key, not the status, is what a caller branches on |

## Quick start

```dart complete
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

The two `DELETE`s differ only in whether a path segment follows the collection:
`/preferences/{key}` removes one preference and `/preferences` removes every
one. An account reset is the second, and it is an endpoint rather than a loop
because only the server can make it a single statement — a loop that stops half
way leaves a state nobody chose, on a store every device the user owns reads.
It is also why the empty key is refused: it resolves to the collection.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
