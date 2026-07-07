/// DTO barrel — the JSON wire shapes the advanced sample's servers emit and its
/// clients parse.
///
/// Reflection-first wire DTOs (G-DTO): each is a `@tomReflector` class with
/// plain non-`final` fields and **no** hand-written `toJson`/`fromJson`. The
/// framework serializes them through the kernel reflection path
/// ([TomReflectionInfo.getValues] / [TomReflectionInfo.createInstanceFromJson])
/// exactly like the reflected `advanced_todo_domain` entities — the server
/// endpoint pipeline drives it directly, while off-server consumers (the Flutter
/// client core, the round-trip tests) go through the [dtoFromJson] / [dtoToMap] /
/// [dtoToJsonString] helpers in `dto_reflection.dart`. Values that cannot cross
/// the wire as their native type (the four-state grade, project role, user
/// status) travel as their enum `.name` token in a plain `String`/`Map` field,
/// with a typed accessor for callers. A log-safe `toString` never renders
/// passwords or bearer tokens.
library;

export 'admin_dtos.dart';
export 'dto_reflection.dart';
export 'entity_id_request.dart';
export 'graded_field_dto.dart';
export 'grant_matrix_dto.dart';
export 'login_dtos.dart';
export 'resource_bundle_dto.dart';
export 'share_request.dart';
