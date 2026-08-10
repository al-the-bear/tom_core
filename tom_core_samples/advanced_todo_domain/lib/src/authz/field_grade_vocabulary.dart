/// The §A.4 per-field grade matrix — the *finer* concern the resource-role
/// registry ([registerProjectRoleVocabulary]) explicitly defers to.
///
/// The framework's [TomResourceRoleRegistry] resolves a [ProjectRole] to a single
/// **resource-level** [TomAuthState] (owner/editor → full, commenter/viewer →
/// read). That is the ceiling a principal has on a whole resource. Inside that
/// ceiling the advanced sample grades individual item fields differently per
/// role — an editor may edit the title but only read the assignee; a viewer sees
/// a disabled status control but a read-only priority. That per-field vocabulary
/// cannot come from the resource-level registry (which collapses owner≡editor and
/// commenter≡viewer); it lives here, in the shared domain, so both the server's
/// enforcement and the client's item screen grade the same fields identically.
///
/// The item screen composes the two: it resolves the item's resource-level state
/// through the framework registry and **narrows** it by the field's grade from
/// this matrix. Because every role's field grades sit at or below its
/// resource-level ceiling, the narrow is an identity over this matrix — so the
/// composition reproduces §A.4 exactly while making the registry the load-bearing
/// resource-level gate (no role → resource state `none` → every field collapses).
///
/// The same vocabulary carries one graded key that is **not** a form field:
/// [itemAttachmentGradeKey], the item's file column. It is graded per role like
/// the fields are, but enforced on the file endpoint rather than in the item
/// payload — see [projectRoleAttachmentGrades] for why the distinction is
/// load-bearing.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../enums.dart';

/// The resolved per-field [TomAuthState] for each [ProjectRole], keyed by the
/// gradable item resource keys (`todo.item.<field>`).
///
/// Read down the columns to see all four states:
///
/// | field       | owner | editor | commenter | viewer   |
/// | ----------- | ----- | ------ | --------- | -------- |
/// | title       | full  | full   | read      | read     |
/// | status      | full  | full   | read      | disabled |
/// | priority    | full  | full   | none      | read     |
/// | assigneeId  | full  | read   | read      | read     |
/// | dueDate     | full  | full   | read      | read     |
/// | estimate    | full  | read   | none      | none     |
/// | description | full  | full   | read      | read     |
///
/// `owner` is fully editable; `editor` cannot reassign or edit the estimate
/// (read); `commenter` cannot see `priority`/`estimate` (none); `viewer` can
/// toggle nothing — `status` renders disabled while the rest are read-only. A
/// field absent from a role's map (or a role absent here) resolves closed-safe to
/// [TomAuthState.none].
///
/// This is the **client's** copy, used to shape the item form without a round
/// trip; the *authoritative* copy is the `tom_resource_grant` row the auth server
/// seeds and the authadmin console edits, which the app server resolves on every
/// write. The two are seeded identically and may then diverge — an administrator
/// who narrows `editor`'s `title` to `read` changes the server's answer, not this
/// map, and the server's answer is the binding one; the shaping here is
/// cooperation rather than enforcement. That both *start* identical is not left
/// to care: `advanced_auth_server/test/grant_matrix_key_consistency_test.dart`
/// parses the seed SQL and asserts it against this map cell-for-cell, so a
/// regrade applied to one side alone fails there rather than silently at runtime.
/// [projectRoleAttachmentGrades] carries the same duality for the file column.
///
/// One consequence of the `viewer`/`status` cell is worth naming, because it is
/// the matrix's only [TomAuthState.disabled] and `disabled` is *masked*
/// (`showsContent` is false): the server's write path preserves a changed
/// `disabled` field silently instead of rejecting it the way it rejects a change
/// to a visible `read` field. Both are non-writable; they differ in the shape of
/// the refusal. See `TomColumnAuthorization.decideWrites`.
const Map<ProjectRole, Map<String, TomAuthState>> projectRoleFieldGrades = {
  ProjectRole.owner: {
    'todo.item.title': TomAuthState.full,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.full,
    'todo.item.assigneeId': TomAuthState.full,
    'todo.item.dueDate': TomAuthState.full,
    'todo.item.estimate': TomAuthState.full,
    'todo.item.description': TomAuthState.full,
  },
  ProjectRole.editor: {
    'todo.item.title': TomAuthState.full,
    'todo.item.status': TomAuthState.full,
    'todo.item.priority': TomAuthState.full,
    'todo.item.assigneeId': TomAuthState.read,
    'todo.item.dueDate': TomAuthState.full,
    'todo.item.estimate': TomAuthState.read,
    'todo.item.description': TomAuthState.full,
  },
  ProjectRole.commenter: {
    'todo.item.title': TomAuthState.read,
    'todo.item.status': TomAuthState.read,
    'todo.item.priority': TomAuthState.none,
    'todo.item.assigneeId': TomAuthState.read,
    'todo.item.dueDate': TomAuthState.read,
    'todo.item.estimate': TomAuthState.none,
    'todo.item.description': TomAuthState.read,
  },
  ProjectRole.viewer: {
    'todo.item.title': TomAuthState.read,
    'todo.item.status': TomAuthState.disabled,
    'todo.item.priority': TomAuthState.read,
    'todo.item.assigneeId': TomAuthState.read,
    'todo.item.dueDate': TomAuthState.read,
    'todo.item.estimate': TomAuthState.none,
    'todo.item.description': TomAuthState.read,
  },
};

