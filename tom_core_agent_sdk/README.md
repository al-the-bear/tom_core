# tom_core_agent_sdk

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Anthropic's Claude Agent SDK as a `tom_core_llm` provider: one transport seam
with two implementations — a running VS Code window's CLI server, and a
standalone Node server the app starts and owns — the SDK's messages translated
into run events, a liveness bound every run passes, sessions that each run in
an isolate of their own, an availability gate that says why it is shut, and an
on-demand install of the server's npm dependencies. The app hands it requests
and, for an agent run, the tools the model may call; it holds no HTTP client
and no credential store.

## Overview

- **`AgentSdkSessionProvider`** is the `LlmProvider`. Every request runs in a
  session; the run streams the events of `tom_core_llm` — the request's
  prelude, the far end's start, thinking and text as they stream, each tool
  call with its result, retries, usage and exactly one end — and the end of a
  completed run carries its `LlmCallReport`, kept by an `LlmRunAccount` from the
  run's own events. It sends a request's two channels as they are: the
  instruction (user channel) followed by the context (system channel).
  `agentToolsEnabled` is a switch read on every request: while it answers
  false the provider reports `canUseTools: false` and refuses a request that
  carries tools, before anything is sent.
- **`AgentSdkServerTransport`** is the seam, and it names nothing about VS
  Code, Node, sockets or processes: send a composed prompt, stream the run's
  events back, report failures as `LlmTransportException` with a kind, cancel
  by cancelling the subscription, and probe reachability without side effects.
  - **`HostedCliServerAiTransport`** reaches a running VS Code's CLI server: one
    scan of ports 19900–19909, an identity handshake (`workspace.getInfoVce`)
    and a local match against an optional workspace pin. Two windows with the
    same workspace answer identically, so a pin selects a workspace, not a
    window; the choice is the lowest port, and it is reported through
    `selectionNotice` rather than made silently. `discoverHostedAiWorkspaces`
    returns the same scan as `AgentSdkWorkspaceCandidate`s, so a settings
    surface can offer the identities that answer rather than ask for one to be
    typed.
  - **`StandaloneNodeAiTransport`** starts `node/agent_sdk_server.js` on a Node
    at or above a version floor (currently 20) and speaks the same wire to it.
    The floor is enforced rather than mere resolvability, because the Agent SDK
    starts the Claude Code CLI as a grandchild that inherits the interpreter:
    an older Node would probe as available and then fail with an unreadable
    child error. It tells its own `close()` from a crash, so a connect still
    waiting for the ready line reports that the transport was closed, not that
    the server exited with code -15. A server that dies before it is ready is
    reported with its last stderr lines, waited for up to `stderrDrainBound`
    (2 s), because the exit code and those lines arrive on different pipes.
- **`CliServerAiChannel`** is the wire both transports hold. Every SDK message
  goes through an `SdkTrailTranslator` into the run event it means; text and
  thinking arrive twice — as partial deltas and again in the assembled message
  — and are emitted once, from the deltas, so a trail is live. Anything that
  carries no event is liveness. A credential rejection — a `system/api_retry`
  carrying a 401, or an `authentication_failed` assistant message — fails the
  run as `remote` at once and cancels the query. The query asks for partial
  messages and adaptive, summarized thinking: without partial messages a
  thinking model is silent until it has finished, and the liveness bound would
  cap model latency instead of detecting a dead far end.
- **`boundedAiRun`** is the liveness bound, applied by the provider over
  whatever stream a transport returns, so no transport can escape it. A run
  that hears nothing — no event, no liveness — for `defaultAiStallTimeout`
  (120 s) ends as a stall, an error and a `timeout`, and its transport stream is
  cancelled. It is a **gap**, not a budget: every event resets it, so a long
  completion is never cut off. A stall leaves the availability gate open,
  because the server is up and answering. The figure is ten times the largest
  silence a long thinking completion was measured to contain; re-measure it
  with `test/stall_gap_measure_live_test.dart` whenever the SDK, the model or a
  transport changes.
