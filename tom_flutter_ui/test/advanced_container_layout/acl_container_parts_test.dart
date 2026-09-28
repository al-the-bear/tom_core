/// The `acl_container` library is split into parts, and stays split.
///
/// One file held the model, the values, the widgets, three responsive passes,
/// the policy-path builders, the fitting engine, the geometry pass and the
/// render pipeline — 3552 lines. Three defects found in one review were the
/// same shape: a rule enforced in one part of that file and quietly not
/// enforced in another, several hundred lines away. A file that long makes
/// that class of inconsistency invisible, which is a property of its size and
/// not of anyone's care.
///
/// Parts rather than separate libraries because privacy in Dart is per
/// *library*: the pieces share `_AclRowLayout`, `_AclFloorWidthBox` and every
/// private member of the container's state. Separate libraries would mean
/// widening those to public — trading the encapsulation for the file split,
/// when the point was to keep both.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _dir = 'lib/src/advanced_container_layout';
const _library = '$_dir/acl_container.dart';

/// The ceiling a part is held to.
///
/// Not a style preference: it is roughly what a reviewer can hold in mind at
/// once, and the number that would have made the three defects visible. The
/// largest part today is a little under it, so a part that grows past this has
/// grown by something worth putting somewhere else.
const _maxLines = 600;

List<String> _partPaths() => RegExp(r"^part '([^']+)';", multiLine: true)
    .allMatches(File(_library).readAsStringSync())
    .map((m) => '$_dir/${m.group(1)!}')
    .toList();

void main() {
  test('the library declares parts, and every one of them exists', () {
    // Guards the two cases below: a library that declared none would satisfy
    // "no part is too long" by having nothing to measure.
    final parts = _partPaths();
    expect(
      parts,
      hasLength(greaterThanOrEqualTo(8)),
      reason: 'found ${parts.length} parts — the split has been undone',
    );
    for (final part in parts) {
      expect(
        File(part).existsSync(),
        isTrue,
        reason:
            '$part is declared and '
            'missing',
      );
    }
  });

  test('every part names this library as its own', () {
    // A `part of` pointing elsewhere would not compile, but a file that is a
    // part of nothing — left behind by a move — would sit in the directory
    // looking like source and be read by nobody.
    for (final part in _partPaths()) {
      expect(
        File(part).readAsStringSync(),
        contains("part of 'acl_container.dart';"),
        reason: '$part does not declare which library it belongs to',
      );
    }
  });

  test('no file in the unit is longer than $_maxLines lines', () {
    // The library itself and its parts, plus the rest of the module: the point
    // is the ceiling, not which file happens to be under it.
    //
    // `acl_builder.dart` is over it and is exempt, with a reason rather than
    // by omission. Its length is ~100 fluent methods of three to ten lines
    // each on one class — a shape a reviewer reads by jumping to a name, not
    // by holding the file. What made the container's length dangerous was five
    // subsystems that had to agree with each other while being hundreds of
    // lines apart, and the builder has one. Splitting it is a separate
    // question, and the day it is answered this line comes out.
    const exempt = {'acl_builder.dart'};
    final offenders = <String>[];
    for (final file in Directory(_dir).listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (exempt.contains(file.uri.pathSegments.last)) continue;
      final length = file.readAsLinesSync().length;
      if (length > _maxLines) {
        offenders.add('${file.path}: $length lines');
      }
    }
    expect(
      offenders..sort(),
      isEmpty,
      reason:
          'a file past $_maxLines lines is one a reviewer cannot hold at once, '
          'which is how a rule comes to be enforced in one half of a file and '
          'not the other: $offenders',
    );
  });

  test('every part of the directory is reachable from the barrel', () {
    // The split must not have orphaned anything. Every `.dart` file here is
    // either exported by the module barrel, or a part of something that is.
    final barrel = File(
      '$_dir/advanced_container_layout.dart',
    ).readAsStringSync();
    final exported = RegExp(
      r"^export '([^']+)';",
      multiLine: true,
    ).allMatches(barrel).map((m) => '$_dir/${m.group(1)!}').toSet();
    final reachable = {...exported};
    for (final library in exported) {
      for (final m in RegExp(
        r"^part '([^']+)';",
        multiLine: true,
      ).allMatches(File(library).readAsStringSync())) {
        reachable.add('$_dir/${m.group(1)!}');
      }
    }
    final onDisk = Directory(_dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.dart'))
        .where((p) => !p.endsWith('advanced_container_layout.dart'))
        .toSet();
    expect(
      onDisk.difference(reachable).toList()..sort(),
      isEmpty,
      reason: 'these files are in the module and reach no consumer',
    );
  });
}
