import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Synchronous lazy initialization without a manual preload.
///
/// This file deliberately does **not** call `tz_data.initializeTimeZones()`
/// in a `setUpAll`. Each test file runs in its own isolate, so the timezone
/// database and `TomTimezone`'s static cache start empty here. The fixed
/// `_initialize()` must load the embedded database synchronously on first
/// access (option (a) from `status_questions.md`), so lookups succeed
/// immediately with no manual initialization and no async re-entry error.
void main() {
  group('TomTimezone lazy synchronous init', () {
    test('fromName resolves a zone without any manual preload', () {
      final tokyo = TomTimezone.fromName('Asia/Tokyo');
      expect(tokyo, isNotNull);
      expect(tokyo!.timezone, equals('Asia/Tokyo'));
    });

    test('timezones map is populated on first access', () {
      final timezones = TomTimezone.timezones;
      expect(timezones.length, greaterThan(100));
      expect(timezones.containsKey('UTC'), isTrue);
      expect(timezones.containsKey('EUROPE/LONDON'), isTrue);
    });

    test('repeated access does not throw a re-entry error', () {
      expect(() => TomTimezone.fromName('Europe/Berlin'), returnsNormally);
      expect(() => TomTimezone.fromName('America/New_York'), returnsNormally);
      expect(() => TomTimezone.timezones, returnsNormally);
    });
  });
}
