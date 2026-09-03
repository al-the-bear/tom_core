import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FileRef _ref(String name, List<int> bytes) => FileRef(
  name: name,
  sizeBytes: bytes.length,
  bytes: Uint8List.fromList(bytes),
);

/// A reference whose content arrives in [chunks] pieces of [chunkSize] bytes.
FileRef _chunkedRef(
  String name, {
  required int chunks,
  required int chunkSize,
}) {
  final total = chunks * chunkSize;
  return FileRef(
    name: name,
    sizeBytes: total,
    source: TomFileSource.stream(
      fileName: name,
      byteCount: total,
      open: () => Stream.fromIterable(
        List.generate(chunks, (_) => List.filled(chunkSize, 1)),
      ),
    ),
  );
}

/// A client that fails the next [failures] attempts before delegating.
///
/// Lets a test drive the failed → retry → succeeded path without a server.
class _FlakyClient extends TomFileTransferClient {
  _FlakyClient(this.inner);

  final TomMemoryFileTransferClient inner;

  /// Attempts still to be rejected; a test may raise it before the first call.
  int failures = 1;
  int uploadAttempts = 0;

  @override
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async {
    uploadAttempts++;
    if (failures > 0) {
      failures--;
      throw TomFileTransferException(
        'file_transfer.rejected',
        'The server rejected the transfer.',
        parameters: {'slot': slot},
      );
    }
    return inner.upload(
      slot: slot,
      source: source,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  @override
  Stream<List<int>> download(
    String slot, {
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) =>
      inner.download(slot, onProgress: onProgress, cancellation: cancellation);

  @override
  Future<TomFileMetadata?> describe(String slot) => inner.describe(slot);

  @override
  Future<bool> remove(String slot) => inner.remove(slot);

  @override
  void close() => inner.close();
}

/// A client whose upload never finishes until [release] is called.
class _BlockingClient extends TomFileTransferClient {
  final Completer<void> gate = Completer<void>();

  @override
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async {
    onProgress?.call(const TomTransferProgress(1, 4));
    await gate.future;
    if (cancellation?.isCancelled ?? false) {
      throw TomFileTransferException(
        'file_transfer.cancelled',
        'The file transfer was cancelled.',
        parameters: {'slot': slot},
      );
    }
    return TomFileMetadata(
      key: 'k',
      mediaType: source.mediaType,
      byteCount: source.byteCount ?? 0,
    );
  }

  @override
  Stream<List<int>> download(
    String slot, {
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async* {
    throw UnimplementedError();
  }

  @override
  Future<TomFileMetadata?> describe(String slot) async => null;

  @override
  Future<bool> remove(String slot) async => false;

  @override
  void close() {}
}

void main() {
  late TomMemoryFileTransferClient client;
  late TomFileTransferController controller;

  setUp(() {
    client = TomMemoryFileTransferClient(chunkSize: 4);
    controller = TomFileTransferController(client: client, slot: 'docs/1');
  });

  tearDown(() => controller.dispose());

  group('TomFileTransferState', () {
    test('a fresh controller is idle with nothing to retry', () {
      expect(controller.value.phase, TomTransferPhase.idle);
      expect(controller.value.kind, TomTransferKind.none);
      expect(controller.isRunning, isFalse);
      expect(controller.canRetry, isFalse);
      expect(controller.value.fraction, isNull);
    });

    test(
      'errorKey is the transfer layer\'s key, and null for anything else',
      () {
        final transferFailure = TomFileTransferState(
          phase: TomTransferPhase.failed,
          error: TomFileTransferException('file_transfer.not_found', 'gone'),
        );
        expect(transferFailure.errorKey, 'file_transfer.not_found');

        const otherFailure = TomFileTransferState(
          phase: TomTransferPhase.failed,
          error: FormatException('nope'),
        );
        expect(otherFailure.errorKey, isNull);
      },
    );

    test('copyWith clears rather than keeps when told to', () {
      const state = TomFileTransferState(
        phase: TomTransferPhase.failed,
        error: 'boom',
        metadata: TomFileMetadata(
          key: 'k',
          mediaType: 'text/plain',
          byteCount: 1,
        ),
      );
      final cleared = state.copyWith(clearError: true, clearMetadata: true);
      expect(cleared.error, isNull);
      expect(cleared.metadata, isNull);
      // Untouched fields survive.
      expect(cleared.phase, TomTransferPhase.failed);
    });
  });

  group('upload', () {
    test('publishes running then succeeded, and reports progress', () async {
      final phases = <TomTransferPhase>[];
      controller.addListener(() => phases.add(controller.value.phase));

      final stored = await controller.upload(_ref('note.txt', [1, 2, 3, 4, 5]));

      expect(stored, isNotNull);
      expect(stored!.byteCount, 5);
      expect(phases.first, TomTransferPhase.running);
      expect(phases.last, TomTransferPhase.succeeded);
      expect(controller.value.metadata, stored);
      expect(controller.value.fraction, 1.0);
    });

    test('a chunked source reports fractions between 0 and 1', () async {
      final fractions = <double?>[];
      controller.addListener(() => fractions.add(controller.value.fraction));
      // A bytes-backed ref is one chunk and so jumps straight to 1.0; a
      // streamed source is what makes a progress bar move.
      await controller.upload(_chunkedRef('big.bin', chunks: 4, chunkSize: 5));
      expect(fractions.where((f) => f != null && f > 0 && f < 1), isNotEmpty);
      expect(fractions.last, 1.0);
    });

    test('a second transfer while one runs is a programming error', () async {
      final blocking = _BlockingClient();
      final blocked = TomFileTransferController(client: blocking, slot: 's');
      addTearDown(blocked.dispose);

      final first = blocked.upload(_ref('a.txt', [1, 2, 3, 4]));
      expect(blocked.isRunning, isTrue);
      await expectLater(
        () => blocked.upload(_ref('b.txt', [1])),
        throwsStateError,
      );
      blocking.gate.complete();
      await first;
    });

    test('a rejected upload lands in failed, carrying the error key', () async {
      final flaky = _FlakyClient(client);
      final failing = TomFileTransferController(client: flaky, slot: 'docs/1');
      addTearDown(failing.dispose);

      final stored = await failing.upload(_ref('note.txt', [1, 2, 3]));
      expect(stored, isNull);
      expect(failing.value.phase, TomTransferPhase.failed);
      expect(failing.value.errorKey, 'file_transfer.rejected');
      expect(failing.canRetry, isTrue);
    });
  });

  group('retry', () {
    test('re-opens the source and succeeds on the second attempt', () async {
      final flaky = _FlakyClient(client);
      final failing = TomFileTransferController(client: flaky, slot: 'docs/1');
      addTearDown(failing.dispose);

      await failing.upload(_ref('note.txt', [1, 2, 3]));
      expect(failing.value.phase, TomTransferPhase.failed);

      await failing.retry();
      expect(flaky.uploadAttempts, 2);
      expect(failing.value.phase, TomTransferPhase.succeeded);
      expect(client.slots, contains('docs/1'));
    });

    test('does nothing when there is nothing to repeat', () async {
      await controller.retry();
      expect(controller.value.phase, TomTransferPhase.idle);
    });
  });

  group('cancel', () {
    test('a cancelled transfer lands in cancelled, not failed', () async {
      final blocking = _BlockingClient();
      final blocked = TomFileTransferController(client: blocking, slot: 's');
      addTearDown(blocked.dispose);

      final running = blocked.upload(_ref('a.txt', [1, 2, 3, 4]));
      blocked.cancel();
      blocking.gate.complete();
      await running;

      expect(blocked.value.phase, TomTransferPhase.cancelled);
      expect(blocked.canRetry, isTrue);
    });

    test('cancelling when nothing runs is harmless', () {
      controller.cancel();
      expect(controller.value.phase, TomTransferPhase.idle);
    });
  });

  group('download', () {
    test('returns the stored bytes', () async {
      await controller.upload(_ref('note.txt', [1, 2, 3, 4, 5, 6, 7]));
      final bytes = await controller.download();
      expect(bytes, [1, 2, 3, 4, 5, 6, 7]);
      expect(controller.value.kind, TomTransferKind.download);
      expect(controller.value.phase, TomTransferPhase.succeeded);
    });

    test('downloadTo streams without accumulating', () async {
      await controller.upload(_ref('note.txt', List.filled(10, 3)));
      final chunks = <List<int>>[];
      await controller.downloadTo(chunks.add);
      // chunkSize is 4, so 10 bytes arrive in more than one piece.
      expect(chunks.length, greaterThan(1));
      expect(chunks.expand((c) => c).toList(), List.filled(10, 3));
    });

    test('a missing slot fails with not_found and yields null bytes', () async {
      final bytes = await controller.download();
      expect(bytes, isNull);
      expect(controller.value.phase, TomTransferPhase.failed);
      expect(controller.value.errorKey, 'file_transfer.not_found');
    });
  });

  group('describe and remove', () {
    test(
      'describe publishes the stored descriptor without a transfer',
      () async {
        await controller.upload(_ref('note.txt', [1, 2, 3]));
        controller.reset();

        final described = await controller.describe();
        expect(described, isNotNull);
        expect(controller.value.metadata, described);
        // Describing is not a transfer, so the phase stays idle.
        expect(controller.value.phase, TomTransferPhase.idle);
      },
    );

    test('describe of an empty slot clears the metadata', () async {
      final described = await controller.describe();
      expect(described, isNull);
      expect(controller.value.metadata, isNull);
    });

    test('remove deletes the stored file and forgets the descriptor', () async {
      await controller.upload(_ref('note.txt', [1, 2, 3]));
      expect(await controller.remove(), isTrue);
      expect(client.slots, isEmpty);
      expect(controller.value.metadata, isNull);
      expect(controller.value.kind, TomTransferKind.removal);
    });

    test('removing nothing reports that nothing was removed', () async {
      expect(await controller.remove(), isFalse);
    });
  });

  group('reset and dispose', () {
    test('reset drops the error but keeps knowing a file is stored', () async {
      await controller.upload(_ref('note.txt', [1, 2, 3]));
      final stored = controller.value.metadata;
      await controller.download();
      controller.reset();

      expect(controller.value.phase, TomTransferPhase.idle);
      expect(controller.value.error, isNull);
      expect(controller.value.metadata, stored);
    });

    test('a transfer that outlives its controller publishes nothing', () async {
      final blocking = _BlockingClient();
      final orphan = TomFileTransferController(client: blocking, slot: 's');
      final running = orphan.upload(_ref('a.txt', [1, 2, 3, 4]));
      orphan.dispose();
      blocking.gate.complete();
      // No "used after dispose" from a late publish.
      await running;
    });
  });
}
