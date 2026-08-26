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
/// **Single-listener limitation.** This adaptor holds at most one listener, and
/// deviates from the [ValueListenable] contract at both ends of it:
///   * [addListener] **replaces** any previously registered callback rather
///     than appending. Handing one adaptor to two [ValueListenableBuilder]s
///     leaves only the last one receiving notifications.
///   * [removeListener] **ignores its argument**. It clears the single slot
///     unconditionally, so calling it with a listener that was never registered
///     still silences the adaptor. There is one slot, so there is nothing to
///     match against.
///
/// Both suit its sole intended consumer — a single [ValueListenableBuilder] —
/// and both are why this is not a general-purpose multicast [ValueListenable].
/// If two parts of a screen need the same observable, give each its own adaptor
/// rather than adding two listeners to one.
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

  /// Clears the single listener slot so notifications are no longer forwarded.
  ///
  /// [listener] is **ignored**. There is one slot rather than a list, so there
  /// is nothing to match the argument against and any argument clears it —
  /// including a closure that was never registered. It is traced, not compared.
  @override
  void removeListener(VoidCallback listener) {
    tomLog.trace("ValueListenableObserver: Listener removed $listener");
    voidCallback = null;
  }

  /// The current value — the observed [observable] itself.
  @override
  T get value => observable;
}
