/// A single item that can be selected from a [TomSelectableSource].
class SelectableItem<T> {
  final T value;
  final String label;
  final String? description;
  final bool enabled;

  const SelectableItem({
    required this.value,
    required this.label,
    this.description,
    this.enabled = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectableItem<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      'SelectableItem($label: $value${!enabled ? ', disabled' : ''})';
}

/// Abstract source of selectable items for selection-based form fields.
///
/// Provides both a one-shot [getItems] and an optional [itemsStream]
/// for sources that update over time.
abstract class TomSelectableSource<T> {
  /// Fetches the current list of selectable items.
  Future<List<SelectableItem<T>>> getItems();

  /// Optional stream of item updates. Returns `null` if the source is static.
  Stream<List<SelectableItem<T>>>? get itemsStream => null;
}
