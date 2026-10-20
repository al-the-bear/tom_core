/// The browser medium, handed bytes.
///
/// `TomIndexedDbBundleMedium` hands IndexedDB the bytes as a typed array and
/// copies them back out. The journal's own test reaches the medium only
/// through YAML text, which is UTF-8 by the time it arrives; a fault in that
/// handoff would pass it. Here the medium is given the bytes themselves — every byte value, and
/// a block that is not UTF-8 and does not compress — and asked for them back.
///
/// Runs on a real browser (`--platform chrome`); on the VM the conditional
/// import selects the in-memory stub and this would assert nothing about
/// IndexedDB. `browser_suite_test.dart` drives it from the ordinary
/// `dart test`, and names its own skip condition.
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_core_storage/web.dart';

Future<void> wipe(String namespace) async {
  final medium = tomOpenBrowserMedium(namespace);
  for (final path in await medium.listFiles()) {
    await medium.delete(path);
  }
}

/// Bytes nothing can mistake for text: a fixed-seed generator, so the block is
/// the same on every run and carries no run of any length that repeats.
Uint8List incompressible(int length) {
  var state = 0x2545F491;
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    out[i] = state & 0xFF;
  }
  return out;
}

void main() {
  const ns = 'webwork.test.medium';
  const other = 'webwork.test.medium.other';

  setUp(() async {
    await wipe(ns);
    await wipe(other);
  });
  tearDown(() async {
    await wipe(ns);
    await wipe(other);
  });

  test(
    'STORAGE-BROWSER-MEDIUM-1: this run selected the browser half, not the stub',
    () {
      expect(tomOpenBrowserMedium(ns), isNot(isA<TomMemoryBundleMedium>()));
    },
  );

  test(
    'STORAGE-BROWSER-MEDIUM-2: every byte value comes back as it went in [0929]',
    () async {
      final all = Uint8List.fromList([for (var i = 0; i < 256; i++) i]);
      await tomOpenBrowserMedium(ns).writeBytes('all.bin', all);
      // A second medium over the same namespace: nothing is held in memory.
      expect(await tomOpenBrowserMedium(ns).readBytes('all.bin'), all);
    },
  );

  test(
    'STORAGE-BROWSER-MEDIUM-3: 64 KiB that is not UTF-8 and does not compress comes '
    'back byte for byte [0929]',
    () async {
      final block = incompressible(64 * 1024);
      expect(
        () => utf8.decode(block),
        throwsFormatException,
        reason: 'the fixture has to be something text handling would break',
      );
      await tomOpenBrowserMedium(ns).writeBytes('assets/a.png', block);
      final back = await tomOpenBrowserMedium(ns).readBytes('assets/a.png');
      expect(back.length, block.length);
      expect(back, block);
    },
  );

  test(
    'STORAGE-BROWSER-MEDIUM-Q1: more than localStorage could ever hold is written and '
    'read back [1001]',
    () async {
      // localStorage's ceiling is a few megabytes per origin, and a journal
      // entry carrying one asset met it. 8 MiB of incompressible bytes is past
      // it under any encoding; IndexedDB's quota is a share of the disk.
      final block = incompressible(8 * 1024 * 1024);
      await tomOpenBrowserMedium(ns).writeBytes('assets/big.bin', block);
      final back = await tomOpenBrowserMedium(ns).readBytes('assets/big.bin');
      expect(back.length, block.length);
      expect(back, block);
    },
  );

  test(
    'STORAGE-BROWSER-MEDIUM-5: text written as text is read as the same text [0929]',
    () async {
      const text = 'Überschrift — “quoted” 日本語\n';
      await tomOpenBrowserMedium(ns).writeString('t.yaml', text);
      expect(await tomOpenBrowserMedium(ns).readString('t.yaml'), text);
    },
  );

  test(
    'STORAGE-BROWSER-MEDIUM-6: the namespace keeps one medium\'s files from another\'s, in '
    'reading, listing and deleting [0929]',
    () async {
      final mine = tomOpenBrowserMedium(ns);
      final theirs = tomOpenBrowserMedium(other);
      await mine.writeBytes('same.bin', Uint8List.fromList([1, 2, 3]));
      await theirs.writeBytes('same.bin', Uint8List.fromList([9, 9]));
      // A namespace that merely STARTS like this one is a different database.
      final stray = tomOpenBrowserMedium('${ns}x');
      await stray.writeBytes('stray.bin', Uint8List.fromList([0]));
      addTearDown(() => stray.delete('stray.bin'));

      expect(await mine.readBytes('same.bin'), [1, 2, 3]);
      expect(await theirs.readBytes('same.bin'), [9, 9]);
      expect(await mine.listFiles(), ['same.bin']);
      expect(await theirs.listFiles(), ['same.bin']);

      await mine.delete('same.bin');
      expect(await mine.exists('same.bin'), isFalse);
      expect(await theirs.readBytes('same.bin'), [9, 9]);
    },
  );

  test(
    'STORAGE-BROWSER-MEDIUM-7: a file that is not there is an error, not empty bytes',
    () async {
      expect(
        () => tomOpenBrowserMedium(ns).readBytes('absent.bin'),
        throwsStateError,
      );
    },
  );
}
