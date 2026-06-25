/// Unit tests for the pure logic in the demo *state fixtures* that no other
/// suite reaches (review finding tests §65):
///
///   * `phase2aLookupProductPrice` — the duplicate-name **return-first**
///     invariant. The catalog carries three names twice ('Patch review token',
///     'Maintainer T-shirt', 'Conference badge'); the linear lookup returning
///     the first match is only *correct* because each duplicate pair shares a
///     price. Nothing asserted that invariant — so this suite pins it directly.
///   * `phase2aProductSource` — the dedup-by-name that collapses those
///     duplicates for the picker.
///   * `DemoRPageSource.fetchPage` — the pagination arithmetic at the tail of
///     the 10 000-row source: the `start >= totalRows → []` past-last-page
///     branch and the `start + pageSize > totalRows` end-clamp, neither of
///     which `phase6_smoke_test.dart` (page 0 only) reaches.
///
/// All three are pure (the picker source is a `StaticSelectableSource`, the
/// page source is plain async arithmetic), so no reflection / widget binding
/// is needed — these are plain `test()`s.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_flutter_form_test/state/phase2a_state.dart';
import 'package:tom_flutter_form_test/state/phase6_state.dart';

void main() {
  group('phase2aLookupProductPrice — duplicate-name return-first invariant',
      () {
    test('returns the (shared) price for each duplicated catalog name', () {
      // Each of these names appears twice in the catalog; the linear lookup
      // returns the *first* match — correct only because the pair agrees.
      expect(phase2aLookupProductPrice('Patch review token'), 12.00);
      expect(phase2aLookupProductPrice('Maintainer T-shirt'), 24.50);
      expect(phase2aLookupProductPrice('Conference badge'), 0.00);
    });

    test(
        'every duplicated catalog name shares a single price '
        '(the latent invariant the return-first lookup relies on)', () {
      // Group prices by name; any name mapping to >1 distinct price would make
      // phase2aLookupProductPrice depend on catalog *order* — a silent bug.
      final pricesByName = <String, Set<double>>{};
      for (final p in phase2aProductCatalog) {
        pricesByName.putIfAbsent(p.name, () => <double>{}).add(p.price);
      }
      final conflicting = pricesByName.entries
          .where((e) => e.value.length > 1)
          .map((e) => '${e.key}: ${e.value}')
          .toList();
      expect(conflicting, isEmpty,
          reason: 'duplicate catalog names must agree on price so the '
              'return-first lookup is order-independent');

      // And there genuinely are duplicates to protect (otherwise this test
      // would be vacuously green if the catalog were ever fully deduped).
      final names = phase2aProductCatalog.map((p) => p.name).toList();
      expect(names.length, greaterThan(names.toSet().length),
          reason: 'the fixture is expected to contain duplicate names');
    });
  });

  group('phase2aProductSource — dedup-by-name', () {
    test('collapses duplicate names to one item each', () async {
      final items = await phase2aProductSource().getItems();
      final values = items.map((i) => i.value).toList();

      // No value appears twice.
      expect(values.length, values.toSet().length,
          reason: 'the picker source must not list a product name twice');

      // The deduped count equals the number of *distinct* catalog names …
      final distinctNames =
          phase2aProductCatalog.map((p) => p.name).toSet();
      expect(values.toSet(), distinctNames);

      // … and is strictly fewer than the raw catalog (dedup did collapse).
      expect(values.length, lessThan(phase2aProductCatalog.length));
    });

    test('each duplicated name survives exactly once', () async {
      final items = await phase2aProductSource().getItems();
      final values = items.map((i) => i.value).toList();
      for (final dup in const [
        'Patch review token',
        'Maintainer T-shirt',
        'Conference badge',
      ]) {
        expect(values.where((v) => v == dup), hasLength(1),
            reason: '$dup should be deduped to a single picker entry');
      }
    });

    test('labels embed the formatted price', () async {
      final items = await phase2aProductSource().getItems();
      final badge = items.firstWhere((i) => i.value == 'Conference badge');
      expect(badge.label, 'Conference badge  —  \$0.00');
    });
  });

  group('DemoRPageSource.fetchPage — pagination edges', () {
    final source = DemoRPageSource();

    test('a full first page returns pageSize formatted rows', () async {
      final page = await source.fetchPage(0, 50);
      expect(page, hasLength(50));
      expect(page.first, 'Row #00000');
      expect(page.last, 'Row #00049');
    });

    test('the last partial page is end-clamped to totalRows', () async {
      // pageSize 300 does not divide 10 000 evenly: page 33 spans
      // start=9900 .. start+pageSize=10200, clamped to 10000 → 100 rows.
      final page = await source.fetchPage(33, 300);
      expect(page, hasLength(100));
      expect(page.last, 'Row #09999',
          reason: 'the clamp must stop exactly at the last row');
    });

    test('a page entirely past the last row returns []', () async {
      // start = 200 * 50 = 10 000 == totalRows → past-last-page branch.
      expect(await source.fetchPage(200, 50), isEmpty);
      // And well beyond.
      expect(await source.fetchPage(500, 50), isEmpty);
    });

    test('failNext makes the fetch throw instead of returning a slice',
        () async {
      expect(
        () => source.fetchPage(0, 50, failNext: true),
        throwsStateError,
      );
    });
  });
}