- **`AgentSdkTransportSelector`** owns the availability gate. It probes the
  transports in preference order; `initialize()` never throws, because "nothing
  reachable" is the ordinary offline case. `isAvailable` is a field read, and
  `unavailableReason` is a sentence that names the remedy — no CLI server
  listening (and the command that starts one), the server not installed, no
  Node at or above the floor (and where the search looked). `notices` emits
  once per unavailability episode; the reason stays current for as long as the
  gate is shut. A selector with no transports says the AI is not configured.
  Every place this package raises `unreachable` says what to fix, and
  `test/unreachable_messages_test.dart` holds each site to it.
- **`AgentSdkServerInstaller`** installs the server's dependencies on the
  user's request; see [Installing the server](#installing-the-server).

The far end owns the Anthropic credential on both paths: the hosted path never
sees one, and the standalone path hands a given key straight into its child's
environment. Capabilities are static per transport; `canEmbed` is false.

## Installation

The package is consumed by path inside this workspace:

```yaml
dependencies:
  tom_core_agent_sdk:
    path: ../../tom_ai/core/tom_core_agent_sdk
```

Dart SDK `^3.10.8`. No Flutter dependency. It takes `tom_basics` and
`tom_vscode_scripting_api` by path.

## Features

| Type | What it does |
| ---- | ------------ |
| `AgentSdkSessionProvider` | The `LlmProvider`: runs every request in a session over the selected transport. |
| `AgentSdkServerTransport`, `AgentSdkInstallableTransport` | The transport seam; a transport whose server the user installs. |
| `HostedCliServerAiTransport`, `discoverHostedAiWorkspaces`, `AgentSdkWorkspaceCandidate` | A running VS Code's CLI server; the windows that answer a scan. |
| `StandaloneNodeAiTransport`, `agentSdkChildEnvironment` | A Node server the app starts and owns; the environment its child gets. |
| `AgentSdkCompletionRequest`, `AgentSdkToolSet`, `AgentSdkCompletionEvent` | What a transport is handed and what it streams back. |
| `CliServerAiChannel`, `agentSdkMcpToolName` | The wire both transports hold; how a relayed tool is named to the model. |
| `boundedAiRun`, `defaultAiStallTimeout` | The liveness bound. |
| `AgentSdkTransportSelector`, `AgentSdkNotice`, `AgentSdkUnavailableKind` | The availability gate and what it says. |
| `AgentSdkSessionManager`, `AgentSdkSessionHosting` | Sessions, each in an isolate of its own. |
| `AgentSdkServerInstaller`, `stageAgentSdkServer`, `verifyAgentSdkPayloadFor` | Installing the server's dependencies; staging and verifying a build's payload. |
| `probeAgentSdkModel` (`live_probe.dart`) | Whether a model answers behind a transport, for live suites. |
| `FakeAiServer`, `agentSdkFixtureScript` (`testing.dart`) | A fake CLI server and spawnable fixture servers, for suites with no model. |

## Example

```dart
import 'dart:io';

import 'package:tom_core_agent_sdk/tom_core_agent_sdk.dart';
import 'package:tom_core_llm/io.dart';

Future<void> main() async {
  const request = LlmRequest(
    prompt: WirePrompt(
      system: 'The formula engine now recalculates transitively.',
      user: 'Summarize this in five words.',
      anchorHash: '',
      roleId: 'summarize',
    ),
  );
  print(request.prompt.combined);
  // The formula engine now recalculates transitively.
  //
  // Summarize this in five words.

  final selector = AgentSdkTransportSelector([
    HostedCliServerAiTransport(), // a running VS Code
    StandaloneNodeAiTransport(
      node: llmNodeResolverFor(), // PATH, nvm, Homebrew, /usr/local
      apiKey: Platform.environment['ANTHROPIC_API_KEY'],
    ), // our own Node process
  ]);
  await selector.initialize(); // never throws
  // Every run is served from a session in its own isolate.
  final sessions = AgentSdkSessionManager();
  final provider = AgentSdkSessionProvider(
    selector: selector,
    sessions: sessions,
    toolServerName: 'tools',
  );

  if (provider.isAvailable) {
    await for (final delta in llmAnswerText(provider.run(request))) {
      stdout.write(delta);
    }
  } else {
    // The ordinary offline case: the app stays usable, AI gated off.
    print('AI unavailable');
  }
  await sessions.dispose();
  await selector.dispose();
}
```

