# notifications

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The notification model, one layer above messaging. A **notification** names
*what happened* and *for whom* — "task 17 was assigned to Ada". This module
turns it into one message per recipient and channel the recipient wants it on,
and hands each message to the messaging outbox, which delivers it like any
other. The outbox knows nothing about notifications, and this module nothing
about transports.

The application supplies four things, because only it knows them:

1. **The types** (`TomNotificationType`) — its vocabulary of events, each with
   its policy: the channels it may use, the channels a user who chose nothing
   gets, whether it may be turned off, whether it waits out quiet hours, and
   how often a user who chose nothing receives it.
2. **The audience** of each type (`TomNotificationAudience`) — who receives
   it, as a query over the application's own data.
3. **The addresses** of each recipient (`TomNotificationRecipient`) — an email
   address, a phone number, device tokens. The framework stores none.
4. **The texts** — resource keys under `notification.<type>`, rendered in the
   recipient's locale. No user-facing text is written in Dart.

The framework supplies the rest: the choice rules that read each user's channel
choices, cadence and quiet hours from the **user preferences** (role and
deployment defaults included, no second store), the renderer, the dispatcher,
the **digests** that collect a user's hourly or daily notifications into one
message per channel, and
`GET /notification-preferences` for a settings screen. The preference keys and
the endpoint's API declaration are the kernel's (`tom_core_kernel`
`preferences` module), because a client writes the one and reads the other.

**A repeated dispatch sends nothing twice.** Every message id is derived from
the notification id, the recipient and the channel, and the outbox queues a
message id once. Dispatching the same notification again — a retry after a
crash halfway through — queues only what the first dispatch did not, and a
digest holds a notification once.

