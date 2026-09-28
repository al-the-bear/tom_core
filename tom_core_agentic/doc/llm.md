# LLM Module

The provider seam: the interface every LLM backend implements, the value types
that cross it, and the Anthropic Agent SDK provider that is the package's one
shipped implementation.

The seam exists to keep two things apart that otherwise fuse. A *caller*
assembles a prompt, decides which route serves it, and records what came back;
a *provider* translates one assembled prompt into one backend's wire shape and
reports what happened. Everything a caller needs to attribute a call — which
route, which anchor, which template, what it cost — travels back as data rather
than as a side effect, which is what makes an audit trail possible at all.

> **Looking for a signature?** This page explains the seam.
> [`doc/api/api_summary_llm.md`](api/api_summary_llm.md) is the symbol-level
> mirror: all twenty exported types with a section each, the one top-level
> function, and both public statics. `test/api_summary_test.dart` derives the
> required set from the barrel, so it cannot fall behind the code.

> **Want to run it?** [`example/llm/llm_example.dart`](../example/llm/llm_example.dart)
> is a complete `LlmProvider` in about sixty lines, driven through both entry
> points. It asserts the three invariants an implementer most easily breaks —
> the anchor stamp, the unmodified body, and one route announced once — and
> shows the two shapes a single failure takes depending on which entry point
> raised it. No network and no key: the provider echoes, because the seam is
> what is being demonstrated.

## Table of Contents

