import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// §74 / tests §59(a): the builder-wide default row-alignment setters must apply
// retroactively to the already-created first row, not just to rows started by a
// later newRow(). The vertical setter already does this; the horizontal one
// did not (it mutated the default but never walked _rows).

void main() {
  group('AclBuilder — default-alignment retroactivity (§74)', () {
    test(
      'setAclDefaultRowHorizontalAlignment applies to the first row too',
      () {
        final acl = AclBuilder()
            .append(const Text('a'))
            .setAclDefaultRowHorizontalAlignment(RowAlignment.center)
            .newRow()
            .append(const Text('b'))
            .build();

        // The first row existed before the setter was called; it must pick up
        // the new default just like the later row.
        expect(acl.rows[0].alignment, RowAlignment.center);
        expect(acl.rows[1].alignment, RowAlignment.center);
      },
    );

    test('setAclDefaultRowVerticalAlignment applies to the first row too '
        '(regression guard)', () {
      final acl = AclBuilder()
          .append(const Text('a'))
          .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.bottom)
          .newRow()
          .append(const Text('b'))
          .build();

      expect(acl.rows[0].defaultRowCrossAlignment, AclRowCrossAlignment.bottom);
      expect(acl.rows[1].defaultRowCrossAlignment, AclRowCrossAlignment.bottom);
    });

    test(
      'an explicit per-row horizontal override is preserved when the default '
      'later changes',
      () {
        final acl = AclBuilder()
            .append(const Text('a'))
            .setRowHorizontalAlignment(RowAlignment.right)
            .setAclDefaultRowHorizontalAlignment(RowAlignment.center)
            .newRow()
            .append(const Text('b'))
            .build();

        expect(
          acl.rows[0].alignment,
          RowAlignment.right,
          reason: 'explicit per-row alignment must survive a default change',
        );
        expect(acl.rows[1].alignment, RowAlignment.center);
      },
    );

    test(
      'an explicit override equal to the previous default is still preserved',
      () {
        // This is the case a naive "value == previousDefault" heuristic would get
        // wrong: the row was explicitly set to left (the construction-time
        // default), so a later default change must NOT clobber it.
        final acl = AclBuilder()
            .append(const Text('a'))
            .setRowHorizontalAlignment(RowAlignment.left)
            .setAclDefaultRowHorizontalAlignment(RowAlignment.center)
            .newRow()
            .append(const Text('b'))
            .build();

        expect(
          acl.rows[0].alignment,
          RowAlignment.left,
          reason: 'an explicit left override must not be treated as inherited',
        );
        expect(acl.rows[1].alignment, RowAlignment.center);
      },
    );

    test('a default set before any append still reaches the first row', () {
      final acl = AclBuilder()
          .setAclDefaultRowHorizontalAlignment(RowAlignment.right)
          .append(const Text('a'))
          .build();

      expect(acl.rows[0].alignment, RowAlignment.right);
    });
  });
}
