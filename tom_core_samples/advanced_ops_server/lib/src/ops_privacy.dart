/// The sample's personal data, registered with `TomPrivacy`: what an erasure
/// of a user reaches, and what their subject-access export holds.
///
/// The back-office server is the one process that reaches both databases — the
/// app server's `app_db` and the auth server's `auth_db` — through those
/// servers' own repositories, which is why the registration lives here rather
/// than in either of them. What each row does when its user is erased is
/// declared on the records themselves:
///
/// | Record | Field | Erasure |
/// | ------ | ----- | ------- |
/// | `WorkspaceRecord` | `ownerId` | deleted — and with it, by the schema's `ON DELETE CASCADE`, its projects, lists, items and comments |
/// | `ItemRecord` | `assigneeId`, `reporterId` | unlinked: the item stays in someone else's workspace |
/// | `CommentRecord` | `authorId` | anonymized: the comment stays in its thread, its author and its `body` removed |
/// | `GroupMemberRecord`, `UserRoleRecord` | `userId` | deleted |
/// | `UserRecord` | `id` | deleted; `username`, `displayName` and `email` are personal, so their audit values are sealed for the user |
///
/// Workspaces come first, so the rows they cascade away are not visited twice;
/// the user's own account comes last.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Registers the sample's records with `TomPrivacy`, in the order an erasure
/// visits them — see the library documentation.
void registerOpsPersonalData() {
  TomPrivacy.register(workspaceRepository);
  TomPrivacy.register(itemRepository);
  TomPrivacy.register(commentRepository);
  TomPrivacy.register(GroupMemberRepository());
  TomPrivacy.register(UserRoleRepository());
  TomPrivacy.register(userRepository);
}
