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
///
/// **Construction subscribes, and [dispose] is what ends it.** An adaptor held
/// beyond a single build — in a `State` field, which is the normal way to hold
/// one — **must** be disposed, exactly like the [TomObservingWidget] it is the
/// non-widget counterpart of:
///
/// ```dart
/// class _MyScreenState extends State<MyScreen> {
///   late final ValueListenableObserver<TomString> error =
///       ValueListenableObserver(widget.state.error);
///
///   @override
///   void dispose() {
///     error.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// [removeListener] is not a substitute: it clears the Flutter listener and
/// leaves the kernel registration in place, so the adaptor keeps running
/// [onNotify] on every notification. The kernel does hold its observers weakly
/// and sweeps dead ones on the next notification, so a forgotten adaptor is not
/// an unbounded leak — but that sweep happens when the adaptor becomes
/// unreachable and something else happens to notify, which is not a moment a
/// caller can choose, and an adaptor still held in a field never becomes
/// unreachable at all. "It stops eventually, at a point you cannot observe" is
/// not a contract to build on.
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

  /// Whether [dispose] has run. Read by the debug assertions below.
  bool _isDisposed = false;

  /// Ends the subscription: deregisters from [observable] and drops the
  /// listener.
  ///
  /// **Required for any adaptor that outlives one build.** After this the
  /// adaptor is spent — it is off the observable's observer list, so nothing
  /// re-subscribes it and no listener added later will ever fire. That is
  /// asserted in debug rather than left to be discovered: [addListener] on a
  /// disposed adaptor fails an `assert`, which is where a mistake of this shape
  /// is cheapest to find.
  ///
  /// Idempotent. Disposing twice is what a `State` that also nulls its field
  /// ends up doing, and a teardown that punishes being called twice makes the
  /// call sites defensive instead of simple.
  void dispose() {
    observable.removeObserver(this);
    voidCallback = null;
    _isDisposed = true;
  }

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
    assert(
      !_isDisposed,
      'A disposed ValueListenableObserver is off the observable\'s observer '
      'list, so this listener would never fire. Build a new adaptor.',
    );
    tomLog.trace("ValueListenableObserver: Listener added $listener");
    voidCallback = listener;
  }

  /// Clears the single listener slot so notifications are no longer forwarded.
  ///
  /// [listener] is **ignored**. There is one slot rather than a list, so there
  /// is nothing to match the argument against and any argument clears it —
  /// including a closure that was never registered. It is traced, not compared.
  ///
  /// This is **not** a teardown. The kernel registration made at construction
  /// survives it, so the adaptor stays on the observable's observer list and
  /// keeps running [onNotify]; only the forwarding stops. Use [dispose] to end
  /// the subscription.
  @override
  void removeListener(VoidCallback listener) {
    tomLog.trace("ValueListenableObserver: Listener removed $listener");
    voidCallback = null;
  }

  /// The current value — the observed [observable] itself.
  @override
  T get value => observable;
}
