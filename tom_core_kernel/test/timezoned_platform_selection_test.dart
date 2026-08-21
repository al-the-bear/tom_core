import 'dart:io';

import 'package:test/test.dart';

/// What the timezoned module's conditional import actually selects, and
/// whether the documentation says the same thing.
///
/// `timezones.dart` picks its initializer with a conditional import:
///
/// ```dart
/// import 'init_tz.dart'
///     if (dart.library.io) 'init_tz_flutter.dart'
///     if (dart.library.js) 'init_tz_web.dart';
/// ```
///
/// The first line is the **default** arm, not the native one. Every VM target —
/// server, CLI, test runner and Flutter alike — has `dart.library.io`, so they
/// all take `init_tz_flutter.dart`; `init_tz.dart` is reached only where
/// neither `dart:io` nor `dart:js` exists. The file names invite the opposite
/// reading, and the documentation took it: the platform table paired the
/// server with `init_tz.dart` and credited it with a `timezone` entry point no
/// file in the module imports.
///
/// That mistake is invisible from either side alone. The source is correct and
/// says nothing about platforms; the prose is wrong and never mentions a
/// condition. Only holding the two together shows it, which is what these
/// tests do:
///
/// - the `import` and `export` arms stay identical, which the source asks for
///   in a comment and nothing else enforces;
/// - each arm's file describes the role the selection gives it;
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

    test('each arm holds the implementation its condition implies', () {
      final selection = _selection('import');

      expect(
        _dartdoc(selection.defaultArm),
        contains('fallback'),
        reason:
            'The first line of a conditional import is the default arm, taken '
            'only where no condition holds. Whatever file sits there is the '
            'fallback and should say so — reading it as the native '
            'implementation is exactly the mistake this group exists to catch.',
      );
      expect(_dartdoc(selection.arms['dart.library.io']!), contains('native'));
      expect(_dartdoc(selection.arms['dart.library.js']!), contains('web'));
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

final _moduleDirectory = Directory('lib/src/tombase/timezoned');

/// The documents that describe this module: its own readme, the prose document
/// and the API summary.
final _documents = <File>[
  File('lib/src/tombase/timezoned/readme.md'),
  File('doc/timezoned/timezoned.md'),
  File('doc/api_reference/api_summary_timezoned.md'),
];

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

/// The source's own rendering of the import, used to hold quotations to it.
String _sourceImportBlock() {
  final lines = File(
    'lib/src/tombase/timezoned/timezones.dart',
  ).readAsLinesSync();
  final start = lines.indexWhere(
    (l) =>
        _directive('import').hasMatch(l) ||
        l.startsWith("import 'init_tz.dart'"),
  );
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
      if (!lines[i].startsWith("import 'init_tz.dart'")) continue;
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
/// Native and Flutter are the same answer on purpose: both have `dart:io`, so
/// both take the `dart.library.io` arm. Treating them as separate rows is what
/// produced the wrong table.
String? _conditionFor(String platform) => switch (platform) {
  'native' || 'Flutter' => 'dart.library.io',
  'web' || 'the web' => 'dart.library.js',
  _ => null,
};

const _inventedLibraryReason =
    'A document names a package:timezone library that no file in the module '
    'imports. The reader cannot tell an entry point that was renamed from one '
    'that never existed, and either way the line describes a dependency the '
    'module does not have.';

const _misattributedEntryPointReason =
    'A document credits a platform with a timezone entry point that the arm '
    'serving that platform does not import. Check the conditional import: the '
    'first line is the default arm, and every VM target — server, CLI, test '
    'runner and Flutter — takes the dart.library.io arm instead.';
