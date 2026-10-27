/// Per-user notification preferences: which channels a principal receives a
/// notification type on, and the quiet hours non-urgent notifications wait
/// out.
///
/// They are ordinary user preferences under the keys
/// [TomNotificationPreferenceKeys] spells, so a user's choices are written
/// through the preferences API, role and deployment defaults apply beneath
/// them (`TomPreferenceDefaults`), and there is no second store.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../messaging/message.dart';
import '../preferences/user_preferences_service.dart';
import 'notification.dart';

/// A window of the day during which non-urgent notifications are held, in
/// minutes after midnight of the principal's time zone. A window whose end
/// comes before its start runs past midnight (`22:00-07:00`); one whose start
/// equals its end is empty.
class TomQuietHours {
  /// Minutes after midnight the window opens.
  final int startMinute;

  /// Minutes after midnight the window closes.
  final int endMinute;

  /// The window from [startMinute] to [endMinute], each in `0..1439`.
  TomQuietHours(this.startMinute, this.endMinute) {
    if (startMinute < 0 ||
        startMinute >= _day ||
        endMinute < 0 ||
        endMinute >= _day) {
      throw TomNotificationException(
        'notifications.quiet_hours.invalid',
        'Quiet hours are minutes of the day, 0 to 1439.',
        parameters: {'start': startMinute, 'end': endMinute},
      );
    }
  }

  static const int _day = 24 * 60;
  static final RegExp _pattern = RegExp(
    r'^([01]\d|2[0-3]):([0-5]\d)-([01]\d|2[0-3]):([0-5]\d)$',
  );