**A digest is a pending job run.** `TomNotificationDigests` keeps each
recipient's digest per channel and due time as one run in the outbox's job
store, due at the end of the hour or at the user's digest time (moved past
their quiet hours), so it survives a restart and any node sends it. Across a
cluster, give it the lease lock, or two nodes appending to one digest at the
same instant can lose an item.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomNotificationType` | A kind of notification and its policy: `name`, `category`, `allowedChannels` (never widened by a user), `defaultChannels`, `mandatory` (cannot be turned off), `urgent` (delivered through quiet hours, never digested), `defaultCadence`. Refuses a declaration it cannot keep (`notifications.type.invalid`). |
| `TomNotificationCadence` | `immediate`, `hourly` or `daily` — how often a recipient receives a type; `named(name)` reads a stored value. |
| `TomNotificationCatalog` | The registered types, each with its audience. Refuses a second declaration under one name (`notifications.type.duplicate`). `install()` makes it the bean the endpoint reads. |
| `TomNotificationAudience` | Subscription resolution — who receives a notification of one type. `TomNotificationAudience.of(function)` for a function. |
| `TomNotificationRecipient` | A principal and their addresses per channel, an optional locale and template parameters. Recipients named twice are merged by `principal.qualifiedId`. |
| `TomNotification` | One occurrence: its `type`, its template `parameters`, recipients named where it was raised, and the `id` every message id derives from. |
| `TomNotificationPreferences` | The choice rules: the type's key, else its category's, else the type's default channels — always cut to what the type allows; a mandatory type never ends with no channel. The cadence falls the same way, from the type's cadence key to its category's to `defaultCadence`; an urgent type is always immediate. Static `setTypeChannels`, `setCategoryChannels`, `setQuietHours`, `setTypeCadence`, `setCategoryCadence` and `setDigestTime` write the caller's choices. |
| `TomNotificationChoice` / `TomNotificationChoiceOrigin` | What one principal receives one type on, where that came from (`type`, `category`, `defaults`), its cadence, their quiet hours and digest time; `digestAt(now)` answers when the digest a notification joins goes out. |
| `TomNotificationPreferenceSource` / `TomUserPreferencesNotificationSource` | Where the stored values come from: the seam, and its implementation over `TomUserPreferences.getFor`. |
| `TomQuietHours` | `HH:MM-HH:MM` in the principal's time zone, past midnight allowed; `endAfter` answers when the window ends, at its local time across a daylight-saving change. Its static `wallClockOf`, `instantOf`, `nextWallClock` and `minuteOfDay` are the clock arithmetic the digest times share. |
| `TomNotificationRenderer` / `TomTemplatedNotificationRenderer` / `TomNotificationRendering` | One notification, one recipient, one channel → one `TomMessage`, from `notification.<type>.<channel>.<part>` then `notification.<type>.<part>`. A webhook gets the notification as JSON. |
| `TomNotificationDigestItem` / `TomNotificationDigestRendering` | One notification as a digest holds it (`toJson` / `fromJson`), and one digest to render as one message — `renderDigest`, from `notification.digest.*` keys with `{count}` and `{items}`, one line per item from `notification.<type>.digestItem`. |
| `TomNotificationDispatcher` | Fans a notification out: recipients, choices, rendering (all before queueing anything), then `outbox.send`, held until the quiet hours end for a non-urgent type — or, with `digests`, into the recipient's digest for an hourly or daily cadence. `messageIdOf` is the deterministic message id. |
| `TomNotificationDigests` | The hourly and daily digests: one pending job run per recipient, channel and due time (`notifications.digest`), `add` appending a notification once, the due digest rendered and handed to the outbox under an id derived from the run. `lock` serialises appends across a cluster. |
| `TomNotificationDispatchReport` / `TomNotificationDelivery` / `TomNotificationDeliveryOutcome` | What a dispatch did: per recipient and channel `queued`, `deferred`, `digested`, `alreadyQueued` or `noAddress`, and who opted out. |
| `TomNotificationPreferencesServer` | `GET /notification-preferences`: every registered type with its allowed channels and the caller's channels in effect, and the caller's quiet hours. |
| `TomNotificationException` | Every failure of the module, keyed `notifications.*`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

/// The user's stored choices. A deployment reads them from the user
/// preferences instead — the default source.
class _Choices extends TomNotificationPreferenceSource {
  final Map<String, String> values = {};

  @override
  String? read(TomPrincipal principal, String key) => values[key];
}

Future<void> main() async {
  final taskAssigned = TomNotificationType(
    name: 'taskAssigned',
    allowedChannels: {TomMessageChannel.email, TomMessageChannel.push},
    defaultChannels: {TomMessageChannel.email},
  );
  final ada = TomPrincipal(
    user: TomUser(id: 'ada', username: 'ada'),
    aci: TomAccessControlInformation(roles: const []),
    authenticated: true,
  );
  final catalog = TomNotificationCatalog()
    ..register(
      taskAssigned,
      audience: TomNotificationAudience.of(
        (notification) => [
          TomNotificationRecipient(
            principal: ada,
            addresses: {
              TomMessageChannel.push: [TomRecipient('device-ada')],
            },
          ),
        ],
      ),
    );

  // Ada chose push for this type.
  final choices = _Choices()
    ..values[TomNotificationPreferenceKeys.typeKey('taskAssigned')] = 'push';

  final push = TomMemoryMessageTransport(channel: TomMessageChannel.push);
  final outbox = TomMessageOutbox(router: TomMessageRouter([push]));
  final dispatcher = TomNotificationDispatcher(
    outbox: outbox,
    catalog: catalog,
    preferences: TomNotificationPreferences(source: choices),
    renderer: TomTemplatedNotificationRenderer(
      texts: TomLocalizedTextResources(
        defaultLocale: TomTextLocale('en'),
        bundles: const {
          'en': {
            'notification': {
              'taskAssigned': {
                'subject': 'New task',
                'body': '"{task}" is yours.',
              },
            },
          },
        },
      ),
    ),
  );

  final report = await dispatcher.dispatch(
    TomNotification(
      id: 'task-17-assigned',
      type: taskAssigned,
      parameters: {'task': 'Write the release notes'},
    ),
  );
  await outbox.tick();
  print(report.deliveries.single.outcome.name); // queued
  print(push.last!.textBody!.content); // "Write the release notes" is yours.
  await outbox.close();
}
```

```bash
dart run example/notifications/notifications_example.dart
```

`example/notifications/notifications_example.dart` goes further in ten
checked steps, all in memory: two types registered with an audience; a category
choice applying to a type and an empty choice turning one off; a mandatory type
falling back to its defaults; one notification fanned out to the outbox; the
same notification dispatched again sending nothing twice; a notification held
through quiet hours in `Europe/Berlin`; an urgent one going through them; the
held one delivered when the window ends; and two notifications collected into
a daily digest at 18:30, sent as one message. `test/notifications_test.dart`
covers the types, the choice rules, quiet hours across zones and midnight, the
dispatcher, the renderer, the digests and the endpoint; `test/messaging_test.dart` the
outbox's idempotence and `notBefore`.

See [`doc/notifications.md`](../../../../doc/notifications.md) for the choice
rules, the resource keys, dispatch and idempotence, digests, and the endpoint.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
