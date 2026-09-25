import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Reflection helpers for the reflection-first wire DTOs (G-DTO).
///
/// The wire DTOs carry no hand-written `toJson`/`fromJson`; the framework
/// serializes them through the kernel reflection path. On the server the
/// endpoint pipeline drives that path directly when an endpoint returns a DTO.
/// Off the server — the Flutter client's live read path and the contract
/// round-trip tests — these one-liners centralise the `ClassMirror` wiring so no
/// consumer repeats it. They require the reflection seed to have been installed
/// (`initializeReflection()`).
///
/// Shared in shape with `advanced_todo_contracts`.

/// Deserializes [json] into a reflection-first DTO of type [T].
///
/// Throws a [StateError] when the reflection seed has not been installed —
/// the caller forgot `initializeReflection()` — and a `NoSuchCapabilityError`
/// naming the type when the seed does not cover [T].
T dtoFromJson<T extends Object>(Map<String, Object?> json) {
  final mirror = tomReflector.reflectType(T) as ClassMirror;
  return tomReflectionInfo.createInstanceFromJson<T>(mirror, json);
}

/// Serializes a reflection-first DTO to its JSON-ready map.
Map<String, Object?> dtoToMap(Object dto) => tomReflectionInfo.getValues(dto);

/// Serializes a reflection-first DTO to a JSON string.
String dtoToJsonString(Object dto) =>
    tomReflectionInfo.convertToJsonString(dto);
