/// How a typed payload becomes the JSON a message carries, and back.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'message.dart';

/// Encodes payloads of type [T] to JSON and decodes them back.
///
/// [TomBusCodec.reflected] — the default of every publish and subscription —
/// takes a JSON value as it is and any other object through the kernel's
/// reflection, so a `@tomReflector` class with plain fields crosses the bus
/// with no codec written for it. A type that needs its own wire shape supplies
/// a codec with [TomBusCodec.new].
class TomBusCodec<T> {
  /// A codec of [encode] and [decode].
  const TomBusCodec(this._encode, this._decode);

  /// The reflection codec — see the class documentation.
  const TomBusCodec.reflected() : _encode = null, _decode = null;

  final Object? Function(T payload)? _encode;
  final T Function(Object? json)? _decode;

  /// [payload] as JSON. Throws `message_bus.payload.not_json` for a value
  /// neither JSON nor reflectable.
  Object? encode(T payload) {
    final encode = _encode;
    final json = encode != null ? encode(payload) : _reflectedEncode(payload);
    try {
      // A round trip through the text form: what is published is exactly what
      // a broker would carry, never a live object a consumer could mutate.
      return jsonDecode(jsonEncode(json));
    } on JsonUnsupportedObjectError catch (error, stack) {
      throw TomBusException(
        'message_bus.payload.not_json',
        'The payload ${payload.runtimeType} does not encode to JSON.',
        parameters: {'type': '${payload.runtimeType}'},
        rootException: error,
        stack: stack,
      );
    }
  }

  /// The payload [json] encodes. Throws `message_bus.payload.undecodable` for
  /// JSON that is not a [T].
  T decode(Object? json) {
    try {
      final decode = _decode;
      return decode != null ? decode(json) : _reflectedDecode(json);
    } on TomBusException {
      rethrow;
    } on Object catch (error, stack) {
      throw TomBusException(
        'message_bus.payload.undecodable',
        'The payload does not decode to $T: $error',
        parameters: {'type': '$T'},
        rootException: error,
        stack: stack,
      );
    }
  }

  static bool _isJson(Object? value) =>
      value == null ||
      value is String ||
      value is num ||
      value is bool ||
      value is List ||
      value is Map;

  Object? _reflectedEncode(T payload) {
    if (_isJson(payload)) return payload;
    return jsonDecode(tomReflectionInfo.convertToJsonString(payload!));
  }

  T _reflectedDecode(Object? json) {
    if (json is T) return json;
    if (json is Map) {
      final mirror = tomReflector.reflectType(T) as ClassMirror;
      return tomReflectionInfo.createInstanceFromJson<Object>(
            mirror,
            json.cast<String, Object?>(),
          )
          as T;
    }
    throw TomBusException(
      'message_bus.payload.undecodable',
      'A ${json.runtimeType} payload does not decode to $T.',
      parameters: {'type': '$T', 'json': '${json.runtimeType}'},
    );
  }
}
