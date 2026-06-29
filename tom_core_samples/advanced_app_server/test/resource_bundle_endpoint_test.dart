/// Tests for the app server's authenticated resource endpoint (todo 7).
///
/// Three things the done-when calls for: the bundle returns the app tier's keys
/// (board + item-form labels), the keys are *derived* from the todo-1 domain
/// convention so a served label key cannot drift from the field's grade key, and
/// the endpoint requires authentication (an anonymous caller is rejected). The
/// bundle is pure text — no database — so this verifies directly against the
/// [AppResourceBundles] source and the contract's `appApiAccess` policy, with no
/// server or MariaDB.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

TomPrincipal _authenticated({List<String> roles = const []}) => TomPrincipal(
      authenticated: true,
      user: TomUser(username: 'alice'),
      aci: TomAccessControlInformation(roles: roles),
    );

void main() {
  group('app resource bundle (todo 7)', () {
    test('appBundle labels every gradable item field, keyed off the domain '
        'convention', () {
      final texts = AppResourceBundles.appBundle().texts;
      for (final field in TodoItemResourceKeys.allFields) {
        final key = '${TodoItemResourceKeys.keyFor(field)}.label';
        expect(texts.containsKey(key), isTrue, reason: 'missing label key $key');
      }
      // The estimate label is keyed on the concept token (`estimate`), never the
      // entity member `estimateHours` — the label key tracks the grade key.
      expect(texts.containsKey('todo.item.estimate.label'), isTrue);
      expect(texts.containsKey('todo.item.estimateHours.label'), isFalse);
      expect(texts['todo.item.title.label'], 'Title');
      expect(texts['todo.item.estimate.label'], 'Estimate (h)');
    });

    test('appBundle carries the board texts', () {
      final texts = AppResourceBundles.appBundle().texts;
      expect(texts['board.title'], isNotNull);
      expect(texts['board.item.save'], 'Save');
    });

    test('the appResources handler returns the app bundle', () async {
      final dto = await AdvancedAppApiService().resources();
      expect(dto, AppResourceBundles.appBundle());
    });

    test('appResources requires authentication (rejects an anonymous caller)',
        () {
      final access = appApiAccess['appResources']!;
      expect(access.checkAccessibility(null), isFalse);
      expect(access.checkAccessibility(_authenticated()), isTrue);
    });
  });
}
