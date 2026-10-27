# Preferences Module

Both halves of a user's preferences, from the client side: the **device** store
— one typed API, one backend per platform, chosen by dependency injection rather
than by an `if (kIsWeb)` where the value is read — and the **account** store,
reached over the kernel's `/preferences/*` contract by a typed client.

## Table of Contents

- [Overview](#overview)
- [Reflection Is a Precondition](#reflection-is-a-precondition)
- [Why the Framework Owns This](#why-the-framework-owns-this)
- [The Same Shape as the Server Store](#the-same-shape-as-the-server-store)
- [Choosing a Backend](#choosing-a-backend)
- [How Big the Device Store Can Get](#how-big-the-device-store-can-get)
  - [Entities on the device belong to the offline module](#entities-on-the-device-belong-to-the-offline-module)
- [Two Writers Over One Location](#two-writers-over-one-location)
- [When the Platform Refuses](#when-the-platform-refuses)
- [What the Store Does Not Protect](#what-the-store-does-not-protect)
- [Writing a Backend](#writing-a-backend)
- [Scope: A Store Belongs to Its Location](#scope-a-store-belongs-to-its-location)
  - [Name the owner, and that mistake is loud](#name-the-owner-and-that-mistake-is-loud)
- [Reaching the Account Store](#reaching-the-account-store)
- [Precedence Against the Server Store](#precedence-against-the-server-store)
- [Moving a Preference Between the Stores](#moving-a-preference-between-the-stores)
- [Resetting an Account](#resetting-an-account)
- [The Stored Document](#the-stored-document)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDevicePreferences` | abstract class | The typed API; resolved as a bean |
| `TomStoredDevicePreferences` | class | The shipped implementation — typed API over a store |
| `TomDevicePreferenceStore` | abstract class | The narrow backend: read / write the whole set |
| `TomPlatformDevicePreferenceStore` | class | The backend for the current target (file / `localStorage` / loud failure) |
| `TomMemoryDevicePreferenceStore` | class | A store that persists nothing beyond the process |
| `TomDevicePreferenceStoreConflictDetection` | mixin | What the backends use to refuse a write over a document other than the one they read |
| `TomEncryptedDevicePreferenceStore` | class | A decorator that encrypts preference **values** and delegates storage to any backend |
| `TomDevicePreferenceCipher` | abstract class | The two-method cipher seam an encrypting store defers to |
| `TomDevicePreferenceJson` | class | The stored JSON document, written once for every persistent backend |
| `TomDevicePreferenceException` | class | Device-store failures, keyed by stable dotted codes |
| `TomUserPreferencesClient` | class | The **account** store: the same typed API, over the server's `/preferences/*` routes |
| `TomUserPreferencesClientException` | class | Client failures, keyed by stable dotted codes |

The *keys*, the *wire DTO* and the *value codec* are not here. `TomUserPreferenceKeys`,
`TomUserPreferenceDto` and `TomUserPreferenceCodec` live in `tom_core_kernel`'s
`preferences` module, because the server-side store (C-13) uses exactly the same
three, and a vocabulary spelled in two packages is a preference that silently
splits in two.

## Reflection Is a Precondition

**Both halves of this module encode `TomUserPreferenceDto` through
`tomReflectionInfo`**, so an application using either must call
`initializeReflection()` as the first action in its `main`. That is a
precondition of the framework, not a quirk of this module: every entrypoint runs
`reflection_generator`, and the generated seed covers the whole dependency
closure — framework types included. A real one carries the kernel's sources and
registers `TomUserPreferenceDto` itself.

One rule, not two. The stored document and the wire request are the same DTO in
the same package, and encoding it by hand on one side while reflecting it on the
other would leave two definitions of one shape to be kept in step by inspection.

What the module does **not** delegate is the timestamp rule. `updatedAt` is
checked before an entry reaches reflection, because reflection parses a
`DateTime` with `DateTime.parse` — which reads a stamp naming no zone as *this*
device's local time, the one clock certainly not the writer's. Encoding needs no
such care: reflection normalises a `DateTime` to UTC on the way out, so a
document this module writes always names its zone.

### When it is missing, the module says so

A missing seed is a configuration fault of the program, and it is reported as
one rather than as damage to whatever it was reading:

| Raised by | Key |
| --------- | --- |
| the device store, encoding or decoding | `device_preferences.store.reflection_not_initialised` |
| the account client, reading or writing | `preferences.client.reflection_not_initialised` |

Both messages name `initializeReflection()`. The alternative is what these
replace: a valid stored document reported as `device_preferences.store.invalid_content`,
and a correct HTTP 200 carrying a valid preference reported as
`preferences.client.invalid_response` — "The server did not answer with a
preference". Blaming a correctly behaving server for a client-side fault is the
worst available diagnosis, because the first thing the caller does is inspect
something that is fine.

A write fails **before** the request is made, since its body is encoded through
reflection too — so the network is never involved and nothing suggests it was.

## Why the Framework Owns This

Some preferences must **not** follow the user. Which account was last used on
this device, whether biometric unlock is enabled *here*, a layout choice that is
right on the tablet and wrong on the phone in the same pocket — storing those
server-side gives every device the last one's answer.

Without a framework device store every application reaches for
`shared_preferences` (or `window.localStorage`, or a file) directly. That puts a
raw platform dependency at the application layer and makes the *call site*
branch on the platform, which is what G-DI-3 / G-ENV-1 exist to prevent. The
requirement this module satisfies is therefore not "a place to put values" — it
is the **uniform API**: the same call works on web, desktop and mobile, and only
one line in the whole application knows which storage is behind it.

## The Same Shape as the Server Store

`TomDevicePreferences`' method set deliberately mirrors `TomUserPreferences`
(`tom_core_server`), plus the device-only `getPreferred`:

| Method | Returns | Description |
|--------|---------|-------------|
| `all()` | `Future<List<TomUserPreferenceDto>>` | Every preference on this device, ordered by key. **Unmodifiable** — as the account client's `all()` is |
| `read(key)` | `Future<TomUserPreferenceDto?>` | One preference as stored, or `null` |
| `get<T>(key)` | `Future<T?>` | Decoded as a `T`; `null` when never written |
| `getOr<T>(key, fallback)` | `Future<T>` | `get`, with a default for the unwritten case |
| `set<T>(key, value)` | `Future<TomUserPreferenceDto>` | Encodes and stores; a value over 16 KiB of encoded JSON is refused, in both stores |
| `remove(key)` | `Future<bool>` | Deletes; answers whether one was removed |
| `clear()` | `Future<void>` | Deletes everything on this device — and everything in the account, on the other face |
| `getPreferred<T>(key, fromUserStore)` | `Future<T?>` | Applies the documented precedence |

That symmetry is not incidental. It is what lets a preference **move** between
the two stores — a value that turns out to belong to the user rather than the
device — without a single call site changing.

There is no `getFor`: a device store has one user by definition, so a principal
parameter would have nothing to select. What *makes* that definition true is the
store's location, not anything the framework tracks — see
[Scope: A Store Belongs to Its Location](#scope-a-store-belongs-to-its-location)
for what an application must do to keep it true.

`clear()` is its own method rather than a loop over `all()` because a backend
can do it atomically and a loop cannot: a loop that fails half way leaves a
device in a state no user asked for. The account store carries it for the same
reason and gets it the same way — the contract declares a bulk
`DELETE /preferences`, so `TomUserPreferencesClient.clear()` is one request and
the server one statement. See
[Resetting an Account](#resetting-an-account).

**`all()` is ordered by key, ascending — and so is the account store's.** The
rule is stated once, on the kernel's `TomUserPreferencesApiService.listPreferences`,
because both stores answer it: a sequence that depended on which face an
application happened to hold would not be one surface with two backings, which
is the whole premise of the symmetry above. Anything that renders the list, or
diffs the device store against the account store to decide what to sync, reads
that sequence.

The key is the ordering field because it is the one that is unique within a
store and never changes while the preference exists — rewriting a value must not
move it in the list, which rules out `updatedAt`, and there is no insertion order
a rebuilt store could preserve. Ascending by code unit, which over the ASCII-only
alphabet `TomUserPreferenceKeys` admits is plain alphabetical with uppercase
first, so `tom.Theme` precedes `tom.theme`.

The device store sorts on the way *out* rather than keeping its document sorted:
a JSON file may have been written by an older build or edited by hand, and a
store wrapping a keychain enumerates however the keychain likes — neither can be
made to comply by a sorted `set()`. The client does the opposite and sorts
nothing, because the order is the server's to produce off an index that already
covers it; a client that re-sorted defensively would hide the one symptom by
which a store breaking the contract could be noticed.

`getOr` answers its fallback only for a preference that has **never been
written**. A type *mismatch* still throws `TomUserPreferenceCodecException`: an
unwritten preference is an ordinary state that a default answers, while a
preference stored as the wrong type is a bug, and silently answering the
fallback would hide it.

## Choosing a Backend

Backend selection happens twice, and neither half is a branch at the call site.

**At compile time**, `platform_device_preference_store.dart` conditionally
exports one of three implementations of `TomPlatformDevicePreferenceStore`:

| Target | Backend | Notes |
|--------|---------|-------|
| `dart:io` (desktop, mobile) | JSON file | Write-then-rename; deleted when empty |
| `dart:js` (web) | `localStorage` | One entry holding the whole document |
| neither | throws on construction | `device_preferences.unsupported_platform` |

It takes one `location` on every platform — a filesystem path where there is a
filesystem, a `localStorage` entry name in the browser — so the construction is
written once and never branches.

The neutral variant **throws** rather than degrading to an in-memory store. A
settings screen whose switches appear to work but forget everything on restart
is a worse outcome than a failure at startup, and only the app knows what the
right store would be on such a target. A client that genuinely wants no
machine-local persistence says so with `TomMemoryDevicePreferenceStore`.

**At run time**, the bean locator selects the `TomDevicePreferences`
implementation. The simplest wiring registers one instance:

```dart
TomBean.withType<TomDevicePreferences>(
  TomStoredDevicePreferences(TomPlatformDevicePreferenceStore(location)),
);

final preferences = TomDevicePreferences.resolve()!;
await preferences.set('device.biometricUnlock', true);
```

An application that needs genuinely different behaviour per platform — an
encrypted store on mobile, a plain one on desktop — declares reflected
components instead and lets the four-tier selection choose:

```dart
@tomReflector
@TomComponent(TomDevicePreferences)
@platformIos
class IosDevicePreferences extends TomStoredDevicePreferences {
  IosDevicePreferences(super.store);
}
```

The framework ships **no** default component. A default would have to be the
memory store — the only one constructible without knowing where the app's
machine-local state belongs — and a default that silently forgets is exactly
what this module refuses.

`resolve()` answers `null` when nothing is registered, mirroring
`TomUserPreferences.resolve`: a preference is optional by nature, and an
application that has not wired a device store should fall back to its defaults
rather than fail to start.

## How Big the Device Store Can Get

**Every operation reads the whole document, and every mutation writes all of it
back.** `all`, `read`, `get`, `getOr`, `set` and `remove` each go through
`store.read()`, which decodes the entire document; a `set` is a full
read-modify-write.

That is a decision, not an omission. It is what keeps `TomDevicePreferenceStore`
at **two methods**, and two methods is the whole cost of adapting a new backend —
`shared_preferences`, a keychain, an encrypted file. A per-key backend interface
would push that cost onto every platform, to save work on a document that is a
few hundred bytes.

It is only safe because the document is bounded, by the same two ceilings the
account store declares:

| Ceiling | Value | Enforced by | Refusal |
| ------- | ----- | ----------- | ------- |
| `tomUserPreferencesMaxPerPrincipal` — preferences one owner may hold | 256 | `TomStoredDevicePreferences.set`, on a write that would **add** a key | `preferences.limit.exceeded` |
| `TomUserPreferenceCodec.maxValueBytes` — the encoded value of one preference | 16 KiB of UTF-8 | the kernel codec, on the writing side | `preferences.encode.too_large` |

So the largest document this store can ever hold is about **four megabytes**, and
a real one — a theme, a language, a last-used account, a handful of flags — is a
few hundred bytes.

**The count ceiling is the account store's, applied here too**, and for a reason
beyond symmetry: a preference is meant to be able to *move* between the two
stores, and a device document the account store would refuse to accept could only
ever move in one direction. Both refusals carry the contract's own key rather
than a device-local spelling, because it is the same rule.

**Only an insert is refused.** A device at the ceiling can still change every
preference it holds, and removing one frees a place — the ceiling keeps the
document small, it does not freeze it.

### What the ceilings say a preference is for

256 is far beyond what settings need, and 16 KiB holds a reflected settings
object with dozens of members. An application that reaches either has put data in
a preference that belongs in a store of its own — a preference **per document**
or **per project** is the usual case, and it is exactly the shape that makes
every read of any preference decode all of them.

For that data: a table in the application's own database on the server, kept on
the device through the kernel's offline module when the client needs it there.
Not this store, and not the account store either — the same two ceilings apply
there, for the same reasons.

### Entities on the device belong to the offline module

This store holds a settings bag and nothing more. The boundary is that **the
server owns persistence**: entities live in the server's datasources, reached
through its endpoints.

A client that has to work offline against entities uses the kernel's
[offline module](../../tom_core_kernel/doc/offline/offline.md). A
`TomLocalRepository` reads and writes the device's copy of server entities with
the operations of the server's `TomRepository`, queues every change with the
server version it was based on, and a `TomSyncEngine` pushes the queue, hands
conflicts to the application's resolver and pulls what changed on the server.
The server stays authoritative.

The device database itself is the application's. The offline module asks for a
`TomLocalStoreEngine` — JSON documents in named collections, and transactions —
and the application implements it over the database package it chose. That
choice is an architectural commitment with a platform matrix behind it (which
platforms, web or not, encrypted or not, how its files migrate), and the
framework has no consumer whose answer it could generalise. Owning one would
make every Tom application carry that commitment to spare the few that need it
a dependency they can add themselves.

## Two Writers Over One Location

Every write is a read-modify-write over the **whole** document. There is no
per-key storage to update in place, so two writers over one location each read
the same document and each write their own version of it — two desktop windows
sharing a support directory, two browser tabs on one origin, two isolates.

### Compare-and-swap, then one retry

A store **compares before it writes**. If the document in place is not the one
it read, the write fails with `device_preferences.store.conflict` rather than
discarding the other writer's change; `TomStoredDevicePreferences` then re-reads
and re-applies the change **once**:

| Two writers | Outcome |
| ----------- | ------- |
| different keys | both survive — the loser re-applies *onto* the winner's document |
| the same key | last-writer-wins, after the loser has seen the winner's document |
| a store somebody is writing continuously | `device_preferences.store.conflict`, after exactly one retry |

**Once, not until it succeeds.** A retry loop over a contended location is an
unbounded wait with no way out, and the honest end of it is the named failure: a
second conflict means a contended store rather than an unlucky interleave, and
the caller is the one who can decide what to do about that.

**The comparison is over the document's identity, not a version counter.** A
counter would have to live in the stored JSON, and a header in every document
would retire the property [The Stored Document](#the-stored-document) is built
around — that an unowned document is exactly the array the server's
`/preferences` list endpoint answers. Comparing what is there against what was
read answers the same question inside the two methods the backend contract
already has, and needs no format at all. The two persistent backends compare the
stored text; the in-memory one a revision counter.

A store that has never read makes no claim about what is there, so a blind
`write` is **not** a conflict: that caller is replacing the document wholesale,
which is what they asked for.

### What atomicity was, and still is

The io backend's write-then-rename makes a *single* write all-or-nothing against
a torn file, and it still does. That was never the same guarantee as ordering
two writes, and the web backend — a whole-value `setItem` — has no atomicity at
all. What is new is that the *second* writer now finds out.

## When the Platform Refuses

A browser whose quota is exhausted; a full disk; a read-only support directory;
storage disabled for an origin. These are the storage failures a *correctly
configured* client actually meets, and each platform reports them in its own
vocabulary — a `DOMException` in the browser, a `FileSystemException` under
`dart:io`.

Both backends translate them into this module's own failure, so a caller
branches on a code rather than on whichever object the platform happened to
throw:

| Code | The operation that was refused |
| ---- | ------------------------------ |
| `device_preferences.store.unreadable` | the read |
| `device_preferences.store.write_refused` | the write |

### Which operation, not why

A full disk, a read-only directory and an exhausted quota are different events
with different remedies — but `dart:io` reports them as one exception type
distinguished by an OS error number whose meaning is per-platform, and a browser
distinguishes them by the `name` of a `DOMException`, a value the interop type
does not promise across engines. A cause classified here would be a guess
wearing a code.

So the code names the part this module can state truthfully: which operation the
platform refused. The platform's own error travels on `rootException` for a
caller that wants to inspect it, and the message quotes it.

### A failure already named passes through

A conflict, an undecodable document, an owner mismatch, an uninitialised
reflection — each is already a code a caller branches on, and burying one under
a code about the filesystem would send the reader to a disk that is fine. The
translation catches only what it did not raise itself.

## What the Store Does Not Protect

**The shipped backends write plaintext.** A JSON file on desktop and mobile, one
`localStorage` entry in the browser — readable by anything that can read the
file, and by any script on the origin. Nothing about a preference is secret
because it is a preference, and the module has never said otherwise; what it had
not said is this, plainly.

### An encrypting store, for values that are sensitive

`TomEncryptedDevicePreferenceStore` wraps **any** backend:

```dart
TomStoredDevicePreferences(
  TomEncryptedDevicePreferenceStore(
    TomPlatformDevicePreferenceStore(location, owner: accountId),
    cipher,
  ),
);
```

A decorator rather than a fourth backend, because encryption is orthogonal to
all three of the existing ones — it wraps the file store on desktop, the
`localStorage` store in the browser, the memory store in a test, and none of
them changes. That the two-method backend seam makes this possible is the
module's best structural property, and the contract already named "an encrypted
file" as one of the adaptations it is for.

**It encrypts values only, and that is a line rather than an oversight.** A
reader of the document still learns that `device.authToken` exists, that it
holds a `String`, and when it last changed — but not what it is. Encrypting the
keys as well would have to be deterministic for a per-key read to work at all,
which leaks equality while looking as though it does not, and would make the
document unreadable to every tool that inspects one. The honest statement is the
one worth having: this hides the secret, not the fact that a secret is kept.

A value the cipher will not read back raises
`device_preferences.store.undecryptable`, naming the preference — a rotated key,
or a document from another install. A store is usually readable in part, and
which entry failed is the first thing anyone asks.

### The cipher is the application's

`TomDevicePreferenceCipher` is two methods over `String` — `encrypt` and
`decrypt`, either synchronous or asynchronous — with no key, no algorithm and no
lifecycle. The framework does not choose one, for two reasons that point the
same way: key material belongs to a **platform keystore**, and reaching one is
exactly the platform dependency this module exists to keep out of the call site;
and `tom_crypto` ships no symmetric cipher, so a framework that encrypted here
would either take a new dependency on every application's behalf or hand-roll
one.

### It is not a credential store

A refresh token, a password, a private key: these belong in the platform's own
credential storage, whose guarantees — hardware backing, biometric gating, wipe
on device reset — no wrapper around a JSON file can offer. What the encrypting
store is for is the preference that is merely sensitive, where the alternative
today is plaintext.

## Writing a Backend

`TomDevicePreferenceStore` is the module's only platform seam, and it is two
methods wide:

```dart
Future<List<TomUserPreferenceDto>> read();
Future<void> write(List<TomUserPreferenceDto> values);
```

Everything typed — the codec, the key rules, the precedence — sits above it, so
adapting a new backend is a question about storage and never about preferences.
Three obligations come with those two methods:

**Absence is not an error.** `read()` answers an empty list when nothing has
been persisted. Content that *is* there but cannot be read is a different case
and throws `device_preferences.store.invalid_content` — a corrupt store that
reported itself empty would be overwritten by the next `write` and take
everything the device had chosen with it.

**A write is all-or-nothing.** A failure part-way through must leave the
previously readable content intact rather than a truncated set. The file backend
gets this from write-then-rename; a backend without an atomic primitive has to
build one.

**Each list belongs to one side, and it is not the same side.** The list
`read()` returns belongs to the **store**: callers must not modify it, so an
implementation may return its own list, an unmodifiable view, or the same
instance every time — a cache over `shared_preferences` or a keychain needs no
defensive copy per read. The list handed to `write()` belongs to the **caller**:
an implementation must not modify it and must not retain it without copying,
because the caller may still hold it and may pass one that cannot be modified at
all — `clear()` passes `const []`.

The two halves are what let both sides be written naturally at once, and they
are checked rather than merely stated: the shared test suite runs against a
store that returns its own unmodifiable list from `read()`, so an operation here
that treated that list as scratch space would fail the suite rather than fail in
somebody's keychain-backed store.

## Scope: A Store Belongs to Its Location

Nothing in this module knows who is signed in. One store is one flat key space,
and its `location` is the only thing that separates one key space from another.
That is what the absent `getFor` means in practice: a device store has one user
because its *location* has one user — not because the framework tracks one.

So **an application on which more than one account can sign in separates them by
construction.** It gives the store a `location` naming the signed-in account,
and installs a new store when the account changes:

```dart
TomBean.withType<TomDevicePreferences>(
  TomStoredDevicePreferences(
    TomPlatformDevicePreferenceStore(
      '$supportDirectory/preferences/$accountId.json',
    ),
  ),
);
```

The account part must be a **single** segment of the path (or of the
`localStorage` entry name) and it must be **stable** — a surrogate id, or an
address hashed or percent-encoded, never a display name. A segment holding a
separator silently reshapes the path into something the application did not
choose; one that changes when a user edits their profile strands every
preference written under the old spelling.

An install that gives every account the same location gives them the same
preferences. The second sign-in would read the first user's last-used account,
biometric flag and layout — on a screen that looks entirely normal.

### Name the owner, and that mistake is loud

`owner` is an opaque string the application chooses, absent by default. A store
told one records it in the stored document and refuses one written under a
different owner:

```dart
TomPlatformDevicePreferenceStore(
  '$supportDirectory/preferences/$accountId.json',
  owner: accountId,
);
```

The first read of another account's document throws
`device_preferences.store.wrong_owner`, naming both owners. A correct install
never sees it; what it removes is the case where a correct construction and a
wrong one are indistinguishable at run time.

It does **not** replace the location. Two accounts still get two locations, and
the owner is a check on that arrangement rather than a substitute for it — a
store is still never told that a user changed, and the marker is compared only
against the document it was handed.

**Absent is a value on both sides.** An unowned document read by an owning store
is a mismatch, and so is an owned document read by a store with no owner. An
unowned document was written by a build that did not separate accounts, so it
could belong to anyone; one rule with no exemptions is the only one a reader can
hold, and a lenient one would wave through exactly the direction that leaks. An
application adding an owner to an install that has none clears the store or
re-writes it deliberately.

Switching accounts costs nothing beyond the new bean:
`TomStoredDevicePreferences` holds no cache, so the next read already answers
from the new document.

The same choice decides which configuration scope the store occupies
(`tom_core_codespecs/doc/codespecs_mapping.md` §11). At a fixed location it is `(client app, machine)`
— CE-CC's scope; at a per-account location it is `(user, device)`, CE-DS. Same
class, different address. The API stays principal-free under both, which is what
keeps it swappable with the server-side `TomUserPreferences`.

## Reaching the Account Store

`TomUserPreferencesClient` is the account half. The kernel declares the contract
(`tomUserPreferencesApi`) and `tom_core_server` implements it, but a preference
exists to *follow a user across devices*, which makes it a capability only once a
device can reach it. Without a framework client every application writes the four
HTTP calls itself: four spellings of the same URIs, four decodings of the same
DTO, four chances to read a broken server as "no such preference" — the same
G-DI-3 failure the device store removes, one layer up.

It carries the device store's method set — `all` / `read` / `get` / `getOr` /
`set` / `remove` — over the same DTO and the same codec, so a call site reads
identically whichever store it addresses, plus `setAll`, the account store's
bulk write:

```dart
final account = TomUserPreferencesClient(
  baseUri: Uri.parse('https://api.example.com'),
);

await account.set(TomUserPreferenceKeys.theme, 'dark');
final theme = await account.getOr(TomUserPreferenceKeys.theme, 'system');

await account.setAll({
  TomUserPreferenceKeys.language: 'de',
  TomUserPreferenceKeys.country: 'DE',
});
```

**No URI is written by the caller, or by the client.** Every request is built by
`TomApiEndpoint.resolveUri` from the endpoint's own declaration — its method, its
path template, its `urlParameterMapping` — so the address the client calls and
the route the server serves are two readings of one declaration rather than two
spellings that agree by inspection.

**A write states its key once, in the body.** `read` and `deletePreference`
address a preference by path — the contract mounts them at `/{key}` — while
`writePreference` is a `PUT` at `/preferences` whose request already carries the
key, so it passes no path parameters at all. `writePreferences`, the bulk write,
is a `POST` at `/preferences` whose request keys its map by preference key, so
it too passes none. A URL and a body naming different preferences is not
something this client can build.

**Several preferences in one request, all or none.** `setAll(values)` encodes
every entry of a key → value map as `set` encodes one, builds a
`TomUserPreferenceBulkWriteRequest` and sends it through `writePreferences`; the
answer is the stored DTOs ordered by key. The server writes the batch in one
transaction, so a refusal of one entry — a value it cannot store, a batch whose
new keys would take the account past its ceiling — leaves every preference as it
was. A settings screen saving several changes therefore never leaves the
account half saved, which a loop of `set`s could, on the store every device the
user owns reads.

**Defaults arrive with an origin.** Under a key the user has not written, the
server answers the default it holds — a role's or the deployment's — so `all`,
`read`, `get` and `getOr` return it like a stored value, and
`TomUserPreferenceDto.origin` (`user`, `role`, `deployment`; `isDefault`) says
which it is. A settings screen that offers "reset to default" reads it: `remove`
on a `user` value brings the default back, and `remove` under a key whose value
is a default changes nothing.

**Two deletes share a method and differ by one path segment.**
`deletePreference` is a `DELETE` at `/preferences/{key}` and `clearPreferences`
a `DELETE` at `/preferences` — the same collection/item pair the two reads form,
except that here the two answers are "one preference gone" and "all of them
gone".

**A key that could not be a path segment never reaches a request.** `read`,
`writePreference`, `writePreferences` (every key of the batch) and
`deletePreference` all validate the key against
`TomUserPreferenceKeys` before building one, and refuse it with
`TomUserPreferenceKeyException` — the write included, because the rule is the
store's vocabulary rather than the URL's. Escaping is not a usable alternative:
`%2F` is not a settled outcome — much HTTP infrastructure rejects it and some
normalises it back to `/`, at which point the request addresses a two-segment
path the API never declared. The empty key is worse than ambiguous: it resolves
to the collection, so "read the preference named `''`" would silently become
"read them all" — and "delete the preference named `''`" would become "delete
every one of them", because a `DELETE` at the collection is the clear. That is
why the key is validated before any URI is built rather than after. The server validates the same key again on
arrival, because a well-behaved client is not the only thing that can send an
HTTP request.

`clear()` deletes every preference of the calling principal in one request — see
[Resetting an Account](#resetting-an-account).
`remove` returns `void` where the device store answers a `bool`, because the
delete endpoint is idempotent by design and the server does not report whether a
row existed — a `bool` invented here could only be a second round trip
pretending to be an answer.

**A miss is a `404` that says so.** The server answers a key with neither a
value of the user's nor a default with a `404` whose error envelope names the kernel's
`tomUserPreferencesNotFoundErrorKey`; for that answer `read` and `get` answer
`null` and `getOr` answers its fallback. Only `readPreference`, the
service-interface call whose result is not nullable, turns the miss into
`TomUserPreferencesClientException` with `preferences.client.not_found`. A *bare* `404` is not a miss: the
endpoint pipeline answers a denied or signed-out caller that way, so that a
refusal looks like a route that does not exist, and reading it as "not set"
would hand that caller the defaults. Every answer other than the enveloped miss
throws `TomUserPreferencesClientException` with `preferences.client.rejected`
— a `404` from `remove` included,
since the server deletes a missing preference with a `200` — because a deployment whose preference store
is unreachable must not be indistinguishable from a user who has set nothing —
an application that could not tell them apart would paper the outage over with a
default and never learn. A rejection's `parameters` carry the `statusCode` and,
when the server answered with its error envelope, the server's `errorKey` — so an
account at its ceiling of 256 preferences (`409`, `preferences.limit.exceeded`)
is told apart from any other refusal without parsing the body — and so is a
malformed bulk entry (`400`, `preferences.bulk.malformed`). A *value* failure
— a preference stored as the wrong type, or one whose encoding exceeds the
codec's 16 KiB — arrives as the kernel's `TomUserPreferenceCodecException`
instead, since it means the same thing in both stores.

Requests carry the signed-in bearer token from `TomBearerAuthentication`. An
`Authorization` supplied through `headers` or `headerProvider` **suppresses** it,
so exactly one credential reaches the server; `headerProvider` is the seam for a
credential that rotates, which a constructor argument would capture once.

## Precedence Against the Server Store

A key normally belongs to exactly one store. Where the same key exists in both,
**the device value wins for as long as it exists**, and the server value answers
only a key this device has never written.

That ordering matches what a user did: writing a preference on *this* device is
a deliberate, later, more specific act than the value that arrived with the
account. So the account value behaves as a cross-device default and the device
value as this machine's override — the same relationship the
[client-configuration module](configuration.md) has between shipped defaults and
install overrides. Reversing it would make a setting the user changed here
revert the moment their other device wrote the same key.

Both stores sit **beneath** that module's scope, and a third rung continues the
same ladder: an install's `TomSetting` may declare that a user or device
preference of the same key is allowed to shadow it, and `TomEffectiveSettings`
reads all three as one value. `getPreferred` is the two-store case of that
chain, kept because a preference that no setting declares is the ordinary case
and should not need a configuration holder to be read. See
[Shadowing by a Narrower Scope](configuration.md#shadowing-by-a-narrower-scope).

The rule is stated once on `TomDevicePreferences` and applied once in
`getPreferred`:

```dart
final theme = await preferences.getPreferred<String>(
  TomUserPreferenceKeys.theme,
  () => account.get<String>(TomUserPreferenceKeys.theme),
);
```

The server side arrives as a **callback** rather than a dependency, and stays one
now that `TomUserPreferencesClient` ships in this package. Two reasons: a
device-only app must not be made to carry an HTTP client to read a local setting,
and the callback is only invoked when this device has no answer — a device that
has written the key never pays for the round trip. The client is simply what an
application that has one closes over, which is why the pairing is written at the
application layer and shown in `example/preferences/preferences_example.dart`.

## Moving a Preference Between the Stores

The two stores carry one method set so that a preference can change which of
them owns it without a call site changing. That move is itself a method, in each
direction:

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

Each answers whether the destination holds the preference afterwards — `false`
means there was nothing under that key to carry. The account side arrives as
callbacks for the reason it does on `getPreferred`: a device-only application
must not be made to carry an HTTP client, and the client is simply what an
application that has one closes over.

### At-least-once, because two stores share no transaction

One store is a file on this machine; the other is a row behind an HTTP round
trip. Nothing spans them, so a move cannot be atomic and saying otherwise would
be a promise the shape cannot keep. What it promises instead is an **order**:
the destination is written first and the source cleared second, so an
interruption between the two leaves the key in *both* stores, and repeating the
same call from there completes it.

### The value in effect never changes

That ordering is chosen to make the interrupted state harmless rather than
merely recoverable. In it, both stores hold the **same** value — so the
precedence rule picks the value the move was carrying whichever copy it picks.
The winner before a move, during it and after it is one value.

The reverse order would not have that property. Clearing the source first and
failing before the destination is written loses the preference outright; and
writing a *different* value into the device store would make the move visible as
a change, on the one device where it looks correct and nowhere else.

The same invariant decides what happens when both stores already hold the key
and `moveToDeviceStore` is called: **the value already on this device is not
overwritten.** By the precedence rule it is the one in effect and the account
copy is the shadowed one, so the move is the removal of the shadowed copy.
Promoting the account value would not move a preference; it would change the one
the user sees.

### What it does not promise

That the source copy is gone. A caller for whom a leftover matters — a "stop
syncing this setting" the user can see — repeats the call, or reads both stores
and compares. Nothing retries on the caller's behalf, for the reason a
contended write is not retried either: an unbounded wait inside a framework call
is a decision that belongs to the application.

## Resetting an Account

"Reset this account's preferences" is an ordinary requirement, and the operation
most likely to be run when something is already wrong. Both stores answer it
with one method:

```dart
await preferences.clear();     // this device
await account.clear();         // every device, via the server
```

`TomDevicePreferences.clear()` writes an empty document; `clear()` on the
account client issues the contract's `DELETE /preferences`, which the server
answers with a single `DELETE ... WHERE principal_id = ?`.

**Neither is a loop, and that is the whole point.** A reset written as "list,
then delete each" can stop half way, and what it leaves is a set of preferences
nobody chose — half the old account, half the defaults. On the account store
that half-reset state is shared by every device the user owns. One statement
either happens or does not.

The bulk route takes nothing: no key, no filter. A partial clear is
`deletePreference` repeated, and a caller that wants one already has it. It
answers nothing either — how many preferences went is the server's business,
and the only branch a count could support is "some were already gone", which is
the case the idempotence exists to make uninteresting. Clearing an account that
holds nothing succeeds.

Every non-2xx answer throws, a `404` included: the clear is idempotent, so a
`404` from it is the pipeline's refusal and never "nothing to clear". Reporting
it as success would tell a caller an account was reset that still holds every
preference it did.

## The Stored Document

Every persistent backend stores the same JSON text, produced by
`TomDevicePreferenceJson`:

```json
[
  {"key": "device.lastAccount", "valueType": "String", "value": "\"alex\"",
   "updatedAt": "2026-03-14T09:26:53.000Z"},
  {"key": "device.launchCount", "valueType": "int", "value": "12"}
]
```

An **array** rather than an object keyed by preference key, because that is the
shape `TomDevicePreferenceStore` reads and writes, and because it is the shape
the server's `/preferences` list endpoint answers — the same text moves between
the two stores without a reshaping step.

A store that names an `owner` wraps that array in an envelope instead:

```json
{"owner": "alex", "preferences": [ … ]}
```

Two shapes rather than one, and the reason is the paragraph above: the bare
array is the interchange shape and stays exactly the server's, so an application
that names no owner is unaffected and the "same text, both stores" property
holds where it was argued for. The envelope appears only where an owner was
asked for. `decode` reads both, and compares the owner before it reads anything
else — the question of whose document this is decides whether the rest may be
read at all.

The encoding lives in one class rather than in each backend: two backends that
each wrote their own JSON would agree only by inspection, and the day they
diverged would be the day a preference exported from one device failed to import
on another.

Blank content decodes to an empty document — a crash between creating a file and
writing it leaves exactly that, and treating it as empty loses nothing that was
ever committed. Anything else that is not an array of objects throws
`device_preferences.store.invalid_content` rather than reading as empty, because
a corrupt store that looked empty would be overwritten by the next write and
lose everything the device had chosen.

`updatedAt` is the device's own clock, normalised to UTC. Unlike the server
store nothing here can supply a more authoritative timestamp, but the
normalisation means a preference that later moves to the server carries an
instant the server can store unchanged.

It is read back with the same strictness: the document is meant to travel
between devices, so an `updatedAt` that names no time zone throws
`device_preferences.store.invalid_content` rather than being read as the
*importing* device's local time — the one clock that certainly did not write it.

## Core Components

- **`TomDevicePreferences`** — the interface, the precedence rule, and
  `resolve()`.
- **`TomStoredDevicePreferences`** — the typed API over a store; holds the
  single encode/decode decision. Every operation goes to the store: a device
  preference is read when a screen opens and written when a user flips a switch,
  so a cache would buy nothing measurable and would go stale the moment a second
  browser tab or a background isolate wrote the same store.
- **`TomDevicePreferenceStore`** — two methods, `read` and `write`, over the
  whole set. The only platform-specific part of the module, and the whole cost
  of adapting a new backend.
- **`TomPlatformDevicePreferenceStore`** — the compile-time selected backend.
- **`TomMemoryDevicePreferenceStore`** — for tests, examples, and clients that
  deliberately keep no machine-local state.
- **`TomUserPreferencesClient`** — the account store, with `setAll` for an
  all-or-none bulk write. Not a bean and not resolved: it needs a `baseUri`, which only the application knows, and unlike
  the device store there is nothing to select between. Holds no cache, for the
  device store's reason and one more — the account store is shared with the
  user's other devices, so a cached value is stale the moment one of them writes.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `encrypted_device_preference_store.dart` | `FutureOr`, so a cipher may be synchronous or not |
| `dart:convert` | dart | `device_preference_json.dart`, `user_preferences_client.dart` | `json`, `jsonDecode`, `jsonEncode`, `utf8` |
| `dart:io` | dart | `platform_device_preference_store_io.dart` | in the respective compile-time variants only |
| `tom_core_kernel` | package | 9 of 11 files | `TomUserPreferenceKeys`, `TomUserPreferenceDto`, `TomUserPreferenceCodec`, `TomBean`, `TomRuntime`, and for the client `tomUserPreferencesApi`, `TomApiEndpoint.resolveUri`, `TomServerChannel`, `TomBearerAuthentication` (see `../../tom_core_kernel/doc/preferences/preferences.md`) |
| `web` | package | `platform_device_preference_store_web.dart` | `window.localStorage` — the browser store the web implementation writes its one entry to |
| [little_things](little_things.md) | module | `device_preferences.dart`, `user_preferences_client.dart` | `TomClientException` (see [little_things.md](little_things.md)) |

The client reaches the network through `TomPlatformUtils.current.httpClient()`,
so an application must register its platform
(`TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)`) at startup. The
neutral fallback throws rather than guessing, so a missing registration fails on
the first call instead of silently choosing a client.
