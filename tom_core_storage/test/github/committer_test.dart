/// `TomGitHubStorage.committer`: the author and committer its commits name.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/github.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_github_api/testing.dart';
import 'package:tom_github_api/tom_github_api.dart';

TomGitHubStorage storage(FakeGitHubServer server, {GitHubGitIdentity? who}) {
  final s = TomGitHubStorage.withClient(
    GitHubApiClient(
      token: 'test-token',
      httpClient: server.client,
      baseUrl: FakeGitHubServer.baseUrl,
      minMutativeInterval: Duration.zero,
    ),
    committer: who,
  );
  addTearDown(s.close);
  return s;
}

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  const locator = 'github:al-the-bear/vaults/fleet.kdbx';
  const device = GitHubGitIdentity(
    name: 'bigbeast',
    email: 'bigbeast@tsm.invalid',
  );

  test('STORAGE-COMMITTER-01: a save and a delete name the committer as '
      'author and committer', () async {
    final server = FakeGitHubServer()
      ..repo('al-the-bear/vaults')
      ..authenticatedUser = 'token-owner';
    final s = storage(server, who: device);
    final first = await s.commit(
      locator,
      TomChangeset.singleFile(bytes('one')),
      message: 'tsm: fleet.kdbx from bigbeast',
    );
    final second = await s.commit(
      locator,
      TomChangeset.singleFile(bytes('two')),
      expectedHead: first,
      message: 'tsm: fleet.kdbx from bigbeast',
    );
    await s.delete(locator);
    final named = server.commits.values
        .where((c) => c.message != 'initialize repository')
        .toList();
    expect(named.length, greaterThanOrEqualTo(3));
    for (final c in named) {
      expect(c.author, {'name': 'bigbeast', 'email': 'bigbeast@tsm.invalid'});
      expect(c.committer, {
        'name': 'bigbeast',
        'email': 'bigbeast@tsm.invalid',
      });
    }
    expect(second, isNotEmpty);
  });

  test('STORAGE-COMMITTER-02: without a committer GitHub records the token\'s '
      'owner', () async {
    final server = FakeGitHubServer()
      ..repo('al-the-bear/vaults')
      ..authenticatedUser = 'token-owner';
    final s = storage(server);
    await s.commit(locator, TomChangeset.singleFile(bytes('one')));
    final c = server.commits.values.last;
    expect(c.author!['name'], 'token-owner');
    expect(c.committer!['name'], 'token-owner');
    expect(s.committer, isNull);
  });
}
