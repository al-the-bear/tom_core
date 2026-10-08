import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Concrete TomField subclass for testing (TomField is abstract)
// ---------------------------------------------------------------------------
class _TestField<T> extends TomField<T> {
  _TestField(
    super.tomId,
    super.initialValue, {
    super.form,
    super.validators,
    super.authorizer,
    super.uiStateController,
    super.tomGroup,
  });

  @override
  Widget get widget => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Custom auth adapter for testing
// ---------------------------------------------------------------------------
class _TestAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {};

  void setRule(String path, TomAuthState state) => _rules[path] = state;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    return _rules[resourceKeyPath] ?? TomAuthState.full;
  }
}

void main() {
  group('TomField — value tracking', () {
    test('stores initial value', () {
      final field = _TestField<String>('name', 'Alice');
      expect(field.initialValue, 'Alice');
      expect(field.get(), 'Alice');
    });

    test('isDirty when value differs from initial', () {
      final field = _TestField<String>('name', 'Alice');
      expect(field.isDirty, isFalse);

      field.set('Bob');
      expect(field.isDirty, isTrue);
    });

    test('isDirty is false after setting back to initial', () {
      final field = _TestField<String>('name', 'Alice');
      field.set('Bob');
      field.set('Alice');
      expect(field.isDirty, isFalse);
    });

    test('commit makes current value the new initial', () {
      final field = _TestField<String>('name', 'Alice');
      field.set('Bob');
      expect(field.isDirty, isTrue);

      field.commit();
      expect(field.isDirty, isFalse);
      expect(field.initialValue, 'Bob');
    });

    test('reset restores initial value', () {
      final field = _TestField<String>('name', 'Alice');
      field.set('Bob');
      expect(field.get(), 'Bob');

      field.reset();
      expect(field.get(), 'Alice');
      expect(field.isDirty, isFalse);
    });

    test('reset clears validation state', () {
      final field = _TestField<String>(
        'name',
        '',
        validators: [TomValidators.required()],
      );

      // Validate to produce error
      field.validate();

      field.reset();
      expect(field.validationState, isA<TomValidationPristine>());
    });

    test('works with int values', () {
      final field = _TestField<int>('age', 25);
      expect(field.get(), 25);
      field.set(30);
      expect(field.isDirty, isTrue);
      field.reset();
      expect(field.get(), 25);
    });

    test('works with nullable values', () {
      final field = _TestField<String?>('optional', null);
      expect(field.get(), isNull);
      field.set('value');
      expect(field.isDirty, isTrue);
      field.reset();
      expect(field.get(), isNull);
    });
  });

  group('TomField — scope and basePath', () {
    test('basePath is tomId when no scope', () {
      // Outside any zone → default scope → empty scope path
      final field = _TestField<String>('email', '');
      expect(field.basePath, 'email');
    });

    test('basePath includes scope when inside TomScope', () {
      TomScope.withScope('checkout', () {
        final field = _TestField<String>('email', '');
        expect(field.basePath, 'checkout.email');
        expect(field.scope, 'checkout');
      });
    });

    test('basePath includes nested scope', () {
      TomScope.withScope('app', () {
        TomScope.withScope('checkout', () {
          final field = _TestField<String>('email', '');
          expect(field.basePath, 'app.checkout.email');
        });
      });
    });
  });

  group('TomField — validation', () {
    test('starts with TomValidationPristine', () {
      final field = _TestField<String>('name', 'Alice');
      expect(field.validationState, isA<TomValidationPristine>());
    });

    test('validate returns success when no validators', () async {
      final field = _TestField<String>('name', 'Alice');
      final result = await field.validate();
      expect(result, isA<TomValidationSuccess>());
    });

    test('validate runs validators and returns error', () async {
      final field = _TestField<String>(
        'name',
        '',
        validators: [TomValidators.required()],
      );

      final result = await field.validate();
      expect(result, isA<TomValidationError>());
      expect((result as TomValidationError).errorKey, 'error.required');
      expect(field.validationState, isA<TomValidationError>());
    });

    test('validate returns success when validators pass', () async {
      final field = _TestField<String>(
        'name',
        'Alice',
        validators: [TomValidators.required()],
      );

      final result = await field.validate();
      expect(result, isA<TomValidationSuccess>());
      expect(field.validationState, isA<TomValidationSuccess>());
    });

    test('validate stops on first error', () async {
      var secondCalled = false;
      final field = _TestField<String>(
        'name',
        '',
        validators: [
          TomValidators.required(),
          (value) {
            secondCalled = true;
            return const TomValidationSuccess();
          },
        ],
      );

      await field.validate();
      expect(secondCalled, isFalse);
    });

    test('validate handles async validators', () async {
      final field = _TestField<String>(
        'name',
        'test',
        validators: [
          (value) async {
            await Future.delayed(const Duration(milliseconds: 10));
            return const TomValidationSuccess();
          },
        ],
      );

      final result = await field.validate();
      expect(result, isA<TomValidationSuccess>());
    });

    // Because the field already stops on the first error (above), composing
    // rules before handing them over buys nothing — this pins the equivalence
    // so the documented "don't bother" cannot quietly become false.
    test('a composed rule and the same rules as a list agree', () async {
      final asList = _TestField<String>(
        'name',
        'ab',
        validators: [TomValidators.required(), TomValidators.minLength(3)],
      );
      final asComposite = _TestField<String>(
        'name',
        'ab',
        validators: [
          TomValidators.compose<String>([
            TomValidators.required(),
            TomValidators.minLength(3),
          ]),
        ],
      );

      expect(
        await asList.validate(),
        const TomValidationError('error.minLength'),
      );
      expect(
        await asComposite.validate(),
        const TomValidationError('error.minLength'),
      );
    });

    // compose returns a plain TomValidator, so however slow its members are the
    // composite is dispatched on the fast path — no pending spinner, short
    // debounce. TomSlowValidator is what moves it, and it accepts a composite.
    test('a composite of async rules is still a fast validator', () async {
      Future<TomValidationResult> remote(String value) async =>
          const TomValidationSuccess();

      final fast = _TestField<String>(
        'name',
        'x',
        validators: [
          TomValidators.compose<String>([TomValidators.required(), remote]),
        ],
      );
      expect(fast.hasSlowValidators, isFalse);

      final slow = _TestField<String>(
        'name',
        'x',
        validators: [
          TomSlowValidator(
            TomValidators.compose<String>([TomValidators.required(), remote]),
          ),
        ],
      );
      expect(slow.hasSlowValidators, isTrue);
    });
  });

  group('TomField — authorization', () {
    late _TestAuthAdapter adapter;

    setUp(() {
      adapter = _TestAuthAdapter();
      TomAuthorization.adapter = adapter;
    });

    tearDown(() {
      TomAuthorization.reset();
    });

    test('resolveEffectiveAuth returns full by default', () {
      final field = _TestField<String>('email', '');
      expect(field.resolveEffectiveAuth(), TomAuthState.full);
    });

    test('resolveEffectiveAuth uses resource-based auth', () {
      adapter.setRule('email', TomAuthState.read);
      final field = _TestField<String>('email', '');
      expect(field.resolveEffectiveAuth(), TomAuthState.read);
    });

    test('resolveEffectiveAuth uses scoped basePath for lookup', () {
      TomScope.withScope('checkout', () {
        adapter.setRule('checkout.email', TomAuthState.disabled);
        final field = _TestField<String>('email', '');
        expect(field.resolveEffectiveAuth(), TomAuthState.disabled);
      });
    });

    test('per-field authorizer narrows auth', () {
      // Resource says full, authorizer says read → result is read
      final field = _TestField<String>(
        'email',
        '',
        authorizer: TomAuthorizer.fixed(TomAuthState.read),
      );
      expect(field.resolveEffectiveAuth(), TomAuthState.read);
    });

    test('uiStateController narrows auth', () {
      final field = _TestField<String>(
        'email',
        '',
        uiStateController: TomUIStateController(
          resolve: (_, _) => TomAuthState.disabled,
        ),
      );
      expect(field.resolveEffectiveAuth(), TomAuthState.disabled);
    });

    test('authorizer + uiStateController chain narrows correctly', () {
      // Resource: full → authorizer: read → uiStateController: disabled → result: disabled
      final field = _TestField<String>(
        'email',
        '',
        authorizer: TomAuthorizer.fixed(TomAuthState.read),
        uiStateController: TomUIStateController(
          resolve: (_, _) => TomAuthState.disabled,
        ),
      );
      expect(field.resolveEffectiveAuth(), TomAuthState.disabled);
    });

    test('effectiveAuthState getter delegates to resolveEffectiveAuth', () {
      adapter.setRule('email', TomAuthState.read);
      final field = _TestField<String>('email', '');
      expect(field.effectiveAuthState, TomAuthState.read);
      expect(field.effectiveAuthState, field.resolveEffectiveAuth());
    });

    test('isEditable when full auth', () {
      final field = _TestField<String>('email', '');
      expect(field.isEditable, isTrue);
    });

    test('isEditable false when read auth', () {
      adapter.setRule('email', TomAuthState.read);
      final field = _TestField<String>('email', '');
      expect(field.isEditable, isFalse);
    });

    test('isVisible when not none', () {
      adapter.setRule('email', TomAuthState.disabled);
      final field = _TestField<String>('email', '');
      expect(field.isVisible, isTrue);
    });

    test('isVisible false when none', () {
      adapter.setRule('email', TomAuthState.none);
      final field = _TestField<String>('email', '');
      expect(field.isVisible, isFalse);
    });
  });

  group('TomField — TomAuthorizable interface', () {
    test('tomId returns the short tomId, not the full basePath', () {
      final field = _TestField<String>('email', '');
      // With no TomScope wrapper basePath collapses to tomId anyway, so
      // also verify they stay consistent with/without scope prefix.
      expect(field.tomId, 'email');
      expect(field.tomId, 'email');
      expect(field.basePath, 'email');
    });

    test('tomId stays short when the field lives inside a scope', () {
      final field = TomScope.withScope(
        'checkout',
        () => TomScope.withScope(
          'customer',
          () => _TestField<String>('email', ''),
        ),
      );
      expect(
        field.tomId,
        'email',
        reason: 'tomId is the short id that was passed to the constructor.',
      );
      expect(
        field.basePath,
        'checkout.customer.email',
        reason: 'basePath is the full scope-prefixed path.',
      );
    });

    test('tomGroup is null by default', () {
      final field = _TestField<String>('email', '');
      expect(field.tomGroup, isNull);
    });

    test('tomGroup can be set via constructor', () {
      final group = TomAuthorizationGroup('shipping');
      final field = _TestField<String>('street', '', tomGroup: group);
      expect(field.tomGroup, same(group));
    });
  });

  group('TomField — dispose', () {
    test('dispose completes without error', () {
      final field = _TestField<String>('name', 'Alice');
      expect(() => field.dispose(), returnsNormally);
    });

    test('dispose after validation completes without error', () async {
      final field = _TestField<String>(
        'name',
        'test',
        validators: [TomValidators.required()],
      );
      await field.validate();
      expect(() => field.dispose(), returnsNormally);
    });
  });

  group('TomField — toString', () {
    test('includes runtimeType, tomId, value, dirty status', () {
      final field = _TestField<String>('name', 'Alice');
      final str = field.toString();
      expect(str, contains('name'));
      expect(str, contains('Alice'));
      expect(str, contains('dirty: false'));
    });

    test('shows dirty when modified', () {
      final field = _TestField<String>('name', 'Alice');
      field.set('Bob');
      expect(field.toString(), contains('dirty: true'));
    });
  });

  group('TomField — AuthGroupMode', () {
    late _TestAuthAdapter adapter;

    setUp(() {
      adapter = _TestAuthAdapter();
      TomAuthorization.adapter = adapter;
    });

    tearDown(() {
      TomAuthorization.reset();
    });

    test('controlsAll replaces member state with group state', () {
      // Field would have full access, but group has read
      adapter.setRule('street', TomAuthState.full);
      adapter.setRule('shipping', TomAuthState.read);

      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsAll,
      );
      final field = _TestField<String>('street', '', tomGroup: group);

      expect(field.effectiveAuthState, TomAuthState.read);
    });

    test('controlsWidest narrows member to group ceiling', () {
      // Field has full, group has read — result should be read (narrower)
      adapter.setRule('city', TomAuthState.full);
      adapter.setRule('shipping', TomAuthState.read);

      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      final field = _TestField<String>('city', '', tomGroup: group);

      expect(field.effectiveAuthState, TomAuthState.read);
    });

    test('controlsWidest keeps narrower member state', () {
      // Field has disabled, group has full — result stays disabled
      adapter.setRule('region', TomAuthState.disabled);
      adapter.setRule('shipping', TomAuthState.full);

      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      final field = _TestField<String>('region', '', tomGroup: group);

      expect(field.effectiveAuthState, TomAuthState.disabled);
    });

    test('controlsNarrowest widens member to group floor', () {
      // Field has disabled, group has read — result should be read (wider)
      adapter.setRule('zip', TomAuthState.disabled);
      adapter.setRule('shipping', TomAuthState.read);

      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsNarrowest,
      );
      final field = _TestField<String>('zip', '', tomGroup: group);

      expect(field.effectiveAuthState, TomAuthState.read);
    });

    test('controlsNarrowest keeps wider member state', () {
      // Field has full, group has read — result stays full (already wider)
      adapter.setRule('phone', TomAuthState.full);
      adapter.setRule('shipping', TomAuthState.read);

      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsNarrowest,
      );
      final field = _TestField<String>('phone', '', tomGroup: group);

      expect(field.effectiveAuthState, TomAuthState.full);
    });
  });

  group('TomAuthorizationGroup — queries', () {
    late _TestAuthAdapter adapter;

    setUp(() {
      adapter = _TestAuthAdapter();
      TomAuthorization.adapter = adapter;
    });

    tearDown(() {
      TomAuthorization.reset();
    });

    test('isUniform true when all visible members have same state', () {
      adapter.setRule('street', TomAuthState.read);
      adapter.setRule('city', TomAuthState.read);
      adapter.setRule('shipping', TomAuthState.full);

      final group = TomAuthorizationGroup('shipping');
      final street = _TestField<String>('street', '', tomGroup: group);
      final city = _TestField<String>('city', '', tomGroup: group);

      // Both should resolve to read (narrowed by group with controlsWidest)
      expect(street.effectiveAuthState, TomAuthState.read);
      expect(city.effectiveAuthState, TomAuthState.read);
      expect(group.isUniform, isTrue);
    });

    test('isUniform false when visible members have different states', () {
      // With controlsWidest (default), wider member states are narrowed to group
      // but narrower states stay narrow. This creates non-uniform states.
      adapter.setRule('street', TomAuthState.full);
      adapter.setRule('city', TomAuthState.disabled);
      adapter.setRule('shipping', TomAuthState.read);

      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      final street = _TestField<String>('street', '', tomGroup: group);
      final city = _TestField<String>('city', '', tomGroup: group);

      // street full -> narrowed to read; city disabled -> stays disabled
      expect(street.effectiveAuthState, TomAuthState.read);
      expect(city.effectiveAuthState, TomAuthState.disabled);
      expect(group.isUniform, isFalse);
    });

    test('isUniform true for empty group', () {
      final group = TomAuthorizationGroup('empty');
      expect(group.isUniform, isTrue);
    });

    test('mostRestrictive returns most restrictive visible member state', () {
      // With controlsWidest mode, wider states are narrowed to group
      // but narrower states stay as-is. This gives varied effective states.
      adapter.setRule('street', TomAuthState.full);
      adapter.setRule('city', TomAuthState.read);
      adapter.setRule('zip', TomAuthState.disabled);
      adapter.setRule('shipping', TomAuthState.read);

      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      _TestField<String>('street', '', tomGroup: group); // full -> read
      _TestField<String>('city', '', tomGroup: group); // read -> read
      _TestField<String>('zip', '', tomGroup: group); // disabled -> disabled

      // Most restrictive is disabled (zip)
      expect(group.mostRestrictive, TomAuthState.disabled);
    });

    test('mostRestrictive returns none for empty group', () {
      // A group with nothing to show reports `none`, not `full` — `full` is
      // the identity of the narrowing fold, and leaking it here made a fully
      // hidden group read as a fully editable one.
      final group = TomAuthorizationGroup('empty');
      expect(group.mostRestrictive, TomAuthState.none);
    });

    test('mostRestrictive returns none when every field is hidden', () {
      adapter.setRule('street', TomAuthState.none);
      adapter.setRule('city', TomAuthState.none);
      adapter.setRule('shipping', TomAuthState.full);

      final group = TomAuthorizationGroup('shipping');
      _TestField<String>('street', '', tomGroup: group);
      _TestField<String>('city', '', tomGroup: group);

      expect(group.isEmpty, isTrue);
      expect(group.mostRestrictive, TomAuthState.none);
    });
  });
}
