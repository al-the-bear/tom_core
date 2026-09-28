/// The morning digest: one summary per person with open work, handed to the
/// messaging outbox rather than to a transport.
///
/// ## What this demonstrates that `messaging.md` only describes
///
/// `messaging.md` §"Delivery Semantics: One Retry Mechanism" states that the
/// outbox puts retries on the job queue.
/// That is a sentence about two modules meeting, and until something composed
/// them it was only a sentence. Here the composition is literal and doubled:
/// the digest is produced *by* a scheduled job and delivered *through* a queue
/// that is itself a scheduler. Two independent schedules, and they are
/// independent on purpose — see below.
///
/// ## Why the job does not deliver
///
/// [OpsDigestService.queueDigests] returns the moment the messages are durably
/// enqueued. It never waits for a relay, and it never learns whether delivery
/// succeeded. That is the whole reason the outbox exists:
///
///  * a job that awaited SMTP would fail — and *retry the composition* — because
///    a mail server was slow, re-reading every row to rebuild messages that were
///    already correct; and
///  * the retry budget would then belong to the wrong unit of work. The thing
///    worth retrying is one undeliverable message to one person, not the whole
///    morning's digest.
///
/// So composition retries on the ops scheduler's terms (once, at its window) and
/// delivery retries on the outbox's (five attempts over a widening backoff), and
/// neither is able to trigger the other. `test/ops_digest_test.dart` asserts
/// exactly that separation: a transport failing its first attempt is redelivered
/// from the queue without the digest ever being recomposed.
///
/// ## Why the message id is the idempotence key
///
/// The scheduler's guarantee is at-least-once, so this job *will* occasionally
/// run twice for one window — after a node dies mid-run, most obviously. A
/// digest that arrived twice because a scheduler recovered would be the
/// framework's fault surfacing as spam.
///
/// [OpsDigestService.messageIdFor] derives the id from the recipient and the
/// window, and `TomMessageOutbox.send` keys its queue row on it
/// (`'<job>:<message id>'`), so a second composition of the same window
/// *replaces* the queued run instead of adding one. At-least-once delivery of a
/// message that is its own key is exactly-once delivery of a digest.
///
/// ## Why the text is not here
///
/// The digest names a **template key** and supplies values;
/// [TomEmailService] resolves the subject and body from `assets/text_*.yaml`
/// in the recipient's locale (`ops_texts.dart`). There is no sentence in this
/// file that anybody reads.
///
/// That is not tidiness. The transport and the outbox are good enough to call
/// directly, and a job that calls them directly composes its own subject —
/// which is how user-facing text ends up in Dart literals, untranslatable and
/// uneditable without a rebuild. The service exists to make the resource-keyed
/// path the *convenient* one, and this job is the proof that it is: the same
/// pass renders German for one recipient and English for the next, which
/// per-process bundle state could not do at all.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../ops_identity.dart';
import '../ops_texts.dart';
import 'retention_service.dart';

/// The statuses that count as outstanding work.
///
/// Derived from the terminal set rather than listed, so a status added to
/// [TodoStatus] is in the digest by default. The alternative — a hand-written
/// list of open states — silently *excludes* anything new, and a digest that
/// under-reports is worse than one that over-reports: nobody notices work that
/// was never mentioned.
final Set<TodoStatus> openStatuses = TodoStatus.values.toSet().difference(
  retainableTerminalStatuses,
);

/// One person's outstanding work, as the digest reports it.
class OpsDigestSummary {
  /// Creates a summary.
  const OpsDigestSummary({
    required this.userId,
    required this.displayName,
    required this.emailAddress,
    required this.openCount,
    required this.overdueCount,
    this.nextDue,
    this.locale,
  });

  /// `auth_users.id` of the assignee.
  final int userId;

  /// The name the digest greets.
  final String displayName;

  /// Where the digest is sent.
  final String emailAddress;

  /// How many open items are assigned to this person.
  final int openCount;

  /// How many of those are past their due date.
  final int overdueCount;

