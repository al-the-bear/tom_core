import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Initialization must not report routine setup as a failure.
///
/// `package:timezone`'s bundled IANA database has no location keyed exactly
/// `UTC` — it ships `Etc/UTC` — while [TomTimezone.utc] is a documented
/// singleton and `fromName('UTC')` is expected to resolve. `TomTimezone`
/// therefore registers the singleton itself, which is correct and intended —
/// but announcing it with `tomLog.error` would not be. That branch is not
/// intermittent: it fires on every run, on every platform, forever, for a
/// state the code fully anticipates and repairs. An ERROR line that is always
/// there teaches a team to filter out ERROR.
///
/// These tests pin the outcome rather than the wording: no ERROR-level record
/// during a healthy initialization, the UTC registration still happening, and
/// the fact still being discoverable at debug level.
///
/// The whole file shares one initialization because `TomTimezone`'s caches are
/// static and populate exactly once per isolate — and every test file gets its
/// own isolate, so installing the recorder in `setUpAll` really does capture
/// the first access.

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
    // The first access, and the only one that populates the caches.
    TomTimezone.timezones;
  });

  tearDownAll(() {
    tomLog.logOutput = TomConsoleLogOutput();
  });

  group('tccc3: timezone initialization logging', () {
    test('tccc3-01: a healthy initialization emits no ERROR-level record', () {
      expect(recorder.messagesAt('ERROR'), isEmpty);
    });

    test('tccc3-02: the UTC singleton is still registered', () {
      final utc = TomTimezone.fromName('UTC');
      expect(utc, isNotNull);
      expect(utc!.timezone, equals('UTC'));
      expect(utc.timezoneOffsetMin, equals(0));
      expect(identical(utc, TomTimezone.utc), isTrue);
    });

    test('tccc3-03: the registration is still announced, at debug level', () {
      expect(
        recorder.messagesAt('DEBUG'),
        contains(allOf(contains('UTC'), contains('Etc/UTC'))),
      );
    });

    test(
      'tccc3-04: the database itself loaded, so no failure was reported',
      () {
        // Guards the loud branch against firing on a normal run: an ERROR here
        // would mean "no locations loaded", which plainly is not the case.
        expect(TomTimezone.timezones.length, greaterThan(100));
      },
    );
  });
}
