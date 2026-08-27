import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// `TomWidgetFamily` has 26 values, but they are not equal citizens: 20 are
// fixed by a branch base in `tom_family_base.dart` and reported by concrete
// widgets, while the 6 Tom form values have no branch base and are reported
// by nothing at all. That asymmetry is invisible from the enum declaration —
// which is exactly how the docs came to claim the branch bases covered the
// form families too.
//
// These tests pin the split so neither side can drift silently. Add a 27th
// enum value, or a branch base for `formField`, and the partition assertions
// below fail and send you to `doc/widget_base.md`.
//
// The subclasses are declared here rather than borrowed from `widgets/` on
// purpose: the claim under test is about the *bases*, so the test should not
// break merely because a concrete widget was renamed or retired.

/// Instantiates a branch base with no arguments so `family` can be read.
///
/// `family` is a plain getter — no `BuildContext`, no pumping — so a bare
/// instance is enough. `buildContent` is never called.
Widget _stub(TomFamilyBase w) => w;

class _Button extends TomButtonBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Input extends TomInputBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Select extends TomSelectBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Toggle extends TomToggleBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Slider extends TomSliderBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Container extends TomContainerBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Dialog extends TomDialogBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Table extends TomTableBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Label extends TomLabelBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Image extends TomImageBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Navigation extends TomNavigationBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Progress extends TomProgressBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Chip extends TomChipBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _List extends TomListBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Tree extends TomTreeBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Sliver extends TomSliverBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Animated extends TomAnimatedBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Effect extends TomEffectBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Interaction extends TomInteractionBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _Builder extends TomBuilderBase {
  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

/// One instance per branch base, in declaration order.
final _branchBases = <TomFamilyBase>[
  _Button(),
  _Input(),
  _Select(),
  _Toggle(),
  _Slider(),
  _Container(),
  _Dialog(),
  _Table(),
  _Label(),
  _Image(),
  _Navigation(),
  _Progress(),
  _Chip(),
  _List(),
  _Tree(),
  _Sliver(),
  _Animated(),
  _Effect(),
  _Interaction(),
  _Builder(),
];

/// The six values the taxonomy declares but nothing claims.
const _reservedFormFamilies = <TomWidgetFamily>{
  TomWidgetFamily.formField,
  TomWidgetFamily.dateTimePicker,
  TomWidgetFamily.listEditor,
  TomWidgetFamily.masterDetail,
  TomWidgetFamily.searchField,
  TomWidgetFamily.fileUpload,
};

void main() {
  final covered = _branchBases.map((w) => w.family).toSet();

  group('TomWidgetFamily: which values a branch base actually claims', () {
    test('there are exactly 20 branch bases', () {
      expect(_branchBases, hasLength(20));
    });

    test('each branch base claims a distinct family', () {
      // A duplicate would mean two bases fix `family` to the same value,
      // which would silently shrink the covered set below.
      expect(covered, hasLength(_branchBases.length));
    });

    test('the branch bases cover exactly the 20 Flutter-derived families', () {
      expect(covered, hasLength(20));
      expect(covered.intersection(_reservedFormFamilies), isEmpty);
    });

    test('the 6 Tom form families are claimed by no branch base', () {
      for (final family in _reservedFormFamilies) {
        expect(
          covered.contains(family),
          isFalse,
          reason:
              '$family gained a branch base. That is a real improvement, but '
              'doc/widget_base.md and the TomWidgetFamily dartdoc both state '
              'it has none — update them before relaxing this test.',
        );
      }
    });

    test('covered and reserved partition the enum exactly', () {
      // The load-bearing assertion: no value is both, and none is neither.
      // A 27th enum value fails here even if it is added to neither set.
      expect(covered.union(_reservedFormFamilies), hasLength(26));
      expect(TomWidgetFamily.values.toSet(), covered.union(
        _reservedFormFamilies,
      ));
    });
  });

  group('TomWidgetFamily: multi-family membership is unused', () {
    test('families defaults to the single primary family', () {
      // `families` is overridden nowhere in the package. If that changes,
      // the "reports exactly one family" claim in doc/widget_base.md and in
      // the ACL spec's status note both need revisiting.
      for (final widget in _branchBases) {
        expect(widget.families, {widget.family});
      }
    });

    test('isFamily matches the primary family and nothing else', () {
      for (final widget in _branchBases) {
        expect(widget.isFamily(widget.family), isTrue);
        for (final other in TomWidgetFamily.values) {
          if (other == widget.family) continue;
          expect(widget.isFamily(other), isFalse);
        }
      }
    });

    test('no widget reports a reserved form family', () {
      for (final widget in _branchBases) {
        for (final family in _reservedFormFamilies) {
          expect(widget.isFamily(family), isFalse);
        }
      }
    });
  });

  group('TomWidgetFamily: the taxonomy reads without a widget tree', () {
    test('family resolves on a bare instance', () {
      // Documented in widget_base.md as a pure getter; assert it rather than
      // trusting the prose, since every other test here depends on it.
      expect(_stub(_Button()), isA<TomButtonBase>());
      expect(_Button().family, TomWidgetFamily.button);
      expect(_Builder().family, TomWidgetFamily.builder);
    });
  });
}
