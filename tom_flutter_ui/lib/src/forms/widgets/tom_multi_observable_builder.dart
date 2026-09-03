import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A widget that observes one or more [TomObservable] instances and rebuilds
/// when any of them change.
///
/// Manages **clean registration and deregistration** of observable listeners.
/// When the widget is created, it registers listeners on all provided
/// observables. When disposed or when the observable list changes, it
/// deregisters all previous listeners before registering new ones.
///
/// ```dart
/// TomMultiObservableBuilder(
///   observables: [field, field.min, field.max],
///   builder: (context) => Slider(
///     value: field.value.toDouble(),
///     min: field.min.value.toDouble(),
///     max: field.max.value.toDouble(),
///     onChanged: (v) => field.setValue(v.round()),
///   ),
/// );
/// ```
class TomMultiObservableBuilder extends StatefulWidget {
  /// The observables to watch for changes.
  final List<TomObservable> observables;

  /// Builder called when any observed value changes.
  final WidgetBuilder builder;

  const TomMultiObservableBuilder({
    super.key,
    required this.observables,
    required this.builder,
  });

  @override
  State<TomMultiObservableBuilder> createState() =>
      _TomMultiObservableBuilderState();
}

class _TomMultiObservableBuilderState extends State<TomMultiObservableBuilder> {
  late final _Observer _observer;

  @override
  void initState() {
    super.initState();
    _observer = _Observer(() {
      if (mounted) setState(() {});
    });
    _registerAll(widget.observables);
  }

  @override
  void didUpdateWidget(TomMultiObservableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Deregister old, register new if the observable list changed
    if (!_listEquals(oldWidget.observables, widget.observables)) {
      _deregisterAll(oldWidget.observables);
      _registerAll(widget.observables);
    }
  }

  @override
  void dispose() {
    _deregisterAll(widget.observables);
    super.dispose();
  }

  void _registerAll(List<TomObservable> observables) {
    for (final obs in observables) {
      obs.addObserver(_observer);
    }
  }

  void _deregisterAll(List<TomObservable> observables) {
    for (final obs in observables) {
      obs.removeObserver(_observer);
    }
  }

  /// Identity-based list comparison (same objects in same order).
  static bool _listEquals(List<TomObservable> a, List<TomObservable> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Internal observer that triggers a callback on notification.
class _Observer implements TomObserver<TomObservable> {
  final VoidCallback _callback;

  _Observer(this._callback);

  @override
  void onNotify(TomObservable observable) => _callback();
}
