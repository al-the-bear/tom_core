import 'package:flutter/material.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomObservingWidget<T extends TomObservable> extends StatefulWidget {
  TomObservingWidget({required this.child, required this.subState});

  final Widget Function(T state) child;
  final T subState;

  @override
  State<StatefulWidget> createState() {
    return TomObservingWidgetState(child: child, subState: subState);
  }
}

class TomObservingWidgetState<T extends TomObservable>
    extends State<TomObservingWidget<T>>
    implements TomObserver {
  TomObservingWidgetState({required this.child, required this.subState}) {
    subState.addObserver(this);
  }

  Widget Function(T state) child;
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
