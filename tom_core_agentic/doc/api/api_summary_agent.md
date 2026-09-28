# Tom Core Agentic API Reference: Agent Module

The symbol-level mirror of `lib/src/agent/`: 52 exported types, 13 top-level
functions, 4 constants and 3 public statics, each with a section.

[`doc/agent.md`](../agent.md) explains how the unit behaves — the degradation
rule, the bridge protocol, the back-off, the retry conditions. This document is
arranged for lookup instead: one heading per symbol, grouped by the concern the
symbol belongs to.

## Table of Contents

- [Overview](#overview)
- [The models](#the-models)
  - [AgentProfile](#agentprofile)
  - [ToolApprovalMode](#toolapprovalmode)
  - [AgentSettings](#agentsettings)
  - [ChatRole](#chatrole)
  - [ChatMessage](#chatmessage)
  - [TrailPair](#trailpair)
  - [ChatVariable](#chatvariable)
  - [QueuedPrompt](#queuedprompt)
  - [QueuedPrePrompt](#queuedpreprompt)
  - [QueuedFollowUpPrompt](#queuedfollowupprompt)
  - [QueuedPromptStatus](#queuedpromptstatus)
  - [QueuedPrePromptStatus](#queuedprepromptstatus)
  - [QueuedPromptType](#queuedprompttype)
  - [QueuedTransport](#queuedtransport)
  - [PromptTemplate](#prompttemplate)
  - [QueueTemplate](#queuetemplate)
  - [ReminderTemplate](#remindertemplate)
  - [TimedRequest](#timedrequest)
  - [ScheduleMode](#schedulemode)
  - [TimedRequestStatus](#timedrequeststatus)
  - [ScheduledTime](#scheduledtime)
- [The stores](#the-stores)
  - [AgentProfileStore](#agentprofilestore)
  - [AgentSettingsStore](#agentsettingsstore)
  - [ChatVariableStore](#chatvariablestore)
  - [PromptQueueStore](#promptqueuestore)
  - [PromptTemplateStore](#prompttemplatestore)
  - [QueueTemplateStore](#queuetemplatestore)
  - [TimedRequestStore](#timedrequeststore)
  - [PromptTrailStore](#prompttrailstore)
  - [ReminderTemplateStore](#remindertemplatestore)
  - [SpecSessionStore](#specsessionstore)
  - [BridgeChoiceStore](#bridgechoicestore)
- [The YAML plumbing](#the-yaml-plumbing)
  - [readAgentYamlFile](#readagentyamlfile)
  - [decodeAgentYamlList](#decodeagentyamllist)
  - [decodeAgentYamlValue](#decodeagentyamlvalue)
  - [decodeAgentYamlEntries](#decodeagentyamlentries)
  - [encodeAgentYaml](#encodeagentyaml)
  - [decodeAgentYaml](#decodeagentyaml)
  - [deepPlainYaml](#deepplainyaml)
  - [yamlValue](#yamlvalue)
  - [yamlStringList](#yamlstringlist)
  - [yamlEnum](#yamlenum)
- [Bridge discovery and binding](#bridge-discovery-and-binding)
  - [BridgeServer](#bridgeserver)
  - [BridgeServerStatus](#bridgeserverstatus)
  - [BridgePortScanner](#bridgeportscanner)
  - [BridgeConnectionService](#bridgeconnectionservice)
  - [BridgeChoice](#bridgechoice)
  - [connectAgentSdkClient](#connectagentsdkclient)
  - [AgentSdkClientFactory](#agentsdkclientfactory)
- [Reconnect](#reconnect)
  - [ReconnectCoordinator](#reconnectcoordinator)
  - [ReconnectResult](#reconnectresult)
  - [ReconnectResolution](#reconnectresolution)
  - [ReconnectDelay](#reconnectdelay)
  - [composeInterruptRetry](#composeinterruptretry)
- [The send engine](#the-send-engine)
  - [AgentSendEngine](#agentsendengine)
  - [AgentSendConfig](#agentsendconfig)
  - [AgentSendEvent](#agentsendevent)
  - [AgentSendStarted](#agentsendstarted)
  - [AgentSendChunk](#agentsendchunk)
  - [AgentSendSessionRefreshed](#agentsendsessionrefreshed)
  - [AgentSendCompleted](#agentsendcompleted)
  - [AgentSendFailed](#agentsendfailed)
  - [specSessionLooksLikeError](#specsessionlookslikeerror)
- [Placeholders](#placeholders)
  - [EditorPlaceholderBindings](#editorplaceholderbindings)
  - [PlaceholderExpressionsUnsupportedError](#placeholderexpressionsunsupportederror)
- [Constants](#constants)
  - [defaultBridgeHost](#defaultbridgehost)
  - [bridgeScanMinPort](#bridgescanminport)
  - [bridgeScanMaxPort](#bridgescanmaxport)
  - [defaultReconnectBackoff](#defaultreconnectbackoff)

## Overview

Source: `lib/src/agent/`, barrelled by `agent.dart`, which re-exports 24
libraries.

Four layers, and the grouping below follows them:

- **The models** — the persisted domain objects, each with a `toYaml()` /
  `fromYaml()` pair and no behaviour beyond validation.
- **The stores** — one per model set, each resolving a YAML sidecar path and
  degrading rather than throwing on a damaged file.
- **The YAML plumbing** — the codec and the shared read-and-decode path every
  sidecar goes through.
- **The session layer** — bridge discovery and binding, the reconnect
  protocol, and the send engine.

`test/agent_api_summary_test.dart` derives the required set from the barrel and
fails on a symbol with no section here, so this document cannot fall behind the
code.

## The models

### AgentProfile

`final class`. A named persona supplying the system prompt and per-send
behaviour. Carries the `Options` overlay fields a send reads (model, turn cap,
thinking, prompt caching, tool approval) and `interruptRetryPrefix`, the text
prepended to a prompt re-sent after a reconnect. Its one public static is
`AgentProfile.defaultInterruptRetryPrefix`, the value seeded when a VS Code
profile is copied into the editor.

### ToolApprovalMode

`enum`: `always`, `never`. The approval gate for write tool calls.
`ToolApprovalMode.fromValue` reads one back from its persisted token.

### AgentSettings

`final class`. The global settings a profile overlays: the bridge target
(`bridgeHost`, `portScanStart`, `portScanEnd`), the profile selected on launch,
and the `Options` defaults that apply where a profile leaves a field unset.

### ChatRole

`enum`: `user`, `assistant`, `system`, `tool`. Who authored a message.
`ChatRole.fromValue` reads one back from its token.

### ChatMessage

`final class`. A single message in a chat exchange: its role, its text, and
when it was made.

### TrailPair

`final class`. One request/answer pair from an SDK exchange, as the trail
displays it.

### ChatVariable

`final class`. One placeholder binding, identified by `name`.
`ChatVariable.bindingsOf` turns a list of them into the `name → value` map the
placeholder resolver takes, which is the only shape a caller needs.

### QueuedPrompt

`final class`. A prompt queued for dispatch, with its optional pre-prompts,
follow-ups, transport and repeat settings. Identified by `id`.

### QueuedPrePrompt

`final class`. A prompt sent *ahead* of a queue item's main prompt. Keyed by
its `text` rather than by an id — a pre-prompt is identified by its body.

### QueuedFollowUpPrompt

`final class`. A prompt sent *after* the main prompt is answered. Keyed by
`id`. Both it and `QueuedPrePrompt` carry `answerWaitMinutes`; the field sets
otherwise differ, so neither is a subset of the other.

### QueuedPromptStatus

`enum`: `staged`, `pending`, `sending`, `sent`, `error`. The lifecycle of a
queued prompt. `QueuedPromptStatus.fromValue` reads one back.

### QueuedPrePromptStatus

`enum`: `pending`, `sent`, `error` — deliberately narrower than the main
prompt's set, because a pre-prompt is never staged or in a sending state of its
own.

### QueuedPromptType

`enum`: `normal`, `timed`, `reminder`. What kind of queued prompt this is.

### QueuedTransport

`enum`: `copilot`, `anthropic`. Which backend the item dispatches through; an
item without one follows the default.

### PromptTemplate

`final class`. A reusable prompt body, identified by `id`.

### QueueTemplate

`final class`. A named, ordered set of prompt bodies, identified by `id`.

### ReminderTemplate

`final class`. A reusable reminder body, identified by `id`.

### TimedRequest

`final class`. A timed or repeating prompt entry: its schedule, its status and
its body. `id`, `originalText` and **`scheduleMode` are required** — the mode
is not defaulted, so a caller has to say whether the entry repeats on an
interval or at fixed times rather than discovering which it got.
`intervalMinutes` and `scheduledTimes` are both nullable, because each belongs
to one mode and neither is meaningful under the other.

### ScheduleMode

`enum`: `interval`, `scheduled`. How a timed request fires.

### TimedRequestStatus

`enum`: `active`, `paused`, `completed`. The lifecycle of a timed entry.

### ScheduledTime

`final class`. One scheduled slot. A bare `time` repeats daily; adding a `date`
makes it a one-shot.

## The stores

Each is constructed with a `File`, and each carries a `resolveDefault()`
factory that honours an environment override and otherwise falls back to a
fixed name under `<cwd>/.tom/`. The paths and overrides are tabulated in
[`doc/agent.md`](../agent.md#the-sidecar-stores); `load()` never throws.

### AgentProfileStore

Loads and saves `List<AgentProfile>` under the `profiles` key, identified by
`id`.

### AgentSettingsStore

Loads and saves the singleton `AgentSettings` under the `settings` key. Being a
singleton it falls back to defaults rather than skipping, since there is
nothing to skip to.

### ChatVariableStore

Loads and saves `List<ChatVariable>` under `variables`, identified by `name` —
the one store whose identity field is not `id`.

### PromptQueueStore

Loads and saves `List<QueuedPrompt>` under `items`, identified by `id`.

### PromptTemplateStore

Loads and saves `List<PromptTemplate>` under `templates`, identified by `id`.

### QueueTemplateStore

Loads and saves `List<QueueTemplate>` under `templates`, identified by `id` —
the same key as the prompt templates, in a different file.

### TimedRequestStore

Loads and saves `List<TimedRequest>` under `requests`, identified by `id`.

### PromptTrailStore

Loads and saves `List<TrailPair>` under `pairs`, identified by `id`.

### ReminderTemplateStore

Loads and saves `List<ReminderTemplate>` under `templates`, identified by `id`.
The store that makes `QueuedPrompt.reminderTemplateId` and
`TimedRequest.reminderTemplateId` resolvable — both of those models are
themselves persisted, so without it a restored queue named a body nothing could
find.

### SpecSessionStore

The per-specification SDK session id. The one sidecar holding a bare scalar
(`sessionId`) rather than a model, so it reads the shared file loader directly.
`load()` answers `null` for an absent or empty id as well as for a damaged
file; `save` persists; `clear` forgets, which is what a session error triggers.

### BridgeChoiceStore

The persisted binding. `load()` answers `null` when the file cannot supply one,
`save` writes it, and `clear` removes the file — an explicit unbind.

## The YAML plumbing

### readAgentYamlFile

```dart
Map<String, dynamic>? readAgentYamlFile(File file)
```

Reads and parses one sidecar, answering `null` for missing, empty, unreadable
and malformed alike. The four collapse into one result on purpose: to a caller
about to fall back on its defaults, a file it cannot use and a file that is not
there are the same file.

### decodeAgentYamlList

```dart
List<T> decodeAgentYamlList<T>(
  Map<String, dynamic>? root, {
  required String key,
  required String identity,
  required T Function(Map<String, dynamic>) fromYaml,
})
```

Builds the models under `key`, skipping an entry that is not a mapping, whose
`identity` field is not a non-empty string, or whose `fromYaml` throws. Skips
per entry rather than failing the load, so one bad row costs one row.

### decodeAgentYamlValue

```dart
T decodeAgentYamlValue<T>(
  Map<String, dynamic>? root, {
  required String key,
  required T Function(Map<String, dynamic>) fromYaml,
  required T orElse,
})
```

The singleton counterpart. With nothing to skip *to*, an unusable value falls
back to `orElse`.

### decodeAgentYamlEntries

Builds a list of models from a raw value, with the identity requirement
optional — which is what separates a store's top-level list from a nested list
inside one entry.

### encodeAgentYaml

```dart
String encodeAgentYaml(Map<String, dynamic> data)
```

Serialises to a YAML document through `yaml_edit`: stable key order, block
style.

### decodeAgentYaml

```dart
Map<String, dynamic> decodeAgentYaml(String yaml)
```

Parses a document into a plain map. **Throws** `FormatException` when the root
is not a mapping — the one function here that throws, which is why
`readAgentYamlFile` wraps it.

### deepPlainYaml

Recursively converts a parsed `YamlMap` / `YamlList` tree into plain Dart
collections, coercing map keys to `String`, so a model's `fromYaml` never sees
a YAML view type.

### yamlValue

```dart
T? yamlValue<T>(Map<String, dynamic> yaml, String key)
```

Reads `key` when it holds a `T`, and `null` when it does not — whether absent or
present with the wrong type. Type-testing rather than casting is what stops a
hand-edited `name: 7` from throwing past a store's catch.

### yamlStringList

The list counterpart: a `List<String>` when every element is one, `null`
otherwise.

### yamlEnum

Reads an enum by its persisted token, answering `null` for a token the enum
does not define.

## Bridge discovery and binding

### BridgeServer

One responsive VS Code bridge: its `port`, its `host`, the `workspace` its
window reported through the identity handshake, and its `status`.

### BridgeServerStatus

`enum`: `available`, `bound`. How a discovered server relates to the editor
right now. Every scan result is `available`; binding is the caller's concern.

### BridgePortScanner

```dart
typedef BridgePortScanner =
    Future<Map<int, String>> Function({
      required String host,
      required int minPort,
      required int maxPort,
    });
```

The injected scan seam, so a test supplies fake bridges without opening a
socket.

### BridgeConnectionService

Scans the port range and returns the responsive servers in ascending port
order. Takes the host, the range and the scanner, all defaulted.

### BridgeChoice

The persisted binding — `host` and `port`, nothing else. `fromMap` type-tests
both fields and defaults either it cannot use. `matches(BridgeServer)` is the
comparison that matters: equal port, and a host naming the same *endpoint*,
which is weaker than the same string. Deliberately not folded into
`operator ==`, which is value equality on the record that was persisted.

### connectAgentSdkClient

```dart
Future<AgentSdkClient> connectAgentSdkClient({
  required String host,
  required int port,
})
```

The production `AgentSdkClientFactory`: opens a bridge socket and wraps it in
the bridge-backed transport. **Throws** `StateError` when the socket does not
come up, so a caller can surface a connect failure.

### AgentSdkClientFactory

```dart
typedef AgentSdkClientFactory =
    Future<AgentSdkClient> Function({required String host, required int port});
```

The transport seam. It lives in this pure-Dart layer rather than in the Flutter
controller so the UI hands down a factory (or a fake) and stays
transport-agnostic.

## Reconnect

### ReconnectCoordinator

Runs the back-off: after each delay it rescans and, the first time the bound
endpoint answers, classifies the result. Takes an injectable
`BridgeConnectionService`, the back-off list, and a `ReconnectDelay`.

### ReconnectResult

The outcome: the `resolution`, the `server` found (`null` when still gone), and
`attempts` — 1-based for a server that came back, the full schedule length when
it did not.

### ReconnectResolution

`enum`: `sameWorkspace`, `differentWorkspace`, `stillGone`.

### ReconnectDelay

```dart
typedef ReconnectDelay = Future<void> Function(Duration duration);
```

The delay seam, so a test runs the protocol instantly instead of waiting the
real schedule.

### composeInterruptRetry

```dart
String composeInterruptRetry(String prefix, String prompt)
```

Composes the auto-resend body: the prefix, a blank line, then the prompt. An
empty prefix yields the prompt unchanged, and composition never stacks —
repeated drops re-send one prefix because the *original* prompt is what is
composed each time.

## The send engine

### AgentSendEngine

Wraps one connected client, one `SpecSessionStore` and one `AgentSendConfig`.
`send(prompt, {cancelToken})` is a **cold** stream: each listen runs one query.
It retries once with a fresh session under four conditions together, and ends
**silently** on cancellation — no terminal event at all.

### AgentSendConfig

The editor-assembled inputs to one `query` `Options`, minus the session id the
engine supplies: model, system prompt (sent additively, never as an override),
permission mode, turn cap, working directory, and the MCP servers.

### AgentSendEvent

`sealed class`. One step of a send run, so a consumer can switch exhaustively.

### AgentSendStarted

Emitted once, first.

### AgentSendChunk

A streamed chunk of assistant answer text, in order. Only `TextBlock` content
becomes one — thinking and tool blocks are not answer text.

### AgentSendSessionRefreshed

Emitted when a session error caused the stored id to be dropped, immediately
before the retried attempt's chunks.

### AgentSendCompleted

Terminal success, carrying the session id of the completed turn (or `null` when
the result carried none).

### AgentSendFailed

Terminal failure: a non-session error, an error that failed one of the four
retry conditions, or a stream that ended with no result message.

### specSessionLooksLikeError

```dart
bool specSessionLooksLikeError(String message)
```

The editor's session-error rule: the text contains `session`, `message` or
`msg`, case-insensitively. Deliberately broader than the brain's matcher — the
editor would rather refresh a per-spec session id once too often than leave a
stale one wedged in place.

## Placeholders

### EditorPlaceholderBindings

Resolves the editor's supported placeholder forms — `${name}`, `{{name}}`,
`${env:NAME}` — against a fixed set of bindings, through the package's own
placeholder engine.

### PlaceholderExpressionsUnsupportedError

`final class`. Thrown when a template carries the `${{ … }}` expression form.
The refusal is a decision rather than a gap: an editor has no evaluator, and
refusing before the mustache pass is what stops an expression being quietly
rewritten into something resolvable.

## Constants

### defaultBridgeHost

`'127.0.0.1'` — the host every bridge default in the package points at, named
once so the defaults cannot diverge.

### bridgeScanMinPort

The lowest port scanned, inclusive: 19900, taken from the transport package's
own constant.

### bridgeScanMaxPort

The highest port scanned, inclusive: 19909.

### defaultReconnectBackoff

`[10 s, 30 s, 60 s]` — the default reconnect schedule.
