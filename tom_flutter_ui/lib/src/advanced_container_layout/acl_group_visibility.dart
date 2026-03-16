import 'package:flutter/foundation.dart';

/// Controls whether a group of components is visible, hidden, or disabled.
enum AclGroupVisibilityMode {
  /// Group is visible and interactive (default).
  visible,

  /// Group is hidden — components removed from layout (zero size, no paint).
  hidden,

  /// Group is disabled — components are visible but non-interactive
  /// (greyed out, ignores pointer events).
  disabled,
}

/// Base class for controlling the visibility of a named group within an
/// ACL container.
abstract class AclGroupVisibilityController {
  /// Returns the current visibility mode for the group.
  AclGroupVisibilityMode get mode;

  /// Notifier that the layout listens to for reactive updates.
  ValueNotifier<AclGroupVisibilityMode> get modeNotifier;

  /// Dispose resources when the container is disposed.
  void dispose();
}

/// Simple binary toggle controller for group visibility.
///
/// ```dart
/// final ctrl = AclBinaryVisibilityController(
///   initialMode: AclGroupVisibilityMode.hidden,
/// );
/// ctrl.mode = AclGroupVisibilityMode.visible; // toggle
/// ```
class AclBinaryVisibilityController extends AclGroupVisibilityController {
  final ValueNotifier<AclGroupVisibilityMode> _notifier;

  AclBinaryVisibilityController({
    AclGroupVisibilityMode initialMode = AclGroupVisibilityMode.visible,
  }) : _notifier = ValueNotifier(initialMode);

  @override
  AclGroupVisibilityMode get mode => _notifier.value;

  set mode(AclGroupVisibilityMode value) => _notifier.value = value;

  @override
  ValueNotifier<AclGroupVisibilityMode> get modeNotifier => _notifier;

  @override
  void dispose() => _notifier.dispose();
}

/// Callback-based controller that derives visibility from an external
/// [ValueListenable].
///
/// ```dart
/// final ctrl = AclCallbackVisibilityController<String>(
///   valueListenable: countryNotifier,
///   modeBuilder: (country) => country == 'US'
///       ? AclGroupVisibilityMode.visible
///       : AclGroupVisibilityMode.hidden,
/// );
/// ```
class AclCallbackVisibilityController<T> extends AclGroupVisibilityController {
  final ValueListenable<T> _source;
  final AclGroupVisibilityMode Function(T value) _modeBuilder;
  final ValueNotifier<AclGroupVisibilityMode> _notifier;

  AclCallbackVisibilityController({
    required ValueListenable<T> valueListenable,
    required AclGroupVisibilityMode Function(T value) modeBuilder,
  })  : _source = valueListenable,
        _modeBuilder = modeBuilder,
        _notifier = ValueNotifier(modeBuilder(valueListenable.value)) {
    _source.addListener(_onSourceChanged);
  }

  void _onSourceChanged() {
    _notifier.value = _modeBuilder(_source.value);
  }

  @override
  AclGroupVisibilityMode get mode => _notifier.value;

  @override
  ValueNotifier<AclGroupVisibilityMode> get modeNotifier => _notifier;

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    _notifier.dispose();
  }
}
