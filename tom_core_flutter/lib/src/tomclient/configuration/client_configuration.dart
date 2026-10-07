/// The machine-scoped settings holder of a client app, its observable settings
/// and the resolution order behind them.
///
/// @docImport 'effective_settings.dart';
/// @docImport '../preferences/device_preferences.dart';
/// @docImport '../preferences/user_preferences_client.dart';
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'client_configuration_store.dart';
import 'environment_reader.dart';

/// Where a setting's [TomSetting.envAlias] is looked up.
///
/// A seam, not a test hook — though it is both. `dart:io`'s process environment
/// is the right source on a desktop install and is what [reader] starts as, and
/// it is empty or absent everywhere else: a browser has none, and a mobile app
/// is launched by the OS rather than by a shell. Those platforms have their own
/// answer to "what did the operator configure" — a `--dart-define` baked at
/// build time, a value fetched at startup, an MDM-delivered payload — and only
/// the app knows which. So the framework reads through one function the app can
/// replace, rather than picking one and calling it *the* environment.
///
/// ```dart
/// TomClientEnvironment.reader = (name) => myLaunchArguments[name];
/// ```
///
/// Replace it **before** the holder is constructed: settings resolve their
/// environment value at declaration, which happens in the constructor.
abstract class TomClientEnvironment {
  /// Reads [name], or answers `null` when it is not set.
  ///
  /// Defaults to the process environment where there is one and to a function
  /// answering `null` where there is not.
  static String? Function(String name) reader = readPlatformEnvironment;

  /// Restores the platform default, undoing an assignment to [reader].
  static void useDefaultReader() => reader = readPlatformEnvironment;
}

/// Which narrower client scope, if any, may shadow a [TomSetting].
///
/// A client value lives at one of three scopes, from widest to narrowest: the
/// **install** (this app on this machine — a [TomSetting]), the **user** (it
/// follows the account onto any device — a server-stored preference), and the
/// **user on this device** (a device-stored preference). Shadowing is **opt-in
/// and declared at the wider scope**: an install setting is scope-pinned unless
/// it says otherwise, so a narrower store that happens to hold the same key
/// cannot silently take a value over.
///
/// The value names the **narrowest** scope permitted, and every scope between
/// the setting and that one is permitted too — so [device] opens [user] as
/// well. [TomEffectiveSettings] is what applies the declaration.
///
/// [none] is the arm every security and infrastructure setting keeps, and it is
/// the **default** on the declaration methods. That is not the fail-safe rule
/// weakened: `none` *is* the closed arm, so a setting whose author said nothing
/// about shadowing is pinned, and opening one is the deliberate act.
enum TomOverridableBy {
  /// Scope-pinned: neither preference store may shadow this setting.
  none,

  /// A server-stored user preference under the same key may shadow it.
  user,

  /// A device-stored preference may shadow it — and so may a user one, which
  /// lies between the two.
  device,
}

/// One observable, addressable client setting.
///
/// A [TomSetting] is a [TomObject] — so everything that already works on an
/// observable value works on a setting unchanged: the `~`/`|`/`<<`/`call()`
/// operators, `addObserver`, and `TomObservingWidget`. What it adds is the two
/// pieces of identity a *setting* has and a plain observable value does not:
///
/// - [key] — the dotted configuration key. This, not the Dart field name, is
///   the setting's identity: it is what the shipped config resources are keyed
///   by and what the override store persists. Two builds may name the field
///   differently; the key is the contract.
/// - [baseline] — the value this setting has **when the install has not
///   overridden it**: the shipped config-resources value if the key is present
///   there, otherwise [declaredDefault].
///
/// [isOverridden] is therefore simply "current value differs from baseline",
/// and that is exactly the set of values
/// [TomBaseClientConfiguration.save] persists. Nothing else needs to track
/// dirtiness.
class TomSetting<T> extends TomObject<T> {
  TomSetting._(
    this.key,
    this.declaredDefault,
    this.baseline,
    this.envAlias,
    this.isFromEnvironment,
    this.overridableBy,
  ) : super(baseline);

  /// The dotted configuration key — the setting's stable identity.
  final String key;

