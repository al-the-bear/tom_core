# preferences

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Both halves of a user's preferences, from the client side: the **device** store
— one typed API, one backend per platform, chosen by dependency injection instead
of an `if (kIsWeb)` where the value is read — and `TomUserPreferencesClient`, the
typed client for the **account** store the server holds.

Some preferences must **not** follow the user — which account was last used on
this device, whether biometric unlock is on here, a layout choice that is right
on the tablet and wrong on the phone. Those live in the device store. The ones
that *should* follow the user live server-side (`TomUserPreferences`,
`tom_core_server`) and are reached from here through `TomUserPreferencesClient`,
which speaks the kernel's `tomUserPreferencesApi` contract. The keys, the wire
DTO and the value codec are the kernel's, so the two stores share one vocabulary
and one encoding rather than two that agree by inspection — and both carry the
same method set, which is what lets a preference *move* between them without a
call site changing. That move is a method: see
[Moving a preference between the stores](#moving-a-preference-between-the-stores).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDevicePreferences` | The interface: `all` / `read` / `get` / `getOr` / `set` / `remove` / `clear`, plus `getPreferred` for the documented device-over-server precedence and `moveToUserStore` / `moveToDeviceStore` for carrying one key across. Resolved as a bean. |
| `TomStoredDevicePreferences` | The shipped implementation — the typed API over a store; holds the single encode/decode decision. |
| `TomDevicePreferenceStore` | The narrow backend: `read()` / `write()` of the whole set. The only platform-specific part of the module. The list `read()` returns belongs to the store and the list given to `write()` belongs to the caller, so neither side has to copy defensively. |
| `TomPlatformDevicePreferenceStore` | The backend for the current target, chosen by conditional export: a JSON file on desktop/mobile, a `localStorage` entry on the web, a loud failure elsewhere. |
| `TomMemoryDevicePreferenceStore` | A store that persists nothing beyond the process — for tests, examples, and clients that deliberately keep no machine-local state. |
| `TomEncryptedDevicePreferenceStore` | A decorator that encrypts preference **values** through a `TomDevicePreferenceCipher` and delegates storage to any other backend. Keys, types and timestamps stay in the clear. |
| `TomDevicePreferenceCipher` | The two-method cipher seam an encrypting store defers to. The framework names it and holds no key. |
| `TomDevicePreferenceJson` | The stored JSON document, written once so every persistent backend stores the same text. Bare array without an owner — the interchange shape, the server's own — and `{"owner":…,"preferences":[…]}` with one. |
| `TomDevicePreferenceException` | Every device-store failure, under a stable dotted code: `.unsupported_platform`, `.store.invalid_content`, `.store.wrong_owner`, `.store.conflict`, `.store.unreadable`, `.store.write_refused`, `.store.undecryptable`, `.store.reflection_not_initialised`. |
| `TomUserPreferencesClient` | The account store: `all` / `read` / `get` / `getOr` / `set` / `remove` over the server's `/preferences/*` routes. Implements the kernel's `TomUserPreferencesApiService`; every URI is resolved from the contract, none is written. |
| `TomUserPreferencesClientException` | `preferences.client.not_found`, `preferences.client.rejected`, `preferences.client.invalid_response`. A rejection carries the `statusCode` and, when the server sent its error envelope, the server's `errorKey` — `preferences.limit.exceeded` for an account at its ceiling. |

## Quick start

```dart complete
import 'package:tom_core_flutter/tom_core_flutter.dart';

Future<void> main() async {
  // Wherever this platform keeps application support files — on a Flutter app
  // typically `getApplicationSupportDirectory().path`. It is named here rather
  // than resolved, because which directory that is belongs to the app and not
  // to this module.
  const supportDirectory = '/var/lib/example-app';

  // Register once at startup — the only line that knows about storage.
  TomBean.withType(
    TomDevicePreferences,
    TomStoredDevicePreferences(
      TomPlatformDevicePreferenceStore('$supportDirectory/preferences.json'),
    ),
  );

  // Every call site from here on is platform-independent.
  final preferences = TomDevicePreferences.resolve()!;
  await preferences.set('device.biometricUnlock', true);

  final unlock = await preferences.getOr('device.biometricUnlock', false);
  print(unlock); // true
}
```

`TomPlatformDevicePreferenceStore` takes one `location` on every platform — a
filesystem path where there is a filesystem, a `localStorage` entry name in the
browser — so the construction above is written once and never branches.

## Scope — a store belongs to its location, not to a user

Nothing in this module knows who is signed in; one store is one flat key space.
So **an application on which more than one account can sign in separates them by
construction** — it gives the store a `location` naming the signed-in account
and installs a new store when the account changes:

```dart
TomBean.withType(
  TomDevicePreferences,
  TomStoredDevicePreferences(
    TomPlatformDevicePreferenceStore(
      '$supportDirectory/preferences/$accountId.json',
    ),
  ),
);
```

The account part must be a single path (or entry-name) segment and stable — a
surrogate id, or an address hashed or percent-encoded, never a display name. An
install that gives every account one location gives them one set of
preferences: the second sign-in would read the first user's last-used account,
biometric flag and layout.

**Name the owner and that mistake becomes loud.** `owner` is an opaque string,
absent by default; a store told one records it in the document and refuses one
written under a different owner with
`device_preferences.store.wrong_owner` on the first read:

```dart
TomPlatformDevicePreferenceStore(
  '$supportDirectory/preferences/$accountId.json',
  owner: accountId,
);
```

It does not replace the location — two accounts still get two locations — and a
correct install never sees it. What it removes is the case where a correct
construction and a wrong one are indistinguishable at run time, on a screen that
looks entirely normal.

Absent is a value on both sides: an unowned document read by an owning store is
a mismatch, as is the reverse. An unowned document was written by a build that
did not separate accounts, so it could belong to anyone, and one rule with no
exemptions is the only one a reader can hold. An application adding an owner to
an install that has none clears the store or re-writes it deliberately.

That is also what decides which configuration scope the store occupies
(`codespecs_mapping.md` §11): at a fixed location it is `(client app, machine)`
— CE-CC's scope — and at a per-account location `(user, device)`, CE-DS. Same
class, different address. The API stays principal-free under both, which is what
keeps it swappable with the server-side `TomUserPreferences`.

Switching accounts costs nothing beyond the new bean: `TomStoredDevicePreferences`
holds no cache, so the next read already answers from the new document.

## How big the store can get

Every operation reads the whole document and every mutation writes all of it
back. That is what keeps `TomDevicePreferenceStore` at **two methods**, and two
methods is the whole cost of adapting a new backend — a per-key interface would
push that cost onto every platform to save work on a document of a few hundred
bytes.

It is safe because the document is bounded, by the two ceilings the account store
also declares:

| Ceiling | Value | Refusal |
| ------- | ----- | ------- |
| preferences one owner may hold (`tomUserPreferencesMaxPerPrincipal`) | 256 | `preferences.limit.exceeded`, on a write that would **add** a key |
| the encoded value of one preference (`TomUserPreferenceCodec.maxValueBytes`) | 16 KiB | `preferences.encode.too_large` |

Worst case about **four megabytes**; a real document is a few hundred bytes. Only
an insert is refused — a store at the ceiling can still change every preference
it holds, and removing one frees a place.

The count ceiling is the account store's, applied here for a reason beyond
symmetry: a preference is meant to move between the two stores, and a device
document the account store would refuse could only move one way.

An application that reaches either ceiling has put data in a preference that
belongs in a store of its own — a preference *per document* or *per project* is
the usual case, and it is exactly the shape that makes every read decode
everything. That data belongs in the application's own table on the server, or a
file it manages itself.

## Two writers over one location

Every write is a read-modify-write over the **whole** document — there is no
per-key storage to update in place — so two writers each read the same document
and each write their own version of it. Two desktop windows sharing a support
directory, two browser tabs on one origin, two isolates.

A store **compares before it writes**: if the document in place is not the one
it read, the write fails with `device_preferences.store.conflict` instead of
discarding the other writer's change. `TomStoredDevicePreferences` then re-reads
and re-applies **once**, so two writers touching different keys both survive and
two touching the same key are last-writer-wins.

Once, not until it succeeds. A retry loop over a location somebody else is
writing in a tight loop is an unbounded wait with no way out; a second conflict
is a contended store rather than an unlucky interleave, and the caller is the
one who can decide what to do about it.

The io backend's write-then-rename is a different guarantee and remains: it
makes a *single* write all-or-nothing against a torn file. It never made two
writes ordered.

A store that has never read makes no claim about what is there, so a blind
`write` is not a conflict — that caller is replacing the document wholesale,
which is what they asked for.

## When the platform refuses

A browser whose quota is exhausted, a full disk, a read-only support directory:
the platform says no, in its own vocabulary — a `DOMException` on one side, a
`FileSystemException` on the other. Both backends translate that into this
module's own failure, so a caller branches on a code rather than on whichever
object the platform happened to throw:

| Code | The operation that was refused |
| ---- | ------------------------------ |
| `device_preferences.store.unreadable` | the read |
| `device_preferences.store.write_refused` | the write |

**Which operation, not why.** A full disk, a read-only directory and an
exhausted quota are different events with different remedies, but each platform
reports them in its own vocabulary — an OS error number whose meaning is
per-platform, a `DOMException` name the interop type does not promise across
engines — so a cause classified here would be a guess wearing a code. The
original travels on `rootException`.

A failure this module has already named passes through untouched: a conflict, an
undecodable document, an uninitialised reflection. Burying one of those under a
code about the filesystem would send the reader to a disk that is fine.

## What the store does not protect

**The shipped backends write plaintext.** A JSON file on desktop and mobile, one
`localStorage` entry in the browser — readable by anything that can read the
file, and by any script on the origin. Nothing about a preference is secret
because it is a preference.

For a value that is merely *sensitive* — the last-used account, a device
nickname, a flag whose value implies something about the user —
`TomEncryptedDevicePreferenceStore` wraps any backend:

```dart
TomStoredDevicePreferences(
  TomEncryptedDevicePreferenceStore(
    TomPlatformDevicePreferenceStore(location, owner: accountId),
    cipher,
  ),
);
```

It encrypts **values only**. A reader of the file still learns that
`device.authToken` exists, that it holds a `String` and when it last changed —
but not what it is. Encrypting the keys as well would have to be deterministic
for a per-key read to work, which leaks equality while looking as though it does
not.

The cipher is the application's. The framework names a two-method seam and holds
no key, because key material belongs to a platform keystore — the Keychain, the
Android keystore, a browser key kept outside `localStorage` — and reaching one is
exactly the platform dependency this module exists to keep out of the call site.

**None of this is a credential store.** A refresh token or a password belongs in
the platform's own credential storage, whose guarantees — hardware backing,
biometric gating, wipe on device reset — no wrapper around a JSON file can offer.

## One order, both faces

`all()` answers **ordered by key, ascending**, on the device store and on the
account client alike. The rule is stated once — on the kernel's
`TomUserPreferencesApiService.listPreferences`, which both stores implement —
because a sequence that depended on which of the two an application happened to
be holding would not be one surface with two backings. Anything that renders the
list, or diffs the device store against the account store to decide what to sync,
reads it.

The key is the ordering field: it is the one that is unique within a store and
never changes while the preference exists, so rewriting a value does not move it
in the list. Ascending by code unit, which over the ASCII-only alphabet
`TomUserPreferenceKeys` admits is plain alphabetical with uppercase first.

`TomStoredDevicePreferences` sorts on the way out, so the guarantee holds for a
hand-edited document and for a backend with no insertion order to preserve;
`TomUserPreferencesClient` sorts nothing, because the order is the server's to
produce off an index that already covers it.

## Precedence

Where a key exists in both stores, **the device value wins for as long as it
exists**; the server value answers only a key this device has never written.
Writing here is the later, more specific act, so the account value behaves as a
cross-device default and the device value as this machine's override. The rule
is stated on `TomDevicePreferences` and applied in `getPreferred` — no caller
re-derives it.

```dart
final theme = await preferences.getPreferred<String>(
  TomUserPreferenceKeys.theme,
  () => account.get<String>(TomUserPreferenceKeys.theme),
);
```

The account side stays a **callback** even though the client ships beside the
device store: a device-only app must not be made to carry an HTTP client to read
a local setting. The client is simply what an application that has one closes
over, so the pairing is written at the application layer — see
`example/preferences/preferences_example.dart`, which runs it end to end against
a real socket.

The client needs the application to have registered its platform
(`TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)`); it reaches the
network through `TomPlatformUtils.current.httpClient()`, and the neutral fallback
throws rather than guessing one.

## Moving a preference between the stores

A preference that turns out to belong to the user rather than the device — or
the other way round — is carried across by one call:

```dart
// This machine's choice becomes the account's, for every device.
await preferences.moveToUserStore<String>(
  TomUserPreferenceKeys.theme,
  (value) => account.set(TomUserPreferenceKeys.theme, value),
);

// And back: the account stops carrying it, this machine keeps it.
await preferences.moveToDeviceStore<String>(
  TomUserPreferenceKeys.theme,
  () => account.get<String>(TomUserPreferenceKeys.theme),
  () => account.remove(TomUserPreferenceKeys.theme),
);
```

Both answer whether the destination holds the preference afterwards, and both
reach the account through callbacks, for the reason `getPreferred` does: a
device-only app must not be made to carry an HTTP client.

**The value in effect never changes.** That is the guarantee, and it is what the
ordering buys. There is no transaction across a file on this machine and a row
behind an HTTP round trip, so a move is **at-least-once**: it writes the
destination first and clears the source second, and a failure between the two
leaves the key in both stores. Harmless, because in that state both copies hold
the *same* value — whichever one the precedence rule picks, the answer is the
value the move was carrying. Repeating the call from there completes it.

The same invariant is why **a move onto a device that already holds the key
writes nothing**: by the precedence rule the device copy is the one in effect
and the account copy is the shadowed one, so the move is the removal of the
shadowed copy. Installing the account value instead would not move a
preference; it would change the one the user sees.

What the ordering does not promise is that the source copy is gone. A caller for
whom a leftover matters repeats the call, or reads both stores and compares.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
