/// Runs `example/` the way its header tells a reader to, and checks the three
/// things it exists to show.
///
/// The example needs no database, scheduler or socket, so there is no skip
/// here: if it cannot run on a bare checkout, that is the defect.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('example/digest_composition_example.dart queues, then delivers one '
      'German and one English digest', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'example/digest_composition_example.dart',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final out = result.stdout as String;

    // Queued, not sent: the pass returns before the transport sees anything.
    expect(out, contains('queued 2 digest(s); delivered so far: 0'));

    // Each recipient in their stored language, from the shipped bundles.
    final bob = out.substring(out.indexOf('To:      bob@example.com'));
    final carol = out.substring(out.indexOf('To:      carol@example.com'));
    expect(bob, contains('Subject: Advanced Todo: 2 offene Vorgänge'));
    expect(bob, contains('Guten Morgen Bob Turing'));
    expect(carol, contains('Subject: Advanced Todo: 1 open item(s)'));
    expect(carol, contains('Good morning Carol Hopper'));

    // The conditional lines are resources too, and only appear when true.
    expect(bob, contains('überfällig'));
    expect(carol, isNot(contains('overdue')));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
