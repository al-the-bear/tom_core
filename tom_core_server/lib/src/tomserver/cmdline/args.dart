import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Parses `key=value` command-line arguments and converts string values to
/// their natural Dart types.
///
/// All members are static; the class is a namespace, not a value type. Three
/// entry points share the same value-conversion rules (see [convertToObjectMap]
/// for the exact table):
///
/// - [fillFromArgs] populates a reflected configuration object from `argv`.
/// - [parseArgsToMap] returns the arguments as a loose `Map<String, dynamic>`.
/// - [convertToObjectMap] converts an existing string map (e.g.
///   `Platform.environment`) using the same rules.
///
/// An argument is split on its **first** `=`: the key is the text before it and
/// the value is everything after, so a value may itself contain `=` (a
/// connection string, a URL with a query, a padded base64 blob). This is the
/// rule `TomEnvFile.parse` applies, so the same text means the same thing on
/// the command line and in a `.env` file.
///
/// An argument with no `=` is treated as a flag. Both map-producing paths
/// encode a bare flag identically as the boolean `true` — consistent with how
/// `key=true` is converted (see [convertToObjectMap]) — so a bare flag can fill
/// a reflected `bool` field directly.
///
/// A key is stripped of its **leading `-` characters**, so `--port=8080`,
/// `-port=8080` and `port=8080` are one argument under the name `port`, and
/// `--verbose` is the flag `verbose`. The conventional command-line spelling
/// therefore reaches a reflected field, which a key carrying its dashes cannot:
/// no Dart class declares a field named `--port`. Two consequences follow. A
/// key cannot begin with `-`, and the dashed and bare spellings of one option
/// are the same entry, so the later of the two wins rather than both being
/// recorded. Only the *leading* run is a prefix: a dash inside or at the end of
/// a name is part of it (`--dry-run=1` is the key `dry-run`), and a dash in the
/// value is data. Stripping is a command-line convention and is not applied by
/// `TomEnvFile.parse`, which takes a variable name as it is written — the one
/// place the two sources part company by design.
///
/// An argument whose key is empty is **skipped**: an empty argument, one that
/// starts with `=` so that nothing precedes the separator, and one whose key is
/// nothing but dashes (`--`, the conventional end-of-options marker) all name
/// no field and are dropped rather than recorded under an empty key. Apart from
/// the dashes this is the rule `TomEnvFile.parse` applies. Skipping is per
/// argument — the arguments around a malformed one are still parsed.
class TomArgs {
  /// Fills [fillIn] from `key=value` [args] using reflection and returns it.
  ///
  /// Each `key=value` argument becomes a field assignment on [fillIn]: the key
  /// is the text before the first `=` with its leading dashes stripped, the
  /// value is everything after it, and the value is type-converted (see
  /// [convertToObjectMap]). So `--port=8080` and `port=8080` both assign the
  /// field `port`. A bare flag (`--verbose`) is recorded as the boolean `true`,
  /// matching how `key=true` converts, so it fills a reflected `bool` field
  /// directly. An argument whose key is empty, or nothing but dashes, is
  /// skipped and never reaches [fillIn].
  ///
  /// [T] must be a type registered with the reflection system
  /// (`tomReflectionInfo.setValues` performs the assignment); unknown keys that
  /// do not map to a field are ignored by the reflection layer.
  ///
  /// **Deliberately tolerant, not an oversight.** The shared
  /// [tomReflectionInfo] is used rather than a
  /// `TomReflectionInfo(strictUnknownFields: true)`, so a typo'd `--prot=8080`
  /// is dropped and the field keeps its default instead of failing the start.
  /// Strictness is wrong *here* for two reasons that are properties of a
  /// command line rather than of this method. A wrapper script routinely hands
  /// one flag set to several tools, so every flag meant for another one would
  /// become fatal. And a bare flag is recorded as `key=true`, which puts every
  /// undeclared switch — `--verbose`, `--dry-run` — in the same category. A
  /// caller that does want an unrecognised option to stop the process should
  /// compare the parsed keys against what it declares and say so itself, which
  /// is a decision about that program rather than about argument parsing.
  static T fillFromArgs<T extends Object>(List<String> args, T fillIn) {
    tomReflectionInfo.setValues<T>(fillIn, _parseArgs(args));
    return fillIn;
  }

