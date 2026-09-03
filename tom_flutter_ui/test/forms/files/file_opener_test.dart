/// `file_opener.dart` is the forms module's only conditional import, and it
/// guards the path a real application actually takes: every mainstream picker
/// plugin hands back a *path*, not a stream, so `openFilePath` is what turns a
/// user's choice into something the upload can read.
///
/// It was untested on both branches. That is the worst shape for a conditional
/// import to be in, because the two halves are compiled on different platforms
/// and neither one's failure is visible from the other. A regression here does
/// not fail a build in this package — it surfaces downstream as "uploads are
/// empty on mobile".
///
/// So this suite exercises all three things separately:
///
///   * **the branch this platform compiles**, against a file that really
///     exists on disk — the only way to prove `openFilePath` reads anything;
///   * **the web half**, by importing `file_opener_stub.dart` by name. A VM
///     test run would otherwise never compile that file at all, and "returns
///     null" is a contract the caller depends on, not a placeholder;
///   * **that the two halves still match**, since a conditional export whose
///     branches drift apart compiles perfectly on the platform you happen to
///     be testing on.
///
/// The three `file_opener*` files are deliberately not exported from the
/// barrel — this is internal plumbing — so the behavioural assertions go
/// through `TomFilePickers.toFileRef`, which is both the only call site and
/// the public entry a picker adaptor uses.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/files/file_opener.dart' as resolved;
import 'package:tom_flutter_ui/src/forms/files/file_opener_io.dart' as io_half;
import 'package:tom_flutter_ui/src/forms/files/file_opener_stub.dart'
    as web_half;
import 'package:tom_flutter_ui/src/forms/files/tom_file_picker_registry.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// The shape both halves of the conditional export must keep.
typedef _Opener = Stream<List<int>> Function()? Function(String path);

/// The shape both halves of the size probe must keep.
typedef _Sizer = int? Function(String path);

