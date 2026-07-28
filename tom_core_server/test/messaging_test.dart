import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Messaging-substrate tests, verified without a mail server.
///
/// Everything here is reachable without a socket, and that is a property of the
/// design rather than a convenience of the tests: the document is rendered by a
/// [TomMimeEncoder] that returns a string, and the protocol is driven through a
/// [TomSmtpConnection] interface. The branches that matter most — a relay that
/// does not offer STARTTLS, a rejected credential, one dead address in a
/// distribution list, a `4xx` deferral — are precisely the ones a real relay
/// will not produce on demand.

// =============================================================================
// FIXTURES
// =============================================================================

/// A clock that only moves when a test moves it.
class _FakeClock {
  DateTime now;

  _FakeClock(this.now);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

/// A scripted SMTP server.
///
/// Each entry in [replies] answers one read, in order. [commands] records what
/// the transport said, which is how the protocol itself — not merely its
/// outcome — is asserted.
class _ScriptedSmtpConnection implements TomSmtpConnection {
  final List<TomSmtpReply> replies;
  final List<String> commands = [];
  String? data;
  bool upgraded = false;
  bool closed = false;
  int _next = 0;

  _ScriptedSmtpConnection(this.replies);

  @override
  Future<void> write(String command) async => commands.add(command);

  @override
  Future<void> writeData(String payload) async {
    commands.add('DATA<body>');
    data = payload;
  }

  @override
  Future<TomSmtpReply> readReply() async {
    if (_next >= replies.length) {
      throw TomDeliveryException.transient(
        'test.smtp.script_exhausted',
        'The script ran out of replies after ${commands.length} commands: '
            '${commands.join(' | ')}',
      );
    }
    return replies[_next++];
  }

  @override
  Future<void> upgradeToTls() async => upgraded = true;

