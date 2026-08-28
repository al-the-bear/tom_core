/// The auth server's text resource bundles.
///
/// Per D-A10 the auth server owns two text sets: the **public** login-screen
/// texts (served before anyone signs in, by both clients) and the **admin
/// console** texts (served after an admin signs in). Both are served as the flat
/// `<basePath>.<suffix>` maps the resource endpoints return and the clients
/// install via `TomTextResourceProvider.from(dto.texts)` — see
/// `advanced_app_client` and `advanced_authadmin_client`.
///
/// The texts no longer live as Dart `const` maps: each set is a **nested JSON
/// asset** structured along the client's scope → form → field hierarchy, loaded
/// once and [flattenResourceTree]-ed into the flat served shape. The nesting is
/// an authoring convenience only: flattening is what the endpoints return, so
/// the wire contract is the flat map either way:
///
/// - [loginBundle] (public, `GET /auth/resources/login`,
///   `assets/resources_login.json`) carries the `login.*` keys the app client's
///   login form self-addresses (`formId: 'login'`, no scope → `login.username.label`,
///   …) plus the `adminLogin.*` keys the admin console's plain login screen reads.
/// - [adminConsoleBundle] (admin-gated, `GET /admin/resources`,
///   `assets/resources_admin.json`) carries the admin editors' form labels
///   (`user.*`/`role.*`/`group.*`, matching each reflected form's `formId` and
///   field `tomId`s) plus the `grants.*` texts of the grant-matrix screen.
library;

import 'dart:convert';
import 'dart:io';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';

/// Builds the auth server's text bundles from their nested JSON resource assets.
class AuthResourceBundles {
  const AuthResourceBundles._();

  /// The public login-texts asset (working-directory-relative, as the YAML
  /// config/datasource assets are).
  static const String loginAssetPath = 'assets/resources_login.json';

  /// The admin-console-texts asset.
  static const String adminAssetPath = 'assets/resources_admin.json';

  static Map<String, Object?>? _loginCache;
  static Map<String, Object?>? _adminCache;

  /// Public login + adminLogin texts, loaded and flattened once.
  static Map<String, Object?> loginTexts() =>
      _loginCache ??= loadFlatResourceAsset(loginAssetPath);

  /// Admin-console texts (editor labels + grants), loaded and flattened once.
  static Map<String, Object?> adminConsoleTexts() =>
      _adminCache ??= loadFlatResourceAsset(adminAssetPath);

  /// The public login bundle (`login.*` + `adminLogin.*`).
  static ResourceBundleDto loginBundle() => ResourceBundleDto(loginTexts());

  /// The admin-gated console bundle (admin form labels + grants texts).
  static ResourceBundleDto adminConsoleBundle() =>
      ResourceBundleDto(adminConsoleTexts());
}

/// Reads a nested JSON resource asset at [path] (working-directory-relative) and
/// flattens it to the flat `<basePath>.<suffix>` map the wire bundle carries.
///
/// Throws a [StateError] when the asset is missing, rather than silently serving
/// an empty bundle — an absent text asset would otherwise break the
/// no-hard-coded-strings property invisibly.
Map<String, Object?> loadFlatResourceAsset(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Resource asset not found: $path (cwd: ${Directory.current.path})',
    );
  }
  final tree = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return flattenResourceTree(tree);
}
