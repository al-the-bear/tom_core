/// The state machine behind a file field's upload/download UX.
///
/// The kernel's [TomFileTransferClient] moves bytes; it says nothing about
/// what a user sees while they move. This controller is that missing half: one
/// [ValueNotifier] holding the phase, the progress and the error, so a widget
/// rebuilds on `ValueListenableBuilder` and a test can assert the sequence of
/// states without a frame.
///
/// ## Why a controller and not just a `Future`
///
/// Three of the four things a file field needs — progress, cancel, retry — are
/// not expressible as a future. Progress arrives *during* it, cancel has to reach
/// into it, and retry needs to know what the last attempt was. Holding those in
/// one object is also what lets the field, the dialog and the preview all watch
/// the same transfer.
///
/// ## Example
///
/// ```dart
/// final controller = TomFileTransferController(
///   client: transferClient,
///   slot: 'invoices/4711/scan',
/// );
///
/// await controller.upload(pickedRef);
/// if (controller.value.phase == TomTransferPhase.failed) {
///   await controller.retry();
/// }
/// ```
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'file_ref.dart';

// ===========================================================================
// State
// ===========================================================================

/// Where a transfer has got to.
enum TomTransferPhase {
  /// Nothing has been started, or the last result has been cleared.
  idle,

  /// A transfer is in flight.
  running,

  /// The last transfer finished.
  succeeded,

  /// The last transfer was cancelled by the user.
  cancelled,

  /// The last transfer failed.
  failed,
}

/// What kind of transfer the controller last ran.
enum TomTransferKind {
  /// No transfer yet.
  none,

  /// Sending a file to the store.
  upload,

  /// Reading a file back from the store.
  download,

  /// Deleting a stored file.
  removal,
}

/// A snapshot of a transfer, as a widget needs to render it.
@immutable
class TomFileTransferState {
  /// Creates a transfer snapshot.
  const TomFileTransferState({
    this.phase = TomTransferPhase.idle,
    this.kind = TomTransferKind.none,
    this.progress,
    this.error,
    this.metadata,
  });

  /// Where the transfer has got to.
  final TomTransferPhase phase;

  /// What kind of transfer this describes.
  final TomTransferKind kind;

  /// The most recent progress report, when the transfer produced one.
  final TomTransferProgress? progress;

  /// The failure, when [phase] is [TomTransferPhase.failed].
  final Object? error;

  /// The server's descriptor, after a successful upload or describe.
  final TomFileMetadata? metadata;

  /// Whether a transfer is in flight.
  bool get isRunning => phase == TomTransferPhase.running;

  /// The completed fraction, or `null` when it cannot be known.
  ///
  /// A widget passes this straight to a progress indicator's `value`, where
  /// `null` already means "indeterminate" — so the two vocabularies line up
  /// and no widget has to translate.
  double? get fraction => progress?.fraction;

  /// The error key when the failure came from the transfer layer, else `null`.
  ///
  /// Lets a UI distinguish "not found" from "rejected" without matching on
  /// message text.
  String? get errorKey {
    final failure = error;
    return failure is TomFileTransferException ? failure.key : null;
  }

  /// A copy with the given fields replaced.
  ///
  /// [error] and [metadata] are cleared rather than kept when the flags say so,
  /// because a `copyWith` that could only *set* them would leave a stale error
  /// visible next to a fresh success.
  TomFileTransferState copyWith({
    TomTransferPhase? phase,
    TomTransferKind? kind,
    TomTransferProgress? progress,
    Object? error,
    TomFileMetadata? metadata,
    bool clearProgress = false,
    bool clearError = false,
    bool clearMetadata = false,
  }) => TomFileTransferState(
    phase: phase ?? this.phase,
    kind: kind ?? this.kind,
    progress: clearProgress ? null : (progress ?? this.progress),
    error: clearError ? null : (error ?? this.error),
    metadata: clearMetadata ? null : (metadata ?? this.metadata),
  );

  @override
  String toString() =>
      'TomFileTransferState(${phase.name}, ${kind.name}'
      '${progress == null ? '' : ', $progress'}'
      '${error == null ? '' : ', error: $error'})';
}

// ===========================================================================
// Controller
// ===========================================================================

/// Drives one file slot's transfers and publishes their state.
///
/// One controller per slot. It owns the cancellation token for the transfer in
/// flight and remembers the last attempt so [retry] can repeat it.
class TomFileTransferController extends ValueNotifier<TomFileTransferState> {
  /// Creates a controller for [slot] on [client].
  TomFileTransferController({required this.client, required this.slot})
    : super(const TomFileTransferState());

  /// The transport moving the bytes.
  final TomFileTransferClient client;

  /// The application-owned slot this controller transfers to and from.
  final String slot;

  TomTransferCancellation? _cancellation;

  /// The last attempt, replayable by [retry].
  ///
  /// A closure rather than a recorded set of arguments: every operation
  /// captures whatever it needs, so adding one does not mean extending a
  /// bookkeeping record.
  Future<void> Function()? _lastAttempt;

  bool _disposed = false;

  /// Whether a transfer is in flight.
  bool get isRunning => value.isRunning;

