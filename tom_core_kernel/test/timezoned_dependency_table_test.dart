import 'dart:io';

import 'package:test/test.dart';

/// The two claims about the timezoned dependency table that only source can
/// settle, and that the repository gate cannot.
///
/// `tool/check_module_dependencies.py` holds every module document's table to
/// its module's imports — in both directions, including which files are
/// credited with each dependency — across all 57 of them. That is where the
/// general rule lives, and a second implementation of it here would be a copy
/// that can disagree with the original.
///
/// What stays is what is specific to this module:
///
/// * **Which sibling file a module row names.** The gate checks *importers* —
///   which files in this module reach a dependency. This checks the other
///   direction: which files *of the sibling module* are reached. The table lost
///   `formatting.dart` that way, naming one of the two entry points into
///   `little_things`, and the gate would not have seen it.
/// * **The note after the table.** It names a module file that carries none of
///   the kernel dependencies and says what it imports instead. That is a
///   sentence about a file the table deliberately does not have a row for, so
///   nothing derivable from the table can keep it true.
///
/// What this file does *not* cover is the conditional import that selects the
/// platform initializer, and the `package:timezone/…` entry points the prose
/// credits to each platform — `timezoned_platform_selection_test.dart` owns
/// those, following the imports into the `timezone` package to do it.
void main() {
  // ===========================================================================
  // Which files reach them
  // ===========================================================================
  group('the sibling files a module row names', () {
    test('each sibling module row names the files it is reached through', () {
      final offenders = <String>[];

      for (final entry in _entryFiles().entries) {
        final row = _rows()[entry.key];
        if (row == null) continue; // Absence is the previous group's business.
        for (final file in entry.value) {
          if (row.contains('`$file`')) continue;
          offenders.add('${entry.key}: the row never mentions `$file`');
        }
      }

      expect(
        _entryFiles(),
        isNotEmpty,
        reason:
            'No sibling kernel module is imported any more, so this test is '
            'checking nothing. If the module became self-contained, delete it.',
      );
      expect(offenders, isEmpty, reason: _unnamedEntryFileReason);
    });
  });

  // ===========================================================================
  // What the table says about the files it leaves out
  // ===========================================================================
  group('the note about the undepended file', () {
    test('the file it names imports exactly what it claims', () {
      final note = _note();

      expect(
        _claimOf(note),
        _reachOf(_subjectOf(note)),
        reason:
            'The table closes by naming a module file that carries none of the '
            'kernel dependencies, and saying what it does import instead. That '
            'sentence is now false, so a reader who took it as the reason the '
            'rows above are attributed the way they are was misled.',
      );
    });
  });
}

// -----------------------------------------------------------------------------
// The anchor: what the module actually imports
// -----------------------------------------------------------------------------

const String _moduleDirectory = 'lib/src/tombase/timezoned';

/// The sibling kernel files each sibling module is reached through, keyed by
/// module directory — `little_things` → `exception_base.dart`, `formatting.dart`.
///
/// Which files these are is the detail the table lost, so it is anchored
/// separately from the module name itself.
Map<String, Set<String>> _entryFiles() {
  final found = <String, Set<String>>{};

  for (final file in _moduleFiles()) {
    for (final uri in _importsIn(file)) {
      final sibling = _siblingModule.firstMatch(uri);
      if (sibling == null) continue;
      (found[sibling.group(1)!] ??= <String>{}).add(sibling.group(2)!);
    }
  }

  return found;
}

/// Everything `file` reaches, as the table would name it: dependency keys for
/// what lies outside the module, plain file names for what lies inside it.
Set<String> _reachOf(String file) => {
  for (final uri in _importsIn(File('$_moduleDirectory/$file')))
    if (_dependencyKey(uri) case final key?)
      key
    else if (!uri.startsWith('dart:'))
      uri,
};

/// A package name, a sibling module directory, or `null` for an import that is
/// not a dependency at all.
String? _dependencyKey(String uri) =>
    _package.firstMatch(uri)?.group(1) ??
    _siblingModule.firstMatch(uri)?.group(1);

final _package = RegExp(r'^package:(\w+)/');
final _siblingModule = RegExp(r'^\.\./(\w+)/([\w.]+\.dart)$');
final _import = RegExp(r"import\s+'([^']+)'");

List<File> _moduleFiles() =>
    Directory(_moduleDirectory)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

Set<String> _importsIn(File file) => {
  for (final match in _import.allMatches(file.readAsStringSync()))
    match.group(1)!,
};

