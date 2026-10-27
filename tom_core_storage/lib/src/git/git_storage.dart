/// A storage backend over git repositories — on any server that speaks smart
/// HTTP, through a local clone, or in a folder on this device — with no git
/// binary.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tom_git/tom_git.dart';

import '../bundle_medium.dart';
import '../commit_progress.dart';
import '../lfs_pointer.dart';
import '../object_ceiling.dart';
import '../storage.dart';
import '../token_source.dart';
import '../git_locator.dart';

/// Opens (creating when needed) the local clone of [remote].
typedef TomGitCloneOpener = Future<GitRepository> Function(Uri remote);

/// A repository in a folder on this device, as [TomGitStorage] needs it.
///
/// `package:tom_core_storage/io.dart` supplies one over `tom_git`'s
/// `GitLocalRepository` (`tomGitLocalRepositories`); this library names no
/// `dart:io`.
abstract interface class TomGitLocalRepository {
  /// Objects and branches, in git's own layout.
  GitRepository get repository;

  /// The branch `HEAD` names: the default branch of a bare repository, the
  /// one checked out in a working one; null when detached.
  String? headBranch();

  /// Every branch some working tree of the repository has checked out.
  Set<String> checkedOutBranches();
}

/// Opens the repository in [folder], a `file:` URL. Throws
/// `GitNotARepositoryException` when the folder holds none.
typedef TomGitLocalOpener = Future<TomGitLocalRepository> Function(Uri folder);

/// Clones held in memory for the life of the opener — for a build with no
/// file system, where every session starts from a fresh fetch.
TomGitCloneOpener tomGitMemoryClones() {
  final clones = <String, GitRepository>{};
  return (remote) async =>
      clones.putIfAbsent(remote.toString(), GitRepository.memory);
}

/// Documents in git repositories: on a server reached over smart HTTP(S), or
/// in a folder on this device.
///
/// * **The medium is a local clone** — [openClone] supplies it, a directory
///   (`package:tom_core_storage/io.dart`) or memory. Only the branch a
///   document is on is fetched, and only when its tip is not already here.
/// * **A head is the document's object id** in the branch tip: the blob of a
///   single-file container, the tree of a folder. Another document changing
///   on the same branch does not move it.
/// * **A commit is a compare-and-swap on that head,** then a push. When the
///   push is refused because somebody else moved the branch, the branch is
///   fetched again; if this document is still where the caller expected, the
///   commit is rebuilt on the new tip and pushed again, and if it is not, the
///   caller gets a [TomCasConflictException] and merges, as with every other
///   backend.
/// * **Credentials** come from [tokens] by the repository's host: the token
///   is the HTTP password, under the token's account name or
///   `x-access-token`.
/// * **A folder on this device** (`git:file:///…`) is read and written in
///   place when [openLocal] is given: there is nothing to fetch, and a commit
///   moves the branch under git's ref lock, compare-and-swap on its old tip,
///   so git and this backend can write the same repository. A branch some
///   working tree has checked out is read but never written — the tree and
///   its index would be left describing the commit before, which is why git
///   itself refuses a push to such a branch. Without [openLocal] (a build
///   with no file system) `file:` locators are not this backend's.
class TomGitStorage extends TomStorage {
  TomGitStorage({
    required this.openClone,
    this.openLocal,
    this.tokens,
    http.Client? client,
    ({String name, String email}) Function()? committer,
    this.commitMessagePrefix = '',
    this.maxPushAttempts = 5,
    int? maxObjectBytes,
  }) : _client = client,
       _committer =
           committer ??
           (() => (name: 'Tom storage', email: 'tom-storage@localhost')),
       _maxObjectBytes = maxObjectBytes;

  final TomGitCloneOpener openClone;
  final TomGitLocalOpener? openLocal;
  final TomTokenSource? tokens;
  final String commitMessagePrefix;

  /// How often a commit is rebuilt and pushed again after losing a race to
  /// a change elsewhere on the branch.
  final int maxPushAttempts;

  final http.Client? _client;

  /// Who a commit is by, asked when each commit is made.
  final ({String name, String email}) Function() _committer;
  final int? _maxObjectBytes;

  final Map<String, _Endpoint> _endpoints = {};

  /// Listings made inside the current [withinPass], by repository.
  Map<String, GitRemoteRefs>? _pass;

  @override
  int? get maxObjectBytes => _maxObjectBytes;

  GitPerson _author() {
    final who = _committer();
    return GitPerson.now(who.name, who.email);
  }

  @override
  bool handles(String locator) {
    if (!TomGitLocator.matches(locator)) return false;
    if (openLocal != null) return true;
    try {
      return !TomGitLocator.parse(locator).isLocal;
    } on FormatException {
      return true;
    }
  }

