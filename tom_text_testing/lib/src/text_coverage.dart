/// The coverage check of the internationalisation guideline (section 7 of the
/// workspace guideline `_agent_guidelines/i18n.md`): a package's resource
/// files and its code held to each other.
library;

import 'dart:convert';
import 'dart:io';

import 'dart_source.dart';
import 'element_kinds.dart';
import 'package_texts.dart';

/// Where code names a text id: a named argument (`tomId: '...'`) or the
/// first argument of a call (`TomCtr.resolvePath('...')`,
/// `ForgeText('...')`), always as one string literal.
class TextIdCarrier {
  /// The named argument [name]: `tomId: 'rename.nameField'`. The literal is
  /// an element id.
  const TextIdCarrier.namedArgument(this.name)
    : callPattern = null,
      includesKey = false,
      paramsArgument = null;

  /// A call whose name (the code just before its `(`) matches [pattern]
  /// directly before the `(`: `r'\bForgeText'` finds `ForgeText('...')` but
  /// not `ForgeText.literal('...')`, `r'\bscope\.text'` finds
  /// `scope.text('...')`. The literal is its first argument.
  ///
  /// With [includesKey] the literal is an element id followed by one of its
  /// keys (`actions.saveAction.label`); with [paramsArgument] the call's
  /// named argument of that name is a map literal whose keys are the text's
  /// parameters (`params: {'name': ...}`), checked against the text's
  /// `{name}` placeholders.
  const TextIdCarrier.call(
    String pattern, {
    this.includesKey = false,
    this.paramsArgument,
  }) : callPattern = pattern,
       name = null;

  /// The named argument's name, for [TextIdCarrier.namedArgument].
  final String? name;

  /// The call's name pattern, for [TextIdCarrier.call].
  final String? callPattern;

  /// Whether the literal ends in a key of the element.
  final bool includesKey;

  /// The named argument holding the parameters, or null.
  final String? paramsArgument;

  /// `tomId: '...'`: every `tom_flutter_ui` widget.
  static const tomId = TextIdCarrier.namedArgument('tomId');

  /// `TomCtr.resolvePath('...', scope)`: a plain widget resolving an
  /// element's path to read its texts.
  static const resolvePath = TextIdCarrier.call(r'\bTomCtr\.resolvePath');

  /// The carriers every check knows.
  static const standard = [tomId, resolvePath];

  RegExp get _regExp => name != null
      ? RegExp('\\b${RegExp.escape(name!)}\\s*:\\s*')
      : RegExp('(?:$callPattern)\\s*\\(\\s*');

  @override
  String toString() => name != null ? '$name:' : '$callPattern(';
}

/// A string literal in `lib/` that the check would report as user-visible
/// but that is not, with the reason.
class AllowedLiteral {
  const AllowedLiteral({
    required this.file,
    required this.text,
    required this.reason,
  });

  /// The file, relative to the package root (`lib/src/x.dart`).
  final String file;

  /// The literal's text as it reads (escapes resolved, an interpolation as
  /// `${...}` is not matched: allow such a literal by its text with each
  /// interpolation written as `{}`).
  final String text;

  /// Why it is not translated.
  final String reason;
}

/// What a finding is about.
enum TextCoverageKind {
  /// The resource file breaks the shape of section 1 (top level, dotted key,
  /// `null`, list, a value that is neither a text nor a map).
  shape,

  /// An id the code uses is not in the file.
  missingId,

  /// A key the code uses (an id that includes its key) is not in the file.
  missingKey,

  /// An element of the file no code uses.
  unusedEntry,

  /// An entry with texts whose name ends in no type suffix of section 3.
  noSuffix,

  /// A key the element's kind does not allow.
  disallowedKey,

  /// A required key of the element's kind is missing.
  missingRequiredKey,

  /// The parameters a call passes and the text's placeholders differ.
  placeholders,

  /// A user-visible string literal left in `lib/`.
  literal,

  /// An allow-list entry no literal matches any more.
  unusedAllowance,

  /// Another language's file differs from the reference file.
  language,

  /// An id written with an interpolation, so no check can follow it.
  nonLiteralId,

  /// An id that names the package (the scope adds it).
  packageName,
}

