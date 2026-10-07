import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// What the timezoned module's conditional import selects, whether the
/// selected file can run where it is selected, and whether the documentation
/// says the same thing.
///
/// `timezones.dart` picks its initializer with a conditional import:
///
/// ```dart
/// import 'init_tz_embedded.dart' if (dart.library.js) 'init_tz_web.dart';
/// ```
///
/// The first entry is the **default** arm, taken wherever no condition holds.
/// That is the position with the strongest requirement in the whole construct
/// and the easiest to misjudge: an arm reached where nothing can be assumed
/// must assume nothing, so it may not touch `dart:io` any more than it may
/// touch `dart:js`. The embedded database qualifies — it is a constant and a
/// decoder — and it is the default for exactly that reason.
///
/// Both mistakes this file guards against were invisible from one side alone.
/// A default arm that pulled in `dart:io` looked fine in isolation, because
/// nothing in the file names the condition that would exclude it, and it
/// compiled everywhere anyone ever built. And prose that credited the wrong
/// platform with the wrong entry point looked fine too, because the source is
/// correct and says nothing about platforms while the prose names platforms
/// and quotes no condition. So the tests hold the pieces together:
///
/// - the `import` and `export` arms stay identical, which the source asks for
///   in a comment and nothing else enforces;
/// - each arm's file says which selection it serves;
/// - no arm reaches a `dart:` library its own condition rules out, following
///   the imports through the `timezone` package to find out;
/// - the documentation quotes the block as written;
/// - every `package:timezone/…` library the documentation names is one the
///   module imports;
/// - every "*this entry point on that platform*" claim names a library the
///   platform's own arm actually reaches.
void main() {
  // ===========================================================================
  // The selection itself
  // ===========================================================================
  group('conditional import', () {
    test('the import and export arms select the same files', () {
      final import = _selection('import');
      final export = _selection('export');

      // `timezones.dart` re-exports the same configuration it imports, because
      // an import alone would not carry `tomSetupTimezones` out to the barrel.
      // Two copies of one decision drift, and the drift is silent: the package
      // would export one platform's implementation while calling another's.
      expect(export.defaultArm, import.defaultArm);
      expect(export.arms, import.arms);
    });

    test('each arm says which selection it serves', () {
      final selection = _selection('import');

      expect(
        _dartdoc(selection.defaultArm),
        contains('default'),
        reason:
            'The first entry of a conditional import is the default arm, taken '
            'wherever no condition holds. Whatever file sits there should say '
            'so, because nothing about its name or its contents reveals the '
            'position it occupies — and that position carries a requirement '
            'none of the other arms carry.',
      );

      for (final arm in selection.arms.entries) {
        final word = _armSelfDescription[arm.key];
        expect(
          word,
          isNotNull,
          reason:
              'The conditional import grew an arm on ${arm.key} with no entry '
              'in _armSelfDescription. Say what that arm ought to call itself, '
              'or this test quietly stops covering it.',
        );
        expect(
          _dartdoc(arm.value),
          contains(word!),
          reason:
              '${arm.value} is selected on ${arm.key} but its dartdoc never '
              'says so, leaving the file name as the only clue to where it '
              'runs. File names are what misled the documentation before.',
        );
      }
    });
  });

  // ===========================================================================
  // Whether each arm can run where it is selected
  // ===========================================================================
  group('platform reachability', () {
    test('no arm reaches a library its own condition rules out', () {
      final selection = _selection('import');
      final offenders = <String>[];
      var filesWalked = 0;

      for (final arm in _armsByCondition(selection).entries) {
        final walk = _walkTimezoneImports(arm.value);
        filesWalked += walk.visited.length;
        final forbidden = _forbiddenUnder(arm.key);
        for (final reached in walk.platformLibraries.entries) {
          final banned = reached.value.where(forbidden.contains);
          if (banned.isEmpty) continue;
          offenders.add(
            '${arm.value} (selected ${_describe(arm.key)}) reaches '
            '${reached.key}, which imports ${banned.join(', ')}',
          );
        }
      }

      expect(
        filesWalked,
        greaterThan(selection.arms.length + 1),
        reason:
            'The walk visited no more files than the arms it started from, so '
            'it is not following imports into the timezone package any more '
            'and this test is checking nothing.',
      );
      expect(offenders, isEmpty, reason: _unreachableLibraryReason);
    });
  });

  // ===========================================================================
  // How the arm that cannot run here refuses
  // ===========================================================================
  group('the web arm refuses a synchronous load', () {
    // `timezone_throw_contract_test.dart` runs the refusal itself and asserts
    // it is a `StateError`; it can, because refusing asks nothing of the
    // platform. What it cannot do is reach the arm that raises it, so the two
    // halves are joined here: that file pins the shape, this one pins that the
    // browser's arm is what takes it.
    test('through the shared refusal rather than a second copy', () {
      final web = _armSource('dart.library.js');

      expect(
        web,
        contains(_refusal),
        reason:
            'The browser has no synchronous path to the database, and saying '
            'so is the whole body of its `tomSetupTimezonesSync`. It has to '
            'say it by calling `$_refusal`, because that is the form the VM '
            'suite can execute — a `throw` written out here instead would be '
            'asserted by reading this file, which is not a test of anything '
            'that runs.',
      );
      expect(
        web,
        isNot(contains('throw ')),
        reason:
            'A second `throw` in the web arm is a second refusal, and the one '
            'the suite executes would no longer be the one the browser meets.',
      );
    });

    test('and the native arm does not refuse at all', () {
      // The asymmetry is the module's whole initialization story: the embedded
      // database loads synchronously, so there is nothing to refuse. A refusal
      // appearing here would mean native lazy-init had stopped working, and
      // the failure would surface at every first access instead.
      expect(_armSource(null), isNot(contains(_refusal)));
    });
  });

  // ===========================================================================
  // What the documentation says about it
  // ===========================================================================
  group('platform documentation', () {
    test('the documented import block is the one in the source', () {
      final quoted = _quotedImportBlocks();

      expect(
        quoted,
        isNotEmpty,
        reason:
            'No document quotes the conditional import any more. Either the '
            'quotation was dropped — in which case delete this test — or its '
            'shape changed and the test is now checking nothing.',
      );
      for (final entry in quoted.entries) {
        expect(entry.value, _sourceImportBlock(), reason: entry.key);
      }
    });

    test(
      'every timezone library the documents name is one the module imports',
      () {
        final imported = _moduleTimezoneImports();
        final offenders = <String>[];

        for (final mention in _mentions(_namedTimezoneLibrary)) {
          if (imported.contains(mention.value)) continue;
          offenders.add('${mention.where}: `${mention.value}`');
        }

        expect(offenders, isEmpty, reason: _inventedLibraryReason);
      },
    );

    test('every entry point is credited to a platform whose arm imports it', () {
      final claims = _mentions(_platformClaim);
      final offenders = <String>[];

      for (final claim in claims) {
        final condition = _conditionFor(claim.qualifier!);
        final arm = condition == null
            ? _selection('import').defaultArm
            : _selection('import').arms[condition]!;
        if (_timezoneImportsOf(arm).any((i) => i.endsWith(claim.value))) {
          continue;
        }
        offenders.add(
          '${claim.where}: `${claim.value}` credited to ${claim.qualifier}, '
          'which takes $arm — and that file imports '
          '${_timezoneImportsOf(arm).join(', ')}',
        );
      }

      expect(
        claims.length,
        greaterThanOrEqualTo(3),
        reason:
            'Fewer than three platform claims found, so the scan has stopped '
            'reading the sentence it was written for. A rewrite that drops the '
            'form is fine; leaving this test passing on nothing is not.',
      );
      expect(offenders, isEmpty, reason: _misattributedEntryPointReason);
    });
  });
}

