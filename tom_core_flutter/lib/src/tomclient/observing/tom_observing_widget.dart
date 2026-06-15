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
  State<StatefulWidget> createState() {
    return TomObservingWidgetState(child: child, subState: subState);
  }
}

/// The [State] for [TomObservingWidget]; observes [subState] and rebuilds on
/// every notification.
class TomObservingWidgetState<T extends TomObservable>
    extends State<TomObservingWidget<T>>
    implements TomObserver {
  TomObservingWidgetState({required this.child, required this.subState}) {
    subState.addObserver(this);
  }

  /// Builder for the observed subtree (mirrors [TomObservingWidget.child]).
  Widget Function(T state) child;

  /// The observed value (mirrors [TomObservingWidget.subState]).
  T subState;

  @override
  Widget build(BuildContext context) {
    return widget.child(subState);
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
