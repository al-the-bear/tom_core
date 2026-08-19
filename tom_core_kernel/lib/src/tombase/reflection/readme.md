# reflection

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).
>
> The reflection layer derives from the **`reflectable`** package; see the
> [`tom_reflection`](../../../../../../reflection/tom_reflection/README.md)
> lineage for the full attribution and the derivation notes.

Build-time reflection for the kernel, and the JSON converter built on it.
`TomReflector` is the capability used to mark types as reflectable; the
generated mirrors let `TomReflectionInfo` create instances, populate their
fields from a map or JSON string, and read them back out — without
`dart:mirrors`.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomReflector` | The reflection capability; annotate types with `@tomReflector` to make them reflectable. |
| `TomReflectionInfo` | The converter: `createInstance`, `setValues`, `getValues`, `convertToJsonString`, `convertFromJsonString`, plus collection element-type resolution. |
| `TomReflectorException` | Thrown when a type is not reflectable, a mirror lookup is ambiguous, or a value cannot be materialized onto a field. |

Two globals are exported: `tomReflector` (the annotation) and
`tomReflectionInfo` (the shared converter instance).

> Reflection metadata is produced by the
> [`tom_reflection_generator`](../../../../../../reflection/tom_reflection_generator/README.md)
> build step — annotate, run the generator, then reflect.

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Mark a domain type as reflectable; the generator emits its mirror.
// Fields must be non-final, non-static, non-private, and initialised.
@tomReflector
class TodoItem {
  String title = '';
  bool done = false;
}

void main() {
  initializeReflection(); // from the generated *.reflection.dart

  final item = tomReflectionInfo.createInstance<TodoItem>();
  tomReflectionInfo.setValues(item, {'title': 'Write docs', 'done': false});

  print(tomReflectionInfo.convertToJsonString(item));
  // {"title":"Write docs","done":false}
}
```

Every entry point insists the target class carries `@tomReflector`. Passing a
`String`, an `int`, a `DateTime`, a `List` or a plain `Map` raises
`reflector.type.not_annotated` rather than doing nothing: those types have
mirror data only because they appear as *field types* of annotated classes, so
they reflect successfully and then present no settable fields — `getValues`
used to return `{}` and `convertToJsonString` the string `"{}"`, a
valid-looking payload with every field dropped. A class with no generated data
at all still raises `reflector.reflect.not_reflectable`; both are
`TomReflectorException`, so one `catch` covers either.

A string that will not parse into a `DateTime`, `TomZonedDate`,
`TomZonedTime` or `TomZonedDateTime` field raises
`reflection.set.date_parse_failed`, naming the class, the field and the text
that failed — and the map key or list index when the field is a collection.
The parsers themselves throw a bare `FormatException` that reports only the
offending text; letting it out told a caller deserializing a thirty-field
payload that *something* in it was not a date, kept the failure out of the
module's auto-logging, and slipped past `on TomReflectorException`. The
original `FormatException` is retained as the `rootException`.

A class may take conversion over from the field walk with any of three
optional hooks: a `fromJson` constructor (used by `createInstanceFromJson`), a
`jsonDecode` method (used by `setValues`), or a `jsonEncode` getter (used by
`getValues`). Each is looked up before it is called, so **declaring no hook
still falls back silently, while a hook that exists and throws propagates** as
`reflection.hook.failed`, naming the hook and the class and keeping the
original error as `rootException`. The lookups used to be the *call itself*
inside an unqualified `catch`, which made the two cases one: a bug in a
caller's own `fromJson` was swallowed and the object rebuilt by the fallback
path, and a throwing `jsonDecode` or `jsonEncode` produced no error at all —
the custom representation was simply not used. A hook that returns something
unusable — a `jsonEncode` that is not a `Map<String, Object?>` — raises
`reflection.hook.invalid_return` rather than being ignored.

Collection fields are deserialized **atomically**: a `List<T>` or
`Map<String, T>` is materialized in full before the field is touched, so an
element the target type rejects throws a `TomReflectorException` and leaves the
field's previous content intact.

Collections nest **one level deep**: the element type of a `List<T>` or a
`Map<String, T>` must be a primitive, a date/time type, or an annotated class —
not another collection. `List<List<String>>` and `Map<String, List<Address>>`
raise `reflector.type_resolution.nested_generic_unsupported`, which names the
declaration and the argument that is generic. Give the inner collection a class
of its own to carry the extra level.

This holds for collections of primitives as much as for collections of
annotated objects — every element is checked at `setValues`, and the exception
names the field, the position and the offending value. The one deliberate
exception is a whole-number `int` bound for a `double` collection: JSON has no
int/double distinction, so `[1, 2]` for a `List<double>` is widened rather than
refused, exactly as it is for a scalar `double` field.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
