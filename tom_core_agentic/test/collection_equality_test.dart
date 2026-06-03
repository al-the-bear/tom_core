import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('mapEquals', () {
    test('identical references are equal', () {
      final m = {'a': 1};
      expect(mapEquals(m, m), isTrue);
    });

    test('same keys and values are equal regardless of order', () {
      expect(mapEquals({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isTrue);
    });

    test('differing length is unequal', () {
      expect(mapEquals({'a': 1}, {'a': 1, 'b': 2}), isFalse);
    });

    test('same length, differing key is unequal', () {
      expect(mapEquals({'a': 1}, {'b': 1}), isFalse);
    });

    test('same key, differing value is unequal', () {
      expect(mapEquals({'a': 1}, {'a': 2}), isFalse);
    });

    test('null value is matched, not treated as absent', () {
      expect(mapEquals<String, Object?>({'a': null}, {'a': null}), isTrue);
      expect(mapEquals<String, Object?>({'a': null}, {'b': null}), isFalse);
    });

    test('two empty maps are equal', () {
      expect(mapEquals(<String, int>{}, <String, int>{}), isTrue);
    });
  });

  group('setEquals', () {
    test('identical references are equal', () {
      final s = {1, 2};
      expect(setEquals(s, s), isTrue);
    });

    test('same members are equal regardless of order', () {
      expect(setEquals({1, 2, 3}, {3, 2, 1}), isTrue);
    });

    test('differing length is unequal', () {
      expect(setEquals({1}, {1, 2}), isFalse);
    });

    test('same length, differing member is unequal', () {
      expect(setEquals({1, 2}, {1, 3}), isFalse);
    });
  });

  group('listEquals', () {
    test('identical references are equal', () {
      final l = [1, 2];
      expect(listEquals(l, l), isTrue);
    });

    test('same elements in same order are equal', () {
      expect(listEquals([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('order matters', () {
      expect(listEquals([1, 2, 3], [3, 2, 1]), isFalse);
    });

    test('differing length is unequal', () {
      expect(listEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });
}
