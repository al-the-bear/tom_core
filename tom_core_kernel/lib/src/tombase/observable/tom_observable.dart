import '../reflection/reflection.dart';

/// A base class that implements the Observer pattern, allowing objects to be
/// observed for changes.
///
/// [TomObservable] maintains a list of [TomObserver] instances that are notified
/// when changes occur. Observers are held via [WeakReference] to prevent memory
/// leaks - if an observer is garbage collected, it will be automatically removed
/// from the observer list.
///
/// Notifications can be muted temporarily so that a run of changes surfaces as
/// a single notification instead of one per change. Use [batch] for that —
/// it releases the mute even when the body throws. [mute] and [unmute] are the
/// unscoped form; they nest, so a batching method may be called from inside a
/// caller's batch without cutting it short.
///
/// Example usage:
/// ```dart
/// class MyModel extends TomObservable {
///   String _name = '';
///   
///   set name(String value) {
///     _name = value;
///     notifyObservers();
///   }
/// }
///
/// class MyView extends TomObserver<MyModel> {
///   @override
///   void onNotify(MyModel observable) {
///     // React to changes
///   }
/// }
/// ```
@tomReflector
class TomObservable {
  /// How many mutes are currently held. Zero means notifications flow.
  ///
  /// A counter rather than a flag so that batches nest: a batching method
  /// called from inside an enclosing batch must suppress its own
  /// notifications without releasing the caller's.
  int _muteDepth = 0;
  bool _dirty = false;

  /// The cascade targets of each still-open mute, innermost last.
  ///
  /// Invariant: `_cascades.length == _muteDepth`. Each [mute] snapshots the
  /// targets it silenced and each [unmute] releases exactly that snapshot, so
  /// membership changes made *during* a batch cannot unbalance it — an element
  /// added mid-batch was never muted here and is not released here, and one
  /// removed mid-batch was muted here and still is released here.
  final List<List<TomObservable>> _cascades = [];

  /// The registered observers, in registration order.
  ///
  /// A set rather than a list because [addObserver] must reject a duplicate,
  /// and looking one up by walking the collection made attaching *n* observers
  /// cost O(n^2) comparisons — a bill a [TomList] pays in full, since it
  /// registers itself with every element it holds. [_ObserverRef] carries the
  /// identity hash of its target, so membership is an O(1) lookup. The default
  /// [Set] is insertion-ordered, so observers are still notified in the order
  /// they registered.
  final Set<_ObserverRef> _observers = {};

  /// The observables that [mute] cascades to.
  ///
  /// Empty for a plain observable. The composites ([TomClass], [TomList],
  /// [TomMap]) override this to name their members, so that muting a container
  /// silences what it contains.
  ///
  /// The result is snapshotted at [mute] time; returning a live view is safe.
  Iterable<TomObservable> get muteCascadeTargets => const [];

  /// Mutes all observer notifications, and those of [muteCascadeTargets].
  ///
  /// While muted, calls to [notifyObservers] mark the observable as dirty
  /// instead of notifying. The matching [unmute] delivers a single
  /// consolidated notification if anything was marked dirty.
  ///
  /// **Mutes nest.** Each call must be matched by exactly one [unmute];
  /// notifications resume only when the outermost one is released. This is
  /// what lets a batching mutator be called from inside a caller's batch
  /// without cutting it short.
  ///
  /// Prefer [batch], which cannot leak a mute on the throwing path.
  void mute() {
    final targets = List<TomObservable>.of(muteCascadeTargets);
    _muteDepth++;
    _cascades.add(targets);
    for (final target in targets) {
      target.mute();
    }
  }

  /// Releases one [mute].
  ///
  /// The cascade targets this mute silenced are released first, while this
  /// object is still muted, so any notification they emit collapses into this
  /// object's single notification rather than escaping as one of its own.
  ///
  /// When the last mute is released and [notifyObservers] was called while
  /// muted, observers are notified once.
  ///
  /// Releasing more often than muting is a no-op rather than an error: the
  /// depth floors at zero, so a stray call cannot poison later batches.
  void unmute() {
    if (_muteDepth == 0) return;

    for (final target in _cascades.removeLast()) {
      target.unmute();
    }
    _muteDepth--;
    if (_muteDepth > 0) return;

    if (_dirty) {
      _dirty = false;
      notifyObservers();
    }
  }

