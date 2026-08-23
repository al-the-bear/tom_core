/// Reports what a delegation's validity window becomes on the way to and from a
/// `DATETIME` column, under whatever zone `TZ` forces on this process.
///
/// Run as a child process by `principal_delegation_test.dart` with `TZ` set to
/// two zones far apart. The detour exists because the defect it pins — a
/// security window stored as the *writer's* wall clock — is **unobservable in a
/// single process**: whatever zone that process is in, it writes and reads the
/// column through the same offset, so the round trip closes and an in-process
/// assertion is green whether or not two nodes would agree. The whole question
/// is what happens when the writer and the reader disagree about the zone, and
/// only a second process in a second zone can ask it.
///
/// Prints four fields separated by `|` on one line:
///
/// 1. the local UTC offset in hours, so the parent can confirm `TZ` actually
///    took effect before believing anything else the probe says;
/// 2. the characters [probeInstant] binds as — the text the server would store;
/// 3. the instant the *canonical* stored text reads back as, in ISO-8601 —
///    isolating the read from this process's own write;
/// 4. `utc` or `local`, the flag on that read-back value.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

/// The window bound every run is pinned to: late on 11 August, UTC.
///
/// Chosen so that a host far east of UTC has already turned over to the 12th
/// while a host far west is still on the 11th — the calendars disagree, which
/// is what makes a wall-clock store detectable at all.
final DateTime probeInstant = DateTime.utc(2026, 8, 11, 23, 30);

/// The characters [probeInstant] *should* occupy in the column, on every node.
///
/// Spelled out rather than computed so the probe cannot agree with a broken
/// implementation by sharing its arithmetic.
const String canonicalStoredText = '2026-08-11 23:30:00.000000';

Future<void> main() async {
  final delegation = TomPrincipalDelegation(
    delegatorId: 'a',
    delegateId: 'b',
    mode: 'absence',
    validFrom: probeInstant,
  );

  // The write side, exactly as the repository reaches it: the column's
  // converter hands the datasource a boxed value, and the bind boundary
  // marshals the box into what the driver sends.
  final bound = MariadbPreparedStatement.buildPositionalParameters(
    ['valid_from'],
    {'valid_from': TomDbDateTime(delegation.validFrom)},
  ).single;

  // The read side, isolated from this process's own write: parse the text a
  // *correct* writer leaves behind, whatever zone this process is in.
  final readBack = TomDbDateTime.of(canonicalStoredText).get()!;

  final offset = probeInstant.toLocal().timeZoneOffset.inHours;
  stdout.write(
    '$offset|$bound|${readBack.toIso8601String()}|'
    '${readBack.isUtc ? 'utc' : 'local'}',
  );
}