  @override
  Future<T> withinPass<T>(Future<T> Function() body) async {
    if (_pass != null) return body();
    _pass = {};
    try {
      return await body();
    } finally {
      _pass = null;
    }
  }

  Future<_Endpoint> _endpointFor(TomGitLocator loc) async {
    final key = loc.remote.toString();
    final known = _endpoints[key];
    if (known != null) return known;
    if (loc.isLocal) {
      final opener = openLocal;
      if (opener == null) {
        throw StateError('No local repositories in this build: ${loc.remote}');
      }
      return _endpoints[key] = _LocalEndpoint(await opener(loc.remote));
    }
    final remote = GitHttpRemote(
      loc.remote,
      client: _client,
      credentials: (uri) async {
        final token = await tokens?.tokenFor(uri.host);
        if (token == null) return null;
        return GitCredentials(token.account ?? 'x-access-token', token.secret);
      },
    );
    return _endpoints[key] = _ServedEndpoint(
      remote,
      await openClone(loc.remote),
    );
  }

  /// The branch [loc] is on, resolved, and its tip — fetched when it is a
  /// server's and not in the clone yet. A null tip: the branch does not exist.
  Future<({_Endpoint endpoint, TomGitLocator loc, GitObjectId? tip})> _tip(
    String locator,
    TomGitLocator loc, {
    bool fresh = false,
  }) => _wrap(locator, () async {
    final e = await _endpointFor(loc);
    final tip = await e.tip(loc.branch, pass: fresh ? null : _pass);
    return (endpoint: e, loc: loc.withBranch(tip.branch), tip: tip.id);
  });

  Future<String?> _headAt(
    GitRepository repo,
    GitObjectId? tip,
    String path,
  ) async {
    if (tip == null) return null;
    final root = (await repo.readCommit(tip)).tree;
    if (path.isEmpty) return root.hex;
    final entry = await repo.entryAt(root, path);
    return entry?.id.hex;
  }

  @override
  Future<String?> headOf(String locator) async {
    final loc = TomGitLocator.parse(locator);
    final t = await _tip(locator, loc);
    return _headAt(t.endpoint.repo, t.tip, t.loc.path);
  }

  /// One listing per repository, however many documents it holds.
  @override
  Future<Map<String, String?>> headsOf(Iterable<String> locators) =>
      withinPass(() async {
        final heads = <String, String?>{};
        for (final locator in locators) {
          heads[locator] = await headOf(locator);
        }
        return heads;
      });

  @override
  Future<List<TomStorageEntry>> list(String locator) async {
    final loc = TomGitLocator.parse(locator);
    final t = await _tip(locator, loc);
    final repo = t.endpoint.repo;
    final tip = t.tip;
    if (tip == null) throw TomContainerNotFoundException(locator);
    final root = (await repo.readCommit(tip)).tree;
    final entry = t.loc.path.isEmpty
        ? GitTreeEntry(mode: GitTreeEntry.treeMode, name: '', id: root)
        : await repo.entryAt(root, t.loc.path);
    if (entry == null) throw TomContainerNotFoundException(locator);
    if (!entry.isTree) {
      return [
        TomStorageEntry(
          name: t.loc.path.split('/').last,
          path: TomChangeset.containerPath,
          kind: TomEntryKind.file,
          revision: entry.id.hex,
        ),
      ];
    }
    return [
      for (final e in await repo.listFiles(
        root,
        t.loc.path,
        includeTrees: true,
      ))
        TomStorageEntry(
          name: e.path.split('/').last,
          path: e.path,
          kind: e.isTree ? TomEntryKind.directory : TomEntryKind.file,
          revision: e.isTree ? null : e.id.hex,
        ),
    ];
  }

  @override
  Future<Uint8List> readBytes(String locator) async {
    final loc = TomGitLocator.parse(locator);
    final t = await _tip(locator, loc);
    final tip = t.tip;
    if (tip == null) throw TomContainerNotFoundException(locator);
    final repo = t.endpoint.repo;
    final entry = await repo.entryAt(
      (await repo.readCommit(tip)).tree,
      t.loc.path,
    );
    if (entry == null) throw TomContainerNotFoundException(locator);
    if (entry.isTree) {
      throw TomStorageException(locator, 'Not a single-file container');
    }
    final bytes = await repo.readBlob(entry.id);
    tomRefuseLfsPointer(locator, t.loc.path, bytes, remedy: lfsRemedy);
    return bytes;
  }

  static const lfsRemedy =
      'The repository stores this file in Git LFS, which this backend does '
      'not fetch; store the document without LFS.';