  /// Matches an optional `-` and then an unpadded run of digits — `0` itself,
  /// or a run starting with a non-zero digit. A value is parsed as an `int`
  /// only when this pattern matches the *whole* string, so trailing text keeps
  /// the value a `String` (`12px`), and so does a sign with nothing a number
  /// can be made of after it (`-`, `-abc`).
  ///
  /// **A `-` is admitted and a `+` is not**, which is the padding rule rather
  /// than an omission. A `-` is never decorative: it changes the value it
  /// introduces, and without it a negative setting could not reach a numeric
  /// field from any source. A `+` in front of a digit run *is* decorative — it
  /// is how an international phone number is written — so converting
  /// `+4917612345678` would produce a different identifier and report nothing,
  /// exactly as `007` → `7` would. The cost lands where it is loud instead of
  /// where it is silent: `+5` against an `int` field is refused at assignment,
  /// naming the key.
  ///
  /// The padding restriction is part of the rule, not a quirk of the regular
  /// expression. A leading zero is only ever written when the zeros carry
  /// meaning — nobody writes `port=08080` intending 8080 — so a padded run is
  /// an identifier: a phone number written with its international prefix, a
  /// zero-padded account or article number, a postcode, a country code.
  /// Converting one produces a *different* identifier and reports nothing, so
  /// `007` stays the `String` `007`, and so does `-007`: the sign is judged
  /// first and the run after it exactly as an unsigned one is. A lone `0` is
  /// not padding and converts to the `int` 0.
  ///
  /// Matching is necessary but not sufficient: the pattern constrains shape,
  /// not magnitude, and a run too long for a 64-bit `int` also stays a
  /// `String`. The two ends are not mirrors — two's complement reaches one
  /// further down than up — so `-9223372036854775808` converts and
  /// `9223372036854775808` does not.
  static final RegExp intPattern = RegExp("-?(?:0|[1-9][0-9]*)");

  /// Matches an optional `-` and then a decimal number (`digits . digits*`). A
  /// value is parsed as a `double` only when this pattern matches the *whole*
  /// string and it is not already an `int`; a missing integer part keeps the
  /// value a `String` (`.5` and `-.5` stay strings).
  ///
  /// The sign follows [intPattern]'s rule for the same reason: `-1.5` is a
  /// quantity, while a leading `+` is decoration an identifier may carry, so
  /// `+1.5` stays a `String`.
  ///
  /// The integer part obeys the same padding rule as [intPattern] — it is a
  /// digit run and loses its zeros the same way — so `00.5` stays a `String`
  /// while `0.5` converts. The *fractional* part is deliberately unrestricted:
  /// a trailing zero after the point is not identity, since `1.50` and `1.5`
  /// are one quantity, whereas `007` and `7` are two identifiers.
  ///
  /// The fractional part is `*`, zero or more digits — not one optional digit.
  /// So `3.14` converts, and so does a value ending in a bare `.`: `5.` becomes
  /// the `double` `5.0` rather than staying a `String`.
  static final RegExp doublePattern = RegExp("-?(?:0|[1-9][0-9]*)[.][0-9]*");

  /// Parses `key=value` [args] into a loose map, type-converting each value.
  ///
  /// `key=value` becomes `key -> convertedValue`, split on the first `=` (see
  /// [convertToObjectMap] for the conversion table); a bare flag becomes
  /// `flag -> true` (boolean). A key is stripped of its leading dashes, so
  /// `--port=8080` returns `port -> 8080` and the returned map never carries a
  /// key beginning with `-`. An argument with an empty key contributes no
  /// entry, so the map never carries an empty key either.
  static Map<String, dynamic> parseArgsToMap(List<String> args) =>
      _parseArgs(args);

