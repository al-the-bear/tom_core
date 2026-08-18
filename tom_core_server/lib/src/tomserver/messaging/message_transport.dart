/// The contract every delivery channel implements, and the transports that do
/// not need a network.
///
/// ## The one distinction a transport must get right
///
/// Delivery fails in two fundamentally different ways, and conflating them is
/// the classic mailer bug:
///
/// - **Transient** — the far side is down, the connection dropped, the server
///   said "try later" (SMTP 4xx). Retrying is the *only* correct response.
/// - **Permanent** — the address does not exist, the credential was rejected,
///   the message was refused (SMTP 5xx). Retrying is guaranteed to fail
///   identically, so it wastes the budget and, worse, delays the report of a
///   failure the caller could have acted on at once.
///
/// [TomDeliveryException.isPermanent] carries that judgement, and it is the
/// *transport* that makes it, because only the transport can read the far
/// side's answer. The outbox does not second-guess it: a permanent failure
/// mixes in the kernel's `TomPermanentFailure`, which the scheduler already
/// understands, so the retry decision is made once and honoured everywhere.
///
/// ## What a transport is not responsible for
///
/// Not retrying (the outbox and the scheduler own that), not queueing, and not
/// deciding *whether* to send. A transport does one attempt at one message and
/// reports what happened. That is what makes [TomMemoryMessageTransport] a
/// complete stand-in for [TomSmtpTransport] in a test: there is nothing else in
/// the interface to fake.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'message.dart';
import 'mime_encoder.dart';

// =============================================================================
// OUTCOME
// =============================================================================

/// What became of one delivery attempt.
enum TomDeliveryOutcome {
  /// The far side accepted the message. For most channels this means "accepted
  /// for delivery", not "read by a human" — the transport cannot promise more
  /// than its protocol does.
  delivered,

  /// The far side refused it, and would refuse it again.
  rejected,

  /// The attempt did not conclude and should be repeated.
  deferred,

  /// Nothing was sent because the transport is a stand-in.
  discarded,
}

/// The result of one delivery attempt.
class TomDeliveryReceipt {
  /// The [TomMessage.id] this receipt concerns.
  final String messageId;

  /// What happened.
  final TomDeliveryOutcome outcome;

  /// The far side's identifier for the message, when the protocol supplies one.
  ///
  /// For SMTP this is whatever the server echoed on the final `250`, which is
  /// how a delivery is traced into someone else's logs.
  final String? remoteId;

  /// When the attempt concluded.
  final DateTime at;

  /// The far side's own words, kept verbatim for diagnosis.
  final String? detail;

  /// Recipients the far side refused while accepting the others.
  ///
  /// A partial delivery is a real outcome — a mail to five people where one
  /// address is dead — and reporting it as either success or failure loses
  /// information the operator needs.
  final List<String> rejectedRecipients;

  /// Creates a receipt.
  TomDeliveryReceipt({
    required this.messageId,
    required this.outcome,
    this.remoteId,
    DateTime? at,
    this.detail,
    this.rejectedRecipients = const [],
  }) : at = at ?? DateTime.now();

  /// Whether the far side took responsibility for the message.
  bool get isDelivered => outcome == TomDeliveryOutcome.delivered;

  /// Whether some but not all recipients were accepted.
  bool get isPartial => isDelivered && rejectedRecipients.isNotEmpty;

  /// Encodes this receipt as a JSON-native map.
  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'outcome': outcome.name,
    if (remoteId != null) 'remoteId': remoteId,
    'at': at.toIso8601String(),
    if (detail != null) 'detail': detail,
    if (rejectedRecipients.isNotEmpty) 'rejectedRecipients': rejectedRecipients,
  };

  @override
  String toString() =>
      'TomDeliveryReceipt($messageId, ${outcome.name}'
      '${remoteId == null ? '' : ', remote $remoteId'})';
}

// =============================================================================
// FAILURE
// =============================================================================

