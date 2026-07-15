import 'package:flutter/material.dart';

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
abstract final class TomMessenger {
  /// Shows [snackBar] on the [ScaffoldMessenger] nearest [context].
  ///
  /// Throws if no [ScaffoldMessenger] is in scope — use
  /// [showSnackBarIfPresent] when the messenger may be absent.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    BuildContext context,
    SnackBar snackBar,
  ) =>
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

  /// Shows [snackBar] only if a [ScaffoldMessenger] is in scope; otherwise a
  /// no-op returning null. Use this from code paths that may run without a
  /// surrounding [Scaffold] (e.g. field callbacks).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      showSnackBarIfPresent(
    BuildContext context,
    SnackBar snackBar,
  ) =>
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);

  /// Shows a plain [message] wrapped in a [TomSnackBar]/[TomText], the common
  /// case for one-line notifications.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMessage(
    BuildContext context,
    String message,
  ) =>
      showSnackBar(context, TomSnackBar(content: TomText(text: message)));
}
