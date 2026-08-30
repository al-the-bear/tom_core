// Validation messages are resources (G-RES-1 / G-UI-7), and this suite is what
// makes that claim falsifiable.
//
// A validator does not carry a message; it emits an `error.<name>` key, and the
// field resolves that key through `<basePath>.<key>` → `<key>` → **the raw key
// itself** as a development indicator. That last fallback is the trap this file
// exists to spring: a key no bundle defines still renders, as its own name, and
// a test that only checked "an error is showing" would pass on `error.invalidUrl`
// exactly as happily as on real prose. So every assertion here names the human
// sentence, and `no validation message renders as a raw resource key` sweeps the
// whole form for anything that still looks like a key.
//
// The form is driven through the widget, not by poking `field.value`: typing is
// what a user does, and it exercises the decoration path that actually paints the
// message.

import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
// `reflection_seed` re-exports the domain entities and the forms bound to them,
// which is how the sibling suites reach `CompanyProfile` and `CompanyForm`.
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  setUpAll(initializeReflection);

  late CompanyForm form;

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
    form = TomScope.withScope('validationMessages', CompanyForm.new);
    form.bind(CompanyProfile());
  });

  tearDown(() => form.dispose());

  /// Render the three validated string inputs of [form] at a width wide enough
  /// that the field anatomy is in its roomiest tier — the message slot is a real
  /// row there, so nothing is clipped out of the tree before it can be found.
  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) =>
                  TomAclBuilder(id: 'validationAcl', elementProvider: form)
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

  /// Type [text] into the input at [index] (0 = name, 1 = taxId, 2 = website)
  /// and let the field validate itself.
  ///
  /// Typing schedules a 300ms debounce; when it elapses the field runs its own
  /// fast validation and publishes the result. Waiting for that rather than
  /// calling `form.validate()` keeps the test on the path a user actually takes
  /// — and leaves no timer pending at teardown, which the widget binding treats
  /// as a failure in its own right.
  Future<void> typeAndAwaitValidation(
    WidgetTester tester,
    int index,
    String text,
  ) async {
    await tester.enterText(find.byType(TextField).at(index), text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('a malformed tax ID resolves error.taxIdFormat to its message',
      (tester) async {
    await pumpForm(tester);
    await typeAndAwaitValidation(tester, 1, 'de 1234');

    expect(find.text(companyValidationTexts['error.taxIdFormat']), findsOneWidget,
        reason: 'the pattern validator emits error.taxIdFormat; the field must '
            'resolve it through the registered bundle, not render the key');
  });

  testWidgets('a malformed website resolves error.invalidUrl to its message',
      (tester) async {
    await pumpForm(tester);
    await typeAndAwaitValidation(tester, 2, 'not a url');

    expect(find.text(companyValidationTexts['error.invalidUrl']), findsOneWidget,
        reason: 'the URL pattern validator emits error.invalidUrl');
  });

  testWidgets('clearing a required field resolves error.required',
      (tester) async {
    await pumpForm(tester);
    // The bound [CompanyProfile] seeds every field with a valid value, so the
    // field has to be *emptied* to trip `required` — validating the pristine
    // form would pass and prove nothing.
    await typeAndAwaitValidation(tester, 1, '');

    expect(find.text(companyValidationTexts['error.required']), findsOneWidget,
        reason: 'the built-in required validator emits error.required, which '
            'the bundle must define like any other message');
  });

  testWidgets('error.minLength interpolates its {min} parameter',
      (tester) async {
    await pumpForm(tester);
    await typeAndAwaitValidation(tester, 0, 'A');

    // The bundle stores a `{min}` placeholder; the field substitutes the
    // validator's param. Asserting the *substituted* string is what proves the
    // interpolation happened — a template rendered verbatim would fail here.
    expect(find.text('Use at least 2 characters.'), findsOneWidget,
        reason: 'minLength(2) passes params {min: 2}, which the resolver '
            'interpolates into the resource template');
    expect(find.textContaining('{min}'), findsNothing,
        reason: 'an uninterpolated placeholder reaching the screen is a bug');
  });

  testWidgets('no validation message renders as a raw resource key',
      (tester) async {
    await pumpForm(tester);
    await typeAndAwaitValidation(tester, 1, 'de 1234');
    await typeAndAwaitValidation(tester, 2, 'not a url');

    // The catch-all. Resolution falls back to the key itself, so an undefined
    // key is *invisible* to any test that merely checks an error appeared. This
    // sweeps every Text in the tree for anything shaped like a key, which makes
    // adding a validator with an undeclared errorKey a failing build rather than
    // a silently ugly screen.
    final keyish = find.byWidgetPredicate(
      (w) => w is Text && (w.data?.startsWith('error.') ?? false),
      description: 'a Text still showing a raw error.* resource key',
    );
    expect(keyish, findsNothing,
        reason: 'every error.* key the sample can emit must be defined in '
            'companyValidationTexts — see chrome_texts.dart');
  });
}
