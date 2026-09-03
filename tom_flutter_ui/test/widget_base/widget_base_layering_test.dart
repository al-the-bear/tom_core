import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// `widget_base/` is the foundation the widget layer is built on, and the
/// dependency arrow between them runs one way: `widgets/` imports
/// `widget_base/`, never the reverse.
///
/// That was once false in one place, and the consequence was not theoretical.
/// `TomCtr` imported `widgets/labels/tom_labels.dart` so that two of its
/// members could return a `TomText` — and `TomText` extends `TomFamilyBase`
/// extends `TomPolicyNodeBase` extends `TomNodeBase`, all three of which live
/// in `widget_base/`. So a foundation member depended on three of its own
/// siblings by routing through the layer built on top of them. The cost came
/// due when `TomNodeBase` needed the scope-path rule that already existed on
/// `TomCtr`: calling it would have closed the loop, so the rule had to move to
/// a new Flutter-free file instead. A cycle does not announce itself; it
/// presents as an unrelated helper being unexpectedly unreachable.
///
/// The check is **transitive**, and that is the point. A direct-import check
/// would pass the moment someone routed the same dependency through one
/// intermediate file, which is the shape this kind of violation usually takes
/// once a direct import has been noticed and forbidden.
void main() {
  group('widget_base does not depend on widgets', () {
    const base = 'lib/src/widget_base';
    const forbidden = 'lib/src/widgets';

    /// Relative (first-party) imports of [file], resolved to repo-relative
    /// paths. `package:` and `dart:` imports are not part of the question —
    /// only the internal shape of this library is.
    List<String> relativeImportsOf(String file) {
      final source = File(file).readAsStringSync();
      final matches =
          RegExp(r"^import\s+'([^']+)'", multiLine: true).allMatches(source);
      return [
        for (final match in matches)
          if (!match.group(1)!.startsWith('package:') &&
              !match.group(1)!.startsWith('dart:'))
            p.normalize(p.join(p.dirname(file), match.group(1)!)),
      ];
    }

    final seeds = Directory(base)
        .listSync()
        .whereType<File>()
        .map((f) => p.normalize(f.path))
        .where((f) => f.endsWith('.dart'))
        .toList()
      ..sort();

    test('the source scan found the files it is meant to check', () {
      // Guards the guard: a walk that started from nothing would report no
      // violations for the best possible reason and the worst possible one
      // alike.
      expect(seeds, isNotEmpty);
      expect(seeds, contains('$base/tom_construction_helpers.dart'));
      expect(Directory(forbidden).existsSync(), isTrue);
    });

    test('no file under widget_base/ reaches widgets/, however indirectly', () {
      // Breadth-first so the reported path is the shortest one, which is the
      // one a maintainer can act on: the longer the chain, the more of it is
      // incidental.
      final queue = Queue<List<String>>()..addAll(seeds.map((s) => [s]));
      final visited = <String>{};
      final offences = <List<String>>[];

      while (queue.isNotEmpty) {
        final trail = queue.removeFirst();
        final file = trail.last;
        if (!visited.add(file)) continue;
        if (p.isWithin(forbidden, file)) {
          offences.add(trail);
          continue;
        }
        if (!File(file).existsSync()) continue;
        for (final next in relativeImportsOf(file)) {
          queue.add([...trail, next]);
        }
      }

      expect(
        offences,
        isEmpty,
        reason: 'widget_base/ must not depend on widgets/, but these import '
            'chains do:\n${offences.map((trail) => '  '
                '${trail.map((f) => p.relative(f, from: 'lib/src')).join(' -> ')}').join('\n')}\n'
            'A helper under widget_base/ that needs a widget is a helper in '
            'the wrong layer — it belongs in widgets/, where its callers '
            'already are.',
      );
    });
  });
}