  /// The earliest due date still ahead, or `null` when nothing is dated.
  final DateTime? nextDue;

  /// The language to render this person's digest in, or `null` for the
  /// deployment default.
  ///
  /// Per recipient rather than per process, because one pass mails everybody:
  /// there is no moment at which the digest job could meaningfully "switch to
  /// German". [RepositoryDigestAudience] fills it from the account's stored
  /// `auth_users.language` / `.country`, so a recipient who set no preference
  /// gets `null` and the deployment's default bundle.
  final TomTextLocale? locale;

  @override
  String toString() =>
      'OpsDigestSummary($displayName <$emailAddress>, open: $openCount, '
      'overdue: $overdueCount)';
}

/// What one digest pass did.
class OpsDigestReport {
  /// Creates a report.
  const OpsDigestReport({
    required this.window,
    required this.considered,
    required this.queued,
    required this.skippedWithoutAddress,
  });

  /// The window the digests were composed for — also the id component that
  /// makes a re-run idempotent.
  final DateTime window;

  /// How many people had open work.
  final int considered;

  /// How many messages reached the outbox.
  final int queued;

  /// How many people were skipped for want of an address.
  ///
  /// Counted rather than logged: a deployment whose user directory has holes
  /// should be able to see the size of the hole without grepping.
  final int skippedWithoutAddress;

  @override
  String toString() =>
      'OpsDigestReport(window: $window, considered: $considered, '
      'queued: $queued, skippedWithoutAddress: $skippedWithoutAddress)';
}

/// Where the digest's facts come from.
///
/// Two sources behind one port, because the digest needs both halves and
/// neither is meaningful alone: the *work* lives in `app_db` and the *addresses*
/// live in `auth_db`. The join is this method's job, and putting it behind the
/// port is what lets `test/ops_digest_test.dart` prove the queueing behaviour
/// without either database.
abstract class OpsDigestAudience {
  /// Everyone with open work as of [now], with their contact details.
  Future<List<OpsDigestSummary>> summariesFor(DateTime now);
}

/// [OpsDigestAudience] over the app server's items and the auth server's users.
///
/// Read-only against both, and unscoped for the same reason the retention pass
/// is: the ops service account is assigned nothing, so a scoped read would find
/// no work and mail nobody. See `ops_identity.dart` for what it pays for that
/// bypass.
class RepositoryDigestAudience implements OpsDigestAudience {
  /// Creates an audience over the process-wide repositories.
  const RepositoryDigestAudience();

  @override
  Future<List<OpsDigestSummary>> summariesFor(DateTime now) async {
    final statuses = openStatuses.map((s) => s.name).toList();
    final placeholders = [
      for (var i = 0; i < statuses.length; i++) ':status$i',
    ].join(' , ');
    final open = await TomDataScope.runUnscoped(
      () => itemRepository.findByQuerySentence(
        'FIND BY status IS IN ( $placeholders ) AND assignee_id IS NOT NULL',
        {for (var i = 0; i < statuses.length; i++) 'status$i': statuses[i]},
      ),
    );

    final byAssignee = <int, List<ItemRecord>>{};
    for (final item in open) {
      final assignee = item.assigneeId;
      if (assignee == null) continue;
      byAssignee.putIfAbsent(assignee, () => []).add(item);
    }
    if (byAssignee.isEmpty) return const [];

    // One query for the whole audience rather than one per person. The digest
    // is the classic place an N+1 hides: it is correct either way, it is fast on
    // a developer's ten rows, and it is a thousand round trips at 06:00 on a
    // real directory.
    final ids = byAssignee.keys.toList()..sort();
    final idPlaceholders = [
      for (var i = 0; i < ids.length; i++) ':user$i',
    ].join(' , ');
    final users = await TomDataScope.runUnscoped(
      () => userRepository.findByQuerySentence(
        'FIND BY id IS IN ( $idPlaceholders )',
        {for (var i = 0; i < ids.length; i++) 'user$i': ids[i]},
      ),
    );

    return summariesFrom(users: users, itemsByAssignee: byAssignee, now: now);
  }

