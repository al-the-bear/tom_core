import 'dart:async';

import 'tom_selectable_source.dart';

/// A [TomSelectableSource] whose item set can be replaced at runtime.
///
/// [StaticSelectableSource] answers `getItems()` from a fixed list and returns
/// `null` from [itemsStream], so a field built on it never hears about a
/// change. This source is the other half of the contract: [setItems] swaps the
/// catalogue and publishes it, and every field holding this source reloads and
/// reconciles its own value — multi-select fields drop selections that vanished,
/// single-select fields fall back to the first enabled item.
///
/// Use it wherever the options depend on something that moves: a role, a
/// selected parent record, a search term, a server push.
///
/// ```dart
/// final source = TomMutableSelectableSource<String>([
///   const SelectableItem(value: 'tech', label: 'Technology'),
///   const SelectableItem(value: 'finance', label: 'Finance'),
/// ]);
/// final field = TomFormStringChoiceChips('industry', 'tech', source: source);
///
/// // Later — the field re-renders, and resets its value if 'tech' is gone.
/// source.setItems([const SelectableItem(value: 'retail', label: 'Retail')]);
/// ```
///
/// The stream is a broadcast stream, so any number of fields may share one
/// source. Call [dispose] when the owner goes away; a disposed source still
/// answers [getItems] but refuses further [setItems] calls.
class TomMutableSelectableSource<T> extends TomSelectableSource<T> {
  List<SelectableItem<T>> _items;
  final _controller = StreamController<List<SelectableItem<T>>>.broadcast();

  TomMutableSelectableSource(List<SelectableItem<T>> initial)
    : _items = List.of(initial);

  /// The current item set.
  List<SelectableItem<T>> get items => List.unmodifiable(_items);

  /// Replaces the item set and notifies every listening field.
  ///
  /// Throws [StateError] if the source has been disposed — a swap nobody can
  /// hear is a bug at the call site, not a no-op worth swallowing.
  void setItems(List<SelectableItem<T>> next) {
    if (isDisposed) {
      throw StateError('setItems called on a disposed TomMutableSelectableSource');
    }
    _items = List.of(next);
    _controller.add(List.unmodifiable(_items));
  }

  @override
  Future<List<SelectableItem<T>>> getItems() async => List.unmodifiable(_items);

  @override
  Stream<List<SelectableItem<T>>> get itemsStream => _controller.stream;

  /// Whether [dispose] has closed the underlying broadcast controller.
  bool get isDisposed => _controller.isClosed;

  /// Closes the stream. Idempotent.
  void dispose() {
    if (!isDisposed) _controller.close();
  }
}
