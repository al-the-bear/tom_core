/// Pins every builder-wide default that `AclBuilder`'s `setAclDefault*`
/// dartdocs name, against the value the builder actually produces.
///
/// These setters describe their own defaults in prose, and prose is the one
/// part of a codebase nothing checks. `setAclDefaultRowGap` told readers that
/// 0 was the default while the field was initialised to 8, and survived that
/// way because no test anywhere named the setter — the gap it configures was
/// simply never asserted.
///
/// So the rule here is: **if a dartdoc names a default, this file asserts it**,
/// and **every `setAclDefault*` setter is exercised here at least once**. A
/// drift between the two then fails a test instead of misleading a reader.
///
/// The second half of that rule is checked rather than merely stated — see
/// "every builder-wide default setter is covered" at the bottom of this file.
/// A rule about test coverage that lives only in a header comment is the same
/// kind of unenforced prose as the dartdocs it is meant to police: the file
/// asserted five factory defaults while never *calling* the five setters that
/// change them, so the setters' own effects went unpinned.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'acl_builder_sources.dart';

/// The builder whose setters must all be exercised, and this file, which must
/// exercise them. Paths are package-relative; `flutter test` runs with the
/// package root as its working directory.
const _builderSource =
    'lib/src/advanced_container_layout/acl_builder.dart and its parts';
