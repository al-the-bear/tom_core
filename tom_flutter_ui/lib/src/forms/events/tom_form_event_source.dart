import 'tom_form_event.dart';
import 'tom_form_event_listener.dart';

/// Abstract event source for form events.
///
/// Allows widgets like [TomFormErrorBanner] to be decoupled from the full
/// [TomForm] implementation, improving testability.
abstract class TomFormEventSource {
  /// Register a listener for form events.
  void addListener(TomFormEventListener listener);

  /// Remove a previously registered listener.
  void removeListener(TomFormEventListener listener);

  /// Dispatch an event to all registered listeners.
  void fireEvent(TomFormEvent event);
}
