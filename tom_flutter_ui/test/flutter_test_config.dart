// Installs empty text and config bundles before the suite runs.
//
// Why: `TomTextResourceProvider.getAppResources()` refuses to bootstrap itself
// — it throws `resources.text_provider.not_installed` until startup code has
// called `setAppResourceProvider`. That is deliberate (a self-installing lookup
// would put a bundle in place without bumping `appResourcesRevision`, so
// observers registered earlier would keep showing raw keys), and it means every
// widget in this package that resolves a label needs the same bootstrap a real
// application performs in `main()`.
//
// An empty bundle is the right bootstrap here: every lookup then echoes its
// key, which is exactly what these tests assert against. Tests that care about
// specific text install their own provider in `setUp`.
//
// `flutter test` auto-discovers this file (one per package test root) and runs
// `testExecutable` before the suite.

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from(const {}),
  );
  await testMain();
}
