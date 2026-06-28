/// DTO barrel — the JSON wire shapes the advanced sample's servers emit and its
/// clients parse.
///
/// Plain value records (not reflected entities): each carries hand-written
/// `toJson`/`fromJson`, structural `==`/`hashCode`, and a log-safe `toString`
/// (passwords and bearer tokens are never rendered). The app/auth endpoints
/// exchange these as plain JSON maps — mirroring `core_server_sample`'s
/// `Map<String, Object>` surface — and the client core maps them with pure
/// functions.
library;

export 'admin_dtos.dart';
export 'graded_field_dto.dart';
export 'grant_matrix_dto.dart';
export 'login_dtos.dart';
export 'share_request.dart';