  /// The default written in code at the declaration site.
  ///
  /// Only the fallback: a value present in the shipped config resources wins
  /// over it (see [baseline]).
  final T declaredDefault;

  /// The value this setting takes when the install has not overridden it.
  ///
  /// Resolved once, at declaration time, from the config resources with
  /// [declaredDefault] as the fallback. It deliberately does **not** track
  /// later mutations of the config provider: a setting whose baseline could
  /// shift underneath a running app would make [isOverridden] — and therefore
  /// what gets persisted — depend on when you asked.
  final T baseline;

  /// The environment variable this setting may also be read from, verbatim, or
  /// `null` when it is not declared with one.
  ///
  /// Looked up through [TomClientEnvironment.reader] at declaration time.
  final String? envAlias;

  /// Whether [TomClientEnvironment] supplied this setting's value.
  ///
  /// An environment-configured setting sits **above** the install's override:
  /// [TomBaseClientConfiguration.load] does not adopt a stored value for it,
  /// [TomBaseClientConfiguration.save] never writes it, and [reset] restores
  /// the environment's value rather than the [baseline]. The operator has taken
  /// the setting out of the install's hands.
  ///
  /// It is not enforced against `set`, because a [TomSetting] is a
  /// [TomObject] and taking its setter away would take the observable with it.
  /// An in-memory change simply does not survive: nothing persists it and
  /// [reset] and a reload put the operator's value back. A settings screen
  /// reads this to disable the field, which is what this member is for.
  final bool isFromEnvironment;

  /// Which narrower client scope may shadow this setting, if any.
  ///
  /// Declared here, at the wider scope, and applied by
  /// [TomEffectiveSettings.valueOf]. It does not change what [get] answers:
  /// this holder stays synchronous and login-free, and a preference store is
  /// neither. What it changes is what an *effective* read returns once a store
  /// is in the picture.
  ///
  /// A setting that opens itself carries a key both preference stores accept —
  /// the declaration validates it against [TomUserPreferenceKeys], because a
  /// key the stores would refuse could never be shadowed and the declaration
  /// would be a promise nothing can keep.
  final TomOverridableBy overridableBy;

  /// Whether the **install** has changed this setting away from its [baseline].
  ///
  /// Always `false` for an [isFromEnvironment] setting: an operator's variable
  /// is not the install's override, and reporting it as one would have [save]
  /// bake the environment's value into the store — where it would outlive the
  /// variable being unset.
  bool get isOverridden => !isFromEnvironment && get() != baseline;

  /// Restores the value this setting has with no install override.
  ///
  /// The [baseline] normally; the **environment's** value when
  /// [isFromEnvironment], because that layer sits above the override and
  /// resetting to the baseline would drop the operator's configuration rather
  /// than the install's.
  ///
  /// Notifies observers when the value actually changes, like any other set.
  void reset() => set(_environmentValue ?? baseline);

  /// The coerced environment value, held so [reset] can restore it.
  T? _environmentValue;

  /// Whether [raw] reads as this setting's [baseline].
  ///
  /// The store is loosely typed — a `3` may arrive as `'3'` — so the comparison
  /// coerces first. Used by [TomBaseClientConfiguration.hasUnsavedChanges] to
  /// recognise a persisted entry that is not an override: [save] does not write
  /// one and [isOverridden] does not report one, so a holder that loaded one
  /// and was not touched has nothing unsaved.
  ///
  /// A value that will not coerce cannot be the baseline, but it also cannot
  /// reach here: [TomBaseClientConfiguration.load] throws on it first.
  bool _readsAsBaseline(Object? raw) {
    try {
      return coerceSettingValue<T>(key, raw) == baseline;
    } on TomClientConfigurationException {
      return false;
    }
  }

  /// Whether [raw] reads as this setting's current value, coercing first as
  /// [_readsAsBaseline] does.
  bool _equalsRaw(Object? raw) {
    try {
      return coerceSettingValue<T>(key, raw) == get();
    } on TomClientConfigurationException {
      return false;
    }
  }

