// Validation messages are resources (G-RES-1 / G-UI-7), and this suite is what
// makes that claim falsifiable.
//
// A validator does not carry a message; it emits an `error.<name>` key, and the
// field resolves that key through `<basePath>.<key>` → `<key>` → **the raw key
// itself** as a development indicator. That last fallback is the trap this file
// exists to spring: a key no bundle defines still renders, as its own name, and
// a test that only checked "an error is showing" would pass on `error.invalidUrl`
// exactly as happily as on real prose. So every assertion here names the human
// sentence, `no validation message renders as a raw resource key` sweeps the
// rendered form for anything that still looks like a key, and the closing source
// sweep catches the keys no reachable interaction can paint.
//
// The forms are driven through the widget, not by poking `field.value`: typing
// is what a user does, and it exercises the decoration path that actually paints
// the message.

import 'dart:io';

import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:core_flutter_form_showcase/common/form_host.dart';
// `reflection_seed` re-exports the domain entities and the forms bound to them,
// which is how the sibling suites reach `CompanyProfile` and `CompanyForm`.
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  /// Render [children] at a width wide enough that the field anatomy is in its
  /// roomiest tier — the message slot is a real row there, so nothing is clipped
  /// out of the tree before it can be found.
  Future<void> pumpFields(
    WidgetTester tester,
    List<Widget> Function() children,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: Column(children: children())),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pump the three validated string inputs of a freshly bound [CompanyForm]
  /// (0 = name, 1 = taxId, 2 = website).
  ///
  /// The form is created and disposed by a [FormHost], which is how every
  /// showcase cell owns one — so the suite exercises the same lifecycle the app
  /// does rather than a test-only variant.
  Future<void> pumpCompanyForm(WidgetTester tester) => pumpFields(
    tester,
    () => [
      FormHost<CompanyForm>(
        scopeId: 'validationMessages',
        create: CompanyForm.new,
        bind: (form) => form.bind(CompanyProfile()),
        builder: (context, form) => Column(
          children: [form.name.widget, form.taxId.widget, form.website.widget],
        ),
      ),
    ],
  );

  /// Type [text] into the input at [index] and let the field validate itself.
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

  testWidgets('a malformed tax ID resolves error.taxIdFormat to its message', (
    tester,
  ) async {
    await pumpCompanyForm(tester);
    await typeAndAwaitValidation(tester, 1, 'de 1234');

    expect(
      find.text(showcaseValidationTexts['error.taxIdFormat']),
      findsOneWidget,
      reason:
          'the pattern validator emits error.taxIdFormat; the field must '
          'resolve it through the registered bundle, not render the key',
    );
  });

  testWidgets('a malformed website resolves error.invalidUrl to its message', (
    tester,
  ) async {
    await pumpCompanyForm(tester);
    await typeAndAwaitValidation(tester, 2, 'not a url');

    expect(
      find.text(showcaseValidationTexts['error.invalidUrl']),
      findsOneWidget,
      reason: 'the URL pattern validator emits error.invalidUrl',
    );
  });

  testWidgets('clearing a required field resolves error.required', (
    tester,
  ) async {
    await pumpCompanyForm(tester);
    // The bound [CompanyProfile] seeds empty, but a pristine field has not
    // validated yet — so the field is filled and then *emptied*, which is the
    // interaction that actually trips `required` on screen.
    await typeAndAwaitValidation(tester, 0, 'Acme');
    await typeAndAwaitValidation(tester, 0, '');

    expect(
      find.text(showcaseValidationTexts['error.required']),
      findsOneWidget,
      reason:
          'the built-in required validator emits error.required, which '
          'the bundle must define like any other message',
    );
  });

  testWidgets('error.minLength interpolates its {min} parameter', (
    tester,
  ) async {
    await pumpCompanyForm(tester);
    await typeAndAwaitValidation(tester, 0, 'A');

    // The bundle stores a `{min}` placeholder; the field substitutes the
    // validator's param. Asserting the *substituted* string is what proves the
    // interpolation happened — a template rendered verbatim would fail here.
    expect(
      find.text('Use at least 2 characters.'),
      findsOneWidget,
      reason:
          'minLength(2) passes params {min: 2}, which the resolver '
          'interpolates into the resource template',
    );
    expect(
      find.textContaining('{min}'),
      findsNothing,
      reason: 'an uninterpolated placeholder reaching the screen is a bug',
    );
  });

  testWidgets('an autoValidate field resolves error.invalidInteger', (
    tester,
  ) async {
    // `OrderItemForm.quantity` is the only `autoValidate: true` field in the
    // sample, and its validator is hand-written rather than a `Validators`
    // built-in — so it is the one that proves a bespoke `ValidationError` key
    // resolves through the same bundle as the framework's own.
    await pumpFields(
      tester,
      () => [
        FormHost<OrderItemForm>(
          scopeId: 'validationMessagesItem',
          create: OrderItemForm.new,
          bind: (form) => form.bind(OrderItem()),
          builder: (context, form) => form.quantity.widget,
        ),
      ],
    );
    await typeAndAwaitValidation(tester, 0, 'twelve');

    expect(
      find.text(showcaseValidationTexts['error.invalidInteger']),
      findsOneWidget,
      reason: '_positiveIntegerValidator emits error.invalidInteger',
    );
  });

  testWidgets('no validation message renders as a raw resource key', (
    tester,
  ) async {
    await pumpCompanyForm(tester);
    await typeAndAwaitValidation(tester, 1, 'de 1234');
    await typeAndAwaitValidation(tester, 2, 'not a url');
    await typeAndAwaitValidation(tester, 0, 'A');

    // The catch-all. Resolution falls back to the key itself, so an undefined
    // key is *invisible* to any test that merely checks an error appeared. This
    // sweeps every Text in the tree for anything shaped like a key, which makes
    // adding a validator with an undeclared errorKey a failing build rather than
    // a silently ugly screen.
    final keyish = find.byWidgetPredicate(
      (w) => w is Text && (w.data?.startsWith('error.') ?? false),
      description: 'a Text still showing a raw error.* resource key',
    );
    expect(
      keyish,
      findsNothing,
      reason:
          'every error.* key the sample can emit must be defined in '
          'showcaseValidationTexts — see chrome_texts.dart',
    );
  });

  test('every error key the library emits is defined by the bundle', () {
    // The widget sweep above can only judge what an interaction can paint, and
    // some rules are unreachable by typing (`maxLength(500)` sits behind a
    // `maxLength:` input cap, and the async uniqueness check needs a server
    // round-trip). Reading the source closes that gap: whatever key a validator
    // *could* emit must have a sentence, whether or not a test can provoke it.
    final emitted = <String>{};
    final literal = RegExp(r"'(error\.[A-Za-z0-9_]+)'");
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      // The bundle itself declares these keys rather than emitting them, and
      // the generated reflection output is not hand-written source.
      if (file.path.endsWith('chrome_texts.dart')) continue;
      if (file.path.endsWith('.reflection.dart')) continue;
      for (final m in literal.allMatches(file.readAsStringSync())) {
        emitted.add(m.group(1)!);
      }
    }

    expect(
      emitted,
      isNotEmpty,
      reason: 'the scan must actually find keys, or it proves nothing',
    );
    expect(
      emitted.difference(showcaseValidationTexts.keys.toSet()),
      isEmpty,
      reason:
          'a validator names a key with no sentence behind it; it would '
          'render as its own name — add it to showcaseValidationTexts',
    );
  });
}
