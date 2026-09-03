/// Widget tests for the item attachment — the file half of the end-user app.
///
/// The item's file is not an eighth form field: it is a **slot** on the server,
/// moved by [AppBackend.files] rather than by [AppBackend.saveItem] and worded
/// under `board.item.attachment.*`. Its authorization, however, is the same
/// story as every field's — the item's resource ceiling narrowed by the role's
/// grade, here [projectRoleAttachmentGrades] rather than
/// `projectRoleFieldGrades`. These tests hold both halves of that shape in place
/// from both ends: the detail screen (pick → upload → progress → download →
/// clear; an editor who may replace the file, a viewer who may only see it, and
/// no field at all when the resource ceiling cannot be resolved) and the board
/// (paperclip exactly the items that have a file, and hand the detail screen the
/// descriptor it already fetched).
///
/// What these cannot show is whether the **server** agrees: the shaping here is
/// cooperation, and the binding answer is the app server's per-row grade at the
/// file endpoint. That half is asserted live by `advanced_client_core`'s
/// `file_transfer_integration_test.dart` (TC-FT-05) and by the cross-tier runner
/// (TC-37-09).
///
/// Socket-free, like the rest of the suite: the seeded [InMemoryAppBackend]
/// carries the kernel's own [TomMemoryFileTransferClient], so the field runs its
/// *real* upload/download/delete code path against a map. What is stubbed is the
/// platform dialog and nothing else — [TomFilePickerRegistry] is the one seam an
/// application replaces with its picker package, so a test registering a
/// synthetic picker is exercising the same registration `main` performs.
library;

import 'dart:async';
import 'dart:convert';

