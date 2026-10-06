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
/// Three properties carry the rule, and each catches a different mistake:
///
/// - every `resolve…` reads the provider exactly once, through `TomCtr`, and
///   delegates to its matching `parse…`, so no resolver invents a second route
///   to the provider or quietly builds its object inline;
/// - *which* `TomCtr` accessor it reads through is not a free choice: a parser
///   that accepts a bare `dynamic` accepts scalars and lists too, so its
///   resolver must read the raw value or those forms are documented and
///   unreachable — which is exactly what had happened to five of them;
/// - no `parse…` (nor any private helper they share) mentions `TomCtr`, which
///   is what keeps the `parse` half testable with no resources installed.
///
/// This reads the source rather than calling the API on purpose: the claim is
/// about how the file is *written*, and a new helper added the wrong way would
/// otherwise pass every behavioural test in the suite.
/// A static member declaration, capturing its name.
///
/// Both classes are flat — every member sits at one indent level and no nested
/// declaration exists — so a body reliably runs from the declaration to the
/// next line that closes at that same indent.
final _declaration = RegExp(
  r'^  static\s+[\w<>?,\s]+?\s(\w+)\(',
  multiLine: true,
);

/// Maps every static member name in [source] to the text of its body.
Map<String, String> _membersOf(String source) {
  final bodies = <String, String>{};
  for (final match in _declaration.allMatches(source)) {
    final end = source.indexOf('\n  }\n', match.end);
    bodies[match.group(1)!] = end == -1
        ? source.substring(match.start)
        : source.substring(match.start, end);
  }
  return bodies;
}

/// English for [n], as the class dartdoc spells its counts.
///
/// The range is deliberately narrow and a miss is a failure rather than a
/// skip: a class that has grown past it is exactly the class whose comment
/// most needs re-reading, so it should stop the suite, not slip through an
/// unmatched lookup.
String _numberWord(int n) {
  const words = <int, String>{
    3: 'three',
    4: 'four',
    5: 'five',
    6: 'six',
    7: 'seven',
    8: 'eight',
    9: 'nine',
    10: 'ten',
    11: 'eleven',
    12: 'twelve',
    13: 'thirteen',
    14: 'fourteen',
    15: 'fifteen',
    16: 'sixteen',
    17: 'seventeen',
    18: 'eighteen',
    19: 'nineteen',
    20: 'twenty',
  };
  final word = words[n];
  if (word == null) {
    fail(
      'no English word registered for $n, so the count claims in the '
      'TomStyleResolvers dartdoc cannot be checked; extend this map and '
      're-read the comment while you are there',
    );
  }
  return word;
}