// -----------------------------------------------------------------------------
// Reading the source
// -----------------------------------------------------------------------------

/// The function each arm calls to refuse a synchronous load of the database.
const _refusal = 'refuseSynchronousTimezoneLoad';

/// The text of the arm selected by [condition], or of the default arm for
/// `null`.
String _armSource(String? condition) {
  final selection = _selection('import');
  final arm = condition == null
      ? selection.defaultArm
      : selection.arms[condition]!;
  return File('${_moduleDirectory.path}/$arm').readAsStringSync();
}

final _moduleDirectory = Directory('lib/src/tombase/timezoned');

/// The documents that describe this module: its own readme, the prose document
/// and the API summary.
final _documents = <File>[
  File('lib/src/tombase/timezoned/readme.md'),
  File('doc/timezoned/timezoned.md'),
  File('doc/api/api_summary_timezoned.md'),
];

/// The word each conditional arm's dartdoc has to contain to have described
/// where it runs. The default arm is not here — it is checked separately,
/// because what it has to say is about its position, not about a platform.
const _armSelfDescription = {
  'dart.library.io': 'native',
  'dart.library.js': 'browser',
};

/// One conditional directive: the default arm plus each `if (…)` arm.
class _Selection {
  _Selection(this.defaultArm, this.arms);

  final String defaultArm;
  final Map<String, String> arms;
}

/// Matches `import 'a.dart' if (c) 'b.dart' if (d) 'e.dart';` across lines,
/// for `directive` of `import` or `export`.
RegExp _directive(String directive) => RegExp(
  '$directive\\s+\'([\\w.]+)\'((?:\\s+if\\s*\\([^)]+\\)\\s*\'[\\w.]+\')+);',
);

final _arm = RegExp(r"if\s*\(([^)]+)\)\s*'([\w.]+)'");

