/// Unit tests for [SaveFormAction] — the failure, multi-form roll-up, and
/// transient-status branches that the widget-level demo tests never assert.
///
/// `demo_a_lifecycle_test` only pins the *success* path and the cross-field
/// error *banner*; nothing checks that the action writes its resolved
/// `.error` / "Validation failed — check fields" message to the bound
/// `status` `TomString` when the aggregated result is `false`, and the
/// `results.every(...)` roll-up across *multiple* forms is untested. The
/// transient "Validating…" status is likewise never observed.
///
/// In addition these tests pin the bug-§36 contract: a `save()` that *throws*
/// (rather than completing `false`) must be reported on `status` exactly like
/// a `false` result — not left stuck on the transient "Validating…" message
/// with the rejection escaping as an uncaught async error.
///
/// The forms here are reflection-free [TomForm] test doubles: they override
/// the self-observation hooks to skip reflective member discovery (they carry
/// no fields) and expose a scripted [save] result, so the action's own logic
/// can be exercised without binding state, resources, or a widget tree.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/actions/form_actions.dart';

/// A [TomForm] whose [save] outcome is scripted. Skips reflection-driven
/// self-observation (no fields), so it constructs without the app's
/// reflection registry being initialised.
class _ScriptedForm extends TomForm<TomClass> {
  /// Value returned by [save] when it completes normally.
  final bool result;

  /// When `true`, [save] throws instead of completing — models a save that
  /// rejects (validator/back-write error) rather than returning `false`.
  final bool throws;

  /// Artificial latency so callers can observe the transient status the
  /// action sets *before* the futures resolve.
  final Duration delay;

  _ScriptedForm({
    this.result = true,
    this.throws = false,
    this.delay = Duration.zero,
  }) : super(formId: 'scripted');

  @override
  void prepareForSelfObservation() {
    // No reflective members to discover — intentionally skip the base
    // TomForm hook (which would resolve scope/basePath and call
    // createFormElements under reflection).
  }

  @override
  void startSelfObservation() {
    // No TomObject members to register; skip the reflective walk.
  }

  @override
  void createFormElements() {}

  @override
  Future<bool> save({bool? commitBaselines}) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (throws) {
      throw StateError('scripted save failure');
    }
    return result;
  }
}

SaveFormAction _action(List<TomForm> forms, TomString status) {
  return SaveFormAction(
    TomActionController(controllerId: 'demoTest'),
    forms: forms,
    status: status,
  );
}

void main() {
  group('SaveFormAction — status resolution', () {
    test('a single failing save writes the resolved error message', () async {
      final status = TomString('idle');
      _action([_ScriptedForm(result: false)], status).execute(
        TomActionContext(),
        TomActionTransaction(label: 'save'),
      );
      // Let the fire-and-forget Future.wait settle.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(status.get(), 'Validation failed — check fields',
          reason: 'allOk == false must surface the .error fallback on status');
    });

    test('a single successful save writes the success message', () async {
      final status = TomString('idle');
      _action([_ScriptedForm(result: true)], status).execute(
        TomActionContext(),
        TomActionTransaction(label: 'save'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(status.get(), 'Saved!');
    });

    test('sets the transient "Validating…" status synchronously', () async {
      final status = TomString('idle');
      _action(
        [_ScriptedForm(result: true, delay: const Duration(milliseconds: 50))],
        status,
      ).execute(
        TomActionContext(),
        TomActionTransaction(label: 'save'),
      );
      // execute() returns before the delayed save resolves: the transient
      // status must already be visible.
      expect(status.get(), 'Validating…',
          reason: 'status must show the transient message before save resolves');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(status.get(), 'Saved!',
          reason: 'once the save resolves the transient status is replaced');
    });
  });

  group('SaveFormAction — multi-form roll-up', () {
    test('all forms valid rolls up to success', () async {
      final status = TomString('idle');
      _action(
        [_ScriptedForm(result: true), _ScriptedForm(result: true)],
        status,
      ).execute(TomActionContext(), TomActionTransaction(label: 'save'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(status.get(), 'Saved!');
    });

    test('one failing form makes the all-or-nothing roll-up fail', () async {
      final status = TomString('idle');
      _action(
        [_ScriptedForm(result: true), _ScriptedForm(result: false)],
        status,
      ).execute(TomActionContext(), TomActionTransaction(label: 'save'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(status.get(), 'Validation failed — check fields',
          reason: 'results.every must report failure if any form is invalid');
    });
  });

  group('SaveFormAction — thrown save (bug §36)', () {
    test('a save that throws is reported on status like a false result',
        () async {
      final status = TomString('idle');
      _action([_ScriptedForm(throws: true)], status).execute(
        TomActionContext(),
        TomActionTransaction(label: 'save'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(status.get(), 'Validation failed — check fields',
          reason: 'a thrown save must not leave status stuck on "Validating…"');
    });

    test('a thrown save in a multi-form batch still reports failure',
        () async {
      final status = TomString('idle');
      _action(
        [_ScriptedForm(result: true), _ScriptedForm(throws: true)],
        status,
      ).execute(TomActionContext(), TomActionTransaction(label: 'save'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(status.get(), 'Validation failed — check fields');
    });
  });
}
