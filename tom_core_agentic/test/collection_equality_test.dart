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

  group('deepValueEquals', () {
    test('two nulls are equal', () {
      expect(deepValueEquals(null, null), isTrue);
    });

    test('null and non-null are unequal', () {
      expect(deepValueEquals(null, 1), isFalse);
      expect(deepValueEquals('a', null), isFalse);
    });

    test('scalars compare with ==', () {
      expect(deepValueEquals(1, 1), isTrue);
      expect(deepValueEquals('a', 'a'), isTrue);
      expect(deepValueEquals(1, 2), isFalse);
    });

    test('nested lists compare by contents, not reference', () {
      expect(
        deepValueEquals(
          [
            1,
            [2, 3],
          ],
          [
            1,
            [2, 3],
          ],
        ),
        isTrue,
      );
      expect(
        deepValueEquals(
          [
            1,
            [2, 3],
          ],
          [
            1,
            [2, 4],
          ],
        ),
        isFalse,
      );
    });

    test('lists of differing length are unequal', () {
      expect(deepValueEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });

  group('deepValueHash', () {
    test('null hashes to 0', () {
      expect(deepValueHash(null), 0);
    });

    test('a scalar uses its own hashCode', () {
      expect(deepValueHash('a'), 'a'.hashCode);
    });

    test('equal nested values hash equal', () {
      expect(deepValueHash([1, 2, 3]), deepValueHash([1, 2, 3]));
    });

    // Bug §71: the list arm hashed elements by their own hashCode
    // (Object.hashAll(v)), so a nested List hashed by identity. Two
    // structurally-equal nested values then hashed differently even though
    // deepValueEquals reports them equal — breaking the equals/hash contract.
    // The hash must recurse like the equality does.
    test('equal nested-list values hash equal (bug §71)', () {
      final a = [
        1,
        [2, 3],
      ];
      final b = [
        1,
        [2, 3],
      ];
      // The two share the same notion of equality...
      expect(deepValueEquals(a, b), isTrue);
      // ...so they must hash equal (before §71 these differed by identity).
      expect(deepValueHash(a), deepValueHash(b));
    });

    test('deeply nested equal values hash equal (bug §71)', () {
      final a = [
        1,
        [
          2,
          [3, 4],
        ],
      ];
      final b = [
        1,
        [
          2,
          [3, 4],
        ],
      ];
      expect(deepValueEquals(a, b), isTrue);
      expect(deepValueHash(a), deepValueHash(b));
    });
  });
}
