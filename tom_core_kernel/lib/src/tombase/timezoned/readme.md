# timezoned

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Timezone-aware date/time types built on the `timezone` database. `TomTimezoned`
extends `DateTime` with an attached `TomTimezone`; `TomZonedDate`,
`TomZonedTime`, and `TomZonedDateTime` carve out the date-only, time-only, and
full variants used by the observable date/time cells.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTimezone` | A named IANA zone; `TomTimezone.utc`, `TomTimezone.fromName('Asia/Tokyo')` — `null` for a name the database does not hold. |
| `TomTimezoned` | `DateTime` with an attached zone; base for the variants below, and the supertype to hold one at. Declares no conversion — see [Conversion](#conversion). |
| `TomZonedDate` | Date-only zoned value. |
| `TomZonedTime` | Time-only zoned value. |
| `TomZonedDateTime` | Full zoned date-and-time value. |
| `TomTimezoneException` | Thrown by `findTimezone`, the strict lookup, and by nothing else: for a name that is not in the database, or one whose current offset does not match a value supplied alongside it. Parsing fails with `FormatException` — see [Failures](#failures). |

> On native (VM / Flutter) the timezone database loads **synchronously on first
> access** from the embedded IANA data — no startup call is required. On the
> **web** the data is fetched over the network, so `await tomSetupTimezones()`
> during startup is mandatory; a first access without it throws `StateError`
> rather than resolving to an empty database. `tomSetupTimezones` is exported
> from the package barrel alongside the types below, and is harmless on native
> — see [Initialization](../../../../doc/timezoned/timezoned.md#initialization).

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final tokyo = TomTimezone.fromName('Asia/Tokyo');
  print(tokyo?.timezone); // Asia/Tokyo

  final meeting = TomZonedDateTime(
    year: 2026, month: 6, day: 16, hour: 9,
    timezone: tokyo,
  );
  print(meeting.year); // 2026
}
```

## Conversion

Conversion is declared on the three variants and **not** on `TomTimezoned`, so
a value from `TomTimezoned.now()`, `TomTimezoned.parseFromString(...)` or the
default factory cannot be converted at that type — the call does not compile.

That is a decision. Dart permits an override to narrow its return type, so a
hoisted declaration would compile; what rules it out is that the variants do
not offer the same set. A date has `convertToTzSameInstant` and
`convertToTzSameDate`, a time has `convertToTzSameInstant` and
`convertToTzSameTime`, and a datetime has only `convertToTzSameInstant` because
it already names an instant. The one method common to all three is the wrong
default for two of them, and hoisting it would apply that default to any value
whose kind the caller has not established — silently, since it would compile.

Rebuild first; it is one line:

```dart
final base = TomTimezoned.now();
TomZonedDateTime.fromDateTime(base, base.timezone).convertToTzSameInstant(zone);
```

## Failures

Which failure a caller sees depends on the entry point rather than on the
mistake. `fromName('Mars/Olympus')` returns `null`, while `findTimezone` throws
`TomTimezoneException` for a name that is not in the database — with or without
an offset supplied to disagree with — and for a name that is there but whose
current offset does not match one that was. Ask with `fromName` when a zone's
absence is an answer, with `findTimezone` when it is a fault.

Parsing refuses differently again: `parseFromString`, on all three variants,
throws `FormatException` and never `TomTimezoneException` — both for a string
that is not in the serialized form and for one naming a zone the database does
not hold. An unknown zone is a parse failure rather than a silent substitution,
because the value would otherwise carry UTC while claiming a zone it never had.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
