/// Unit tests for [FieldStateAuthorizationAdapter] (realignment todo 2): the
/// implicit-authorization adapter that resolves a field's grade from the
/// session's resolved matrix.
///
/// These pin the four behaviours the plan's done-when calls out — present key →
/// its state; absent leaf → `none` (D-A4); repointing `states` changes
/// resolution; structural ancestor (the form path `todo.item`) → permissive so
/// the layer-3 form narrow is a no-op — plus integration through the
/// `TomAuthorization` singleton the form layer actually consults.
library;

import 'package:advanced_app_client/app/field_state_authorization_adapter.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // An owner-style matrix: everything editable except a read-only assignee and
  // a hidden estimate, exercising three of the four states.
  Map<String, TomAuthState> ownerish() => {
        TodoItemResourceKeys.title: TomAuthState.full,
        TodoItemResourceKeys.status: TomAuthState.full,
        TodoItemResourceKeys.assigneeId: TomAuthState.read,
        TodoItemResourceKeys.estimate: TomAuthState.none,
      };

  group('FieldStateAuthorizationAdapter.resolveAuth', () {
    test('returns the matrix state for a present field key', () {
      final adapter = FieldStateAuthorizationAdapter(ownerish());
      expect(adapter.resolveAuth(TodoItemResourceKeys.title), TomAuthState.full);
      expect(
          adapter.resolveAuth(TodoItemResourceKeys.assigneeId), TomAuthState.read);
      expect(adapter.resolveAuth(TodoItemResourceKeys.estimate), TomAuthState.none);
    });

    test('a known gradable key the matrix omits degrades to none (D-A4)', () {
      final adapter = FieldStateAuthorizationAdapter(ownerish());
      // `priority` is a gradable key absent from the owner-ish matrix.
      expect(adapter.resolveAuth(TodoItemResourceKeys.priority), TomAuthState.none);
    });

    test('a path outside the gradable namespace stays permissive (full)', () {
      // The adapter is installed on the singleton, so non-item fields (the login
      // form, the board) route through it too — they must NOT be hidden.
      final adapter = FieldStateAuthorizationAdapter(ownerish());
      expect(adapter.resolveAuth('login.username'), TomAuthState.full);
      expect(adapter.resolveAuth('login'), TomAuthState.full);
      // An unknown leaf that is not a gradable key is likewise left alone.
      expect(adapter.resolveAuth('todo.item.bogus'), TomAuthState.full);
    });

    test('an empty matrix resolves every gradable leaf to none', () {
      final adapter = FieldStateAuthorizationAdapter();
      expect(adapter.resolveAuth(TodoItemResourceKeys.title), TomAuthState.none);
      // The form-path ancestor stays permissive even with no matrix loaded, so
      // the layer-3 form narrow never hides the form before an item is opened.
      final formPath =
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}';
      expect(adapter.resolveAuth(formPath), TomAuthState.full);
    });

    test('a structural ancestor (the form path) resolves permissively to full',
        () {
      final adapter = FieldStateAuthorizationAdapter(ownerish());
      // The layer-3 form narrow looks up `todo.item`; it must NOT clobber the
      // per-field grades, so an ungraded ancestor of graded fields → full.
      final formPath =
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}';
      expect(formPath, 'todo.item');
      expect(adapter.resolveAuth(formPath), TomAuthState.full);
      // The scope node is also an ancestor → permissive.
      expect(adapter.resolveAuth(TodoItemResourceKeys.scope), TomAuthState.full);
    });

    test('an explicit grade for an ancestor still wins over the permissive rule',
        () {
      final adapter = FieldStateAuthorizationAdapter({
        'todo.item': TomAuthState.read,
        TodoItemResourceKeys.title: TomAuthState.full,
      });
      expect(adapter.resolveAuth('todo.item'), TomAuthState.read);
    });

    test('repointing states changes resolution without a new instance', () {
      final adapter = FieldStateAuthorizationAdapter(ownerish());
      expect(adapter.resolveAuth(TodoItemResourceKeys.title), TomAuthState.full);

      adapter.states = {TodoItemResourceKeys.title: TomAuthState.read};
      expect(adapter.resolveAuth(TodoItemResourceKeys.title), TomAuthState.read);
      // A key dropped from the new matrix returns to the closed-safe default.
      expect(adapter.resolveAuth(TodoItemResourceKeys.status), TomAuthState.none);

      adapter.states = const {};
      expect(adapter.resolveAuth(TodoItemResourceKeys.title), TomAuthState.none);
    });
  });

  group('through the TomAuthorization singleton', () {
    tearDown(TomAuthorization.reset);

    test('the form layer reads grades via the installed adapter', () {
      final adapter = FieldStateAuthorizationAdapter(ownerish());
      TomAuthorization.adapter = adapter;

      // What a field's layer-1 resolution sees:
      expect(TomAuthorization.resolveAuth(TodoItemResourceKeys.title),
          TomAuthState.full);
      expect(TomAuthorization.resolveAuth(TodoItemResourceKeys.priority),
          TomAuthState.none);
      // And the form-path narrow (layer 3) is a no-op:
      expect(TomAuthorization.resolveAuth('todo.item'), TomAuthState.full);
    });
  });
}
