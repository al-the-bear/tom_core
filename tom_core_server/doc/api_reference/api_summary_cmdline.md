# Tom Core Server API Reference: Command Line Module

Parsing of `key=value` command-line arguments and `.env` files, with automatic
conversion of string values to their natural Dart types.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomArgs](#tomargs)
  - [TomEnvFile](#tomenvfile)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/cmdline/args.dart`, `lib/src/tomserver/cmdline/env_file.dart`.

`TomArgs` is a static namespace that parses `key=value` arguments and converts
each value to its natural Dart type (`bool`, `int`, `double`, or `String`). It
offers three entry points — `fillFromArgs` (reflection-fills a configuration
object), `parseArgsToMap` (loose map), and `convertToObjectMap` (converts an
existing string map such as `Platform.environment`) — all sharing the same
conversion rules. An argument is split on its **first** `=`, so a value may
itself contain `=` (a connection string, a URL with a query, padded base64) and
arrives whole; `TomEnvFile` splits the same way. A bare flag becomes the boolean
`true` in both `parseArgsToMap` and `fillFromArgs`, consistent with how
`key=true` converts. An argument whose key is empty — an empty argument, or one
starting with `=` — is skipped rather than recorded under an empty key, again as
`TomEnvFile` does; the arguments around it are still parsed.

`TomEnvFile` reads environment variables from a `.env` file (synchronously or
asynchronously), supporting comments, empty lines, quoted values, and inline
comments. It reuses the `TomArgs` conversion rules, so a value is typed the same
way from either source with one documented exception — an empty value becomes
`null` here and the empty `String` there. It can merge multiple sources, with
later sources overriding earlier ones, and `resolveEnvironment` merges one
particular pair — the OS environment and a `.env` — into the string map that
`TomYaml`'s `${VAR:default}` expansion reads.

## Class Hierarchy

```
TomArgs      (static namespace)
TomEnvFile   (static namespace)
```

## Classes

### TomArgs

Parses `key=value` command-line arguments and converts string values to their
natural Dart types. All members are static; the class is a namespace, not a
value type.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fillFromArgs` | `static T fillFromArgs<T extends Object>(List<String> args, T fillIn)` | Fills `fillIn` from `key=value` `args` using reflection and returns it, splitting each argument on its first `=`; a bare flag is recorded as the boolean `true`, and an argument with an empty key is skipped. `T` must be registered with the reflection system. |
| `parseArgsToMap` | `static Map<String, dynamic> parseArgsToMap(List<String> args)` | Parses `key=value` `args` into a loose map, splitting on the first `=` and type-converting each value; a bare flag becomes the boolean `true`, and an argument with an empty key contributes no entry. |
| `convertToObjectMap` | `static Map<String, dynamic> convertToObjectMap(Map<String, String> map)` | Converts every value in a string `map` to its natural Dart type (useful for normalising `Platform.environment`). |
| `unquote` | `static String? unquote(String value)` | Returns the contents of `value` with its surrounding quotes removed, or `null` when `value` is not a quoted literal. Quotes count only as a **matched pair** — at least two characters, opening with `"` or `'` and closing with that same character — so `""` unquotes to the empty string while a lone `"`, an unterminated `"hello` and a mismatched `"hello'` all yield `null` and are used verbatim. `TomEnvFile.parse` decides through this method too, so the two sources cannot disagree. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `intPattern` | `RegExp` | Matches an **unpadded** run of digits (`0` itself, or a run starting with a non-zero digit); a value parses as `int` only when this matches the whole string **and** the number fits a 64-bit `int` — the pattern constrains shape, not magnitude (static, final). |
| `doublePattern` | `RegExp` | Matches a decimal number (`digits . digits*` — the fractional part is zero or more digits, not one optional digit) whose integer part is unpadded like `intPattern`; a value parses as `double` only when this matches the whole string and it is not already an `int` (static, final). |

Value-conversion table (shared by all entry points):

| Input | Result |
| ----- | ------ |
| `"true"` / `null` | `bool` `true` |
| `"false"` | `bool` `false` |
| wrapped in a matched pair of `"` or `'` | the unquoted contents |
| all digits, unpadded, and it fits a 64-bit `int` | `int` |
| decimal number, `digits . digits*` (`5.` included), integer part unpadded | `double` |
| anything else | the original `String` |

Quotes are stripped only as a pair (see `unquote`), so an unbalanced quote is
data rather than a syntax error: `"` and `"hello` pass through unchanged.

Two restrictions on a digit run are part of the rule, and both say the same
thing — a type is produced only when it can carry the value faithfully:

- **Magnitude.** `9223372036854775807` converts, `9223372036854775808` and
  longer runs stay `String`. Overflow is not a parse failure — an account
  number or device id arrives as the text it was written as, instead of
  aborting the whole argument list or `.env` file.
- **Padding.** A run with leading zeros stays a `String`, because an `int` has
  no notion of the padding and `007` would arrive as `7`. A lone `0` is not
  padding and converts. The rule reaches the integer part of a decimal too
  (`00.5` stays a `String`, `0.5` converts) but not the fractional part, since
  `1.50` and `1.5` are one quantity while `007` and `7` are two identifiers.
  The consequence for a reflected object is that `port=08080` is refused at
  assignment rather than binding 8080.

The fractional part of a decimal is zero or more digits, so a value ending in a
bare `.` converts rather than staying a `String`: `5.` becomes the `double`
`5.0`. An integer part is still required, so `.5` stays a `String`.

### TomEnvFile

Reads environment variables from a `.env` file. Supports `KEY=value` pairs,
`#` comments, empty lines, quoted values, and inline comments. All members are
static.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `read` | `static Map<String, Object?> read([String path = '.env'])` | Reads a `.env` file synchronously, converting values to their natural types; returns an empty map if the file does not exist. |
| `readAsync` | `static Future<Map<String, Object?>> readAsync([String path = '.env'])` | Asynchronous variant of `read`; returns an empty map if the file does not exist. |
| `parse` | `static Map<String, Object?> parse(List<String> lines)` | Parses a list of `.env`-format lines into a map, usable for content from any source. |
| `merge` | `static Map<String, Object?> merge(List<Map<String, Object?>> sources)` | Merges multiple environment maps; later sources override earlier ones. Converts nothing: a raw `Map<String, String>` such as `Platform.environment` passes by covariance and contributes `String` values, so wrap it in `TomArgs.convertToObjectMap` first. |
| `load` | `static Map<String, Object?> load([String path = '.env'])` | Loads a `.env` file and returns the values (note: `Platform.environment` is read-only, so this does not mutate the OS environment). |
| `resolveEnvironment` | `static Map<String, String> resolveEnvironment({String path = '.env', Map<String, String>? processEnvironment})` | Builds the variable map that `${VAR:default}` placeholders expand from: `processEnvironment` (defaulting to `Platform.environment`) with the `.env` at `path` layered **on top**. Hand the result to `TomYaml.loadYamlFile(..., environment:)` — that is the only way a `.env` reaches a placeholder, since the process environment cannot be written to. Values are returned as `String` because an expansion is substituted as text; a key whose `.env` value is empty is dropped rather than contributed as `''`, leaving any process value for it standing. A missing file contributes nothing. |

`parse` reads a line only when it carries a `=` and a non-empty key, so a blank
line, a `#` comment line, and a line with no separator are all skipped, as is a
line beginning with `=`. Key and value are each trimmed of surrounding
whitespace — `TomArgs` does not trim, which is the other way the two sources
differ. A skipped line costs only itself; the lines around it are still read.

Value conversion then runs through the `TomArgs` table above. Three further
rules decide *which* type a value arrives as, and each is what one of the
supported features named above actually does:

| Input line | Result | Rule |
| ---------- | ------ | ---- |
| `NUM=123` | `int` `123` | the shared table applies |
| `NUM="123"` | `String` `123` | quoted — no conversion at all |
| `ON="true"` | `String` `true` | quoted — not a `bool` |
| `EMPTY=` | `null` | empty value (`.env` only) |
| `EMPTY=""` | `String` `''` | quoted empty — not `null` |
| `PW=pa#ss` | `String` `pa` | truncated at the inline comment |

**A quoted value skips conversion entirely.** `TomArgs.unquote` decides what
counts as quoted — a matched pair, see `unquote` above — and a value it accepts
is stored as its unquoted contents with no further typing. Quoting is therefore
how a value that *looks* like another type is kept a `String`: `NUM="123"` is
the string `123`, not the `int`, and `ON="true"` is the string `true`, not the
`bool`. `TomArgs` treats a quoted argument the same way, so this is a shared
rule rather than a `.env` peculiarity — but it is what "quoted values" means.

**An empty value becomes `null`, not the empty `String`.** This is the one
place the two classes' conversion tables diverge: the `.env` line `EMPTY=`
yields `null`, while the argument `EMPTY=` yields the empty `String`. The key is
present either way — `containsKey` returns `true` — so an empty assignment is a
key explicitly set to nothing, which is distinct from a key no source mentioned
at all. To store an empty `String` from a `.env` file, quote it: `EMPTY=""`.

**An unquoted value is truncated at its first `#`.** No whitespace is required
before it, so `PW=pa#ss` yields `pa` and a URL loses its fragment; that is what
"inline comments" means. `TomArgs` strips no comments, so unlike the quoting
rule this one really is `.env`-only. Quote any value that may legitimately
contain a `#`.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
