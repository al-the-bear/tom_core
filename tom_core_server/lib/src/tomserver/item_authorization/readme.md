# item_authorization

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Item authorizations kept by an external authority — Tom UAM — used by a Tom
application that keeps none of its own: who may view, comment on or edit which
of its documents, todos or other items. `TomItemAuthorizationClient` asks the
authority through the `TomItemAuthority` port, caches every answer until a
change names its item or subject, and carries the user's sharing acts to it.
`TomItemAuthorityScopeSource` feeds the grant-driven row scope from the same
client, so a list view shows what the user owns and what was shared with them.

The levels are the kernel's item permission levels (`TomItemType`). The cache
and the way changes arrive — the authority's webhook and its change feed — are
the cache module's (`TomItemAuthorizationCache`, `TomItemAuthorizationWebhook`,
`TomItemAuthorizationFeedFollower`).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomItemAuthority` | The port to the authority: `checkItemPermission` (at most 100 items a call), `queryAccessibleItems` (paged), `readItemAuthorizationChanges` with the application's credentials; `shareItem`, `changeItemAuthorization`, `revokeItemAuthorization`, `listItemsSharedWithMe` with the user's token. An adapter speaks the authority's protocol. |
| `TomItemAuthorizationClient` | The application's entry point: `levelOn` / `levelsOn` / `allows` answered from the cache where it can and asked in chunks where not; `accessibleItemIds` gathered page by page and cached; `share` / `change` / `revoke`, each dropping the answers it affects on every node; `sharedWithMe`; `followChanges` for the feed follower. Answers given while acting for a delegator are not cached. |
| `TomItemAuthorityScopeSource` | A `TomResourceScopeSource` over the client: readable keys are the items at each type's weakest level granting `read`, writable keys those at its weakest level granting `full`. `install()` puts it behind the `resource` scope kind. |
| `TomItemAuthorizationRecord` · `TomItemShareRequest` · `TomShareSubjectKind` | One authorization as the authority keeps it, a share as a user asks for it, and whether the subject is a user or a group. |
| `TomAccessibleItemsPage` · `TomSharedItemsPage` | The pages the authority answers with. |
| `TomItemAuthorizationException` | `error.item_authority.scope_too_large`: more accessible items than a row scope may hold, refused rather than cut short. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final document = TomItemType.standard('document');
  TomItemTypeRegistry.register(document);
  TomItemAuthorizationCache.install();

  final client = TomItemAuthorizationClient(uamAdapter);
  TomItemAuthorityScopeSource(client, [document]).install();
  await client.followChanges().start();

  // In a request:
  if (await client.allows(principal, document, documentId, 'comment')) {
    print('may comment');
  }
}
```

> **A fragment, not a program.** `uamAdapter` stands for the deployment's
> `TomItemAuthority` adapter, and `principal` and `documentId` for what a
> request brings — none of which a standalone script has. It is shown whole
> because the four steps belong to one start-up and mislead when shown apart.

See [`doc/item_authorization.md`](../../../../doc/item_authorization.md) for the
two kinds of call and their credentials, the cache and how changes drop it, the
row scope, and the limits, and
`example/item_authorization/item_authorization_example.dart` for a walkthrough
against a small in-memory authority that checks its own results.
`test/item_authorization_client_test.dart` covers the
module against a fake authority that keeps owners, groups and authorizations
the way Tom UAM does; `test/readme_quick_start_test.dart` holds the fragment
above to admitting that it is one, and `test/examples_test.dart` runs the
example.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
