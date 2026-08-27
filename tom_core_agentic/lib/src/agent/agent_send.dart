// Agent send pipeline — assemble SDK `Options`, stream a `query`, and keep a
// per-specification session id with the §7.2 refresh rule (TomSpecs editor §7).
//
// This is the **non-UI** half (no Flutter): the editor's Flutter controller in
// `tom_forge_agentic` drives [AgentSendEngine] and renders its [AgentSendEvent]
// stream. The engine is a thin orchestration over `tom_vscode_scripting_api`'s
// [AgentSdkClient]:
//
//   * assemble an [Options] from the active profile + global settings (+ the
//     navigation/mutation MCP tools, wired in §8/step 14) via [AgentSendConfig];
//   * stream `query(prompt, options)`, translating each `SdkAssistantMessage`'s
//     `TextBlock`s into [AgentSendChunk]s and the terminal `SdkResultMessage`
//     into [AgentSendCompleted];
//   * hold a per-spec SDK session id in a YAML sidecar ([SpecSessionStore]),
//     auto-refreshed on a session error per §7.2 / N3.
//
// It is intentionally **separate** from the substrate `AgentSdkLlmProvider`
// (also in this package): that provider serves the brain's `LlmProvider` seam
// with `WirePrompt`/`LlmCallReport` and the conservative brain session matcher;
// the editor sends a plain prompt string, assembles a far wider `Options`
// surface, and uses the broader §7.2 rule. The ~20-line stream loop they share
// in shape will diverge in substance, so they are kept apart by design.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import '../cancellation.dart';
import 'agent_profile.dart' show AgentProfile;
import 'agent_sidecar.dart';

/// True when [message] should be treated as an SDK **session error** under the
/// editor rule (§7.2, N3): its text contains `session`, `message`, or `msg`
/// (case-insensitive).
///
/// Deliberately broad — unlike the brain's conservative matcher
/// (`agentSdkLooksLikeSessionError`) it does not require a separate failure cue.
/// The editor would rather drop and refresh a per-spec session id one extra
/// time than leave a stale id wedged in place.
bool specSessionLooksLikeError(String message) {
  final lower = message.toLowerCase();
  return lower.contains('session') ||
      lower.contains('message') ||
      lower.contains('msg');
}

/// The per-specification SDK session id, persisted to a YAML sidecar so the
/// agent can resume the same Claude-Code conversation across sends and launches
/// (§7.2). Held **out of** the `document:` pass — it is transport state, not
/// document content.
///
/// Mirrors the editor's other sidecars (e.g. `BridgeChoiceStore`): a small YAML
/// file written synchronously on every change, degrading to "no session" on any
/// read/parse error rather than throwing.
class SpecSessionStore {
  SpecSessionStore(this.file);

  /// The backing YAML file.
  final File file;

  /// Resolves the sidecar location. Honors `TOM_SPECS_SESSION_FILE`; falls back
  /// to `<cwd>/.tom/agent_session.yaml`.
  factory SpecSessionStore.resolveDefault() {
    final override = Platform.environment['TOM_SPECS_SESSION_FILE'];
    final path = (override != null && override.isNotEmpty)
        ? override
        : p.join(Directory.current.path, '.tom', 'agent_session.yaml');
    return SpecSessionStore(File(path));
  }

