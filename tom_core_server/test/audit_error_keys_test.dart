/// Pins the `audit` module's error keys that no other suite names.
///
/// A key is the contract a caller, a log search or a translation table is
/// written against. One that no test names is a failure mode nobody checks:
/// its raise site can be deleted, reworded into a different key, or swallowed
/// by a broader catch, and every suite stays green. Each test reaches the raise
/// site through the smallest real input that gets there and asserts the exact
/// key.
///
/// `audit.anchor.malformed_line` is the file store's answer to an anchor line
/// it cannot read. It matters more than most read errors: the anchor archive is
/// the thing an attacker who rewrote the audit table must not be able to edit
/// too, so a damaged line is evidence and has to surface as itself — not be
/// skipped, and not be reported as some other parse failure that hides which
/// file and line to look at.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  group('TomFileAuditAnchorStore.read', () {
    late Directory directory;
    late TomFileAuditAnchorStore store;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('audit_error_keys_');
      store = TomFileAuditAnchorStore(directory: directory);
    });

    tearDown(() => directory.deleteSync(recursive: true));

    // Each line is damaged at a different depth: not JSON at all, JSON that is
    // not an object, and an object the anchor decoder itself refuses. All
    // three must arrive under the store's key, with the line number that
    // locates them.
    for (final (label, line) in [
      ('text that is not JSON', 'this is not an anchor'),
      ('JSON that is not an object', '[1, 2, 3]'),
      ('an object that is not an anchor', '{"writer": "node-a"}'),
    ]) {
      test('a line holding $label is reported, not skipped', () async {
        final file = store.fileFor('node-a');
        file.writeAsStringSync('\n$line\n');

        await expectLater(
          store.read('node-a'),
          throwsA(
            isA<TomAuditException>()
                .having((e) => e.key, 'key', 'audit.anchor.malformed_line')
                .having((e) => e.parameters?['line'], 'line', 2)
                .having(
                  (e) => p.basename('${e.parameters?['file']}'),
                  'file',
                  p.basename(file.path),
                ),
          ),
        );
      });
    }
  });
}
