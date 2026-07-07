/// The client-side configuration bean: the base URLs the Flutter clients target
/// when they run against real servers — which is the **default** run mode
/// (G-ENV-2). A client started with no dart-defines talks to these servers.
///
/// Server URLs live **here**, in a config bean resolved through the kernel's
/// [TomBean] locator, never in `String.fromEnvironment` reads scattered across a
/// client's `main()` (G-ENV-3). [registerDefault] seeds the local-development
/// defaults once at startup; each client's `main()` resolves the bean and reads
/// the two URLs it needs. The seeded in-memory backend is a separate, opt-in
/// path selected only by `--dart-define=TEST_MODE=true` (G-ENV-3 / G-RUN-2) — it
/// does not read this config.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The server base URLs both advanced clients target.
///
/// One shared shape carries all three URLs (auth, app, admin) so a single bean
/// serves both clients; each client reads only the pair it drives — the app
/// client [authServerUrl] + [appServerUrl], the admin console [authServerUrl] +
/// [adminServerUrl].
class AdvancedClientConfig {
  /// Creates a config with the given URLs, defaulting to the local-development
  /// stack (`advanced_auth_server` on 8081, `advanced_app_server` on 8080; the
  /// admin API is the auth server's `/admin/*` on 8081).
  const AdvancedClientConfig({
    this.authServerUrl = 'http://localhost:8081',
    this.appServerUrl = 'http://localhost:8080',
    this.adminServerUrl = 'http://localhost:8081',
  });

  /// The name both clients register and resolve the shared config bean under.
  static const String beanName = 'advancedClientConfig';

  /// The auth server issuing the bearer both clients present (login/token).
  final String authServerUrl;

  /// The task API the app client's board calls hit.
  final String appServerUrl;

  /// The `/admin/*` API the admin console mutates roles/groups/grants through.
  final String adminServerUrl;

  /// Registers [config] (default: the local-development URLs) as the named
  /// config bean and returns it. If a config bean is already registered — a
  /// repeated boot, or a test that pre-seeded its own — the existing one is
  /// returned unchanged, so this never trips the locator's duplicate-name guard.
  static AdvancedClientConfig registerDefault([
    AdvancedClientConfig config = const AdvancedClientConfig(),
  ]) {
    final existing = TomBean.getBeanByName(beanName);
    if (existing is AdvancedClientConfig) return existing;
    TomBean<AdvancedClientConfig>.withName(beanName, config);
    return config;
  }

  /// Resolves the registered config bean. Call [registerDefault] first (each
  /// client's `main()` does, before building its backend).
  static AdvancedClientConfig resolve() =>
      TomBean<AdvancedClientConfig>.fromName(beanName).get();
}
