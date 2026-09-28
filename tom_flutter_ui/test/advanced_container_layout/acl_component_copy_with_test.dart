/// Enforces that `AclComponent.copyWith` and `AclRow.copyWith` each cover
/// **every** field their class declares.
///
/// Both are copied by a hand-restated field list, and a field left out of that
/// list does not fail to compile — it silently falls back to its default. It
/// has happened to each of them. On `AclComponent`, the specialised
/// `copyWithGapBefore` restated the fields inline, so a component rewritten by
/// the hide-unauthorized pass quietly lost anything the copier had not been
/// taught about. On `AclRow`, the two responsive passes built fragments by
/// naming fields and between them dropped four, so a row kept all its
/// properties at the width the developer tested and lost some at the width
/// their user had.
///
/// `copyWith` is the answer to both, and it does not remove the hazard — it is
/// the same hand-restated list, one level down. So the coverage is checked here
/// against the declaration itself rather than trusted: for each class, the
/// constructor's parameters, `copyWith`'s parameters, and `copyWith`'s
/// forwarding expressions must name exactly the same fields. Adding a field and
/// forgetting `copyWith` fails this file instead of silently dropping the field
/// at runtime.
///
/// The classes are driven from a list rather than written out twice, so a third
/// copier cannot be added without a line here saying whether it is covered.
///
/// The field count is also a *documented* claim — `copyWith`'s own dartdoc
/// weighs the no-clearing tradeoff against the size of the class — so the
/// number in that prose is checked against the real count too. It had drifted
/// (the dartdoc said 24 after `preferredWidthIsDefault` made it 25), which is
/// what prompted this file.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Path of the source under inspection, relative to the package root — the
/// directory `flutter test` runs from.
///
/// The model is a `part` of the `acl_container` library rather than a library
/// of its own; this names the part that declares the two types, which is where
/// a constructor and its `copyWith` have to agree.
const _sourcePath =
    'lib/src/advanced_container_layout/acl_container_model.dart';

/// Returns the substring delimited by the bracket pair that opens at
/// [openIndex], excluding the brackets themselves.
///
/// Nesting-aware, so a parameter list containing function types or collection
/// literals is sliced correctly.
String _balanced(String source, int openIndex) {
  const pairs = {'(': ')', '{': '}'};
  final open = source[openIndex];
  final close = pairs[open];
  if (close == null) {
    throw StateError('not an opening bracket at $openIndex: "$open"');
  }

  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final ch = source[i];
    if (ch == open) {
      depth++;
    } else if (ch == close) {
      depth--;
      if (depth == 0) return source.substring(openIndex + 1, i);
    }
  }
  throw StateError('unbalanced "$open" from $openIndex');
}

/// Returns the bracket-balanced slice that follows [marker], where the opening
/// bracket is the first [open] character at or after the end of the marker.
String _sliceAfter(String source, String marker, String open) {
  final markerAt = source.indexOf(marker);
  if (markerAt < 0) {
    throw StateError('marker not found in $_sourcePath: "$marker"');
  }
  final openAt = source.indexOf(open, markerAt + marker.length);
  if (openAt < 0) {
    throw StateError('no "$open" after marker: "$marker"');
  }
  return _balanced(source, openAt);
}

/// [source] with every balanced `(...)` group removed.
///
/// A parameter *name* is the identifier before a comma — but a record type
/// writes commas of its own, so `List<(double, double?)>? heightBpOverrides`
/// otherwise contributes a phantom parameter called `double`. `AclComponent`
/// has no record-typed field and never showed this; `AclRow` has two.
String _withoutNestedParens(String source) {
  final out = StringBuffer();
  var depth = 0;
  for (final ch in source.split('')) {
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      if (depth > 0) depth--;
    } else if (depth == 0) {
      out.write(ch);
    }
  }
  return out.toString();
}