The compiled form is [`example/readme_example.dart`](example/readme_example.dart),
and `test/readme_example_test.dart` asserts what it prints.

## Sessions

`AgentSdkSessionProvider` runs every request in a session, and every session
in an isolate of its own, through an `AgentSdkSessionManager` the application
builds once and disposes before the transport selector. The isolate holds the
transport's connection, the request loop and the liveness bound, and is kept
between runs; two sessions run at once, and a death, a hang or a cancel in one
leaves the other running.

- **What crosses.** A transport cannot be sent to an isolate, so each answers
  `sessionCopy`: a function over primitives that builds a copy of it there. The
  hosted copy reuses the port the selector found; the standalone copy starts
  its own Node child, because the server accepts one client.
- **One run per session.** A second run in a busy session throws
  `LlmSessionBusyException` at once, and is never queued.
- **Cancel.** The caller's stream ends with a cancelled run at once. A session
  that has not acknowledged within `cancelGrace` (2 s) is killed, and the next
  run spawns a new one.
- **Tool calls run in the main isolate**, through the request's
  `LlmToolBinding`, against whatever state the application owns there.
- **Logs.** `ai.run.started`, `ai.run.ended` and `ai.session.failed`, none
  carrying text.

`AgentSdkSessionHosting.inProcess` runs the same worker in the main isolate,
for a stand-in whose state a copy in another isolate could not share.

## Tools

When a request carries a `toolBinding`, the provider hands the transport an
`AgentSdkToolSet` — the binding's declarations and a function that answers a
call with text — declared on the in-process MCP server the provider was given
as `toolServerName`, so the model sees `mcp__<toolServerName>__<tool>`. The
server crosses the wire as a descriptor and the far end rebuilds it (the VS
Code extension's bridge, or `node/agent_sdk_server.js`). Each call comes back
over the same connection as `agentSdk.toolCall {streamId, server, tool, args}`
and is answered from the binding; a refusal is an answer with
`isError: true`. No socket, port or pipe is added.

Such a query has the SDK's own tools off, `allowedTools` exactly the relayed
tools, `strictMcpConfig` so no MCP server from the far end's settings is
reachable, and `maxTurns: agentRunMaxTurns` (24) instead of a plain
completion's 1. A provider whose transport reports `canUseTools: false` and is
handed a binding anyway refuses it before anything is sent.

## Installing the server

The standalone transport runs a small Node.js server,
`node/agent_sdk_server.js`, this package's own code under BSD-3-Clause. It
runs on **Anthropic's Claude Agent SDK** (`@anthropic-ai/claude-agent-sdk`),
which is **proprietary software** (© Anthropic PBC, usable under Anthropic's
terms, <https://code.claude.com/docs/en/legal-and-compliance>), so an
application built on this package does not ship it. A build carries only the
server's three source files (`agent_sdk_server.js`, `package.json`,
`package-lock.json`) in `<app-executable-dir>/ai/` and **no `node_modules`**,
and the user installs the SDK from the app when they decide to use AI.

**What an install does.** When AI is unavailable because the server is not
installed, the transport's kind is `notInstalled` and the application offers
an install. `AgentSdkServerInstaller`:

1. checks that Node.js **20 or newer** is available — the same search and the
   same check the gate uses, so without one no install is offered;
2. reads the shipped `package-lock.json` and checks that the locked SDK version
   ships a Claude Code CLI for that Node's platform (`darwin-arm64`,
   `win32-x64`, …) — on Windows on ARM with an SDK that has no `win32-arm64`
   build, it refuses and says to use the x64 Node.js;
3. runs `npm ci --omit=dev` with that Node's own npm into a staging folder
   beside `<app-data>/ai/`, downloading the SDK, its native CLI for the
   platform (~220 MB) and their dependencies;
4. checks the installed tree (the SDK's entry point and peers, the CLI binary
   and its executable bit) and only then moves it to `<app-data>/ai/`. A
   failed install leaves the previous state untouched and reports npm's last
   lines.

When an application update moves the locked SDK version, the install reports
as outdated and installing again updates it. Removing it is deleting
`<app-data>/ai/`.

