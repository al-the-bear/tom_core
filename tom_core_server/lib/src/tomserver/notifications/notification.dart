/// The notification model: what kinds of notification an application raises
/// ([TomNotificationType]), one occurrence of one ([TomNotification]), and the
/// person it reaches with the addresses they can be reached at
/// ([TomNotificationRecipient]).
///
/// A notification is not a message. It names *what happened* and *for whom*;
/// [TomNotificationDispatcher] turns it into one message per recipient and
/// channel the recipient wants it on, and hands each to the messaging outbox.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/v4.dart';

import '../little_things/server_exception.dart';
import '../messaging/message.dart';
import '../resources/localized_text_resources.dart';

/// Raised when a notification cannot be declared, raised or rendered; [key]
/// names which (`notifications.type.invalid`, `notifications.type.unknown`,
/// `notifications.template.missing`, …).
class TomNotificationException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomNotificationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// A kind of notification the application raises — `taskAssigned`,
/// `invoiceOverdue`.
///
/// The set is the application's vocabulary, declared in its own code and
/// registered in a [TomNotificationCatalog]; the framework knows none of them.
/// What a type declares is the policy around it:
///
/// - [allowedChannels]: the channels it may ever go out on. A password reset
///   that must never reach a webhook says so here, and no user choice can
///   widen it.
/// - [defaultChannels]: what a user who chose nothing receives it on.
/// - [category]: a group of types a user can choose for at once ("everything
///   about tasks by email"); a choice for the type itself wins over it.
/// - [mandatory]: the user cannot turn it off entirely — choosing no channel
///   falls back to [defaultChannels]. A security alert is mandatory.
/// - [urgent]: it is delivered at once, through the recipient's quiet hours,
///   and never collected into a digest.
/// - [defaultCadence]: how often a recipient who chose no cadence receives
///   it — at once, or in an hourly or daily digest.
///
/// Two types are the same type when their names are equal.
class TomNotificationType {
  /// The type's name: a letter, then letters, digits, `_` and `-`. It is part
  /// of preference keys and resource keys, so a dot or a space is refused.
  final String name;

  /// The category it belongs to, under the same naming rule; `null` for none.
  final String? category;

  /// The channels it may go out on; never empty.
  final Set<TomMessageChannel> allowedChannels;

  /// The channels a recipient who chose nothing receives it on; a subset of
  /// [allowedChannels]. Empty means "only to those who chose a channel".
  final Set<TomMessageChannel> defaultChannels;

  /// Whether a recipient may turn it off entirely.
  final bool mandatory;

  /// Whether it is delivered at once, through the recipient's quiet hours and
  /// whatever cadence they chose.
  final bool urgent;

  /// The cadence of a recipient who chose none.
  final TomNotificationCadence defaultCadence;

  static final RegExp _namePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$');

  /// Declares a type; refuses (`notifications.type.invalid`) a name or
  /// category outside the naming rule, no allowed channel, a default channel
  /// that is not allowed, and a mandatory type without a default channel.
  TomNotificationType({
    required this.name,
    this.category,
    required Set<TomMessageChannel> allowedChannels,
    Set<TomMessageChannel> defaultChannels = const {},
    this.mandatory = false,
    this.urgent = false,
    this.defaultCadence = TomNotificationCadence.immediate,
  }) : allowedChannels = Set.unmodifiable(allowedChannels),
       defaultChannels = Set.unmodifiable(defaultChannels) {
    String? problem;
    if (!_namePattern.hasMatch(name)) {
      problem =
          "the name '$name' is not a letter followed by letters, "
          'digits, _ or -';
    } else if (category != null && !_namePattern.hasMatch(category!)) {
      problem =
          "the category '$category' is not a letter followed by "
          'letters, digits, _ or -';
    } else if (allowedChannels.isEmpty) {
      problem = 'it allows no channel';
    } else if (!allowedChannels.containsAll(defaultChannels)) {
      problem = 'a default channel is not among its allowed channels';
    } else if (mandatory && defaultChannels.isEmpty) {
      problem = 'it is mandatory but has no default channel';
    } else if (urgent && defaultCadence != TomNotificationCadence.immediate) {
      problem = 'it is urgent but collected into a digest by default';
    }
    if (problem != null) {
      throw TomNotificationException(
        'notifications.type.invalid',
        "Notification type '$name' cannot be declared: $problem.",
        parameters: {'type': name, 'reason': problem},
      );
    }
  }

