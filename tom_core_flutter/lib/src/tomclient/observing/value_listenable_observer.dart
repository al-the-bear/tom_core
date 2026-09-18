import 'package:flutter/foundation.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Adapts a kernel [TomObservable] to Flutter's [ValueListenable] contract.
///
/// `ValueListenableObserver` lets a [TomObservable] drive any Flutter API that
/// consumes a [ValueListenable] — e.g. a [ValueListenableBuilder] or an
/// [AnimatedBuilder]. It registers as a [TomObserver] on [observable] and,
/// whenever the kernel state notifies, forwards the notification to every
/// registered Flutter listener.
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
/// **It is a real multicast [Listenable].** [addListener] appends and
/// [removeListener] removes the callback it is given, so one adaptor may be
/// handed to any number of consumers — two [ValueListenableBuilder]s, a builder
/// plus an [AnimatedBuilder], a manual registration in a `State.initState` —
/// and each is notified. That matters because a [Listenable] is *structurally*
/// substitutable wherever Flutter asks for one: a type that replaced on add
/// would leave the first consumer silently not rebuilding, with no error
/// anywhere.
///
/// The semantics are Flutter's own, including the corners:
///   * registering the same callback twice makes it fire twice, and one
///     [removeListener] undoes one registration;
///   * removing a callback that was never registered does nothing, rather than
///     silencing the adaptor;
///   * a listener may add or remove listeners while it is being notified —
///     dispatch walks a snapshot, so a listener removed mid-notification does
///     not shift the ones after it, and one added mid-notification is called on
///     the next notification rather than this one.
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
/// [removeListener] is not a substitute: it unregisters one Flutter listener
/// and leaves the kernel registration in place, so the adaptor keeps running
/// [onNotify] on every notification — and removing the last listener does not
/// end the subscription either. The kernel does hold its observers weakly
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
  ///
  /// `final`, because the subscription is made against *this* observable in the
  /// constructor and nothing moves it. A settable field would let an adaptor be
  /// pointed at a second observable while still registered on the first, so
  /// [value] would report one and [onNotify] would fire from the other — a
  /// `ValueListenableBuilder` rebuilding on one observable's changes while
  /// rendering another's. Retargeting is what a new adaptor is for; a
  /// `TomObservingWidget` migrates instead, because a widget has a
  /// `didUpdateWidget` to migrate in and this has no lifecycle at all.
  final T observable;

  /// The Flutter listeners to invoke on each notification, in registration
  /// order.
  ///
  /// Private: it is implementation state, not surface. Reaching it directly
  /// would bypass [addListener] and [removeListener], which is where
  /// registration is traced and where use after [dispose] is caught. [value] is
  /// the type's reader.
  ///
  /// A [List] rather than a [Set]: the [Listenable] contract counts
  /// registrations, so the same callback added twice is notified twice and
  /// removed once stays registered once. A set would silently collapse that.
  final List<VoidCallback> _listeners = [];

  /// Whether [dispose] has run. Read by the debug assertions below.
  bool _isDisposed = false;

  /// Ends the subscription: deregisters from [observable] and drops every
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
    _listeners.clear();
    _isDisposed = true;
  }

  @override
  void onNotify(T observable) {
    if (_listeners.isEmpty) return;
    // A snapshot, because the contract lets a listener register or unregister
    // while it is being notified — a `ValueListenableBuilder` disposing in
    // response to a change is the ordinary case. Walking the live list would
    // either skip the listener after a removed one or throw on concurrent
    // modification.
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
    // A closure, not a string — see [TomObservingWidgetState.onNotify]. The
    // message is built only if the line is written, so a notification costs no
    // `toString()` of the observable while trace logging is off.
    tomLog.trace(
      () =>
          "ValueListenableObserver: notified "
          "${observable.runtimeType} $observable",
    );
  }

  /// Registers [listener] to fire on every notification.
  ///
  /// Appends, per the [Listenable] contract. Registering the same callback
  /// twice makes it fire twice; it then takes two [removeListener] calls to
  /// stop it.
  @override
  void addListener(VoidCallback listener) {
    assert(
      !_isDisposed,
      'A disposed ValueListenableObserver is off the observable\'s observer '
      'list, so this listener would never fire. Build a new adaptor.',
    );
    tomLog.trace(() => "ValueListenableObserver: Listener added $listener");
    _listeners.add(listener);
  }

  /// Stops [listener] being notified.
  ///
  /// Removes **one** registration of it, per the [Listenable] contract, and
  /// does nothing when it was never registered — it does not silence the other
  /// listeners.
  ///
  /// This is **not** a teardown. The kernel registration made at construction
  /// survives it, so the adaptor stays on the observable's observer list and
  /// keeps running [onNotify]; only this listener stops. Use [dispose] to end
  /// the subscription.
  ///
  /// Tolerated after [dispose], unlike [addListener]. A widget tearing down
  /// cannot always control whether the listenable it registered on was disposed
  /// first, and refusing the call would turn a correct teardown into a crash;
  /// there is nothing left to remove, so nothing is lost by accepting it.
  @override
  void removeListener(VoidCallback listener) {
    tomLog.trace(() => "ValueListenableObserver: Listener removed $listener");
    _listeners.remove(listener);
  }

  /// The current value — the observed [observable] itself.
  @override
  T get value => observable;
}
