# Tom Core Agentic API Reference: LLM Module

The symbol-level mirror of `lib/src/llm/`: twenty exported types across nine
libraries, one top-level function, and two public statics.

[`doc/llm.md`](../llm.md) explains the seam — the invariants, the control
inversion, why the retry is bounded the way it is. This document is arranged
for lookup: one heading per symbol, grouped by the concern it belongs to.

## Table of Contents

- [Overview](#overview)
- [The contract](#the-contract)
  - [LlmProvider](#llmprovider)
  - [WirePrompt](#wireprompt)
  - [LlmOptions](#llmoptions)
  - [ToolCatalogue](#toolcatalogue)
  - [ToolDescriptor](#tooldescriptor)
  - [LlmCallReport](#llmcallreport)
  - [CapturedWirePrompt](#capturedwireprompt)
- [The stream events](#the-stream-events)
  - [LlmStreamEvent](#llmstreamevent)
  - [LlmStreamStarted](#llmstreamstarted)
  - [LlmStreamChunk](#llmstreamchunk)
  - [LlmStreamToolCallProposed](#llmstreamtoolcallproposed)
  - [LlmStreamCompleted](#llmstreamcompleted)
  - [LlmStreamFailed](#llmstreamfailed)
  - [LlmFailure](#llmfailure)
- [The Agent SDK provider](#the-agent-sdk-provider)
  - [AgentSdkLlmProvider](#agentsdkllmprovider)
  - [agentSdkLooksLikeSessionError](#agentsdklookslikesessionerror)
- [Session strategies](#session-strategies)
  - [AgentSdkSessionStrategy](#agentsdksessionstrategy)
  - [NoSessionStrategy](#nosessionstrategy)
  - [BrainSessionStrategy](#brainsessionstrategy)
  - [AgentSdkSessionStore](#agentsdksessionstore)
  - [QuestSessionStrategy](#questsessionstrategy)

## Overview

Source: `lib/src/llm/`, barrelled by `llm.dart`.

Three layers, and the grouping below follows them:

- **The contract** — `LlmProvider`, and the value types that cross it. These
  import nothing outside the folder, so a second provider can be written
  against the seam without taking the Agent SDK with it.
- **The stream events** — a sealed family a consumer switches on exhaustively.
- **The Agent SDK provider** — the package's one shipped implementation, plus
  the three session strategies it consults per call.

## The contract

### LlmProvider

`abstract class`. One backend a caller can route to. `String get id` keys it in
a caller's provider map and is stamped on every report;
`Future<LlmCallReport> complete(WirePrompt, LlmOptions)` and
`Stream<LlmStreamEvent> completeStream(WirePrompt, LlmOptions)` are both
first-class — neither is defined in terms of the other.

Three obligations bind every implementation: stamp the prompt's `anchorHash`
onto the report, never mutate the prompt body, and fill the provenance fields
(`providerId` equal to `id`, the resolved `modelId`, the body's `promptHash`).
An abstract class rather than a typedef so the analyzer enforces method-set
completeness.

### WirePrompt

`final class`. The post-assembly, post-anchor prompt. `system` is the standing
framing and **begins with the anchor block**; `user` is the call-specific
content and defaults to empty; `combined` joins them with a blank line, dropping
empty parts — and because `system` leads, `combined` begins with the anchor too.
A backend with no channel separation *sends* `combined`; one with channels routes
`system` and `user` instead. Every provider *hashes* `combined` either way, since
`promptHash` is its content hash, so the join belongs to the hash contract.
`anchorHash` is the anchor block's content hash; `roleId` and `templateSha` are
carried for observability and never branched on.

`final` because every provider must consume the same shape, and a subtype would
invite per-provider variants that bypass the anchor guarantee.

### LlmOptions

`final class`. The per-call knobs: `model` (overriding the route default),
`temperature`, `maxOutputTokens`, `stopSequences`, `toolCatalogue`,
`responseFormat`, and `brainSessionId`. `copyWith` produces a variant.

`LlmOptions.empty` is the all-defaults instance. `stopSequences` is
non-nullable with an empty-list default, so passing `null` cannot defeat it.
`brainSessionId` is ignored by every provider except the Agent SDK one in
`brain` session mode.

### ToolCatalogue

`final class`. The tools a role may invoke: a `tools` list with `isEmpty` /
`isNotEmpty`. `ToolCatalogue.empty` is the no-tools instance, and an empty
catalogue means no tool call is permitted.

### ToolDescriptor

`final class`. One proposable tool: `name`, `description`, and a
`parametersSchema` map.

### LlmCallReport

`final class`. The provenance record a completed call produces:
`providerId`, `modelId`, `anchorHash`, `promptHash`, `tokensIn`, `tokensOut`,
`retries`, `wallClockMs`, `cost`, `templateSha` and `notes`.

Three of those carry a rule rather than a value. `retries` counts in-call
retries before this report, so a retried call cannot present as a first-shot
success. `wallClockMs` is measured from submission and **includes** the retry
waits. `cost` is `null` when no price is known for the route — never silently
zero.

### CapturedWirePrompt

`final class`. A data-only mirror of the wire body for a trail writer: `body`,
`anchorHash`, `roleId`, `templateSha`. It exists because `WirePrompt` is
provider-facing and a consumer must not be able to construct one and bypass
assembly.

## The stream events

### LlmStreamEvent

`sealed class`. One step of a streamed completion. Sealed so a consumer
switches exhaustively over the five below.

### LlmStreamStarted

`final class`. Emitted once, first, carrying `callId`, `providerId` and
`modelId` — which must match the terminal report's, because consumers log the
route from this event long before a report exists.

### LlmStreamChunk

`final class`. One chunk of streamed text: `callId` and `text`. Granularity is
the provider's; chunks arrive in order.

### LlmStreamToolCallProposed

`final class`. A proposed tool call: `toolCallId`, `toolName` and `arguments`.
The stream pauses while the caller's adapter resolves it. The Agent SDK
provider never emits this — its tool loop runs inside Claude Code.

### LlmStreamCompleted

`final class`. Successful completion, carrying the terminal `report` and an
optional `wire` (the `CapturedWirePrompt` a trail writer records).

### LlmStreamFailed

`final class`. Terminal failure, carrying both the typed `failure` and the
`report` the call had accumulated — so a failed call is still attributable.

### LlmFailure

`final class`. The failure envelope: a `classCode`, a `message` and an optional
`cause`.

## The Agent SDK provider

### AgentSdkLlmProvider

`final class`. The Anthropic Agent SDK as an `LlmProvider`.

Constructed with `id`, `defaultModel`, an optional `maxTurns`, a
`permissionMode`, a `clientFactory` over the bridge port, an optional
`clientDisposer` and a `sessionStrategy`. The factory is **memoised** on first
use, so the asynchronous bridge connect is deferred to the first call and
shared by every later one; `rebindBridgePort(newPort)` drops that memo, which
is how a caller follows a bridge that moved.

`complete` and `completeStream` implement the contract. The stream translation:
one `LlmStreamStarted`; each assistant message's text blocks become chunks,
with thinking blocks dropped from the answer text though their tokens still
count; the terminal result becomes `LlmStreamCompleted` with tokens, cost and
wall-clock read off it; any SDK failure becomes `LlmStreamFailed`.

**One retry, under four conditions together**: the call was resuming a stored
session, it has not already retried, nothing has streamed yet, and the message
looks session-shaped by `agentSdkLooksLikeSessionError`. Each retry increments
`retries`, and the stopwatch runs across it.

Two failure classes: a thrown or costed backend error is `unknown`, because the
provider does not classify what it cannot see; a stream ending with no terminal
result is `format`, the one failure it can name itself.

### agentSdkLooksLikeSessionError

```dart
bool agentSdkLooksLikeSessionError(String message)
```

The conservative session-error rule: the message must contain `session` **and**
one of `not found`, `invalid`, `no such`, `unknown`, `expired` or
`does not exist`. The second cue is what separates it from the editor's broader
matcher in the `agent` unit — this side would rather not discard a working
session on a message that merely mentions one.

## Session strategies

### AgentSdkSessionStrategy

`abstract interface class`. The per-call decision, in three methods:
`resumeIdFor(options)` answers the session id to resume or `null` for a fresh
one; `record(options, claudeSessionId)` stores what a successful call produced;
`evict(options)` forgets a stored id after a session-shaped failure.

**No method may throw because the session state is damaged** — write included.
The provider awaits `record` on the success path immediately before the terminal
event, so a strategy that threw there would destroy the result of a call that
has already been billed. A degraded store costs at most one fresh call.

### NoSessionStrategy

`final class`. Mode `none`: every call is a first call. Resolves no id, records
and evicts nothing. `const`-constructible.

### BrainSessionStrategy

`final class`. Mode `brain`: reads and writes the Claude session id through an
`AgentSdkSessionStore`, keyed by `LlmOptions.brainSessionId`. The only strategy
that writes.

### AgentSdkSessionStore

`final class`. The JSON-backed `session id → Claude-Code session id` map behind
`BrainSessionStrategy`: `lookup(brainSessionId)`, `put(brainSessionId,
claudeSessionId)` and `remove(brainSessionId)` over a `File`, with the contents
cached after first read.

### QuestSessionStrategy

`final class`. Mode `quest`: **read-only**. Resolves the session id from the VS
Code window's quest history file, located from `questHistoryRoot`, `questId`
and `sessionKey`. The file belongs to the editor, so nothing is ever written
to it: `record` does nothing, and `evict` remembers the id last answered as
rejected, in memory, for the strategy's lifetime. While the file still names a
rejected id `resumeIdFor` answers `null`, so a stale quest session costs one
failed resume rather than one per call; a file rewritten with a new id is
resumed again.
