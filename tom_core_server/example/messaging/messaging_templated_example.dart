/// Executable example for the **application-level** half of the messaging
/// module of `tom_core_server`: the templated services, and the SMS channel.
///
/// `messaging_example.dart` composes a [TomMessage] by hand. That is the
/// substrate, and most application code should not touch it — for the same
/// reason most application code does not write SQL strings. What it should
/// reach for is [TomEmailService] and [TomSmsService], where a message is a
/// **template key plus parameters** and no user-facing string ever reaches
/// Dart. This file demonstrates that layer, and the one concern SMS has that
/// email does not: a message has a *price*, and the arithmetic is not visible
/// in the template.
///
/// The two halves are worth reading in order. Steps 1–5 are the rule and its
/// enforcement — resolve through resource keys, fail loudly before anything is
/// queued. Steps 6–8 are what the second channel added to that rule. Steps
/// 9–12 are the seam: a templated SMS rides the same outbox, the same retry
/// budget and the same permanence marker an email does, and only the last two
/// steps know that a gateway has vendor-specific field names at all.
///
/// The one thing not shown here is a socket. [TomSmsTransport] talks to a real
/// gateway in production; its HTTP is driven through an injectable channel,
/// which is what lets `test/sms_transport_test.dart` assert every branch of the
/// classification — and lets steps 11 and 12 below run offline.
///
/// Run with `dart run example/messaging/messaging_templated_example.dart`.
/// Every step checks its own result and the run fails when one does not hold,
/// so a green run is a verification and not just a transcript.
/// `test/messaging_test.dart` runs this file under that exact command and
/// requires it to exit 0, which is what keeps the checks honest once nobody
/// runs the example by hand.
library;

import 'dart:convert';

import 'package:http/http.dart'
    show BaseClient, BaseRequest, Request, StreamedResponse;
import 'package:tom_core_server/tom_core_server.dart';

// ignore_for_file: avoid_print

/// Throws unless [ok] holds, naming the expectation that failed.
///
/// Deliberately not `assert`: `dart run` leaves assertions **disabled** — that
/// is what its `--enable-asserts` flag is for — so an `assert` here compiles
/// out under the very command this file's header gives. An example whose
/// checks vanish under its own documented invocation is worse than one with no
/// checks at all, because it still prints a plausible transcript and still
/// exits 0 while every expectation in it is violated. A plain `if`/`throw`
/// holds however the file is run.
void check(bool ok, String expectation) {
  if (!ok) throw StateError('templated messaging example failed: $expectation');
}

// =============================================================================
// A STAND-IN GATEWAY
// =============================================================================

/// An HTTP client whose every answer is scripted, so no socket is opened.
///
/// This is the same seam `test/sms_transport_test.dart` uses. It exists because
/// the interesting part of an SMS transport is what it does with the *answer* —
/// and a real gateway will not produce an invalid-number rejection on demand.
class _ScriptedGateway extends BaseClient {
  _ScriptedGateway(this.handler);

  /// Answers one request.
  final Future<StreamedResponse> Function(BaseRequest request) handler;

  /// The bodies the transport posted, in order, so a step can show what the
  /// vendor mapping actually produced.
  final List<String> bodies = [];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    bodies.add(request is Request ? request.body : '');
    return handler(request);
  }
}

/// Hands a [TomServerChannel] the scripted client instead of a real one.
class _ScriptedGatewayFactory extends TomHttpClientFactory {
  _ScriptedGatewayFactory(this._client);

  final _ScriptedGateway _client;

  @override
  _ScriptedGateway getClient() => _client;
}

StreamedResponse _answer(String body, {int status = 200}) {
  final bytes = utf8.encode(body);
  return StreamedResponse(
    Stream<List<int>>.value(bytes),
    status,
    contentLength: bytes.length,
  );
}

