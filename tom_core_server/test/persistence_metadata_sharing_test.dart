/// Tests that an entity's resolved persistence metadata cannot be made to
/// disagree with itself.
///
/// `TomAnnotationAnalyzer` resolves an entity's columns once and then hands the
/// same objects to every repository, query compiler and datasource for the life
/// of the isolate. Sharing is what makes the metadata cheap, and it is also
/// what makes a single stray write catastrophic: an assignment to a column's
/// mapped name would change what every later query on that entity compiles to,
/// far from the code that made the mistake and without an error anywhere. The
/// module therefore hands out nothing writable, and this file pins that from
/// both sides — the runtime shape of what callers receive, and the structural
/// property of the class that guarantees it.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureDocumentRecord, FixtureResourceRecord, FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// The declaration of `TomColumnInformation`, which owns the shared metadata.
const String annotationsSource =
    'lib/src/tomserver/object_persistence/persistence_annotations.dart';

/// The analyzer that resolves the metadata and holds the memos.
const String analyzerSource =
    'lib/src/tomserver/object_persistence/annotation_analyzer.dart';

void main() {
  setUpAll(initializeReflection);

  group('resolved columns are shared', () {
    test('two resolutions return the same list', () {
      final first = TomAnnotationAnalyzer.getPersistentColumns(
        FixtureTaskRecord,
      );
      final second = TomAnnotationAnalyzer.getPersistentColumns(
        FixtureTaskRecord,
      );
      expect(first, isNotNull);
      expect(first, isNotEmpty);
      expect(identical(first, second), isTrue);
    });

    test('two resolutions return the same column objects', () {
      // Identity of the list alone would not settle it: a cache that rebuilt
      // the entries into a stable list would still let one holder's edit be
      // invisible to another.
      final first = TomAnnotationAnalyzer.getPersistentColumns(
        FixtureTaskRecord,
      )!;
      final second = TomAnnotationAnalyzer.getPersistentColumns(
        FixtureTaskRecord,
      )!;
      for (var i = 0; i < first.length; i++) {
        expect(identical(first[i], second[i]), isTrue);
      }
    });

    test('every column of an entity names the one table of that entity', () {
      // One entity, one `@TomDbTable`: the analyzer resolves the table once per
      // type and hands the same annotation to every column it builds, so a
      // column list is homogeneous in its table and a caller may read the
      // entity's table off any element.
      //
      // Pinned because callers act on it. `autoScopeFor` decides the
      // resource-scope guard from the tables its columns name, and it is a
      // one-line change here — resolving the table per declaration rather than
      // per type — that would make the same list describe two tables and the
      // guard answer for whichever one it met. The consequence is not local:
      // auto-scoping one of the framework's grant tables closes the
      // authorization layer against itself.
      for (final type in [
        FixtureTaskRecord,
        FixtureDocumentRecord,
        FixtureResourceRecord,
      ]) {
        final columns = TomAnnotationAnalyzer.analysePersistentType(
          type,
        ).columnInfo;
        expect(columns, isNotEmpty);
        expect(
          columns.map((column) => column.table.table).toSet(),
          hasLength(1),
          reason: '$type must resolve all its columns against one table',
        );
      }
    });
  });

  group('shared metadata is not writable', () {
    test('the column list refuses every mutation', () {
      final columns = TomAnnotationAnalyzer.getPersistentColumns(
        FixtureTaskRecord,
      )!;
      final intruder = columns.first;
      expect(() => columns.add(intruder), throwsUnsupportedError);
      expect(() => columns.removeLast(), throwsUnsupportedError);
      expect(() => columns.clear(), throwsUnsupportedError);
      expect(() => columns[0] = intruder, throwsUnsupportedError);
      expect(() => columns.sort(), throwsUnsupportedError);
    });

    test('the derived column-rights list refuses every mutation', () {
      // findAuthColumns memoises its own filtered list, so it needs the same
      // guarantee: it is handed to every C-4 check on the entity.
      final columns = TomAnnotationAnalyzer.findAuthColumns(
        FixtureDocumentRecord,
      );
      expect(columns, isNotEmpty);
      expect(() => columns.add(columns.first), throwsUnsupportedError);
      expect(() => columns.clear(), throwsUnsupportedError);
    });

    test('the derived file-column list refuses every mutation', () {
      final columns = TomAnnotationAnalyzer.findFileColumns(
        FixtureDocumentRecord,
      );
      expect(columns, isNotEmpty);
      expect(() => columns.add(columns.first), throwsUnsupportedError);
      expect(() => columns.clear(), throwsUnsupportedError);
    });

    test('every field of TomColumnInformation is declared final', () {
      // The runtime cases above cannot reach this: assigning to a final field
      // is a compile error, so a test that tried would not build. Reading the
      // declaration is the only way to state the rule for fields added later —
      // and a field added later is exactly the case that matters, because it
      // would inherit the sharing without inheriting the discipline.
      final fields = _fieldDeclarationsOf(
        annotationsSource,
        'TomColumnInformation',
      );
      expect(fields, isNotEmpty, reason: 'the class body was not found');
      final writable = [
        for (final field in fields)
          if (!field.text.startsWith('final ')) '${field.line}: ${field.text}',
      ];
      expect(
        writable,
        isEmpty,
        reason:
            'These fields of TomColumnInformation are writable. An instance is '
            'shared by every consumer of the entity, so a write to one of them '
            'changes what every later query compiles to, silently. Declare '
            'them final and pass the value through the constructor.',
      );
    });
  });

  group('reset is the one way to discard a resolution', () {
    tearDown(TomAnnotationAnalyzer.reset);

    test(
      'the next resolution rebuilds rather than answering from the memo',
      () {
        final before = TomAnnotationAnalyzer.getPersistentColumns(
          FixtureTaskRecord,
        )!;
        TomAnnotationAnalyzer.reset();
        final after = TomAnnotationAnalyzer.getPersistentColumns(
          FixtureTaskRecord,
        )!;
        expect(identical(before, after), isFalse);
        // Rebuilt from the same declaration, so it says the same thing — the
        // point is that it was read again, not that it changed.
        expect(
          after.map((column) => column.getQueryFieldName()),
          before.map((column) => column.getQueryFieldName()),
        );
      },
    );

    test('every derived resolution is discarded with it', () {
      // The six memos are derived from one another, so clearing some and not
      // others would leave the rest describing an entity that no longer exists.
      // These three are the ones whose rebuild is observable by identity: each
      // returns a freshly built object rather than one held in the annotation.
      final columns = TomAnnotationAnalyzer.findAuthColumns(
        FixtureDocumentRecord,
      );
      final files = TomAnnotationAnalyzer.findFileColumns(
        FixtureDocumentRecord,
      );
      final scope = TomAnnotationAnalyzer.findDataScope(FixtureResourceRecord);
      expect(scope, isNotNull);

      TomAnnotationAnalyzer.reset();

      expect(
        identical(
          columns,
          TomAnnotationAnalyzer.findAuthColumns(FixtureDocumentRecord),
        ),
        isFalse,
      );
      expect(
        identical(
          files,
          TomAnnotationAnalyzer.findFileColumns(FixtureDocumentRecord),
        ),
        isFalse,
      );
      expect(
        identical(
          scope,
          TomAnnotationAnalyzer.findDataScope(FixtureResourceRecord),
        ),
        isFalse,
      );
    });

    test('reset reaches every cache the analyzer declares', () {
      // The failure this guards is a *seventh* cache added beside the six and
      // not added to reset(): the analyzer would then half-forget an entity,
      // and the stale half would be read as current. Identity checks cannot
      // see that — a memo nobody thought to test is a memo nobody thought to
      // clear — so the declaration is compared with the body directly.
      final source = File(analyzerSource).readAsStringSync();
      final declared = RegExp(
        r'static final (_\w*Cache)\b',
      ).allMatches(source).map((match) => match.group(1)!).toSet();
      expect(declared, hasLength(6));
      final cleared = RegExp(r'(_\w*Cache)\.clear\(\)')
          .allMatches(_bodyOfReset(source))
          .map((match) => match.group(1)!)
          .toSet();
      expect(
        declared.difference(cleared),
        isEmpty,
        reason:
            'TomAnnotationAnalyzer.reset() does not clear every cache the '
            'mixin declares. A memo left behind survives the reset and is '
            'then read as current, against metadata that was discarded.',
      );
    });
  });

  group('the declaration reader', () {
    test('sees a writable field beside a final one', () {
      final fields = _fieldDeclarations(
        '''
class Sample {
  /// Documented.
  final int settled;

  int loose;

  Sample(this.settled, this.loose);

  int get derived => settled;
}
'''
            .split('\n'),
        'Sample',
      );
      expect(fields.map((field) => field.text), [
        'final int settled;',
        'int loose;',
      ]);
    });

    test('stops at the end of the named class', () {
      final fields = _fieldDeclarations(
        '''
class Sample {
  final int inside;

  Sample(this.inside);
}

class Neighbour {
  int outside = 0;
}
'''
            .split('\n'),
        'Sample',
      );
      expect(fields.map((field) => field.text), ['final int inside;']);
    });

    test('reads nothing out of a method body or a wrapped constructor', () {
      // Both of these end in `;` at the left margin of the class, and a reader
      // that only looked at the punctuation would report them as writable
      // fields — a failure that accuses the class of a defect it does not have.
      final fields = _fieldDeclarations(
        '''
class Sample {
  final int settled;

  Sample(
    this.settled, {
    this.optional,
  });

  int read() {
    return settled;
  }
}
'''
            .split('\n'),
        'Sample',
      );
      expect(fields.map((field) => field.text), ['final int settled;']);
    });
  });
}

