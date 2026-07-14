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
/// The mapping mirrors the sample's §A.4 resource-level policy: an `owner` or
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
/// Idempotent: [TomResourceRoleRegistry.registerAll] overwrites, so calling it
/// again at another runtime's boot re-establishes the same mapping. The runtimes
/// that resolve a [ProjectRole] resource to a grade call this once at startup so
/// the resource-role adapter resolves grades consistently on both tiers: the
/// auth server, the app server, and the end-user app client. The administrator
/// console does not grade `ProjectRole` resources (it edits users/roles/grants),
/// so it does not register this vocabulary.
void registerProjectRoleVocabulary() {
  TomResourceRoleRegistry.registerAll(<String, TomAuthState>{
    ProjectRole.owner.name: TomAuthState.full,
    ProjectRole.editor.name: TomAuthState.full,
    ProjectRole.commenter.name: TomAuthState.read,
    ProjectRole.viewer.name: TomAuthState.read,
  });
}
