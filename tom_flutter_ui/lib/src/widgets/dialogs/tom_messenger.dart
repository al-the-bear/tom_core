import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../labels/tom_labels.dart';
import 'tom_dialogs.dart';

/// Tom-native presenter for transient messages (snack bars).
///
/// [ScaffoldMessenger] is the Flutter *mechanism* for showing a [SnackBar]; it
/// is not a widget a screen composes, it is an API a screen calls. [TomMessenger]
/// gives that call a Tom-owned surface so screens present notifications through
/// the framework instead of reaching for Flutter directly — the same reason the
/// Tom widgets wrap their Flutter counterparts. It carries no state; every method
/// forwards to the ambient [ScaffoldMessenger].
///
/// ```dart
/// TomMessenger.showSnackBar(context, TomSnackBar(tomId: 'saveSuccess'));
/// TomMessenger.showMessage(context, 'Saved.');
/// ```
///
/// It is also where a [TomSnackBar]'s authorization is enforced. Every other
/// Tom widget hides itself by building nothing, but a snack bar does not build
/// where it is written — it is handed to [ScaffoldMessenger] and placed
/// elsewhere, so a bar that hid its own content would still slide up empty.
/// Presenting it is the last moment at which not-presenting it is possible,
/// which is why both methods return null for a bar that resolves to
/// [TomAuthState.none].
abstract final class TomMessenger {
  /// Shows [snackBar] on the [ScaffoldMessenger] nearest [context].
  ///
  /// Returns null, showing nothing, when [snackBar] is a [TomSnackBar] whose
  /// authorization resolves to [TomAuthState.none]. A plain [SnackBar] has no
  /// authorization to resolve and is always shown.
  ///
  /// Throws if no [ScaffoldMessenger] is in scope — use
  /// [showSnackBarIfPresent] when the messenger may be absent.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  showSnackBar(BuildContext context, SnackBar snackBar) => _isHidden(snackBar)
      ? null
      : ScaffoldMessenger.of(context).showSnackBar(snackBar);

  /// Shows [snackBar] only if a [ScaffoldMessenger] is in scope; otherwise a
  /// no-op returning null. Use this from code paths that may run without a
  /// surrounding [Scaffold] (e.g. field callbacks).
  ///
  /// Also returns null for a hidden [TomSnackBar], as [showSnackBar] does.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  showSnackBarIfPresent(BuildContext context, SnackBar snackBar) =>
      _isHidden(snackBar)
      ? null
      : ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);

  /// Whether [snackBar] carries Tom authorization that denies it outright.
  static bool _isHidden(SnackBar snackBar) =>
      snackBar is TomSnackBar &&
      snackBar.effectiveAuthState == TomAuthState.none;

  /// Shows a plain [message] wrapped in a [TomSnackBar]/[TomText], the common
  /// case for one-line notifications.
  ///
  /// The bar it builds carries no `tomId`, so it is never gated.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showMessage(
    BuildContext context,
    String message,
  ) => showSnackBar(context, TomSnackBar(content: TomText(text: message)));
}
