/// Executable example for the `forms/` module of `tom_flutter_ui`.
///
/// The form system is large (declarative `TomForm` / `TomField` data model,
/// validators, selectable sources, an event bus, a Material+Cupertino style
/// system, and the full field catalogue). The full `TomForm` lifecycle binds
/// to a reflected `TomClass` and renders a widget tree, so this example
/// exercises the **pure-logic surfaces** that need no `BuildContext`:
///
/// 1. validators and the sealed `ValidationResult` states,
/// 2. selectable sources (`SelectableItem` / `StaticSelectableSource`),
/// 3. the typed event bus (`TomFormInspector` collecting `TomFormEvent`s),
/// 4. the `FormFieldFamily` factory building Material vs Cupertino fields and
///    the shared `TomField` value/dirty/commit/reset contract,
/// 5. a cross-field `FormValidationError`,
/// 6. the responsive `TomBreakpoint` ladder and the anatomy placement enums,
/// 7. the tristate boolean field and the collection-size rules.
///
/// Because it imports `flutter/material` (→ `dart:ui`) through the package
/// barrel, run it under the Flutter toolchain, e.g.
/// `flutter test example/forms/forms_example.dart`, not bare `dart run`. The
/// same scenarios are covered by `test/forms/forms_example_test.dart`.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Future<void> run() async {
  // ---------------------------------------------------------------------------
  // 1. Validators + ValidationResult
  // ---------------------------------------------------------------------------
  // Validators are `FutureOr<ValidationResult> Function(value)`; `compose`
  // chains them and stops on the first failure.
  final usernameRule = Validators.compose<String>([
    Validators.required(),
    Validators.minLength(3),
    Validators.maxLength(12),
  ]);

  final tooShort = await usernameRule('ab');
  final ok = await usernameRule('alice');
  final emailErr = await Validators.email()('not-an-email');
  print('username "ab"    -> $tooShort');
  print('username "alice" -> $ok');
  print('email bad        -> $emailErr');

  // ---------------------------------------------------------------------------
  // 2. Selectable sources
  // ---------------------------------------------------------------------------
  final countries = StaticSelectableSource<String>(const [
    SelectableItem(value: 'de', label: 'Germany'),
    SelectableItem(value: 'fr', label: 'France'),
    SelectableItem(value: 'jp', label: 'Japan', enabled: false),
  ]);
  final items = await countries.getItems();
  print(
    'countries: ${items.map((i) => i.label).join(', ')}  '
    '(jp enabled=${items[2].enabled})',
  );

  // ---------------------------------------------------------------------------
  // 3. Event bus — collect and filter typed events
  // ---------------------------------------------------------------------------
  final inspector = TomFormInspector();
  inspector.handleEvent(FormBoundEvent(source: 'signupForm'));
  inspector.handleEvent(
    FieldValueChangedEvent(source: 'user.name', oldValue: '', newValue: 'a'),
  );
  inspector.handleEvent(
    FieldValueChangedEvent(source: 'user.age', oldValue: 0, newValue: 30),
  );
  inspector.handleEvent(FormSavedEvent(source: 'signupForm'));

  final valueChanges = inspector.ofType<FieldValueChangedEvent>();
  final formEvents = inspector.fromSource('signupForm');
  print(
    'events collected: ${inspector.length}, '
    'value-changes: ${valueChanges.length}, '
    'from signupForm: ${formEvents.length}',
  );

  // ---------------------------------------------------------------------------
  // 4. FormFieldFamily — same declaration, Material vs Cupertino concretes
  // ---------------------------------------------------------------------------
  final material = FormFieldFamily.material;
  final cupertino = FormFieldFamily.cupertino;

  final mName = material.stringInput('user.name', 'Alice');
  final cName = cupertino.stringInput('user.name', 'Alice');
  print('material name type: ${mName.runtimeType}');
  print('cupertino name type: ${cName.runtimeType}');

  // The shared TomField contract: value / dirty / commit / reset.
  mName.set('Bob');
  final dirtyAfterSet = mName.isDirty;
  mName.commit();
  final dirtyAfterCommit = mName.isDirty;
  mName.set('Carol');
  mName.reset();
  print(
    'name dirty after set=$dirtyAfterSet, after commit=$dirtyAfterCommit, '
    'after reset value=${mName.get()}',
  );

  // ---------------------------------------------------------------------------
  // 5. Cross-field validation error
  // ---------------------------------------------------------------------------
  final start = material.intInput('range.start', 10);
  final end = material.intInput('range.end', 5);
  final rangeError = FormValidationError(
    errorKey: 'error.endBeforeStart',
    fields: [start, end],
  );
  print('cross-field error over: ${rangeError.tomIds}');

  // ---------------------------------------------------------------------------
  // 6. Responsive breakpoints + anatomy enums
  // ---------------------------------------------------------------------------
  print(
    'breakpoints: mobile=${TomBreakpoint.resolve('mobile')} '
    'tablet=${TomBreakpoint.resolve('tablet')} '
    'desktop=${TomBreakpoint.resolve('desktop')} '
    'unknown=${TomBreakpoint.resolve('watch')}',
  );
  print('label placements: ${LabelPlacement.values}');

  // ---------------------------------------------------------------------------
  // 7. Tristate booleans + collection-size rules
  // ---------------------------------------------------------------------------
  // A `TomFormBoolField` binds a `bool` and so has no way to say "not
  // answered". The nullable sibling binds `bool?`, where `null` *is* the
  // third state; `tristate` decides whether the user can reach it.
  final answered = material.nullableBoolToggle('survey.optIn', null);
  final unsetToTrue = answered.get();
  answered.set(true);
  print(
    'optIn: initial=$unsetToTrue now=${answered.get()} '
    'dirty=${answered.isDirty} tristate=${answered.tristate} '
    'type=${answered.runtimeType}',
  );

  // minItems/maxItems bound the *size* of a selection rather than a value —
  // this is how a multi-select expresses its selection count.
  final toppingsRule = Validators.compose<List<String>>([
    Validators.minItems(2),
    Validators.maxItems(3),
  ]);
  final tooFew = await toppingsRule(['cheese']);
  final justRight = await toppingsRule(['cheese', 'basil']);
  final tooMany = await toppingsRule(['cheese', 'basil', 'olives', 'chilli']);
  print('toppings 1 -> $tooFew');
  print('toppings 2 -> $justRight');
  print('toppings 4 -> $tooMany');

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
  assert(tooShort is ValidationError);
  assert((tooShort as ValidationError).errorKey == 'error.minLength');
  assert(ok is ValidationSuccess);
  assert((emailErr as ValidationError).errorKey == 'error.email');

  assert(items.length == 3);
  assert(items.first.value == 'de');
  assert(items[2].enabled == false);

  assert(inspector.length == 4);
  assert(valueChanges.length == 2);
  assert(formEvents.length == 2); // FormBound + FormSaved

  // Material and Cupertino families produce distinct concrete types.
  assert(mName.runtimeType != cName.runtimeType);
  assert(material.isCupertino == false);
  assert(cupertino.isCupertino == true);

  // TomField value contract.
  assert(dirtyAfterSet == true);
  assert(dirtyAfterCommit == false); // commit makes 'Bob' the new initial
  assert(mName.get() == 'Bob'); // reset() restored the committed initial
  assert(mName.isDirty == false);

  assert(rangeError.tomIds.length == 2);
  assert(rangeError.tomIds.first == 'range.start');

  assert(TomBreakpoint.resolve('mobile') == TomBreakpoint.mobile);
  assert(TomBreakpoint.resolve('watch') == null);
  assert(LabelPlacement.values.contains(LabelPlacement.floating));

  // The third state is a real value, not an absent one.
  assert(unsetToTrue == null);
  assert(answered.get() == true);
  assert(answered.isDirty == true);
  assert(answered.tristate == true);

  assert((tooFew as ValidationError).errorKey == 'error.minItems');
  assert(justRight is ValidationSuccess);
  assert((tooMany as ValidationError).errorKey == 'error.maxItems');
}

void main() => run();
