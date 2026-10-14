/// Item permission levels: item types with ordered levels, items named at run
/// time, levels held on a category pattern, and the grade every level maps to
/// for code that only knows grades.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  late TomItemType document;

  setUp(() {
    TomItemTypeRegistry.reset();
    TomResourceRoleRegistry.reset();
    document = TomItemType.standard('document');
    TomItemTypeRegistry.register(document);
  });

  tearDown(() {
    TomItemTypeRegistry.reset();
    TomResourceRoleRegistry.reset();
  });

  group('an item type', () {
    test('orders its levels and maps each to a grade', () {
      expect(document.levels, ['view', 'comment', 'edit', 'manage']);
      expect(document.rankOf('comment'), 1);
      expect(document.rankOf('approve'), -1);
      expect(document.gradeOf('comment'), TomAuthState.read);
      expect(document.gradeOf('edit'), TomAuthState.full);
      expect(document.stronger('view', 'comment'), 'comment');
    });

    test('names its items and patterns at run time', () {
      const id = '0b1f6c1e-7a39-4c55-9f0e-2d4b8a1c3e57';
      expect(document.keyFor(id), 'document:$id');
      expect(document.patternFor('finance/'), 'document:finance/*');
      expect(document.patternFor(), 'document:*');
    });

    test('round-trips a manifest declaration', () {
      final type = TomItemType.fromJson({
        'name': 'todo',
        'levels': [
          {'name': 'see', 'grade': 'read'},
          {'name': 'tick', 'grade': 'full'},
        ],
      });
      expect(type.levels, ['see', 'tick']);
      expect(type.gradeOf('tick'), TomAuthState.full);
      expect(TomItemType.fromJson(type.toJson()).toJson(), type.toJson());
    });

    test('refuses a malformed declaration', () {
      expect(
        () => TomItemType('Document', ['view'], {'view': TomAuthState.read}),
        throwsArgumentError,
      );
      expect(() => TomItemType('doc', [], {}), throwsArgumentError);
      expect(
        () => TomItemType('doc', ['view', 'view'], {'view': TomAuthState.read}),
        throwsArgumentError,
      );
      expect(
        () => TomItemType('doc', ['view', 'edit'], {'view': TomAuthState.read}),
        throwsArgumentError,
      );
      expect(
        () => TomItemType.fromJson({
          'name': 'doc',
          'levels': [
            {'name': 'view', 'grade': 'sometimes'},
          ],
        }),
        throwsArgumentError,
      );
    });
  });

  group('the level a principal holds', () {
    test('is read from the item key', () {
      final roles = {'document:a1': 'comment'};
      expect(TomItemPermissions.levelOn(roles, document, 'a1'), 'comment');
      expect(TomItemPermissions.levelOn(roles, document, 'a2'), isNull);
      expect(TomItemPermissions.allows(roles, document, 'a1', 'view'), isTrue);
      expect(
        TomItemPermissions.allows(roles, document, 'a1', 'comment'),
        isTrue,
      );
      expect(TomItemPermissions.allows(roles, document, 'a1', 'edit'), isFalse);
    });

    test('covers every item of a category through a pattern', () {
      final roles = {document.patternFor('finance/'): 'edit'};
      expect(
        TomItemPermissions.levelOn(roles, document, 'finance/2026/q1'),
        'edit',
      );
      expect(TomItemPermissions.levelOn(roles, document, 'hr/q1'), isNull);
      expect(
        TomItemPermissions.levelOn({'document:*': 'view'}, document, 'any'),
        'view',
      );
    });

    test('is the strongest of the key and the patterns covering it', () {
      final roles = {
        'document:finance/q1': 'comment',
        'document:finance/*': 'edit',
        'document:*': 'view',
      };
      expect(TomItemPermissions.levelOn(roles, document, 'finance/q1'), 'edit');
      expect(TomItemPermissions.levelOn(roles, document, 'hr/q1'), 'view');
    });

    test(
      'ignores levels the type does not declare and keys of other types',
      () {
        TomItemTypeRegistry.register(TomItemType.standard('todo'));
        final roles = {
          'document:a1': 'approve',
          'todo:a1': 'manage',
          'todo:*': 'manage',
        };
        expect(TomItemPermissions.levelOn(roles, document, 'a1'), isNull);
        expect(
          TomItemPermissions.gradeOn(roles, document, 'a1'),
          TomAuthState.none,
        );
      },
    );

    test('asking for an undeclared level is a bug', () {
      expect(
        () => TomItemPermissions.allows(const {}, document, 'a1', 'approve'),
        throwsArgumentError,
      );
    });
  });

  group('for code that only knows grades', () {
    test('an item key resolves to its level\'s grade, patterns included', () {
      final adapter = TomResourceRoleAdapter(const {
        'document:a1': 'comment',
        'document:finance/*': 'manage',
      });
      expect(adapter.resolveAuth('document:a1'), TomAuthState.read);
      expect(adapter.resolveAuth('document:finance/q1'), TomAuthState.full);
      expect(adapter.resolveAuth('document:hr/q1'), TomAuthState.none);
    });

    test('other keys resolve through the role registry', () {
      TomResourceRoleRegistry.register('owner', TomAuthState.full);
      final adapter = TomResourceRoleAdapter(const {'project.42': 'owner'});
      expect(adapter.resolveAuth('project.42'), TomAuthState.full);
      expect(
        TomResourceRoleRegistry.stateOn('project.42', 'owner'),
        TomAuthState.full,
      );
      // A key whose prefix names no declared type is an ordinary key.
      expect(
        TomResourceRoleRegistry.stateOn('report:7', 'owner'),
        TomAuthState.full,
      );
    });

    test('two levels on one item fold by the type\'s order, not the grade', () {
      // view and comment are both `read`; the order still tells them apart.
      expect(
        TomResourceRoleRegistry.strongerOn('document:a1', 'view', 'comment'),
        'comment',
      );
      expect(
        TomResourceRoleRegistry.stateOn('document:a1', 'comment'),
        TomAuthState.read,
      );
      expect(TomResourceRoleRegistry.stateOn('document:a1', 'approve'), isNull);
    });
  });
}
