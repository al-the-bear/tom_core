import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `TomStyleResolvers` and `TomCtr` are divided by *what they take in*, not by
/// what they import — both need the Material library, so imports could never
/// have told them apart.
///
/// The dartdoc on `TomStyleResolvers` and `doc/widget_base.md` both now state
/// the real criterion: `TomCtr` is the single place that reads the resource
/// provider, and `TomStyleResolvers` assembles composite Flutter objects out of
/// what it returns. That is a rule a maintainer applies when placing a new
/// helper, which makes it worth holding the code to — a stated criterion that
/// nothing checks is how the *previous* rationale survived being false.
///
/// Two properties carry the rule, and each catches a different mistake:
///
/// - every `resolve…` goes through `TomCtr.map` and delegates to its matching
///   `parse…`, so no resolver invents a second route to the provider or
///   quietly builds its object inline;
/// - no `parse…` (nor any private helper they share) mentions `TomCtr`, which
///   is what keeps the `parse` half testable with no resources installed.
///
/// This reads the source rather than calling the API on purpose: the claim is
/// about how the file is *written*, and a new helper added the wrong way would
/// otherwise pass every behavioural test in the suite.
void main() {
  group('TomStyleResolvers layering', () {
    final source =
        File('lib/src/widget_base/tom_style_resolvers.dart').readAsStringSync();

    /// A static member declaration, capturing its name.
    ///
    /// The class is flat — every member sits at one indent level and no nested
    /// declaration exists — so a body reliably runs from the declaration to the
    /// next line that closes at that same indent.
    final declaration = RegExp(r'^  static\s+[\w<>?,\s]+?\s(\w+)\(',
        multiLine: true);

    final bodies = <String, String>{};
    for (final match in declaration.allMatches(source)) {
      final end = source.indexOf('\n  }\n', match.end);
      bodies[match.group(1)!] =
          end == -1 ? source.substring(match.start) : source.substring(
              match.start, end);
    }

    final resolvers = bodies.keys.where((n) => n.startsWith('resolve')).toList();
    final parsers = bodies.keys.where((n) => n.startsWith('parse')).toList();

    test('the source scan found the members it is meant to check', () {
      // Guards the guard: a regex that stopped matching would leave every
      // assertion below iterating an empty list and passing.
      expect(resolvers, hasLength(17));
      expect(parsers, hasLength(17));
    });

    test('every resolve reads the provider through TomCtr.map only', () {
      for (final resolver in resolvers) {
        expect(
          bodies[resolver],
          contains('TomCtr.map('),
          reason: '$resolver does not read its map through TomCtr.map, so the '
              'provider is being reached from somewhere other than TomCtr',
        );
      }
    });

    test('every resolve delegates to its matching parse', () {
      for (final resolver in resolvers) {
        final parser = 'parse${resolver.substring('resolve'.length)}';
        expect(
          bodies.containsKey(parser),
          isTrue,
          reason: '$resolver has no $parser partner',
        );
        expect(
          bodies[resolver],
          contains('$parser('),
          reason: '$resolver builds its object itself instead of delegating to '
              '$parser, so the composition it performs cannot be tested '
              'without installed resources',
        );
      }
    });

    test('no parse or private helper touches TomCtr', () {
      final providerFree = bodies.keys.where((n) => !n.startsWith('resolve'));
      for (final member in providerFree) {
        expect(
          bodies[member],
          isNot(contains('TomCtr')),
          reason: '$member reaches the resource provider, so it can no longer '
              'be called with a plain map and the parse half stops being '
              'testable without resources',
        );
      }
    });
  });
}
