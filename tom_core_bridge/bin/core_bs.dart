/// Tom Core Bridge Server (`core_bs`) — extended VS Code bridge.
///
/// Entry point for the extended VS Code bridge server: the base
/// `tom_vscode_bridge` server (DCli + VS Code API bridges) **plus** the full
/// Tom Framework D4rt bridge set registered by `tom_core_d4rt`
/// (`TomDartscriptBridges.register`): tom_basics, tom_reflection,
/// tom_core_kernel, tom_core_server, tom_build, tom_dist_ledger,
/// tom_process_monitor, tom_doc_scanner, tom_doc_specs, tom_md2latex, and
/// tom_md2pdf.
///
/// Configure this binary in the VS Code extension as an alternative to the
/// base `tom_bs` bridge to expose all Tom Framework classes and functions in
/// the D4rt scripting environment.
///
/// The binary is launched by the VS Code extension and communicates over
/// stdin/stdout using a JSON-RPC-like protocol (see [main]).
library;

import 'package:tom_vscode_bridge/bridge_server.dart';
import 'package:tom_core_d4rt/dartscript.b.dart';

/// Starts the extended bridge server and blocks on stdin until VS Code closes
/// the pipe.
///
/// The body is intentionally trivial — this binary only *composes* the base
/// [VSCodeBridgeServer] with one extra bridge registrar; all behaviour lives
/// in the owning libraries (`tom_vscode_bridge` + `tom_core_d4rt`).
void main() {
  VSCodeBridgeServer(
    // Why: `additionalBridgeRegistrars` is the documented seam for layering
    // extra D4rt bridges onto the base server. Each entry is a
    // `BridgeRegistrar` callback `(D4rt interpreter) => void`; the server
    // invokes it after registering the base DCli + VS Code bridges, so the
    // Tom Framework surfaces become available without forking the server.
    additionalBridgeRegistrars: [TomDartscriptBridges.register],
    // Why: `VSCodeBridgeServer.start()` wires the JSON-RPC-like transport —
    // it reads UTF-8, newline-delimited JSON request objects from stdin
    // ({method, id, params}) and writes JSON responses ({id, result|error})
    // to stdout. The channel is bidirectional: the server can also issue
    // reverse-RPC requests to the extension over the same pipe. Keeping the
    // protocol in the library means `core_bs` and the base `tom_bs` speak it
    // identically.
  ).start();
}
