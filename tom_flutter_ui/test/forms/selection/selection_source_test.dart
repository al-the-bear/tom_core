import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('SelectableItem', () {
    test('stores value, label, description, enabled', () {
      const item = SelectableItem(
        value: 42,
        label: 'Forty-Two',
        description: 'The answer',
        enabled: false,
      );

      expect(item.value, 42);
      expect(item.label, 'Forty-Two');
      expect(item.description, 'The answer');
      expect(item.enabled, false);
    });

    test('enabled defaults to true', () {
      const item = SelectableItem(value: 1, label: 'One');
      expect(item.enabled, true);
    });

    test('description defaults to null', () {
      const item = SelectableItem(value: 1, label: 'One');
      expect(item.description, isNull);
    });

    test('equality based on value', () {
      const a = SelectableItem(value: 1, label: 'One');
      const b = SelectableItem(value: 1, label: 'Different Label');
      const c = SelectableItem(value: 2, label: 'One');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode based on value', () {
      const a = SelectableItem(value: 1, label: 'One');
      const b = SelectableItem(value: 1, label: 'Other');

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString provides readable representation', () {
      const item = SelectableItem(value: 1, label: 'One');
      expect(item.toString(), contains('One'));
      expect(item.toString(), contains('1'));
    });

    test('toString indicates disabled state', () {
      const item = SelectableItem(value: 1, label: 'One', enabled: false);
      expect(item.toString(), contains('disabled'));
    });
  });

  group('StaticSelectableSource', () {
    test('returns all items', () async {
      final source = StaticSelectableSource([
        const SelectableItem(value: 'a', label: 'Alpha'),
        const SelectableItem(value: 'b', label: 'Beta'),
        const SelectableItem(value: 'c', label: 'Charlie'),
      ]);

      final items = await source.getItems();
      expect(items, hasLength(3));
      expect(items[0].value, 'a');
      expect(items[1].value, 'b');
      expect(items[2].value, 'c');
    });

    test('returns unmodifiable list', () async {
      final source = StaticSelectableSource([
        const SelectableItem(value: 1, label: 'One'),
      ]);

      final items = await source.getItems();
      expect(
        () => items.add(const SelectableItem(value: 2, label: 'Two')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('returns empty list for empty source', () async {
      final source = StaticSelectableSource<String>([]);
      final items = await source.getItems();
      expect(items, isEmpty);
    });

    test('itemsStream is null (static source)', () {
      final source = StaticSelectableSource([
        const SelectableItem(value: 1, label: 'One'),
      ]);

      expect(source.itemsStream, isNull);
    });
  });
}