  @override
  Future<TomBundleMedium> readBundle(String locator) async {
    final loc = TomGitLocator.parse(locator);
    final t = await _tip(locator, loc);
    final tip = t.tip;
    if (tip == null) throw TomContainerNotFoundException(locator);
    final repo = t.endpoint.repo;
    final entry = await repo.entryAt(
      (await repo.readCommit(tip)).tree,
      t.loc.path,
    );
    if (entry == null || !entry.isTree) {
      throw TomContainerNotFoundException(locator);
    }
    return TomReadOnlyBundleMedium(_TreeMedium(repo, entry.id, locator));
  }

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) async {
    tomGuardChangeset(locator, changeset, this);
    final loc = TomGitLocator.parse(locator);
    final path = loc.path;
    if (path.isEmpty) {
      throw TomStorageException(
        locator,
        'A git locator with no path names the repository, not a document',
      );
    }
    final result = await _commitLoop(
      locator,
      loc,
      expectedHead: expectedHead,
      changeset: changeset,
      message: message ?? '${commitMessagePrefix}save ${path.split('/').last}',
      writes: {
        for (final w in changeset.writes.entries)
          w.key == TomChangeset.containerPath ? path : '$path/${w.key}':
              w.value,
      },
      deletes: {for (final d in changeset.deletes) '$path/$d'},
    );
    return result ?? TomStorage.emptyHead;
  }

  @override
  Future<void> delete(String locator) async {
    final loc = TomGitLocator.parse(locator);
    final current = await headOf(locator);
    if (current == null) return;
    await _commitLoop(
      locator,
      loc,
      expectedHead: current,
      changeset: null,
      message: '${commitMessagePrefix}delete ${loc.path.split('/').last}',
      writes: const {},
      deletes: {loc.path},
    );
  }

  /// Compares, builds and pushes; rebuilds on a new tip after a lost race
  /// when the document itself did not move. Returns the document's new head.
  Future<String?> _commitLoop(
    String locator,
    TomGitLocator loc, {
    required String? expectedHead,
    required TomChangeset? changeset,
    required String message,
    required Map<String, Uint8List> writes,
    required Set<String> deletes,
  }) async {
    for (var attempt = 0; attempt < maxPushAttempts; attempt++) {
      final t = await _tip(locator, loc, fresh: true);
      final repo = t.endpoint.repo;
      final actual = await _headAt(repo, t.tip, t.loc.path);
      if (actual != expectedHead) {
        throw TomCasConflictException(
          locator,
          expectedHead: expectedHead,
          actualHead: actual,
        );
      }
      if (changeset != null && changeset.isEmpty) return actual;
      final refusal = t.endpoint.refusalFor(t.loc.branch!);
      if (refusal != null) throw TomStorageException(locator, refusal);
      final pushed = await _wrap(locator, () async {
        final base = t.tip == null
            ? null
            : (await repo.readCommit(t.tip!)).tree;
        final tree = await repo.editTree(
          base,
          writes: writes,
          deletes: deletes,
        );
        final commit = await repo.commit(
          tree: tree,
          parents: [?t.tip],
          message: message,
          author: _author(),
        );
        final outcome = await t.endpoint.update(
          t.loc.branch!,
          commit,
          previous: t.tip,
        );
        return (outcome: outcome, tree: tree);
      });
      switch (pushed.outcome) {
        case _Landed():
          final entry = await repo.entryAt(pushed.tree, t.loc.path);
          return entry?.id.hex;
        case _Raced():
          continue;
        case _Refused(:final message):
          throw TomStorageException(locator, message);
      }
    }
    throw TomCasConflictException(
      locator,
      expectedHead: expectedHead,
      actualHead: await headOf(locator),
    );
  }

  Future<T> _wrap<T>(String locator, Future<T> Function() body) async {
    try {
      return await body();
    } on GitUnreachableException catch (e) {
      throw TomUnreachableException(locator, e.message, cause: e);
    } on GitAuthException catch (e) {
      // A public repository is read without a token, so a missing one is
      // only known when the server asks for it; the two answers are those of
      // the other backends, which is what makes the shell ask for a token.
      final host = TomGitLocator.parse(locator).remote.host;
      if (await tokens?.tokenFor(host) == null) {
        throw TomTokenRequiredException(host);
      }
      throw TomTokenRejectedException(
        locator,
        host,
        'The git server refused the credential: ${e.message}',
        cause: e,
      );
    } on GitNotARepositoryException catch (e) {
      throw TomStorageException(
        locator,
        '${e.path} is not a git repository',
        cause: e,
      );
    } on GitRepositoryNotFoundException catch (e) {
      throw TomStorageException(locator, e.message, cause: e);
    } on GitTransportException catch (e) {
      throw TomStorageException(locator, e.message, cause: e);
    } on GitRemoteError catch (e) {
      throw TomStorageException(locator, e.message, cause: e);
    }
  }

  @override
  void close() {
    for (final e in _endpoints.values) {
      e.close();
    }
    _endpoints.clear();
  }
}

