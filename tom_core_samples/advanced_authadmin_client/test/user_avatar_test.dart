/// Widget tests for the account avatar on the Users editor — the console's one
/// file field, and the proof that the suite's authenticated file client works
/// against the *auth* server exactly as it does against the app server.
///
/// The avatar is a **file slot**, not an eighth profile field: it is addressed
/// by the account's id ([AppFileSlots.userAvatar]), it transfers on pick rather
/// than on Save, and it is read back with a single `HEAD` when the editor opens
/// because [UserDto] carries no avatar column. Each of those three properties is
/// asserted below, because each is a thing a reader would otherwise have to take
/// on trust.
///
/// Socket-free: the console runs over the seeded [InMemoryAdminBackend], whose
/// blob store is the kernel's own [TomMemoryFileTransferClient]. Only the
/// platform *dialog* is stubbed — everything downstream of the picker (the
/// [FileRef] conversion, the streaming upload, progress, cancel, describe,
/// download and delete) is the real code path.
library;

import 'dart:async';

import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:advanced_authadmin_client/files/sample_avatar_picker.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'support/admin_console_harness.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
    registerSampleAvatarPicker();
  });

  tearDown(() {
    // The registry is process-global — a picker left registered would be the
    // *previous* test's picker as far as the next one is concerned.
    TomFilePickerRegistry.clear();
  });

  /// Bob's avatar slot on the auth server, spelled out rather than composed, so
  /// a change to the slot convention fails a test instead of following it.
  const bobSlot = 'auth_users/u-bob/avatar_ref';

  /// Signs in and opens Bob's editor.
  Future<void> openBobEditor(
    WidgetTester tester,
    InMemoryAdminBackend backend,
  ) async {
    await pumpSignedInConsole(tester, backend);
    await tester.tap(find.byKey(const Key('users-tile-u-bob')));
    await tester.pumpAndSettle();
  }

  /// Taps the avatar field's picker button and settles the upload it starts.
  Future<void> pickAvatar(WidgetTester tester) async {
    await tester.tap(find.text('Choose image…'));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-D12-09: the editor renders the avatar field from the bundle',
      (tester) async {
    await openBobEditor(tester, InMemoryAdminBackend());

    // The label comes from `admin.users.avatar.label` and the caption from the
    // console bundle's `file.none` — the framework's own fallback would read
    // "— no file selected", so this text can only be the served one.
    expect(find.text('Avatar'), findsWidgets);
    expect(find.text('— no avatar set'), findsOneWidget);
    expect(find.text('Choose image…'), findsOneWidget);
  });

  testWidgets('TC-D12-10: the avatar is edit-only — create offers no file field',
      (tester) async {
    // A slot is addressed by the row id, and on create there is no row yet.
    await pumpSignedInConsole(tester, InMemoryAdminBackend());
    await tester.tap(find.byKey(const Key('users-create')));
    await tester.pumpAndSettle();

    expect(find.text('Avatar'), findsNothing);
    expect(find.text('Choose image…'), findsNothing);
  });

  testWidgets("TC-D12-11: picking uploads into the account's slot",
      (tester) async {
    final store = TomMemoryFileTransferClient();
    await openBobEditor(tester, InMemoryAdminBackend(files: store));
    expect(store.slots, isEmpty);

    await pickAvatar(tester);

    // The bytes landed in the slot the contracts name — on the auth server's
    // table, not the app server's.
    expect(store.slots, contains(bobSlot));
    expect(store.slots, contains(AppFileSlots.userAvatar('u-bob')));
    final stored = await store.describe(bobSlot);
    expect(stored, isNotNull);
    expect(stored!.fileName, startsWith('avatar-'));
    expect(stored.byteCount, greaterThan(0));

    // …and the caption names the file, through `file.selected`.
    expect(find.textContaining('avatar-'), findsOneWidget);
  });

  testWidgets('TC-D12-12: the upload does not wait for Save', (tester) async {
    // The dialog's Save writes the JSON profile; the bytes have already gone.
    // Cancelling the editor must therefore not un-upload the avatar.
    final store = TomMemoryFileTransferClient();
    await openBobEditor(tester, InMemoryAdminBackend(files: store));

    await pickAvatar(tester);
    expect(store.slots, contains(bobSlot));

    await tester.tap(find.widgetWithText(TextButton, 'Cancel').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin-editor-dialog')), findsNothing);
    expect(store.slots, contains(bobSlot));
  });

  testWidgets('TC-D12-13: a stored avatar is found by the HEAD on open, '
      'downloads and clears', (tester) async {
    // An avatar already in the slot, as if a previous session had set it. The
    // editor was never told about it — it discovers it with one `describe`,
    // which is the whole read path.
    final store = TomMemoryFileTransferClient();
    final uploaded = await store.upload(
      slot: bobSlot,
      source: TomFileSource.bytes(
        'face.png',
        const [0x89, 0x50, 0x4E, 0x47],
        mediaType: 'image/png',
      ),
    );
    expect(uploaded.fileName, 'face.png');

    await openBobEditor(tester, InMemoryAdminBackend(files: store));

    // Rendered from the descriptor the `HEAD` returned, without downloading.
    expect(find.textContaining('face.png'), findsOneWidget);

    // Downloading hands the bytes to the console, which reports what arrived.
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Downloaded face.png'), findsOneWidget);

    // Clearing deletes the blob, not just the field's value.
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(store.slots, isEmpty);
    expect(await store.describe(bobSlot), isNull);

    // Closed rather than left open, because the field's lifetime *is* the
    // dialog's: the editor disposes it when it pops, and disposal is what
    // cancels the validation debounce that changing the value just scheduled.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').first);
    await tester.pumpAndSettle();
  });

  testWidgets('TC-D12-14: a transfer in flight shows progress and a cancel '
      'affordance', (tester) async {
    // Hold the upload open at 40% so the indicator can be observed mid-flight;
    // everything else is the real in-memory client.
    final gate = _GatedFileTransferClient(TomMemoryFileTransferClient());
    await openBobEditor(tester, InMemoryAdminBackend(files: gate));

    // Tapped and pumped by hand rather than through [pickAvatar]: that helper
    // settles, and a gated upload never settles. The tap itself completes — it
    // is the transfer it starts that stays in flight.
    await tester.tap(find.text('Choose image…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // The progress line is the console bundle's `file.uploading`, interpolated.
    expect(find.textContaining('Uploading 40%'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);

    gate.release();
    await tester.pumpAndSettle();
    expect(find.textContaining('Uploading 40%'), findsNothing);
  });

  testWidgets('TC-D12-15: the avatar chrome is server-bundle-driven '
      '(sentinel proof)', (tester) async {
    // Every string the field renders carries a sentinel only the installed
    // bundle could supply, so a hardcoded fallback leaking through would fail
    // rather than merely look plausible.
    final backend = InMemoryAdminBackend();
    await pumpSignedInConsole(tester, backend);
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({
        for (final entry in InMemoryAdminBackend.fullTexts.entries)
          entry.key: '${entry.value} [srv]',
      }),
    );
    await tester.tap(find.byKey(const Key('users-tile-u-bob')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Avatar [srv]'), findsWidgets);
    expect(find.textContaining('— no avatar set [srv]'), findsOneWidget);
    expect(find.textContaining('Choose image… [srv]'), findsOneWidget);
  });
}

/// A transfer client that reports 40% and then waits, so a test can observe an
/// upload mid-flight.
///
/// Delegates everything else to the real in-memory client — the point is to
/// suspend the transfer, not to fake it, so what the indicator renders is what
/// the real progress callback produced.
class _GatedFileTransferClient extends TomFileTransferClient {
  _GatedFileTransferClient(this._inner);

  final TomFileTransferClient _inner;
  final Completer<void> _gate = Completer<void>();

  /// Lets the held upload finish.
  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async {
    onProgress?.call(const TomTransferProgress(40, 100));
    await _gate.future;
    return _inner.upload(
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
      _inner.download(slot, onProgress: onProgress, cancellation: cancellation);

  @override
  Future<TomFileMetadata?> describe(String slot) => _inner.describe(slot);

  @override
  Future<bool> remove(String slot) => _inner.remove(slot);

  @override
  void close() => _inner.close();
}
