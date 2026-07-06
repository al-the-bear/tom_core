/// Entry point for `advanced_authadmin_client` — the administrator console for
/// the advanced Tom Core full-stack sample (steps 33–34).
///
/// Before the first frame these bootstraps run: [initializeReflection] (from
/// this app's `reflection_seed.dart`) registers the reflected drafts and the
/// user/role/group editor forms so the admin screens' `TomForm` bind/save
/// round-trips resolve (step 34); the Flutter client platform is registered via
/// `TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)` so kernel code that
/// probes the runtime gets the Flutter implementation; and the public login
/// resource bundle is fetched through the backend seam and installed as the
/// singleton [TomTextResourceProvider], so the admin sign-in screen renders
/// server-delivered chrome rather than any hardcoded string. The console then
/// runs over an [AdminSession] wrapping the chosen [AdminBackend].
///
/// The **default** run mode is the live stack: started with no dart-defines the
/// console drives the local auth server's `/admin/*` API through a
/// [LiveAdminBackend], reading its URLs from the [AdvancedClientConfig] config
/// bean (G-ENV-2). The seeded [InMemoryAdminBackend] is a testing convenience,
/// opt-in only via `--dart-define=TEST_MODE=true` (G-ENV-3) — never a default
/// reached by forgetting a flag.
///
/// The two backends are not chosen by an inline `if`: the launch flag selects an
/// environment *name* ([_clientEnvironment]) and the kernel bean locator installs
/// the one backend registered for that environment (G-DI-3/G-DI-5).
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'app/admin_app.dart';
import 'backend/backend.dart';
import 'reflection_seed.dart';

/// The active client environment, chosen by the one launch flag: `prod` (the
/// default live stack) unless `--dart-define=TEST_MODE=true` selects the seeded
/// in-memory `test` environment (G-ENV-2/G-ENV-3). This is the environment
/// *selector*; the locator picks the backend from the name.
const String _clientEnvironment =
    bool.fromEnvironment('TEST_MODE') ? 'test' : 'prod';

Future<void> main() async {
  initializeReflection();
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
  AdvancedClientConfig.registerDefault();

  final session = AdminSession(_installBackend());

  // Fetch + install the server-delivered login chrome before the first frame.
  await session.loadLoginResources();

  runApp(AdminConsoleApp(session: session));
}

/// Selects and installs the [AdminBackend] by environment (G-DI-3/G-DI-5): the
/// `prod` environment self-wires a [LiveAdminBackend] from the
/// [AdvancedClientConfig] config bean; the `test` environment installs the seeded
/// [InMemoryAdminBackend]. Exactly one backend is built and registered — there is
/// no runtime dispatcher.
AdminBackend _installBackend() => TomBean.installByEnvironment<AdminBackend>(
      {
        'prod': LiveAdminBackend.fromConfig,
        'test': InMemoryAdminBackend.new,
      },
      environment: _clientEnvironment,
    ).get();
