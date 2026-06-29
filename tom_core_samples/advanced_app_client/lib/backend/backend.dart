/// The end-user app's backend seam and its two implementations (step 26).
///
/// Import this barrel to bind a screen against the transport-independent
/// [AppBackend]: the seeded [InMemoryAppBackend] for offline use and widget
/// tests, or the [LiveAppBackend] that delegates to `advanced_client_core` over
/// HTTP.
library;

export 'app_backend.dart';
export 'in_memory_app_backend.dart';
export 'live_app_backend.dart';
