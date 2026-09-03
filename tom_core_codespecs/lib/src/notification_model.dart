/// The spec-side notification model a CodeSpec's `@CsNotification` /
/// `@CsNotificationChannel` (CE-NT) is built on.
///
/// **Why this is a gap (`codespecs_mapping.md` §4.3, CE-NT promotion).**
/// `tom_core_server`'s `messaging` module delivers: `TomMessage`,
/// `TomMessageChannel` (an open named value), `TomMessageTransport` /
/// `TomMessageRouter`, `TomSmtpTransport` and the durable `TomMessageOutbox`.
/// Everything needed to *send* on a named channel already exists and is reused
/// directly per pillar (b) — re-implementing any of it here would be exactly
/// the mistake that pillar forbids.
///
/// What the transport deliberately has no home for is the layer **above** it:
/// which notification *types* the system has, which channels each goes out on,
/// and how a user's preferences narrow that set. The transport takes an
/// already-composed message and a channel that has already been chosen; the
/// choosing is what a specification authors, in `NotificationModel` (`NM`) with
/// its `NotificationChannelEntry` / `NotificationTypeEntry` /
/// `UserNotificationPreferences` subsections.
///
/// So the model lands here as concrete `tom_core`-family classes — never an
/// abstract `Cs*` base (the framework carries annotations only).
///
/// CE-NT is a **shared** part for these declarations (the client renders the
/// preference UI against the same type catalogue the server dispatches from)
/// and a **server** part for delivery, which is `tom_core_server` messaging.
library;

/// What a notification is *for* — the closed catalogue authored in
/// `NotificationTypeEntry.category`.
///
/// The distinction is not cosmetic: it decides whether a user may switch the
/// notification off. [security] and [transactional] messages are consequences
/// of something the user did or something they must know about;
/// [marketing] is the category consent regimes actually regulate.
enum TomNotificationCategory {
  /// A direct consequence of a user action (order confirmation, receipt).
  transactional,

  /// Promotional content. The only category a blanket opt-out may silence
  /// entirely.
  marketing,

  /// Operational messages about the system itself (maintenance, quota).
  system,

  /// Security-relevant events (password reset, new-device sign-in).
  security,
}

/// How urgent a notification is — the closed catalogue authored in
/// `NotificationTypeEntry.urgency`.
///
/// Ordered least to most urgent so [TomNotificationUrgency.index] comparisons
/// are meaningful; [TomNotificationChannelDeclaration.carries] relies on it.
enum TomNotificationUrgency {
  /// Can wait indefinitely; a digest is appropriate.
  low,

  /// The default — delivered promptly but not interrupting.
  medium,

  /// Should reach the user the same day.
  high,

  /// Must interrupt. A channel that cannot interrupt should not carry it.
  critical,
}

/// A declared delivery channel — the spec-side counterpart of
/// `NotificationChannelEntry` (`NTFCH`).
///
/// [channelId] is the name of a `TomMessageChannel`, so the declaration and the
/// transport agree on one string. Everything else here is policy the transport
/// has no opinion about: which urgencies the channel is allowed to carry,
/// whether it respects quiet hours, and where traffic goes when the channel is
/// not available in a deployment.
class TomNotificationChannelDeclaration {
  /// Stable identifier, matching the `TomMessageChannel` name it delivers on.
  String channelId;

  /// Human-readable name of the channel.
  String displayName;

  /// The channel to use when this one is unavailable in a deployment.
  ///
  /// A *specification* fallback, distinct from transport retry: the router
  /// fails an unrouted channel permanently rather than guessing a substitute,
  /// because guessing is a policy decision and policy is authored here.
  String? fallbackChannelId;

  /// Whether delivery on this channel is suppressed during a user's quiet
  /// hours.
  ///
  /// Interruptive channels (push, SMS) normally set this; a mailbox the user
  /// opens on their own schedule normally does not.
  bool honoursQuietHours;

  /// The urgencies this channel is allowed to carry.
  ///
  /// An **empty set means every urgency** — the common case is a channel with
  /// no restriction, and making that the default keeps urgency lists out of
  /// specs that do not need them.
  Set<TomNotificationUrgency> urgencyLevels;