  /// Converts every value in a string [map] to its natural Dart type.
  ///
  /// Useful for normalising an environment map such as `Platform.environment`.
  /// Each value is converted as follows:
  ///
  /// | Input | Result |
  /// | ----- | ------ |
  /// | `"true"` / `null` | `bool` `true` |
  /// | `"false"` | `bool` `false` |
  /// | wrapped in a matched pair of `"` or `'` | the unquoted contents |
  /// | an optional `-`, then digits, unpadded, and it fits a 64-bit `int` | `int` |
  /// | an optional `-`, then a decimal, `digits . digits*` (`5.` included), integer part unpadded | `double` |
  /// | anything else | the original `String` |
  ///
  /// Quotes are only stripped as a **pair** (see [unquote]): an unbalanced
  /// quote is not a quoted value, so a lone `"` and an unterminated `"hello`
  /// are both passed through unchanged rather than truncated.
  ///
  /// Three restrictions on a digit run are part of the rule rather than edge
  /// cases, and all three say the same thing: a type is produced only when it
  /// can carry the value faithfully, and otherwise the text arrives as it was
  /// written rather than as something else.
  ///
  /// - **Magnitude.** Dart's `int` is 64-bit, so a digit run larger than
  ///   `9223372036854775807` has no `int` to become and stays a `String` — an
  ///   account number or a device id arrives whole, rather than aborting the
  ///   parse.
  /// - **Padding.** A run with leading zeros stays a `String`, because the
  ///   zeros are part of the identifier and an `int` has no notion of them:
  ///   `007` would arrive as `7`, and a phone number as a different phone
  ///   number, with nothing reporting the change (see [intPattern]). A lone
  ///   `0` is not padding and converts. The consequence a deployment sees is
  ///   that a padded number no longer reaches an `int` field at all —
  ///   `port=08080` is refused at assignment instead of silently binding 8080.
  /// - **Sign.** A leading `-` is part of the number (`offset=-5` is the `int`
  ///   `-5`), because it changes the value and a negative setting must be able
  ///   to reach a numeric field. A leading `+` is not, because it is how an
  ///   international phone number is written and dropping it yields a
  ///   different identifier — the padding rule again, in its other spelling.
  ///   Quoting is the escape in both directions: `"-5"` stays the text `-5`.
  static Map<String, dynamic> convertToObjectMap(Map<String, String> map) {
    Map<String, dynamic> result = {};
    for (var key in map.keys) {
      result[key] = _convertString(map[key]);
    }
    return result;
  }

  /// Matches a name written in `SCREAMING_SNAKE_CASE`: an upper-case or digit
  /// run, then any number of further runs each introduced by one `_`.
  ///
  /// Anchored at both ends, so the whole name must be of that shape. A name
  /// that is only partly upper-case (`Mixed_Case`), one that starts or ends on
  /// the separator (`_LEADING`, `TRAILING_`), and one written in any other
  /// convention are all outside it — see [resolveEnvironmentNames] for why a
  /// near miss is left alone rather than approximated.
  ///
  /// The first character is `[A-Z]` rather than `[A-Z0-9]` because a name
  /// beginning with a digit has no field to name: a Dart identifier cannot.
  static final RegExp environmentNamePattern = RegExp(
    r"^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$",
  );

