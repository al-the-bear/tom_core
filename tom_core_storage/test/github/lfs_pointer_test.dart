/// An LFS pointer read back must say so, not be handed over as a 130-byte
/// document.
///
/// The write direction is closed by measurement: Git-LFS is a **client-side**
/// clean/smudge filter, the git-data REST API never consults
/// `.gitattributes`, and a 1 MiB write to an LFS-tracked path stored 1 MiB of
/// raw bytes. So these backends cannot opt into LFS and do not want to.
///
/// The read direction is the residual, and it is an ordinary user path: the
/// repository is a normal git repository that other tools push to. A client
/// that *did* have the filter installed leaves ~130 bytes of pointer where the
/// content should be. Delivered as content that is a blank image, or a YAML
/// parse error whose message points nowhere near the cause.
///
/// The suite asserts the refusal on **both** backends — the shape of the bytes
/// is the same question wherever they came from — and, in C52-04/C52-05, that
/// the guard is the pointer *shape* rather than the byte count, so a short
/// document is not refused for being short.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/github.dart';
import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_github_api/tom_github_api.dart';

import 'package:tom_github_api/testing.dart';

import '../support/scratch.dart';

const oid =
    'sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393';

/// Exactly what git-lfs leaves in the tree.
const pointer =
    'version https://git-lfs.github.com/spec/v1\n'
    'oid $oid\n'
    'size 4194304\n';

Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

/// A **valid** pointer padded to exactly [target] bytes with an extension key.
///
/// The padding is well-formed on purpose: the strict parser accepts it, so the
/// only thing that can decide against it is the size cutoff. That is what makes
/// C52-04 able to fail when the cutoff is removed — a padding the parser
/// rejected would pass either way and prove nothing.
String paddedPointer(int target) {
  const head = 'version https://git-lfs.github.com/spec/v1\n';
  const tail = 'oid $oid\nsize 7\n';
  const prefix = 'ext-0-pad ';
  final filler = target - head.length - tail.length - prefix.length - 1;
  return '$head$prefix${'a' * filler}\n$tail';
}

({FakeGitHubServer server, TomGitHubStorage storage}) gitHub() {
  final server = FakeGitHubServer();
  server.repo('al-the-bear/docs');
  final storage = TomGitHubStorage.withClient(
    GitHubApiClient(
      token: 'test-token',
      httpClient: server.client,
      baseUrl: FakeGitHubServer.baseUrl,
      minMutativeInterval: Duration.zero,
    ),
  );
  return (server: server, storage: storage);
}

