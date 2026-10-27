/// Every local commit moves the head, however fast the commits come.
///
/// A file's head token is its size and modification time, and a file system
/// reports that time to the millisecond. Two same-size commits inside one
/// millisecond would otherwise leave the head where it was, and a device
/// holding the older head could then commit over the newer write: the lost
/// update the compare-and-swap exists to refuse.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

import 'support/scratch.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late Directory dir;
  const storage = TomLocalFileSystemStorage();

  setUp(() {
    dir = scratchDirectory('head_advances');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  });

  test('LOCAL-HEAD-1: back-to-back same-size commits to one file each move '
      'the head', () async {
    final loc = p.join(dir.path, 'doc.kdbx');
    var head = await storage.commit(
      loc,
      TomChangeset.singleFile(_b('aaa')),
      expectedHead: null,
    );
    for (var i = 0; i < 200; i++) {
      final next = await storage.commit(
        loc,
        TomChangeset.singleFile(_b(i.isEven ? 'bbb' : 'ccc')),
        expectedHead: head,
      );
      expect(next, isNot(head), reason: 'commit $i left the head unchanged');
      head = next;
    }
  });

  test('LOCAL-HEAD-2: the same for a part of a directory container', () async {
    final loc = p.join(dir.path, 'doc.webwork');
    var head = await storage.commit(
      loc,
      TomChangeset(writes: {'part.yaml': _b('aaa')}),
      expectedHead: null,
    );
    for (var i = 0; i < 200; i++) {
      final next = await storage.commit(
        loc,
        TomChangeset(writes: {'part.yaml': _b(i.isEven ? 'bbb' : 'ccc')}),
        expectedHead: head,
      );
      expect(next, isNot(head), reason: 'commit $i left the head unchanged');
      head = next;
    }
  });

  test('LOCAL-HEAD-3: so a commit against the head before a fast same-size '
      'write is refused', () async {
    final loc = p.join(dir.path, 'race.kdbx');
    for (var i = 0; i < 100; i++) {
      final h1 = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('one')),
        expectedHead: await storage.headOf(loc),
      );
      await storage.commit(
        loc,
        TomChangeset.singleFile(_b('two')),
        expectedHead: h1,
      );
      await expectLater(
        storage.commit(
          loc,
          TomChangeset.singleFile(_b('late')),
          expectedHead: h1,
        ),
        throwsA(isA<TomCasConflictException>()),
        reason: 'round $i: a stale head was accepted',
      );
    }
  });
}