  /// Returns the `lowerCamelCase` field name a `SCREAMING_SNAKE_CASE`
  /// environment variable [name] spells, or null when [name] is not written in
  /// that convention.
  ///
  /// The separator is the underscore and nothing else. A digit does not open a
  /// segment, so `OAUTH2_TOKEN_URI` is three segments and becomes
  /// `oauth2TokenUri` — splitting on the digit instead would produce
  /// `oAuth2TokenUri`, a field nobody declared.
  ///
  /// Each segment after the first contributes one capital and then lower case,
  /// which is the same rule the configuration fields are written under
  /// (`jwtRsaPubKey`, `smsApiKey`, `listenToAnyIp` — an acronym is a word,
  /// not a run of capitals). So the mapping is total: every configuration
  /// field's environment variable is its name in `SCREAMING_SNAKE_CASE`, and
  /// `configuration_test.dart` holds every field of the base configuration to
  /// that.
  static String? fieldNameOf(String name) {
    if (!environmentNamePattern.hasMatch(name)) return null;

    final segments = name.toLowerCase().split('_');
    final buffer = StringBuffer(segments.first);
    for (final segment in segments.skip(1)) {
      buffer
        ..write(segment[0].toUpperCase())
        ..write(segment.substring(1));
    }
    return buffer.toString();
  }

  /// Returns [source] with, for every `SCREAMING_SNAKE_CASE` key, an added
  /// entry under the field name it spells (see [fieldNameOf]).
  ///
  /// This is what lets a deployment write `JWT_SHARED_SECRET_KEY` — the
  /// spelling every `.env` file, container platform and CI secret store uses —
  /// and reach the `jwtSharedSecretKey` field, which before this was settable
  /// only by a variable literally named `jwtSharedSecretKey`. The mapping is
  /// mechanical and total in one direction, so a reader can predict the
  /// variable for any field without consulting a table of special cases.
  ///
  /// Two rules keep it from taking anything away:
  ///
  /// - **The original key is kept.** The alias is added alongside, so a
  ///   `${VAR}` datasource placeholder or any other verbatim reader is
  ///   unaffected.
  /// - **A key already spelled as the field wins.** It names the target
  ///   literally, with no convention in between, so a deployment that used the
  ///   exact name is never overruled by a variable it did not know also aimed
  ///   there.
  ///
  /// A name outside the convention contributes no alias at all. Approximating
  /// one would be guessing, and a guess that happened to match a declared field
  /// would bind a value nobody aimed at it — which is the failure this method
  /// exists to remove, not a cost worth paying to widen its reach.
  ///
  /// Apply this **per source**, before the sources are merged over one another:
  /// applied to an already-merged map, an alias derived from a low-precedence
  /// source would outrank a high-precedence exact key, reversing the documented
  /// order for exactly the keys the convention touches. See
  /// [TomBaseServerConfiguration.getDefaultValues].
  static Map<String, dynamic> resolveEnvironmentNames(
    Map<String, Object?> source,
  ) {
    final resolved = <String, dynamic>{};
    for (final entry in source.entries) {
      final fieldName = fieldNameOf(entry.key);
      if (fieldName != null && fieldName != entry.key) {
        resolved[fieldName] = entry.value;
      }
    }
    // The source last, so a key already spelled as the field overwrites the
    // alias derived from its screaming twin rather than the other way round.
    resolved.addAll(source);
    return resolved;
  }

  /// Splits each `key=value` entry of [args] on its **first** `=` and converts
  /// the value, returning the resulting map. An entry with no `=` is a flag and
  /// maps to the boolean `true`.
  ///
  /// The first `=` rather than every `=`, because everything after the
  /// separator is the value and may legitimately contain more of them — a
  /// connection string, a URL with a query, and a padded base64 blob all do.
  /// `TomEnvFile.parse` splits the same way, which is what lets the two sources
  /// be documented as one syntax rather than two that merely resemble each
  /// other.
  ///
  /// The key is then stripped of its leading `-` characters, so the
  /// conventional `--port=8080` names the field `port`. See [_withoutLeadingDashes].
  ///
  /// An argument whose key is empty (`""`, `"=orphan"`, `"="`), or is nothing
  /// but dashes and so empty once they are stripped (`"--"`), is skipped. Apart
  /// from the dashes that is the shape a `.env` file skips too.
  ///
  /// Both public entry points parse through here, so they cannot disagree.
  static Map<String, dynamic> _parseArgs(List<String> args) {
    var argMap = <String, dynamic>{};
    for (String arg in args) {
      var separator = arg.indexOf("=");
      final key = _withoutLeadingDashes(
        separator < 0 ? arg : arg.substring(0, separator),
      );
      // An empty key names nothing. On the fillFromArgs path it could never
      // match a field, so it would reach setValues as dead weight; and
      // `TomEnvFile.parse` skips it, so accepting it here would make the same
      // text mean different things in the two sources. A key of only dashes
      // arrives here empty and is dropped the same way, which is what a bare
      // `--` end-of-options marker needs.
      // Skipped rather than fatal: one malformed argument must not cost the
      // launch line the arguments around it.
      if (key.isEmpty) {
        continue;
      }
      if (separator < 0) {
        argMap[key] = true;
      } else {
        argMap[key] = _convertString(arg.substring(separator + 1));
      }
    }
    return argMap;
  }

