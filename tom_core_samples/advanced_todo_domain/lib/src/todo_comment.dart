import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A discussion entry on a [TodoItem].
///
/// Forms the comment thread shown on the item detail view; [authorId] points
/// at the commenting [User].
@tomReflector
class TodoComment extends TomClass {
  /// Stable identifier (the server's primary key).
  late final id = TomString('');

  /// `TodoItem.id` this comment is attached to.
  late final itemId = TomString('');

  /// [User.id] of the comment author.
  late final authorId = TomString('');

  /// Comment text.
  late final body = TomString('');

  /// When the comment was posted; null until persisted.
  late final createdAt = TomNDateTime(null);
}
