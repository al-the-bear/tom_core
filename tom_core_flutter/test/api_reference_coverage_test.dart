/// Holds every module's API summary to the sources it mirrors.
///
/// `doc/api/api_summary_<module>.md` is a mirror of a module's public
/// surface, and a mirror is to be verified rather than trusted: nothing in the
/// toolchain regenerates one, so it stays true only for as long as someone
/// remembers to update it by hand — and a summary that omits a public member
/// the source declares reads as if the member does not exist. A reader deciding
/// what the module offers takes the silence for an answer.
///
/// This is not hypothetical. Six public members of the configuration module
/// were missing from its summary and nobody noticed until a guard was written
/// for that one module. The guard was module-scoped because at the time it had
/// exactly one call site; the other six modules kept the same unverified
/// mirror, and the same drift could sit in any of them.
///
/// **The table is derived, not written.** `lib/src/tomclient/` is the authority
/// on what modules exist — the same authority `module_inventory_test.dart`
/// uses — so a module added tomorrow is covered here without anyone widening a
/// list. A checker told where to look stops covering the package the moment
/// something appears somewhere else, and reports nothing while it does, which
/// is the failure mode this file exists to prevent one level down.
///
/// **What this file does not check**, because
/// `module_inventory_test.dart` already does: that every module *has* a
/// summary, and that no summary outlives the module it documents. Both
/// directions are asserted there as set equality. This file assumes the pairing
/// and checks its contents.
///
/// Connection-free: every test reads source and markdown off disk.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/exception_constructor_mirror.dart';

/// A module and the two artefacts this file compares.
typedef _Module = ({String name, List<String> sources, String summary});

/// The `lib/src/…` paths a caller outside the package can reach.
///
/// The barrel's own exports, plus the variants a conditional export selects —
/// `export 'x_neutral.dart' if (dart.library.io) 'x_io.dart';` puts both behind
/// one reachable name, and the members they declare are that name's members.
///
/// Used to decide what counts as module *surface*. The summaries describe what
/// an application can call, and a file the barrel does not export is not that:
/// it is how the module is built, like a private type, whose members this file
/// already skips for the same reason. Without this, adding an internal helper
/// to a module forces a choice between documenting something no caller can
/// reach and leaving the guard red — and the first is the untruth the guard
/// exists to prevent.
Set<String> _reachableSources() {
  final exported = RegExp(r"^export '([^']+)'", multiLine: true);
  final conditional = RegExp(r"if \([^)]*\) '([^']+)'");
  final reachable = <String>{};
  final barrel = File('lib/tom_core_flutter.dart').readAsStringSync();
  for (final match in exported.allMatches(barrel)) {
    final target = match.group(1)!;
    if (!target.startsWith('src/')) continue;
    reachable.add('lib/$target');
    final selector = File('lib/$target');
    if (!selector.existsSync()) continue;
    // One level deeper, and only one: a selector names its variants directly.
    final source = selector.readAsStringSync();
    final directory = target.substring(0, target.lastIndexOf('/') + 1);
    for (final variant in exported.allMatches(source)) {
      reachable.add('lib/$directory${variant.group(1)!}');
    }
    for (final variant in conditional.allMatches(source)) {
      reachable.add('lib/$directory${variant.group(1)!}');
    }
  }
  return reachable;
}

/// Every module under `lib/src/tomclient/`, with its sources and its summary.
///
/// Read off the directory rather than declared, for the reason the library
/// comment gives. Sources are the module's own `.dart` files that the package
/// barrel actually reaches; a module's `readme.md` is not one, neither is
/// anything a generator wrote, and neither is a file the barrel never exports.
List<_Module> _modules() {
  final root = Directory('lib/src/tomclient');
  final reachable = _reachableSources();
  final modules = <_Module>[];
  for (final entry in root.listSync().whereType<Directory>()) {
    final name = entry.uri.pathSegments[entry.uri.pathSegments.length - 2];
    final sources =
        entry
            .listSync()
            .whereType<File>()
            .map((file) => file.path)
            .where((path) => path.endsWith('.dart'))
            .where((path) => !path.endsWith('.reflection.dart'))
            .where(reachable.contains)
            .toList()
          ..sort();
    modules.add((
      name: name,
      sources: sources,
      summary: 'doc/api/api_summary_$name.md',
    ));
  }
  modules.sort((a, b) => a.name.compareTo(b.name));
  return modules;
}

