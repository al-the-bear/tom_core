/// The two internal file primitives, asserted on their own.
///
/// `atomic_file.dart` and `file_mutex.dart` are not exported: they are how
/// the kernel's file-backed stores reach the disk, and both stores exercise
/// them realistically — `scheduling_test.dart` and `logging_test.dart` hold
/// the torn-staging-file, blocked-staging-path, stale-guard and second-owner
/// cases. What a store never reaches has no home there, so it lives here: the
/// write contract stated without a store around it, and the guard's behaviour
/// at its own edges — a fresh guard that times out, a stale one that is
/// broken and reported, and two waiters reaching the staleness boundary
/// together.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:tom_core_kernel/src/tombase/little_things/atomic_file.dart';
import 'package:tom_core_kernel/src/tombase/little_things/file_mutex.dart';
import 'package:tom_core_kernel/tom_core_kernel_io.dart' as io;

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('file_primitives_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('tomWriteFileAtomically', () {
    test('FP-1: writes the content and creates missing parents', () {
      final file = File('${dir.path}/a/b/store.json');
      tomWriteFileAtomically(file, '[1]');
      expect(file.readAsStringSync(), '[1]');
    });

    test('FP-2: replaces the previous content whole and leaves no staging '
        'file behind', () {
      final file = File('${dir.path}/store.json')..writeAsStringSync('[old]');
      tomWriteFileAtomically(file, '[new]');
      expect(file.readAsStringSync(), '[new]');
      expect(File(tomAtomicWriteTempPath(file.path)).existsSync(), isFalse);
    });

    test('FP-3: the staging name is per writer and per target', () {
      final a = tomAtomicWriteTempPath('${dir.path}/a.json');
      final b = tomAtomicWriteTempPath('${dir.path}/b.json');
      expect(a, contains(tomFileWriterId));
      expect(a, isNot(b));
    });

    test('FP-4: a failed publish keeps the target, removes the staging file '
        'and throws', () {
      // A non-empty directory at the target path makes the rename fail after
      // the staging write has succeeded — the step whose failure would
      // otherwise leave debris beside the store.
      final target = Directory('${dir.path}/store.json')..createSync();
      File('${target.path}/occupant').writeAsStringSync('x');
      expect(
        () => tomWriteFileAtomically(File(target.path), '[new]'),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(tomAtomicWriteTempPath(target.path)).existsSync(), isFalse);
      expect(target.existsSync(), isTrue);
    });
  });

  group('tomWithFileLock', () {
    test('FP-5: runs the body, returns its value and releases the guard', () {
      final guard = File(tomFileLockPath('${dir.path}/store.json'));
      expect(tomWithFileLock(guard, () => 42), 42);
      expect(guard.existsSync(), isFalse);
    });

    test('FP-6: releases the guard when the body throws', () {
      final guard = File(tomFileLockPath('${dir.path}/store.json'));
      expect(
        () => tomWithFileLock<void>(guard, () => throw StateError('body')),
        throwsStateError,
      );
      expect(guard.existsSync(), isFalse);
    });

    test('FP-7: the guard is a sibling, not the file it protects', () {
      // The protected file is replaced by a rename on every write, so a guard
      // on the file itself would guard an inode that loses its name.
      expect(tomFileLockPath('/x/store.json'), '/x/store.json.lock');
    });

    test('FP-8: a fresh guard held by someone else times out, and the body '
        'never runs', () {
      final guard = File(tomFileLockPath('${dir.path}/store.json'))
        ..writeAsStringSync('other-writer');
      var ran = false;
      expect(
        () => tomWithFileLock(
          guard,
          () => ran = true,
          staleAfter: const Duration(minutes: 1),
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<FileSystemException>().having(
            (e) => e.message,
            'message',
            contains('Nothing was written'),
          ),
        ),
      );
      expect(ran, isFalse);
      expect(guard.existsSync(), isTrue, reason: 'a live guard is not broken');
    });

    test('FP-9: a stale guard is broken, reported with its holder, and the '
        'body runs', () {
      final guard = File(tomFileLockPath('${dir.path}/store.json'))
        ..writeAsStringSync('dead-writer')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
      final warnings = <String>[];
      expect(
        tomWithFileLock(guard, () => 'ran', onBrokenLock: warnings.add),
        'ran',
      );
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('dead-writer'));
      expect(guard.existsSync(), isFalse);
    });

    test('FP-11: a writer whose guard was broken while it worked leaves the '
        'new holder\'s guard alone', () {
      // A guard is broken when it looks abandoned, so a writer that outlives
      // the staleness bound finds, on release, a guard that is not its own.
      // Deleting it would let a third writer in beside the new holder.
      final guard = File(tomFileLockPath('${dir.path}/store.json'));
      tomWithFileLock(guard, () {
        guard
          ..deleteSync()
          ..writeAsStringSync('another-writer#0');
      });
      expect(guard.readAsStringSync(), 'another-writer#0');
    });

    test('FP-12: an orphaned break guard is cleared once stale', () {
      // A breaker killed between taking its turn and finishing it would
      // otherwise block every later waiter on a guard that is itself stale.
      final guard = File(tomFileLockPath('${dir.path}/store.json'))
        ..writeAsStringSync('dead-writer')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
      File('${guard.path}.break')
        ..writeAsStringSync('')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
      expect(tomWithFileLock(guard, () => 'ran'), 'ran');
      expect(File('${guard.path}.break').existsSync(), isFalse);
    });

    test('FP-10: waiters reaching the staleness boundary together never '
        'hold the guard at once', () async {
      // The race the re-check before the delete exists for: both waiters see
      // the abandoned guard as stale, one breaks it and wins the create, and
      // the other must not then delete that winner's fresh guard. Each body
      // claims a marker with an exclusive create, so an overlap fails the
      // create rather than passing unnoticed.
      final guardPath = tomFileLockPath('${dir.path}/store.json');
      File(guardPath)
        ..writeAsStringSync('dead-writer')
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
      final markerPath = '${dir.path}/inside';

      Future<bool> waiter() => Isolate.run(() {
        return tomWithFileLock(
          File(guardPath),
          () {
            final marker = File(markerPath);
            try {
              marker.createSync(exclusive: true);
            } on FileSystemException {
              return false; // someone else is inside
            }
            sleep(const Duration(milliseconds: 100));
            marker.deleteSync();
            return true;
          },
          staleAfter: const Duration(seconds: 5),
          timeout: const Duration(seconds: 10),
        );
      });

      // Eight rather than two: the window between one waiter reading the old
      // guard's age and deleting it is narrow, and more waiters arriving at
      // once is what makes a missing re-check show up run after run.
      final results = await Future.wait(List.generate(8, (_) => waiter()));
      expect(results, everyElement(isTrue), reason: 'every body ran alone');
      expect(File(guardPath).existsSync(), isFalse);
    });
  });
  group('tomWithFileLockAsync', () {
    test('FP-13: runs an asynchronous body, returns its value and releases '
        'the guard', () async {
      final guard = File(tomFileLockPath('${dir.path}/store.json'));
      final value = await tomWithFileLockAsync(guard, () async {
        expect(guard.existsSync(), isTrue, reason: 'held while the body runs');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 42;
      });
      expect(value, 42);
      expect(guard.existsSync(), isFalse);
    });

    test('FP-14: releases the guard when the body throws', () async {
      final guard = File(tomFileLockPath('${dir.path}/store.json'));
      await expectLater(
        tomWithFileLockAsync<void>(guard, () async => throw StateError('b')),
        throwsStateError,
      );
      expect(guard.existsSync(), isFalse);
    });

    test(
      'FP-15: two tasks on one isolate never hold the guard at once',
      () async {
        // The case an operating-system lock cannot see: both tasks belong to
        // one isolate of one process. Each body yields while it holds the
        // guard, which is exactly when the other task would get in.
        final guard = File(tomFileLockPath('${dir.path}/store.json'));
        var inside = 0;
        var overlapped = false;
        Future<void> task() => tomWithFileLockAsync(guard, () async {
          inside++;
          if (inside > 1) overlapped = true;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inside--;
        });
        await Future.wait(List.generate(6, (_) => task()));
        expect(overlapped, isFalse);
        expect(guard.existsSync(), isFalse);
      },
    );

    test('FP-16: a fresh guard held by someone else times out, and the body '
        'never runs', () async {
      final guard = File(tomFileLockPath('${dir.path}/store.json'))
        ..writeAsStringSync('other-writer');
      var ran = false;
      await expectLater(
        tomWithFileLockAsync(
          guard,
          () async => ran = true,
          staleAfter: const Duration(minutes: 1),
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(ran, isFalse);
      expect(guard.existsSync(), isTrue);
    });

    test(
      'FP-17: isolates waiting asynchronously never hold the guard at once',
      () async {
        final guardPath = tomFileLockPath('${dir.path}/store.json');
        final markerPath = '${dir.path}/inside';
        Future<bool> waiter() => Isolate.run(() {
          return tomWithFileLockAsync(File(guardPath), () async {
            final marker = File(markerPath);
            try {
              marker.createSync(exclusive: true);
            } on FileSystemException {
              return false; // someone else is inside
            }
            await Future<void>.delayed(const Duration(milliseconds: 50));
            marker.deleteSync();
            return true;
          }, timeout: const Duration(seconds: 10));
        });
        final results = await Future.wait(List.generate(6, (_) => waiter()));
        expect(results, everyElement(isTrue));
      },
    );

    test('FP-18: the io entry library exports both waiters', () {
      // The guard is reached from outside the kernel through this library
      // alone; the platform-neutral barrel cannot carry `dart:io`.
      expect(io.tomWithFileLock, same(tomWithFileLock));
      expect(io.tomFileLockPath('/x/a.json'), '/x/a.json.lock');
      expect(io.tomFileLockStaleAfter, tomFileLockStaleAfter);
      expect(io.tomWithFileLockAsync, isNotNull);
    });
  });
}