/// The gradable item resource keys, in display order — the columns of
/// [projectRoleFieldGrades] (the owner map carries the full set). The item
/// screen and the backends resolve grades over exactly these keys.
const List<String> gradableItemKeys = [
  'todo.item.title',
  'todo.item.status',
  'todo.item.priority',
  'todo.item.assigneeId',
  'todo.item.dueDate',
  'todo.item.estimate',
  'todo.item.description',
];

/// The C-4 resource key of the item's **attachment column** — the graded file
/// column behind the slot `app_items/<id>/attachment`.
///
/// Deliberately *not* a member of [gradableItemKeys], because it is not a form
/// field. The keys in that list name JSON members a client sends back in an item
/// payload; this one names a **blob-key column** which no client may ever write
/// directly — the key is minted server-side by `saveFile`, and a caller able to
/// write it would repoint their row at somebody else's bytes. Keeping it out of
/// the gradable field set is what keeps it out of the item write path's
/// overlay; it is graded on the *file endpoint* instead, where the only thing a
/// caller can supply is bytes.
const String itemAttachmentGradeKey = 'todo.item.attachment';

/// The per-role grade of the attachment column ([itemAttachmentGradeKey]).
///
/// | role      | attachment | meaning                                  |
/// | --------- | ---------- | ---------------------------------------- |
/// | owner     | full       | download and replace                     |
/// | editor    | full       | download and replace                     |
/// | commenter | read       | download only — the upload is refused    |
/// | viewer    | read       | download only — the upload is refused    |
///
/// This is the **client's** copy of the default, used to shape the attachment
/// field; the *authoritative* copy is the `tom_resource_grant` row the auth
/// server seeds and the authadmin console edits, which the app server resolves
/// per row at the file endpoint. The two are seeded identically and may then
/// diverge — an administrator who narrows `owner` to `read` changes the server's
/// answer, not this map, and the server's answer is the binding one. That is
/// exactly the duality [projectRoleFieldGrades] already has, and the reason the
/// client's shaping is cooperation rather than enforcement.
const Map<ProjectRole, TomAuthState> projectRoleAttachmentGrades = {
  ProjectRole.owner: TomAuthState.full,
  ProjectRole.editor: TomAuthState.full,
  ProjectRole.commenter: TomAuthState.read,
  ProjectRole.viewer: TomAuthState.read,
};
