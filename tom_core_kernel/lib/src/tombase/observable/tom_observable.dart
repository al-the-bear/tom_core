import '../reflection/reflection.dart';

/// A base class that implements the Observer pattern, allowing objects to be
/// observed for changes.
///
/// [TomObservable] maintains a list of [TomObserver] instances that are notified
/// when changes occur. Observers are held via [WeakReference] to prevent memory
/// leaks - if an observer is garbage collected, it will be automatically removed
/// from the observer list.
///
/// The class supports muting notifications temporarily, which is useful during
/// batch updates where you want to defer notifications until all changes are complete.
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
  bool _silent = false;
  bool _dirty = false;

  final List<WeakReference<TomObserver>> _observers = [];

  /// Mutes all observer notifications.
  ///
  /// While muted, calls to [notifyObservers] will mark the observable as dirty
  /// but will not actually notify observers. When [unmute] is called, if the
  /// observable was marked dirty, observers will be notified at that time.
  ///
  /// This is useful for batch updates where you want to make multiple changes
  /// without triggering notifications for each individual change.
  void mute() {
    _silent = true;
  }

  /// Unmutes observer notifications and notifies observers if changes occurred while muted.
  ///
  /// If [notifyObservers] was called while the observable was muted, observers
  /// will be notified immediately upon calling this method.
  void unmute() {
    _silent = false;
    if (_dirty) {
      notifyObservers();
    }
    _dirty = false;
  }

  /// Returns `true` if observer notifications are currently muted.
  bool get isMuted => _silent;

  /// Finds the weak reference wrapper for the given observer.
  ///
  /// Returns `null` if the observer is not registered.
  WeakReference<TomObserver>? _getObserverReference(TomObserver observer) {
    for (var observerReference in _observers) {
      if (identical(observer, observerReference.target)) {
        return observerReference;
      }
    }
    return null;
  }

  /// Registers an observer to receive change notifications.
  ///
  /// The observer is stored as a [WeakReference], so it will be automatically
  /// removed if it is garbage collected. This prevents memory leaks from
  /// observers that are no longer in use.
  ///
  /// If the observer is already registered, this method does nothing.
  void addObserver(TomObserver observer) {
    if (_getObserverReference(observer) == null) {
      _observers.add(WeakReference(observer));
    }
  }

  /// Unregisters an observer so it no longer receives change notifications.
  ///
  /// If the observer is not registered, this method does nothing.
  void removeObserver(TomObserver observer) {
    var ref = _getObserverReference(observer);
    if (ref != null) {
      _observers.remove(ref);
    }
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
    if (_silent) {
      _dirty = true;
      return;
    }

    // Snapshot the observer list before iterating so that add/remove calls
    // inside onNotify callbacks (e.g. from TomMultiObservableBuilder disposing
    // or a form save propagating through nested TomClass / TomList chains)
    // cannot cause a ConcurrentModificationError on _observers.
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

    // Clean up dead weak references from the live list (snapshot may have
    // captured stale entries; the live list may also have grown since then,
    // so removeWhere only affects entries that are still dead).
    if (hasDeadReferences) {
      _observers.removeWhere((ref) => ref.target == null);
    }
  }

  /// Operator to add an observer callback: `observable >> (obs) => print('changed')`.
  ///
  /// The callback is invoked whenever this observable notifies its observers.
  /// Returns the [TomFunctionObserver] wrapper, which can later be removed via
  /// [removeObserver].
  ///
  /// **You must retain the returned observer for as long as you want
  /// notifications.** Observers are held by [WeakReference] (see [addObserver]),
  /// so the returned wrapper is the *only* strong reference keeping the callback
  /// alive. If you discard it — the fire-and-forget form
  /// `myObservable >> (obs) => print('Changed!');` — the wrapper becomes eligible
  /// for garbage collection and the callback **silently stops firing** at a
  /// nondeterministic later time. Always capture the result:
  ///
  /// Example:
  /// ```dart
  /// // Keep `observer` alive (e.g. in a field) for as long as you observe:
  /// final observer = myObservable >> (obs) => print('Changed!');
  /// // Later, to stop observing:
  /// myObservable.removeObserver(observer);
  /// ```
  TomFunctionObserver<TomObservable> operator >>(
      void Function(TomObservable observable) callback) {
    var observer = TomFunctionObserver<TomObservable>(callback);
    addObserver(observer);
    return observer;
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
/// This enables the `>>` operator syntax for observing changes.
///
/// **The returned wrapper must be retained for as long as notifications are
/// wanted.** [TomObservable] holds its observers by [WeakReference], so this
/// wrapper is the only strong reference keeping the callback alive; if it is
/// not captured, it can be garbage-collected and the callback silently stops
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
class TomFunctionObserver<T extends TomObservable> implements TomObserver<T> {
  final void Function(T observable) _callback;

  /// Creates a function observer that wraps the given callback.
  TomFunctionObserver(this._callback);

  @override
  void onNotify(T observable) {
    _callback(observable);
  }
}
