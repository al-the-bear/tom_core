# Tom Core D4rt API Reference: Registration Module

The single entry point that wires every Tom Framework bridge into a `d4rt`
interpreter. This is the one class most consumers of `tom_core_d4rt` call
directly.

## Table of contents

- [Overview](#overview)
- [Class hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomDartscriptBridges](#tomdartscriptbridges)
- [Enums](#enums)
- [Global functions and constants](#global-functions-and-constants)

## Overview

`TomDartscriptBridges` is the combined registration facade generated for this
package. Its `register` method registers, in one call, the `tom_d4rt_dcli` base
bridges plus the eleven generated `Tom*Bridge` containers (see
[`api_summary_bridges.md`](api_summary_bridges.md)) against a `D4rt`
interpreter, so a script can `import` any bridged Tom package.

- Source: `lib/dartscript.b.dart` (re-exported from
  `lib/tom_dartscript_bridges.dart`, the package barrel).

## Class hierarchy

```
Object
 └── TomDartscriptBridges   (static utility; not instantiated)
```

## Classes

### TomDartscriptBridges

Combined bridge registration for `tom_dartscript_bridges`. A static utility
class — it is never instantiated; call its static members directly.

**Constructors**

```dart
// None — TomDartscriptBridges exposes only static members.
```

**Static methods**

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register([D4rt? interpreter])` | Registers every Tom Framework bridge (dcli base bridges, the eleven generated containers, and the relaxer/generic-constructor factories) with `interpreter`. If `interpreter` is omitted a fresh `D4rt()` is created and used. |
| `getImportBlock` | `static String getImportBlock()` | Returns the concatenated `import` block covering every bridged package, ready to prepend to generated or REPL scripts. |

**Static properties**

None.

## Enums

None — this module defines no enums.

## Global functions and constants

None — this module exposes no top-level functions or constants.
