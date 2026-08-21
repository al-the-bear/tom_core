/// Reports the file name [TomFileAuditSink] chooses for a fixed instant.
///
/// Run as a child process by `audit_test.dart` with `TZ` forced to a zone far
/// from UTC. That detour exists because the defect this pins — naming files by
/// the host's local calendar rather than the UTC calendar the records carry —
/// is **unobservable in a process whose zone is UTC**, which is what CI runners
/// usually are. An in-process test would therefore assert nothing on the one
/// machine that gates the merge, and would look green while doing it.
///
/// Prints `<local-utc-offset-in-hours>|<file name>` on one line so the parent
/// can check that the forced zone actually took effect before believing the
/// name it reports.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';

/// The instant every run is pinned to: late on 11 August, UTC.
///
/// Chosen so that a host east of UTC has already turned over to the 12th while
/// UTC has not — the whole discrimination the probe exists for.
final DateTime probeInstant = DateTime.utc(2026, 8, 11, 23, 30);

Future<void> main() async {
  final directory = Directory.systemTemp.createTempSync('tom_audit_tz_probe_');
  try {
    final sink = TomFileAuditSink(
      directory: directory,
      // `toLocal()` is the point: the sink is handed a local-flavoured
      // `DateTime`, exactly as the default `DateTime.now` would give it.
      clock: () => probeInstant.toLocal(),
    );
    await sink.write(
      TomAuditRecord(
        id: 'probe',
        timestamp: probeInstant,
        actor: TomAuditActor.system,
        action: TomAuditAction.update,
        target: 'Widget',
        outcome: TomAuditOutcome.succeeded,
      ),
    );
    sink.close();
    final offset = probeInstant.toLocal().timeZoneOffset.inHours;
    stdout.write('$offset|${p.basename(sink.files.single.path)}');
  } finally {
    directory.deleteSync(recursive: true);
  }
}
