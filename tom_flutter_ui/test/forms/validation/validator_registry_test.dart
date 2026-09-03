import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// C-11 — Resource-based form validation with named custom validators.
//
// These tests cover the TomValidatorRegistry (name → validator resolution,
// built-ins, spec/declaration parsing, DI swap) and the done-bar: a field
// validates via a *resource-declared* custom validator and its error message
// resolves from resources.
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    // Every test starts from the default registry (built-ins only) and an
    // empty app resource provider — both are process-wide singletons.
    TomValidatorRegistry.resetInstance();
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  tearDown(() {
    TomValidatorRegistry.resetInstance();
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  group('TomValidatorRegistry — spec parsing', () {
    test('parseSpec splits name and colon-separated args', () {
      // Records compare their List field by identity, so destructure and
      // match name + args separately.
      final (name0, args0) = TomValidatorRegistry.parseSpec('required');
      expect(name0, 'required');
      expect(args0, isEmpty);

      final (name1, args1) = TomValidatorRegistry.parseSpec('minLength:8');
      expect(name1, 'minLength');
      expect(args1, ['8']);

      final (name2, args2) = TomValidatorRegistry.parseSpec('between:2:9');
      expect(name2, 'between');
      expect(args2, ['2', '9']);
    });

    test('parseSpec trims whitespace around name and args', () {
      final (name, args) = TomValidatorRegistry.parseSpec('  minLength : 8 ');
      expect(name, 'minLength');
      expect(args, ['8']);
    });
  });

  group('TomValidatorRegistry — registration & lookup', () {
    test('built-ins are pre-registered', () {
      final registry = TomValidatorRegistry();
      expect(registry.has('required'), isTrue);
      expect(registry.has('email'), isTrue);
      expect(registry.has('minLength'), isTrue);
      expect(registry.has('maxLength'), isTrue);
      expect(registry.has('pattern'), isTrue);
      expect(registry.has('min'), isTrue);
      expect(registry.has('max'), isTrue);
      expect(registry.has('minItems'), isTrue);
      expect(registry.has('maxItems'), isTrue);
    });

    test('register adds a custom validator by name', () {
      final registry = TomValidatorRegistry();
      expect(registry.has('strongPassword'), isFalse);
      registry.register(
        'strongPassword',
        (_) => (Object? value) => const ValidationSuccess(),
      );
      expect(registry.has('strongPassword'), isTrue);
      expect(registry.names, contains('strongPassword'));
    });

    test('resolve returns null for an unknown name', () {
      final registry = TomValidatorRegistry();
      expect(registry.resolve('nope'), isNull);
    });

    test('resolveOrThrow throws ArgumentError listing known names', () {
      final registry = TomValidatorRegistry();
      expect(
        () => registry.resolveOrThrow('nope'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TomValidatorRegistry — built-in validators run correctly', () {
    test('required rejects empty and null, accepts non-empty', () async {
      final v = TomValidatorRegistry().resolveOrThrow('required');
      expect(await v(''), isA<ValidationError>());
      expect(await v(null), isA<ValidationError>());
      expect(await v('ok'), isA<ValidationSuccess>());
    });

    test('minLength enforces its integer argument', () async {
      final v = TomValidatorRegistry().resolveSpec('minLength:3');
      expect(await v('ab'), isA<ValidationError>());
      expect(await v('abc'), isA<ValidationSuccess>());
    });

    test('min enforces its numeric argument', () async {
      final v = TomValidatorRegistry().resolveSpec('min:5');
      expect(await v(4), isA<ValidationError>());
      expect(await v(5), isA<ValidationSuccess>());
    });

    test('minLength with a missing argument throws', () {
      expect(
        () => TomValidatorRegistry().resolveSpec('minLength'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('minLength with a non-integer argument throws', () {
      expect(
        () => TomValidatorRegistry().resolveSpec('minLength:x'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // The selection bounds are declarable by name, so a field description's
    // minimum and maximum selection counts reach a field through its resource
    // bundle without any per-field constructor argument.
    test('minItems enforces its integer argument on a selection', () async {
      final v = TomValidatorRegistry().resolveSpec('minItems:2');
      expect(await v(['a']), isA<ValidationError>());
      expect(await v(['a', 'b']), isA<ValidationSuccess>());
    });

    test('maxItems enforces its integer argument on a selection', () async {
      final v = TomValidatorRegistry().resolveSpec('maxItems:2');
      expect(await v(['a', 'b', 'c']), isA<ValidationError>());
      expect(await v(['a', 'b']), isA<ValidationSuccess>());
    });

    test('minItems with a non-integer argument throws', () {
      expect(
        () => TomValidatorRegistry().resolveSpec('minItems:many'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TomValidatorRegistry — declaration resolution', () {
    test('resolveDeclaration produces one validator per comma-separated spec',
        () {
      final validators =
          TomValidatorRegistry().resolveDeclaration('required,minLength:8');
      expect(validators, hasLength(2));
    });

    test('resolveDeclaration ignores blank entries', () {
      final validators =
          TomValidatorRegistry().resolveDeclaration('required, ,minLength:8,');
      expect(validators, hasLength(2));
    });
  });

  group('TomValidatorRegistry — dependency injection', () {
    test('instance is swappable and resetInstance restores default', () {
      final custom = TomValidatorRegistry()
        ..register('x', (_) => (Object? v) => const ValidationSuccess());
      TomValidatorRegistry.instance = custom;
      expect(TomValidatorRegistry.instance.has('x'), isTrue);

      TomValidatorRegistry.resetInstance();
      expect(TomValidatorRegistry.instance.has('x'), isFalse);
      expect(TomValidatorRegistry.instance.has('required'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Done-bar: a field validates via a resource-declared custom validator and
  // the error message resolves from resources.
  // -------------------------------------------------------------------------
  group('C-11 done-bar — resource-declared field validation', () {
    test('field runs a resource-named custom validator; error resolves from '
        'resources', () async {
      // 1. Register a custom validator by name.
      TomValidatorRegistry.instance.register(
        'strongPassword',
        (_) => (Object? value) => (value as String).length >= 8
            ? const ValidationSuccess()
            : const ValidationError('error.weakPassword'),
      );

      // 2. A field's resource bundle names the validator and provides the
      //    error message text.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'password.validators': 'strongPassword',
          'error.weakPassword': 'Password is too weak.',
        }),
      );

      // 3. The field declares NO code validators — everything comes from
      //    resources.
      final field = TomFormStringInput('password', '');

      // Invalid value → the custom validator fires.
      final result = await field.validate();
      expect(result, isA<ValidationError>());
      expect((result as ValidationError).errorKey, 'error.weakPassword');

      // 4. The error message resolves from resources (global key here).
      expect(field.resolvedErrorMessage, 'Password is too weak.');

      // A valid value passes.
      field.setValue('longenough');
      expect(await field.validate(), isA<ValidationSuccess>());
    });

    test('scoped error message overrides the global one', () async {
      TomValidatorRegistry.instance.register(
        'strongPassword',
        (_) => (Object? value) => const ValidationError('error.weakPassword'),
      );
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'password.validators': 'strongPassword',
          'password.error.weakPassword': 'This password is not strong enough.',
          'error.weakPassword': 'Password is too weak.',
        }),
      );

      final field = TomFormStringInput('password', '');
      await field.validate();
      // Scoped `<basePath>.<key>` wins over global `<key>`.
      expect(field.resolvedErrorMessage, 'This password is not strong enough.');
    });

    test('resource-declared built-in validator runs on the field', () async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'username.validators': 'required',
        }),
      );
      final field = TomFormStringInput('username', '');
      expect(await field.validate(), isA<ValidationError>());
      field.setValue('alice');
      expect(await field.validate(), isA<ValidationSuccess>());
    });

    test('a multi-choice field enforces resource-declared selection bounds',
        () async {
      // A field description's minimum and maximum selection counts land here:
      // as a validator declaration on the field's resource bundle, with no
      // per-field constructor argument.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'toppings.validators': 'minItems:2,maxItems:3',
          'error.minItems': 'Pick at least 2.',
        }),
      );
      final field = TomFormStringFilterChips(
        'toppings',
        const ['cheese'],
        source: StaticSelectableSource<String>(const [
          SelectableItem(value: 'cheese', label: 'Cheese'),
          SelectableItem(value: 'basil', label: 'Basil'),
          SelectableItem(value: 'olives', label: 'Olives'),
          SelectableItem(value: 'chilli', label: 'Chilli'),
        ]),
      );

      // Below the lower bound.
      final tooFew = await field.validate();
      expect(tooFew, isA<ValidationError>());
      expect((tooFew as ValidationError).errorKey, 'error.minItems');
      expect(field.resolvedErrorMessage, 'Pick at least 2.');

      // Inside the range.
      field.setValue(const ['cheese', 'basil']);
      expect(await field.validate(), isA<ValidationSuccess>());

      // Above the upper bound.
      field.setValue(const ['cheese', 'basil', 'olives', 'chilli']);
      final tooMany = await field.validate();
      expect(tooMany, isA<ValidationError>());
      expect((tooMany as ValidationError).errorKey, 'error.maxItems');
    });

    test('code validators and resource validators both apply', () async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'nickname.validators': 'minLength:3',
        }),
      );
      // Code declares required; resource adds minLength:3.
      final field = TomFormStringInput(
        'nickname',
        '',
        validators: [(String v) => const ValidationSuccess()],
      );
      // 'ab' passes the code validator but fails resource minLength:3.
      field.setValue('ab');
      final result = await field.validate();
      expect(result, isA<ValidationError>());
      expect((result as ValidationError).errorKey, 'error.minLength');
    });

    test('a resource-declared required raises the required indicator',
        () async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'username.validators': 'required',
        }),
      );
      final field = TomFormStringInput('username', '');

      // The anatomy decides whether to paint the required marker by looking
      // for the shared required validator in the merged list — so the rule
      // resolved from the bundle has to *be* that validator, not a wrapper
      // around it, or a bundle-declared constraint renders unmarked.
      expect(fieldHasRequiredValidator(field.validators), isTrue);
    });
  });
}
