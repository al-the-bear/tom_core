# Tom Core Server API Reference: Item Authorization Module

Item authorizations kept by an external authority — Tom UAM — used by a Tom
application that keeps none of its own: the port to the authority, a client
that asks and caches, and the row scope it feeds.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomItemAuthorizationRecord](#tomitemauthorizationrecord)
  - [TomItemShareRequest](#tomitemsharerequest)
  - [TomAccessibleItemsPage](#tomaccessibleitemspage)
  - [TomSharedItemsPage](#tomshareditemspage)
  - [TomItemAuthority](#tomitemauthority)
  - [TomItemAuthorizationException](#tomitemauthorizationexception)
  - [TomItemAuthorizationClient](#tomitemauthorizationclient)
  - [TomItemAuthorityScopeSource](#tomitemauthorityscopesource)
- [Enums](#enums)
  - [TomShareSubjectKind](#tomsharesubjectkind)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/item_authorization/item_authority.dart`, `lib/src/tomserver/item_authorization/item_authority_scope_source.dart`, `lib/src/tomserver/item_authorization/item_authorization_client.dart`.

`TomItemAuthority` is the transport-neutral port to the authority. The
application's own questions — `checkItemPermission` on up to 100 items,
`queryAccessibleItems` page by page, `readItemAuthorizationChanges` — use the
application's credentials and name the principal; the user's acts —
`shareItem`, `changeItemAuthorization`, `revokeItemAuthorization`,
`listItemsSharedWithMe` — carry the signed-in user's token. Items cross it as
item keys `<type>:<id>`, levels as level names, `null` for none.

`TomItemAuthorizationClient` answers checks from `TomItemAuthorizationCache`
where it can and asks the rest in chunks, gathers and caches accessible-item
lists, passes the user's acts on and drops the answers each affects on every
node, and builds the change-feed follower. An answer given while an
invalidation was applied is not cached, and neither is one given while acting
for a delegator. `TomItemAuthorityScopeSource` feeds the `resource` row scope
from the client: per item type, the items at the weakest level granting `read`
are readable, those at the weakest level granting `full` writable.

## Class Hierarchy

```
TomItemAuthorizationRecord

TomItemShareRequest

TomAccessibleItemsPage

TomSharedItemsPage

TomItemAuthority  (interface)

TomServerException  (little_things)
    └── TomItemAuthorizationException

TomItemAuthorizationClient

TomResourceScopeSource  (object_persistence)
    └── TomItemAuthorityScopeSource
```

## Classes

### TomItemAuthorizationRecord

One item authorization as the authority keeps it: `subjectKind` `subjectId`
holds `level` on `item`, from `validFrom` to `validTo`.

#### Constructors

```dart
const TomItemAuthorizationRecord({required String id, required String item, required TomShareSubjectKind subjectKind, required String subjectId, required String level, DateTime? validFrom, DateTime? validTo})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The authorization's id at the authority (final). |
| `item` | `String` | The item key, `<type>:<id>` (final). |
| `subjectKind` | `TomShareSubjectKind` | Whether `subjectId` is a user or a group (final). |
| `subjectId` | `String` | The user or group (final). |
| `level` | `String` | The level, a level name of the item's type (final). |
| `validFrom` | `DateTime?` | When the authorization starts, or `null` for at once (final). |
| `validTo` | `DateTime?` | When it ends, or `null` for never (final). |
| `invalidationSubject` | `String?` | The subject an invalidation of this authorization names: the user, or `null` for a group, whose members the application cannot list. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The id, subject, level and item, for a log line. |

### TomItemShareRequest

What a user asks for when sharing an item.

#### Constructors

```dart
const TomItemShareRequest({required String item, required TomShareSubjectKind subjectKind, required String subjectId, required String level, DateTime? validFrom, DateTime? validTo, String? idempotencyKey})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `item` | `String` | The item key, `<type>:<id>` (final). |
| `subjectKind` | `TomShareSubjectKind` | Whether `subjectId` is a user or a group (final). |
| `subjectId` | `String` | The user or group (final). |
| `level` | `String` | The level to give (final). |
| `validFrom` | `DateTime?` | When the authorization starts, or `null` for at once (final). |
| `validTo` | `DateTime?` | When it ends, or `null` for never (final). |
| `idempotencyKey` | `String?` | Makes a repeated request — a retry after a lost answer — share once (final). |

### TomAccessibleItemsPage

One page of the items of a type a principal reaches.

#### Constructors

```dart
const TomAccessibleItemsPage({required List<String> itemIds, String? nextPage})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `itemIds` | `List<String>` | The application's ids of the items, the part after `<type>:` (final). |
| `nextPage` | `String?` | The token of the next page, or `null` on the last (final). |

### TomSharedItemsPage

One page of the authorizations shared with the signed-in user.

#### Constructors

```dart
const TomSharedItemsPage({required List<TomItemAuthorizationRecord> authorizations, String? nextPage})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authorizations` | `List<TomItemAuthorizationRecord>` | The authorizations, each naming its item, level and validity (final). |
| `nextPage` | `String?` | The token of the next page, or `null` on the last (final). |

### TomItemAuthority

The operations a Tom application needs from its item-authorization authority —
an `abstract interface class`, implemented by an adapter that speaks the
authority's protocol or by a test fake. A multi-tenant adapter reads the tenant
from `TomTenantContext`.

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `maximumItemsPerCheck` | `int` | 100: the most items one `checkItemPermission` call may name. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `checkItemPermission` | `Future<List<String?>> checkItemPermission(String principalId, List<String> items, {String? actingFor})` | The level `principalId` holds on each of `items`, in request order; `null` for none or an unknown item. With `actingFor`, the levels reached acting for that delegator. Application credentials. |
| `queryAccessibleItems` | `Future<TomAccessibleItemsPage> queryAccessibleItems(String principalId, String itemType, {required String minimumLevel, String? actingFor, String? page})` | One page of the ids of the items of `itemType` that `principalId` reaches at `minimumLevel` or above. Application credentials. |
| `readItemAuthorizationChanges` | `Future<TomItemAuthorizationChangePage> readItemAuthorizationChanges(String? cursor)` | The changes since `cursor`, `null` for the current position; throws `TomItemAuthorizationFeedExpiredException` for a cursor the feed no longer holds. Application credentials. |
| `shareItem` | `Future<TomItemAuthorizationRecord> shareItem(String userToken, TomItemShareRequest request)` | Shares an item as the user `userToken` belongs to. |
| `changeItemAuthorization` | `Future<TomItemAuthorizationRecord> changeItemAuthorization(String userToken, String authorizationId, {String? level, DateTime? validTo})` | Changes an authorization's level or end of validity, as the user. |
| `revokeItemAuthorization` | `Future<void> revokeItemAuthorization(String userToken, String authorizationId)` | Revokes an authorization — or leaves it, when the user is its subject. |
| `listItemsSharedWithMe` | `Future<TomSharedItemsPage> listItemsSharedWithMe(String userToken, {String? itemType, String? page})` | One page of the authorizations shared with the user. |

### TomItemAuthorizationException

A row scope over more items than the client may gather, refused rather than cut
short. Key `error.item_authority.scope_too_large`, with `itemType` and
`maximum`; `clientThrow: false` by default.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomItemAuthorizationException(String key, String defaultUserMessage, {Map<String, Object?>? parameters, bool clientThrow = false})
```

### TomItemAuthorizationClient

Asks the authority about items, caching each answer in
`TomItemAuthorizationCache`, and carries the user's sharing acts to it. A
principal is the subject by its id; a principal that is not signed in holds no
level and the authority is not asked. Answers given while acting for a
delegator are not cached, and an answer during which an invalidation was
applied on this isolate (`TomItemAuthorizationCache.generation`) is returned
but not stored.

#### Constructors

```dart
TomItemAuthorizationClient(TomItemAuthority authority, {int maximumScopeItems = defaultMaximumScopeItems})
```

#### Static Members

| Member | Type | Description |
| ------ | ---- | ----------- |
| `defaultMaximumScopeItems` | `int` | 10,000. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `authority` | `TomItemAuthority` | The authority asked (final). |
| `maximumScopeItems` | `int` | The most item ids `accessibleItemIds` gathers before refusing (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `levelOn` | `Future<String?> levelOn(TomPrincipal? principal, TomItemType type, String itemId, {String? actingFor})` | The level `principal` holds on one item, or `null`. |
| `levelsOn` | `Future<Map<String, String?>> levelsOn(TomPrincipal? principal, TomItemType type, List<String> itemIds, {String? actingFor})` | The level on each item, keyed by id in request order; cached answers used, the rest asked in calls of at most `maximumItemsPerCheck`; a level the type does not declare is none. |
| `allows` | `Future<bool> allows(TomPrincipal? principal, TomItemType type, String itemId, String level, {String? actingFor})` | Whether the principal holds `level` or a stronger one; `ArgumentError` for an undeclared `level`. |
| `accessibleItemIds` | `Future<List<String>> accessibleItemIds(TomPrincipal? principal, TomItemType type, {required String minimumLevel, String? actingFor})` | The ids of the items of `type` the principal reaches at `minimumLevel` or above, gathered page by page and cached; throws `TomItemAuthorizationException` past `maximumScopeItems`, `ArgumentError` for an undeclared level. |
| `share` | `Future<TomItemAuthorizationRecord> share(String userToken, TomItemShareRequest request)` | Shares as the user, then drops the subject's answers on the item on every node. |
| `change` | `Future<TomItemAuthorizationRecord> change(String userToken, TomItemAuthorizationRecord authorization, {String? level, DateTime? validTo})` | Changes an authorization as the user, then drops the answers it affects. |
| `revoke` | `Future<void> revoke(String userToken, TomItemAuthorizationRecord authorization)` | Revokes as the user, then drops the answers it affects. |
| `sharedWithMe` | `Future<TomSharedItemsPage> sharedWithMe(String userToken, {String? itemType, String? page})` | One page of what was shared with the user; not cached. |
| `followChanges` | `TomItemAuthorizationFeedFollower followChanges({Duration pollInterval = TomItemAuthorizationFeedFollower.defaultPollInterval, String? tenantId})` | A follower of the authority's change feed. |

### TomItemAuthorityScopeSource

A `TomResourceScopeSource` that asks the authority, through the client, which
items of each of `itemTypes` a principal reaches. Keys are item keys, so the
scoped table's resource-key column holds item keys.

- **Implements:** `TomResourceScopeSource`

#### Constructors

```dart
TomItemAuthorityScopeSource(TomItemAuthorizationClient client, Iterable<TomItemType> itemTypes)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `client` | `TomItemAuthorizationClient` | The client asked (final). |
| `itemTypes` | `List<TomItemType>` | The item types whose items the scoped tables hold (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `void install()` | Installs the source behind the built-in `resource` scope kind. |
| `readableResourceKeys` | `Future<List<Object?>> readableResourceKeys(TomPrincipal? principal)` | *(override)* Per type, the items at its weakest level granting `read`. |
| `writableResourceKeys` | `Future<List<Object?>> writableResourceKeys(TomPrincipal? principal)` | *(override)* Per type, the items at its weakest level granting `full`; nothing for a type with no such level. |

## Enums

### TomShareSubjectKind

Whom an item is shared with.

| Value | Meaning |
| ----- | ------- |
| `user` | One user. |
| `group` | A group; every member reaches the item. |

## Global Functions and Constants

None.
