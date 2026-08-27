/// Pins what an `addVariant` builder inherits from the outer builder — and,
/// more importantly, what it does not.
///
/// A variant's rows are harvested from a second, throwaway `AclBuilder` that is
/// constructed fresh. Every builder-wide default the outer builder configured
/// is therefore absent from it, so below the breakpoint the layout changes in
/// ways the author never asked for. The container's own chrome (border,
/// padding, background, title) is unaffected, but for a different reason than
/// readers were told: it lives on the container widget and is never sourced
/// from a variant builder at all.
///
/// **The `drops` group below pins behaviour that is wrong.** It exists so the
/// documentation can describe the real thing, and so that whoever makes the
/// variant builder inherit properly gets a failing test naming each default
/// they have fixed rather than silent success. When that work lands, these
/// expectations flip to match the outer builder — do not "repair" them by
/// reverting the implementation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Builds a container whose every builder-wide default differs from the
/// framework default, plus a variant that restates only its rows — the usage
/// the documentation invites.
Acl buildWithVariant() {
  return AclBuilder(
    title: 'Outer',
    padding: const EdgeInsets.all(11),
    backgroundColor: const Color(0xFF123456),
  )
      .setAclDefaultAppendGap(40)
      .setAclDefaultRowGap(20)
      .setAclDefaultRowHeight(50)
      .setAclDefaultRowHorizontalAlignment(RowAlignment.right)
      .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.bottom)
      .setAclDefaultFlags(AclFlags.expandX)
      .setAclDefaultUnknownPreferredSize(222, 33)
      .setAclDefaultUnknownMinimumSize(44, 55)
      .append(const Text('A'))
      .newRow()
      .append(const Text('B'))
      .addVariant(
        'narrow',
        atWidth: 600,
        builder: (b) =>
            b.append(const Text('X')).newRow().append(const Text('Y')),
      )
      .build();
}

void main() {
  late Acl acl;
  late List<AclRow> base;
  late List<AclRow> variant;

  setUp(() {
    acl = buildWithVariant();
    base = acl.rows;
    variant = acl.variants.single.rows;
  });

  group('the outer builder configured what this file measures', () {
    // Without this, every "drops" expectation below could pass because the
    // setter did nothing rather than because the variant ignored it.
    test('the base rows carry all eight defaults', () {
      expect(base[0].defaultAppendGap, 40.0);
      expect(base[1].gapBefore, 20.0);
      expect(base[0].height, 50.0);
      expect(base[0].alignment, RowAlignment.right);
      expect(base[0].components[0].rowCrossAlignment,
          AclRowCrossAlignment.bottom);
      expect(base[0].components[0].flags, AclFlags.expandX);
      expect(base[0].components[0].preferredSize, const Size(222, 33));
      expect(base[0].components[0].minimumSize, const Size(44, 55));
    });
  });

  group('a variant inherits the container chrome', () {
    // Not through the variant builder — through the container. Which variant
    // is active changes the rows and nothing else, so the chrome cannot vary.
    test('the container keeps its own title, padding and background', () {
      expect(acl.title, 'Outer');
      expect(acl.padding, const EdgeInsets.all(11));
      expect(acl.backgroundColor, const Color(0xFF123456));
    });

    test('a variant carries rows and nothing else', () {
      final v = acl.variants.single;
      expect(v.name, 'narrow');
      expect(v.atWidth, 600);
      expect(v.rows, hasLength(2));
    });
  });

  group('a variant drops every builder-wide default (see library note)', () {
    test('the append gap falls back to 8', () {
      expect(variant[0].defaultAppendGap, 8.0);
    });

    test('the row gap falls back to 8', () {
      expect(variant[1].gapBefore, 8.0);
    });

    test('the row height falls back to intrinsic', () {
      expect(variant[0].height, isNull);
    });

    test('the horizontal alignment falls back to left', () {
      expect(variant[0].alignment, RowAlignment.left);
    });

    test('the vertical alignment falls back to top', () {
      expect(variant[0].components[0].rowCrossAlignment,
          AclRowCrossAlignment.top);
    });

    test('the flags register falls back to empty', () {
      expect(variant[0].components[0].flags, 0);
    });

    test('the unknown preferred size falls back to 150 x 0', () {
      expect(variant[0].components[0].preferredSize,
          const Size(AclBuilder.defaultPreferredWidth, 0));
    });

    test('the unknown minimum size falls back to none', () {
      expect(variant[0].components[0].minimumSize, isNull);
    });
  });

  group('a variant restates its rows against framework defaults', () {
    test('an explicit setting inside the variant builder still applies', () {
      // The workaround the documentation must point at until the builder
      // inherits: restate the defaults inside the variant too.
      final withDefaults = AclBuilder()
          .setAclDefaultAppendGap(40)
          .append(const Text('A'))
          .addVariant(
            'narrow',
            atWidth: 600,
            builder: (b) => b
                .setAclDefaultAppendGap(40)
                .append(const Text('X'))
                .append(const Text('Y')),
          )
          .build();

      expect(withDefaults.variants.single.rows[0].defaultAppendGap, 40.0);
    });
  });
}
