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

A token is split on its **first** `=`: the key is the text before it, the value
is everything after it. Later `=` characters belong to the value, so a
connection string, a URL with a query, or a padded base64 blob arrives intact:

```dart
TomArgs.parseArgsToMap(['url=mysql://h/db?user=root']);
// => {'url': 'mysql://h/db?user=root'}   (not truncated at the second '=')
```

`TomEnvFile` splits the same way, which is what lets the two sources be
described as one syntax rather than two that merely resemble each other.

A token with no `=` is a **flag**. Both map paths encode a flag identically as
the boolean `true` — consistent with how `key=true` is converted — so a flag
fills a reflected `bool` field directly.

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
| wrapped in a matched pair of `"` or `'` | the unquoted contents |
| all digits, fitting a 64-bit `int` (e.g. `8080`) | `int` |
| decimal, `digits . digits*` (e.g. `3.14`, `5.`) | `double` |
| empty (`.env` only) | `null` |
| anything else | the original `String` |

The numeric rules match the *whole* string, so a leading sign or trailing text
keeps the value a `String`: `-5`, `1.2.3`, and `12px` all stay strings. `int` is
tried before `double`, so `8080` is an `int` and `3.14` a `double`.

The decimal's fractional part is **zero or more** digits, not one optional
digit. Two consequences are easy to predict wrongly:

| Value | Result | Why |
| ----- | ------ | --- |
| `3.14` | `double` `3.14` | any number of fractional digits is accepted |
| `5.` | `double` `5.0` | zero fractional digits is a match; the bare `.` does **not** keep it a `String` |
| `.5` | `String` | the integer part is required |

### A digit run larger than an `int` stays a `String`

Dart's `int` is 64-bit. A run of digits longer than `9223372036854775807` has no
`int` to become, so it is left as the text it arrived as — the same outcome as
`-5` or `12px`, and for the same reason: the converter only produces a type it
can actually represent.

| Value | Result |
| ----- | ------ |
| `9223372036854775807` | `int` — the largest that fits |
| `9223372036854775808` | `String` — one past the limit |
| `99999999999999999999` | `String` |

This matters because the values that overflow are rarely arithmetic. An account
number, a device identifier, or a phone number written without punctuation is a
label that happens to be spelled in digits, and a `String` is what the caller
wanted anyway. Treating the overflow as a parse failure would have cost the
whole argument list or `.env` file, not just the one value.

### Quotes are stripped only in pairs

`TomArgs.unquote` decides what counts as quoted, and both sources ask it, so a
value means the same thing on the command line as in a `.env` file. A value is
quoted only when it is at least two characters long, opens with `"` or `'`, and
closes with that same character:

| Value | Result | Why |
| ----- | ------ | --- |
| `"hello"` | `hello` | matched pair |
| `""` | the empty string | matched pair, empty contents |
| `"` | `"` | one character — there is no pair to strip |
| `"hello` | `"hello` | no closing quote |
| `"hello'` | `"hello'` | the quotes do not match |
| `hello"` | `hello"` | does not open with a quote |

An unbalanced quote is therefore **data, not a syntax error**: it is passed
through verbatim and start-up continues. A stray quote in a `.env` file does not
abort the read, and the lines after it are still parsed.

## How Configuration Composes Them

`TomBaseServerConfiguration` layers all three sources, later overriding earlier:

```text
Platform.environment  ─┐
.env file             ─┼─►  merged config values  ─►  the running server
command-line args     ─┘   (args win over .env win over environment)
```

(See `base_server_configuration.dart`, which calls `convertToObjectMap`,
`TomEnvFile.read`, and `parseArgsToMap` in that order.)

To build the same stack yourself, layer the three with `merge`:

```dart
final merged = TomEnvFile.merge([
  TomArgs.convertToObjectMap(Platform.environment),  // wrap is required
  TomEnvFile.read('.env'),
  TomArgs.parseArgsToMap(args),
]);
tomReflectionInfo.setValues<AppServerConfiguration>(configuration, merged);
```

> **Convert the environment before merging it.** `merge` overlays maps and
> converts nothing; `read` and `parseArgsToMap` hand it values that are already
> typed, but `Platform.environment` is a `Map<String, String>`. Dart's
> covariance lets it pass as a `Map<String, Object?>`, so an unwrapped
> environment merges without error and delivers every value as a `String` — and
> an `int` or `bool` field is then refused at `setValues` with
> `TomReflectorException: Unexpected type int set using String`.

## Core Components

- **`TomArgs`** — `fillFromArgs` (reflected object), `parseArgsToMap` (loose
  map), `convertToObjectMap` (string map → typed map), `unquote` (the shared
  matched-pair quoting rule), and the `intPattern` / `doublePattern` matchers
  that drive numeric detection.
- **`TomEnvFile`** — `read` / `readAsync` (file → map), `parse` (lines → map),
  `merge` (overlay maps), and `load` (read for manual use; the OS environment is
  read-only and is not mutated).

## Dependencies

- `tom_core_kernel` — `tomReflectionInfo` (the reflection entry point used by
  `fillFromArgs`).
- `dart:io` — `File` reads for `TomEnvFile`.
