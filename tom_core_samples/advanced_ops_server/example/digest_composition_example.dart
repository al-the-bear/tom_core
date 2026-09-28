/// The morning digest, end to end, with no infrastructure: two people, one
/// pass, one German mail and one English one.
///
/// This is the seam of the ops server a reader is most likely to adapt, shown
/// without booting three servers and two databases. Every class below is the
/// one the running server uses; only the two ends are swapped:
///
/// * **Where the facts come from.** The server's `RepositoryDigestAudience`
///   runs two queries and hands the rows to
///   [RepositoryDigestAudience.summariesFrom]. Here [_TwoPeople] builds the
///   same rows in memory and calls the same join, so each person's stored
///   `auth_users.language` becomes their digest's locale exactly as it does in
///   production — `bob` stores `de`, `carol` stores nothing.
/// * **Where the mail goes.** The server hands the outbox an SMTP transport;
///   here it is a [TomMemoryMessageTransport] that keeps what it was given.
///
/// What stays real is the part worth reading: [OpsDigestService] queues one
/// message per person into a [TomMessageOutbox] and returns — it never sends —
/// and [TomEmailService] renders subject and body from the shipped
/// `assets/text_en.yaml` / `assets/text_de.yaml` in each recipient's locale.
/// There is no sentence in the digest's Dart; change a line of a bundle and
/// rerun this to see it.
///
/// ## Running it
///
/// From this package, so the relative `assets/` path resolves:
///
/// ```sh
/// dart run example/digest_composition_example.dart
/// ```
///
/// `test/examples_test.dart` runs it the same way and checks what it prints.
library;

import 'dart:io';

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  // The deployment identity every job runs under (`ops_identity.dart`). The
  // server installs it at boot; the pass below refuses to run without it.
  installOpsDeploymentPrincipal();

  final transport = TomMemoryMessageTransport();
  final outbox = TomMessageOutbox(
    router: TomMessageRouter([transport]),
    store: TomMemoryJobStore(),
  );
  final digest = OpsDigestService(
    audience: _TwoPeople(),
    email: TomEmailService(outbox: outbox, texts: OpsTexts.resources()),
  );

  try {
    final window = DateTime.utc(2026, 8, 3, 6);
    final report = await runAsOpsService(() => digest.queueDigests(window));
    stdout.writeln(
      'queued ${report.queued} digest(s); delivered so far: '
      '${transport.count}',
    );

    // One outbox tick is what the server's scheduler does every few seconds.
    await outbox.tick();

    for (final mail in transport.sent) {
      stdout
        ..writeln()
        ..writeln('To:      ${mail.recipients.first.address}')
        ..writeln('Subject: ${mail.subject}')
        ..writeln(mail.textBody?.content ?? '');
    }
  } finally {
    await outbox.close();
  }
}

/// Two people with open work: `bob` prefers German, `carol` has no stored
/// preference and gets the deployment default, English.
class _TwoPeople implements OpsDigestAudience {
  @override
  Future<List<OpsDigestSummary>> summariesFor(DateTime now) async {
    final bob = UserRecord()
      ..id = 3
      ..username = 'bob'
      ..displayName = 'Bob Turing'
      ..email = 'bob@example.com'
      ..language = 'de';
    final carol = UserRecord()
      ..id = 4
      ..username = 'carol'
      ..displayName = 'Carol Hopper'
      ..email = 'carol@example.com';

    return RepositoryDigestAudience.summariesFrom(
      users: [bob, carol],
      itemsByAssignee: {
        3: [
          _item(1, due: now.subtract(const Duration(days: 2))),
          _item(2, due: now.add(const Duration(days: 4))),
        ],
        4: [_item(3)],
      },
      now: now,
    );
  }

  ItemRecord _item(int id, {DateTime? due}) => ItemRecord()
    ..id = id
    ..status = 'todo'
    ..dueDate = due;
}
