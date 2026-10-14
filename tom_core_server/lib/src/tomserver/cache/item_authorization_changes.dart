/// How news of a changed item authorization reaches this application: pushed
/// by the authority's webhook, and pulled from its change feed to catch what a
/// webhook missed.
///
/// An authority that keeps item authorizations — Tom UAM — reports each change
/// as an item and, where the change concerns one user, that user. Both paths
/// below turn such a report into
/// [TomCacheInvalidator.invalidateItemAuthorization], which drops the cached
/// answers ([TomItemAuthorizationCache]) on every node:
///
/// - [TomItemAuthorizationWebhook] verifies and decodes one webhook delivery.
///   It is fast — the delay is the invalidation channel's staleness bound — but
///   needs the application reachable from the authority, and a delivery can be
///   lost.
/// - [TomItemAuthorizationFeedFollower] reads the change feed since its cursor
///   on a timer. It works behind a firewall and misses nothing the feed still
///   holds; its delay is the poll interval plus the channel's bound.
///
/// Run both: the webhook for speed, the feed as the catch-up. A change arriving
/// on both paths is dropped twice, which is harmless.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'cache_invalidation.dart';

/// One reported change: the [item] whose authorizations changed and the
/// [subject] they changed for, or `null` when they may have changed for
/// several subjects.
class TomItemAuthorizationChange {
  /// Creates the change.
  const TomItemAuthorizationChange(this.item, {this.subject});

  /// A change as the authority reports it:
  /// `{"item": "document:42", "subject": "u-7", "subjectKind": "user"}`.
  ///
  /// A subject of another kind than `user` — a group, an organization —
  /// changes the answers of every member, which the application cannot list,
  /// so it becomes a change for every subject. Throws [FormatException] when
  /// `item` is missing.
  factory TomItemAuthorizationChange.fromJson(Map<String, Object?> json) {
    final item = json['item'];
    if (item is! String || item.isEmpty) {
      // throws-outside-family: parse contract — a public fromJson reports a
      // malformed document as Dart's parsers do.
      throw FormatException('An item authorization change names no item', json);
    }
    final kind = json['subjectKind'];
    final subject = json['subject'];
    return TomItemAuthorizationChange(
      item,
      subject: subject is String && (kind == null || kind == 'user')
          ? subject
          : null,
    );
  }

  /// The item key `<type>:<id>`, a pattern `<type>:<prefix>*`, or `*` for
  /// every item.
  final String item;

  /// The user the change is for, or `null` for every subject.
  final String? subject;

  /// The change as [TomItemAuthorizationChange.fromJson] reads it.
  Map<String, Object?> toJson() => {
    'item': item,
    if (subject != null) 'subject': subject,
  };

  /// Drops the answers this change names on every node.
  Future<void> invalidate() =>
      TomCacheInvalidator.invalidateItemAuthorization(item, subject: subject);

  @override
  String toString() =>
      'TomItemAuthorizationChange($item${subject == null ? '' : ' for $subject'})';
}

/// One answer of the change feed: the [changes] since the cursor asked with,
/// the cursor to ask with next, and whether more changes wait behind it.
class TomItemAuthorizationChangePage {
  /// Creates the page.
  const TomItemAuthorizationChangePage({
    required this.changes,
    required this.nextCursor,
    this.hasMore = false,
  });

  /// The changes, oldest first.
  final List<TomItemAuthorizationChange> changes;

  /// The cursor to read the following changes with.
  final String nextCursor;

  /// Whether more changes follow [nextCursor] at once.
  final bool hasMore;
}

/// A webhook delivery that cannot be trusted or read. The receiving endpoint
/// answers it with a client error; the authority retries.
class TomItemAuthorizationWebhookException extends TomServerException {
  /// Creates the exception.
  TomItemAuthorizationWebhookException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
  });
}

/// The change feed no longer holds the cursor asked with — it is older than
/// the feed's retention. Thrown by the fetch function given to
/// [TomItemAuthorizationFeedFollower], which then drops every answer and
/// continues from the current position.
class TomItemAuthorizationFeedExpiredException extends TomServerException {
  /// Creates the exception for [cursor].
  TomItemAuthorizationFeedExpiredException(String cursor)
    : super(
        'error.item_authorization.feed.cursor_expired',
        'The change feed no longer holds the cursor.',
        parameters: {'cursor': cursor},
        clientThrow: false,
      );
}

