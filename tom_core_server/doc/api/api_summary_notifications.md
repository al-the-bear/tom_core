# Tom Core Server API Reference: Notifications Module

The notification model above messaging: the notification types an application
declares and their policy, the audience that resolves who receives one, the
per-user channel choices, cadences and quiet hours read from the user
preferences, the renderer that composes each message and each digest from
resource keys, the dispatcher that fans one notification out to the messaging
outbox, the digests that collect hourly and daily notifications into one
message, and the
`GET /notification-preferences` endpoint a settings screen reads.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomNotificationException](#tomnotificationexception)
  - [TomNotificationType](#tomnotificationtype)
  - [TomNotificationRecipient](#tomnotificationrecipient)
  - [TomNotification](#tomnotification)
  - [TomNotificationAudience](#tomnotificationaudience)
  - [TomNotificationCatalog](#tomnotificationcatalog)
  - [TomQuietHours](#tomquiethours)
  - [TomNotificationChoice](#tomnotificationchoice)
  - [TomNotificationPreferenceSource](#tomnotificationpreferencesource)
  - [TomUserPreferencesNotificationSource](#tomuserpreferencesnotificationsource)
  - [TomNotificationPreferences](#tomnotificationpreferences)
  - [TomNotificationRendering](#tomnotificationrendering)
  - [TomNotificationDigestItem](#tomnotificationdigestitem)
  - [TomNotificationDigestRendering](#tomnotificationdigestrendering)
  - [TomNotificationRenderer](#tomnotificationrenderer)
  - [TomTemplatedNotificationRenderer](#tomtemplatednotificationrenderer)
  - [TomNotificationDelivery](#tomnotificationdelivery)
  - [TomNotificationDispatchReport](#tomnotificationdispatchreport)
  - [TomNotificationDispatcher](#tomnotificationdispatcher)
  - [TomNotificationDigests](#tomnotificationdigests)
  - [TomNotificationPreferencesServer](#tomnotificationpreferencesserver)
- [Enums](#enums)
  - [TomNotificationCadence](#tomnotificationcadence)
  - [TomNotificationChoiceOrigin](#tomnotificationchoiceorigin)
  - [TomNotificationDeliveryOutcome](#tomnotificationdeliveryoutcome)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/notifications/notification.dart`,
`lib/src/tomserver/notifications/notification_catalog.dart`,
`lib/src/tomserver/notifications/notification_preferences.dart`,
`lib/src/tomserver/notifications/notification_renderer.dart`,
`lib/src/tomserver/notifications/notification_dispatcher.dart`,
`lib/src/tomserver/notifications/notification_digests.dart`,
`lib/src/tomserver/notifications/notification_preferences_endpoint.dart`.

A notification is not a message. It names *what happened* and *for whom*;
`TomNotificationDispatcher` turns it into one message per recipient and channel
the recipient wants it on, and hands each to `TomMessageOutbox.send`. The
messaging module knows nothing about notifications, and this module nothing
about transports: a channel the deployment routes is a channel a type may
allow. A recipient who chose an hourly or daily cadence for a type gets its
notifications collected by `TomNotificationDigests` into one message per channel
when the digest is due.

The preference *keys* (`TomNotificationPreferenceKeys`) and the endpoint's API
declaration (`tomNotificationPreferencesApi`) are `tom_core_kernel`'s
`preferences` module, because a client writes the choices and reads the
endpoint. A user's choices are ordinary user preferences, so this module has no
store of its own.

## Class Hierarchy

```text
TomServerException
└── TomNotificationException

TomNotificationType
TomNotificationCadence                     (enum)
TomNotificationRecipient
TomNotification

TomNotificationAudience                    (abstract; .of(function))
TomNotificationCatalog                     (bean-installed)

TomQuietHours
TomNotificationChoice
TomNotificationPreferenceSource            (abstract)
└── TomUserPreferencesNotificationSource
TomNotificationPreferences

TomNotificationRendering
TomNotificationDigestItem
TomNotificationDigestRendering
TomNotificationRenderer                    (abstract)
└── TomTemplatedNotificationRenderer

TomNotificationDelivery
TomNotificationDispatchReport
TomNotificationDispatcher                  (bean-resolvable)
TomNotificationDigests                     (implements TomClosable)

TomNotificationPreferencesServer           (@tomReflector, @tomComponent, @TomApiImplementation)
```

## Classes

### TomNotificationException

Raised when a notification cannot be declared, raised or rendered; `key` names
which. See [doc/notifications.md](../notifications.md#error-keys) for every key.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomNotificationException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  StackTrace? stack,
})
```

Parameters mirror `TomServerException`.

### TomNotificationType

A kind of notification the application raises — `taskAssigned`,
`invoiceOverdue`. The set is the application's vocabulary; what a type declares
is the policy around it. Two types are the same type when their names are
equal.

#### Constructors

```dart
TomNotificationType({
  required String name,
  String? category,
  required Set<TomMessageChannel> allowedChannels,
  Set<TomMessageChannel> defaultChannels = const {},
  bool mandatory = false,
  bool urgent = false,
  TomNotificationCadence defaultCadence = TomNotificationCadence.immediate,
})
```

Refuses (`notifications.type.invalid`) a name or category that is not a letter
followed by letters, digits, `_` or `-`; no allowed channel; a default channel
that is not allowed; a mandatory type without a default channel; and an urgent
type whose default cadence is a digest.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The type's name. Part of preference keys and resource keys, so a dot or a space is refused. |
| `category` | `String?` | A group of types a user can choose for at once; `null` for none. |
| `allowedChannels` | `Set<TomMessageChannel>` | The channels it may ever go out on; never empty. No user choice widens it. |
| `defaultChannels` | `Set<TomMessageChannel>` | What a recipient who chose nothing receives it on; a subset of `allowedChannels`. Empty means "only to those who chose a channel". |
| `mandatory` | `bool` | The user cannot turn it off: a choice leaving no channel falls back to `defaultChannels`. |
| `urgent` | `bool` | Delivered at once, through the recipient's quiet hours and whatever cadence they chose; never collected into a digest. |
| `defaultCadence` | `TomNotificationCadence` | The cadence of a recipient who chose none; `immediate` by default. |
| `hashCode` | `int` | *(override)* The name's hash. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `allowedOf` | `Set<TomMessageChannel> allowedOf(Iterable<String> names)` | The channels of `names` this type allows, ignoring the rest — a stored choice may name a channel the type does not allow. |
| `operator ==` | `bool operator ==(Object other)` | *(override)* Equal names. |

### TomNotificationRecipient

Someone a notification reaches: the principal whose preferences decide the
channels, and the addresses they can be reached at. The addresses are the
application's to supply; the framework stores none.

#### Constructors

```dart
TomNotificationRecipient({
  required TomPrincipal principal,
  Map<TomMessageChannel, List<TomRecipient>> addresses = const {},
  TomTextLocale? locale,
  Map<String, Object?> parameters = const {},
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `principal` | `TomPrincipal` | Its `qualifiedId` identifies the recipient; its roles select the role defaults of its preferences. |
| `addresses` | `Map<TomMessageChannel, List<TomRecipient>>` | The addresses on each channel. A push channel may carry several (one per device), and each becomes a recipient of the one message. A channel with no address is skipped. |
| `locale` | `TomTextLocale?` | The locale it is rendered in; the resources' default when `null`. |
| `parameters` | `Map<String, Object?>` | Template values besides the notification's own — typically the recipient's name (`{firstname}`). |
| `id` | `String` | `principal.qualifiedId`, the identity two recipients are merged by. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `merge` | `TomNotificationRecipient merge(TomNotificationRecipient other)` | This recipient with `other`'s addresses added (an address already present is not repeated), its own first; this one's locale and parameters win. |

### TomNotification

One occurrence of a notification.

#### Constructors

```dart
TomNotification({
  String? id,
  required TomNotificationType type,
  Map<String, Object?> parameters = const {},
  List<TomNotificationRecipient> recipients = const [],
  DateTime? createdAt,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | Identifies this occurrence; every message it fans out to derives its id from it. Give one of your own when the event has one (`taskAssigned:4711:2026-10-27T10:00`); a random UUID otherwise. |
| `type` | `TomNotificationType` | What kind of notification it is. |
| `parameters` | `Map<String, Object?>` | The values its templates are rendered with (`{taskTitle}`). |
| `recipients` | `List<TomNotificationRecipient>` | Recipients named where it was raised, merged with the audience's. |
| `createdAt` | `DateTime` | When it was raised; UTC now by default. |

### TomNotificationAudience

Subscription resolution: who receives a notification of one type. A query over
the application's own entities, so the application's to write. It answers
recipients with their addresses; whether each wants the notification is decided
afterwards from their preferences.

#### Constructors

```dart
const TomNotificationAudience()

const factory TomNotificationAudience.of(
  FutureOr<Iterable<TomNotificationRecipient>> Function(
    TomNotification notification,
  )
  resolve,
)
```

The default constructor is for a subclass; `.of` builds an audience answered by
the function.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `FutureOr<Iterable<TomNotificationRecipient>> resolve(TomNotification notification)` | *(abstract)* The recipients of `notification`; a recipient answered twice is merged. |

### TomNotificationCatalog

The registered notification types, each with its audience. Installed as a bean
so `GET /notification-preferences` can list the types; the dispatcher takes it
as an argument.

#### Constructors

```dart
TomNotificationCatalog()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `types` | `List<TomNotificationType>` | The registered types, in registration order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `void register(TomNotificationType type, {TomNotificationAudience? audience})` | Registers `type` with the audience that resolves its recipients (none: only the recipients a notification names reach it). Refuses (`notifications.type.duplicate`) a second, different declaration under one name; registering the same declaration again replaces the audience. |
| `typeNamed` | `TomNotificationType? typeNamed(String name)` | The type named `name`, or `null`. |
| `isRegistered` | `bool isRegistered(TomNotificationType type)` | Whether `type` is the declaration registered under its name (identity, not name equality). |
| `audienceOf` | `TomNotificationAudience? audienceOf(TomNotificationType type)` | The audience of `type`, or `null`. |
| `install` | `void install()` | Installs this catalog as the process-wide bean, replacing one installed before. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `static TomNotificationCatalog? resolve()` | The installed catalog, or `null`. |

### TomQuietHours

A window of the day during which non-urgent notifications are held, in minutes
after midnight of the principal's time zone. A window whose end comes before
its start runs past midnight (`22:00-07:00`); one whose start equals its end is
empty.

#### Constructors

| Constructor | Signature | Description |
| ----------- | --------- | ----------- |
| (default) | `TomQuietHours(int startMinute, int endMinute)` | Each in `0..1439`; refuses (`notifications.quiet_hours.invalid`) anything else. |
| `parse` | `factory TomQuietHours.parse(String value)` | Reads `HH:MM-HH:MM`; refuses (`notifications.quiet_hours.invalid`) anything else. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `startMinute` | `int` | Minutes after midnight the window opens. |
| `endMinute` | `int` | Minutes after midnight the window closes. |
| `isEmpty` | `bool` | Whether start equals end. |
| `hashCode` | `int` | *(override)* The hash of start and end. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `contains` | `bool contains(int minuteOfDay)` | Whether the minute falls inside the window; never for an empty one. |
| `endAfter` | `DateTime? endAfter(DateTime now, TomTimezone zone)` | When the window around `now` ends, read in `zone`, as a UTC instant; `null` when `now` is outside it. The end is the wall-clock end with the offset in force then, so a window spanning a daylight-saving change ends at its local time. |
| `encode` | `String encode()` | The window as `HH:MM-HH:MM`. |
| `operator ==` | `bool operator ==(Object other)` | *(override)* Same start and end. |

#### Static Methods

The wall-clock arithmetic the window and the digest times share. A wall-clock
reading is a UTC `DateTime` whose fields are the local ones.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `wallClockOf` | `static DateTime wallClockOf(DateTime instant, TomTimezone zone)` | The wall-clock reading of `instant` in `zone`. |
| `instantOf` | `static DateTime instantOf(DateTime wallClock, TomTimezone zone)` | The instant at which the clocks of `zone` read `wallClock`, with the offset in force then — a time across a daylight-saving change is still its local time. |
| `nextWallClock` | `static DateTime nextWallClock(DateTime local, int minuteOfDay)` | The first wall-clock reading after `local` that shows `minuteOfDay`. |
| `minuteOfDay` | `static int? minuteOfDay(String value)` | The minute of the day `HH:MM` names, or `null` for anything else. |

### TomNotificationChoice

What a principal receives one notification type on, and when.

#### Constructors

```dart
TomNotificationChoice({
  required Set<TomMessageChannel> channels,
  required TomNotificationChoiceOrigin origin,
  TomQuietHours? quietHours,
  TomTimezone? timeZone,
  TomNotificationCadence cadence = TomNotificationCadence.immediate,
  int digestMinute = defaultDigestMinute,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `channels` | `Set<TomMessageChannel>` | The channels, always within the type's allowed channels. |
| `origin` | `TomNotificationChoiceOrigin` | Where `channels` came from. |
| `quietHours` | `TomQuietHours?` | The principal's quiet hours, or `null` for none. |
| `timeZone` | `TomTimezone` | The zone `quietHours` and `digestMinute` are read in; UTC by default. |
| `cadence` | `TomNotificationCadence` | How often the type reaches the principal; `immediate` for an urgent type. |
| `digestMinute` | `int` | The minute of the day a daily digest goes out. |

#### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `defaultDigestMinute` | `int` | `480` | The digest time when none is chosen: 08:00. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `digestAt` | `DateTime? digestAt(DateTime now)` | When the digest a notification raised at `now` joins goes out: for `hourly` the end of the current hour of the principal's clock, for `daily` the next digest time — moved to the end of the quiet hours when it falls inside them. `null` for `immediate`. |

### TomNotificationPreferenceSource

Reads one principal's stored notification preference values — the seam between
the choice rules and the store. A test, or an application keeping its choices
elsewhere, supplies its own.

#### Constructors

```dart
const TomNotificationPreferenceSource()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `read` | `FutureOr<String?> read(TomPrincipal principal, String key)` | *(abstract)* The `String` stored for `principal` under `key` — the principal's own value, else a role or deployment default — or `null`. |

### TomUserPreferencesNotificationSource

`TomNotificationPreferenceSource` over the server's user preferences, role and
deployment defaults included.

- **Extends:** `TomNotificationPreferenceSource`

#### Constructors

```dart
const TomUserPreferencesNotificationSource([TomUserPreferences? preferences])
```

Reads through `preferences`, else the installed `TomUserPreferences` bean.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `read` | `Future<String?> read(TomPrincipal principal, String key)` | *(override)* `TomUserPreferences.getFor<String>(principal, key)`. Throws `notifications.preferences.not_configured` when no `TomUserPreferences` was passed or installed. |

### TomNotificationPreferences

The choice rules: from a principal's stored values to what a notification type
reaches them on.

#### Constructors

```dart
const TomNotificationPreferences({
  TomNotificationPreferenceSource source =
      const TomUserPreferencesNotificationSource(),
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `source` | `TomNotificationPreferenceSource` | Where the stored values come from. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `choiceFor` | `Future<TomNotificationChoice> choiceFor(TomPrincipal principal, TomNotificationType type)` | The first that is set of: the choice for the type, the choice for its category, the type's default channels — cut down to the channels the type allows. A mandatory type whose choice leaves no channel falls back to its defaults. The cadence is the type's cadence key, else its category's, else the type's `defaultCadence` (a value naming no cadence counts as unset; an urgent type is always `immediate`). Carries the quiet hours, the zone and the digest time; a stored window, zone or digest time that cannot be read counts as unset. |
| `quietHoursFor` | `Future<(TomQuietHours?, TomTimezone)> quietHoursFor(TomPrincipal principal)` | The principal's quiet hours (`null` for none or an empty window) and the zone they are read in (UTC when unset or unknown). |

#### Static Methods

Each writes the caller's value — the principal of the request zone — through
`preferences`, else the installed `TomUserPreferences`; with neither it throws
`notifications.preferences.not_configured`.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `setTypeChannels` | `static Future<void> setTypeChannels(TomNotificationType type, Set<TomMessageChannel> channels, {TomUserPreferences? preferences})` | Writes the channels for `type`; an empty set turns it off (a mandatory type still reaches the caller on its defaults). Refuses (`notifications.preferences.channel_not_allowed`) a channel the type does not allow, before writing. |
| `setCategoryChannels` | `static Future<void> setCategoryChannels(String category, Set<TomMessageChannel> channels, {TomUserPreferences? preferences})` | Writes the channels for every type of `category` without a choice of its own; each type still takes only the channels it allows. |
| `setQuietHours` | `static Future<void> setQuietHours(TomQuietHours? window, {String? timeZone, TomUserPreferences? preferences})` | Writes the window and, when given, the zone; `null` removes the window. Refuses (`notifications.preferences.time_zone_unknown`) a zone that is not an IANA name. |
| `setTypeCadence` | `static Future<void> setTypeCadence(TomNotificationType type, TomNotificationCadence cadence, {TomUserPreferences? preferences})` | Writes the cadence for `type`. Refuses (`notifications.preferences.cadence_not_allowed`) a digest for an urgent type. |
| `setCategoryCadence` | `static Future<void> setCategoryCadence(String category, TomNotificationCadence cadence, {TomUserPreferences? preferences})` | Writes the cadence for every type of `category` without one of its own; an urgent type of the category stays immediate. |
| `setDigestTime` | `static Future<void> setDigestTime(String time, {TomUserPreferences? preferences})` | Writes the time of day a daily digest goes out, `HH:MM` in the caller's zone. Refuses (`notifications.preferences.digest_time_invalid`) anything else. |

### TomNotificationRendering

What a renderer is asked to render: one notification, for one recipient, on one
channel.

#### Constructors

```dart
const TomNotificationRendering({
  required TomNotification notification,
  required TomNotificationRecipient recipient,
  required TomMessageChannel channel,
  required List<TomRecipient> addresses,
  required String messageId,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `notification` | `TomNotification` | The notification. |
| `recipient` | `TomNotificationRecipient` | Who it is for. |
| `channel` | `TomMessageChannel` | The channel the message goes out on. |
| `addresses` | `List<TomRecipient>` | The recipient's addresses on `channel`; never empty. |
| `messageId` | `String` | The id the message must carry, which keeps a repeated dispatch from queueing a second copy. |
| `parameters` | `Map<String, Object?>` | The template values: the notification's parameters with the recipient's on top. |
| `metadata` | `Map<String, Object?>` | `notificationType`, `notificationId` and `recipientId` — carried by every rendered message, so a delivery report or a log line leads back to the notification. |

### TomNotificationDigestItem

One notification collected into a digest: enough to render its line when the
digest goes out, long after the notification itself is gone.

#### Constructors

```dart
TomNotificationDigestItem({
  required String notificationId,
  required String type,
  Map<String, Object?> parameters = const {},
  required DateTime raisedAt,
})

factory TomNotificationDigestItem.fromJson(Map<String, Object?> map)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `notificationId` | `String` | The notification's id. |
| `type` | `String` | The name of its type. |
| `parameters` | `Map<String, Object?>` | Its template values, as JSON values. |
| `raisedAt` | `DateTime` | When it was raised. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | `id`, `type`, `parameters` and `raisedAt` (UTC ISO 8601) — the form a digest run's payload holds and `fromJson` reads. |

### TomNotificationDigestRendering

What a renderer is asked to render for a digest: the items collected for one
recipient on one channel, as one message.

#### Constructors

```dart
const TomNotificationDigestRendering({
  required String recipientId,
  TomTextLocale? locale,
  Map<String, Object?> recipientParameters = const {},
  required TomMessageChannel channel,
  required List<TomRecipient> addresses,
  required List<TomNotificationDigestItem> items,
  required String messageId,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `recipientId` | `String` | The recipient's id. |
| `locale` | `TomTextLocale?` | The locale the digest is rendered in. |
| `recipientParameters` | `Map<String, Object?>` | The recipient's template values (`{firstname}`). |
| `channel` | `TomMessageChannel` | The channel the digest goes out on. |
| `addresses` | `List<TomRecipient>` | The recipient's addresses on `channel`. |
| `items` | `List<TomNotificationDigestItem>` | The notifications collected, oldest first; never empty. |
| `messageId` | `String` | The id the digest message must carry. |
| `metadata` | `Map<String, Object?>` | `notificationDigest` (`true`), `notificationIds` and `recipientId` — carried by every digest message. |

### TomNotificationRenderer

Turns a notification into a message for one recipient and channel, and a digest
of notifications into one message.

#### Constructors

```dart
const TomNotificationRenderer()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `TomMessage render(TomNotificationRendering rendering)` | *(abstract)* The message; it must carry `rendering.messageId` and be addressed to `rendering.addresses`. |
| `renderDigest` | `TomMessage renderDigest(TomNotificationDigestRendering rendering)` | *(abstract)* The one message for a digest; it must carry `rendering.messageId` and be addressed to `rendering.addresses`. |

### TomTemplatedNotificationRenderer

The renderer that composes every message from resource keys, in the
recipient's locale. For type `T` on channel `C` it reads
`notification.T.C.<part>` first and `notification.T.<part>` second, for the
parts `subject` (email subject, push title) and `body` (required), and
`notification.T.C.html` for an optional email HTML body. A `webhook` message is
not rendered from text: its body is the notification as JSON (`type`, `id`,
`parameters`).

A digest reads under `notification.digest`: `C.subject` then `subject`, with
`{count}`, and `C.body` then `body` (required), with `{count}` and `{items}`.
`{items}` is the item lines joined by line breaks; each line is
`notification.T.C.digestItem`, else `notification.T.digestItem`, else the
item's channel body, else its body, rendered with the item's parameters and the
recipient's. A webhook digest is JSON: `{"digest": true, "items": [...]}`.

- **Extends:** `TomNotificationRenderer`

#### Constructors

```dart
const TomTemplatedNotificationRenderer({TomLocalizedTextResources? texts})
```

Renders from `texts`, else the installed `TomLocalizedTextResources`.

#### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `keyPrefix` | `String` | `notification` | The prefix of every notification resource key. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `render` | `TomMessage render(TomNotificationRendering rendering)` | *(override)* An email with a text body and, when its key resolves, an HTML body; a push message (`TomMessage.push`) with the title, body and `notificationType` / `notificationId` as data; an SMS with no subject; a webhook carrying JSON; any other channel a text message. A missing body throws `notifications.template.missing` naming the keys tried; no resources at all throws `notifications.texts.not_configured`. |
| `renderDigest` | `TomMessage renderDigest(TomNotificationDigestRendering rendering)` | *(override)* The digest message on the channel's shape — an email or text message with the subject (none for SMS), a push message with the title, a webhook carrying JSON. A missing digest body or item line throws `notifications.template.missing`. |

### TomNotificationDelivery

One recipient-channel pair of a dispatch.

#### Constructors

```dart
const TomNotificationDelivery({
  required String recipientId,
  required TomMessageChannel channel,
  required TomNotificationDeliveryOutcome outcome,
  String? messageId,
  DateTime? notBefore,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `recipientId` | `String` | The recipient's `TomNotificationRecipient.id`. |
| `channel` | `TomMessageChannel` | The channel. |
| `outcome` | `TomNotificationDeliveryOutcome` | What became of it. |
| `messageId` | `String?` | The id of the message; `null` for `noAddress`. |
| `notBefore` | `DateTime?` | For `deferred`, when delivery may start; for `digested`, when the digest goes out. |

### TomNotificationDispatchReport

What a dispatch did.

#### Constructors

```dart
TomNotificationDispatchReport({
  required TomNotification notification,
  required List<TomNotificationDelivery> deliveries,
  required List<String> optedOut,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `notification` | `TomNotification` | The notification dispatched. |
| `deliveries` | `List<TomNotificationDelivery>` | One entry per recipient and channel the recipient wanted it on. |
| `optedOut` | `List<String>` | The recipient ids whose choice left no channel — they turned the type off. |
| `queued` | `List<TomNotificationDelivery>` | The deliveries that queued a message: now (`queued`), held (`deferred`) or into a digest (`digested`). |

### TomNotificationDispatcher

Fans one notification out to the messaging outbox: takes the recipients the
notification names and those the type's audience resolves, merged by
principal; reads each one's choice; renders one message per chosen channel the
recipient has an address on; and queues it — held until the quiet hours end
when the type is not urgent and the window is open now — or, when the recipient
chose an hourly or daily cadence and `digests` is given, adds it to their digest
for that channel. Without `digests` every notification goes out at once.

#### Constructors

```dart
TomNotificationDispatcher({
  required TomMessageOutbox outbox,
  required TomNotificationCatalog catalog,
  TomNotificationPreferences preferences = const TomNotificationPreferences(),
  TomNotificationRenderer renderer = const TomTemplatedNotificationRenderer(),
  TomNotificationDigests? digests,
  DateTime Function()? clock,
})
```

`clock` is the instant quiet hours and digest times are judged against;
`DateTime.now` by default.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `outbox` | `TomMessageOutbox` | Where the messages go. |
| `catalog` | `TomNotificationCatalog` | The registered types and their audiences. |
| `preferences` | `TomNotificationPreferences` | The choice rules. |
| `renderer` | `TomNotificationRenderer` | The renderer. |
| `digests` | `TomNotificationDigests?` | Where notifications of an hourly or daily cadence are collected; `null` sends every notification at once. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `dispatch` | `Future<TomNotificationDispatchReport> dispatch(TomNotification notification)` | Dispatches `notification`. Refuses (`notifications.type.unknown`) a type that is not the declaration registered in `catalog` under its name. Renders every message — and every digested notification as a digest of one — before queueing the first, so a missing template fails the dispatch without having queued part of it. A message the outbox already holds, or a notification its digest already holds, is reported `alreadyQueued`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `resolve` | `static TomNotificationDispatcher? resolve()` | The installed dispatcher, or `null`. |
| `messageIdOf` | `static String messageIdOf(TomNotification notification, TomNotificationRecipient recipient, TomMessageChannel channel)` | `notification-` and the first 32 hex digits of the SHA-256 of the notification id, the recipient id and the channel name: the same for the same three in every process, which is what makes a repeated dispatch queue nothing twice. |

### TomNotificationDigests

Collects digested notifications and sends each digest when it is due. A digest
is one recipient's notifications on one channel for one due time, kept as one
pending run of a scheduler job — in the outbox's job store unless given another:
the run's id names the recipient, the channel and the due time, its payload
holds the items, and it becomes due at the due time. A digest is therefore as
durable as the outbox, and any node of a cluster sends a due one. When the run
comes due the digest is rendered with `renderer.renderDigest` and handed to the
outbox under an id derived from the run, so a retried digest run queues its
message once.

- **Implements:** `TomClosable`

#### Constructors

```dart
factory TomNotificationDigests({
  required TomMessageOutbox outbox,
  required TomNotificationRenderer renderer,
  TomJobStore? store,
  String jobName = tomNotificationDigestJobName,
  TomLeaseLock? lock,
  Duration tickInterval = const Duration(seconds: 30),
  DateTime Function()? clock,
  TomJobAlertSink? onAlert,
  String? owner,
})
```

`store` defaults to `outbox.store`. `lock` serialises appends to one digest
across a cluster — pass the cluster's lease lock; without one, two nodes
appending to the same digest at the same instant can lose an item. The
scheduler retries a failed send five times over a widening backoff.

#### Static Constants

| Constant | Type | Value | Description |
| -------- | ---- | ----- | ----------- |
| `lockTtl` | `Duration` | 30 seconds | How long one append may hold the digest's lease, and how long an append waits for it. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `outbox` | `TomMessageOutbox` | Where a due digest's message goes. |
| `renderer` | `TomNotificationRenderer` | Renders a digest. |
| `jobName` | `String` | The job name digest runs are stored under. |
| `store` | `TomJobStore` | The store holding the digests. |
| `scheduler` | `TomScheduler` | The scheduler that sends due digests; inline-dispatching. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `runIdOf` | `String runIdOf(String recipientId, TomMessageChannel channel, DateTime dueAt)` | `<jobName>:` and the first 32 hex digits of the SHA-256 of the recipient id, the channel name and the due instant. |
| `add` | `Future<bool> add({required TomNotification notification, required TomNotificationRecipient recipient, required TomMessageChannel channel, required DateTime dueAt, required String messageId})` | Adds the notification to the digest due at `dueAt`, creating it when it is the first; `false` when the notification is in it already. Appends to one digest are serialised in the process, and across a cluster through `lock` (`notifications.digest.locked` when the lease does not come free within `lockTtl`). A digest whose run has left `pending` is not reopened: the notification is rendered on its own under `messageId` and sent to the outbox. |
| `tick` | `Future<void> tick()` | Sends every digest due now and waits until they are through; for a caller driving the clock. |
| `start` | `void start()` | Starts sending due digests on the scheduler's tick. |
| `close` | `Future<void> close()` | *(override)* Accepts nothing more, waits for appends in flight and closes the scheduler. `add` and `start` afterwards throw `notifications.digest.closed`. Idempotent. |

### TomNotificationPreferencesServer

The implementation of `tomNotificationPreferencesApi` (`GET
/notification-preferences`). Reads the installed `TomNotificationCatalog` (none:
no types) and the installed dispatcher's `TomNotificationPreferences` (none: the
user preferences).

- **Annotations:** `@tomReflector`, `@tomComponent`,
  `@TomApiImplementation(apiId: tomNotificationPreferencesApiId)`

#### Constructors

```dart
const TomNotificationPreferencesServer()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `listNotificationPreferences` | `Future<Map<String, Object?>> listNotificationPreferences()` | The caller's notification preferences. Throws `notifications.preferences.no_principal` without a principal in the zone. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `describe` | `static Future<Map<String, Object?>> describe(TomPrincipal principal, TomNotificationCatalog catalog, TomNotificationPreferences preferences)` | The answer for `principal`: `types` (each with `name`, `category`, `allowedChannels`, `channels`, `origin` `type` / `category` / `default`, `cadence`, `mandatory`, `urgent`; channel lists sorted), `quietHours` (`HH:MM-HH:MM` or `null`), `timeZone` (`null` for UTC) and `digestTime` (`HH:MM`, `08:00` when unset or unreadable). |

## Enums

### TomNotificationCadence

How often a recipient receives a notification type.

| Value | Description |
| ----- | ----------- |
| `immediate` | One message per notification, when it is raised. |
| `hourly` | One digest at the end of each hour of the recipient's clock. |
| `daily` | One digest a day, at the recipient's digest time. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `named` | `static TomNotificationCadence? named(String name)` | The cadence named `name` (`immediate`, `hourly`, `daily`), or `null`. |

### TomNotificationChoiceOrigin

Where a recipient's channels for a type came from.

| Value | Description |
| ----- | ----------- |
| `type` | The choice for the type itself — the principal's own, or a role or deployment default under the type's key. |
| `category` | The choice for the type's category. |
| `defaults` | The type's declared default channels. |

### TomNotificationDeliveryOutcome

What became of one recipient-channel pair of a dispatch.

| Value | Description |
| ----- | ----------- |
| `queued` | Queued in the outbox for delivery now. |
| `deferred` | Queued in the outbox, held until the recipient's quiet hours end. |
| `digested` | Added to the recipient's hourly or daily digest, which goes out at `notBefore`. |
| `alreadyQueued` | The outbox already held this message, or the digest this notification — an earlier dispatch of the same notification queued it — so nothing was queued again. |
| `noAddress` | The recipient has no address on the channel; nothing was queued. |

## Global Functions and Constants

| Name | Type | Description |
| ---- | ---- | ----------- |
| `tomNotificationDigestJobName` | `String` | `notifications.digest` — the default job name digest runs are stored under. |

The API declaration and the preference keys are in `tom_core_kernel`'s
`preferences` module.
