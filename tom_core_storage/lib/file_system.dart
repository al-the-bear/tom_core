/// A `TomFileSystem` (`package:tom_file_system`) over a [TomStorage]
/// container: the files of a local folder, a GitHub repository, a git server
/// or memory, for an editor that takes its storage as a file system.
///
/// An entry point of its own, so the default library carries no file-system
/// dependency.
library;

import 'tom_core_storage.dart';

export 'src/file_system/storage_file_system.dart';
