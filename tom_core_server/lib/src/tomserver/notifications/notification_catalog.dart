/// The notification types an application declares, and for each the audience
/// that answers "who gets this".
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'notification.dart';

/// Subscription resolution: who receives a notification of one type.
///
/// It is a query over the application's own entities — the assignee of the
/// task, the members of the project, everyone who watches the invoice — and
/// so the application's to write. It answers recipients with their addresses
/// ([TomNotificationRecipient]); whether each wants the notification, and on
/// which channel, is decided afterwards from their preferences.
abstract class TomNotificationAudience {
  /// Creates an audience.
  const TomNotificationAudience();

  /// An audience answered by [resolve].
  const factory TomNotificationAudience.of(
    FutureOr<Iterable<TomNotificationRecipient>> Function(
      TomNotification notification,
    )
    resolve,
  ) = _FunctionAudience;

  /// The recipients of [notification]; a recipient answered twice is merged.
  FutureOr<Iterable<TomNotificationRecipient>> resolve(
    TomNotification notification,
  );
}

class _FunctionAudience extends TomNotificationAudience {
  final FutureOr<Iterable<TomNotificationRecipient>> Function(
    TomNotification notification,
  )
  _resolve;

  const _FunctionAudience(this._resolve);

  @override
  FutureOr<Iterable<TomNotificationRecipient>> resolve(
    TomNotification notification,
  ) => _resolve(notification);
}

/// The registered notification types, each with its audience.
///
/// Installed as a bean ([install]) so `GET /notification-preferences` can list
/// the types; the dispatcher takes it as an argument.
class TomNotificationCatalog {
  final Map<String, TomNotificationType> _types = {};
  final Map<String, TomNotificationAudience> _audiences = {};

  /// Creates an empty catalog.
  TomNotificationCatalog();

  /// The installed catalog, or `null`.
  static TomNotificationCatalog? resolve() {
    final installed = TomBean.getBeanByType(TomNotificationCatalog);
    return installed is TomNotificationCatalog ? installed : null;
  }

  /// Installs this catalog as the process-wide bean, replacing one installed
  /// before.
  void install() => TomBean.overrideWithType<TomNotificationCatalog>(this);

  /// Registers [type], with the [audience] that resolves its recipients (none:
  /// only the recipients a notification names reach it).
  ///
  /// Refuses (`notifications.type.duplicate`) a second, different type under
  /// the same name; registering the same declaration again replaces the
  /// audience.
  void register(TomNotificationType type, {TomNotificationAudience? audience}) {
    final known = _types[type.name];
    if (known != null && !identical(known, type)) {
      throw TomNotificationException(
        'notifications.type.duplicate',
        "A notification type named '${type.name}' is already registered.",
        parameters: {'type': type.name},
      );
    }
    _types[type.name] = type;
    if (audience == null) {
      _audiences.remove(type.name);
    } else {
      _audiences[type.name] = audience;
    }
  }

  /// The registered types, in registration order.
  List<TomNotificationType> get types => List.unmodifiable(_types.values);

  /// The type named [name], or `null`.
  TomNotificationType? typeNamed(String name) => _types[name];

  /// Whether [type] is the registered type of its name.
  bool isRegistered(TomNotificationType type) =>
      identical(_types[type.name], type);

  /// The audience of [type], or `null`.
  TomNotificationAudience? audienceOf(TomNotificationType type) =>
      _audiences[type.name];
}
