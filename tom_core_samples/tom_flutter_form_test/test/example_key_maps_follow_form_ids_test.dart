/// The Examples section's two static maps are keyed by the forms' own paths.
///
/// One string does four jobs in `lib/examples/`. `exampleCustomer` is the
/// **form id**, the **list id**, the top-level segment of every key in the
/// resource map (`shared/example_resources.dart`) and the first segment of every
/// key in the authorization map (`shared/example_authorization.dart`). Only the
/// first two are the compiler's business; the other two are strings in constant
/// maps that no compiler and no other test reads.
///
/// That asymmetry is what made the rename dangerous. When the kernel started
/// refusing a scope id containing '.', the ids had to change from
/// `example.customer` to `exampleCustomer` — and the two maps had to follow, in
/// silence, because a stale key is not an error. A resource key that matches
/// nothing yields no label; an authorization key that matches nothing yields
/// [TomAuthState.full], the *permissive* default, so a grant that stops applying
/// looks exactly like a grant that was never needed.
///
/// **What this asserts, and why through the framework.** Every id and every path
/// here is taken from a constructed form — `form.basePath`, `field.basePath` —
/// never spelled out. Those are built by `TomScopePath.join`, the same join that
/// runs in the app, so the paths this file compares the maps against are the
/// paths the app will look up. Restating them as literals would produce a third
/// copy of the scheme that can drift from the other two, which is the fault this
/// file exists to prevent.
///
/// The scan of `formId:` / `listId:` literals closes the last gap: it proves the
/// five forms constructed below are *all* the forms `lib/examples/` declares, so
/// "every key matches a form" is a statement about the whole section rather than
/// about whichever forms this file happened to remember.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/examples/forms/example_customer_form.dart';
import 'package:tom_flutter_form_test/examples/forms/example_customer_rich_form.dart';
import 'package:tom_flutter_form_test/examples/shared/example_authorization.dart';
import 'package:tom_flutter_form_test/examples/shared/example_resources.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

import 'support/form_id_sites.dart';

/// The one resource-map entry that is not a form.
///
/// `exampleCommon` holds the section's shared button captions (Save, Discard,
/// …), which belong to no single form. It is named here rather than pattern-
/// matched so that adding a second non-form bundle is a decision someone makes
/// in this file, not something a wildcard absorbs.
const _sharedBundle = 'exampleCommon';

/// The resource sub-key that names screen chrome rather than a field.
///
/// `<form>.panel.title` is read by the panel header, not by a [TomField], so it
/// is the one second-level key with no field behind it.
const _panelSubKey = 'panel';

