/// Storage on the local filesystem: [TomLocalFileSystemStorage] (atomic
/// commits through staged temps and a recorded intent) and
/// [TomDirectoryBundleMedium] (a keyed file medium over a directory). Imports
/// `dart:io`, so a web build cannot link it.
library;

export 'src/io/directory_medium.dart';
export 'src/io/local_storage.dart';
