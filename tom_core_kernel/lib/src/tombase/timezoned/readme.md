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
| `TomTimezone` | A named IANA zone; `TomTimezone.utc`, `TomTimezone.fromName('Asia/Tokyo')`. |
| `TomTimezoned` | `DateTime` with an attached zone; base for the variants below. |
| `TomZonedDate` | Date-only zoned value. |
| `TomZonedTime` | Time-only zoned value. |
| `TomZonedDateTime` | Full zoned date-and-time value. |
| `TomTimezoneException` | Thrown on unknown zones / parse failures. |

> On native (VM / Flutter) the timezone database loads **synchronously on first
> access** from the embedded IANA data — no startup call is required. On the
> **web** the data is fetched over the network, so `await tomSetupTimezones()`
> during startup is mandatory; a first access without it throws rather than
> resolving to an empty database.

## Quick start

```dart
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

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