/// A branch, resolved, and where it points.
typedef _Tip = ({String branch, GitObjectId? id});

/// What moving a branch came to.
sealed class _Outcome {
  const _Outcome();
}

final class _Landed extends _Outcome {
  const _Landed();
}

/// Somebody else moved the branch first; the caller looks again.
final class _Raced extends _Outcome {
  const _Raced();
}

final class _Refused extends _Outcome {
  const _Refused(this.message);
  final String message;
}

/// Where a repository's branches are read and moved.
sealed class _Endpoint {
  GitRepository get repo;

  /// [branch] (the default when null) and its tip, with the commits in [repo].
  Future<_Tip> tip(String? branch, {required Map<String, GitRemoteRefs>? pass});

  /// Why [branch] must not be written here, or null.
  String? refusalFor(String branch) => null;

  /// Moves [branch] from [previous] to [commit].
  Future<_Outcome> update(
    String branch,
    GitObjectId commit, {
    required GitObjectId? previous,
  });

  void close();
}

/// A repository on a server, through a clone.
final class _ServedEndpoint extends _Endpoint {
  _ServedEndpoint(this.http, this.repo);

  final GitHttpRemote http;

  @override
  final GitRepository repo;

  @override
  Future<_Tip> tip(
    String? branch, {
    required Map<String, GitRemoteRefs>? pass,
  }) async {
    final key = http.url.toString();
    var refs = pass?[key];
    if (refs == null) {
      refs = await http.listRefs();
      pass?[key] = refs;
    }
    final resolved = branch ?? refs.defaultBranch ?? 'main';
    final fetched = await repo.fetchBranch(http, resolved, refs: refs);
    return (branch: resolved, id: fetched.tip);
  }

  @override
  Future<_Outcome> update(
    String branch,
    GitObjectId commit, {
    required GitObjectId? previous,
  }) async {
    final result = await repo.pushBranch(
      http,
      branch,
      commit,
      remoteTip: previous,
    );
    if (result.ok) return const _Landed();
    if (result.isRace) return const _Raced();
    return _Refused('The server refused the push: $result');
  }

  @override
  void close() => http.close();
}

/// A repository in a folder on this device, written in place.
final class _LocalEndpoint extends _Endpoint {
  _LocalEndpoint(this.local);

  final TomGitLocalRepository local;

  @override
  GitRepository get repo => local.repository;

  @override
  String? refusalFor(String branch) =>
      local.checkedOutBranches().contains(branch)
      ? 'The branch "$branch" is checked out in a working tree of this '
            'repository, which a commit made here would leave behind its '
            'branch. Save to another branch, or check out another one '
            'first.'
      : null;

  @override
  Future<_Tip> tip(
    String? branch, {
    required Map<String, GitRemoteRefs>? pass,
  }) async {
    final resolved = branch ?? local.headBranch() ?? 'main';
    return (branch: resolved, id: await repo.refs.read('refs/heads/$resolved'));
  }

  @override
  Future<_Outcome> update(
    String branch,
    GitObjectId commit, {
    required GitObjectId? previous,
  }) async {
    try {
      await repo.refs.write(
        'refs/heads/$branch',
        commit,
        expected: previous ?? GitObjectId.zero,
      );
      return const _Landed();
    } on GitRefConflict {
      return const _Raced();
    }
  }

  @override
  void close() {}
}

/// One folder of one commit, read lazily.
class _TreeMedium extends TomBundleMedium {
  _TreeMedium(this.repo, this.tree, this.locator);

  final GitRepository repo;
  final GitObjectId tree;
  final String locator;

  @override
  Future<bool> exists(String path) async {
    final e = await repo.entryAt(tree, path);
    return e != null && !e.isTree;
  }

  @override
  Future<Uint8List> readBytes(String path) async {
    final e = await repo.entryAt(tree, path);
    if (e == null || e.isTree) {
      throw TomStorageException(locator, 'No file $path in the container');
    }
    final bytes = await repo.readBlob(e.id);
    tomRefuseLfsPointer(locator, path, bytes, remedy: TomGitStorage.lfsRemedy);
    return bytes;
  }

  @override
  Future<List<String>> listFiles() async => [
    for (final e in await repo.listFiles(tree, '')) e.path,
  ];

  @override
  Future<void> writeBytes(String path, Uint8List bytes) =>
      throw UnsupportedError('A commit of a git container is read-only');

  @override
  Future<void> delete(String path) =>
      throw UnsupportedError('A commit of a git container is read-only');
}