/// A delivery attempt that did not succeed.
///
/// [isPermanent] is the whole point of the type. A permanent failure also mixes
/// in the kernel's [TomPermanentFailure], so it does not merely *describe*
/// itself as unretryable — the scheduler reads the marker and acts on it,
/// without the outbox translating anything.
class TomDeliveryException extends TomMessagingException {
  /// Whether retrying this exact message could ever succeed.
  final bool isPermanent;

  /// The protocol's own status code, when it had one (e.g. SMTP `550`).
  final int? statusCode;

  /// Creates a delivery failure.
  ///
  /// Prefer [TomDeliveryException.permanent] and
  /// [TomDeliveryException.transient], which cannot be built with the wrong
  /// classification by accident.
  TomDeliveryException(
    super.key,
    super.defaultUserMessage, {
    required this.isPermanent,
    this.statusCode,
    super.parameters,
    super.rootException,
    super.stack,
  });

  /// A failure that retrying cannot fix.
  static TomPermanentDeliveryException permanent(
    String key,
    String message, {
    int? statusCode,
    Map<String, dynamic>? parameters,
    Object? rootException,
    StackTrace? stack,
  }) => TomPermanentDeliveryException(
    key,
    message,
    statusCode: statusCode,
    parameters: parameters,
    rootException: rootException,
    stack: stack,
  );

  /// A failure that a later attempt may well survive.
  static TomDeliveryException transient(
    String key,
    String message, {
    int? statusCode,
    Map<String, dynamic>? parameters,
    Object? rootException,
    StackTrace? stack,
  }) => TomDeliveryException(
    key,
    message,
    isPermanent: false,
    statusCode: statusCode,
    parameters: parameters,
    rootException: rootException,
    stack: stack,
  );

  @override
  String toString() =>
      '${super.toString()} '
      '(${isPermanent ? 'permanent' : 'transient'}'
      '${statusCode == null ? '' : ', status $statusCode'})';
}

/// A [TomDeliveryException] the scheduler will not retry.
///
/// A separate type only so it can carry the [TomPermanentFailure] marker; every
/// caller should reach it through [TomDeliveryException.permanent].
class TomPermanentDeliveryException extends TomDeliveryException
    with TomPermanentFailure {
  /// Creates a permanent delivery failure.
  TomPermanentDeliveryException(
    super.key,
    super.defaultUserMessage, {
    super.statusCode,
    super.parameters,
    super.rootException,
    super.stack,
  }) : super(isPermanent: true);
}

// =============================================================================
// TRANSPORT
// =============================================================================

/// One delivery channel.
///
/// Implementations do a single attempt and report the outcome. They must throw
/// [TomDeliveryException] — classified — rather than returning a failed
/// receipt, so that a caller who ignores the return value cannot silently drop
/// a message.
abstract class TomMessageTransport {
  /// Creates a transport.
  const TomMessageTransport();

  /// The channel this transport delivers.
  TomMessageChannel get channel;

  /// Whether this transport can express `Cc`/`Bcc`.
  ///
  /// Declared rather than assumed, because a transport that cannot (SMS, push)
  /// must not quietly promote copies to primary recipients — the recipients
  /// would then see each other, which for a blind copy is a disclosure.
  bool get supportsCopies => false;

  /// Whether this transport can carry [TomAttachment]s.
  bool get supportsAttachments => false;

  /// Delivers [message], once.
  ///
  /// Throws [TomDeliveryException] on failure. Must not retry: retrying is the
  /// outbox's job, and a transport with its own loop makes the configured retry
  /// policy a lie.
  Future<TomDeliveryReceipt> send(TomMessage message);

  /// Releases whatever the transport owns.
  Future<void> close() async {}

