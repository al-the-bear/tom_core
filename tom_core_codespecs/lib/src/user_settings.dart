/// Where a user setting is persisted — the CE-UP `local`/`roaming` split
/// (`codespecs_mapping.md` §11).
enum TomUserSettingsPersistence {
  /// Machine-persisted: stored on the client device and **does not** follow the
  /// user to another machine (e.g. a per-device window layout). Backed by the
  /// client-only project's local store.
  local,

  /// Server-persisted: stored server-side against the user and **restored on any
  /// machine** they sign in on (e.g. preferred language). Delivered to the client
  /// via `TomGetSettingsResult` and written back through the server project. This
  /// is the default for a user setting.
  roaming,
}

/// The user-settings holder a CodeSpec's `@CsUserSetting` (CE-UP) is built on.
///
/// **Why this is a gap (csm2r7 survey `codespecs_mapping.md` §1.1b).**
/// The roaming *transport* reuses the kernel `TomGetSettingsResult` (server →
/// client settings payload) and the local reads reuse `TomProperty`, but
/// `tom_core` has no **user-settings holder** that (a) names a setting as a
/// spec-authorable unit and (b) carries the [persistence] discriminator deciding
/// whether it follows the user (`roaming`) or stays on the machine (`local`).
/// CodeSpecs needs that, so it lands here as a concrete `tom_core`-family class
/// (never an abstract `Cs*` base, §0).
///
/// A CodeSpec `@CsUserSetting` class *is a* `TomUserSettings`. A `roaming` setting
/// has both a client shape and server persistence (both generated projects, §11);
/// a `local` setting exists only in the client-only project.
class TomUserSettings {
  /// Stable identifier of the setting (e.g. `preferred_language`).
  String settingId;

  /// Human-readable name of the setting.
  String displayName;

  /// Where the setting is persisted — `roaming` (server, follows the user) or
  /// `local` (machine-bound). Defaults to `roaming`, matching
  /// `@CsUserSetting`'s default.
  TomUserSettingsPersistence persistence;

  /// The setting's current value.
  Object? value;

  /// The value applied when the user has set nothing.
  Object? defaultValue;

  /// Creates a user-settings holder.
  TomUserSettings({
    this.settingId = '',
    this.displayName = '',
    this.persistence = TomUserSettingsPersistence.roaming,
    this.value,
    this.defaultValue,
  });

  /// Whether this setting follows the user across machines.
  bool get isRoaming => persistence == TomUserSettingsPersistence.roaming;
}
