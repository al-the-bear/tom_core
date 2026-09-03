/// Enforces that `AclComponent.copyWith` covers **every** declared field.
///
/// `AclComponent` is copied by a hand-restated field list, and a field left out
/// of that list does not fail to compile — it silently falls back to its
/// default. This already happened once: before `copyWith` existed, the
/// specialised `copyWithGapBefore` restated the fields inline, so a component
/// rewritten by the hide-unauthorized pass quietly lost anything the copier had
/// not been taught about.
///
/// `copyWith` replaced that copier but not the hazard — it is the same
/// hand-restated list, one level down. So the coverage is checked here against
/// the declaration itself rather than trusted: the constructor's parameters,
/// `copyWith`'s parameters, and `copyWith`'s forwarding expressions must name
/// exactly the same fields. Adding a 26th field to the class and forgetting
/// `copyWith` fails this file instead of silently dropping the field at
/// runtime.
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
const _sourcePath = 'lib/src/advanced_container_layout/acl_container.dart';

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

  group('copyWith covers every declared field', () {
    test('the constructor declares the fields this file expects', () {
      // A guard on the guard: if the parse silently matched nothing, every
      // set-equality below would pass vacuously.
      expect(declaredFields, isNotEmpty);
      expect(declaredFields, contains('child'));
      expect(declaredFields, contains('hideUnauthorized'));
    });

    test('copyWith accepts a parameter for each one', () {
      final params = _sliceAfter(source, 'AclComponent copyWith(', '{');
      final names = RegExp(
        r'(\w+)\s*,',
      ).allMatches(params).map((m) => m.group(1)!).toSet();

      expect(names, declaredFields);
    });

    test('copyWith forwards each one as `x ?? this.x`', () {
      // The body is what actually decides whether a field survives a copy: a
      // parameter can be accepted and then ignored, which reverts the field
      // just as silently as omitting it.
      final signature = source.indexOf('AclComponent copyWith(');
      final bodyOpen = source.indexOf('return AclComponent(', signature);
      final body = _balanced(source, source.indexOf('(', bodyOpen + 19));

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

      expect(forwarded, declaredFields);
    });

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
