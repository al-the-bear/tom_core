// Bridge connection discovery + choice persistence (§6, Q4, C1).
//
// The TomSpecs editor connects to a running VS Code CLI Integration Server to
// reach Claude Code over the bridge. Multiple VS Code windows each run a
// server on a distinct port in 19900–19909; this layer scans that range, runs
// the workspace-identify handshake (`workspace.getInfoVce`, via
// `scanBridgePorts`), and persists the user's picked server so it is restored
// on the next launch.
//
// This file is the **non-UI** half (no Flutter): the scan service, the picker
// model, and the YAML sidecar store. The Flutter controller + picker widget
// that drive it live in `tom_forge_agentic`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';
import 'package:yaml/yaml.dart';

/// Lowest CLI bridge port scanned (inclusive).
const int bridgeScanMinPort = defaultVSCodeBridgePort;

/// Highest CLI bridge port scanned (inclusive).
const int bridgeScanMaxPort = maxVSCodeBridgePort;

/// How a discovered server relates to the editor right now.
enum BridgeServerStatus {
  /// A live server, reachable but not currently bound.
  available('available'),

  /// The server the editor is bound to.
  bound('bound');

  const BridgeServerStatus(this.token);

  /// Stable token for display / persistence.
  final String token;
}

/// One responsive VS Code bridge: its port, the workspace its window has open,
/// and how it relates to the editor (`available` / `bound`). Shown in the
/// picker as *port · workspace · status*.
class BridgeServer {
  const BridgeServer({
    required this.port,
    required this.workspace,
    this.host = '127.0.0.1',
    this.status = BridgeServerStatus.available,
  });

  /// The CLI Integration Server port.
  final int port;

  /// Host the server is reachable on.
  final String host;

  /// The workspace name reported by the window-identity handshake.
  final String workspace;

  /// How this server relates to the editor right now.
  final BridgeServerStatus status;

  BridgeServer copyWith({BridgeServerStatus? status}) => BridgeServer(
        port: port,
        host: host,
        workspace: workspace,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) =>
      other is BridgeServer &&
      other.port == port &&
      other.host == host &&
      other.workspace == workspace &&
      other.status == status;

  @override
  int get hashCode => Object.hash(port, host, workspace, status);

  @override
  String toString() =>
      'BridgeServer($host:$port · $workspace · ${status.token})';
}

/// Scans the bridge port range and returns a `port → workspace` table.
///
/// Injected into [BridgeConnectionService] so a test can supply fake bridges
/// without opening sockets. The production default delegates to
/// [scanBridgePorts].
typedef BridgePortScanner = Future<Map<int, String>> Function({
  required String host,
  required int minPort,
  required int maxPort,
});

Future<Map<int, String>> _defaultScanner({
  required String host,
  required int minPort,
  required int maxPort,
}) =>
    scanBridgePorts(host: host, minPort: minPort, maxPort: maxPort);

/// Discovers live VS Code bridge servers (§6).
///
/// Wraps the port scan so the UI controller depends only on `tom_core_agentic`
/// and never touches the transport package directly.
class BridgeConnectionService {
  BridgeConnectionService({
    this.host = '127.0.0.1',
    this.minPort = bridgeScanMinPort,
    this.maxPort = bridgeScanMaxPort,
    BridgePortScanner scanner = _defaultScanner,
  }) : _scanner = scanner;

  /// Host to scan (default loopback).
  final String host;

  /// First port scanned (inclusive).
  final int minPort;

  /// Last port scanned (inclusive).
  final int maxPort;

  final BridgePortScanner _scanner;

  /// Scans the port range and returns the responsive servers in ascending
  /// port order. Every result is [BridgeServerStatus.available]; binding is
  /// the caller's concern.
  Future<List<BridgeServer>> scan() async {
    final table = await _scanner(
      host: host,
      minPort: minPort,
      maxPort: maxPort,
    );
    final ports = table.keys.toList()..sort();
    return [
      for (final port in ports)
        BridgeServer(port: port, host: host, workspace: table[port]!),
    ];
  }
}

/// The persisted choice: which host+port the editor last bound to.
class BridgeChoice {
  const BridgeChoice({required this.host, required this.port});

  /// Bound host.
  final String host;

  /// Bound port.
  final int port;

  Map<String, Object?> toMap() => {'host': host, 'port': port};

  factory BridgeChoice.fromMap(Map map) => BridgeChoice(
        host: (map['host'] as String?) ?? '127.0.0.1',
        port: (map['port'] as num?)?.toInt() ?? defaultVSCodeBridgePort,
      );

  @override
  bool operator ==(Object other) =>
      other is BridgeChoice && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => 'BridgeChoice($host:$port)';
}

/// Persists the picked bridge server to a YAML sidecar so the binding is
/// restored on the next launch ("the choice persists per spec", §6).
///
/// Mirrors the editor's other sidecars: a small YAML file written
/// synchronously on every change. The file lives outside the document so it is
/// never part of a `*.docspecs.yaml` save.
class BridgeChoiceStore {
  BridgeChoiceStore(this.file);

  /// The backing YAML file.
  final File file;

  /// Resolves the sidecar location. Honors `TOM_SPECS_BRIDGE_FILE`; falls back
  /// to `<cwd>/.tom/bridge_connection.yaml`.
  factory BridgeChoiceStore.resolveDefault() {
    final override = Platform.environment['TOM_SPECS_BRIDGE_FILE'];
    final path = (override != null && override.isNotEmpty)
        ? override
        : p.join(Directory.current.path, '.tom', 'bridge_connection.yaml');
    return BridgeChoiceStore(File(path));
  }

  /// Loads the persisted choice, or `null` if none is stored.
  BridgeChoice? load() {
    if (!file.existsSync()) return null;
    final content = file.readAsStringSync();
    if (content.trim().isEmpty) return null;
    final doc = loadYaml(content);
    if (doc is! YamlMap) return null;
    final bridge = doc['bridge'];
    if (bridge is! YamlMap) return null;
    return BridgeChoice.fromMap(bridge);
  }

  /// Persists [choice], creating the parent directory if needed.
  void save(BridgeChoice choice) {
    final buffer = StringBuffer()
      ..writeln('# TomSpecs editor — bound VS Code bridge server.')
      ..writeln('# Written by the agent connection picker (§6).')
      ..writeln('version: 1')
      ..writeln('bridge:')
      ..writeln('  host: ${choice.host}')
      ..writeln('  port: ${choice.port}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(buffer.toString());
  }

  /// Removes the persisted choice (e.g. on explicit unbind).
  void clear() {
    if (file.existsSync()) file.deleteSync();
  }
}
