import 'package:flutter/foundation.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Adapts a kernel [TomObservable] to Flutter's [ValueListenable] contract.
///
/// `ValueListenableObserver` lets a [TomObservable] drive any Flutter API that
/// consumes a [ValueListenable] — e.g. a [ValueListenableBuilder] or an
/// [AnimatedBuilder]. It registers as a [TomObserver] on [observable] and,
/// whenever the kernel state notifies, forwards the notification to the
/// currently registered Flutter listener.
///
/// ```dart
/// final error = TomString('');
/// final adaptor = ValueListenableObserver<TomString>(error);
///
/// ValueListenableBuilder<TomString>(
///   valueListenable: adaptor,
///   builder: (context, value, _) => Text(~value),
/// );
///
/// error | 'Boom'; // the builder rebuilds with "Boom"
/// ```
///
/// **Single-listener limitation:** this adaptor holds at most one listener.
/// [addListener] replaces any previously registered callback rather than
/// appending, which matches its sole intended consumer (a single
/// [ValueListenableBuilder]). It is not a general-purpose multicast
/// [ValueListenable].
class ValueListenableObserver<T extends TomObservable>
    implements TomObserver<T>, ValueListenable<T> {
  /// Registers this adaptor as an observer of [observable].
  ValueListenableObserver(this.observable) {
    observable.addObserver(this);
  }

  /// The kernel observable whose notifications are forwarded to Flutter.
  T observable;

  /// The single Flutter listener to invoke on each notification, if any.
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

  /// Registers [listener] as the callback to fire on notification.
  ///
  /// Replaces any previously registered listener (see the single-listener
  /// limitation in the class docs).
  @override
  void addListener(VoidCallback listener) {
    tomLog.trace("ValueListenableObserver: Listener added $listener");
    voidCallback = listener;
  }

  /// Clears the registered listener so notifications are no longer forwarded.
  @override
  void removeListener(VoidCallback listener) {
    tomLog.trace("ValueListenableObserver: Listener removed $listener");
    voidCallback = null;
  }

  /// The current value — the observed [observable] itself.
  @override
  T get value => observable;
}
