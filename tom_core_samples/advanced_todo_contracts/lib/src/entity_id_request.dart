/// The single-field request DTO for by-id endpoints (delete / read-one).
///
/// Every `/…/{id}` (or `/…/{key}`) endpoint whose only input is the addressed
/// resource's identifier binds to this one reusable request type rather than a
/// bare-`String` handler parameter (G-API-2). The path capture is folded onto
/// [id] by the endpoint's `urlParameterMapping` before the DTO is instantiated,
/// so `DELETE /admin/users/{id}` arrives as `request.id`, and
/// `DELETE /admin/roles/{key}` maps `{'key': 'id'}` onto the same field.
///
/// A reflection-first wire DTO (G-DTO): `@tomReflector`, a plain non-`final`
/// field, no hand-written serializer — the framework serializes it through the
/// kernel reflection path exactly like the other contract DTOs.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A request carrying only the addressed resource's identifier.
@tomReflector
class EntityIdRequest {
  /// The addressed resource's identifier (the value captured from the URL path).
  String id;

  /// Creates a by-id request for the resource identified by [id].
  EntityIdRequest({this.id = ''});

  @override
  String toString() => 'EntityIdRequest($id)';
}
