/// The [ProjectRole] → [TomAuthState] vocabulary for the framework's C-5
/// resource-role mechanism ([TomResourceRoleRegistry]).
///
/// The registry is the framework's global `roleName → TomAuthState` table that a
/// [TomResourceRoleAdapter] consults when it resolves a resource key to a grade:
/// `resourceRoles[key]` yields a role name, and the registry turns that role name
/// into the [TomAuthState] the UI renders the key through. For the advanced
/// sample to route its resource-level access through the framework (rather than
/// its bespoke resolver), every server and client must agree on how a
/// [ProjectRole] maps to an interaction grade — so this single registration is
/// the one place that vocabulary lives, called once at each runtime's boot.
///
/// The mapping mirrors the sample's resource-level policy: an `owner` or
/// `editor` interacts fully with a resource they hold; a `commenter` or `viewer`
/// sees it read-only. (Field-level *grades* within a resource — e.g. a member who
/// may see the title but not the priority — are a finer, separate concern the
/// field-grade matrix owns; this registry is only the resource-level role→grade
/// agreement the [TomResourceRoleAdapter] needs.)
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../enums.dart';

/// Registers the [ProjectRole] resource-role vocabulary in the framework's
/// [TomResourceRoleRegistry].
///
/// Idempotent: [TomResourceRoleRegistry.registerAll] overwrites, so a second
/// call — another runtime's boot, or a test's `setUp` — re-establishes the same
/// mapping rather than conflicting. Every runtime that resolves a [ProjectRole]
/// resource to a grade calls this once at startup, so the resource-role adapter
/// grades a key the same way wherever it runs. That is four boots: the auth
/// server, the app server, the ops server, and the end-user app client. The
/// administrator console is the only runtime that does not call it, because it
/// grades no [ProjectRole] resource — it edits users, roles and grants.
void registerProjectRoleVocabulary() {
  TomResourceRoleRegistry.registerAll(<String, TomAuthState>{
    ProjectRole.owner.name: TomAuthState.full,
    ProjectRole.editor.name: TomAuthState.full,
    ProjectRole.commenter.name: TomAuthState.read,
    ProjectRole.viewer.name: TomAuthState.read,
  });
}