/// The Dart keywords and clause openers that reach [_declaredPublicMembers]'
/// pattern and are not members.
///
/// A top-level function's body sits at the same indent as a class member, so a
/// statement keyword matches the same shape a field does. They are dropped by
/// name rather than by a cleverer pattern because the list is short, closed and
/// obvious, where a pattern that tried to tell a statement from a declaration
/// would be neither.
const Set<String> _statementKeywords = {
  'get', 'set', 'operator', //
  'if', 'for', 'while', 'do', 'else', 'switch', 'try', 'catch',
  'return', 'throw', 'assert', 'await', 'yield', 'final', 'var',
};

/// Opens a top-level declaration whose members follow at one indent.
///
/// Read so that a member can be attributed to the type declaring it, which is
/// what makes "public" answerable: a `String body` field is public API when its
/// class is and unreachable when its class is not.
final RegExp _typeDeclaration = RegExp(
  r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
  r'(?:class|mixin|enum|extension(?:\s+type)?)\s+(\w+)',
);

/// A member line: indented exactly one level inside a type.
///
/// `(?! )` pins the indent. Without it the character class swallows a method
/// body's deeper indentation and every local variable is reported as public
/// API.
final RegExp _memberDeclaration = RegExp(
  r'^  (?! )(?:@override\s+)?(?:const |final |static |late )*'
  r'[\w<>?, ]*?\b(\w+)\s*(?:\(|=>|;|=[^=])',
);

/// Type names the pattern reports in place of the member they qualify.
///
/// A field declared `final Widget Function(T state) child;` matches at
/// `Function(`, because the pattern stops at the first parenthesis — so it
/// reports the type and not `child`. Losing `child` is the tolerable direction
/// (see [_declaredPublicMembers]); demanding `Function` of a summary is not,
/// since the only way to satisfy that is to write something untrue about the
/// module. Teaching the pattern to skip a nested parameter list would be a
/// small parser rather than a regex, which is a worse trade than naming the one
/// type this arises for.
const Set<String> _typeNamesReadAsMembers = {'Function'};

/// Members the framework calls and a caller never does.
///
/// A summary describes what a module offers its consumer. `createState` is not
/// offered to anyone: Flutter calls it, and a reader who found it in a table
/// would learn nothing they could act on. Demanding it would make the summary
/// worse, since the only way to satisfy the guard is to document a hook as
/// though it were API.
///
/// Named rather than derived from `@override`, because the two are not the same
/// question. `toString` is an override too, and it belongs in a summary — it is
/// what a developer reads out of a log. The distinction is who calls the
/// member, which no annotation records, so the set is written down. It is short,
/// closed and obvious, the same trade as [_statementKeywords].
const Set<String> _frameworkHooks = {
  'build',
  'createState',
  'initState',
  'dispose',
  'didUpdateWidget',
  'didChangeDependencies',
  'debugFillProperties',
  'paint',
  'shouldRepaint',
  'shouldRebuildSemantics',
};

/// Every public member name [sources] declare.
///
/// Deliberately conservative: it reads members indented exactly one level
/// inside a type, and skips four things — `_private` member names, members of a
/// `_Private` type, the declaration keywords, and the framework hooks. A name it
/// reports is one a caller can type and would want to find. Under-reporting is
/// the tolerable failure here and over-reporting is not: a name wrongly demanded
/// of a summary is a fault the author cannot fix except by writing something
/// untrue about the module.
Set<String> _declaredPublicMembers(Iterable<String> sources) {
  final names = <String>{};
  for (final path in sources) {
    var enclosing = '';
    for (final line in File(path).readAsLinesSync()) {
      final type = _typeDeclaration.firstMatch(line);
      if (type != null) {
        enclosing = type.group(1)!;
        continue;
      }
      // A private type's members are unreachable whatever they are called, so
      // a summary that named one would be describing something no caller can
      // use. `_PreferencesResponse.body` is the case that showed this: a
      // public-looking field name on a class the module never exposes.
      if (enclosing.startsWith('_')) continue;
      final member = _memberDeclaration.firstMatch(line);
      if (member == null) continue;
      final name = member.group(1)!;
      if (name.startsWith('_')) continue;
      if (_statementKeywords.contains(name)) continue;
      if (_frameworkHooks.contains(name)) continue;
      if (_typeNamesReadAsMembers.contains(name)) continue;
      names.add(name);
    }
  }
  return names;
}

/// Whether [summary] names [member] as a member rather than in passing.
///
/// Two spellings, because the summaries use both: a backticked name in a table
/// cell, and a call shape in a signature. Matching bare text instead would let
/// a member "appear" because an unrelated sentence happens to contain the word.
bool _summaryNames(String summary, String member) =>
    summary.contains('`$member`') || summary.contains('$member(');