const _thisTest =
    'test/advanced_container_layout/acl_builder_defaults_test.dart';

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
      expect(
        acl.rows[0].components[0].rowCrossAlignment,
        AclRowCrossAlignment.top,
      );
    });

    test('the default row horizontal alignment is left', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].alignment, AclRowAlignment.left);
    });

    test('the default unknown preferred size is 150 x 0', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(
        acl.rows[0].components[0].preferredSize,
        const Size(AclBuilder.defaultPreferredWidth, 0),
      );
    });

    test('no default unknown minimum size is applied', () {
      final acl = AclBuilder().append(const Text('A')).build();
      expect(acl.rows[0].components[0].minimumSize, isNull);
    });
  });

  group('the gap setters take 0 literally', () {
    // Both gap setters document "pass 0 to disable", and neither falls back to
    // the built-in 8 the way the preferred-size setter falls back to 150. A
    // gap of 0 is a value someone might actually want; a size of 0 usually is
    // not, which is why the two families read 0 differently.
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

  group('what 0 means in each of the two builder-wide size setters', () {
    // The two setters look like a matched pair and are not one. Only the
    // preferred setter falls back on a 0, and only on its width; the minimum
    // setter stores the 0. Both are pinned here so the asymmetry is a decision
    // rather than an accident.
    test('a 0 width keeps the built-in preferred width of 150', () {
      final acl = AclBuilder()
          .setAclDefaultUnknownPreferredSize(0, 24)
          .append(const Text('A'))
          .build();

      expect(
        acl.rows[0].components[0].preferredSize,
        const Size(AclBuilder.defaultPreferredWidth, 24),
      );
    });

    test('a non-zero width replaces it', () {
      final acl = AclBuilder()
          .setAclDefaultUnknownPreferredSize(200)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].components[0].preferredSize, const Size(200, 0));
    });

    test('a 0 width falls back to 150, not to an earlier default', () {
      // "Keep the built-in default" is not "keep the value you set last". The
      // 200 below is discarded, and the fallback is the factory 150.
      final acl = AclBuilder()
          .setAclDefaultUnknownPreferredSize(200, 10)
          .setAclDefaultUnknownPreferredSize(0, 24)
          .append(const Text('A'))
          .build();

      expect(
        acl.rows[0].components[0].preferredSize,
        const Size(AclBuilder.defaultPreferredWidth, 24),
      );
    });

    test('a 0 minimum dimension is stored as 0, not skipped', () {
      // The component ends up with a non-null minimumSize whose width is 0.
      // A 0 minimum and no minimum are indistinguishable to the layout, which
      // is why storing the 0 is harmless — but they are distinguishable here,
      // and the setter stores rather than skips.
      final acl = AclBuilder()
          .setAclDefaultUnknownMinimumSize(0, 32)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].components[0].minimumSize, const Size(0, 32));
    });

    test('a 0 minimum dimension overwrites an earlier default', () {
      // The defect this pins down. The dartdoc read "pass 0 to leave that
      // dimension untouched", which is a claim only a second call can
      // falsify — and no test made one. The setter assigns the whole Size, so
      // the 100 below is gone and the width is 0.
      final acl = AclBuilder()
          .setAclDefaultUnknownMinimumSize(100, 50)
          .setAclDefaultUnknownMinimumSize(0, 32)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].components[0].minimumSize, const Size(0, 32));
    });
  });

  group(
    '0 on a per-component size setter does preserve the previous value',
    () {
      // The contrast that makes the builder-wide behaviour above legible: the
      // per-component setters really do implement "leave that dimension alone",
      // because they have a previous per-component value to leave alone. The
      // builder-wide setters have none, which is why they cannot.
      test('setMSize(0, h) keeps the width set by the earlier call', () {
        final acl = AclBuilder()
            .append(const Text('A'))
            .setMSize(40, 8)
            .setMSize(0, 12)
            .build();

        expect(acl.rows[0].components[0].minimumSize, const Size(40, 12));
      });

      test('setPSize(0, h) keeps the width set by the earlier call', () {
        final acl = AclBuilder()
            .append(const Text('A'))
            .setPSize(60, 8)
            .setPSize(0, 12)
            .build();

        expect(acl.rows[0].components[0].preferredSize, const Size(60, 12));
      });

      test('setXSize(0, h) keeps the width set by the earlier call', () {
        final acl = AclBuilder()
            .append(const Text('A'))
            .setXSize(80, 8)
            .setXSize(0, 12)
            .build();

        expect(acl.rows[0].components[0].maximumSize, const Size(80, 12));
      });
    },
  );

  group('an omitted maximum leaves its axis unconstrained, not at zero', () {
    // 0 means "leave this axis alone" on all three setters, but what it falls
    // back to when there is nothing to leave alone differs by setter, because
    // 0 does not mean the same thing to a maximum as to a preferred or a
    // minimum. A preferred or minimum of 0 is no constraint; a *maximum* of 0
    // is "no size at all", which the container faithfully turns into
    // `BoxConstraints(maxHeight: 0)` and the child collapses.
    //
    // So `setXSize(200)` — the natural way to write "cap the width at 200" —
    // used to render nothing at all. Both shipped ACL sizing samples call it
    // that way, including the one titled "Maximum width — setXSize".

    test('setXSize(width) leaves the height unconstrained', () {
      final acl = AclBuilder().append(const Text('A')).setXSize(200).build();

      final max = acl.rows[0].components[0].maximumSize!;
      expect(max.width, 200.0);
      expect(
        max.height,
        double.infinity,
        reason: 'an omitted height must not cap the component at 0 high',
      );
    });

    test('setXSize(0, height) leaves the width unconstrained', () {
      // The same defect on the other axis, reachable by the documented
      // "pass 0 to leave that dimension unchanged" spelling.
      final acl = AclBuilder().append(const Text('A')).setXSize(0, 44).build();

      final max = acl.rows[0].components[0].maximumSize!;
      expect(max.width, double.infinity);
      expect(max.height, 44.0);
    });

    test(
      'setXSize and setXWidthInChars agree on the missing-height fallback',
      () {
        // The two set the same field and had two different answers. Derive both
        // rather than restating the constant, so they stay agreed rather than
        // merely being equal today.
        final bySize = AclBuilder()
            .append(const Text('A'))
            .setXSize(80)
            .build();
        final byChars = AclBuilder()
            .append(const Text('A'))
            .setXWidthInChars(10)
            .build();

        expect(
          bySize.rows[0].components[0].maximumSize!.height,
          byChars.rows[0].components[0].maximumSize!.height,
        );
      },
    );

    testWidgets('capping the width does not change the rendered height', (
      tester,
    ) async {
      // The done-bar, asserted in pixels rather than only in the builder's
      // data. The subject has to be a child with an intrinsic height — a bare
      // `Container` measures 0 high with or without the cap, so it would have
      // passed this test while the bug was live.
      //
      // Stated as a comparison against the uncapped component, because the
      // claim is not "some height" but "the height a width cap has no business
      // touching". A defect here shows as the capped `Text` rendering 0.0
      // against the uncapped 20.0.
      Future<double> heightOf(AclBuilder builder) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SizedBox(width: 500, child: builder.build())),
          ),
        );
        await tester.pump();
        return tester.getRect(find.byKey(const ValueKey('x-capped'))).height;
      }

      const child = Text('A', key: ValueKey('x-capped'));
      final uncapped = await heightOf(AclBuilder().append(child));
      final capped = await heightOf(AclBuilder().append(child).setXSize(200));

      expect(
        uncapped,
        greaterThan(0),
        reason:
            'the subject must have an intrinsic height, or this test '
            'cannot detect the collapse it exists to catch',
      );
      expect(
        capped,
        uncapped,
        reason:
            'setXSize(200) caps the width and must say nothing about '
            'the height',
      );
    });
  });

  group('the remaining default setters change what their dartdoc names', () {
    // Asserting the factory default proves only that nobody changed the field
    // initialiser. These call the setter, which is the part a caller uses.
    test('setAclDefaultFlags applies the register to every append', () {
      final acl = AclBuilder()
          .setAclDefaultFlags(AclFlags.expandX)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].components[0].expandX, isTrue);
    });

    test('setAclDefaultRowHeight applies to rows that set no height', () {
      final acl = AclBuilder()
          .setAclDefaultRowHeight(48)
          .append(const Text('A'))
          .newRow()
          .append(const Text('B'))
          .build();

      expect(acl.rows.map((r) => r.height), everyElement(48.0));
    });

    test('setAclDefaultHideUnauthorized reaches the container', () {
      final acl = AclBuilder()
          .setAclDefaultHideUnauthorized(true)
          .append(const Text('A'))
          .build();

      expect(acl.defaultHideUnauthorized, isTrue);
    });

    test('setAclDefaultRowVerticalAlignment reaches the components', () {
      final acl = AclBuilder()
          .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.center)
          .append(const Text('A'))
          .build();

      expect(
        acl.rows[0].components[0].rowCrossAlignment,
        AclRowCrossAlignment.center,
      );
    });

    test('setAclDefaultRowHorizontalAlignment reaches the rows', () {
      final acl = AclBuilder()
          .setAclDefaultRowHorizontalAlignment(AclRowAlignment.right)
          .append(const Text('A'))
          .build();

      expect(acl.rows[0].alignment, AclRowAlignment.right);
    });
  });

  group('every builder-wide default setter is covered', () {
    test('each setAclDefault* method is called somewhere in this file', () {
      // Turns this file's header rule into something that fails. A setter
      // added to AclBuilder and never exercised here is a documented default
      // nothing checks — the condition that let setAclDefaultRowGap document
      // 0 while the field held 8.
      final declared = RegExp(
        r'\bAclBuilder\s+(setAclDefault\w*)\s*\(',
      ).allMatches(aclBuilderSource()).map((m) => m.group(1)!).toSet();
      expect(
        declared,
        isNotEmpty,
        reason:
            'no setAclDefault* declarations found in $_builderSource — '
            'the check below would pass vacuously',
      );

      // Comments stripped: a setter merely *named* in prose is not a setter
      // this file exercises, and accepting the mention would make the rule
      // satisfiable by writing its name in a comment.
      final exercised = _withoutComments(File(_thisTest).readAsStringSync());
      final uncovered =
          declared.where((name) => !exercised.contains('.$name(')).toList()
            ..sort();

      expect(
        uncovered,
        isEmpty,
        reason:
            'these AclBuilder setters are never called in $_thisTest, so '
            'the defaults their dartdoc names are unpinned:\n'
            '${uncovered.map((s) => '  $s').join('\n')}',
      );
    });
  });
}

/// Source with comments removed, so a setter named in prose does not count as
/// a setter this file exercises.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final start = line.indexOf('//');
      return start < 0 ? line : line.substring(0, start);
    })
    .join('\n');
