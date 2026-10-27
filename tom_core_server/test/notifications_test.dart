/// The notification model: types and their policy, the choice rules over a
/// principal's preferences, quiet hours, the dispatcher's fan-out to the
/// outbox (merging, opting out, missing addresses, deferral, idempotence), the
/// templated renderer, and `GET /notification-preferences`.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// Preference values held in a map, keyed by principal and key.
class _MapSource extends TomNotificationPreferenceSource {
  final Map<String, Map<String, String>> values;

  _MapSource([Map<String, Map<String, String>>? values])
    : values = values ?? {};

  @override
  String? read(TomPrincipal principal, String key) =>
      values[principal.qualifiedId]?[key];

  void set(TomPrincipal principal, String key, String value) =>
      (values[principal.qualifiedId] ??= {})[key] = value;
}

class _Clock {
  DateTime now;
  _Clock(this.now);
  DateTime call() => now;
}

/// A lease lock some other node always holds.
class _HeldLock extends TomLeaseLock {
  @override
  Future<TomLease?> acquire(
    String resource,
    String owner,
    Duration ttl,
  ) async => null;

  @override
  Future<TomLease?> renew(TomLease lease, Duration ttl) async => null;

  @override
  Future<void> release(TomLease lease) async {}

  @override
  Future<TomLeaseInfo> inspect(String resource) =>
      throw UnimplementedError('not asked');

  @override
  Future<void> forget(TomOneShotResource resource) async {}
}

TomPrincipal _principal(String id, {List<String> roles = const []}) =>
    TomPrincipal(
      user: TomUser(id: id, username: id),
      aci: TomAccessControlInformation(roles: roles),
      authenticated: true,
    );

const _email = TomMessageChannel.email;
const _sms = TomMessageChannel.sms;
const _push = TomMessageChannel.push;
const _webhook = TomMessageChannel.webhook;

final _texts = TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: const {
    'en': {
      'notification': {
        'taskAssigned': {
          'subject': '{firstname}, you have a new task',
          'body': '{taskTitle} was assigned to you.',
          'sms': {'body': 'New task: {taskTitle}'},
          'digestItem': '- {taskTitle}',
          'email': {'html': '<p><b>{taskTitle}</b> was assigned to you.</p>'},
        },
        'securityAlert': {
          'subject': 'Security alert',
          'body': 'A new device signed in.',
        },
        'digest': {
          'subject': '{count} updates for {firstname}',
          'body': 'Since the last digest:\n{items}',
        },
      },
    },
    'de': {
      'notification': {
        'taskAssigned': {
          'subject': '{firstname}, du hast eine neue Aufgabe',
          'body': '{taskTitle} wurde dir zugewiesen.',
        },
      },
    },
  },
);