/// One thing the coverage check found.
class TextCoverageFinding {
  const TextCoverageFinding({
    required this.kind,
    required this.message,
    required this.file,
    this.line,
    this.id,
    this.key,
  });

  /// What it is about.
  final TextCoverageKind kind;

  /// What is wrong, in a sentence.
  final String message;

  /// The file it is in, relative to the package root.
  final String file;

  /// The 1-based line, for a finding in code.
  final int? line;

  /// The id (element path) it is about, or null.
  final String? id;

  /// The key it is about, or null.
  final String? key;

  @override
  String toString() =>
      '[${kind.name}] $file${line == null ? '' : ':$line'}'
      '${id == null ? '' : ' $id${key == null ? '' : ' / $key'}'}: $message';
}

/// The coverage check's result.
class TextCoverageReport {
  const TextCoverageReport(this.packageName, this.findings);

  /// The package checked.
  final String packageName;

  /// Everything found, in the order of the checks.
  final List<TextCoverageFinding> findings;

  /// Whether nothing was found.
  bool get isClean => findings.isEmpty;

  /// The findings of [kind].
  List<TextCoverageFinding> ofKind(TextCoverageKind kind) => [
    for (final finding in findings)
      if (finding.kind == kind) finding,
  ];

  @override
  String toString() => isClean
      ? 'Text coverage of $packageName: clean'
      : 'Text coverage of $packageName: ${findings.length} finding(s)\n'
            '${findings.map((f) => '  $f').join('\n')}';
}

/// Thrown by [expectTextCoverage] when the check finds anything; the test
/// fails with its message.
class TextCoverageFailure implements Exception {
  TextCoverageFailure(this.report);

  /// The report.
  final TextCoverageReport report;

  @override
  String toString() => report.toString();
}

/// Calls whose string arguments are never shown to a user: log and trail
/// output, assertions, developer messages of errors and exceptions, keys,
/// patterns and URIs. Matched against the name of the call a literal is an
/// argument of.
const List<String> defaultNonUserCalls = [
  r'^(print|debugPrint|log|assert|Symbol|RegExp)$',
  r'[tT]rail$',
  r'^tomLog\.',
  r'(Error|Exception)$',
  r'^(Key|ValueKey|ObjectKey|GlobalKey|PageStorageKey|LocalKey)$',
  r'^Uri\.',
  r'^(DateFormat|NumberFormat)$',
];

/// Checks [packageName]'s resource files and code under [packageRoot]
/// (default: the current directory, the package root in its tests) against
/// each other, as section 7 of the guideline lists:
///
/// 1. every id the code uses is in `lib/resources/<package>_<reference>.json`
///    (and a key named with it, for a carrier that [TextIdCarrier.includesKey]);
/// 2. no element of the file is unused;
/// 3. every element's name ends in a type suffix of [kinds], with only
///    allowed keys and its required keys;
/// 4. the parameters a call passes match the text's `{name}` placeholders;
/// 5. no user-visible string literal is left in `lib/` (unless a call of
///    [nonUserCalls] or an entry of [allowedLiterals] says why not);
/// 6. every other language's file has the reference file's texts with the
///    same placeholders (plus plural forms of its own).
///
/// Ids are found where [carriers] say ([TextIdCarrier.standard] plus the
/// package family's own, such as `ForgeText`). [checkLiterals] off skips
/// point 5, for a package that is not migrated yet.
TextCoverageReport checkTextCoverage(
  String packageName, {
  String packageRoot = '.',
  String referenceLanguage = 'en',
  List<TextIdCarrier> carriers = const [],
  List<String> nonUserCalls = const [],
  List<AllowedLiteral> allowedLiterals = const [],
  TextElementKinds kinds = TextElementKinds.standard,
  bool checkLiterals = true,
}) => _Check(
  packageName: packageName,
  root: packageRoot,
  referenceLanguage: referenceLanguage,
  carriers: [...TextIdCarrier.standard, ...carriers],
  nonUserCalls: [
    for (final pattern in [...defaultNonUserCalls, ...nonUserCalls])
      RegExp(pattern),
  ],
  allowedLiterals: allowedLiterals,
  kinds: kinds,
  checkLiterals: checkLiterals,
).run();