void main() {
  // The forms carry no state binding here — `basePath` is fixed by the
  // constructor (`TomClass` runs `prepareForSelfObservation` before the object
  // escapes), and binding data would only add a dependency on the fixtures.
  late List<TomForm> forms;

  setUpAll(() {
    initializeReflection();
    const family = TomFormFieldFamily.material;
    forms = <TomForm>[
      ExampleCustomerForm(family: family),
      ExampleCustomerRichForm(family: family),
      ExampleOrderForm(family: family),
      ExampleOrderItemForm(family: family),
      ExampleAddressForm(family: family),
    ];
  });

  /// The form ids the section actually uses, read off the constructed forms.
  Set<String> formIds() => {for (final form in forms) form.basePath};

  /// Every field path across all example forms, keyed by their owning form id.
  ///
  /// Two forms share the id `exampleCustomer` — the plain one and the rich one,
  /// which adds `vip`, `loyaltyPoints` and the rest — so the fields of an id are
  /// the *union* over the forms that declare it. The resource map holds the
  /// union too, which is why it must be compared against one.
  Map<String, Set<String>> fieldsByFormId() {
    final byId = <String, Set<String>>{};
    for (final form in forms) {
      final mirror = tomReflector.reflectType(form.runtimeType) as ClassMirror;
      final instance = tomReflector.reflect(form);
      for (final member in mirror.instanceMembers.values) {
        if (!member.isGetter) continue;
        final value = instance.invokeGetter(member.simpleName);
        if (value is! TomField) continue;
        (byId[form.basePath] ??= <String>{}).add(value.tomId);
      }
    }
    return byId;
  }

  test('the forms constructed here are all the ones lib/examples declares', () {
    // Without this, every assertion below is silently scoped to whichever forms
    // this file remembered to build: a sixth form with a resource entry and no
    // constructor call here would pass the "keys match a form" tests by being
    // invisible to them.
    final declared = {
      for (final site in idSites(root: 'lib/examples')) site.testable,
    };

    expect(
      declared,
      isNotEmpty,
      reason:
          'no formId/listId literal was found under lib/examples. Either the '
          'forms moved or the scan in support/form_id_sites.dart no longer '
          'matches how they are written; an empty set must not read as '
          '"every id is accounted for".',
    );
    expect(
      declared,
      equals(formIds()),
      reason:
          'every id written in lib/examples must belong to a form this file '
          'constructs, and vice versa. Add the new form to `forms` in '
          'setUpAll — the map assertions below only cover what is in it.',
    );
  });

  group('the resource map', () {
    test('is keyed by the form ids, plus the one shared bundle', () {
      expect(
        exampleResourceMap.keys.toSet(),
        equals({...formIds(), _sharedBundle}),
        reason:
            'a top-level segment of the resource map is a form id: the form '
            'joins it into every field path it looks a label up by. A key that '
            'matches no form resolves nothing and reports nothing — the label '
            'is simply absent.',
      );
    });

    test('names, under each form id, only fields that form has', () {
      final fields = fieldsByFormId();
      for (final id in formIds()) {
        final entry = exampleResourceMap[id] as Map<String, dynamic>;
        final named = entry.keys.toSet()..remove(_panelSubKey);
        expect(
          named,
          equals(fields[id]),
          reason:
              'the second-level keys under `$id` are field ids: the field '
              'looks its label up at `<basePath>.label`, and `basePath` is '
              '`$id` joined with the field id. An entry for a field that does '
              'not exist is dead, and a field with no entry falls back to its '
              'own name.',
        );
      }
    });
  });

  group('the authorization map', () {
    test('is keyed by paths that name a form or one of its fields', () {
      final fields = fieldsByFormId();
      final grantable = <String>{
        for (final id in formIds()) ...[
          id,
          for (final field in fields[id]!) '$id.$field',
        ],
      };

      expect(
        exampleAuthMap.keys.toSet().difference(grantable),
        isEmpty,
        reason:
            'an authorization key is matched against a field basePath, and an '
            'unmatched key is the dangerous direction: `resolveAuth` returns '
            'TomAuthState.full for anything it does not recognise, so a grant '
            'that stopped applying is indistinguishable from one that was '
            'never written. Legal keys are $grantable.',
      );
    });

    test('grants land on the field they name', () {
      // The map says `exampleCustomer.tier` is disabled. Whether that is *true*
      // is a question about the path the framework composes, not about the
      // string in the map — so ask the framework, with the path the field
      // carries and the adapter the examples install.
      final saved = TomAuthorization.adapter;
      addTearDown(() => TomAuthorization.adapter = saved);
      installExampleAuthorization();

      final customer = forms.whereType<ExampleCustomerForm>().single;
      expect(
        TomAuthorization.resolveAuth(customer.tier.basePath),
        TomAuthState.disabled,
        reason:
            '`${customer.tier.basePath}` is the path the tier field resolves '
            'auth by, and the examples grant it `disabled` so the section shows '
            'a real auth state. If the form id and the map key stop agreeing '
            'this reverts to `full` and the field just looks ordinary.',
      );
      expect(
        TomAuthorization.resolveAuth(customer.email.basePath),
        TomAuthState.full,
        reason:
            'only `tier` is granted, so a sibling under the same form id must '
            'be untouched — otherwise the assertion above would also pass with '
            'a map that disabled the whole form.',
      );
    });
  });
}
