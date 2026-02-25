import 'package:flutter/foundation.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

class ValueListenableObserver<T extends TomObservable>
    implements TomObserver<T>, ValueListenable<T> {
  ValueListenableObserver(this.observable) {
    observable.addObserver(this);
  }

  T observable;

  void Function()? voidCallback;

  @override
  void onNotify(T observable) {
    if (voidCallback != null) {
      voidCallback!();
      tomLog.trace(
        "ValueListenableObserver: notified ${observable.runtimeType} ${observable.toString()}",
      );
    }
  }

  @override
  void addListener(VoidCallback listener) {
    tomLog.trace("ValueListenableObserver: Listener added $listener");
    voidCallback = listener;
  }

  @override
  void removeListener(VoidCallback listener) {
    tomLog.trace("ValueListenableObserver: Listener removed $listener");
    voidCallback = null;
  }

  @override
  T get value => observable;
}
