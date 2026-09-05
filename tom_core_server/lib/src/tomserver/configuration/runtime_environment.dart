/// Resolves which runtime environment a deployment selected, from the same
/// sources the configuration merge reads and in the same order.
///
/// The selection has to happen *before* the configuration exists — the
/// environment is what picks the configuration overlay
/// (`config-resources_<env>.yaml`) — so it cannot come out of the merge and has
/// to read the sources itself. That is the whole reason this is a separate
/// lookup rather than a configuration field.
library;

import 'dart:io';

import '../cmdline/args.dart';
import '../cmdline/env_file.dart';

/// Returns the runtime environment name the deployment selected, or null when
/// no source named one.
///
/// Sources, highest precedence first:
///
/// 1. a command-line argument, `env=dev` (undashed, as `doc/cmdline.md` has it);
/// 2. the `.env` file in the current directory;
/// 3. the OS environment.
///
/// That is the order [TomBaseServerConfiguration.getDefaultValues] gives the
/// same three sources, so a server's environment and its configuration are
/// never chosen by different rules.
///
/// Null means nobody named one, which is exactly what
/// `TomRuntime.setCurrentEnvironment` takes as "apply the fallback" — so the
/// choice of default stays with the caller that knows it:
///
/// ```dart
/// TomRuntime.setCurrentEnvironment(selectedRuntimeEnvironmentName(args), 'prod');
/// ```
///
/// [variable] is the name looked up in each source; it defaults to `env`, which
/// is what every sample and server in this workspace writes. The value is
/// returned as text even when a source typed it — `TomEnvFile` converts `2` to
/// an int, and an environment is named rather than numbered, so a caller
/// comparing against `TomEnvironment.env` would otherwise silently miss.
String? selectedRuntimeEnvironmentName(
  List<String> args, {
  String variable = 'env',
}) {
  final fromArgs = TomArgs.parseArgsToMap(args)[variable];
  if (fromArgs != null) return fromArgs.toString();

  final fromEnvFile = TomEnvFile.read()[variable];
  if (fromEnvFile != null) return fromEnvFile.toString();

  return Platform.environment[variable];
}
