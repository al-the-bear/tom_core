/// Pins what an `addVariant` builder inherits from the outer builder — and,
/// more importantly, what it does not.
///
/// A variant's rows are harvested from a second, throwaway `AclBuilder`, and
/// the outer builder copies its **row-level** defaults onto that builder before
/// the caller's callback runs — so a variant that restates only its rows gets
/// rows built against the same defaults as the container's own. An explicit
/// setting inside the variant still wins; it overwrites the inherited value on
/// the way past.
///
/// The container's own settings — chrome, `aclId`, `idScope`, `aclGroup`,
/// `defaultHideUnauthorized` — are **not** copied, and do not need to be: they
/// are read from the outer builder at `build()` and land on the container
/// widget, which a variant never replaces. Selecting a variant swaps the row
/// list and nothing else.
///
/// Each default is asserted separately rather than in one sweep, so a
/// regression names the setting it broke. The eight were measured as *drops*
/// first — the variant builder was constructed bare, and every builder-wide
/// default the outer builder configured was absent from it — which is how the
/// list came to be complete rather than plausible.
library;

import 'dart:io';

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
      expect(
        base[0].components[0].rowCrossAlignment,
        AclRowCrossAlignment.bottom,
      );
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

  group('a variant inherits every builder-wide row default', () {
    test('the append gap', () {
      expect(variant[0].defaultAppendGap, 40.0);
    });

    test('the row gap', () {
      expect(variant[1].gapBefore, 20.0);
    });

    test('the row height', () {
      expect(variant[0].height, 50.0);
    });

    test('the horizontal alignment, including on the first row', () {
      // The first row is created by the builder's constructor, before the
      // defaults are copied in — so it is the one a copy that only sets the
      // fields would miss.
      expect(variant[0].alignment, RowAlignment.right);
      expect(variant[1].alignment, RowAlignment.right);
    });

    test('the vertical alignment', () {
      expect(
        variant[0].components[0].rowCrossAlignment,
        AclRowCrossAlignment.bottom,
      );
    });

    test('the flags register', () {
      expect(variant[0].components[0].flags, AclFlags.expandX);
    });

    test('the unknown preferred size', () {
      expect(variant[0].components[0].preferredSize, const Size(222, 33));
    });

    test('the unknown minimum size', () {
      expect(variant[0].components[0].minimumSize, const Size(44, 55));
    });

    test('so the variant rows match the base rows default for default', () {
      // The claim the documentation makes, stated once as a whole: restating
      // only the rows changes only the rows.
      expect(variant[0].defaultAppendGap, base[0].defaultAppendGap);
      expect(variant[1].gapBefore, base[1].gapBefore);
      expect(variant[0].height, base[0].height);
      expect(variant[0].alignment, base[0].alignment);
      expect(
        variant[0].components[0].rowCrossAlignment,
        base[0].components[0].rowCrossAlignment,
      );
      expect(variant[0].components[0].flags, base[0].components[0].flags);
      expect(
        variant[0].components[0].preferredSize,
        base[0].components[0].preferredSize,
      );
      expect(
        variant[0].components[0].minimumSize,
        base[0].components[0].minimumSize,
      );
    });
  });

  group('a variant may still set its own defaults', () {
    test('a setting inside the variant overrides the inherited one', () {
      // Inheritance must not become imposition: the narrow layout is where an
      // author is most likely to want a different gap, and the variant builder
      // is the only place to say so.
      final overridden = AclBuilder()
          .setAclDefaultAppendGap(40)
          .append(const Text('A'))
          .addVariant(
            'narrow',
            atWidth: 600,
            builder: (b) => b
                .setAclDefaultAppendGap(4)
                .append(const Text('X'))
                .append(const Text('Y')),
          )
          .build();

      expect(overridden.rows[0].defaultAppendGap, 40.0, reason: 'the outer');
      expect(
        overridden.variants.single.rows[0].defaultAppendGap,
        4.0,
        reason: 'the variant said otherwise, and gets what it asked for',
      );
    });

    test('a row alignment set inside the variant beats the inherited one', () {
      // The alignment is the one the copy has to restamp onto an
      // already-created row, so "the variant can still override it" is worth
      // asserting separately from the others.
      final overridden = AclBuilder()
          .setAclDefaultRowHorizontalAlignment(RowAlignment.right)
          .append(const Text('A'))
          .addVariant(
            'narrow',
            atWidth: 600,
            builder: (b) => b
                .setAclDefaultRowHorizontalAlignment(RowAlignment.center)
                .newRow()
                .append(const Text('X')),
          )
          .build();

      expect(overridden.rows[0].alignment, RowAlignment.right);
      expect(
        overridden.variants.single.rows.last.alignment,
        RowAlignment.center,
      );
    });
  });

  group('every builder-wide default is classified', () {
    // The durable half. A default added to `AclBuilder` is either row-level —
    // and must be copied into the variant builder, or a variant silently stops
    // inheriting it — or container-level, read once at `build()` and already
    // applying. Nothing may be neither, which is the state all ten row-level
    // defaults were in.
    //
    // Read from the source because the question is which fields *exist*, and
    // no runtime value can answer that.
    late String builderSource;

    setUp(() {
      builderSource = File(
        'lib/src/advanced_container_layout/acl_builder.dart',
      ).readAsStringSync();
    });

    /// The fields `_copyRowDefaultsTo` assigns onto its target.
    Set<String> copied(String source) {
      final start = source.indexOf('void _copyRowDefaultsTo(');
      expect(start, isNot(-1), reason: '_copyRowDefaultsTo not found');
      final end = source.indexOf('\n  }', start);
      return RegExp(r'target\.(_\w+)\s*=')
          .allMatches(source.substring(start, end))
          .map((m) => m.group(1)!)
          .toSet();
    }

    /// Declared `_default*` fields that `build()` reads off this builder, so
    /// they reach the container widget and apply to every variant already.
    const containerLevel = <String>{'_defaultHideUnauthorized'};

    test('each one is copied into the variant or read by the container', () {
      final declared = RegExp(
        r'^  [\w?<>,()\[\] ]+?\s+(_default\w+)\s*[=;]',
        multiLine: true,
      ).allMatches(builderSource).map((m) => m.group(1)!).toSet();

      expect(
        declared.length,
        greaterThan(8),
        reason:
            'AclBuilder declares a handful of _default fields; far fewer '
            'means the scan stopped matching rather than the class shrinking',
      );

      final unclassified =
          declared
              .difference(copied(builderSource))
              .difference(containerLevel)
              .toList()
            ..sort();
      expect(
        unclassified,
        isEmpty,
        reason:
            'these builder-wide defaults are neither copied into the variant '
            'builder nor listed as container-level, so a variant silently '
            'stops inheriting them: $unclassified',
      );
    });

    test('nothing is listed as container-level and copied as well', () {
      expect(
        containerLevel.intersection(copied(builderSource)),
        isEmpty,
        reason:
            'a container-level default copied into the variant builder is '
            'a second channel to the same place',
      );
    });
  });
}
