/// The admin console shell barrel (step 33): the [AdminSession] and the
/// [AdminConsoleApp] root that swaps between the login and console screens on
/// session state.
///
/// Import this to bootstrap or test the console; the individual screens live
/// under `lib/screens/` and are reached through the shell, not bound directly.
library;

export 'admin_root.dart';
export 'admin_session.dart';
