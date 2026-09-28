/// Holds the README's generated endpoint table to the registry it renders.
///
/// The table is written by `tool/endpoint_table.dart` from the `TomApi`
/// objects themselves. This suite re-renders it and compares, so the README
/// can only fall behind the registry by failing here — the regeneration
/// command is in the failure message.
library;

import 'dart:io';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:test/test.dart';

import '../tool/endpoint_table.dart';

void main() {
  final readme = File('README.md').readAsStringSync();

  test('the README carries exactly what the registry renders', () {
    expect(
      replaceEndpointTable(readme, renderEndpointTable()),
      readme,
      reason:
          'README.md endpoint table is stale — run '
          'dart run tool/endpoint_table.dart --write',
    );
  });

  test('every registry endpoint has exactly one row', () {
    final rows = RegExp(
      r'^\| `(\w+)` \|',
      multiLine: true,
    ).allMatches(renderEndpointTable()).map((m) => m.group(1)!).toList();

    final declared = [
      for (final api in [authApi, adminApi, appApi]) ...api.endpoints.keys,
    ];
    expect(rows, declared);
    expect(rows.toSet(), hasLength(rows.length), reason: 'duplicate ids');
  });

  test('no row reports an undeclared access policy', () {
    expect(renderEndpointTable(), isNot(contains('undeclared')));
  });
}
