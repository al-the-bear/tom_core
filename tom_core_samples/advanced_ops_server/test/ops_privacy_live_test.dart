/// A user exported and erased across the sample's entities, against the live
/// databases.
///
/// The user is created the way the application would hold them: an account and
/// a role assignment in `auth_db`; in `app_db` a workspace of their own with a
/// project, a list, an item and a comment inside it, and — in a workspace that
/// is somebody else's — an item assigned to them and a comment they wrote. The
/// subject-access export must find all of it; the erasure must then delete
/// what is theirs, unlink them from what is not, keep their comment in the
/// other workspace's thread without their name or words, and leave their
/// words unreadable in the audit trail while the trail still verifies.
///
/// What each record does is declared on the record (`@TomDataSubject`,
/// `@TomPersonal`); what the operation visits is `registerOpsPersonalData`.
/// Skips when `app_db` is unreachable; `tool/run_ops_integration.sh` runs it
/// with the databases up and treats a skip as a failure.
library;

import 'dart:convert';

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'support/live_database.dart';

/// Runs [body] as the deployment, with row scopes out of the way: the stage is
/// set and inspected by the test, not by a user.
Future<T> _asOps<T>(Future<T> Function() body) =>
    runAsOpsService(() => TomDataScope.runUnscoped(body));