  /// Reads `HH:MM-HH:MM`; refuses (`notifications.quiet_hours.invalid`)
  /// anything else.
  factory TomQuietHours.parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      throw TomNotificationException(
        'notifications.quiet_hours.invalid',
        "'$value' is not a quiet-hours window HH:MM-HH:MM.",
        parameters: {'value': value},
      );
    }
    int at(int hour, int minute) =>
        int.parse(match.group(hour)!) * 60 + int.parse(match.group(minute)!);
    return TomQuietHours(at(1, 2), at(3, 4));
  }

  /// Whether the window is empty.
  bool get isEmpty => startMinute == endMinute;

  /// Whether [minuteOfDay] falls inside the window.
  bool contains(int minuteOfDay) {
    if (isEmpty) return false;
    return startMinute < endMinute
        ? minuteOfDay >= startMinute && minuteOfDay < endMinute
        : minuteOfDay >= startMinute || minuteOfDay < endMinute;
  }

  /// When the window around [now] ends, read in [zone]; `null` when [now] is
  /// outside it.
  DateTime? endAfter(DateTime now, TomTimezone zone) {
    final local = wallClockOf(now, zone);
    if (!contains(local.hour * 60 + local.minute)) return null;
    return instantOf(nextWallClock(local, endMinute), zone);
  }

  /// The wall-clock reading of [instant] in [zone], as a UTC [DateTime] whose
  /// fields are the local ones.
  static DateTime wallClockOf(DateTime instant, TomTimezone zone) {
    final utc = instant.toUtc();
    return utc.add(_offsetAt(zone, utc));
  }

  /// The instant at which the clocks of [zone] read [wallClock] (a UTC
  /// [DateTime] carrying local fields) — with the offset in force then, so a
  /// time across a daylight-saving change is still its local time.
  static DateTime instantOf(DateTime wallClock, TomTimezone zone) {
    final guess = wallClock.subtract(_offsetAt(zone, wallClock));
    return wallClock.subtract(_offsetAt(zone, guess));
  }

  /// The first wall-clock reading after [local] that shows [minuteOfDay].
  static DateTime nextWallClock(DateTime local, int minuteOfDay) {
    final today = DateTime.utc(
      local.year,
      local.month,
      local.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    return today.isAfter(local) ? today : today.add(const Duration(days: 1));
  }

  static Duration _offsetAt(TomTimezone zone, DateTime instant) =>
      zone.location.timeZone(instant.millisecondsSinceEpoch).offset;

  static final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// The minute of the day `HH:MM` names, or `null` for anything else.
  static int? minuteOfDay(String value) {
    final match = _timePattern.firstMatch(value.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  /// The window as `HH:MM-HH:MM`.
  String encode() => '${_clock(startMinute)}-${_clock(endMinute)}';

  static String _clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is TomQuietHours &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);

  @override
  String toString() => 'TomQuietHours(${encode()})';
}

/// Where a recipient's channels for a type came from.
enum TomNotificationChoiceOrigin {
  /// The principal's (or a default's) choice for the type itself.
  type,

  /// The choice for the type's category.
  category,

  /// The type's declared default channels.
  defaults,
}

/// What a principal receives one notification type on, and when.
class TomNotificationChoice {
  /// The channels, always within the type's allowed channels.
  final Set<TomMessageChannel> channels;

  /// Where [channels] came from.
  final TomNotificationChoiceOrigin origin;

  /// The principal's quiet hours, or `null` for none.
  final TomQuietHours? quietHours;

  /// The zone [quietHours] and [digestMinute] are read in.
  final TomTimezone timeZone;

  /// How often the type reaches the principal.
  final TomNotificationCadence cadence;

  /// The minute of the day a daily digest goes out.
  final int digestMinute;

  /// The digest time when none is chosen: 08:00.
  static const int defaultDigestMinute = 8 * 60;

  /// Creates a choice.
  TomNotificationChoice({
    required Set<TomMessageChannel> channels,
    required this.origin,
    this.quietHours,
    TomTimezone? timeZone,
    this.cadence = TomNotificationCadence.immediate,
    this.digestMinute = defaultDigestMinute,
  }) : channels = Set.unmodifiable(channels),
       timeZone = timeZone ?? TomTimezone.utc;

  /// When the digest a notification raised at [now] joins goes out: the end of
  /// the current hour of the principal's clock, or the next digest time —
  /// moved to the end of the quiet hours when it falls inside them. `null` for
  /// [TomNotificationCadence.immediate].
  DateTime? digestAt(DateTime now) {
    final local = TomQuietHours.wallClockOf(now, timeZone);
    final DateTime due;
    switch (cadence) {
      case TomNotificationCadence.immediate:
        return null;
      case TomNotificationCadence.hourly:
        due = TomQuietHours.instantOf(
          DateTime.utc(
            local.year,
            local.month,
            local.day,
            local.hour,
          ).add(const Duration(hours: 1)),
          timeZone,
        );
      case TomNotificationCadence.daily:
        due = TomQuietHours.instantOf(
          TomQuietHours.nextWallClock(local, digestMinute),
          timeZone,
        );
    }
    return quietHours?.endAfter(due, timeZone) ?? due;
  }
}

/// Reads one principal's stored notification preference values.
///
/// The seam between the choice rules and the store:
/// [TomUserPreferencesNotificationSource] reads `TomUserPreferences`, and a
/// test or an application keeping its choices elsewhere supplies its own.
abstract class TomNotificationPreferenceSource {
  /// Creates a source.
  const TomNotificationPreferenceSource();

  /// The `String` stored for [principal] under [key] — the principal's own
  /// value, else a role or deployment default — or `null` when there is none.
  FutureOr<String?> read(TomPrincipal principal, String key);
}

/// [TomNotificationPreferenceSource] over the server's user preferences, role
/// and deployment defaults included.
class TomUserPreferencesNotificationSource
    extends TomNotificationPreferenceSource {
  final TomUserPreferences? _preferences;

  /// Reads through [preferences], else the installed `TomUserPreferences`
  /// bean.
  const TomUserPreferencesNotificationSource([TomUserPreferences? preferences])
    : _preferences = preferences;

  TomUserPreferences get _service =>
      _preferences ??
      TomUserPreferences.resolve() ??
      (throw TomNotificationException(
        'notifications.preferences.not_configured',
        'Notification preferences are read from TomUserPreferences, and none '
            'was passed or installed as a bean.',
      ));

  @override
  Future<String?> read(TomPrincipal principal, String key) =>
      _service.getFor<String>(principal, key);
}

/// The choice rules: from a principal's stored values to what a notification
/// type reaches them on.
class TomNotificationPreferences {
  /// Where the stored values come from.
  final TomNotificationPreferenceSource source;

  /// Reads the stored values from [source] (the user preferences by default).
  const TomNotificationPreferences({
    this.source = const TomUserPreferencesNotificationSource(),
  });

  /// What [principal] receives [type] on.
  ///
  /// The channels are the first that is set of: the choice for the type, the
  /// choice for its category, the type's default channels — always cut down to
  /// the channels the type allows, so a stored value naming a channel the type
  /// does not allow (or no longer allows) cannot widen it. A mandatory type
  /// whose choice leaves no channel falls back to its default channels.
  ///
  /// A stored quiet-hours value or time zone that cannot be read is treated as
  /// unset rather than failing the notification: the notification is worth
  /// more to the user than the honouring of a malformed window.
  Future<TomNotificationChoice> choiceFor(
    TomPrincipal principal,
    TomNotificationType type,
  ) async {
    var origin = TomNotificationChoiceOrigin.defaults;
    var channels = type.defaultChannels;
    final ownValue = await source.read(
      principal,
      TomNotificationPreferenceKeys.typeKey(type.name),
    );
    final categoryValue = ownValue == null && type.category != null
        ? await source.read(
            principal,
            TomNotificationPreferenceKeys.categoryKey(type.category!),
          )
        : null;
    if (ownValue != null) {
      origin = TomNotificationChoiceOrigin.type;
      channels = type.allowedOf(
        TomNotificationPreferenceKeys.decodeChannels(ownValue),
      );
    } else if (categoryValue != null) {
      origin = TomNotificationChoiceOrigin.category;
      channels = type.allowedOf(
        TomNotificationPreferenceKeys.decodeChannels(categoryValue),
      );
    }
    if (type.mandatory && channels.isEmpty) {
      channels = type.defaultChannels;
      origin = TomNotificationChoiceOrigin.defaults;
    }
    final (quietHours, timeZone) = await quietHoursFor(principal);
    return TomNotificationChoice(
      channels: channels,
      origin: origin,
      quietHours: quietHours,
      timeZone: timeZone,
      cadence: type.urgent
          ? TomNotificationCadence.immediate
          : await _cadenceFor(principal, type),
      digestMinute:
          TomQuietHours.minuteOfDay(
            await source.read(
                  principal,
                  TomNotificationPreferenceKeys.digestTimeKey,
                ) ??
                '',
          ) ??
          TomNotificationChoice.defaultDigestMinute,
    );
  }

  /// The type's own cadence, else its category's, else its default; a stored
  /// value that names no cadence counts as unset.
  Future<TomNotificationCadence> _cadenceFor(
    TomPrincipal principal,
    TomNotificationType type,
  ) async {
    final keys = [
      TomNotificationPreferenceKeys.typeCadenceKey(type.name),
      if (type.category != null)
        TomNotificationPreferenceKeys.categoryCadenceKey(type.category!),
    ];
    for (final key in keys) {
      final value = await source.read(principal, key);
      final cadence = value == null
          ? null
          : TomNotificationCadence.named(value);
      if (cadence != null) return cadence;
    }
    return type.defaultCadence;
  }

  /// [principal]'s quiet hours (`null` for none) and the zone they are read in
  /// (UTC when none is set or the stored one is unknown).
  Future<(TomQuietHours?, TomTimezone)> quietHoursFor(
    TomPrincipal principal,
  ) async => (
    _quietHours(
      await source.read(principal, TomNotificationPreferenceKeys.quietHoursKey),
    ),
    _timeZone(
          await source.read(
            principal,
            TomNotificationPreferenceKeys.timeZoneKey,
          ),
        ) ??
        TomTimezone.utc,
  );

  static TomQuietHours? _quietHours(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final window = TomQuietHours.parse(value);
      return window.isEmpty ? null : window;
    } on TomNotificationException {
      return null;
    }
  }

  static TomTimezone? _timeZone(String? value) =>
      value == null || value.trim().isEmpty
      ? null
      : TomTimezone.fromName(value.trim());

  /// Writes the caller's channels for [type]; an empty set turns it off (a
  /// mandatory type still reaches the caller on its default channels).
  ///
  /// Refuses (`notifications.preferences.channel_not_allowed`) a channel the
  /// type does not allow. Writes through [preferences] (the installed
  /// `TomUserPreferences` by default), so the caller is the principal of the
  /// request zone.
  static Future<void> setTypeChannels(
    TomNotificationType type,
    Set<TomMessageChannel> channels, {
    TomUserPreferences? preferences,
  }) async {
    final refused = channels.difference(type.allowedChannels);
    if (refused.isNotEmpty) {
      throw TomNotificationException(
        'notifications.preferences.channel_not_allowed',
        "Notification type '${type.name}' cannot go out on "
            '${refused.map((c) => c.name).join(', ')}.',
        parameters: {
          'type': type.name,
          'channels': [for (final c in refused) c.name],
        },
      );
    }
    await _service(preferences).set<String>(
      TomNotificationPreferenceKeys.typeKey(type.name),
      TomNotificationPreferenceKeys.encodeChannels(channels.map((c) => c.name)),
    );
  }

  /// Writes the caller's channels for every type of [category] without a
  /// choice of its own; each type still takes only the channels it allows.
  static Future<void> setCategoryChannels(
    String category,
    Set<TomMessageChannel> channels, {
    TomUserPreferences? preferences,
  }) => _service(preferences).set<String>(
    TomNotificationPreferenceKeys.categoryKey(category),
    TomNotificationPreferenceKeys.encodeChannels(channels.map((c) => c.name)),
  );

  /// Writes the caller's quiet hours and the zone they are read in; `null`
  /// [window] removes them.
  ///
  /// Refuses (`notifications.preferences.time_zone_unknown`) a zone that is
  /// not an IANA name.
  static Future<void> setQuietHours(
    TomQuietHours? window, {
    String? timeZone,
    TomUserPreferences? preferences,
  }) async {
    if (timeZone != null && TomTimezone.fromName(timeZone) == null) {
      throw TomNotificationException(
        'notifications.preferences.time_zone_unknown',
        "'$timeZone' is not a known time zone.",
        parameters: {'timeZone': timeZone},
      );
    }
    final service = _service(preferences);
    if (window == null) {
      await service.remove(TomNotificationPreferenceKeys.quietHoursKey);
      return;
    }
    await service.set<String>(
      TomNotificationPreferenceKeys.quietHoursKey,
      window.encode(),
    );
    if (timeZone != null) {
      await service.set<String>(
        TomNotificationPreferenceKeys.timeZoneKey,
        timeZone,
      );
    }
  }

  /// Writes the caller's cadence for [type].
  ///
  /// Refuses (`notifications.preferences.cadence_not_allowed`) a digest for an
  /// urgent type, which is always delivered at once.
  static Future<void> setTypeCadence(
    TomNotificationType type,
    TomNotificationCadence cadence, {
    TomUserPreferences? preferences,
  }) async {
    if (type.urgent && cadence != TomNotificationCadence.immediate) {
      throw TomNotificationException(
        'notifications.preferences.cadence_not_allowed',
        "Notification type '${type.name}' is urgent and is not collected into "
            'a digest.',
        parameters: {'type': type.name, 'cadence': cadence.name},
      );
    }
    await _service(preferences).set<String>(
      TomNotificationPreferenceKeys.typeCadenceKey(type.name),
      cadence.name,
    );
  }

  /// Writes the caller's cadence for every type of [category] without one of
  /// its own; an urgent type of the category stays immediate.
  static Future<void> setCategoryCadence(
    String category,
    TomNotificationCadence cadence, {
    TomUserPreferences? preferences,
  }) => _service(preferences).set<String>(
    TomNotificationPreferenceKeys.categoryCadenceKey(category),
    cadence.name,
  );

  /// Writes the time of day the caller's daily digest goes out, `HH:MM` in
  /// their time zone; refuses (`notifications.preferences.digest_time_invalid`)
  /// anything else.
  static Future<void> setDigestTime(
    String time, {
    TomUserPreferences? preferences,
  }) async {
    final minute = TomQuietHours.minuteOfDay(time);
    if (minute == null) {
      throw TomNotificationException(
        'notifications.preferences.digest_time_invalid',
        "'$time' is not a time of day HH:MM.",
        parameters: {'time': time},
      );
    }
    await _service(
      preferences,
    ).set<String>(TomNotificationPreferenceKeys.digestTimeKey, time.trim());
  }

  static TomUserPreferences _service(TomUserPreferences? preferences) =>
      preferences ??
      TomUserPreferences.resolve() ??
      (throw TomNotificationException(
        'notifications.preferences.not_configured',
        'Notification preferences are written through TomUserPreferences, and '
            'none was passed or installed as a bean.',
      ));
}
