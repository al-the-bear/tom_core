/// Non-form custom widgets.
///
/// Nine widgets that are not form fields and carry no form-value
/// binding. They extend `StatelessWidget` / `StatefulWidget` directly
/// rather than a `TomFamilyBase`, and they reach for the package's
/// systems only where each genuinely needs one: [TomAuthGuard],
/// [TomAuthTreeView], [TomChoiceGroup] and [TomPrincipalPicker] resolve
/// authorization through the kernel, [TomEmptyState] and
/// [TomPrincipalPicker] resolve resources, and the other four take their
/// appearance from the ambient `ThemeData`.
///
/// * [TomAuthGuard] — hides or disables a subtree by resolved auth state.
/// * [TomAuthTreeView] — hierarchical tree with per-node authorization.
/// * [TomEmptyState] — placeholder for an empty data view.
/// * [TomErrorBoundary] — catches build errors raised inside a subtree.
/// * [TomInfiniteScroll] — paginated list over a page fetcher.
/// * [TomLoadingOverlay] — scrim and spinner over a subtree.
/// * [TomChoiceGroup] — radio selection with group-level authorization.
/// * [TomPrincipalPicker] — finds users and groups through an injected search
///   and shows the picked ones as chips.
/// * [TomSkeletonLoader] — shimmer placeholder for a loading surface.
///
/// Their companion types:
///
/// * [TomAuthTreeNode] — one node of a [TomAuthTreeView].
/// * [TomChoiceGroupItem] — one entry of a [TomChoiceGroup].
/// * [TomPrincipalCandidate] — one user or group a [TomPrincipalPicker]
///   offers, of [TomPrincipalKind]; [TomPrincipalSearch] finds them.
/// * [TomErrorBoundaryFallbackBuilder] — what a [TomErrorBoundary] renders in
///   place of the subtree that failed.
/// * [TomPageFetcher] — the source a [TomInfiniteScroll] pulls pages from,
///   [TomInfiniteScrollItemBuilder] the tile it draws per item, and
///   [TomInfiniteScrollState] its public state.
///
/// [TomInfiniteScroll]'s failure slot has two shapes, so its builder is told
/// which one it is in: see [TomInfiniteScrollErrorBuilder] and
/// [TomInfiniteScrollErrorPlacement].
library;

export 'tom_auth_guard.dart';
export 'tom_auth_tree.dart';
export 'tom_empty_state.dart';
export 'tom_error_boundary.dart';
export 'tom_infinite_scroll.dart';
export 'tom_loading_overlay.dart';
export 'tom_choice_group.dart';
export 'tom_principal_picker.dart';
export 'tom_skeleton_loader.dart';
