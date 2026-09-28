/// Every per-component setter refuses when there is no current component.
///
/// A per-component setter with no component is a misordered chain, and the
/// value the caller wrote is dropped: `append(x).gap().setPSize(200)` sizes
/// nothing. Nothing reported that — the layout merely came out subtly wrong,
/// which costs far more to find than a throw at the call that is wrong.
///
/// The family was also inconsistent in exactly the respect a caller wants it to
/// be consistent in: fourteen returned silently and `setHideUnauthorized` threw.
///
/// Three ways to have no current component, and each is tested for every
/// setter rather than once for the family: before the first `append`, after a
/// `gap`, and after a `newRow`. They are separate code paths — `gap` and
/// `newRow` each clear the component for their own reasons — so a regression in
/// one would otherwise hide behind the others.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Calls one per-component setter on [b], named for the message it should
/// raise.
///
/// [reference] says where this setter needs its reference widget to be, since
/// `alignX*` requires a *different* row and `alignY*` requires the *same* one —
/// opposite preconditions, so one fixture cannot satisfy both.
typedef _Setter = ({
  String name,
  void Function(AclBuilder b) call,
  _Reference reference,
});

enum _Reference { none, previousRow, sameRow }

/// The widget a reference-taking setter points at.
///
/// The builder keys its row map by the appended *object*, so a reference must
/// be the very widget that was appended — a `Key` alone is not registered.
const _referenceWidget = SizedBox(key: ValueKey('elsewhere'));

final _setters = <_Setter>[
  (name: 'setPSize', call: (b) => b.setPSize(200), reference: _Reference.none),
  (name: 'setMSize', call: (b) => b.setMSize(50), reference: _Reference.none),
  (name: 'setXSize', call: (b) => b.setXSize(400), reference: _Reference.none),
  (
    name: 'setPWidthInChars',
    call: (b) => b.setPWidthInChars(10),
    reference: _Reference.none,
  ),
  (
    name: 'setMWidthInChars',
    call: (b) => b.setMWidthInChars(4),
    reference: _Reference.none,
  ),
  (
    name: 'setXWidthInChars',
    call: (b) => b.setXWidthInChars(20),
    reference: _Reference.none,
  ),
  (
    name: 'setAttr',
    call: (b) => b.setAttr(AclFlags.expandX),
    reference: _Reference.none,
  ),
  (
    name: 'clearAttr',
    call: (b) => b.clearAttr(AclFlags.expandX),
    reference: _Reference.none,
  ),
  (
    name: 'setComp',
    call: (b) => b.sameWidthAs(_referenceWidget),
    reference: _Reference.previousRow,
  ),
  (
    name: 'setVerticalAlignment',
    call: (b) => b.setVerticalAlignment(AclRowCrossAlignment.bottom),
    reference: _Reference.none,
  ),
  (
    name: 'setHideUnauthorized',
    call: (b) => b.setHideUnauthorized(true),
    reference: _Reference.none,
  ),
  (name: 'setId', call: (b) => b.setId('x'), reference: _Reference.none),
  (name: 'group', call: (b) => b.group('g'), reference: _Reference.none),
  (
    name: 'alignX*',
    call: (b) => b.alignLeftToLeft(_referenceWidget),
    reference: _Reference.previousRow,
  ),
  (
    name: 'alignY*',
    call: (b) => b.alignTopToTop(_referenceWidget),
    reference: _Reference.sameRow,
  ),
];

