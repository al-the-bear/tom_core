/// Executable example for the messaging module of `tom_core_server`.
///
/// Demonstrates the outbound message substrate without a mail server: the
/// channel-neutral message shape, the MIME document an SMTP relay would
/// receive, the stand-in transports that make `email` exercisable in tests, the
/// router that maps a channel to a transport, the transient/permanent
/// distinction that decides whether a failure is worth retrying, and the
/// durable outbox that queues delivery onto the kernel's job scheduler.
///
/// The one thing not shown here is a socket. [TomSmtpTransport] talks to a real
/// relay in production; its protocol is driven through the [TomSmtpConnection]
/// interface, which is what lets `test/messaging_test.dart` assert the
/// conversation — STARTTLS, AUTH, a rejected recipient, a `4xx` deferral —
/// without one.
///
/// Run with `dart run example/messaging/messaging_example.dart`.
/// The same behaviour is covered by `test/messaging_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

// ignore_for_file: avoid_print

Future<void> run() async {
  // 1. A message is composed, not "an email is sent". The shape names
  //    recipients, subject, body parts and attachments — and a *channel*, so
  //    that the same envelope can one day be an SMS or a push without the
  //    caller learning a second API.
  final message = TomMessage.email(
    from: TomRecipient('build@example.com', displayName: 'Build Robot'),
    to: [TomRecipient('ada@example.com', displayName: 'Ada')],
    subject: 'Nightly build failed',
    text: 'The 03:00 build failed on step 4.',
    html: '<p>The 03:00 build failed on <b>step 4</b>.</p>',
  );
  print('1. channel                   : ${message.channel.name}');
  print(
    '   bodies (least preferred first): '
    '${message.bodies.map((b) => b.mediaType).join(', ')}',
  );
  assert(message.channel == TomMessageChannel.email);
  assert(message.preferredBody!.isHtml);

  // 2. Channels are open, not an enum. A deployment with an internal channel
  //    names it and registers a transport; it does not patch the framework.
  const slack = TomMessageChannel('slack');
  print('2. an unanticipated channel  : ${slack.name}');
  assert(slack == const TomMessageChannel('slack'));

  // 3. Blind copies are blind. They ride the delivery *envelope*, which is what
  //    the relay routes on, and never appear in a header, which is what a
  //    recipient reads.
  final copied = TomMessage(
    from: TomRecipient('build@example.com'),
    recipients: [
      TomRecipient('ada@example.com'),
      TomRecipient('team@example.com', kind: TomRecipientKind.cc),
      TomRecipient('archive@example.com', kind: TomRecipientKind.bcc),
    ],
    subject: 'Release cut',
    bodies: const [TomMessageBody.text('1.4.0 is tagged.')],
  );
  final document = TomMimeEncoder().encode(copied);
  print('3. envelope addresses        : ${copied.envelopeAddresses.length}');
  print('   Bcc appears in document?  : ${document.contains('archive@')}');
  assert(copied.envelopeAddresses.contains('archive@example.com'));
  assert(!document.contains('archive@example.com'));

  // 4. The document structure follows the content rather than being fixed:
  //    one body is a single part, text+html is multipart/alternative, an inline
  //    image makes it multipart/related, a file attachment multipart/mixed.
  final rendered = TomMimeEncoder().encode(message);
  print(
    '4. content type              : '
    '${rendered.split('\r\n').firstWhere((l) => l.startsWith('Content-Type'))}',
  );
  assert(rendered.contains('multipart/alternative'));

  // 5. A memory transport is what makes a spec that names `email` exercisable.
  //    Nothing leaves the process; the messages are inspectable afterwards.
  final memory = TomMemoryMessageTransport();
  final receipt = await memory.send(message);
  print(
    '5. delivered to memory       : ${receipt.outcome.name}, '
    'captured ${memory.count}',
  );
  assert(receipt.isDelivered);

  // 6. A no-op transport is the other stand-in: it accepts and *discards*, so a
  //    local run of a server that sends mail neither fails nor delivers.
  //    `discarded` rather than `delivered` — the receipt does not claim
  //    something that did not happen.
  const noOp = TomNoOpMessageTransport();
  final discarded = await noOp.send(message);
  print('6. no-op outcome             : ${discarded.outcome.name}');
  assert(discarded.outcome == TomDeliveryOutcome.discarded);

  // 7. The router maps a channel to a transport. An unrouted channel fails
  //    *permanently*: no number of retries adds a transport, and a deployment
  //    that named a channel it did not wire up should hear about it now.
  final router = TomMessageRouter([
    TomMemoryMessageTransport(),
    TomNoOpMessageTransport(channel: TomMessageChannel.sms),
  ]);
  print(
    '7. routed channels           : '
    '${router.channels.map((c) => c.name).join(', ')}',
  );
  try {
    await router.send(
      TomMessage(
        channel: slack,
        recipients: [TomRecipient('#builds')],
        bodies: const [TomMessageBody.text('The 03:00 build failed.')],
      ),
    );
  } on TomDeliveryException catch (e) {
    print('   unrouted "slack"          : permanent=${e.isPermanent}');
    assert(e.isPermanent);
  }

  // 8. The transient/permanent distinction is the whole retry policy. SMTP
  //    states it on the wire — 4xx means "try later", 5xx means "do not" — and
  //    a permanent failure carries a marker the *scheduler* honours, so the
  //    decision is made once and not re-derived at every layer.
  final failures = <TomDeliveryException>[
    TomDeliveryException.transient('x.deferred', 'Greylisted, try later.'),
    TomDeliveryException.permanent('x.rejected', 'No such mailbox.'),
  ];
  for (final failure in failures) {
    print(
      '8. ${failure.key.padRight(12)} '
      'permanent=${failure.isPermanent} '
      'scheduler gives up=${failure is TomPermanentFailure}',
    );
    // The marker and the flag agree because they are the same decision: the
    // scheduler stops retrying on [TomPermanentFailure], and nothing else in
    // the stack re-derives the classification.
    assert(failure.isPermanent == (failure is TomPermanentFailure));
  }

  // 9. Delivery is queued, not synchronous. `send` returns once the message is
  //    durably stored; the outbox's scheduler delivers afterwards. There is no
  //    retry loop here — durability, backoff, at-most-one-runner-per-message
  //    and failure alerting all belong to the kernel's job scheduler, and
  //    building a second copy of them would give "why is this stuck?" two
  //    answers.
  final store = TomMemoryJobStore();
  final outbox = TomMessageOutbox(
    router: TomMessageRouter([memory]),
    store: store,
  );
  memory.clear();

  await outbox.send(message);
  print('9. delivered before a tick   : ${memory.count}');
  assert(memory.count == 0);

  // A tick *starts* the pass and returns; it does not wait the deliveries out,
  // because one slow transport must not hold up the next window of a fast one.
  // So "has it been delivered yet?" is answered by [TomMessageOutbox.receipts],
  // not by the tick's future. Subscribe before ticking — the stream is a
  // broadcast, so a listener attached afterwards would miss the receipt it is
  // waiting for and wait forever.
  final delivered = outbox.receipts.first;
  await outbox.tick();
  await delivered;
  print('   delivered after a tick    : ${memory.count}');
  assert(memory.count == 1);

  // 10. The message id is the idempotence key: a caller retrying a `send` it is
  //     unsure completed replaces the queued run rather than queueing a second
  //     copy, so an uncertain caller cannot cause two deliveries.
  await outbox.send(message);
  await outbox.send(message);
  final queued = (await store.all())
      .where((r) => r.jobName == tomOutboxJobName)
      .map((r) => r.id)
      .toSet();
  print('10. distinct runs after two sends: ${queued.length}');
  assert(queued.length == 1);
  outbox.close();

  // 11. A file transport writes each message to a `.eml` file — a local run
  //     that produces something openable, without a relay.
  final dir = await Directory.systemTemp.createTemp('tom_messaging_example_');
  try {
    final files = TomFileMessageTransport(directory: dir);
    await files.send(message);
    print('11. files written            : ${files.files.length}');
    assert(files.files.length == 1);
  } finally {
    await dir.delete(recursive: true);
  }

  // 12. Real SMTP is configured, never coded. The declarations live on the
  //     server configuration; `smtpPassword` is secret-bearing, so its *value*
  //     is supplied out-of-band at deploy time and never authored into a spec
  //     or a checked-in configuration tree. An unset host is not an error — it
  //     is how a deployment says "this server sends no mail".
  final settings = TomSmtpSettings(
    host: 'relay.example.com',
    security: TomSmtpSecurity.startTls,
    username: 'mailer',
    password: 'supplied-at-deploy-time',
    defaultFrom: TomRecipient('build@example.com'),
  );
  print('12. resolved port            : ${settings.port}');
  print(
    '    toString leaks password? : '
    '${settings.toString().contains('supplied')}',
  );
  assert(settings.port == 587);
  assert(!settings.toString().contains('supplied'));
  // In a server this is where the transport would be registered:
  //   router.register(TomSmtpTransport(settings));
  // and the settings would come from configuration:
  //   final settings = TomSmtpSettings.fromConfiguration(config);
}

Future<void> main() async {
  await run();
}