  /// Creates a channel declaration.
  TomNotificationChannelDeclaration({
    this.channelId = '',
    this.displayName = '',
    this.fallbackChannelId,
    this.honoursQuietHours = false,
    Set<TomNotificationUrgency>? urgencyLevels,
  }) : urgencyLevels = urgencyLevels ?? <TomNotificationUrgency>{};

  /// Whether this channel may carry a notification of [urgency].
  bool carries(TomNotificationUrgency urgency) =>
      urgencyLevels.isEmpty || urgencyLevels.contains(urgency);
}

/// A declared notification type — the spec-side counterpart of
/// `NotificationTypeEntry` (`NTFTY`).
///
/// The type is the unit a user has an opinion about ("stop emailing me about
/// shipping updates"), which is why the preference resolution in
/// [channelsFor] hangs here rather than on the preferences: the constraints
/// that a preference may not override are properties of the *type*.
class TomNotificationType {
  /// Stable identifier of the notification type, unique within the system.
  String typeId;

  /// Human-readable name ("Order Confirmation", "Password Reset").
  String displayName;

  /// What the notification is for; see [TomNotificationCategory].
  TomNotificationCategory category;

  /// How urgent the notification is.
  TomNotificationUrgency urgency;

  /// Channel ids used when the user has expressed no preference.
  List<String> defaultChannelIds;

  /// Channel ids that no preference can remove.
  ///
  /// This is the compliance surface: a security notification whose delivery a
  /// user could silence is not a security notification.
  List<String> mandatoryChannelIds;

  /// Whether the user may change the channels for this type at all.
  ///
  /// When `false`, preferences are ignored outright — which is stronger than
  /// listing every channel as mandatory, and says so in one field.
  bool userConfigurable;

  /// The system event that emits this notification, if one is named.
  String? triggerEvent;

  /// The CE-TX message key naming the body template.
  ///
  /// A key rather than the text, so the copy stays in the message-key registry
  /// with every other translatable string.
  String? contentTemplateKey;

  /// Whether the template is translated.
  bool localized;

  /// Creates a notification-type declaration.
  TomNotificationType({
    this.typeId = '',
    this.displayName = '',
    this.category = TomNotificationCategory.transactional,
    this.urgency = TomNotificationUrgency.medium,
    List<String>? defaultChannelIds,
    List<String>? mandatoryChannelIds,
    this.userConfigurable = true,
    this.triggerEvent,
    this.contentTemplateKey,
    this.localized = false,
  }) : defaultChannelIds = defaultChannelIds ?? <String>[],
       mandatoryChannelIds = mandatoryChannelIds ?? <String>[];

  /// Whether this type survives a blanket opt-out.
  ///
  /// `globalOptOut` in the SOM is scoped to "all **non-essential**
  /// notifications", and this is where "essential" is decided: a type the user
  /// cannot configure, or one with a mandatory channel, is essential.
  bool get isEssential => !userConfigurable || mandatoryChannelIds.isNotEmpty;

  /// The channel ids this type is delivered on for a user holding
  /// [preferences] (`null` for a user who has expressed none).
  ///
  /// The rules, in the order they apply — mandatory first, because every later
  /// rule is a narrowing and the mandatory set must survive all of them:
  ///
  /// 1. [mandatoryChannelIds] are always included.
  /// 2. If [userConfigurable] is `false`, preferences are ignored: the result
  ///    is the declared defaults plus the mandatory channels.
  /// 3. A global opt-out or an individual mute silences the type outright.
  ///    Only a *non-essential* type can be silenced ([isEssential]), and such
  ///    a type has no mandatory channels by definition, so this leaves
  ///    nothing — an essential type is unaffected and keeps its full set.
  /// 4. Otherwise the user's channel selection for this type replaces the
  ///    defaults; with no selection recorded, the defaults stand.
  ///
  /// Order is preserved and duplicates are dropped, so the result is usable
  /// directly as a delivery order.
  List<String> channelsFor(TomNotificationPreferences? preferences) {
    if (preferences == null || !userConfigurable) {
      return _ordered(mandatoryChannelIds, defaultChannelIds);
    }
    if (preferences.silences(this)) {
      return _ordered(mandatoryChannelIds, const []);
    }
    final chosen = preferences.channelsByTypeId[typeId] ?? defaultChannelIds;
    return _ordered(mandatoryChannelIds, chosen);
  }