void main() {
  final taskAssigned = TomNotificationType(
    name: 'taskAssigned',
    category: 'tasks',
    allowedChannels: {_email, _sms, _push},
    defaultChannels: {_email},
  );
  final securityAlert = TomNotificationType(
    name: 'securityAlert',
    allowedChannels: {_email, _push},
    defaultChannels: {_email},
    mandatory: true,
    urgent: true,
  );

  group('a notification type', () {
    test('declares its policy and refuses one it cannot keep', () {
      expect(taskAssigned.allowedOf(['sms', 'webhook', 'fax']), {_sms});
      for (final (build, reason) in [
        (
          () =>
              TomNotificationType(name: 'bad.name', allowedChannels: {_email}),
          'name',
        ),
        (
          () => TomNotificationType(
            name: 'x',
            category: 'a b',
            allowedChannels: {_email},
          ),
          'category',
        ),
        (
          () => TomNotificationType(name: 'x', allowedChannels: {}),
          'no channel',
        ),
        (
          () => TomNotificationType(
            name: 'x',
            allowedChannels: {_email},
            defaultChannels: {_sms},
          ),
          'default channel',
        ),
        (
          () => TomNotificationType(
            name: 'x',
            allowedChannels: {_email},
            mandatory: true,
          ),
          'mandatory',
        ),
      ]) {
        expect(
          build,
          throwsA(
            isA<TomNotificationException>()
                .having((e) => e.key, 'key', 'notifications.type.invalid')
                .having(
                  (e) => e.parameters?['reason'],
                  'reason',
                  contains(reason),
                ),
          ),
        );
      }
    });

    test('a catalog refuses a second type under one name', () {
      final catalog = TomNotificationCatalog()..register(taskAssigned);
      catalog.register(taskAssigned); // the same declaration again
      expect(
        () => catalog.register(
          TomNotificationType(name: 'taskAssigned', allowedChannels: {_sms}),
        ),
        throwsA(
          isA<TomNotificationException>().having(
            (e) => e.key,
            'key',
            'notifications.type.duplicate',
          ),
        ),
      );
      expect(catalog.types, [taskAssigned]);
      expect(catalog.typeNamed('taskAssigned'), same(taskAssigned));
    });
  });

  group('the choice', () {
    final ada = _principal('ada');
    late _MapSource source;
    late TomNotificationPreferences preferences;

    setUp(() {
      source = _MapSource();
      preferences = TomNotificationPreferences(source: source);
    });

    test('falls from the type to its category to its defaults', () async {
      var choice = await preferences.choiceFor(ada, taskAssigned);
      expect(choice.channels, {_email});
      expect(choice.origin, TomNotificationChoiceOrigin.defaults);

      source.set(
        ada,
        TomNotificationPreferenceKeys.categoryKey('tasks'),
        'push',
      );
      choice = await preferences.choiceFor(ada, taskAssigned);
      expect(choice.channels, {_push});
      expect(choice.origin, TomNotificationChoiceOrigin.category);

      source.set(
        ada,
        TomNotificationPreferenceKeys.typeKey('taskAssigned'),
        'sms,email',
      );
      choice = await preferences.choiceFor(ada, taskAssigned);
      expect(choice.channels, {_sms, _email});
      expect(choice.origin, TomNotificationChoiceOrigin.type);
    });

    test('never widens what the type allows, and an empty choice is '
        'off', () async {
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeKey('taskAssigned'),
        'webhook,push',
      );
      expect((await preferences.choiceFor(ada, taskAssigned)).channels, {
        _push,
      });
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeKey('taskAssigned'),
        '',
      );
      expect(
        (await preferences.choiceFor(ada, taskAssigned)).channels,
        isEmpty,
      );
    });

    test('a mandatory type cannot be turned off', () async {
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeKey('securityAlert'),
        '',
      );
      final choice = await preferences.choiceFor(ada, securityAlert);
      expect(choice.channels, {_email});
      expect(choice.origin, TomNotificationChoiceOrigin.defaults);
    });

    test('reads the quiet hours and their zone, ignoring what it cannot '
        'read', () async {
      source.set(
        ada,
        TomNotificationPreferenceKeys.quietHoursKey,
        '22:00-07:00',
      );
      source.set(
        ada,
        TomNotificationPreferenceKeys.timeZoneKey,
        'Europe/Berlin',
      );
      var (window, zone) = await preferences.quietHoursFor(ada);
      expect(window, TomQuietHours(22 * 60, 7 * 60));
      expect(zone.timezone, 'Europe/Berlin');

      source.set(ada, TomNotificationPreferenceKeys.quietHoursKey, 'late');
      source.set(
        ada,
        TomNotificationPreferenceKeys.timeZoneKey,
        'Mars/Olympus',
      );
      (window, zone) = await preferences.quietHoursFor(ada);
      expect(window, isNull);
      expect(zone, TomTimezone.utc);
    });

    test('a write naming a channel the type does not allow is refused before '
        'anything is stored', () {
      expect(
        () => TomNotificationPreferences.setTypeChannels(taskAssigned, {
          _email,
          _webhook,
        }),
        throwsA(
          isA<TomNotificationException>()
              .having(
                (e) => e.key,
                'key',
                'notifications.preferences.channel_not_allowed',
              )
              .having((e) => e.parameters?['channels'], 'channels', [
                'webhook',
              ]),
        ),
      );
    });

    test('channel values encode stably and decode leniently', () {
      expect(
        TomNotificationPreferenceKeys.encodeChannels(['sms', 'email', 'sms']),
        'email,sms',
      );
      expect(TomNotificationPreferenceKeys.decodeChannels(' email, ,push '), {
        'email',
        'push',
      });
      expect(TomNotificationPreferenceKeys.decodeChannels(''), isEmpty);
    });
  });

  group('quiet hours', () {
    test('parse, contain and run past midnight', () {
      final night = TomQuietHours.parse('22:30-07:00');
      expect(night.encode(), '22:30-07:00');
      expect(night.contains(22 * 60 + 29), isFalse);
      expect(night.contains(22 * 60 + 30), isTrue);
      expect(night.contains(3 * 60), isTrue);
      expect(night.contains(7 * 60), isFalse);
      final lunch = TomQuietHours.parse('12:00-13:00');
      expect(lunch.contains(12 * 60 + 30), isTrue);
      expect(lunch.contains(13 * 60), isFalse);
      expect(TomQuietHours.parse('08:00-08:00').isEmpty, isTrue);
      for (final bad in ['24:00-07:00', '7:00-8:00', '22:00', '']) {
        expect(
          () => TomQuietHours.parse(bad),
          throwsA(
            isA<TomNotificationException>().having(
              (e) => e.key,
              'key',
              'notifications.quiet_hours.invalid',
            ),
          ),
          reason: bad,
        );
      }
    });

    test('end at their local time, across a day and a zone', () {
      final berlin = TomTimezone.fromName('Europe/Berlin')!;
      final night = TomQuietHours.parse('22:00-07:00');
      // 23:30 in Berlin (UTC+2 in summer): the window ends at 07:00 Berlin,
      // 05:00 UTC the next day.
      expect(
        night.endAfter(DateTime.utc(2026, 7, 1, 21, 30), berlin),
        DateTime.utc(2026, 7, 2, 5),
      );
      // 02:00 in Berlin in winter (UTC+1): the same morning, 06:00 UTC.
      expect(
        night.endAfter(DateTime.utc(2026, 1, 15, 1), berlin),
        DateTime.utc(2026, 1, 15, 6),
      );
      // Noon in Berlin: outside the window.
      expect(night.endAfter(DateTime.utc(2026, 7, 1, 10), berlin), isNull);
      // The night the clocks go back (25 October 2026, 03:00 CEST -> 02:00
      // CET): the window still ends at 07:00 on the wall clock, now UTC+1.
      expect(
        night.endAfter(DateTime.utc(2026, 10, 24, 21), berlin),
        DateTime.utc(2026, 10, 25, 6),
      );
    });
  });

  group('the dispatcher', () {
    final ada = _principal('ada');
    final ben = _principal('ben');
    final cleo = _principal('cleo');
    late _Clock clock;
    late Map<TomMessageChannel, TomMemoryMessageTransport> transports;
    late TomMessageOutbox outbox;
    late _MapSource source;
    late TomNotificationCatalog catalog;
    late TomNotificationDispatcher dispatcher;

    TomNotificationRecipient recipientFor(
      TomPrincipal principal, {
      bool phone = true,
      TomTextLocale? locale,
    }) => TomNotificationRecipient(
      principal: principal,
      addresses: {
        _email: [TomRecipient('${principal.user.username}@example.com')],
        if (phone) _sms: [TomRecipient('+4915100000${principal.user.id}')],
        _push: [TomRecipient('token-${principal.user.id}')],
      },
      locale: locale,
      parameters: {'firstname': principal.user.username.toUpperCase()},
    );

    setUp(() {
      clock = _Clock(DateTime.utc(2026, 7, 1, 10));
      transports = {
        for (final channel in [_email, _sms, _push, _webhook])
          channel: TomMemoryMessageTransport(channel: channel),
      };
      outbox = TomMessageOutbox(
        router: TomMessageRouter(transports.values.toList()),
        clock: clock.call,
      );
      addTearDown(outbox.close);
      source = _MapSource();
      catalog = TomNotificationCatalog()
        ..register(
          taskAssigned,
          audience: TomNotificationAudience.of(
            (notification) => [recipientFor(ben), recipientFor(ada)],
          ),
        )
        ..register(securityAlert);
      dispatcher = TomNotificationDispatcher(
        outbox: outbox,
        catalog: catalog,
        preferences: TomNotificationPreferences(source: source),
        renderer: TomTemplatedNotificationRenderer(texts: _texts),
        clock: clock.call,
      );
    });

    List<TomMessage> sent(TomMessageChannel channel) =>
        transports[channel]!.sent;

    test(
      'fans one notification out per recipient and chosen channel',
      () async {
        source.set(
          ada,
          TomNotificationPreferenceKeys.typeKey('taskAssigned'),
          'email,sms',
        );
        source.set(
          ben,
          TomNotificationPreferenceKeys.typeKey('taskAssigned'),
          '',
        );
        final report = await dispatcher.dispatch(
          TomNotification(
            id: 'task-17-assigned',
            type: taskAssigned,
            parameters: {'taskTitle': 'Write the release notes'},
            // Named where raised and resolved by the audience: one recipient.
            recipients: [recipientFor(ada), recipientFor(cleo, phone: false)],
          ),
        );
        await outbox.tick();

        expect(report.optedOut, [ben.qualifiedId]);
        expect(
          [
            for (final d in report.deliveries)
              '${d.recipientId}:${d.channel.name}:${d.outcome.name}',
          ],
          unorderedEquals([
            '${ada.qualifiedId}:email:queued',
            '${ada.qualifiedId}:sms:queued',
            '${cleo.qualifiedId}:email:queued',
          ]),
        );
        expect(sent(_email).map((m) => m.recipients.single.address), {
          'ada@example.com',
          'cleo@example.com',
        });
        final mail = sent(
          _email,
        ).firstWhere((m) => m.recipients.single.address == 'ada@example.com');
        expect(mail.subject, 'ADA, you have a new task');
        expect(
          mail.textBody!.content,
          'Write the release notes was assigned to you.',
        );
        expect(
          mail.htmlBody!.content,
          contains('<b>Write the release notes</b>'),
        );
        expect(mail.metadata['notificationType'], 'taskAssigned');
        expect(mail.metadata['notificationId'], 'task-17-assigned');
        final text = sent(_sms).single;
        expect(text.textBody!.content, 'New task: Write the release notes');
        expect(text.subject, isNull);
        expect(sent(_push), isEmpty);
      },
    );

    test('a chosen channel without an address is reported, not '
        'queued', () async {
      source.set(
        cleo,
        TomNotificationPreferenceKeys.typeKey('taskAssigned'),
        'sms',
      );
      // Without its audience: only the recipients named below.
      catalog.register(taskAssigned);
      final report = await dispatcher.dispatch(
        TomNotification(
          type: taskAssigned,
          parameters: {'taskTitle': 'x'},
          recipients: [recipientFor(cleo, phone: false)],
        ),
      );
      expect(
        report.deliveries.single.outcome,
        TomNotificationDeliveryOutcome.noAddress,
      );
      expect(report.queued, isEmpty);
    });

    test('renders in the recipient\'s locale', () async {
      // Without its audience: only the recipients named below.
      catalog.register(taskAssigned);
      await dispatcher.dispatch(
        TomNotification(
          type: taskAssigned,
          parameters: {'taskTitle': 'Bericht'},
          recipients: [recipientFor(ada, locale: TomTextLocale('de'))],
        ),
      );
      await outbox.tick();
      expect(sent(_email).single.subject, 'ADA, du hast eine neue Aufgabe');
    });

    test('holds a non-urgent notification through quiet hours, and lets an '
        'urgent one through', () async {
      // 23:30 in Berlin.
      clock.now = DateTime.utc(2026, 7, 1, 21, 30);
      for (final p in [ada]) {
        source.set(
          p,
          TomNotificationPreferenceKeys.quietHoursKey,
          '22:00-07:00',
        );
        source.set(
          p,
          TomNotificationPreferenceKeys.timeZoneKey,
          'Europe/Berlin',
        );
      }
      // Without its audience: only the recipients named below.
      catalog.register(taskAssigned);
      final held = await dispatcher.dispatch(
        TomNotification(
          type: taskAssigned,
          parameters: {'taskTitle': 'x'},
          recipients: [recipientFor(ada)],
        ),
      );
      final alert = await dispatcher.dispatch(
        TomNotification(type: securityAlert, recipients: [recipientFor(ada)]),
      );
      expect(
        held.deliveries.single.outcome,
        TomNotificationDeliveryOutcome.deferred,
      );
      expect(held.deliveries.single.notBefore, DateTime.utc(2026, 7, 2, 5));
      expect(
        alert.deliveries.single.outcome,
        TomNotificationDeliveryOutcome.queued,
      );

      await outbox.tick();
      expect(sent(_email).map((m) => m.subject), ['Security alert']);

      clock.now = DateTime.utc(2026, 7, 2, 5);
      await outbox.tick();
      expect(sent(_email).map((m) => m.subject), [
        'Security alert',
        'ADA, you have a new task',
      ]);
    });

    test('dispatching the same notification again delivers it once, before '
        'and after the first delivery', () async {
      final notification = TomNotification(
        id: 'task-18-assigned',
        type: taskAssigned,
        parameters: {'taskTitle': 'x'},
      );
      final first = await dispatcher.dispatch(notification);
      final second = await dispatcher.dispatch(notification);
      await outbox.tick();
      final third = await dispatcher.dispatch(notification);
      await outbox.tick();
      expect(first.queued, hasLength(2)); // ada and ben, by email
      for (final repeat in [second, third]) {
        expect(repeat.queued, isEmpty);
        expect(
          repeat.deliveries.map((d) => d.outcome),
          everyElement(TomNotificationDeliveryOutcome.alreadyQueued),
        );
        expect(
          repeat.deliveries.map((d) => d.messageId),
          first.queued.map((d) => d.messageId),
        );
      }
      expect(sent(_email), hasLength(2));
      expect(
        TomNotificationDispatcher.messageIdOf(
          notification,
          recipientFor(ada),
          _email,
        ),
        isNot(
          TomNotificationDispatcher.messageIdOf(
            notification,
            recipientFor(ada),
            _sms,
          ),
        ),
      );
    });

    test('refuses an unregistered type, and a missing template before '
        'anything is queued', () async {
      final stray = TomNotificationType(
        name: 'stray',
        allowedChannels: {_email},
        defaultChannels: {_email},
      );
      await expectLater(
        dispatcher.dispatch(TomNotification(type: stray)),
        throwsA(
          isA<TomNotificationException>().having(
            (e) => e.key,
            'key',
            'notifications.type.unknown',
          ),
        ),
      );
      catalog.register(stray);
      await expectLater(
        dispatcher.dispatch(
          TomNotification(type: stray, recipients: [recipientFor(ada)]),
        ),
        throwsA(
          isA<TomNotificationException>()
              .having((e) => e.key, 'key', 'notifications.template.missing')
              .having((e) => e.parameters?['resourceKeys'], 'keys', [
                'notification.stray.email.body',
                'notification.stray.body',
              ]),
        ),
      );
      await outbox.tick();
      expect(sent(_email), isEmpty);
    });

    test('a webhook carries the notification as JSON', () {
      final hooks = TomNotificationType(
        name: 'invoicePaid',
        allowedChannels: {_webhook},
        defaultChannels: {_webhook},
      );
      final message = const TomTemplatedNotificationRenderer().render(
        TomNotificationRendering(
          notification: TomNotification(
            id: 'inv-1',
            type: hooks,
            parameters: {'invoice': 'R-1001', 'amount': 120},
          ),
          recipient: TomNotificationRecipient(principal: ada),
          channel: _webhook,
          addresses: [TomRecipient('https://hooks.example.com/in')],
          messageId: 'm-1',
        ),
      );
      expect(message.bodies.single.mediaType, 'application/json');
      expect(jsonDecode(message.bodies.single.content), {
        'type': 'invoicePaid',
        'id': 'inv-1',
        'parameters': {'invoice': 'R-1001', 'amount': 120},
      });
    });
  });

  group('digests', () {
    final ada = _principal('ada');
    final ben = _principal('ben');
    final berlin = TomTimezone.fromName('Europe/Berlin')!;
    late _Clock clock;
    late TomMemoryMessageTransport email;
    late TomMemoryMessageTransport hooks;
    late TomMessageOutbox outbox;
    late TomNotificationDigests digests;
    late _MapSource source;
    late TomNotificationDispatcher dispatcher;

    TomNotificationRecipient recipientFor(TomPrincipal principal) =>
        TomNotificationRecipient(
          principal: principal,
          addresses: {
            _email: [TomRecipient('${principal.user.username}@example.com')],
            _webhook: [
              TomRecipient('https://hooks.example.com/${principal.user.id}'),
            ],
          },
          parameters: {'firstname': principal.user.username},
        );

    setUp(() {
      // 12:20 in Berlin.
      clock = _Clock(DateTime.utc(2026, 7, 1, 10, 20));
      email = TomMemoryMessageTransport();
      hooks = TomMemoryMessageTransport(channel: _webhook);
      outbox = TomMessageOutbox(
        router: TomMessageRouter([email, hooks]),
        clock: clock.call,
      );
      addTearDown(outbox.close);
      digests = TomNotificationDigests(
        outbox: outbox,
        renderer: TomTemplatedNotificationRenderer(texts: _texts),
        clock: clock.call,
      );
      addTearDown(digests.close);
      source = _MapSource();
      for (final p in [ada, ben]) {
        source.set(
          p,
          TomNotificationPreferenceKeys.timeZoneKey,
          'Europe/Berlin',
        );
      }
      dispatcher = TomNotificationDispatcher(
        outbox: outbox,
        catalog: TomNotificationCatalog()
          ..register(taskAssigned)
          ..register(securityAlert),
        preferences: TomNotificationPreferences(source: source),
        renderer: TomTemplatedNotificationRenderer(texts: _texts),
        digests: digests,
        clock: clock.call,
      );
    });

    Future<void> tickAll() async {
      await digests.tick();
      await outbox.tick();
    }

    TomNotification task(String id, String title, List<TomPrincipal> to) =>
        TomNotification(
          id: id,
          type: taskAssigned,
          parameters: {'taskTitle': title},
          recipients: [for (final p in to) recipientFor(p)],
        );

    test('a cadence falls from the type to its category to its default, and '
        'an urgent type is always immediate', () async {
      final preferences = TomNotificationPreferences(source: source);
      expect(
        (await preferences.choiceFor(ada, taskAssigned)).cadence,
        TomNotificationCadence.immediate,
      );
      source.set(
        ada,
        TomNotificationPreferenceKeys.categoryCadenceKey('tasks'),
        'daily',
      );
      expect(
        (await preferences.choiceFor(ada, taskAssigned)).cadence,
        TomNotificationCadence.daily,
      );
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeCadenceKey('taskAssigned'),
        'hourly',
      );
      expect(
        (await preferences.choiceFor(ada, taskAssigned)).cadence,
        TomNotificationCadence.hourly,
      );
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeCadenceKey('securityAlert'),
        'daily',
      );
      expect(
        (await preferences.choiceFor(ada, securityAlert)).cadence,
        TomNotificationCadence.immediate,
      );
      expect(
        () => TomNotificationType(
          name: 'x',
          allowedChannels: {_email},
          urgent: true,
          defaultCadence: TomNotificationCadence.daily,
        ),
        throwsA(isA<TomNotificationException>()),
      );
      expect(
        () => TomNotificationPreferences.setTypeCadence(
          securityAlert,
          TomNotificationCadence.hourly,
        ),
        throwsA(
          isA<TomNotificationException>().having(
            (e) => e.key,
            'key',
            'notifications.preferences.cadence_not_allowed',
          ),
        ),
      );
      expect(
        () => TomNotificationPreferences.setDigestTime('8 am'),
        throwsA(
          isA<TomNotificationException>().having(
            (e) => e.key,
            'key',
            'notifications.preferences.digest_time_invalid',
          ),
        ),
      );
    });

    test('a digest is due at the end of the hour or at the digest time, and '
        'never inside quiet hours', () {
      final now = clock.now; // 12:20 Berlin, UTC+2
      TomNotificationChoice choice(
        TomNotificationCadence cadence, {
        int minute = TomNotificationChoice.defaultDigestMinute,
        TomQuietHours? quiet,
      }) => TomNotificationChoice(
        channels: {_email},
        origin: TomNotificationChoiceOrigin.type,
        timeZone: berlin,
        cadence: cadence,
        digestMinute: minute,
        quietHours: quiet,
      );
      expect(choice(TomNotificationCadence.immediate).digestAt(now), isNull);
      expect(
        choice(TomNotificationCadence.hourly).digestAt(now),
        DateTime.utc(2026, 7, 1, 11),
      );
      expect(
        choice(TomNotificationCadence.daily).digestAt(now),
        DateTime.utc(2026, 7, 2, 6), // 08:00 Berlin tomorrow
      );
      expect(
        choice(
          TomNotificationCadence.daily,
          minute: 18 * 60 + 30,
        ).digestAt(now),
        DateTime.utc(2026, 7, 1, 16, 30),
      );
      expect(
        choice(
          TomNotificationCadence.daily,
          minute: 6 * 60,
          quiet: TomQuietHours.parse('22:00-07:00'),
        ).digestAt(now),
        DateTime.utc(2026, 7, 2, 5), // 06:00 is quiet: sent at 07:00
      );
    });

    test('collects a recipient\'s notifications into one message per channel, '
        'sent when due', () async {
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeCadenceKey('taskAssigned'),
        'hourly',
      );
      final first = await dispatcher.dispatch(
        task('t1', 'Write notes', [ada, ben]),
      );
      clock.now = clock.now.add(const Duration(minutes: 10));
      await dispatcher.dispatch(task('t2', 'Review budget', [ada]));
      await tickAll();

      final adaFirst = first.deliveries.firstWhere(
        (d) => d.recipientId == ada.qualifiedId,
      );
      expect(adaFirst.outcome, TomNotificationDeliveryOutcome.digested);
      expect(adaFirst.notBefore, DateTime.utc(2026, 7, 1, 11));
      // Ben chose nothing: his arrives at once; Ada's waits.
      expect(email.sent.map((m) => m.recipients.single.address), [
        'ben@example.com',
      ]);

      clock.now = DateTime.utc(2026, 7, 1, 11);
      await tickAll();
      final digest = email.sent.last;
      expect(digest.recipients.single.address, 'ada@example.com');
      expect(digest.subject, '2 updates for ada');
      expect(
        digest.textBody!.content,
        'Since the last digest:\n- Write notes\n- Review budget',
      );
      expect(digest.metadata['notificationIds'], ['t1', 't2']);

      // Sent once, however often the digest job ticks.
      await tickAll();
      expect(email.count, 2);
    });

    test('dispatching a digested notification again adds it once', () async {
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeCadenceKey('taskAssigned'),
        'daily',
      );
      final notification = task('t3', 'Plan', [ada]);
      await dispatcher.dispatch(notification);
      final again = await dispatcher.dispatch(notification);
      expect(
        again.deliveries.single.outcome,
        TomNotificationDeliveryOutcome.alreadyQueued,
      );
      clock.now = DateTime.utc(2026, 7, 2, 6);
      await tickAll();
      expect(email.sent.single.subject, '1 updates for ada');
    });

    test('an urgent notification is never digested', () async {
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeCadenceKey('securityAlert'),
        'daily',
      );
      final report = await dispatcher.dispatch(
        TomNotification(type: securityAlert, recipients: [recipientFor(ada)]),
      );
      await tickAll();
      expect(
        report.deliveries.single.outcome,
        TomNotificationDeliveryOutcome.queued,
      );
      expect(email.sent.single.subject, 'Security alert');
    });

    test('a digest already sent is not reopened: a late addition goes out '
        'on its own', () async {
      final dueAt = DateTime.utc(2026, 7, 1, 11);
      final ok = await digests.add(
        notification: task('t4', 'Early', [ada]),
        recipient: recipientFor(ada),
        channel: _email,
        dueAt: dueAt,
        messageId: 'm-t4',
      );
      expect(ok, isTrue);
      clock.now = dueAt;
      await tickAll();
      expect(email.count, 1);
      await digests.add(
        notification: task('t5', 'Late', [ada]),
        recipient: recipientFor(ada),
        channel: _email,
        dueAt: dueAt,
        messageId: 'm-t5',
      );
      await outbox.tick();
      expect(email.count, 2);
      expect(email.sent.last.textBody!.content, 'Late was assigned to you.');
    });

    test('a closed digest accepts nothing, and a digest held by another node '
        'is refused once the lease does not come free', () async {
      Future<bool> add(TomNotificationDigests to) => to.add(
        notification: task('t7', 'x', [ada]),
        recipient: recipientFor(ada),
        channel: _email,
        dueAt: DateTime.utc(2026, 7, 1, 11),
        messageId: 'm-t7',
      );
      await digests.close();
      expect(
        () => add(digests),
        throwsA(
          isA<TomNotificationException>().having(
            (e) => e.key,
            'key',
            'notifications.digest.closed',
          ),
        ),
      );
      // Every reading of this clock is a minute later, so the wait for the
      // lease runs past its deadline at once.
      var minutes = 0;
      final held = TomNotificationDigests(
        outbox: outbox,
        renderer: TomTemplatedNotificationRenderer(texts: _texts),
        lock: _HeldLock(),
        clock: () =>
            DateTime.utc(2026, 7, 1, 10).add(Duration(minutes: minutes++)),
      );
      addTearDown(held.close);
      await expectLater(
        add(held),
        throwsA(
          isA<TomNotificationException>().having(
            (e) => e.key,
            'key',
            'notifications.digest.locked',
          ),
        ),
      );
    });

    test('a webhook digest carries the items as JSON', () async {
      final hookType = TomNotificationType(
        name: 'invoicePaid',
        allowedChannels: {_webhook},
        defaultChannels: {_webhook},
        defaultCadence: TomNotificationCadence.hourly,
      );
      final hookDispatcher = TomNotificationDispatcher(
        outbox: outbox,
        catalog: TomNotificationCatalog()..register(hookType),
        preferences: TomNotificationPreferences(source: source),
        renderer: TomTemplatedNotificationRenderer(texts: _texts),
        digests: digests,
        clock: clock.call,
      );
      for (final id in ['i1', 'i2']) {
        await hookDispatcher.dispatch(
          TomNotification(
            id: id,
            type: hookType,
            parameters: {'invoice': id},
            recipients: [recipientFor(ada)],
          ),
        );
      }
      clock.now = DateTime.utc(2026, 7, 1, 11);
      await tickAll();
      final body = jsonDecode(hooks.sent.single.bodies.single.content) as Map;
      expect(body['digest'], isTrue);
      expect(
        [for (final i in body['items'] as List) (i as Map)['id']],
        ['i1', 'i2'],
      );
    });

    test('a missing digest template fails the dispatch before anything is '
        'queued', () async {
      final bare = TomNotificationDispatcher(
        outbox: outbox,
        catalog: TomNotificationCatalog()..register(taskAssigned),
        preferences: TomNotificationPreferences(source: source),
        renderer: TomTemplatedNotificationRenderer(
          texts: TomLocalizedTextResources(
            defaultLocale: TomTextLocale('en'),
            bundles: const {
              'en': {
                'notification': {
                  'taskAssigned': {'body': '{taskTitle}'},
                },
              },
            },
          ),
        ),
        digests: digests,
        clock: clock.call,
      );
      source.set(
        ada,
        TomNotificationPreferenceKeys.typeCadenceKey('taskAssigned'),
        'hourly',
      );
      await expectLater(
        bare.dispatch(task('t6', 'x', [ada])),
        throwsA(
          isA<TomNotificationException>().having(
            (e) => e.key,
            'key',
            'notifications.template.missing',
          ),
        ),
      );
      expect(await outbox.store.all(), isEmpty);
    });
  });

  group('without what it reads from', () {
    setUp(TomBean.resetBeanContext);
    tearDown(TomBean.resetBeanContext);
    final ada = _principal('ada');

    Matcher refused(String key) => throwsA(
      isA<TomNotificationException>().having((e) => e.key, 'key', key),
    );

    test('the preferences say which store is missing', () {
      expect(
        () => const TomUserPreferencesNotificationSource().read(
          ada,
          TomNotificationPreferenceKeys.quietHoursKey,
        ),
        refused('notifications.preferences.not_configured'),
      );
      expect(
        () => TomNotificationPreferences.setCategoryChannels('tasks', {_email}),
        refused('notifications.preferences.not_configured'),
      );
    });

    test('an unknown time zone is refused before anything is written', () {
      expect(
        () => TomNotificationPreferences.setQuietHours(
          TomQuietHours.parse('22:00-07:00'),
          timeZone: 'Mars/Olympus',
        ),
        refused('notifications.preferences.time_zone_unknown'),
      );
    });

    test('the renderer says it has no texts', () {
      expect(
        () => const TomTemplatedNotificationRenderer().render(
          TomNotificationRendering(
            notification: TomNotification(type: taskAssigned),
            recipient: TomNotificationRecipient(principal: ada),
            channel: _email,
            addresses: [TomRecipient('ada@example.com')],
            messageId: 'm',
          ),
        ),
        refused('notifications.texts.not_configured'),
      );
    });

    test('the endpoint answers only an authenticated caller', () {
      expect(
        () => const TomNotificationPreferencesServer()
            .listNotificationPreferences(),
        refused('notifications.preferences.no_principal'),
      );
    });
  });

  group('GET /notification-preferences', () {
    late Handler handler;
    final source = _MapSource();

    setUpAll(() {
      initializeReflection();
      registerFixtureAccessApi();
    });

    setUp(() {
      TomBean.resetBeanContext();
      (TomNotificationCatalog()
            ..register(taskAssigned)
            ..register(securityAlert))
          .install();
      TomBean.overrideWithType<TomNotificationDispatcher>(
        TomNotificationDispatcher(
          outbox: TomMessageOutbox(
            router: TomMessageRouter([TomMemoryMessageTransport()]),
          ),
          catalog: TomNotificationCatalog.resolve()!,
          preferences: TomNotificationPreferences(source: source),
        ),
      );
      final router = TomEndpointRouting().initializeRouter();
      handler = const Pipeline()
          .addMiddleware(
            contextSetupMiddleware('notifications test', {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addMiddleware(tomDefaultAuthenticationMiddleware('notifications'))
          .addHandler(router.call);
    });
    tearDown(TomBean.resetBeanContext);

    Future<Response> get({String? token}) async => handler(
      Request(
        'GET',
        Uri.parse('http://localhost/notification-preferences'),
        headers: {'authorization': ?(token == null ? null : 'Bearer $token')},
      ),
    );

    test('lists every type with the caller\'s channels', () async {
      final ada = _principal('ada');
      source
        ..set(
          ada,
          TomNotificationPreferenceKeys.categoryKey('tasks'),
          'push,sms',
        )
        ..set(ada, TomNotificationPreferenceKeys.quietHoursKey, '22:00-07:00')
        ..set(ada, TomNotificationPreferenceKeys.timeZoneKey, 'Europe/Berlin')
        ..set(
          ada,
          TomNotificationPreferenceKeys.categoryCadenceKey('tasks'),
          'daily',
        )
        ..set(ada, TomNotificationPreferenceKeys.digestTimeKey, '18:30');
      final token = TomServerJwtToken({
        'userId': 'ada',
        'username': 'ada',
      }).getJWT(TomJwtSigning.current.issuer);
      final response = await get(token: token);
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['quietHours'], '22:00-07:00');
      expect(body['timeZone'], 'Europe/Berlin');
      expect(body['digestTime'], '18:30');
      expect(body['types'], [
        {
          'name': 'taskAssigned',
          'category': 'tasks',
          'allowedChannels': ['email', 'push', 'sms'],
          'channels': ['push', 'sms'],
          'origin': 'category',
          'cadence': 'daily',
          'mandatory': false,
          'urgent': false,
        },
        {
          'name': 'securityAlert',
          'category': null,
          'allowedChannels': ['email', 'push'],
          'channels': ['email'],
          'origin': 'default',
          'cadence': 'immediate',
          'mandatory': true,
          'urgent': true,
        },
      ]);
    });

    test('is not answered for an anonymous caller', () async {
      final response = await get();
      expect(response.statusCode, anyOf(401, 403, 404));
    });
  });
}