  /// Returns [key] without the `-` characters it begins with.
  ///
  /// This is what makes `--port=8080` and `port=8080` one argument, so that the
  /// spelling every command line uses can also name a field: `setValues` is
  /// given the key as a field name, and no Dart class declares `--port`.
  ///
  /// The whole leading run is removed rather than one or two characters. There
  /// is then no arity to remember and no difference between the short and long
  /// prefixes, and a third dash is a typo in the prefix rather than the first
  /// character of a name — a name that begins with `-` is not reachable this
  /// way, which is the price of the convention.
  ///
  /// Only the leading run. A dash inside a name is part of it (`--dry-run`
  /// names `dry-run`), and the value is not touched at all, so a negative
  /// number or a `-` standing for stdin survives.
  static String _withoutLeadingDashes(String key) {
    var start = 0;
    while (start < key.length && key[start] == '-') {
      start++;
    }
    return start == 0 ? key : key.substring(start);
  }

  /// Returns the contents of [value] with its surrounding quotes removed, or
  /// `null` if [value] is not a quoted literal.
  ///
  /// A value is quoted only when its quotes form a **pair**: it is at least two
  /// characters long, starts with `"` or `'`, and ends with that same
  /// character. `""` is therefore a quoted literal whose contents are empty,
  /// while a lone `"`, an unterminated `"hello`, and a mismatched `"hello'` are
  /// not quoted at all and yield `null` so the caller can use them verbatim.
  ///
  /// Requiring the pair is what keeps a stray quote harmless. Dropping the
  /// first and last character on the strength of the opening quote alone
  /// truncates an unterminated value (`"hello` → `hello` minus its last
  /// character), and on a one-character value it asks for `substring(1, 0)` —
  /// a `RangeError` that names neither the key nor the file it came from.
  ///
  /// Both this class and `TomEnvFile.parse` decide through here, so the two
  /// sources cannot disagree about what counts as quoted.
  static String? unquote(String value) {
    if (value.length < 2) {
      return null;
    }
    final quote = value[0];
    if (quote != '"' && quote != "'") {
      return null;
    }
    if (!value.endsWith(quote)) {
      return null;
    }
    return value.substring(1, value.length - 1);
  }

  /// Converts a single string [value] to its natural Dart type. See
  /// [convertToObjectMap] for the conversion table.
  static Object _convertString(String? value) {
    if (value == "true" || value == null) {
      return true;
    }
    if (value == "false") {
      return false;
    }
    final unquoted = unquote(value);
    if (unquoted != null) {
      return unquoted;
    }
    if (intPattern.stringMatch(value) == value) {
      // tryParse, not parse: the pattern says "an unpadded digit run", which
      // is a claim about shape and not about magnitude. Dart's int is 64-bit,
      // so a longer run has no int to become and tryParse returns null — the
      // value then falls through to the String at the end, exactly as `+5`,
      // `12px` and `007` do. parse would instead throw a FormatException
      // naming neither the key nor the source, aborting the whole parse over
      // one account number.
      final asInt = int.tryParse(value);
      if (asInt != null) {
        return asInt;
      }
    }
    if (doublePattern.stringMatch(value) == value) {
      return double.parse(value);
    }
    return value;
  }
}
