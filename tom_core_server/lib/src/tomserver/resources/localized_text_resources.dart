/// Resource text chosen by the *recipient's* locale rather than the process's.
///
/// ## Why the kernel's provider is not enough here
///
/// [TomTextResourceProvider] is a **singleton with no locale dimension**: one
/// installed bundle, swapped when the user's language changes. That is exactly
/// right on a client, where there is one user looking at one screen — and
/// exactly wrong on a server, which renders text for many users in many
/// languages *concurrently*. There is no moment at which a server could
/// meaningfully "switch to German": it is answering a German user and an
/// English one in the same event loop.
///
/// So the locale has to be an **argument**, not ambient state. That is the only
/// thing this library adds.
///
/// ## Layered, not reimplemented
///
/// Everything about how a key resolves — dot-notation tree walk, flat-key
/// fallback, what counts as a String — stays in [TomTextResourceProvider]. This
/// class holds one provider per locale and decides *which* provider answers.
/// Reimplementing the walk would give a deployment two resolution semantics for
/// the same bundle format, and the first key that resolved on the client but
/// not in an email would be a genuinely hard bug to see.
///
/// ## The fallback chain
///
/// A lookup walks, in order:
///
/// 1. the requested locale's exact tag (`de_AT`),
/// 2. its bare language (`de`),
/// 3. the default locale's tag, then its bare language.
///
/// Per **key**, not per bundle. A half-translated `de` bundle therefore serves
/// the strings it has and falls through to the default locale for the rest,
/// which is what a translation in progress looks like; the alternative — a
/// bundle being all-or-nothing — means the first untranslated key silently
/// reverts a whole message to another language.
///
/// *Which* locale that is belongs to the deployment. [defaultLocale] is a
/// required constructor argument with no framework-supplied value, so a set
/// built with `TomTextLocale('fr')` falls through to French. There is no
/// privileged language here, and that is deliberate: a built-in English would
/// be precisely the ambient assumption this library exists to remove.
///
/// ## A miss is `null`, never the key
///
/// [TomTextResourceProvider.getText] answers an unknown key with the key
/// itself. On a screen that is the right failure: the button reads
/// `two_factor.totp.enrol.submit`, which is unmistakable and gets fixed. In an
/// email it is not: nobody sees the subject line before the recipient does. So
/// only [textOrNull] is offered, and the caller decides how loudly to fail —
/// [TomEmailService] fails at send.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// Raised when a locale cannot be formed from what a caller supplied.
class TomResourceLocaleException extends TomServerException {
  /// Creates a locale exception.
  ///
  /// Never client-visible: the malformed value came from configuration or a user
  /// record, and quoting it back to a browser tells an attacker about the
  /// deployment rather than telling anyone useful about the fault.
  ///
  /// `clientThrow` is not a parameter, so that is an invariant of the type and
  /// not merely the value it is born with — which is the whole reason the type
  /// is declared at all, since it adds no field and no behaviour otherwise. It
  /// would be a weaker claim as a re-defaulted parameter: the two throw sites
  /// below would still be hidden, but nothing would stop a third from asking to
  /// be shown.
  TomResourceLocaleException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  }) : super(clientThrow: false);
}

/// A language, optionally narrowed by a country.
///
/// Deliberately *not* Dart's `Locale` (which lives in `dart:ui` and would drag
/// Flutter into a server package) and not a bare `String` (which would leave
/// every call site to decide whether `de-AT`, `de_AT` and `DE_at` are the same
/// bundle — they are).
class TomTextLocale {
  /// ISO 639-1, lowercase.
  final String language;

  /// ISO 3166-1 alpha-2, uppercase; `null` when the locale names only a
  /// language.
  ///
  /// Enforced, not merely described: the constructor refuses anything else.
  /// Left as prose, the rule admits a four-letter script subtag and yields the
  /// key `zh_HANS`.
  final String? country;

