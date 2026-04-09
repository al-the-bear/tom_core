import 'tom_selectable_source.dart';

/// A [TomSelectableSource] backed by a fixed list of items.
class StaticSelectableSource<T> extends TomSelectableSource<T> {
  final List<SelectableItem<T>> _items;

  StaticSelectableSource(this._items);

  @override
  Future<List<SelectableItem<T>>> getItems() async =>
      List.unmodifiable(_items);

  @override
  Stream<List<SelectableItem<T>>>? get itemsStream => null;
}
