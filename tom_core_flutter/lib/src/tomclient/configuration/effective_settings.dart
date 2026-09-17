/// Composition of the three client value scopes — the install's configuration
/// and the two preference stores that may shadow it.
///
/// @docImport '../preferences/device_preferences.dart';
/// @docImport '../preferences/user_preferences_client.dart';
library;

import 'client_configuration.dart';

/// Reads one key from a preference store.
///
/// The shape both stores already carry: [TomDevicePreferences.get] and
/// [TomUserPreferencesClient.get] are each a [TomPreferenceLookup] as written,
/// so a caller passes the method rather than adapting it. `null` means the
/// store has never been given that key.
typedef TomPreferenceLookup = Future<T?> Function<T extends Object>(String key);

/// Resolves a [TomSetting] against the narrower client scopes that are
/// permitted to shadow it.
///
/// ## What it composes
///
/// A client value lives at one of three scopes. Widest first:
///
/// | Scope | Holder | Keyed by |
/// | ----- | ------ | -------- |
/// | install | [TomBaseClientConfiguration] | app, machine |
/// | user | [TomUserPreferencesClient] | user |
/// | user on this device | [TomDevicePreferences] | user, device |
///
/// Each holder answers for its own scope and none of them knows about the
/// others. This class is the one place the *order* between them is written:
/// the narrowest scope that holds the key wins, and the install's setting —
/// itself already resolved through the environment, the persisted override,
/// the shipped resources and the declared default — is the floor that always
/// answers.
///
/// ## Shadowing is opt-in, and declared at the wider scope
///
/// [valueOf] consults a store only when the setting's
/// [TomSetting.overridableBy] names it. A preference that happens to share a
/// key with a pinned setting is a different value that happens to be spelled
/// the same, and reading it would be a scope leak no declaration asked for.
///
/// The permission is authored once, on the setting, and never restated by the
/// preference — so there is no second statement of the relation that could
/// disagree with the first.
///
/// ## Both stores arrive as callbacks
///
/// Neither is a dependency of this class, for the reason `preferences.md`
/// gives for [TomDevicePreferences.getPreferred]: an application that has no
/// account store must not be made to carry an HTTP client, and one that has no
/// device store must not be made to carry a platform backend. An omitted
/// lookup simply never answers, so a holder built with neither resolves every
/// setting to the install's value — which is what an app with no preference
/// stores should see.
///
/// ```dart
/// final effective = TomEffectiveSettings(
///   fromDeviceStore: TomDevicePreferences.resolve()?.get,
///   fromUserStore: accountPreferences.get,
/// );
///
/// final seconds = await effective.valueOf(config.refreshSeconds);
/// ```
///
/// ## What it is not
///
/// It does not **write**. A value is written by whichever holder owns its
/// scope — `config.darkMode | true` then `config.save()`, or
/// `preferences.set(key, value)` — because "where does this change belong" is
/// the question the scopes exist to answer, and a composed setter would have
/// to guess at it.
///
/// It is not **observable**. A [TomSetting] is a `TomObject` and a preference
/// is a stored document with no change notification, so an effective value has
/// nothing to fire on when the narrower scope moves. A screen that must follow
/// one re-reads it at the points it already knows about — a sign-in, a
/// preference edit it made itself, a pull-to-refresh.
class TomEffectiveSettings {
  /// Composes the scopes reachable through the given lookups.
  ///
  /// Both are optional and independent: pass the ones this application has.
  const TomEffectiveSettings({this.fromUserStore, this.fromDeviceStore});

  /// Reads the server-stored preferences of the signed-in user, or `null` when
  /// this application has no account store.
  final TomPreferenceLookup? fromUserStore;

  /// Reads the preferences stored on this device, or `null` when this
  /// application has no device store.
  final TomPreferenceLookup? fromDeviceStore;

  /// The value of [setting] after the scopes it opens itself to have had their
  /// say.
  ///
  /// The narrowest store holding the key answers; failing that the next; and
  /// failing all of them the setting's own value, which always exists. A
  /// [TomOverridableBy.none] setting is answered from the setting alone and
  /// costs no round trip.
  ///
  /// A preference stored under the key as a different type throws
  /// `TomUserPreferenceCodecException` from the store rather than falling
  /// through to the wider scope: an unwritten preference is an ordinary state
  /// that the wider scope answers, while one written as the wrong type is a
  /// bug, and quietly answering the install's value would hide it.
  Future<T> valueOf<T extends Object>(TomSetting<T> setting) async {
    switch (setting.overridableBy) {
      case TomOverridableBy.none:
        return setting.get();
      case TomOverridableBy.device:
        final onThisDevice = await fromDeviceStore?.call<T>(setting.key);
        if (onThisDevice != null) return onThisDevice;
        continue user;
      user:
      case TomOverridableBy.user:
        final ofThisUser = await fromUserStore?.call<T>(setting.key);
        if (ofThisUser != null) return ofThisUser;
        return setting.get();
    }
  }
}