  /// The channels of [names] this type allows, ignoring the rest — a stored
  /// choice may name a channel the type has since stopped allowing.
  Set<TomMessageChannel> allowedOf(Iterable<String> names) => {
    for (final channel in allowedChannels)
      if (names.contains(channel.name)) channel,
  };

  @override
  bool operator ==(Object other) =>
      other is TomNotificationType && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'TomNotificationType($name)';
}

/// How often a recipient receives a notification type: at once, or collected
/// with the others of the same channel into one digest message per hour or
/// per day.
enum TomNotificationCadence {
  /// One message per notification, when it is raised.
  immediate,

  /// One digest at the end of each hour of the recipient's clock.
  hourly,

  /// One digest a day, at the recipient's digest time.
  daily;

  /// The cadence named [name] (`immediate`, `hourly`, `daily`), or `null`.
  static TomNotificationCadence? named(String name) {
    for (final cadence in values) {
      if (cadence.name == name.trim()) return cadence;
    }
    return null;
  }
}

/// Someone a notification reaches: the [principal] whose preferences decide
/// the channels, and the [addresses] they can be reached at on each channel.
///
/// The addresses are the application's to supply — an email address and a
/// phone number from its user record, the push tokens of the user's devices —
/// because the framework stores none of them. A channel with no address is
/// skipped for this recipient, whatever they chose.
class TomNotificationRecipient {
  /// The principal; [TomPrincipal.qualifiedId] identifies the recipient, and
  /// its roles select the role defaults of its preferences.
  final TomPrincipal principal;

  /// The addresses on each channel; a push channel may carry several (one per
  /// device), and every one becomes a recipient of the one message.
  final Map<TomMessageChannel, List<TomRecipient>> addresses;

  /// The locale the notification is rendered in; the resources' default when
  /// `null`.
  final TomTextLocale? locale;

  /// Values the renderer offers the templates besides the notification's own
  /// parameters — typically the recipient's name (`{firstname}`).
  final Map<String, Object?> parameters;

  /// Creates a recipient.
  TomNotificationRecipient({
    required this.principal,
    Map<TomMessageChannel, List<TomRecipient>> addresses = const {},
    this.locale,
    Map<String, Object?> parameters = const {},
  }) : addresses = Map.unmodifiable({
         for (final entry in addresses.entries)
           entry.key: List<TomRecipient>.unmodifiable(entry.value),
       }),
       parameters = Map.unmodifiable(parameters);

  /// The identity two recipients are merged by.
  String get id => principal.qualifiedId;

  /// This recipient with [other]'s addresses added, its own kept first; the
  /// locale and parameters of this one win.
  TomNotificationRecipient merge(TomNotificationRecipient other) {
    final merged = <TomMessageChannel, List<TomRecipient>>{
      for (final entry in addresses.entries) entry.key: [...entry.value],
    };
    for (final entry in other.addresses.entries) {
      final list = merged.putIfAbsent(entry.key, () => []);
      for (final address in entry.value) {
        if (!list.any((known) => known.address == address.address)) {
          list.add(address);
        }
      }
    }
    return TomNotificationRecipient(
      principal: principal,
      addresses: merged,
      locale: locale ?? other.locale,
      parameters: {...other.parameters, ...parameters},
    );
  }

  @override
  String toString() => 'TomNotificationRecipient($id)';
}

/// One occurrence of a notification: [type], what it is about ([parameters],
/// which the templates read), and any recipients named by the code that raised
/// it ([recipients]) on top of those the type's audience resolves.
class TomNotification {
  /// Identifies this occurrence. Every message it fans out to derives its id
  /// from it, so dispatching the same notification again — a retry after a
  /// crash — queues no second copy. Give an id of your own when the event has
  /// one (`taskAssigned:4711:2026-10-27T10:00`); a random one otherwise.
  final String id;

  /// What kind of notification it is.
  final TomNotificationType type;

  /// The values its templates are rendered with (`{taskTitle}`).
  final Map<String, Object?> parameters;

  /// Recipients named where it was raised, merged with the audience's.
  final List<TomNotificationRecipient> recipients;

  /// When it was raised.
  final DateTime createdAt;

  /// Raises a notification.
  TomNotification({
    String? id,
    required this.type,
    Map<String, Object?> parameters = const {},
    List<TomNotificationRecipient> recipients = const [],
    DateTime? createdAt,
  }) : id = id ?? const UuidV4().generate(),
       parameters = Map.unmodifiable(parameters),
       recipients = List.unmodifiable(recipients),
       createdAt = createdAt ?? DateTime.now().toUtc();

  @override
  String toString() => 'TomNotification(${type.name} $id)';
}