/// Runs [checkTextCoverage] and throws a [TextCoverageFailure] naming every
/// finding unless the package is clean: one call in a package's
/// `test/i18n_coverage_test.dart`.
void expectTextCoverage(
  String packageName, {
  String packageRoot = '.',
  String referenceLanguage = 'en',
  List<TextIdCarrier> carriers = const [],
  List<String> nonUserCalls = const [],
  List<AllowedLiteral> allowedLiterals = const [],
  TextElementKinds kinds = TextElementKinds.standard,
  bool checkLiterals = true,
}) {
  final report = checkTextCoverage(
    packageName,
    packageRoot: packageRoot,
    referenceLanguage: referenceLanguage,
    carriers: carriers,
    nonUserCalls: nonUserCalls,
    allowedLiterals: allowedLiterals,
    kinds: kinds,
    checkLiterals: checkLiterals,
  );
  if (!report.isClean) throw TextCoverageFailure(report);
}

/// An element of a resource file: its path, kind and keys with their texts.
class _Element {
  _Element(this.path, this.kind);

  final String path;
  final TextElementKind? kind;
  final Map<String, String> texts = {};
}

/// A use of an id in code.
class _Use {
  _Use(this.id, this.file, this.line, this.carrier, this.params);

  final String id;
  final String file;
  final int line;
  final TextIdCarrier carrier;
  final Set<String>? params;
}

class _Check {
  _Check({
    required this.packageName,
    required this.root,
    required this.referenceLanguage,
    required this.carriers,
    required this.nonUserCalls,
    required this.allowedLiterals,
    required this.kinds,
    required this.checkLiterals,
  });

  final String packageName;
  final String root;
  final String referenceLanguage;
  final List<TextIdCarrier> carriers;
  final List<RegExp> nonUserCalls;
  final List<AllowedLiteral> allowedLiterals;
  final TextElementKinds kinds;
  final bool checkLiterals;

  final findings = <TextCoverageFinding>[];
  final elements = <String, _Element>{};

  late final String referenceFile = textResourcePath(
    packageName,
    referenceLanguage,
  );

  void _add(
    TextCoverageKind kind,
    String file,
    String message, {
    int? line,
    String? id,
    String? key,
  }) => findings.add(
    TextCoverageFinding(
      kind: kind,
      message: message,
      file: file,
      line: line,
      id: id,
      key: key,
    ),
  );

  TextCoverageReport run() {
    final reference = _readFile(referenceFile);
    if (reference != null) _collectElements(reference, '', referenceFile);
    final uses = _scanCode();
    _checkUses(uses);
    _checkLanguages(reference);
    return TextCoverageReport(packageName, List.unmodifiable(findings));
  }

  // --- the resource files -------------------------------------------------

