/// Every size and alignment reference must name a component this builder has.
///
/// An unresolvable reference has no symptom of its own: a fabricated key
/// attached to nothing still builds, the component simply keeps its own size,
/// and a typo in the captured variable reads as "these two do not match" with
/// nothing pointing at the call that caused it. So the refusal belongs where
/// the reference is written, and every one of the five methods owes the same
/// one — which is what these cases hold.
///
/// `doc/acl_design_specification.md` §15 states the rule for all five and for
/// raw `Key` arguments; the `Widget` parameter type carries the `Key` half.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// The reference methods, by the family that shares one row rule.
///
/// `sameSize` stands in for `sameWidthAs` / `sameHeightAs` on the cases where
/// the dimension is irrelevant; the dimension itself is covered separately.
typedef _Ref = ({String name, void Function(AclBuilder b, Widget ref) call});

const _sizeRefs = <_Ref>[
  (name: 'sameWidthAs', call: _sameWidthAs),
  (name: 'sameHeightAs', call: _sameHeightAs),
  (name: 'sameSize', call: _sameSize),
];

void _sameWidthAs(AclBuilder b, Widget ref) => b.sameWidthAs(ref);
void _sameHeightAs(AclBuilder b, Widget ref) => b.sameHeightAs(ref);
void _sameSize(AclBuilder b, Widget ref) => b.sameSize(ref);

const _allRefs = <_Ref>[
  ..._sizeRefs,
  (name: 'alignLeftToLeft', call: _alignX),
  (name: 'alignTopToTop', call: _alignY),
];

void _alignX(AclBuilder b, Widget ref) => b.alignLeftToLeft(ref);
void _alignY(AclBuilder b, Widget ref) => b.alignTopToTop(ref);

/// A builder whose first row holds [anchor], positioned on a second row so a
/// cross-row reference to [anchor] is legal and a same-row one is not.
AclBuilder _withAnchorInRow0(Widget anchor) =>
    AclBuilder().append(anchor).newRow().append(const Text('target'));

void main() {
  group('a reference the builder has no component for is refused', () {
    for (final ref in _allRefs) {
      test('${ref.name}, widget never appended', () {
        const stranger = Text('stranger');
        expect(
          () => ref.call(_withAnchorInRow0(const Text('anchor')), stranger),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains(ref.name.startsWith('align') ? 'align' : 'same'),
                contains('append()'),
              ),
            ),
          ),
        );
      });

      test('${ref.name}, widget appended later', () {
        // Indistinguishable from "never" at the call, and the builder must not
        // guess: an entry created now would make a same-row reference legal
        // that the row rules forbid.
        const later = Text('later');
        final b = AclBuilder().append(const Text('first')).newRow();
        b.append(const Text('target'));
        expect(() => ref.call(b, later), throwsUnsupportedError);
      });
    }
  });

  group('a Flexible, Expanded or Spacer is refused by name', () {
    // These are appended but carry no component key, so the generic "no
    // component for it" message would send the reader looking for a missing
    // append() that is right there.
    final unkeyed = <String, Widget>{
      'Flexible': Flexible(child: Container()),
      'Expanded': Expanded(child: Container()),
      'Spacer': const Spacer(),
    };

    for (final entry in unkeyed.entries) {
      test('sameWidthAs a ${entry.key}', () {
        final b = AclBuilder()
            .append(entry.value)
            .newRow()
            .append(const Text('target'));
        expect(
          () => b.sameWidthAs(entry.value),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Flexible'),
                contains('Expanded'),
                contains('Spacer'),
              ),
            ),
          ),
        );
      });
    }
  });

  group('a legal reference still resolves to the referenced component', () {
    // Without this the refusals above are satisfied by a builder that rejects
    // every reference.
    test('each method links to the anchor\'s own key', () {
      for (final ref in _allRefs) {
        const anchor = Text('anchor');
        final b = _withAnchorInRow0(anchor);
        final isAlignY = ref.name == 'alignTopToTop';
        if (isAlignY) {
          // alignY* is the same-row family: give it a same-row anchor.
          const sameRow = Text('same row');
          final c = AclBuilder().append(sameRow).append(const Text('target'));
          c.alignTopToTop(sameRow);
          final acl = c.build();
          expect(
            acl.rows[0].components[1].alignYToKey,
            same(acl.rows[0].components[0].componentKey),
            reason: '${ref.name} must point at the anchor that was appended',
          );
          continue;
        }
        ref.call(b, anchor);
        final acl = b.build();
        final target = acl.rows[1].components[0];
        final anchorKey = acl.rows[0].components[0].componentKey;
        expect(
          ref.name == 'alignLeftToLeft'
              ? target.alignXToKey
              : target.referenceKey,
          same(anchorKey),
          reason: '${ref.name} must point at the anchor that was appended',
        );
      }
    });

    test('the dimension flag follows the method that was called', () {
      // The unknown-reference path used to set the flag whether or not a
      // relationship had been established; it is now reached only once one has.
      const anchor = Text('anchor');
      AclComponent linked(void Function(AclBuilder) call) {
        final b = _withAnchorInRow0(anchor);
        call(b);
        return b.build().rows[1].components[0];
      }

      final width = linked((b) => b.sameWidthAs(anchor));
      expect((width.useOtherDimX, width.useOtherDimY), (true, false));
      final height = linked((b) => b.sameHeightAs(anchor));
      expect((height.useOtherDimX, height.useOtherDimY), (false, true));
      final both = linked((b) => b.sameSize(anchor));
      expect((both.useOtherDimX, both.useOtherDimY), (true, true));
    });
  });

  group('setComp refuses an attribute that carries no dimension', () {
    // The raw-int entry point masks its argument to the otherDim bits. Silently
    // masking to zero recorded a reference the layout never reads.
    test('no otherDim bit', () {
      const anchor = Text('anchor');
      expect(
        () => _withAnchorInRow0(anchor).setComp(anchor, AclFlags.expandX),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a dimension bit alongside another flag is accepted', () {
      const anchor = Text('anchor');
      final b = _withAnchorInRow0(anchor);
      b.setComp(anchor, AclFlags.otherDimX | AclFlags.expandX);
      final c = b.build().rows[1].components[0];
      expect(c.useOtherDimX, isTrue);
      expect(
        c.flags & AclFlags.expandX,
        0,
        reason: 'setComp takes the dimension bits and nothing else',
      );
    });
  });

  group('the row rules still hold', () {
    test('sameWidthAs refuses a same-row anchor', () {
      const anchor = Text('anchor');
      final b = AclBuilder().append(anchor).append(const Text('target'));
      expect(() => b.sameWidthAs(anchor), throwsUnsupportedError);
    });

    test('alignX* refuses a same-row anchor', () {
      const anchor = Text('anchor');
      final b = AclBuilder().append(anchor).append(const Text('target'));
      expect(() => b.alignLeftToLeft(anchor), throwsUnsupportedError);
    });

    test('alignY* refuses a cross-row anchor', () {
      const anchor = Text('anchor');
      final b = _withAnchorInRow0(anchor);
      expect(() => b.alignTopToTop(anchor), throwsUnsupportedError);
    });
  });
}