/// Verifies and applies one `itemAuthorization.changed` webhook delivery.
///
/// A delivery carries three headers and a JSON body:
///
/// | Header | Content |
/// | ------ | ------- |
/// | [eventIdHeader] | the event's id |
/// | [timestampHeader] | when it was sent, in seconds since the epoch |
/// | [signatureHeader] | `sha256=` and the hex HMAC-SHA256 of `<id>.<timestamp>.<body>` |
///
/// The HMAC key is the subscription's secret; during a rotation two
/// [secrets] are valid. A delivery older than [tolerance] is refused, so a
/// captured one cannot be replayed later. The body is
/// `{"type": "itemAuthorization.changed", "changes": [<change>, …]}` with each
/// change as [TomItemAuthorizationChange.fromJson] reads it; other event types
/// are accepted and ignored.
///
/// The application's own endpoint hands each delivery to [receive], in the
/// tenant's context when the subscription is a tenant's ([tenantId]).
class TomItemAuthorizationWebhook {
  /// Creates the receiver for a subscription with [secrets] — one, or two
  /// during a rotation.
  TomItemAuthorizationWebhook(
    List<String> secrets, {
    this.tenantId,
    this.tolerance = defaultTolerance,
    DateTime Function()? clock,
  }) : secrets = List.unmodifiable(secrets),
       _clock = clock ?? DateTime.now {
    if (secrets.isEmpty || secrets.length > 2) {
      // throws-outside-family: programmer error — a receiver is configured
      // with its subscription's one secret, or two during a rotation.
      throw ArgumentError.value(secrets.length, 'secrets', 'must be 1 or 2');
    }
  }

  /// The header carrying the event id.
  static const String eventIdHeader = 'x-tom-event-id';

  /// The header carrying the send time.
  static const String timestampHeader = 'x-tom-timestamp';

  /// The header carrying the signature.
  static const String signatureHeader = 'x-tom-signature';

  /// The event type this receiver applies.
  static const String eventType = 'itemAuthorization.changed';

  /// How old a delivery may be.
  static const Duration defaultTolerance = Duration(minutes: 5);

  /// The secrets a signature may be made with.
  final List<String> secrets;

  /// The tenant the subscription belongs to, or `null`.
  final String? tenantId;

  /// How far a delivery's timestamp may lie from now, either way.
  final Duration tolerance;

  final DateTime Function() _clock;

  /// The signature header value for [body] sent as event [eventId] at
  /// [timestamp] (seconds since the epoch) with [secret] — what the sender
  /// computes.
  static String sign(
    String secret,
    String eventId,
    String timestamp,
    String body,
  ) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return 'sha256=${mac.convert(utf8.encode('$eventId.$timestamp.$body'))}';
  }

  /// Verifies the delivery of [body] with [headers] (names in any case) and
  /// drops the answers its changes name on every node. Answers how many
  /// changes it applied — none for another event type.
  ///
  /// Throws [TomItemAuthorizationWebhookException] —
  /// `error.item_authorization.webhook.signature_invalid` for a missing or
  /// wrong signature, `…timestamp_stale` for a delivery outside [tolerance],
  /// `…payload_invalid` for a body that is not an event.
  Future<int> receive(Map<String, String> headers, String body) async {
    final lower = {
      for (final entry in headers.entries) entry.key.toLowerCase(): entry.value,
    };
    final eventId = lower[eventIdHeader];
    final timestamp = lower[timestampHeader];
    final signature = lower[signatureHeader];
    if (eventId == null ||
        timestamp == null ||
        signature == null ||
        !secrets.any(
          (secret) => _equal(sign(secret, eventId, timestamp, body), signature),
        )) {
      throw TomItemAuthorizationWebhookException(
        'error.item_authorization.webhook.signature_invalid',
        'The webhook delivery is not signed by the subscription.',
      );
    }
    final seconds = int.tryParse(timestamp);
    final sent = seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    if (sent == null || _clock().difference(sent).abs() > tolerance) {
      throw TomItemAuthorizationWebhookException(
        'error.item_authorization.webhook.timestamp_stale',
        'The webhook delivery is too old or from the future.',
        parameters: {'timestamp': timestamp},
      );
    }
    final changes = _decode(body);
    if (changes == null) return 0;
    await TomTenantContext.run(tenantId, () async {
      for (final change in changes) {
        await change.invalidate();
      }
    });
    return changes.length;
  }

  /// The changes of an [eventType] event, or `null` for another type.
  static List<TomItemAuthorizationChange>? _decode(String body) {
    try {
      final event = jsonDecode(body);
      if (event is! Map<String, Object?>) throw _payloadInvalid();
      if (event['type'] != eventType) return null;
      final changes = event['changes'];
      if (changes is! List) throw _payloadInvalid();
      return [
        for (final change in changes)
          TomItemAuthorizationChange.fromJson(change as Map<String, Object?>),
      ];
    } on FormatException {
      throw _payloadInvalid();
    } on TypeError {
      throw _payloadInvalid();
    }
  }

  static TomItemAuthorizationWebhookException _payloadInvalid() =>
      TomItemAuthorizationWebhookException(
        'error.item_authorization.webhook.payload_invalid',
        'The webhook delivery is not an item authorization event.',
      );

  /// Compares in time independent of where the strings differ.
  static bool _equal(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}

