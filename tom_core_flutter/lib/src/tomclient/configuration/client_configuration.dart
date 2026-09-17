import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'client_configuration_store.dart';

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
  TomSetting._(this.key, this.declaredDefault, this.baseline) : super(baseline);

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

  /// Whether the install has changed this setting away from its [baseline].
  bool get isOverridden => get() != baseline;

  /// Restores the [baseline], dropping the install's override.
  ///
  /// Notifies observers when the value actually changes, like any other set.
  void reset() => set(baseline);

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
/// A value that varies per *user* is a user preference and belongs in a
/// different holder with a different lifecycle (it follows the account, it
/// syncs, it needs a login before it can be read); a value that configures the
/// *server* belongs in `TomBaseServerConfiguration`. Adding either here turns
/// the holder into a junk drawer and quietly breaks the guarantee that reading
/// a client setting never needs a session.
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
/// 1. the **persisted override** — what this install last saved;
/// 2. the **shipped config-resources value** for the key
///    ([TomConfigResourceProvider]);
/// 3. the **declared default** at the declaration site.
///
/// Only layer 1 is persisted. A key the install never changed is re-resolved
/// from layers 2–3 at every start, so shipping a new default in an app update
/// actually reaches installs that never touched that key. Persisting the full
/// value set instead would freeze the shipped defaults at the moment of the
/// first save.
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
/// await config.save();          // persist the overrides — and only those
/// ```
///
/// [declareSettings] is called from the constructor, mirroring
/// `TomClass.prepareForSelfObservation`. It exists because Dart field
/// initialisers cannot call instance methods, so `stringSetting(...)` cannot
/// appear in a field initialiser — and because it makes the declaration set
/// **complete by the end of construction**, which is what lets [settings],
/// [save] and [resetAll] be exhaustive rather than "exhaustive so far".
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
  /// [save] deliberately does *not* seed its carry-forward from here — see the
  /// note on [save] for why it re-reads instead.
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
      if (!_settings.containsKey(entry.key)) continue;
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
  TomSetting<String> stringSetting(String key, String declaredDefault) =>
      _declare<String>(key, declaredDefault);

  /// Declares an `int` setting under the dotted [key].
  TomSetting<int> intSetting(String key, int declaredDefault) =>
      _declare<int>(key, declaredDefault);

  /// Declares a `double` setting under the dotted [key].
  TomSetting<double> doubleSetting(String key, double declaredDefault) =>
      _declare<double>(key, declaredDefault);

  /// Declares a `bool` setting under the dotted [key].
  TomSetting<bool> boolSetting(String key, bool declaredDefault) =>
      _declare<bool>(key, declaredDefault);

  // The four public declaration methods fix the value types to exactly those
  // that survive a JSON round-trip through the store. A public generic
  // `declare<T>` would let a caller declare a type the store cannot persist,
  // and the failure would surface at save time rather than at the declaration.
  TomSetting<T> _declare<T>(String key, T declaredDefault) {
    if (_settings.containsKey(key)) {
      throw TomClientConfigurationException(
        'client_configuration.key.duplicate',
        "Configuration key '$key' is declared more than once.",
        parameters: {'key': key},
      );
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
    final setting = TomSetting<T>._(key, declaredDefault, baseline);
    // A setting declared after load() must still see its persisted override —
    // registration order is not the caller's problem.
    if (_persisted.containsKey(key)) {
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

  /// Persists the install's overrides — and only those.
  ///
  /// A setting sitting at its baseline is *not* written, and is removed from
  /// the store if it was there before; see the class documentation for why
  /// storing the full value set would be wrong.
  ///
  /// Keys in the store that this build does not declare are carried forward
  /// untouched. A build that has dropped a setting — or an older build during
  /// a staged rollout — must not destroy an install's value for a key it
  /// simply does not know about.
  ///
  /// Carry-forward is seeded by **re-reading the store**, not from the snapshot
  /// [load] took. The snapshot answers a different question — what this store
  /// held when this holder started — and the two diverge in two ways that both
  /// break the promise above. A holder pointed at a second store would deposit
  /// the *first* store's keys into it while destroying the second's own. And a
  /// key written by anyone else since this holder loaded — a second holder over
  /// the same location, an external edit — is not in the snapshot, so it would
  /// be deleted rather than carried forward, which is precisely the loss this
  /// mechanism exists to prevent.
  ///
  /// What re-reading does **not** do is make a store location shareable. The
  /// carry-forward covers keys this build does not declare; a key two holders
  /// both declare is written from the saving holder's own view, and a holder
  /// that has not adopted the other's change holds that key at its baseline —
  /// so it writes "no override" over it, sequentially, with no concurrency
  /// involved. On top of that, read-then-write is not atomic, so two saves that
  /// genuinely overlap lose the earlier reader's change even if both reloaded.
  /// Nothing detects either; see the module documentation.
  ///
  /// Throws `client_configuration.store.not_configured` when no [store] is
  /// wired.
  Future<void> save() async {
    final store = _requireStore('save');
    final live = await store.read();
    final overrides = <String, Object?>{
      for (final entry in live.entries)
        if (!_settings.containsKey(entry.key)) entry.key: entry.value,
      ..._declaredOverrides,
    };
    await store.write(overrides);
    _persisted = overrides;
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
