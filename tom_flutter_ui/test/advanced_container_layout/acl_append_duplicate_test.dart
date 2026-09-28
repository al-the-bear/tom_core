/// `append` takes responsibility for a widget instance exactly once.
///
/// The builder's maps are identity-keyed, and the container attaches a
/// `GlobalKey` to each component it builds. A widget instance that reaches the
/// row twice therefore has one key covering two places in the tree, and a
/// `sameWidthAs` naming it could mean either — so the second append is refused
/// where it is written.
///
/// The flex wrappers are the case worth its own cases: `Flexible`, `Expanded`
/// and `Spacer` get no key of their own, so the widget that has to be distinct
/// is the one *inside* the wrapper, and they are also the widgets a layout is
/// most likely to declare once and reuse.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('the same instance cannot be appended twice', () {
    test('a plain widget', () {
      final w = Container();
      final b = AclBuilder().append(w);
      expect(() => b.append(w), throwsUnsupportedError);
    });

    test('an Expanded', () {
      final e = Expanded(child: Container());
      final b = AclBuilder().append(e);
      expect(
        () => b.append(e),
        throwsA(
          isA<UnsupportedError>().having(
            (x) => x.message,
            'message',
            contains('same widget instance'),
          ),
        ),
      );
    });

    test('a Flexible', () {
      final f = Flexible(child: Container());
      final b = AclBuilder().append(f);
      expect(() => b.append(f), throwsUnsupportedError);
    });

    test('a Spacer', () {
      // The message points at gap(), which is this module's own elastic space
      // and needs no instance at all.
      const spacer = Spacer();
      final b = AclBuilder().append(const Text('a')).append(spacer);
      expect(
        () => b.append(spacer),
        throwsA(
          isA<UnsupportedError>().having(
            (x) => x.message,
            'message',
            contains('gap()'),
          ),
        ),
      );
    });

    test('two separately written const widgets are distinct', () {
      // Measured rather than assumed: `const Spacer()` written twice does not
      // canonicalise to one instance here, so a layout that spells its spacers
      // out is unaffected by the rule above. Only a reused variable trips it.
      expect(
        () => AclBuilder()
            .append(const Text('a'))
            .append(const Spacer())
            .append(const Text('b'))
            .append(const Spacer())
            .build(),
        returnsNormally,
      );
    });

    test('across rows, not just within one', () {
      final w = Container();
      final b = AclBuilder().append(w).newRow();
      expect(() => b.append(w), throwsUnsupportedError);
    });
  });

  group('a flex wrapper is unwrapped to the widget it wraps', () {
    test('the same child in two Expanded wrappers', () {
      final w = Container();
      final b = AclBuilder().append(Expanded(child: w));
      expect(
        () => b.append(Expanded(child: w)),
        throwsA(
          isA<UnsupportedError>().having(
            (x) => x.message,
            'message',
            contains('wraps a widget that was already appended'),
          ),
        ),
      );
    });

    test('appended plainly, then wrapped', () {
      final w = Container();
      final b = AclBuilder().append(w).newRow();
      expect(() => b.append(Expanded(child: w)), throwsUnsupportedError);
    });

    test('wrapped first, then appended plainly', () {
      final w = Container();
      final b = AclBuilder().append(Expanded(child: w)).newRow();
      expect(() => b.append(w), throwsUnsupportedError);
    });

    test('through a chain of wrappers', () {
      final w = Container();
      final b = AclBuilder().append(Flexible(child: Expanded(child: w)));
      expect(() => b.append(w), throwsUnsupportedError);
    });

    test('a wrapper the row does not lay out is compared as itself', () {
      // `Padding` is a component in its own right — it gets its own key, so
      // what is inside it is content, not a second component.
      final w = Container();
      final b = AclBuilder().append(
        Padding(padding: EdgeInsets.zero, child: w),
      );
      expect(
        () => b.append(Padding(padding: const EdgeInsets.all(1), child: w)),
        returnsNormally,
      );
    });

    test('an appended widget may reappear as another component\'s content', () {
      // The other direction, and the line the rule draws: unwrapping every
      // wrapper would refuse this, and it is harmless — the key is on the
      // component, not on `w`, so neither occurrence is ambiguous.
      final w = Container();
      final b = AclBuilder().append(w).newRow();
      expect(
        () => b.append(Padding(padding: EdgeInsets.zero, child: w)),
        returnsNormally,
      );
    });
  });

  group('distinct instances are still accepted', () {
    // Without this the guard is satisfied by an append that refuses
    // everything.
    test('two equal but distinct widgets', () {
      expect(
        () => AclBuilder().append(Container()).append(Container()).build(),
        returnsNormally,
      );
    });

    test('two distinct Expanded wrappers over distinct children', () {
      expect(
        () => AclBuilder()
            .append(Expanded(child: Container()))
            .append(Expanded(child: Container()))
            .build(),
        returnsNormally,
      );
    });
  });

  group('flex-native children reach the row as the row\'s own child', () {
    // The guard above covers a path that has to work: a `ParentDataWidget`
    // whose parent is not the `Row` cannot apply its parent data, so any
    // wrapper the container adds around one is an assertion at first paint.
    for (final entry in <String, Widget Function()>{
      'Expanded': () => Expanded(child: Container()),
      'Flexible': () => Flexible(child: Container()),
      'Spacer': () => const Spacer(),
    }.entries) {
      testWidgets('a ${entry.key} paints', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AclBuilder()
                  .append(const Text('before'))
                  .append(entry.value())
                  .append(const Text('after'))
                  .build(),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('before'), findsOneWidget);
        expect(find.text('after'), findsOneWidget);
      });
    }

    testWidgets('an Expanded takes the row surplus', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: AclBuilder()
                  .append(const SizedBox(width: 100, height: 20))
                  .append(Expanded(child: Container(key: const Key('grew'))))
                  .build(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final width = tester.getSize(find.byKey(const Key('grew'))).width;
      expect(
        width,
        greaterThan(100),
        reason: 'the flex child must receive the row surplus, not a hint size',
      );
    });
  });
}