  /// The block of [relative] under the package name, or null (with a shape
  /// finding) when it cannot be used.
  Map<String, dynamic>? _readFile(String relative) {
    final file = File('$root/$relative');
    if (!file.existsSync()) {
      _add(TextCoverageKind.shape, relative, 'the resource file is missing');
      return null;
    }
    final Object? json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } on FormatException catch (error) {
      _add(TextCoverageKind.shape, relative, 'not JSON: ${error.message}');
      return null;
    }
    if (json is! Map<String, dynamic> ||
        json.length != 1 ||
        json[packageName] is! Map<String, dynamic>) {
      _add(
        TextCoverageKind.shape,
        relative,
        'the top level must be the one key "$packageName" holding an object',
      );
      return null;
    }
    final block = json[packageName] as Map<String, dynamic>;
    _checkShape(block, '', relative);
    return block;
  }

  void _checkShape(Map<String, dynamic> map, String path, String file) {
    for (final entry in map.entries) {
      final at = path.isEmpty ? entry.key : '$path.${entry.key}';
      final value = entry.value;
      if (entry.key.contains('.')) {
        _add(
          TextCoverageKind.shape,
          file,
          'a dotted key; nest it instead',
          id: at,
        );
      }
      if (value is Map<String, dynamic>) {
        _checkShape(value, at, file);
      } else if (value == null) {
        _add(
          TextCoverageKind.shape,
          file,
          'null; leave an untranslated entry out instead',
          id: at,
        );
      } else if (value is List) {
        _add(TextCoverageKind.shape, file, 'a list; texts only', id: at);
      } else if (value is! String) {
        _add(
          TextCoverageKind.shape,
          file,
          'a ${value.runtimeType}; texts only',
          id: at,
        );
      }
    }
  }

  /// Walks [map] (at [path]) for elements: an entry whose name ends in a type
  /// suffix, or that holds texts directly.
  void _collectElements(Map<String, dynamic> map, String path, String file) {
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final at = path.isEmpty ? entry.key : '$path.${entry.key}';
      final kind = kinds.kindOf(entry.key);
      final holdsTexts = value.values.any((v) => v is String);
      if (kind == null && !holdsTexts) {
        _collectElements(value, at, file);
        continue;
      }
      final element = _Element(at, kind);
      elements[at] = element;
      _collectKeys(element, value, '', file);
      if (kind == null) {
        _add(
          TextCoverageKind.noSuffix,
          file,
          '"${entry.key}" holds texts but ends in no type suffix of the '
          'guideline (nameText, saveButton, ...)',
          id: at,
        );
        continue;
      }
      for (final key in element.texts.keys) {
        if (!kind.allows(key)) {
          _add(
            TextCoverageKind.disallowedKey,
            file,
            'a ${kinds.suffixOf(entry.key)} (${kind.description}) allows '
            '${kind.allowed.join(', ')}',
            id: at,
            key: key,
          );
        }
      }
      final missing = kind.missingRequired(element.texts.keys.toSet());
      if (missing.isNotEmpty) {
        _add(
          TextCoverageKind.missingRequiredKey,
          file,
          'a ${kinds.suffixOf(entry.key)} requires ${kind.requiredText}; '
          'missing ${missing.join(', ')}',
          id: at,
          key: missing.first,
        );
      }
    }
  }

  /// Adds [map]'s texts to [element] under [prefix]; a map named by a type
  /// suffix is an element of its own.
  void _collectKeys(
    _Element element,
    Map<String, dynamic> map,
    String prefix,
    String file,
  ) {
    for (final entry in map.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      if (value is String) {
        element.texts[key] = value;
      } else if (value is Map<String, dynamic>) {
        if (prefix.isEmpty && kinds.kindOf(entry.key) != null) {
          _collectElements({entry.key: value}, element.path, file);
        } else {
          _collectKeys(element, value, key, file);
        }
      }
    }
  }

  // --- the code -------------------------------------------------------------

  List<_Use> _scanCode() {
    final uses = <_Use>[];
    final lib = Directory('$root/lib');
    if (!lib.existsSync()) return uses;
    final files =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.path.endsWith('.g.dart') &&
                  !f.path.endsWith('.freezed.dart'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final usedAllowances = <AllowedLiteral>{};
    for (final file in files) {
      final relative = _relative(file.path);
      final source = DartSource.parse(file.readAsStringSync());
      final idLiterals = <int>{};
      for (final carrier in carriers) {
        for (final match in carrier._regExp.allMatches(source.masked)) {
          final literal = source.literalAt(match.end);
          if (literal == null) continue;
          idLiterals.add(literal.start);
          if (literal.interpolated) {
            _add(
              TextCoverageKind.nonLiteralId,
              relative,
              'an id with an interpolation; write each id as one literal '
              '(a switch answers the literal ids)',
              line: literal.line,
              id: literal.value.replaceAll(
                DartStringLiteral.interpolationMark,
                r'${}',
              ),
            );
            continue;
          }
          uses.add(
            _Use(
              literal.value,
              relative,
              literal.line,
              carrier,
              carrier.paramsArgument == null
                  ? null
                  : _params(source, match, carrier.paramsArgument!),
            ),
          );
        }
      }
      if (checkLiterals) {
        _checkLiterals(source, relative, idLiterals, usedAllowances);
      }
    }
    if (checkLiterals) {
      for (final allowed in allowedLiterals) {
        if (!usedAllowances.contains(allowed)) {
          _add(
            TextCoverageKind.unusedAllowance,
            allowed.file,
            'the allow-list names "${allowed.text}", which is no longer in '
            'the file; remove the entry',
          );
        }
      }
    }
    return uses;
  }

  /// The keys of the map literal passed as [argument] in the call whose id
  /// [match] found; an empty set when the call passes none.
  Set<String> _params(DartSource source, Match match, String argument) {
    final close = source.closingParen(match.end);
    final args = source.masked.substring(match.end, close);
    final named = RegExp(
      '\\b${RegExp.escape(argument)}\\s*:\\s*(?:const\\s*)?(?:<[^>]*>\\s*)?\\{',
    ).firstMatch(args);
    if (named == null) return {};
    final open = match.end + named.end;
    final end = source.closingParen(open);
    final keys = <String>{};
    var depth = 0;
    for (var i = open; i < end; i++) {
      final c = source.masked.codeUnitAt(i);
      if (c == 0x28 || c == 0x5B || c == 0x7B) depth++;
      if (c == 0x29 || c == 0x5D || c == 0x7D) depth--;
      if (depth != 0) continue;
      final literal = source.literalAt(i);
      if (literal == null) continue;
      final after = source.masked.substring(literal.end).trimLeft();
      if (after.startsWith(':')) keys.add(literal.value);
      i = literal.end - 1;
    }
    return keys;
  }

  void _checkLiterals(
    DartSource source,
    String relative,
    Set<int> idLiterals,
    Set<AllowedLiteral> usedAllowances,
  ) {
    for (final literal in source.literals) {
      if (idLiterals.contains(literal.start)) continue;
      final shown = literal.value.replaceAll(
        DartStringLiteral.interpolationMark,
        '{}',
      );
      if (!_looksUserVisible(shown)) continue;
      if (_isDirective(source, literal)) continue;
      final call = source.enclosingCall(literal.start);
      if (call != null && nonUserCalls.any((p) => p.hasMatch(call))) continue;
      final outer = source.literalAround(literal.start);
      if (outer != null && outer.start != literal.start) {
        // Inside an interpolation: the outer literal is judged already.
        continue;
      }
      AllowedLiteral? allowance;
      for (final allowed in allowedLiterals) {
        if (allowed.text == shown && relative.endsWith(allowed.file)) {
          allowance = allowed;
          break;
        }
      }
      if (allowance != null) {
        usedAllowances.add(allowance);
        continue;
      }
      _add(
        TextCoverageKind.literal,
        relative,
        'a user-visible literal "$shown"; move it into $referenceFile and '
        'name it by id, or allow-list it with the reason it is not '
        'translated',
        line: literal.line,
      );
    }
  }

  static final RegExp _sentence = RegExp(r'[A-Za-z]{2,}[^ ]* +[^ ]*[A-Za-z]');
  static final RegExp _word = RegExp(r'^[A-Z][a-z]+[.…!?:]*$');

  /// A heuristic: two words with a space between, or one capitalised word
  /// (`Save`, `Cancel…`). Ids, paths, keys and patterns have neither.
  bool _looksUserVisible(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('://')) return false;
    return _sentence.hasMatch(trimmed) || _word.hasMatch(trimmed);
  }

  /// Whether [literal] is the URI of an `import`, `export` or `part`.
  bool _isDirective(DartSource source, DartStringLiteral literal) {
    final lineStart = source.masked.lastIndexOf('\n', literal.start) + 1;
    final head = source.masked.substring(lineStart, literal.start).trim();
    return RegExp(r'^(import|export|part(\s+of)?)$').hasMatch(head);
  }

  String _relative(String path) {
    final prefix = '$root/';
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
  }

  // --- uses against the file -----------------------------------------------

  void _checkUses(List<_Use> uses) {
    final used = <String>{};
    for (final use in uses) {
      if (use.id == packageName || use.id.startsWith('$packageName.')) {
        _add(
          TextCoverageKind.packageName,
          use.file,
          'the id names the package; ids are relative to the package, the '
          'scope adds its name',
          line: use.line,
          id: use.id,
        );
      }
      _Element? element;
      String? key;
      if (use.carrier.includesKey) {
        for (final candidate in elements.values) {
          if (use.id.startsWith('${candidate.path}.') &&
              (element == null ||
                  candidate.path.length > element.path.length)) {
            element = candidate;
          }
        }
        if (element != null) key = use.id.substring(element.path.length + 1);
      } else {
        element = elements[use.id];
      }
      if (element == null) {
        _add(
          TextCoverageKind.missingId,
          use.file,
          'used by ${use.carrier} but not in $referenceFile',
          line: use.line,
          id: use.id,
        );
        continue;
      }
      used.add(element.path);
      if (key != null && !element.texts.containsKey(key)) {
        _add(
          TextCoverageKind.missingKey,
          use.file,
          'used by ${use.carrier} but $referenceFile has no such key',
          line: use.line,
          id: element.path,
          key: key,
        );
        continue;
      }
      final params = use.params;
      if (params != null) {
        final placeholders = key != null
            ? _placeholders(element.texts[key]!)
            : {for (final text in element.texts.values) ..._placeholders(text)};
        final unknown = params.difference(placeholders);
        final missing = placeholders.difference(params);
        if (unknown.isNotEmpty || missing.isNotEmpty) {
          _add(
            TextCoverageKind.placeholders,
            use.file,
            [
              if (missing.isNotEmpty)
                'the text has {${missing.join('}, {')}}, which the call does '
                    'not pass',
              if (unknown.isNotEmpty)
                'the call passes ${unknown.join(', ')}, which the text does '
                    'not hold',
            ].join('; '),
            line: use.line,
            id: element.path,
            key: key,
          );
        }
      }
    }
    for (final element in elements.values) {
      if (!used.contains(element.path)) {
        _add(
          TextCoverageKind.unusedEntry,
          referenceFile,
          'no code uses this element; remove it or use it',
          id: element.path,
        );
      }
    }
  }

  static final RegExp _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}');

  Set<String> _placeholders(String text) => {
    for (final match in _placeholder.allMatches(text)) match.group(1)!,
  };

  // --- the other languages -------------------------------------------------

  void _checkLanguages(Map<String, dynamic>? reference) {
    if (reference == null) return;
    final dir = Directory('$root/lib/resources');
    if (!dir.existsSync()) return;
    final expected = _flatten(reference);
    final pattern = RegExp(
      '^${RegExp.escape(packageName)}_([A-Za-z_]+)\\.json\$',
    );
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final match = pattern.firstMatch(name);
      if (match == null || match.group(1) == referenceLanguage) continue;
      final relative = 'lib/resources/$name';
      final block = _readFile(relative);
      if (block == null) continue;
      final actual = _flatten(block);
      for (final path in expected.keys) {
        if (!actual.containsKey(path)) {
          _add(
            TextCoverageKind.language,
            relative,
            'missing; $referenceFile has it',
            id: path,
          );
        } else if (!_samePlaceholders(expected[path]!, actual[path]!)) {
          _add(
            TextCoverageKind.language,
            relative,
            'its placeholders differ from $referenceFile\'s '
            '(${_placeholders(expected[path]!).join(', ')})',
            id: path,
          );
        }
      }
      for (final path in actual.keys) {
        if (expected.containsKey(path) || _isExtraPluralForm(path, expected)) {
          continue;
        }
        _add(
          TextCoverageKind.language,
          relative,
          'not in $referenceFile',
          id: path,
        );
      }
    }
  }

  bool _samePlaceholders(String a, String b) {
    final pa = _placeholders(a);
    final pb = _placeholders(b);
    return pa.length == pb.length && pa.containsAll(pb);
  }

  /// A plural form a language adds (`zero`, `two`, `few`) beside the
  /// reference's `one` / `many`.
  bool _isExtraPluralForm(String path, Map<String, String> expected) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    final form = path.substring(dot + 1);
    final element = path.substring(0, dot);
    return const {'zero', 'two', 'few'}.contains(form) &&
        expected.containsKey('$element.one') &&
        expected.containsKey('$element.many');
  }

  Map<String, String> _flatten(Map<String, dynamic> map, [String path = '']) {
    final out = <String, String>{};
    for (final entry in map.entries) {
      final at = path.isEmpty ? entry.key : '$path.${entry.key}';
      final value = entry.value;
      if (value is String) {
        out[at] = value;
      } else if (value is Map<String, dynamic>) {
        out.addAll(_flatten(value, at));
      }
    }
    return out;
  }
}
