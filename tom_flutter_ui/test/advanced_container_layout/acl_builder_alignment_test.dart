import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// The builder-wide default row-alignment setters apply retroactively to the
// already-created first row, not just to rows started by a later newRow().
// Both the vertical and the horizontal setter therefore walk _rows; a setter
// that merely stored the new default would leave the first row behind.

void main() {
  group('AclBuilder — default-alignment retroactivity', () {
    test(
      'setAclDefaultRowHorizontalAlignment applies to the first row too',
      () {
        final acl = AclBuilder()
            .append(const Text('a'))
            .setAclDefaultRowHorizontalAlignment(AclRowAlignment.center)
            .newRow()
            .append(const Text('b'))
            .build();

        // The first row existed before the setter was called; it must pick up
        // the new default just like the later row.
        expect(acl.rows[0].alignment, AclRowAlignment.center);
        expect(acl.rows[1].alignment, AclRowAlignment.center);
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
            .setRowHorizontalAlignment(AclRowAlignment.right)
            .setAclDefaultRowHorizontalAlignment(AclRowAlignment.center)
            .newRow()
            .append(const Text('b'))
            .build();

        expect(
          acl.rows[0].alignment,
          AclRowAlignment.right,
          reason: 'explicit per-row alignment must survive a default change',
        );
        expect(acl.rows[1].alignment, AclRowAlignment.center);
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
            .setRowHorizontalAlignment(AclRowAlignment.left)
            .setAclDefaultRowHorizontalAlignment(AclRowAlignment.center)
            .newRow()
            .append(const Text('b'))
            .build();

        expect(
          acl.rows[0].alignment,
          AclRowAlignment.left,
          reason: 'an explicit left override must not be treated as inherited',
        );
        expect(acl.rows[1].alignment, AclRowAlignment.center);
      },
    );

    test('a default set before any append still reaches the first row', () {
      final acl = AclBuilder()
          .setAclDefaultRowHorizontalAlignment(AclRowAlignment.right)
          .append(const Text('a'))
          .build();

      expect(acl.rows[0].alignment, AclRowAlignment.right);
    });
  });
}
