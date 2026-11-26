import 'package:test/test.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

void main() {
  group('DartSource', () {
    test('finds literals of every form with their values and lines', () {
      final source = DartSource.parse(r"""
final a = 'one';
final b = "two\n";
final c = r'raw\n';
final d = '''three
lines''';
final e = 'it\'s';
""");
      expect(source.literals.map((l) => l.value), [
        'one',
        'two\n',
        r'raw\n',
        'three\nlines',
        "it's",
      ]);
      expect(source.literals.map((l) => l.line), [1, 2, 3, 4, 6]);
    });

    test('blanks comments and literals in the masked code, offsets kept', () {
      const text = "f('x'); // tomId: 'y'\n/* tomId: 'z' */ g();";
      final source = DartSource.parse(text);
      expect(source.masked.length, text.length);
      expect(source.masked.contains('tomId'), isFalse);
      expect(source.masked.contains('x'), isFalse);
      expect(source.masked.contains('f('), isTrue);
      expect(source.masked.contains('g()'), isTrue);
      expect(source.literals.map((l) => l.value), ['x']);
    });

    test('marks interpolations and lists literals inside them', () {
      final source = DartSource.parse(
        r"""final s = 'a $b ${c ? 'Yes' : 'No'} d';""",
      );
      final mark = DartStringLiteral.interpolationMark;
      expect(source.literals.first.value, 'a $mark $mark d');
      expect(source.literals.first.interpolated, isTrue);
      expect(source.literals.skip(1).map((l) => l.value), ['Yes', 'No']);
      expect(
        source.literalAround(source.literals[1].start)!.start,
        source.literals.first.start,
      );
    });

    test('names the call a literal is an argument of', () {
      final source = DartSource.parse(
        "x(StateError('a'), tomLog.warn('b'), foo([bar('c')]), "
        "List<String>.of(['d']));\nfinal e = 'e';",
      );
      String? callOf(String value) => source.enclosingCall(
        source.literals.firstWhere((l) => l.value == value).start,
      );
      expect(callOf('a'), 'StateError');
      expect(callOf('b'), 'tomLog.warn');
      expect(callOf('c'), 'bar');
      expect(callOf('d'), 'List.of');
      expect(callOf('e'), isNull);
    });
  });
}
