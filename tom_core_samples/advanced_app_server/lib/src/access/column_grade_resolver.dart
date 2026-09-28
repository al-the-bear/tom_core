/// Per-row C-4 column grades: the file endpoint's half of the authorization
/// story, resolved through the *same* two layers the JSON endpoints use.
///
/// The item's `attachment` is an authorized column ([itemAttachmentGradeKey]).
/// A grade for it cannot come from the process-wide [TomAuthorization]
/// singleton the framework consults by default, for two independent reasons:
///
///  * **It is per-request.** `TomAuthorization` is one global adapter for the
///    whole process; a server handling two callers at once has two answers.
///  * **It is per-row.** The grade is *relational* — a principal may replace the
///    attachment of an item in a project they own and only download the one in a
///    project shared with them as a viewer. The role lives in another table, in
///    another database, so it cannot even be computed synchronously.
///
/// [TomRowColumnAuthorization] is the framework seam for exactly that shape (the
/// column-grade counterpart of the async data scopes in
/// `visible_resource_resolver.dart`): a stateless resolver registered once at
/// boot against the column's `authKey`, awaited per operation with the request's
/// principal and the row's id. Only `saveFile` / `openFile` / `describeFile`
/// consult it — they address exactly one row and are already asynchronous.
///
/// The resolution reuses the app server's existing layers verbatim, which is the
/// whole point: the file endpoint is not a second authorization scheme bolted on
/// beside the item endpoints, it is the same one reaching a different kind of
/// value.
///
///   1. [ResourceRoleResolver] — the caller's effective [ProjectRole] on
///      `item:<rowId>`, folding C-5 ownership grants and C-6 shares and applying
///      the containment rule. No role ⇒ [TomAuthState.none].
///   2. [FieldGradeResolver] — that role's grade for [itemAttachmentGradeKey],
///      read from the seeded `tom_resource_grant` matrix in `auth_db`. So an
///      administrator who narrows `owner`'s attachment grant to `read` through
///      the authadmin console changes what an owner may do with a *file*, using
///      the same screen, table and API that already govern the item's fields.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'field_grade_resolver.dart';
import 'resource_role_resolver.dart';

/// Registers the app server's per-row C-4 column grades on the framework
/// [TomRowColumnAuthorization] registry.
///
/// Called once at boot, under the same ordering constraint as
/// `registerAppDataScopes`: after *both* `initializeReflection()` and
/// `TomDataSourceInfo.initializeDatasourceInfo(...)`, because it eagerly builds
/// the production resolvers, whose repositories resolve their reflected types
/// and datasource metadata at construction time. Both resolvers are stateless
/// (they read the live repositories per call), so the single pair built here
/// serves every concurrent request.
void registerAppColumnGrades() {
  final grades = ItemAttachmentGradeResolver.production();
  TomRowColumnAuthorization.register(itemAttachmentGradeKey, grades.gradeFor);
}

/// Resolves the C-4 grade a principal holds on one item's `attachment` column.
///
/// Split out of [registerAppColumnGrades] so the composition — role first,
/// then that role's grant — is testable without a socket: both collaborators
/// already have in-memory seams ([InMemoryResourceContainmentStore],
/// [InMemoryGrantStore]).
class ItemAttachmentGradeResolver {
  /// Resolves the caller's effective [ProjectRole] on the addressed item.
  final ResourceRoleResolver roles;

  /// Resolves that role's grade for [itemAttachmentGradeKey] from the grant
  /// matrix.
  final FieldGradeResolver grades;

  /// Builds the resolver over the two collaborators (live at boot, seeded stores
  /// under test).
  const ItemAttachmentGradeResolver(this.roles, this.grades);

  /// The production wiring: the live resource-role resolver, and a field-grade
  /// resolver restricted to the attachment key.
  ///
  /// The key list is given explicitly rather than defaulted, because the default
  /// is the domain's *form field* set (`gradableItemKeys`) and the attachment is
  /// deliberately not in it — it is a column, not a field.
  factory ItemAttachmentGradeResolver.production() =>
      ItemAttachmentGradeResolver(
        ResourceRoleResolver.production(),
        FieldGradeResolver(
          const RepositoryGrantStore(),
          gradableItemKeys: const [itemAttachmentGradeKey],
        ),
      );

  /// The grade [principal] holds on the `attachment` of the item keyed by
  /// [rowId].
  ///
  /// Closed-safe at every step: no principal, a non-numeric principal id, an
  /// unparseable row id, or no role on the item all yield [TomAuthState.none],
  /// and a role with no grant row for the key resolves to `none` through the
  /// grant fold. A `null` [rowId] is an *insert* — a row that does not exist yet
  /// belongs to no project, so no role can be resolved for it and the answer is
  /// `none`; the sample never reaches that path, because the file endpoint
  /// always addresses a stored row.
  Future<TomAuthState> gradeFor(TomPrincipal? principal, Object? rowId) async {
    if (principal == null) return TomAuthState.none;
    final userId = int.tryParse('${principal.user.id}');
    final itemId = int.tryParse('$rowId');
    if (userId == null || itemId == null) return TomAuthState.none;
    final role = await roles.resolveRole(
      userId: userId,
      resourceType: AppResourceTypes.item,
      resourceId: itemId,
    );
    if (role == null) return TomAuthState.none;
    final resolved = await grades.resolveItemFieldStates(role);
    return resolved[itemAttachmentGradeKey] ?? TomAuthState.none;
  }
}
