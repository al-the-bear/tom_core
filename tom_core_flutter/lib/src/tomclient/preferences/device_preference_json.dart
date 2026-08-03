import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preferences.dart';

/// The on-disk / in-`localStorage` representation of a device's preferences.
///
/// Every persistent [TomDevicePreferenceStore] backend stores the same JSON
/// text — a file on desktop and mobile, one `localStorage` entry on the web —
/// so the encoding lives here once rather than in each backend. Two backends
/// that each wrote their own JSON would agree only by inspection, and the day
/// they diverged would be the day a preference exported from one device failed
/// to import on another.
///
/// The document is a JSON **array** of objects, each with `key`, `valueType`,
/// `value` and an optional `updatedAt`:
///
/// ```json
/// [{"key":"device.lastAccount","valueType":"String","value":"\"alex\""}]
/// ```
///
/// An array rather than an object keyed by preference key, because that is the
/// shape [TomDevicePreferenceStore] reads and writes, and because it is the
/// shape the server's `/preferences` list endpoint answers — the same text can
/// be moved between the two stores without a reshaping step in between.
///
/// The DTO is written field by field rather than through reflection: this
/// package's reflection domain is the application's, and a framework store must
/// keep working in an app whose generator never saw [TomUserPreferenceDto].
class TomDevicePreferenceJson {
  const TomDevicePreferenceJson._();

  /// Encodes [values] to the stored JSON text.
  static String encode(List<TomUserPreferenceDto> values) {
    return jsonEncode([
      for (final value in values)
        <String, Object?>{
          'key': value.key,
          'valueType': value.valueType,
          'value': value.value,
          if (value.updatedAt != null)
            'updatedAt': value.updatedAt!.toUtc().toIso8601String(),
        },
    ]);
  }

  /// Decodes [content] back into preferences.
  ///
  /// Empty or blank [content] decodes to an empty list: a crash between
  /// creating a file and writing it leaves exactly that, and treating it as
  /// empty loses nothing that was ever committed. Anything else that is not a
  /// JSON array of objects throws
  /// `device_preferences.store.invalid_content` — [source] only names the
  /// backend in the failure.
  static List<TomUserPreferenceDto> decode(
    String content, {
    String source = '',
  }) {
    if (content.trim().isEmpty) return [];

    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (error, stack) {
      throw TomDevicePreferenceException(
        'device_preferences.store.invalid_content',
        'The device preference store $source does not contain valid JSON.',
        parameters: {'source': source},
        rootException: error,
        stack: stack,
      );
    }
    if (decoded is! List) {
      throw TomDevicePreferenceException(
        'device_preferences.store.invalid_content',
        'The device preference store $source must contain a JSON array, but '
            'holds a ${decoded.runtimeType}.',
        parameters: {'source': source},
      );
    }

    final values = <TomUserPreferenceDto>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        throw TomDevicePreferenceException(
          'device_preferences.store.invalid_content',
          'The device preference store $source holds an entry that is not a '
              'JSON object.',
          parameters: {'source': source},
        );
      }
      final updatedAt = entry['updatedAt'];
      values.add(
        TomUserPreferenceDto(
          key: '${entry['key'] ?? ''}',
          valueType: '${entry['valueType'] ?? ''}',
          value: '${entry['value'] ?? ''}',
          updatedAt: updatedAt is String
              ? DateTime.parse(updatedAt).toUtc()
              : null,
        ),
      );
    }
    return values;
  }
}