void main() {
  group('TomStyleResolvers layering', () {
    final source = File(
      'lib/src/widget_base/tom_style_resolvers.dart',
    ).readAsStringSync();

    final bodies = _membersOf(source);

    final resolvers = bodies.keys
        .where((n) => n.startsWith('resolve'))
        .toList();
    final parsers = bodies.keys.where((n) => n.startsWith('parse')).toList();

    test('the source scan found the members it is meant to check', () {
      // Guards the guard: a regex that stopped matching would leave every
      // assertion below iterating an empty list and passing.
      //
      // The parsers outnumber the resolvers by the two whose resolver lives in
      // TomCtr instead — parseEdgeInsets and parseFontWeight — so the rule
      // below is stated over resolvers, each of which must find its parser,
      // and not over parsers, which need not each find a resolver.
      expect(resolvers, hasLength(17));
      expect(parsers, hasLength(19));
    });

    /// A single leading `dynamic` parameter, which is how a parser declares
    /// that it takes scalars and lists as well as maps.
    ///
    /// Matched on the parameter rather than on `contains('dynamic')`, which
    /// every `Map<String, dynamic>?` signature would satisfy.
    final rawParameter = RegExp(r'\(\s*dynamic\s');

    String signatureOf(String member) {
      final body = bodies[member]!;
      return body.substring(0, body.indexOf('{'));
    }

    final rawParsers = parsers
        .where((p) => rawParameter.hasMatch(signatureOf(p)))
        .toList();

    test('the parsers accepting a raw value are the seven that document one', () {
      // Guards the guard twice over: it pins the derived split so a signature
      // change cannot silently move a resolver out from under the rule below,
      // and it names the seven so the failure is legible.
      //
      // Five of them have a `resolve…` partner in this class and so fall under
      // that rule; parseEdgeInsets and parseFontWeight are resolved by TomCtr,
      // which reads the raw value for the same reason.
      expect(rawParsers..sort(), <String>[
        'parseAlignment',
        'parseBorderRadius',
        'parseEdgeInsets',
        'parseFontWeight',
        'parseOffset',
        'parseScrollPhysics',
        'parseVisualDensity',
      ]);
    });

    test('the class dartdoc counts its own members correctly', () {
      // The two assertions above hold the *members* to a count. Nothing held
      // the *prose* that repeats it, and that asymmetry has already cost
      // something: the class comment opened with a parenthesised list of
      // twelve Flutter types while nineteen parsers sat below it, because a
      // list in a comment is only correct on the day it is written.
      //
      // The list is gone; these counts are what replaced it. A count is small
      // enough to check, so it is checked — otherwise the twentieth parser
      // gets added, `hasLength(19)` above gets corrected, and the comment is
      // left saying nineteen, which is the same drift in a shorter form.
      final classDoc = source.substring(
        0,
        source.indexOf('class TomStyleResolvers {'),
      );

      // Every parser that does not take a bare `dynamic` takes a map, and
      // every raw parser either has its resolver here or in TomCtr — so all
      // four counts follow from the two lists, and none is written twice.
      final mapParsers = parsers.length - rawParsers.length;
      final rawResolvedHere = rawParsers
          .where(
            (p) => resolvers.contains('resolve${p.substring('parse'.length)}'),
          )
          .length;

      final claims = <String>[
        '${_numberWord(parsers.length)} parsers live here',
        '${_numberWord(resolvers.length)} have their',
        '${_numberWord(mapParsers)} parsers take a',
        '${_numberWord(rawParsers.length)} take a bare',
        '${_numberWord(rawResolvedHere)} with resolvers here',
      ];

      for (final claim in claims) {
        expect(
          classDoc.toLowerCase(),
          contains(claim),
          reason:
              'the class dartdoc no longer says "$claim", so a count it '
              'states about its own members has drifted from them',
        );
      }
    });

    test('every resolve reads the provider exactly once, through TomCtr', () {
      for (final resolver in resolvers) {
        expect(
          'TomCtr.'.allMatches(bodies[resolver]!).length,
          1,
          reason:
              '$resolver does not make exactly one TomCtr call, so it is '
              'either reaching the provider from somewhere other than TomCtr '
              'or reading it twice for one value',
        );
      }
    });

    test('a resolver reads the raw value exactly when its parser accepts one', () {
      for (final resolver in resolvers) {
        final parser = 'parse${resolver.substring('resolve'.length)}';
        final takesRaw = rawParsers.contains(parser);
        expect(
          bodies[resolver],
          contains(takesRaw ? 'TomCtr.value(' : 'TomCtr.map('),
          reason: takesRaw
              ? '$parser accepts a scalar or a list, but $resolver reads '
                    'TomCtr.map, which yields null for anything that is not a '
                    'map — so those documented forms are unreachable from a '
                    'resource'
              : '$parser only accepts a map, so $resolver must read TomCtr.map '
                    'rather than hand it a raw value it has no signature for',
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
          reason:
              '$resolver builds its object itself instead of delegating to '
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
          reason:
              '$member reaches the resource provider, so it can no longer '
              'be called with a plain map and the parse half stops being '
              'testable without resources',
        );
      }
    });
  });

  /// The two classes may call each other, but they may not each hold their own
  /// copy of the same helper.
  ///
  /// Private clones of `_parseEdgeInsets`, `_asNum` and `_parseFontWeight` in
  /// `TomCtr` would be copies kept in step by hand, and hand-kept copies
  /// drift: one accepting strictly less than its twin is the typical result.
  ///
  /// A shared name is the signal, not the identical body: two functions in this
  /// module named `_parseX` are two answers to one question, and a maintainer
  /// fixing one will not think to look for the other. Checking names rather
  /// than bodies also catches the case the comment could not — copies that have
  /// already diverged.
  group('TomCtr and TomStyleResolvers do not each hold their own helper', () {
    final helpers = File(
      'lib/src/widget_base/tom_construction_helpers.dart',
    ).readAsStringSync();
    final resolvers = File(
      'lib/src/widget_base/tom_style_resolvers.dart',
    ).readAsStringSync();

    final inTomCtr = _membersOf(helpers).keys.toSet();
    final inResolvers = _membersOf(resolvers).keys.toSet();

    test('the source scan found members in both files', () {
      // Guards the guard: an empty set on either side would make the
      // intersection empty and the assertion below vacuous.
      expect(inTomCtr, isNotEmpty);
      expect(inResolvers, isNotEmpty);
    });

    test('no member name is declared in both classes', () {
      expect(
        (inTomCtr.intersection(inResolvers).toList()..sort()),
        isEmpty,
        reason:
            'a name declared in both classes is the same question answered '
            'twice; move the implementation to TomStyleResolvers, which owns '
            'the value-to-object parsers, and have TomCtr call it after '
            'reading the resource',
      );
    });

    test('TomCtr reaches the shared parsers by name', () {
      // The two parsers TomStyleResolvers exposes without a `resolve…` partner
      // are public *because* TomCtr is their resolver. If that call went away
      // the parser would be public for no reason, and the duplicate would be
      // the obvious way to bring the behaviour back.
      for (final parser in <String>['parseEdgeInsets', 'parseFontWeight']) {
        expect(
          helpers,
          contains('TomStyleResolvers.$parser('),
          reason: 'TomCtr no longer routes through $parser',
        );
      }
    });
  });
}
