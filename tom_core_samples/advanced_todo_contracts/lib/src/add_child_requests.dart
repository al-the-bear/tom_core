/// The request DTOs for creating a child row under an item.
///
/// `POST /items/{id}/comments` and `POST /items/{id}/subtasks` address the
/// parent in the path, so the parent must not travel in the body as well: a
/// request that states its subject twice can state it two different ways, and
/// the pipeline would settle the disagreement silently by letting the path
/// overwrite the body. These requests therefore carry the caller-authored
/// fields only, plus [AddCommentRequest.id] / [AddSubtaskRequest.id], which the
/// endpoint's `{'id': 'id'}` mapping fills from the path capture — the same
/// binding `EntityIdRequest` uses. The client sends that field in the URL and
/// leaves it out of the body, so the parent is stated exactly once.
///
/// Everything else on the created row — its own id, the author, the creation
/// time, a subtask's position — is stamped server-side, so it has no field here.
///
/// Reflection-first wire DTOs (G-DTO): `@tomReflector`, plain non-`final`
/// fields, no hand-written serializer.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A comment to add to an item, posted to `POST /items/{id}/comments`.
@tomReflector
class AddCommentRequest {
  /// The parent item's id, bound from the `{id}` path capture; never sent in
  /// the body.
  String id;

  /// The comment text.
  String body;

  /// Creates a comment request for the item [id].
  AddCommentRequest({this.id = '', this.body = ''});

  @override
  String toString() => 'AddCommentRequest(item $id)';
}

/// A subtask to add to an item, posted to `POST /items/{id}/subtasks`.
@tomReflector
class AddSubtaskRequest {
  /// The parent item's id, bound from the `{id}` path capture; never sent in
  /// the body.
  String id;

  /// The subtask's title.
  String title;

  /// Whether the subtask starts out done.
  bool done;

  /// Creates a subtask request for the item [id].
  AddSubtaskRequest({this.id = '', this.title = '', this.done = false});

  @override
  String toString() => 'AddSubtaskRequest(item $id: $title)';
}
