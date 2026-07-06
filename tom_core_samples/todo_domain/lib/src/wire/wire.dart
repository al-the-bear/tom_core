/// Wire-contract barrel — the reflection-first JSON DTOs the samples exchange.
///
/// These are the transport shapes of the read-only server API
/// (`core_server_sample`) that the client's live read path parses
/// (`core_client_sample`). Each is a `@tomReflector` class with plain
/// non-`final` fields and **no** hand-written serializer (G-DTO): the framework
/// round-trips them through the kernel reflection path — the server endpoint
/// pipeline directly, off-server consumers through the [dtoFromJson] /
/// [dtoToMap] / [dtoToJsonString] helpers in `dto_reflection.dart`.
///
/// The wire DTOs live beside the domain entities (rather than in a separate
/// contracts package) because the deliberately-minimal core sample pair already
/// shares this one reflected package across both tiers; keeping them in a
/// dedicated `wire/` folder preserves the domain-vs-transport separation without
/// a second package to build and reflect.
library;

export 'dto_reflection.dart';
export 'todo_field_matrix_dto.dart';
export 'todo_item_dto.dart';
