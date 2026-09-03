/// Checks that the variants behind a conditional export present one signature.
///
/// Two modules select an implementation with `export ... if (dart.library.io)`
/// — `configuration`'s `TomFileClientConfigurationStore` (two variants) and
/// `preferences`' `TomPlatformDevicePreferenceStore` (three). The whole point of
/// that mechanism is that one name means one thing on every target, so a
/// difference between the variants is a compile error waiting for a platform
/// switch: code that builds on the platform you are working on fails on the one
/// you are not, and the compiler only says so once someone builds for it.
///
/// **Constness is the difference that keeps happening.** A variant whose job is
/// to fail loudly does it by throwing from its constructor body, and a
/// constructor with a body cannot be `const`. The variants that *could* be const
/// therefore must not be: otherwise `const Store(location)` compiles on the
/// working targets and breaks the build on the one whose intended behaviour was
/// a run-time failure — converting a locatable startup diagnostic into a build
/// break at an unrelated call site. tcopen198 established this for
/// `configuration`, tcinc665 for `preferences`.
///
/// **Why the source is read with comments stripped, and the summary only in its
/// code fences.** The rationale above is written into the very dartdoc these
/// checks scan — and again into the API summary beside the signature — and both
/// copies have to quote the `const Store(...)` expression they are warning
/// about. Matched against the raw text, the guard reports a `const` declaration
/// that does not exist and fails on correct code. That is not hypothetical: it
/// is what these checks did, in both places, the moment the explanatory prose
/// was written. The `configuration` source copy escaped only because its
/// paragraph happened to wrap between `const` and the class name — a false pass
/// one reflow away.
///
/// Both fixes are the same idea: **read the declaration, not the discussion of
/// it.** In Dart that means dropping comments; in a Markdown summary it means
/// reading only the fenced `dart` blocks, which is where a summary states a
/// signature and where prose by construction cannot reach.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [source] with `///` and `//` comment lines and `/* */` blocks removed.
///
/// Line-oriented, which is all these declaration-shape checks need: it does not
/// understand a `//` inside a string literal. Nothing it is used on contains
/// one, and a guard that quietly mis-parses is worse than one with a stated
/// limit.
String sourceWithoutComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// Whether [file] *declares* [className]'s constructor `const` — as code, not
/// as prose in a comment.
bool declaresConstConstructor(String file, String className) => RegExp(
  '\\bconst\\s+$className\\s*\\(',
).hasMatch(sourceWithoutComments(File(file).readAsStringSync()));

/// The contents of [markdown]'s fenced ` ```dart ` blocks, joined.
///
/// An API summary states a signature in a code fence and explains it in prose
/// around one. Reading only the fences is what lets the prose quote the very
/// expression a check is looking for without the check mistaking the warning
/// for the thing warned about.
String fencedDartOf(String markdown) => RegExp(
  r'```dart\n([\s\S]*?)```',
  multiLine: true,
).allMatches(markdown).map((m) => m.group(1)!).join('\n');

/// Whether the API summary at [summaryPath] *states* [className]'s constructor
/// `const`, judged by its signature blocks alone.
bool summaryDeclaresConstConstructor(String summaryPath, String className) =>
    RegExp(
      '\\bconst\\s+$className\\s*\\(',
    ).hasMatch(fencedDartOf(File(summaryPath).readAsStringSync()));

/// The public member names [file] declares at class level.
Set<String> publicMembersOf(String file) {
  // `(?! )` pins the match to exactly one indent level — a class member.
  // Without it the character class swallows the deeper indentation of a method
  // body and every local variable reads as a member.
  return RegExp(
        r'^  (?! )(?:final |const )?[\w<>?, ]*\b(\w+)\s*[(;=]',
        multiLine: true,
      )
      .allMatches(sourceWithoutComments(File(file).readAsStringSync()))
      .map((m) => m.group(1)!)
      .where((name) => !name.startsWith('_'))
      .toSet();
}

/// Asserts every variant in [variantPaths] makes the same choice about `const`
/// for [className]'s constructor.
///
/// Stated as agreement rather than as "none is const" because agreement is the
/// actual contract. The impossible direction — making them all const — is
/// barred by the compiler for any variant that throws from its body, and the
/// caller is expected to pin that throw with a test of its own so agreement
/// cannot be reached by deleting it.
void expectVariantsAgreeOnConst({
  required Iterable<String> variantPaths,
  required String className,
}) {
  final choices = <bool, List<String>>{};
  for (final path in variantPaths) {
    choices
        .putIfAbsent(declaresConstConstructor(path, className), () => [])
        .add(path);
  }

  expect(
    choices,
    hasLength(1),
    reason:
        'a `const $className(...)` expression must compile on every target '
        'or on none, and these variants disagree: '
        '${choices[true] ?? const []} declare it const, '
        '${choices[false] ?? const []} do not',
  );
}

/// Asserts every variant in [variantPaths] declares the same public members.
///
/// Compared against the first path rather than pairwise, so a failure names the
/// two files that disagree instead of reporting a set difference of three.
void expectVariantsDeclareSameMembers(Iterable<String> variantPaths) {
  final paths = variantPaths.toList();
  final reference = paths.first;
  for (final path in paths.skip(1)) {
    expect(
      publicMembersOf(path),
      publicMembersOf(reference),
      reason:
          'the variants are interchangeable by name, so a member present '
          'on one and absent on another is a compile error waiting for a '
          'platform switch ($path vs $reference)',
    );
  }
}
