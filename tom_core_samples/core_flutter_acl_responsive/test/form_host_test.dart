// `FormHost` is the one piece of shared scaffolding every live-form cell goes
// through, and this suite pins the contract section 5 of the README states:
// the host creates the form inside a scope, runs an **optional** caller-supplied
// `bind`, and disposes the form on teardown.
//
// The optional half is what makes the file worth having. Both call sites in
// `lib/groups/` happen to pass `bind`, so the unbound path — the one the README
// has to describe accurately — is exercised nowhere else in the package. A
// documented behaviour that no test reaches is a documented guess.
//
// Disposal is asserted behaviourally rather than through a flag: a bound form
// subscribes to its entity, so the observable consequence of `dispose()` is that
// a mutation made after teardown no longer reaches the fields. Asserting that
// catches a leaked observer, which asserting `disposed == true` would not.

import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
import 'package:core_flutter_acl_responsive/common/form_host.dart';
// `reflection_seed` re-exports the domain entities and the forms bound to them,
// which is how the sibling suites reach `CompanyProfile` and `CompanyForm`.
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  /// Pumps a [FormHost] carrying the three validated string inputs, at a width
  /// wide enough that the roomiest field anatomy applies and nothing is clipped
  /// out of the tree before it can be found.
  ///
  /// The dropdown is left out deliberately: its declared default (`''`) matches
  /// no [SelectableItem], so including it would make the *unbound* case a test
  /// of the dropdown's empty-value handling rather than of [FormHost].
  Future<void> pumpHost(
    WidgetTester tester, {
    required String scopeId,
    void Function(CompanyForm form)? bind,
    void Function(CompanyForm form)? capture,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormHost<CompanyForm>(
              scopeId: scopeId,
              create: () {
                final form = CompanyForm();
                capture?.call(form);
                return form;
              },
              bind: bind,
              builder: (context, form) =>
                  TomAclBuilder(id: '${scopeId}_acl', elementProvider: form)
                      .setAclExpandXDefault(true)
                      .append((CompanyForm p) => p.name.widget)
                      .newRow()
                      .append((CompanyForm p) => p.taxId.widget)
                      .newRow()
                      .append((CompanyForm p) => p.website.widget)
                      .build(context),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('with no bind the host renders the form at its declared defaults',
      (tester) async {
    late final CompanyForm form;
    await pumpHost(
      tester,
      scopeId: 'formHostUnbound',
      capture: (f) => form = f,
    );

    // `CompanyForm` declares every field with `''`; `CompanyProfile` seeds real
    // values. Reading empty here is therefore the positive evidence that no
    // entity was involved — the host constructs none of its own.
    expect(form.name.get(), isEmpty);
    expect(form.taxId.get(), isEmpty);
    expect(form.website.get(), isEmpty);
    expect(find.text('Acme Corporation'), findsNothing,
        reason: 'no entity was supplied, so no entity value can be on screen');

    // The point of the unbound path is that it *renders*. A form that threw
    // without a binding would make the optionality of `bind` a lie.
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('the caller-supplied bind seeds every field from its entity',
      (tester) async {
    late final CompanyForm form;
    final profile = CompanyProfile();
    await pumpHost(
      tester,
      scopeId: 'formHostBound',
      bind: (f) => f.bind(profile),
      capture: (f) => form = f,
    );

    expect(form.name.get(), profile.name.get());
    expect(find.text('Acme Corporation'), findsOneWidget,
        reason: 'binding is what puts entity state on screen — the host itself '
            'only forwards the callback');
  });

  testWidgets('the host disposes the form when it leaves the tree',
      (tester) async {
    late final CompanyForm form;
    final profile = CompanyProfile();
    await pumpHost(
      tester,
      scopeId: 'formHostDispose',
      bind: (f) => f.bind(profile),
      capture: (f) => form = f,
    );

    // While mounted, the form observes its binding: an external write to the
    // entity re-snapshots the pristine field. This half is the control — without
    // it, the assertion after teardown would pass on a form that never listened.
    profile.name.set('Mounted Ltd');
    await tester.pump();
    expect(form.name.get(), 'Mounted Ltd');

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    // Teardown detaches the binding observer, so the same write no longer
    // reaches the field. A leaked observer would fail here by keeping the two
    // in sync past the widget's life.
    profile.name.set('Disposed Ltd');
    await tester.pump();
    expect(form.name.get(), 'Mounted Ltd',
        reason: 'the form was disposed with the host; a post-teardown mutation '
            'of the entity must not reach a disposed field');
  });
}