  /// Whether [retry] has something to repeat.
  bool get canRetry =>
      _lastAttempt != null &&
      (value.phase == TomTransferPhase.failed ||
          value.phase == TomTransferPhase.cancelled);

  /// Uploads [ref] into [slot], returning the stored descriptor.
  ///
  /// Returns `null` when the upload was cancelled or failed; the reason is in
  /// [value]. Callers that want to react to a specific failure read
  /// [TomFileTransferState.errorKey] rather than catching, because the error is
  /// already captured in the published state.
  Future<TomFileMetadata?> upload(TomFileRef ref) {
    TomFileMetadata? stored;
    return _run(TomTransferKind.upload, () async {
      stored = await client.upload(
        slot: slot,
        source: ref.toSource(),
        onProgress: _report,
        cancellation: _cancellation,
      );
      _publish(value.copyWith(metadata: stored));
    }).then((_) => stored);
  }

  /// Downloads the stored file, handing each chunk to [onChunk].
  ///
  /// The streaming form: nothing accumulates unless [onChunk] accumulates.
  /// Use it to write to a file, a decoder, or anywhere a whole-file buffer
  /// would be the wrong shape.
  Future<void> downloadTo(void Function(List<int> chunk) onChunk) {
    return _run(TomTransferKind.download, () async {
      await for (final chunk in client.download(
        slot,
        onProgress: _report,
        cancellation: _cancellation,
      )) {
        onChunk(chunk);
      }
    });
  }

  /// Downloads the stored file into memory.
  ///
  /// For previews and small documents. Returns `null` when the transfer was
  /// cancelled or failed.
  Future<Uint8List?> download() async {
    final builder = BytesBuilder();
    await downloadTo(builder.add);
    return value.phase == TomTransferPhase.succeeded
        ? builder.takeBytes()
        : null;
  }

  /// Describes the stored file without transferring it.
  ///
  /// Cheap enough to call when a form opens, which is how a re-opened form
  /// shows its existing attachment.
  Future<TomFileMetadata?> describe() async {
    final stored = await client.describe(slot);
    if (!_disposed) {
      _publish(value.copyWith(metadata: stored, clearMetadata: stored == null));
    }
    return stored;
  }

  /// Deletes the stored file, returning whether anything was deleted.
  Future<bool> remove() async {
    var removed = false;
    await _run(TomTransferKind.removal, () async {
      removed = await client.remove(slot);
      _publish(value.copyWith(clearMetadata: true));
    });
    return removed;
  }

  /// Cancels the transfer in flight; does nothing when none is.
  void cancel() => _cancellation?.cancel();

  /// Repeats the last attempt.
  ///
  /// Works because a [TomFileSource] can be opened again — the whole reason
  /// the source is a factory rather than a stream.
  Future<void> retry() async {
    final attempt = _lastAttempt;
    if (attempt == null || isRunning) return;
    await attempt();
  }

  /// Returns to [TomTransferPhase.idle], dropping the last result.
  ///
  /// Keeps [TomFileTransferState.metadata]: forgetting an error should not
  /// also forget that a file is stored.
  void reset() {
    _publish(const TomFileTransferState().copyWith(metadata: value.metadata));
  }

  /// Runs [body] as the controller's single in-flight transfer.
  ///
  /// Centralises the phase transitions so every operation reports cancellation
  /// and failure the same way — the alternative is four copies of the same
  /// try/catch, drifting apart.
  Future<void> _run(TomTransferKind kind, Future<void> Function() body) async {
    if (isRunning) {
      throw StateError(
        'A transfer for slot "$slot" is already running; cancel it first.',
      );
    }
    // Recorded before the attempt, so a failure that happens immediately is
    // still retryable.
    _lastAttempt = () => _run(kind, body);
    final cancellation = TomTransferCancellation();
    _cancellation = cancellation;
    _publish(
      TomFileTransferState(
        phase: TomTransferPhase.running,
        kind: kind,
      ).copyWith(metadata: value.metadata),
    );
    try {
      await body();
      _publish(value.copyWith(phase: TomTransferPhase.succeeded));
    } on TomFileTransferException catch (error) {
      _publish(
        value.copyWith(
          phase: error.key == 'file_transfer.cancelled'
              ? TomTransferPhase.cancelled
              : TomTransferPhase.failed,
          error: error,
        ),
      );
    } catch (error) {
      _publish(value.copyWith(phase: TomTransferPhase.failed, error: error));
    } finally {
      _cancellation = null;
    }
  }

  void _report(TomTransferProgress progress) =>
      _publish(value.copyWith(progress: progress));

  /// Publishes [state], unless this controller has been disposed.
  ///
  /// A transfer outlives the widget that started it often enough — a user
  /// leaves the page mid-upload — that guarding here is cheaper than guarding
  /// at every call site.
  void _publish(TomFileTransferState state) {
    if (_disposed) return;
    value = state;
  }

  @override
  void dispose() {
    _disposed = true;
    // Not `close()`: the client is usually shared across the application and
    // outlives any one field.
    _cancellation?.cancel();
    super.dispose();
  }
}
