/// The guard that keeps `TomObservable`'s observer registry weak.
///
/// Holding observers by [WeakReference] is the module's single most important
/// invariant, and the one a reader is most likely to "simplify" away: a plain
/// strong reference makes every symptom the weak holding produces disappear —
/// the discarded `>>` handle keeps working, the callback never falls silent —
/// while quietly turning every observable into a permanent owner of everything
/// that ever observed it.
///
/// **The behavioural suite cannot report that change.** `observable_test.dart`
/// exercises the real thing in *collecting registered observers does not
/// disturb the survivors*, but the VM offers no way to demand a collection, so
/// that test allocates until a probe clears and calls [markTestSkipped] when it
/// does not. A strong registry is indistinguishable from a lazy collector down
/// that path: the probe never clears, the test skips, and the suite still
/// reports *All tests passed*. Measured — replacing the [WeakReference] in
/// `_ObserverRef` with the observer itself turns 375 passing tests into 374
/// passing and one skipped, and nothing goes red.
///
/// So the invariant is asserted here instead, against the source text. That is
/// a deliberate trade and worth naming: this test proves nothing about
/// behaviour, it only proves the declaration still says what the documentation
/// says. It is chosen because it is *deterministic* — the alternative that
/// would fail on the real change is a garbage-collection test, and a guard that
/// is occasionally red is a guard that gets deleted.
///
/// **When this fails**, the fix is almost never to edit this file. Check first
/// whether the registry is still weak; if it is and the declaration has merely
/// been reshaped, update the patterns below to match the new shape. If it is
/// not, that is the regression this exists to catch — see the *Memory
/// Management* section of `doc/observable/observable.md`, which promises
/// consumers that an observable does not keep its observers alive.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The file that defines the registry, relative to the package root.
///
/// Tests run with the package root as the working directory, which is the same
/// assumption `formatting_test.dart` makes when it walks the package.
const String _sourcePath = 'lib/src/tombase/observable/tom_observable.dart';

/// The handle's field must be declared as a weak reference to the observer.
///
/// Whitespace is the only thing left loose: the type is the assertion.
final RegExp _weakField = RegExp(
  r'final\s+WeakReference<TomObserver>\s+\w+\s*;',
);

/// `addObserver` must register through that handle rather than the observer.
///
/// Without this, the field above could stay weak while `addObserver` grew a
/// second, strong collection beside it — the same regression wearing a
/// different shape.
final RegExp _registersThroughHandle = RegExp(
  r'void\s+addObserver\s*\(\s*TomObserver\s+observer\s*\)\s*\{'
  r'\s*\w+\.add\(\s*_ObserverRef\(\s*observer\s*\)\s*\)\s*;\s*\}',
);

void main() {
  group('the observer registry is weak', () {
    late final String source;

    setUpAll(() {
      final file = File(_sourcePath);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'this guard reads $_sourcePath and cannot find it; either the '
            'module moved, in which case update _sourcePath, or the working '
            'directory is not the package root',
      );
      source = file.readAsStringSync();
      // A guard that reads an empty string finds nothing and passes. Prove the
      // read produced the file rather than a truncation or a stub.
      expect(
        source,
        contains('class _ObserverRef'),
        reason: 'read $_sourcePath but it does not define _ObserverRef',
      );
    });

    test('the registry handle holds its observer weakly', () {
      final handle = source.substring(source.indexOf('class _ObserverRef'));
      expect(
        _weakField.hasMatch(handle),
        isTrue,
        reason:
            '_ObserverRef no longer declares a WeakReference<TomObserver>. An '
            'observable that holds its observers strongly keeps every one of '
            'them alive for its own lifetime, which is the leak this design '
            'exists to prevent — and no behavioural test reports it.',
      );
    });

    test('addObserver registers through that handle', () {
      expect(
        _registersThroughHandle.hasMatch(source),
        isTrue,
        reason:
            'addObserver no longer stores an _ObserverRef and nothing else. A '
            'strong collection kept beside the weak one leaks exactly as much '
            'as a strong registry would.',
      );
    });
  });
}
