import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preferences.dart';
import 'reflection_readiness.dart';

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
/// **The DTO is encoded through reflection**, like every other Tom type and
/// like the account half of this module. Reflection setup is a precondition of
/// the framework rather than a favour the application does it: every entrypoint
/// runs `reflection_generator`, and the generated seed covers the whole
/// dependency closure — framework types included. A store that hand-wrote this
/// one document would be keeping a second encoding of a DTO the package already
/// encodes elsewhere, on the theory that the seed might not cover it.
///
/// What is *not* delegated is the timestamp rule. `updatedAt` is validated here,
/// before the entry reaches reflection, because reflection parses a `DateTime`
/// with `DateTime.parse` — which reads a stamp naming no zone as **this**
/// device's local time, the one clock certainly not the writer's. Encoding is
/// safe either way: reflection normalises a `DateTime` to UTC on the way out.
class TomDevicePreferenceJson {
  const TomDevicePreferenceJson._();

  /// Encodes [values] to the stored JSON text.
  ///
  /// Through [TomReflectionInfo.convertToJsonString], which takes a list as
  /// readily as a single object and normalises every `DateTime` to UTC — so the
  /// document this writes always names its zone, which is what [decode] on
  /// another device requires.
  ///
  /// Throws `device_preferences.store.reflection_not_initialised` when the
  /// application never called `initializeReflection()`. That is a configuration
  /// fault of the program, not of the store, and saying so is the difference
  /// between a one-line fix and an afternoon spent inspecting a file that is
  /// intact.
  static String encode(List<TomUserPreferenceDto> values) {
    try {
      return tomReflectionInfo.convertToJsonString(values);
    } catch (error, stack) {
      if (isReflectionUninitialised(error)) throw _uninitialised(error, stack);
      rethrow;
    }
  }

  /// The failure raised when reflection was never initialised.
  static TomDevicePreferenceException _uninitialised(
    Object error,
    StackTrace stack,
  ) => TomDevicePreferenceException(
    'device_preferences.store.reflection_not_initialised',
    'Device preferences are encoded through reflection, and this application '
        'never called initializeReflection(). Call it as the first action in '
        'main().',
    rootException: error,
    stack: stack,
  );

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
      final DateTime? parsedUpdatedAt;
      if (updatedAt is String) {
        // [encode] always writes a `Z`, but this document is meant to travel
        // between devices, so the reader cannot assume it wrote it. A timestamp
        // with no zone would be read as *this* device's local time — the one
        // device whose clock is certainly not the one that wrote it.
        parsedUpdatedAt = TomUserPreferenceCodec.parseInstant(updatedAt);
        if (parsedUpdatedAt == null) {
          throw TomDevicePreferenceException(
            'device_preferences.store.invalid_content',
            'The device preference store $source holds an entry whose '
                'updatedAt is not a timestamp naming its time zone.',
            parameters: {'source': source, 'updatedAt': updatedAt},
          );
        }
      } else {
        parsedUpdatedAt = null;
      }
      values.add(_toDto(entry, source: source));
    }
    return values;
  }

  /// Builds one DTO from a decoded JSON object, through reflection.
  ///
  /// The `updatedAt` check above has already run, so what reaches here is a
  /// document this module is willing to read; reflection's job is the field
  /// mapping, which is the part that would otherwise be written twice in one
  /// package.
  static TomUserPreferenceDto _toDto(Map entry, {required String source}) {
    try {
      final mirror = tomReflector.reflectType(TomUserPreferenceDto);
      if (mirror is! ClassMirror) {
        throw TomDevicePreferenceException(
          'device_preferences.store.invalid_content',
          'The device preference store $source cannot be read: '
              'TomUserPreferenceDto is not reflectable.',
          parameters: {'source': source},
        );
      }
      return tomReflectionInfo.createInstanceFromJson<TomUserPreferenceDto>(
        mirror,
        // `jsonDecode` answers `Map<String, dynamic>` for an object; the
        // signature above is `Map`, so the re-typing happens here rather than
        // by casting the decoded document and losing the shape check that
        // produced the `invalid_content` failures.
        <String, Object?>{
          for (final pair in entry.entries) '${pair.key}': pair.value,
        },
      );
    } on TomDevicePreferenceException {
      rethrow;
    } catch (error, stack) {
      if (isReflectionUninitialised(error)) throw _uninitialised(error, stack);
      throw TomDevicePreferenceException(
        'device_preferences.store.invalid_content',
        'The device preference store $source holds an entry that cannot be '
            'read as a preference.',
        parameters: {'source': source},
        rootException: error,
        stack: stack,
      );
    }
  }
}
