import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../tom_form.dart';

/// A thin [StatelessWidget] wrapper that lets a widget rendered by a
/// [TomField] participate in [TomAuthorizable] protocols.
///
/// `TomField` itself already implements `TomAuthorizable`, but the widget
/// returned by its `widget` getter is typically a Flutter-native `TextField`
/// / `DropdownButtonFormField` / `ValueListenableBuilder` wrapper that has
/// no link back to the field instance. Code that walks a widget tree —
/// most importantly `AclContainer`'s per-component auth check used by
/// `setAclDefaultHideUnauthorized` — cannot ask those Flutter widgets for
/// their authorization state.
///
/// Wrapping the rendered widget in [TomFieldWidgetAdapter] closes that gap:
/// the adapter delegates `tomId`, `tomGroup`, and `effectiveAuthState` to
/// the underlying field so ACL (and any other `TomAuthorizable`-aware
/// consumer) can treat a form-field widget identically to a regular
/// `TomWidget`.
class TomFieldWidgetAdapter extends StatelessWidget
    implements TomAuthorizable {
  /// The field whose auth state this adapter exposes.
  final TomField field;

  /// The actual rendered content (the field's own widget).
  final Widget child;

  const TomFieldWidgetAdapter({
    super.key,
    required this.field,
    required this.child,
  });

  @override
  String? get tomId => field.tomId;

  @override
  TomAuthorizationGroup? get tomGroup => field.tomGroup;

  @override
  TomAuthState get effectiveAuthState => field.effectiveAuthState;

  @override
  Widget build(BuildContext context) {
    // Force a fresh State subtree whenever the underlying field identity
    // changes. Without this, Flutter's positional element reconciliation
    // happily reuses a field-widget's State across row swaps in
    // master/detail (and any other parent that swaps `field` at the same
    // tree position). The reused State keeps observing the *previous*
    // field — its TextEditingController never updates, the displayed
    // value goes stale, and edits flow into the wrong field.
    //
    // Keying by the field instance means the slot's effective key
    // changes whenever the underlying field changes, so Flutter
    // disposes the old State and constructs a new one bound to the
    // new field. For breakpoint-driven re-layouts the field instance
    // is the same → key is the same → State is preserved (focus,
    // selection, controller text are not flashed).
    return KeyedSubtree(
      key: ValueKey<TomField>(field),
      child: child,
    );
  }
}
