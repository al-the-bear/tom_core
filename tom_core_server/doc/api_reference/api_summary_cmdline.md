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
`key=true` converts.

`TomEnvFile` reads environment variables from a `.env` file (synchronously or
asynchronously), supporting comments, empty lines, quoted values, and inline
comments. It reuses the `TomArgs` conversion rules so values are typed
consistently, and can merge multiple sources with later sources overriding
earlier ones.

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
| `fillFromArgs` | `static T fillFromArgs<T extends Object>(List<String> args, T fillIn)` | Fills `fillIn` from `key=value` `args` using reflection and returns it, splitting each argument on its first `=`; a bare flag is recorded as the boolean `true`. `T` must be registered with the reflection system. |
| `parseArgsToMap` | `static Map<String, dynamic> parseArgsToMap(List<String> args)` | Parses `key=value` `args` into a loose map, splitting on the first `=` and type-converting each value; a bare flag becomes the boolean `true`. |
| `convertToObjectMap` | `static Map<String, dynamic> convertToObjectMap(Map<String, String> map)` | Converts every value in a string `map` to its natural Dart type (useful for normalising `Platform.environment`). |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `intPattern` | `RegExp` | Matches a run of digits; a value parses as `int` only when this matches the whole string (static, final). |
| `doublePattern` | `RegExp` | Matches a decimal number (`digits . digits?`); a value parses as `double` only when this matches the whole string and it is not already an `int` (static, final). |

Value-conversion table (shared by all entry points):

| Input | Result |
| ----- | ------ |
| `"true"` / `null` | `bool` `true` |
| `"false"` | `bool` `false` |
| starts with `"` or `'` | the unquoted contents (first/last char dropped) |
| all digits | `int` |
| decimal number | `double` |
| anything else | the original `String` |

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

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
