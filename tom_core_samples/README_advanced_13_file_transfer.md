# File transfer under the authorization matrix

<!-- doc-samples: packages tom_core_kernel, tom_core_server, tom_flutter_ui, tom_core_samples/advanced_app_server, tom_core_samples/advanced_client_core, tom_core_samples/advanced_app_client -->

*Part 13 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

The previous twelve parts build a secured system and then prove it. This part
takes **one feature** — moving bytes in and out of the system — and follows it
through every layer of that system, because file transfer is where an
authorization model is most often quietly abandoned. Uploads tend to acquire
their own permission scheme: a token in a query string, a "signed URL", an
`isPublic` flag on a bucket. This sample deliberately does the opposite. An
item's attachment is a **column** like any other, and who may read or replace it
is decided by the very same `tom_resource_grant` row that decides whether the
item's *title* is editable — the row an administrator edits in the console from
[Part 11](README_advanced_11_clients_app_admin.md), through the API from
[Part 10](README_advanced_10_servers_endpoints.md).

That claim is the reason this part exists, and it is asserted rather than
described: `advanced_client_core/tool/run_cross_tier_integration.sh` narrows one
grant cell through the admin API and watches the owner of a row lose the right to
upload to it (**TC-37-09**).

The *storage* mechanics — the `@TomFileReference` column, the blob stores, the
migrations — are [Part 05](README_advanced_05_persistence_database.md#file-columns--the-blob-stores);
the *endpoint* is
[Part 10](README_advanced_10_servers_endpoints.md#the-file-endpoint). This part
is the authorization story that joins them, plus the client half and the proof.

## Three declarations, and each one is silent when it is lost

A file column in this sample says at most three things, all of them next to the
field they govern:

```dart
// advanced_app_server — ItemRecord
@TomDbColumn(
  columnName: itemAttachmentColumn,       // 'attachment'
  authKey: itemAttachmentGradeKey,        // 'todo.item.attachment'
)
@TomFileReference(
  keyPrefix: 'items/attachment',
  exposed: true,
  cascadeDelete: true,
)
String? attachment;
```

| Declaration | Decides | What its loss looks like |
| --- | --- | --- |
| `exposed` | whether the column is **addressable over HTTP** at all | nothing fails to compile; the feature simply stops existing, or starts existing |
| `cascadeDelete` | whether deleting the row **reclaims the bytes** | nothing fails at request time; blobs orphan quietly, one per deleted row |
| `authKey` | which **C-4 grade** governs read and write of this column | nothing fails at all — the column falls back to the process-global `TomAuthorization`, which answers `full` for everyone when no adapter is installed |

The third row is the dangerous one, and it is why the sample carries a
declaration test per server rather than trusting the source text. An ungraded
file column on a graded entity is not a compile error, not a runtime error, and
not visibly different in any response — it is simply a column everyone who can
see the row may also overwrite. `file_column_declarations_test.dart` (in both
`advanced_app_server` and `advanced_auth_server`) reads these three facts back
through the **same reflection the repository reads at runtime**, so the
assertions cannot pass against a stale comment.

The suite's three file columns are chosen to make every one of these decisions
visible in a pair:

| Column | `exposed` | `cascadeDelete` | `authKey` | The contrast it draws |
| --- | --- | --- | --- | --- |
| `app_items.attachment` | **true** | **true** | `todo.item.attachment` | the full case: reachable, graded per row, dies with its item |
| `app_items.internal_note` | *false* (default) | true | *(none)* | **default-closed**: the same row, the same principal, no slot |
| `auth_users.avatar_ref` | true | **false** | *(none)* | a blob that **outlives** the row that named it |

The avatar carries no `authKey` on purpose: a user owns their own picture, and
the row scope on `auth_users` already answers who may reach the row. Adding a
key there would demand a resolver the auth server does not register — and an
unregistered key falls back to the permissive global, which is the failure mode
the table above warns about.

## From a declaration to a slot

`TomFileSlots.register(itemRepository)` — one line per entity at boot — turns the
*exposed* file columns of that entity into addressable slots and leaves the
others unpublished. It is per entity, not per column: the same call publishes
`attachment` and not `internal_note` purely from what the two declare.

That is the **first refusal layer**, and it is not an authorization decision at
all. Exposure is consulted while *resolving the slot*, before any principal is
looked at, so `TomFileSlots.resolve('app_items', 'internal_note')` returns `null`
exactly as it would for a column that does not exist — and the endpoint answers
both with a plain **404** (`file_endpoint.unknown_slot`), for everybody equally,
including the owner of the row who is graded `full` on its neighbour. There is no
authorization question to ask about a column HTTP cannot name, and answering 403
would confirm the column is there.

## The C-4 grade, resolved per row

The `authKey` on `attachment` names a grade, and that grade cannot come from the
framework's default source. `TomAuthorization` is a **process-global, synchronous
singleton**: one adapter for the whole server, answering without awaiting
anything. The grade this sample needs is neither.

- It is **per request** — a server handling alice and carol at once has two
  answers.
- It is **per row** — alice may replace the attachment of an item in a project
  she owns and only download the one in a project shared with her as a viewer.
  The role lives in another table, in another database, so it cannot be computed
  synchronously at all.

`TomRowColumnAuthorization` is the framework seam for that shape — the
column-grade counterpart of the async data scopes that already back C-3. A
stateless resolver is registered once at boot against the column's `authKey` and
awaited per operation with the request's principal and the row's id; only
`saveFile` / `openFile` / `describeFile` / `clearFile` consult it, because those
address exactly one row and are already asynchronous.

```dart
// advanced_app_server — registerAppColumnGrades(), called once at boot
TomRowColumnAuthorization.register(
  itemAttachmentGradeKey,
  ItemAttachmentGradeResolver.production().gradeFor,
);
```

The resolver itself introduces nothing new. It is the app server's two existing
authorization layers, composed in the order the JSON endpoints already use them:

1. **`ResourceRoleResolver`** — the caller's effective `ProjectRole` on
   `item:<rowId>`, folding C-5 ownership grants and C-6 shares and applying the
   containment rule (an item inherits its project's role). No role ⇒
   `TomAuthState.none`.
2. **`FieldGradeResolver`** — that role's grade for `todo.item.attachment`, read
   from the seeded `tom_resource_grant` matrix in `auth_db`.

Closed-safe at every edge, and each edge is pinned by
`advanced_app_server/test/column_grade_resolver_test.dart`: no principal, a
non-numeric principal id, an unparseable row id, a stranger with no role, a role
with no grant row for the key — all `none`. A `null` row id is an insert, and a
row that does not exist belongs to no project, so it too resolves `none`.

Because step 2 reads the grant matrix rather than a constant, the **matrix is the
authority and the code is not**. That is the property TC-37-09 exercises over the
live stack: an administrator narrows `owner` → `todo.item.attachment` from `full`
to `read` through `PUT /admin/grants`, and alice — who owns the item — keeps the
download and loses the upload. Restoring the cell gives it back. One grant row,
edited in the console that already edits form-field grades, decides whether bytes
may be written.

### Why the attachment key is *not* a gradable field

`itemAttachmentGradeKey` is deliberately absent from `gradableItemKeys`, the
seven `todo.item.<field>` keys the item form iterates. The seven are **form
fields** bound to members of `TodoItem`; the attachment is a **column** whose
value is a storage key the server stamps. Keeping it out of that list is what
stops a client from minting a storage key by editing an item — the server's
writable bindings simply do not contain the column — and it is why
`ItemAttachmentGradeResolver.production()` passes the key list explicitly instead
of accepting the default — the domain's `gradableItemKeys`, the form fields.

It is still graded by the same matrix, in the same table, with the same four
states. Only the delivery mechanism differs.

## Three refusals, three different questions

The endpoint answers a refusal differently depending on which layer refused, and
the live suite pins one test to each. The distinctions are the substance of the
feature, not incidental status codes:

| Layer | Asked | Answer | Live anchor |
| --- | --- | --- | --- |
| **Exposure** | while resolving the slot, before any principal exists | **404** `file_endpoint.unknown_slot` — for everyone, owner included | **TC-FT-03** |
| **The gate** | at the endpoint, before the handler runs (`TomAuthenticatedAccess`) | **403** — no principal, nothing principal-relative can be decided | **TC-FT-04** |
| **Row scope (C-3)** | per principal, per row | **404** — an unreachable row is reported missing, never *forbidden* | (part [10](README_advanced_10_servers_endpoints.md#the-file-endpoint)) |
| **Column grade (C-4)** | per principal, per row, once the slot and caller are both known | **403** `column_authorization.{read,write}.field_forbidden` — the row is not in question, the column is | **TC-FT-05** |

TC-FT-05 is the assertion that joins file transfer to the sample's existing
thesis. Carol holds a `viewer` share on alice's project, which the seeded matrix
grades `read` on the attachment column. Over the live stack she gets the
descriptor and the **complete bytes** — a read grade serves the file, it does not
hand back a redacted stand-in — and both write verbs are refused with 403: the
replace *and* the delete, because a grade that refuses the replace must refuse the
delete or the read-only file could still be destroyed. The test then re-downloads
and finds alice's bytes intact, proving both refusals landed before the blob store
was touched.

Set against TC-FT-03 on the neighbouring column of the *same row*, the pair says
the thing that is easy to state and hard to keep true: **`exposed` decides which
column a slot names, never whether this caller may have it.**

## The client half is cooperation, not enforcement

The end-user app renders the attachment through `TomFormFileUpload`, scoped under
`board.item.attachment` so its label, caption and messages resolve from the
server-delivered bundle like every other text ([Part 08](README_advanced_08_resources_texts.md)).
It is **not** a member of `TodoItemForm` — the field holds a `TomFileRef`, the
entity member holds a storage key, and the bytes travel over a different
endpoint — so `item_detail_screen.dart` grades it by hand where the form's
`gradableFields` loop cannot reach:

```dart
final grade = role == null
    ? TomAuthState.none
    : (projectRoleAttachmentGrades[role] ?? TomAuthState.none);
TomFormFileUpload(
  'item.attachment',
  …,
  authorizer: TomAuthorizer.fixed(resourceState.narrow(grade)),
);
```

The shape is exactly the fields' shape: the registry-resolved **resource
ceiling** narrowed by the role's grade, composition that can only restrict.
`projectRoleAttachmentGrades` grades owner and editor `full`, commenter and
viewer `read` — so an editor keeps the picker and a viewer sees only the download
(**TC-D13-01**, **TC-D12-05**), and if the resource-role registry cannot resolve
a role at all the field disappears rather than defaulting to an owner's
(**TC-D13-02**).

None of that is a permission. It is an affordance the user would otherwise be
offered and then refused; the binding answer is the app server's per-row grade at
the file endpoint. An administrator who edits the grant row changes the server's
answer without touching this map — which is precisely what TC-37-09 does, and why
the client map may safely be a plain constant.

Between the client and the endpoint sits `AuthorizedFileTransferClient`
(`advanced_client_core`), which presents the bearer token on all five verbs and
replays a transfer once after refreshing an expired one — re-reading the source
so the retry sends the same bytes, and *not* retrying a refusal that arrives after
the first chunk. Its twelve tests (`authorized_file_transfer_test.dart`,
TC-AFT-01…12) are socket-free.

## Cascade delete: who proves what

`cascadeDelete` is the one claim in this part the sample deliberately does **not**
assert end-to-end, and the division of labour is worth stating because it looks
like a gap.

Over HTTP the flag is unobservable. A client cannot inspect a blob store, and
after either kind of delete the row is gone, so both slots answer 404 whether or
not the bytes were reclaimed. The behaviour therefore has to be proved where the
blob store can be read directly, and it already is:
`tom_core_server/test/file_storage_db_test.dart` deletes rows against a real
MariaDB and shows a `cascadeDelete: true` column losing its bytes while a
`cascadeDelete: false` one keeps them.

What is left over is genuinely this sample's, and it is the half the framework
cannot know: that **these** columns carry **those** flags —
`app_items.attachment` cascading, `auth_users.avatar_ref` not. That is what the
two `file_column_declarations_test.dart` suites pin, read back through
reflection. Framework proves the mechanism; the sample proves its own
declarations. Neither suite duplicates the other.

## How the whole feature is proved

| Level | Suite | What it settles |
| --- | --- | --- |
| declarations | `advanced_app_server`, `advanced_auth_server` `file_column_declarations_test.dart` | the three flags on all three columns, plus `TomFileSlots.register` publishing the exposed column and only that one |
| server logic | `advanced_app_server/test/column_grade_resolver_test.dart` | role × grant composition, every closed-safe edge, and that narrowing the grant row takes the owner's upload away |
| client core | `advanced_client_core/test/authorized_file_transfer_test.dart` | token presentation, the single replay after refresh, and the refusals that must *not* be retried |
| widgets | `advanced_app_client/test/item_attachment_test.dart` | pick → upload → progress → download → clear; the grade matrix per role; the board's paperclip |
| live stack | `advanced_client_core/test/file_transfer_integration_test.dart` (TC-FT-01…05) | bytes through both blob stores, the closed column, the anonymous refusal, and the read-only grade |
| live loop | `advanced_client_core/test/cross_tier_integration_test.dart` (TC-37-09) | an admin grant edit reaching the file endpoint, and being undone |

The last two run only under
`advanced_client_core/tool/run_cross_tier_integration.sh`, which boots both
databases and both servers and treats a server-unreachable skip as a failure
([Part 12](README_advanced_12_testing_integration.md)). A file feature that
passed everything above it but not those two would be a demonstration; passing
them is what makes it part of the sample's authorization story.

## Building this into your own app

The whole feature, minus the tests, is five decisions:

1. **Annotate the column**, not a service: `@TomFileReference(exposed:,
   cascadeDelete:)` beside `@TomDbColumn(authKey:)`. Say `exposed: true` only for
   the columns HTTP should be able to name — the default is closed and requires
   nothing to be written.
2. **Publish slots with one `TomFileSlots.register(repository)` per entity** at
   boot, after reflection and the store registry, before serving. Never restate a
   table or column name.
3. **Point the store at the right database.** A `type: database` blob store names
   its datasource; that name is what keeps one tier's blobs out of the other
   tier's database.
4. **Register a per-row resolver for every graded file column** —
   `TomRowColumnAuthorization.register(authKey, resolver)` — and compose it from
   the authorization layers you already have. An `authKey` with no registered
   resolver silently falls back to the permissive global.
5. **Grade the client field by the same rule as the form fields** — resource
   ceiling narrowed by the role's grade, closed-safe — and treat it as
   cooperation.

[Appendix A4](README_advanced_A4_implementation_rules_checklist.md) carries these
as checklist lines with their enforcement anchors.

## Primary sources

- `advanced_app_server/lib/src/access/column_grade_resolver.dart`,
  `advanced_app_server/lib/src/persistence/app_persistence_model.dart`,
  `advanced_app_server/bin/app_server_start.dart` (the `TomFileSlots.register` line)
- `advanced_app_client/lib/screens/item_detail_screen.dart` (`_buildAttachmentField`),
  `advanced_todo_domain/lib/src/authz/field_grade_vocabulary.dart`
- `tom_core_server` `object_persistence/column_authorization.dart`,
  `endpoints/file_endpoint.dart`, `test/file_storage_db_test.dart`
- `advanced_client_core/test/{file_transfer_integration_test.dart, cross_tier_integration_test.dart}`

---

← Prev: [12 · Testing & cross-tier integration](README_advanced_12_testing_integration.md) · Next: [14 · Operations: scheduled work over live data](README_advanced_14_operations.md) →