void main() {
  final modules = _modules();

  group('the API summary mirrors its module sources', () {
    for (final module in modules) {
      test(module.name, () {
        final summary = File(module.summary).readAsStringSync();
        final offenders = <String>[
          for (final name in _declaredPublicMembers(module.sources))
            if (!_summaryNames(summary, name)) name,
        ]..sort();

        expect(
          offenders,
          isEmpty,
          reason:
              'these public members are declared in the ${module.name} '
              'sources but named nowhere in ${module.summary}. A summary that '
              'omits a member reads as if the member does not exist.',
        );
      });
    }
  });

  group('an exception the module declares is mirrored with its parameters', () {
    // The name check above cannot see this. An exception class whose
    // constructor is undocumented still has its *name* on the page as a type,
    // so the omission reads as covered — and a parameter shown with the wrong
    // type reads as usable and is not. The types have to be read off the kernel
    // constructor, because `super.x` resolves against it rather than against
    // the field: `uuid`'s field is a non-nullable `late String` while its
    // parameter is `String?`, and documenting either from the other gives the
    // wrong answer.
    for (final module in modules) {
      // Each class is matched against *its own* file, not against the module.
      // `constructorBodyFrom` finds a constructor by looking for `Name(\n`,
      // which a multi-line call site matches as readily as a declaration — so
      // handing it every source in the module lets a `throw TomFooException(`
      // three files away stand in for the declaration, and the guard then
      // compares the summary against an argument list.
      final declaring = <String, String>{
        for (final source in module.sources)
          for (final name in exceptionClassesIn([source])) name: source,
      };
      if (declaring.isEmpty) continue;
      test(module.name, () {
        for (final entry in declaring.entries) {
          expectSummaryListsForwardedParameters(
            summaryPath: module.summary,
            sourcePaths: [entry.value],
            classNames: [entry.key],
          );
        }
        expectSummaryTypesMatchKernel(
          summaryPath: module.summary,
          classNames: declaring.keys,
        );
      });
    }
  });

  group('the sweep is reading what it claims to read', () {
    // Every test above is a "for all" over a derived table, so a table that
    // came back empty would pass all of them while checking nothing — and so
    // would a parser that stopped matching. These are what make the rest mean
    // something.

    test('it finds the package\'s modules, each with sources', () {
      expect(
        modules.map((m) => m.name),
        containsAll(<String>[
          'configuration',
          'little_things',
          'observing',
          'preferences',
          'resources',
          'runtime',
          'security',
        ]),
        reason:
            'the walk of lib/src/tomclient/ missed a module that exists, so '
            'its summary is checked by nothing',
      );
      for (final module in modules) {
        expect(module.sources, isNotEmpty, reason: module.name);
        expect(
          File(module.summary).existsSync(),
          isTrue,
          reason:
              '${module.summary} does not exist — module_inventory_test.dart '
              'is the guard for that and should have failed first',
        );
      }
    });

    test('the parser reports members from every module', () {
      // A floor per module, not a total: a regex that stopped matching one
      // module's style would otherwise hide behind the others' counts.
      for (final module in modules) {
        expect(
          _declaredPublicMembers(module.sources),
          isNotEmpty,
          reason:
              'the parser read no public member at all from ${module.name}, '
              'so its summary is compared against an empty set',
        );
      }
    });

    test('the members the original guard was written for are still read', () {
      // The six configuration members whose omission prompted the guard, plus
      // the two class names. Pinned by name so a regex that stops matching
      // fails here rather than going quiet.
      expect(
        _declaredPublicMembers(
          modules.firstWhere((m) => m.name == 'configuration').sources,
        ),
        containsAll(<String>[
          'toString',
          'path',
          'read',
          'write',
          'load',
          'save',
          'TomClientConfigurationStore',
          'TomClientConfigurationException',
        ]),
      );
    });

    test('a function-typed field does not demand its type', () {
      // The exclusion above, exercised on the declaration that produced it. If
      // the pattern is ever taught to read past a nested parameter list this
      // fails, which is the moment to drop the exclusion rather than leave a
      // rule nobody knows is dead.
      expect(
        _declaredPublicMembers(const [
          'lib/src/tomclient/observing/tom_observing_widget.dart',
        ]),
        isNot(contains('Function')),
      );
    });

    test('a member absent from a summary is actually reported', () {
      // The check itself, applied to a name no summary can contain. Without
      // this the offenders list could be empty because the comparison is broken
      // rather than because the mirrors are complete.
      expect(
        _summaryNames('a summary naming nothing', 'TomNoSuchMember'),
        isFalse,
      );
      expect(_summaryNames('names `TomThing` here', 'TomThing'), isTrue);
      expect(_summaryNames('shows TomThing(a, b)', 'TomThing'), isTrue);
    });
  });
}