void main() {
  group('a per-component setter with no component throws', () {
    /// The three ways to arrive with no current component.
    final starts = <String, AclBuilder Function()>{
      'before the first append': AclBuilder.new,
      'after a gap': () => AclBuilder().append(const Text('a')).gap(),
      'after a newRow': () => AclBuilder().append(const Text('a')).newRow(),
    };

    for (final setter in _setters) {
      for (final start in starts.entries) {
        test('${setter.name}, ${start.key}', () {
          expect(
            () => setter.call(start.value()),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains(setter.name),
              ),
            ),
            reason:
                'the value would be discarded, and nothing else would say so',
          );
        });
      }
    }

    test('the same refusal, whichever way the component went away', () {
      // One message, so a reader diagnosing a misordered chain is not asked to
      // learn three.
      final messages = <String>{};
      for (final start in starts.values) {
        try {
          AclBuilder b = start();
          b.setPSize(200);
        } on StateError catch (e) {
          messages.add(e.message);
        }
      }
      expect(messages, hasLength(1));
    });
  });

  group('a setter still applies when there is a component', () {
    // Without this the assertions above pass for a builder that throws from
    // every setter unconditionally.
    test('each one leaves the chain usable', () {
      for (final setter in _setters) {
        final b = AclBuilder();
        if (setter.reference == _Reference.previousRow) {
          b.append(_referenceWidget).newRow();
        }
        b.append(const Text('target'));
        if (setter.reference == _Reference.sameRow) {
          b.append(_referenceWidget);
        }
        expect(
          () => setter.call(b),
          returnsNormally,
          reason: '${setter.name} must apply to the component just appended',
        );
      }
    });

    test('setPSize reaches the component it names', () {
      final acl = AclBuilder()
          .append(const Text('a'))
          .setId('a')
          .setPSize(200, 30)
          .build();
      expect(acl.rows[0].components[0].preferredSize, const Size(200, 30));
    });
  });

  group('every per-component setter goes through the one guard', () {
    // The durable half. A setter added later that reads `_currentComponent`
    // itself would reintroduce a fourteenth behaviour, and nothing about its
    // output would say so.
    late List<String> lines;

    setUp(() {
      lines = File(
        'lib/src/advanced_container_layout/acl_builder.dart',
      ).readAsLinesSync();
    });

    /// The methods that legitimately touch `_currentComponent` directly: the
    /// one that creates it, the ones that clear it, and the finalizer that
    /// must tolerate its absence because `build()` calls it unconditionally.
    const lifecycle = <String>{
      '_finalizeCurrentComponent',
      'append',
      'gap',
      'newRow',
      'gapRow',
    };

    test('no other method reads _currentComponent directly', () {
      final declaration = RegExp(r'^  ([A-Za-z_][\w<>?,\[\] ]*?)\s+(\w+)\s*\(');
      const keywords = {'if', 'for', 'while', 'switch', 'return', 'throw'};
      final offenders = <String>{};
      String? current;

      for (var i = 0; i < lines.length; i++) {
        final match = declaration.firstMatch(lines[i]);
        if (match != null &&
            !keywords.contains(match.group(2)) &&
            !keywords.contains(match.group(1)!.split(' ').first)) {
          current = match.group(2);
        }
        // The field's own declaration belongs to no method.
        if (lines[i].trimLeft().startsWith(
          '_ComponentData? _currentComponent',
        )) {
          continue;
        }
        if (!lines[i].contains('_currentComponent')) continue;
        if (current == null || lifecycle.contains(current)) continue;
        // The field's own declaration and the guard that reads it.
        if (current == '_requireComponent') continue;
        offenders.add('$current (line ${i + 1})');
      }

      expect(
        offenders.toList()..sort(),
        isEmpty,
        reason:
            'these read _currentComponent without going through '
            '_requireComponent, so they answer a missing component their own '
            'way instead of the family\'s: $offenders',
      );
    });

    test('the guard and the lifecycle methods all still exist', () {
      // A guard on the guard: if the scan matched nothing the case above
      // passes vacuously.
      final source = lines.join('\n');
      expect(source, contains('_ComponentData _requireComponent(String '));
      for (final name in lifecycle) {
        expect(
          source,
          contains(RegExp(r'\b' + name + r'\s*\(')),
          reason: '$name is listed as lifecycle and no longer exists',
        );
      }
    });
  });
}
