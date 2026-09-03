/// What a catalogued message is *for* (`codespecs_mapping.md` §5.21).
///
/// The role drives channel-specific treatment (an email subject is length-bound,
/// an error string is paired with a CE-ER code), so it is authored rather than
/// inferred from the key's spelling.
enum TomMessageRole {
  /// Copy for a failure, paired 1:1 with a CE-ER error code.
  error,

  /// Copy for a user-facing notification.
  notification,

  /// Copy rendered into an email.
  email,

  /// Copy rendered into a generated report.
  report,

  /// Copy with no channel-specific treatment.
  generic,
}

/// The derived-vs-catalogued split of `codespecs_mapping.md` §5.8/§5.21.
///
/// Element copy (a field's label, a button's caption) is **derived** from the
/// element's `basePath` and gets no catalogue entry — duplicating it here would
/// create two places to rename one label. Everything else is catalogued.
enum TomMessageCategory {
  /// Copy attached to UI surfaces that are not element labels.
  uiCopy,

  /// Copy for a CE-ER error code. The error-copy namespace *is* the CE-ER code
  /// namespace: one entry per code, no more and no fewer.
  errorCopy,
}

/// One catalogued message key with its base copy and per-locale translations.
class TomMessageKey {
  /// The catalogue key (e.g. `app.error.amount.tooLarge`).
  String key;

  /// Copy in the registry's base locale. Always present, so resolution can fall
  /// back to real text rather than to the raw key.
  String baseCopy;

  /// What this message is for.
  TomMessageRole role;

  /// Which side of the derived/catalogued split this entry sits on.
  TomMessageCategory category;

  /// The CE-ER error code this copy renders, for
  /// [TomMessageCategory.errorCopy] entries; `null` otherwise.
  String? errorCode;

  /// Placeholder names the copy interpolates (e.g. `max` for `{max}`).
  ///
  /// Declared rather than parsed out of the copy so a translation that drops a
  /// placeholder is detectable.
  List<String> parameters;

  /// Translated copy by locale tag. A locale absent here falls back to
  /// [baseCopy].
  Map<String, String> localeCopy;

  /// Creates a catalogue entry.
  TomMessageKey({
    this.key = '',
    this.baseCopy = '',
    this.role = TomMessageRole.generic,
    this.category = TomMessageCategory.uiCopy,
    this.errorCode,
    List<String>? parameters,
    Map<String, String>? localeCopy,
  }) : parameters = parameters ?? <String>[],
       localeCopy = localeCopy ?? <String, String>{};
}

/// The message-key catalogue a CodeSpec's `@CsMessage` (CE-TX) is built on.
///
/// **Why this is a gap (`codespecs_mapping.md` §5.8/§5.21, verdict *gap*).**
/// The `tom_core_kernel` substrate (`TomTextResourceProvider` in
/// `tombase/resources/`) is an untyped **runtime lookup store** — a
/// `Map<String, dynamic>` filled at startup and read by key. It answers "what
/// text is behind this key right now", which is a *runtime* question. CodeSpecs
/// needs the *authoring* question answered instead: what is the **closed set of
/// keys** this system may render, what role and category does each carry, which
/// CE-ER code does each error string belong to, and which placeholders must
/// every translation preserve. None of that exists in the provider — it will
/// happily return `null` for a key nobody ever defined. So the catalogue lands
/// here as a concrete `tom_core`-family class — never an abstract `Cs*` base
/// (the framework carries annotations only, `codespecs_mapping.md` §1.1).
///
/// A CodeSpec `@CsMessage` catalogue *is a* [TomMessageKeyRegistry]. CE-TX is a
/// *shared* part (`codespecs_mapping.md` §4.2): server-side error and email
/// copy and client-side UI copy resolve against one catalogue, so it lives in
/// the shared project of the three-project output trio.
class TomMessageKeyRegistry {
  /// Locale whose copy is held in [TomMessageKey.baseCopy].
  String baseLocale;

  final Map<String, TomMessageKey> _byKey = <String, TomMessageKey>{};

  /// Creates an empty catalogue.
  TomMessageKeyRegistry({this.baseLocale = 'en'});

  /// Every catalogued entry, in registration order.
  List<TomMessageKey> get keys => _byKey.values.toList(growable: false);

  /// Whether [key] is catalogued.
  bool hasKey(String key) => _byKey.containsKey(key);

  /// Adds [entry] to the catalogue.
  ///
  /// Throws [ArgumentError] if the key is already catalogued (two entries for
  /// one key make the rendered text depend on registration order) or if an
  /// error-copy entry carries no CE-ER code (`codespecs_mapping.md` §5.21: the
  /// error-copy namespace *is* the code namespace, so an uncoded error string
  /// belongs to nothing).
  void register(TomMessageKey entry) {
    if (_byKey.containsKey(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'entry.key',
        'message key is already registered',
      );
    }
    if (entry.category == TomMessageCategory.errorCopy &&
        (entry.errorCode == null || entry.errorCode!.isEmpty)) {
      throw ArgumentError.value(
        entry.key,
        'entry.key',
        'error copy must name the CE-ER error code it renders',
      );
    }
    _byKey[entry.key] = entry;
  }

  /// The entry rendering CE-ER code [errorCode], or `null` when the code has no
  /// copy yet.
  TomMessageKey? forErrorCode(String errorCode) {
    for (final entry in _byKey.values) {
      if (entry.errorCode == errorCode) return entry;
    }
    return null;
  }

  /// Copy for [key] in [locale], falling back to the base-locale copy when the
  /// locale has no translation.
  ///
  /// Fallback is **never to the raw key** (`codespecs_mapping.md` §5.21): a
  /// user shown `app.error.amount.tooLarge` has been shown a bug, not a
  /// message. An unregistered key is a *generation-time spec error* — the
  /// catalogue is the closed key vocabulary, so a key outside it cannot be
  /// rendered at all.
  String resolve(String key, String locale) {
    final entry = _byKey[key];
    if (entry == null) {
      throw ArgumentError.value(
        key,
        'key',
        'message key is not in the catalogue',
      );
    }
    return entry.localeCopy[locale] ?? entry.baseCopy;
  }
}
