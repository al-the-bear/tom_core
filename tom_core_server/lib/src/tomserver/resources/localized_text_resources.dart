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
  /// Not client-visible: the malformed value came from configuration or a user
  /// record, and quoting it back to a browser tells an attacker about the
  /// deployment rather than telling anyone useful about the fault.
  TomResourceLocaleException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
    super.clientThrow = false,
  });
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
  final String? country;

  /// Names a locale, normalising case and treating a blank country as none.
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
  }

  /// Parses `de`, `de_AT` or `de-AT`.
  ///
  /// Both separators are accepted because both are in the wild — POSIX and
  /// Java write `_`, BCP 47 and HTTP write `-` — and a bundle keyed one way
  /// that a user record spells the other way is a silent miss, not an error.
  factory TomTextLocale.parse(String tag) {
    final parts = tag.trim().split(RegExp('[_-]'));
    return TomTextLocale(parts.first, parts.length > 1 ? parts[1] : null);
  }

  /// The locale to render for [principal], or `null` when it names none.
  ///
  /// The *stored* language wins over the client device's. A mail is read later,
  /// often elsewhere, so the user's recorded preference is the durable answer;
  /// the device locale is a fact about one sign-in and is used only when there
  /// is no preference to honour. `null` rather than a guess, so the caller
  /// falls back to the deployment's default locale in one place instead of
  /// each caller inventing `'en'`.
  static TomTextLocale? fromPrincipal(TomPrincipal principal) {
    final stored = principal.language;
    if (stored != null && stored.trim().isNotEmpty) {
      return TomTextLocale(stored, principal.country);
    }
    final client = principal.clientLanguage;
    if (client != null && client.trim().isNotEmpty) {
      return TomTextLocale(client, principal.clientCountry);
    }
    return null;
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
///     'en': loadYaml('resources/text_en.yaml'),
///     'de': loadYaml('resources/text_de.yaml'),
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
  /// proof-reading it, which an empty gap is not.
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
  static String substitute(String template, Map<String, Object?> parameters) {
    if (parameters.isEmpty) return template;
    var result = template;
    for (final entry in parameters.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
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