  /// Names a locale, normalising case and treating a blank country as none.
  ///
  /// Refuses a [country] that ISO 3166-1 could not assign to one — anything
  /// that is not two letters, and the user-assigned codes that are two letters
  /// but reserved from ever naming a country (`XX` among them; see
  /// [TomTextLocale.lenient] and `_isCountry`). Strict because the value ends
  /// up in a bundle key: a country that cannot be one produces a key that names
  /// no locale, and since the chain still reaches the bare language the
  /// deployment sees plausible text and never learns its regional bundle was
  /// unreachable. For values from a user record or a client request, where a
  /// throw would be wrong, use [TomTextLocale.lenient].
  TomTextLocale(String language, [String? country])
    : language = language.trim().toLowerCase(),
      country = (country == null || country.trim().isEmpty)
          ? null
          : country.trim().toUpperCase() {
    if (this.language.isEmpty) {
      throw TomResourceLocaleException(
        'resources.locale.empty_language',
        'A locale needs a language.',
      );
    }
    final named = this.country;
    if (named != null && !_isCountry(named)) {
      throw TomResourceLocaleException(
        'resources.locale.invalid_country',
        'A country must be an assigned ISO 3166-1 alpha-2 code.',
        parameters: {'country': named},
      );
    }
  }

  /// Parses `de`, `de_AT`, `de-AT`, or a fuller BCP 47 tag like `zh-Hans-CN`.
  ///
  /// Both separators are accepted because both are in the wild — POSIX and
  /// Java write `_`, BCP 47 and HTTP write `-` — and a bundle keyed one way
  /// that a user record spells the other way is a silent miss, not an error.
  ///
  /// The region is found by **shape, not position**. BCP 47 places an optional
  /// script before the region for the languages that have more than one, so
  /// `zh-Hans-CN` names China in its *third* segment; taking the second
  /// unconditionally yielded `zh_HANS`, a key no `zh_CN` bundle could match,
  /// and the chain's fall through to bare `zh` hid it. Script, extlang and
  /// variant subtags are skipped, and a subtag that cannot be an alpha-2
  /// region — `es-419`'s UN M.49 number among them — leaves a bare language
  /// rather than becoming a country it is not.
  factory TomTextLocale.parse(String tag) {
    final parts = tag.trim().split(RegExp('[_-]'));
    return TomTextLocale(parts.first, _regionIn(parts.skip(1)));
  }

  /// A locale from data this process does not control.
  ///
  /// Lenient exactly where the default constructor is strict: a [country] that
  /// cannot be one is dropped rather than refused. `TomPrincipal.country` and
  /// the 2FA context's are free-form strings filled from a client request, so
  /// the strict constructor must not be reachable with them — a client sending
  /// `XYZ` would otherwise throw inside message delivery. Dropping the country
  /// leaves a bundle that exists; the refused key never was one.
  ///
  /// The commonest such value is not malformed at all: it is the `XX` this
  /// stack uses to mean *no country*, which arrives by default rather than by
  /// mistake. Dropping it is the whole point — `en` is the bundle that user
  /// should get.
  factory TomTextLocale.lenient(String language, [String? country]) =>
      TomTextLocale(language, _countryOrNull(country));

  /// The locale to render for [principal], or `null` when it names none.
  ///
  /// **This is the derivation for rendering text for a recipient.** The
  /// kernel's `TomContextProviders` also exposes the principal's locale fields,
  /// but as four independent accessors — `getLanguage`, `getCountry`,
  /// `getClientLanguage`, `getClientCountry` — each reading one field and
  /// substituting a sentinel when it is absent. Those report *what the
  /// principal says*; they deliberately do not choose between the stored pair
  /// and the device's, because a caller wanting one specific field must be able
  /// to ask for it. Choosing is this method's job, and composing the accessors
  /// instead — `TomTextLocale(getLanguage(), getCountry())` — reintroduces the
  /// sentinels the country invariant now refuses.
  ///
  /// The *stored* language wins over the client device's. A mail is read later,
  /// often elsewhere, so the user's recorded preference is the durable answer;
  /// the device locale is a fact about one sign-in and is used only when there
  /// is no preference to honour. `null` rather than a guess, so the caller
  /// falls back to the deployment's default locale in one place instead of
  /// each caller inventing `'en'`.
  ///
  /// Reads the record leniently — see [TomTextLocale.lenient].
  static TomTextLocale? fromPrincipal(TomPrincipal principal) {
    final stored = principal.language;
    if (stored != null && stored.trim().isNotEmpty) {
      return TomTextLocale.lenient(stored, principal.country);
    }
    final client = principal.clientLanguage;
    if (client != null && client.trim().isNotEmpty) {
      return TomTextLocale.lenient(client, principal.clientCountry);
    }
    return null;
  }

