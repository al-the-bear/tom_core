/// Non-form custom widgets.
///
/// Eight widgets that are not form fields and carry no form-value
/// binding, but consume the same authorization, resource, and
/// state-binding systems the fields do:
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
