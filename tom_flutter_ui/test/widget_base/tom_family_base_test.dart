import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// A widget's behavioural family is the branch base it extends: a
// `TomButtonBase` is a button, and `widget is TomButtonBase` is the question a
// caller asks. There is no separate family value to read, so what has to hold
// is the hierarchy itself — twenty bases, each a `TomFamilyBase`, none of them
// extending another, so that every widget belongs to exactly one family.
//
// The subclasses are declared here rather than borrowed from `widgets/` on
// purpose: the claim under test is about the *bases*, so the test should not
// break merely because a concrete widget was renamed or retired.

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

/// One membership test per branch base, keyed by its name.
final Map<String, bool Function(Object)> _isBase = {
  'TomButtonBase': (w) => w is TomButtonBase,
  'TomInputBase': (w) => w is TomInputBase,
  'TomSelectBase': (w) => w is TomSelectBase,
  'TomToggleBase': (w) => w is TomToggleBase,
  'TomSliderBase': (w) => w is TomSliderBase,
  'TomContainerBase': (w) => w is TomContainerBase,
  'TomDialogBase': (w) => w is TomDialogBase,
  'TomTableBase': (w) => w is TomTableBase,
  'TomLabelBase': (w) => w is TomLabelBase,
  'TomImageBase': (w) => w is TomImageBase,
  'TomNavigationBase': (w) => w is TomNavigationBase,
  'TomProgressBase': (w) => w is TomProgressBase,
  'TomChipBase': (w) => w is TomChipBase,
  'TomListBase': (w) => w is TomListBase,
  'TomTreeBase': (w) => w is TomTreeBase,
  'TomSliverBase': (w) => w is TomSliverBase,
  'TomAnimatedBase': (w) => w is TomAnimatedBase,
  'TomEffectBase': (w) => w is TomEffectBase,
  'TomInteractionBase': (w) => w is TomInteractionBase,
  'TomBuilderBase': (w) => w is TomBuilderBase,
};

/// One instance of each branch base, keyed by the base it extends.
final Map<String, TomFamilyBase> _instances = {
  'TomButtonBase': _Button(),
  'TomInputBase': _Input(),
  'TomSelectBase': _Select(),
  'TomToggleBase': _Toggle(),
  'TomSliderBase': _Slider(),
  'TomContainerBase': _Container(),
  'TomDialogBase': _Dialog(),
  'TomTableBase': _Table(),
  'TomLabelBase': _Label(),
  'TomImageBase': _Image(),
  'TomNavigationBase': _Navigation(),
  'TomProgressBase': _Progress(),
  'TomChipBase': _Chip(),
  'TomListBase': _List(),
  'TomTreeBase': _Tree(),
  'TomSliverBase': _Sliver(),
  'TomAnimatedBase': _Animated(),
  'TomEffectBase': _Effect(),
  'TomInteractionBase': _Interaction(),
  'TomBuilderBase': _Builder(),
};

void main() {
  group('the twenty branch bases', () {
    test('there are exactly 20, and each has an instance here', () {
      expect(_isBase, hasLength(20));
      expect(_instances.keys.toSet(), _isBase.keys.toSet());
    });

    test('every branch base is a TomFamilyBase and a TomPolicyNodeBase', () {
      for (final widget in _instances.values) {
        expect(widget, isA<TomFamilyBase>());
        expect(widget, isA<TomPolicyNodeBase>());
      }
    });

    test('a widget belongs to exactly the family it extends', () {
      // Were one base to extend another, a widget of the inner base would
      // answer `is` for both, and "which family is this" would have two
      // answers.
      for (final entry in _instances.entries) {
        final families = [
          for (final base in _isBase.entries)
            if (base.value(entry.value)) base.key,
        ];
        expect(families, [entry.key], reason: '${entry.value.runtimeType}');
      }
    });
  });
}
