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

  // The population that happened in setUpAll is the isolate's one population.
  // This file is where a second one can be attempted at all, because every
  // other file has reached its database through a lookup and has no way to
  // offer a different one.
  group('a second population', () {
    test('is refused, naming what is loaded and what was offered', () {
      expect(
        () => TomTimezone.populateFromLocations(_oneLocation),
        throwsA(
          isA<TomTimezoneException>()
              .having(
                (e) => e.key,
                'key',
                'timezone.database.already_populated',
              )
              .having((e) => e.parameters, 'parameters', {
                'loaded': 1,
                'offered': 1,
              }),
        ),
      );
    });

    test('leaves the loaded database exactly as it was', () {
      // The refusal is the whole of it: a rejected population must not have
      // written half a database on its way out, and must not have left the
      // zones a caller already holds pointing at an index that moved.
      expect(TomTimezone.fromName('Mars/Olympus'), isNull);
      expect(TomTimezone.timezones.keys, ['UTC']);
      expect(TomTimezone.fromName('UTC'), same(TomTimezone.utc));
    });
  });
}

/// One location, so a refused population is offering something real.
final Map<String, tz.Location> _oneLocation = {
  'Mars/Olympus': tz.Location('Mars/Olympus', const [0], const [0], const [
    tz.TimeZone(Duration.zero, isDst: false, abbreviation: 'MARS'),
  ]),
};