_Selection _selection(String directive) {
  final source = File(
    'lib/src/tombase/timezoned/timezones.dart',
  ).readAsStringSync();
  final match = _directive(directive).firstMatch(source);
  if (match == null) {
    throw StateError(
      'No conditional $directive found in timezones.dart. If the module no '
      'longer selects its initializer this way, this test file is obsolete.',
    );
  }
  return _Selection(match.group(1)!, {
    for (final arm in _arm.allMatches(match.group(2)!))
      arm.group(1)!.trim(): arm.group(2)!,
  });
}

/// How a quotation of the conditional import begins, derived from the source
/// so that renaming the default arm cannot leave the scans looking for a file
/// that no longer exists — and silently finding nothing.
String _importOpening() => "import '${_selection('import').defaultArm}'";

/// The source's own rendering of the import, used to hold quotations to it.
String _sourceImportBlock() {
  final lines = File(
    'lib/src/tombase/timezoned/timezones.dart',
  ).readAsLinesSync();
  final start = lines.indexWhere((l) => l.startsWith(_importOpening()));
  final end = lines.indexWhere((l) => l.trimRight().endsWith(';'), start);
  return lines.sublist(start, end + 1).join('\n');
}

/// The leading `///` block of a module file, lower-cased.
String _dartdoc(String fileName) {
  final lines = File('${_moduleDirectory.path}/$fileName').readAsLinesSync();
  return lines
      .where((l) => l.trimLeft().startsWith('///'))
      .join('\n')
      .toLowerCase();
}

/// Every `package:timezone/…` URI imported anywhere in the module.
Set<String> _moduleTimezoneImports() => {
  for (final entity in _moduleDirectory.listSync())
    if (entity is File && entity.path.endsWith('.dart'))
      ..._timezoneImportsIn(entity),
};

Set<String> _timezoneImportsOf(String fileName) =>
    _timezoneImportsIn(File('${_moduleDirectory.path}/$fileName'));

final _timezoneImport = RegExp(r"import\s+'(package:timezone/[\w/]+\.dart)'");

Set<String> _timezoneImportsIn(File file) => {
  for (final m in _timezoneImport.allMatches(file.readAsStringSync()))
    m.group(1)!,
};

// -----------------------------------------------------------------------------
// Following the imports into the timezone package
// -----------------------------------------------------------------------------

/// Every arm of `selection`, keyed by the condition that selects it; the
/// default arm is keyed `null`.
Map<String?, String> _armsByCondition(_Selection selection) => {
  null: selection.defaultArm,
  for (final arm in selection.arms.entries) arm.key: arm.value,
};

String _describe(String? condition) =>
    condition == null ? 'by default' : 'on $condition';

/// The `dart:` libraries an arm selected by `condition` cannot rely on.
///
/// The default arm is the strict case: it is chosen precisely where none of
/// the conditions hold, so *every* platform library is out of reach. The
/// conditional arms may use what their own condition guarantees and nothing
/// from the other side.
Set<String> _forbiddenUnder(String? condition) => switch (condition) {
  'dart.library.io' => _webLibraries,
  'dart.library.js' => _nativeLibraries,
  _ => {..._nativeLibraries, ..._webLibraries},
};

const _nativeLibraries = {
  'dart:io',
  'dart:isolate',
  'dart:ffi',
  'dart:mirrors',
};
const _webLibraries = {
  'dart:js',
  'dart:js_interop',
  'dart:js_util',
  'dart:html',
};

class _Walk {
  _Walk(this.visited, this.platformLibraries);

  /// Every file read, module files included.
  final Set<String> visited;

  /// Files that import a `dart:` library, and which ones.
  final Map<String, Set<String>> platformLibraries;
}

final _anyImport = RegExp(r"import\s+'([^']+)'");

/// Reads `fileName` and everything it reaches inside `package:timezone`.
///
/// The walk stops at every other package on purpose. What this conditional
/// import chooses between is `timezone` entry points, and `timezone` is the
/// dependency whose platform surface differs across them — descending into an
/// unrelated package would only report that package's own conditional imports,
/// which it resolves for itself.
_Walk _walkTimezoneImports(String fileName) {
  final visited = <String>{};
  final platformLibraries = <String, Set<String>>{};
  final queue = <File>[File('${_moduleDirectory.path}/$fileName')];

  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    final key = file.path;
    if (!visited.add(key)) continue;

    for (final match in _anyImport.allMatches(file.readAsStringSync())) {
      final uri = match.group(1)!;
      if (uri.startsWith('dart:')) {
        (platformLibraries[_shortPath(key)] ??= <String>{}).add(uri);
      } else if (uri.startsWith('package:timezone/')) {
        queue.add(File('${_timezoneLib()}${uri.substring(17)}'));
      } else if (!uri.startsWith('package:')) {
        final resolved = File(
          Uri.file(file.absolute.path).resolve(uri).toFilePath(),
        );
        if (resolved.existsSync()) queue.add(resolved);
      }
    }
  }
  return _Walk(visited, platformLibraries);
}