/// Drains a re-openable source the way the transfer client does.
Future<List<int>> _drain(Stream<List<int>> Function() open) =>
    open().expand((chunk) => chunk).toList();

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('tom_file_opener_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Writes [bytes] to a file inside the temp directory and returns its path.
  String write(String name, List<int> bytes) {
    final file = File('${temp.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(bytes);
    return file.path;
  }

  /// A path inside the temp directory with nothing written to it.
  String absent(String name) => '${temp.path}${Platform.pathSeparator}$name';

  // -------------------------------------------------------------------------
  // The branch this platform compiles
  // -------------------------------------------------------------------------

  group('on a platform with a filesystem', () {
    test('openFilePath hands back a factory that reads the file', () async {
      final path = write('payload.bin', const [1, 2, 3, 4, 5]);

      final open = resolved.openFilePath(path);

      expect(open, isNotNull);
      expect(await _drain(open!), [1, 2, 3, 4, 5]);
    });

    test('the factory re-reads, so a failed upload can be retried', () async {
      // The reason the signature is `Function()?` and not `Stream?`: a stream
      // is consumed once. If this ever degrades to a captured single-use
      // stream the first upload still succeeds and only the retry is empty,
      // which is precisely the bug that would reach production.
      final path = write('retry.bin', const [7, 8, 9]);

      final open = resolved.openFilePath(path)!;

      expect(await _drain(open), [7, 8, 9]);
      expect(await _drain(open), [7, 8, 9]);
    });

    test(
      'a path with nothing at it yields null, not an empty stream',
      () async {
        // Null is the caller's signal to fall back to the picker's bytes. An
        // empty stream would look like a successful upload of nothing.
        expect(resolved.openFilePath(absent('gone.bin')), isNull);
      },
    );

    test(
      'an empty file still opens — it is a file, just a short one',
      () async {
        final path = write('empty.bin', const []);

        final open = resolved.openFilePath(path);

        expect(open, isNotNull);
        expect(await _drain(open!), isEmpty);
      },
    );

    test('fileLengthAt measures the file without reading it', () {
      final path = write('sized.bin', List<int>.filled(1234, 0));

      expect(resolved.fileLengthAt(path), 1234);
    });

    test(
      'fileLengthAt returns null rather than throwing on a missing path',
      () {
        expect(resolved.fileLengthAt(absent('never-written.bin')), isNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // The other branch
  // -------------------------------------------------------------------------

  group('on the web, where there are no paths', () {
    test('openFilePath is null even for a path that exists here', () {
      // Named explicitly rather than assumed: the point of the stub is that it
      // declines *unconditionally*, so handing it a path that genuinely
      // resolves on this machine is the assertion worth making.
      final path = write('real.bin', const [1]);

      expect(web_half.openFilePath(path), isNull);
    });

    test('fileLengthAt is null too, so the size falls to the picker', () {
      final path = write('real.bin', const [1, 2, 3]);

      expect(web_half.fileLengthAt(path), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // The export contract
  // -------------------------------------------------------------------------

  group('the two halves stay interchangeable', () {
    // These assertions are the *assignments*: a signature that drifted on one
    // side would stop compiling here. Without them the drift is invisible
    // until someone builds for the platform that was not being tested, since
    // only one half is compiled at a time.
    test('both export the same openFilePath', () {
      const _Opener web = web_half.openFilePath;
      const _Opener io = io_half.openFilePath;
      const _Opener chosen = resolved.openFilePath;

      expect([web, io, chosen], everyElement(isNotNull));
    });

    test('both export the same fileLengthAt', () {
      const _Sizer web = web_half.fileLengthAt;
      const _Sizer io = io_half.fileLengthAt;
      const _Sizer chosen = resolved.fileLengthAt;

      expect([web, io, chosen], everyElement(isNotNull));
    });

    test('the resolved export is this platform\'s half, not the other one', () {
      // Guards the direction of the `if (dart.library.io)` condition. Swapped,
      // every test above that reads a file would fail — but on the web nothing
      // would, so the mistake is only catchable from the side that has a
      // filesystem.
      expect(resolved.openFilePath, same(io_half.openFilePath));
      expect(resolved.openFilePath, isNot(same(web_half.openFilePath)));
    });
  });

  // -------------------------------------------------------------------------
  // What the caller sees
  // -------------------------------------------------------------------------

  group('a picked file that carries only a path', () {
    test('streams the file rather than reading it into the ref', () async {
      final path = write('doc.txt', const [104, 105]);

      final ref = TomFilePickers.toFileRef(
        TomPickedFile(name: 'doc.txt', path: path),
      );

      expect(ref.bytes, isNull, reason: 'the point is not to hold the file');
      expect(ref.source, isNotNull);
      expect(await _drain(ref.toSource().open), [104, 105]);
    });

    test(
      'takes its size from the filesystem when the picker gave none',
      () async {
        final path = write('sized.bin', List<int>.filled(64, 1));

        final ref = TomFilePickers.toFileRef(
          TomPickedFile(name: 'sized.bin', path: path),
        );

        expect(ref.sizeBytes, 64);
        expect(ref.source!.byteCount, 64);
        expect(ref.source!.hasKnownSize, isTrue);
      },
    );

    test('keeps the size the picker reported over the one on disk', () {
      // The picker is the more authoritative source: it may be describing a
      // file it is still writing, and re-stating what `stat` says would be a
      // silent override of the adaptor.
      final path = write('sized.bin', List<int>.filled(64, 1));

      final ref = TomFilePickers.toFileRef(
        TomPickedFile(name: 'sized.bin', sizeBytes: 99, path: path),
      );

      expect(ref.sizeBytes, 99);
    });

    test('can be re-opened, so the upload is retryable end to end', () async {
      final path = write('retry.txt', const [1, 2, 3]);

      final source = TomFilePickers.toFileRef(
        TomPickedFile(name: 'retry.txt', path: path),
      ).toSource();

      expect(await _drain(source.open), [1, 2, 3]);
      expect(await _drain(source.open), [1, 2, 3]);
    });

    test('guesses its media type from the name, as any other pick does', () {
      final path = write('photo.png', const [1]);

      final ref = TomFilePickers.toFileRef(
        TomPickedFile(name: 'photo.png', path: path),
      );

      expect(ref.mimeType, 'image/png');
      expect(ref.source!.mediaType, 'image/png');
    });
  });

  group('when the path leads nowhere', () {
    test('the picker\'s bytes are used instead', () async {
      // The web takes this branch for every pick; a filesystem platform takes
      // it when the picker handed over a stale path.
      final ref = TomFilePickers.toFileRef(
        TomPickedFile(
          name: 'stale.bin',
          path: absent('stale.bin'),
          bytes: Uint8List.fromList([5, 6]),
        ),
      );

      expect(ref.source, isNull);
      expect(ref.bytes, [5, 6]);
      expect(ref.sizeBytes, 2);
    });

    test(
      'and there are no bytes either, the ref is named but content-less',
      () {
        final ref = TomFilePickers.toFileRef(
          TomPickedFile(name: 'nothing.bin', path: absent('nothing.bin')),
        );

        expect(ref.hasLocalContent, isFalse);
        expect(ref.name, 'nothing.bin');
        expect(ref.sizeBytes, 0);
      },
    );
  });

  group('a picked file that carries both a stream and a path', () {
    test('uses the stream and never opens the path', () async {
      // `open` wins outright. Proven by giving the path different contents:
      // if the path were consulted the assertion below reads 9s.
      final path = write('both.bin', const [9, 9, 9]);

      final ref = TomFilePickers.toFileRef(
        TomPickedFile(
          name: 'both.bin',
          path: path,
          open: () => Stream<List<int>>.value(const [1, 1, 1]),
        ),
      );

      expect(await _drain(ref.toSource().open), [1, 1, 1]);
    });

    test('but still measures the path when the picker gave no size', () {
      // The two decisions are independent: the opener comes from `open`, the
      // size still comes from `fileLengthAt`. Collapsing them into one branch
      // would leave a streamed pick with an indeterminate progress bar it did
      // not need to have.
      final path = write('both.bin', List<int>.filled(48, 9));

      final ref = TomFilePickers.toFileRef(
        TomPickedFile(
          name: 'both.bin',
          path: path,
          open: () => Stream<List<int>>.value(const [1]),
        ),
      );

      expect(ref.sizeBytes, 48);
    });
  });

  // -------------------------------------------------------------------------
  // Through the registry, which is how an application reaches all of this
  // -------------------------------------------------------------------------

  group('through the registered picker', () {
    tearDown(TomFilePickerRegistry.clear);

    test('a path-returning adaptor produces a readable FileRef', () async {
      // What every mainstream picker plugin actually does on desktop and
      // mobile — and, until now, the one journey nothing exercised.
      final path = write('chosen.txt', const [42, 43]);
      TomFilePickerRegistry.register(
        (_) async => [TomPickedFile(name: 'chosen.txt', path: path)],
      );

      final ref = await TomFilePickerRegistry.pick(const TomFilePickRequest());

      expect(ref!.name, 'chosen.txt');
      expect(ref.sizeBytes, 2);
      expect(await _drain(ref.toSource().open), [42, 43]);
    });
  });
}