/// The body of `static void reset()` in [source].
///
/// Bounded by the closing brace at the method's own indentation, so the search
/// for `clear()` calls cannot wander into whatever follows and report a cache
/// as cleared that is only mentioned elsewhere.
String _bodyOfReset(String source) {
  final start = source.indexOf('static void reset() {');
  if (start < 0) return '';
  final end = source.indexOf('\n  }', start);
  return end < 0 ? source.substring(start) : source.substring(start, end);
}

/// One field declaration read out of a source file.
typedef _FieldDeclaration = ({int line, String text});

/// The field declarations of [className] in the file at [path].
List<_FieldDeclaration> _fieldDeclarationsOf(String path, String className) =>
    _fieldDeclarations(File(path).readAsLinesSync(), className);

/// The field declarations of [className] among [lines].
///
/// A deliberately small reader rather than a parser: it keeps the lines that
/// sit *directly* in the class body — brace depth one — end in `;`, and are
/// neither a comment nor a constructor, method or accessor. The depth condition
/// is what keeps a `return x;` inside a method, or the `});` closing a
/// multi-line constructor, from being read as a field. That is enough to see a
/// missing `final`, which is the only question asked of it.
List<_FieldDeclaration> _fieldDeclarations(
  List<String> lines,
  String className,
) {
  final start = lines.indexWhere(
    (line) =>
        line.startsWith('class $className ') || line == 'class $className {',
  );
  if (start < 0) return const [];
  final fields = <_FieldDeclaration>[];
  var depth = 0;
  var entered = false;
  for (var index = start; index < lines.length; index++) {
    final line = lines[index];
    final enclosing = depth;
    depth += '{'.allMatches(line).length - '}'.allMatches(line).length;
    entered |= depth > 0;
    if (entered && depth == 0) break;
    if (enclosing != 1) continue;
    final text = line.trim();
    if (!text.endsWith(';')) continue;
    if (text.startsWith('//')) continue;
    if (text.contains('(') || text.contains('=>')) continue;
    fields.add((line: index + 1, text: text));
  }
  return fields;
}