  /// [mandatory] followed by the entries of [optional] not already present.
  static List<String> _ordered(List<String> mandatory, List<String> optional) {
    final result = <String>[];
    final seen = <String>{};
    for (final id in [...mandatory, ...optional]) {
      if (seen.add(id)) result.add(id);
    }
    return result;
  }
}

/// A user's notification preferences — the spec-side counterpart of
/// `UserNotificationPreferences` (`UNP`).
///
/// Holds only what the user chose. What those choices are *allowed* to do is
/// [TomNotificationType]'s to decide, so a preference object can never be
/// constructed into a state that silences something it must not.
class TomNotificationPreferences {
  /// The user these preferences belong to.
  String? userId;

  /// Whether the user has opted out of all non-essential notifications.
  ///
  /// "Non-essential" is [TomNotificationType.isEssential], not a second list
  /// kept here — one definition, on the type that owns it.
  bool globalOptOut;

  /// Type ids the user has muted individually.
  Set<String> mutedTypeIds;

  /// The channels the user chose, per type id.
  ///
  /// A type absent from this map has no recorded preference and falls back to
  /// its declared defaults — which is different from a type mapped to an empty
  /// list, meaning the user actively chose no optional channel.
  Map<String, List<String>> channelsByTypeId;

  /// Creates a preference set.
  TomNotificationPreferences({
    this.userId,
    this.globalOptOut = false,
    Set<String>? mutedTypeIds,
    Map<String, List<String>>? channelsByTypeId,
  }) : mutedTypeIds = mutedTypeIds ?? <String>{},
       channelsByTypeId = channelsByTypeId ?? <String, List<String>>{};

  /// Whether these preferences silence [type]'s optional channels.
  ///
  /// An essential type is never silenced, however the flags are set — the
  /// check is here so no caller has to remember to combine the two.
  bool silences(TomNotificationType type) {
    if (type.isEssential) return false;
    return globalOptOut || mutedTypeIds.contains(type.typeId);
  }
}

/// The declared notification catalogue: every channel and every type the
/// system has.
///
/// Exists as a class rather than two lists because the useful questions need
/// both halves at once — resolving a type's channels to their declarations,
/// and walking a fallback chain without looping.
class TomNotificationCatalog {
  /// The declared channels, by [TomNotificationChannelDeclaration.channelId].
  final Map<String, TomNotificationChannelDeclaration> channels;

  /// The declared types, by [TomNotificationType.typeId].
  final Map<String, TomNotificationType> types;

  /// Creates a catalogue from the declared [channels] and [types].
  TomNotificationCatalog({
    List<TomNotificationChannelDeclaration>? channels,
    List<TomNotificationType>? types,
  }) : channels = {
         for (final channel in channels ?? const []) channel.channelId: channel,
       },
       types = {for (final type in types ?? const []) type.typeId: type};

  /// The fallback chain starting at [channelId], nearest first.
  ///
  /// The chain **includes** [channelId] itself and stops at the first channel
  /// already visited, so a declaration cycle (a falls back to b, b back to a)
  /// terminates instead of hanging. An unknown id yields an empty chain rather
  /// than throwing: a dangling fallback is a specification defect for the
  /// validator to report, not a crash at delivery time.
  List<String> fallbackChainFrom(String channelId) {
    final chain = <String>[];
    final seen = <String>{};
    var current = channelId;
    while (seen.add(current)) {
      final declaration = channels[current];
      if (declaration == null) break;
      chain.add(current);
      final next = declaration.fallbackChannelId;
      if (next == null) break;
      current = next;
    }
    return chain;
  }

  /// The channels [typeId] is delivered on for [preferences], restricted to
  /// channels that are declared and that [carry][TomNotificationChannelDeclaration.carries]
  /// the type's urgency.
  ///
  /// This is the whole CE-NT resolution in one call: type constraints, user
  /// preferences, and the channel's own urgency ceiling. An unknown type id
  /// yields an empty list.
  List<String> deliveryChannelsFor(
    String typeId,
    TomNotificationPreferences? preferences,
  ) {
    final type = types[typeId];
    if (type == null) return const [];
    return type
        .channelsFor(preferences)
        .where((id) => channels[id]?.carries(type.urgency) ?? false)
        .toList();
  }
}
