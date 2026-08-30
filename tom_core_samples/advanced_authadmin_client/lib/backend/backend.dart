/// The admin console's backend seam and its two implementations.
///
/// Import this barrel to bind an admin screen against the transport-independent
/// [AdminBackend]: the seeded [InMemoryAdminBackend] for offline use and widget
/// tests, or the [LiveAdminBackend] that delegates to `advanced_client_core` over
/// HTTP.
library;

export 'admin_backend.dart';
export 'in_memory_admin_backend.dart';
export 'live_admin_backend.dart';
