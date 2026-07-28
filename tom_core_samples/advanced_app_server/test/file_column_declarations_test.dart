/// Database-free assertions on the *declarations* that decide how this server's
/// two file columns behave — exposure, cascade and grade.
///
/// The framework already proves that a `@TomFileReference` behaves as declared:
/// `tom_core_server/test/file_storage_db_test.dart` deletes rows against a real
/// MariaDB and shows that a `cascadeDelete: true` column loses its bytes while a
/// `cascadeDelete: false` one keeps them, and that an unexposed column has no
/// slot. What is *this sample's* to assert is the other half — that
/// `app_items.attachment` and `app_items.internal_note` really carry the
/// declarations the guide claims they do, read back through the same reflection
/// the repository reads at runtime rather than from the source text.
///
/// The second group closes the loop from the declaration to the *server*: the
/// one boot line `TomFileSlots.register(itemRepository)` publishes a slot for
/// the exposed column and none for the other, from the same entity and the same
/// call — which is the server-side half of the 404 the live suite (TC-FT-03)
/// observes over HTTP.
///
/// Every claim in this file is a claim about one line of
/// `app_persistence_model.dart`, and each is a line whose loss would be silent:
/// dropping `exposed` makes a column unreachable (nothing fails to compile),
/// dropping `cascadeDelete` orphans blobs on every delete, dropping `authKey`
/// turns a graded column into an ungraded one that everybody may write.
///
/// The auth server pins the mirror image for `auth_users.avatar_ref`
/// (`cascadeDelete: false`) in its own package — each suite reads only its own
/// entities.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import '../bin/app_server_start.reflection.dart' show initializeReflection;

void main() {
  setUpAll(initializeReflection);

  group('the item record declares two file columns, one of them reachable', () {
    late final Map<String, TomColumnInformation> fileColumns;

    setUpAll(() {
      fileColumns = {
        for (final column in TomAnnotationAnalyzer.findFileColumns(ItemRecord))
          column.getQueryFieldName(): column,
      };
    });

    test('both file columns are found, and only those two', () {
      expect(
        fileColumns.keys.toSet(),
        {itemAttachmentColumn, 'internal_note'},
        reason: 'a third file column would widen the sample\'s surface without '
            'the guide saying so',
      );
    });

    test('the attachment is exposed, cascading and graded', () {
      final reference = fileColumns[itemAttachmentColumn]!.fileReference!;
      expect(reference.exposed, isTrue,
          reason: 'exposure is what gives the column a slot at all — without '
              'it the whole file feature is unreachable over HTTP');
      expect(reference.cascadeDelete, isTrue,
          reason: 'an attachment belongs to its item and must die with it; the '
              'framework db suite proves this flag is what makes that happen');
      expect(
        fileColumns[itemAttachmentColumn]!.column?.authKey,
        itemAttachmentGradeKey,
        reason: 'the C-4 key is what routes openFile/saveFile through the '
            'per-row grade resolver — an ungraded file column would be '
            'writable by anyone who can see the row',
      );
    });

    test('the internal note is a file column that nobody exposed', () {
      final column = fileColumns['internal_note']!;
      expect(column.fileReference!.exposed, isFalse,
          reason: 'the default-closed contrast the integration suite asserts '
              'over HTTP: same row, same principal, no slot');
      expect(column.column?.authKey, isNull,
          reason: 'and it needs no grade, because a column with no slot is '
              'never reached by a request in the first place');
    });
  });

  group('exposure decides which slots the boot registration publishes', () {
    // `TomFileSlots.register` reads the same annotations the group above pins
    // and turns the *exposed* ones into addressable slots. Registering needs the
    // repository's datasource metadata (never a connection) — see the note in
    // the next group.
    setUp(() {
      TomDataSourceInfo.datasources[appDatasource] =
          TomDataSourceInfo(appDatasource, {});
      TomFileSlots.register(itemRepository);
    });
    tearDown(() {
      TomFileSlots.reset();
      TomDataSourceInfo.datasources.remove(appDatasource);
    });

    test('the exposed column resolves to a slot', () {
      expect(TomFileSlots.resolve(appItemsTable, itemAttachmentColumn),
          isNotNull,
          reason: 'this is the object the file endpoint and the board\'s '
              'batched descriptor lookup both go through — one registration '
              'line at boot, derived from the annotation, never a second copy '
              'of the table and column names');
    });

    test('the unexposed column resolves to nothing at all', () {
      // The server-side half of the default-closed rule the live suite asserts
      // over HTTP (TC-FT-03): there is no slot object to reach, so the endpoint
      // has nothing to authorize and answers 404 for every caller. The
      // registration is per *entity*, not per column — passing the same
      // repository publishes one column and not the other purely because of
      // what they declare.
      expect(TomFileSlots.resolve(appItemsTable, 'internal_note'), isNull);
    });
  });

  group('the graded column is registered for per-row resolution', () {
    // Like `registerAppDataScopes`, this eagerly builds the production
    // repositories, which resolve their datasource *metadata* (never a
    // connection) at construction time — so the two datasources they bind
    // (`main` for the grant/delegation tables, `app_db` for the records) must be
    // registered first. Bare, uninitialised entries satisfy the lookup without
    // opening a socket, keeping this test connection-free.
    setUp(() {
      TomDataSourceInfo.datasources['main'] = TomDataSourceInfo('main', {});
      TomDataSourceInfo.datasources[appDatasource] =
          TomDataSourceInfo(appDatasource, {});
    });
    tearDown(() {
      TomRowColumnAuthorization.reset();
      TomDataSourceInfo.datasources.remove('main');
      TomDataSourceInfo.datasources.remove(appDatasource);
    });

    test('registerAppColumnGrades installs a resolver for the attachment key',
        () {
      // Boot registers this; without it `_rowColumnGrade` falls back to the
      // process-global TomAuthorization, which answers `full` for everyone when
      // no adapter is installed — exactly the sample servers' situation. So the
      // registration is not a refinement of the grade, it *is* the grade.
      expect(TomRowColumnAuthorization.isRegistered(itemAttachmentGradeKey),
          isFalse);

      registerAppColumnGrades();

      expect(
        TomRowColumnAuthorization.isRegistered(itemAttachmentGradeKey),
        isTrue,
      );
    });
  });
}
