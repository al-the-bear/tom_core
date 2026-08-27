/// Non-form custom widgets.
///
/// Eight widgets that are not form fields and carry no form-value
/// binding. They extend `StatelessWidget` / `StatefulWidget` directly
/// rather than a `TomFamilyBase`, and they reach for the package's
/// systems only where each genuinely needs one: [TomAuthGuard],
/// [TomAuthTreeView] and [TomRadioGroup] resolve authorization through
/// the kernel, [TomEmptyState] resolves resources, and the other four
/// take their appearance from the ambient `ThemeData`.
///
/// * [TomAuthGuard] — hides or disables a subtree by resolved auth state.
/// * [TomAuthTreeView] — hierarchical tree with per-node authorization.
/// * [TomEmptyState] — placeholder for an empty data view.
/// * [TomErrorBoundary] — catches build errors raised inside a subtree.
/// * [TomInfiniteScroll] — paginated list over a page fetcher.
/// * [TomLoadingOverlay] — scrim and spinner over a subtree.
/// * [TomRadioGroup] — radio selection with group-level authorization.
/// * [TomSkeletonLoader] — shimmer placeholder for a loading surface.
library;

export 'tom_auth_guard.dart';
export 'tom_auth_tree.dart';
export 'tom_empty_state.dart';
export 'tom_error_boundary.dart';
export 'tom_infinite_scroll.dart';
export 'tom_loading_overlay.dart';
export 'tom_radio_group.dart';
export 'tom_skeleton_loader.dart';