void main() {
  group('STORAGE-LFS a Git-LFS pointer is refused, not delivered', () {
    test(
      'STORAGE-LFS-01: the GitHub backend refuses a single-file container that is a '
      'pointer, naming the path and the real size [0918]',
      () async {
        final h = gitHub();
        addTearDown(h.storage.close);
        h.server.commitFiles('al-the-bear/docs', {'a.webwork.kdbx': pointer});

        await expectLater(
          h.storage.readBytes('github:al-the-bear/docs/a.webwork.kdbx'),
          throwsA(
            isA<TomLfsObjectException>()
                .having((e) => e.path, 'path', 'a.webwork.kdbx')
                .having((e) => e.pointer.size, 'real size', 4194304)
                .having((e) => e.pointer.oid, 'oid', oid)
                .having((e) => e.message, 'message', contains('Git LFS')),
          ),
        );
      },
    );

    test(
      'STORAGE-LFS-02: a bundle member that is a pointer aborts the read and names '
      'the member, not the bundle [0918]',
      () async {
        final h = gitHub();
        addTearDown(h.storage.close);
        h.server.commitFiles('al-the-bear/docs', {
          'mydoc.webwork/webwork.yaml': 'version: "1.0"\nroot: abc\n',
          'mydoc.webwork/assets/2b1c4f.png': pointer,
        });

        // Opening the bundle is lazy, so a pointer stored anywhere in it — a
        // `.history/` snapshot included — no longer fails the open. The refusal
        // fires on the member that is actually a pointer, and on nothing else.
        final medium = await h.storage.readBundle(
          'github:al-the-bear/docs/mydoc.webwork',
        );
        expect(
          await medium.readString('webwork.yaml'),
          contains('root: abc'),
          reason: 'a member that is not a pointer reads normally',
        );

        await expectLater(
          () => medium.readBytes('assets/2b1c4f.png'),
          throwsA(
            isA<TomLfsObjectException>().having(
              (e) => e.path,
              'path',
              'assets/2b1c4f.png',
            ),
          ),
          reason:
              'bundle-relative, the same key the medium would have held — '
              'and byte-identical to what C52-06 reports off a local folder, so '
              'the path a user is shown does not depend on the transport',
        );
      },
    );

    test(
      'STORAGE-LFS-03: an ordinary container of the same length is delivered [0918]',
      () async {
        final h = gitHub();
        addTearDown(h.storage.close);
        // Same byte length as the pointer, so a guard that keyed on "small"
        // rather than on the pointer's shape would fail this.
        final content = 'x' * pointer.length;
        h.server.commitFiles('al-the-bear/docs', {'a.webwork.kdbx': content});

        final read = await h.storage.readBytes(
          'github:al-the-bear/docs/a.webwork.kdbx',
        );
        expect(utf8.decode(read), content);
        expect(
          content.length,
          pointer.length,
          reason: 'the fixture is the guard',
        );
      },
    );

    test(
      'STORAGE-LFS-04: the size cutoff decides before the parser does, at exactly '
      "git-lfs's own 1024 bytes [0918]",
      () {
        // Both of these parse perfectly as pointers. The only difference is one
        // byte of padding, so this pins the cutoff itself rather than the shape
        // — and it is the boundary, so an off-by-one is visible too.
        final atLimit = paddedPointer(TomLfsPointer.maxPointerBytes);
        final overLimit = paddedPointer(TomLfsPointer.maxPointerBytes + 1);
        expect(atLimit.length, 1024);
        expect(overLimit.length, 1025);

        expect(TomLfsPointer.tryParse(bytesOf(atLimit)), isNotNull);
        expect(
          TomLfsPointer.tryParse(bytesOf(overLimit)),
          isNull,
          reason:
              'past the cutoff the bytes are content by definition — git '
              'lfs itself stops looking there, and the bound is what keeps the '
              'check from decoding a 40 MiB asset on every read',
        );
      },
    );

    test('STORAGE-LFS-04b: content that merely begins with the version line is '
        'delivered [0918]', () async {
      final h = gitHub();
      addTearDown(h.storage.close);
      // A section about LFS, quoting the format. The strict parse is what
      // saves it: the trailing prose is not a `key value` line.
      final content = '$pointer\nand that is what a pointer looks like.\n';
      h.server.commitFiles('al-the-bear/docs', {'a.webwork.kdbx': content});

      final read = await h.storage.readBytes(
        'github:al-the-bear/docs/a.webwork.kdbx',
      );
      expect(utf8.decode(read), content);
    });

    test(
      'STORAGE-LFS-05: the local filesystem backend refuses the same bytes, with its '
      'own remedy [0918]',
      () async {
        final dir = scratchDirectory('github').createTempSync('local');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/a.webwork.kdbx')
          ..writeAsStringSync(pointer);

        await expectLater(
          const TomLocalFileSystemStorage().readBytes(file.path),
          throwsA(
            isA<TomLfsObjectException>()
                .having((e) => e.path, 'path', 'a.webwork.kdbx')
                .having((e) => e.message, 'remedy', contains('git lfs pull')),
          ),
        );
      },
    );

    test(
      'STORAGE-LFS-06: and refuses a bundle member, naming it [0918]',
      () async {
        final dir = scratchDirectory('github').createTempSync('bundle');
        addTearDown(() => dir.deleteSync(recursive: true));
        File('${dir.path}/webwork.yaml').writeAsStringSync('version: "1.0"\n');
        File('${dir.path}/assets/2b1c4f.png')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(pointer);

        final medium = await const TomLocalFileSystemStorage().readBundle(
          dir.path,
        );
        expect(
          await medium.readString('webwork.yaml'),
          contains('version'),
          reason: 'the clean member is unaffected by the pointer beside it',
        );

        await expectLater(
          () => medium.readBytes('assets/2b1c4f.png'),
          throwsA(
            isA<TomLfsObjectException>().having(
              (e) => e.path,
              'path',
              'assets/2b1c4f.png',
            ),
          ),
        );
      },
    );

    test(
      'STORAGE-LFS-07: the two backends diagnose identically and remedy differently '
      '[0918]',
      () async {
        final h = gitHub();
        addTearDown(h.storage.close);
        h.server.commitFiles('al-the-bear/docs', {'a.webwork.kdbx': pointer});
        final dir = scratchDirectory('github').createTempSync('pair');
        addTearDown(() => dir.deleteSync(recursive: true));
        File('${dir.path}/a.webwork.kdbx').writeAsStringSync(pointer);

        final remote = await _refusalOf(
          () => h.storage.readBytes('github:al-the-bear/docs/a.webwork.kdbx'),
        );
        final local = await _refusalOf(
          () => const TomLocalFileSystemStorage().readBytes(
            '${dir.path}/a.webwork.kdbx',
          ),
        );

        expect(
          remote.pointer.oid,
          local.pointer.oid,
          reason: 'one parser, so the diagnosis cannot differ by transport',
        );
        expect(
          remote.message,
          isNot(local.message),
          reason:
              'what the reader can do about it is exactly what differs — '
              'the REST API cannot resolve a pointer at all, while a working '
              'tree only needs smudging',
        );
      },
    );

    test(
      'STORAGE-LFS-08: it is a TomStorageException, so the sync loop sees it '
      '[0918]',
      () {
        final error = TomLfsObjectException(
          'github:al-the-bear/docs/a.webwork.kdbx',
          path: 'a.webwork.kdbx',
          pointer: const TomLfsPointer(oid: oid, size: 1),
          remedy: 'x',
        );
        // The reason TomKeyRequiredException gives for living beside the
        // transport outcomes: a read outcome the loop cannot name is one that
        // escapes into an unhandled async error on a timer tick.
        expect(error, isA<TomStorageException>());
      },
    );
  });

  group('STORAGE-LFS the parser is strict', () {
    test('STORAGE-LFS-09: the canonical pointer parses [0918]', () {
      final parsed = TomLfsPointer.tryParse(bytesOf(pointer));
      expect(parsed, isNotNull);
      expect(parsed!.oid, oid);
      expect(parsed.size, 4194304);
    });

    test('STORAGE-LFS-10: the two legacy version lines parse too [0918]', () {
      for (final version in const [
        'version https://hawser.github.com/spec/v1',
        'version https://git-media.io/v/2',
      ]) {
        final text = '$version\noid $oid\nsize 7\n';
        expect(
          TomLfsPointer.tryParse(bytesOf(text)),
          isNotNull,
          reason:
              'a pointer written by an old client is still a pointer; '
              'not recognising it delivers it as content',
        );
      }
    });

    test('STORAGE-LFS-11: an extension key does not defeat it [0918]', () {
      final text =
          'version https://git-lfs.github.com/spec/v1\n'
          'ext-0-shortname sha256:aaaa\n'
          'oid $oid\n'
          'size 7\n';
      expect(TomLfsPointer.tryParse(bytesOf(text)), isNotNull);
    });

    test('STORAGE-LFS-12: content is not a pointer [0918]', () {
      final cases = <String, String>{
        'no version line': 'oid $oid\nsize 7\n',
        'wrong version url':
            'version https://example.com/spec/v1\noid $oid\nsize 7\n',
        'no size': 'version https://git-lfs.github.com/spec/v1\noid $oid\n',
        'no oid': 'version https://git-lfs.github.com/spec/v1\nsize 7\n',
        'uppercase oid hex':
            'version https://git-lfs.github.com/spec/v1\n'
            'oid sha256:${'A' * 64}\nsize 7\n',
        'short oid':
            'version https://git-lfs.github.com/spec/v1\n'
            'oid sha256:abc\nsize 7\n',
        'duplicate oid':
            'version https://git-lfs.github.com/spec/v1\n'
            'oid $oid\noid $oid\nsize 7\n',
        'junk line':
            'version https://git-lfs.github.com/spec/v1\n'
            'oid $oid\n!!!\nsize 7\n',
        'a YAML section': 'id: 7f3c9e21\nheadline: Intro\ntype: text\n',
      };
      for (final entry in cases.entries) {
        expect(
          TomLfsPointer.tryParse(bytesOf(entry.value)),
          isNull,
          reason: entry.key,
        );
      }
    });

    test(
      'STORAGE-LFS-13: binary bytes are not a pointer and do not throw [0918]',
      () {
        final binary = Uint8List.fromList([0xFF, 0xFE, 0x80, 0x00, 0x41]);
        expect(
          TomLfsPointer.tryParse(binary),
          isNull,
          reason:
              'an undecodable blob is content — the parser must answer, '
              'not rethrow the decode',
        );
      },
    );
  });
}

Future<TomLfsObjectException> _refusalOf(
  Future<Object?> Function() read,
) async {
  try {
    await read();
  } on TomLfsObjectException catch (error) {
    return error;
  }
  fail('expected a TomLfsObjectException');
}
