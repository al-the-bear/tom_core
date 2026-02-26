/// Tom Core Bridge Server - Extended VS Code Bridge
///
/// Entry point for the extended VS Code bridge server with full Tom Framework
/// D4rt bridges (tom_core_kernel, tom_core_server, tom_build, tom_dist_ledger,
/// tom_process_monitor, tom_basics, tom_reflection, and DCli).
///
/// This binary can be configured in the VS Code extension as an alternative
/// to the basic `tom_bs` bridge. It provides all Tom Framework classes and
/// functions in the D4rt scripting environment.
///
/// This binary is launched by the VS Code extension and communicates via
/// stdin/stdout using a JSON-RPC-like protocol.
library;

import 'package:tom_vscode_bridge/bridge_server.dart';
import 'package:tom_core_d4rt/dartscript.b.dart';

void main() {
  VSCodeBridgeServer(
    additionalBridgeRegistrars: [TomDartscriptBridges.register],
  ).start();
}
