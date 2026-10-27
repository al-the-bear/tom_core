/// The git backend held to the storage contract — over a git server in
/// memory, with clones in memory and on disk — and the local filesystem
/// held to the same contract beside it, so the suite is checked against a
/// backend that predates it.
///
/// The live half runs the contract against GitHub and a Gitea in Docker on
/// `TOM_LIVE` (package:tom_test_support's live contract), each on a branch of
/// its own that is deleted afterwards.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/git.dart';
import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_git/io.dart';
import 'package:tom_git/testing.dart';
import 'package:tom_git/tom_git.dart';
import 'package:tom_test_support/gitea.dart';
import 'package:tom_test_support/github_live.dart';

import 'support/scratch.dart';
import 'support/storage_contract.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

String _stamp() => DateTime.now().microsecondsSinceEpoch.toString();

void main() {
  group('local filesystem', () {
    late Directory root;
    var n = 0;
    setUpAll(() => root = scratchDirectory('contract_local_${_stamp()}'));
    tearDownAll(() => root.deleteSync(recursive: true));
    storageContract(
      'STORE-LOCAL',
      open: () async => const TomLocalFileSystemStorage(),
      locator: (name) => '${root.path}/${n++}_$name',
      secondDevice: () async => const TomLocalFileSystemStorage(),
    );
  });

  group('git over a memory server, memory clones', () {
    late GitMemoryServer server;
    var n = 0;
    setUp(() => server = GitMemoryServer());
    storageContract(
      'STORE-GIT-MEM',
      open: () async =>
          TomGitStorage(openClone: tomGitMemoryClones(), client: server.client),
      locator: (name) => 'git:${server.url}::docs/${n++}_$name',
      secondDevice: () async =>
          TomGitStorage(openClone: tomGitMemoryClones(), client: server.client),
    );
  });

  group('git over a memory server, clones on disk', () {
    late GitMemoryServer server;
    late Directory root;
    var n = 0;
    setUp(() {
      server = GitMemoryServer(protocolV2: false);
      root = scratchDirectory('contract_git_${_stamp()}');
    });
    tearDown(() => root.deleteSync(recursive: true));
    storageContract(
      'STORE-GIT-DIR',
      open: () async => TomGitStorage(
        openClone: tomGitDirectoryClones('${root.path}/a'),
        client: server.client,
      ),
      locator: (name) => 'git:${server.url}::${n++}_$name',
      secondDevice: () async => TomGitStorage(
        openClone: tomGitDirectoryClones('${root.path}/b'),
        client: server.client,
      ),
    );
  });

  group('git over a local repository', () {
    late Directory root;
    var n = 0;
    setUp(() {
      root = scratchDirectory('contract_git_local_${_stamp()}');
      gitOpenDirectory('${root.path}/store.git', create: true);
    });
    tearDown(() => root.deleteSync(recursive: true));
    storageContract(
      'STORE-GIT-LOCAL',
      open: () async => TomGitStorage(
        openClone: tomGitMemoryClones(),
        openLocal: tomGitLocalRepositories(),
      ),
      locator: (name) =>
          'git:${Uri.directory('${root.path}/store.git')}::docs/${n++}_$name',
      secondDevice: () async => TomGitStorage(
        openClone: tomGitMemoryClones(),
        openLocal: tomGitLocalRepositories(),
      ),
    );
  });

  group('git backend, local repositories', () {
    late Directory root;
    late TomGitStorage storage;
    setUp(() {
      root = scratchDirectory('git_local_${_stamp()}');
      storage = TomGitStorage(
        openClone: tomGitMemoryClones(),
        openLocal: tomGitLocalRepositories(),
      );
    });
    tearDown(() {
      storage.close();
      root.deleteSync(recursive: true);
    });

    /// A working repository at [name] with `main` checked out and holding
    /// `readme.md`.
    Future<String> working(String name) async {
      final folder = '${root.path}/$name';
      final repo = gitOpenDirectory('$folder/.git', create: true);
      File('$folder/.git/config').writeAsStringSync(
        '[core]\n\trepositoryformatversion = 0\n\tbare = false\n',
      );
      final tree = await repo.editTree(null, writes: {'readme.md': _b('hi')});
      final commit = await repo.commit(
        tree: tree,
        parents: [],
        message: 'init',
        author: GitPerson(name: 'T', email: 't@x', seconds: 1700000000),
      );
      await repo.refs.write('refs/heads/main', commit);
      return folder;
    }

    test('STORE-GIT-LOCAL-1: the branch checked out in a working repository '
        'is read, and a write to it is refused, naming the branch', () async {
      final folder = await working('notes');
      final url = Uri.directory(folder);
      expect(
        utf8.decode(await storage.readBytes('git:$url::readme.md')),
        'hi',
        reason: 'no branch named: HEAD\'s, the one checked out',
      );
      await expectLater(
        storage.commit(
          'git:$url::doc.webwork.zip',
          TomChangeset.singleFile(_b('x')),
          expectedHead: null,
        ),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.message,
            'message',
            allOf(contains('"main"'), contains('checked out')),
          ),
        ),
      );
      expect(
        await storage.headOf('git:$url::doc.webwork.zip'),
        isNull,
        reason: 'nothing was written',
      );
    });

    test('STORE-GIT-LOCAL-2: another branch of a working repository is '
        'written in git\'s own layout and leaves the checked-out branch '
        'alone', () async {
      final folder = await working('notes');
      final before = await gitOpenDirectory(
        '$folder/.git',
      ).refs.read('refs/heads/main');
      final loc = 'git:${Uri.directory(folder)}#webwork::doc.webwork.zip';
      final head = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('saved')),
        expectedHead: null,
      );
      final repo = GitLocalRepository.open(folder).repository;
      final tip = await repo.refs.read('refs/heads/webwork');
      expect(tip, isNotNull);
      final entry = await repo.entryAt(
        (await repo.readCommit(tip!)).tree,
        'doc.webwork.zip',
      );
      expect(entry!.id.hex, head);
      expect(await repo.refs.read('refs/heads/main'), before);
    });

    test('STORE-GIT-LOCAL-3: a folder that holds no repository is refused, '
        'naming the folder', () async {
      final folder = '${root.path}/plain';
      Directory(folder).createSync();
      await expectLater(
        storage.headOf('git:${Uri.directory(folder)}::doc.webwork.zip'),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.message,
            'message',
            contains('not a git repository'),
          ),
        ),
      );
    });

    test('STORE-GIT-LOCAL-4: a commit that loses the race to another writer '
        'on the branch is rebuilt on the new tip; one that loses it on the '
        'same document is a conflict', () async {
      final folder = '${root.path}/store.git';
      gitOpenDirectory(folder, create: true);
      final url = Uri.directory(folder);
      final mine = 'git:$url::mine.kdbx';
      final head = await storage.commit(
        mine,
        TomChangeset.singleFile(_b('1')),
        expectedHead: null,
      );
      final other = TomGitStorage(
        openClone: tomGitMemoryClones(),
        openLocal: tomGitLocalRepositories(),
      );
      addTearDown(other.close);
      await other.commit(
        'git:$url::theirs.txt',
        TomChangeset.singleFile(_b('theirs')),
        expectedHead: null,
      );
      final next = await storage.commit(
        mine,
        TomChangeset.singleFile(_b('2')),
        expectedHead: head,
      );
      expect(
        utf8.decode(await storage.readBytes('git:$url::theirs.txt')),
        'theirs',
      );
      await other.commit(
        mine,
        TomChangeset.singleFile(_b('3')),
        expectedHead: next,
      );
      await expectLater(
        storage.commit(
          mine,
          TomChangeset.singleFile(_b('4')),
          expectedHead: next,
        ),
        throwsA(isA<TomCasConflictException>()),
      );
    });

    test('STORE-GIT-LOCAL-5: the repository root is a folder: it lists, and '
        'a document there is addressed under it', () async {
      final folder = '${root.path}/store.git';
      gitOpenDirectory(folder, create: true);
      final url = Uri.directory(folder);
      await storage.commit(
        'git:$url::top.webwork.zip',
        TomChangeset.singleFile(_b('t')),
        expectedHead: null,
      );
      final entries = await storage.list('git:$url::');
      expect(entries.map((e) => e.name), contains('top.webwork.zip'));
      await expectLater(
        storage.commit(
          'git:$url::',
          TomChangeset.singleFile(_b('x')),
          expectedHead: null,
        ),
        throwsA(isA<TomStorageException>()),
      );
    });

    test('STORE-GIT-LOCAL-7: a commit is by the committer asked for when it '
        'is made', () async {
      final folder = '${root.path}/store.git';
      gitOpenDirectory(folder, create: true);
      var name = 'First';
      final named = TomGitStorage(
        openClone: tomGitMemoryClones(),
        openLocal: tomGitLocalRepositories(),
        committer: () => (name: name, email: ''),
      );
      addTearDown(named.close);
      name = 'Ada';
      await named.commit(
        'git:${Uri.directory(folder)}::a.kdbx',
        TomChangeset.singleFile(_b('a')),
        expectedHead: null,
      );
      final repo = GitLocalRepository.open(folder).repository;
      final commit = await repo.readCommit(
        (await repo.refs.read('refs/heads/main'))!,
      );
      expect(commit.author.name, 'Ada');
      expect(commit.author.email, '');
    });

    test('STORE-GIT-LOCAL-6: without a local opener a file: locator is not '
        'this backend\'s, and an http one still is', () {
      final remoteOnly = TomGitStorage(openClone: tomGitMemoryClones());
      addTearDown(remoteOnly.close);
      expect(
        remoteOnly.handles('git:file:///tmp/x/::doc.webwork.zip'),
        isFalse,
      );
      expect(remoteOnly.handles('git:https://example.org/r.git::d'), isTrue);
      expect(storage.handles('git:file:///tmp/x/::doc.webwork.zip'), isTrue);
    });
  });

  group('git backend', () {
    late GitMemoryServer server;
    late TomGitStorage storage;
    setUp(() {
      server = GitMemoryServer();
      storage = TomGitStorage(
        openClone: tomGitMemoryClones(),
        client: server.client,
      );
    });
    tearDown(() => storage.close());

    test('STORE-GIT-1: a push that loses the race to a change elsewhere on the '
        'branch is rebuilt on the new tip and lands', () async {
      final loc = 'git:${server.url}::mine.kdbx';
      final head = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('1')),
        expectedHead: null,
      );
      var raced = false;
      server.beforePush = () async {
        if (raced) return;
        raced = true;
        await server.seed({'theirs.txt': utf8.encode('theirs')});
      };
      final next = await storage.commit(
        loc,
        TomChangeset.singleFile(_b('2')),
        expectedHead: head,
      );
      expect(raced, isTrue);
      expect(server.requests['push'], 3);
      expect(await storage.headOf(loc), next);
      expect(utf8.decode(await storage.readBytes(loc)), '2');
      expect(
        utf8.decode(await storage.readBytes('git:${server.url}::theirs.txt')),
        'theirs',
        reason: 'the other change is kept: the commit was rebuilt on it',
      );
    });

    test(
      'STORE-GIT-2: a push that loses the race to a change of the same '
      'document is a compare-and-swap conflict naming the new head',
      () async {
        final loc = 'git:${server.url}::mine.kdbx';
        final head = await storage.commit(
          loc,
          TomChangeset.singleFile(_b('1')),
          expectedHead: null,
        );
        server.beforePush = () async {
          server.beforePush = null;
          await server.seed({'mine.kdbx': utf8.encode('theirs')});
        };
        final theirs = GitObject.blob(utf8.encode('theirs')).id.hex;
        await expectLater(
          storage.commit(
            loc,
            TomChangeset.singleFile(_b('2')),
            expectedHead: head,
          ),
          throwsA(
            isA<TomCasConflictException>().having(
              (e) => e.actualHead,
              'actualHead',
              theirs,
            ),
          ),
        );
      },
    );

    test('STORE-GIT-3: a branch named in the locator is the one written, and '
        'the default branch is left alone', () async {
      await server.seed({'readme': utf8.encode('main')});
      final loc = 'git:${server.url}#drafts::doc.kdbx';
      await storage.commit(
        loc,
        TomChangeset.singleFile(_b('draft')),
        expectedHead: null,
      );
      expect(await server.repository.refs.read('refs/heads/drafts'), isNotNull);
      expect(await storage.headOf('git:${server.url}::doc.kdbx'), isNull);
    });

    test('STORE-GIT-4: a refused credential and a missing one are the token '
        'exceptions the other backends throw', () async {
      final guarded = GitMemoryServer(requiredPassword: 'right');
      final loc = 'git:${guarded.url}::doc.kdbx';
      final anonymous = TomGitStorage(
        openClone: tomGitMemoryClones(),
        client: guarded.client,
      );
      addTearDown(anonymous.close);
      await expectLater(
        anonymous.headOf(loc),
        throwsA(isA<TomTokenRequiredException>()),
      );
      final host = guarded.url.host;
      final wrong = TomGitStorage(
        openClone: tomGitMemoryClones(),
        client: guarded.client,
        tokens: TomInMemoryTokenSource([TomToken(host: host, secret: 'wrong')]),
      );
      addTearDown(wrong.close);
      await expectLater(
        wrong.headOf(loc),
        throwsA(isA<TomTokenRejectedException>()),
      );
      final right = TomGitStorage(
        openClone: tomGitMemoryClones(),
        client: guarded.client,
        tokens: TomInMemoryTokenSource([TomToken(host: host, secret: 'right')]),
      );
      addTearDown(right.close);
      expect(await right.headOf(loc), isNull);
    });

    test('STORE-GIT-5: a server nobody answers at is unreachable', () async {
      final offline = TomGitStorage(openClone: tomGitMemoryClones());
      addTearDown(offline.close);
      await expectLater(
        offline.headOf('git:http://127.0.0.1:9/nobody/repo.git::doc.kdbx'),
        throwsA(isA<TomUnreachableException>()),
      );
    });

    test(
      'STORE-GIT-6: inside a pass the refs are listed once per repository',
      () async {
        final a = 'git:${server.url}::a.kdbx';
        final b = 'git:${server.url}::b.kdbx';
        await storage.commit(
          a,
          TomChangeset.singleFile(_b('a')),
          expectedHead: null,
        );
        final before = server.requests['ls-refs'] ?? 0;
        await storage.withinPass(() => storage.headsOf([a, b]));
        expect((server.requests['ls-refs'] ?? 0) - before, 1);
      },
    );
  });

  _liveGitHub();
  _liveGitea();
}

