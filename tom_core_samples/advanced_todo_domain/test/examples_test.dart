/// Runs `example/advanced_todo_domain_example.dart` the way its header tells a
/// reader to, and checks each of the four things it shows.
///
/// No infrastructure is involved, so there is no skip.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the domain example shows the chain, the enums, the key and the '
      'two-level grade', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'example/advanced_todo_domain_example.dart',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final lines = (result.stdout as String).split('\n');

    // The chain, by foreign key.
    expect(
      lines,
      contains(
        'Acme Engineering > Advanced sample > This week > '
        'Ship the advanced sample',
      ),
    );
    expect(
      lines,
      contains('item.listId=l1  list.projectId=p1  project.workspaceId=w1'),
    );

    // A stored name that is not an enum value reads as the safe default.
    expect(
      lines,
      contains(
        'status stored "shipped-yesterday", read backlog '
        '(the closed-safe fallback)',
      ),
    );

    // The resource key.
    expect(lines, contains('item:i1'));

    // Ceiling narrowed by grade, one row per role, and no role collapsing all.
    List<String> row(String role) => lines
        .firstWhere((l) => l.startsWith('$role '))
        .split(RegExp(r'\s+'))
        .toList();
    expect(row('owner'), ['owner', 'full', 'full', 'full', 'full']);
    expect(row('editor'), ['editor', 'full', 'full', 'full', 'read']);
    expect(row('commenter'), ['commenter', 'read', 'read', 'read', 'none']);
    expect(row('viewer'), ['viewer', 'read', 'read', 'disabled', 'none']);
    expect(row('(no'), ['(no', 'role)', 'none', 'none', 'none', 'none']);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