  /// Rejects a message this transport cannot faithfully deliver.
  ///
  /// Called by implementations from [send]. The failure is *permanent* by
  /// construction: a message with an attachment does not become deliverable
  /// over a channel that has no attachments by being tried again.
  void checkSupported(TomMessage message) {
    if (message.channel != channel) {
      throw TomDeliveryException.permanent(
        'messaging.transport.wrong_channel',
        'A ${channel.name} transport was handed a '
            '${message.channel.name} message.',
        parameters: {'messageId': message.id, 'channel': message.channel.name},
      );
    }
    if (!supportsAttachments && message.attachments.isNotEmpty) {
      throw TomDeliveryException.permanent(
        'messaging.transport.no_attachments',
        'The ${channel.name} transport cannot carry attachments.',
        parameters: {'messageId': message.id},
      );
    }
    if (!supportsCopies &&
        message.recipients.any((r) => r.kind != TomRecipientKind.to)) {
      throw TomDeliveryException.permanent(
        'messaging.transport.no_copies',
        'The ${channel.name} transport cannot express Cc/Bcc; delivering the '
            'copies as primary recipients would disclose them to each other.',
        parameters: {'messageId': message.id},
      );
    }
  }
}

// =============================================================================
// ROUTER
// =============================================================================

/// Resolves a message's channel to the transport that delivers it.
///
/// This is what makes `email` a *name* in a spec rather than a class reference:
/// the spec says which channel, the deployment says which transport, and
/// swapping SMTP for a stand-in in a test changes one registration rather than
/// every call site.
class TomMessageRouter {
  final Map<String, TomMessageTransport> _transports = {};

  /// Creates a router, optionally pre-registering [transports].
  TomMessageRouter([Iterable<TomMessageTransport> transports = const []]) {
    transports.forEach(register);
  }

  /// Registers [transport] for its own channel, replacing any previous one.
  void register(TomMessageTransport transport) =>
      _transports[transport.channel.name] = transport;

  /// Removes the transport registered for [channel], if any.
  void deregister(TomMessageChannel channel) =>
      _transports.remove(channel.name);

  /// The channels that currently have a transport.
  List<TomMessageChannel> get channels =>
      _transports.keys.map(TomMessageChannel.new).toList(growable: false);

  /// Whether [channel] can be delivered.
  bool supports(TomMessageChannel channel) =>
      _transports.containsKey(channel.name);

  /// The transport for [message]'s channel.
  ///
  /// An unrouted channel is a *permanent* failure: no amount of retrying adds a
  /// transport, and a deployment that names a channel it did not wire up needs
  /// to hear about it now rather than after the retry budget runs out.
  TomMessageTransport transportFor(TomMessage message) {
    final transport = _transports[message.channel.name];
    if (transport == null) {
      throw TomDeliveryException.permanent(
        'messaging.router.unrouted_channel',
        'No transport is registered for channel '
            '"${message.channel.name}".',
        parameters: {
          'messageId': message.id,
          'channel': message.channel.name,
          'registered': _transports.keys.join(', '),
        },
      );
    }
    return transport;
  }

  /// Delivers [message] through its channel's transport.
  ///
  /// `async` deliberately, so that [transportFor]'s unrouted-channel failure
  /// arrives *on the returned future* rather than being thrown synchronously
  /// out of the call. A caller who handles delivery failures the way a
  /// future-returning API invites — `.catchError`, or an `await` in a `try` —
  /// would otherwise never see the one failure it is most likely to hit in a
  /// half-configured deployment.
  Future<TomDeliveryReceipt> send(TomMessage message) async =>
      transportFor(message).send(message);

  /// Closes every registered transport.
  Future<void> close() async {
    for (final transport in _transports.values) {
      await transport.close();
    }
    _transports.clear();
  }
}

// =============================================================================
// STAND-IN TRANSPORTS
// =============================================================================

/// A transport that keeps everything it is given and sends nothing.
///
/// This is the answer to "a spec names `email`, but the test has no mail
/// server": register one of these for [TomMessageChannel.email] and the whole
/// path — composition, routing, the outbox, retry — runs unchanged, with
/// [sent] as the assertion surface.
///
/// It accepts copies and attachments deliberately. A stand-in that rejected
/// what the real transport accepts would make tests pass and production fail,
/// which is worse than having no stand-in.
class TomMemoryMessageTransport extends TomMessageTransport {
  /// Every message this transport was handed, in order.
  final List<TomMessage> sent = [];