/// A reachable file named the way a reader would name it.
String _shortPath(String path) {
  final lib = _timezoneLib();
  if (path.startsWith(lib)) {
    return 'package:timezone/${path.substring(lib.length)}';
  }
  final here = Directory.current.path;
  return path.startsWith(here) ? path.substring(here.length + 1) : path;
}

String? _timezoneLibCache;

/// The `lib/` directory of the resolved `timezone` package, with a trailing
/// separator.
String _timezoneLib() => _timezoneLibCache ??= _resolveTimezoneLib();

String _resolveTimezoneLib() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    throw StateError(
      'No .dart_tool/package_config.json — run `dart pub get` before this '
      'suite. Without it the imports cannot be resolved and the reachability '
      'check would silently pass.',
    );
  }
  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;
  final timezone = packages.cast<Map<String, dynamic>>().firstWhere(
    (pkg) => pkg['name'] == 'timezone',
    orElse: () => throw StateError(
      'The timezone package is not in package_config.json. If the module no '
      'longer depends on it, this test file is obsolete.',
    ),
  );
  // `rootUri` is relative to the config file when the package is a path
  // dependency and absolute when it comes from the pub cache; resolving
  // against the config's own URI covers both. Both URIs name directories and
  // neither is guaranteed to say so, and `resolve` drops a final segment that
  // has no trailing slash — so add one before resolving through it.
  final root = Uri.file(
    config.absolute.path,
  ).resolve(_asDirectory(timezone['rootUri'] as String));
  return root
      .resolve(_asDirectory(timezone['packageUri'] as String))
      .toFilePath();
}

String _asDirectory(String uri) => uri.endsWith('/') ? uri : '$uri/';

// -----------------------------------------------------------------------------
// Reading the documents
// -----------------------------------------------------------------------------

/// A backticked `package:timezone/…` URI named in prose.
final _namedTimezoneLibrary = RegExp(r'`(package:timezone/[\w/]+\.dart)`');

/// A claim of the form ``` `data/latest.dart` on native ```: an entry point
/// into the `timezone` package, credited to a platform.
final _platformClaim = RegExp(
  r'`([\w/]+\.dart)`\s+(?:on|under)\s+(native|Flutter|the web|web)\b',
);

class _Mention {
  _Mention(this.where, this.value, this.qualifier);

  final String where;
  final String value;
  final String? qualifier;
}

List<_Mention> _mentions(RegExp pattern) {
  final found = <_Mention>[];
  for (final document in _documents) {
    final lines = document.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final match in pattern.allMatches(lines[i])) {
        found.add(
          _Mention(
            '${document.path}:${i + 1}',
            match.group(1)!,
            match.groupCount >= 2 ? match.group(2) : null,
          ),
        );
      }
    }
  }
  return found;
}

/// Every fenced block in the documents that reproduces the conditional import.
Map<String, String> _quotedImportBlocks() {
  final quoted = <String, String>{};
  for (final document in _documents) {
    final lines = document.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith(_importOpening())) continue;
      final end = lines.indexWhere((l) => l.trimRight().endsWith(';'), i);
      quoted['${document.path}:${i + 1}'] = lines
          .sublist(i, end + 1)
          .join('\n');
    }
  }
  return quoted;
}

/// The condition that selects the arm serving a platform, or `null` for the
/// default arm.
///
/// Native and Flutter are the same answer on purpose, and that answer is the
/// default arm: neither is singled out by a condition, so both are served by
/// whatever serves everything else. Giving them separate rows is what produced
/// the wrong table.
String? _conditionFor(String platform) => switch (platform) {
  'web' || 'the web' => 'dart.library.js',
  _ => null,
};

const _inventedLibraryReason =
    'A document names a package:timezone library that no file in the module '
    'imports. The reader cannot tell an entry point that was renamed from one '
    'that never existed, and either way the line describes a dependency the '
    'module does not have.';

const _unreachableLibraryReason =
    'An arm of the conditional import reaches a dart: library that is not '
    'available where that arm is selected, so the arm cannot compile on the '
    'platform it exists to serve. The default arm is the easiest one to get '
    'wrong: it is taken where none of the conditions hold, which rules out '
    'every platform library at once — including dart:io, which a `standalone` '
    'or `file`-flavoured entry point of a dependency will pull in.';

const _misattributedEntryPointReason =
    'A document credits a platform with a timezone entry point that the arm '
    'serving that platform does not import. Check the conditional import: the '
    'first line is the default arm, and every VM target — server, CLI, test '
    'runner and Flutter — takes the dart.library.io arm instead.';
