/// The in-memory remote behind `testing.dart`: it guards a commit by its head
/// as a real backend does, and each failure switch fails only its own kind of
/// request.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/testing.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

const _doc = 'mem:/library/handbook';

TomChangeset _write(String path, String text) =>
    TomChangeset(writes: {path: Uint8List.fromList(utf8.encode(text))});

void main() {
  group('STORAGE-MEMORY the in-memory remote', () {
    test(
      'STORAGE-MEMORY-1: a remote with nothing committed has no head',
      () async {
        final remote = TomMemoryRemote();
        expect(remote.headOf(_doc), isNull);
        expect(await TomMemoryStorage(remote).headOf(_doc), isNull);
      },
    );

    test('STORAGE-MEMORY-2: a commit against the right head lands, and one '
        'against a stale head is refused', () async {
      final remote = TomMemoryRemote();
      final storage = TomMemoryStorage(remote);
      final first = await storage.commit(_doc, _write('a.yaml', 'one'));
      expect(remote.textSnapshot(_doc), {'a.yaml': 'one'});
      await storage.commit(_doc, _write('a.yaml', 'two'), expectedHead: first);
      await expectLater(
        storage.commit(_doc, _write('a.yaml', 'three'), expectedHead: first),
        throwsA(isA<TomCasConflictException>()),
      );
      expect(remote.textSnapshot(_doc), {'a.yaml': 'two'});
      expect(remote.commits, hasLength(2));
    });

    test('STORAGE-MEMORY-3: two devices share the remote and not their '
        'reachability', () async {
      final remote = TomMemoryRemote();
      final a = TomMemoryStorage(remote);
      final b = TomMemoryStorage(remote);
      final head = await a.commit(_doc, _write('a.yaml', 'one'));
      a.goOffline();
      await expectLater(
        a.commit(_doc, _write('a.yaml', 'x'), expectedHead: head),
        throwsA(isA<TomUnreachableException>()),
      );
      expect(await a.headOf(_doc), head, reason: 'reads still answer offline');
      expect(await b.headOf(_doc), head);
      await b.commit(_doc, _write('a.yaml', 'two'), expectedHead: head);
      expect(remote.textSnapshot(_doc), {'a.yaml': 'two'});
    });

    test('STORAGE-MEMORY-4: a stale replica answers null, which the truth '
        'does not', () async {
      final remote = TomMemoryRemote();
      final storage = TomMemoryStorage(remote);
      final head = await storage.commit(_doc, _write('a.yaml', 'one'));
      storage.staleHead = const TomStaleHead(null);
      expect(await storage.headOf(_doc), isNull);
      storage.staleHead = null;
      expect(await storage.headOf(_doc), head);
    });

    test('STORAGE-MEMORY-5: quota and a locked container are refused with '
        'their own exceptions', () async {
      final remote = TomMemoryRemote();
      final storage = TomMemoryStorage(remote);
      await storage.commit(_doc, _write('a.yaml', 'one'));
      storage.keyRequiredReason = 'locked';
      await expectLater(
        storage.readBundle(_doc),
        throwsA(isA<TomKeyRequiredException>()),
      );
      storage.keyRequiredReason = null;
      storage.rateLimitedUntil = DateTime.utc(2030);
      await expectLater(
        storage.headOf(_doc),
        throwsA(isA<TomRateLimitException>()),
      );
    });
  });
}