  /// Whether [subtag] is an ISO 3166-1 alpha-2 code that can name a country.
  ///
  /// Shape is necessary and not sufficient. ISO 3166-1 permanently withholds
  /// `AA`, `QM`-`QZ`, `XA`-`XZ` and `ZZ` from assignment so applications can
  /// use them privately, so no country will ever bear one and no bundle will
  /// ever be keyed with one.
  ///
  /// They matter more than their rarity suggests, because they are exactly
  /// what a caller supplies when it has *no* country. `TomLoginMessage`
  /// defaults `clientCountry` to `XX`, clients send it verbatim when the
  /// device names no region, and it reaches [TomPrincipal.clientCountry]
  /// through an ordinary sign-in; the kernel's `TomContextProviders.getCountry`
  /// answers the same sentinel, and CLDR spells the idea `ZZ`. Admitting one
  /// produced the tag `en_XX`, which matches no bundle, resolves through bare
  /// `en`, and reports nowhere that it did — the silent miss this invariant
  /// exists to prevent rather than an exception to it.
  static bool _isCountry(String subtag) =>
      _countryPattern.hasMatch(subtag) &&
      !_userAssignedPattern.hasMatch(subtag.toUpperCase());

  static final RegExp _countryPattern = RegExp(r'^[A-Za-z]{2}$');

  static final RegExp _userAssignedPattern = RegExp(r'^(AA|Q[M-Z]|X[A-Z]|ZZ)$');

  /// The first subtag shaped like a region, or `null` when there is none.
  ///
  /// Stops at a singleton: in BCP 47 a one-character subtag opens an extension
  /// or private-use sequence, whose contents are not subtags of the language.
  static String? _regionIn(Iterable<String> subtags) {
    for (final subtag in subtags) {
      if (subtag.length == 1) return null;
      if (_isCountry(subtag)) return subtag;
    }
    return null;
  }

  /// [country] when it can be one, `null` otherwise.
  static String? _countryOrNull(String? country) {
    if (country == null) return null;
    final trimmed = country.trim();
    return _isCountry(trimmed) ? trimmed : null;
  }

  /// The bundle key: `de` or `de_AT`.
  String get tag => country == null ? language : '${language}_$country';

  /// This locale's tags from most to least specific.
  List<String> get fallbackTags =>
      country == null ? [language] : ['${language}_$country', language];

  @override
  bool operator ==(Object other) => other is TomTextLocale && other.tag == tag;

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => tag;
}

/// One [TomTextResourceProvider] per locale, plus the rule for picking one.
///
/// ```dart
/// final texts = TomLocalizedTextResources(
///   defaultLocale: TomTextLocale('en'),
///   bundles: {
///     'en': TomYaml.loadYamlFile('resources/text_en.yaml'),
///     'de': TomYaml.loadYamlFile('resources/text_de.yaml'),
///   },
/// );
///
/// texts.textOrNull(
///   'email.password_reset.subject',
///   locale: TomTextLocale.fromPrincipal(principal),
///   parameters: {'firstname': principal.user.firstname},
/// );
/// ```
class TomLocalizedTextResources {
  /// The locale that answers when the requested one has nothing to say.
  final TomTextLocale defaultLocale;

  final Map<String, TomTextResourceProvider> _bundles;

