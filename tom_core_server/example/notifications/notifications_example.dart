/// Executable example for the **notifications** module of `tom_core_server`:
/// notification types, per-user channel choices, quiet hours, and the
/// dispatcher that fans one notification out to the messaging outbox.
///
/// A notification says *what happened* and *for whom* — "task 17 was assigned
/// to Ada". The module turns it into one message per recipient and channel the
/// recipient wants it on — or, for a recipient who chose an hourly or daily
/// cadence, collects it into one digest message; the messaging outbox delivers
/// those like any other message.
///
/// Everything runs in memory: the users' choices come from a map instead of the
/// user-preferences table, and the transports are the messaging module's
/// stand-ins, so no database and no socket are needed.
///
/// Run with `dart run example/notifications/notifications_example.dart`.
/// Every step checks its own result and the run fails when one does not hold.
/// `test/examples_test.dart` runs this file under that exact command.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// ignore_for_file: avoid_print

/// The users' stored choices — in a deployment, rows of the user-preferences
/// table read through [TomUserPreferencesNotificationSource].
class _Choices extends TomNotificationPreferenceSource {
  final Map<String, Map<String, String>> byUser = {};

  @override
  String? read(TomPrincipal principal, String key) =>
      byUser[principal.qualifiedId]?[key];

  void set(TomPrincipal principal, String key, String value) =>
      (byUser[principal.qualifiedId] ??= {})[key] = value;
}

TomPrincipal _user(String id) => TomPrincipal(
  user: TomUser(id: id, username: id),
  aci: TomAccessControlInformation(roles: const []),
  authenticated: true,
);

/// The application's user directory: who a principal is and where to reach
/// them. The framework stores no addresses.
TomNotificationRecipient _recipient(TomPrincipal principal) =>
    TomNotificationRecipient(
      principal: principal,
      addresses: {
        TomMessageChannel.email: [
          TomRecipient('${principal.user.username}@example.com'),
        ],
        TomMessageChannel.push: [TomRecipient('device-${principal.user.id}')],
      },
      parameters: {'firstname': principal.user.username},
    );