  /// Mutes this observable *without* cascading to [muteCascadeTargets].
  ///
  /// Used by the batching mutators on the composites, which consolidate their
  /// own notifications but must leave the elements' own observers alone.
  void _muteSelf() {
    _muteDepth++;
    _cascades.add(const <TomObservable>[]);
  }

  /// Returns `true` if observer notifications are currently muted.
  bool get isMuted => _muteDepth > 0;

  /// Runs [body] with notifications muted, releasing the mute afterwards.
  ///
  /// The scoped form of [mute] / [unmute], and the one to reach for: the
  /// release happens in a `finally`, so a throwing [body] cannot leave the
  /// object silent for the rest of its life. Nests like [mute] does.
  ///
  /// ```dart
  /// list.batch(() {
  ///   list.add(a);
  ///   list.add(b);
  /// }); // one notification
  /// ```
  ///
  /// Returns whatever [body] returns.
  T batch<T>(T Function() body) {
    mute();
    try {
      return body();
    } finally {
      unmute();
    }
  }

  /// Runs [body] with *this* observable's notifications muted, without
  /// cascading to [muteCascadeTargets].
  ///
  /// A composite mutator that makes several internal edits uses this to
  /// surface them as one notification, while leaving observers of the
  /// individual elements to hear about their own changes as they happen.
  ///
  /// Returns whatever [body] returns.
  T batchSelf<T>(T Function() body) {
    _muteSelf();
    try {
      return body();
    } finally {
      unmute();
    }
  }

  /// Registers an observer to receive change notifications.
  ///
  /// The observer is stored as a [WeakReference], so it will be automatically
  /// removed if it is garbage collected. This prevents memory leaks from
  /// observers that are no longer in use.
  ///
  /// If the observer is already registered, this method does nothing.
  /// "Already registered" means *the same object*, not an equal one: an
  /// observer that overrides `==` is still distinct from its equals.
  void addObserver(TomObserver observer) {
    _observers.add(_ObserverRef(observer));
  }

  /// Unregisters an observer so it no longer receives change notifications.
  ///
  /// If the observer is not registered, this method does nothing.
  void removeObserver(TomObserver observer) {
    _observers.remove(_ObserverRef(observer));
  }

  /// Notifies all registered observers of a change.
  ///
  /// If the observable is currently muted (via [mute]), this method will mark
  /// the observable as dirty but will not notify observers. Observers will be
  /// notified when [unmute] is called.
  ///
  /// This method also cleans up any weak references to observers that have been
  /// garbage collected.
  ///
  /// The optional [message] parameter is currently unused but reserved for
  /// future use to pass additional context about the change.
  void notifyObservers([dynamic message]) {
    if (isMuted) {
      _dirty = true;
      return;
    }

    // Snapshot the observers before iterating so that add/remove calls inside
    // onNotify callbacks (e.g. from TomMultiObservableBuilder disposing or a
    // form save propagating through nested TomClass / TomList chains) cannot
    // cause a ConcurrentModificationError on _observers.
    final snapshot = List.of(_observers);
    bool hasDeadReferences = false;

    for (var element in snapshot) {
      var target = element.target;
      if (target != null) {
        target.onNotify(this);
      } else {
        hasDeadReferences = true;
      }
    }

    // Clean up dead weak references from the live set (the snapshot may have
    // captured stale entries; the live set may also have grown since then, so
    // removeWhere only affects entries that are still dead).
    if (hasDeadReferences) {
      _observers.removeWhere((ref) => ref.target == null);
    }
  }

}