  /// Applies a raw (store- or config-shaped) value, coercing it to [T].
  ///
  /// Throws [TomClientConfigurationException]
  /// `client_configuration.value.type_mismatch` when [raw] cannot be read as a
  /// [T] — see [coerceSettingValue].
  void applyRaw(Object? raw) => set(coerceSettingValue<T>(key, raw));

  @override
  String toString() => '$key=${get()}${isOverridden ? ' (overridden)' : ''}';
}

/// Reads [raw] as a [T], or throws.
///
/// Both external sources are loosely typed — a JSON store round-trips
/// `int`/`double`/`bool`/`String`, and a YAML config resource may well spell a
/// double as `30` or a port as `"8080"`. Rejecting those outright would make
/// perfectly reasonable config files fail, so this accepts the widenings that
/// have exactly one sensible reading:
///
/// - the exact type, unchanged;
/// - `int` → `double` (`30` reads as `30.0`);
/// - `String` → `int` / `double` / `bool`, when it parses.
///
/// Anything else throws
/// `client_configuration.value.type_mismatch` naming the key — a silent
/// fallback to the default would hide a typo in a config file behind behaviour
/// that merely looks like "the default was used".
///
/// Note there is deliberately **no** `Object → String` leg: accepting anything
/// via `toString()` would make a mis-typed key impossible to detect.
T coerceSettingValue<T>(String key, Object? raw) {
  if (raw is T) return raw;
  if (raw is int && T == double) return raw.toDouble() as T;
  if (raw is String) {
    if (T == int) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed as T;
    } else if (T == double) {
      final parsed = double.tryParse(raw);
      if (parsed != null) return parsed as T;
    } else if (T == bool) {
      if (raw == 'true') return true as T;
      if (raw == 'false') return false as T;
    }
  }
  throw TomClientConfigurationException(
    'client_configuration.value.type_mismatch',
    "Configuration key '$key' holds a value of type "
        '${raw.runtimeType} which cannot be read as $T.',
    parameters: {
      'key': key,
      'expectedType': '$T',
      'actualType': '${raw.runtimeType}',
    },
  );
}

