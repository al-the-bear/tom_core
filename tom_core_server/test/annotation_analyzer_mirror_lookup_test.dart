/// Tests that a failure to reflect an entity is reported as what it is.
///
/// `TomAnnotationAnalyzer.findMirror` is the gate every entity's mapping passes
/// through, and it answers `null` for a type it cannot reflect. That answer is
/// correct for exactly one cause — the type is not registered with
/// `tomReflector` — and wrong for every other, because each of the others is a
/// fault the developer has to be told about: reflection was never initialized,
/// or the name resolves to something that is not a class. Reported as `null`
/// they all arrive later as "it is not in tomReflector", which is a plausible
/// and misleading diagnosis; it sends the reader to the entity's annotations
/// and its generated file, neither of which is at fault.
///
/// So the tolerated cause is caught by its own type and everything else is
/// allowed out, wrapped. This file pins both halves — that the tolerated case
/// still resolves to `null`, and that the two faults no longer can.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureAmountSummary, FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// The analyzer, read for the structural assertion below.
const String analyzerSource =
    'lib/src/tomserver/object_persistence/annotation_analyzer.dart';

/// A class deliberately left out of the reflection root: no `@tomReflector`,
/// so `tomReflector` has no mirror for it. This is the one cause `findMirror`
/// tolerates.
class UnreflectedRecord {
  /// A field, so the class is not empty; never read.
  String name = '';
}

void main() {
  setUpAll(initializeReflection);

  group('a type that is simply not registered', () {
    test('resolves to null rather than raising', () {
      expect(TomAnnotationAnalyzer.findMirror(UnreflectedRecord), isNull);
    });

    test('is still reported by name when a caller needs the metadata', () {
      // The tolerated case has a diagnosis of its own, one call up. Keeping it
      // is the reason findMirror answers `null` at all.
      expect(
        () => TomAnnotationAnalyzer.analysePersistentType(UnreflectedRecord),
        throwsA(
          isA<TomAnnotationAnalyzerException>().having(
            (error) => error.defaultUserMessage,
            'message',
            allOf(contains('UnreflectedRecord'), contains('tomReflector')),
          ),
        ),
      );
    });

    test('a registered entity still resolves', () {
      expect(TomAnnotationAnalyzer.findMirror(FixtureTaskRecord), isNotNull);
    });
  });

  group('a name that is not a class', () {
    test('is reported instead of being answered as unregistered', () {
      // `dynamic` and `void` are registered with every reflector that has the
      // type capability, and neither has a ClassMirror. A generic parameter
      // that erased to `dynamic` reaches here, and answering `null` accuses
      // the reflection setup of a gap it does not have.
      expect(
        () => TomAnnotationAnalyzer.findMirror(dynamic),
        throwsA(
          isA<TomAnnotationAnalyzerException>().having(
            (error) => error.defaultUserMessage,
            'message',
            contains('not a class'),
          ),
        ),
      );
    });

    test('the report is not memoised as an answer', () {
      // A thrown lookup must not leave `null` behind for the type: the second
      // call would then read the memo, return `null`, and the caller would see
      // the misleading diagnosis the first call refused to give.
      expect(
        () => TomAnnotationAnalyzer.findMirror(dynamic),
        throwsA(anything),
      );
      expect(
        () => TomAnnotationAnalyzer.findMirror(dynamic),
        throwsA(anything),
      );
    });
  });

  group('reflection that was never initialized', () {
    test('says so, rather than blaming the entity', () async {
      // Top-level lazy state is per-isolate, so a fresh isolate that never
      // calls `initializeReflection()` reproduces the real deployment fault:
      // one missing call in `main`, against which *every* entity looks
      // unregistered. The reflection library writes the instruction to fix it
      // into its own StateError; the analyzer's job is not to lose it.
      final report = await Isolate.run(() {
        try {
          TomAnnotationAnalyzer.findMirror(FixtureTaskRecord);
          return 'findMirror returned without raising';
        } catch (error) {
          return '$error';
        }
      });
      expect(report, contains('not been initialized'));
      expect(report, contains('initializeReflection'));
    });
  });

  group('analysePersistentType names the missing thing', () {
    test('a reflectable type without @TomDbTable is told which annotation', () {
      // FixtureAmountSummary is reflectable and deliberately carries no
      // @TomDbTable — it is an aggregate holder. The developer's next action is
      // to add the annotation, so the message says that rather than reporting
      // the null-check that noticed.
      expect(
        () => TomAnnotationAnalyzer.analysePersistentType(FixtureAmountSummary),
        throwsA(
          isA<TomAnnotationAnalyzerException>().having(
            (error) => error.defaultUserMessage,
            'message',
            allOf(contains('FixtureAmountSummary'), contains('@TomDbTable')),
          ),
        ),
      );
    });

    test('it absorbs none of its lookups\' failures', () {
      // The module raises two exception types on purpose: a registration
      // mistake and a declaration mistake are fixed in different files. A
      // `catch` here would flatten the second into the first, so the caller
      // could no longer tell them apart — and the analyzer's other callers of
      // getPersistentColumns already let the syntax exception through, so a
      // catch here would also make the module disagree with itself.
      //
      // The three lookups each answer `null` for their own ordinary reason,
      // which this method turns into a diagnosis; nothing else they can do is
      // this method's to relabel.
      final body = _bodyOf('analysePersistentType');
      // Read the body back before judging it: a reader that found nothing
      // would report every future `catch` as absent, and the guard would pass
      // for the rest of its life without ever looking at anything.
      expect(body, contains('mirror_not_found'));
      expect(body, contains('table_not_found'));
      expect(body, contains('columns_not_found'));
      expect(body, isNot(contains('catch')));
    });
  });
}

/// The body of the `static` method [name] in the analyzer source.
///
/// Bounded by the closing brace at the method's own indentation, so the search
/// cannot wander into whatever follows and report a `catch` that belongs to a
/// different method — or miss one because a later method has none.
String _bodyOf(String name) {
  final source = File(analyzerSource).readAsStringSync();
  final start = source.indexOf('$name(Type T) {');
  if (start < 0) return 'the method was not found';
  final end = source.indexOf('\n  }', start);
  return end < 0 ? source.substring(start) : source.substring(start, end);
}
