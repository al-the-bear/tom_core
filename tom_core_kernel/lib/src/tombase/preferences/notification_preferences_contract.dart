/// What a client shares with a Tom server about notification preferences: the
/// preference keys a user's notification choices are stored under, and the
/// one endpoint that lists the notification types the user may configure.
///
/// The choices are ordinary user preferences. A client writes them through the
/// preferences API (`PUT /preferences/<key>`) under the keys
/// [TomNotificationPreferenceKeys] spells, as `String` values:
///
/// ```dart
/// // email and push for task assignments, nothing for weekly digests
/// TomNotificationPreferenceKeys.typeKey('taskAssigned')  // 'email,push'
/// TomNotificationPreferenceKeys.typeKey('weeklyDigest')  // ''
/// TomNotificationPreferenceKeys.quietHoursKey            // '22:00-07:00'
/// TomNotificationPreferenceKeys.timeZoneKey              // 'Europe/Berlin'
/// // everything about tasks once a day, at 08:00
/// TomNotificationPreferenceKeys.categoryCadenceKey('tasks')  // 'daily'
/// TomNotificationPreferenceKeys.digestTimeKey            // '08:00'
/// ```
///
/// `GET /notification-preferences` answers what a settings screen needs to
/// offer them: every type, the channels it may use, and the channels in effect
/// for the caller.
library;

import '../http_connection/endpoints_apis.dart';
import '../http_connection/httpmethods.dart';
import '../security/access_controls.dart';

/// The preference keys a principal's notification choices are stored under,
/// and the encoding of their values.
///
/// A choice is looked up from the most specific key to the least: the type's
/// own key, then its category's, then the type's declared defaults. An empty
/// string is a choice — "no channel" — and differs from an absent key, which
/// defers to the next level.
abstract final class TomNotificationPreferenceKeys {
  /// The prefix of every notification preference key.
  static const String prefix = 'notifications';

  /// The key holding the channels chosen for the notification type [type].
  static String typeKey(String type) => '$prefix.type.$type';

  /// The key holding the channels chosen for every type of [category] that
  /// has no choice of its own.
  static String categoryKey(String category) => '$prefix.category.$category';

  /// The key holding the quiet hours, `HH:MM-HH:MM` in the principal's time
  /// zone; a window ending before it starts runs past midnight.
  static const String quietHoursKey = '$prefix.quietHours';

  /// The key holding the IANA time zone the quiet hours and the digest time
  /// are read in (`Europe/Berlin`); UTC when unset.
  static const String timeZoneKey = '$prefix.timeZone';

  /// The key holding how often the notification type [type] is delivered:
  /// one of [cadences] — at once, or collected into an hourly or daily digest.
  static String typeCadenceKey(String type) => '$prefix.cadence.type.$type';

  /// The key holding the cadence for every type of [category] that has no
  /// cadence of its own.
  static String categoryCadenceKey(String category) =>
      '$prefix.cadence.category.$category';

  /// The key holding the time of day a daily digest goes out, `HH:MM` in the
  /// principal's time zone; 08:00 when unset.
  static const String digestTimeKey = '$prefix.digestTime';

  /// The cadence values: `immediate`, `hourly`, `daily`.
  static const List<String> cadences = ['immediate', 'hourly', 'daily'];

  /// [channels] as a preference value: the names, comma-separated, in a
  /// stable order.
  static String encodeChannels(Iterable<String> channels) =>
      (channels.toSet().toList()..sort()).join(',');

  /// The channel names a preference value holds; the empty set for an empty
  /// value.
  static Set<String> decodeChannels(String value) => {
    for (final name in value.split(','))
      if (name.trim().isNotEmpty) name.trim(),
  };
}

/// The id of the notification-preferences API in the remote-API registry.
const String tomNotificationPreferencesApiId = 'tomNotificationPreferences';

/// The id of its one endpoint.
const String tomNotificationPreferencesListEndpointId =
    'listNotificationPreferences';

/// The notification-preferences API: one authenticated `GET` answering
///
/// ```json
/// {
///   "types": [
///     {"name": "taskAssigned", "category": "tasks",
///      "allowedChannels": ["email", "push", "sms"],
///      "channels": ["email", "push"], "origin": "type",
///      "cadence": "daily",
///      "mandatory": false, "urgent": false}
///   ],
///   "quietHours": "22:00-07:00",
///   "timeZone": "Europe/Berlin",
///   "digestTime": "08:00"
/// }
/// ```
///
/// `channels` is what the caller receives the type on now, and `origin` says
/// where that came from: `type`, `category` or `default`. `cadence` is how
/// often: at once, or in an hourly or daily digest (an urgent type is always
/// `immediate`).
final TomApi tomNotificationPreferencesApi = TomApi(
  id: tomNotificationPreferencesApiId,
  name: 'Notification Preferences API',
  description:
      'The notification types the caller may configure, with the channels in '
      'effect for the caller.',
  uri: '/notification-preferences',
  endpoints: [
    TomApiEndpoint<Map<String, Object?>, Object?>(
      id: tomNotificationPreferencesListEndpointId,
      uri: '',
      method: TomHttpMethod.get,
      description:
          'Every notification type with its allowed channels and the channels '
          'in effect for the caller, and the caller\'s quiet hours.',
      requestTypes: const [],
      access: const TomAuthenticatedAccess(),
    ),
  ],
);

/// Registers [tomNotificationPreferencesApi] in the remote-API registry;
/// idempotent.
void registerTomNotificationPreferencesApi() {
  tomRemoteApis.register(tomNotificationPreferencesApi);
}