void main() {
  setUpAll(bootstrapLiveDatabase);

  late TomMemoryAuditSink trail;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  late int userId;
  late int otherWorkspaceId;
  final ownIds = <String, int>{};
  final foreignIds = <String, int>{};

  setUp(() async {
    if (!liveDatabaseAvailable) return;
    trail = TomMemoryAuditSink();
    TomAuditTrail.install(trail);
    installOpsDeploymentPrincipal();
    final store = TomSqlSubjectKeyStore('app_db');
    TomPrivacy.installSubjectKeys(
      TomSubjectKeys(
        store: store,
        keys: [TomAesKeyEncryptionKey('ops-test-kek', List.filled(32, 9))],
      ),
    );

    await _asOps(() async {
      final user = await userRepository.save(
        UserRecord()
          ..username = 'gdpr-$stamp'
          ..displayName = 'Gina Data'
          ..email = 'gina-$stamp@example.com'
          ..status = 'active'
          ..language = 'en'
          ..country = 'DE',
      );
      userId = user.id!;
      final role = (await roleRepository.findAll()).first;
      await UserRoleRepository().save(
        UserRoleRecord()
          ..userId = userId
          ..roleId = role.id,
      );

      // Her own workspace, and everything in it.
      final workspace = await workspaceRepository.save(
        WorkspaceRecord()
          ..name = 'Gina $stamp'
          ..ownerId = userId,
      );
      final project = await projectRepository.save(
        ProjectRecord()
          ..workspaceId = workspace.id
          ..name = 'Plans'
          ..archived = false,
      );
      final list = await listRepository.save(
        ListRecord()
          ..projectId = project.id
          ..name = 'Now'
          ..position = 0,
      );
      final item = await itemRepository.save(
        ItemRecord()
          ..listId = list.id
          ..title = 'her own task'
          ..reporterId = userId,
      );
      final comment = await commentRepository.save(
        CommentRecord()
          ..itemId = item.id
          ..authorId = userId
          ..body = 'note to self',
      );
      ownIds.addAll({
        'workspace': workspace.id!,
        'project': project.id!,
        'item': item.id!,
        'comment': comment.id!,
      });

      // Somebody else's workspace, where she is assigned and has spoken.
      final other = await workspaceRepository.save(
        WorkspaceRecord()
          ..name = 'Team $stamp'
          ..ownerId = userId + 1000000,
      );
      otherWorkspaceId = other.id!;
      final otherProject = await projectRepository.save(
        ProjectRecord()
          ..workspaceId = other.id
          ..name = 'Shared'
          ..archived = false,
      );
      final otherList = await listRepository.save(
        ListRecord()
          ..projectId = otherProject.id
          ..name = 'Doing'
          ..position = 0,
      );
      final assigned = await itemRepository.save(
        ItemRecord()
          ..listId = otherList.id
          ..title = 'the team task'
          ..assigneeId = userId,
      );
      final remark = await commentRepository.save(
        CommentRecord()
          ..itemId = assigned.id
          ..authorId = userId
          ..body = 'Gina was here',
      );
      foreignIds.addAll({'item': assigned.id!, 'comment': remark.id!});
    });
  });

  tearDown(() async {
    if (!liveDatabaseAvailable) return;
    // Whatever the erasure under test did not remove must not survive into the
    // next run. A row it already removed refuses its delete — the expected case.
    Future<void> tolerant(Future<Object?> Function() step) async {
      try {
        await step();
      } on Object {
        // Already erased.
      }
    }

    await TomAuditTrail.runUnaudited(
      () => _asOps(() async {
        for (final w in [otherWorkspaceId, ownIds['workspace']]) {
          if (w != null)
            await tolerant(() => workspaceRepository.deleteById(w));
        }
        await tolerant(
          () => UserRoleRepository().deleteByQuerySentence(
            'delete by userId = :u',
            {'u': userId},
          ),
        );
        await tolerant(() => userRepository.deleteById(userId));
      }),
    );
    TomPrivacy.reset();
    registerOpsPersonalData();
    TomAuditTrail.uninstall();
    TomServerPrincipal.clear();
  });

  test(
    'a subject-access export holds the user across both databases',
    () async {
      if (liveDatabaseUnavailable()) return;
      final access = await runAsOpsService(
        () => TomPrivacy.subjectAccess(userId),
      );
      expect(access.rowCounts, {
        WorkspaceRecord: 1,
        // Her own task (as reporter) and the team task (as assignee).
        ItemRecord: 2,
        CommentRecord: 2,
        GroupMemberRecord: 0,
        UserRoleRecord: 1,
        UserRecord: 1,
      });
      final csv = utf8.decode(
        await runAsOpsService(
          () => TomPrivacy.exportSubject(userId, format: 'csv'),
        ),
      );
      expect(csv, contains('gina-$stamp@example.com'));
      expect(csv, contains('Gina was here'));
      expect(csv, contains('the team task'));
      final exports = trail.records.where(
        (r) => r.target == TomPrivacy.subjectAccessTarget,
      );
      expect(exports.first.targetKey, '$userId');
    },
  );

  test('an erasure removes the user from both databases, as each record '
      'declares, and their words from the audit trail', () async {
    if (liveDatabaseUnavailable()) return;
    final remarkCreated = trail.records.firstWhere(
      (r) =>
          r.target == 'CommentRecord' &&
          r.action == TomAuditAction.create &&
          r.targetKey == '${foreignIds['comment']}',
    );
    expect(remarkCreated.after['body'], startsWith(TomSubjectKeys.prefix));
    expect(
      (await TomPrivacy.reveal(remarkCreated)).after['body'],
      'Gina was here',
    );

    final report = await runAsOpsService(() => TomPrivacy.erase(userId));
    expect(report.countOf(WorkspaceRecord).deleted, 1);
    expect(report.countOf(ItemRecord).unlinked, 1);
    expect(report.countOf(CommentRecord).anonymized, 1);
    expect(report.countOf(UserRoleRecord).deleted, 1);
    expect(report.countOf(UserRecord).deleted, 1);
    expect(report.auditKeyShredded, isTrue);

    await _asOps(() async {
      // Hers: gone, her workspace's contents with it.
      expect(await userRepository.findById(userId), isNull);
      expect(await workspaceRepository.findById(ownIds['workspace']!), isNull);
      expect(await projectRepository.findById(ownIds['project']!), isNull);
      expect(await itemRepository.findById(ownIds['item']!), isNull);
      expect(await commentRepository.findById(ownIds['comment']!), isNull);
      // Not hers: kept, with her name and words removed.
      final teamTask = await itemRepository.findById(foreignIds['item']!);
      expect(teamTask!.assigneeId, isNull);
      expect(teamTask.title, 'the team task');
      final remark = await commentRepository.findById(foreignIds['comment']!);
      expect(remark!.authorId, isNull);
      expect(remark.body, '[removed]');
    });

    expect(
      trail.records
          .where((r) => r.target == TomPrivacy.erasureTarget)
          .single
          .targetKey,
      '$userId',
    );
    expect(
      (await TomPrivacy.reveal(remarkCreated)).after['body'],
      TomSubjectKeys.erasedPlaceholder,
    );
    expect(trail.verify().isValid, isTrue);
    // A second erasure finds nothing left.
    final again = await runAsOpsService(() => TomPrivacy.erase(userId));
    expect(again.counts.every((c) => c.isEmpty), isTrue);
  });
}
