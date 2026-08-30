/// Entry point for `advanced_app_client` — the end-user task board for the
/// advanced Tom Core full-stack sample (step 27).
///
/// Five registrations run before the first frame, in this order:
///
///  1. [initializeReflection] (from this app's `reflection_seed.dart`) registers
///     the reflected `@tomReflector` entities the backend constructs and the
///     forms bind — the shared `advanced_todo_domain` entities plus the
///     client-local `LoginCredentials`/`LoginForm`, all captured by the one
///     generated seed. It must run before any reflected type is built (the
///     in-memory backend seeds its tree in its constructor), so it comes first.
///  2. [registerProjectRoleVocabulary] establishes the shared
///     `ProjectRole → TomAuthState` mapping in the [TomResourceRoleRegistry],
///     which every resource-key lookup resolves a role name through (C-5).
///  3. The Flutter client platform is registered via
///     `TomPlatformUtils.setCurrentPlatform(clientPlatformUtils)` so kernel code
///     that probes the runtime gets the Flutter implementation.
///  4. [registerSampleFilePicker] installs the one picker seam every file field
///     in the app opens.
///  5. [AdvancedClientConfig.registerDefault] installs the config bean holding
///     the server URLs the live backend self-wires from.
///
/// Then an [AppSession] is constructed over the DI-selected [AppBackend]; the
/// public login resource bundle is fetched through that backend seam and
/// installed as the singleton [TomTextResourceProvider], so the sign-in screen
/// renders server-delivered chrome rather than any hardcoded string; and
/// [runApp] starts the shell over that session.
///
/// The **default** run mode is the live stack: started with no dart-defines the
/// app targets the local `advanced_auth_server` + `advanced_app_server` through
/// a [LiveAppBackend], reading their URLs from the [AdvancedClientConfig] config
/// bean (G-ENV-2). The seeded [InMemoryAppBackend] is a testing convenience,
/// opt-in only via `--dart-define=TEST_MODE=true` (G-ENV-3) — never a default
/// reached by forgetting a flag.
///
/// The two backends are not chosen by an inline `if`: the launch flag selects an
/// environment *name* ([_clientEnvironment]) and the kernel bean locator installs
/// the one backend registered for that environment (G-DI-3/G-DI-5).
///
/// Authorization resolves through the framework registry (RCC2): boot registers
/// the shared `ProjectRole → TomAuthState` vocabulary
/// ([registerProjectRoleVocabulary]), and on login the [AppSession] installs the
/// principal's per-resource role grants as the [TomAuthorization] adapter, so the
/// item detail screen resolves each field's resource-level ceiling through the
/// [TomResourceRoleRegistry] and narrows it by the shared field-grade matrix —
/// rather than stamping a DB-resolved grade directly.
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'app/app.dart';
import 'backend/backend.dart';
import 'files/sample_file_picker.dart';
import 'reflection_seed.dart';

/// The active client environment, chosen by the one launch flag: `prod` (the
/// default live stack) unless `--dart-define=TEST_MODE=true` selects the seeded
/// in-memory `test` environment (G-ENV-2/G-ENV-3). This is the environment
/// *selector*; the locator picks the backend from the name.
const String _clientEnvironment =
    bool.fromEnvironment('TEST_MODE') ? 'test' : 'prod';

Future<void> main() async {
  initializeReflection();
  // Establishes the shared ProjectRole → TomAuthState grade vocabulary the
  // framework's TomResourceRoleAdapter resolves resource keys through (C-5);
  // every runtime that grades a ProjectRole resource registers the identical
  // mapping at boot — here, the auth server, the app server and the ops server.
  registerProjectRoleVocabulary();
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
  // The one file-picker registration every file field in the app opens. A real
  // application replaces the body of [registerSampleFilePicker] with the six
  // lines that call its picker package — the seam does not change.
  registerSampleFilePicker();
  AdvancedClientConfig.registerDefault();

  final session = AppSession(_installBackend());

  // Fetch + install the server-delivered login chrome before the first frame.
  await session.loadLoginResources();

  runApp(AdvancedTodoApp(session: session));
}

/// Selects and installs the [AppBackend] by environment (G-DI-3/G-DI-5): the
/// `prod` environment self-wires a [LiveAppBackend] from the
/// [AdvancedClientConfig] config bean; the `test` environment installs the seeded
/// [InMemoryAppBackend]. Exactly one backend is built and registered — there is
/// no runtime dispatcher.
///
/// The two run modes show the *same* sign-in, and they do so without a switch
/// here: which accounts owe a second factor is seed data in both. Offline it is
/// [InMemoryAppBackend]'s `_secrets` / `twoFactorEnrolling`; live it is the
/// `two_factor_secret` column and the `two_factor_required` /
/// `two_factor_optional` role rows the `[005]` migration seeds. So `dave` is
/// challenged and `erin` is offered enrolment in either mode, and `alice` signs
/// straight in in either mode.
AppBackend _installBackend() => TomBean.installByEnvironment<AppBackend>(
      {
        'prod': LiveAppBackend.fromConfig,
        'test': InMemoryAppBackend.new,
      },
      environment: _clientEnvironment,
    ).get();
