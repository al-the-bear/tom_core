/// `TomBundleMedium` carries bytes, and text is the convenience.
///
/// A medium whose primitives were text, a ZIP codec that went through `utf8`,
/// or a `readBundle` that decoded on the way in would leave nowhere for a PNG
/// to live beside the text files of a container.
///
/// Every case here runs one payload of **incompressible, deliberately
/// not-UTF-8 bytes** through a medium and compares byte-for-byte. That is what
/// makes the suite a guard rather than a description: under the old
/// `utf8.decode` each of these either throws a `FormatException`, silently
/// drops the file, or (with `allowMalformed: true`) substitutes U+FFFD and
/// comes back a different length. C51-01 pins that the payload really is
/// undecodable, so none of the others can pass vacuously.
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

/// 4 KiB of deterministic pseudorandom bytes.
///
/// Deterministic so a failure is reproducible, pseudorandom so the zip path is
/// exercised against something deflate cannot collapse to nothing, and seeded
/// through an LCG whose full byte range guarantees lone continuation bytes and
/// `0xFF` — the two things UTF-8 has no reading for.
Uint8List incompressible() {
  var state = 0x2545F491;
  final out = Uint8List(4096);
  for (var i = 0; i < out.length; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    out[i] = (state >> 16) & 0xFF;
  }
  return out;
}

const assetPath = 'assets/2b1c4f.png';
const sectionPath = 'intro--7f3c9e.webwork.yaml';
const sectionText = 'id: 7f3c9e21\nheadline: Intro — a dash and an em-dash\n';

void main() async {
  final payload = incompressible();

  group('STORAGE-BYTES bundle media carry bytes', () {
    test(
      'STORAGE-BYTES-01: the payload is not decodable as UTF-8, so every later case '
      'would have failed under the old text medium [0918]',
      () {
        expect(
          () => utf8.decode(payload),
          throwsFormatException,
          reason:
              'a payload that happened to be valid UTF-8 would make the '
              'whole suite pass against the code it is guarding',
        );
        expect(
          utf8.decode(payload, allowMalformed: true).codeUnits.length,
          isNot(payload.length),
          reason:
              'and a lenient decode does not round-trip either — it '
              'substitutes, which is a different file that looks like a file',
        );
      },
    );

    test(
      'STORAGE-BYTES-02: a memory medium round-trips bytes [0918]',
      () async {
        final medium = TomMemoryBundleMedium();
        await medium.writeBytes(assetPath, payload);
        expect(await medium.readBytes(assetPath), payload);
      },
    );

    test('STORAGE-BYTES-03: the zip codec round-trips bytes [0918]', () async {
      final source = TomMemoryBundleMedium();
      await source.writeBytes(assetPath, payload);
      await source.writeString(sectionPath, sectionText);

      final restored = TomMemoryBundleMedium.fromZip(source.toZip());

      expect(await restored.readBytes(assetPath), payload);
      expect(
        await restored.readString(sectionPath),
        sectionText,
        reason:
            'nothing about the plaintext format changes: a section file '
            'is still written and read as a string',
      );
    });

    test(
      'STORAGE-BYTES-04: a directory medium round-trips bytes [0918]',
      () async {
        final dir = scratchDirectory('github').createTempSync('dir');
        addTearDown(() => dir.deleteSync(recursive: true));

        final medium = TomDirectoryBundleMedium(dir);
        await medium.writeBytes(assetPath, payload);

        expect(
          File('${dir.path}/$assetPath').readAsBytesSync(),
          payload,
          reason: 'what the medium wrote is what is on disk',
        );
        expect(
          await TomDirectoryBundleMedium(dir).readBytes(assetPath),
          payload,
          reason: 'and a medium that did not write it reads the same bytes',
        );
      },
    );

    test(
      'STORAGE-BYTES-05: the local filesystem backend reads a binary member back, '
      'rather than skipping it [0918]',
      () async {
        final dir = scratchDirectory('github').createTempSync('local');
        addTearDown(() => dir.deleteSync(recursive: true));
        File('${dir.path}/$assetPath')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(payload);
        File('${dir.path}/$sectionPath').writeAsStringSync(sectionText);

        final medium = await const TomLocalFileSystemStorage().readBundle(
          dir.path,
        );

        expect(
          await medium.listFiles(),
          contains(assetPath),
          reason:
              'the old reader skipped what it could not decode, so an '
              'asset was dropped on the way in and the drop was silent',
        );
        expect(await medium.readBytes(assetPath), payload);
        expect(await medium.readString(sectionPath), sectionText);
      },
    );

    test(
      'STORAGE-BYTES-06: the GitHub backend round-trips bytes [0918]',
      () async {
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
        addTearDown(storage.close);

        const locator = 'github:al-the-bear/docs/mydoc.webwork';
        await storage.commit(
          locator,
          TomChangeset(
            writes: {
              assetPath: payload,
              sectionPath: Uint8List.fromList(utf8.encode(sectionText)),
            },
            deletes: const {},
          ),
          expectedHead: null,
        );

        final medium = await storage.readBundle(locator);

        expect(
          await medium.readBytes(assetPath),
          payload,
          reason:
              'a blob goes up and comes back down as the bytes it is — '
              '`readBundle` no longer decodes',
        );
        expect(await medium.readString(sectionPath), sectionText);
      },
    );

    test('STORAGE-BYTES-07: `move` is byte-preserving, so the snapshot that '
        'retires an asset is the asset [0918]', () async {
      final medium = TomMemoryBundleMedium();
      await medium.writeBytes(assetPath, payload);

      await medium.move(assetPath, '.history/.assets/2b1c4f.png');

      expect(await medium.exists(assetPath), isFalse);
      expect(await medium.readBytes('.history/.assets/2b1c4f.png'), payload);
    });

    test(
      'STORAGE-BYTES-08: the recorder carries the written bytes into the changeset '
      'verbatim [0918]',
      () async {
        final recorder = TomRecordingBundleMedium(TomMemoryBundleMedium());
        await recorder.writeBytes(assetPath, payload);
        await recorder.writeString(sectionPath, sectionText);

        final changeset = recorder.changeset;

        expect(
          changeset.writes[assetPath],
          payload,
          reason:
              'this is the unit a TomStorage commits — a re-encode '
              'here would corrupt the asset between the save and the remote',
        );
        expect(changeset.writes[sectionPath], utf8.encode(sectionText));
      },
    );

    test(
      'STORAGE-BYTES-09: a string written through the convenience is utf8 on every '
      'medium [0918]',
      () async {
        final dir = scratchDirectory('github').createTempSync('utf8');
        addTearDown(() => dir.deleteSync(recursive: true));

        final expected = Uint8List.fromList(utf8.encode(sectionText));
        for (final medium in <TomBundleMedium>[
          TomMemoryBundleMedium(),
          TomDirectoryBundleMedium(dir),
          TomRecordingBundleMedium(TomMemoryBundleMedium()),
        ]) {
          await medium.writeString(sectionPath, sectionText);
          expect(
            await medium.readBytes(sectionPath),
            expected,
            reason:
                '${medium.runtimeType} must encode a section file the '
                'same way every other medium does — the pair is defined once '
                'on the base class so it cannot drift',
          );
        }
      },
    );

    test(
      'STORAGE-BYTES-10: `fromText` and the byte map build the same bundle [0918]',
      () {
        final fromText = TomMemoryBundleMedium.fromText({
          sectionPath: sectionText,
        });
        final fromBytes = TomMemoryBundleMedium({
          sectionPath: Uint8List.fromList(utf8.encode(sectionText)),
        });
        expect(fromText.files, fromBytes.files);
      },
    );
  });
}
