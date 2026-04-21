/// Phase 6 — Non-form custom widgets barrel.
///
/// Exports the eight custom widgets defined in §23 of
/// `tom_ui_widgets_forms.md`. None of these are fields; they consume
/// the same authorization, resource, and state-binding systems used
/// by Phase 1–5 fields and form a reusable kit for downstream apps.
library;

export 'tom_auth_guard.dart';
export 'tom_auth_tree.dart';
export 'tom_empty_state.dart';
export 'tom_error_boundary.dart';
export 'tom_infinite_scroll.dart';
export 'tom_loading_overlay.dart';
export 'tom_radio_group.dart';
export 'tom_skeleton_loader.dart';
