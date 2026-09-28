// CE-NT — the layer that CHOOSES a channel.
//
// `tom_core_server`'s messaging module delivers a composed message on a named
// channel and takes the channel as already chosen. Choosing is this layer, and
// the resolution order is much clearer run than described:
//
//   1. mandatory channels first, always, in declaration order;
//   2. then the user's selection for the type, which REPLACES the defaults
//      rather than adding to them;
//   3. then an urgency ceiling per channel — a channel declaring
//      `urgencyLevels` carries only those, so a low-urgency notification is
//      filtered out even though the user asked for it.
//
// Step 2 is the one that surprises, and step 3 is the one that makes a
// user-selected channel legitimately produce nothing.
//
// Run with:
//   dart run --enable-asserts example/notification_model_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

void main() {
  requireAsserts();
  print('== CE-NT: notification catalogue ==');

  final notifications = TomNotificationCatalog(
    channels: [
      TomNotificationChannelDeclaration(
        channelId: 'push',
        displayName: 'Push',
        fallbackChannelId: 'email',
        honoursQuietHours: true,
      ),
      TomNotificationChannelDeclaration(
        channelId: 'email',
        displayName: 'E-mail',
      ),
      // An urgency ceiling: sms carries critical traffic and nothing else.
      TomNotificationChannelDeclaration(
        channelId: 'sms',
        displayName: 'SMS',
        honoursQuietHours: true,
        urgencyLevels: {TomNotificationUrgency.critical},
      ),
    ],
    types: [
      TomNotificationType(
        typeId: 'order.shipped',
        displayName: 'Order shipped',
        defaultChannelIds: ['email', 'push'],
        contentTemplateKey: 'app.notification.order.shipped',
      ),
      TomNotificationType(
        typeId: 'security.passwordReset',
        displayName: 'Password reset',
        category: TomNotificationCategory.security,
        urgency: TomNotificationUrgency.critical,
        defaultChannelIds: ['email'],
        mandatoryChannelIds: ['email'],
      ),
    ],
  );

  // With no preferences at all, the defaults stand.
  final defaults = notifications.deliveryChannelsFor('order.shipped', null);
  print('  order.shipped, no preferences  -> ${defaults.join(", ")}');
  assert(defaults.length == 2);

  // The user picks sms for this type. The selection REPLACES the defaults —
  // and sms carries critical only, while order.shipped is medium — so the
  // resolved set is empty. Nothing is delivered, and that is correct.
  final prefs = TomNotificationPreferences(
    userId: 'u-42',
    channelsByTypeId: {
      'order.shipped': ['sms'],
    },
  );
  final chosen = notifications.deliveryChannelsFor('order.shipped', prefs);
  print(
    '  order.shipped, user chose sms  -> ${chosen.isEmpty ? "(none)" : chosen.join(", ")}',
  );
  assert(chosen.isEmpty, 'replaced the defaults, then the ceiling removed sms');

  // An essential type survives a blanket opt-out: a mandatory channel makes
  // the type essential, and `silences` refuses to silence one.
  final optedOut = notifications.deliveryChannelsFor(
    'security.passwordReset',
    TomNotificationPreferences(globalOptOut: true),
  );
  print('  passwordReset, global opt-out  -> ${optedOut.join(", ")}');
  assert(optedOut.length == 1 && optedOut.first == 'email');

  // The same type is not silenced by muting it either.
  final muted = notifications.deliveryChannelsFor(
    'security.passwordReset',
    TomNotificationPreferences(mutedTypeIds: {'security.passwordReset'}),
  );
  assert(muted.length == 1, 'an essential type cannot be muted');

  // An ordinary type CAN be silenced, which is what makes the line above a
  // statement about essentialness rather than about opt-out doing nothing.
  final silenced = notifications.deliveryChannelsFor(
    'order.shipped',
    TomNotificationPreferences(globalOptOut: true),
  );
  print(
    '  order.shipped, global opt-out  -> '
    '${silenced.isEmpty ? "(none)" : silenced.join(", ")}',
  );
  assert(silenced.isEmpty);

  // The fallback chain is what a deployment consults when a channel is not
  // wired. An undeclared channel has no chain at all — not a chain of itself.
  print(
    '  fallback from push             -> '
    '${notifications.fallbackChainFrom("push").join(" -> ")}',
  );
  assert(notifications.fallbackChainFrom('push').length == 2);
  assert(notifications.fallbackChainFrom('carrier-pigeon').isEmpty);
  print('  fallback from carrier-pigeon   -> (none, undeclared)');
}