void main() {
  late String source;
  late Set<String> declaredFields;

  setUpAll(() {
    final file = File(_sourcePath);
    if (!file.existsSync()) {
      fail(
        'Cannot read $_sourcePath. This test inspects the ACL source and must '
        'be run from the tom_flutter_ui package root.',
      );
    }
    source = file.readAsStringSync();

    final ctor = _sliceAfter(source, 'const AclComponent(', '{');
    declaredFields = RegExp(
      r'this\.(\w+)',
    ).allMatches(ctor).map((m) => m.group(1)!).toSet();
  });

  /// Every class in this unit that carries a hand-restated `copyWith`.
  ///
  /// A record per class rather than a second copy of the group below: the
  /// assertions are identical and only the names differ, and a class added here
  /// is covered by all three at once.
  const copiers = <({String type, String ctor, List<String> witnesses})>[
    (
      type: 'AclComponent',
      ctor: 'const AclComponent(',
      witnesses: ['child', 'hideUnauthorized'],
    ),
    (
      type: 'AclRow',
      ctor: 'const AclRow(',
      // The two the responsive passes were dropping, so a parse that stopped
      // seeing them fails here rather than passing an empty comparison.
      witnesses: ['defaultRowCrossAlignment', 'gapRowMinSize'],
    ),
  ];

  for (final copier in copiers) {
    group('${copier.type}.copyWith covers every declared field', () {
      late Set<String> fields;

      setUp(() {
        final ctor = _sliceAfter(source, copier.ctor, '{');
        fields = RegExp(
          r'this\.(\w+)',
        ).allMatches(ctor).map((m) => m.group(1)!).toSet();
        // `this.x` is unambiguous, so the constructor needs no stripping —
        // but assert the two sides were parsed the same way round.
        expect(fields, isNotEmpty);
      });

      test('the constructor declares the fields this file expects', () {
        // A guard on the guard: if the parse silently matched nothing, every
        // set-equality below would pass vacuously.
        expect(fields, isNotEmpty);
        for (final witness in copier.witnesses) {
          expect(fields, contains(witness));
        }
      });

      test('copyWith accepts a parameter for each one', () {
        final params = _withoutNestedParens(
          _sliceAfter(source, '${copier.type} copyWith(', '{'),
        );
        final names = RegExp(
          r'(\w+)\s*,',
        ).allMatches(params).map((m) => m.group(1)!).toSet();

        expect(names, fields);
      });

      test('copyWith forwards each one as `x ?? this.x`', () {
        // The body is what actually decides whether a field survives a copy: a
        // parameter can be accepted and then ignored, which reverts the field
        // just as silently as omitting it.
        final signature = source.indexOf('${copier.type} copyWith(');
        final bodyOpen = source.indexOf('return ${copier.type}(', signature);
        final body = _balanced(
          source,
          source.indexOf('(', bodyOpen + copier.type.length + 7),
        );

        final forwarded = <String>{};
        for (final m in RegExp(
          r'(\w+):\s*(\w+)\s*\?\?\s*this\.(\w+)',
        ).allMatches(body)) {
          final [name, argument, fallback] = [
            m.group(1)!,
            m.group(2)!,
            m.group(3)!,
          ];
          expect(
            [argument, fallback],
            [name, name],
            reason: 'field "$name" is forwarded from the wrong source',
          );
          forwarded.add(name);
        }

        expect(forwarded, fields);
      });
    });
  }

  group('AclComponent.copyWith sizes itself honestly', () {
    test('the dartdoc names the real field count', () {
      final match = RegExp(r'(\d+)-field class').firstMatch(source);
      expect(
        match,
        isNotNull,
        reason:
            'copyWith\'s dartdoc no longer sizes the class; either restore '
            'the phrase or drop this test with it',
      );
      expect(int.parse(match!.group(1)!), declaredFields.length);
    });
  });

  group('a copy keeps what it was not asked to change', () {
    /// A component whose every inspected field differs from its default, so a
    /// dropped field shows up as a reverted value rather than a coincidence.
    AclComponent populated() => AclComponent(
      child: const Text('original'),
      flags: AclFlags.expandX,
      gapBefore: 12,
      gapBeforeIsDefault: true,
      gapWeight: 3,
      preferredSize: const Size(120, 40),
      preferredWidthIsDefault: true,
      minimumSize: const Size(60, 20),
      maximumSize: const Size(400, 80),
      alignXGap: 7,
      alignYGap: 9,
      rowCrossAlignment: AclRowCrossAlignment.bottom,
      id: 'save',
      group: 'actions',
      inlineVariant: true,
      hideUnauthorized: true,
    );

    void expectSameExceptGap(AclComponent copy, AclComponent original) {
      expect(copy.child, original.child);
      expect(copy.flags, original.flags);
      expect(copy.gapWeight, original.gapWeight);
      expect(copy.preferredSize, original.preferredSize);
      expect(copy.preferredWidthIsDefault, original.preferredWidthIsDefault);
      expect(copy.minimumSize, original.minimumSize);
      expect(copy.maximumSize, original.maximumSize);
      expect(copy.alignXGap, original.alignXGap);
      expect(copy.alignYGap, original.alignYGap);
      expect(copy.rowCrossAlignment, original.rowCrossAlignment);
      expect(copy.id, original.id);
      expect(copy.group, original.group);
      expect(copy.inlineVariant, original.inlineVariant);
      expect(copy.hideUnauthorized, original.hideUnauthorized);
    }

    test('copyWith with no arguments changes nothing', () {
      final original = populated();
      final copy = original.copyWith();

      expectSameExceptGap(copy, original);
      expect(copy.gapBefore, original.gapBefore);
      expect(copy.gapBeforeIsDefault, original.gapBeforeIsDefault);
    });

    test('copyWithGapBefore changes only the gap', () {
      // The production path that used to lose fields: the hide-unauthorized
      // pass carries a hidden component's gap onto the next visible one.
      final original = populated();
      final copy = original.copyWithGapBefore(24);

      expectSameExceptGap(copy, original);
      expect(copy.gapBefore, 24);
      expect(copy.gapBeforeIsDefault, false);
    });

    test('copyWithGapBefore can keep the gap marked as defaulted', () {
      final copy = populated().copyWithGapBefore(24, gapBeforeIsDefault: true);

      expect(copy.gapBefore, 24);
      expect(copy.gapBeforeIsDefault, true);
    });
  });
}
