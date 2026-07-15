# Tom Core D4rt API Reference: CLI & REPL Module

The interactive interpreter shell and its build-time version metadata. This is
what `bin/d4rt.dart` runs: a REPL with every Tom Framework bridge pre-registered
and optional VS Code editor integration.

## Table of contents

- [Overview](#overview)
- [Class hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [D4rtRepl](#d4rtrepl)
  - [TomVersionInfo](#tomversioninfo)
- [Enums](#enums)
- [Global functions and constants](#global-functions-and-constants)

## Overview

`D4rtRepl` is the Tom-flavoured extension of the base REPL from `tom_d4rt_dcli`:
it overrides bridge registration to call
[`TomDartscriptBridges.register`](api_summary_registration.md), advertises
`.dcli`/`.d4rt` replay support, and mixes in VS Code integration. `d4rtMain` is
the process entry point that constructs and runs it. `TomVersionInfo` holds the
version constants stamped in at build time by the versioner.

- Source: `lib/src/cli/d4rt_repl.dart` (`D4rtRepl`, `d4rtMain`).
- Source: `lib/src/cli/version.versioner.dart` (`TomVersionInfo`, generated).

## Class hierarchy

```
D4rtReplBase (tom_d4rt_dcli)
 └── D4rtRepl                 with VSCodeIntegrationMixin

Object
 └── TomVersionInfo           (static; private constructor)
```

## Classes

### D4rtRepl

D4rt REPL with the full Tom Framework bridge set and VS Code integration.

**Extends:** `D4rtReplBase` (from `tom_d4rt_dcli`)

**Mixes in:** `VSCodeIntegrationMixin`

**Constructors**

```dart
D4rtRepl();
```

**Properties**

| Property | Signature | Description |
| -------- | --------- | ----------- |
| `toolName` | `String get toolName` | Tool name reported by the REPL — `'D4rt'`. |
| `toolVersion` | `String get toolVersion` | The long version string from `TomVersionInfo.versionLong`. |
| `hasVSCodeIntegration` | `bool get hasVSCodeIntegration` | Always `true`; this REPL supports VS Code editor integration. |
| `replayFilePatterns` | `List<String> get replayFilePatterns` | Replay file suffixes accepted: `.replay.txt`, `.dcli`, `.d4rt`. |

**Methods**

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerBridges` | `void registerBridges(D4rt d4rt)` | Registers all Tom Framework bridges via `TomDartscriptBridges.register`. |
| `getImportBlock` | `String getImportBlock()` | Returns the stdlib imports plus the combined Tom bridge import block. |
| `getBridgesHelp` | `String getBridgesHelp([D4rt? d4rt])` | Builds the `Bridges` help section, listing per-package `info` commands. |
| `getAdditionalHelpSections` | `List<String> getAdditionalHelpSections()` | Extra help sections — the VS Code integration help. |
| `getCliOptionsHelp` | `String getCliOptionsHelp()` | The `Options` help text (session, replay, VS Code port, debug flags). |
| `createReplState` | `ReplState createReplState()` | Initialises VS Code integration and returns a `d4rt`-prompted `ReplState`. |
| `onReplStartup` | `Future<void> onReplStartup(D4rt d4rt, ReplState state)` | Startup hook — checks VS Code server availability. |
| `handleAdditionalCommands` | `Future<bool> handleAdditionalCommands(D4rt d4rt, ReplState state, String line, {bool silent = false})` | Delegates unrecognised commands to the VS Code integration mixin. |
| `handleAdditionalMultilineEnd` | `Future<bool> handleAdditionalMultilineEnd(D4rt d4rt, ReplState state, MultilineMode mode, String code, {bool silent = false})` | Delegates multiline-block completion to the VS Code integration mixin. |

**Fields set by the entry point**

`vscodePort` (from `VSCodeIntegrationMixin`) may be assigned before `run` to
override the default VS Code integration port.

### TomVersionInfo

Version information generated at build time. A static holder — the private
constructor `TomVersionInfo._()` prevents instantiation.

> **Generated file.** `version.versioner.dart` is produced by the versioner on
> every build; the constant values below are examples from the current build and
> change automatically. Do not edit them by hand.

**Constructors**

```dart
// None — private constructor TomVersionInfo._(); the class is static-only.
```

**Static properties**

| Property | Signature | Description |
| -------- | --------- | ----------- |
| `version` | `static const String version` | Package version from `pubspec.yaml`. |
| `buildTime` | `static const String buildTime` | Build timestamp (ISO 8601 UTC). |
| `gitCommit` | `static const String gitCommit` | Git commit hash (short form). |
| `buildNumber` | `static const int buildNumber` | Build number, incremented each build. |
| `dartSdkVersion` | `static const String dartSdkVersion` | Dart SDK version used for the build. |
| `versionShort` | `static String get versionShort` | `version+buildNumber` (e.g. `1.0.1+42`). |
| `versionMedium` | `static String get versionMedium` | `version+buildNumber.gitCommit (buildTime)`. |
| `versionLong` | `static String get versionLong` | Medium plus `[Dart <sdk>]` — used as `D4rtRepl.toolVersion`. |

## Enums

None — this module defines no enums.

## Global functions and constants

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `d4rtMain` | `Future<void> d4rtMain(List<String> arguments)` | Process entry point: parses `-integration-server-port`, constructs a `D4rtRepl`, and runs it against `arguments`. |
