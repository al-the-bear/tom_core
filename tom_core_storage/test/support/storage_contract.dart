/// The storage contract every backend is held to: what a caller of
/// `TomStorage` may rely on, whatever the medium.
///
/// A backend's suite calls [storageContract] with a way to open it and a way
/// to name a fresh container; the cases below run against that backend.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

/// Runs the contract against a backend.
///
/// [locator] names a container no case has used yet; [secondDevice], when
/// given, opens another instance over the same remote, for the cases about
/// what one device sees of another's writes.
void storageContract(
  String id, {
  required Future<TomStorage> Function() open,
  required String Function(String name) locator,
  Future<TomStorage> Function()? secondDevice,
}) {
  late TomStorage storage;
  setUp(() async => storage = await open());
  tearDown(() => storage.close());

  group('$id contract', () {
    test(
      '$id-C1: a container nobody wrote has no head and cannot be read',
      () async {
        final loc = locator('absent');
        expect(await storage.headOf(loc), isNull);
        await expectLater(
          storage.readBytes(loc),
          throwsA(isA<TomContainerNotFoundException>()),
        );
        await expectLater(
          storage.readBundle(loc),
          throwsA(isA<TomContainerNotFoundException>()),
        );
      },
    );

    test('$id-C2: a single-file container is created, read back, and its '
        'head is the one the commit returned', () async {
      final loc = locator('single.kdbx');
      final head = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('one')),
        expectedHead: null,
      );
      expect(await storage.headOf(loc), head);
      expect(utf8.decode(await storage.readBytes(loc)), 'one');
      final next = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('two')),
        expectedHead: head,
      );
      expect(next, isNot(head));
      expect(utf8.decode(await storage.readBytes(loc)), 'two');
    });

    test('$id-C3: a commit against a stale head is refused, names the head '
        'it found, and changes nothing', () async {
      final loc = locator('cas.kdbx');
      final first = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('first')),
        expectedHead: null,
      );
      final second = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('second')),
        expectedHead: first,
      );
      try {
        await storage.commit(
          loc,
          TomChangeset.singleFile(_b('stale')),
          expectedHead: first,
        );
        fail('a stale head was accepted');
      } on TomCasConflictException catch (e) {
        expect(e.expectedHead, first);
        expect(e.actualHead, second);
      }
      expect(utf8.decode(await storage.readBytes(loc)), 'second');
      await expectLater(
        storage.commit(
          loc,
          TomChangeset.singleFile(_b('x')),
          expectedHead: null,
        ),
        throwsA(isA<TomCasConflictException>()),
        reason: 'creating over an existing container is a stale head too',
      );
    });

    test('$id-C4: a folder container takes writes and deletes, and its '
        'bundle and listing show the result', () async {
      final loc = locator('bundle.webwork');
      final h1 = await storage.commit(
        loc,
        TomChangeset(
          writes: {
            'webwork.yaml': _b('manifest'),
            'a.webwork.yaml': _b('a'),
            'sub/b.webwork.yaml': _b('b'),
          },
        ),
        expectedHead: null,
      );
      final h2 = await storage.commit(
        loc,
        TomChangeset(
          writes: {'c.webwork.yaml': _b('c')},
          deletes: {'a.webwork.yaml'},
        ),
        expectedHead: h1,
      );
      expect(h2, isNot(h1));
      expect(await storage.headOf(loc), h2);
      final bundle = await storage.readBundle(loc);
      expect(await bundle.listFiles(), [
        'c.webwork.yaml',
        'sub/b.webwork.yaml',
        'webwork.yaml',
      ]);
      expect(await bundle.readString('sub/b.webwork.yaml'), 'b');
      expect(await bundle.exists('a.webwork.yaml'), isFalse);
      final files = [
        for (final e in await storage.list(loc))
          if (e.isFile) e.path,
      ]..sort();
      expect(files, ['c.webwork.yaml', 'sub/b.webwork.yaml', 'webwork.yaml']);
    });

    test('$id-C5: an empty changeset against the current head changes '
        'nothing and answers that head', () async {
      final loc = locator('empty.kdbx');
      final head = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('stay')),
        expectedHead: null,
      );
      expect(
        await storage.commit(loc, TomChangeset(), expectedHead: head),
        head,
      );
      expect(await storage.headOf(loc), head);
    });

    test('$id-C6: a deleted container has no head again', () async {
      final loc = locator('gone.webwork');
      await storage.commit(
        loc,
        TomChangeset(writes: {'x.yaml': _b('x')}),
        expectedHead: null,
      );
      await storage.delete(loc);
      expect(await storage.headOf(loc), isNull);
      await expectLater(
        storage.readBundle(loc),
        throwsA(isA<TomContainerNotFoundException>()),
      );
      await storage.delete(loc);
    });

    test('$id-C7: two containers are independent: a commit to one does not '
        'move the other\'s head', () async {
      final a = locator('a.kdbx');
      final b = locator('b.kdbx');
      final ha = await storage.commit(
        a,
        TomChangeset.singleFile(_b('a')),
        expectedHead: null,
      );
      await storage.commit(
        b,
        TomChangeset.singleFile(_b('b')),
        expectedHead: null,
      );
      expect(await storage.headOf(a), ha);
      await storage.commit(
        a,
        TomChangeset.singleFile(_b('a2')),
        expectedHead: ha,
      );
    });

    if (secondDevice != null) {
      test('$id-C8: another device sees a commit, and loses the race when it '
          'commits against the head it read before', () async {
        final other = await secondDevice();
        addTearDown(other.close);
        final loc = locator('shared.kdbx');
        final h1 = await storage.commit(
          loc,
          TomChangeset.singleFile(_b('one')),
          expectedHead: null,
        );
        expect(await other.headOf(loc), h1);
        expect(utf8.decode(await other.readBytes(loc)), 'one');
        final h2 = await storage.commit(
          loc,
          TomChangeset.singleFile(_b('two')),
          expectedHead: h1,
        );
        await expectLater(
          other.commit(
            loc,
            TomChangeset.singleFile(_b('late')),
            expectedHead: h1,
          ),
          throwsA(
            isA<TomCasConflictException>().having(
              (e) => e.actualHead,
              'actualHead',
              h2,
            ),
          ),
        );
      });
    }
  });
}
