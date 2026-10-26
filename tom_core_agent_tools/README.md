# tom_core_agent_tools

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The tool surface an LLM agent works through: tools with declared arguments,
validated before a body runs; one registry presented to a model as native tool
declarations or through an in-process MCP server; a permission scope every
target passes in a fixed gate order; an invocation record that carries
execution consent; an append-only audit trail of every call; and
preview-then-apply runs that keep or discard an agent's work as one unit. An
application supplies its tools, its context — what a call reaches and how its
writes are rolled back — and nothing else.

## Overview

- **A tool** (`AgentTool`) is a name, a summary, an argument schema, a prose
  result, and a body. It declares whether it writes (`isWrite`) and whether it
  runs a program (`needsExecution`). The body is private: the only way to run
  a tool is `call`, which validates the arguments, records the call in the
  audit trail and runs the body with its declaration in force. A call refused
  by validation, by a gate or by its own body is recorded exactly as an
  applied one is.
- **The registry** (`AgentToolRegistry`) is what a presentation renders.
  `where` derives a narrower set and can only remove, so a set offered to a
  program — the registry less every tool that `needsExecution` — follows the
  declarations rather than a second list, and an agent → program → agent call
  graph stays bounded. An application keeps its surface closed by
  constructing its registry once and deriving every other set from it.
- **The scope and the guard** (`AgentScope`, `agentGuard`) decide every
  target of every call in one order: (1) exclusion — a target the application
  keeps out of the surface, asked before any grant; (2) the write gate; (3)
  the kind gate; (4) the id gate, through which a target being created is
  admitted by its parent; (5) allow. A refusal names the gate in the audit
  trail; an excluded target is "not found" to the caller, so the surface is
  not an existence oracle.
- **The invocation** (`AgentInvocation`) is immutable and minted per user act.
  Execution consent exists only on it, and the one factory that grants it
  takes the application's residual-risk statement (`AgentExecutionGrant`) as
  proof it was shown. Its origin is a closed set of one, `local-agent`.
- **The audit trail** (`AgentAuditLog`) is append-only, synchronous to append
  and persisted in order. An entry holds operations, ids, digests, sizes and
  reasons and has no field that could hold content, a program's source or
  output, or a credential. `AgentFileAuditLog` keeps one file per appended
  batch, filed by UTC day, over any `AgentAuditStore`; retention deletes whole
  days. An application reports its writes to the running call through
  `AgentToolContext.callZoneValues` and `AgentAuditRecording.recordMutation`,
  and a program run through `agentAuditExecution`.
- **The presentations** (`AgentToolBinding`, `AgentInProcessMcpServer`) are
  generated from the registry on every call and dispatch back into it. The
  binding is the `LlmToolBinding` of `tom_llm` a tool-capable provider
  receives per request; the MCP server is a JSON-RPC handler a caller invokes
  directly — no port, socket or pipe. A refusal is an answer the model sees;
  once a call of a run fails, every later call is refused rather than
  performed; a defect answers "the call failed" and nothing of its text.
- **Runs** (`AgentRun`, `AgentPreviewThenApply`) keep an agent's work whole.
  A run is a proposal: the calls write inside `AgentToolContext.runAtomically`
  while the model works, a refused call rolls the run back without asking,
  and the user's decision keeps it or rolls it back. The preview carries a dry
  run of the calls against `dryRunCopy`, replaying ids the run created and
  leaving program steps unsimulated. The audit entries are staged and
  committed once the run's fate is known, rolled-back ones marked so.

## Installation

The package is consumed by path inside this workspace:

```yaml
dependencies:
  tom_core_agent_tools:
    path: ../../tom_ai/core/tom_core_agent_tools
```

Dart SDK `^3.10.8`. No Flutter, no `dart:io`: it links into a browser build.

## Features