/// Follows the authority's change feed and drops, on every node, the answers
/// each change names.
///
/// [fetch] reads the feed since a cursor — `null` for the current position —
/// and throws [TomItemAuthorizationFeedExpiredException] for a cursor the feed
/// no longer holds. The client of the authority supplies it.
///
/// A follower that does not know its position — at its first poll, and after
/// an expired cursor — takes the current position and then drops every answer
/// of its tenant, since whatever changed before that position is out of its
/// reach. The cursor lives in the follower, so a restart costs one such drop.
/// Running a follower on every node is correct, since dropping twice is
/// harmless; one per cluster is enough.
class TomItemAuthorizationFeedFollower {
  /// Creates a follower reading with [fetch] every [pollInterval], in
  /// [tenantId]'s context when given.
  TomItemAuthorizationFeedFollower(
    this.fetch, {
    this.pollInterval = defaultPollInterval,
    this.tenantId,
  });

  /// How often the feed is read when nothing else is said.
  static const Duration defaultPollInterval = Duration(seconds: 30);

  /// Reads the feed since a cursor.
  final Future<TomItemAuthorizationChangePage> Function(String? cursor) fetch;

  /// How often the feed is read.
  final Duration pollInterval;

  /// The tenant whose feed this is, or `null`.
  final String? tenantId;

  String? _cursor;
  Timer? _timer;
  bool _polling = false;

  /// The cursor the next poll reads with; `null` until the position is known.
  String? get cursor => _cursor;

  /// Whether the follower polls on a timer.
  bool get isRunning => _timer != null;

  /// The longest time from a change in the authority to its answers being
  /// dropped on every node, when no webhook delivered it first.
  Duration get stalenessBound =>
      pollInterval + TomCacheInvalidator.channel.stalenessBound;

  /// Polls once, then on a timer every [pollInterval].
  Future<void> start() async {
    await poll();
    _timer?.cancel();
    // In the root zone, so the start-up flow that starts the follower does not
    // own process-lifetime work.
    _timer = Zone.root.createPeriodicTimer(pollInterval, (_) => poll());
  }

  /// Reads the feed until it has no more and drops the answers each change
  /// names; answers how many changes it applied.
  ///
  /// Runs on the timer; callable directly, which is what a test does. A poll
  /// still running when the next is due is not overlapped. The cursor
  /// advances only after a page's changes are applied, so a failure — logged —
  /// makes the next poll read the same page again.
  Future<int> poll() async {
    if (_polling) return 0;
    _polling = true;
    try {
      return await TomTenantContext.run(tenantId, _readAll);
    } catch (error) {
      tomLog.warn(
        'TomItemAuthorizationFeedFollower: reading the change feed failed, '
        'retrying at the next poll: $error',
      );
      return 0;
    } finally {
      _polling = false;
    }
  }

  Future<int> _readAll() async {
    var applied = 0;
    while (true) {
      final TomItemAuthorizationChangePage page;
      final known = _cursor;
      if (known == null) {
        page = await _takePosition();
      } else {
        try {
          page = await fetch(known);
        } on TomItemAuthorizationFeedExpiredException {
          _cursor = null;
          continue;
        }
      }
      for (final change in page.changes) {
        await change.invalidate();
      }
      applied += page.changes.length;
      _cursor = page.nextCursor;
      if (!page.hasMore) return applied;
    }
  }

  /// Takes the current position first and drops every answer after: an answer
  /// cached in between was given after that position, so a later change to it
  /// is still ahead of the cursor.
  Future<TomItemAuthorizationChangePage> _takePosition() async {
    final page = await fetch(null);
    await TomCacheInvalidator.invalidateItemAuthorization('*');
    return page;
  }

  /// Stops the timer. Idempotent.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
