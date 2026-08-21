import 'dart:io';

import 'package:test/test.dart';

/// The dependency table in the timezoned prose, held to the module's imports.
///
/// A dependency table is the one part of a document that is wholly derivable
/// from the source, and it is also the part that goes stale most quietly. An
/// import added to a file changes nothing a reader can see; the table keeps
/// listing what the module used to need, and the omission looks exactly like a
/// dependency that was never there. The table had lost a `little_things` file
/// that way — the module reaches that module through two files and the table
/// named one.
///
/// So the source is the anchor and the table is compared to it in both
/// directions: a dependency with no row is an omission, a row with no
/// dependency is a leftover, and both are wrong in the same way. The
/// `Imported by` column is checked the same way, per dependency, because a
/// table can name the right four things and still attribute them to the wrong
/// files.
///
/// What this file does *not* cover is the conditional import that selects the
/// platform initializer, and the `package:timezone/…` entry points the prose
/// credits to each platform — `timezoned_platform_selection_test.dart` owns
/// those, following the imports into the `timezone` package to do it. Here a
/// dependency is a name and a set of importing files, nothing deeper.
void main() {
  // ===========================================================================
  // Which dependencies are named
  // ===========================================================================
  group('the table names the module\'s dependencies', () {
    test('every dependency has a row', () {
      expect(
        _dependencies().keys.toSet().difference(_rows().keys.toSet()),
        isEmpty,
        reason:
            'The module imports something the dependency table never mentions. '
            'A reader auditing what this module pulls in gets an answer that is '
            'short by exactly the entry they would have cared about.',
      );
    });

    test('no row names something the module does not import', () {
      expect(
        _rows().keys.toSet().difference(_dependencies().keys.toSet()),
        isEmpty,
        reason:
            'The dependency table has a row for something no file in the module '
            'imports. Either the dependency was dropped and the row outlived '
            'it, or the row was never right.',
      );
    });

    // Both comparisons above are set differences, and a set difference against
    // an empty set is empty. Each side has to have found something.
    test('both sides of the comparison found something', () {
      expect(_dependencies(), hasLength(greaterThanOrEqualTo(4)));
      expect(_rows(), hasLength(greaterThanOrEqualTo(4)));
    });
  });

  // ===========================================================================
  // Which files reach them
  // ===========================================================================
  group('the Imported by column is what the files import', () {
    test('each row attributes its dependency to the right files', () {
      final actual = _dependencies();
      final offenders = <String>[];

      for (final row in _rows().entries) {
        final claimed = _importers(row.value);
        final real = actual[row.key];
        if (real == null || _setEquals(claimed, real)) continue;
        offenders.add(
          '${row.key}: the table says ${_list(claimed)}, the source says '
          '${_list(real)}',
        );
      }

      expect(offenders, isEmpty, reason: _wrongImporterReason);
    });

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

/// Every dependency the module reaches outside its own directory, mapped to
/// the module files that import it.
///
/// A dependency is named the way the table names it: a package by its package
/// name, a sibling kernel module by its directory. Imports within the module
/// are not dependencies — they are the module — and neither are `dart:`
/// libraries, which no table row could usefully describe.
Map<String, Set<String>> _dependencies() {
  final found = <String, Set<String>>{};

  for (final file in _moduleFiles()) {
    for (final uri in _importsIn(file)) {
      final key = _dependencyKey(uri);
      if (key == null) continue;
      (found[key] ??= <String>{}).add(_name(file));
    }
  }

  return found;
}

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

String _name(File file) => file.uri.pathSegments.last;

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

/// The files a row's `Imported by` cell credits.
///
/// `every file` is the one phrase that names a set rather than its members, so
/// it is resolved against the module rather than parsed.
Set<String> _importers(String row) {
  final cell = _cells(row)[2];
  if (cell.contains('every file')) return _moduleFiles().map(_name).toSet();
  return {for (final m in _backtickedFile.allMatches(cell)) m.group(1)!};
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

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

String _list(Set<String> values) {
  final sorted = values.toList()..sort();
  return sorted.join(', ');
}

const _wrongImporterReason =
    'A dependency table row credits the wrong files with an import. The column '
    'exists so a reader can tell which half of the module carries which '
    'dependency — the lookup half or the value types — and a wrong entry sends '
    'them to the wrong file.';

const _unnamedEntryFileReason =
    'The module reaches a sibling kernel module through a file the table never '
    'names. A row that names one entry point out of two reads as though there '
    'were only one, which is how this table went stale before.';