  /// Builds a bundle set from raw resource maps, keyed by locale tag.
  ///
  /// The tags are normalised through [TomTextLocale.parse], so a deployment may
  /// name its files `text_de-AT.yaml` or `text_de_AT.yaml` and get the same
  /// bundle either way.
  ///
  /// **Throws [TomResourceLocaleException] for a key that names no language** —
  /// an empty or blank key, or one whose first subtag is empty (`_AT`). Every
  /// other key parses: [TomTextLocale.parse] finds the region by shape and
  /// drops any subtag that cannot be one, so `es-419` and `en_XX` normalise to
  /// `es` and `en` rather than being refused. A missing language is the one
  /// thing it cannot recover from.
  ///
  /// That throw is worth expecting because of where keys come from. The
  /// documented pattern derives them from *file names* (`text_de-AT.yaml` →
  /// `de-AT`), so a stray `text_.yaml` or a mis-globbed directory entry becomes
  /// a bootstrap failure whose message names a locale and not the file that
  /// caused it — catch it at the loader if the path is worth reporting, as
  /// `advanced_ops_server`'s `ops_texts.dart` does.
  ///
  /// Normalisation also means two keys can name one locale, and the last of
  /// them wins with no warning: `{'en': …, 'en_XX': …}` yields a single `en`
  /// bundle. Mostly that is the point (`de-AT` and `de_AT` *should* be one
  /// bundle); it stops being the point when the second key is one the deployment
  /// believed was a separate regional variant.
  factory TomLocalizedTextResources({
    required Map<String, Map<String, dynamic>> bundles,
    required TomTextLocale defaultLocale,
  }) => TomLocalizedTextResources.ofProviders(
    defaultLocale: defaultLocale,
    bundles: bundles.map(
      (tag, map) => MapEntry(tag, TomTextResourceProvider.from(map)),
    ),
  );

  /// Builds a bundle set from providers that are already constructed.
  ///
  /// For a deployment whose bundles come from somewhere with its own loading
  /// rules — a database, an asset archive, [TomTextResourceProvider.load] —
  /// rather than from a map it happens to be holding.
  ///
  /// Keys are normalised and validated exactly as in the unnamed constructor,
  /// which delegates here: **a key naming no language throws
  /// [TomResourceLocaleException]**, everything else parses, and two keys
  /// reaching one tag collapse silently. The rule belongs to this constructor
  /// rather than to the factory, so a deployment that only ever calls
  /// `ofProviders` gets it too — and a locale tag read from a database column
  /// is at least as likely to be blank as one read from a file name.
  TomLocalizedTextResources.ofProviders({
    required Map<String, TomTextResourceProvider> bundles,
    required this.defaultLocale,
  }) : _bundles = {
         for (final entry in bundles.entries)
           TomTextLocale.parse(entry.key).tag: entry.value,
       };

  /// The locale tags this set carries, in insertion order.
  List<String> get locales => _bundles.keys.toList(growable: false);

  /// Whether a bundle exists for [locale]'s exact tag.
  ///
  /// Exact, not resolved: this answers "did someone write this translation",
  /// which is a deployment question. What a *lookup* would do is
  /// [resolveLocale].
  bool hasLocale(TomTextLocale locale) => _bundles.containsKey(locale.tag);

  /// The locale a lookup for [locale] would actually read from, following the
  /// fallback chain; `null` when the chain reaches no bundle.
  ///
  /// Reports the bundle that answers, not the key that resolves — a
  /// per-key fallthrough may still land elsewhere. It exists so a caller that
  /// must *state* the language it rendered (a `Content-Language` header, a
  /// stored copy of a sent mail) can say so truthfully rather than echoing what
  /// was asked for.
  ///
  /// `null` does **not** mean the set is empty. Every chain ends with
  /// [defaultLocale]'s own tags, so `null` says precisely that the set carries
  /// no bundle for its *default* locale: a set holding `fr` with a default of
  /// `en` answers `null` for `de` while carrying a perfectly good `fr`. Reading
  /// it as "the set is empty" makes the usual
  /// `resolveLocale(requested) ?? defaultLocale` look unreachable in a
  /// configured deployment, when it is the branch that fires on exactly that
  /// wiring fault — and names a language nothing was rendered in.
  TomTextLocale? resolveLocale(TomTextLocale? locale) {
    for (final tag in _chain(locale)) {
      if (_bundles.containsKey(tag)) return TomTextLocale.parse(tag);
    }
    return null;
  }

