/// A storage backend over any git server that speaks smart HTTP, with a local
/// clone as its medium and no git binary.
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
import 'git_locator.dart';

/// Opens (creating when needed) the local clone of [remote].
typedef TomGitCloneOpener = Future<GitRepository> Function(Uri remote);

/// Clones held in memory for the life of the opener — for a build with no
/// file system, where every session starts from a fresh fetch.
TomGitCloneOpener tomGitMemoryClones() {
  final clones = <String, GitRepository>{};
  return (remote) async =>
      clones.putIfAbsent(remote.toString(), GitRepository.memory);
}

/// Documents in git repositories, reached over smart HTTP(S).
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
class TomGitStorage extends TomStorage {
  TomGitStorage({
    required this.openClone,
    this.tokens,
    http.Client? client,
    GitPerson Function()? committer,
    this.commitMessagePrefix = '',
    this.maxPushAttempts = 5,
    int? maxObjectBytes,
  }) : _client = client,
       _committer =
           committer ??
           (() => GitPerson.now('Tom storage', 'tom-storage@localhost')),
       _maxObjectBytes = maxObjectBytes;

  final TomGitCloneOpener openClone;
  final TomTokenSource? tokens;
  final String commitMessagePrefix;

  /// How often a commit is rebuilt and pushed again after losing a race to
  /// a change elsewhere on the branch.
  final int maxPushAttempts;

  final http.Client? _client;
  final GitPerson Function() _committer;
  final int? _maxObjectBytes;

  final Map<String, _Remote> _remotes = {};

  /// Listings made inside the current [withinPass], by repository.
  Map<String, GitRemoteRefs>? _pass;

  @override
  int? get maxObjectBytes => _maxObjectBytes;

  @override
  bool handles(String locator) => TomGitLocator.matches(locator);

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

  Future<_Remote> _remoteFor(TomGitLocator loc) async {
    final key = loc.remote.toString();
    final known = _remotes[key];
    if (known != null) return known;
    final repo = await openClone(loc.remote);
    final remote = GitHttpRemote(
      loc.remote,
      client: _client,
      credentials: (uri) async {
        final token = await tokens?.tokenFor(uri.host);
        if (token == null) return null;
        return GitCredentials(token.account ?? 'x-access-token', token.secret);
      },
    );
    return _remotes[key] = _Remote(remote, repo);
  }

  /// The branch [loc] is on, resolved, and its tip — fetched when it is not
  /// in the clone yet. A null tip: the branch does not exist.
  Future<({_Remote remote, TomGitLocator loc, GitObjectId? tip})> _tip(
    String locator,
    TomGitLocator loc, {
    bool fresh = false,
  }) => _wrap(locator, () async {
    final r = await _remoteFor(loc);
    final key = loc.remote.toString();
    final pass = _pass;
    GitRemoteRefs refs;
    if (!fresh && pass != null && pass[key] != null) {
      refs = pass[key]!;
    } else {
      refs = await r.http.listRefs();
      pass?[key] = refs;
    }
    final resolved = loc.branch == null
        ? loc.withBranch(refs.defaultBranch ?? 'main')
        : loc;
    final fetched = await r.repo.fetchBranch(
      r.http,
      resolved.branch!,
      refs: refs,
    );
    return (remote: r, loc: resolved, tip: fetched.tip);
  });

  Future<String?> _headAt(
    GitRepository repo,
    GitObjectId? tip,
    String path,
  ) async {
    if (tip == null) return null;
    final entry = await repo.entryAt((await repo.readCommit(tip)).tree, path);
    return entry?.id.hex;
  }

  @override
  Future<String?> headOf(String locator) async {
    final loc = TomGitLocator.parse(locator);
    final t = await _tip(locator, loc);
    return _headAt(t.remote.repo, t.tip, t.loc.path);
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
    final repo = t.remote.repo;
    final tip = t.tip;
    if (tip == null) throw TomContainerNotFoundException(locator);
    final root = (await repo.readCommit(tip)).tree;
    final entry = await repo.entryAt(root, t.loc.path);
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
    final repo = t.remote.repo;
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
    final repo = t.remote.repo;
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
      final repo = t.remote.repo;
      final actual = await _headAt(repo, t.tip, t.loc.path);
      if (actual != expectedHead) {
        throw TomCasConflictException(
          locator,
          expectedHead: expectedHead,
          actualHead: actual,
        );
      }
      if (changeset != null && changeset.isEmpty) return actual;
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
          author: _committer(),
        );
        final result = await repo.pushBranch(
          t.remote.http,
          t.loc.branch!,
          commit,
          remoteTip: t.tip,
        );
        return (result: result, tree: tree);
      });
      if (pushed.result.ok) {
        final entry = await repo.entryAt(pushed.tree, t.loc.path);
        return entry?.id.hex;
      }
      if (!pushed.result.isRace) {
        throw TomStorageException(
          locator,
          'The server refused the push: ${pushed.result}',
        );
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
    for (final r in _remotes.values) {
      r.http.close();
    }
    _remotes.clear();
  }
}

class _Remote {
  _Remote(this.http, this.repo);

  final GitHttpRemote http;
  final GitRepository repo;
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
