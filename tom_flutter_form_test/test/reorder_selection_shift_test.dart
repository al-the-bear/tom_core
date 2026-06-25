/// Unit tests for `reorderedSelectionIndex` — the pure post-reorder
/// selection-shift arithmetic behind `customer_hd_panes.dart`'s
/// `_trackSelection` (review finding tests §62).
///
/// `_trackSelection` keeps a user's pinned master-pane row tracking whichever
/// index a dragged row landed on after a drag-reorder. Its only non-trivial
/// part is integer index arithmetic, lifted to the `@visibleForTesting`
/// top-level `reorderedSelectionIndex` so it can be pinned directly rather
/// than through a `testWidgets` reorder drag. The contract:
///
///   * `selectedIndex == from`            → follows the drag to `to`
///   * down-move `from < s <= to`         → `s - 1`
///   * up-move   `to <= s < from`          → `s + 1`
///   * everything else (and no selection) → `null` (unchanged)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_form_test/common/customer_hd_panes.dart';

void main() {
  group('reorderedSelectionIndex — no selection / no-op', () {
    test('a null selection never shifts', () {
      expect(reorderedSelectionIndex(1, 4, null), isNull);
      expect(reorderedSelectionIndex(4, 1, null), isNull);
    });

    test('an in-place move (from == to) only re-pins the dragged row', () {
      // The dragged row itself "follows" to the same index (harmless re-pin).
      expect(reorderedSelectionIndex(2, 2, 2), 2);
      // Any other selection is untouched.
      expect(reorderedSelectionIndex(2, 2, 0), isNull);
      expect(reorderedSelectionIndex(2, 2, 5), isNull);
    });
  });

  group('reorderedSelectionIndex — the dragged row follows the drag', () {
    test('selectedIndex == from returns to (down-move)', () {
      expect(reorderedSelectionIndex(1, 4, 1), 4);
    });

    test('selectedIndex == from returns to (up-move)', () {
      expect(reorderedSelectionIndex(4, 1, 4), 1);
    });
  });

  group('reorderedSelectionIndex — down-move (from < to) shifts s-1', () {
    // Drag row 1 → 4. Rows originally at 2,3,4 each slide one step left.
    test('a selection swept by the down-move shifts up by one', () {
      expect(reorderedSelectionIndex(1, 4, 2), 1);
      expect(reorderedSelectionIndex(1, 4, 3), 2);
      expect(reorderedSelectionIndex(1, 4, 4), 3); // s == to is included
    });

    test('a selection outside the [from+1, to] window is unaffected', () {
      expect(reorderedSelectionIndex(1, 4, 0), isNull); // before from
      expect(reorderedSelectionIndex(1, 4, 5), isNull); // after to
    });
  });

  group('reorderedSelectionIndex — up-move (from > to) shifts s+1', () {
    // Drag row 4 → 1. Rows originally at 1,2,3 each slide one step right.
    test('a selection swept by the up-move shifts down by one', () {
      expect(reorderedSelectionIndex(4, 1, 1), 2); // s == to is included
      expect(reorderedSelectionIndex(4, 1, 2), 3);
      expect(reorderedSelectionIndex(4, 1, 3), 4);
    });

    test('a selection outside the [to, from-1] window is unaffected', () {
      expect(reorderedSelectionIndex(4, 1, 0), isNull); // before to
      expect(reorderedSelectionIndex(4, 1, 5), isNull); // after from
    });
  });

  group('reorderedSelectionIndex — adjacent single-step moves', () {
    test('down-move by one: only the dragged row and its neighbour move', () {
      expect(reorderedSelectionIndex(2, 3, 2), 3); // dragged row follows
      expect(reorderedSelectionIndex(2, 3, 3), 2); // displaced neighbour
      expect(reorderedSelectionIndex(2, 3, 1), isNull);
      expect(reorderedSelectionIndex(2, 3, 4), isNull);
    });

    test('up-move by one: only the dragged row and its neighbour move', () {
      expect(reorderedSelectionIndex(3, 2, 3), 2); // dragged row follows
      expect(reorderedSelectionIndex(3, 2, 2), 3); // displaced neighbour
      expect(reorderedSelectionIndex(3, 2, 1), isNull);
      expect(reorderedSelectionIndex(3, 2, 4), isNull);
    });
  });
}
