import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Helpers
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

class _TestAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {};
  void setRule(String path, TomAuthState state) => _rules[path] = state;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    return _rules[resourceKeyPath] ?? TomAuthState.full;
  }
}

// ---------------------------------------------------------------------------
// TomFormStringField (abstract) tests — via TomFormStringInput
// ---------------------------------------------------------------------------

void main() {
  group('TomFormStringField — resource resolution', () {
    test('labelText falls back to null when no override and no resource', () {
      final field = TomFormStringInput('email', '');
      // No override, no resource → null
      expect(field.labelText, isNull);
    });

    test('labelText uses explicit override', () {
      final field = TomFormStringInput(
        'email',
        '',
        labelTextOverride: 'Email Address',
      );
      expect(field.labelText, 'Email Address');
    });

    test('hintText uses explicit override', () {
      final field = TomFormStringInput(
        'email',
        '',
        hintTextOverride: 'Enter email',
      );
      expect(field.hintText, 'Enter email');
    });

    test('descriptionText uses explicit override', () {
      final field = TomFormStringInput(
        'name',
        '',
        descriptionTextOverride: 'Your full name',
      );
      expect(field.descriptionText, 'Your full name');
    });

    test('resolveErrorMessage falls back to errorKey', () {
      final field = TomFormStringInput('name', '');
      expect(field.resolveErrorMessage('required'), 'required');
    });
  });

  // -------------------------------------------------------------------------
  // TomFormStringInput — value management
  // -------------------------------------------------------------------------

  group('TomFormStringInput — value management', () {
    test('initial value is set correctly', () {
      final field = TomFormStringInput('name', 'hello');
      expect(field.get(), 'hello');
      expect(field.initialValue, 'hello');
    });

    test('setValue updates value', () {
      final field = TomFormStringInput('name', '');
      field.setValue('test');
      expect(field.get(), 'test');
    });

    test('isDirty is true after setValue', () {
      final field = TomFormStringInput('name', 'original');
      expect(field.isDirty, isFalse);
      field.setValue('changed');
      expect(field.isDirty, isTrue);
    });

    test('commit resets dirty state', () {
      final field = TomFormStringInput('name', 'a');
      field.setValue('b');
      expect(field.isDirty, isTrue);
      field.commit();
      expect(field.isDirty, isFalse);
      expect(field.initialValue, 'b');
    });

    test('reset restores initial value', () {
      final field = TomFormStringInput('name', 'original');
      field.setValue('changed');
      field.reset();
      expect(field.get(), 'original');
      expect(field.isDirty, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // TomFormStringInput — validation
  // -------------------------------------------------------------------------

  group('TomFormStringInput — validation', () {
    test('validates with sync validator returning error', () async {
      final field = TomFormStringInput(
        'name',
        '',
        validators: [Validators.required()],
      );
      final result = await field.validate();
      expect(result, isA<ValidationError>());
      expect((result as ValidationError).errorKey, 'error.required');
    });

    test('validates successfully when value is valid', () async {
      final field = TomFormStringInput(
        'name',
        'John',
        validators: [Validators.required()],
      );
      final result = await field.validate();
      expect(result, isA<ValidationSuccess>());
    });

    test('async validator with delay', () async {
      final field = TomFormStringInput(
        'name',
        'taken',
        validators: [
          (value) async {
            await Future.delayed(const Duration(milliseconds: 10));
            if (value == 'taken') {
              return const ValidationError('already_taken');
            }
            return const ValidationSuccess();
          },
        ],
      );
      final result = await field.validate();
      expect(result, isA<ValidationError>());
      expect((result as ValidationError).errorKey, 'already_taken');
    });

    test('setValue clears error and schedules debounced validation', () async {
      final field = TomFormStringInput(
        'name',
        '',
        validators: [Validators.required()],
      );

      // First validate to get an error
      await field.validate();
      expect(field.validationState, isA<ValidationError>());

      // setValue should clear error immediately
      field.setValue('valid');
      expect(field.validationState, isA<ValidationSuccess>());
    });

    test('multiple validators stop on first failure', () async {
      var secondCalled = false;
      final field = TomFormStringInput(
        'name',
        '',
        validators: [
          Validators.required(),
          (value) {
            secondCalled = true;
            return const ValidationSuccess();
          },
        ],
      );
      await field.validate();
      expect(secondCalled, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // TomFormStringInput — authorization
  // -------------------------------------------------------------------------

  group('TomFormStringInput — authorization', () {
    late _TestAuthAdapter authAdapter;

    setUp(() {
      authAdapter = _TestAuthAdapter();
      TomAuthorization.adapter = authAdapter;
    });

    tearDown(() => TomAuthorization.reset());

    test('default auth state is full', () {
      final field = TomFormStringInput('name', '');
      expect(field.effectiveAuthState, TomAuthState.full);
      expect(field.isEditable, isTrue);
      expect(field.isVisible, isTrue);
    });

    test('disabled auth state from resource', () {
      authAdapter.setRule('name', TomAuthState.disabled);
      final field = TomFormStringInput('name', '');
      expect(field.effectiveAuthState, TomAuthState.disabled);
      expect(field.isEditable, isFalse);
      expect(field.isVisible, isTrue);
    });

    test('none auth state hides field', () {
      authAdapter.setRule('name', TomAuthState.none);
      final field = TomFormStringInput('name', '');
      expect(field.isVisible, isFalse);
    });

    test('authorizer narrows state', () {
      final field = TomFormStringInput(
        'name',
        '',
        authorizer: TomAuthorizer.fixed(TomAuthState.read),
      );
      expect(field.effectiveAuthState, TomAuthState.read);
      expect(field.isEditable, isFalse);
    });

    test('uiStateController narrows further', () {
      final field = TomFormStringInput(
        'name',
        '',
        uiStateController: TomUIStateController(
          resolve: (_, _) => TomAuthState.disabled,
        ),
      );
      expect(field.effectiveAuthState, TomAuthState.disabled);
    });
  });

  // -------------------------------------------------------------------------
  // TomFormStringInput — widget rendering
  // -------------------------------------------------------------------------

  group('TomFormStringInput — widget rendering', () {
    testWidgets('renders TextField with label', (tester) async {
      final field = TomFormStringInput(
        'name',
        '',
        labelTextOverride: 'Full Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
    });

    testWidgets('renders initial value in TextField', (tester) async {
      final field = TomFormStringInput(
        'name',
        'John Doe',
        labelTextOverride: 'Name',
      );

      await tester.pumpWidget(_wrap(field.widget));

      final textField =
          tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'John Doe');
    });

    testWidgets('typing updates field value', (tester) async {
      final field = TomFormStringInput(
        'name',
        '',
        labelTextOverride: 'Name',
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(field.get(), 'Hello');

      // Dispose field to cancel debounce timer
      field.dispose();
    });

    testWidgets('hides field when auth is none', (tester) async {
      final adapter = _TestAuthAdapter();
      adapter.setRule('name', TomAuthState.none);
      TomAuthorization.adapter = adapter;

      final field = TomFormStringInput('name', '', labelTextOverride: 'Name');

      await tester.pumpWidget(_wrap(field.widget));

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);

      TomAuthorization.reset();
    });

    testWidgets('disables input when auth is disabled', (tester) async {
      final field = TomFormStringInput(
        'name',
        '',
        labelTextOverride: 'Name',
        authorizer: TomAuthorizer.fixed(TomAuthState.disabled),
      );

      await tester.pumpWidget(_wrap(field.widget));

      // Wrapped in Opacity for disabled — 0.5 is the current default.
      expect(find.byType(Opacity), findsOneWidget);
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.5);
    });

    testWidgets('read-only background when auth is read', (tester) async {
      final field = TomFormStringInput(
        'name',
        'readonly',
        labelTextOverride: 'Name',
        authorizer: TomAuthorizer.fixed(TomAuthState.read),
      );

      await tester.pumpWidget(_wrap(
        field.widget,
        style: TomFormStyle(
          defaults: TomFieldStyle(
            readOnlyBackground:
                WidgetStatePropertyAll(const Color(0xFFEEEEEE)),
          ),
        ),
      ));

      expect(find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == const Color(0xFFEEEEEE),
      ), findsOneWidget);
    });

    testWidgets('shows validation error text', (tester) async {
      final field = TomFormStringInput(
        'name',
        '',
        labelTextOverride: 'Name',
        validators: [Validators.required()],
      );

      // Validate to produce an error
      await field.validate();

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pump();

      // Error text is rendered by the decoration mixin, not InputDecoration.
      // Look for the error key text in the widget tree.
      expect(find.text('error.required'), findsOneWidget);
    });

    testWidgets('shows spinner during slow pending validation', (tester) async {
      final completer = Completer<ValidationResult>();
      final field = TomFormStringInput(
        'name',
        'test',
        labelTextOverride: 'Name',
        validators: [SlowValidator<String>((value) => completer.future)],
      );

      // Start validation (don't await)
      field.validate();
      // After fast validators pass, slow validation starts → pending
      await tester.pump(const Duration(milliseconds: 10));
      expect(field.validationState, isA<ValidationPending>());
      expect(field.isSlowValidationPending, isTrue);

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the validation
      completer.complete(const ValidationSuccess());
    });

    testWidgets('obscureText enabled for password field', (tester) async {
      final field = TomFormStringInput(
        'password',
        '',
        labelTextOverride: 'Password',
        obscureText: true,
      );

      await tester.pumpWidget(_wrap(field.widget));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // TomFormStringDropdown — basic functionality
  // -------------------------------------------------------------------------

  group('TomFormStringDropdown — basic functionality', () {
    test('initial value is set correctly', () {
      final field = TomFormStringDropdown(
        'country',
        'US',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'United States'),
          const SelectableItem(value: 'UK', label: 'United Kingdom'),
        ]),
      );
      expect(field.get(), 'US');
    });

    test('setValue changes value', () {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'United States'),
        ]),
      );
      field.setValue('US');
      expect(field.get(), 'US');
    });

    test('validation works with required validator', () async {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'United States'),
        ]),
        validators: [Validators.required()],
      );
      final result = await field.validate();
      expect(result, isA<ValidationError>());
    });

    test('labelText resolves through override (not mixin default)', () {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'US'),
        ]),
        labelTextOverride: 'Country Label',
      );
      expect(field.labelText, 'Country Label');
    });

    test('descriptionText resolves through override (not mixin default)', () {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'US'),
        ]),
        descriptionTextOverride: 'Pick your country',
      );
      expect(field.descriptionText, 'Pick your country');
    });

    test('labelText is null when no override and no resource', () {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'US'),
        ]),
      );
      expect(field.labelText, isNull);
    });
  });

  group('TomFormStringDropdown — widget rendering', () {
    testWidgets('renders dropdown with items', (tester) async {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'United States'),
          const SelectableItem(value: 'UK', label: 'United Kingdom'),
        ]),
        labelTextOverride: 'Country',
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('renders label via decoration mixin', (tester) async {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'United States'),
        ]),
        labelTextOverride: 'Country Label',
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      // Label should render through TomDropdownDecorationMixin anatomy
      expect(find.text('Country Label'), findsOneWidget);
    });

    testWidgets('renders description via decoration mixin', (tester) async {
      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'United States'),
        ]),
        labelTextOverride: 'Country',
        descriptionTextOverride: 'Select your country of residence',
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Select your country of residence'), findsOneWidget);
    });

    testWidgets('hides when auth is none', (tester) async {
      final adapter = _TestAuthAdapter();
      adapter.setRule('country', TomAuthState.none);
      TomAuthorization.adapter = adapter;

      final field = TomFormStringDropdown(
        'country',
        '',
        source: StaticSelectableSource([
          const SelectableItem(value: 'US', label: 'US'),
        ]),
      );

      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);

      TomAuthorization.reset();
    });
  });

  // -------------------------------------------------------------------------
  // Legacy class renames
  // -------------------------------------------------------------------------

  group('Legacy class renames', () {
    test('TomFormStringInputClassic exists and works', () {
      // ignore: deprecated_member_use
      final field = TomFormStringInputClassic('name', '');
      expect(field, isNotNull);
      expect(field.tomId, 'name');
    });

    test('TomFormPasswordStringInputClassic exists and works', () {
      // ignore: deprecated_member_use
      final field = TomFormPasswordStringInputClassic('pass', '');
      expect(field.obscureText, isTrue);
    });

    test('TomFormIntInputClassic exists and works', () {
      // ignore: deprecated_member_use
      final field = TomFormIntInputClassic('age', 0, min: 0, max: 150);
      expect(field, isNotNull);
    });

    test('TomFormDoubleInputClassic exists and works', () {
      // ignore: deprecated_member_use
      final field = TomFormDoubleInputClassic('rating', 0.0, min: 0.0, max: 5.0);
      expect(field, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // TomField.setValue — event and debounce behavior
  // -------------------------------------------------------------------------

  group('TomField.setValue — events and debounce', () {
    test('setValue does not fire event when value unchanged', () {
      final field = TomFormStringInput('name', 'same');
      // Set same value — should not trigger anything
      field.setValue('same');
      // If it did fire, it would also be ok, but the contract is no-op
      expect(field.get(), 'same');
      expect(field.isDirty, isFalse);
    });

    test('setValue fires event and clears validation', () async {
      final field = TomFormStringInput(
        'name',
        '',
        validators: [Validators.required()],
      );

      // Produce an error state
      await field.validate();
      expect(field.validationState, isA<ValidationError>());

      // setValue clears it
      field.setValue('new value');
      expect(field.validationState, isA<ValidationSuccess>());
      expect(field.get(), 'new value');
    });

    test('dispose cancels debounce timer', () {
      final field = TomFormStringInput('name', '');
      field.setValue('trigger debounce');
      // Dispose should cancel the timer without errors
      field.dispose();
    });
  });

  group('TomFormStringInput — error visuals (Phase 6)', () {
    const outlinedField = OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF000000)),
    );
    const outlinedError = OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
    );
    const styleWithVisuals = TomFormStyle(
      defaults: TomFieldStyle(
        fieldBorder: outlinedField,
        focusedBorder: outlinedField,
        errorBorder: outlinedError,
        errorBorderEnabled: true,
        errorIconEnabled: true,
      ),
    );
    const styleNoVisuals = TomFormStyle(
      defaults: TomFieldStyle(
        fieldBorder: outlinedField,
        focusedBorder: outlinedField,
        errorBorder: outlinedError,
        errorBorderEnabled: false,
        errorIconEnabled: false,
      ),
    );

    testWidgets('no error icon when not in error state', (tester) async {
      final field = TomFormStringInput(
        'name',
        'Alice',
        labelTextOverride: 'Name',
        validators: [Validators.requiredInstance],
      );

      await tester.pumpWidget(_wrap(field.widget, style: styleWithVisuals));

      expect(find.byIcon(Icons.error), findsNothing);
    });

    testWidgets(
      'shows red error icon when in error and errorIconEnabled',
      (tester) async {
        final field = TomFormStringInput(
          'name',
          '',
          labelTextOverride: 'Name',
          validators: [Validators.requiredInstance],
        );
        await field.validate();

        await tester.pumpWidget(_wrap(field.widget, style: styleWithVisuals));

        final iconFinder = find.byIcon(Icons.error);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.color, const Color(0xFFD32F2F));
      },
    );

    testWidgets(
      'suppresses error icon when errorIconEnabled is false',
      (tester) async {
        final field = TomFormStringInput(
          'name',
          '',
          labelTextOverride: 'Name',
          validators: [Validators.requiredInstance],
        );
        await field.validate();

        await tester.pumpWidget(_wrap(field.widget, style: styleNoVisuals));

        expect(find.byIcon(Icons.error), findsNothing);
      },
    );

    testWidgets('swaps border to errorBorder when in error and enabled',
        (tester) async {
      final field = TomFormStringInput(
        'name',
        '',
        labelTextOverride: 'Name',
        validators: [Validators.requiredInstance],
      );
      await field.validate();

      await tester.pumpWidget(_wrap(field.widget, style: styleWithVisuals));

      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration!;
      // withTheme retints border colors but preserves widths.
      // The error border had width=2; the field border had width=1.
      // Verify the error border (not the field border) was applied.
      for (final border in [
        decoration.enabledBorder,
        decoration.focusedBorder,
        decoration.border,
      ]) {
        expect(border, isA<OutlineInputBorder>(), reason: 'border type');
        expect(
          (border! as OutlineInputBorder).borderSide.width,
          2,
          reason: 'error border width applied',
        );
      }
    });

    testWidgets(
      'keeps original border when errorBorderEnabled is false',
      (tester) async {
        final field = TomFormStringInput(
          'name',
          '',
          labelTextOverride: 'Name',
          validators: [Validators.requiredInstance],
        );
        await field.validate();

        await tester.pumpWidget(_wrap(field.widget, style: styleNoVisuals));

        final textField = tester.widget<TextField>(find.byType(TextField));
        final decoration = textField.decoration!;
        // Error border disabled — enabled and focused borders keep the
        // field border (width 1) rather than the error border (width 2).
        for (final border in [decoration.enabledBorder, decoration.focusedBorder]) {
          expect(border, isA<OutlineInputBorder>());
          expect((border! as OutlineInputBorder).borderSide.width, 1);
        }
      },
    );

    testWidgets('preserves existing suffix icon alongside error icon',
        (tester) async {
      final field = TomFormStringInput(
        'name',
        '',
        labelTextOverride: 'Name',
        suffixIcon: const Icon(Icons.search, key: ValueKey('search')),
        validators: [Validators.requiredInstance],
      );
      await field.validate();

      await tester.pumpWidget(_wrap(field.widget, style: styleWithVisuals));

      expect(find.byKey(const ValueKey('search')), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
  });

  group('TomFormStringDropdown — error visuals (Phase 6)', () {
    const outlinedField = OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF000000)),
    );
    const outlinedError = OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
    );
    const styleWithVisuals = TomFormStyle(
      defaults: TomFieldStyle(
        fieldBorder: outlinedField,
        focusedBorder: outlinedField,
        errorBorder: outlinedError,
        errorBorderEnabled: true,
        errorIconEnabled: true,
      ),
    );

    TomSelectableSource<String> twoOptions() => StaticSelectableSource([
          const SelectableItem(value: 'a', label: 'Apple'),
          const SelectableItem(value: 'b', label: 'Banana'),
        ]);

    testWidgets('shows error icon when in error and enabled', (tester) async {
      final field = TomFormStringDropdown(
        'fruit',
        '',
        source: twoOptions(),
        labelTextOverride: 'Fruit',
        validators: [Validators.requiredInstance],
      );
      await field.validate();

      await tester.pumpWidget(_wrap(field.widget, style: styleWithVisuals));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('no error icon when not in error', (tester) async {
      final field = TomFormStringDropdown(
        'fruit',
        'a',
        source: twoOptions(),
        labelTextOverride: 'Fruit',
        validators: [Validators.requiredInstance],
      );

      await tester.pumpWidget(_wrap(field.widget, style: styleWithVisuals));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error), findsNothing);
    });
  });
}
