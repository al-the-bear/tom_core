/// Tests that the analyzer's four nullable lookups answer `null` as an answer,
/// not as a failure — on the first call and on every call after it.
///
/// `findMirror`, `findTable`, `findDataScope` and `getPersistentColumns` each
/// return `null` for an ordinary, expected reason: the type is not registered,
/// carries no `@TomDbTable`, declares no row scope, or has no columns to
/// resolve. Each also *memoises* that `null`, so `containsKey` is true while the
/// value is null — a designed state of every one of those maps.
///
/// Two things follow, and this file pins both.
///
/// The **runtime** rule: a second lookup must read the memoised `null` back as
/// `null`. A cache-hit fast path that casts the entry to its non-nullable type
/// gives the worst possible shape of bug — the first call answers correctly and
/// the second, from the memo, throws.
///
/// The **structural** rule: no caller may null-assert one of these results.
/// `findTable(type)!` is a null check written as an expression: it turns the
/// documented `null` into `Null check operator used on a null value`, thrown
/// from inside a static memo, naming neither the type nor the annotation that
/// was missing. The module has a diagnosis for every one of those cases —
/// `analysePersistentType` raises `TomAnnotationAnalyzerException` naming the
/// type and the missing thing — so the assertion is never the best available
/// error, only the shortest to write. A runtime test cannot reach the ones
/// whose caller happens to have established non-nullness three branches
/// earlier; reading the source can, and that is the case worth guarding,
/// because it is the one that survives until the branch above it changes.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureResourceRecord, FixtureTaskRecord, FixtureUnmappedFileRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// The library sources scanned for null-asserted lookups.
const String libraryRoot = 'lib';

/// The analyzer lookups that answer `null` for an ordinary reason.
const List<String> nullableLookups = [
  'findMirror',
  'findTable',
  'findDataScope',
  'getPersistentColumns',
];

/// A type that is not registered with `tomReflector` at all.
class _Unregistered {}

