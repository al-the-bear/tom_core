// A consumer's-eye view of the package.
//
// This file imports **only** `package:tom_flutter_ui/tom_flutter_ui.dart` and
// Flutter — never `package:tom_core_kernel/...` and never a `lib/src/` path.
// That restriction is the test. `tom_flutter_ui` does not re-export the kernel
// wholesale, so a kernel type missing from `lib/src/kernel_types.dart` is
// unnameable here and this file stops compiling.
//
// The gap this guards against was real and invisible: `scope:` is a parameter
// on every Tom widget, yet `TomScope` was absent from the only `show` list the
// package had. Nothing inside `lib/` caught it, because the files declaring
// those signatures import the kernel barrel unfiltered — the omission could
// only ever be seen from outside.
//
// `tool/check_kernel_bridge.py` covers the other direction: it fails when a
// kernel type reaches a public signature without reaching the bridge.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A consumer authorization adapter — the kernel contract an app implements.
class _DenyOne implements TomAuthorizationAdapter {
  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      resourceKeyPath == 'settings.secret'
          ? TomAuthState.none
          : TomAuthState.full;
}

/// A consumer observer, naming the kernel's observation contract directly.
class _CountingObserver implements TomObserver<TomObservable> {
  int notifications = 0;

  @override
  void onNotify(TomObservable observable) => notifications++;
}

/// A consumer lifecycle listener — the interface `TomListForm` implements, so
/// it appears in a public supertype clause of this package.
class _ClearWatcher extends TomListLifecycleListener {
  int cleared = 0;

  @override
  void onBeforeClear(TomList list) => cleared++;
}

/// Names `TomClass` in a type-parameter bound, exactly as `TomListForm` and
/// `TomForm` do. Instantiating one needs a generated reflection mirror, which
/// is beside the point here: what is under test is that the *name* resolves.
typedef _EntityList<T extends TomClass> = TomList<T>;

void main() {
  group('the barrel carries every kernel type in a public signature', () {
    tearDown(TomAuthorization.reset);

    // The todo's DONE WHEN, spelled as code: declare a TomScope, construct a
    // widget with an explicit `scope:`, and read the resolved path back.
    testWidgets('a consumer can declare a TomScope and pass it as scope:',
        (tester) async {
      final TomScope scope = TomScopeBase(scopeId: 'settings');
      final widget = TomText(tomId: 'title', scope: scope, text: 'Settings');

      expect(widget.scope, same(scope));
      expect(widget.constructionScope, same(scope));
      expect(widget.basePath, endsWith('settings.title'));

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.text('Settings'), findsOneWidget);
    });

    test('a consumer can name the authorization types', () {
      TomAuthorization.adapter = _DenyOne();
      expect(TomAuthorization.resolveAuth('settings.secret'), TomAuthState.none);
      expect(TomAuthorization.resolveAuth('settings.title'), TomAuthState.full);

      const authorizer = TomAuthorizer(
        strategy: TomAuthorizerStrategy.authorizerNarrowsOnly,
        resolve: _readOnly,
      );
      expect(authorizer.effectiveAuth(TomAuthState.full), TomAuthState.read);

      const controller = TomUIStateController(resolve: _disableWhenFlagged);
      expect(controller.apply(TomAuthState.full, data: true),
          TomAuthState.disabled);
      expect(controller.apply(TomAuthState.full), TomAuthState.full);

      final group = TomAuthorizationGroup(
        'block',
        mode: AuthGroupMode.controlsWidest,
      );
      expect(group.groupId, 'block');
      expect(group.mode, AuthGroupMode.controlsWidest);

      // TomAuthorizable is the interface every Tom widget implements, so a
      // consumer holding one has to be able to name it.
      final TomAuthorizable node = TomText(tomId: 'title', text: 'x');
      expect(node.tomId, 'title');
    });

    test('a consumer can name the observable types', () {
      final TomObject<String> cell = TomObject<String>('draft');
      final TomObservable observable = cell;

      final observer = _CountingObserver();
      observable.addObserver(observer);
      cell.set('final');
      expect(observer.notifications, 1);

      // TomFunctionObserver is the only concrete observer the kernel ships;
      // without it, observing a Tom field from outside the package would mean
      // declaring a class for every callback.
      var fired = 0;
      final fn = TomFunctionObserver<TomObservable>((_) => fired++);
      observable.addObserver(fn);
      cell.set('shipped');
      expect(fired, 1);

      final list = TomList<TomObject<String>>();
      list.append(cell);
      expect(list.length, 1);

      final watcher = _ClearWatcher();
      list.addLifecycleListener(watcher);
      list.resetWith([TomObject<String>('replacement')]);
      expect(watcher.cleared, 1);

      // The bound `TomListForm` imposes, named without a reflected entity.
      expect(_EntityList, isNotNull);
    });

    test('a consumer can name TomObservableEnum', () {
      final mode = TomObservableEnum<_Mode>(
        _Mode.compact,
        values: _Mode.values,
      );
      expect(mode.get(), _Mode.compact);
      expect(mode.values, _Mode.values);
      expect(mode.scope, isA<TomScope>());
    });

    test('a consumer can name the file-transfer types', () {
      final source = TomFileSource.bytes(
        'notes.txt',
        Uint8List.fromList(const [1, 2, 3]),
        mediaType: 'text/plain',
      );
      expect(source.fileName, 'notes.txt');

      const metadata = TomFileMetadata(
        key: 'slot/1',
        mediaType: 'text/plain',
        byteCount: 3,
        fileName: 'notes.txt',
      );
      final ref = FileRef.stored(metadata);
      expect(ref.isStored, isTrue);
      expect(ref.name, 'notes.txt');
      expect(ref.toSource, throwsA(isA<StateError>()));

      const progress = TomTransferProgress(1, 3);
      expect(progress.isDeterminate, isTrue);

      final cancellation = TomTransferCancellation();
      expect(cancellation.isCancelled, isFalse);
      cancellation.cancel();
      expect(cancellation.isCancelled, isTrue);

      // The client type and its error are both public: `transferClient:` is a
      // constructor parameter on TomFormFileField, and a consumer supplying an
      // implementation signals failure with the kernel's exception.
      final TomFileTransferClient? client = null;
      expect(client, isNull);
      expect(
        TomFileTransferException('file_transfer.cancelled', 'cancelled'),
        isA<Exception>(),
      );
    });

    test('a consumer can name TomScopeMixin, the public supertype', () {
      // TomScreenElementsProviderBase mixes TomScopeMixin in, so the mixin is
      // part of a supertype chain a consumer subclasses.
      final TomScopeMixin scope = TomScopeBase(scopeId: 'admin');
      expect(scope.id, 'admin');
      expect(scope.getScopePath(), contains('admin'));
    });
  });
}

enum _Mode { compact, comfortable }

TomAuthState _readOnly(TomAuthState resourceAuth) => TomAuthState.read;

TomAuthState _disableWhenFlagged(TomAuthState currentAuth, Object? data) =>
    data == true ? TomAuthState.disabled : currentAuth;
