/// The app shell barrel: the [AppSession] and the [AdvancedTodoApp]
/// root that swaps between the login and board screens on session state, plus
/// the two seams the shell hands to the framework — [AppResourceRoleAdapter]
/// for authorization and [SessionTwoFactorController] for the second factor.
///
/// Import this to bootstrap or test the shell; the individual screens live under
/// `lib/screens/` and are reached through the shell, not bound directly.
library;

export 'app_resource_role_adapter.dart';
export 'app_root.dart';
export 'app_session.dart';
export 'session_two_factor_controller.dart';
