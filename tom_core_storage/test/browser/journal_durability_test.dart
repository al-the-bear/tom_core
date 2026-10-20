/// Does a commit queued offline survive a page reload?
///
/// A `TomMediumCommitJournal` over browser storage is only durable if the
/// browser medium is. On the VM the conditional import substitutes a
/// `TomMemoryBundleMedium` — the honest stand-in for "what durable browser
/// storage does this process have" — so a VM run would prove the journal works
/// over a *volatile* medium, which is precisely the failure a journal exists to
/// prevent.
///
/// So this file runs in a real browser (`-p chrome`), where the conditional
/// import selects `browser_medium_web.dart` and IndexedDB is real. A VM run **skips** it, which is why the suite also carries a driver
/// that invokes this file on Chrome and fails if it does not pass — a browser
/// test nobody runs is the same defect as no browser test.
///
/// **What a "page reload" is here.** Both the journal *and the medium* are
/// dropped and rebuilt over the same namespace. Rebuilding only the journal
/// would prove nothing: `TomMediumCommitJournal` holds no state between
/// calls, so it would pass over a medium that had kept everything in a field.
///
/// **What this file deliberately does not do** is drive a sync engine that
/// replays the journal: delivery is platform-neutral and belongs to the
/// application. What *is* browser-specific is the handoff: after a reload the
/// entry is back, with its changeset bytes intact, which is exactly the input
/// a replay consumes.
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_core_storage/web.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

/// A fresh journal over a fresh medium at [namespace] — a new page load.
TomMediumCommitJournal reopen(String namespace) =>
    TomMediumCommitJournal(medium: tomOpenBrowserMedium(namespace));

/// Clears everything this origin holds under [namespace], so a re-run starts
/// where the first run did. IndexedDB outlives the test process, which is
/// the whole point of the file and also the reason it must clean up.
Future<void> wipe(String namespace) async {
  final medium = tomOpenBrowserMedium(namespace);
  for (final path in await medium.listFiles()) {
    await medium.delete(path);
  }
}

void main() {
  group('STORAGE-BROWSER-JOURNAL an offline edit survives a page reload', () {
    const ns = 'webwork.test.journal';

    setUp(() => wipe(ns));
    tearDown(() => wipe(ns));

    test('STORAGE-BROWSER-JOURNAL-B1: the browser half of the import is what is running '
        '[0923]', () {
      // Anti-vacuity, and the reason this file exists: on the VM the same call
      // returns a `TomMemoryBundleMedium` and every assertion below still passes
      // while proving nothing about durability.
      expect(
        tomOpenBrowserMedium(ns).runtimeType.toString(),
        'TomIndexedDbBundleMedium',
      );
    });

    test(
      'STORAGE-BROWSER-JOURNAL-B2: a queued commit is still there after a reload '
      '[0923]',
      () async {
        final before = reopen(ns);
        final entry = await before.append(
          locator: 'github:acme/handbook/notes.webwork.zip',
          changeset: TomChangeset.singleFile(bytes('the offline edit')),
          baseHead: 'head-1',
          version: 1,
        );
        expect((await before.pending()), hasLength(1));

        // The tab closes. Both objects go; only the origin's storage remains.
        final after = reopen(ns);
        final pending = await after.pending();

        expect(
          pending,
          hasLength(1),
          reason: 'the journal exists to survive exactly this',
        );
        expect(pending.single.sequence, entry.sequence);
        expect(
          pending.single.locator,
          'github:acme/handbook/notes.webwork.zip',
        );
        expect(pending.single.baseHead, 'head-1');
        // The bytes are the point. An entry that survived as a locator and lost
        // its changeset is a queue that knows what it owes and not what to send.
        expect(
          utf8.decode(pending.single.changeset.writes.values.single),
          'the offline edit',
        );
      },
    );

    test(
      'STORAGE-BROWSER-JOURNAL-B3: completing it durably drains it, so a reload does '
      'not resurrect delivered work [0923]',
      () async {
        final before = reopen(ns);
        final entry = await before.append(
          locator: 'github:acme/handbook/notes.webwork.zip',
          changeset: TomChangeset.singleFile(bytes('delivered')),
          baseHead: 'head-1',
          version: 1,
        );

        // Delivered on the next tick: the replay path completes the entry.
        await reopen(ns).complete(entry.sequence);

        expect(
          await reopen(ns).pending(),
          isEmpty,
          reason:
              'a redelivery after every reload would be worse than a lost '
              'queue — it would keep re-pushing work already on the remote',
        );
        // A drained journal keeps no file at all, so nothing is left to misread.
        expect(await tomOpenBrowserMedium(ns).listFiles(), isEmpty);
      },
    );

    test(
      'STORAGE-BROWSER-JOURNAL-B4: two namespaces in one origin do not collide [0923]',
      () async {
        // An origin holds more than one journal: an application's other
        // queues ride the same storage. They are separated by the namespace
        // prefix alone, so that prefix is load-bearing rather than cosmetic.
        const other = 'webwork.test.annotations';
        addTearDown(() => wipe(other));
        await wipe(other);

        await reopen(ns).append(
          locator: 'a.webwork',
          changeset: TomChangeset.singleFile(bytes('journal')),
          baseHead: null,
          version: 1,
        );
        await reopen(other).append(
          locator: 'b.webwork',
          changeset: TomChangeset.singleFile(bytes('annotations')),
          baseHead: null,
          version: 1,
        );

        expect((await reopen(ns).pending()).single.locator, 'a.webwork');
        expect((await reopen(other).pending()).single.locator, 'b.webwork');

        // And neither medium *sees* the other's files. `listFiles` is what a
        // caller enumerates a store with, so a medium that reported keys from
        // across the origin would hand the journal the annotation queue's
        // entries — and strip the wrong number of characters off their names
        // on the way.
        expect(await tomOpenBrowserMedium(ns).listFiles(), hasLength(1));
        expect(await tomOpenBrowserMedium(other).listFiles(), hasLength(1));

        // And clearing one leaves the other, which is what a shared origin
        // requires and what a shared *key* would silently break.
        await reopen(ns).clear();
        expect(await reopen(ns).pending(), isEmpty);
        expect((await reopen(other).pending()).single.locator, 'b.webwork');
      },
    );

    test(
      'STORAGE-BROWSER-JOURNAL-B5: bytes survive the browser store unchanged '
      '[1001]',
      () async {
        // A changeset is arbitrary bytes — a zip bundle, a PNG asset — and a
        // medium that mangled non-UTF-8 would corrupt exactly the payloads that
        // cannot be eyeballed.
        final raw = Uint8List.fromList([0, 1, 2, 250, 251, 252, 253, 254, 255]);
        await reopen(ns).append(
          locator: 'a.webwork',
          changeset: TomChangeset.singleFile(raw),
          baseHead: null,
          version: 1,
        );

        final back = (await reopen(ns).pending()).single;
        expect(back.changeset.writes.values.single, raw);
      },
    );
  });
}
