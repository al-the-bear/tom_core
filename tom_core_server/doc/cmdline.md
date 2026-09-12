# Command-Line Module

Two small helpers for reading process configuration: `TomArgs` parses
`key=value` command-line arguments, and `TomEnvFile` reads `.env` files. Both
convert string values to their natural Dart type (`int`, `double`, `bool`, or
`String`) using the **same conversion rules**, so a value written on the command
line, in the environment, or in a `.env` file is interpreted identically.

## Table of Contents

- [Overview](#overview)
- [Parsing Arguments](#parsing-arguments)
  - [A key is named without its leading dashes](#a-key-is-named-without-its-leading-dashes)
- [Reading `.env` Files](#reading-env-files)
- [Value Conversion](#value-conversion)
  - [A leading `-` is part of the number; a leading `+` is not](#a-leading---is-part-of-the-number-a-leading--is-not)
  - [A digit run larger than an `int` stays a `String`](#a-digit-run-larger-than-an-int-stays-a-string)
  - [A digit run with leading zeros stays a `String`](#a-digit-run-with-leading-zeros-stays-a-string)
  - [Quotes are stripped only in pairs](#quotes-are-stripped-only-in-pairs)
- [How Configuration Composes Them](#how-configuration-composes-them)
  - [A `SCREAMING_SNAKE_CASE` variable names a `lowerCamelCase` field](#a-screaming_snake_case-variable-names-a-lowercamelcase-field)
  - [The `.env` reaches placeholders only if you carry it there](#the-env-reaches-placeholders-only-if-you-carry-it-there)
- [Not Yet Implemented](#not-yet-implemented)
- [Core Components](#core-components)
- [Verification](#verification)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomArgs` | class | Parse `key=value` argv into a typed object or a map. Statics only |
| `TomEnvFile` | class | Read / parse / merge `.env` files into a map. Statics only |

## Parsing Arguments

`TomArgs` offers three entry points over the same conversion rules:

```dart
// 1. Into a reflected configuration object (fields named after the keys):
final config = TomArgs.fillFromArgs(argv, MyServerArgs());

// 2. Into a loose map:
final map = TomArgs.parseArgsToMap(['port=8080', 'debug=true', '--verbose']);
// => {'port': 8080, 'debug': true, 'verbose': true}

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

A token whose key is empty is **skipped**: an empty token, one starting with
`=` so that nothing precedes the separator, and one whose key is nothing but
dashes, name no field, and are dropped rather than recorded under an empty key.
`TomEnvFile` skips such a line for the same reason. Skipping is per token — the
tokens around a malformed one are still parsed, so one stray argument does not
cost the launch line the rest:

```dart
TomArgs.parseArgsToMap(['name=svc', '=orphan', 'port=8080']);
// => {'name': 'svc', 'port': 8080}
```

### A key is named without its leading dashes

A key is stripped of the `-` characters it begins with, so the three spellings
of one option are one argument:

```dart
TomArgs.parseArgsToMap(['--port=8080']);   // => {'port': 8080}
TomArgs.parseArgsToMap(['-port=8080']);    // => {'port': 8080}
TomArgs.parseArgsToMap(['port=8080']);     // => {'port': 8080}
TomArgs.parseArgsToMap(['--verbose']);     // => {'verbose': true}
```

This is what lets the conventional command-line spelling reach a reflected
field: `fillFromArgs` hands the key to `setValues` as a field name, and no Dart
class declares a field named `--port`.

Three consequences are worth stating:

- **A key cannot begin with `-`.** The whole leading run is removed, so there is
  no prefix arity to remember and no way to name a key whose first character is
  a dash. Only the leading run is a prefix — `--dry-run=1` is the key `dry-run`,
  and a dash in the *value* is data (`--mode=-5` gives `'-5'`).
- **The dashed and bare spellings are one entry.** `['port=1', '--port=2']`
  yields `{'port': 2}` — the later argument overrides the earlier one, rather
  than the map holding two values for one setting.
- **`TomEnvFile` does not strip.** Stripping is a command-line convention;
  nothing writes `--PORT=8080` in a `.env` file, where a variable name is the
  name. `TomEnvFile.parse(['--port=8080'])` therefore gives `{'--port': 8080}`.
  This is the one place the two sources part company by design.

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
| an optional `-`, then digits, unpadded, fitting a 64-bit `int` (e.g. `8080`, `-5`) | `int` |
| an optional `-`, then a decimal, `digits . digits*` (e.g. `3.14`, `5.`, `-1.5`), integer part unpadded | `double` |
| empty (`.env` only) | `null` |
| anything else | the original `String` |

The numeric rules match the *whole* string, so trailing text keeps the value a
`String`: `1.2.3` and `12px` both stay strings. `int` is tried before `double`,
so `8080` is an `int` and `3.14` a `double`.

The decimal's fractional part is **zero or more** digits, not one optional
digit. Two consequences are easy to predict wrongly:

| Value | Result | Why |
| ----- | ------ | --- |
| `3.14` | `double` `3.14` | any number of fractional digits is accepted |
| `5.` | `double` `5.0` | zero fractional digits is a match; the bare `.` does **not** keep it a `String` |
| `.5` | `String` | the integer part is required |

### A leading `-` is part of the number; a leading `+` is not

| Value | Result |
| ----- | ------ |
| `-5` | `int` `-5` |
| `-1.5` | `double` `-1.5` |
| `-9223372036854775808` | `int` — the smallest that fits; the ends are not mirrors |
| `+5` | `String` |
| `+4917612345678` | `String` — a phone number, not a quantity |
| `-007` | `String` — the padding rule applies to the run after the sign |
| `-` | `String` — a sign with no number after it |
| `"-5"` | `String` `-5` — quoting is the escape |

A `-` changes the value it introduces, so it is part of the number. Without it
a negative setting could not reach a numeric field from any source: the `String`
arrives at a reflected `int` field and is refused with `TomReflectorException`,
so a negative offset had to be carried as a positive number plus a direction
flag.

A `+` is different, and the asymmetry is the padding rule in its other
spelling. A `+` in front of a digit run is decoration — it is how an
international phone number is written — so converting `+4917612345678` produces
a *different* identifier and reports nothing, exactly as `007` → `7` would. The
cost of refusing it lands where it is loud rather than where it is silent: `+5`
against an `int` field is refused at assignment, naming the key, whereas a
converted `+49…` would have arrived silently as the wrong number.

Quoting works in both directions, as everywhere else in the table: `"-5"` is the
text `-5`, and there is no way to make `+5` a number other than writing it
without the sign.

### A digit run larger than an `int` stays a `String`

Dart's `int` is 64-bit. A run of digits longer than `9223372036854775807` has no
`int` to become, so it is left as the text it arrived as — the same outcome as
`12px` or `+5`, and for the same reason: the converter only produces a type it
can actually represent.

| Value | Result |
| ----- | ------ |
| `9223372036854775807` | `int` — the largest that fits |
| `9223372036854775808` | `String` — one past the limit |
| `-9223372036854775808` | `int` — two's complement reaches one further down |
| `-9223372036854775809` | `String` — one past the limit at the other end |
| `99999999999999999999` | `String` |

This matters because the values that overflow are rarely arithmetic. An account
number, a device identifier, or a phone number written without punctuation is a
label that happens to be spelled in digits, and a `String` is what the caller
wanted anyway. Treating the overflow as a parse failure would have cost the
whole argument list or `.env` file, not just the one value.

### A digit run with leading zeros stays a `String`

The same principle, applied to the other way a digit run has no faithful `int`.
An `int` has no notion of padding, so `007` would arrive as `7` — a *different*
identifier, with nothing reporting the change. The converter therefore accepts a
digit run only when it is unpadded: `0` itself, or a run starting with a
non-zero digit.

| Value | Result |
| ----- | ------ |
| `0` | `int` `0` — a lone zero is not padding |
| `8080` | `int` `8080` |
| `007` | `String` — the zeros are part of the identifier |
| `004917612345678901` | `String` — fits 64 bits, so only this rule saves it |
| `01067` | `String` — a postcode, not the number 1067 |
| `0.5` | `double` `0.5` |
| `00.5` | `String` — the integer part is padded |
| `1.50` | `double` `1.5` — a fractional trailing zero is not identity |

A leading zero is only ever written when the zeros carry meaning: nobody writes
`port=08080` intending 8080. The values that carry them — phone numbers with an
international prefix, zero-padded account and article numbers, postcodes,
country codes — are identifiers rather than quantities, and they arrive as the
text the deployment wrote.

The magnitude limit does not cover this case, which is why it is a rule of its
own: `004917612345678901` fits comfortably in 64 bits, so it converted happily
and lost its prefix. The *fractional* part of a decimal is deliberately left
unrestricted, because a trailing zero after the point is not identity — `1.50`
and `1.5` are one quantity, whereas `007` and `7` are two identifiers.

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

`TomBaseServerConfiguration` layers all three sources **on top of the
configuration resources**, later overriding earlier:

```text
configuration resources  ─┐
Platform.environment     ─┼─►  merged config values  ─►  the running server
.env file                ─┤   (args win over .env win over environment
command-line args        ─┘    win over resources)
```

(See `getDefaultValues` in `base_server_configuration.dart`: it starts from a
deep copy of `TomServerConfigResourceProvider.getServerConfig().resources`, then
calls `convertToObjectMap`, `TomEnvFile.read`, and `parseArgsToMap` in that
order.)

### A `SCREAMING_SNAKE_CASE` variable names a `lowerCamelCase` field

The two environment layers are each passed through
`TomArgs.resolveEnvironmentNames` on the way in, which adds — for every key
written in `SCREAMING_SNAKE_CASE` — a second entry under the field name
`TomArgs.fieldNameOf` gives it. So `JWT_SHARED_SECRET_KEY` fills
`jwtSharedSecretKey` and `SMS_API_KEY` fills `smsApiKey`, which is what lets a
deployment use the spelling its container platform and secret store already use
rather than a variable literally named `jwtSharedSecretKey`.

The original key is **kept** alongside the alias, so a `${VAR}` placeholder is
unaffected; a key already spelled as the field wins over its screaming twin; and
the mapping is applied **per source before merging**, so an alias carries its own
source's precedence rather than jumping the queue. A name outside the convention
contributes no alias — approximating one would be a guess, and a guess that
happened to match a declared field would bind a value nobody aimed at it. The
full rule, its inverse, and the one class of field it cannot reach are in
[configuration.md](configuration.md#a-screaming_snake_case-variable-names-a-lowercamelcase-field).

**Command-line arguments are not aliased.** An argument names its target
directly and is written by the person who knows the field; the convention exists
for the *environment*, where the spelling is imposed by the platform.

The resource tree is the base rather than a fourth peer, and that is the layer
worth knowing about: it is the only one that supplies a value when none of the
other three does. A setting that appears in the running server without being
passed anywhere came from the YAML the provider loaded — see
[configuration.md](configuration.md) for how that tree is built.

### The `.env` reaches placeholders only if you carry it there

The layering above covers **config keys**. It does not cover the `${VAR:default}`
placeholders *inside* the YAML that forms the base layer: those are expanded by
`TomYaml.loadYamlFile` while the file is being read, before anything is layered,
and it expands from `Platform.environment` unless it is handed another map. A
`.env` cannot change that by itself — Dart's process environment is read-only, so
no amount of reading a `.env` puts its values where a default expansion will look.

This matters most for the datasource YAML, which is normally where the `${...}`
placeholders live. A boot that reads a `.env` for its config keys and then loads
`datasources_default.yaml` the default way will connect to the placeholder
defaults while its configuration reports the `.env` values — and if the same
`.env` also drives a Docker Compose file, the database moves and the server does
not follow.

Pass the merged map explicitly:

```dart
final environment = TomEnvFile.resolveEnvironment();          // OS env + .env
final yaml = TomYaml.loadYamlFile('assets/datasources_default.yaml',
    environment: environment);
```

`resolveEnvironment` layers the `.env` **over** the OS environment, matching
`getDefaultValues` above so both halves of a boot read the file the same way.
(Docker Compose resolves the other way round — the shell wins there — so a
variable set in *both* the shell and a `.env` is one of the few things the server
and Compose will disagree about.) Values come back as `String`, since that is
what a placeholder expands to.

To build the three upper layers yourself — without a resource tree beneath
them — use `merge`:

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

## Not Yet Implemented

- **A zero-padded or `+`-signed number cannot fill an `int` field.** Leading
  zeros and a leading `+` keep a value a `String` (above), so `port=08080` and
  `port=+5` are refused at assignment with `TomReflectorException` rather than
  silently binding 8080 and 5. This is the price of the padding rule and is the
  intended one: a deployment that decorates a number learns it at start-up
  rather than never. Write the number plainly (`port=8080`, `offset=-5`) when
  the target is a numeric field.
- **No entry point reports a setting that no source supplied.** `merge`
  overlays maps and returns; `fillFromArgs` binds the keys it was given. A
  required setting that nobody supplied is indistinguishable from one that was
  never declared — the field keeps its initialiser, and the failure surfaces
  later as a connection to `localhost:0` rather than at start-up. Completeness
  is the caller's check, after the last source is merged.
- **`load` does not load.** It reads the file and returns the values, exactly as
  `read` does. `Platform.environment` is read-only, so there is nothing for it
  to install them into. Prefer `read`, which says what happens.
- **A `#` anywhere in an unquoted `.env` value truncates it.** The
  inline-comment rule cuts at the first `#` with no requirement that whitespace
  precede it, so `K=pa#ss` yields `pa` and a URL loses its fragment. Quote any
  value that may legitimately contain a `#` — a password, a fragment, a colour
  literal. Command-line arguments are not affected: `TomArgs` strips no
  comments.
- **The two parsers still differ on whitespace.** `TomEnvFile.parse` trims
  around the key and the value; `TomArgs` takes the token as given. So
  `' k = v '` is `{'k': 'v'}` from a `.env` file and `{' k ': ' v '}` from the
  command line, and a whitespace-only token is an empty line to one and a key
  to the other. The two agree on everything else that decides a key — where it
  ends, what counts as quoted, and that an empty key is skipped.

## Core Components

- **`TomArgs`** — `fillFromArgs` (reflected object), `parseArgsToMap` (loose
  map), `convertToObjectMap` (string map → typed map), `unquote` (the shared
  matched-pair quoting rule), and the `intPattern` / `doublePattern` matchers
  that drive numeric detection.
- **`TomEnvFile`** — `read` / `readAsync` (file → map), `parse` (lines → map),
  `merge` (overlay maps), `resolveEnvironment` (OS environment + `.env`,
  stringified, for `${VAR:default}` expansion), and `load` (read for manual use;
  the OS environment is read-only and is not mutated).

## Verification

`example/cmdline/cmdline_example.dart` walks the codegen-free helpers in seven
steps, with no setup of any kind — parse `key=value` arguments, normalise an
existing string map, `parse` a `.env` blob that never touches disk, read a
`.env` file it writes to a temp directory first, read the same file again with
`readAsync`, the missing file that yields an empty map from either variant, and
a two-layer `merge`. Run it exactly as its header documents:

```bash
dart run example/cmdline/cmdline_example.dart
```

Every step checks its own result through the shared `example/_support/check.dart`
and the run fails when one does not hold, so a green run is a verification
rather than a transcript — see
[A green run is a verification](../README.md#a-green-example-run-is-a-verification)
for why that helper throws instead of asserting.

Two members are left out, and the example's header gives a reason for each:
`fillFromArgs` needs a reflected configuration type, and `load` does nothing
`read` does not (see the limitation above), so demonstrating it would recommend
what this document warns off. The suite covers both. Which members are omitted
is not a matter of habit: a test reads the public method list off
`env_file.dart` and requires each one to be either demonstrated by the example
or named in its header, so a method added later cannot go unmentioned unnoticed.

`test/cmdline_test.dart` covers the module end to end in one process:

```bash
dart test test/cmdline_test.dart     # or `testkit :test` for the whole package
```

Seven groups carry the behaviour — the two map paths and their shared conversion
table, `fillFromArgs` against a reflected fixture (including the assignments the
reflector refuses), `TomEnvFile.parse`, `merge`, the file IO, and the layering
of all three sources onto one configuration object. It needs no external server
and carries no tag, so all of it runs in the default `testkit :test`.

The two are linked in both directions — the example's header names the doc and
the suite, and the suite runs the example, under exactly the command this
section gives, requiring exit 0. A second group extracts the `dart` block under
the module readme's "Quick start" heading and runs that too, pinning the four
values its trailing comments promise. So each of this module's artefacts is
falsifiable from the suite, as are the limitations in
[Not Yet Implemented](#not-yet-implemented) above — none of them can drift
quietly while nobody is reading.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:io` | dart | `env_file.dart` | `File` reads for `TomEnvFile` |
| `tom_core_kernel` | package | `args.dart` | `tomReflectionInfo` (the reflection entry point used by `fillFromArgs`) |
