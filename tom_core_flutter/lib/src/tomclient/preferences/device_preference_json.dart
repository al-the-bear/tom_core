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
/// ## The owned shape
///
/// A store told who it belongs to writes the array inside an envelope instead:
///
/// ```json
/// {"owner":"alex","preferences":[{"key":"device.lastAccount", …}]}
/// ```
///
/// [decode] reads both, and that is the point of having two: the bare array is
/// the interchange shape and stays exactly the server's, so an application that
/// never names an owner is unaffected and the "same text, both stores" property
/// holds where it was argued for. The envelope appears only where an owner was
/// asked for, and it exists to make one mistake loud — a device store shared by
/// two accounts, which otherwise serves the previous user's last-used account
/// and biometric flag to the current one, on a screen that looks entirely
/// normal.
///
/// **The owner must match exactly, and absent is a value.** A document with no
/// owner read by a store that has one is a mismatch, as is the reverse: the
/// unowned document was written by a build that did not separate accounts, so
/// it could belong to anyone. One rule with no exemptions is the only one a
/// reader can hold; an application adding an owner to an install that has none
/// clears the store or re-writes it deliberately.
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
  /// With an [owner], the array is wrapped in the envelope described on this
  /// class; without one it is written bare, which is the interchange shape.
  ///
  /// Throws `device_preferences.store.reflection_not_initialised` when the
  /// application never called `initializeReflection()`. That is a configuration
  /// fault of the program, not of the store, and saying so is the difference
  /// between a one-line fix and an afternoon spent inspecting a file that is
  /// intact.
  static String encode(List<TomUserPreferenceDto> values, {String? owner}) {
    final String entries;
    try {
      entries = tomReflectionInfo.convertToJsonString(values);
    } catch (error, stack) {
      if (isReflectionUninitialised(error)) throw _uninitialised(error, stack);
      rethrow;
    }
    if (owner == null) return entries;
    // The entries are spliced in as text rather than re-encoded: reflection has
    // already produced the exact array `decode` expects, and decoding it here
    // only to encode it again would be two conversions for one document and a
    // second place for the shape to be decided.
    return '{${jsonEncode('owner')}:${jsonEncode(owner)},'
        '${jsonEncode('preferences')}:$entries}';
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
    String? owner,
  }) {
    if (content.trim().isEmpty) return [];

    final Object? document;
    try {
      document = jsonDecode(content);
    } catch (error, stack) {
      throw TomDevicePreferenceException(
        'device_preferences.store.invalid_content',
        'The device preference store $source does not contain valid JSON.',
        parameters: {'source': source},
        rootException: error,
        stack: stack,
      );
    }
    // Either shape: the bare array, or the envelope that names an owner. The
    // owner is compared before anything else is read, because the question it
    // answers — whose document is this — decides whether the rest may be read
    // at all.
    final Object? decoded = document is Map
        ? document['preferences']
        : document;
    _requireOwner(
      document is Map ? document['owner'] : null,
      owner,
      source: source,
    );

    if (decoded is! List) {
      throw TomDevicePreferenceException(
        'device_preferences.store.invalid_content',
        'The device preference store $source must contain a JSON array, or an '
            'object with a preferences array, but holds a '
            '${document.runtimeType}.',
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

  /// Refuses a document whose owner is not [expected].
  ///
  /// Absent is a value on both sides, so an unowned document read by an owning
  /// store is a mismatch exactly as two different names are. That is the whole
  /// guarantee: a store shared by two accounts fails on its first read instead
  /// of serving one user the other's last-used account and biometric flag.
  static void _requireOwner(
    Object? stored,
    String? expected, {
    required String source,
  }) {
    final String? actual = stored is String ? stored : null;
    if (actual == expected) return;
    throw TomDevicePreferenceException(
      'device_preferences.store.wrong_owner',
      'The device preference store $source holds the preferences of '
          '${actual ?? 'no named owner'}, and was read as '
          '${expected ?? 'no named owner'}. Give each account its own store '
          'location, and name the owner on the store that reads it.',
      parameters: {
        'source': source,
        if (actual != null) 'storedOwner': actual,
        if (expected != null) 'expectedOwner': expected,
      },
    );
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