import 'package:advanced_app_client/app/app_session.dart';
import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_app_client/files/sample_file_picker.dart';
import 'package:advanced_app_client/reflection_seed.dart';
import 'package:advanced_app_client/screens/board_screen.dart';
import 'package:advanced_app_client/screens/item_detail_screen.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show
        ProjectRole,
        projectRoleAttachmentGrades,
        registerProjectRoleVocabulary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
    registerProjectRoleVocabulary();
    registerSampleFilePicker();
  });

  tearDown(() {
    TomAuthorization.reset();
    TomResourceRoleRegistry.reset();
    // The registry is process-global — a picker left registered would be the
    // *previous* test's picker as far as the next one is concerned.
    TomFilePickerRegistry.clear();
  });

  /// A tall viewport so the detail form's fields, the attachment row and the
  /// Save button all fit on-screen.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  LoginRequest login(String user) =>
      LoginRequest(username: user, password: 'pw');

  const itemSlot = 'app_items/i-1/attachment';

  /// Signs [user] in over a fresh backend and pushes the detail screen for item
  /// `i-1`, handing it the descriptor the board would have fetched.
  ///
  /// Mirrors `item_detail_screen_test.dart`'s harness, plus the one thing this
  /// suite is about: the `attachment:` argument. [files] replaces the blob
  /// store, so a test can hold the store it inspects or wrap it to suspend a
  /// transfer. Returns the live backend.
  Future<InMemoryAppBackend> openDetail(
    WidgetTester tester,
    String user, {
    ProjectRole? shareCarolAs,
    Map<String, dynamic>? bundleOverride,
    TomFileTransferClient? files,
  }) async {
    useTallViewport(tester);

    final backend = InMemoryAppBackend(files: files);
    final session = AppSession(backend);

    if (shareCarolAs != null) {
      await session.login(login('alice'));
      await backend.share(
        ShareRequest(
          resourceType: 'project',
          resourceId: 'p-1',
          granteeUserId: 'u-carol',
          projectRole: shareCarolAs,
        ),
      );
      await session.logout();
    }

    await session.login(login(user));
    if (bundleOverride != null) {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(bundleOverride),
      );
    }
    final items = await backend.listItems('l-1');
    final item = items.firstWhere((i) => i.id.get() == 'i-1');
    final descriptors = await backend.listAttachments('l-1');
    final stored = descriptors
        .where((d) => d.slotId == 'i-1')
        .cast<FileDescriptorDto?>()
        .firstWhere((_) => true, orElse: () => null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                TomPageRoute<bool>(
                  builder: (_) => ItemDetailScreen(
                    session: session,
                    item: item,
                    attachment: stored,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return backend;
  }

  /// Taps the field's "Choose file…" button and settles the upload it starts.
  Future<void> pickFile(WidgetTester tester) async {
    await tester.tap(find.text('Choose file…'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TC-D12-01: the empty attachment field renders its bundle label and caption',
    (tester) async {
      await openDetail(tester, 'alice');

      // The label comes from `board.item.attachment.label` and the caption from
      // the global `file.none` — both server-bundle keys, neither a framework
      // default (the framework's own fallback is "— no file selected").
      expect(find.text('Attachment'), findsWidgets);
      expect(find.text('— no file attached'), findsOneWidget);
      expect(find.text('Choose file…'), findsOneWidget);
    },
  );

  testWidgets('TC-D12-02: picking a file uploads it into the item\'s slot', (
    tester,
  ) async {
    final store = TomMemoryFileTransferClient();
    final backend = await openDetail(tester, 'alice', files: store);
    expect(store.slots, isEmpty);

    await pickFile(tester);

    // The bytes landed in the slot the contracts name — not a slot the screen
    // composed for itself.
    expect(store.slots, contains(itemSlot));
    expect(store.slots, contains(AppFileSlots.itemAttachment('i-1')));
    final stored = await store.describe(itemSlot);
    expect(stored, isNotNull);
    expect(stored!.fileName, startsWith('note-'));
    expect(stored.byteCount, greaterThan(0));

    // …and the backend now lists the item as having an attachment.
    final listed = await backend.listAttachments('l-1');
    expect(listed.map((d) => d.slotId), contains('i-1'));

    // …and the caption names the file, through `file.selected`.
    expect(find.textContaining('note-'), findsOneWidget);
  });

  testWidgets(
    'TC-D12-03: a transfer in flight shows progress and a cancel affordance',
    (tester) async {
      // Hold the upload open at 30% so the indicator can be observed mid-flight;
      // everything else is the real in-memory client.
      final gate = _GatedFileTransferClient(TomMemoryFileTransferClient());
      await openDetail(tester, 'alice', files: gate);

      // Tapped and pumped by hand rather than through [pickFile]: that helper
      // settles, and a gated upload never settles. The tap itself completes — it
      // is the transfer it starts that stays in flight — so each step can still be
      // awaited, and the pumps let the picked file and its first progress frame
      // render while the upload hangs.
      await tester.tap(find.text('Choose file…'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // The progress line is the bundle's `file.uploading`, interpolated.
      expect(find.textContaining('Uploading 30%'), findsOneWidget);
      // …and the cancel affordance is offered while it is in flight.
      expect(find.byTooltip('Cancel'), findsOneWidget);

      gate.release();
      await tester.pumpAndSettle();
      expect(find.textContaining('Uploading 30%'), findsNothing);
    },
  );

  testWidgets('TC-D12-04: a stored file renders from the board descriptor, '
      'downloads and clears', (tester) async {
    // A file already in the slot, as if a previous session had uploaded it. The
    // harness fetches its descriptor exactly as the board does and hands it to
    // the screen, so what the field renders on its first frame came from the
    // board's own `listAttachments` — no extra round-trip.
    final store = TomMemoryFileTransferClient();
    final uploaded = await store.upload(
      slot: itemSlot,
      source: TomFileSource.bytes('spec.txt', utf8.encode('hello')),
    );
    final backend = await openDetail(tester, 'alice', files: store);

    expect(find.textContaining('spec.txt'), findsOneWidget);
    expect(find.byTooltip('Download'), findsOneWidget);
    expect(uploaded.byteCount, 5);

    // Downloading hands the bytes back and the screen reports what arrived,
    // through `board.item.attachment.downloaded`.
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Downloaded spec.txt'), findsOneWidget);

    // Clearing deletes the blob rather than orphaning it.
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(store.slots, isNot(contains(itemSlot)));
    expect(await backend.listAttachments('l-1'), isEmpty);
  });

  testWidgets('TC-D12-05: a viewer sees the attachment but cannot change it', (
    tester,
  ) async {
    await openDetail(tester, 'carol', shareCarolAs: ProjectRole.viewer);

    // The field is present (a viewer may see that a task has a file) but the
    // picker is closed — the item's resource state is its ceiling, and a
    // viewer's is `read`.
    expect(find.text('Attachment'), findsWidgets);
    final choose = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Choose file…'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(choose.onPressed, isNull);
  });

  testWidgets('TC-D13-01: an editor keeps the picker — the attachment grade follows '
      'the role, not the field set', (tester) async {
    // The complement of TC-D12-05, and the reason the field consults
    // `projectRoleAttachmentGrades` rather than assuming the resource ceiling:
    // an editor and a viewer are *both* below the owner, and the matrix says one
    // may replace the file and the other may not. Regrading `editor` to `read`
    // in the shared matrix would close this picker and fail here — which is what
    // makes the map load-bearing on the client instead of decorative.
    await openDetail(tester, 'carol', shareCarolAs: ProjectRole.editor);

    final choose = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Choose file…'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      choose.onPressed,
      isNotNull,
      reason: 'the editor row of the attachment matrix is `full`',
    );
  });

  testWidgets(
    'TC-D13-02: without the resource-role registry the attachment collapses '
    'entirely',
    (tester) async {
      // The closed-safe floor, and the thing the composition exists to preserve:
      // the attachment's state is the item's *resource ceiling* narrowed by the
      // role's grade, so an unresolvable ceiling closes the field no matter what
      // the grade map says. Dropping the registry is how a real deployment reaches
      // that state (a role name the vocabulary does not know), and the answer must
      // be "no field", not "an owner's field".
      TomResourceRoleRegistry.reset();

      await openDetail(tester, 'alice');

      expect(
        find.text('Attachment'),
        findsNothing,
        reason:
            'resource state `none` hides the field, exactly as it hides an '
            'ungraded form field',
      );
      expect(find.text('Choose file…'), findsNothing);
    },
  );

  testWidgets('TC-D12-06: the board paperclips exactly the items with a file', (
    tester,
  ) async {
    useTallViewport(tester);
    final store = TomMemoryFileTransferClient();
    final backend = InMemoryAppBackend(files: store);
    final session = AppSession(backend);
    await session.login(login('alice'));
    await store.upload(
      slot: AppFileSlots.itemAttachment('i-1'),
      source: TomFileSource.bytes('spec.txt', utf8.encode('hello')),
    );

    await tester.pumpWidget(MaterialApp(home: BoardScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('item-i-1-attachment')), findsOneWidget);
    expect(find.byKey(const Key('item-i-2-attachment')), findsNothing);
    // The tooltip is the bundle's `board.item.attachment.present`, sized.
    expect(
      tester
          .widget<Tooltip>(find.byKey(const Key('item-i-1-attachment')))
          .message,
      'Has an attachment (5 B)',
    );
  });

  testWidgets('TC-D12-07: an upload made on the detail screen paperclips the '
      'board on return', (tester) async {
    useTallViewport(tester);
    final backend = InMemoryAppBackend();
    final session = AppSession(backend);
    await session.login(login('alice'));

    await tester.pumpWidget(MaterialApp(home: BoardScreen(session: session)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('item-i-1-attachment')), findsNothing);

    await tester.tap(find.byKey(const Key('item-i-1')));
    await tester.pumpAndSettle();
    await pickFile(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The board reloads unconditionally on return, because the attachment moved
    // without a save — a reload gated on `pop(true)` would miss it.
    expect(find.byKey(const Key('item-i-1-attachment')), findsOneWidget);
  });

  testWidgets('TC-D12-08: the attachment chrome is server-bundle-driven '
      '(sentinel proof)', (tester) async {
    await openDetail(
      tester,
      'alice',
      bundleOverride: {
        'board.item.attachment.label': 'Attachment [srv]',
        'file.choose': 'Pick one [srv]',
        'file.none': 'Nothing yet [srv]',
      },
    );

    expect(find.textContaining('Attachment [srv]'), findsWidgets);
    expect(find.textContaining('Pick one [srv]'), findsOneWidget);
    expect(find.textContaining('Nothing yet [srv]'), findsOneWidget);
    // Neither the canned bundle value nor the framework's English default: the
    // wording resolves through the installed provider and nowhere else.
    expect(find.text('Choose file…'), findsNothing);
    expect(find.text('— no file selected'), findsNothing);
  });
}

/// A transfer client that reports 30% and then waits, so a test can observe an
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
    onProgress?.call(const TomTransferProgress(30, 100));
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