  /// Loads the stored session id, or `null` if none is persisted (or the file
  /// is missing / unreadable / malformed).
  ///
  /// The one sidecar holding a bare scalar rather than a model, so it reads
  /// the shared file loader directly instead of one of its decoders.
  String? load() {
    final id = readAgentYamlFile(file)?['sessionId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Persists [sessionId], creating the parent directory if needed.
  void save(String sessionId) {
    final buffer = StringBuffer()
      ..writeln('# TomSpecs editor — per-specification Agent SDK session id.')
      ..writeln('# Auto-refreshed on session errors (§7.2). Not part of the')
      ..writeln('# document save — this is transport state only.')
      ..writeln('version: 1')
      ..writeln('sessionId: $sessionId');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(buffer.toString());
  }

  /// Forgets the stored session id (e.g. after a session error, §7.2).
  void clear() {
    if (file.existsSync()) file.deleteSync();
  }
}

/// The editor-assembled inputs to one `query` `Options` (§7.1/§7.2), minus the
/// session id (which the engine supplies from [SpecSessionStore]).
///
/// Built from the active **profile** + global **agent settings** + the
/// navigation/mutation **MCP tools** (§8). Step 12 wires the profile + the few
/// global knobs the send needs; the full §7.1 surface and the MCP tool server
/// are filled by later steps (the [mcpServers] seam is already here so step 14
/// only has to populate it).
class AgentSendConfig {
  const AgentSendConfig({
    this.model,
    this.systemPrompt,
    this.permissionMode,
    this.maxTurns,
    this.cwd,
    this.mcpServers,
  });

  /// The model id, or `null` for the SDK default.
  final String? model;

  /// The profile's system prompt, sent as an additive [SystemPromptText] (never
  /// an override — Claude Code's own system prompt stays in place).
  final String? systemPrompt;

  /// Permission posture for Claude Code's tool loop, or `null` for the default.
  final PermissionMode? permissionMode;

  /// Claude Code's agentic-loop turn cap, or `null` for the SDK default.
  final int? maxTurns;

  /// The agent working directory — the document/spec folder (A1/N2), or `null`.
  final String? cwd;

  /// The navigation/mutation MCP servers (§8), or `null` until step 14 wires
  /// them.
  final Map<String, McpServerConfig>? mcpServers;

  /// Assembles a send config from the active [profile] plus global settings.
  ///
  /// The profile contributes the system prompt (and, absent an explicit
  /// [maxTurns], its `maxRounds`); the remaining knobs come from the global
  /// agent settings the caller passes through.
  factory AgentSendConfig.fromProfile(
    AgentProfile? profile, {
    String? model,
    PermissionMode? permissionMode,
    int? maxTurns,
    String? cwd,
    Map<String, McpServerConfig>? mcpServers,
  }) {
    final prompt = profile?.systemPrompt;
    return AgentSendConfig(
      model: model,
      systemPrompt: (prompt != null && prompt.isNotEmpty) ? prompt : null,
      permissionMode: permissionMode,
      maxTurns: maxTurns ?? profile?.maxRounds,
      cwd: cwd,
      mcpServers: mcpServers,
    );
  }

  /// Builds the SDK [Options] for one `query`, with [resumeSessionId] threaded
  /// into `resume` (omitted from the wire when `null`, so a fresh session is
  /// started).
  Options buildOptions({String? resumeSessionId}) => Options(
        model: model,
        systemPrompt: (systemPrompt == null || systemPrompt!.isEmpty)
            ? null
            : SystemPromptText(systemPrompt!),
        permissionMode: permissionMode,
        maxTurns: maxTurns,
        cwd: cwd,
        mcpServers: mcpServers,
        resume: resumeSessionId,
      );
}

/// One step of an [AgentSendEngine.send] run.
sealed class AgentSendEvent {
  const AgentSendEvent();
}

/// Emitted once, first, when a send begins.
class AgentSendStarted extends AgentSendEvent {
  const AgentSendStarted();
}

/// A streamed chunk of assistant answer text (in order).
class AgentSendChunk extends AgentSendEvent {
  const AgentSendChunk(this.text);

  /// The assistant text fragment.
  final String text;
}

/// Emitted when a session error (§7.2) caused the stored session id to be
/// dropped and the prompt to be retried with a fresh session.
class AgentSendSessionRefreshed extends AgentSendEvent {
  const AgentSendSessionRefreshed();
}

/// Terminal success: the query produced a result message.
class AgentSendCompleted extends AgentSendEvent {
  const AgentSendCompleted(this.sessionId);

  /// The Claude-Code session id of the completed turn, persisted for resume, or
  /// `null` if the result carried none.
  final String? sessionId;
}

/// Terminal failure: a non-session error, or a stream with no result message.
class AgentSendFailed extends AgentSendEvent {
  const AgentSendFailed(this.message);

  /// The error text surfaced to the user.
  final String message;
}

/// Builds (and connects) an [AgentSdkClient] over the VS Code bridge at
/// [host]:[port] (§7, the editor's transport seam).
///
/// Lives here, in the pure-Dart model layer, rather than in the Flutter
/// `tom_forge_agentic` controller because the UI layer "never owns transport
/// specifics" (N7): it hands the controller this factory (or a fake) and stays
/// transport-agnostic. Throws a [StateError] if the bridge socket does not come
/// up, so the caller can surface a connect failure to the user.
typedef AgentSdkClientFactory = Future<AgentSdkClient> Function(
    {required String host, required int port});

/// The production [AgentSdkClientFactory]: opens a [VSCodeBridgeClient] socket
/// and wraps it in the bridge-backed transport.
Future<AgentSdkClient> connectAgentSdkClient({
  required String host,
  required int port,
}) async {
  final bridge = VSCodeBridgeClient(host: host, port: port);
  final connected = await bridge.connect();
  if (!connected) {
    throw StateError('Could not connect to the VS Code bridge at $host:$port.');
  }
  return AgentSdkClient(VSCodeBridgeAgentSdkTransport(bridge));
}

/// Streams a single prompt through the Agent SDK and keeps the per-spec session
/// id refreshed (§7.2).
///
/// One engine wraps one [AgentSdkClient] (bound to the picked bridge), one
/// [SpecSessionStore], and the assembled [AgentSendConfig]. [send] is a cold
/// stream: each listen runs one `query`, transparently retrying once with a
/// fresh session if the first attempt fails with a session error **before** any
/// answer text has streamed.
class AgentSendEngine {
  AgentSendEngine({
    required this.client,
    required this.sessionStore,
    required this.config,
  });

  /// The connected SDK client (over the bound bridge).
  final AgentSdkClient client;

  /// The per-spec session id sidecar.
  final SpecSessionStore sessionStore;

  /// The assembled `Options` inputs.
  final AgentSendConfig config;

  /// Sends [prompt], streaming the assistant's answer and refreshing the
  /// session id on a session error.
  ///
  /// Lifecycle: exactly one [AgentSendStarted] first; zero or more
  /// [AgentSendChunk]s (optionally with one [AgentSendSessionRefreshed] before
  /// the retried attempt's chunks); then exactly one of [AgentSendCompleted] or
  /// [AgentSendFailed].
  ///
  /// Pass a [cancelToken] to abort an in-flight turn: when it signals, the
  /// active `query` is interrupted (`agentSdk.cancelVce`), which closes its
  /// stream so the loop unwinds, and `send` then ends **silently** — no
  /// terminal [AgentSendCompleted] or [AgentSendFailed] is emitted, because a
  /// user-driven stop is neither a completion nor a failure. Relying on the
  /// token (rather than cancelling the returned subscription) is deliberate:
  /// cancelling an `async*` subscription parked on a stalled inner stream does
  /// not resolve promptly, whereas [AgentQuery.interrupt] closes the query
  /// stream eagerly.
  Stream<AgentSendEvent> send(
    String prompt, {
    CancellationToken cancelToken = CancellationToken.none,
  }) async* {
    yield const AgentSendStarted();

    String? resumeId = sessionStore.load();
    var retried = false;
    var emittedChunk = false;

    while (true) {
      final options = config.buildOptions(resumeSessionId: resumeId);

      SdkResultMessage? result;
      Object? caught;
      final query = client.query(prompt: prompt, options: options);
      // When cancellation is requested, interrupt the active query. That closes
      // its stream, so the `await for` below terminates and we bail out below.
      unawaited(cancelToken.whenCancelled.then((_) => query.interrupt()));
      try {
        await for (final message in query) {
          if (message is SdkAssistantMessage) {
            for (final block in message.content) {
              if (block is TextBlock && block.text.isNotEmpty) {
                emittedChunk = true;
                yield AgentSendChunk(block.text);
              }
              // ThinkingBlock / tool blocks are not part of the answer text.
            }
          } else if (message is SdkResultMessage) {
            result = message;
          }
        }
      } catch (e) {
        caught = e;
      }

      // A user-driven stop: the query was interrupted, not completed or failed.
      // End the stream without a terminal event.
      if (cancelToken.isCancelled) return;

      // The error text to classify: a thrown bridge error, or a costed error
      // result. `null` when the turn succeeded.
      final String? errorText = caught != null
          ? caught.toString()
          : (result != null && result.isError
              ? (result.result ?? 'Agent SDK reported an error result.')
              : null);

      if (errorText != null) {
        // §7.2: refresh the session id and retry once when we were resuming a
        // stored session, nothing has streamed yet (so the retry cannot
        // duplicate output), and the failure looks session-shaped.
        if (resumeId != null &&
            !retried &&
            !emittedChunk &&
            specSessionLooksLikeError(errorText)) {
          sessionStore.clear();
          resumeId = null;
          retried = true;
          yield const AgentSendSessionRefreshed();
          continue;
        }
        yield AgentSendFailed(errorText);
        return;
      }

      if (result == null) {
        yield const AgentSendFailed(
          'Agent SDK stream ended without a terminal result message.',
        );
        return;
      }

      // Success: persist the session id so the next send resumes this turn.
      final sessionId = result.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        sessionStore.save(sessionId);
      }
      yield AgentSendCompleted(sessionId);
      return;
    }
  }
}