/// Adds the observation operator `>>` to every [TomObservable].
///
/// An extension rather than a method on [TomObservable] because the whole
/// point is the *receiver's* type: an extension type parameter is inferred
/// from the expression it is applied to, so `count >> …` on a `TomInt` yields
/// a `TomFunctionObserver<TomInt>` and hands the callback a `TomInt`, while a
/// method on the base class could only ever promise `TomObservable`. This
/// works for classes the framework has never heard of — a user's
/// `Person extends TomClass` gets `TomFunctionObserver<Person>`.
extension TomObservableObservation<T extends TomObservable> on T {
  /// Registers [callback] as an observer: `count >> (obs) => print(obs.get())`.
  ///
  /// The callback runs whenever this observable notifies its observers, and
  /// receives the observable itself — typed as the receiver was, so a
  /// `TomInt`'s callback can read `obs.get()` as an `int` with no cast.
  ///
  /// Returns the [TomFunctionObserver] wrapper, which can later be passed to
  /// [TomObservable.removeObserver].
  ///
  /// **You must retain the returned observer for as long as you want
  /// notifications.** Observers are held by [WeakReference] (see
  /// [TomObservable.addObserver]), so the returned wrapper is the *only*
  /// strong reference keeping the callback alive. If you discard it — the
  /// fire-and-forget form `myObservable >> (obs) => print('Changed!');` — the
  /// wrapper becomes eligible for garbage collection and the callback
  /// **silently stops firing** at a nondeterministic later time. Always
  /// capture the result:
  ///
  /// ```dart
  /// // Keep `observer` alive (e.g. in a field) for as long as you observe:
  /// final observer = myObservable >> (obs) => print('Changed!');
  /// // Later, to stop observing:
  /// myObservable.removeObserver(observer);
  /// ```
  ///
  /// The wrapper is bound to the observable that produced it. Registering it
  /// on a *different* observable that is not a [T] fails at notification time
  /// — which is the point: the callback was written against a [T].
  TomFunctionObserver<T> operator >>(void Function(T observable) callback) {
    final observer = TomFunctionObserver<T>(callback);
    addObserver(observer);
    return observer;
  }
}

/// A weakly-held, identity-keyed handle on one registered [TomObserver].
///
/// Holding the observer through a [WeakReference] is the whole point of the
/// registry — the observable must not keep its observers alive. The identity
/// hash is captured at construction rather than computed on demand, so the
/// handle keeps the same hash after its target has been collected and stays
/// findable in the set; a dead entry that could not be found again could not
/// be pruned either.
///
/// Equality is *identity of the target*, deliberately. It is what the linear
/// scan this replaced compared on, and it is the behaviour that matters: two
/// observers that declare themselves `==` are still two observers, and both
/// get notified.
class _ObserverRef {
  final WeakReference<TomObserver> _reference;
  final int _identityHash;

  _ObserverRef(TomObserver observer)
      : _reference = WeakReference(observer),
        _identityHash = identityHashCode(observer);

  /// The observer, or `null` once it has been garbage collected.
  TomObserver? get target => _reference.target;

  @override
  int get hashCode => _identityHash;

  @override
  bool operator ==(Object other) {
    // A handle is always equal to itself — including after its target has
    // been collected, which is what lets pruning find and remove it. Two
    // *different* dead handles are not equal: they were two registrations.
    if (identical(this, other)) return true;
    if (other is! _ObserverRef) return false;
    final observer = target;
    return observer != null && identical(observer, other.target);
  }
}

/// Abstract base class for objects that want to observe changes in a [TomObservable].
///
/// Implementers must override [onNotify] to handle change notifications.
///
/// The type parameter [T] specifies the type of observable this observer can
/// observe, allowing for type-safe access to the observable's properties.
///
/// Example:
/// ```dart
/// class MyModelObserver extends TomObserver<MyModel> {
///   @override
///   void onNotify(MyModel observable) {
///     print('Model changed: ${observable.name}');
///   }
/// }
/// ```
@tomReflector
abstract class TomObserver<T extends TomObservable> {
  /// Called when the observed [TomObservable] notifies its observers of a change.
  ///
  /// The [observable] parameter is the object that triggered the notification,
  /// typed as [T] for convenient access to its properties.
  void onNotify(T observable);
}

/// A wrapper that allows using a callback function as a [TomObserver].
///
/// This is what the `>>` operator
/// ([TomObservableObservation.operator >>]) creates, so [T] is normally
/// inferred from the observable the operator was applied to.
///
/// **The wrapper must be retained for as long as notifications are wanted.**
/// [TomObservable] holds its observers by [WeakReference], so this wrapper is
/// the only strong reference keeping the callback alive; if it is not
/// captured, it can be garbage-collected and the callback silently stops
/// firing. Store it (e.g. in a field) and remove it explicitly via
/// [TomObservable.removeObserver] when done — do not use the fire-and-forget
/// form `myObservable >> (obs) => ...;`.
///
/// Example:
/// ```dart
/// final observer = myObservable >> (obs) => print('Changed!');
/// // Later, to stop observing:
/// myObservable.removeObserver(observer);
/// ```
@tomReflector
class TomFunctionObserver<T extends TomObservable> implements TomObserver<T> {
  final void Function(T observable) _callback;

  /// Creates a function observer that wraps the given callback.
  TomFunctionObserver(this._callback);

  @override
  void onNotify(T observable) {
    _callback(observable);
  }
}