Future<void> main() async {
  // The texts every notification is rendered from: no user-facing string is
  // written in Dart.
  final texts = TomLocalizedTextResources(
    defaultLocale: TomTextLocale('en'),
    bundles: const {
      'en': {
        'notification': {
          'taskAssigned': {
            'subject': 'New task for {firstname}',
            'body': '"{task}" is yours now.',
            'digestItem': '- {task}',
          },
          'digest': {
            'subject': 'Your updates, {firstname}',
            'body': '{count} things happened:\n{items}',
          },
          'securityAlert': {
            'subject': 'New sign-in',
            'body': 'Your account was used on a new device.',
          },
        },
      },
    },
  );

  // 1. The application declares its notification types and their policy.
  final taskAssigned = TomNotificationType(
    name: 'taskAssigned',
    category: 'tasks',
    allowedChannels: {TomMessageChannel.email, TomMessageChannel.push},
    defaultChannels: {TomMessageChannel.email},
  );
  final securityAlert = TomNotificationType(
    name: 'securityAlert',
    allowedChannels: {TomMessageChannel.email, TomMessageChannel.push},
    defaultChannels: {TomMessageChannel.email},
    mandatory: true,
    urgent: true,
  );
  final ada = _user('ada');
  final ben = _user('ben');
  final catalog = TomNotificationCatalog()
    // Subscription resolution: a query over the application's own data. Here
    // the project team.
    ..register(
      taskAssigned,
      audience: TomNotificationAudience.of(
        (notification) => [_recipient(ada), _recipient(ben)],
      ),
    )
    ..register(securityAlert);
  print('1. types registered      => ${catalog.types.map((t) => t.name)}');
  check(catalog.types.length == 2, 'both types are registered');

  // 2. Each user's choice: Ada wants task news by push, Ben turned it off.
  final choices = _Choices()
    ..set(
      ada,
      TomNotificationPreferenceKeys.categoryKey('tasks'),
      TomNotificationPreferenceKeys.encodeChannels(['push']),
    )
    ..set(ben, TomNotificationPreferenceKeys.typeKey('taskAssigned'), '');
  final preferences = TomNotificationPreferences(source: choices);
  final adaChoice = await preferences.choiceFor(ada, taskAssigned);
  final benChoice = await preferences.choiceFor(ben, taskAssigned);
  print(
    '2. choices               => ada ${adaChoice.channels} '
    '(${adaChoice.origin.name}), ben ${benChoice.channels}',
  );
  check(
    adaChoice.channels.single == TomMessageChannel.push &&
        adaChoice.origin == TomNotificationChoiceOrigin.category,
    'the category choice applies to the type',
  );
  check(benChoice.channels.isEmpty, 'an empty choice turns the type off');

  // 3. A mandatory type cannot be turned off.
  choices.set(ben, TomNotificationPreferenceKeys.typeKey('securityAlert'), '');
  final alertChoice = await preferences.choiceFor(ben, securityAlert);
  print('3. mandatory alert       => ben ${alertChoice.channels}');
  check(
    alertChoice.channels.single == TomMessageChannel.email,
    'a mandatory type falls back to its default channels',
  );

  // 4. One notification, fanned out to the outbox.
  var now = DateTime.utc(2026, 7, 1, 10);
  final email = TomMemoryMessageTransport();
  final push = TomMemoryMessageTransport(channel: TomMessageChannel.push);
  final outbox = TomMessageOutbox(
    router: TomMessageRouter([email, push]),
    clock: () => now,
  );
  final renderer = TomTemplatedNotificationRenderer(texts: texts);
  // Where hourly and daily notifications are collected: digests are pending
  // runs in the outbox's own job store, so they survive a restart.
  final digests = TomNotificationDigests(
    outbox: outbox,
    renderer: renderer,
    clock: () => now,
  );
  final dispatcher = TomNotificationDispatcher(
    outbox: outbox,
    catalog: catalog,
    preferences: preferences,
    renderer: renderer,
    digests: digests,
    clock: () => now,
  );
  final assigned = TomNotification(
    id: 'task-17-assigned',
    type: taskAssigned,
    parameters: {'task': 'Write the release notes'},
  );
  final report = await dispatcher.dispatch(assigned);
  await outbox.tick();
  print(
    '4. dispatched            => ${report.queued.length} queued, '
    'opted out ${report.optedOut.length}; push "${push.last?.subject}"',
  );
  check(push.count == 1 && email.count == 0, 'Ada gets one push, Ben nothing');
  check(push.last!.subject == 'New task for ada', 'rendered from the texts');

  // 5. Dispatching it again — a retry after a crash — sends nothing twice.
  await dispatcher.dispatch(assigned);
  await outbox.tick();
  print('5. dispatched again      => push total ${push.count}');
  check(push.count == 1, 'the message ids repeat, so the outbox holds one');

  // 6. Quiet hours hold what is not urgent until they end.
  choices
    ..set(ada, TomNotificationPreferenceKeys.quietHoursKey, '22:00-07:00')
    ..set(ada, TomNotificationPreferenceKeys.timeZoneKey, 'Europe/Berlin');
  now = DateTime.utc(2026, 7, 1, 21, 30); // 23:30 in Berlin
  final late = await dispatcher.dispatch(
    TomNotification(
      type: taskAssigned,
      parameters: {'task': 'Review the budget'},
      recipients: [_recipient(ada)],
    ),
  );
  await outbox.tick();
  final heldUntil = late.queued.single.notBefore;
  print('6. at 23:30 Berlin       => held until $heldUntil');
  check(push.count == 1, 'nothing is delivered during quiet hours');
  check(
    heldUntil == DateTime.utc(2026, 7, 2, 5),
    'held until 07:00 Berlin, 05:00 UTC',
  );

  // 7. An urgent notification goes through them.
  await dispatcher.dispatch(
    TomNotification(type: securityAlert, recipients: [_recipient(ada)]),
  );
  await outbox.tick();
  print('7. urgent alert          => email "${email.last?.subject}"');
  check(email.count == 1, 'the urgent alert is delivered at once');

  // 8. When the window ends, the held notification is delivered.
  now = DateTime.utc(2026, 7, 2, 5);
  await outbox.tick();
  print('8. at 07:00 Berlin       => push "${push.last?.textBody?.content}"');
  check(push.count == 2, 'the held notification is delivered');

  // 9. Ben takes task news back, once a day at 18:30 Berlin time.
  choices
    ..set(ben, TomNotificationPreferenceKeys.typeKey('taskAssigned'), 'email')
    ..set(
      ben,
      TomNotificationPreferenceKeys.categoryCadenceKey('tasks'),
      TomNotificationCadence.daily.name,
    )
    ..set(ben, TomNotificationPreferenceKeys.digestTimeKey, '18:30')
    ..set(ben, TomNotificationPreferenceKeys.timeZoneKey, 'Europe/Berlin');
  now = DateTime.utc(2026, 7, 2, 9); // 11:00 in Berlin
  final mailsBefore = email.count;
  TomNotificationDelivery? collected;
  for (final task in ['Fix the login page', 'Update the roadmap']) {
    final report = await dispatcher.dispatch(
      TomNotification(
        type: taskAssigned,
        parameters: {'task': task},
        recipients: [_recipient(ben)],
      ),
    );
    // The team audience adds Ada too; Ben's delivery is the one to look at.
    collected = report.deliveries.firstWhere(
      (d) => d.recipientId == ben.qualifiedId,
    );
  }
  await digests.tick();
  await outbox.tick();
  print(
    '9. digested for ben      => ${collected!.outcome.name}, '
    'due ${collected.notBefore}',
  );
  check(email.count == mailsBefore, 'nothing is sent before the digest time');
  check(
    collected.notBefore == DateTime.utc(2026, 7, 2, 16, 30),
    'due at 18:30 Berlin, 16:30 UTC',
  );

  // 10. At 18:30 the digest goes out as one message.
  now = DateTime.utc(2026, 7, 2, 16, 30);
  await digests.tick();
  await outbox.tick();
  print('10. digest at 18:30      => "${email.last?.subject}"');
  check(email.count == mailsBefore + 1, 'one message for both notifications');
  check(
    email.last!.textBody!.content ==
        '2 things happened:\n- Fix the login page\n- Update the roadmap',
    'the digest lists both',
  );

  await digests.close();
  await outbox.close();
  print('\nNotifications example completed.');
}
