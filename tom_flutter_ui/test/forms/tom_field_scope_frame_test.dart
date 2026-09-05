/// Where a form field stands, and why both halves of its authorization have to
/// agree about it.
///
/// A field composes two paths: its own `<frame>.<formId>.<tomId>`, and — when
/// it belongs to a group — the group's `<frame>.<groupId>`. They are a
/// `<prefix>.<id>` pair, so a prefix that differs between them looks up a
/// ceiling belonging to some other member, or to none.
///
/// The frame is captured when the field is built, not read when the answer is
/// asked for. A field is a long-lived object consulted from screens, from the
/// group's own inspection, and from tests — and only the zone it was built in
/// describes where it actually lives. Reading `TomScope.current` per lookup
/// makes the answer depend on the caller's whereabouts, which is the defect
/// this file pins.
///
/// The frame is the **form's** frame, not the form's `basePath`. A form is both
/// a field container and a `TomActionController`, and one group routinely holds
/// both a field and an action of the same form — so a group has to mean the
/// same thing to both. `TomAction` already resolves its group in the
/// controller's frame and treats the controller id as namespace rather than
/// location (`actions/actions_test.dart`); a field resolving its group one
/// segment deeper would give a single group object two different ceilings
/// depending on which member asked. The last test here is what holds that line.
///
/// The suite runs on the reflection seed in `test/support/list_form_fixtures.dart`
/// — a `TomForm` is a `TomClass` and needs a generated mirror to exist at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../support/list_form_fixtures.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class _PathAuthAdapter implements TomAuthorizationAdapter {
  _PathAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

/// An action whose only purpose is to carry a group, so a field and an action
/// on one form can be compared against the same group object.
class _NoopAction extends TomSimpleAction<TomActionContext> {
  _NoopAction({required super.controller, required super.tomGroup})
    : super(actionId: 'edit');

  @override
  void executeSimple(TomActionContext context, TomActionTransaction tx) {}
}

/// Attaches [group] to [field] the way a declaration site would.
void _join(TomField field, TomAuthorizationGroup group) {
  field.tomGroup = group;
  group.register(field);
}

void main() {
  setUpAll(initializeReflection);

  tearDown(TomAuthorization.reset);

  // -------------------------------------------------------------------------
  // The frame the field stands in
  // -------------------------------------------------------------------------

  group('a form field captures its frame', () {
    test('outside any scope the path is form id and field id', () {
      final form = AddressForm();
      expect(form.street.basePath, 'address.street');
    });

    test('an ambient scope at form construction prefixes the field path', () {
      final form = TomScope.withScope('checkout', AddressForm.new);
      expect(form.basePath, 'checkout.address');
      expect(form.street.basePath, 'checkout.address.street');
    });

    test('a scope entered after construction does not move the field', () {
      // The field is built at the root; standing somewhere else to read it must
      // not re-address it.
      final form = AddressForm();
      TomScope.withScope('checkout', () {
        expect(form.street.basePath, 'address.street');
      });
    });
  });

  // -------------------------------------------------------------------------
  // The group resolves in that same frame
  // -------------------------------------------------------------------------

  group('a form field resolves its group in its own frame', () {
    /// Four rules, and the last is the point. `shipping: full` is what an
    /// out-of-frame group lookup lands on, so a frame that fails to reach the
    /// group produces a *wider* answer rather than the same one by luck.
    void installRules() {
      TomAuthorization.adapter = _PathAuthAdapter({
        'checkout.address.street': TomAuthState.full,
        'checkout.address': TomAuthState.full, // the form must not narrow
        'checkout.shipping': TomAuthState.read, // the ceiling that must apply
        'shipping': TomAuthState.full, // the unscoped decoy
      });
    }

    test('the group ceiling reaches a field built inside a scope', () {
      installRules();
      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      final form = TomScope.withScope('checkout', AddressForm.new);
      _join(form.street, group);

      expect(form.street.basePath, 'checkout.address.street');
      expect(
        TomAuthorization.resolveAuth(form.street.basePath),
        TomAuthState.full,
        reason: 'the narrowing can only come from the group',
      );
      expect(form.street.effectiveAuthState, TomAuthState.read);
    });

    test('the effective state does not depend on where it is read from', () {
      // The defect this closes: the field's path was frozen at construction
      // while its group was resolved against whatever zone the *reader* stood
      // in. Both halves now come from the frame captured at construction.
      installRules();
      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      final form = TomScope.withScope('checkout', AddressForm.new);
      _join(form.street, group);

      expect(
        form.street.effectiveAuthState,
        TomAuthState.read,
        reason: 'read at the root',
      );
      TomScope.withScope('checkout', () {
        expect(
          form.street.effectiveAuthState,
          TomAuthState.read,
          reason: 'read inside the frame it was built in',
        );
      });
      TomScope.withScope('elsewhere', () {
        expect(
          form.street.effectiveAuthState,
          TomAuthState.read,
          reason: 'a foreign zone does not move the field',
        );
      });
    });

    test('a field with no form stands where it was built', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'checkout.street': TomAuthState.full,
        'checkout.shipping': TomAuthState.read,
        'shipping': TomAuthState.full, // the unscoped decoy
      });
      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      final field = TomScope.withScope(
        'checkout',
        () => TomFormStringInput('street', '', tomGroup: group),
      );

      expect(field.basePath, 'checkout.street');
      expect(field.effectiveAuthState, TomAuthState.read);
    });

    test('a form field and a form action share one group ceiling', () {
      // A group is one ceiling. The form is a TomActionController as well as a
      // field container, so a group holding both must resolve to the same rule
      // for both — which is only true while the field treats the form id as
      // namespace, exactly as the action does, rather than as location.
      installRules();
      final group = TomAuthorizationGroup(
        'shipping',
        mode: AuthGroupMode.controlsWidest,
      );
      final form = TomScope.withScope('checkout', AddressForm.new);
      _join(form.street, group);
      final action = _NoopAction(controller: form, tomGroup: group);

      expect(action.canonicalPath, 'checkout.address.edit');
      expect(form.street.basePath, 'checkout.address.street');
      expect(action.effectiveAuthState, TomAuthState.read);
      expect(form.street.effectiveAuthState, TomAuthState.read);
    });
  });
}
