// Unit tests for the in-memory backend: login, CRUD, and the four-state field
// matrix. These run with no widgets and no socket — the backend is the seam
// the whole app is written against, so its contract is pinned here.

import 'package:core_client_sample/api/in_memory_todo_api.dart';
import 'package:core_client_sample/api/todo_api.dart';
import 'package:core_client_sample/reflection_seed.dart';
import 'package:core_client_sample/resources/app_texts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart' hide initializeReflection;

void main() {
  setUpAll(initializeReflection);

  late InMemoryTodoApi api;
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(appTexts),
    );
    api = InMemoryTodoApi();
  });

  group('login', () {
    test('CCS-API-01: accepts a known account with any non-empty password',
        () async {
      final result = await api.login('alice', 'whatever');
      expect(result.user.role.get(), 'owner');
      expect(result.token, isNotEmpty);
    });

    test('CCS-API-02: is case-insensitive and trims the username', () async {
      final result = await api.login('  ALICE ', 'pw');
      expect(result.user.role.get(), 'owner');
    });

    test('CCS-API-03: rejects an unknown account', () async {
      expect(
        () => api.login('nobody', 'pw'),
        throwsA(isA<TodoApiException>()),
      );
    });

    test('CCS-API-04: rejects an empty password', () async {
      expect(
        () => api.login('alice', ''),
        throwsA(isA<TodoApiException>()),
      );
    });
  });

  group('items CRUD', () {
    test('CCS-API-05: lists the seeded items', () async {
      final items = await api.listItems();
      expect(items, isNotEmpty);
    });

    test('CCS-API-06: creates an item and assigns an id', () async {
      final created = await api.saveItem(TodoItem()..title.set('New one'));
      expect(created.id.get(), isNotEmpty);
      final all = await api.listItems();
      expect(all.map((i) => i.title.get()), contains('New one'));
    });

    test('CCS-API-07: updates an existing item by id', () async {
      final items = await api.listItems();
      final first = items.first;
      first.title.set('Renamed');
      await api.saveItem(first);
      final reloaded = (await api.listItems())
          .firstWhere((i) => i.id.get() == first.id.get());
      expect(reloaded.title.get(), 'Renamed');
    });

    test('CCS-API-08: deletes an item', () async {
      final items = await api.listItems();
      final id = items.first.id.get();
      await api.deleteItem(id);
      final remaining = await api.listItems();
      expect(remaining.map((i) => i.id.get()), isNot(contains(id)));
    });

    test('CCS-API-09: listItems hands out detached copies', () async {
      final a = await api.listItems();
      a.first.title.set('Mutated locally');
      final b = await api.listItems();
      expect(b.first.title.get(), isNot('Mutated locally'));
    });
  });

  group('field states (four-state matrix)', () {
    test('CCS-API-10: owner is fully editable across the board', () async {
      final states = await api.fieldStates('owner');
      expect(states['todo.item.title'], TomAuthState.full);
      expect(states['todo.item.done'], TomAuthState.full);
      expect(states['todo.item.priority'], TomAuthState.full);
      expect(states['todo.item.assigneeId'], TomAuthState.full);
    });

    test('CCS-API-11: member cannot see priority and cannot reassign',
        () async {
      final states = await api.fieldStates('member');
      expect(states['todo.item.priority'], TomAuthState.none);
      expect(states['todo.item.assigneeId'], TomAuthState.read);
    });

    test('CCS-API-12: viewer toggles nothing — done is disabled, rest read',
        () async {
      final states = await api.fieldStates('viewer');
      expect(states['todo.item.done'], TomAuthState.disabled);
      expect(states['todo.item.title'], TomAuthState.read);
      expect(states['todo.item.priority'], TomAuthState.read);
    });

    test('CCS-API-13: an unknown role degrades every field to none', () async {
      final states = await api.fieldStates('ghost');
      for (final key in gradableItemKeys) {
        expect(states[key], TomAuthState.none);
      }
    });
  });
}