void main() {
  setUpAll(initializeReflection);

  group('a memoised null reads back as null', () {
    // Each of these looks the same type up twice on purpose. The first call
    // resolves and stores `null`; only the second exercises the cache-hit path,
    // which is the line that would carry a cast or an assertion.

    test('findMirror answers null twice for an unregistered type', () {
      expect(TomAnnotationAnalyzer.findMirror(_Unregistered), isNull);
      expect(TomAnnotationAnalyzer.findMirror(_Unregistered), isNull);
    });

    test('findTable answers null twice for an entity with no @TomDbTable', () {
      // Reflectable, so the mirror resolves; it simply maps to no table.
      expect(
        TomAnnotationAnalyzer.findTable(FixtureUnmappedFileRecord),
        isNull,
      );
      expect(
        TomAnnotationAnalyzer.findTable(FixtureUnmappedFileRecord),
        isNull,
      );
    });

    test('findTable answers null twice for an unregistered type', () {
      // The other route to a stored `null`: no mirror, so no annotation to
      // read. It reaches the same memo and must read back the same way.
      expect(TomAnnotationAnalyzer.findTable(_Unregistered), isNull);
      expect(TomAnnotationAnalyzer.findTable(_Unregistered), isNull);
    });

    test('findDataScope answers null twice for an unscoped entity', () {
      // FixtureTaskRecord declares no @TomDbScope and carries no resource key,
      // so neither the explicit nor the automatic route yields a scope.
      expect(TomAnnotationAnalyzer.findDataScope(FixtureTaskRecord), isNull);
      expect(TomAnnotationAnalyzer.findDataScope(FixtureTaskRecord), isNull);
    });

    test(
      'getPersistentColumns answers null twice for an unregistered type',
      () {
        expect(
          TomAnnotationAnalyzer.getPersistentColumns(_Unregistered),
          isNull,
        );
        expect(
          TomAnnotationAnalyzer.getPersistentColumns(_Unregistered),
          isNull,
        );
      },
    );

    test('a stored non-null answer is unaffected', () {
      // The rule is about reading `null` back, not about weakening the memo:
      // an entity that does resolve must still be answered from the cache with
      // the very same objects.
      final scope = TomAnnotationAnalyzer.findDataScope(FixtureResourceRecord);
      expect(scope, isNotNull);
      expect(
        identical(
          scope,
          TomAnnotationAnalyzer.findDataScope(FixtureResourceRecord),
        ),
        isTrue,
      );
    });
  });

  group('the absent case is diagnosed, never asserted', () {
    test('analysePersistentType names the type that is not registered', () {
      // This is the error a null assertion replaces. It names the type and the
      // reason; `Null check operator used on a null value` names neither.
      expect(
        () => TomAnnotationAnalyzer.analysePersistentType(_Unregistered),
        throwsA(
          isA<TomAnnotationAnalyzerException>().having(
            (e) => e.key,
            'key',
            'annotation_analyzer.analyse_persistent_type.mirror_not_found',
          ),
        ),
      );
    });

    test('analysePersistentType names the missing @TomDbTable', () {
      expect(
        () => TomAnnotationAnalyzer.analysePersistentType(
          FixtureUnmappedFileRecord,
        ),
        throwsA(
          isA<TomAnnotationAnalyzerException>()
              .having(
                (e) => e.key,
                'key',
                'annotation_analyzer.analyse_persistent_type.table_not_found',
              )
              .having(
                (e) => e.parameters?['type'],
                'type',
                'FixtureUnmappedFileRecord',
              ),
        ),
      );
    });

    test('no library source null-asserts a nullable analyzer lookup', () {
      // The failure this guards is a caller that knows — today — that its type
      // is mapped, and says so with `!` instead of with the lookup that
      // reports. It is correct until the branch that established it moves, and
      // then it is a context-free crash out of a static cache, in code that
      // runs for every entity. Every such site has a nullable-aware form that
      // costs nothing: read once into a local, or ask analysePersistentType.
      final offenders = _nullAssertedLookups(libraryRoot);
      expect(
        offenders,
        isEmpty,
        reason:
            'These lines null-assert a lookup that returns null for an '
            'ordinary, documented reason:\n  ${offenders.join('\n  ')}\n'
            'Read the result into a local and test it, or use '
            'analysePersistentType, which names the type and the missing '
            'annotation instead of throwing a bare null check.',
      );
    });
  });

  group('the source scanner', () {
    test('sees an asserted lookup and leaves a tested one alone', () {
      final found = _scan('sample.dart', [
        'final a = TomAnnotationAnalyzer.findTable(T)!.table;',
        'final b = TomAnnotationAnalyzer.findTable(T);',
        'if (b == null) return;',
        'for (final c in TomAnnotationAnalyzer.getPersistentColumns(T)!) {}',
        'x = TomAnnotationAnalyzer.findDataScope(T)?.field;',
      ]);
      expect(found, [
        'sample.dart:1: final a = TomAnnotationAnalyzer.findTable(T)!.table;',
        'sample.dart:4: for (final c in '
            'TomAnnotationAnalyzer.getPersistentColumns(T)!) {}',
      ]);
    });

    test('ignores a lookup name that appears in prose', () {
      // The dartdoc of these methods discusses them by name constantly, and a
      // scanner that matched a comment would report the documentation as the
      // defect.
      final found = _scan('sample.dart', [
        '/// Unlike findTable(x)! this one reports.',
        '// getPersistentColumns(T)! would crash here.',
      ]);
      expect(found, isEmpty);
    });
  });
}

/// Every line under [root] that null-asserts one of [nullableLookups].
List<String> _nullAssertedLookups(String root) => [
  for (final entity in Directory(root).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart'))
      ..._scan(entity.path, entity.readAsLinesSync()),
];

/// The offending lines among [lines], each rendered as `path:line: text`.
///
/// Matches a call to one of the nullable lookups followed immediately by `!`.
/// Comment lines are skipped: the methods are named throughout their own
/// documentation, including in the sentences that warn against this very shape.
List<String> _scan(String path, List<String> lines) {
  final pattern = RegExp('(?:${nullableLookups.join('|')})\\([^()]*\\)!');
  final found = <String>[];
  for (var index = 0; index < lines.length; index++) {
    final text = lines[index].trim();
    if (text.startsWith('//') || text.startsWith('*')) continue;
    if (pattern.hasMatch(text)) found.add('$path:${index + 1}: $text');
  }
  return found;
}
