/// The auth server's text resource bundles (step / todo 7).
///
/// Per D-A10 the auth server owns two text sets: the **public** login-screen
/// texts (served before anyone signs in, by both clients) and the **admin
/// console** texts (served after an admin signs in). Both are flat
/// `<basePath>.<suffix>` maps the resource endpoints serve and the clients
/// install via `TomTextResourceProvider.from(dto.texts)` (todos 8–9).
///
/// - [loginBundle] (public, `GET /auth/resources/login`) carries the `login.*`
///   keys the app client's login form self-addresses (`formId: 'login'`, no
///   scope → `login.username.label`, …) plus the `adminLogin.*` keys the admin
///   console's plain login screen reads.
/// - [adminConsoleBundle] (admin-gated, `GET /admin/resources`) carries the
///   admin editors' form labels (`user.*`/`role.*`/`group.*`, matching each
///   reflected form's `formId` and field `tomId`s) plus the `grants.*` texts of
///   the grant-matrix screen.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

/// Builds the auth server's text bundles. Pure and database-free, so each is
/// unit-tested directly and the endpoints simply return the matching bundle.
class AuthResourceBundles {
  const AuthResourceBundles._();

  /// Public login-screen texts for both clients.
  static const Map<String, String> _loginTexts = {
    // App client login form (`LoginForm`, formId 'login', no scope).
    'login.title': 'Advanced Todo — Sign in',
    'login.intro': 'Try alice, bob or val (any non-empty password).',
    'login.username.label': 'Username',
    'login.username.hint': 'alice, bob or val',
    'login.password.label': 'Password',
    'login.submit': 'Sign in',
    // Admin console login screen (plain Material form).
    'adminLogin.title': 'Advanced Todo — Admin sign in',
    'adminLogin.intro':
        'Sign in as admin (password pw). A non-admin (alice, bob, val) is rejected.',
    'adminLogin.username.label': 'Username',
    'adminLogin.username.hint': 'admin',
    'adminLogin.password.label': 'Password',
    'adminLogin.submit': 'Sign in',
  };

  /// Admin-console texts: the reflected editors' field labels (keyed
  /// `<formId>.<tomId>.label`, matching `UserForm`/`RoleForm`/`GroupForm`) plus
  /// the grant-matrix screen texts.
  static const Map<String, String> _adminConsoleTexts = {
    // UserForm (formId 'user').
    'user.username.label': 'Username',
    'user.password.label': 'Password',
    'user.displayName.label': 'Display name',
    'user.email.label': 'Email',
    'user.status.label': 'Status',
    // RoleForm (formId 'role').
    'role.key.label': 'Key',
    'role.name.label': 'Name',
    // GroupForm (formId 'group').
    'group.name.label': 'Name',
    // Grant-matrix screen.
    'grants.title': 'Grant matrix',
    'grants.column.none': 'None',
    'grants.column.read': 'Read',
    'grants.column.full': 'Full',
    'grants.save': 'Save grants',
  };

  /// The public login bundle (`login.*` + `adminLogin.*`).
  static ResourceBundleDto loginBundle() =>
      ResourceBundleDto(Map<String, Object?>.from(_loginTexts));

  /// The admin-gated console bundle (admin form labels + grants texts).
  static ResourceBundleDto adminConsoleBundle() =>
      ResourceBundleDto(Map<String, Object?>.from(_adminConsoleTexts));
}
