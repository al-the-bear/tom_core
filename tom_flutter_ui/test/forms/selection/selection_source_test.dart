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

  group('TomMutableSelectableSource', () {
    TomMutableSelectableSource<String> newSource() {
      final source = TomMutableSelectableSource<String>([
        const SelectableItem(value: 'a', label: 'Alpha'),
        const SelectableItem(value: 'b', label: 'Beta'),
      ]);
      addTearDown(source.dispose);
      return source;
    }

    test('starts with the initial items', () async {
      final source = newSource();

      expect(source.items.map((i) => i.value), ['a', 'b']);
      expect((await source.getItems()).map((i) => i.value), ['a', 'b']);
    });

    test('copies the initial list, so the caller cannot mutate it behind '
        'the source', () async {
      final initial = [const SelectableItem(value: 'a', label: 'Alpha')];
      final source = TomMutableSelectableSource<String>(initial);
      addTearDown(source.dispose);

      initial.add(const SelectableItem(value: 'b', label: 'Beta'));

      expect(source.items, hasLength(1));
    });

    test('setItems replaces the catalogue', () async {
      final source = newSource();

      source.setItems([const SelectableItem(value: 'c', label: 'Charlie')]);

      expect(source.items.map((i) => i.value), ['c']);
      expect((await source.getItems()).map((i) => i.value), ['c']);
    });

    test('setItems publishes the new catalogue on itemsStream', () async {
      final source = newSource();
      final seen = <List<String>>[];
      final sub = source.itemsStream.listen(
        (items) => seen.add(items.map((i) => i.value).toList()),
      );
      addTearDown(sub.cancel);

      source.setItems([const SelectableItem(value: 'c', label: 'Charlie')]);
      source.setItems([const SelectableItem(value: 'd', label: 'Delta')]);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        ['c'],
        ['d'],
      ]);
    });

    test('the stream is broadcast, so several fields may share one source', () {
      final source = newSource();

      final first = source.itemsStream.listen((_) {});
      final second = source.itemsStream.listen((_) {});
      addTearDown(first.cancel);
      addTearDown(second.cancel);

      // A single-subscription stream would have thrown on the second listen.
      expect(source.isDisposed, isFalse);
    });

    test('items and getItems return unmodifiable lists', () async {
      final source = newSource();
      const extra = SelectableItem(value: 'z', label: 'Zulu');

      expect(() => source.items.add(extra), throwsUnsupportedError);
      expect(
        () async => (await source.getItems()).add(extra),
        throwsUnsupportedError,
      );
    });

    test('dispose is idempotent', () {
      final source = newSource();

      source.dispose();
      expect(source.isDisposed, isTrue);
      expect(source.dispose, returnsNormally);
    });

    test('a disposed source still answers getItems', () async {
      final source = newSource();
      source.dispose();

      expect((await source.getItems()).map((i) => i.value), ['a', 'b']);
    });

    test('setItems after dispose throws — a swap nobody can hear is a bug at '
        'the call site', () {
      final source = newSource();
      source.dispose();

      expect(
        () => source.setItems(const [SelectableItem(value: 'c', label: 'C')]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
