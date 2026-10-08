import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Dropdown mixin shares its anatomy with the string-input mixin, so this
/// file only asserts the two behaviours that are dropdown-specific:
///   (1) it reads its override from [TomFormStyle.dropdownStyle], and
///   (2) a `TomDropdownStyle`-level override wins over [TomFormStyle.defaults]
///       via [TomFormStyle.resolveFieldStyle].
class _DropdownField extends TomField<String>
    with TomDropdownDecorationMixin<String> {
  @override
  final String? labelText;

  /// The mixin declares this abstract, so the stub has to say what it is.
  /// This field carries no description; the tests here are about style
  /// resolution, not the description slot.
  @override
  String? get descriptionText => null;

  _DropdownField(
    super.tomId,
    super.initialValue, {
    this.labelText,
    super.validators,
  });

  @override
  Widget get widget => Builder(
    builder: (context) => decorateField(
      context,
      const SizedBox(width: 10, height: 10, key: ValueKey('inner')),
    ),
  );
}

Widget _wrap(Widget child, {TomFormStyle? style}) {
  return MaterialApp(
    home: Scaffold(
      body: style != null
          ? TomFormStyleScope(style: style, child: child)
          : child,
    ),
  );
}

void main() {
  group('TomDropdownDecorationMixin', () {
    testWidgets('dropdownStyle override wins over defaults', (tester) async {
      final field = _DropdownField('city', '', labelText: 'City');
      await tester.pumpWidget(
        _wrap(
          field.widget,
          style: const TomFormStyle(
            defaults: TomFieldStyle(labelPlacement: TomLabelPlacement.above),
            dropdownStyle: TomDropdownStyle(
              labelPlacement: TomLabelPlacement.hidden,
            ),
          ),
        ),
      );
      expect(find.text('City'), findsNothing);
    });

    testWidgets('falls back to defaults when dropdownStyle is null', (
      tester,
    ) async {
      final field = _DropdownField('city', '', labelText: 'City');
      await tester.pumpWidget(
        _wrap(
          field.widget,
          style: const TomFormStyle(
            defaults: TomFieldStyle(labelPlacement: TomLabelPlacement.above),
          ),
        ),
      );
      expect(find.text('City'), findsOneWidget);
    });

    testWidgets('required indicator respects dropdownStyle override', (
      tester,
    ) async {
      final field = _DropdownField(
        'city',
        '',
        labelText: 'City',
        validators: [TomValidators.requiredInstance],
      );
      await tester.pumpWidget(
        _wrap(
          field.widget,
          style: const TomFormStyle(
            dropdownStyle: TomDropdownStyle(
              requiredIndicator: TomRequiredIndicator.text,
            ),
          ),
        ),
      );
      expect(find.text(' (required)'), findsOneWidget);
      expect(find.text(' *'), findsNothing);
    });
  });
}
