# D4rt CLI wiring (tom_core_d4rt)

This package ships the **extended D4rt REPL/CLI** — the base `dcli` REPL from
`tom_d4rt_dcli` with the **full Tom Framework bridge set** pre-registered plus
VS Code integration. This document describes how the entry point, the REPL
class, and the generated runners are wired together.

> The programmatic `cli` global API (`cli.replay(...)`, `cli.processPrompt(...)`,
> etc.) is an upstream concern owned by `tom_d4rt_dcli`; its design lives in
> [`d4rt_cli_api_design.md`](d4rt_cli_api_design.md). This document covers only
> the wiring inside *this* package.

## Entry point — thin by design

`bin/d4rt.dart` is the canonical executable. It is intentionally **thin**: it
imports `d4rtMain` from the CLI library and delegates, holding no logic of its
own.

```dart
// bin/d4rt.dart
import 'package:tom_core_d4rt/src/cli/d4rt_repl.dart';

Future<void> main(List<String> arguments) async {
  await d4rtMain(arguments);
}
```

All behaviour lives under `lib/src/cli/`. The rule for this entry is: **no
business logic in `bin/` — parse nothing, decide nothing, just call
`d4rtMain`.** Argument parsing (including the `-integration-server-port`
override) and the REPL lifecycle belong to the library.

## CLI library — `lib/src/cli/`

| File | Role |
| ---- | ---- |
| `d4rt_repl.dart` | The `D4rtRepl` class + the `d4rtMain(args)` entry function. |
| `version.versioner.dart` | **Generated** `TomVersionInfo` (version/build/git constants). Do not hand-edit — emitted by the `versioner` build step. |

### `D4rtRepl` — the extension points

`D4rtRepl extends D4rtReplBase with VSCodeIntegrationMixin`. The REPL engine
(readline, prompts, session/replay handling, command dispatch) is the upstream
`D4rtReplBase` from `tom_d4rt_dcli`; this subclass only supplies the
Tom-specific behaviour by overriding a handful of hooks:

| Override | Supplies |
| -------- | -------- |
| `registerBridges(d4rt)` | Registers the full Tom bridge set via `TomDartscriptBridges.register(d4rt)`. |
| `getImportBlock()` | Stdlib imports + `TomDartscriptBridges.getImportBlock()`. |
| `toolVersion` | `TomVersionInfo.versionLong` (from the generated versioner). |
| `replayFilePatterns` | `['.replay.txt', '.dcli', '.d4rt']` — D4rt accepts both replay dialects. |
| `getBridgesHelp` / `getCliOptionsHelp` / `getAdditionalHelpSections` | Help text (bridge listing, CLI options, VS Code section). |
| `createReplState` / `onReplStartup` / `handleAdditionalCommands` / `handleAdditionalMultilineEnd` | VS Code integration lifecycle (delegated to `VSCodeIntegrationMixin`). |

`d4rtMain` parses the VS Code port override, constructs the `D4rtRepl`, and runs
it:

```dart
Future<void> d4rtMain(List<String> arguments) async {
  int? port; // parsed from -integration-server-port
  // ...
  final repl = D4rtRepl();
  if (port != null) repl.vscodePort = port;
  await repl.run(arguments);
}
```

The bridge set itself is owned by `lib/tom_dartscript_bridges.dart`
(`TomDartscriptBridges.register`) — the per-module `*_bridges.b.dart` files
documented elsewhere in `doc/`.

## Generated non-interactive runner — `bin/d4rtrun.b.dart`

`bin/d4rtrun.b.dart` is a **generated** file (note the `.b.dart` suffix and the
`// Generated:` header — do not hand-edit). It is a *non-interactive* runner,
separate from the REPL entry, used by the test harness and for one-shot
execution. Its modes:

| Invocation | Mode |
| ---------- | ---- |
| `<script.dart\|.d4rt>` | Run a script file via `execute()`. |
| `"<expression>"` | Evaluate an expression via `eval()` (after an init import block). |
| `--eval-file <file>` | Evaluate file contents with `eval()`. |
| `--init-eval` | Validate bridge registrations (`validateRegistrations`). |
| `--test <file>` | Run a script in test mode, capturing print output + exceptions as JSON. |
| `--test-eval <init> <expr>` | Init then eval in test mode (JSON output). |

It registers every bridge inline via its own `_registerBridges` and grants all
permissions. Because it is generated, any change to its behaviour (registration
list, mode handling) is made by regenerating from the `d4rtgen` config, not by
editing this file.

## Build/run note (B3)

`dart analyze bin lib/src/cli` is clean. Compiling/running the **full binary**
(`dart run bin/d4rt.dart`, or `bin/d4rtrun.b.dart`) currently fails at the CFE
because it links in `lib/src/tom_core_server/tom_core_server_bridges.b.dart`,
which carries a generated callback-type defect (`withConnection` —
`FutureOr<Object?>` vs `FutureOr<Object>`). This is the pre-existing **B3**
blocker tracked for the registration/analyze-replay gate
(`refactoring_plan.md` items 75-76); it is a `tom_core_server` codegen defect,
not a CLI-wiring issue,
and the analyzer does not surface it (only the CFE does).
