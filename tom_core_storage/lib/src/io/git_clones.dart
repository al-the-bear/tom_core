/// Local clones on disk for the git backend.
library;

import 'package:path/path.dart' as p;
import 'package:tom_git/io.dart';

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
