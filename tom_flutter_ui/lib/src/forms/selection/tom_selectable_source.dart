/// A single item that can be selected from a [TomSelectableSource].
class TomSelectableItem<T> {
  final T value;
  final String label;
  final String? description;
  final bool enabled;

  const TomSelectableItem({
    required this.value,
    required this.label,
    this.description,
    this.enabled = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TomSelectableItem<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      'TomSelectableItem($label: $value${!enabled ? ', disabled' : ''})';
}

/// Abstract source of selectable items for selection-based form fields.
///
/// Provides both a one-shot [getItems] and an optional [itemsStream]
/// for sources that update over time.
abstract class TomSelectableSource<T> {
  /// Fetches the current list of selectable items.
  Future<List<TomSelectableItem<T>>> getItems();

  /// Optional stream of item updates. Returns `null` if the source is static.
  Stream<List<TomSelectableItem<T>>>? get itemsStream => null;
}
