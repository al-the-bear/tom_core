/// One user-scoped setting a CodeSpec's `@CsUserSetting` (CE-UP) is built on.
///
/// **Scope — user, and only user** (`codespecs_mapping.md` §11). A CE-UP
/// setting is keyed by the **user** and persisted **server-side**, so it is
/// re-materialised on any device that user signs into. There is no persistence
/// mode to choose: `codespecs_mapping.md` §11 splits configuration and settings
/// into four parts, one per scope key, **each single-moded — the scope key
/// alone decides where a value lives**. A value that must stay on one machine
/// is a different part, not a different mode of this one:
///
/// | Scope key | Part |
/// |-----------|------|
/// | server/system — no user, no machine | CE-CF `@CsServerConfig` |
/// | (client app, machine) — no user | CE-CC `@CsClientConfig` |
/// | (user, device) — never leaves the device | CE-DS `@CsDeviceSetting` |
/// | (user) — follows the user | **CE-UP, this class** |
///
/// **Why this is a gap.** `codespecs_mapping.md` §4.1 records the CE-UP
/// substrate as the *round-trip carrier only*: `TomGetSettingsMessage` /
/// `TomGetSettingsResult` (`tom_core_kernel`) deliver a settings bootstrap
/// payload server → client, and that transport is reused as-is. What `tom_core`
/// has nowhere is the pair this file supplies — a **typed user-settings
/// holder** naming a setting as a spec-authorable unit, and a **server-side
/// per-user persistence** seam ([TomUserSettingsStore]). The kernel carrier is
/// read-only and has no write-back path, so a user's chosen preference has
/// nothing to be stored in.
///
/// **Locus (`codespecs_mapping.md` §4.2).** A CE-UP setting spans two of the
/// three generated projects: its **shape** is declared in the client project
/// (`<app>_codespec_client`), and its **persistence** lives in the server
/// project (`<app>_codespec_server`), reached through [TomUserSettingsStore].
///
/// **Spec-authorable surface (`codespecs_mapping.md` §5.16):** the setting's
/// key, type and default. The [value] is the user's persisted choice — supplied
/// at run time, never authored.
class TomUserSettings {
  /// Stable identifier of the setting (e.g. `preferred_language`).
  String settingId;

  /// Human-readable name of the setting.
  String displayName;

  /// The user's persisted choice, or `null` when the user has set nothing.
  ///
  /// `null` means *unset*, not *set to null* — a settings model has no use for
  /// the latter, and collapsing the two keeps [effectiveValue] a single
  /// null-coalesce.
  Object? value;

  /// The value applied when the user has set nothing.
  Object? defaultValue;

  /// Creates a user-settings holder.
  TomUserSettings({
    this.settingId = '',
    this.displayName = '',
    this.value,
    this.defaultValue,
  });

  /// The value in force, applying `codespecs_mapping.md` §5.16's intra-scope
  /// precedence for CE-UP: **persisted user value → declared default**.
  Object? get effectiveValue => value ?? defaultValue;
}

/// Where a user's CE-UP settings are persisted **server-side, keyed by user**
/// (`codespecs_mapping.md` §11, §5.16).
///
/// The user key is in every method signature, because it *is* the scope: this is
/// what separates CE-UP from [TomClientConfiguration]'s store, whose interface
/// deliberately has no user parameter at all. A value written here follows the
/// user onto any device they sign into.
///
/// Deliberately the narrowest interface the holder needs — read a user's map
/// back, write it. There is no `exists`, no per-key accessor and no `clear`:
/// writing an empty map *is* clearing, so a third method would be a second way
/// to say the same thing. Two methods is also the whole cost of adapting a new
/// backend (a settings table, a document store): implement them and pass the
/// instance in.
///
/// The store is **framework-internal** (`codespecs_mapping.md` §5.16) — a spec
/// authors a setting's key, type and default, never the storage. The seam
/// exists so the generated server project has something to bind to.
abstract class TomUserSettingsStore {
  /// Allows `const` implementations.
  const TomUserSettingsStore();

  /// Reads the settings persisted for [userId].
  ///
  /// Returns an empty map for a user who has never stored a setting — absence
  /// is not an error, it is the normal state of a new account.
  Future<Map<String, Object?>> read(String userId);

  /// Replaces the persisted settings of [userId] with [values].
  ///
  /// A write must be **all-or-nothing**: a failure part-way through leaves the
  /// previously readable content intact rather than a truncated map. An empty
  /// [values] clears that user's settings.
  Future<void> write(String userId, Map<String, Object?> values);
}

/// An in-memory [TomUserSettingsStore].
///
/// The right store for tests and examples. Because it forgets on exit it is
/// *not* a fallback for a server that has no real backend wired — a store that
/// silently forgets a user's preferences is worse than a loud one.
class TomMemoryUserSettingsStore extends TomUserSettingsStore {
  /// Creates an empty store, optionally pre-seeded with [initialValues] keyed by
  /// user id.
  TomMemoryUserSettingsStore([Map<String, Map<String, Object?>>? initialValues])
      : _byUser = {
          for (final entry in (initialValues ?? const {}).entries)
            entry.key: {...entry.value},
        };

  final Map<String, Map<String, Object?>> _byUser;

  @override
  Future<Map<String, Object?>> read(String userId) async =>
      {...?_byUser[userId]};

  @override
  Future<void> write(String userId, Map<String, Object?> values) async {
    _byUser[userId] = {...values};
  }
}