/// Builds an SMS transport over a scripted gateway.
({TomSmsTransport transport, _ScriptedGateway gateway}) _smsTransport(
  Future<StreamedResponse> Function(BaseRequest request) handler,
) {
  final gateway = _ScriptedGateway(handler);
  final settings = TomSmsGatewaySettings(
    endpoint: Uri.parse('https://gateway.example.com/v1/messages'),
    apiKey: 'key-supplied-at-deploy-time',
    senderId: 'TOMDEMO',
    maxSegments: 3,
  );
  return (
    transport: TomSmsTransport(
      settings,
      // The vendor mapping: this gateway spells the destination `to`, the body
      // `body`, and reports itself in a `status` field with numeric error
      // codes. Every one of those spellings is confined to this object.
      const TomFieldMappedSmsProtocol(
        toField: 'to',
        fromField: 'from',
        textField: 'body',
        statusPath: 'status',
        acceptedStatuses: {'queued', 'sent'},
        remoteIdPath: 'sid',
        errorCodePath: 'code',
        errorMessagePath: 'message',
        permanentErrorCodes: {'21211'},
        transientErrorCodes: {'20429'},
      ),
      openChannel: (s) => TomServerChannel(
        s.endpoint.host,
        443,
        clientFactory: _ScriptedGatewayFactory(gateway),
      ),
    ),
    gateway: gateway,
  );
}

// =============================================================================
// THE BUNDLE
// =============================================================================

/// Every user-facing string in this example, in one place and in two languages.
///
/// Deliberately *partially* translated: `de` carries the password reset but not
/// the welcome mail, which is what a deployment mid-way through a translation
/// looks like — and is the only way step 3 can show that a missing key falls
/// back to the default locale rather than rendering blank.
TomLocalizedTextResources _texts() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: {
    'en': {
      'email': {
        'password_reset': {
          'subject': 'Reset your password, {firstname}',
          'text':
              'Open {link} to choose a new password. '
              'The link expires in {minutes} minutes.',
          'html':
              '<p>Open <a href="{link}">this link</a> to choose a new '
              'password.</p>',
        },
        'welcome': {
          'subject': 'Welcome aboard',
          'text': 'Glad to have you, {firstname}.',
        },
        'no_body': {'subject': 'Has a subject and nothing else'},
      },
      'sms': {
        'two_factor': {'text': 'Your code is {code}, {firstname}.'},
        'delivery_window': {
          'text':
              'Your delivery is scheduled between {from} and {to} on {date}. '
              'Reply CHANGE to move it, or STOP to stop receiving these '
              'messages. Our support team is available every weekday.',
        },
      },
    },
    'de': {
      'email': {
        'password_reset': {
          'subject': 'Passwort zurücksetzen, {firstname}',
          'text':
              'Öffnen Sie {link}, um ein neues Passwort zu wählen. '
              'Der Link läuft in {minutes} Minuten ab.',
          'html':
              '<p>Öffnen Sie <a href="{link}">diesen Link</a>, um ein neues '
              'Passwort zu wählen.</p>',
        },
      },
      'sms': {
        'two_factor': {'text': 'Ihr Code lautet {code}, {firstname}.'},
      },
    },
  },
);

