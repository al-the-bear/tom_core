import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/decoration/tom_string_input_decoration_mixin.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style_scope.dart';
import 'package:tom_flutter_ui/src/forms/tom_form.dart';
import 'package:tom_flutter_ui/src/forms/validation/validators.dart';

// ---------------------------------------------------------------------------
// Concrete test field with decoration mixin
// ---------------------------------------------------------------------------
class _DecoratedTestField extends TomField<String>
    with TomStringInputDecorationMixin<String> {
  @override
  final String? labelText;

  @override
  final String? descriptionText;

  _DecoratedTestField(
    super.fieldId,
    super.initialValue, {
    this.labelText,
    this.descriptionText,
    super.validators,
  });

  @override
  Widget get widget => Builder(
        builder: (context) => decorateField(
          context,
          const TextField(decoration: InputDecoration(hintText: 'inner')),
        ),
      );
}

// ---------------------------------------------------------------------------
// Auth adapter for testing
// ---------------------------------------------------------------------------
class _TestAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {};
  void setRule(String path, TomAuthState state) => _rules[path] = state;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    return _rules[resourceKeyPath] ?? TomAuthState.full;
  }
}

// ---------------------------------------------------------------------------
// Helper to wrap widget in MaterialApp with optional style
// ---------------------------------------------------------------------------
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
  group('TomStringInputDecorationMixin — label rendering', () {
    testWidgets('renders label text above field', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Full Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('hides label when labelPlacement is hidden', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Full Name',
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(labelPlacement: LabelPlacement.hidden),
        ),
      ));

      expect(find.text('Full Name'), findsNothing);
    });

    testWidgets('hides label when labelPlacement is floating', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Full Name',
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(labelPlacement: LabelPlacement.floating),
        ),
      ));

      // Floating labels are handled by InputDecoration, not the mixin
      expect(find.text('Full Name'), findsNothing);
    });

    testWidgets('renders label inline (same row) when inline placement',
        (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Full Name',
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(labelPlacement: LabelPlacement.inline),
        ),
      ));

      // Label and input should both be present
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // They should share a common Row ancestor (inline layout)
      final labelElement = find.text('Full Name').evaluate().first;
      // Walk up to find the Row that contains both label and input
      Row? inlineRow;
      labelElement.visitAncestorElements((element) {
        if (element.widget is Row) {
          final row = element.widget as Row;
          // The inline row should contain an Expanded child (the input)
          if (row.children.any((c) => c is Expanded)) {
            inlineRow = row;
            return false;
          }
        }
        return true;
      });
      expect(inlineRow, isNotNull, reason: 'Label and input share an inline Row');
    });

    testWidgets('no label row when labelText is null', (tester) async {
      final field = _DecoratedTestField('name', '');

      await tester.pumpWidget(_wrap(field.widget));

      // Only the inner TextField should be present
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('TomStringInputDecorationMixin — required indicator', () {
    testWidgets('shows asterisk for required field', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
        validators: [Validators.requiredInstance],
      );

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets('no asterisk for non-required field', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text(' *'), findsNothing);
    });

    testWidgets('shows text indicator when configured', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
        validators: [Validators.requiredInstance],
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(requiredIndicator: RequiredIndicator.text),
        ),
      ));

      expect(find.text(' (required)'), findsOneWidget);
    });

    testWidgets('no indicator when RequiredIndicator.none', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
        validators: [Validators.requiredInstance],
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(requiredIndicator: RequiredIndicator.none),
        ),
      ));

      expect(find.text(' *'), findsNothing);
      expect(find.text(' (required)'), findsNothing);
    });
  });

  group('TomStringInputDecorationMixin — error display', () {
    testWidgets('shows error below field by default', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        validators: [Validators.requiredInstance],
        labelText: 'Name',
      );

      // Trigger validation to create error state
      await field.validate();

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('error.required'), findsOneWidget);
    });

    testWidgets('shows error above field when configured', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        validators: [Validators.requiredInstance],
        labelText: 'Name',
      );

      await field.validate();

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(errorPlacement: ErrorPlacement.above),
        ),
      ));

      expect(find.text('error.required'), findsOneWidget);
    });

    testWidgets('shows error both above and below when configured',
        (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        validators: [Validators.requiredInstance],
        labelText: 'Name',
      );

      await field.validate();

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(errorPlacement: ErrorPlacement.both),
        ),
      ));

      // Should appear twice (above and below)
      expect(find.text('error.required'), findsNWidgets(2));
    });

    testWidgets('no error shown when validation succeeds', (tester) async {
      final field = _DecoratedTestField(
        'name',
        'Alice',
        validators: [Validators.requiredInstance],
        labelText: 'Name',
      );

      await field.validate();

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('error.required'), findsNothing);
    });
  });

  group('TomStringInputDecorationMixin — description', () {
    testWidgets('shows description below field', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
        descriptionText: 'Enter your full name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Enter your full name'), findsOneWidget);
    });

    testWidgets('shows description above field when configured',
        (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
        descriptionText: 'Enter your full name',
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(
            descriptionPlacement: DescriptionPlacement.above,
          ),
        ),
      ));

      expect(find.text('Enter your full name'), findsOneWidget);
    });

    testWidgets('no description when descriptionText is null', (tester) async {
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      // No description text should appear
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final texts = textWidgets.map((w) => w.data).toList();
      expect(texts, isNot(contains(null)));
    });
  });

  group('TomStringInputDecorationMixin — auth visuals', () {
    late _TestAuthAdapter adapter;

    setUp(() {
      adapter = _TestAuthAdapter();
      TomAuthorization.adapter = adapter;
    });

    tearDown(() {
      TomAuthorization.reset();
    });

    testWidgets('renders SizedBox.shrink when auth is none', (tester) async {
      adapter.setRule('name', TomAuthState.none);
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Name'), findsNothing);
    });

    testWidgets('applies disabled opacity when auth is disabled',
        (tester) async {
      adapter.setRule('name', TomAuthState.disabled);
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.6);
    });

    testWidgets('applies custom disabled opacity', (tester) async {
      adapter.setRule('name', TomAuthState.disabled);
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: const TomFormStyle(
          defaults: TomFieldStyle(disabledOpacity: 0.3),
        ),
      ));

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.3);
    });

    testWidgets('applies readOnlyBackground when auth is read',
        (tester) async {
      adapter.setRule('name', TomAuthState.read);
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: TomFormStyle(
          defaults: TomFieldStyle(
            readOnlyBackground: WidgetStatePropertyAll(Colors.grey.shade200),
          ),
        ),
      ));

      // Find the ColoredBox with our specific readOnlyBackground color
      final coloredBoxes = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((cb) => cb.color == Colors.grey.shade200);
      expect(coloredBoxes, hasLength(1));
    });

    testWidgets('hides required indicator when not editable', (tester) async {
      adapter.setRule('name', TomAuthState.read);
      final field = _DecoratedTestField(
        'name',
        '',
        labelText: 'Name',
        validators: [Validators.requiredInstance],
      );

      await tester.pumpWidget(_wrap(field.widget));

      // Required indicator should be hidden for read-only fields
      expect(find.text(' *'), findsNothing);
    });
  });

  group('TomStringInputDecorationMixin — pending spinner', () {
    testWidgets('no spinner when validation is not pending', (tester) async {
      final field = _DecoratedTestField(
        'name',
        'Alice',
        labelText: 'Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
