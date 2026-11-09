/// Entry point of the audit application.
///
/// Signs in at the advanced sample's auth server and reads the audit trail
/// through the app server's audit-report API, at the addresses
/// `AdvancedClientConfig` names (`http://localhost:8081`, `:8080`). Built with
/// `--dart-define=TEST_MODE=true` it runs on [InMemoryAuditBackend] instead and
/// needs no server.
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'app.dart';
import 'backend.dart';
import 'reflection_seed.dart';

Future<void> main() async {
  initializeReflection();
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
  AdvancedClientConfig.registerDefault();
  runApp(
    AuditApp(
      backend: const bool.fromEnvironment('TEST_MODE')
          ? InMemoryAuditBackend()
          : LiveAuditBackend.fromConfig(),
    ),
  );
}