/// A branch of its own in the scratch repository, deleted afterwards.
void _liveContract(
  String id, {
  required Uri url,
  required TomTokenSource tokens,
  required GitCredentials credentials,
}) {
  final branch = 'tom-storage-contract/${_stamp()}';
  var n = 0;
  tearDownAll(() async {
    final remote = GitHttpRemote(url, credentials: (_) async => credentials);
    try {
      final refs = await remote.listRefs();
      final tip = refs.refs['refs/heads/$branch'];
      if (tip != null) {
        await GitRepository.memory().deleteRemoteBranch(
          remote,
          branch,
          remoteTip: tip,
        );
      }
    } finally {
      remote.close();
    }
  });
  storageContract(
    id,
    open: () async =>
        TomGitStorage(openClone: tomGitMemoryClones(), tokens: tokens),
    locator: (name) => 'git:$url#$branch::${n++}_$name',
    secondDevice: () async =>
        TomGitStorage(openClone: tomGitMemoryClones(), tokens: tokens),
  );
}

void _liveGitHub() {
  final config = TomGitHubLiveConfig.fromEnvironment();
  group('git backend against GitHub', () {
    if (config == null) {
      test(
        'STORE-GIT-LIVE-GH',
        () {},
        skip: tomLiveSkipTitle('the GitHub git-backend suite'),
      );
      return;
    }
    _liveContract(
      'STORE-GIT-LIVE-GH',
      url: Uri.parse('https://github.com/${config.repo}.git'),
      tokens: TomInMemoryTokenSource([
        TomToken(host: 'github.com', secret: config.token),
      ]),
      credentials: GitCredentials.token(config.token),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

void _liveGitea() {
  final live = Platform.environment['TOM_LIVE'] != null;
  group('git backend against Gitea', () {
    if (!live) {
      test(
        'STORE-GIT-LIVE-GITEA',
        () {},
        skip:
            'TOM_LIVE is not set: the Gitea suite starts a Docker '
            'container',
      );
      return;
    }
    if (!_dockerAnswers()) {
      test(
        'STORE-GIT-LIVE-GITEA',
        () {},
        skip: 'docker does not answer: the Gitea suite needs it',
      );
      return;
    }
    TomGiteaServer? gitea;
    setUpAll(() async => gitea = await TomGiteaServer.start());
    tearDownAll(() async => gitea?.stop());
    // The server is started in setUpAll, so the contract reads it lazily.
    final tokens = _LateTokens(() => gitea);
    storageContract(
      'STORE-GIT-LIVE-GITEA',
      open: () async =>
          TomGitStorage(openClone: tomGitMemoryClones(), tokens: tokens),
      locator: (name) =>
          'git:${gitea!.repositoryUrl}::contract/${_stamp()}_$name',
      secondDevice: () async =>
          TomGitStorage(openClone: tomGitMemoryClones(), tokens: tokens),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

bool _dockerAnswers() {
  try {
    return Process.runSync('docker', ['info']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

class _LateTokens extends TomTokenSource {
  _LateTokens(this._server);

  final TomGiteaServer? Function() _server;

  @override
  Future<TomToken?> tokenFor(String host) async {
    final s = _server();
    if (s == null) return null;
    return TomToken(host: host, account: s.user, secret: s.token);
  }
}