  /// The text at [key] for [locale], with `{name}` placeholders substituted
  /// from [parameters]; `null` when no bundle in the chain has the key.
  ///
  /// [parameters] uses the same `{name}` convention as the client's
  /// parameterised text, so one bundle serves both tiers and a translator sees
  /// one placeholder syntax rather than two.
  ///
  /// A placeholder with no matching parameter is left as written rather than
  /// blanked or reported. Bodies legitimately contain braces — inline CSS above
  /// all — so "an unmatched brace is a fault" would fail on correct templates;
  /// and a *visible* `{firstname}` in a proof-read mail is caught by the person
  /// proof-reading it, which an empty gap is not. A parameter whose value is
  /// `null` counts as absent for exactly this reason — see [substitute].
  String? textOrNull(
    String key, {
    TomTextLocale? locale,
    Map<String, Object?> parameters = const {},
  }) {
    for (final tag in _chain(locale)) {
      final found = _bundles[tag]?.getTextOrNull(key);
      if (found != null) return substitute(found, parameters);
    }
    return null;
  }

  /// Whether [key] resolves for [locale] anywhere in the fallback chain.
  bool exists(String key, {TomTextLocale? locale}) =>
      textOrNull(key, locale: locale) != null;

  /// Whether someone actually wrote [key] in [locale]'s **own** bundle.
  ///
  /// Un-chained, and that is the whole difference from [exists]. A render wants
  /// the chain — a half-translated bundle serving what it has is correct
  /// behaviour. A *completeness check* wants the opposite question: `exists`
  /// answers `true` for every key the default locale carries, so a test built
  /// on it passes on a `de` bundle that is entirely empty, which is precisely
  /// the gap such a test exists to find.
  bool isTranslated(String key, TomTextLocale locale) =>
      _bundles[locale.tag]?.getTextOrNull(key) != null;

  /// Substitutes `{name}` in [template] from [parameters].
  ///
  /// Exposed as a static so a caller holding text from elsewhere — a database
  /// column, a message already resolved — substitutes it the same way rather
  /// than writing a second `replaceAll` loop with subtly different escaping.
  ///
  /// A `null` value is skipped, so it behaves exactly like a parameter that was
  /// never passed and its placeholder is left as written. [parameters] takes
  /// `Object?` and callers fill it from nullable model fields — a user's
  /// `firstname` among them — so `null` arrives through the front door.
  /// Interpolating it wrote the word `null` into the text, which reads as
  /// finished prose and would slip past the proof-reader the
  /// unmatched-placeholder rule relies on. Leaving the placeholder puts the
  /// case where that rule can already see it.
  static String substitute(String template, Map<String, Object?> parameters) {
    if (parameters.isEmpty) return template;
    var result = template;
    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value == null) continue;
      result = result.replaceAll('{${entry.key}}', '$value');
    }
    return result;
  }

  /// The tags to try for [locale], most specific first, without repeats.
  List<String> _chain(TomTextLocale? locale) => <String>{
    if (locale != null) ...locale.fallbackTags,
    ...defaultLocale.fallbackTags,
  }.toList(growable: false);

  /// The bundle set this deployment installed, or `null`.
  ///
  /// Nullable with no fallback, following [Tom2FAEnrolmentStore.resolve]: an
  /// empty default would render every email blank, and a blank mail that was
  /// *sent* is worse than a wiring error that was raised.
  static TomLocalizedTextResources? resolve() {
    final installed = TomBean.getBeanByType(TomLocalizedTextResources);
    return installed is TomLocalizedTextResources ? installed : null;
  }
}