  /// Every receipt it issued, in order.
  final List<TomDeliveryReceipt> receipts = [];

  @override
  final TomMessageChannel channel;

  /// A failure to raise instead of accepting the next message.
  ///
  /// Consumed on use, so a test can make exactly the first attempt fail and
  /// then assert that the retry succeeded — which is the behaviour that
  /// actually needs proving, and cannot be shown by a transport that either
  /// always works or always fails.
  TomDeliveryException? failNext;

  /// A failure to raise on every message.
  TomDeliveryException? failAlways;

  /// Creates a stand-in transport for [channel].
  TomMemoryMessageTransport({this.channel = TomMessageChannel.email});

  @override
  bool get supportsCopies => true;

  @override
  bool get supportsAttachments => true;

  /// How many messages have been accepted.
  int get count => sent.length;

  /// The most recently accepted message, or `null`.
  TomMessage? get last => sent.isEmpty ? null : sent.last;

  /// Forgets everything recorded so far.
  void clear() {
    sent.clear();
    receipts.clear();
  }

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);
    final failure = failAlways ?? failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    sent.add(message);
    final receipt = TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      remoteId: 'memory-${sent.length}',
      detail: 'Accepted by TomMemoryMessageTransport',
    );
    receipts.add(receipt);
    return receipt;
  }
}

/// A transport that discards everything and records nothing.
///
/// For a deployment that must run with notifications configured but silenced —
/// a staging environment that would otherwise mail real customers. It reports
/// [TomDeliveryOutcome.discarded] rather than `delivered`, so a receipt never
/// claims something reached a recipient when it did not.
class TomNoOpMessageTransport extends TomMessageTransport {
  @override
  final TomMessageChannel channel;

  /// Whether to log each discarded message at debug level.
  final bool logDiscarded;

  /// Creates a discarding transport for [channel].
  const TomNoOpMessageTransport({
    this.channel = TomMessageChannel.email,
    this.logDiscarded = true,
  });

  @override
  bool get supportsCopies => true;

  @override
  bool get supportsAttachments => true;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);
    if (logDiscarded) {
      tomLog.debug(
        'Discarding ${message.channel.name} message ${message.id} '
        'to ${message.envelopeAddresses.join(', ')} (no-op transport).',
      );
    }
    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.discarded,
      detail: 'Discarded by TomNoOpMessageTransport',
    );
  }
}

/// A transport that writes each message to a file instead of sending it.
///
/// The local-development counterpart of [TomMemoryMessageTransport]: a
/// developer wants to *look* at the mail, including how the MIME tree came
/// out, and an in-memory list cannot be opened in a mail client. Files are
/// written in RFC 5322 form with an `.eml` extension precisely so they can be.
class TomFileMessageTransport extends TomMessageTransport {
  /// Where message files are written.
  final Directory directory;

  @override
  final TomMessageChannel channel;

  /// Creates a file transport writing into [directory], which is created if it
  /// does not exist.
  TomFileMessageTransport({
    required this.directory,
    this.channel = TomMessageChannel.email,
  }) {
    if (!directory.existsSync()) directory.createSync(recursive: true);
  }

  @override
  bool get supportsCopies => true;

  @override
  bool get supportsAttachments => true;

  /// The message files written so far, oldest first.
  List<File> get files =>
      directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.eml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);
    final stamp = message.createdAt
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final file = File(p.join(directory.path, '${stamp}_${message.id}.eml'));
    try {
      await file.writeAsString(TomMimeEncoder().encode(message));
    } on FileSystemException catch (error, stack) {
      // A full or unwritable disk is exactly the kind of thing that clears up,
      // so this is the one failure here that is worth retrying.
      throw TomDeliveryException.transient(
        'messaging.file_transport.write_failed',
        'Could not write message ${message.id} to ${file.path}.',
        parameters: {'messageId': message.id, 'path': file.path},
        rootException: error,
        stack: stack,
      );
    }
    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      remoteId: file.path,
      detail: 'Written to ${file.path}',
    );
  }
}