/// Base class for a client app's **machine-scoped** configuration holder.
///
/// Named for symmetry with `TomBaseServerConfiguration` (`tom_core_server`),
/// and the same idea one scope down: a single object that owns every
/// configuration value of one tier, so the values are addressable as a set
/// rather than scattered across whatever module first needed them.
///
/// ## Scope — (client app, machine), and nothing else
///
/// A [TomBaseClientConfiguration] holds settings of **this install of this app
/// on this machine**: the server URL to talk to, a log level, a polling
/// interval, whether the debug overlay is on. There is no user parameter in
/// this class, in the store interface, or in the persisted format — by design.
/// A value that varies per *user* belongs in one of the two preference holders
/// this package also ships, which have a different lifecycle (they follow the
/// account or the device, and the account one needs a login before it can be
/// read): [TomUserPreferencesClient] for a value that follows the user onto
/// every device, [TomDevicePreferences] for one that stays on this machine. A
/// value that configures the *server* belongs in `TomBaseServerConfiguration`.
/// Adding any of them here turns the holder into a junk drawer and quietly
/// breaks the guarantee that reading a client setting never needs a session.
///
/// Those three scopes are related rather than merely adjacent: a setting
/// declared [TomOverridableBy.user] or [TomOverridableBy.device] may be
/// shadowed by a preference of the same key, and [TomEffectiveSettings]
/// resolves the chain.
///
/// Per-field *validation* is likewise not this class's job, and nothing else in
/// the module does it either. The **type** is checked — [coerceSettingValue]
/// throws `client_configuration.value.type_mismatch` on a raw value that cannot
/// be read as the declared type — but the **value** never is: a
/// `TomSetting<int>` stores and serves a refresh interval of `-1`. There is no
/// hook to add a check either, because [TomSetting]'s constructor is private and
/// settings are created only by the `*Setting` methods below. Range, format and
/// enum constraints are therefore the **caller's**, applied after [load] or at
/// the point of use.
///
/// ## Resolution order
///
/// A setting's value is, highest precedence first:
///
/// 0. the **environment**, for a setting declared with an
///    [TomSetting.envAlias] that [TomClientEnvironment] reports set;
/// 1. the **persisted override** — what this install last saved;
/// 2. the **shipped config-resources value** for the key
///    ([TomConfigResourceProvider]);
/// 3. the **declared default** at the declaration site.
///
/// Only layer 1 is persisted. A key the install never changed is re-resolved
/// from layers 2–3 at every start, so shipping a new default in an app update
/// actually reaches installs that never touched that key. Persisting the full
/// value set instead would freeze the shipped defaults at the moment of the
/// first save. Layer 0 is not persisted either, for the opposite reason: it is
/// the operator's value, not the install's, and baking it into the store would
/// outlive the variable being unset.
///
/// All four layers produce **this install's** value. A value belonging to a
/// narrower scope — the user, or the user on this device — lives in a
/// preference store and may shadow the whole stack, but only for a setting
/// whose declaration opens it: see [TomOverridableBy] and
/// [TomEffectiveSettings].
///
/// ## Lifecycle
///
/// ```dart
/// class AppConfiguration extends TomBaseClientConfiguration {
///   AppConfiguration({super.store});
///
///   late final TomSetting<String> serverUrl;
///   late final TomSetting<int> refreshSeconds;
///   late final TomSetting<bool> darkMode;
///
///   @override
///   void declareSettings() {
///     serverUrl = stringSetting('client.server.url', 'https://api.example.com');
///     refreshSeconds = intSetting('client.refresh.seconds', 60);
///     darkMode = boolSetting('client.ui.darkMode', false);
///   }
/// }
///
/// final config = AppConfiguration(store: myStore);
/// await config.load();          // adopt this install's persisted overrides
/// config.darkMode | true;       // per-field observers fire; so do holder observers
/// await config.save();          // write what changed; adopt the rest
/// ```
///
/// [declareSettings] is called from the constructor, mirroring
/// `TomClass.prepareForSelfObservation`. It exists because Dart field
/// initialisers cannot call instance methods, so `stringSetting(...)` cannot
/// appear in a field initialiser — and because it makes the declaration set
/// **complete by the end of construction**, which is what lets [settings],
/// [save] and [resetAll] be exhaustive rather than "exhaustive so far".
///
/// It also fixes the construction order: every baseline is resolved against
/// [TomConfigResourceProvider] before the constructor returns, so the provider
/// must already be installed. Building the holder first throws
/// `resources.config_provider.not_installed` rather than serving declared
/// defaults that look configured — an application with no configuration bundle
/// installs an empty provider rather than none.
///
/// ## Observation
///
/// Both granularities are available and both are live at once:
///
/// - **per field** — observe the [TomSetting]; it is a [TomObject], so a
///   `TomObservingWidget` bound to it rebuilds on that one setting;
/// - **whole holder** — observe the holder; it observes each of its settings
///   and re-emits, so a single observer sees every change.
///
/// ## Saving is explicit
///
/// There is no autosave. Persisting is asynchronous, and a setter that
/// silently starts an unawaited write gives the caller no way to know whether
/// it landed, no way to handle its failure, and a fresh write per keystroke
/// when a settings screen is bound field-by-field. Call [save] when the
/// install's edit is complete.
abstract class TomBaseClientConfiguration extends TomObservable
    implements TomObserver<TomObservable> {
  /// Creates the holder and declares its settings.
  ///
  /// [store] may be omitted when it is not available yet (a platform store
  /// often needs an async path lookup first) and supplied later via [store];
  /// [load] and [save] throw `client_configuration.store.not_configured`
  /// until it is.
  TomBaseClientConfiguration({TomClientConfigurationStore? store})
    : _store = store {
    declareSettings();
  }

  TomClientConfigurationStore? _store;

  final Map<String, TomSetting> _settings = {};

  /// The override map as last read from — or last written to — [_store].
  ///
  /// Kept so that a setting declared *after* [load] still picks up its
  /// persisted override. It is a snapshot of **[_store] specifically**, so the
  /// [store] setter discards it: a snapshot taken from one store says nothing
  /// about another, and applying it to a setting would hand this install a
  /// value belonging to a location it has been moved away from.
  ///
  /// It is also what [save] measures "changed" against: a declared setting
  /// whose override differs from this snapshot is written, and every other key
  /// is taken from the store as it is at the moment of the write.
  Map<String, Object?> _persisted = {};

  /// Declares every setting of this holder.
  ///
  /// Called once, from the constructor. Implementations assign their fields
  /// using [stringSetting] / [intSetting] / [doubleSetting] / [boolSetting].
  void declareSettings();

  /// Where overrides are persisted. `null` until one is wired.
  TomClientConfigurationStore? get store => _store;

  /// Points the holder at [value], discarding any snapshot of the old store.
  ///
  /// [_persisted] describes the store it was read from, so it does not survive
  /// a change of store. Re-assigning the *same* store is a no-op, leaving a
  /// snapshot taken by an earlier [load] intact.
  ///
  /// The settings themselves keep their current values: a swap is not a load,
  /// and silently resetting an install's in-flight edits would be a surprise.
  /// Call [load] to adopt the new store's overrides.
  set store(TomClientConfigurationStore? value) {
    if (identical(_store, value)) return;
    _store = value;
    _persisted = {};
  }

  /// Every declared setting, keyed by its dotted configuration key.
  Map<String, TomSetting> get settings => Map.unmodifiable(_settings);

  /// The setting declared under [key], or `null` if this build declares none.
  TomSetting? settingFor(String key) => _settings[key];

  /// Whether any setting currently differs from its baseline.
  ///
  /// **Not a dirty flag.** "Differs from baseline" is a fact about the
  /// *install*, not about this session: a setting `load` adopted from the store
  /// is already overridden with nothing unsaved, so a screen guarding its
  /// dismiss with `if (hasOverrides) warn()` warns every time on a holder that
  /// was loaded and never touched. The question a settings screen is asking is
  /// [hasUnsavedChanges].
  bool get hasOverrides => _settings.values.any((s) => s.isOverridden);

  /// Whether [save] would write something other than what the store last held.
  ///
  /// The dirty flag: `true` exactly when this holder's overrides differ from
  /// the snapshot taken by the last [load] or [save] — a value changed, an
  /// override added, or an override dropped, since a *removal* is unsaved work
  /// too. Contrast [hasOverrides], which compares against the baseline and so
  /// answers a question about the install rather than about this session.
  ///
  /// Reads no store. It is meant to be asked during a build or a dismiss guard,
  /// where an `await` is not available and a round trip would be wrong anyway;
  /// the comparison is against the holder's own snapshot. It also changes only
  /// when a setting changes, so a widget observing the holder re-reads it at
  /// exactly the right moments.
  ///
  /// Keys in the store this build does not declare are never unsaved: [save]
  /// carries them forward untouched, so nothing here can make them differ.
  ///
  /// With no store wired there is no snapshot, so any override reads as
  /// unsaved. That is the honest answer — the changes are not persisted and
  /// there is nowhere to persist them — and it is a getter rather than a throw
  /// because a dismiss guard has to be answerable.
  bool get hasUnsavedChanges {
    final live = _declaredOverrides;
    var persisted = 0;
    for (final entry in _persisted.entries) {
      final setting = _settings[entry.key];
      if (setting == null) continue;
      // A persisted value that reads as the baseline is not an override: [save]
      // does not write it and [isOverridden] does not report it. Counting it
      // would report a freshly loaded, untouched holder as dirty — the warning
      // this getter exists to stop [hasOverrides] producing, reappearing for
      // one input. That such an entry is nevertheless *dropped* by the next
      // save is the documented consequence of storing overrides only; see
      // [save].
      if (setting._readsAsBaseline(entry.value)) continue;
      persisted++;
      if (!live.containsKey(entry.key)) return true;
      if (live[entry.key] != entry.value) return true;
    }
    // Counted rather than compared whole, so an override added since the
    // snapshot is caught without building a second map to diff against.
    return live.length != persisted;
  }

  /// The overrides this holder would contribute to the store, by key.
  ///
  /// The one definition of "what this build has to say about the store", read
  /// by both [save] and [hasUnsavedChanges]. Two copies would be two answers to
  /// "is there anything to save", and the getter would eventually disagree with
  /// the writer it is supposed to predict.
  Map<String, Object?> get _declaredOverrides => {
    for (final setting in _settings.values)
      if (setting.isOverridden) setting.key: setting.get(),
  };

  // ---------------------------------------------------------------------------
  // Declaration
  // ---------------------------------------------------------------------------

  /// Declares a `String` setting under the dotted [key].
  ///
  /// [envAlias] names an environment variable that, when
  /// [TomClientEnvironment] reports it set, supplies this setting's value and
  /// takes it out of the install's hands — see [TomSetting.isFromEnvironment]
  /// and the resolution order on this class.
  ///
  /// [overridableBy] opens the key to a narrower client scope — see
  /// [TomOverridableBy] and [TomEffectiveSettings]. It defaults to the closed
  /// arm, so a setting is scope-pinned until its author says otherwise.
  TomSetting<String> stringSetting(
    String key,
    String declaredDefault, {
    String? envAlias,
    TomOverridableBy overridableBy = TomOverridableBy.none,
  }) => _declare<String>(key, declaredDefault, envAlias, overridableBy);

  /// Declares an `int` setting under the dotted [key].
  TomSetting<int> intSetting(
    String key,
    int declaredDefault, {
    String? envAlias,
    TomOverridableBy overridableBy = TomOverridableBy.none,
  }) => _declare<int>(key, declaredDefault, envAlias, overridableBy);

  /// Declares a `double` setting under the dotted [key].
  TomSetting<double> doubleSetting(
    String key,
    double declaredDefault, {
    String? envAlias,
    TomOverridableBy overridableBy = TomOverridableBy.none,
  }) => _declare<double>(key, declaredDefault, envAlias, overridableBy);

  /// Declares a `bool` setting under the dotted [key].
  TomSetting<bool> boolSetting(
    String key,
    bool declaredDefault, {
    String? envAlias,
    TomOverridableBy overridableBy = TomOverridableBy.none,
  }) => _declare<bool>(key, declaredDefault, envAlias, overridableBy);

  // The four public declaration methods fix the value types to exactly those
  // that survive a JSON round-trip through the store. A public generic
  // `declare<T>` would let a caller declare a type the store cannot persist,
  // and the failure would surface at save time rather than at the declaration.
  TomSetting<T> _declare<T>(
    String key,
    T declaredDefault,
    String? envAlias,
    TomOverridableBy overridableBy,
  ) {
    if (_settings.containsKey(key)) {
      throw TomClientConfigurationException(
        'client_configuration.key.duplicate',
        "Configuration key '$key' is declared more than once.",
        parameters: {'key': key},
      );
    }
    if (overridableBy != TomOverridableBy.none) {
      // A declaration that opens a key is a promise that a preference store may
      // answer for it. Both stores enforce `TomUserPreferenceKeys`, so a key
      // they would refuse makes the promise unkeepable — and the refusal would
      // otherwise surface at the first effective read, far from the line that
      // made it. The rule is the preference vocabulary's, so the refusal is
      // `preferences.key.invalid` rather than a second spelling of it here.
      TomUserPreferenceKeys.validate(key);
    }
    // One lookup, not two. `exists` and `getObjectOrNull` are the same
    // resolver — `_resolveObjectOrNull` — so the guarded pair walked the nested
    // map twice per declared setting to answer one question, and every
    // application declares its settings at start-up.
    //
    // The guard was also the only thing standing between a missing key and a
    // wrong value. `getObject` answers a miss with *the key you asked for*, so
    // an unguarded `getObject` gives a `String` setting the literal
    // `'client.server.url'` — which coerces cleanly and is stored as though it
    // had been configured. `getObjectOrNull` cannot do that: a miss is `null`
    // and falls to the declared default, so the safe path no longer depends on
    // remembering the guard.
    //
    // A key configured with no value reads as absent on both, since both go
    // through the same resolver, and so still takes the declared default.
    final config = TomConfigResourceProvider.getAppConfig();
    final configured = config.getObjectOrNull(key);
    final baseline = configured != null
        ? coerceSettingValue<T>(key, configured)
        : declaredDefault;
    // Layer 0. Read here rather than at every `get()` so that one declaration
    // is one lookup, and so that a value the environment cannot supply as this
    // type fails at start-up — where it names the key — rather than at the
    // first read of a screen that happens to show it.
    final raw = envAlias == null ? null : TomClientEnvironment.reader(envAlias);
    final fromEnvironment = raw != null;
    final setting = TomSetting<T>._(
      key,
      declaredDefault,
      baseline,
      envAlias,
      fromEnvironment,
      overridableBy,
    );
    if (fromEnvironment) {
      setting._environmentValue = coerceSettingValue<T>(key, raw);
      setting.set(setting._environmentValue as T);
    } else if (_persisted.containsKey(key)) {
      // A setting declared after load() must still see its persisted override —
      // registration order is not the caller's problem. An environment-bound
      // one does not: the operator's value outranks the store's.
      setting.applyRaw(_persisted[key]);
    }
    setting.addObserver(this);
    _settings[key] = setting;
    return setting;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Adopts this install's persisted overrides.
  ///
  /// Every declared setting ends up at its persisted override if the store has
  /// one and at its baseline if it does not — so `load()` puts the holder in
  /// exactly the state a fresh start would produce, whatever it held before.
  /// That makes it idempotent and makes it the right call after an external
  /// change to the store.
  ///
  /// Observers see **one** notification for the whole load, not one per
  /// setting, because a load is a single event.
  ///
  /// Throws `client_configuration.store.not_configured` when no [store] is
  /// wired.
  Future<void> load() async {
    final store = _requireStore('load');
    _persisted = {...await store.read()};
    mute();
    try {
      for (final entry in _settings.entries) {
        final setting = entry.value;
        // An environment-configured setting is not the store's to set, but it
        // is still `load`'s to restore: this method promises the state a fresh
        // start would produce, and a fresh start applies the operator's value.
        // `reset` is that value for such a setting, which is why it is called
        // here rather than skipped — an in-memory change made against the
        // operator's decision does not survive a reload.
        if (setting.isFromEnvironment) {
          setting.reset();
          continue;
        }
        if (_persisted.containsKey(entry.key)) {
          setting.applyRaw(_persisted[entry.key]);
        } else {
          setting.reset();
        }
      }
    } finally {
      unmute();
    }
  }

  /// Writes the overrides this holder **changed**, and adopts everything else
  /// from the store.
  ///
  /// A declared setting has *changed* when its override differs from the
  /// snapshot the last [load] or [save] took: an override added, a value
  /// altered, an override dropped (a [reset] is a change too). Those keys are
  /// written — the override, or its removal. Every other key is carried
  /// forward exactly as the store holds it **now**, read immediately before the
  /// write: keys this build does not declare, and declared keys this holder did
  /// not touch. So two holders over one store location do not erase each
  /// other: a holder that never touched `client.retries` keeps the value
  /// another holder saved there, whether or not it reloaded in between.
  ///
  /// **Afterwards the holder matches the store.** Each declared setting this
  /// holder did not change adopts the stored value — or its baseline, when the
  /// store has none — under one notification, as [load] does. The holder never
  /// shows a value the store does not hold, and calling [save] again with
  /// nothing changed writes back exactly what it read.
  ///
  /// A setting the environment configured is never changed by the install, so
  /// it is never written and never adopted: the store's entry for it, if any,
  /// is carried forward and comes back into force when the variable is unset.
  ///
  /// **What "changed" means without a snapshot.** After the [store] setter
  /// points the holder somewhere new the snapshot is empty by design, so every
  /// override counts as added and every setting at its baseline as untouched:
  /// the overrides are written, and the new store's values for the rest are
  /// kept and adopted.
  ///
  /// **Pinning.** Only overrides are written, so an install cannot *create* an
  /// entry that equals the baseline: setting a value back to the baseline is
  /// dropping the override, and the key is removed. An entry that already
  /// equals the baseline — written by another build, or by hand — is not a
  /// change of this holder's and is carried forward like any other.
  ///
  /// What stays open is concurrency. Read-then-write is not one operation, so
  /// two saves that genuinely overlap lose the change of whichever wrote first;
  /// nothing detects it, because the persisted document carries no version
  /// stamp. See the module documentation.
  ///
  /// Throws `client_configuration.store.not_configured` when no [store] is
  /// wired.
  Future<void> save() async {
    final store = _requireStore('save');
    final changed = _changedOverrides;
    final document = <String, Object?>{...await store.read()};
    for (final entry in changed.entries) {
      if (entry.value.$1) {
        document[entry.key] = entry.value.$2;
      } else {
        document.remove(entry.key);
      }
    }
    await store.write(document);
    _persisted = document;
    _adopt(document, except: changed.keys.toSet());
  }

  /// The declared keys this holder has changed since its snapshot, each with
  /// whether it now holds an override and, if so, its value.
  ///
  /// A snapshot entry that reads as the baseline is no override — the same rule
  /// [hasUnsavedChanges] applies — so leaving such a key untouched is not a
  /// change, and the entry is carried forward rather than removed.
  Map<String, (bool, Object?)> get _changedOverrides {
    final live = _declaredOverrides;
    final changed = <String, (bool, Object?)>{};
    for (final setting in _settings.values) {
      if (setting.isFromEnvironment) continue;
      final key = setting.key;
      final snapshotted =
          _persisted.containsKey(key) &&
          !setting._readsAsBaseline(_persisted[key]);
      final overridden = live.containsKey(key);
      if (overridden != snapshotted ||
          (overridden && !setting._equalsRaw(_persisted[key]))) {
        changed[key] = (overridden, live[key]);
      }
    }
    return changed;
  }

  /// Brings every declared setting not in [except] to [document]'s value, or
  /// to its baseline when [document] has none; one notification.
  void _adopt(Map<String, Object?> document, {required Set<String> except}) {
    mute();
    try {
      for (final setting in _settings.values) {
        if (setting.isFromEnvironment || except.contains(setting.key)) {
          continue;
        }
        if (document.containsKey(setting.key)) {
          setting.applyRaw(document[setting.key]);
        } else {
          setting.reset();
        }
      }
    } finally {
      unmute();
    }
  }

  // ---------------------------------------------------------------------------
  // Overrides
  // ---------------------------------------------------------------------------

  /// Whether the setting under [key] differs from its baseline.
  ///
  /// Throws `client_configuration.key.unknown` when no such setting is
  /// declared.
  bool isOverridden(String key) => _requireSetting(key).isOverridden;

  /// Drops the install's override for [key], restoring the baseline.
  ///
  /// In memory only — call [save] to make it stick.
  ///
  /// Throws `client_configuration.key.unknown` when no such setting is
  /// declared.
  void reset(String key) => _requireSetting(key).reset();

  /// Drops every override, restoring all baselines.
  ///
  /// Emits a single holder notification, like [load].
  void resetAll() {
    mute();
    try {
      for (final setting in _settings.values) {
        setting.reset();
      }
    } finally {
      unmute();
    }
  }

  // ---------------------------------------------------------------------------
  // Observation
  // ---------------------------------------------------------------------------

  /// Re-emits a member setting's change as a change of the holder.
  @override
  void onNotify(TomObservable observable) => notifyObservers();

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  TomClientConfigurationStore _requireStore(String operation) {
    final store = _store;
    if (store == null) {
      throw TomClientConfigurationException(
        'client_configuration.store.not_configured',
        "Cannot $operation client configuration: no store is configured. "
            'Pass one to the constructor or assign it before use.',
        parameters: {'operation': operation},
      );
    }
    return store;
  }

  TomSetting _requireSetting(String key) {
    final setting = _settings[key];
    if (setting == null) {
      throw TomClientConfigurationException(
        'client_configuration.key.unknown',
        "No client configuration setting is declared under key '$key'.",
        parameters: {'key': key},
      );
    }
    return setting;
  }

  @override
  String toString() =>
      '$runtimeType(${_settings.values.map((s) => s.toString()).join(', ')})';
}
