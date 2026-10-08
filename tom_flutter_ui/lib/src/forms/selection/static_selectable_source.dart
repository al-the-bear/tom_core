import 'tom_selectable_source.dart';

/// A [TomSelectableSource] backed by a fixed list of items.
class TomStaticSelectableSource<T> extends TomSelectableSource<T> {
  final List<TomSelectableItem<T>> _items;

  TomStaticSelectableSource(this._items);

  @override
  Future<List<TomSelectableItem<T>>> getItems() async =>
      List.unmodifiable(_items);

  @override
  Stream<List<TomSelectableItem<T>>>? get itemsStream => null;
}
