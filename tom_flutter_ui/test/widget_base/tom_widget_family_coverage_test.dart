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

/// One branch base: an instance of it, and the family its *name* claims.
///
/// The type argument names the base the row is about. [instanceMatchesBase]
/// checks that `instance` really extends it, because a row that named one base
/// and held another would assert one binding twice and the named one not at
/// all — and it would still pass, since both families are in the covered set.
class _Binding<T extends TomFamilyBase> {
  _Binding(this.instance, this.expected);

  final TomFamilyBase instance;
  final TomWidgetFamily expected;

  Type get base => T;
  bool get instanceMatchesBase => instance is T;
}

/// Every branch base paired with the family its name claims, in declaration
/// order.
///
/// The expected families are written out here rather than read from the
/// source. Restating them is the whole point: a test that asked each base what
/// its family is and compared it to itself would pass on any answer.
final _bindings = <_Binding>[
  _Binding<TomButtonBase>(_Button(), TomWidgetFamily.button),
  _Binding<TomInputBase>(_Input(), TomWidgetFamily.input),
  _Binding<TomSelectBase>(_Select(), TomWidgetFamily.select),
  _Binding<TomToggleBase>(_Toggle(), TomWidgetFamily.toggle),
  _Binding<TomSliderBase>(_Slider(), TomWidgetFamily.slider),
  _Binding<TomContainerBase>(_Container(), TomWidgetFamily.container),
  _Binding<TomDialogBase>(_Dialog(), TomWidgetFamily.dialog),
  _Binding<TomTableBase>(_Table(), TomWidgetFamily.table),
  _Binding<TomLabelBase>(_Label(), TomWidgetFamily.label),
  _Binding<TomImageBase>(_Image(), TomWidgetFamily.image),
  _Binding<TomNavigationBase>(_Navigation(), TomWidgetFamily.navigation),
  _Binding<TomProgressBase>(_Progress(), TomWidgetFamily.progress),
  _Binding<TomChipBase>(_Chip(), TomWidgetFamily.chip),
  _Binding<TomListBase>(_List(), TomWidgetFamily.list),
  _Binding<TomTreeBase>(_Tree(), TomWidgetFamily.tree),
  _Binding<TomSliverBase>(_Sliver(), TomWidgetFamily.sliver),
  _Binding<TomAnimatedBase>(_Animated(), TomWidgetFamily.animated),
  _Binding<TomEffectBase>(_Effect(), TomWidgetFamily.effect),
  _Binding<TomInteractionBase>(_Interaction(), TomWidgetFamily.interaction),
  _Binding<TomBuilderBase>(_Builder(), TomWidgetFamily.builder),
];

/// One instance per branch base, in declaration order.
///
/// Derived from [_bindings] rather than listed again — two hand-maintained
/// lists of the same twenty classes would be free to disagree, and the set
/// assertions below would keep passing while one of them went short.
final _branchBases = _bindings.map((b) => b.instance).toList();

/// The six values the taxonomy declares but nothing claims.
const _reservedFormFamilies = <TomWidgetFamily>{
  TomWidgetFamily.formField,
  TomWidgetFamily.dateTimePicker,
  TomWidgetFamily.listEditor,
  TomWidgetFamily.masterDetail,
  TomWidgetFamily.searchField,
  TomWidgetFamily.fileUpload,
};

/// A widget reporting two families, which nothing in `lib/` does.
///
/// `formField` + `dateTimePicker` is the pairing
/// `doc/container_widget_resources_authorization.md` §12.2 names as the
/// intent, so the capability is pinned against the case it was designed for
/// rather than an invented one.
///
/// It extends [TomFamilyBase] directly, not a branch base, so it stays outside
/// the 20/6 partition asserted above — a stub that widened `covered` would
/// break the very split this file exists to hold.
class _MultiFamily extends TomFamilyBase {
  @override
  TomWidgetFamily get family => TomWidgetFamily.formField;

