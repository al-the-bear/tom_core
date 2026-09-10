import 'package:test/test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A database that did not load must still report loudly.
///
/// Keeping the routine UTC message at debug level is only safe if the
/// *genuine* failure is still an ERROR, otherwise the module trades a false
/// alarm for a silent one. On a native platform the embedded IANA database always loads,
/// so that state cannot be provoked through the public entry points — which is
/// why [TomTimezone.populateFromLocations] exists: it is the same code path
/// initialization takes, with the location map passed in.
///
/// This lives in its own file because `TomTimezone`'s caches are static and
/// populate once per isolate. Driving them from an empty map has to be the
/// first thing that happens in the isolate, and every test file gets one.

/// Captures log records instead of printing them.
class _RecordingLogOutput extends TomLogOutput {
  final List<({String level, String message})> records = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    records.add((level: level.trim(), message: convertToString(message)));
  }

  Iterable<String> messagesAt(String level) =>
      records.where((r) => r.level == level).map((r) => r.message);
}

void main() {
  late _RecordingLogOutput recorder;

  setUpAll(() {
    recorder = _RecordingLogOutput();
    tomLog.logOutput = recorder;
    TomTimezone.populateFromLocations(const <String, tz.Location>{});
  });

  tearDownAll(() {
    tomLog.logOutput = TomConsoleLogOutput();
  });

  group('tccc3: an unloadable timezone database', () {
    test('tccc3-05: reports at ERROR level', () {
      expect(recorder.messagesAt('ERROR'), isNotEmpty);
    });

    test('tccc3-06: the error names the actual problem, not UTC', () {
      expect(
        recorder.messagesAt('ERROR'),
        contains(allOf(contains('empty'), contains('lookups will fail'))),
      );
    });

    test('tccc3-07: UTC is registered even so, so time still works', () {
      // The one lookup that must survive a broken database: the singleton is
      // the framework's own, not the database's.
      expect(TomTimezone.fromName('UTC'), isNotNull);
      expect(TomTimezone.fromName('Asia/Tokyo'), isNull);
    });
  });
}
