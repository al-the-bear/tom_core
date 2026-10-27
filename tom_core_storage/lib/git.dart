/// A storage backend over any git server that speaks smart HTTP(S), with a
/// local clone as its medium and no git binary (`package:tom_git`).
///
/// Reaches no `dart:io`: the clone is supplied by an opener — a directory
/// clone from `package:tom_core_storage/io.dart`, or one in memory.
library;

export 'src/git/git_storage.dart';
