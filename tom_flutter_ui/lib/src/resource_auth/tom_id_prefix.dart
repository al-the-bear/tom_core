/// ID prefix constants and canonical path utilities for the Tom UI identity
/// system.
///
/// Every widget, container, form, and action can carry a unique ID. The ID is
/// automatically prefixed at resolution time to make paths unambiguous.
class TomIdPrefix {
  TomIdPrefix._();

  static const route = 'r-';
  static const container = 'c-';
  static const row = 'rw-';
  static const form = 'f-';
  static const widget = 'w-';
  static const action = 'a-';
  static const controller = 'ac-';
  static const group = 'g-';

  /// Builds a canonical path by joining non-null segments with '.'.
  static String buildPath(List<String?> segments) {
    return segments.whereType<String>().join('.');
  }

  /// Prefixes a raw ID with the appropriate scope prefix.
  static String prefixed(String prefix, String id) => '$prefix$id';
}