**Which Node.js.** The transport never spawns the bare name `node`: an app
started from a launcher has a minimal `PATH`. It runs `tom_core_llm`'s Node
search (`llmDiscoverNode`) — every `PATH` entry, then nvm's versions newest
first, then Homebrew and `/usr/local` — and takes the first at or above the
floor by version. A path the user sets (`llmNodeAt`) replaces the search.

**From a terminal:**

```bash
dart run tom_core_agent_sdk:install_agent_sdk_server --app-data <dir> [--node <node>]
```

**Developers** can skip all of it: `npm ci --omit=dev` in this package's
`node/`, then point `AGENT_SDK_SERVER_SCRIPT` at `node/agent_sdk_server.js`, or
run from a checkout, where the transport finds the script itself.

**A key handed to the standalone transport is the only credential its server
can use.** With `apiKey` given, the child starts without any of the app's
`ANTHROPIC_*` or `CLAUDE*` variables and with `CLAUDE_CONFIG_DIR` pointing at
an empty directory of its own, so the machine's Claude Code login cannot
answer in place of the key. With no key the child inherits the app's
environment, and the ambient login answers. `scrubbedVariables` names any
further variable of the app's own — a session token it was launched with —
that the child, a tool-running process, must not inherit.

## Live suites

`package:tom_core_agent_sdk/live_probe.dart` (`probeAgentSdkModel`) runs one
tiny completion with a 30 s bound before a live suite spends minutes on real
ones: a model answering runs the suite, a transport that connects with no model
behind it **skips** it with a sentence naming the credential, and an
unreachable transport **fails**.

- `AGENT_SDK_LIVE_HOSTED=1`, with VS Code running **and its CLI server
  started** (the "Start CLI Server" command, `tomAi.cliServer.start`; its
  autostart is off by default). `AGENT_SDK_LIVE_WORKSPACE` optionally pins the
  identity the server reports.
- `AGENT_SDK_LIVE=1`, with the server installed (`npm ci` in `node/`). No
  `ANTHROPIC_API_KEY` is required: the SDK falls back to the ambient Claude
  Code login.
- `AGENT_SDK_RECORD=1` beside either re-records
  `test/fixtures/sdk_messages/<transport>_agent_run.json` through
  `test/event_stream_live_test.dart`. `tool/write_trail_replay.dart` turns a
  recording into the run events a UI test's stand-in transport replays.
- `AGENT_SDK_LIVE_MEASURE=1` runs the stall-gap measurement (~170k input
  tokens per transport).

## Deadlines in tests that spawn a child

A test that starts a server child is bounded twice: by the transport's
`startupTimeout` and by the harness. The harness timer starts earlier — it
covers `setUp`, the fixture server's own bind and the `node --version` runs
before the child is spawned — so equal bounds mean the harness always wins,
abandoning the body mid-connect with a live child. The rule is
`harness >= 2 × startup`: a spawning test declares a library-level `@Timeout`
of at least twice `spawnStartupTimeout` (30 s), exported with the other
deadlines from `testing.dart`.

## Limits

- **Two transports, one model family.** Both reach Anthropic models through the
  Agent SDK; a provider for another API is a different `LlmProvider`.
- **No embeddings.** `canEmbed` is false on both transports.
- **Closing a channel waits at most two seconds** (`CliServerAiChannel.closeBound`):
  a socket's close completes in the zone it was last written in, which may never
  run again, and the standalone transport kills its child only after the channel
  closes.

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_core_llm` | runtime | the provider contract, the run events, the run account, sessions and the Node search |
| `tom_vscode_scripting_api` | runtime | the CLI-server wire, the port scan and the Agent SDK message mirror |
| `tom_basics` | runtime | the diagnostics port the session manager logs through |
| `meta` | runtime | `@visibleForTesting` |
| `test`, `lints` | dev | the suite |
| `@anthropic-ai/claude-agent-sdk` | npm, installed by the user | the server's runtime (proprietary, not shipped) |

## Status

Version **0.1.0**. `dart test` runs the offline suite — the transport contract
over a fake CLI server and spawned stand-in servers, the translator over real
recordings of both transports, the liveness bound, sessions in isolates,
degradation and the availability gate's sentences, the install and payload
checks, and the example — and the live suites run behind the variables above.
