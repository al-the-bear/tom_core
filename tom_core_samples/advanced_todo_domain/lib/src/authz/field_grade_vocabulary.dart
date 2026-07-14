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