| Type | What it does |
| ---- | ------------ |
| `AgentTool`, `AgentToolSchema`, `AgentToolArgument`, `AgentToolValueType` | A declared tool and the arguments it validates. |
| `AgentToolErrorCode`, `AgentToolException` | The refusals a call can end in; an application adds codes of its own. |
| `AgentToolContext` | What a call runs against: the invocation, the audit log, the guard, and the transaction hooks an application implements. |
| `AgentToolRegistry` | A set of tools, invoked by name, narrowed by `where`. |
| `AgentScope`, `AgentScopeGate`, `AgentGuardTarget`, `agentGuard` | The scope and the five-gate guard. |
| `AgentInvocation`, `AgentExecutionGrant`, `AgentOrigin` | The invocation record and the consent it carries. |
| `AgentAuditEntry`, `AgentAuditLog`, `AgentMemoryAuditLog`, `AgentFileAuditLog`, `AgentAuditStore`, `agentFilterAudit` | The audit trail and where it is kept. |
| `AgentAuditRecording`, `agentAuditExecution`, `agentAuditResolved`, `agentAuditCallIsOneGroup`, `agentAuditEntering` | The per-call recording and what an application reports to it. |
| `AgentToolBinding`, `AgentToolResult`, `AgentInProcessMcpServer` | The presentations a provider and an MCP client see. |
| `AgentRun`, `AgentRunStep`, `AgentRunOutcome`, `AgentRunStatus` | An agent run, its steps, and its dry run. |
| `AgentPreviewThenApply`, `AgentProposalOutcome`, `AgentProposalStatus`, `AgentAtomicScope` | Preview-then-apply for any proposal. |

## Example

```dart
import 'dart:convert';

import 'package:tom_core_agent_tools/tom_core_agent_tools.dart';

/// What the tools reach: notes by id, one kept out of the agent's view.
final notes = {'n1': 'Buy milk', 'n2': 'Call Ada', 'vault': 'pin 1234'};

/// The context a call runs against: the guard, and an atomic scope.
class NotesContext extends AgentToolContext {
  NotesContext(AgentInvocation invocation)
    : super(invocation: invocation, audit: AgentMemoryAuditLog());

  @override
  List<String> get auditTargetKeys => const ['noteId'];

  /// The note [id], once the guard admits it; the vault is never admitted.
  String admit(String id) {
    final text = notes[id];
    final gate = guard(
      AgentGuardTarget(id: id, kind: 'note', excluded: id == 'vault'),
    );
    if (text == null || gate == AgentScopeGate.excluded) {
      throw const AgentToolException(
        AgentToolErrorCode.notFound,
        'No such note.',
      );
    }
    if (gate != null) {
      throw AgentToolException(
        AgentToolErrorCode.readOnly,
        'Refused.',
        gate: gate,
      );
    }
    return text;
  }

  @override
  Future<T> runAtomically<T>(String label, Future<T> Function() body) => body();

  @override
  NotesContext dryRunCopy() => NotesContext(invocation);
}

final tools = AgentToolRegistry<NotesContext>([
  AgentTool(
    name: 'read_note',
    summary: 'Read one note.',
    result: '{text}',
    arguments: const AgentToolSchema([
      AgentToolArgument('noteId', AgentToolValueType.string, required: true),
    ]),
    invoke: (context, arguments) => {
      'text': context.admit(arguments['noteId']! as String),
    },
  ),
]);

Future<void> main() async {
  final context = NotesContext(
    AgentInvocation.mint(scope: AgentScope(allowWrite: false)),
  );
  final binding = AgentToolBinding(context: context, registry: tools);

  // What a provider declares to the model.
  print(binding.declarations.single.name); // read_note

  // What the model's calls answer — a refusal is an answer too.
  print((await binding.call('read_note', {'noteId': 'n1'})).text);
  // {"text":"Buy milk"}
  print((await binding.call('read_note', {'noteId': 'vault'})).text);
  // {"code":"E_NOT_FOUND","message":"No such note."}

  // The same registry over MCP, in-process.
  final server = AgentInProcessMcpServer(binding, serverName: 'notes');
  final listed = await server.handle({
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'tools/list',
  });
  print(jsonEncode((listed!['result']! as Map)['tools'].length)); // 1

  // Every call is in the audit trail; the vault's text is not.
  for (final entry in context.audit.entries) {
    print('${entry.toolName} ${entry.targetId} ${entry.outcome.wire}');
  }
  // read_note n1 applied
  // read_note vault denied
}
```

The compiled form of this section is
[`example/readme_example.dart`](example/readme_example.dart), and
`test/readme_example_test.dart` asserts what it prints.

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_llm` | runtime | `LlmToolBinding`, the per-request binding a provider receives |
| `meta` | runtime | `@visibleForTesting` |
| `test`, `lints` | dev | the suite |

## Status

Version **0.1.0**. `dart test` runs the suite: the schema, the guard's order,
the invocation's consent, a call's recording, the registry, the audit log and
its file store, the binding, the MCP server, runs and their dry run,
preview-then-apply, the package's shape, and the example.