Future<void> run() async {
  final texts = _texts();

  // A router carrying both channels, and one outbox over it. That the same
  // outbox serves email and SMS is the point of steps 9 and 10; it is built
  // here because the services need it at construction.
  final mail = TomMemoryMessageTransport();
  final handsets = TomMemoryMessageTransport(channel: TomMessageChannel.sms);
  final outbox = TomMessageOutbox(
    router: TomMessageRouter([mail, handsets]),
    store: TomMemoryJobStore(),
  );

  final emailService = TomEmailService(outbox: outbox, texts: texts);
  final smsService = TomSmsService(outbox: outbox, texts: texts);

  // 1. A message is a template key plus parameters, never a literal. The rule
  //    is enforced by the *type*: TomEmailRequest has no `subject` field and no
  //    `text` field, so a caller cannot pass a user-facing string even by
  //    accident. That is a compiler's job rather than a reviewer's.
  final request = TomEmailRequest(
    templateKey: 'email.password_reset',
    to: [TomRecipient('ada@example.com', displayName: 'Ada')],
    parameters: {
      'firstname': 'Ada',
      'link': 'https://app/reset/t0ken',
      'minutes': 30,
    },
  );
  print('1. template key              : ${request.templateKey}');
  print('   parameters                : ${request.parameters.keys.join(', ')}');
  check(
    request.templateKey == 'email.password_reset',
    'a request names a template key rather than carrying the text itself',
  );

  // 2. Rendering resolves three sub-keys of that one key: `.subject`, `.text`
  //    and `.html`. Subject and text are required; HTML is optional, because a
  //    plain-text-only mail is a legitimate template and an empty <p> is not.
  final mailMessage = emailService.render(request);
  print('2. subject                   : ${mailMessage.subject}');
  print(
    '   bodies                    : '
    '${mailMessage.bodies.map((b) => b.mediaType).join(', ')}',
  );
  check(
    mailMessage.subject == 'Reset your password, Ada',
    'the subject comes from <key>.subject with {firstname} substituted',
  );
  check(
    mailMessage.textBody!.content.contains('https://app/reset/t0ken'),
    'the body comes from <key>.text with its parameters substituted',
  );
  check(
    mailMessage.htmlBody != null,
    'an HTML alternative is offered when the template has one',
  );

  // 3. The same key renders per recipient locale, and a key the translation has
  //    not reached yet falls back to the default bundle rather than rendering
  //    blank. Falling back is the right failure: a German user reading an
  //    English subject is inconvenienced; one reading an empty subject was
  //    never told anything at all.
  final german = emailService.render(
    TomEmailRequest(
      templateKey: 'email.password_reset',
      to: [TomRecipient('bea@example.de')],
      locale: TomTextLocale('de'),
      parameters: {
        'firstname': 'Bea',
        'link': 'https://app/reset/t0k3n',
        'minutes': 30,
      },
    ),
  );
  final untranslated = emailService.render(
    TomEmailRequest(
      templateKey: 'email.welcome',
      to: [TomRecipient('bea@example.de')],
      locale: TomTextLocale('de'),
      parameters: {'firstname': 'Bea'},
    ),
  );
  print('3. de subject                : ${german.subject}');
  print('   de subject, untranslated  : ${untranslated.subject}');
  check(
    german.subject!.startsWith('Passwort'),
    'the same template key renders in the requested locale',
  );
  check(
    untranslated.subject == 'Welcome aboard',
    'a key the de bundle lacks falls back to the default locale rather than '
    'rendering blank',
  );

  // 4. A template nobody wrote fails at *render*, naming the resource key that
  //    is missing — and render happens before the outbox is touched, so the
  //    fault never becomes a queued message that mails a blank subject.
  var missingTemplateThrew = false;
  try {
    emailService.render(
      TomEmailRequest(
        templateKey: 'email.no_body',
        to: [TomRecipient('ada@example.com')],
      ),
    );
  } on TomMessagingException catch (e) {
    missingTemplateThrew = true;
    print('4. missing sub-key           : ${e.key}');
    print('   names which key           : ${e.parameters?['resourceKey']}');
    check(
      e.parameters?['resourceKey'] == 'email.no_body.text',
      'the failure names the exact resource key that is missing, so the fix '
      'does not require a search',
    );
  }
  // Checked outside the handler on purpose: a check written inside `catch`
  // cannot fail when the `catch` never runs, so a service that quietly rendered
  // a blank body would skip the block and leave the step green.
  check(
    missingTemplateThrew,
    'a template with no body throws rather than mailing an empty message',
  );

  // 5. `toPrincipal` derives the three things every send site would otherwise
  //    re-derive — and eventually get subtly different: the address, the
  //    display name, and the locale. A principal with no address raises *here*,
  //    at composition, where the caller still knows which user it meant; a
  //    transport discovering it later can only say that an address was empty.
  final principal = TomPrincipal(
    authenticated: true,
    user: TomUser(
      id: 7,
      username: 'bea',
      firstname: 'Bea',
      lastname: 'Muster',
      email: 'bea@example.de',
    ),
    language: 'de',
  );
  final forPrincipal = emailService.render(
    TomEmailRequest.toPrincipal(
      templateKey: 'email.password_reset',
      principal: principal,
      parameters: {
        'firstname': 'Bea',
        'link': 'https://app/reset/x',
        'minutes': 30,
      },
    ),
  );
  print(
    '5. derived recipient         : ${forPrincipal.recipientsOf(TomRecipientKind.to).single}',
  );
  print('   derived locale            : rendered as "${forPrincipal.subject}"');
  check(
    forPrincipal.subject!.startsWith('Passwort'),
    "the principal's own language chose the locale, with no caller involvement",
  );

  // 6. SMS is the same rule with one sub-key: an SMS has a body and nothing
  //    else, so `<key>.text` is the whole template. TomSmsRequest likewise has
  //    no text field.
  final code = TomSmsRequest(
    templateKey: 'sms.two_factor',
    to: [TomRecipient('+41791234567')],
    parameters: {'code': '123456', 'firstname': 'Ada'},
  );
  final smsMessage = smsService.render(code);
  print('6. sms text                  : ${smsMessage.textBody!.content}');
  check(
    smsMessage.channel == TomMessageChannel.sms,
    'the SMS service composes on the sms channel',
  );
  check(
    smsMessage.textBody!.content == 'Your code is 123456, Ada.',
    'the whole SMS comes from <key>.text',
  );

  // 7. What email has no equivalent of: a price. An SMS is billed per segment —
  //    160 characters in GSM-7, but only 70 once a single character falls
  //    outside that alphabet. So a *parameter* can triple the cost of a message
  //    whose template never changed, which is exactly the surprise that is
  //    invisible in a green test run.
  final ascii = smsService.segmentationOf(code);
  final accented = smsService.segmentationOf(
    TomSmsRequest(
      templateKey: 'sms.two_factor',
      to: [TomRecipient('+41791234567')],
      parameters: {'code': '123456', 'firstname': 'Zoë'},
    ),
  );
  print(
    '7. "Ada"                     : ${ascii.encoding.name}, '
    '${ascii.units} units, ${ascii.segments} segment, '
    'room for ${ascii.singleCapacity}',
  );
  print(
    '   "Zoë"                     : ${accented.encoding.name}, '
    '${accented.units} units, ${accented.segments} segment, '
    'room for ${accented.singleCapacity}',
  );
  check(
    ascii.encoding == TomSmsEncoding.gsm7,
    'plain text is GSM-7, where a single segment holds 160 characters',
  );
  check(
    accented.encoding == TomSmsEncoding.ucs2,
    'one character outside the GSM alphabet moves the whole message to UCS-2',
  );
  check(
    accented.singleCapacity < ascii.singleCapacity,
    'and the room available collapses, which is what makes it cost more',
  );

  // 8. So the cap is enforced at *render*, before anything is queued: a message
  //    too long is a caller's error, not a line on next month's invoice. The
  //    service cap is separate from the gateway's on purpose — this one is an
  //    application's own bound, and it may be stricter than the deployment's.
  final capped = TomSmsService(outbox: outbox, texts: texts, maxSegments: 1);
  final longRequest = TomSmsRequest(
    templateKey: 'sms.delivery_window',
    to: [TomRecipient('+41791234567')],
    parameters: {'from': '09:00', 'to': '13:00', 'date': 'Tuesday'},
  );
  print(
    '8. would cost                : '
    '${capped.segmentationOf(longRequest).segments} segments',
  );
  var tooLongThrew = false;
  try {
    capped.render(longRequest);
  } on TomMessagingException catch (e) {
    tooLongThrew = true;
    print('   refused with              : ${e.key}');
    check(
      e.key == 'messaging.sms.too_long',
      'the refusal names the length as the reason',
    );
  }
  check(
    tooLongThrew,
    'a message over the service cap is refused at render, before it becomes '
    'something somebody pays for',
  );
  check(
    capped.segmentationOf(longRequest).segments > 1,
    'segmentationOf still measures a message the cap would refuse, because a '
    'measurement that throws cannot be used to decide whether it would',
  );

  // 9. Both services queue on the *same* outbox, and `send` returns once the
  //    message is durably stored — not once it is delivered. Retry, backoff,
  //    permanence and alerting already exist there, on the kernel's job
  //    scheduler; a service that reached past it would grow a second copy of
  //    them beside the working one.
  await emailService.send(request);
  await smsService.send(code);
  print(
    '9. delivered before a tick   : mail=${mail.count} sms=${handsets.count}',
  );
  check(
    mail.count == 0 && handsets.count == 0,
    'send() stores the message and returns, without delivering it',
  );

  // 10. A tick starts the pass. Subscribe before ticking — the receipt stream
  //     is a broadcast, so a listener attached afterwards misses what it is
  //     waiting for.
  final bothDelivered = outbox.receipts.take(2).toList();
  await outbox.tick();
  await bothDelivered;
  print(
    '10. delivered after a tick    : mail=${mail.count} sms=${handsets.count}',
  );
  check(
    mail.count == 1 && handsets.count == 1,
    'one outbox carries every channel, so the SMS rides the retry budget the '
    'email does',
  );
  outbox.close();

  // 11. Only now does a vendor appear. TomSmsTransport turns the message into
  //     whatever fields this gateway wants, and the mapping lives entirely in
  //     the protocol object — nothing above the transport names a vendor field.
  final accepted = _smsTransport(
    (_) async => _answer('{"status":"queued","sid":"SM-9001"}'),
  );
  final receipt = await accepted.transport.send(smsMessage);
  print('11. gateway received          : ${accepted.gateway.bodies.single}');
  print(
    '    outcome                   : ${receipt.outcome.name}, '
    'remoteId=${receipt.remoteId}',
  );
  check(
    accepted.gateway.bodies.single.contains('body=') &&
        accepted.gateway.bodies.single.contains('to='),
    "the vendor's own field names appear in the request and nowhere else",
  );
  check(
    receipt.isDelivered && receipt.remoteId == 'SM-9001',
    "the gateway's id is carried back on the receipt, for correlation with a "
    'later delivery report',
  );

  // 12. And the transport makes exactly one judgement: is this worth trying
  //     again? One dead number among several is a *partial* delivery rather
  //     than a failure — it must not cost the other recipients their message,
  //     exactly as a rejected RCPT TO does not in SMTP.
  final partial = _smsTransport((request) async {
    final body = request is Request ? request.body : '';
    return body.contains('%2B41000000000')
        ? _answer('{"status":"failed","code":"21211","message":"Invalid To"}')
        : _answer('{"status":"queued","sid":"SM-9002"}');
  });
  final mixed = await partial.transport.send(
    smsService.render(
      TomSmsRequest(
        templateKey: 'sms.two_factor',
        to: [TomRecipient('+41000000000'), TomRecipient('+41791234567')],
        parameters: {'code': '654321', 'firstname': 'Ada'},
      ),
    ),
  );
  print(
    '12. partial delivery          : delivered=${mixed.isDelivered} '
    'rejected=${mixed.rejectedRecipients.join(', ')}',
  );
  check(
    mixed.isPartial,
    'one invalid number is a partial delivery, not a failure of the whole '
    'message',
  );

  // A transient provider code is the other half of that judgement: it is not a
  // statement about the message, so it is thrown for the outbox to retry rather
  // than recorded as a rejection.
  final rateLimited = _smsTransport(
    (_) async => _answer('{"status":"failed","code":"20429","message":"Slow"}'),
  );
  var transientThrew = false;
  try {
    await rateLimited.transport.send(smsMessage);
  } on TomDeliveryException catch (e) {
    transientThrew = true;
    print('    rate limited              : permanent=${e.isPermanent}');
    check(
      !e.isPermanent,
      'a rate limit is transient, so the outbox will try the message again '
      'rather than discarding it',
    );
  }
  check(
    transientThrew,
    'a transient refusal stops the pass rather than being reported as a '
    'delivery',
  );
}

Future<void> main() async {
  await run();
}