// -----------------------------------------------------------------------------
// The scan: what the table states
// -----------------------------------------------------------------------------

const String _document = 'doc/timezoned/timezoned.md';
const String _heading = '## Dependencies';

/// The table's rows, keyed by the dependency each one names.
///
/// The key comes out of the first cell, which names a package in backticks or
/// a sibling module as a link to that module's document. Deriving the key from
/// the link target rather than the link text is deliberate: the text is prose
/// ("Little Things Module") and the target is a path, and only the path can be
/// compared to an import.
Map<String, String> _rows() {
  final rows = <String, String>{};

  for (final line in _section()) {
    if (!line.startsWith('|')) continue;
    final cells = _cells(line);
    if (cells.length < 3 || cells.first == 'Dependency') continue;
    if (_separator.hasMatch(cells.first)) continue;

    final key =
        _backtickedWord.firstMatch(cells.first)?.group(1) ??
        _linkedModule.firstMatch(cells.first)?.group(1);
    if (key != null) rows[key] = line;
  }

  return rows;
}

/// The sentence that follows the table, naming a module file that carries none
/// of the kernel dependencies.
String _note() {
  final lines = _section();
  final start = lines.indexWhere((line) => line.startsWith('Note that'));
  if (start < 0) throw StateError(_noNoteFound);

  // The sentence runs past the line it starts on.
  final blank = lines.indexWhere((l) => l.trim().isEmpty, start);
  final note = lines.sublist(start, blank < 0 ? lines.length : blank).join(' ');

  if (!note.contains(_claimOpening) || !_backtickedFile.hasMatch(note)) {
    throw StateError(_noNoteFound);
  }
  return note;
}

/// The module file the note is about — the first thing it names.
String _subjectOf(String note) => _backtickedFile.firstMatch(note)!.group(1)!;

/// What the note claims that file imports.
///
/// Only what follows `imports only`, and only to the end of that sentence,
/// counts. Both bounds were needed. Before the sentence, the note names the
/// types that live in the file, in an aside, and those are backticked exactly
/// like the imports are — reading from the start would take three class names
/// for three dependencies. After it, the paragraph goes on to mention
/// `timezones.dart` again, so a scan running to the blank line would keep
/// finding that name however badly the claim itself was worded.
Set<String> _claimOf(String note) {
  final from = note.indexOf(_claimOpening) + _claimOpening.length;
  final rest = note.substring(from);
  final end = _sentenceEnd.firstMatch(rest);
  final claim = end == null ? rest : rest.substring(0, end.start);

  return {for (final m in _backtickedWord.allMatches(claim)) m.group(1)!};
}

/// A full stop that ends a sentence rather than one inside a file name — the
/// difference being what follows it.
final _sentenceEnd = RegExp(r'\.(\s|$)');

/// The words that separate the note's aside from its claim.
const String _claimOpening = 'imports only';

const String _noNoteFound =
    'The dependency section no longer closes with a note naming a module file '
    'and saying what it imports only. If the note was dropped this test is '
    'obsolete; if it was reworded the scan has stopped reading it and would '
    'pass on nothing.';

List<String> _section() {
  final lines = File(_document).readAsLinesSync();
  final start = lines.indexOf(_heading);
  if (start < 0) {
    throw StateError(
      'No `$_heading` section in $_document. If the module stopped documenting '
      'its dependencies, say so deliberately rather than by deleting a heading.',
    );
  }
  // Up to the next heading of the same level or higher, so the platform
  // subsection stays inside the section.
  var end = start + 1;
  while (end < lines.length && !_sameOrHigher.hasMatch(lines[end])) {
    end++;
  }
  return lines.sublist(start, end);
}

List<String> _cells(String row) {
  final parts = row.split('|').map((c) => c.trim()).toList();
  return parts.sublist(1, parts.length - 1);
}

final _sameOrHigher = RegExp(r'^#{1,2}\s');
final _separator = RegExp(r'^-+$');
final _backtickedWord = RegExp(r'`([\w./:]+)`');
final _backtickedFile = RegExp(r'`([\w.]+\.dart)`');
final _linkedModule = RegExp(r'\]\(\.\./(\w+)/');

const _unnamedEntryFileReason =
    'The module reaches a sibling kernel module through a file the table never '
    'names. A row that names one entry point out of two reads as though there '
    'were only one, which is how this table went stale before.';