  @override
  Future<void> close() async => closed = true;
}

TomSmtpReply _reply(int code, String text) => TomSmtpReply(code, [text]);

/// The replies of a relay that accepts everything, up to but excluding `RCPT`.
List<TomSmtpReply> _opening({bool auth = false, bool startTls = false}) => [
  _reply(220, 'relay.example.com ESMTP'),
  TomSmtpReply(250, [
    'relay.example.com',
    if (startTls) 'STARTTLS',
    if (auth) 'AUTH PLAIN LOGIN',
  ]),
];

TomSmtpSettings _settings({
  TomSmtpSecurity security = TomSmtpSecurity.none,
  String? username,
  String? password,
  TomRecipient? defaultFrom,
}) => TomSmtpSettings(
  host: 'relay.example.com',
  port: 25,
  security: security,
  username: username,
  password: password,
  defaultFrom: defaultFrom,
);

TomMessage _mail({
  String? id,
  List<TomRecipient>? to,
  String? subject = 'Subject',
  String? text = 'Body',
  String? html,
  List<TomAttachment> attachments = const [],
  // An address rather than a recipient: [TomRecipient] validates in its body
  // and so cannot be const, which a default value must be. Passing
  // `fromAddress: null` is how a test asks for a message with no sender.
  String? fromAddress = 'sender@example.com',
}) => TomMessage.email(
  id: id,
  from: fromAddress == null ? null : TomRecipient(fromAddress),
  to: to ?? [TomRecipient('to@example.com')],
  subject: subject,
  text: text,
  html: html,
  attachments: attachments,
);

void main() {
  // ===========================================================================
  // THE SHAPE
  // ===========================================================================

  group('TomMessageChannel (open rather than closed)', () {
    test('the four channels CE-NT names are constants', () {
      expect(TomMessageChannel.standard.map((c) => c.name), [
        'email',
        'sms',
        'push',
        'webhook',
      ]);
    });

    test('a channel nobody anticipated can still be named', () {
      // The point of not using an enum: a deployment with an internal channel
      // does not have to patch the framework to route it.
      const slack = TomMessageChannel('slack');
      expect(slack.name, 'slack');
      expect(slack == const TomMessageChannel('slack'), isTrue);
      expect(slack == TomMessageChannel.email, isFalse);
    });

    test('equal channels hash equally, so they work as map keys', () {
      final routed = {TomMessageChannel.email: 1};
      expect(routed[const TomMessageChannel('email')], 1);
    });
  });

  group('TomMessage', () {
    test('an unaddressed message is rejected at composition', () {
      // Not at delivery: the caller who forgot the recipient is on the stack
      // now, and would not be minutes later on a retry in another isolate.
      expect(
        () => TomMessage(recipients: []),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('an omitted id is generated, so every message is correlatable', () {
      final a = _mail();
      final b = _mail();
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
    });

    test('the email factory orders bodies least-preferred first', () {
      final message = _mail(text: 'plain', html: '<p>rich</p>');
      expect(message.bodies.first.mediaType, 'text/plain');
      expect(message.preferredBody!.isHtml, isTrue);
      expect(message.textBody!.content, 'plain');
      expect(message.htmlBody!.content, '<p>rich</p>');
    });

    test('the envelope includes blind copies', () {
      // The envelope is what a transport delivers to; the *headers* are what a
      // recipient reads. Bcc belongs in exactly one of them.
      final message = TomMessage(
        recipients: [
          TomRecipient('to@example.com'),
          TomRecipient('cc@example.com', kind: TomRecipientKind.cc),
          TomRecipient('bcc@example.com', kind: TomRecipientKind.bcc),
        ],
      );
      expect(message.envelopeAddresses, hasLength(3));
      expect(message.envelopeAddresses, contains('bcc@example.com'));
      expect(message.recipientsOf(TomRecipientKind.bcc), hasLength(1));
    });

    test('headers and metadata are unmodifiable once composed', () {
      final message = _mail();
      expect(() => message.headers['X-Late'] = 'no', throwsUnsupportedError);
      expect(() => message.metadata['late'] = 'no', throwsUnsupportedError);
    });

    test('copyWith fills a sender without mutating the original', () {
      // A transport supplying its default From must not edit the caller's
      // message, or a retry operates on something the first attempt invented.
      final original = _mail(fromAddress: null);
      final resolved = original.copyWith(
        from: TomRecipient('default@example.com'),
      );
      expect(original.from, isNull);
      expect(resolved.from!.address, 'default@example.com');
      expect(resolved.id, original.id);
    });

    test('round-trips through JSON with every field populated', () {
      final original = TomMessage(
        id: 'msg-1',
        channel: TomMessageChannel.email,
        from: TomRecipient('from@example.com', displayName: 'From'),
        replyTo: TomRecipient('reply@example.com'),
        recipients: [
          TomRecipient('to@example.com', displayName: 'To'),
          TomRecipient('bcc@example.com', kind: TomRecipientKind.bcc),
        ],
        subject: 'Subject',
        bodies: const [
          TomMessageBody.text('plain'),
          TomMessageBody.html('<p>rich</p>'),
        ],
        attachments: [TomAttachment.text(fileName: 'note.txt', text: 'hello')],
        headers: const {'X-Tag': 'value'},
        metadata: const {'priority': 3},
        createdAt: DateTime.utc(2026, 7, 28, 10, 30),
      );

      final restored = TomMessage.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );

      expect(restored.id, 'msg-1');
      expect(restored.from!.displayName, 'From');
      expect(restored.replyTo!.address, 'reply@example.com');
      expect(restored.recipients.last.kind, TomRecipientKind.bcc);
      expect(restored.bodies.map((b) => b.content), ['plain', '<p>rich</p>']);
      expect(utf8.decode(restored.attachments.single.bytes), 'hello');
      expect(restored.headers['X-Tag'], 'value');
      expect(restored.metadata['priority'], 3);
      expect(restored.createdAt, DateTime.utc(2026, 7, 28, 10, 30));
    });

    test('JSON round-tripping is what makes a queued message durable', () {
      // Asserted through a real encode/decode cycle rather than object
      // identity, because the outbox stores the map, not the object.
      final encoded = jsonEncode(_mail(id: 'durable').toJson());
      expect(TomMessage.fromJson(jsonDecode(encoded)).id, 'durable');
    });

    test('an attachment needs a name', () {
      expect(
        () => TomAttachment(fileName: '  ', bytes: Uint8List(0)),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('a contentId is what makes an attachment inline', () {
      final listed = TomAttachment.text(fileName: 'a.txt', text: 'x');
      final inline = TomAttachment(
        fileName: 'logo.png',
        bytes: Uint8List.fromList([1, 2, 3]),
        contentId: 'logo',
      );
      expect(listed.isInline, isFalse);
      expect(inline.isInline, isTrue);
    });
  });

  // ===========================================================================
  // THE DOCUMENT
  // ===========================================================================

  group('TomMimeEncoder (headers)', () {
    final encoder = TomMimeEncoder(
      random: Random(1),
      clock: () => DateTime.utc(2026, 7, 28, 10, 30),
    );

    test('Bcc recipients never reach a header', () {
      // The single most consequential assertion in this file: writing a blind
      // copy into a header is the canonical way to turn it into a disclosure.
      final document = encoder.encode(
        TomMessage(
          from: TomRecipient('from@example.com'),
          recipients: [
            TomRecipient('to@example.com'),
            TomRecipient('secret@example.com', kind: TomRecipientKind.bcc),
          ],
          subject: 'Hi',
          bodies: const [TomMessageBody.text('x')],
        ),
      );
      expect(document, contains('To: to@example.com'));
      expect(document, isNot(contains('secret@example.com')));
      expect(document.toLowerCase(), isNot(contains('bcc')));
    });

    test('Cc recipients do reach a header', () {
      final document = encoder.encode(
        TomMessage(
          recipients: [
            TomRecipient('to@example.com'),
            TomRecipient('cc@example.com', kind: TomRecipientKind.cc),
          ],
          bodies: const [TomMessageBody.text('x')],
        ),
      );
      expect(document, contains('Cc: cc@example.com'));
    });

    test('a plain ASCII subject is not needlessly encoded', () {
      // An encoded-word where none is needed is noise in every "show original".
      expect(TomMimeEncoder.encodeHeaderValue('Hello'), 'Hello');
    });

    test('a non-ASCII subject becomes an RFC 2047 encoded word', () {
      final encoded = TomMimeEncoder.encodeHeaderValue('Grüße');
      expect(encoded, startsWith('=?utf-8?B?'));
      expect(encoded, endsWith('?='));
      expect(
        utf8.decode(base64.decode(encoded.substring(10, encoded.length - 2))),
        'Grüße',
      );
    });

    test('a display name is quoted, and its quotes escaped', () {
      expect(
        TomMimeEncoder.encodeAddress(
          TomRecipient('a@b.c', displayName: 'Ada "Bug" Lovelace'),
        ),
        r'"Ada \"Bug\" Lovelace" <a@b.c>',
      );
    });

    test('a bare address carries no angle brackets', () {
      expect(TomMimeEncoder.encodeAddress(TomRecipient('a@b.c')), 'a@b.c');
    });

    test(
      'the Date header is English and offset-numeric whatever the locale',
      () {
        final formatted = TomMimeEncoder.formatRfc5322Date(
          DateTime.utc(2026, 7, 28, 9, 5, 3),
        );
        expect(formatted, 'Tue, 28 Jul 2026 09:05:03 +0000');
      },
    );

    test('caller headers come last, so a deployment can override', () {
      final document = encoder.encode(
        TomMessage(
          recipients: [TomRecipient('to@example.com')],
          bodies: const [TomMessageBody.text('x')],
          headers: const {'List-Unsubscribe': '<https://example.com/u>'},
        ),
      );
      expect(
        document.indexOf('List-Unsubscribe'),
        greaterThan(document.indexOf('MIME-Version')),
      );
    });

    test('every line ends CRLF, never a bare LF', () {
      final document = encoder.encode(_mail());
      expect(
        RegExp(r'(?<!\r)\n').hasMatch(document),
        isFalse,
        reason:
            'a bare LF is accepted by some servers and corrupts the '
            'message on others',
      );
    });
  });

  group('TomMimeEncoder (structure follows content)', () {
    final encoder = TomMimeEncoder(
      random: Random(1),
      clock: () => DateTime.utc(2026, 7, 28, 10, 30),
    );

    test('one body is a single part, with no multipart wrapper', () {
      // A single text part wrapped in multipart/mixed renders as an empty mail
      // with one attachment in several popular clients.
      final document = encoder.encode(_mail());
      expect(document, contains('Content-Type: text/plain; charset=utf-8'));
      expect(document, isNot(contains('multipart')));
    });

    test('text plus HTML is multipart/alternative', () {
      final document = encoder.encode(_mail(text: 'plain', html: '<p>x</p>'));
      expect(document, contains('multipart/alternative'));
      expect(document, isNot(contains('multipart/mixed')));
      expect(document, contains('text/plain'));
      expect(document, contains('text/html'));
    });

    test('an attachment makes the whole message multipart/mixed', () {
      final document = encoder.encode(
        _mail(
          attachments: [TomAttachment.text(fileName: 'a.txt', text: 'hi')],
        ),
      );
      expect(document, contains('multipart/mixed'));
      expect(
        document,
        contains(
          'Content-Disposition: attachment; '
          'filename="a.txt"',
        ),
      );
    });

    test('an inline image makes the content multipart/related', () {
      final document = encoder.encode(
        _mail(
          html: '<img src="cid:logo">',
          attachments: [
            TomAttachment(
              fileName: 'logo.png',
              bytes: Uint8List.fromList([1, 2, 3]),
              mediaType: 'image/png',
              contentId: 'logo',
            ),
          ],
        ),
      );
      expect(document, contains('multipart/related'));
      expect(document, contains('Content-ID: <logo>'));
      expect(document, contains('Content-Disposition: inline'));
      // The image is referenced by the markup, not offered as a download, so it
      // must not also appear as a mixed-part attachment.
      expect(document, isNot(contains('multipart/mixed')));
    });

    test('a boundary cannot collide with the base64 it delimits', () {
      final document = encoder.encode(_mail(text: 'a', html: '<p>b</p>'));
      final boundary = RegExp('boundary="([^"]+)"').firstMatch(document)![1]!;
      expect(boundary, startsWith('==_tom_'));
      // `=` is not in the base64 alphabet except as terminal padding, and never
      // begins a line of wrapped output.
      expect(boundary, matches(RegExp(r'^==_tom_\w+_[0-9a-f]{16}$')));
    });

    test('base64 is wrapped to a legal line length', () {
      final document = encoder.encode(_mail(text: 'x' * 500));
      final longest = document
          .split('\r\n')
          .map((l) => l.length)
          .reduce((a, b) => a > b ? a : b);
      expect(longest, lessThanOrEqualTo(76));
    });

    test('a message with no body at all still produces a valid document', () {
      final document = encoder.encode(
        TomMessage(recipients: [TomRecipient('to@example.com')]),
      );
      expect(document, contains('Content-Type: text/plain; charset=utf-8'));
    });

    test('the same message encodes identically given the same seed', () {
      // Boundaries are random in production and pinned here, which is the only
      // reason an exact-document assertion is possible at all.
      final message = _mail(id: 'fixed', text: 'a', html: '<p>b</p>');
      final first = TomMimeEncoder(
        random: Random(7),
        clock: () => DateTime.utc(2026),
      ).encode(message);
      final second = TomMimeEncoder(
        random: Random(7),
        clock: () => DateTime.utc(2026),
      ).encode(message);
      expect(first, second);
    });
  });

  // ===========================================================================
  // THE CONTRACT AND ITS STAND-INS
  // ===========================================================================

  group('TomMemoryMessageTransport', () {
    test('records what it was handed and reports delivered', () async {
      final transport = TomMemoryMessageTransport();
      final receipt = await transport.send(_mail(id: 'm1'));
      expect(receipt.isDelivered, isTrue);
      expect(receipt.messageId, 'm1');
      expect(transport.count, 1);
      expect(transport.last!.id, 'm1');
    });

    test('failNext is consumed, so a retry can be shown to succeed', () async {
      // The behaviour that actually needs proving. A transport that either
      // always works or always fails cannot demonstrate a recovery.
      final transport = TomMemoryMessageTransport()
        ..failNext = TomDeliveryException.transient('x', 'once');
      await expectLater(
        transport.send(_mail()),
        throwsA(isA<TomDeliveryException>()),
      );
      await transport.send(_mail());
      expect(transport.count, 1);
    });

    test('failAlways is not consumed', () async {
      final transport = TomMemoryMessageTransport()
        ..failAlways = TomDeliveryException.transient('x', 'always');
      await expectLater(
        transport.send(_mail()),
        throwsA(isA<TomDeliveryException>()),
      );
      await expectLater(
        transport.send(_mail()),
        throwsA(isA<TomDeliveryException>()),
      );
    });

    test(
      'it accepts copies and attachments, as the real transport does',
      () async {
        // A stand-in that rejected what production accepts would make tests pass
        // and production fail, which is worse than having no stand-in.
        final transport = TomMemoryMessageTransport();
        expect(transport.supportsCopies, isTrue);
        expect(transport.supportsAttachments, isTrue);
        await transport.send(
          TomMessage(
            recipients: [
              TomRecipient('to@example.com'),
              TomRecipient('bcc@example.com', kind: TomRecipientKind.bcc),
            ],
            attachments: [TomAttachment.text(fileName: 'a.txt', text: 'x')],
          ),
        );
        expect(transport.count, 1);
      },
    );
  });

  group('TomNoOpMessageTransport', () {
    test('reports discarded, never delivered', () async {
      // A receipt must never claim something reached a recipient when nothing
      // was sent.
      final receipt = await const TomNoOpMessageTransport(
        logDiscarded: false,
      ).send(_mail());
      expect(receipt.outcome, TomDeliveryOutcome.discarded);
      expect(receipt.isDelivered, isFalse);
    });

    test(
      'it lets a spec naming email run with no mail server at all',
      () async {
        final router = TomMessageRouter(const [
          TomNoOpMessageTransport(logDiscarded: false),
        ]);
        expect(router.supports(TomMessageChannel.email), isTrue);
        expect(
          (await router.send(_mail())).outcome,
          TomDeliveryOutcome.discarded,
        );
      },
    );
  });

  group('TomFileMessageTransport', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('tom_mail_'));
    tearDown(() => directory.deleteSync(recursive: true));

    test('writes an openable .eml document', () async {
      final transport = TomFileMessageTransport(directory: directory);
      await transport.send(_mail(id: 'm1', subject: 'Hello'));
      expect(transport.files, hasLength(1));
      final written = transport.files.single.readAsStringSync();
      expect(written, contains('Subject: Hello'));
      expect(written, contains('To: to@example.com'));
    });

    test(
      'creates its directory rather than failing on the first send',
      () async {
        final nested = Directory('${directory.path}/a/b');
        TomFileMessageTransport(directory: nested);
        expect(nested.existsSync(), isTrue);
      },
    );
  });

  group('the transient/permanent distinction', () {
    test('a permanent failure carries the marker the scheduler reads', () {
      // This is the join: the transport classifies, and the kernel scheduler
      // honours it without the outbox translating anything.
      final failure = TomDeliveryException.permanent(
        'k',
        'no such mailbox',
        statusCode: 550,
      );
      expect(failure.isPermanent, isTrue);
      expect(failure, isA<TomPermanentFailure>());
      expect(failure.statusCode, 550);
    });

    test('a transient failure does not carry it', () {
      final failure = TomDeliveryException.transient(
        'k',
        'try later',
        statusCode: 451,
      );
      expect(failure.isPermanent, isFalse);
      expect(failure, isNot(isA<TomPermanentFailure>()));
    });

    test('wrong channel is permanent: retrying adds no transport', () async {
      final transport = TomMemoryMessageTransport(
        channel: TomMessageChannel.sms,
      );
      await expectLater(
        transport.send(_mail()),
        throwsA(isA<TomPermanentDeliveryException>()),
      );
    });

    test(
      'an unsupported attachment is permanent, not silently dropped',
      () async {
        // Dropping it would deliver a message that says "see attached" with
        // nothing attached.
        final transport = _AttachmentlessTransport();
        await expectLater(
          transport.send(
            _mail(
              attachments: [TomAttachment.text(fileName: 'a.txt', text: 'x')],
            ),
          ),
          throwsA(isA<TomPermanentDeliveryException>()),
        );
      },
    );

    test(
      'a channel with no copies refuses them rather than promoting them',
      () async {
        // Promoting a Bcc to a primary recipient discloses it to everyone else.
        final transport = _AttachmentlessTransport();
        await expectLater(
          transport.send(
            TomMessage(
              channel: TomMessageChannel.sms,
              recipients: [
                TomRecipient('to@example.com'),
                TomRecipient('bcc@example.com', kind: TomRecipientKind.bcc),
              ],
            ),
          ),
          throwsA(isA<TomPermanentDeliveryException>()),
        );
      },
    );
  });

  group('TomMessageRouter', () {
    test('routes each channel to its own transport', () async {
      final email = TomMemoryMessageTransport();
      final sms = TomMemoryMessageTransport(channel: TomMessageChannel.sms);
      final router = TomMessageRouter([email, sms]);

      await router.send(_mail());
      await router.send(
        TomMessage(
          channel: TomMessageChannel.sms,
          recipients: [TomRecipient('+100')],
        ),
      );

      expect(email.count, 1);
      expect(sms.count, 1);
    });

    test('an unrouted channel is permanent, not a doomed retry', () async {
      // A deployment that named a channel it did not wire up needs to hear
      // about it now, not after the retry budget runs out.
      final router = TomMessageRouter();
      await expectLater(
        router.send(_mail()),
        throwsA(isA<TomPermanentDeliveryException>()),
      );
    });

    test('registering replaces the transport for a channel', () async {
      final first = TomMemoryMessageTransport();
      final second = TomMemoryMessageTransport();
      final router = TomMessageRouter([first])..register(second);
      await router.send(_mail());
      expect(first.count, 0);
      expect(second.count, 1);
    });

    test('deregistering makes the channel unrouted again', () {
      final router = TomMessageRouter([TomMemoryMessageTransport()]);
      expect(router.supports(TomMessageChannel.email), isTrue);
      router.deregister(TomMessageChannel.email);
      expect(router.supports(TomMessageChannel.email), isFalse);
    });
  });

  // ===========================================================================
  // SMTP
  // ===========================================================================

  group('TomSmtpSettings', () {
    test('a username without a password fails at construction', () {
      // Not at the AUTH command: a deployment that forgot the secret should
      // fail at startup naming the setting, not on the first notification.
      expect(
        () => _settings(username: 'user'),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('a blank host is rejected', () {
      expect(
        () => TomSmtpSettings(host: '  '),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('the port follows the security when not given', () {
      expect(
        TomSmtpSettings(host: 'h', security: TomSmtpSecurity.none).port,
        25,
      );
      expect(
        TomSmtpSettings(host: 'h', security: TomSmtpSecurity.startTls).port,
        587,
      );
      expect(
        TomSmtpSettings(host: 'h', security: TomSmtpSecurity.implicitTls).port,
        465,
      );
    });

    test('toString never reveals the password', () {
      // A secret that reaches a log file has stopped being one.
      final described = _settings(
        username: 'user',
        password: 'hunter2',
      ).toString();
      expect(described, contains('user'));
      expect(described, isNot(contains('hunter2')));
    });
  });

  group('TomSmtpTransport (a clean delivery)', () {
    test('runs the conversation in the order the protocol requires', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(250, 'sender ok'), // MAIL FROM
        _reply(250, 'recipient ok'), // RCPT TO
        _reply(354, 'go ahead'), // DATA
        _reply(250, 'queued as ABC123'), // body
        _reply(221, 'bye'), // QUIT
      ]);
      final transport = TomSmtpTransport(
        _settings(),
        connect: (_) async => connection,
      );

      final receipt = await transport.send(_mail(id: 'm1'));

      expect(connection.commands, [
        'EHLO localhost',
        'MAIL FROM:<sender@example.com>',
        'RCPT TO:<to@example.com>',
        'DATA',
        'DATA<body>',
        'QUIT',
      ]);
      expect(receipt.isDelivered, isTrue);
      expect(receipt.remoteId, 'queued as ABC123');
      expect(connection.data, contains('Subject: Subject'));
      expect(connection.closed, isTrue);
    });

    test(
      'the envelope carries Bcc even though the document does not',
      () async {
        final connection = _ScriptedSmtpConnection([
          ..._opening(),
          _reply(250, 'sender ok'),
          _reply(250, 'ok'), // to@
          _reply(250, 'ok'), // bcc@
          _reply(354, 'go ahead'),
          _reply(250, 'queued'),
          _reply(221, 'bye'),
        ]);
        await TomSmtpTransport(
          _settings(),
          connect: (_) async => connection,
        ).send(
          TomMessage(
            from: TomRecipient('sender@example.com'),
            recipients: [
              TomRecipient('to@example.com'),
              TomRecipient('bcc@example.com', kind: TomRecipientKind.bcc),
            ],
            bodies: const [TomMessageBody.text('x')],
          ),
        );

        expect(connection.commands, contains('RCPT TO:<bcc@example.com>'));
        expect(connection.data, isNot(contains('bcc@example.com')));
      },
    );

    test('a message with no sender uses the configured default From', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(250, 'ok'),
        _reply(250, 'ok'),
        _reply(354, 'go'),
        _reply(250, 'queued'),
        _reply(221, 'bye'),
      ]);
      await TomSmtpTransport(
        _settings(defaultFrom: TomRecipient('noreply@example.com')),
        connect: (_) async => connection,
      ).send(_mail(fromAddress: null));

      // The header and the envelope must agree — it is the first thing a spam
      // filter compares.
      expect(connection.commands, contains('MAIL FROM:<noreply@example.com>'));
      expect(connection.data, contains('From: noreply@example.com'));
    });

    test('no sender and no default is permanent, not a doomed retry', () async {
      final transport = TomSmtpTransport(
        _settings(),
        connect: (_) async => _ScriptedSmtpConnection([]),
      );
      await expectLater(
        transport.send(_mail(fromAddress: null)),
        throwsA(isA<TomPermanentDeliveryException>()),
      );
    });

    test('HELO is used when the relay does not understand EHLO', () async {
      final connection = _ScriptedSmtpConnection([
        _reply(220, 'ready'),
        _reply(500, 'unrecognised command'), // EHLO
        _reply(250, 'hello'), // HELO
        _reply(250, 'ok'),
        _reply(250, 'ok'),
        _reply(354, 'go'),
        _reply(250, 'queued'),
        _reply(221, 'bye'),
      ]);
      await TomSmtpTransport(
        _settings(),
        connect: (_) async => connection,
      ).send(_mail());
      expect(connection.commands, contains('HELO localhost'));
    });
  });

  group('TomSmtpTransport (security)', () {
    test('STARTTLS is negotiated and the greeting repeated after it', () async {
      // The capability list before an upgrade is not binding after it: most
      // servers only advertise AUTH once the channel is private.
      final connection = _ScriptedSmtpConnection([
        _reply(220, 'ready'),
        TomSmtpReply(250, ['relay', 'STARTTLS']),
        _reply(220, 'ready to start TLS'),
        TomSmtpReply(250, ['relay', 'AUTH PLAIN']),
        _reply(250, 'ok'),
        _reply(250, 'ok'),
        _reply(354, 'go'),
        _reply(250, 'queued'),
        _reply(221, 'bye'),
      ]);
      await TomSmtpTransport(
        _settings(security: TomSmtpSecurity.startTls),
        connect: (_) async => connection,
      ).send(_mail());

      expect(connection.upgraded, isTrue);
      expect(
        connection.commands.where((c) => c.startsWith('EHLO')),
        hasLength(2),
      );
    });

    test('a relay that offers no STARTTLS when required is refused', () async {
      // Continuing would send the credential in the clear, and retrying cannot
      // make a server advertise a capability it does not have.
      final connection = _ScriptedSmtpConnection(_opening());
      await expectLater(
        TomSmtpTransport(
          _settings(security: TomSmtpSecurity.startTls),
          connect: (_) async => connection,
        ).send(_mail()),
        throwsA(isA<TomPermanentDeliveryException>()),
      );
      expect(connection.upgraded, isFalse);
    });

    test('AUTH PLAIN sends NUL-separated credentials, not spaces', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(auth: true),
        _reply(235, 'authenticated'),
        _reply(250, 'ok'),
        _reply(250, 'ok'),
        _reply(354, 'go'),
        _reply(250, 'queued'),
        _reply(221, 'bye'),
      ]);
      await TomSmtpTransport(
        _settings(username: 'user', password: 'hunter2'),
        connect: (_) async => connection,
      ).send(_mail());

      final auth = connection.commands.firstWhere(
        (c) => c.startsWith('AUTH PLAIN '),
      );
      expect(
        utf8.decode(base64.decode(auth.substring('AUTH PLAIN '.length))),
        '\x00user\x00hunter2',
      );
    });

    test('AUTH LOGIN is used when PLAIN is not offered', () async {
      final connection = _ScriptedSmtpConnection([
        _reply(220, 'ready'),
        TomSmtpReply(250, ['relay', 'AUTH LOGIN']),
        _reply(334, 'VXNlcm5hbWU6'),
        _reply(334, 'UGFzc3dvcmQ6'),
        _reply(235, 'authenticated'),
        _reply(250, 'ok'),
        _reply(250, 'ok'),
        _reply(354, 'go'),
        _reply(250, 'queued'),
        _reply(221, 'bye'),
      ]);
      await TomSmtpTransport(
        _settings(username: 'user', password: 'hunter2'),
        connect: (_) async => connection,
      ).send(_mail());

      expect(connection.commands, contains('AUTH LOGIN'));
      expect(
        connection.commands,
        contains(base64.encode(utf8.encode('hunter2'))),
      );
    });

    test('a rejected credential is permanent and names the setting', () async {
      // "535 authentication failed" on its own sends people looking in the
      // wrong place; far more often it is a deployment secret, not an account.
      final connection = _ScriptedSmtpConnection([
        ..._opening(auth: true),
        _reply(535, 'authentication failed'),
      ]);
      await expectLater(
        TomSmtpTransport(
          _settings(username: 'user', password: 'wrong'),
          connect: (_) async => connection,
        ).send(_mail()),
        throwsA(
          isA<TomPermanentDeliveryException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('smtpPassword'),
          ),
        ),
      );
    });

    test('an unauthenticated relay is never sent AUTH', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(auth: true),
        _reply(250, 'ok'),
        _reply(250, 'ok'),
        _reply(354, 'go'),
        _reply(250, 'queued'),
        _reply(221, 'bye'),
      ]);
      await TomSmtpTransport(
        _settings(),
        connect: (_) async => connection,
      ).send(_mail());
      expect(connection.commands.any((c) => c.startsWith('AUTH')), isFalse);
    });
  });

  group('TomSmtpTransport (failure classification)', () {
    test('a 4xx is transient, so the outbox will try again', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(451, 'greylisted, try later'),
      ]);
      await expectLater(
        TomSmtpTransport(
          _settings(),
          connect: (_) async => connection,
        ).send(_mail()),
        throwsA(
          isA<TomDeliveryException>()
              .having((e) => e.isPermanent, 'isPermanent', isFalse)
              .having((e) => e.statusCode, 'statusCode', 451),
        ),
      );
    });

    test(
      'a 5xx on the body is permanent, so the budget is not burned',
      () async {
        final connection = _ScriptedSmtpConnection([
          ..._opening(),
          _reply(250, 'ok'),
          _reply(250, 'ok'),
          _reply(354, 'go'),
          _reply(552, 'message too large'),
        ]);
        await expectLater(
          TomSmtpTransport(
            _settings(),
            connect: (_) async => connection,
          ).send(_mail()),
          throwsA(
            isA<TomPermanentDeliveryException>().having(
              (e) => e.statusCode,
              'statusCode',
              552,
            ),
          ),
        );
      },
    );

    test('one dead address does not cost the others their mail', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(250, 'ok'),
        _reply(250, 'ok'), // good@
        _reply(550, 'no such user'), // dead@
        _reply(354, 'go'),
        _reply(250, 'queued'),
        _reply(221, 'bye'),
      ]);
      final receipt =
          await TomSmtpTransport(
            _settings(),
            connect: (_) async => connection,
          ).send(
            TomMessage(
              from: TomRecipient('sender@example.com'),
              recipients: [
                TomRecipient('good@example.com'),
                TomRecipient('dead@example.com'),
              ],
              bodies: const [TomMessageBody.text('x')],
            ),
          );

      // A partial delivery is a real outcome; reporting it as either success or
      // failure loses what the operator needs to know.
      expect(receipt.isDelivered, isTrue);
      expect(receipt.isPartial, isTrue);
      expect(receipt.rejectedRecipients, ['dead@example.com']);
    });

    test('every address rejected is a permanent failure', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(250, 'ok'),
        _reply(550, 'no such user'),
      ]);
      await expectLater(
        TomSmtpTransport(
          _settings(),
          connect: (_) async => connection,
        ).send(_mail()),
        throwsA(isA<TomPermanentDeliveryException>()),
      );
    });

    test('a 4xx on a recipient defers the whole message', () async {
      // Unlike a 5xx, this is not the address being wrong — it is the server
      // being busy, and dropping the recipient would silently under-deliver.
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(250, 'ok'),
        _reply(450, 'mailbox busy'),
      ]);
      await expectLater(
        TomSmtpTransport(
          _settings(),
          connect: (_) async => connection,
        ).send(_mail()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });

    test('an unreachable relay is transient', () async {
      await expectLater(
        TomSmtpTransport(
          _settings(),
          connect: (_) async => throw const SocketException('refused'),
        ).send(_mail()),
        throwsA(
          isA<TomDeliveryException>().having(
            (e) => e.isPermanent,
            'isPermanent',
            isFalse,
          ),
        ),
      );
    });

    test('a failure after acceptance does not undo the delivery', () async {
      // The relay took responsibility on the 250; turning a dropped QUIT into a
      // failure would produce a duplicate on the retry.
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(250, 'ok'),
        _reply(250, 'ok'),
        _reply(354, 'go'),
        _reply(250, 'queued as XYZ'),
        // No reply to QUIT: the script is exhausted, which the transport must
        // swallow rather than report.
      ]);
      final receipt = await TomSmtpTransport(
        _settings(),
        connect: (_) async => connection,
      ).send(_mail());
      expect(receipt.isDelivered, isTrue);
      expect(receipt.remoteId, 'queued as XYZ');
    });

    test('the connection is closed even when delivery fails', () async {
      final connection = _ScriptedSmtpConnection([
        ..._opening(),
        _reply(550, 'rejected'),
      ]);
      await expectLater(
        TomSmtpTransport(
          _settings(),
          connect: (_) async => connection,
        ).send(_mail()),
        throwsA(isA<TomDeliveryException>()),
      );
      expect(connection.closed, isTrue);
    });
  });

  // ===========================================================================
  // THE OUTBOX
  // ===========================================================================

  group('TomMessageOutbox (queueing)', () {
    late _FakeClock clock;
    late TomMemoryMessageTransport transport;
    late TomMessageOutbox outbox;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2026, 7, 28, 10));
      transport = TomMemoryMessageTransport();
      outbox = TomMessageOutbox(
        router: TomMessageRouter([transport]),
        clock: clock.call,
      );
      addTearDown(outbox.close);
    });

    test('send queues without delivering', () async {
      await outbox.send(_mail(id: 'm1'));
      expect(transport.count, 0);
      expect(await outbox.store.all(), hasLength(1));
    });

    test('a tick delivers what was queued', () async {
      await outbox.send(_mail(id: 'm1'));
      await outbox.tick();
      await pumpEventQueue();
      expect(transport.count, 1);
      expect(transport.last!.id, 'm1');
    });

    test('sendNow queues and delivers in one step', () async {
      await outbox.sendNow(_mail(id: 'm1'));
      await pumpEventQueue();
      expect(transport.count, 1);
    });

    test(
      'two messages composed in the same instant are both delivered',
      () async {
        // The reason the outbox enqueues directly instead of pushing through the
        // schedule's event stream: the scheduler collapses same-instant events
        // into one windowed run, which for a trigger is right and for an outbox
        // loses mail. The frozen clock makes that collision certain.
        await outbox.send(_mail(id: 'm1'));
        await outbox.send(_mail(id: 'm2'));
        await outbox.tick();
        await pumpEventQueue();
        expect(transport.sent.map((m) => m.id), containsAll(['m1', 'm2']));
      },
    );

    test('the message id is the idempotence key', () async {
      // A caller retrying a send it is unsure completed must not cause two
      // deliveries.
      final message = _mail(id: 'same');
      await outbox.send(message);
      await outbox.send(message);
      expect(await outbox.store.all(), hasLength(1));
      await outbox.tick();
      await pumpEventQueue();
      expect(transport.count, 1);
    });

    test('the queued payload is the message, restorable in full', () async {
      await outbox.send(_mail(id: 'm1', subject: 'Restored'));
      final run = (await outbox.store.all()).single;
      final restored = TomMessage.fromJson(
        run.payload! as Map<String, dynamic>,
      );
      expect(restored.subject, 'Restored');
    });

    test('a delivered message produces a receipt on the stream', () async {
      final receipts = <TomDeliveryReceipt>[];
      outbox.receipts.listen(receipts.add);
      await outbox.sendNow(_mail(id: 'm1'));
      await pumpEventQueue();
      expect(receipts, hasLength(1));
      expect(receipts.single.messageId, 'm1');
    });

    test('a closed outbox refuses further messages', () async {
      outbox.close();
      await expectLater(
        outbox.send(_mail()),
        throwsA(isA<TomMessagingException>()),
      );
    });

    test('closing the outbox leaves the router open', () async {
      // A router shared with the rest of the application must not be torn down
      // because the outbox stopped.
      outbox.close();
      expect((await transport.send(_mail())).isDelivered, isTrue);
    });
  });

  group('TomMessageOutbox (retry rides the job queue)', () {
    late _FakeClock clock;
    late TomMemoryMessageTransport transport;
    late List<TomJobAlert> alerts;
    late TomMessageOutbox outbox;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2026, 7, 28, 10));
      transport = TomMemoryMessageTransport();
      alerts = [];
      outbox = TomMessageOutbox(
        router: TomMessageRouter([transport]),
        clock: clock.call,
        onAlert: alerts.add,
        retryPolicy: const TomRetryPolicy(
          maxAttempts: 3,
          initialBackoff: Duration(minutes: 1),
          jitter: 0,
        ),
      );
      addTearDown(outbox.close);
    });

    test('a transient failure is retried and can then succeed', () async {
      transport.failNext = TomDeliveryException.transient(
        'smtp',
        'greylisted',
        statusCode: 451,
      );

      await outbox.sendNow(_mail(id: 'm1'));
      await pumpEventQueue();
      expect(transport.count, 0, reason: 'the first attempt failed');

      // The backoff is the scheduler's, not the outbox's — there is no second
      // retry loop to advance.
      clock.advance(const Duration(minutes: 2));
      await outbox.tick();
      await pumpEventQueue();

      expect(transport.count, 1);
      final run = (await outbox.store.all()).single;
      expect(run.state, TomJobRunState.succeeded);
      expect(run.attempt, 2);
    });

    test(
      'a permanent failure is not retried, whatever the budget says',
      () async {
        // Three attempts were configured; the classification overrides them,
        // because "no attempt can succeed" makes the budget irrelevant.
        transport.failAlways = TomDeliveryException.permanent(
          'smtp',
          'no such mailbox',
          statusCode: 550,
        );

        await outbox.sendNow(_mail(id: 'm1'));
        await pumpEventQueue();

        final run = (await outbox.store.all()).single;
        expect(run.state, TomJobRunState.failed);
        expect(run.attempt, 1);
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
          hasLength(1),
        );
      },
    );

    test('the retry budget is finite and its exhaustion is reported', () async {
      transport.failAlways = TomDeliveryException.transient(
        'smtp',
        'still down',
      );

      await outbox.sendNow(_mail(id: 'm1'));
      for (var i = 0; i < 4; i++) {
        await pumpEventQueue();
        clock.advance(const Duration(minutes: 10));
        await outbox.tick();
      }
      await pumpEventQueue();

      final run = (await outbox.store.all()).single;
      expect(run.state, TomJobRunState.failed);
      expect(run.attempt, 3);
      // Failures are reported on one channel — the scheduler's alert sink — so
      // "how many times did this fail" has exactly one answer.
      expect(
        alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
        hasLength(1),
      );
      expect(
        alerts.where((a) => a.kind == TomJobAlertKind.attemptFailed),
        hasLength(2),
      );
    });

    test(
      'an unroutable channel fails permanently on the first attempt',
      () async {
        await outbox.sendNow(
          TomMessage(
            id: 'sms-1',
            channel: TomMessageChannel.sms,
            recipients: [TomRecipient('+100')],
          ),
        );
        await pumpEventQueue();

        final run = (await outbox.store.all()).single;
        expect(run.state, TomJobRunState.failed);
        expect(run.attempt, 1);
      },
    );

    test(
      'an unreadable payload is permanent rather than retried forever',
      () async {
        // Nothing makes a malformed run parse, and retrying it holds a slot a
        // deliverable message could use.
        final now = clock.now;
        await outbox.store.enqueue(
          TomJobRun(
            id: 'bad',
            jobName: tomOutboxJobName,
            scheduledFor: now,
            runAt: now,
            payload: 'not a message',
          ),
        );
        await outbox.tick();
        await pumpEventQueue();

        final run = (await outbox.store.all()).single;
        expect(run.state, TomJobRunState.failed);
        expect(run.attempt, 1);
      },
    );

    test(
      'purgeFinished drops delivered history but keeps pending work',
      () async {
        await outbox.sendNow(_mail(id: 'done'));
        await pumpEventQueue();
        clock.advance(const Duration(hours: 1));
        await outbox.send(_mail(id: 'waiting'));

        final purged = await outbox.purgeFinished(clock.now);
        expect(purged, 1);
        expect(
          (await outbox.store.all()).single.id,
          '$tomOutboxJobName:waiting',
        );
      },
    );
  });

  // ===========================================================================
  // CONFIGURATION
  // ===========================================================================

  group('TomSmtpSettings.fromConfiguration', () {
    test('no host means no mail, reported as null rather than a failure', () {
      // How a deployment says "this server does not send mail" — the caller
      // registers a no-op transport instead of failing to start.
      expect(TomSmtpSettings.fromConfiguration(_Configuration()), isNull);
    });

    test('a configured host produces usable settings', () {
      final settings = TomSmtpSettings.fromConfiguration(
        _Configuration()
          ..smtpHost = 'relay.example.com'
          ..smtpSecurity = 'implicitTls'
          ..smtpUsername = 'user'
          ..smtpPassword = 'secret'
          ..smtpFromAddress = 'noreply@example.com'
          ..smtpFromName = 'Example',
      )!;

      expect(settings.host, 'relay.example.com');
      expect(settings.security, TomSmtpSecurity.implicitTls);
      expect(settings.port, 465, reason: 'port 0 means "take the default"');
      expect(settings.isAuthenticated, isTrue);
      expect(settings.defaultFrom!.displayName, 'Example');
    });

    test('an explicit port wins over the security default', () {
      final settings = TomSmtpSettings.fromConfiguration(
        _Configuration()
          ..smtpHost = 'relay.example.com'
          ..smtpPort = 2525,
      )!;
      expect(settings.port, 2525);
    });

    test('an unrecognised security value fails closed, onto startTls', () {
      // Failing *closed* on a typo is the only acceptable direction for a
      // setting that decides whether a password crosses the network in clear.
      final settings = TomSmtpSettings.fromConfiguration(
        _Configuration()
          ..smtpHost = 'relay.example.com'
          ..smtpSecurity = 'nonsense',
      )!;
      expect(settings.security, TomSmtpSecurity.startTls);
    });

    test('blank credentials are treated as absent, not as empty strings', () {
      final settings = TomSmtpSettings.fromConfiguration(
        _Configuration()
          ..smtpHost = 'relay.example.com'
          ..smtpUsername = '   ',
      )!;
      expect(settings.username, isNull);
      expect(settings.isAuthenticated, isFalse);
    });
  });
}

/// A transport that supports neither copies nor attachments, to exercise
/// [TomMessageTransport.checkSupported] the way SMS or push would.
class _AttachmentlessTransport extends TomMessageTransport {
  @override
  TomMessageChannel get channel => TomMessageChannel.email;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);
    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
    );
  }
}

/// A minimal concrete configuration.
///
/// [TomBaseServerConfiguration] is abstract and normally filled by generated
/// reflection; these tests only need the `smtp*` field values, so the base
/// constructor's source-merging is bypassed entirely.
class _Configuration extends TomBaseServerConfiguration {
  _Configuration() : super(const []);

  @override
  void setValues(Map<String, Object?> values) {}
}
