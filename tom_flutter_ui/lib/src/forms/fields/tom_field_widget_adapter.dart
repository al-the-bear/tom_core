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
  Widget build(BuildContext context) => child;
}
