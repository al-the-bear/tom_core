import 'package:flutter/material.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A widget that rebuilds whenever a [TomObservable] notifies its observers.
///
/// `TomObservingWidget` bridges the kernel observation model to Flutter: it
/// registers as a [TomObserver] on [subState] and calls [State.setState] on
/// every notification, re-invoking [child] with the (current) observable.
///
/// ```dart
/// final showForm = TomBool(false);
///
/// TomObservingWidget<TomBool>(
///   subState: showForm,
///   child: (s) => ~s ? const FormPanel() : const SizedBox.shrink(),
/// );
///
/// showForm | true; // the widget rebuilds
/// ```
class TomObservingWidget<T extends TomObservable> extends StatefulWidget {
  TomObservingWidget({required this.child, required this.subState});

  /// Builds the subtree from the current observable state.
  final Widget Function(T state) child;

  /// The observable whose notifications drive the rebuild.
  final T subState;

  @override
  State<StatefulWidget> createState() => TomObservingWidgetState<T>();
}

/// The [State] for [TomObservingWidget]; observes the current
/// [TomObservingWidget.subState] and rebuilds on every notification.
///
/// The observation lifecycle follows the standard Flutter `State` contract so
/// the bridge neither leaks nor outlives the element:
///   * [initState] registers as an observer on the initial `subState`.
///   * [didUpdateWidget] migrates the registration when the parent rebuilds
///     with a different `subState`, so the widget always observes the current
///     observable and drops the previous one.
///   * [dispose] deregisters before the element is destroyed, so a later
///     mutation never calls [setState] on a disposed `State`.
class TomObservingWidgetState<T extends TomObservable>
    extends State<TomObservingWidget<T>>
    implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.subState.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant TomObservingWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.subState, oldWidget.subState)) {
      oldWidget.subState.removeObserver(this);
      widget.subState.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.subState.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child(widget.subState);
  }

  @override
  void onNotify(TomObservable observable) {
    setState(() {
      tomLog.trace(
        "TomObservingWidgetState: Updating state ${observable.runtimeType} ${observable.toString()}",
      );
    });
  }
}