  @override
  Set<TomWidgetFamily> get families => {
    TomWidgetFamily.formField,
    TomWidgetFamily.dateTimePicker,
  };

  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

/// A `families` override that leaves out the widget's own primary family.
///
/// Incoherent on its face, and nothing prevents it: `isFamily` reads `families`
/// alone, so this widget answers `false` when asked about the family its own
/// `family` getter returns.
class _FamiliesWithoutPrimary extends TomFamilyBase {
  @override
  TomWidgetFamily get family => TomWidgetFamily.formField;

  @override
  Set<TomWidgetFamily> get families => {TomWidgetFamily.dateTimePicker};

  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

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
      expect(
        TomWidgetFamily.values.toSet(),
        covered.union(_reservedFormFamilies),
      );
    });
  });

  group(
    'TomWidgetFamily: each branch base claims the family it is named for',
    () {
      // Everything in the group above is a statement about *sets* — which
      // families are covered, that they are distinct, that they partition the
      // enum. None of it can see a permutation: swap the bodies of
      // `TomListBase.family` and `TomChipBase.family` and the covered set is
      // unchanged, still 20, still distinct, still disjoint from the reserved
      // six. Every assertion above passes and two bases lie about what they are.
      //
      // The bases are near-identical boilerplate differing in one line, which is
      // exactly the shape that invites a copy-paste slip, and neither the
      // analyzer nor a consumer test can catch it: a widget reporting the wrong
      // family builds and renders perfectly.

      test('every row instantiates the base it names', () {
        for (final binding in _bindings) {
          expect(
            binding.instanceMatchesBase,
            isTrue,
            reason:
                '${binding.instance.runtimeType} does not extend '
                '${binding.base}, so this row asserts nothing about '
                '${binding.base} and covers another base twice',
          );
        }
      });

      test('the table names each of the 20 branch bases exactly once', () {
        expect(_bindings, hasLength(20));
        expect(
          _bindings.map((b) => b.base).toSet(),
          hasLength(20),
          reason:
              'a duplicated base type would leave another untested while '
              'the length check still passed',
        );
      });

      test('each branch base reports the family its name claims', () {
        for (final binding in _bindings) {
          expect(
            binding.instance.family,
            binding.expected,
            reason:
                '${binding.base} reports ${binding.instance.family}. The '
                'name and the family must agree — every tool that switches on '
                'TomWidgetFamily trusts that they do',
          );
        }
      });
    },
  );

  group('TomFamilyBase: how family, families and isFamily relate', () {
    // `doc/widget_base.md` says `families` "allows it to report more than one"
    // without saying how the two connect, and the connection is not the
    // obvious one: `isFamily` consults `families` alone and never `family`.
    // Since nothing in the package overrides `families`, the first widget to
    // do so is the first to find out what the contract actually is.

    test('the default families is exactly the primary family', () {
      expect(_Button().families, {TomWidgetFamily.button});
    });

    test('isFamily answers from families, so an override adds members', () {
      final widget = _MultiFamily();
      expect(widget.families, {
        TomWidgetFamily.formField,
        TomWidgetFamily.dateTimePicker,
      });
      expect(widget.isFamily(TomWidgetFamily.formField), isTrue);
      expect(widget.isFamily(TomWidgetFamily.dateTimePicker), isTrue);
      expect(widget.isFamily(TomWidgetFamily.button), isFalse);
    });

    test('overriding families leaves family alone', () {
      // The two are independent getters; a multi-family widget still has one
      // primary, which is what a tool needing a single answer should read.
      expect(_MultiFamily().family, TomWidgetFamily.formField);
    });

    test('a families override that omits the primary disowns it', () {
      // Pinned as a consequence, not endorsed. `isFamily` reads `families`
      // alone, so a widget can deny the family it reports as primary. The
      // base class could rule this out by composing `families` as
      // `{family, ...extra}`, which would cost a new overridable member for a
      // capability with no users; until there is one, the trap is stated
      // here and in the `families` dartdoc rather than designed around.
      final widget = _FamiliesWithoutPrimary();
      expect(widget.family, TomWidgetFamily.formField);
      expect(
        widget.isFamily(widget.family),
        isFalse,
        reason:
            'if this now passes, families composes in the primary and '
            'the dartdoc warning about omitting it is obsolete',
      );
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
