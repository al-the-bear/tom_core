# Item Authorization Module

Item authorizations kept by an external authority, used by a Tom application
that keeps none of its own. Tom UAM is that authority for Tom applications: a
user shares a document, a todo or any other item with another user or a group
at a permission level, and the application asks Tom UAM what a principal may do.
This module is the application's side of that arrangement — a client that asks
and caches, a row scope fed by it, and the port an adapter implements to speak
the authority's protocol.

The pieces it builds on live elsewhere: the levels are the kernel's item
permission levels (`TomItemType`, kernel `security.md` § Item Permission
Levels), and the cache together with the two ways the authority reports a
change — its webhook and its change feed — is the cache module's
([cache.md § Item-Authorization Answers](cache.md#item-authorization-answers)).

## Table of Contents

- [Overview](#overview)
- [The External-Authority Pattern](#the-external-authority-pattern)
- [Two Kinds of Call](#two-kinds-of-call)
- [Checking a Level](#checking-a-level)
- [The Row Scope](#the-row-scope)
- [Sharing for the User](#sharing-for-the-user)
- [How a Change Reaches the Cache](#how-a-change-reaches-the-cache)
- [Starting Up](#starting-up)
- [Limits](#limits)
- [Failure Keys](#failure-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomItemAuthority` | abstract interface class | The port to the authority, implemented by an adapter or a test fake |
| `TomItemAuthorizationClient` | class | Checks and accessible-item queries, cached; the user's sharing acts; the feed follower |
| `TomItemAuthorityScopeSource` | class | The `resource` row scope fed by the client |
| `TomItemAuthorizationRecord` | class | One authorization as the authority keeps it |
| `TomItemShareRequest` | class | A share as a user asks for it |
| `TomShareSubjectKind` | enum | `user` or `group` |
| `TomAccessibleItemsPage` | class | One page of the items a principal reaches |
| `TomSharedItemsPage` | class | One page of the authorizations shared with the user |
| `TomItemAuthorizationException` | class | A row scope larger than the client may gather |

## The External-Authority Pattern

The authorization module's grants live in the application's own database: a
principal holds a role on a resource key, and the row scope reads those grants.
Item authorizations are different in kind. They change while a token lives,
they reach users through groups and delegations, and several applications share
one picture of them — what was shared with a user, in every application. So
they live in one authority, and an application asks it.

Asking on every request would put the authority's latency into every check and
its availability into every page. The pattern is therefore:

1. **ask** the authority — through the `TomItemAuthority` port — the first time
   a question comes up;
2. **cache** the answer, per item and subject, or per subject and item type for
   an accessible-item list;
3. **drop** the cached answer when the authority reports a change that names
   its item or subject — on every node, through the invalidation channel;
4. **age out** whatever no report reached, after the cache's lifetime.

The row scope is fed by the same cache, so a list view shows what the user owns
and what was shared with them without the application storing either.

## Two Kinds of Call

Each operation of the port is one or the other:

| Call | Credentials | Through the client |
| ---- | ----------- | ------------------ |
| `checkItemPermission` — the level on up to 100 items | the application's, naming the principal | `levelOn`, `levelsOn`, `allows` |
| `queryAccessibleItems` — one page of the items of a type reached at a minimum level | the application's, naming the principal | `accessibleItemIds`, the row scope |
| `readItemAuthorizationChanges` — the change feed since a cursor | the application's | `followChanges` |
| `shareItem`, `changeItemAuthorization`, `revokeItemAuthorization` | the signed-in user's token | `share`, `change`, `revoke` |
| `listItemsSharedWithMe` | the signed-in user's token | `sharedWithMe` |

The application's own questions name the principal they are about; the user's
acts carry the user's token, exchanged for the authority's item interface, so
that the decision — never a level above the sharer's own — and its audit entry
are the user's. A multi-tenant adapter reads the tenant from `TomTenantContext`
and uses that tenant's credentials.

## Checking a Level

```dart
final document = TomItemType.standard('document');

final level = await client.levelOn(principal, document, documentId);
final mayComment = await client.allows(principal, document, documentId, 'comment');
final levels = await client.levelsOn(principal, document, documentIds);
```

- A principal is the subject by its id, the id the authority names users by in
  its change reports. A principal that is not signed in holds no level, and the
  authority is not asked.
- Cached answers are used as they are; the rest are asked in calls of at most
  `TomItemAuthority.maximumItemsPerCheck` (100) items.
- A level the type does not declare is answered as none. Asking `allows` for a
  level the type does not declare is a programmer error (`ArgumentError`).
- **An answer overtaken by a change is not cached.** The client notes
  `TomItemAuthorizationCache.generation` before it asks and stores the answer
  only when no invalidation was applied meanwhile, since one that arrived during
  the question may concern the answer. Invalidations are applied on the main
  isolate, so the guard holds for a client there.
- **Acting for a delegator** (`actingFor`) is asked every time. The cache is
  keyed by subject, and a delegation's changes do not name the delegate.

## The Row Scope

`TomItemAuthorityScopeSource` is a `TomResourceScopeSource`: installed behind
the built-in `resource` scope kind, it decides which rows of a table whose
resource-key column holds item keys (`<type>:<id>`) a principal sees and may
write.

```dart
TomItemAuthorityScopeSource(client, [document, todo]).install();
```

| Question | Keys answered |
| -------- | ------------- |
| `readableResourceKeys` | for each type, the items at its weakest level that grants `read` or above |
| `writableResourceKeys` | for each type, the items at its weakest level that grants `full` |

"Weakest level that grants" is `TomItemType.lowestLevelGranting`; a type with
no level granting `full` contributes nothing writable. The lists come from
`TomItemAuthorizationClient.accessibleItemIds`, which pages through the
authority's answers and caches the whole list per subject, type and minimum
level. A change on an item of the type that names the subject — or no subject,
as a change for a group does — drops the list.

## Sharing for the User

```dart
final record = await client.share(
  userToken,
  TomItemShareRequest(
    item: document.keyFor(documentId),
    subjectKind: TomShareSubjectKind.user,
    subjectId: colleagueId,
    level: 'comment',
  ),
);
await client.change(userToken, record, level: 'view');
await client.revoke(userToken, record);
```

Each act passes to the authority and then drops the answers it affects on every
node: the subject's on the item, or every subject's when the subject is a group,
whose members the application cannot list. The authority's own report of the
same change arrives later and drops them again, which is harmless. A refusal —
a level above the sharer's own, a subject outside the tenant — is the
authority's, and reaches the caller as the adapter's exception.

`sharedWithMe` lists what was shared with the user, page by page. It is not
cached: it is a list the user reads, not a decision.

## How a Change Reaches the Cache

A change made anywhere — in this application, another one, or the authority's
own screens — reaches the cache in one of two ways, both described in the cache
guide:

| Path | Delay until every node stops granting |
| ---- | ------------------------------------- |
| the `itemAuthorization.changed` webhook, through `TomItemAuthorizationWebhook` | the invalidation channel's bound |
| the change feed, through the follower `client.followChanges()` returns | the poll interval plus the channel's bound |
| neither | the cache's lifetime, five minutes by default |

## Starting Up

```dart
final document = TomItemType.standard('document');
TomItemTypeRegistry.register(document);
TomItemAuthorizationCache.install();
await TomCacheInvalidator.install(TomSqlInvalidationChannel.named('main'));

final client = TomItemAuthorizationClient(uamAdapter);
TomItemAuthorityScopeSource(client, [document]).install();
await client.followChanges().start();
```

The webhook receiver is mounted by the application's own endpoint, which hands
each delivery to `TomItemAuthorizationWebhook.receive`.

## Limits

| Limit | Value | Where |
| ----- | ----- | ----- |
| Items in one check call | 100 | `TomItemAuthority.maximumItemsPerCheck`; the client splits larger requests |
| Items one accessible-item list may gather | 10,000 by default | `TomItemAuthorizationClient.maximumScopeItems`; beyond it the list is refused |

A row scope is rendered as `<column> IN (…)`, so it cannot grow without bound.
Past the limit the client refuses rather than cutting the list short: a
shortened scope would hide rows without saying so.

## Failure Keys

| Key | Raised when |
| --- | ----------- |
| `error.item_authority.scope_too_large` | `accessibleItemIds` gathers more than `maximumScopeItems` ids. A `TomItemAuthorizationException` (`clientThrow: false`), carrying `itemType` and `maximum`. |

## Not Yet Implemented

- **No adapter for Tom UAM's protocol.** `TomItemAuthority` is the port; the
  adapter that speaks Tom UAM's item interface follows Tom UAM's interface
  specification, which defines the paths and payloads.
  <!-- unpinned: absence — no adapter for Tom UAM's protocol exists -->
- **No local copy.** An application whose row scope covers more items than a
  list may gather would keep a copy of its item types' authorizations, fed by
  the change feed; the client answers only online, from its cache.
  <!-- unpinned: absence — no local copy exists -->

## Verification

`test/item_authorization_client_test.dart` runs the module against a fake
authority that keeps owners, groups and authorizations the way Tom UAM does —
levels resolved from ownership, direct and group authorizations, answers paged,
every change written to a change feed. It covers checks answered from the cache
and asked in chunks of at most 100, the type's order, undeclared levels,
principals not signed in, acting for a delegator, an answer overtaken by a
change; a share revoked or changed through the client and one revoked
elsewhere and reported on the feed; group shares; the accessible-item lists,
their pages, their invalidation and their limit; and the row scope's readable
and writable keys, including after a revocation. The cache and the two report
paths are covered by `test/item_authorization_invalidation_test.dart`.

```bash
dart run example/item_authorization/item_authorization_example.dart
```

`example/item_authorization/item_authorization_example.dart` walks the module
in seven steps against a small in-memory authority — a level, a share for the
signed-in user, checks by the type's order, a check answered from the cache, the
row scope, a revocation, and a revocation made elsewhere arriving through the
change feed. Every step checks its own result, and `test/examples_test.dart`
runs it.

## Core Components

- **`TomItemAuthority`** — the port: the application's questions and the user's
  acts, items as item keys and levels as level names.
- **`TomItemAuthorizationClient`** — `levelOn`, `levelsOn`, `allows`,
  `accessibleItemIds`, `share`, `change`, `revoke`, `sharedWithMe`,
  `followChanges`; `maximumScopeItems`.
- **`TomItemAuthorityScopeSource`** — the row scope over the client; `install`.
- **`TomItemAuthorizationRecord`**, **`TomItemShareRequest`**,
  **`TomShareSubjectKind`**, **`TomAccessibleItemsPage`**,
  **`TomSharedItemsPage`** — what crosses the port.
- **`TomItemAuthorizationException`** — the refused row scope.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `tom_core_kernel` | package | `item_authority_scope_source.dart`, `item_authorization_client.dart` | `TomItemType` (levels and their grades), `TomPrincipal`, `TomAuthState` |
| [cache](cache.md) | module | `item_authority.dart`, `item_authorization_client.dart` | `TomItemAuthorizationCache` (the answers), `TomCacheInvalidator` (dropping them on every node), `TomItemAuthorizationChangePage` and `TomItemAuthorizationFeedFollower` (the change feed) |
| [little_things](little_things.md) | module | `item_authorization_client.dart` | `TomServerException`, the base of `TomItemAuthorizationException` |
| [object_persistence](object_persistence.md) | module | `item_authority_scope_source.dart` | `TomResourceScopeSource` and `TomDataScopeRegistry`, the row-scope seam |