- [Overview](#overview)
- [The provider contract](#the-provider-contract)
  - [Two entry points, neither derived from the other](#two-entry-points-neither-derived-from-the-other)
- [The value types](#the-value-types)
  - [`WirePrompt` — two channels, anchor first](#wireprompt--two-channels-anchor-first)
  - [`LlmOptions` — the per-call knobs](#llmoptions--the-per-call-knobs)
  - [`LlmCallReport` — what a call is attributed by](#llmcallreport--what-a-call-is-attributed-by)
  - [`CapturedWirePrompt` — the trail's view](#capturedwireprompt--the-trails-view)
  - [The stream events](#the-stream-events)
- [`AgentSdkLlmProvider`](#agentsdkllmprovider)
  - [The control inversion](#the-control-inversion)
  - [Stream translation](#stream-translation)
  - [The anchor, through a backend with no channels](#the-anchor-through-a-backend-with-no-channels)
  - [One retry, and the four conditions on it](#one-retry-and-the-four-conditions-on-it)
  - [Failure classification](#failure-classification)
  - [The bridge client](#the-bridge-client)
- [Session strategies](#session-strategies)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `LlmProvider` | abstract class | The contract every backend implements: `complete` and `completeStream` |
| `WirePrompt` | final class | The post-assembly, post-anchor prompt a provider sees |
| `LlmOptions` | final class | Per-call knobs: model, sampling, stop sequences, tools, response format |
| `LlmCallReport` | final class | The provenance record a completed call produces |
| `CapturedWirePrompt` | final class | A data-only mirror of the wire body, for a trail writer |
| `ToolCatalogue` | final class | The tools a role offers on one call; empty is how a role says "none" |
| `ToolDescriptor` | final class | One tool's name, description and JSON-schema parameters |
| `LlmStreamEvent` | sealed class | One step of a streamed completion |
| `LlmStreamStarted` | final class | Opens a stream, announcing the route the terminal report must match |
| `LlmStreamChunk` | final class | One piece of answer text, in order |
| `LlmStreamToolCallProposed` | final class | A tool the backend wants called — never emitted by the Agent SDK provider, which runs its tools internally |
| `LlmStreamCompleted` | final class | Closes a stream successfully, carrying the report |
| `LlmStreamFailed` | final class | Closes a stream on failure, still carrying an attributable report |
| `LlmFailure` | final class | The classified failure carried by a failed stream |
| `AgentSdkLlmProvider` | final class | The Anthropic Agent SDK as a provider |
| `AgentSdkSessionStrategy` | abstract interface class | Per-call decision: resume a Claude session, or start fresh |
| `NoSessionStrategy` | final class | Mode `none`: every call starts fresh |
| `BrainSessionStrategy` | final class | Mode `brain`: resumes from a store it also evicts from |
| `AgentSdkSessionStore` | final class | The session ids `BrainSessionStrategy` persists and caches |
| `QuestSessionStrategy` | final class | Mode `quest`: resumes the id recorded in a quest's history file, read-only |

## The provider contract

`LlmProvider` is an abstract class rather than a typedef so the analyzer
enforces method-set completeness on implementers, and so a
`Map<String, LlmProvider>` keyed by `id` stays type-precise.

Two rules bind every implementation, and both exist to keep the audit trail
honest:

- **The anchor stamp.** Every report must carry the prompt's `anchorHash`
  unchanged. A conformance test can then prove, from reports alone, that every
  emitted prompt carried the assistant-dedication anchor. A provider that drops
  the hash is a defect, not a variation.
- **No prompt mutation.** A provider must not prepend, append or reorder the
  body it receives. The producer has already wrapped the body with the anchor;
  mutation here would corrupt the anchor block or inject text the trail cannot
  attribute. Translating `WirePrompt` into a backend's wire shape is the
  provider's job — changing the body is not.

Provenance is the third obligation and is spelled out per field: the report's
`providerId` must equal the provider's own `id`, `modelId` the resolved model,
and `promptHash` the content hash of the prompt body.

### Two entry points, neither derived from the other

`complete` runs to completion and returns one report. `completeStream` streams.
Both are first-class: a provider implements each directly rather than defining
one in terms of the other.

A streamed call has a fixed shape:

1. exactly one `LlmStreamStarted`;
2. zero or more `LlmStreamChunk`s, in order;
3. zero or more `LlmStreamToolCallProposed` events, possibly interleaved;
4. exactly one terminal event — `LlmStreamCompleted` or `LlmStreamFailed`.

**A non-streaming backend still implements `completeStream`**, by buffering its
response and emitting it as a single chunk followed by the terminal event. A
caller never has to ask whether its route streams.

The opening event must announce the *same* `providerId` and `modelId` as the
terminal report. Consumers log the route from the first event, long before a
report exists, and a stream that opens on one route and completes on another
makes the two disagree.

## The value types

### `WirePrompt` — two channels, anchor first

A `WirePrompt` is the *result* of assembly, not an input to it: the producer
has already composed the role framing and prepended the anchor. It carries the
body as two parts so a provider can route each to its native channel:

- `system` — the standing framing, **beginning with the anchor block**: the
  dedication anchor, the role persona and objective, the structured-output
  declaration. A provider routes this to a top-level `system` field or a
  `system`-role message.
- `user` — the call-specific content, empty for system-only roles.

`combined` joins them with a blank line, dropping empty parts. It has two
consumers and only the first is a provider's choice. A backend with no channel
separation *sends* it — the Agent SDK, since its `query` takes one string —
while a backend that has channels routes `system` and `user` and never sends
it. That choice is the whole of a provider's native-channel mapping; there is
no third shape to migrate to. But **every** provider *hashes* it: `promptHash`
is the content hash of `combined` whether or not the provider puts it on the
wire, which is what makes one prompt fingerprint the same across two routes
that deliver its halves differently.

So the join is part of the hash contract rather than a formatting detail.
Change the separator, the order, or the rule that drops an empty part, and
every prompt hashes differently from the way it was already recorded; the three
branches are held by `test/llm_value_types_test.dart`. Because `system` leads
and begins with the anchor, `combined` begins with the anchor too, so the
guarantee survives the join.

`anchorHash` is the content hash of the anchor block. `roleId` and
`templateSha` are carried for observability only: providers never branch on
them, and a `null` `templateSha` stays `null` in the report rather than being
zeroed or turned into `"unknown"`.

The class is `final`. Every provider must consume the same shape, and a subtype
would invite per-provider variants that bypass the anchor guarantee.

### `LlmOptions` — the per-call knobs

`model` overrides the route default when non-null; the resolved id is stamped
on the report either way. `temperature`, `maxOutputTokens`, `stopSequences`,
`toolCatalogue` and `responseFormat` are the generation controls —
`stopSequences` is non-nullable with an empty-list default, so a caller cannot
defeat the default by passing `null`.

`brainSessionId` is the odd one out: every HTTP and stub provider **ignores**
it. It exists so the Agent SDK provider, in `brain` session mode, can key its
persisted Claude session id by the caller's session.

### `LlmCallReport` — what a call is attributed by

`providerId` and `modelId` name the route; `anchorHash` proves the anchor;
`promptHash` correlates prompts across runs without storing bodies; `tokensIn`
and `tokensOut` are the provider's usage figures, or zero when it returns none;
`retries` counts in-call retries before this report; `wallClockMs` is the total
from submission, **including** retry waits; `cost` is `null` when no price is
known, never silently zero; `templateSha` and `notes` carry through from the
prompt and the provider.

`retries` and `wallClockMs` are worth reading together: the point of both is
that a retried call does not present as a first-shot success with a short clock.

### `CapturedWirePrompt` — the trail's view

A trail writer needs the full wire body, but `WirePrompt` is a provider-facing
type a consumer must not construct. So the body crosses as this data-only
mirror: `body`, `anchorHash`, `roleId`, `templateSha`, and nothing that would
let a consumer assemble a wire and bypass the producer.

### The stream events

`LlmStreamEvent` is sealed, so a consumer can switch exhaustively:
`LlmStreamStarted`, `LlmStreamChunk`, `LlmStreamToolCallProposed`,
`LlmStreamCompleted` and `LlmStreamFailed`. A failed stream carries an
`LlmFailure` with a `classCode`, a message and an optional cause, plus the
report the call had accumulated.

## `AgentSdkLlmProvider`

### The control inversion

In the ordinary model the caller owns the loop: it asks for one completion,
then drives tools, recall and re-entry itself. The Agent SDK inverts that —
Claude Code owns the tool loop, the MCP loop and its own memory. The provider
hands it a prompt; it runs its own agentic loop and streams back assistant text
plus a terminal result.

That inversion is invisible at the seam. From the caller's side the Agent SDK
is one very capable black-box completion, so this provider implements
`LlmProvider` unchanged. What it costs is a dependency on
`tom_vscode_scripting_api` and a live VS Code bridge, which is why the provider
lives here and not beside the HTTP ones.

### Stream translation

- one `LlmStreamStarted` first;
- each assistant message's text blocks become `LlmStreamChunk`s. **Thinking
  blocks are dropped** from the answer text — they are not part of the reply —
  but their token cost still counts, because the terminal usage figures already
  include them;
- the terminal result becomes `LlmStreamCompleted` with a report whose tokens,
  cost and wall-clock come off the result message. Cost is the SDK's own
  `total_cost_usd`, never a price table, which has no Claude entries;
- any SDK failure becomes `LlmStreamFailed`.

**`LlmStreamToolCallProposed` is never emitted.** Tool and MCP calls run
*inside* Claude Code, so the caller never sees them and there is nothing to
propose. That is a property of this provider, not a gap in it.

### The anchor, through a backend with no channels

The Agent SDK's `query` takes one string, so the provider sends
`wire.combined` unmodified and stamps `report.anchorHash = wire.anchorHash`,
exactly as a channel-aware provider would. Claude Code's own system prompt is
additive context, never a replacement for the anchor, so the SDK's
`systemPrompt` option is left at its append default and is never set to
override.

### One retry, and the four conditions on it

A resumed Claude session can be gone by the time the next call uses it. The
provider evicts the stored id and retries once — and only when all four of
these hold:

1. the call was resuming a stored session;
2. it has not already retried;
3. nothing has streamed yet, so the retry cannot duplicate output;
4. the failure message looks session-shaped.

The fourth test is `agentSdkLooksLikeSessionError`, and it is **conservative**:
the message must contain `session` *and* one of `not found`, `invalid`,
`no such`, `unknown`, `expired` or `does not exist`. Requiring a second cue is
what separates it from the editor's broader matcher in the `agent` unit — the
brain would rather not discard a working session on a message that merely
mentions one.

Each retry increments the report's `retries`, and the stopwatch keeps running
across it, so the report shows both that a retry happened and how long the
whole call took.

### Failure classification

Two shapes reach `LlmStreamFailed` with different `classCode`s: a thrown or
costed backend error is `unknown` — the provider does not pretend to classify
what it cannot see, and the caller maps it onto its own taxonomy — while a
stream that ends with no terminal result message is `format`, which is the one
failure the provider can name from where it stands.

### The bridge client

`clientFactory` is memoised on first use, so the asynchronous bridge connect is
deferred to the first call and shared by every later one.
`rebindBridgePort(newPort)` drops that memo, which is how a caller follows a
bridge that moved. Tests inject a factory over a fake transport.

## Session strategies

Claude Code owns its conversation memory, keyed by a session id. Whether a call
continues a prior conversation or starts fresh is the *only* thing that differs
between the three modes, so it sits behind one seam —
`AgentSdkSessionStrategy` — that the provider consults per call. The provider
never branches on the mode: it asks for a resume id, streams, and reports the
outcome back.

| Mode | Strategy | Resume id comes from | Writes |
| ---- | -------- | -------------------- | ------ |
| `none` | `NoSessionStrategy` | nothing — every call is a first call | no |
| `brain` | `BrainSessionStrategy` | a JSON store keyed by `LlmOptions.brainSessionId` | yes |
| `quest` | `QuestSessionStrategy` | the VS Code window's quest history file | no |

**No method may throw because the session state is damaged** — and that rule
covers the write, not just the read. `resumeIdFor` answers `null` for state it
cannot read; `record` and `evict` return normally for state they cannot write.
The provider awaits `record` on the success path, immediately before the
terminal event, so a strategy that threw there would not merely fail to persist
a session id: it would destroy the result of a call that has already been
billed. A degraded store costs at most one fresh call.

## Core Components

- **`llm_provider.dart`** — the contract and its three invariants.
- **`wire_prompt.dart`** / **`captured_wire.dart`** — the prompt a provider
  sees, and the mirror a trail writer keeps.
- **`llm_options.dart`** / **`llm_call_report.dart`** — what goes in per call,
  and what comes back to be attributed.
- **`llm_stream_event.dart`** — the sealed event family and `LlmFailure`.
- **`agent_sdk_llm_provider.dart`** — the Agent SDK provider.
- **`agent_sdk_session.dart`** — the three session strategies and the
  conservative session-error matcher.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `agent_sdk_llm_provider.dart` | The `Stream` the provider returns and the `Future`s it awaits. `dart:core` re-exports both, so the import is a statement of which library declares them rather than a requirement |
| `dart:convert` | dart | `agent_sdk_session.dart` | JSON, for the session cache file and the quest history file the strategies read |
| `dart:io` | dart | `agent_sdk_session.dart` | The `brain` and `quest` strategies read and write those files |
| `tom_vscode_scripting_api` | package | `agent_sdk_llm_provider.dart` | The Agent SDK client the provider streams through, and the VS Code bridge under it |
| `prompt_sha256.dart` | module | `agent_sdk_llm_provider.dart` | `promptSha256`, the `sha256:<hex>` fingerprint every report is stamped with |

The contract and the value types depend on neither: `llm_provider.dart`,
`wire_prompt.dart`, `llm_options.dart`, `llm_call_report.dart` and
`captured_wire.dart` import nothing outside this folder, so a second provider
can be written against the seam without taking the Agent SDK with it.
