/// The git backend's repositories on disk: clones of remotes, and the
/// repositories in folders a person picked.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_git/io.dart';
import 'package:tom_git/tom_git.dart';

import '../git/git_storage.dart';

/// Opens the bare clone of a remote under [root], creating it on first use:
/// one directory per repository, named by host and path, in git's own
/// layout.
TomGitCloneOpener tomGitDirectoryClones(String root) => (remote) async {
  final segments = [
    remote.host + (remote.hasPort ? '_${remote.port}' : ''),
    for (final s in remote.pathSegments)
      if (s.isNotEmpty) s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_'),
  ];
  var path = p.joinAll([root, ...segments]);
  if (!path.endsWith('.git')) path = '$path.git';
  return gitOpenDirectory(path, create: true);
};

/// Opens the repository in the folder a `git:file:` locator names — a working
/// repository, a linked worktree or a bare repository
/// ([GitLocalRepository.open]) — for local git locations on a device with a
/// file system.
TomGitLocalOpener tomGitLocalRepositories() =>
    (folder) async => _LocalRepository(
      GitLocalRepository.open(folder.toFilePath(windows: Platform.isWindows)),
    );

class _LocalRepository implements TomGitLocalRepository {
  _LocalRepository(this._local);

  final GitLocalRepository _local;

  @override
  GitRepository get repository => _local.repository;

  @override
  String? headBranch() => _local.headBranch();

  @override
  Set<String> checkedOutBranches() => _local.checkedOutBranches();
}
