# Command-Line Module

Two small helpers for reading process configuration: `TomArgs` parses
`key=value` command-line arguments, and `TomEnvFile` reads `.env` files. Both
convert string values to their natural Dart type (`int`, `double`, `bool`, or
`String`) using the **same conversion rules**, so a value written on the command
line, in the environment, or in a `.env` file is interpreted identically.

## Table of Contents

- [Overview](#overview)
- [Parsing Arguments](#parsing-arguments)
- [Reading `.env` Files](#reading-env-files)
- [Value Conversion](#value-conversion)
- [How Configuration Composes Them](#how-configuration-composes-them)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomArgs` | class (static) | Parse `key=value` argv into a typed object or a map |
| `TomEnvFile` | class (static) | Read / parse / merge `.env` files into a map |

## Parsing Arguments

`TomArgs` offers three entry points over the same conversion rules:

```dart
// 1. Into a reflected configuration object (fields named after the keys):
final config = TomArgs.fillFromArgs(argv, MyServerArgs());

// 2. Into a loose map:
final map = TomArgs.parseArgsToMap(['port=8080', 'debug=true', '--verbose']);
// => {'port': 8080, 'debug': true, '--verbose': true}

// 3. Convert an existing string map (e.g. the OS environment):
final env = TomArgs.convertToObjectMap(Platform.environment);
```

A token with no `=` is a **flag**. The two map paths encode a flag slightly
differently — `parseArgsToMap` stores the boolean `true`, while `fillFromArgs`
stores the string `"true"` and lets the reflection layer coerce it to the target
field's declared type.

> **`fillFromArgs` needs a reflected type.** It assigns through
> `tomReflectionInfo.setValues`, so `T` must be registered with the reflection
> system (an `@tomReflector` configuration class). Keys that do not match a
> field are ignored. `parseArgsToMap` and `convertToObjectMap` have no such
> requirement and work on any input.

## Reading `.env` Files

`TomEnvFile` reads a dotenv-style file. A missing file yields an empty map (it
is never an error):

```dart
final env = TomEnvFile.read();            // reads './.env'
final env = TomEnvFile.read('config.env'); // custom path
final env = await TomEnvFile.readAsync();   // async variant
```

The format supports `KEY=value` pairs, `#` comment lines, blank lines, quoted
values (`KEY="with spaces"`), and inline comments after an unquoted value
(`KEY=value # note`). `parse(List<String>)` exposes the same parsing for content
from any source, and `merge` overlays several maps (later wins):

```dart
final env = TomEnvFile.merge([
  TomEnvFile.read('.env'),
  TomEnvFile.read('.env.local'), // overrides the base
]);
```

A **quoted** value is always kept as a `String` (no type conversion); an
unquoted value is converted by the same rules as `TomArgs` (see below).

## Value Conversion

Both classes share one conversion table (implemented once in `TomArgs`):

| Input string | Result |
| ------------ | ------ |
| `true` | `bool` `true` |
| `false` | `bool` `false` |
| starts with `"` or `'` | the unquoted contents |
| all digits (e.g. `8080`) | `int` |
| decimal (e.g. `3.14`) | `double` |
| empty (`.env` only) | `null` |
| anything else | the original `String` |

The numeric rules match the *whole* string, so a leading sign or trailing text
keeps the value a `String`: `-5`, `1.2.3`, and `12px` all stay strings. `int` is
tried before `double`, so `8080` is an `int` and `3.14` a `double`.

## How Configuration Composes Them

`TomBaseServerConfiguration` layers all three sources, later overriding earlier:

```text
Platform.environment  ─┐
.env file             ─┼─►  merged config values  ─►  the running server
command-line args     ─┘   (args win over .env win over environment)
```

(See `base_server_configuration.dart`, which calls `convertToObjectMap`,
`TomEnvFile.read`, and `parseArgsToMap` in that order.)

## Core Components

- **`TomArgs`** — `fillFromArgs` (reflected object), `parseArgsToMap` (loose
  map), `convertToObjectMap` (string map → typed map), and the `intPattern` /
  `doublePattern` matchers that drive numeric detection.
- **`TomEnvFile`** — `read` / `readAsync` (file → map), `parse` (lines → map),
  `merge` (overlay maps), and `load` (read for manual use; the OS environment is
  read-only and is not mutated).

## Dependencies

- `tom_core_kernel` — `tomReflectionInfo` (the reflection entry point used by
  `fillFromArgs`).
- `dart:io` — `File` reads for `TomEnvFile`.
