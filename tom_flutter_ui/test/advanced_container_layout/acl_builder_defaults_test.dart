/// Pins every builder-wide default that `AclBuilder`'s `setAclDefault*`
/// dartdocs name, against the value the builder actually produces.
///
/// These setters describe their own defaults in prose, and prose is the one
/// part of a codebase nothing checks. `setAclDefaultRowGap` told readers that
/// 0 was the default while the field was initialised to 8, and survived that
/// way because no test anywhere named the setter — the gap it configures was
/// simply never asserted.
///
/// So the rule here is: **if a dartdoc names a default, this file asserts it.**
/// A drift between the two then fails a test instead of misleading a reader.
/// When you add a `setAclDefault*` setter whose documentation names a default,
/// add its case below.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/advanced_container_layout/acl_builder.dart';
import 'package:tom_flutter_ui/src/advanced_container_layout/acl_container.dart';
import 'package:tom_flutter_ui/src/advanced_container_layout/row_alignment.dart';

void main() {
  group('documented builder defaults', () {
    test('the default row gap is 8, not 0', () {
      // The value `setAclDefaultRowGap`'s dartdoc names. `newRow()` with no
      // `dist` is the path that consumes it.
      final acl = AclBuilder()
          .append(const Text('A'))
          .newRow()
          .append(const Text('B'))
          .build();

      expect(acl.rows[1].gapBefore, 8.0);
    });

    test('the default append gap is 8', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].defaultAppendGap, 8.0);
    });

    test('the default row height is null — intrinsic', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].height, isNull);
    });

    test('the default flags register is empty', () {
      expect(AclBuilder().defaultFlags, 0);
    });

    test('hide-unauthorized defaults to false', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.defaultHideUnauthorized, false);
    });

    test('the default row vertical alignment is top', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].components[0].rowCrossAlignment,
          AclRowCrossAlignment.top);
    });

    test('the default row horizontal alignment is left', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].alignment, RowAlignment.left);
    });

    test('the default unknown preferred size is 150 x 0', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].components[0].preferredSize,
          const Size(AclBuilder.defaultPreferredWidth, 0));
    });

    test('no default unknown minimum size is applied', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].components[0].minimumSize, isNull);
    });
  });

  group('the gap setters take 0 literally', () {
    // Both gap setters document "pass 0 to disable". That is the opposite of
    // the zero-means-untouched rule the *size* setters follow, where 0 means
    // "keep the built-in default" — so the two conventions are pinned against
    // each other here to keep the asymmetry deliberate.
    test('setAclDefaultRowGap(0) disables the row gap', () {
      final acl = AclBuilder()
          .setAclDefaultRowGap(0)
          .append(const Text('A'))
          .newRow()
          .append(const Text('B'))
          .build();

      expect(acl.rows[1].gapBefore, 0.0);
    });

    test('setAclDefaultAppendGap(0) disables the append gap', () {
      final acl = AclBuilder()
          .setAclDefaultAppendGap(0)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].defaultAppendGap, 0.0);
    });

    test('an explicit newRow dist always beats the default', () {
      final acl = AclBuilder()
          .setAclDefaultRowGap(4)
          .append(const Text('A'))
          .newRow(dist: 20)
          .append(const Text('B'))
          .build();

      expect(acl.rows[1].gapBefore, 20.0);
    });
  });

  group('the size setters take 0 as "keep the built-in default"', () {
    test('a 0 width keeps the built-in preferred width of 150', () {
      final acl = AclBuilder()
          .setAclDefaultUnknownPreferredSize(0, 24)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].components[0].preferredSize,
          const Size(AclBuilder.defaultPreferredWidth, 24));
    });

    test('a non-zero width replaces it', () {
      final acl = AclBuilder()
          .setAclDefaultUnknownPreferredSize(200)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].components[0].preferredSize, const Size(200, 0));
    });

    test('a 0 dimension applies no minimum on that axis', () {
      final acl = AclBuilder()
          .setAclDefaultUnknownMinimumSize(0, 32)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].components[0].minimumSize, const Size(0, 32));
    });
  });
}
