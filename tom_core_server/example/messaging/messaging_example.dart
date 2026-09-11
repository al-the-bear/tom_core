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
/// Run with `dart run example/messaging/messaging_example.dart`. Every step
/// checks its own result and the run fails when one does not hold, so a green
/// run is a verification and not just a transcript. `test/messaging_test.dart`
/// runs this file under that exact command and requires it to exit 0, which is
/// what keeps the checks honest once nobody runs the example by hand.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

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
  check(
    message.channel == TomMessageChannel.email,
    'TomMessage.email composes on the email channel',
  );
  check(
    message.preferredBody!.isHtml,
    'bodies are least-preferred first, so the HTML part is the preferred one',
  );

  // 2. Channels are open, not an enum. A deployment with an internal channel
  //    names it and registers a transport; it does not patch the framework.
  const slack = TomMessageChannel('slack');
  print('2. an unanticipated channel  : ${slack.name}');
  check(
    slack == const TomMessageChannel('slack'),
    'channels compare by name, so a deployment can name one the framework '
    'never anticipated',
  );

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
  check(
    copied.envelopeAddresses.contains('archive@example.com'),
    'the Bcc address rides the delivery envelope, which is what the relay '
    'routes on',
  );
  check(
    !document.contains('archive@example.com'),
    'the Bcc address appears nowhere in the MIME document, which is what a '
    'recipient reads',
  );

  // 4. The document structure follows the content rather than being fixed:
  //    one body is a single part, text+html is multipart/alternative, an inline
  //    image makes it multipart/related, a file attachment multipart/mixed.
  final rendered = TomMimeEncoder().encode(message);
  print(
    '4. content type              : '
    '${rendered.split('\r\n').firstWhere((l) => l.startsWith('Content-Type'))}',
  );
  check(
    rendered.contains('multipart/alternative'),
    'a message carrying both text and html encodes as multipart/alternative',
  );

  // 5. A memory transport is what makes a spec that names `email` exercisable.
  //    Nothing leaves the process; the messages are inspectable afterwards.
  final memory = TomMemoryMessageTransport();
  final receipt = await memory.send(message);
  print(
    '5. delivered to memory       : ${receipt.outcome.name}, '
    'captured ${memory.count}',
  );
  check(
    receipt.isDelivered,
    'the memory transport reports a delivery, so a spec naming `email` is '
    'exercisable without a relay',
  );

  // 6. A no-op transport is the other stand-in: it accepts and *discards*, so a
  //    local run of a server that sends mail neither fails nor delivers.
  //    `discarded` rather than `delivered` — the receipt does not claim
  //    something that did not happen.
  const noOp = TomNoOpMessageTransport();
  final discarded = await noOp.send(message);
  print('6. no-op outcome             : ${discarded.outcome.name}');
  check(
    discarded.outcome == TomDeliveryOutcome.discarded,
    'the no-op transport reports `discarded`, not `delivered` — the receipt '
    'does not claim something that did not happen',
  );

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
  var unroutedThrew = false;
  try {
    await router.send(
      TomMessage(
        channel: slack,
        recipients: [TomRecipient('#builds')],
        bodies: const [TomMessageBody.text('The 03:00 build failed.')],
      ),
    );
  } on TomDeliveryException catch (e) {
    unroutedThrew = true;
    print('   unrouted "slack"          : permanent=${e.isPermanent}');
    check(
      e.isPermanent,
      'an unrouted channel fails permanently: no number of retries adds a '
      'transport',
    );
  }
  // Checked outside the handler on purpose. A check written inside `catch`
  // cannot fail when the `catch` never runs, so a router that quietly accepted
  // the unrouted channel would skip the block and leave the step green — the
  // same "verifies nothing" shape the `check` helper above exists to close.
  check(
    unroutedThrew,
    'sending to an unrouted channel throws rather than silently succeeding',
  );

  // 8. The transient/permanent distinction is the whole retry policy. SMTP
  //    states it on the wire — 4xx means "try later", 5xx means "do not" — and
  //    a permanent failure carries a marker the *scheduler* honours, so the
  //    decision is made once and not re-derived at every layer.
  final deferred = TomDeliveryException.transient(
    'x.deferred',
    'Greylisted, try later.',
  );
  final rejected = TomDeliveryException.permanent(
    'x.rejected',
    'No such mailbox.',
  );
  for (final failure in <TomDeliveryException>[deferred, rejected]) {
    print(
      '8. ${failure.key.padRight(12)} '
      'permanent=${failure.isPermanent} '
      'scheduler gives up=${failure is TomPermanentFailure}',
    );
  }
  // Two checks that could once have been written here are deliberately absent.
  // Asserting `isPermanent == (failure is TomPermanentFailure)` would assert
  // nothing: `isPermanent` *is* that test, one fact with one representation.
  // And asserting `deferred is TomTransientDeliveryException` is rejected by
  // the analyzer as always true, because the builders are statically typed to
  // their own subtypes — the compiler proving it outright is the stronger
  // statement. What is left is the classification a caller actually acts on.
  check(
    !deferred.isPermanent,
    'transient() yields a failure the scheduler will retry',
  );
  check(
    rejected.isPermanent,
    'permanent() yields a failure carrying the marker that stops the retry '
    'loop',
  );

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
  check(
    memory.count == 0,
    'send() returns once the message is durably stored, without delivering it',
  );

  // A tick is a *completed* pass: it returns once every message it picked up
  // has been through a transport and its outcome recorded. That is what makes
  // the count below true on the very next line, rather than only after a
  // receipt subscription or an event-queue pump — and what lets a shutdown
  // path empty the queue before it closes.
  await outbox.tick();
  print('   delivered after a tick    : ${memory.count}');
  check(memory.count == 1, 'the tick delivered the queued message');

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
  check(
    queued.length == 1,
    'two sends of one message id queue one run, so an uncertain caller '
    'retrying cannot cause two deliveries',
  );
  await outbox.close();

  // 11. A file transport writes each message to a `.eml` file — a local run
  //     that produces something openable, without a relay.
  final dir = await Directory.systemTemp.createTemp('tom_messaging_example_');
  try {
    final files = TomFileMessageTransport(directory: dir);
    await files.send(message);
    print('11. files written            : ${files.files.length}');
    check(
      files.files.length == 1,
      'the file transport wrote one .eml file, so a local run produces '
      'something openable without a relay',
    );
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
  check(
    settings.port == 587,
    'an unset port resolves from the security mode: STARTTLS means submission '
    'on 587',
  );
  check(
    !settings.toString().contains('supplied'),
    'the password does not leak through toString, so settings are safe to log',
  );
  // In a server this is where the transport would be registered:
  //   router.register(TomSmtpTransport(settings));
  // and the settings would come from configuration:
  //   final settings = TomSmtpSettings.fromConfiguration(config);
}

Future<void> main() async {
  await run();
}
