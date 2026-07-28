import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/files/file_ref.dart';
import 'package:tom_flutter_ui/src/forms/files/tom_file_transfer_controller.dart';
import 'package:tom_flutter_ui/src/forms/files/tom_file_transfer_indicator.dart';

// ---------------------------------------------------------------------------
// A client a test can hold open, so the running phase can be rendered.
// ---------------------------------------------------------------------------

class _GatedClient extends TomFileTransferClient {
  _GatedClient({this.failWith});

  /// When set, the upload fails with this key instead of succeeding.
  final String? failWith;

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
      throw TomFileTransferException('file_transfer.cancelled', 'cancelled');
    }
    final key = failWith;
    if (key != null) {
      throw TomFileTransferException(key, 'failed');
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

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

FileRef _ref() =>
    FileRef(name: 'note.txt', sizeBytes: 4, bytes: Uint8List.fromList([1, 2, 3, 4]));

void main() {
  group('TomFileTransferIndicator', () {
    testWidgets('renders nothing while idle', (tester) async {
      final controller = TomFileTransferController(
        client: TomMemoryFileTransferClient(),
        slot: 's',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(TomFileTransferIndicator(controller: controller)),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('offers a download row while idle when asked to', (
      tester,
    ) async {
      final controller = TomFileTransferController(
        client: TomMemoryFileTransferClient(),
        slot: 's',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          TomFileTransferIndicator(controller: controller, onDownload: () {}),
        ),
      );
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('shows progress and a cancel affordance while running', (
      tester,
    ) async {
      final client = _GatedClient();
      final controller = TomFileTransferController(client: client, slot: 's');
      addTearDown(controller.dispose);

      var cancelled = false;
      await tester.pumpWidget(
        _wrap(
          TomFileTransferIndicator(
            controller: controller,
            onCancel: () => cancelled = true,
          ),
        ),
      );

      final running = controller.upload(_ref());
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Uploading 25%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      expect(cancelled, isTrue);

      client.gate.complete();
      await running;
      await tester.pump();
    });

    testWidgets('confirms a completed upload', (tester) async {
      final client = _GatedClient();
      final controller = TomFileTransferController(client: client, slot: 's');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(TomFileTransferIndicator(controller: controller)),
      );

      final running = controller.upload(_ref());
      client.gate.complete();
      await running;
      await tester.pump();

      expect(find.text('Uploaded.'), findsOneWidget);
    });

    testWidgets('showSuccess: false leaves no confirmation behind', (
      tester,
    ) async {
      final client = _GatedClient();
      final controller = TomFileTransferController(client: client, slot: 's');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          TomFileTransferIndicator(controller: controller, showSuccess: false),
        ),
      );

      final running = controller.upload(_ref());
      client.gate.complete();
      await running;
      await tester.pump();

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a failure shows its message and a retry affordance', (
      tester,
    ) async {
      final client = _GatedClient(failWith: 'file_transfer.rejected');
      final controller = TomFileTransferController(client: client, slot: 's');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          TomFileTransferIndicator(controller: controller, onRetry: () {}),
        ),
      );

      final running = controller.upload(_ref());
      client.gate.complete();
      await running;
      await tester.pump();

      expect(find.text('The server rejected the transfer.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a cancellation is reported without a retry when none is '
        'offered', (tester) async {
      final client = _GatedClient();
      final controller = TomFileTransferController(client: client, slot: 's');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(TomFileTransferIndicator(controller: controller)),
      );

      final running = controller.upload(_ref());
      controller.cancel();
      client.gate.complete();
      await running;
      await tester.pump();

      expect(find.text('Transfer cancelled.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('tomTransferErrorMessage', () {
    test('maps the transfer layer\'s keys to wording', () {
      String messageFor(String key) => tomTransferErrorMessage(
        TomFileTransferState(
          phase: TomTransferPhase.failed,
          error: TomFileTransferException(key, 'raw'),
        ),
      );

      expect(
        messageFor('file_transfer.not_found'),
        'The file is no longer available.',
      );
      expect(
        messageFor('file_transfer.rejected'),
        'The server rejected the transfer.',
      );
      expect(
        messageFor('file_transfer.invalid_slot'),
        'The file location is not valid.',
      );
      expect(
        messageFor('file_transfer.invalid_descriptor'),
        'The server sent an unreadable response.',
      );
    });

    test('falls back to the exception text for anything unrecognised', () {
      const state = TomFileTransferState(
        phase: TomTransferPhase.failed,
        error: 'disk on fire',
      );
      expect(tomTransferErrorMessage(state), 'disk on fire');
    });

    test('describes a failure with no error at all', () {
      const state = TomFileTransferState(phase: TomTransferPhase.failed);
      expect(tomTransferErrorMessage(state), 'The transfer failed.');
    });
  });
}