  /// Joins the two halves the queries fetched: one summary per user who has
  /// open work, carrying the address and the stored language from `auth_users`.
  ///
  /// Static and pure for the same reason as [summarise] — it is the part of the
  /// audience with rules in it (who is included, what the address falls back
  /// to, how a stored language becomes a locale), so it is asserted over real
  /// [UserRecord] rows without a database.
  ///
  /// The language is read with [TomTextLocale.lenient]: a user row is data
  /// somebody typed, and a country that cannot name one must cost that person
  /// their regional variant, not abort the pass for everybody after them. A
  /// blank language is no preference, which [OpsDigestSummary.locale] spells
  /// `null`.
  static List<OpsDigestSummary> summariesFrom({
    required Iterable<UserRecord> users,
    required Map<int, List<ItemRecord>> itemsByAssignee,
    required DateTime now,
  }) {
    final summaries = <OpsDigestSummary>[];
    for (final user in users) {
      final id = user.id;
      if (id == null) continue;
      final items = itemsByAssignee[id];
      if (items == null) continue;
      summaries.add(
        summarise(
          userId: id,
          displayName: user.displayName ?? user.username ?? 'user $id',
          emailAddress: user.email ?? '',
          items: items,
          now: now,
          locale: _storedLocale(user),
        ),
      );
    }
    return summaries;
  }

  static TomTextLocale? _storedLocale(UserRecord user) {
    final language = user.language?.trim() ?? '';
    if (language.isEmpty) return null;
    return TomTextLocale.lenient(language, user.country);
  }

  /// Reduces one person's items to the three numbers the digest reports.
  ///
  /// Static and pure so the counting rules — in particular what "overdue" means
  /// — are assertable without a database. Exposed rather than private because a
  /// test that reimplemented them would be asserting its own arithmetic.
  static OpsDigestSummary summarise({
    required int userId,
    required String displayName,
    required String emailAddress,
    required List<ItemRecord> items,
    required DateTime now,
    TomTextLocale? locale,
  }) {
    var overdue = 0;
    DateTime? nextDue;
    for (final item in items) {
      final due = item.dueDate;
      if (due == null) continue;
      if (due.isBefore(now)) {
        overdue++;
      } else if (nextDue == null || due.isBefore(nextDue)) {
        nextDue = due;
      }
    }
    return OpsDigestSummary(
      userId: userId,
      displayName: displayName,
      emailAddress: emailAddress,
      openCount: items.length,
      overdueCount: overdue,
      nextDue: nextDue,
      locale: locale,
    );
  }
}

/// Composes the digest and queues it. Delivery is the outbox's problem.
class OpsDigestService {
  /// Creates a digest pass.
  OpsDigestService({
    required this.audience,
    required this.email,
    this.sender,
    this.productName = 'Advanced Todo',
  });

  /// Where the facts come from.
  final OpsDigestAudience audience;

  /// Where the messages go: a template renderer over a queue, never a
  /// transport.
  ///
  /// The service rather than the outbox, because the outbox takes a composed
  /// [TomMessage] — which means a caller holding one has already written the
  /// subject line somewhere. Holding the service instead leaves this class no
  /// way to spell a literal subject at all.
  final TomEmailService email;

  /// The `From` address, or `null` to let the transport supply its configured
  /// default.
  final TomRecipient? sender;

  /// The product name the digest calls itself by.
  ///
  /// Configuration rather than prose — it is a deployment's identity, the same
  /// in every language — so it is a parameter the templates substitute rather
  /// than a resource key they duplicate.
  final String productName;

  /// The id a digest for [userId] in the day of [window] is queued under.
  ///
  /// Day-granular, matching the job's daily schedule: two runs of the same
  /// window must collide, and two runs of different windows must not. Encoding
  /// the full timestamp would make every recovery-triggered re-run a new
  /// message, which is precisely the duplicate this is here to prevent.
  static String messageIdFor(int userId, DateTime window) {
    final day = window.toUtc();
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return 'digest-${day.year}$month$dayOfMonth-$userId';
  }

