/// Database-free assertions on the *declarations* that decide how this server's
/// one file column behaves — exposure, cascade, and the absence of a grade.
///
/// `auth_users.avatar_ref` is the deliberate mirror image of the app server's
/// `app_items.attachment`, and the contrast is the point: an attachment belongs
/// to its item and dies with it (`cascadeDelete: true`), while an avatar is a
/// picture a person uploaded that outlives the account row
/// (`cascadeDelete: false`). The framework proves that this flag really is what
/// decides the outcome — `tom_core_server/test/file_storage_db_test.dart`
/// deletes rows against a real MariaDB and watches one column lose its bytes
/// while the other keeps them. What is *this sample's* to assert is that the
/// avatar column carries the declaration the guide says it does, read back
/// through the same reflection the repository reads at runtime rather than from
/// the source text — because losing the flag breaks nothing at compile time and
/// nothing at request time, only silently changes what a delete reclaims.
///
/// The app server pins its half (`attachment` exposed/cascading/graded,
/// `internal_note` unexposed) in `advanced_app_server`'s test of the same name;
/// each suite reads only its own entities.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import '../bin/auth_server_start.reflection.dart' show initializeReflection;

void main() {
  setUpAll(initializeReflection);

  group('the user record declares one non-cascading file column', () {
    late final Map<String, TomColumnInformation> fileColumns;

    setUpAll(() {
      fileColumns = {
        for (final column in TomAnnotationAnalyzer.findFileColumns(UserRecord))
          column.getQueryFieldName(): column,
      };
    });

    test('the avatar is the only file column on the record', () {
      expect(
        fileColumns.keys.toSet(),
        {AppFileSlots.userAvatarColumn},
        reason:
            'the auth tier stores exactly one blob per user; a second file '
            'column would widen the sample without the guide saying so',
      );
    });

    test('the avatar is exposed but does not cascade', () {
      final reference =
          fileColumns[AppFileSlots.userAvatarColumn]!.fileReference!;
      expect(
        reference.exposed,
        isTrue,
        reason:
            'exposure is what gives the column a slot at all — the '
            'avatar is uploaded and fetched over HTTP like the attachment',
      );
      expect(
        reference.cascadeDelete,
        isFalse,
        reason:
            'the counterpart of the attachment: deleting a user must '
            'leave the avatar bytes in the blob store. This one flag is the '
            'whole difference, and the framework db suite proves it decides '
            'the outcome',
      );
    });

    test('the avatar carries no column grade', () {
      // Unlike `app_items.attachment`, the avatar is not graded per row: a user
      // owns their own picture, and the file endpoint's row scope on
      // `auth_users` already answers who may reach the row at all. Adding an
      // `authKey` here would demand a resolver the auth server does not
      // register, and an unregistered key falls back to the process-global
      // TomAuthorization — `full` for everyone, since no adapter is installed.
      expect(
        fileColumns[AppFileSlots.userAvatarColumn]!.column?.authKey,
        isNull,
      );
    });
  });
}
