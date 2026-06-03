import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('HttpDate.parse', () {
    test('parses RFC 1123 format to UTC', () {
      final d = HttpDate.parse('Wed, 21 Oct 2026 07:28:00 GMT');
      expect(d, DateTime.utc(2026, 10, 21, 7, 28, 0));
      expect(d.isUtc, isTrue);
    });

    test('parses RFC 850 format (2-digit year, dash-separated)', () {
      final d = HttpDate.parse('Wednesday, 21-Oct-26 07:28:00 GMT');
      expect(d, DateTime.utc(2026, 10, 21, 7, 28, 0));
    });

    test('parses asctime format', () {
      final d = HttpDate.parse('Wed Oct 21 07:28:00 2026');
      expect(d, DateTime.utc(2026, 10, 21, 7, 28, 0));
    });

    test('tolerates surrounding whitespace', () {
      final d = HttpDate.parse('  Wed, 21 Oct 2026 07:28:00 GMT  ');
      expect(d, DateTime.utc(2026, 10, 21, 7, 28, 0));
    });

    test('throws FormatException on an unknown month', () {
      expect(
        () => HttpDate.parse('Wed, 21 Zzz 2026 07:28:00 GMT'),
        throwsFormatException,
      );
    });

    test('throws FormatException on a malformed date', () {
      expect(() => HttpDate.parse('not-a-date'), throwsFormatException);
    });
  });
}
