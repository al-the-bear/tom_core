/// `GET /notification-preferences`: what a settings screen offers a user —
/// every registered notification type with the channels it may use and the
/// channels in effect for the caller, and the caller's quiet hours.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import 'notification.dart';
import 'notification_catalog.dart';
import 'notification_dispatcher.dart';
import 'notification_preferences.dart';

/// The implementation of `tomNotificationPreferencesApi`.
///
/// Reads the installed [TomNotificationCatalog] (no catalog: no types) and the
/// installed dispatcher's [TomNotificationPreferences] (none: the user
/// preferences). The choices themselves are written through the preferences
/// API under the keys [TomNotificationPreferenceKeys] spells.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: tomNotificationPreferencesApiId)
class TomNotificationPreferencesServer {
  /// Const constructor: the endpoint keeps no state of its own.
  const TomNotificationPreferencesServer();

  /// The caller's notification preferences.
  @TomApiEndpointImplementation(
    apiId: tomNotificationPreferencesApiId,
    endpointId: tomNotificationPreferencesListEndpointId,
  )
  Future<Map<String, Object?>> listNotificationPreferences() async {
    final principal = getFromCurrentZone<TomPrincipal>();
    if (principal == null) {
      throw TomNotificationException(
        'notifications.preferences.no_principal',
        'Notification preferences are read for an authenticated caller.',
      );
    }
    return describe(
      principal,
      TomNotificationCatalog.resolve() ?? TomNotificationCatalog(),
      TomNotificationDispatcher.resolve()?.preferences ??
          const TomNotificationPreferences(),
    );
  }

  /// The answer for [principal]: what the endpoint serves, for a caller that
  /// has the catalog and the preferences at hand.
  static Future<Map<String, Object?>> describe(
    TomPrincipal principal,
    TomNotificationCatalog catalog,
    TomNotificationPreferences preferences,
  ) async {
    final types = <Map<String, Object?>>[];
    for (final type in catalog.types) {
      final choice = await preferences.choiceFor(principal, type);
      types.add({
        'name': type.name,
        'category': type.category,
        'allowedChannels': _names(type.allowedChannels.map((c) => c.name)),
        'channels': _names(choice.channels.map((c) => c.name)),
        'origin': switch (choice.origin) {
          TomNotificationChoiceOrigin.type => 'type',
          TomNotificationChoiceOrigin.category => 'category',
          TomNotificationChoiceOrigin.defaults => 'default',
        },
        'cadence': choice.cadence.name,
        'mandatory': type.mandatory,
        'urgent': type.urgent,
      });
    }
    final digestTime = await preferences.source.read(
      principal,
      TomNotificationPreferenceKeys.digestTimeKey,
    );
    final (window, zone) = await preferences.quietHoursFor(principal);
    return {
      'types': types,
      'quietHours': window?.encode(),
      'timeZone': zone == TomTimezone.utc ? null : zone.timezone,
      'digestTime': TomQuietHours.minuteOfDay(digestTime ?? '') == null
          ? '08:00'
          : digestTime!.trim(),
    };
  }

  static List<String> _names(Iterable<String> names) => names.toList()..sort();
}
