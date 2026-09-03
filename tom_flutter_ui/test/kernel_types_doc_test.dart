// `lib/src/kernel_types.dart` carries a fixed list of kernel names, and
// `doc/kernel_types.md` enumerates that list in prose. Nothing kept the two in
// step before, and they drifted: the previous list's documentation named eight
// of its nine names, omitting `AuthGroupMode` — the enum deciding whether a
// group narrows, replaces or lifts its members' states. An enumeration that
// silently loses an entry is worse than no enumeration, because it still reads
// as complete.
//
// This is the third guard on the bridge, and the only one that reads prose.
// `tool/check_kernel_bridge.py` checks that every kernel type in a public
// signature is on the list; `test/kernel_types_test.dart` checks that every
// name on the list resolves through the barrel; this file checks that the list
// and its documentation say the same thing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('doc/kernel_types.md enumerates the bridge', () {
    test('names every symbol the show list carries', () {
      // The library dartdoc discusses the show list at length; drop it before
      // matching so its prose cannot be mistaken for the list itself.
      final source = File('lib/src/kernel_types.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '');
      final shown = RegExp(r'show\s+([^;]+);').firstMatch(source);
      expect(shown, isNotNull, reason: 'no show list in kernel_types.dart');

      // The show list is commented by group; the comments name no types, but
      // they do name members and neighbouring classes, so strip them first.
      final names = shown!
          .group(1)!
          .replaceAll(RegExp(r'//.*'), '')
          .split(',')
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .toList();
      // A tripwire, not a fact worth knowing: widening the bridge is a
      // deliberate act, so it should require saying so in two places. Bump
      // this and the count in the doc's "The list" heading together.
      expect(names, hasLength(27));

      final doc = File('doc/kernel_types.md').readAsStringSync();
      final start = doc.indexOf('## The list');
      expect(start, greaterThan(-1), reason: 'no "The list" section');
      final end = doc.indexOf('\n## ', start + 1);
      final section = doc.substring(start, end == -1 ? doc.length : end);

      final missing = names.where((n) => !section.contains('`$n`')).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'the bridge shows these names, but the "The list" section '
            'of doc/kernel_types.md never mentions them: $missing',
      );
    });
  });
}