  /// Composes and queues one digest per person with open work.
  ///
  /// Returns once every message is durably on the queue. Nothing here awaits a
  /// transport, so the pass takes as long as the two reads and no longer.
  Future<OpsDigestReport> queueDigests(DateTime window) async {
    await requireOpsCapability(
      OpsCapabilities.sendDigest,
      operation: 'OpsDigest',
      entitlement: digestSendEntitlement,
    );

    final summaries = await audience.summariesFor(window);
    var queued = 0;
    var skipped = 0;
    for (final summary in summaries) {
      if (summary.emailAddress.trim().isEmpty) {
        // A person with work and no address is a directory problem, not a
        // delivery failure, and queueing an unaddressable message would turn it
        // into five doomed retries and an alert.
        skipped++;
        continue;
      }
      await email.send(requestFor(summary, window));
      queued++;
    }
    if (queued > 0) {
      // One entry for the pass. The trail's interest here is that the ops
      // server sent mail to N people on behalf of nobody in particular — the
      // per-message record already exists in the outbox's own queue.
      await TomAuditTrail.recordAction(
        action: TomAuditAction.execute,
        target: 'OpsDigest',
        outcome: TomAuditOutcome.succeeded,
        detail: 'queued $queued digest(s) for ${window.toUtc()}',
      );
    }
    return OpsDigestReport(
      window: window,
      considered: summaries.length,
      queued: queued,
      skippedWithoutAddress: skipped,
    );
  }

  /// What to send one person: a template key, an address, and values.
  ///
  /// Deliberately has nowhere to put a subject line. The digest supplies four
  /// numbers and a name; `assets/text_*.yaml` decides what is said about them,
  /// in the recipient's language.
  ///
  /// Plain text only — no `.html` key. An operational digest is read on a phone
  /// at breakfast and its whole content is four numbers; an HTML alternative
  /// would double the surface that can be wrong for no reader who benefits.
  TomEmailRequest requestFor(OpsDigestSummary summary, DateTime window) {
    final locale = summary.locale;
    final next = summary.nextDue;
    return TomEmailRequest(
      templateKey: opsDigestTemplateKey,
      messageId: messageIdFor(summary.userId, window),
      from: sender,
      to: [
        TomRecipient(summary.emailAddress, displayName: summary.displayName),
      ],
      locale: locale,
      parameters: {
        'product': productName,
        'sender': opsServiceUsername,
        'displayName': summary.displayName,
        'openCount': summary.openCount,
        // The two conditional sentences are resolved here, fully, and passed in
        // as finished text. A template cannot say "only when there is an
        // overdue count", and resolving the fragment *with its own parameters*
        // matters: substitution is one pass over the map, so a fragment
        // inserted with `{overdueCount}` still in it would resolve or not
        // depending on map order.
        'overdueLine': summary.overdueCount == 0
            ? ''
            : email.requiredText(
                opsDigestTemplateKey,
                opsDigestOverdueSubKey,
                locale: locale,
                parameters: {'overdueCount': summary.overdueCount},
              ),
        'nextDueLine': next == null
            ? ''
            : email.requiredText(
                opsDigestTemplateKey,
                opsDigestNextDueSubKey,
                locale: locale,
                parameters: {'nextDue': _dateOnly(next)},
              ),
      },
    );
  }

  /// The rendered message for one person, without queueing it.
  ///
  /// Kept as a named step so a test — or an operator asking "what does the
  /// digest look like" — can see the mail without sending it. Sending goes
  /// through [TomEmailService.send], which renders the same way and then
  /// queues.
  TomMessage composeFor(OpsDigestSummary summary, DateTime window) =>
      email.render(requestFor(summary, window));

  static String _dateOnly(DateTime value) {
    final utc = value.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }
}
