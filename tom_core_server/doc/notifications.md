# Notifications Module

The notification model, one layer above messaging: the notification types an
application declares and the policy of each, the audience that answers who
receives one, each user's channel choices, cadences and quiet hours — stored as
ordinary user preferences — the renderer that composes every message from
resource keys, the dispatcher that fans one notification out to the messaging
outbox, the digests that collect a user's hourly or daily notifications into
one message, and the `GET /notification-preferences` endpoint a settings screen
reads.

## Table of Contents

- [Overview](#overview)
  - [A notification is not a message](#a-notification-is-not-a-message)
  - [What the application supplies](#what-the-application-supplies)
- [Notification Types](#notification-types)
  - [The catalog](#the-catalog)
- [Recipients and Audiences](#recipients-and-audiences)
- [The Choice](#the-choice)
  - [The preference keys](#the-preference-keys)
  - [The rules](#the-rules)
  - [Writing a choice](#writing-a-choice)
  - [Another source](#another-source)
- [Quiet Hours](#quiet-hours)
- [Rendering and Resource Keys](#rendering-and-resource-keys)
  - [The webhook channel](#the-webhook-channel)
  - [Digest texts](#digest-texts)
- [Dispatch and Idempotence](#dispatch-and-idempotence)
  - [What a dispatch reports](#what-a-dispatch-reports)
  - [Why a repeated dispatch sends nothing twice](#why-a-repeated-dispatch-sends-nothing-twice)
  - [The tenant of a dispatch](#the-tenant-of-a-dispatch)
- [Digests](#digests)
  - [When a digest is due](#when-a-digest-is-due)
  - [Where a digest is kept](#where-a-digest-is-kept)
  - [A digest across a cluster](#a-digest-across-a-cluster)
- [The Endpoint](#the-endpoint)
- [Wiring a Server](#wiring-a-server)
- [Error Keys](#error-keys)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomNotificationType` | class | A kind of notification the application raises, and its policy: allowed and default channels, category, mandatory, urgent, default cadence |
| `TomNotificationCadence` | enum | How often a recipient receives a type: `immediate`, `hourly` or `daily` |
| `TomNotificationCatalog` | class | The registered types, each with its audience; installed as a bean |
| `TomNotificationAudience` | abstract class | Subscription resolution: who receives a notification of one type |
| `TomNotificationRecipient` | class | A principal, the addresses they can be reached at per channel, their locale and template parameters |
| `TomNotification` | class | One occurrence: type, parameters, named recipients, and the id every message id derives from |
| `TomNotificationPreferences` | class | The choice rules, and the writes of the caller's choices |
| `TomNotificationChoice` | class | What one principal receives one type on, how often, and their quiet hours and digest time |
| `TomNotificationChoiceOrigin` | enum | Where the channels came from: `type`, `category` or `defaults` |
| `TomNotificationPreferenceSource` | abstract class | Reads a principal's stored notification preference values |
| `TomUserPreferencesNotificationSource` | class | That source over `TomUserPreferences`, role and deployment defaults included |
| `TomQuietHours` | class | A daily window, in the principal's time zone, during which non-urgent notifications are held |
| `TomNotificationRendering` | class | One notification, for one recipient, on one channel, under one message id |
| `TomNotificationRenderer` | abstract class | Turns a rendering into a `TomMessage` |
| `TomTemplatedNotificationRenderer` | class | Renders from resource keys in the recipient's locale; a webhook gets the notification as JSON |
| `TomNotificationDigestItem` | class | One notification collected into a digest |
| `TomNotificationDigestRendering` | class | One digest — the items of one recipient on one channel — to render as one message |
| `TomNotificationDigests` | class | Collects hourly and daily notifications and sends each digest through the outbox when it is due |
| `TomNotificationDispatcher` | class | Fans a notification out to the messaging outbox |
| `TomNotificationDispatchReport` | class | What a dispatch did |
| `TomNotificationDelivery` | class | One recipient-channel pair of a dispatch |
| `TomNotificationDeliveryOutcome` | enum | `queued`, `deferred`, `digested`, `alreadyQueued` or `noAddress` |
| `TomNotificationPreferencesServer` | class | The `GET /notification-preferences` handler |
| `TomNotificationException` | class | Every failure of the module, keyed `notifications.*` |

The *contract* half is in `tom_core_kernel`'s `preferences` module:
`TomNotificationPreferenceKeys` spells the preference keys a user's choices are
stored under, and `tomNotificationPreferencesApi` declares the endpoint. A
client writes the choices and reads the endpoint, so both live in the package a
client and a server share.

### A notification is not a message

A **message** (`TomMessage`, in the [messaging module](messaging.md)) is
something to deliver on one channel to a set of addresses. A **notification**
names *what happened* and *for whom* — "task 17 was assigned to Ada" — and says
nothing about channels or addresses. Between the two sit three questions: who
receives it, on which channels each recipient wants it, and in which words.
This module answers them and ends in `TomMessageOutbox.send`, one message per
recipient and chosen channel.

The layering runs one way. Messaging knows nothing about notifications: a
channel the deployment routes (`TomMessageRouter`) is a channel a notification
type may allow, and a channel added to messaging needs nothing here. This
module knows nothing about transports: it never sees an SMTP relay or a push
credential.

### What the application supplies

| What | Why it is the application's | Where it goes |
| ---- | --------------------------- | ------------- |
| The notification types — `taskAssigned`, `invoiceOverdue` | They are its domain vocabulary | `TomNotificationType`, registered in a `TomNotificationCatalog` |
| Who receives each type | A query over its own entities — the assignee, the project members, the watchers | `TomNotificationAudience` |
| The recipients' addresses | Email addresses, phone numbers and device tokens live in its user records; the framework stores none | `TomNotificationRecipient.addresses` |
| The texts | Every user-facing string lives in a resource bundle | `notification.<type>.*` resource keys |

Everything else — reading each user's choices, holding a notification through
quiet hours, collecting digests, rendering, queueing exactly once — is this
module's.

## Notification Types

A type is declared in the application's code. What it declares is the policy
around it:

```dart
final taskAssigned = TomNotificationType(
  name: 'taskAssigned',
  category: 'tasks',
  allowedChannels: {TomMessageChannel.email, TomMessageChannel.push},
  defaultChannels: {TomMessageChannel.email},
  defaultCadence: TomNotificationCadence.immediate,
);
final securityAlert = TomNotificationType(
  name: 'securityAlert',
  allowedChannels: {TomMessageChannel.email, TomMessageChannel.push},
  defaultChannels: {TomMessageChannel.email},
  mandatory: true,
  urgent: true,
);
```

| Field | Meaning |
| ----- | ------- |
| `name` | A letter, then letters, digits, `_` and `-`. It is part of preference keys and resource keys, so a dot or a space is refused. Two types with one name are the same type. |
| `category` | A group of types a user can choose for at once ("everything about tasks by email"), under the same naming rule; `null` for none. A choice for the type itself wins over it. |
| `allowedChannels` | The channels it may ever go out on; never empty. A password reset that must never reach a webhook says so here, and no user choice can widen it. |
| `defaultChannels` | What a user who chose nothing receives it on; a subset of `allowedChannels`. Empty means "only to those who chose a channel". |
| `mandatory` | The user cannot turn it off: a choice leaving no channel falls back to `defaultChannels`. A security alert is mandatory. |
| `urgent` | Delivered at once, through the recipient's quiet hours and whatever cadence they chose — an urgent type is never collected into a digest. |
| `defaultCadence` | How often a user who chose no cadence receives it: `immediate` (the default), or in an `hourly` or `daily` digest. |

The constructor refuses, with `notifications.type.invalid`, a declaration it
could not keep: a name or category outside the naming rule, no allowed channel,
a default channel that is not allowed, a mandatory type with no default
channel — which would be a type nobody can turn off and nobody receives — and
an urgent type whose default cadence is a digest.

### The catalog

`TomNotificationCatalog` holds the registered types, in registration order, and
each type's audience:

```dart
final catalog = TomNotificationCatalog()
  ..register(taskAssigned, audience: TomNotificationAudience.of(assigneeOf))
  ..register(securityAlert);
catalog.install();
```

`register` refuses (`notifications.type.duplicate`) a second, different
declaration under a name already registered; registering the same declaration
again replaces its audience. `install()` makes the catalog the process-wide
bean, which is where [the endpoint](#the-endpoint) reads the types from;
`TomNotificationCatalog.resolve()` answers it, or `null`.

The dispatcher refuses a notification whose type is not *the* declaration
registered under its name (`isRegistered` compares identity, not the name):
a type built somewhere else with the same name may carry a different policy,
and dispatching it would apply a policy nobody registered.

## Recipients and Audiences

A `TomNotificationRecipient` is the principal whose preferences decide the
channels, plus what only the application knows about them:

```dart
TomNotificationRecipient recipientOf(User user) => TomNotificationRecipient(
  principal: user.principal,
  addresses: {
    TomMessageChannel.email: [TomRecipient(user.email)],
    TomMessageChannel.push: [
      for (final token in user.deviceTokens) TomRecipient(token),
    ],
  },
  locale: TomTextLocale(user.language),
  parameters: {'firstname': user.firstName},
);
```

A push channel may carry several addresses, one per device; every one becomes a
recipient of the one message. A channel with no address is skipped for this
recipient whatever they chose, and the dispatch reports it as `noAddress`.
`parameters` are template values offered besides the notification's own.

A notification reaches the recipients the code that raised it names
(`TomNotification.recipients`) **and** those the type's audience resolves. The
audience is a query over the application's own data:

```dart
final audience = TomNotificationAudience.of(
  (notification) async => [
    for (final member in await projectMembers(notification.parameters['projectId']))
      recipientOf(member),
  ],
);
```

A principal answered twice — named and resolved, or resolved twice — is
**merged** by `principal.qualifiedId`: the addresses of both are kept, an
address already present is not repeated, and the first recipient's locale and
parameters win. One person therefore receives one message per channel, however
many routes led to them.

## The Choice

Which channels a user receives a type on, and when, is stored as ordinary user
preferences (see the [preferences module](preferences.md)). There is no second
store, so a user's choices are written through the preferences API, follow the
user across devices, and have role and deployment defaults beneath them like
any other key.

### The preference keys

`TomNotificationPreferenceKeys` (kernel) spells them. Every value is a `String`:

| Key | Example value | Meaning |
| --- | ------------- | ------- |
| `notifications.type.<type>` | `email,push` | The channels for one type |
| `notifications.category.<category>` | `email` | The channels for every type of the category that has no choice of its own |
| `notifications.quietHours` | `22:00-07:00` | The window non-urgent notifications wait out |
| `notifications.timeZone` | `Europe/Berlin` | The IANA zone the window and the digest time are read in; UTC when unset |
| `notifications.cadence.type.<type>` | `hourly` | How often one type is delivered: `immediate`, `hourly` or `daily` |
| `notifications.cadence.category.<category>` | `daily` | The cadence for every type of the category that has no cadence of its own |
| `notifications.digestTime` | `18:30` | When a daily digest goes out, `HH:MM` in the user's zone; 08:00 when unset |

Channel names are comma-separated (`encodeChannels` sorts them and drops
duplicates). **An empty string is a choice** — "no channel" — and differs from
an absent key, which defers to the next level.

### The rules

`TomNotificationPreferences.choiceFor(principal, type)` decides:

1. The channels are the first that is **set** of: the value under the type's
   key, the value under its category's key, the type's `defaultChannels`.
2. They are **cut to the type's `allowedChannels`**. A stored value naming a
   channel the type does not allow — or a typo — cannot widen what the type
   allows; the unknown name is ignored.
3. A **mandatory** type whose choice leaves no channel falls back to its
   `defaultChannels`.

`TomNotificationChoice.origin` says which level applied: `type`, `category` or
`defaults` (a mandatory fallback reports `defaults`). A role or deployment
default stored under the type's key counts as `type`: it is read through
`TomUserPreferences.getFor`, which answers the principal's own value or the
default beneath it, so the role defaults of the principal's roles apply.

| Stored under the type | Stored under its category | Type allows | Defaults | Channels | Origin |
| --------------------- | ------------------------- | ----------- | -------- | -------- | ------ |
| `push` | `email` | email, push | email | push | `type` |
| — | `push,sms` | email, push, sms | email | push, sms | `category` |
| — | `push,sms` | email, push | email | push | `category` |
| — | — | email, push | email | email | `defaults` |
| `''` | — | email, push | email | none — turned off | `type` |
| `''` (mandatory type) | — | email, push | email | email | `defaults` |

The **cadence** is chosen the same way: the value under the type's cadence key,
else under its category's, else the type's `defaultCadence`. A value that names
no cadence counts as unset. An urgent type is always `immediate`, whatever is
stored. `hourly` and `daily` collect the type's notifications into a
[digest](#digests); the cadence applies to every channel the type reaches the
user on.

The choice also carries the principal's quiet hours, time zone and digest time
(`digestMinute`, 08:00 by default). A stored window, zone or digest time that
cannot be read counts as unset rather than failing the notification: the
notification is worth more to the user than honouring a malformed window.

### Writing a choice

A client writes the keys through `PUT /preferences` like any other preference.
Server code writing for the caller of the current request uses the static
helpers, which go through `TomUserPreferences` (the one passed, else the bean):

```dart
await TomNotificationPreferences.setTypeChannels(
  taskAssigned,
  {TomMessageChannel.push},
);
await TomNotificationPreferences.setCategoryChannels('tasks', {});
await TomNotificationPreferences.setQuietHours(
  TomQuietHours.parse('22:00-07:00'),
  timeZone: 'Europe/Berlin',
);
```

`setTypeChannels` refuses a channel the type does not allow
(`notifications.preferences.channel_not_allowed`) before writing anything; an
empty set turns the type off, except that a mandatory type still reaches the
caller on its defaults. `setCategoryChannels` writes the category's value; each
type still takes only the channels it allows. `setQuietHours` refuses a zone
that is not an IANA name (`notifications.preferences.time_zone_unknown`), and
`null` removes the window.

```dart
await TomNotificationPreferences.setTypeCadence(
  taskAssigned,
  TomNotificationCadence.hourly,
);
await TomNotificationPreferences.setCategoryCadence(
  'tasks',
  TomNotificationCadence.daily,
);
await TomNotificationPreferences.setDigestTime('18:30');
```

`setTypeCadence` refuses a digest for an urgent type
(`notifications.preferences.cadence_not_allowed`); `setCategoryCadence` writes
the category's value, and an urgent type of the category stays immediate.
`setDigestTime` refuses anything but `HH:MM`
(`notifications.preferences.digest_time_invalid`). With no `TomUserPreferences`
passed or installed, each writer throws
`notifications.preferences.not_configured`.

### Another source

`TomNotificationPreferences` reads through a `TomNotificationPreferenceSource`,
by default `TomUserPreferencesNotificationSource`. A test, or an application
keeping its choices elsewhere, supplies its own — one method answering the
stored `String` for a principal and a key:

```dart
class MapSource extends TomNotificationPreferenceSource {
  final Map<String, Map<String, String>> byUser = {};

  @override
  String? read(TomPrincipal principal, String key) =>
      byUser[principal.qualifiedId]?[key];
}

final preferences = TomNotificationPreferences(source: MapSource());
```

## Quiet Hours

`TomQuietHours` is a window of the day, `HH:MM-HH:MM`, read in the principal's
time zone. A window whose end comes before its start runs past midnight
(`22:00-07:00`); one whose start equals its end is empty and holds nothing.
`TomQuietHours.parse` refuses anything else with
`notifications.quiet_hours.invalid`, as does the constructor for a minute
outside `0..1439`.

When a notification of a **non-urgent** type is dispatched while the
recipient's window is open, its messages are queued at once and held until the
window ends: `endAfter(now, zone)` answers the end as a UTC instant, and the
dispatcher passes it to `TomMessageOutbox.send` as `notBefore`. The message is
durable from the moment the notification was raised; nothing waits in memory.
An **urgent** type ignores quiet hours.

The end is the window's *local* end. A window spanning a daylight-saving change
ends at its wall-clock time with the offset in force then — `07:00` is `07:00`
the morning after a clock change, not an hour off. `notBefore` is computed when
the notification is dispatched: a window the user changes afterwards does not
move a message already held.

A notification collected into a digest is not held on its own: the digest's due
time is moved past the quiet hours instead (see
[When a digest is due](#when-a-digest-is-due)).

`TomQuietHours` also carries the wall-clock arithmetic the window and the
digest times share: `wallClockOf(instant, zone)` reads an instant on a zone's
clock, `instantOf(wallClock, zone)` turns a clock reading back into an instant
with the offset in force then, `nextWallClock(local, minute)` is the next
reading showing a minute of the day, and `minuteOfDay('HH:MM')` reads a time of
day.

## Rendering and Resource Keys

`TomTemplatedNotificationRenderer` composes every message from resource keys in
the recipient's locale (`TomLocalizedTextResources`, the one passed, else the
bean), so no user-facing text is written in Dart. For type `taskAssigned` on
channel `email` it reads under `notification.taskAssigned` the channel's own key
first and the type's second:

| Text | Keys, in order | Used for |
| ---- | -------------- | -------- |
| subject | `email.subject`, `subject` | the email subject, the push title; an SMS has none |
| body (required) | `email.body`, `body` | the text body of every channel |
| HTML body (optional) | `email.html` | a second body part of an email |

So a type states its text once and overrides it where a channel needs it —
typically a shorter SMS:

```yaml
notification:
  taskAssigned:
    subject: "New task for {firstname}"
    body: "\"{taskTitle}\" is yours now."
    sms:
      body: "New task: {taskTitle}"
```

The parameters are the notification's with the recipient's on top
(`{taskTitle}`, `{firstname}`). A missing body fails with
`notifications.template.missing`, naming the keys tried; no text resources at
all fail with `notifications.texts.not_configured`. A push message carries
`notificationType` and `notificationId` in its data map.

Every rendered message carries `notificationType`, `notificationId` and
`recipientId` in its metadata, so a receipt, a delivery report or a log line
leads back to the notification.

An application that renders differently implements `TomNotificationRenderer`:
one method from a `TomNotificationRendering` to a `TomMessage`, which must carry
`rendering.messageId` and be addressed to `rendering.addresses`.

### The webhook channel

A `webhook` message is not rendered from text: its recipient is a program. Its
body is the notification as JSON, `application/json`, and its subject the type
name:

```json
{"type": "taskAssigned", "id": "task-17-assigned", "parameters": {"taskTitle": "Write the release notes"}}
```

The address is the webhook URL, supplied like any other address. The messaging
module's `TomWebhookTransport` delivers it.

### Digest texts

A [digest](#digests) is rendered by `renderDigest` from keys under
`notification.digest`, with the channel's own key first:

| Text | Keys, in order | Parameters |
| ---- | -------------- | ---------- |
| subject | `notification.digest.<channel>.subject`, `notification.digest.subject` | `{count}` and the recipient's |
| body (required) | `notification.digest.<channel>.body`, `notification.digest.body` | `{count}`, `{items}` and the recipient's |

`{items}` is one line per collected notification, joined by line breaks. Each
line is read under the item's own type: `notification.<type>.<channel>.digestItem`,
`notification.<type>.digestItem`, then the type's channel body and its body —
so a type without a digest line still appears, in its full text. A line is
rendered with the notification's parameters and the recipient's.

```yaml
notification:
  taskAssigned:
    body: "\"{task}\" is yours now."
    digestItem: "- {task}"
  digest:
    subject: "Your updates, {firstname}"
    body: "{count} things happened:\n{items}"
```

A missing digest body or item line is `notifications.template.missing`. A
webhook digest is not rendered from text: its body is JSON,
`{"digest": true, "items": [...]}`, each item with its `id`, `type`,
`parameters` and `raisedAt`. A digest message carries `notificationDigest`
(`true`), `notificationIds` and `recipientId` in its metadata.

## Dispatch and Idempotence

`TomNotificationDispatcher.dispatch(notification)`:

1. Refuses (`notifications.type.unknown`) a type that is not the declaration
   registered in its catalog.
2. Takes the recipients the notification names and those the type's audience
   resolves, merged by principal.
3. Reads each recipient's choice. A recipient whose choice leaves no channel is
   reported as opted out.
4. For each chosen channel — in channel-name order — on which the recipient has
   an address, renders one message under a deterministic id.
5. When the recipient's cadence for the type is `hourly` or `daily` and the
   dispatcher has `digests`, it renders the notification as a digest of one
   instead — only to prove the digest texts exist — and marks it for the
   recipient's digest on that channel.
6. Only when **every** message is rendered, queues each with
   `TomMessageOutbox.send` — with `notBefore` set to the end of the quiet hours
   when the type is not urgent and the window is open — and adds each digested
   notification to its digest.

Rendering everything before queueing anything is what makes a missing template
fail the whole dispatch instead of a part of it: either every recipient's
messages are queued or none are. A missing digest text fails at the dispatch
too, rather than hours later when the digest goes out.

```dart
final dispatcher = TomNotificationDispatcher(
  outbox: outbox,
  catalog: catalog,
);
final report = await dispatcher.dispatch(
  TomNotification(
    id: 'taskAssigned:${task.id}:${assignment.at.toIso8601String()}',
    type: taskAssigned,
    parameters: {'taskTitle': task.title},
    recipients: [recipientOf(task.assignee)],
  ),
);
```

`preferences` defaults to the user preferences and `renderer` to
`TomTemplatedNotificationRenderer`; `clock` is the instant quiet hours and
digest times are judged against. `digests` is where hourly and daily
notifications are collected; a dispatcher without it sends every notification
at once, whatever cadence the user chose.

### What a dispatch reports

`TomNotificationDispatchReport` lists one `TomNotificationDelivery` per
recipient and chosen channel, and the ids of the recipients who opted out:

| Outcome | Meaning |
| ------- | ------- |
| `queued` | Queued for delivery now |
| `deferred` | Queued, held until `notBefore`, the end of the recipient's quiet hours |
| `digested` | Added to the recipient's digest on the channel, which goes out at `notBefore` |
| `alreadyQueued` | The outbox already held this message, or the digest this notification; nothing was queued again |
| `noAddress` | The recipient chose the channel and has no address on it; nothing was queued |

`report.queued` answers the deliveries that queued a message: now, deferred or
into a digest.
The report says what was *queued*; whether a message was then *delivered* is
the outbox's receipts and alerts (see [messaging.md](messaging.md#failure-reporting)).

### Why a repeated dispatch sends nothing twice

`messageIdOf(notification, recipient, channel)` is `notification-` followed by
the first 32 hex digits of the SHA-256 of the notification id, the recipient id
and the channel name: the same three give the same id in every process. The
outbox queues a message id once — `send` answers `false` for an id whose run the
store still holds, queued, delivered or failed for good (see
[messaging.md](messaging.md#delivery-semantics-one-retry-mechanism)).

So dispatching the same notification again — a retry after a crash halfway
through the queueing, or the same event processed twice — queues only what the
first dispatch did not, and reports the rest as `alreadyQueued`. A digest does
the same: it holds a notification id once. That holds as
long as the outbox keeps the finished runs: `purgeFinished` removes them, and a
message id it removed can be queued again.

It also means the notification id is worth choosing. An id derived from the
event — `taskAssigned:4711:2026-10-27T10:00` — makes the same event the same
notification wherever it is raised. The default is a random UUID, under which
two raises of one event are two notifications.

### The tenant of a dispatch

The dispatcher has no tenant of its own: it works in the tenant in context
when `dispatch` is called. The audience resolves recipients there, the
preferences are read there, and every message it queues is queued in that
tenant — the outbox records the tenant on each run, files the message id under
it (`TomMessageOutbox.runIdOf`, so two tenants' notifications of one id are two
messages) and delivers each in its tenant
([messaging.md](messaging.md#messages-per-tenant)). Dispatch a tenant's
notification inside the tenant — a request handler is; a background job planned
per tenant (`TomJobTenants`) is too.

## Digests

A user who chose an `hourly` or `daily` cadence for a type receives its
notifications collected: one message per channel when the digest is due,
listing every notification since the last one. `TomNotificationDigests`
collects them; the dispatcher hands it every notification of a digest cadence.

```dart
final digests = TomNotificationDigests(
  outbox: outbox,
  renderer: const TomTemplatedNotificationRenderer(),
  lock: leaseLock,      // the cluster's lease lock; see below
)..start();

final dispatcher = TomNotificationDispatcher(
  outbox: outbox,
  catalog: catalog,
  digests: digests,
);
```

A digest is **one recipient's notifications on one channel for one due time**.
`add` appends a notification to it and answers `false` when the notification is
in it already, so a repeated dispatch adds nothing. `start()` sends due digests
on the scheduler's tick (every thirty seconds by default); `tick()` sends what
is due now, for a test or a process driving the clock. `close()` waits for the
appends in flight and stops; `add` or `start` afterwards throws
`notifications.digest.closed`.

### When a digest is due

`TomNotificationChoice.digestAt(now)` answers, on the user's clock:

| Cadence | Due |
| ------- | --- |
| `hourly` | The end of the current hour — a notification at 14:20 joins the digest of 15:00 |
| `daily` | The next digest time — 08:00 unless the user chose another — today if it is still ahead, else tomorrow |

A due time inside the user's quiet hours is moved to their end, so a 22:00-07:00
window turns an hourly digest at 23:00 into one at 07:00, which every
notification of the night joins. The times are wall-clock times in the user's
zone and keep their local time across a daylight-saving change.

### Where a digest is kept

A digest is a **pending run of a scheduler job** (`notifications.digest`,
`tomNotificationDigestJobName`), in the outbox's job store unless another is
given. Its id (`runIdOf`) names the recipient — qualified by the tenant in
context, so two tenants' recipients of one id have two digests — the channel and
the due time; it runs in that tenant, and its
payload holds the recipient's address, locale and template parameters and the
collected items (`TomNotificationDigestItem`: id, type, parameters, raised-at);
it becomes due at the due time. So a digest is as durable as the outbox: a node
that restarts finds the digests it was collecting, and any node sends a due
one.

When the run comes due the digest is rendered with `renderDigest` (see
[Digest texts](#digest-texts)) and handed to the outbox under an id derived
from the run — a digest run the scheduler retries queues its message once. A
failed send is retried, up to five attempts over a widening backoff.

A digest that has stopped collecting — its due time passed and it is being
sent, or was sent — is not reopened. A notification arriving for it then is
rendered and sent on its own, under its own message id.

### A digest across a cluster

Appends to one digest are read-modify-write on its run. Within a process they
are serialised. Across a cluster they are serialised through `lock`: pass the
cluster's lease lock (`TomSqlLeaseLock`). **Without a lock, two nodes appending
to the same digest at the same instant can lose an item.** An append waits up
to thirty seconds (`lockTtl`) for the digest's lease and then fails with
`notifications.digest.locked`.

## The Endpoint

`GET /notification-preferences` answers what a settings screen offers a user:

```json
{
  "types": [
    {"name": "taskAssigned", "category": "tasks",
     "allowedChannels": ["email", "push", "sms"],
     "channels": ["push", "sms"], "origin": "category",
     "cadence": "daily",
     "mandatory": false, "urgent": false},
    {"name": "securityAlert", "category": null,
     "allowedChannels": ["email", "push"],
     "channels": ["email"], "origin": "default",
     "cadence": "immediate",
     "mandatory": true, "urgent": true}
  ],
  "quietHours": "22:00-07:00",
  "timeZone": "Europe/Berlin",
  "digestTime": "18:30"
}
```

Every registered type, in registration order, with the channels it may use and
the channels in effect for the caller (sorted), where those came from (`type`,
`category` or `default`), its cadence (`immediate`, `hourly` or `daily`; an
urgent type is always `immediate`), and whether it can be turned off or goes
through quiet hours. `quietHours` and `timeZone` are `null` when unset;
`digestTime` is `08:00` when unset or unreadable.

The endpoint writes nothing. A settings screen changes a choice by writing its
key through `PUT /preferences`, with the value
`TomNotificationPreferenceKeys.encodeChannels(...)`, and reads this endpoint
again.

`TomNotificationPreferencesServer` implements it. Its API,
`tomNotificationPreferencesApi`, is `TomAuthenticatedAccess` and is registered
by `TomEndpointRouting.registerFrameworkApis`, so every server mounts it. It
reads the installed `TomNotificationCatalog` — with none it lists no types —
and the installed dispatcher's `TomNotificationPreferences`, else the user
preferences. An anonymous caller is refused by the pipeline before the handler
runs; a call with no principal in the zone at all fails with
`notifications.preferences.no_principal`. `describe(principal, catalog,
preferences)` builds the same answer for server code that has the three at hand.

## Wiring a Server

```dart
// The user preferences: the store the choices live in.
TomBean.withType<TomUserPreferences>(
  TomUserPreferences(TomUserPreferenceRepository()),
);

// The types and who receives them; installed so the endpoint lists them.
final catalog = TomNotificationCatalog()
  ..register(taskAssigned, audience: taskAudience)
  ..register(securityAlert);
catalog.install();

// The digests, over the same outbox and the cluster's lease lock.
final digests = TomNotificationDigests(
  outbox: outbox,
  renderer: const TomTemplatedNotificationRenderer(),
  lock: leaseLock,
)..start();

// The dispatcher, over the deployment's outbox.
final dispatcher = TomNotificationDispatcher(
  outbox: outbox,
  catalog: catalog,
  digests: digests,
);
TomBean.overrideWithType<TomNotificationDispatcher>(dispatcher);

// Wherever the event happens:
await TomNotificationDispatcher.resolve()!.dispatch(
  TomNotification(type: taskAssigned, parameters: {'taskTitle': title}),
);
```

The texts come from the installed `TomLocalizedTextResources` (see
[resources.md](resources.md)); the outbox, its router and its transports from
the [messaging module](messaging.md#wiring-a-server). The outbox must route
every channel a type allows, or a message on an unrouted channel fails at
delivery. On shutdown, close the digests before the outbox.

## Error Keys

Every failure is a `TomNotificationException` (a `TomServerException`):

| Key | Raised when |
| --- | ----------- |
| `notifications.type.invalid` | A `TomNotificationType` is declared with a name or category outside the naming rule, no allowed channel, a default channel that is not allowed, as mandatory with no default channel, or as urgent with a digest as its default cadence. Carries `type` and `reason` |
| `notifications.type.duplicate` | `TomNotificationCatalog.register` is given a second, different declaration under a registered name. Carries `type` |
| `notifications.type.unknown` | `dispatch` is given a notification whose type is not the declaration registered in the catalog. Carries `type` and `notificationId` |
| `notifications.quiet_hours.invalid` | `TomQuietHours.parse` is given anything but `HH:MM-HH:MM`, or the constructor a minute outside `0..1439` |
| `notifications.preferences.channel_not_allowed` | `setTypeChannels` names a channel the type does not allow. Carries `type` and `channels` |
| `notifications.preferences.time_zone_unknown` | `setQuietHours` names a zone that is not an IANA name. Carries `timeZone` |
| `notifications.preferences.cadence_not_allowed` | `setTypeCadence` asks for a digest for an urgent type. Carries `type` and `cadence` |
| `notifications.preferences.digest_time_invalid` | `setDigestTime` is given anything but `HH:MM`. Carries `time` |
| `notifications.preferences.not_configured` | A choice is read or written and no `TomUserPreferences` was passed or installed |
| `notifications.preferences.no_principal` | The endpoint's handler runs with no principal in the zone |
| `notifications.template.missing` | No body resolves for a type and channel. Carries `type`, `channel` and `resourceKeys` |
| `notifications.texts.not_configured` | A message is rendered and no `TomLocalizedTextResources` was passed or installed |
| `notifications.digest.locked` | An append waited `lockTtl` for a digest's lease held by another node. Carries `digest` |
| `notifications.digest.closed` | `TomNotificationDigests.add` or `start` is called after `close` |

## Core Components

- **`TomNotificationType`** / **`TomNotificationCadence`** / **`TomNotificationCatalog`** /
  **`TomNotificationAudience`** — what can be notified, its policy, and who
  receives it.
- **`TomNotification`** / **`TomNotificationRecipient`** — one occurrence, and
  the people it reaches with their addresses.
- **`TomNotificationPreferences`** / **`TomNotificationChoice`** /
  **`TomNotificationChoiceOrigin`** / **`TomNotificationPreferenceSource`** /
  **`TomUserPreferencesNotificationSource`** / **`TomQuietHours`** — the choice
  rules over the user preferences.
- **`TomNotificationRenderer`** / **`TomTemplatedNotificationRenderer`** /
  **`TomNotificationRendering`** — one notification for one recipient on one
  channel, as a message.
- **`TomNotificationDispatcher`** / **`TomNotificationDispatchReport`** /
  **`TomNotificationDelivery`** / **`TomNotificationDeliveryOutcome`** — the
  fan-out to the outbox, and what it did.
- **`TomNotificationDigests`** / **`TomNotificationDigestItem`** /
  **`TomNotificationDigestRendering`** / **`tomNotificationDigestJobName`** —
  hourly and daily digests, kept as pending job runs and sent as one message.
- **`TomNotificationPreferencesServer`** — `GET /notification-preferences`.
- **`TomNotificationException`** — the module's error.

## Not Yet Implemented

- **A digest is per channel, and its cadence per type.** A user chooses how
  often a type reaches them, not how often each channel does: a daily task
  digest by email is also a daily task digest by push when the user chose both
  channels. Each channel gets its own digest message.
  <!-- unpinned: decision — the cadence keys name types and categories, not channels -->
- **No record of notifications.** Nothing stores a notification or lists a
  user's past notifications — there is no in-app inbox. The outbox's finished
  runs, which carry the notification's id in each message's metadata, are the
  only trace, and they last until `purgeFinished`.
  <!-- unpinned: absence — no notification history or in-app inbox ships -->
- **A user chooses channels, not addresses.** A choice says "push", and every
  device token the application supplies for the recipient receives the message;
  a user cannot choose one device over another through the choice keys.
  <!-- unpinned: decision — the choice keys name channels; addresses are the application's -->

## Verification

`test/notifications_test.dart` covers the module without a database or a
socket. A notification type declares its policy and refuses one it cannot keep,
and the catalog refuses a second type under one name. The choice falls from the
type to its category to its defaults, never widens what the type allows, keeps
a mandatory type on, and reads the quiet hours and their zone while ignoring
values it cannot read; a write naming a disallowed channel is refused before
anything is written. Quiet hours parse, contain and run past midnight, and end
at their local time across a day and a zone. The dispatcher fans one
notification out per recipient and chosen channel, reports a chosen channel
without an address, renders in the recipient's locale, holds a non-urgent
notification through quiet hours while an urgent one goes through, delivers a
repeated dispatch once, and refuses an unregistered type or a missing template
before queueing anything; a webhook carries the notification as JSON. The
endpoint is driven through the real routing pipeline: it lists every type with
the caller's channels, and is not answered for an anonymous caller.

Its `digests` group covers the cadence: it falls from the type to its category
to its default, and an urgent type is always immediate; a digest is due at the
end of the hour or at the digest time, moved past the quiet hours; a
recipient's notifications are collected into one message per channel; a
digested notification dispatched again is added once; an urgent notification
is never digested; a digest already sent is not reopened, and a late addition
goes out on its own; a closed digest accepts nothing, and a digest held by
another node fails the append; a webhook digest carries the items as JSON; and
a missing digest template fails the dispatch before anything is queued. The
group `without what it reads from` covers the preferences, the time zone, the
renderer and the endpoint when what they read is missing.

`test/messaging_test.dart` covers the outbox behaviour the dispatcher relies
on: a message sent twice is queued once, a message already delivered is not
delivered again, and `notBefore` holds a message until that instant.

```bash
dart run example/notifications/notifications_example.dart
```

`example/notifications/notifications_example.dart` runs the module in ten
checked steps, in memory with the messaging module's stand-in transports: two
types registered, one with an audience; a category choice applying to a type
and an empty choice turning one off; a mandatory type falling back to its
defaults; one notification fanned out to the outbox and rendered from the
texts; the same notification dispatched again sending nothing twice; a
notification at 23:30 in `Europe/Berlin` held until 07:00; an urgent one
delivered through the quiet hours; the held one delivered when the window
ends; two task notifications collected into a daily digest due at 18:30 in
`Europe/Berlin`, nothing sent before then; and at 18:30 the digest going out as
one message listing both. `test/examples_test.dart` runs it and requires its
steps.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `notification_catalog.dart`, `notification_digests.dart`, `notification_preferences.dart` | `FutureOr`, so an audience and a preference source may answer synchronously; `Completer` and `unawaited` for the serialised appends |
| `dart:convert` | dart | `notification_digests.dart`, `notification_dispatcher.dart`, `notification_renderer.dart` | `utf8` for the message-id and digest-id hashes, `jsonEncode` for the webhook bodies and the digest payload |
| `crypto` | package | `notification_digests.dart`, `notification_dispatcher.dart` | `sha256`, the deterministic message and digest ids |
| `tom_core_kernel` | package | `notification.dart`, `notification_catalog.dart`, `notification_digests.dart`, `notification_dispatcher.dart`, `notification_preferences.dart`, `notification_preferences_endpoint.dart` | `TomPrincipal`, `TomBean`, `TomTimezone`, `TomNotificationPreferenceKeys`, `tomNotificationPreferencesApiId`, `getFromCurrentZone`; `TomScheduler`, `TomJobStore`, `TomJobRun`, `TomLeaseLock` and `TomRetryPolicy`, which carry the digests |
| `uuid` | package | `notification.dart`, `notification_digests.dart` | `UuidV4`, a notification id when the caller supplies none and the digests' lease owner |
| [endpoints](endpoints.md) | module | `notification_preferences_endpoint.dart` | `@TomApiImplementation` and `@TomApiEndpointImplementation`, by which the pipeline binds the handler to the kernel's declaration |
| [little_things](little_things.md) | module | `notification.dart` | `TomServerException`, the base of `TomNotificationException` |
| [messaging](messaging.md) | module | `notification.dart`, `notification_digests.dart`, `notification_dispatcher.dart`, `notification_preferences.dart`, `notification_renderer.dart` | `TomMessageChannel`, `TomRecipient`, `TomMessage`, `TomMessageBody`, and `TomMessageOutbox`, where every message goes |
| [preferences](preferences.md) | module | `notification_preferences.dart` | `TomUserPreferences`, which stores the choices and answers role and deployment defaults beneath them |
| [resources](resources.md) | module | `notification.dart`, `notification_digests.dart`, `notification_renderer.dart` | `TomLocalizedTextResources` and `TomTextLocale`, which every message is rendered through |
